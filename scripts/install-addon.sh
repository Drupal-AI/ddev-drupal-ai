#!/usr/bin/env bash

## #ddev-generated
# Install add-on script
# Usage: install-addon.sh <addon_name>

set -euo pipefail

# Configuration
set -euo pipefail

# Directory paths
CONFIGS_DIR="${DDEV_APPROOT}/.ddev/configs"

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

# Install specific add-on
install_addon() {
    local addon="$1"

    if [[ -z "$addon" ]]; then
        log_error "Add-on name is required"
        return 1
    fi

    log_info "Installing add-on: $addon"

    # Check if add-on is already installed (check by identifier pattern)
    if check_addon_installed "$addon"; then
        log_warning "Add-on $addon is already installed"
        return 0
    fi

    # Install using ddev add-on get (addon parameter is now the full identifier)
    if ddev add-on get "$addon"; then
        log_success "Successfully installed $addon"

        # Run post-install configuration if needed
        configure_addon "$addon"

        return 0
    else
        log_error "Failed to install $addon"
        return 1
    fi
}

# Check if add-on is already installed
check_addon_installed() {
    local addon="$1"

    case "$addon" in
        "pgvector")
            # Check for robertoperuzzo/ddev-pgvector add-on
            [[ -f "${DDEV_APPROOT}/.ddev/docker-compose.pgvector.yaml" ]]
            ;;
        "unstructured")
            [[ -f "${DDEV_APPROOT}/.ddev/docker-compose.unstructured.yaml" ]]
            ;;
        "ollama-service")
            # Check for stinis87/ddev-ollama add-on
            [[ -f "${DDEV_APPROOT}/.ddev/docker-compose.ollama.yaml" ]]
            ;;
        "redis")
            [[ -f "${DDEV_APPROOT}/.ddev/docker-compose.redis.yaml" ]]
            ;;
        *)
            # Generic check for docker-compose files
            [[ -f "${DDEV_APPROOT}/.ddev/docker-compose.${addon}.yaml" ]]
            ;;
    esac
}

# Configure add-on after installation
configure_addon() {
    local addon="$1"

    case "$addon" in
        "pgvector")
            log_info "Configuring PostgreSQL with pgvector extension..."
            # Add any specific pgvector configuration here
            ;;
        "unstructured")
            log_info "Configuring Unstructured service..."
            # Add any specific unstructured configuration here
            ;;
        "ollama-service")
            log_info "Configuring Ollama service..."
            log_warning "Note: Ollama requires significant resources. Ensure sufficient Docker memory allocation."
            ;;
        "redis")
            log_info "Configuring Redis cache..."
            # Add any specific Redis configuration here
            ;;
    esac
}

# Validate add-on installation
validate_installation() {
    local addon="$1"

    log_info "Validating installation of $addon..."

    # Check if services start properly
    if ddev restart; then
        log_success "Services restarted successfully"

        # Additional validation based on add-on type
        case "$addon" in
            "pgvector")
                if ddev exec -s db 'psql -c "SELECT 1;"' >/dev/null 2>&1; then
                    log_success "PostgreSQL connection validated"
                else
                    log_warning "PostgreSQL connection test failed"
                fi
                ;;
            "redis")
                if ddev exec -s redis 'redis-cli ping' >/dev/null 2>&1; then
                    log_success "Redis connection validated"
                else
                    log_warning "Redis connection test failed"
                fi
                ;;
            "ollama-service")
                if ddev exec -s ollama 'curl -f http://localhost:11434/api/tags' >/dev/null 2>&1; then
                    log_success "Ollama service validated"
                else
                    log_warning "Ollama service test failed"
                fi
                ;;
        esac
    else
        log_error "Failed to restart services after installing $addon"
        return 1
    fi
}

# Remove add-on
remove_addon() {
    local addon="$1"

    if [[ -z "$addon" ]]; then
        log_error "Add-on name is required"
        return 1
    fi

    log_warning "Removing add-on: $addon"

    # Find and remove docker-compose files
    local compose_files=()
    case "$addon" in
        "pgvector")
            compose_files+=("${DDEV_APPROOT}/.ddev/docker-compose.pgvector.yaml")
            ;;
        "unstructured")
            compose_files+=("${DDEV_APPROOT}/.ddev/docker-compose.unstructured.yaml")
            ;;
        "ollama-service")
            compose_files+=("${DDEV_APPROOT}/.ddev/docker-compose.ollama.yaml")
            ;;
        "redis")
            compose_files+=("${DDEV_APPROOT}/.ddev/docker-compose.redis.yaml")
            ;;
        *)
            compose_files+=("${DDEV_APPROOT}/.ddev/docker-compose.${addon}.yaml")
            ;;
    esac

    local removed_files=0
    for file in "${compose_files[@]}"; do
        if [[ -f "$file" ]]; then
            rm -f "$file"
            log_success "Removed: $(basename "$file")"
            ((removed_files++))
        fi
    done

    if [[ $removed_files -gt 0 ]]; then
        log_success "Add-on $addon removed successfully"
        log_info "Run 'ddev restart' to apply changes"
    else
        log_warning "No files found for add-on: $addon"
    fi
}

# Main function
main() {
    local action="${1:-install}"
    local addon="${2:-}"

    if [[ -z "$addon" ]]; then
        log_error "Usage: $0 [install|remove|validate] <addon_name>"
        exit 1
    fi

    case "$action" in
        "install")
            install_addon "$addon"
            validate_installation "$addon"
            ;;
        "remove")
            remove_addon "$addon"
            ;;
        "validate")
            validate_installation "$addon"
            ;;
        *)
            log_error "Unknown action: $action"
            log_error "Valid actions: install, remove, validate"
            exit 1
            ;;
    esac
}

# Check if script is being sourced or executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
