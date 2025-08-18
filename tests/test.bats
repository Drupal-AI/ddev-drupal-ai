#!/usr/bin/env bats

# Bats is a testing framework for Bash
# Documentation https://bats-core.readthedocs.io/en/stable/
# Bats libraries documentation https://github.com/ztombol/bats-docs

# For local tests, install bats-core, bats-assert, bats-file, bats-support
# And run this in the add-on root directory:
#   bats ./tests/test.bats
# To exclude release tests:
#   bats ./tests/test.bats --filter-tags '!release'
# For debugging:
#   bats ./tests/test.bats --show-output-of-passing-tests --verbose-run --print-output-on-failure

setup() {
  set -eu -o pipefail

  # Override this variable for your add-on:
  export GITHUB_REPO=Drupal-AI/ddev-drupal-ai

  TEST_BREW_PREFIX="$(brew --prefix 2>/dev/null || true)"
  export BATS_LIB_PATH="${BATS_LIB_PATH}:${TEST_BREW_PREFIX}/lib:/usr/lib/bats"
  bats_load_library bats-assert
  bats_load_library bats-file
  bats_load_library bats-support

  export DIR="$(cd "$(dirname "${BATS_TEST_FILENAME}")/.." >/dev/null 2>&1 && pwd)"
  export PROJNAME="test-$(basename "${GITHUB_REPO}")"
  mkdir -p ~/tmp
  export TESTDIR=$(mktemp -d ~/tmp/${PROJNAME}.XXXXXX)
  export DDEV_NONINTERACTIVE=true
  export DDEV_NO_INSTRUMENTATION=true
  ddev delete -Oy "${PROJNAME}" >/dev/null 2>&1 || true
  cd "${TESTDIR}"
  run ddev config --project-name="${PROJNAME}" --project-tld=ddev.site
  assert_success
  run ddev start -y
  assert_success
}

health_checks() {
  # Check if drupal-ai command is available
  run ddev drupal-ai help
  assert_success
  assert_output --partial "Drupal AI Add-on"

  # Check if configuration files exist
  assert_file_exists ".ddev/drupal-ai/configs/providers.yaml"
  assert_file_exists ".ddev/drupal-ai/configs/functionalities.yaml"
  assert_file_exists ".ddev/drupal-ai/configs/dependencies.yaml"
  
  # Check if scripts are executable
  assert_file_exists ".ddev/drupal-ai/scripts/install-addon.sh"
  assert_file_executable ".ddev/drupal-ai/scripts/install-addon.sh"
  
  # Test basic YAML parsing
  run yq eval '.providers | keys' .ddev/drupal-ai/configs/providers.yaml
  assert_success
  assert_output --partial "openai"
  assert_output --partial "anthropic"
  assert_output --partial "ollama"
}

teardown() {
  set -eu -o pipefail
  ddev delete -Oy ${PROJNAME} >/dev/null 2>&1
  # Persist TESTDIR if running inside GitHub Actions. Useful for uploading test result artifacts
  # See example at https://github.com/ddev/github-action-add-on-test#preserving-artifacts
  if [ -n "${GITHUB_ENV:-}" ]; then
    [ -e "${GITHUB_ENV:-}" ] && echo "TESTDIR=${HOME}/tmp/${PROJNAME}" >> "${GITHUB_ENV}"
  else
    [ "${TESTDIR}" != "" ] && rm -rf "${TESTDIR}"
  fi
}

@test "install from directory" {
  set -eu -o pipefail
  echo "# ddev add-on get ${DIR} with project ${PROJNAME} in $(pwd)" >&3
  run ddev add-on get "${DIR}"
  assert_success
  run ddev restart -y
  assert_success
  health_checks
}

# bats test_tags=release
@test "install from release" {
  set -eu -o pipefail
  echo "# ddev add-on get ${GITHUB_REPO} with project ${PROJNAME} in $(pwd)" >&3
  run ddev add-on get "${GITHUB_REPO}"
  assert_success
  run ddev restart -y
  assert_success
  health_checks
}

@test "drupal-ai help command" {
  set -eu -o pipefail
  run ddev add-on get "${DIR}"
  assert_success
  run ddev restart -y
  assert_success
  
  run ddev drupal-ai help
  assert_success
  assert_output --partial "Interactive CLI orchestration tool"
  assert_output --partial "setup"
  assert_output --partial "add"
  assert_output --partial "list"
}

@test "drupal-ai list command" {
  set -eu -o pipefail
  run ddev add-on get "${DIR}"
  assert_success
  run ddev restart -y
  assert_success
  
  run ddev drupal-ai list
  assert_success
  assert_output --partial "Available AI Providers"
  assert_output --partial "Available AI Functionalities"
  assert_output --partial "OpenAI"
  assert_output --partial "Anthropic"
  assert_output --partial "Vector Search"
}

@test "configuration files validation" {
  set -eu -o pipefail
  run ddev add-on get "${DIR}"
  assert_success
  run ddev restart -y
  assert_success
  
  # Test YAML syntax validation
  run yq eval '.' .ddev/drupal-ai/configs/providers.yaml
  assert_success
  
  run yq eval '.' .ddev/drupal-ai/configs/functionalities.yaml
  assert_success
  
  run yq eval '.' .ddev/drupal-ai/configs/dependencies.yaml
  assert_success
  
  # Test specific provider configuration
  run yq eval '.providers.openai.name' .ddev/drupal-ai/configs/providers.yaml
  assert_success
  assert_output "OpenAI"
  
  # Test functionality configuration
  run yq eval '.functionalities."vector-search".name' .ddev/drupal-ai/configs/functionalities.yaml
  assert_success
  assert_output "Vector Search & Embeddings"
}

@test "script functionality" {
  set -eu -o pipefail
  run ddev add-on get "${DIR}"
  assert_success
  run ddev restart -y
  assert_success
  
  # Test validation script
  run ddev exec ".ddev/drupal-ai/scripts/validate-config.sh ddev"
  assert_success
  
  # Test configure provider script (dry run)
  run ddev exec ".ddev/drupal-ai/scripts/configure-provider.sh list"
  assert_success
}

@test "docker-compose templates exist" {
  set -eu -o pipefail
  run ddev add-on get "${DIR}"
  assert_success
  
  assert_file_exists ".ddev/drupal-ai/templates/.env.drupal-ai.template"
  
  # Test environment template file syntax - it should be a valid environment file
  run grep -q "DRUPAL_AI_PROVIDER=" .ddev/drupal-ai/templates/.env.drupal-ai.template
  assert_success
}

@test "workflow templates validation" {
  set -eu -o pipefail
  run ddev add-on get "${DIR}"
  assert_success
  
  assert_file_exists ".ddev/drupal-ai/configs/workflows/openai-embeddings.yaml"
  assert_file_exists ".ddev/drupal-ai/configs/workflows/ollama-local.yaml"
  assert_file_exists ".ddev/drupal-ai/configs/workflows/anthropic-content.yaml"
  
  # Test workflow YAML syntax
  run yq eval '.' .ddev/drupal-ai/configs/workflows/openai-embeddings.yaml
  assert_success
  
  # Test workflow structure
  run yq eval '.name' .ddev/drupal-ai/configs/workflows/openai-embeddings.yaml
  assert_success
  assert_output "OpenAI with Vector Search"
}

@test "error handling for invalid commands" {
  set -eu -o pipefail
  run ddev add-on get "${DIR}"
  assert_success
  run ddev restart -y
  assert_success
  
  # Test invalid command
  run ddev drupal-ai invalid-command
  assert_failure
  assert_output --partial "Unknown command: invalid-command"
}

@test "provider configuration structure" {
  set -eu -o pipefail
  run ddev add-on get "${DIR}"
  assert_success
  
  # Test that all required providers have proper structure
  local providers=("openai" "anthropic" "ollama" "google_gemini")
  
  for provider in "${providers[@]}"; do
    run yq eval ".providers.${provider}.name" .ddev/drupal-ai/configs/providers.yaml
    assert_success
    
    run yq eval ".providers.${provider}.description" .ddev/drupal-ai/configs/providers.yaml
    assert_success
    
    run yq eval ".providers.${provider}.capabilities" .ddev/drupal-ai/configs/providers.yaml
    assert_success
  done
}

@test "functionality requirements validation" {
  set -eu -o pipefail
  run ddev add-on get "${DIR}"
  assert_success
  
  # Test that vector-search requires pgvector
  run yq eval '.functionalities."vector-search".required_addons[]' .ddev/drupal-ai/configs/functionalities.yaml
  assert_success
  assert_output --partial "pgvector"
  
  # Test that qa-system requires embeddings capability
  run yq eval '.functionalities."qa-system".required_capabilities[]' .ddev/drupal-ai/configs/functionalities.yaml
  assert_success
  assert_output --partial "embeddings"
}

@test "dependency mapping validation" {
  set -eu -o pipefail
  run ddev add-on get "${DIR}"
  assert_success
  
  # Test workflow configuration uses direct identifiers
  run yq eval '.workflows."openai-embeddings".required_addons[0]' .ddev/configs/dependencies.yaml
  assert_success
  assert_output "robertoperuzzo/ddev-pgvector"
  
  # Test ollama workflow uses direct identifiers
  run yq eval '.workflows."ollama-local".required_addons[0]' .ddev/configs/dependencies.yaml
  assert_success
  assert_output "stinis87/ddev-ollama"
  
  # Test workflow configuration
  run yq eval '.workflows."openai-embeddings".provider' .ddev/configs/dependencies.yaml
  assert_success
  assert_output "openai"
}

@test "file permissions and executability" {
  set -eu -o pipefail
  run ddev add-on get "${DIR}"
  assert_success
  
  # Check that main command is executable
  assert_file_executable ".ddev/commands/web/drupal-ai"
  
  # Check that all scripts are executable
  assert_file_executable ".ddev/drupal-ai/scripts/install-addon.sh"
  assert_file_executable ".ddev/drupal-ai/scripts/configure-provider.sh"
  assert_file_executable ".ddev/drupal-ai/scripts/validate-config.sh"
}

@test "integration with ddev structure" {
  set -eu -o pipefail
  run ddev add-on get "${DIR}"
  assert_success
  run ddev restart -y
  assert_success
  
  # Test that the add-on integrates properly with ddev
  run ddev describe
  assert_success
  
  # Check that services can be listed
  run ddev list
  assert_success
  assert_output --partial "${PROJNAME}"
}
