#!/usr/bin/env bash

## #ddev-generated
# Validate configuration script
# Usage: validate-config.sh

set -euo pipefail

# Configuration
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

# Load configuration
load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        # shellcheck disable=SC1090
        source "$CONFIG_FILE"
    fi
}

# Get configuration variable
get_config() {
    local key="$1"
    local default="${2:-}"

    if [[ -f "$CONFIG_FILE" ]]; then
        grep "^${key}=" "$CONFIG_FILE" | cut -d'=' -f2- 2>/dev/null || echo "$default"
    else
        echo "$default"
    fi
}

# Validate DDEV environment
validate_ddev() {
    log_info "Validating DDEV environment..."

    # Check if DDEV is running
    if ! ddev status >/dev/null 2>&1; then
        log_error "DDEV project is not running. Run 'ddev start' first."
        return 1
    fi

    # Check DDEV version
    local ddev_version
    ddev_version=$(ddev version | grep -o 'v[0-9]\+\.[0-9]\+\.[0-9]\+' | head -n1)
    local required_version="v1.24.3"

    if [[ $(printf '%s\n' "$required_version" "$ddev_version" | sort -V | head -n1) != "$required_version" ]]; then
        log_error "DDEV version $ddev_version is too old. Requires $required_version or newer."
        return 1
    fi

    log_success "DDEV environment is valid"
    return 0
}

# Validate Docker environment
validate_docker() {
    log_info "Validating Docker environment..."

    # Check if Docker is running
    if ! docker info >/dev/null 2>&1; then
        log_error "Docker is not running or accessible"
        return 1
    fi

    # Check available resources
    local memory_gb
    memory_gb=$(docker info --format '{{.MemTotal}}' | awk '{print int($1/1024/1024/1024)}')

    if [[ "$memory_gb" -lt 4 ]]; then
        log_warning "Docker has only ${memory_gb}GB memory. AI workloads may require more resources."
    else
        log_success "Docker memory: ${memory_gb}GB"
    fi

    # Check disk space
    local disk_space
    disk_space=$(df -h "$(docker info --format '{{.DockerRootDir}}')" | awk 'NR==2 {print $4}' | sed 's/G//')

    if [[ "${disk_space%%.*}" -lt 10 ]]; then
        log_warning "Low disk space: ${disk_space}G available"
    else
        log_success "Docker disk space: ${disk_space}G available"
    fi

    return 0
}

# Validate configuration files
validate_config_files() {
    log_info "Validating configuration files..."

    local errors=0

    # Check providers.yaml
    if [[ -f "${CONFIGS_DIR}/providers.yaml" ]]; then
        if yq eval '.' "${CONFIGS_DIR}/providers.yaml" >/dev/null 2>&1; then
            log_success "providers.yaml is valid"
        else
            log_error "providers.yaml has invalid YAML syntax"
            ((errors++))
        fi
    else
        log_error "providers.yaml not found"
        ((errors++))
    fi

    # Check functionalities.yaml
    if [[ -f "${CONFIGS_DIR}/functionalities.yaml" ]]; then
        if yq eval '.' "${CONFIGS_DIR}/functionalities.yaml" >/dev/null 2>&1; then
            log_success "functionalities.yaml is valid"
        else
            log_error "functionalities.yaml has invalid YAML syntax"
            ((errors++))
        fi
    else
        log_error "functionalities.yaml not found"
        ((errors++))
    fi

    # Check dependencies.yaml
    if [[ -f "${CONFIGS_DIR}/dependencies.yaml" ]]; then
        if yq eval '.' "${CONFIGS_DIR}/dependencies.yaml" >/dev/null 2>&1; then
            log_success "dependencies.yaml is valid"
        else
            log_error "dependencies.yaml has invalid YAML syntax"
            ((errors++))
        fi
    else
        log_error "dependencies.yaml not found"
        ((errors++))
    fi

    return $errors
}

# Validate provider configuration
validate_provider_config() {
    log_info "Validating provider configuration..."

    load_config

    local provider
    provider=$(get_config "DRUPAL_AI_PROVIDER")

    if [[ -z "$provider" ]]; then
        log_warning "No provider configured yet"
        return 0
    fi

    log_info "Checking provider: $provider"

    # Check if provider exists in configuration
    if ! yq eval ".providers.${provider}" "${CONFIGS_DIR}/providers.yaml" >/dev/null 2>&1; then
        log_error "Provider $provider not found in configuration"
        return 1
    fi

    # Validate required variables
    local required_vars
    required_vars=$(yq eval ".providers.${provider}.required_vars[]?" "${CONFIGS_DIR}/providers.yaml" 2>/dev/null || echo "")

    local missing_vars=0
    if [[ -n "$required_vars" ]]; then
        while IFS= read -r var; do
            [[ -z "$var" ]] && continue

            local value
            value=$(get_config "$var")

            if [[ -z "$value" ]]; then
                log_error "Missing required variable: $var"
                ((missing_vars++))
            else
                log_success "Required variable set: $var"
            fi
        done <<< "$required_vars"
    fi

    if [[ $missing_vars -eq 0 ]]; then
        log_success "Provider configuration is complete"
        return 0
    else
        log_error "Provider configuration is incomplete ($missing_vars missing variables)"
        return 1
    fi
}

# Validate installed add-ons
validate_addons() {
    log_info "Validating installed add-ons..."

    local functionalities
    functionalities=$(get_config "DRUPAL_AI_FUNCTIONALITIES")

    if [[ -z "$functionalities" ]]; then
        log_warning "No functionalities configured yet"
        return 0
    fi

    # Convert comma-separated list to array
    IFS=',' read -ra FUNC_ARRAY <<< "$functionalities"

    local missing_addons=()

    for functionality in "${FUNC_ARRAY[@]}"; do
        local required_addons
        required_addons=$(yq eval ".functionalities.${functionality}.required_addons[]?" "${CONFIGS_DIR}/functionalities.yaml" 2>/dev/null || echo "")

        if [[ -n "$required_addons" ]]; then
            while IFS= read -r addon; do
                [[ -z "$addon" ]] && continue

                if ! check_addon_installed "$addon"; then
                    missing_addons+=("$addon")
                    log_error "Required add-on not installed: $addon (needed for $functionality)"
                else
                    log_success "Add-on installed: $addon"
                fi
            done <<< "$required_addons"
        fi
    done

    if [[ ${#missing_addons[@]} -eq 0 ]]; then
        log_success "All required add-ons are installed"
        return 0
    else
        log_error "${#missing_addons[@]} required add-ons are missing"
        return 1
    fi
}

# Check if add-on is installed
check_addon_installed() {
    local addon="$1"

    case "$addon" in
        "pgvector")
            [[ -f "${DDEV_APPROOT}/.ddev/docker-compose.pgvector.yaml" ]]
            ;;
        "unstructured")
            [[ -f "${DDEV_APPROOT}/.ddev/docker-compose.unstructured.yaml" ]]
            ;;
        "ollama-service")
            [[ -f "${DDEV_APPROOT}/.ddev/docker-compose.ollama.yaml" ]]
            ;;
        "redis")
            [[ -f "${DDEV_APPROOT}/.ddev/docker-compose.redis.yaml" ]]
            ;;
        *)
            [[ -f "${DDEV_APPROOT}/.ddev/docker-compose.${addon}.yaml" ]]
            ;;
    esac
}

# Validate service connectivity
validate_services() {
    log_info "Validating service connectivity..."

    local errors=0

    # Check web service
    if ddev exec 'curl -f http://localhost >/dev/null 2>&1'; then
        log_success "Web service is accessible"
    else
        log_error "Web service is not accessible"
        ((errors++))
    fi

    # Check database
    if ddev exec 'mysql -e "SELECT 1;" >/dev/null 2>&1'; then
        log_success "Database service is accessible"
    else
        log_error "Database service is not accessible"
        ((errors++))
    fi

    # Check additional services based on configuration
    if [[ -f "${DDEV_APPROOT}/.ddev/docker-compose.pgvector.yaml" ]]; then
        if ddev exec -s pgvector 'pg_isready >/dev/null 2>&1'; then
            log_success "PostgreSQL/pgvector service is accessible"
        else
            log_warning "PostgreSQL/pgvector service is not accessible"
        fi
    fi

    if [[ -f "${DDEV_APPROOT}/.ddev/docker-compose.redis.yaml" ]]; then
        if ddev exec -s redis 'redis-cli ping >/dev/null 2>&1'; then
            log_success "Redis service is accessible"
        else
            log_warning "Redis service is not accessible"
        fi
    fi

    if [[ -f "${DDEV_APPROOT}/.ddev/docker-compose.ollama.yaml" ]]; then
        if ddev exec -s ollama 'curl -f http://localhost:11434/api/tags >/dev/null 2>&1'; then
            log_success "Ollama service is accessible"
        else
            log_warning "Ollama service is not accessible"
        fi
    fi

    return $errors
}

# Generate health report
health_report() {
    log_info "Generating Drupal AI health report..."
    echo ""

    local total_checks=0
    local passed_checks=0

    # DDEV validation
    ((total_checks++))
    if validate_ddev; then
        ((passed_checks++))
    fi

    # Docker validation
    ((total_checks++))
    if validate_docker; then
        ((passed_checks++))
    fi

    # Config files validation
    ((total_checks++))
    if validate_config_files; then
        ((passed_checks++))
    fi

    # Provider config validation
    ((total_checks++))
    if validate_provider_config; then
        ((passed_checks++))
    fi

    # Add-ons validation
    ((total_checks++))
    if validate_addons; then
        ((passed_checks++))
    fi

    # Services validation
    ((total_checks++))
    if validate_services; then
        ((passed_checks++))
    fi

    echo ""
    log_info "Health Report Summary:"
    echo "  Passed: $passed_checks/$total_checks checks"

    if [[ $passed_checks -eq $total_checks ]]; then
        log_success "🎉 All systems operational!"
    else
        local failed=$((total_checks - passed_checks))
        log_warning "⚠ $failed checks failed. See details above."
    fi

    return $((total_checks - passed_checks))
}

# Main function
main() {
    local action="${1:-health}"

    case "$action" in
        "health"|"report")
            health_report
            ;;
        "ddev")
            validate_ddev
            ;;
        "docker")
            validate_docker
            ;;
        "config")
            validate_config_files
            ;;
        "provider")
            validate_provider_config
            ;;
        "addons")
            validate_addons
            ;;
        "services")
            validate_services
            ;;
        *)
            log_error "Unknown validation type: $action"
            log_error "Valid types: health, ddev, docker, config, provider, addons, services"
            exit 1
            ;;
    esac
}

# Check if script is being sourced or executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
