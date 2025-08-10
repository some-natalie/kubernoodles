# GitHub Copilot Instructions for Kubernoodles

**ALWAYS follow these instructions and only fallback to additional search and context gathering if the information here is incomplete or found to be in error.**

This file provides instructions to GitHub Copilot for working effectively with the Kubernoodles repository.

## Repository Overview

Kubernoodles is a framework for managing custom self-hosted runners for GitHub Actions in Kubernetes at enterprise scale. This repository contains:

- **Docker images**: Located in `/images/` - Contains Dockerfiles for various runner images
- **Kubernetes deployments**: Located in `/deployments/` - Kubernetes manifests for deploying runners
- **Cluster configs**: Located in `/cluster-configs/` - Configuration files for different cluster setups
- **Documentation**: Located in `/docs/` - Comprehensive guides and troubleshooting
- **Tests**: Located in `/tests/` - End-to-end tests for validating runner images

## Working Effectively with the Codebase

### Development Environment Setup

Do NOT try to set up a traditional local development environment. This is an infrastructure project that requires:
- Docker for building container images
- Access to external container registries (docker.io, quay.io, ghcr.io, registry.access.redhat.com, cgr.dev)
- Kubernetes cluster for testing deployments
- GitHub App credentials for runner registration

### Building and Testing

#### **CRITICAL BUILD TIMING**
- **NEVER CANCEL builds or long-running commands** - Docker image builds take 15-45 minutes per image
- Set timeouts to 60+ minutes for build commands
- Multi-architecture builds (amd64 + arm64) take significantly longer
- Test workflows take 15+ minutes (build→deploy→test→cleanup cycle)

#### Build Commands
```bash
# Build a specific image (from repository root)
docker build -f images/ubi8.Dockerfile -t test-runner:ubi8 .

# Build with multi-architecture support
docker buildx build --platform linux/amd64,linux/arm64 -f images/ubi8.Dockerfile -t test-runner:ubi8 .

# Build all images (use the GitHub workflow instead)
# See .github/workflows/build-latest.yml
```

#### Available Images

Build any of these Dockerfiles in `/images/` (6 main production images):
- `ubi8.Dockerfile` - Red Hat UBI 8 (rootful, no sudo)
- `ubi9.Dockerfile` - Red Hat UBI 9 (rootful, no sudo)  
- `ubi10.Dockerfile` - Red Hat UBI 10 (rootful, no sudo)
- `rootless-ubuntu-jammy.Dockerfile` - Ubuntu 22.04 LTS with rootless Docker-in-Docker
- `rootless-ubuntu-numbat.Dockerfile` - Ubuntu 24.04 LTS with rootless Docker-in-Docker  
- `wolfi.Dockerfile` - Chainguard Wolfi (minimal, no sudo)

**Additional specialized images:**
- `ghes-demo.Dockerfile` - Demo image for GitHub Enterprise Server
- `kaniko-build-test.Dockerfile` - Test image for Kaniko builds

### Linting and Validation

**ALWAYS validate changes before committing** using these commands:

```bash
# 1. Shell script linting (if modifying .sh files)
shellcheck images/*.sh
shellcheck images/software/*.sh

# 2. The repository uses Super Linter via GitHub Actions
# Trigger manually via GitHub UI or by creating PR
# See .github/workflows/super-linter.yml

# 3. Validate JSON files (if modifying deployments)
find . -name "*.json" -exec python -m json.tool {} \;

# 4. Basic Dockerfile syntax validation (will fail fast if major syntax errors)
docker build -f images/ubi8.Dockerfile -t syntax-test . --target build 2>&1 | head -10
```

**Linting Configuration:**
- `.github/linters/.hadolint.yaml` - Dockerfile linting rules
- `.github/linters/.markdownlint.json` - Markdown formatting rules

**The super-linter workflow validates:**
- Dockerfile syntax and best practices (Hadolint)
- Markdown formatting and links  
- JSON syntax validation
- Additional code quality checks

### Testing Strategy

This project uses **End-to-End testing only** - no unit tests. The test cycle is:
1. Build Docker image and push to registry
2. Deploy to Kubernetes cluster as GitHub Actions runner  
3. Run tests as GitHub Actions workflows
4. Clean up deployment

#### Manual Validation Scenarios

**After modifying Docker images:**
1. Build the specific image locally (expect 15-45 minutes)
2. Verify the image starts without errors
3. Test that required software is installed correctly
4. For rootless images: Verify Docker daemon starts in rootless mode
5. For UBI images: Verify Podman/Buildah/Skopeo work correctly

**After modifying deployments:**
1. Deploy to test Kubernetes cluster
2. Verify runner registers with GitHub successfully
3. Run a basic workflow to test functionality
4. Check resource limits and requests are appropriate

**After modifying tests:**
1. Run the specific test workflow
2. Verify test results are accurate and meaningful
3. Ensure cleanup happens properly

**After modifying documentation:**
1. Verify all links work correctly
2. Test any example commands provided
3. Ensure formatting is consistent

### Common Development Tasks

#### Repository Structure (key locations)
```
/images/                    # Docker images and build scripts
  ├── software/            # Software installation scripts
  ├── *.Dockerfile         # Image definitions
  └── startup.sh           # Container startup scripts
/deployments/              # Kubernetes Helm charts
/cluster-configs/          # Cluster configuration files
/tests/                    # End-to-end test definitions
  ├── debug/               # Debug information tests
  ├── docker/              # Docker functionality tests
  ├── podman/              # Podman functionality tests
  └── sudo-*/              # Sudo access tests
/.github/workflows/        # Build, test, and deployment workflows
/.github/linters/          # Linting configuration
```

#### Frequently Used Commands
```bash
# List all available Docker images to build
find images -name "*.Dockerfile" -not -path "*/archive/*"

# Check workflow status and build history
ls .github/workflows/build-*.yml
ls .github/workflows/test-*.yml

# View current image versions and dependencies
grep -r "ARG.*VERSION" images/*.Dockerfile

# Validate Dockerfile syntax (basic check - will fail early if syntax issues)  
docker build -f images/ubi8.Dockerfile -t syntax-test:latest . --no-cache --target build 2>&1 | head -20

# Check test definitions
ls tests/*/action.yml

# Lint shell scripts in the repository  
find images -name "*.sh" -exec shellcheck {} \;
```

#### Expected Command Outputs
```bash
# find images -name "*.Dockerfile" should show:
images/ghes-demo.Dockerfile
images/kaniko-build-test.Dockerfile  
images/rootless-ubuntu-jammy.Dockerfile
images/rootless-ubuntu-numbat.Dockerfile
images/ubi8.Dockerfile
images/ubi9.Dockerfile
images/ubi10.Dockerfile
images/wolfi.Dockerfile

# ls tests/ should show:
cache/  container/  debug/  docker/  podman/  sudo-fails/  sudo-works/
```

### Network Requirements and Enterprise Considerations

This project is designed for enterprise environments and requires:
- Access to multiple container registries (Red Hat, Docker Hub, GitHub, Chainguard)
- Kubernetes cluster with appropriate RBAC permissions
- GitHub App credentials for runner registration
- Potential proxy/firewall configurations for restricted networks

**Network failures are common** in restricted environments. The build process requires downloading from:
- registry.access.redhat.com (for UBI images)
- docker.io (for Ubuntu images)
- cgr.dev (for Wolfi images)  
- External package repositories (yum, apt, apk)

If builds fail with network errors, this is expected in sandbox/restricted environments.

### Troubleshooting Common Issues

#### Build Failures
- **Network timeouts**: Expected in restricted environments - builds require external registry access
- **"repository not found"**: Check if base images are accessible from your network
- **"dnf/apt update failed"**: Package repository access blocked by firewall/proxy

#### Test Failures  
- **"runner failed to connect"**: GitHub App credentials or network connectivity issues
- **"pod failed to start"**: Resource limits, image pull failures, or Kubernetes RBAC issues
- **"timeout waiting for pod"**: Kubernetes cluster performance or resource constraints

#### Validation Failures
- **Shellcheck warnings**: Generally safe to ignore SC1091 (sourcing files not in path)
- **Hadolint warnings**: Review `.hadolint.yaml` for acceptable exceptions
- **Markdown lint**: Check `.markdownlint.json` for formatting rules

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