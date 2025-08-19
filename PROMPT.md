# DDEV Drupal A- ├── commands/web/drupal-ai (CLI implementation)
 ├── drupal-ai/ (namespaced add-on files)
 │   ├── configs/ (YAML configurations)
 │   ├── scripts/ (helper scripts)
 │   └── templates/ (configuration templates)
 ├── tests/test.bats-on Implementation

## Project Overview
- **Repository**: Drupal-AI/ddev-drupal-ai (main branch)
- **Current State**: Basic project structure with CLI implementation
- **Goal**: Create interactive CLI orchestration tool for Drupal AI workflows
- **Reference Issue**: https://www.drupal.org/project/ai/issues/3532795#comment-16218979
- **Inspiration**: Based on ddev-drupal-suite approach https://github.com/lussoluca/ddev-drupal-suite

## Current Project Structure

```
ddev-drupal-ai/
 ├── install.yaml (minimal DDEV v1.24.3+ constraint)
 ├── README.md (describes the vision)
 ├── commands/web/drupal-ai (CLI implementation)
 ├── configs/ (YAML configurations)
 ├── scripts/ (helper scripts)
 ├── templates/ (configuration templates)
 ├── tests/test.bats
 └── LICENSE
```

## Architecture Requirements
- **Glue Add-on Pattern**: Meta-tool that orchestrates other add-ons
- **YAML-driven Configuration**: Steps and recipes defined in YAML, not hardcoded in Bash
- **Dependency Management**: Automatically install required add-ons (pgvector, unstructured)
- **Interactive Workflows**: Guided user experience with provider → functionality → setup flow

## Required CLI Commands

### Primary Commands
1. `ddev drupal-ai setup`
   - Interactive wizard for complete AI stack setup
   - Provider selection (OpenAI, Anthropic, Ollama, Google Gemini, etc.)
   - Functionality selection (search, embeddings, Q&A, content generation)
   - Automatic dependency resolution and installation

2. `ddev drupal-ai list`
   - Display available providers and their capabilities
   - Show installed vs available add-ons
   - List configured recipes

### Workflow Example
```bash
$ ddev drupal-ai setup

🤖 Drupal AI Setup Wizard
========================

Step 1: Select AI Provider
? Choose your AI provider:
  ❯ OpenAI (GPT-4, GPT-3.5, Embeddings)
    Anthropic (Claude 3.5, Claude 3)
    Ollama (Local LLM - llama3, mistral, etc.)
    Google Gemini (gemini-pro, gemini-vision)

Step 2: Select Functionality
? What AI features do you need: (multiple selection)
  ❯ ✓ Vector Search & Embeddings
    ✓ Content Generation
    ○ Image Analysis
    ○ Q&A System
    ○ Code Assistant

Step 3: Dependencies Analysis
📦 Required add-ons for your selection:
  - pgvector (for vector search) → Will install
  - unstructured (for document processing) → Will install

? Proceed with installation? (Y/n)

Step 4: Installation
✅ Installing pgvector add-on...
✅ Installing unstructured add-on...
✅ Configuring OpenAI services...
✅ Setting up vector database...

Step 5: Configuration
? OpenAI API Key: [secure input]
? Default model (gpt-4):
? Enable vector search (Y/n): Y

🎉 Setup Complete!

Next steps:
- Run `ddev restart` to apply changes
- Install Drupal AI modules: `ddev composer require drupal/ai`
- Configure at /admin/config/ai
```

# Technical Architecture

## File Structure to Create

```
.ddev/
 ├── commands/
 │   └── web/
 │       └── drupal-ai # Main CLI script
 ├── drupal-ai/
 │   ├── configs/
 │   │   ├── providers.yaml # AI provider definitions
 │   │   ├── functionalities.yaml # Available AI features
 │   │   ├── dependencies.yaml # Add-on dependency mapping
 │   │   └── workflows/
 │   │       ├── openai-embeddings.yaml
 │   │       ├── ollama-local.yaml
 │   │       └── anthropic-content.yaml
 │   ├── scripts/
 │   │   ├── install-addon.sh # Add-on installation logic
 │   │   ├── configure-provider.sh # Provider-specific setup
 │   │   └── validate-config.sh # Configuration validation
 │   └── templates/
 │       ├── docker-compose.pgvector.yaml
 │       ├── docker-compose.ollama.yaml
 │       └── .env.drupal-ai.template
```

## Core Script Requirements (.ddev/commands/web/drupal-ai)
- **Language**: Bash (compatible with macOS zsh, Linux bash)
- **YAML Parsing**: Use `yq` or similar for reading recipe files
- **Interactive UI**: Use `select` menus, `read` with validation
- **Error Handling**: Comprehensive validation and rollback capability
- **Logging**: Debug mode with verbose output
- **Security**: Secure API key handling (no plaintext storage)

### YAML Configuration Structure

#### providers.yaml
```yaml
providers:
  openai:
    name: "OpenAI"
    description: "GPT-4, GPT-3.5, DALL-E, Embeddings"
    required_vars:
      - OPENAI_API_KEY
    optional_vars:
      - OPENAI_MODEL: "gpt-4"
      - OPENAI_BASE_URL: "https://api.openai.com/v1"
    capabilities: ["text-generation", "embeddings", "image-generation"]

  ollama:
    name: "Ollama (Local)"
    description: "Self-hosted LLMs (Llama, Mistral, etc.)"
    required_vars: []
    optional_vars:
      - OLLAMA_MODEL: "llama3"
      - OLLAMA_HOST: "http://ollama:11434"
    capabilities: ["text-generation", "embeddings"]
    dependencies: ["ollama-service"]
```

#### functionalities.yaml
```yaml
functionalities:
  vector-search:
    name: "Vector Search & Embeddings"
    description: "Semantic search using vector databases"
    required_addons: ["pgvector"]
    required_capabilities: ["embeddings"]
    drupal_modules: ["ai", "ai_search", "search_api"]

  content-generation:
    name: "Content Generation"
    description: "AI-powered content creation"
    required_addons: []
    required_capabilities: ["text-generation"]
    drupal_modules: ["ai", "ai_content"]
```

#### dependencies.yaml
```yaml
workflows:
  openai-embeddings:
    name: "OpenAI + Vector Search"
    provider: "openai"
    functionalities: ["vector-search", "content-generation"]
    required_addons: ["robertoperuzzo/ddev-pgvector"]
    docker_services: ["postgres-vector", "redis"]
```

### Integration Points

- Environment Management: Use .ddev/.env.drupal-ai for configuration persistence
- DDEV Integration: Leverage ddev add-on get for add-on installation
- Validation: Check DDEV version, Docker availability, network connectivity


## User Experience & Error Handling

### Interactive Flow Principles
- **Progressive Disclosure**: Show only relevant options based on previous choices
- **Smart Defaults**: Pre-select most common configurations
- **Validation**: Real-time validation of inputs (API keys, URLs, etc.)
- **Preview**: Show what will be installed/configured before execution
- **Resumability**: Allow users to modify configuration without full reinstall

### Error Handling Scenarios
1. **Missing Dependencies**: DDEV not running, Docker unavailable
2. **Network Issues**: Cannot reach AI provider APIs, GitHub unavailable
3. **Invalid Credentials**: Bad API keys, authentication failures
4. **Conflicting Add-ons**: Existing services using same ports
5. **Insufficient Resources**: Docker memory/disk space limits
6. **Partial Failures**: Some add-ons install, others fail

### Error Recovery
- **Rollback Mechanism**: Undo changes on failure
- **State Tracking**: Know what was successfully installed
- **Repair Mode**: Fix broken configurations
- **Force Mode**: Override conflicts when safe

### Success Indicators
- Configuration files created in correct locations
- Services start successfully with `ddev restart`
- API connectivity tests pass
- Drupal modules can connect to AI services


## Testing Strategy

### Required Test Coverage
1. **Unit Tests** (BATS framework - matching existing tests/test.bats)
   - YAML parsing functions
   - Validation logic
   - Configuration generation
   - Error handling paths

2. **Integration Tests**
   - Full workflow simulation
   - Add-on installation process
   - Service connectivity
   - Multi-provider scenarios

3. **Cross-platform Tests**
   - macOS (zsh), Linux (bash), Windows (WSL)
   - Different DDEV versions
   - Various Docker configurations

### Test Structure Example
```bash
#!/usr/bin/env bats

@test "drupal-ai setup with OpenAI provider" {
  # Mock user input for OpenAI selection
  # Verify correct add-ons are identified
  # Check configuration files are created
  # Validate services can start
}

@test "invalid API key handling" {
  # Test graceful failure with invalid credentials
  # Verify rollback occurs
  # Check user-friendly error message
}
```

### Performance Requirements

- Setup completion in under 3 minutes (excluding large Docker pulls)
- Minimal resource overhead when not actively used
- Efficient YAML parsing (cache parsed configs)
- Parallel add-on installation where possible


## Documentation & Maintenance

### Documentation Requirements

#### Update README.md with:
- Complete command reference
- Recipe development guide
- Troubleshooting section
- Provider-specific setup instructions
- Contributing guidelines for new recipes

#### Inline Documentation
- Comprehensive comments in shell scripts
- YAML schema documentation
- API integration examples
- Custom recipe creation guide

#### Maintenance Considerations
- Version compatibility matrix
- Recipe update mechanism
- Provider API changes handling
- Automated testing in CI/CD

## Definition of Done

### Functional Requirements
- [ ] `ddev drupal-ai setup` completes full workflow in under 5 minutes
- [ ] Supports minimum 3 AI providers (OpenAI, Ollama, Anthropic)
- [ ] Automatically installs pgvector and unstructured add-ons as needed
- [ ] Configuration persists across `ddev restart`
- [ ] All commands work on macOS, Linux, Windows (WSL)

### Technical Requirements
- [ ] YAML-driven configuration (no hardcoded workflows)
- [ ] Comprehensive error handling with user-friendly messages
- [ ] Secure credential management (no plaintext API keys)
- [ ] Follows DDEV add-on best practices
- [ ] Test coverage >80% with BATS framework

### User Experience
- [ ] Clear progress indicators during installation
- [ ] Helpful error messages with suggested fixes
- [ ] Ability to modify configuration without complete reinstall
- [ ] Documentation covers common use cases and troubleshooting

### Integration
- [ ] Works with existing Drupal projects
- [ ] Compatible with other DDEV add-ons
- [ ] Drupal AI modules can connect successfully
- [ ] Services accessible from Drupal application