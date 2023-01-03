# Multitenancy on OpenShift (GitHub Apps)

With a few changes we can leverage a single ARC controller-manager across multiple orgazations. A quick prereq is that the controller must be on 
version 0.26.0+. The initial advantage of this is no having the overhead of multiple controllers and crd's that need to be managed, being our of 
sync with multiple deployments causes issues with your runner deployments.

### Cert-Manager Installation
Prior to installing ARC, you will need to install and configure cert-manager, this can be done by installing the `cert-manager` operator from the Operator Hub. Once the operator is installed (using the defaults), we will need to setup the private CA cert & key.

1. Copy your ca.crt & ca.key files locally

2. Create a SECRET with these files in the openshift-operators namespace \
  `oc create secret tls ca-key-pair --cert=ca.crt --key=ca.key`

3. I chose to provide acces to the cluster by creating a kind ClusterIssuer
  ```
    kind: ClusterIssuer
    apiVersion: cert-manager.io/v1
    metadata:
      name: redcloud-clusterissuer
    spec:
      selfSigned:
        ca:
          secretName: ca-key-pair
```

## ARC to 0.26.0
1. If this is your initial deployment just instal 0.26.0 \
`kubectl replace --force -f https://github.com/actions/actions-runner-controller/releases/download/v0.26.0/actions-runner-controller.yam` \

    [Notes](#Troubleshooting) - If you are upgrading to multitenancy, you must remove all of your runnerdeployments and horizontalrunnerautoscale 
    deployments prior to upgrading. Not doing this could cause your reinstall to hang and fail. Additionaly, we use the "replace --force" to install the 
    controller on OCP or it'll complain _"metadata.annotations: Too long: must have at most 262144 bytes"


2. When deploying the solution for a GHES environment you need to provide an additional environment variable as part of the controller deployment \
`kubectl set env deploy controller-manager -c manager GITHUB_ENTERPRISE_URL=https://${YOUR_GHES_SERVER} --namespace actions-runner-system`

3. Set _privileged_ access \
`oc adm policy add-scc-to-user privileged -z default -n actions-runner-system`

4. Create a PAT using an Admin that has access to the orgs you'll be deploying ARC into. \
    admin:org, admin:org_hook, notifications, read:public_key, read:repo_hook, repo, workflow

5. Set the controller-manager secret using this PAT \
    `oc create secret generic controller-manager  --from-literal=github_token=${GITHUB_TOKEN}`

6. Each Organzation will require it's own GitHub App \
    Replace the ${PARTS} of the following URL with your GHES address & org name before opening it. 
    Then enter any unique name in the "GitHub App name" field, and hit the "Create GitHub App" button at the bottom of the page to create a GitHub App.

    `https://${YOUR_GHES_SERVER}/organizations/${YOUR_ORG}/settings/apps/new?url=http://github.com/actions/actions-runner-controller&webhook_active=false&public=false&administration=write&organization_self_hosted_runners=write&actions=read&checks=read`

    You will see an App ID on the page of the GitHub App you created as follows, the value of this App ID will be used later.

7. Download the private key file by pushing the "Generate a private key" button at the bottom of the GitHub App page. This file will also be used later.

8. Go to the "Install App" tab on the left side of the page and install the GitHub App that you created for your account or organization.

9. Register the App ID `${APP_ID}`, Installation ID `${INSTALLATION_ID}`, and the downloaded private key file `${PRIVATE_KEY_FILE_PATH}` to OpenShift as a secret.
    ```
    $ kubectl create secret generic org1-github-app \
        -n actions-runner-system \
        --from-literal=github_app_id=${APP_ID} \
        --from-literal=github_app_installation_id=${INSTALLATION_ID} \
        --from-file=github_app_private_key=${PRIVATE_KEY_FILE_PATH}
    ```
10. You'll now call out org1-github-app in your manifests for RunnerDeployment and HorizonalRunnerAutoscaler
      ```
      Example:
      ---
      kind: RunnerDeployment
      metadata:
        namespace: org1-runners
      spec:
        template:
          spec:
            githubAPICredentialsFrom:
              secretRef:
                name: org1-github-app
      ---
      kind: HorizontalRunnerAutoscaler
      metadata:
        namespace: org1-runners
      spec:
        githubAPICredentialsFrom:
          secretRef:
            name: org1-github-app
      ```
 👉 Repeat for each Org GitHub App (RunnerDeployment/HorizontalRunnerAutoscaler)
 

--------

## Troubleshooting
1. You upgraded to 0.26.0 without removing your deployments beforehand and the removal has hung.
    If your pods are in a 'Terminating' state, select the pod, switch to YAML and then remove finalizsers, save and move to the next pod. This should
    remove them one-by-one.
2. During the replace phase, your upgrade stops deleting CRD's.
    Search your CRD's for runners \
    `oc get crd | grep runner`
    Edit the CRD and remove the finalizers, when you save/exit the CRD will be removed and the install should complete.

