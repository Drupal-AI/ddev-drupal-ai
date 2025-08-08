[![add-on registry](https://img.shields.io/badge/DDEV-Add--on_Registry-blue)](https://addons.ddev.com)
[![tests](https://github.com/Drupal-AI/ddev-drupal-ai/actions/workflows/tests.yml/badge.svg?branch=main)](https://github.com/Drupal-AI/ddev-drupal-ai/actions/workflows/tests.yml?query=branch%3Amain)
[![last commit](https://img.shields.io/github/last-commit/Drupal-AI/ddev-drupal-ai)](https://github.com/Drupal-AI/ddev-drupal-ai/commits)
[![release](https://img.shields.io/github/v/release/Drupal-AI/ddev-drupal-ai)](https://github.com/Drupal-AI/ddev-drupal-ai/releases/latest)

# DDEV Drupal Ai

## Overview

This add-on integrates Drupal Ai into your [DDEV](https://ddev.com/) project.

## Installation

```bash
ddev add-on get Drupal-AI/ddev-drupal-ai
ddev restart
```

After installation, make sure to commit the `.ddev` directory to version control.

## Usage

| Command | Description |
| ------- | ----------- |
| `ddev describe` | View service status and used ports for Drupal Ai |
| `ddev logs -s drupal-ai` | Check Drupal Ai logs |

## Advanced Customization

To change the Docker image:

```bash
ddev dotenv set .ddev/.env.drupal-ai --drupal-ai-docker-image="busybox:stable"
ddev add-on get Drupal-AI/ddev-drupal-ai
ddev restart
```

Make sure to commit the `.ddev/.env.drupal-ai` file to version control.

All customization options (use with caution):

| Variable | Flag | Default |
| -------- | ---- | ------- |
| `DRUPAL_AI_DOCKER_IMAGE` | `--drupal-ai-docker-image` | `busybox:stable` |

## Credits

**Contributed and maintained by [@Drupal-AI](https://github.com/Drupal-AI)**
