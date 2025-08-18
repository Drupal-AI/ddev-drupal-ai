#!/usr/bin/env bash

## #ddev-generated
# Configure provider script
# Usage: configure-provider.sh <provider_name>

set -euo pipefail

# Configuration
set -euo pipefail

# Directory paths
CONFIGS_DIR="${DDEV_APPROOT}/.ddev/configs"
CONFIG_FILE="${DDEV_APPROOT}/.ddev/.env.drupal-ai"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}ℹ ${1}${NC}"
}

log_success() {
    echo -e "${GREEN}✅ ${1}${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠ ${1}${NC}"
}

log_error() {
    echo -e "${RED}❌ ${1}${NC}"
}

# Save configuration variable
save_config() {
    local key="$1"
    local value="$2"

    # Create config file if it doesn't exist
    touch "$CONFIG_FILE"

    # Update existing key or add new one
    if grep -q "^${key}=" "$CONFIG_FILE"; then
        # Update existing
        if [[ "$OSTYPE" == "darwin"* ]]; then
            # macOS
            sed -i '' "s/^${key}=.*/${key}=${value}/" "$CONFIG_FILE"
        else
            # Linux
            sed -i "s/^${key}=.*/${key}=${value}/" "$CONFIG_FILE"
        fi
    else
        # Add new
        echo "${key}=${value}" >> "$CONFIG_FILE"
    fi
}

# Get configuration variable
get_config() {
    local key="$1"
    local default="${2:-}"

    if [[ -f "$CONFIG_FILE" ]]; then
        grep "^${key}=" "$CONFIG_FILE" | cut -d'=' -f2- || echo "$default"
    else
        echo "$default"
    fi
}

# Validate API key format
validate_api_key() {
    local provider="$1"
    local api_key="$2"

    case "$provider" in
        "openai")
            # OpenAI keys start with sk-
            if [[ "$api_key" =~ ^sk-[A-Za-z0-9]{32,}$ ]]; then
                return 0
            else
                log_warning "OpenAI API key should start with 'sk-' and be at least 35 characters long"
                return 1
            fi
            ;;
        "anthropic")
            # Anthropic keys start with sk-ant-
            if [[ "$api_key" =~ ^sk-ant-[A-Za-z0-9_-]{95,}$ ]]; then
                return 0
            else
                log_warning "Anthropic API key should start with 'sk-ant-' and be around 100 characters long"
                return 1
            fi
            ;;
        "google_gemini")
            # Google API keys start with AIza
            if [[ "$api_key" =~ ^AIza[A-Za-z0-9_-]{35}$ ]]; then
                return 0
            else
                log_warning "Google API key should start with 'AIza' and be 39 characters long"
                return 1
            fi
            ;;
        *)
            # Generic validation - just check it's not empty
            [[ -n "$api_key" ]]
            ;;
    esac
}

# Test API connection
test_api_connection() {
    local provider="$1"

    log_info "Testing API connection for $provider..."

    case "$provider" in
        "openai")
            local api_key=$(get_config "OPENAI_API_KEY")
            local base_url=$(get_config "OPENAI_BASE_URL" "https://api.openai.com/v1")

            if curl -s -f -H "Authorization: Bearer $api_key" \
                   -H "Content-Type: application/json" \
                   "$base_url/models" >/dev/null 2>&1; then
                log_success "OpenAI API connection successful"
                return 0
            else
                log_error "OpenAI API connection failed"
                return 1
            fi
            ;;
        "anthropic")
            local api_key=$(get_config "ANTHROPIC_API_KEY")
            local base_url=$(get_config "ANTHROPIC_BASE_URL" "https://api.anthropic.com")

            if curl -s -f -H "x-api-key: $api_key" \
                   -H "Content-Type: application/json" \
                   -H "anthropic-version: 2023-06-01" \
                   "$base_url/v1/messages" \
                   -d '{"model": "claude-3-haiku-20240307", "max_tokens": 1, "messages": [{"role": "user", "content": "test"}]}' >/dev/null 2>&1; then
                log_success "Anthropic API connection successful"
                return 0
            else
                log_error "Anthropic API connection failed"
                return 1
            fi
            ;;
        "ollama")
            local host=$(get_config "OLLAMA_HOST" "http://ollama:11434")

            if curl -s -f "$host/api/tags" >/dev/null 2>&1; then
                log_success "Ollama connection successful"
                return 0
            else
                log_error "Ollama connection failed - ensure Ollama service is running"
                return 1
            fi
            ;;
        *)
            log_warning "API test not implemented for provider: $provider"
            return 0
            ;;
    esac
}

# Configure specific provider
configure_provider() {
    local provider="$1"

    if [[ ! -f "${CONFIGS_DIR}/providers.yaml" ]]; then
        log_error "Providers configuration not found"
        return 1
    fi

    # Check if provider exists
    if ! yq eval ".providers.${provider}" "${CONFIGS_DIR}/providers.yaml" >/dev/null 2>&1; then
        log_error "Unknown provider: $provider"
        return 1
    fi

    local provider_name
    provider_name=$(yq eval ".providers.${provider}.name" "${CONFIGS_DIR}/providers.yaml")

    log_info "Configuring ${provider_name}"

    # Configure required variables
    local required_vars
    required_vars=$(yq eval ".providers.${provider}.required_vars[]?" "${CONFIGS_DIR}/providers.yaml" 2>/dev/null || echo "")

    if [[ -n "$required_vars" ]]; then
        log_info "Required configuration:"
        while IFS= read -r var; do
            [[ -z "$var" ]] && continue

            local current_value
            current_value=$(get_config "$var")

            if [[ -n "$current_value" ]]; then
                echo -n "? ${var} (current: ${current_value:0:10}...): "
            else
                echo -n "? ${var}: "
            fi

            if [[ "$var" == *"KEY"* ]] || [[ "$var" == *"TOKEN"* ]]; then
                # Secure input for API keys
                read -rs value
                echo ""
            else
                read -r value
            fi

            # Use current value if nothing entered
            if [[ -z "$value" && -n "$current_value" ]]; then
                value="$current_value"
            fi

            # Validate API key format
            if [[ "$var" == *"KEY"* ]] && ! validate_api_key "$provider" "$value"; then
                log_warning "API key format validation failed, but continuing..."
            fi

            save_config "$var" "$value"
        done <<< "$required_vars"
    fi

    # Configure optional variables
    local optional_vars
    optional_vars=$(yq eval ".providers.${provider}.optional_vars | to_entries | .[] | \"\(.key):\(.value)\"" "${CONFIGS_DIR}/providers.yaml" 2>/dev/null || echo "")

    if [[ -n "$optional_vars" ]]; then
        log_info "Optional configuration (press Enter to use default):"
        while IFS=: read -r var default_value; do
            [[ -z "$var" ]] && continue

            local current_value
            current_value=$(get_config "$var" "$default_value")

            echo -n "? ${var} (${current_value}): "
            read -r value

            # Use current/default if nothing entered
            if [[ -z "$value" ]]; then
                value="$current_value"
            fi

            save_config "$var" "$value"
        done <<< "$optional_vars"
    fi

    # Test connection if possible
    if [[ "$provider" != "ollama" ]] || ddev exec -s ollama 'true' >/dev/null 2>&1; then
        test_api_connection "$provider"
    fi

    log_success "Provider $provider configured successfully"
}

# List current configuration
list_configuration() {
    log_info "Current configuration:"

    if [[ -f "$CONFIG_FILE" ]]; then
        while IFS= read -r line; do
            if [[ "$line" == *"="* ]]; then
                local key="${line%%=*}"
                local value="${line#*=}"

                # Mask sensitive values
                if [[ "$key" == *"KEY"* ]] || [[ "$key" == *"TOKEN"* ]]; then
                    value="${value:0:10}..."
                fi

                echo "  $key = $value"
            fi
        done < "$CONFIG_FILE"
    else
        log_warning "No configuration found"
    fi
}

# Reset configuration
reset_configuration() {
    if [[ -f "$CONFIG_FILE" ]]; then
        log_warning "Resetting all configuration..."
        echo -n "Are you sure? (y/N): "
        read -r confirm

        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            rm -f "$CONFIG_FILE"
            log_success "Configuration reset"
        else
            log_info "Reset cancelled"
        fi
    else
        log_info "No configuration to reset"
    fi
}

# Main function
main() {
    local action="${1:-configure}"
    local provider="${2:-}"

    case "$action" in
        "configure")
            if [[ -z "$provider" ]]; then
                log_error "Usage: $0 configure <provider_name>"
                exit 1
            fi
            configure_provider "$provider"
            ;;
        "test")
            if [[ -z "$provider" ]]; then
                log_error "Usage: $0 test <provider_name>"
                exit 1
            fi
            test_api_connection "$provider"
            ;;
        "list")
            list_configuration
            ;;
        "reset")
            reset_configuration
            ;;
        *)
            log_error "Unknown action: $action"
            log_error "Valid actions: configure, test, list, reset"
            exit 1
            ;;
    esac
}

# Check if script is being sourced or executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
