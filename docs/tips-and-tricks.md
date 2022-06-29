# Tips and Tricks

## Nested virtualization

Nested virtualization is complicated and has a lot of design tradeoffs.  Each layer has additional overhead and places where things can go wrong.  Some of these could be removed by using a managed Kubernetes provider and not bare metal, but I'm not sure here.

[MTU](https://en.wikipedia.org/wiki/Maximum_transmission_unit) size is important!  Depending on your use of bare metal Kubernetes or a managed cluster provider, the configuration of the entire rest of the network, etc., this can be a common failure point.  In theory, it shouldn't be as much of a problem as it is, since containers should have some level of [Path MTU Discovery](https://en.wikipedia.org/wiki/Path_MTU_Discovery).  The problem with relying on PMTUD is that a _lot_ of corporate network infrastructure will block all/most [ICMP](https://en.wikipedia.org/wiki/Internet_Control_Message_Protocol) messages, resulting in silent networking failures for users.  A fantastic summary of this problem and ways to remediate it are detailed [here](https://blog.cloudflare.com/path-mtu-discovery-in-practice/).

:information_source: This explicitly specifies an MTU of 1450 for the runner pod (Debian/Ubuntu runners) or sets a kernel configuration for MTU probing for the runner pod (RHEL/derivative runners).  The MTU is set to 1400 for any container inside the runner, but your network architects may have better guidance for you.

## Over-provisioning on bare metal

Over-provision (promising more resources than you have available) at your own risk.  This is a rabbit-hole down which there is no end, but you should read and understand the guidance offered by your base hypervisor platform (e.g., vSphere, Hyper-V, etc) first - then look at potentially over-provisioning within Kubernetes.  The Kubernetes scheduler is only as smart as what it can see and depending on your configuration, might not be able to see into the nested solution above it (such as the hypervisor in use or the physical resources of your servers), if that makes sense.

This consideration drove the large difference between the resource requests and limits for the runners.  The quick little tasks that don't require a lot of compute can go anywhere, the heavy usage pods can be moved around on the nodes by the scheduler to optimize longer-running jobs.  If you're using Kubernetes within a VM infrastructure, the worker nodes can be moved around via vMotion as needed to make the best use of the physical compute.  When this goes wrong, it can cause all manner of cryptic error messages so I've made it a habit to always check resource utilization first.

In general, the fewer "layers" you have, the fewer places things can go wrong.

## Rootless images

Rootless-in-rootless containerization is possible, but comes with a different set of problems than the rootful images.  Common stumbling points here include:

- All tasks have to run as the correct user with the correct UID.  In these, it's `runner` for username and `1000` for UID.
- There's no `sudo` in these images, so users cannot configure the build environment.  It must be configured for them by an admin for things that'd normally require "admin" rights - like software installation.
- Many Docker Actions in the GitHub marketplace assume rootful Docker and can create interesting errors.
- The `PATH` of the environment seems to get lost frequently, so setting the environment variable for it in anything requiring containers seems to be necessary.  It's easy, but one more place for things to break.  An example of needing to do this is in this [workflow file](https://github.com/some-natalie/kubernoodles/blob/main/.github/workflows/test-rootless-ubuntu-focal.yml#L22-L23).

## Software supply chain management

By default, if you clone this repo and set it up without modifications to the image files, each pod is going to

- Build off the base image in [DockerHub](https://hub.docker.com/) or [Quay.io](https://quay.io) using a broad tag, such as [major semver](https://semver.org/) or LTS release version name
- Pull the latest packages needed at build (as described more below)
- Use the default upstream package source for that ecosystem without further modifications or configuration

For example, if the user runs `pip install SOMETHING`, the pod will pull it from PyPI, Python's default package registry, because that's the default behavior.  This means that if you were wanting to control the software supply chain, the configuration on _how_ to do that should be in place on your images for each aspect of the software supply chain the company needs.  For Python, it means editing `~/.config/pip/pip.conf` with the appropriate values.  This would need to be repeated for each tool in use - NPM for JavaScript, `dnf` or `apt` configurations for the operating system, etc.

It's (usually) a reasonable assumption that there are already internal mirrors with processes to add software internally in place at larger companies that have rules on software ingest, so consult with the documentation from that system and from the team that owns that service to get the right files in place to use for these images.

### Reproducibility

These images assume no opinion about changing the default settings - each package management system isn't configured beyond the defaults it ships with.  It's assumed that the defaults are all reasonable and you'll edit them as needed by your enterprise to use the internal repositories/proxies specific to your use case as needed.

Additionally, no packages apart from the [runner agent](https://github.com/actions/runner) (and depending on the image, Docker and/or Docker Compose) are pinned to a particular version.  This is against usual best practices, and Hadolint yells about it so those rules have been [disabled](../.github/linters/.hadolint.yaml).  There's an explicit assumption that if a company cares about specifying versions of packages, they'll do it themselves to the versions they choose as acceptable.  You can read more about best practices for version pinning from [Docker's documentation](https://docs.docker.com/develop/develop-images/dockerfile_best-practices/#run).

The implications of this is that each time you build the exact same Dockerfile, you might get a different end result based on the latest package versions available at that time.  Likewise, the base image for each is a pretty broad tag (`ubuntu:20.04` or `quay.io/podman/stable:v4`) and can vary on rebuild.  To address this, the default workflows build a tagged image on release ([link](../.github/workflows/build-release.yml)) that should be used instead of `latest` in the [deployments](../deployments/README.md) if this is important in your use case.  

### Caching, bandwidth, and rate-limiting problems

Each pod is assumed to be ephemeral, so at scale, this means that the combined setup tasks for each build can use significant bandwidth.  For example, if you have thousands of builds each hour, all running `docker pull SOMETHING` directly from DockerHub, that's a thousand image pulls to your IP address block.  This will get the company's IP address rate-limited pretty fast.

There are a couple ways to mitigate this - however, a production-ready solution shared across diverse teams is likely a mix of these.

1. Point the pods to your internal repositories and mirror for all supported operating systems, frameworks, and languages.  Doing this would include setting up internal mirroring, using something like Nexus or Artifactory, then configuring your pods to use them first.  Many of these configurations can be set in the [`.env`](../images/README.md#what-this-folder-is-all-about) file, but consult each repository format's documentation for more information on files to include.  Common examples would include:

    - Operating system package repositories (RPM, dpkg, etc.)
    - Container registries (Docker Hub, quay.io, gcr.io, etc.)
    - Language-specific package registries (NPM for JavaScript, PyPI for Python, etc.)

1. Consider including commonly-used packages in the image itself.  This makes for _big_ images, but it should reduce both the time needed to install and set up the needed package each runtime and network egress overall.  It's almost always cheaper to fling big images around internally than it is to bring lots of data in, so the economics could still work out well here.
1. Another simple way to address this would be to toss a [squid](http://www.squid-cache.org/) caching proxy in front of the pods, then configure them to use it.  Be sure to set it up with [SSL peek and splice](https://wiki.squid-cache.org/Features/SslPeekAndSplice), as most modern package management systems include TLS encryption.
