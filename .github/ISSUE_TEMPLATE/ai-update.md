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
- https://docs.docker.com/compose/releases/release-notes/ is `ARG COMPOSE_VERSION` is Docker Compose and uses GitHub releases
- `ARG DOCKER_VERSION` is the community Docker engine and releases are semantically versioned.  The list of versions can be found for the `docker-*` package at <https://download.docker.com/linux/static/stable/x86_64/>

For each of these projects, update the version in the Dockerfiles below _if and only if_ they appear in that file:

- images/rootless-ubuntu-jammy.Dockerfile
- images/rootless-ubuntu-numbat.Dockerfile
- images/ubi10.Dockerfile
- images/ubi9.Dockerfile
- images/ubi8.Dockerfile
- images/wolfi.Dockerfile

If there are updates, open a pull request and assign review to @some-natalie.  Comment in that pull request that closing it will close the issue.

If there are no updates, close this issue.
