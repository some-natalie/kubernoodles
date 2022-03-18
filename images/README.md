# Docker stuff for the runners

## Quick Facts

:warning: These are ephemeral pods!  Don't rely on the output being available between workflow steps, runs, etc.  GitHub Actions is also designed to be parallel by default, so try to use that to your advantage when you can.

## What this folder is all about

Here's a quick breakdown of the folder structure here:

- [docker](docker) - Contains the config files needed for the Docker daemon that runs inside each pod.  The pods are all capable of Docker-in-Docker, as quite a few Actions ship as Docker images.
- [software](software) - Bash scripts that install software on the pods at build time.
- [supervisor](supervisor) - The Debian-based runners use [supervisord](http://supervisord.org/) to launch/control Docker within the pod.

In addition to the folders above, here's a bit about the files in this folder.

- The Dockerfiles are ... exactly what you think they are.
- `entrypoint.sh` - The entry point script launches the runner, connects to GitHub, and joins the enterprise pool.
- `logger.sh` - A handy dandy logger script!
- `modprobe.sh` - Not really modprobe, but kinda needed to let Docker-in-Docker run more reliably.  More on this below.
- `startup.sh` - The startup script.  It's a bit ugly, but it works.  It relies on supervisord for the Debian-based runners, but if it fails (such as CentOS), it'll try `sudo $process` before failing for good.
- `.env` - This file gets copied into the container during the build process, then loaded by the entry point script.  Use this to store custom **NON-SECRET** environment variables, such as proxy configurations, caching, private mirrors, etc. that are needed in your on-premises environment.  It is blank by default as this is a public repository, but here's an example:
  
    ```shell
    HTTP_PROXY=http://USERNAME:PASSWORD@10.0.1.1:8080/
    HTTPS_PROXY=https://USERNAME:PASSWORD@10.0.0.1:8080/
    ```

## That modprobe script

It works on an "alternate" interface to load Linux kernel modules using `ip link show $module` rather than `modprobe` directly.  There's no privilege escalation in that it uses the same system call as `modprobe` does ([code](https://github.com/torvalds/linux/blob/v5.16/net/core/dev_ioctl.c#L425-L450) and [docs](https://man7.org/linux/man-pages/man7/capabilities.7.html)), but it does directly call `modprobe` on the container host therefore, needs to be a privileged container to begin with.  Docker uses this method to enable Docker-in-Docker as well ([source](https://github.com/docker-library/docker/blob/master/modprobe.sh))

## More on Docker-in-Docker

There is a whole discussion to be had on the ways you can enable Docker workloads (such as some GitHub Actions) within Kubernetes.  (I hope to expand this section)  Here's a few of the resources that might be helpful:

- The good, bad, and ugly of using Docker-in-Docker for CI [here](https://jpetazzo.github.io/2015/09/03/do-not-use-docker-in-docker-for-ci/), arguing that Docker socket bind mounts are better for quite a few use cases that you might use Docker-in-Docker for.
- Even more reading on using Docker-in-Docker for CI, arguing that for better isolation at scale, this is the better choice - [part 1](https://applatix.com/case-docker-docker-kubernetes-part/) and [part 2](https://applatix.com/case-docker-docker-kubernetes-part-2/).  This is the method chosen for the default in this project, as the problem it's designed to solve is to provide secure, enterprise compute for arbitrary tasks among co-tenanted "internal" projects.  It also allows "out of the box" support for some basic container orchestration through something like `docker compose`, so developers can run multi-container builds in their pod.
