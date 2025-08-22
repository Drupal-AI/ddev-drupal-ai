# Implementation Plan: Drupal Recipe Integration

This document outlines the implementation plan for integrating Drupal recipes into the ddev-drupal-ai add-on, based on [GitHub Issue #3](https://github.com/Drupal-AI/ddev-drupal-ai/issues/3).

## Overview

Transform the current module-based approach by integrating Drupal recipes that provide complete, pre-configured AI environments. This changes the setup from "install modules and configure manually" to "install recipes and get a working AI-powered Drupal site immediately."

## Core Implementation Strategy

### 1. Enhanced Configuration Structure

**File: `drupal-ai/configs/functionalities.yaml`**

Add recipe machine names and configuration overrides to the existing structure:

```yaml
## #ddev-generated

functionalities:
  vector-search:
    name: "Vector Search & Embeddings"
    description: "Semantic search using vector databases"
    required_addons: ["robertoperuzzo/ddev-pgvector"]
    drupal_modules: ["ai", "ai_search", "search_api"]  # Keep existing
    drupal_recipes: ["ai-vector-search"]               # New: just machine name

  content-generation:
    name: "Content Generation"
    description: "AI-powered content creation"
    required_addons: []
    drupal_modules: ["ai", "ai_content"]
    drupal_recipes: ["ai-content-generation"]

  image-analysis:
    name: "Image Analysis"
    description: "AI-powered image recognition and analysis"
    required_addons: []
    drupal_modules: ["ai", "ai_vision"]
    drupal_recipes: ["ai-image-analysis"]

  qa-system:
    name: "Q&A System"
    description: "Intelligent question answering"
    required_addons: ["robertoperuzzo/ddev-pgvector"]
    drupal_modules: ["ai", "ai_qa", "search_api"]
    drupal_recipes: ["ai-qa-system"]

  code-assistant:
    name: "Code Assistant"
    description: "AI-powered code generation and assistance"
    required_addons: []
    drupal_modules: ["ai", "ai_code"]
    drupal_recipes: ["ai-code-assistant"]

  document-processing:
    name: "Document Processing"
    description: "Extract and process various document formats"
    required_addons: ["robertoperuzzo/ddev-unstructured"]
    drupal_modules: ["ai", "ai_documents"]
    drupal_recipes: ["ai-document-processing"]

  ai-agents-chatbot:
    name: "AI Agents Chatbot"
    description: "Interactive AI chatbot with agent evaluation capabilities"
    required_addons: []
    drupal_modules: ["ai", "ai_agents"]
    drupal_recipes: ["ai_agents_chatbot_evaluation_recipe"]  # Real recipe for PoC!
```

### 2. Enhanced CLI Wizard Integration

**File: `commands/web/drupal-ai`** (modifications)

Add these new functions to the existing script:

#### Function: Install Drupal Modules

```bash
# Function to install Drupal modules for functionalities
# Only installs additional modules that aren't provided by recipes
install_drupal_modules() {
    local functionalities=("$@")

    echo ""
    echo "Step 7: Installing Additional Drupal Modules"

    local all_modules=()

    # Collect all required modules
    for functionality in "${functionalities[@]}"; do
        local modules
        modules=$(yq eval ".functionalities.${functionality}.drupal_modules[]?" "${CONFIGS_DIR}/functionalities.yaml" 2>/dev/null || echo "")

        if [[ -n "$modules" ]]; then
            while IFS= read -r module; do
                if [[ -n "$module" && "$module" != "null" ]]; then
                    all_modules+=("$module")
                fi
            done <<< "$modules"
        fi
    done

    # Remove duplicates and install modules
    if [[ ${#all_modules[@]} -gt 0 ]]; then
        local unique_modules=($(printf "%s\n" "${all_modules[@]}" | sort -u))

        log_step "Installing additional modules: ${unique_modules[*]}"

        # Install modules using ddev drush
        for module in "${unique_modules[@]}"; do
            # Check if module is already installed (possibly by recipe)
            if ! ddev drush pm:list --status=enabled --format=list | grep -q "^${module}$"; then
                if ddev drush composer require "drupal/${module}" --no-interaction; then
                    log_info "Module drupal/${module} installed"
                else
                    log_warning "Failed to install module drupal/${module}"
                fi
            else
                log_info "Module ${module} already installed (likely by recipe)"
            fi
        done

        # Enable any modules that might not be enabled yet
        if ddev drush pm:enable "${unique_modules[@]}" --no-interaction; then
            log_success "All additional modules enabled successfully"
        else
            log_warning "Some modules failed to enable"
        fi
    else
        log_info "No additional modules to install"
    fi
}
```

#### Function: Install Drupal Site

```bash
# Function to install Drupal with standard profile
# This is required before recipes can be applied
install_drupal_site() {
    echo ""
    echo "Step 5: Installing Drupal"

    log_step "Installing Drupal with standard profile"

    # Check if Drupal is already installed
    if ddev drush status bootstrap 2>/dev/null | grep -q "Successful"; then
        log_info "Drupal is already installed, skipping installation"
        return
    fi

    # Install Drupal with standard profile
    if ddev drush site:install standard --account-name=admin --account-pass=admin -y --no-interaction; then
        log_success "Drupal installed successfully with admin/admin credentials"
        log_info "You can access the site at your DDEV URL with admin/admin"
    else
        log_error "Failed to install Drupal - cannot proceed with recipe installation"
        exit 1
    fi
}
```

#### Function: Install Functionality Recipes

```bash
# New function to install recipes for selected functionalities
install_functionality_recipes() {
    local functionalities=("$@")

    echo ""
    echo "Step 6: Installing Drupal Recipes"

    for functionality in "${functionalities[@]}"; do
        local recipes
        recipes=$(yq eval ".functionalities.${functionality}.drupal_recipes[]?" "${CONFIGS_DIR}/functionalities.yaml" 2>/dev/null || echo "")

        if [[ -n "$recipes" ]]; then
            while IFS= read -r recipe; do
                if [[ -n "$recipe" && "$recipe" != "null" ]]; then
                    install_recipe "$recipe" "$functionality"
                fi
            done <<< "$recipes"
        else
            log_info "No recipes defined for ${functionality}"
        fi
    done
}
```

#### Function: Install Single Recipe

```bash
# Function to install a single recipe
install_recipe() {
    local recipe="$1"
    local functionality="$2"

    log_step "Installing recipe: drupal/${recipe}"

    # Use ddev drush to require the recipe via Composer
    if ddev drush composer require "drupal/${recipe}" --no-interaction; then
        log_info "Recipe drupal/${recipe} installed via Composer"

        # Apply the recipe using ddev drush (this applies the default recipe configuration)
        if ddev drush recipe:apply "${recipe}" --no-interaction; then
            log_success "Recipe ${recipe} applied successfully with default configuration"
        else
            log_warning "Failed to apply recipe ${recipe}, continuing with module-only setup"
        fi
    else
        log_warning "Recipe drupal/${recipe} not available, continuing with module-only setup"
    fi
}
```

#### Function: Apply Wizard Configurations

```bash
# Function to apply configurations based on CLI wizard choices
# This runs after recipes and modules are installed and applies the provider/functionality settings chosen in Steps 1-2
apply_wizard_configurations() {
    local provider="$1"
    shift
    local functionalities=("$@")

    echo ""
    echo "Step 8: Applying Wizard-Based Configurations"

    # Apply provider-specific configurations to AI modules using the provider chosen in Step 1
    log_info "Configuring AI modules for provider: ${provider}"

    # Set the default AI provider in the main AI module configuration
    if ddev drush config:set ai.settings default_provider "${provider}" --no-interaction; then
        log_info "Set default AI provider to: ${provider}"
    else
        log_warning "Failed to set default AI provider"
    fi

    # Apply functionality-specific configurations based on wizard choices from Step 2
    for functionality in "${functionalities[@]}"; do
        apply_functionality_wizard_config "$functionality" "$provider"
    done
}

# Function to apply wizard-based configuration for a specific functionality
apply_functionality_wizard_config() {
    local functionality="$1"
    local provider="$2"

    log_info "Configuring ${functionality} for provider ${provider}"

    case "$functionality" in
        "vector-search")
            # Configure search integration with the selected provider
            ddev drush config:set search_api.settings default_tracker "search_api_db" --no-interaction || true
            ;;
        "content-generation")
            # Configure content generation with provider-specific settings
            ddev drush config:set ai_content.settings default_provider "${provider}" --no-interaction || true
            ;;
        "image-analysis")
            # Configure image analysis with the selected provider
            ddev drush config:set ai_vision.settings default_provider "${provider}" --no-interaction || true
            ;;
        "qa-system")
            # Configure Q&A system with search and provider integration
            ddev drush config:set ai_qa.settings default_provider "${provider}" --no-interaction || true
            ddev drush config:set ai_qa.settings search_integration true --no-interaction || true
            ;;
        "code-assistant")
            # Configure code assistant with provider-specific settings
            ddev drush config:set ai_code.settings default_provider "${provider}" --no-interaction || true
            ;;
        "document-processing")
            # Configure document processing with provider and extraction settings
            ddev drush config:set ai_documents.settings default_provider "${provider}" --no-interaction || true
            ddev drush config:set ai_documents.settings extraction_service "unstructured" --no-interaction || true
            ;;
        "ai-agents-chatbot")
            # Configure AI agents chatbot with the selected provider (PoC functionality)
            ddev drush config:set ai_agents.settings default_provider "${provider}" --no-interaction || true
            ddev drush config:set ai_agents.settings chatbot_enabled true --no-interaction || true
            log_info "AI Agents Chatbot configured - access via /admin/config/ai/agents"
            ;;
    esac

    log_info "Configuration applied for ${functionality}"
}
```

#### Modified Setup Workflow

```bash
# Modify the existing setup_workflow function
setup_workflow() {
    echo -e "${PURPLE}🤖 Drupal AI Setup Wizard${NC}"
    echo "=========================="

    # Protect config file from git commits
    protect_config_from_git

    # Step 1: Select provider
    local provider
    provider=$(select_provider)

    # Step 2: Select functionalities
    local functionalities
    readarray -t functionalities < <(select_functionalities "$provider")

    # Step 3: Analyze dependencies
    local required_addons
    readarray -t required_addons < <(analyze_dependencies "$provider" "${functionalities[@]}")

    # Step 4: Install add-ons
    if [[ ${#required_addons[@]} -gt 0 ]]; then
        echo ""
        echo "Step 4: Installation"
        for addon in "${required_addons[@]}"; do
            install_addon "$addon"
        done
    fi

    # Step 5: Install Drupal with standard profile (NEW)
    install_drupal_site

    # Step 6: Install recipes and apply recipe configurations (NEW)
    install_functionality_recipes "${functionalities[@]}"

    # Step 7: Install additional Drupal modules (NEW)
    # Only installs modules that aren't already provided by recipes
    install_drupal_modules "${functionalities[@]}"

    # Step 8: Apply wizard-based configurations (NEW)
    # Use the provider and functionality choices from Steps 1-2 to configure the installed recipes/modules
    apply_wizard_configurations "$provider" "${functionalities[@]}"

    # Save configuration
    save_config "DRUPAL_AI_PROVIDER" "$provider"
    save_config "DRUPAL_AI_FUNCTIONALITIES" "$(IFS=,; echo "${functionalities[*]}")"

    echo ""
    log_success "🎉 Setup Complete!"
    echo ""
    echo "Next steps:"
    echo "- Run \`ddev restart\` to apply changes"
    echo "- Your AI functionalities are now configured with recipes and ready to use"
    echo "- Configure additional settings at /admin/config/ai"
    echo ""
}
```

### 3. Updated Documentation

**File: `README.md`** (additions to existing content)

Add this section after the existing "Quick Start" section:

```markdown
## Recipe-Enhanced Setup

The add-on now supports Drupal recipes for complete AI environment setup. When you run `ddev drupal-ai setup`, the wizard will:

1. Install required DDEV add-ons
2. **Install Drupal with standard profile** (NEW)
3. **Install and apply Drupal recipes** (NEW)
4. Install additional Drupal modules
5. Apply configuration overrides based on your setup

### How Recipes Work

For each selected functionality, the system will:

1. Install Drupal using `ddev drush site:install standard --account-name=admin --account-pass=admin -y`
2. Install the corresponding Drupal recipe via `ddev drush composer require drupal/[recipe-name]`
3. Apply the recipe using `ddev drush recipe:apply [recipe-name]`
4. Override specific configurations based on your provider and setup choices

### Available Recipe Integrations

- **Vector Search**: `drupal/ai-vector-search` - Complete semantic search setup
- **Content Generation**: `drupal/ai-content-generation` - AI content workflows
- **Image Analysis**: `drupal/ai-image-analysis` - Computer vision integration
- **Q&A System**: `drupal/ai-qa-system` - Knowledge base functionality
- **Code Assistant**: `drupal/ai-code-assistant` - Code generation tools
- **Document Processing**: `drupal/ai-document-processing` - File processing workflows
- **AI Agents Chatbot**: `drupal/ai_agents_chatbot_evaluation_recipe` - Interactive AI chatbot with evaluation capabilities (**PoC Ready!**)

### Fallback Behavior

If a recipe is not available, the system gracefully falls back to the module-only installation approach, ensuring your setup always works.

### Configuration Approach

The setup wizard now follows a "one-shot" approach:

1. **Recipe Installation**: Recipes provide complete, working baseline configurations
2. **Provider Integration**: Wizard choices (AI provider, etc.) are applied directly via `ddev drush config:set`
3. **No Configuration Files**: No need to store custom configurations - everything is applied immediately
4. **Standard Drupal Management**: Post-setup changes use Drupal's normal admin interface at `/admin/config/ai`
5. **Fresh Setup**: Re-running the wizard completely reinstalls the environment from scratch
```

## Key Design Principles

- **One-Shot Setup**: The wizard is designed for environment initialization, not ongoing configuration management
- **Simplicity**: Use machine names only, leverage existing `ddev drush` commands
- **Reliability**: Graceful fallback to module-only installation if recipes fail
- **Standard Drupal Workflow**: Post-setup configuration changes use normal Drupal admin interface
- **Integration**: Build on existing CLI wizard patterns and functionality
- **Community**: Use standard Drupal recipe format and distribution methods

## Implementation Benefits

1. **Complete Environment Setup**: Users get fully configured AI environments immediately
2. **Community Standards**: Leverages Drupal's recipe ecosystem and best practices
3. **Reduced Manual Configuration**: Eliminates most post-installation setup steps
4. **Better Defaults**: Uses community-vetted configurations via recipes
5. **Backward Compatibility**: Existing module-based approach still works as fallback
6. **Graceful Degradation**: System works even when recipes aren't available
7. **Clean Architecture**: No configuration file management, pure "one-shot" approach
8. **Standard Drupal Experience**: Subsequent configuration changes use Drupal's built-in tools

## Proof of Concept (PoC) Implementation

### AI Agents Chatbot Recipe - First Test Case

The **AI Agents Chatbot** functionality uses the existing [`ai_agents_chatbot_evaluation_recipe`](https://www.drupal.org/project/ai_agents_chatbot_evaluation_recipe) from Drupal.org as our first real-world test case.

#### Why This Recipe is Perfect for PoC:

1. **Real Recipe**: Published on Drupal.org, not theoretical
2. **AI-Focused**: Specifically designed for AI agent evaluation
3. **Community Project**: Already follows Drupal recipe standards
4. **Complete Functionality**: Provides full chatbot setup with evaluation tools
5. **Test Case**: Perfect for validating our recipe integration approach

#### PoC Implementation Flow:

```bash
# User selects "AI Agents Chatbot" in the wizard
ddev drupal-ai setup
# 7. AI Agents Chatbot
# Your selection: 7

# System executes:
# Step 5: Install Drupal
ddev drush site:install standard --account-name=admin --account-pass=admin -y

# Step 6: Install and apply recipe
ddev drush composer require drupal/ai_agents_chatbot_evaluation_recipe
ddev drush recipe:apply ai_agents_chatbot_evaluation_recipe

# Step 8: Configure with selected AI provider
ddev drush config:set ai_agents.settings default_provider "openai"

# Result: Fully configured AI chatbot with evaluation capabilities
```

#### Expected PoC Outcomes:

- ✅ **Recipe Discovery**: System can find and install the recipe via Composer
- ✅ **Recipe Application**: Recipe applies successfully with default configuration
- ✅ **Functionality Testing**: Chatbot interface is accessible and functional
- ✅ **Provider Integration**: Selected AI provider works with the chatbot
- ✅ **Fallback Testing**: System handles recipe unavailability gracefully

#### PoC Success Criteria:

1. Recipe installs without errors
2. Chatbot interface is accessible in Drupal admin
3. AI provider integration works correctly
4. User can interact with the chatbot immediately after setup
5. Configuration can be further customized through Drupal admin

This PoC will validate our entire recipe integration architecture using a real, production-ready recipe from the Drupal community.

## Files to Modify

### Modified Files:
1. **`drupal-ai/configs/functionalities.yaml`** - Add `drupal_recipes` array (remove config_overrides)
2. **`commands/web/drupal-ai`** - Add recipe installation and wizard-based configuration functions
3. **`README.md`** - Document recipe integration features

### Implementation Steps:
1. Update `functionalities.yaml` with recipe definitions only
2. Add new functions to `commands/web/drupal-ai` for recipe management and wizard-based configuration
3. **Add Drupal installation step** - Install Drupal with standard profile before recipes
4. Integrate recipe installation into existing setup workflow
5. Apply provider and functionality configurations directly during setup
6. Update documentation to explain recipe functionality and one-shot setup approach
7. **Implement PoC with AI Agents Chatbot recipe** - Test with real Drupal.org recipe
8. Test with available recipes and ensure fallback behavior works

## Testing Scenarios

### Standard Testing
1. **Recipe Available**: Recipe installs successfully, configuration overrides applied
2. **Recipe Unavailable**: System falls back to module-only installation gracefully
3. **Recipe Install Fails**: System continues with module installation and logs warning
4. **Configuration Override Fails**: System logs warning but continues setup
5. **Mixed Success**: Some recipes work, others fall back - system handles gracefully

### PoC Testing (AI Agents Chatbot)
6. **Real Recipe Installation**: `drupal/ai_agents_chatbot_evaluation_recipe` installs via Composer
7. **Recipe Application**: Recipe applies successfully using `drush recipe:apply`
8. **Functionality Verification**: Chatbot interface is accessible and functional
9. **Provider Integration**: Selected AI provider integrates correctly with chatbot
10. **End-to-End Testing**: User can interact with chatbot immediately after setup

This implementation provides immediate value by leveraging Drupal's recipe ecosystem while maintaining the robust, user-friendly experience of the existing CLI wizard. The AI Agents Chatbot PoC validates the entire approach using a real, production-ready recipe.
