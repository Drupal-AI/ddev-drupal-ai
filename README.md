[![add-on registry](https://img.shields.io/badge/DDEV-Add--on_Registry-blue)](https://addons.ddev.com)
[![tests](https://github.com/Drupal-AI/ddev-drupal-ai/actions/workflows/tests.yml/badge.svg?branch=main)](https://github.com/Drupal-AI/ddev-drupal-ai/actions/workflows/tests.yml?query=branch%3Amain)
[![last commit](https://img.shields.io/github/last-commit/Drupal-AI/ddev-drupal-ai)](https://github.com/Drupal-AI/ddev-drupal-ai/commits)
[![release](https://img.shields.io/github/v/release/Drupal-AI/ddev-drupal-ai)](https://github.com/Drupal-AI/ddev-drupal-ai/releases/latest)

# DDEV Drupal AI Add-on

## Overview

This add-on provides an interactive CLI orchestration tool for Drupal AI workflows within your [DDEV](https://ddev.com/) project. It acts as a meta-tool that streamlines the setup and orchestration of AI capabilities in Drupal development environments.

With this add-on, you can:

* **Interactive Setup Wizard**: Choose AI provider → select functionality → automatic dependency resolution and installation
* **Multiple AI Providers**: Support for OpenAI, Anthropic, Ollama, and Google Gemini
* **Automated Add-on Management**: Automatically install required add-ons (pgvector, unstructured, etc.)
* **YAML-driven Configuration**: Extensible configuration system for providers and functionalities
* **Comprehensive Error Handling**: User-friendly error messages and rollback capabilities

## Architecture

* **Glue Add-on Pattern**: Meta-tool that orchestrates other DDEV add-ons
* **Interactive CLI**: Guided user experience with provider → functionality → setup flow
* **YAML-driven Configuration**: Steps and configurations defined in YAML, not hardcoded in Bash
* **Dependency Management**: Automatically install required add-ons based on selected features

## Installation

```bash
ddev add-on get Drupal-AI/ddev-drupal-ai
ddev restart
```

After installation, make sure to commit the `.ddev` directory to version control.

## Quick Start

### Complete AI Stack Setup

Run the interactive setup wizard to configure your complete AI stack:

```bash
ddev drupal-ai setup
```

This will guide you through:
1. **AI Provider Selection** (OpenAI, Anthropic, Ollama, etc.)
2. **Functionality Selection** (Vector Search, Content Generation, Q&A, etc.)
3. **Dependency Analysis** (Required add-ons will be identified)
4. **Automated Installation** (Add-ons installed automatically)
5. **Provider Configuration** (API keys, models, endpoints)

### Example Workflow

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

Step 3: Dependencies Analysis
📦 Required add-ons for your selection:
  - pgvector (for vector search) → Will install
  
? Proceed with installation? (Y/n)

Step 4: Installation
✅ Installing pgvector add-on...
✅ Configuring OpenAI services...

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

## CLI Commands

### Primary Commands

| Command | Description |
|---------|-------------|
| `ddev drupal-ai setup` | Interactive wizard for complete AI stack setup |
| `ddev drupal-ai list` | Display available providers and installed add-ons |
| `ddev drupal-ai help` | Show help information |

### Supported Add-ons

| Add-on | Description | Source |
|--------|-------------|---------|
| `pgvector` | PostgreSQL with pgvector extension for vector storage | [robertoperuzzo/ddev-pgvector](https://github.com/robertoperuzzo/ddev-pgvector) |
| `unstructured` | Document processing and parsing service | [drud/ddev-unstructured](https://github.com/drud/ddev-unstructured) |
| `ollama-service` | Local LLM server for running models like Llama, Mistral | [stinis87/ddev-ollama](https://github.com/stinis87/ddev-ollama) |
| `redis` | Redis cache for improved AI performance | [drud/ddev-redis](https://github.com/drud/ddev-redis) |

### Supported Providers

| Provider | Models | Capabilities |
|----------|--------|--------------|
| **OpenAI** | GPT-4, GPT-3.5, DALL-E | Text generation, embeddings, image generation |
| **Anthropic** | Claude 3.5, Claude 3 | Text generation |
| **Ollama** | Llama3, Mistral, etc. | Local text generation, embeddings |
| **Google Gemini** | Gemini Pro, Vision | Text generation, image analysis |

### Available Functionalities

| Functionality | Description | Requirements |
|---------------|-------------|-------------|
| **Vector Search & Embeddings** | Semantic search using vector databases | pgvector, embeddings capability |
| **Content Generation** | AI-powered content creation | Text generation capability |
| **Image Analysis** | AI-powered image recognition | Image analysis capability |
| **Q&A System** | Intelligent question answering | pgvector, text generation, embeddings |
| **Code Assistant** | AI-powered code generation | Text generation capability |
| **Document Processing** | Extract and process various document formats | unstructured add-on |

## Configuration

### Environment Variables

Configuration is stored in `.ddev/.env.drupal-ai`. Key variables include:

```bash
# Provider Configuration
DRUPAL_AI_PROVIDER=openai
DRUPAL_AI_FUNCTIONALITIES=vector-search,content-generation

# OpenAI Configuration
OPENAI_API_KEY=sk-...
OPENAI_MODEL=gpt-4
OPENAI_BASE_URL=https://api.openai.com/v1

# Database Configuration
POSTGRES_DB=drupal_ai
POSTGRES_USER=drupal_ai
POSTGRES_PASSWORD=drupal_ai
```

### Manual Configuration
All configuration is now handled through the main command interface:

```bash
# Configure providers and functionalities
ddev drupal-ai setup

# List available providers and installed components  
ddev drupal-ai list

# Get help
ddev drupal-ai help
```

## Advanced Usage

### Validation and Health Checks

The main `drupal-ai` command includes built-in validation and health checks that run during setup.

### Service Management

After setup, you can manage services:

```bash
# View all services
ddev describe

# Check PostgreSQL status
ddev exec -s postgres pg_isready

# Check Ollama models (if installed)
ddev exec -s ollama curl http://localhost:11434/api/tags

# View logs
ddev logs -s postgres
ddev logs -s ollama
```

## Drupal Integration

### Installing Drupal AI Modules

After setting up the infrastructure:

```bash
# Install core AI module
ddev composer require drupal/ai

# Install additional AI modules based on your setup
ddev composer require drupal/ai_search    # For vector search
ddev composer require drupal/ai_content   # For content generation
ddev composer require drupal/ai_qa        # For Q&A systems
```

### Configuration

1. Navigate to `/admin/config/ai` in your Drupal site
2. Configure your AI provider with the same settings used in the setup
3. Test the connection
4. Configure specific AI functionalities as needed

## Troubleshooting

### Common Issues

**Command not found**
```bash
# Ensure the add-on is properly installed
ddev add-on get Drupal-AI/ddev-drupal-ai
ddev restart
```

**YAML parsing errors**
```bash
# Install yq if not available
brew install yq  # macOS
# or follow instructions at https://github.com/mikefarah/yq#install
```

**Service connection failures**
```bash
# Check service status
ddev describe

# Restart services
ddev restart

# Check logs
ddev logs -s <service-name>
```

**API connection issues**
```bash
# Use the interactive setup to reconfigure
ddev drupal-ai setup
```

### Reset Configuration

To reset all AI configuration, simply delete the configuration file and run setup again:

```bash
rm .ddev/.env.drupal-ai
ddev drupal-ai setup
```

## Development

### Custom Configurations

You can extend the add-on by creating custom configurations in `.ddev/drupal-ai/configs/`. See the existing YAML files for examples.

### Contributing

1. Fork the repository
2. Create your feature branch
3. Add tests for your changes
4. Ensure all tests pass: `bats tests/test.bats`
5. Submit a pull request

### Testing

Run the test suite:

```bash
# Install bats if needed
brew install bats-core bats-assert bats-file bats-support

# Run tests
bats tests/test.bats

# Run with debugging
bats tests/test.bats --show-output-of-passing-tests --verbose-run
```

## Credits

**Contributed and maintained by [@Drupal-AI](https://github.com/Drupal-AI)**

Based on the [ddev-addon-template](https://github.com/ddev/ddev-addon-template)
