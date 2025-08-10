---
name: AI image dependency bumps
about: AI image dependency bumps
title: "AI image dependency bumps"
---

## Directions

Upstream projects that this project depends on.

- https://github.com/actions/runner is `ARG RUNNER_VERSION` and uses GitHub releases
- https://github.com/actions/runner-container-hooks is `ARG RUNNER_CONTAINER_HOOKS_VERSION` and uses GitHub releases
- https://github.com/Yelp/dumb-init is `ARG DUMB_INIT_VERSION` and uses GitHub releases
- `ARG DOCKER_VERSION` is the community Docker engine and releases are tracked at https://docs.docker.com/engine/release-notes/
- `ARG COMPOSE_VERSION` is Docker Compose and releases are tracked at https://docs.docker.com/compose/releases/release-notes/

For each of these projects, update the version in the Dockerfiles below:

- images/rootless-ubuntu-jammy.Dockerfile
- images/rootless-ubuntu-numbat.Dockerfile
- images/ubi10.Dockerfile
- images/ubi9.Dockerfile
- images/ubi8.Dockerfile
- images/wolfi.Dockerfile

Once updated, open a draft PR and assign review to @some-natalie.

If there are no updates, close this issue.
