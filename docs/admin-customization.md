# Quick guide to customizing your images

There are a couple images in the [images](../images/) folder that can be used as-is if you'd like.  It's likely that some customization will need to happen over time and that's great!  Here's how to do that:

## Types of enterprise-y customizations

There are a few types of customizations you can use within these runners.

1. Adding software directly to the runner image.  This adds to the size of the image, but should make it faster to execute the job.  You can do this either by adding it to the appropriate `Dockerfile` line to install the default OS package (like [this](../images/ubuntu-focal.Dockerfile#L35)), or by creating a [script](../images/software/) and copying it to run within the `Dockerfile` at build time (like [this](../images/ubuntu-focal.Dockerfile#L67)).
1. Adding environment variables, such as a custom proxy setups or package registries.  By default, these images use an [`.env`](../images/.env) file that's loaded when the image starts.
1. Customizing the [deployments](../deployments/) changes the type of runners available to the users and if/how they scale.  The standards and options available in these files is controlled by [actions-runner-controller](https://github.com/actions-runner-controller/actions-runner-controller)
1. Changing the labels on the runners allows your users to target specific deployments, so that their jobs only run on Ubuntu runners, for instance.  Read more about this [here](https://docs.github.com/en/enterprise-cloud@latest/actions/hosting-your-own-runners/using-labels-with-self-hosted-runners).
1. Adding or editing the [enterprise allowlist](https://docs.github.com/en/enterprise-cloud@latest/admin/github-actions/getting-started-with-github-actions-for-your-enterprise/introducing-github-actions-to-your-enterprise) will change what's available from the [Actions marketplace](https://github.com/marketplace?type=actions) to your users.  Read more about the considerations [here](https://docs.github.com/en/enterprise-cloud@latest/actions/security-guides/security-hardening-for-github-actions#using-third-party-actions).

## Other things to think about

These images are assumed to be tagged by release, so they should stay reasonably consistent.  You can, if you choose, only use `latest` to tag your images and deploy them - but there are a lot of reasons this is a [bad idea](https://kubernetes.io/docs/concepts/configuration/overview/#using-labels).  While it's fine for testing, it makes it difficult to track what's deployed into production and hard to roll back changes.

As the images get customized to meet user needs, the version can/should change over time.

Here's a great [hands-on lab](https://lab.github.com/githubtraining/create-a-release-based-workflow) to learn how to get started using release-based workflows.
