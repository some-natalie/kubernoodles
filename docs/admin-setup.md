# Setup guide

Ready to set up some kubernoodles?

## Pre-requisites

You'll need a Kubernetes cluster already set up that GitHub can use.  If you don't have one, or are just testing this out, try out [Docker Desktop](https://www.docker.com/products/docker-desktop).  It can create a local Kubernetes cluster with a few clicks to get you on your way.

Additionally, for **GitHub Enterprise Server**, you will need the following:

- GitHub Enterprise Server 3.3 or later
- [Actions](https://docs.github.com/en/enterprise-server@latest/admin/github-actions/enabling-github-actions-for-github-enterprise-server) and [Packages](https://docs.github.com/en/enterprise-server@latest/admin/packages) are already set up and enabled

:information_source:  While Actions shipped in GHES 3.0, the later versions of actions-runner-controller specify that 3.3 is their minimum supported version.  You may, if needed, want to move to an earlier version of actions-runner-controller.  Upgrading to a later version of GHES is the better option though. :-)

Here are the credentials we'll be generating for enterprise-wide runners:

- A GitHub PAT with _only_ the `admin:enterprise` scope (for enterprise-wide runners)
- A GitHub PAT (or credentials for an alternative container registry) to pull the runner containers from the registry (in this case, we're using GitHub Packages)

## Directions

1. Install [Helm](https://helm.sh) to manage Kubernetes software.

    ```shell
    curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3
    sudo bash get_helm.sh
    ```

1. Install [cert-manager](https://cert-manager.io) to generate and manage certificates.

    ```shell
    kubectl create namespace cert-manager
    helm repo add jetstack https://charts.jetstack.io
    helm repo update
    helm install cert-manager jetstack/cert-manager --namespace cert-manager --version v1.9.1 --set installCRDs=true
    ```

1. Install [actions-runner-controller](https://github.com/actions-runner-controller/actions-runner-controller).

    ```shell
    kubectl create namespace actions-runner-system
    helm repo add actions-runner-controller https://actions-runner-controller.github.io/actions-runner-controller
    helm repo update
    helm install -n actions-runner-system actions-runner-controller actions-runner-controller/actions-runner-controller --version=0.20.2
    ```

1. Set the GitHub Enterprise URL, needed only for GitHub Enterprise Server or GitHub AE.

    ```shell
    kubectl set env deploy actions-runner-controller -c manager GITHUB_ENTERPRISE_URL=https://YOUR-GHE-URL --namespace actions-runner-system
    ```

1. Set a [personal access token](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/creating-a-personal-access-token) for the runner controller to use.

    ```shell
    kubectl create secret generic controller-manager -n actions-runner-system --from-literal=github_token=TOKEN-GOES-HERE
    ```

    :information_source: A personal access token with only the `admin:enterprise` scope is needed for enterprise-wide runner availability.  There is a _ton_ of other ways to authenticate, detailed [here](https://github.com/actions-runner-controller/actions-runner-controller#setting-up-authentication-with-github-api).

1. Create namespaces for the runners, one for production users and another (optionally) for testing the runners prior to making them available to users.

    ```shell
    kubectl create namespace runners
    kubectl create namespace test-runners
    ```

1. Now give each namespace you created the login to the private registry that hosts the image used as a runner.

    ```shell
    kubectl create secret docker-registry ghe -n runners --docker-server=https://docker.YOUR-GHE-URL --docker-username=SOME-USERNAME --docker-password=PAT-FOR-SOME-USERNAME --docker-email=EMAIL@GOES.HERE
    ```

    :information_source:  In this case, we're using GitHub Packages on your instance of Enterprise Server or GitHub AE, but it doesn't _need_ to be that if your company has another registry already in place.  This repository and the testing that's done all use the public images available in this repository.

1. Now deploy one of the [deployments](../deployments), after editing it to attach to the correct enterprise/organization/repo, give it the appropriate resources you'd like, and use the desired image.

    ```shell
    kubectl apply -f ubuntu-focal.yml
    ```

:tada:  Now enjoy an awesome automation experience! :tada:
