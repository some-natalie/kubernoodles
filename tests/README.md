# Tests for images

This folder contains tests for the images built by the project, broken up as logically as I can.  The idea is to have a framework to expand test coverage of the images while keeping the build/test workflows in `~./github/workflows/` as succinct as possible.  These are more towards E2E testing, as it's going to run only after the image has successfully:

1. Builds and is pushed to the registry
2. Deployed to the cluster
3. Attaches to GitHub as a self-hosted runner

The tests are also pretty chill about versions and such, checking for specific things only as needed and relying on failures.  An example would be "docker run hello-world" which will fail if Docker's daemon isn't running, but there's no additional feedback or checks requested.  If needed, you can expand these tests to, say, pipe output into grep to search for a string, etc.

:information_source:  The design of the project is to have self-hosted GitHub Actions runners build, test, manage, and deploy themselves as much as possible - even if other testing frameworks may provide earlier feedback or be easier to write/maintain for testing.  Minimizing dependencies is a good thing in and of itself. :heart:

## Tests

Here's the current tests, what they do, and why.

- `container` (container Action) - builds a container Action from Dockerfile to run
- `debug` (composite Action) - dumps debug information to the console
  - environment variables
  - user information
- `docker` (composite Action) - tests Docker functionality
  - verifies Docker daemon is up
  - runs `hello-world` to verify Docker works
  - prints some debug info about Docker and the network it uses to the console
- `podman` (composite Action) - tests Podman functionality
  - verifies Podman, Buildah, and Skopeo are installed
  - runs `hello-world` to verify Podman works
  - verifies "podman compose" works
  - verifies the alias to "docker" works
  - prints some debug info about versions and container networks to the console
