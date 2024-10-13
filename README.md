# Kubernoodles

Kubernoodles is a framework for **managing custom self-hosted runners for GitHub Actions in Kubernetes at the enterprise-wide scale.**  The design goal is to easily bootstrap a system where customized self-hosted runners update, build, test, deploy, and scale themselves with minimal interaction from enterprise admins and maximum input from the developers using it.

This is an _opinionated_ reference implementation, designed to be taken and modified to your liking.  I use this to test GitHub Actions on my personal account, [GitHub Enterprise Cloud](https://github.com) (SaaS) or [GitHub Enterprise Server](https://docs.github.com/en/enterprise-server@latest) (self-hosted) from Docker Desktop, a Raspberry Pi cluster for `arm64`, a managed Kubernetes provider, and other random platforms as needed.  Your implementation may look wildly different, etc.

:question: Are you a GitHub Enterprise admin that's new to GitHub Actions?  Don't know how to set up self-hosted runners at scale?  Start [here](https://some-natalie.dev/blog/arch-guide-to-selfhosted-actions/)!

Pull requests welcome! :heart:

## Setup

The [admin introduction](https://some-natalie.dev/blog/arch-guide-to-selfhosted-actions/) walks you through some key considerations on _how_ to think about implementing GitHub Actions at the enterprise scale, the implications of those decisions, and why this project is generally built out the way it is.

The [admin setup](https://some-natalie.dev/blog/kubernoodles-pt-1) is a mostly copy-and-paste exercise to get a basic deployment up and going.

The [customization](https://some-natalie.dev/blog/kubernoodles-pt-5) guide has a quick writeup and links to learn more about the ways you can customize things to your needs.

[Tips and tricks](docs/tips-and-tricks.md) has a few more considerations if things aren't quite going according to plan.

## Choosing the image(s)

There are currently 5 images that are "prebuilt" by this project, although you can certainly use others or build your own!  All images assume that they are ephemeral.  If you're copy/pasting out of the [deployments](deployments), you should be set ... provided you give it the right repository/organization/enterprise to use!

<!-- START_SECTION:table -->
| image name | base image | CVE count<br>(crit/high/med+below) | archs | virtualization? | sudo? | notes |
|---|---|---|---|---|---|---|
| ubi8 | [ubi8-init:8.10](https://catalog.redhat.com/software/containers/ubi8/ubi-init/5c359b97d70cc534b3a378c8) | 4/16/564 | x86_64<br>arm64 | :x: | :x: | n/a |
| ubi9 | [ubi9-init:9.4](https://catalog.redhat.com/software/containers/ubi9-init/6183297540a2d8e95c82e8bd) | 0/16/575 | x86_64<br>arm64 | :x: | :x: | n/a |
| rootless-ubuntu-jammy | [ubuntu:jammy](https://hub.docker.com/_/ubuntu) | 0/14/152 | x86_64<br>arm64 | rootless Docker-in-Docker | :x: | [common rootless problems](docs/tips-and-tricks.md#rootless-images) |
| rootless-ubuntu-numbat | [ubuntu:numbat](https://hub.docker.com/_/ubuntu) | 0/14/67 | x86_64<br>arm64 | rootless Docker-in-Docker | :x: | [common rootless problems](docs/tips-and-tricks.md#rootless-images) |
| wolfi:latest | [wolfi-base:latest](https://images.chainguard.dev/directory/image/wolfi-base/versions) | 0/4/3 | x86_64<br>arm64 | :x: | :x: | n/a |
<!-- END_SECTION:table -->

<!-- START_SECTION:date -->
> [!NOTE]
> CVE count was done on 13 October 2024 with the latest versions of [grype](https://github.com/anchore/grype) and runner image tags.
<!-- END_SECTION:date -->

## Design goals and compromises

There are a few assumptions that go into this that aren't necessarily true or best practices outside of an enterprise "walled garden".  Being approachable and readable are the most important goals of all code and documentation.  As a reference implementation, this isn't a turn-key solution, but the amount of fiddling needed should be up to you as much as possible.  Links to the appropriate documentation, resources to learn more where needed, and explanations of design choices will be included!

Co-tenanted business systems tend to have small admin teams running services (like GitHub Enterprise) available to a large group of diverse internal users.  That system places a premium on people-overhead more than computer-overhead.  The implication of that is an anti-pattern where there are larger containers capable of lots of different things instead of discrete, "microservices" type containers.

Moving data around locally is exponentially cheaper and easier than pulling data in from external sources, especially in a larger company.  Big containers are not scary if the registry, the compute, and the entire network path is all within the same datacenter or availability zone.  Caching on-site is important to prevent rate-limiting by upstream providers, as that can take down other services and users that rely on them.  This also provides a mechanism for using a "trusted" package registry, common in enterprise environments, using an `.env` file as outlined [here](images/README.md).

## Sources

These are all excellent reads and can provide more insight into the customization options and updates than are available in this repository.  This entire repository is mostly gluing a bunch of these other bits together and explaining how/why to make this your own.

- GitHub's official [documentation](https://docs.github.com/en/actions/hosting-your-own-runners) on hosting your own runners.
- Kubernetes controller for self-hosted runners, on [GitHub](https://github.com/actions/actions-runner-controller), is the glue that makes this entire solution possible.
- Docker image for runners that can automatically join, which solved a good bit of getting the runner agent started automatically on each pod, [write up](https://sanderknape.com/2020/03/self-hosted-github-actions-runner-kubernetes/) and [GitHub](https://github.com/SanderKnape/github-runner).
- GitHub's repository used to generate the hosted runners' images ([GitHub](https://github.com/actions/virtual-environments)), where I got the idea of using shell scripts to layer discrete dependency management on top of a base image.  The [software](../images/software) scripts are (mostly) copy/pasted directly out of that repo.

### Learn more

- Don't know what the whole Kubernetes thing is about?  Here's some help:
  - The [Kubernetes Aquarium](https://medium.com/@AnneLoVerso/the-kubernetes-aquarium-6a3d1d7a2afd)
  - The Cloud Native Computing Foundation's book, [The Illustrated Children's Guide to Kubernetes](https://www.cncf.io/phippy/the-childrens-illustrated-guide-to-kubernetes/)
  - The official [tutorial](https://kubernetes.io/docs/tutorials/kubernetes-basics/) covering the basics of what Kubernetes is and how it works
  - What helped me to understand this whole concept shift is to think that Kubernetes is to containers as KVM/vSphere/Hyper-V is to virtual machines.  It's probably not a perfect metaphor, but it helped. :smile:
- Want to see a whole bunch of other ways to solve this problem?  You should check out [Awesome Runners](https://jonico.github.io/awesome-runners) for a curated list and amazing matrix comparison of all sorts of other self-hosted runner solutions.
- Even if this is 100% on-premises, many of these [antipatterns for cloud applications](https://docs.microsoft.com/en-gb/azure/architecture/antipatterns/) are very relevant to the architecture of CI at scale and these are all well worth the time to read.
- Rootful versus rootless containerization in Podman is a bit different than in Docker.  Learn more at RedHat's [Enable Sysadmin](https://www.redhat.com/sysadmin/podman-inside-container) blog post.

### Dependencies of note

- [actions-runner-controller](https://github.com/actions/actions-runner-controller)
- [Helm](https://helm.sh/)
- [Yelp dumb-init](https://github.com/Yelp/dumb-init)
- [Docker engine](https://docs.docker.com/engine/release-notes/) and [Docker Compose](https://docs.docker.com/compose/release-notes/) for Debian-based images
- [Podman](https://github.com/containers/podman), [Buildah](https://github.com/containers/buildah), and [Skopeo](https://github.com/containers/skopeo) for the RedHat-based images
- [actions/runner](https://github.com/actions/runner) is the runner agent for GitHub Actions

> [!NOTE]
> GHES users prior to 3.9, please navigate back to tag [v0.9.6](https://github.com/some-natalie/kubernoodles/tree/v0.9.6) ([release](https://github.com/some-natalie/kubernoodles/releases/tag/v0.9.6)) for the APIs that'll work for you. :heart:
