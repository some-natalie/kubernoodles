# GitHub Copilot Instructions for Kubernoodles

This file provides instructions to GitHub Copilot for working effectively with the Kubernoodles repository.

## Repository Overview

Kubernoodles is a framework for managing custom self-hosted runners for GitHub Actions in Kubernetes at enterprise scale. This repository contains:

- **Docker images**: Located in `/images/` - Contains Dockerfiles for various runner images
- **Kubernetes deployments**: Located in `/deployments/` - Kubernetes manifests for deploying runners
- **Cluster configs**: Located in `/cluster-configs/` - Configuration files for different cluster setups
- **Documentation**: Located in `/docs/` - Comprehensive guides and troubleshooting

## AI Image Dependency Bump Workflow

### Overview
The repository maintains several Docker images that depend on upstream projects. When working on dependency updates, follow the AI update template located at `.github/ISSUE_TEMPLATE/ai-update.md`.

### Upstream Dependencies to Track

1. **GitHub Actions Runner** (`ARG RUNNER_VERSION`)
   - Source: https://github.com/actions/runner
   - Release tracking: GitHub releases
   - Used in: **All** runner images

2. **Runner Container Hooks** (`ARG RUNNER_CONTAINER_HOOKS_VERSION`)
   - Source: https://github.com/actions/runner-container-hooks
   - Release tracking: GitHub releases
   - Used in: **All** runner images

3. **Dumb-init** (`ARG DUMB_INIT_VERSION`)
   - Source: https://github.com/Yelp/dumb-init
   - Release tracking: GitHub releases
   - Used in: **Rootless Ubuntu images only** (jammy, numbat)

4. **Docker Engine** (`ARG DOCKER_VERSION`)
   - Source: Community Docker engine
   - Release tracking: https://docs.docker.com/engine/release-notes/
   - Used in: **Rootless Ubuntu images only** (jammy, numbat)

5. **Docker Compose** (`ARG COMPOSE_VERSION`)
   - Source: Docker Compose
   - Release tracking: https://docs.docker.com/compose/releases/release-notes/
   - Used in: **Rootless Ubuntu images only** (jammy, numbat)

6. **.NET Runtime** (`ARG DOTNET_VERSION`)
   - Source: Microsoft .NET releases
   - Release tracking: https://dotnet.microsoft.com/platform/support/policy/dotnet-core
   - Used in: **Wolfi image only**

### Dockerfiles to Update

When updating dependencies, check and update these Dockerfiles:

- `images/rootless-ubuntu-jammy.Dockerfile`
- `images/rootless-ubuntu-numbat.Dockerfile`
- `images/ubi10.Dockerfile`
- `images/ubi9.Dockerfile`
- `images/ubi8.Dockerfile`
- `images/wolfi.Dockerfile`

### Dependency Update Process

1. **Check for Updates**: Compare current ARG versions against latest releases from upstream sources
2. **Update ARG Values**: Update the version numbers in the Dockerfile ARG declarations
3. **Test Changes**: Ensure images build successfully with new versions
4. **Create PR**: Open a draft pull request with updates
5. **Review Assignment**: Assign review to @some-natalie
6. **Documentation**: If no updates are needed, close the issue with explanation

### Code Patterns and Conventions

#### Dockerfile ARG Declarations

**All Images:**
```dockerfile
# GitHub runner arguments (present in all images)
ARG RUNNER_VERSION=2.x.x
ARG RUNNER_CONTAINER_HOOKS_VERSION=0.x.x
```

**Rootless Ubuntu Images Only** (jammy, numbat):
```dockerfile
# Docker and Compose arguments
ARG DOCKER_VERSION=xx.x.x
ARG COMPOSE_VERSION=vx.xx.x

# Dumb-init version
ARG DUMB_INIT_VERSION=x.x.x
```

**Wolfi Image Only:**
```dockerfile
# .NET Runtime version
ARG DOTNET_VERSION=x
```

#### Version Format Conventions
- `RUNNER_VERSION`: Use semantic version format (e.g., `2.327.1`)
- `RUNNER_CONTAINER_HOOKS_VERSION`: Use semantic version format (e.g., `0.7.0`)
- `DUMB_INIT_VERSION`: Use semantic version format (e.g., `1.2.5`) - **rootless Ubuntu only**
- `DOCKER_VERSION`: Use semantic version format (e.g., `28.3.3`) - **rootless Ubuntu only**
- `COMPOSE_VERSION`: Include 'v' prefix (e.g., `v2.39.1`) - **rootless Ubuntu only**
- `DOTNET_VERSION`: Use major version number (e.g., `9`) - **Wolfi only**

### Issue Templates and Automation

#### AI Update Template
Located at `.github/ISSUE_TEMPLATE/ai-update.md`, this template provides structured guidance for dependency updates. Use this template when creating issues for dependency bumps.

#### Automated Issue Creation
The repository has a workflow (`.github/workflows/janky-dependabot.yml`) that automatically creates dependency update issues weekly using the AI update template. These issues are automatically assigned to @Copilot for handling.

#### Workflow Integration
The `verify-builds.yml` workflow validates that all Docker images build successfully across both amd64 and arm64 architectures for all supported base images.

#### Important Notes for Copilot
- Always verify version formats match upstream release patterns
- Check that all specified Dockerfiles exist before suggesting updates
- **Not all dependencies apply to all images**: 
  - UBI images (ubi8, ubi9, ubi10) only use RUNNER_VERSION and RUNNER_CONTAINER_HOOKS_VERSION
  - Wolfi image uses RUNNER_VERSION, RUNNER_CONTAINER_HOOKS_VERSION, and DOTNET_VERSION
  - Rootless Ubuntu images use all dependencies: RUNNER_VERSION, RUNNER_CONTAINER_HOOKS_VERSION, DOCKER_VERSION, COMPOSE_VERSION, and DUMB_INIT_VERSION
- Consider multi-architecture builds (x86_64 and arm64) when updating dependencies
- Rootless images have additional Docker/Compose dependencies that others don't need
- UBI (Red Hat Universal Base Image) and Wolfi images may have different update cadences

### Testing and Validation

When making changes:
1. **Local Build Testing**: Build individual Dockerfiles locally to verify they work with new versions
2. **Multi-Architecture Validation**: Ensure changes work for both x86_64 and arm64 architectures  
3. **Dependency Compatibility**: Verify that dependency versions are compatible with each other
4. **Runner Functionality**: Test that GitHub Actions runner functionality remains intact
5. **Workflow Validation**: The `verify-builds.yml` workflow automatically tests all images on PR creation

#### Build Commands for Local Testing
```bash
# Build specific image locally (example for Ubuntu Jammy)
docker build -f images/rootless-ubuntu-jammy.Dockerfile -t test-runner:jammy .

# Build with specific platform
docker buildx build --platform linux/amd64,linux/arm64 -f images/rootless-ubuntu-jammy.Dockerfile -t test-runner:jammy .
```

### Enterprise Considerations

This project is designed for enterprise environments with specific considerations:
- Larger container images are acceptable for enterprise use
- Caching and internal registries are preferred
- Security scanning and CVE management are important
- Customization and extensibility are prioritized over minimalism

## General Development Guidelines

- Follow existing code patterns and conventions
- Update documentation when making functional changes  
- Consider enterprise deployment scenarios
- Maintain backward compatibility where possible
- Use descriptive commit messages and PR descriptions