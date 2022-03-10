# Kubernoodles

Kubernetes runners for GitHub Actions, built on top of [actions-runner-controller](https://github.com/actions-runner-controller/actions-runner-controller).

This is a reference implementation, designed for you to take and tweak to your own liking.  I use this to test GitHub Actions on my personal account, [GitHub Enterprise Cloud](https://github.com) (SaaS), [GitHub Enterprise Server](https://docs.github.com/en/enterprise-server) (self-hosted), and [GitHub AE](https://docs.github.com/en/github-ae@latest) from Docker Desktop, a Raspberry Pi cluster for `arm64`, and other random platforms as needed.  Your implementation may look wildly different, etc.

Pull requests welcome! :heart:

## Sources

You should read these, as they're all excellent and can provide more insight into the customization options and updates than are available in this repository.

- Kubernetes controller for self-hosted runners, on [GitHub](https://github.com/actions-runner-controller/actions-runner-controller), is the glue that makes this entire solution possible.
- Docker image for runners that can automatically join, which solved a good bit of getting the runner agent started automatically on each pod, [write up](https://sanderknape.com/2020/03/self-hosted-github-actions-runner-kubernetes/) and [GitHub](https://github.com/SanderKnape/github-runner).
- GitHub's repository used to generate the hosted runners' images ([GitHub](https://github.com/actions/virtual-environments)), where I got the idea of using shell scripts to layer discrete dependency management on top of a base image.  The [software](../images/software) scripts are (mostly) copy/pasted directly out of that repo.

### Learn more

- Don't know what the whole Kubernetes thing is about?  Here's some help:
  - The [Kubernetes Aquarium](https://medium.com/@AnneLoVerso/the-kubernetes-aquarium-6a3d1d7a2afd)
  - The Cloud Native Computing Foundation's book, [The Illustrated Children's Guide to Kubernetes](https://www.cncf.io/phippy/the-childrens-illustrated-guide-to-kubernetes/)
  - What helped me to understand this whole concept shift is to think that Kubernetes is to containers as KVM/vSphere/Hyper-V is to virtual machines.  It's probably not a perfect metaphor, but it helped. :smile:

### Dependencies of note

- [actions-runner-controller](https://github.com/actions-runner-controller/actions-runner-controller)
- [cert-manager](cert-manager.io)
- [Yelp dumb-init](https://github.com/Yelp/dumb-init)
