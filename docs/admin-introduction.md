# Admin's (draft) guide to implementing self-hosted GitHub Actions

## Introduction

Audience - GitHub Enterprise administrators wanting to self-host compute for GitHub Actions, especially for [Enterprise Server](https://docs.github.com/en/enterprise-server@latest) (self-hosted) or [GitHub AE](https://docs.github.com/en/github-ae@latest) (dedicated, isolated SaaS).  The guidance changes some depending on which product, so any differences will be noted.  If you're not one of those, you're still welcome!  You might find helpful tips and tricks nonetheless.  :tada:

This piece is going to take a look at what this feature is and a quick overview of how it works, then go through some key decisions you should think through as you set it up.  A bunch of experience running this at scale went into this project, and opinions from that experience is noted in the last paragraph of each key decision on _why_ this problem is approached the way it is in this solution.

We're _not_ covering the details of which Enterprise version you should be on or any future roadmap items.  If that's of interest, reach out to the friendly [Sales](https://github.com/enterprise/contact) or [Support](https://enterprise.github.com/support) teams.

### What's GitHub Actions?

Glad you asked!  You can learn all about it [here](https://docs.github.com/en/actions), but the tl;dr awesome video version is in [this YouTube video](https://www.youtube.com/watch?v=cP0I9w2coGU).  It's a tool that can be used to automate all sorts of other stuff done manually or locally, like:

- Regression testing
- Deploying software
- Linting code
- Running security tools
- Git branch management and other chores
- Reward users with cat gifs (no, [really](https://github.com/ruairidhwm/action-cats))
- Close stale issues and pull requests ([link](https://github.com/actions/stale))
- Integrate with pretty much any other thing that could ever possibly use GitHub
- ... and a lot more ...

There's a whole [marketplace](https://github.com/marketplace?type=actions) full of building blocks of automation to use - over 12,000 of them as of March 2022.  You can also [create your own](https://docs.github.com/en/actions/creating-actions) to further help robots do all the work.

### Why self-hosted?

GitHub provides hosted, managed runners that you can use out of the box - but only for users within GitHub.com.  Information on features, hardware specs, and pricing for this compute can be found [here](https://docs.github.com/en/enterprise-cloud@latest/actions/using-github-hosted-runners/about-github-hosted-runners).  They're super easy to use and offer a wide variety of software built-in, which can be customized as detailed [here](https://docs.github.com/en/enterprise-cloud@latest/actions/using-github-hosted-runners/customizing-github-hosted-runners).  While great, the managed runners don't fit everyone's use case, so bring-your-own compute is also fully supported.  It's a straightforward process to install the [runner agent](https://github.com/actions/runner) on the compute needed.  Common reasons for choosing self-hosted runners include:

- Custom hardware (like ARM processors or GPU-focused compute)
- Custom software beyond what's available or installable in the hosted runners
- You don't have the option to use the GitHub-managed runners because you are on [GitHub Enterprise Server](https://docs.github.com/en/enterprise-server@latest) or [GitHub AE](https://docs.github.com/en/github-ae@latest).
- Firewall rules to access stuff won't allow access to/from whatever it is you need to do
- Needing to run jobs in a specific environment such as "gold load" type imaged machines
- Because you _want_ to and I'm not here to judge that :)

This means that you, intrepid Enterprise administrator, are responsible for setting up and maintaining the compute needed for this service.  The [documentation](https://docs.github.com/en/actions/hosting-your-own-runners) to do this is fantastic.  If you're used to running your own enterprise-wide CI system, GitHub Actions is probably easier than it seems.  If you aren't, or are starting from scratch, it can be a bit daunting.  That's where this guide comes in.  The next section is all about some key decisions to make that will determine how to set up self-hosted compute for GitHub Actions.

---

## Key decisions

### Scaling

How do you want or need to scale up?  By using the runners provided by GitHub, this is handled invisibly to users without any additional fiddling.  Self-hosted runners don't have the same "magic hardware budgeting" out of the box.  Some things to keep in mind:

- **GitHub Actions are parallel by default.**  This means that unless you specify "this job depends on that job", they'll both run at the same time ([link](https://docs.github.com/en/actions/using-workflows/advanced-workflow-features#creating-dependent-jobs)).  Jobs will wait in queue if there are no runners available.  The balance to search for here is minimizing job wait time on users without having a ton of extra compute hanging out idle.  Regardless of if you're using a managed cloud provider or bare metal, efficient capacity management governs infrastructure costs.
- **Users can have multiple tasks kick off simultaneously.**  GitHub Actions is event-driven, meaning that one event can start several processes.  For example, by opening a pull request targeting the main branch, that user is proposing changes into what could be "production" code.  This can and should start some reviews.  Good examples of things that can start at this time include regression testing, security testing, code quality analysis, pinging reviewers in chat, update the project management tool, etc.  These can, but don't necessarily _need_ to, run in parallel.  By encouraging small changes more often, these should run fairly quickly and frequently too, resulting in a faster feedback loop between development and deployment.  However, it means that your usage can appear a bit "peaky" during work hours, with flexibility in job queuing.
- **GitHub Actions encourages use beyond your legacy CI system.**  It can do more with less code defining your pipeline, users can provide all sorts of additional things for it to do, and it can even run scheduled shell scripts and other operations-centric tasks.  These are all great things, but a project that used X minutes of runtime on Y platform may not linearly translate to the same usage in GitHub Actions.
- **Migrating to GitHub Actions can be a gradual transition.**  The corollary to above is that while the end state may be more compute than right now, it's a process to get a project to migrate from one system to another and then to grow their usage over time as a project grows.  Without external pressure like "we're turning off the old system on this date", it'll take a while for users to move themselves.  Use this to your advantage to scale your infrastructure if you have long-lead tasks such as provisioning new servers or appropriating budget.

:information_desk_person: **Opinion** - This is one of those cases where the balance between infrastructure costs and the time a user will spend waiting for a runner to pick up a job can really swing how they perceive the service.  I went with Kubernetes to provide fast scaling of variable-spec compute on a wide variety of platforms.  In the [example deployment](../deployments/README.md), each pod starts out pretty small, but can scale to a maximum size as needed.  This means small tasks get small compute and bigger tasks (such as code security scans) will get bigger compute.  The downside of the choice to use Kubernetes is that it's more complicated than other platform options, detailed in the next section.

### Platform

What platform do you want to run on?  The runner agent for GitHub Actions works in modern versions of Mac OS, Windows, and most major distributions of Linux.  This leaves a lot of flexibility for what the platform to offer to your userbase looks like.  The diagram below offers an overview of the options to consider.

![Deployment options](https://d33wubrfki0l68.cloudfront.net/26a177ede4d7b032362289c6fccd448fc4a91174/eb693/images/docs/container_evolution.svg)

**Bare metal** comes with the upside of simpler management for end-user software licenses or supporting specialized hardware.  In a diverse enterprise user base, there is always a project or two that needs a GPU cluster or specialized Mac hardware to their organization or repository.  Supporting this as an enterprise edge case is a good choice.  However, it comes with the cost of owning and operating the hardware 24/7 even if it isn't in use that entire time.  Since one runner agent corresponds to one job, an agent on a beefy machine will still only run one job to completion before picking up the next one.  If the workloads are primarily targeted to the hardware provided, this isn't a problem, but it can be inefficient at an enterprise scale.

**Virtual machines** are simple to manage using a wide variety of existing enterprise tooling at all stages of their lifecycle.  They can be as isolated or shared across users as you'd like.  Each runner is another VM to manage that isn't fundamentally different than existing CI build agents, web or database servers, etc.  There are some community options to scale them up or down as needed, such as [Terraform](https://github.com/philips-labs/terraform-aws-github-runner) or [Ansible](https://github.com/MonolithProjects/ansible-github_actions_runner), if that's desired.  The hypervisor that manages the VM infrastructure handles resource allocation in the datacenter or it's magically handled by a private cloud provider such as Azure or AWS.

**Kubernetes** provides a scalable and reproducible environment for containerized workloads.  It's declarative deployments and the ephemeral nature of the pods used as runner agents creates less "works on this agent and not that one" by not having the time for configuration to drift.  There are a lot of advantages to using Kubernetes (outlined [here](https://kubernetes.io/docs/concepts/overview/what-is-kubernetes/)), but it is more complicated and less widely-understood than the other options.  A managed provider makes this much simpler to run at scale.

:information_source:  Some GitHub Actions ship as Dockerfiles, meaning the workload builds and runs in the container it defines.  Whichever path is chosen here, a container runtime should be part of the solution if these jobs are required.  This could mean Docker-in-Docker, which this solution fully supports, for Kubernetes-based solutions.

:information_desk_person: **Opinion** - Whatever is currently in use is probably the best path forward.  I hesitate to recommend a total infrastructure rebuild for a few more servers in racks, or VMs, or container deployments.  Managed providers of VM infrastructure or Kubernetes clusters take away the hardware management aspect of this.  This solution relies on Kubernetes and the [actions-runner-controller](https://github.com/actions-runner-controller/actions-runner-controller) community project.

### Persistence

How persistent or transient do you want the environment that is building the code to be?  Should the state of one random job that runs on this machine/container affect any other random job?

There's a lot to unpack here, so here's a helpful analogy:

> A build environment is like a kitchen.  You can make all sorts of food in a kitchen, not just the one dish that you want at any given time.  If it's just you and some reasonable roommates, you can all agree to a shared standard of cleanliness.  The moment one unreasonable houseguest cooks for the team and leaves a mess, it's a bunch of work to get things back in order (broken builds).  There could also be food safety issues (code safety issues) when things are left to get fuzzy and gross.
>
> Imagine being able to snap your fingers and get a brand new identical kitchen at every meal - that's the power of ephemeral build environments.  Now imagine being able to track changes to those tools in that kitchen to ensure the knives are sharp and produce is fresh - that's putting your build environment in some sort of infrastructure-as-code solution.

The persistence here is somewhat independent of the platform chosen.  Bare metal ephemeral runners are possible, but may require more effort than a solution based on virtual machines or containers.  The _exact_ way this gets implemented depends a lot on the other parts and pieces of your unique platform.

:information_desk_person: **Opinion** - The more ephemeral and version-controlled, the better!  This solution uses containers that are used once, then redeployed from the specified container in a registry.  In my experience, persistent environments tend to work alright for single projects and start to have problems when the project needs change.  Persistence leads to configuration drift even with the best config management practices, meaning that "it works on my machine" and the work required to maintain everything doesn't always happen.

### Compute design

This decision depends a lot on how persistent or ephemeral the compute is and the particulars of the environment it lives in, but the goal here is to figure out how large or lean the environment is at runtime.

- **Larger environments with lots of pre-loaded software decrease job execution time.**  As the user base grows in size and diversity of needs (languages, tools, frameworks, etc.), having the more common things installed in the "base" image allows for faster job execution.  If the compute is discarded and rebuilt after each job, this comes at the expense of bandwidth between the compute and the container registry, storage server, or wherever the "base" image comes from.
- **Persistent environments can have conflicting update needs.**  When there's more software to manage, there's a bigger chance that updates conflict or configuration can drift.  That doesn't mean this isn't the right choice for some projects, such as projects that need software that isn't able to be licensed in a non-persistent state.  This can be mitigated somewhat by having persistent compute scoped to only the project(s) that need it.
- **Larger environments with lots of pre-loaded software increases vulnerability area.**  If you're scanning the build environment, there's more things for it to alarm on in larger images.  The validity of these alarms may vary based on tools used, software installed, etc.
- **Smaller ephemeral images that consistently pull in dependencies at setup increases bandwidth use.**  A job that installs build dependencies every time it runs will download those every time.  This isn't necessarily a bad thing, but keep in mind your upstream software sources (such as package registries) may rate-limit the entire source IP, which affects every project in use and not just the offending project.  There are ways to mitigate this, including the use of a caching proxy or private registry.

:information_desk_person: **Opinion** - This isn't a binary choice and can always change as the project/enterprise needs change.  I wouldn't spend too much time on this, but have tended to prefer larger images with more things in them to minimize traffic out of the corporate network at the cost of bandwidth between the Kubernetes cluster and the private image registry that hosts the container images.

### Compute scope

GitHub Enterprise can have runners that are only available to an individual repository, all or select repositories within an organization, or enterprise-wide (detailed [here](https://docs.github.com/en/enterprise-server@latest/actions/hosting-your-own-runners/about-self-hosted-runners)).  What is the ideal state for your company?

:information_desk_person: **Opinion** - All of the above is likely going to happen with any sufficiently diverse user base, so let's make this as secure and easily governable as needed.  Some teams will bring their own hardware and not want to share, which is reasonable, so will join their compute to only accept jobs from their code repositories.  This also means that admins can do some networking shenanigans to allow only runners from X subnet to reach Y addresses to meet rules around isolation if needed.  Likewise, as an enterprise-wide administrator, I wanted to make the most commonly-used Linux compute available and usable to most users for most jobs.  This solution defaults to enterprise-wide availability, but will also demonstrate organization or repository specific compute.

### Policy and compliance

Is there any policy you need to consider while building this out?  Examples could be scan your containers/VMs/bare metal machines with some security tool, to have no critical vulnerabilities in production, project isolation, standards from an industry body or government, etc.

:information_desk_person: **Opinion** - I don't know all the policies everywhere at all times, but I've always found it very helpful to gather these requirements up front and keep them in mind.  When possible, I'll highlight security guidance.

---

## Recommendations

Here's a few general recommendations that don't fall neatly into the above, but were learned from experience:

- Don't underestimate the power of enterprise-wide availability to drive adoption among users.  Just like it's easy to use the GitHub-hosted compute, having a smooth and simple onboarding experience is great.  Offering compute to users is a great "carrot" to keep shadow IT assets to a minimum.
- "Why not both?" is usually a decent answer.  Once you get the hang of creating images and deployments for unique pools of containerized runners, it becomes low-effort to enable more distinct projects.
- Ephemeral compute is great and even better when you have diverse users/workloads.  Each job gets a fresh environment, so no configuration drift or other software maintenance weirdness that develops over time.
- Docker-in-Docker for Kubernetes is hard, but valuable.  It enables containerized workflows for GitHub Actions, so no one is "left out" or needs to check if this type of runner supports that type of Action.  It's a better user experience.  This solution includes it by default.
- Ship your logs somewhere.  You can view job logs in GitHub and that's handy for developers to troubleshoot their stuff, but it's hard to see trends at scale there.  We'll talk about this more in a later writeup.
- Everything is made better by a managed provider and Kubernetes doubly so.  Kubernetes is super powerful and very extensible, but I wouldn't call it easy for anyone to pick up and DIY.
- Have a central-ish place for users to look for information.  This could be wherever the rest of the documentation for your company lives.  In this case, this repository has a [`README.md`](../README.md) file and uses documentation in the repository.

---

## Next steps

:boom: Ready for some scalable, Kubernetes-based ephemeral runners for GitHub Actions?  Let's move to the [setup](admin-setup.md) guide!
