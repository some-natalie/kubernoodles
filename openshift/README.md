# Multitenancy on OpenShift (Community Version)

With a few changes we can leverage a single ARC controller-manager across multiple orgazations. A quick prereq is that the controller must be on 
version 0.26.0+. The initial advantage of this is no having the overhead of multiple controllers and crd's that need to be managed, being our of 
sync with multiple deployments causes issues with your runner deployments.

### Cert-Manager Installation
Prior to installing ARC, it's highly recommended to install and configure cert-manager, this can be done by installing the `cert-manager` operator from the Operator Hub. Once the operator is installed (using the defaults), we will need to setup your Issuer. I've chosen to use the ClusterIssuer so it will apply to all namespaces.

1. Copy any private ca.crt & ca.key files locally, or configure for [ACME](https://cert-manager.io/docs/configuration/acme/).

2. Create a SECRET with these files in the openshift-operators namespace \
  `oc create secret tls ca-key-pair --cert=ca.crt --key=ca.key`

3. I chose to provide acces to the cluster by creating a kind ClusterIssuer
  ```
    kind: ClusterIssuer
    apiVersion: cert-manager.io/v1
    metadata:
      name: my-clusterissuer
    spec:
      selfSigned:
        ca:
          secretName: ca-key-pair
```

## ARC to 0.27.6
### Using PAT
1. If this is your initial deployment, install the ARC controller \
`oc create -f https://github.com/actions/actions-runner-controller/releases/download/v0.27.6/actions-runner-controller.yaml` \

    [Notes](#Troubleshooting) - If you are upgrading to multitenancy, you must remove all of your runnerdeployments and horizontalrunnerautoscaler 
    deployments prior to upgrading. Not doing this _could_ cause your reinstall to hang and fail. Additionaly, if your controller version complains _"metadata.annotations: Too long: must have at most 262144 bytes"_ then use `kubectl replace --force -f https...` instead of the `oc` command above.

3. When deploying the solution for a GHES environment you need to provide an additional environment variable as part of the controller deployment \
`oc -n actions-runner-system set env deploy controller-manager -c manager GITHUB_ENTERPRISE_URL=https://${YOUR_GHES_SERVER}`

4. In this example, we'll set _privileged_ & _anyuid_ access \
`oc adm policy add-scc-to-user privileged -z default -n actions-runner-system`
`oc adm policy add-scc-to-user anyuid -z default -n actions-runner-system`

Note: If you deploy runners in other (!= actions-runner-system) projects/namespaces, you will need to do step 4 in those namespaces to provide access to the 'default' service account. Alternatively, you can you may managed your own SCC and SA for improved RBAC (out-of-scope).

6. Since we'll use 1 controller for all of our jobs, we'll deploy it using a Personal Access Token. Create a PAT using an Admin that has access to the orgs you'll be deploying ARC into. \
    admin:org, admin:org_hook, notifications, read:public_key, read:repo_hook, repo, workflow

7. Set the controller-manager secret using this PAT \
    `oc -n actions-runner-system  create secret generic controller-manager  --from-literal=github_token=${GITHUB_TOKEN}`
   
### Using GitHub Apps

1. Optionally, if you want a spepart controller-manager & namespace for each Organzation (runner group), it will require it's own GitHub App \
    Replace the ${PARTS} of the following URL with your GHES address & Org name before opening it in your browser. 
    Then enter any unique name in the "GitHub App name" field, and hit the "Create GitHub App" button at the bottom of the page to create a GitHub App.

    `https://${YOUR_GHES_SERVER}/organizations/${YOUR_ORG}/settings/apps/new?url=http://github.com/actions/actions-runner-controller&webhook_active=false&public=false&administration=write&organization_self_hosted_runners=write&actions=read&checks=read`

    You will see an App ID on the page of the GitHub App you created as follows, the value of this App ID will be used later.

2. Download the private key file by pushing the "Generate a private key" button at the bottom of the GitHub App page. This file will also be used later.

3. Go to the "Install App" tab on the left side of the page and install the GitHub App that you created for your account or organization.

4. Register the App ID `${APP_ID}`, Installation ID `${INSTALLATION_ID}`, and the downloaded private key file `${PRIVATE_KEY_FILE_PATH}` to OpenShift as a secret.
    ```
    $ kubectl create secret generic org1-github-app \
        -n actions-runner-system \
        --from-literal=github_app_id=${APP_ID} \
        --from-literal=github_app_installation_id=${INSTALLATION_ID} \
        --from-file=github_app_private_key=${PRIVATE_KEY_FILE_PATH}
    ```

### Running the deployments - see [manifests](./manifests) for more examples
13. You'll now call out org1-github-app in your manifests for RunnerDeployment and HorizonalRunnerAutoscaler
      ```
      Example:
      ---
      kind: RunnerDeployment
      metadata:
        name: example-runner
      spec:
        template:
          spec:
            githubAPICredentialsFrom:
              secretRef:
                name: org1-github-app
      ---
      kind: HorizontalRunnerAutoscaler
      metadata:
        name: example-runner-hra
      spec:
        githubAPICredentialsFrom:
          secretRef:
            name: org1-github-app
      ```
 👉 Repeat for each deployment (RunnerDeployment/HorizontalRunnerAutoscaler)
 

--------

## Troubleshooting
1. You upgraded to 0.26.0 without removing your deployments beforehand and the removal has hung.
    If your pods are in a 'Terminating' state, select the pod, switch to YAML and then remove finalizers, save and move to the next pod. This should remove them one-by-one.
2. During the replace phase, your upgrade stops deleting CRD's.
    Search your CRD's for runners \
    `oc get crd | grep runner`
    Edit the CRD and remove the finalizers, when you save/exit the CRD will be removed and the install should complete.

