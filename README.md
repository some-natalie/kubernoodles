# Kubernoodles

Kubernetes runners for GitHub Actions, built on top of [actions-runner-controller](https://github.com/actions-runner-controller/actions-runner-controller).

This is a reference implementation, designed for you to take and tweak to your own liking.  I use this to test GitHub Actions on my personal account, [GitHub Enterprise Cloud](https://github.com) (SaaS), [GitHub Enterprise Server](https://docs.github.com/en/enterprise-server@latest) (self-hosted), and [GitHub AE](https://docs.github.com/en/github-ae@latest) from Docker Desktop, a Raspberry Pi cluster for `arm64`, and other random platforms as needed.  Your implementation may look wildly different, etc.

:question: Are you a GitHub Enterprise admin that's new to GitHub Actions?  Don't know how to set up self-hosted runners at scale?  Start [here](docs/admin-introduction.md)!

Pull requests welcome! :heart:

## Sources

These are all excellent reads and can provide more insight into the customization options and updates than are available in this repository.  This entire repository is mostly gluing a bunch of these other bits together and explaining how/why to make this your own.

- GitHub's official [documentation](https://docs.github.com/en/actions/hosting-your-own-runners) on hosting your own runners.
- Kubernetes controller for self-hosted runners, on [GitHub](https://github.com/actions-runner-controller/actions-runner-controller), is the glue that makes this entire solution possible.
- Docker image for runners that can automatically join, which solved a good bit of getting the runner agent started automatically on each pod, [write up](https://sanderknape.com/2020/03/self-hosted-github-actions-runner-kubernetes/) and [GitHub](https://github.com/SanderKnape/github-runner).
- GitHub's repository used to generate the hosted runners' images ([GitHub](https://github.com/actions/virtual-environments)), where I got the idea of using shell scripts to layer discrete dependency management on top of a base image.  The [software](../images/software) scripts are (mostly) copy/pasted directly out of that repo.

### Learn more

- Don't know what the whole Kubernetes thing is about?  Here's some help:
  - The [Kubernetes Aquarium](https://medium.com/@AnneLoVerso/the-kubernetes-aquarium-6a3d1d7a2afd)
  - The Cloud Native Computing Foundation's book, [The Illustrated Children's Guide to Kubernetes](https://www.cncf.io/phippy/the-childrens-illustrated-guide-to-kubernetes/)
  - The official [tutorial](https://kubernetes.io/docs/tutorials/kubernetes-basics/) covering the basics of what Kubernetes is and how it works
  - What helped me to understand this whole concept shift is to think that Kubernetes is to containers as KVM/vSphere/Hyper-V is to virtual machines.  It's probably not a perfect metaphor, but it helped. :smile:
- Want to see a whole bunch of other ways to solve this problem?  You should check out [Awesome Runners](https://jonico.github.io/awesome-runners) for a curated list and amazing matrix comparison of all sorts of other self-hosted runner solutions.

### Dependencies of note

- [actions-runner-controller](https://github.com/actions-runner-controller/actions-runner-controller)
- [cert-manager](https://cert-manager.io)
- [Helm](https://helm.sh/)
- [Yelp dumb-init](https://github.com/Yelp/dumb-init)
