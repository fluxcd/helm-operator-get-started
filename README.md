# Managing Helm releases the GitOps way

**What is GitOps?**

GitOps is a way to do Continuous Delivery, it works by using Git as a source of truth for declarative infrastructure and workloads.
For Kubernetes this means using `git push` instead of `kubectl create/apply` or `helm install/upgrade`.

In a traditional CICD pipeline, CD is an implementation extension powered by the
continuous integration tooling to promote build artifacts to production.
In the GitOps pipeline model, any change to production must be committed in source control
(preferable via a pull request) prior to being applied on the cluster.
This way rollback and audit logs are provided by Git.
If the entire production state is under version control and described in a single Git repository, when disaster strikes,
the whole infrastructure can be quickly restored from that repository.

To better understand the benefits of this approach to CD and what the differences between GitOps and
Infrastructure-as-Code tools are, head to the Weaveworks website and read [GitOps - What you need to know](https://www.weave.works/technologies/gitops/) article.

In order to apply the GitOps pipeline model to Kubernetes you need three things:

* a Git repository with your workloads definitions in YAML format, Helm charts and any other Kubernetes custom resource that defines your cluster desired state (I will refer to this as the *config* repository)
* a container registry where your CI system pushes immutable images (no *latest* tags, use *semantic versioning* or git *commit sha*)
* an operator that runs in your cluster and does a two-way synchronization:
    * watches the registry for new image releases and based on deployment policies updates the workload definitions with the new image tag and commits the changes to the config repository
    * watches for changes in the config repository and applies them to your cluster

I will be using GitHub to host the config repo, Docker Hub as the container registry and Flux as the GitOps Kubernetes Operator.

![gitops](https://github.com/fluxcd/helm-operator-get-started/blob/master/diagrams/flux-helm-operator-registry.png)

### Prerequisites

You'll need a Kubernetes cluster v1.11 or newer, a GitHub account, git and kubectl installed locally.

Install Helm v3 and fluxctl for macOS with Homebrew:

```sh
brew install helm fluxctl
```

On Windows you can use Chocolatey:

```sh
choco install kubernetes-helm fluxctl
```

On Linux you can download the [helm](https://github.com/helm/helm/releases)
and [fluxctl](https://github.com/fluxcd/flux/releases) binaries from GitHub.

### Install Flux

The first step in automating Helm releases with [Flux](https://github.com/fluxcd/flux) is to create a Git repository with your charts source code.

On GitHub, fork this repository and clone it locally
(replace `fluxcd` with your GitHub username): 

```sh
git clone https://github.com/fluxcd/helm-operator-get-started
cd helm-operator-get-started
```

*If you fork, update the release definitions with your Docker Hub repository and GitHub username located in
\releases\(dev/stg/prod)\podinfo.yaml in your master branch before proceeding.

Add FluxCD repository to Helm repos:

```bash
helm repo add fluxcd https://charts.fluxcd.io
```

Create the `fluxcd` namespace:

```sh
kubectl create ns fluxcd
```

Install Flux by specifying your fork URL (replace `fluxcd` with your GitHub username): 

```bash
helm upgrade -i flux fluxcd/flux --wait \
--namespace fluxcd \
--set git.url=git@github.com:fluxcd/helm-operator-get-started
```

Install the `HelmRelease` Kubernetes custom resource definition:

```sh
kubectl apply -f https://raw.githubusercontent.com/fluxcd/helm-operator/master/deploy/crds.yaml
```

Install Flux Helm Operator with ***Helm v3*** support:

```bash
helm upgrade -i helm-operator fluxcd/helm-operator --wait \
--namespace fluxcd \
--set git.ssh.secretName=flux-git-deploy \
--set helm.versions=v3
```

The Flux Helm operator provides an extension to Flux that automates Helm Chart releases for it.
A Chart release is described through a Kubernetes custom resource named HelmRelease.
The Flux daemon synchronizes these resources from git to the cluster,
and the Flux Helm operator makes sure Helm charts are released as specified in the resources.

Note that Flux Helm Operator works with Kubernetes 1.11 or newer.

At startup, Flux generates a SSH key and logs the public key. Find the public key with:

```bash
fluxctl identity --k8s-fwd-ns fluxcd
```

In order to sync your cluster state with Git you need to copy the public key and
create a **deploy key** with **write access** on your GitHub repository.

Open GitHub, navigate to your fork, go to _Setting > Deploy keys_ click on _Add deploy key_, check
_Allow write access_, paste the Flux public key and click _Add key_.

### GitOps pipeline example

The config repo has the following structure:

```
├── charts
│   └── podinfo
│       ├── Chart.yaml
│       ├── README.md
│       ├── templates
│       └── values.yaml
├── hack
│   ├── Dockerfile.ci
│   └── ci-mock.sh
├── namespaces
│   ├── dev.yaml
│   └── stg.yaml
└── releases
    ├── dev
    │   └── podinfo.yaml
    └── stg
        └── podinfo.yaml
```

I will be using [podinfo](https://github.com/stefanprodan/podinfo) to demonstrate a full CI/CD pipeline including promoting releases between environments.

I'm assuming the following Git branching model:
* dev branch (feature-ready state)
* stg branch (release-candidate state)
* master branch (production-ready state)

When a PR is merged in the dev or stg branch will produce a immutable container image as in `repo/app:branch-commitsha`.

Inside the *hack* dir you can find a script that simulates the CI process for dev and stg.
The *ci-mock.sh* script does the following:
* pulls the podinfo source code from GitHub
* generates a random string and modifies the code
* generates a random Git commit short SHA
* builds a Docker image with the format: `yourname/podinfo:branch-sha`
* pushes the image to Docker Hub

Let's create an image corresponding to the `dev` branch (replace `stefanprodan` with your Docker Hub username):

```
$ cd hack && ./ci-mock.sh -r stefanprodan/podinfo -b dev

Sending build context to Docker daemon  4.096kB
Step 1/15 : FROM golang:1.13 as builder
....
Step 9/15 : FROM alpine:3.10
....
Step 12/15 : COPY --from=builder /go/src/github.com/stefanprodan/k8s-podinfo/podinfo .
....
Step 15/15 : CMD ["./podinfo"]
....
Successfully built 71bee4549fb2
Successfully tagged stefanprodan/podinfo:dev-kb9lm91e
The push refers to repository [docker.io/stefanprodan/podinfo]
36ced78d2ca2: Pushed
```

Inside the *charts* directory there is a podinfo Helm chart.
Using this chart I want to create a release in the `dev` namespace with the image I've just published to Docker Hub.
Instead of editing the `values.yaml` from the chart source, I create a `HelmRelease` definition (located in /releases/dev/podinfo.yaml):

```yaml
apiVersion: helm.fluxcd.io/v1
kind: HelmRelease
metadata:
  name: podinfo-dev
  namespace: dev
  annotations:
    fluxcd.io/automated: "true"
    filter.fluxcd.io/chart-image: glob:dev-*
spec:
  releaseName: podinfo-dev
  chart:
    git: git@github.com:fluxcd/helm-operator-get-started
    path: charts/podinfo
    ref: master
  values:
    image:
      repository: stefanprodan/podinfo
      tag: dev-kb9lm91e
    replicaCount: 1
```

Flux Helm release fields:

* `metadata.name` is mandatory and needs to follow Kubernetes naming conventions
* `metadata.namespace` is optional and determines where the release is created
* `spec.releaseName` is optional and if not provided the release name will be $namespace-$name
* `spec.chart.path` is the directory containing the chart, given relative to the repository root
* `spec.values` are user customizations of default parameter values from the chart itself

The options specified in the HelmRelease `spec.values` will override the ones in `values.yaml` from the chart source.

With the `fluxcd.io/automated` annotations I instruct Flux to automate this release.
When a new tag with the prefix `dev` is pushed to Docker Hub, Flux will update the image field in the yaml file,
will commit and push the change to Git and finally will apply the change on the cluster.

![gitops-automation](https://github.com/stefanprodan/openfaas-flux/blob/master/docs/screens/flux-helm-image-update.png)

When the `podinfo-dev` HelmRelease object changes inside the cluster,
Kubernetes API will notify the Flux Helm Operator and the operator will perform a Helm release upgrade.

```
$ helm -n dev history podinfo-dev

REVISION	STATUS    	CHART        	DESCRIPTION
1       	superseded	podinfo-0.2.0	Install complete
2       	deployed  	podinfo-0.2.0	Upgrade complete
```

The Flux Helm Operator reacts to changes in the HelmRelease collection but will also detect changes in the charts source files.
If I make a change to the podinfo chart, the operator will pick that up and run an upgrade.

![gitops-chart-change](https://github.com/stefanprodan/openfaas-flux/blob/master/docs/screens/flux-helm-chart-update.png)

```
$ helm -n dev history podinfo-dev

REVISION	STATUS    	CHART        	DESCRIPTION
1       	superseded	podinfo-0.2.0	Install complete
2       	superseded	podinfo-0.2.0	Upgrade complete
3       	deployed  	podinfo-0.2.1	Upgrade complete
```

Now let's assume that I want to promote the code from the `dev` branch into a more stable environment for others to test it.
I would create a release candidate by merging the podinfo code from `dev` into the `stg` branch.
The CI would kick in and publish a new image:

```bash
$ cd hack && ./ci-mock.sh -r stefanprodan/podinfo -b stg

Successfully tagged stefanprodan/podinfo:stg-9ij63o4c
The push refers to repository [docker.io/stefanprodan/podinfo]
8f21c3669055: Pushed
```

Assuming the staging environment has some sort of automated load testing in place,
I want to have a different configuration than dev:

```yaml
apiVersion: helm.fluxcd.io/v1
kind: HelmRelease
metadata:
  name: podinfo-rc
  namespace: stg
  annotations:
    fluxcd.io/automated: "true"
    filter.fluxcd.io/chart-image: glob:stg-*
spec:
  releaseName: podinfo-rc
  chart:
    git: git@github.com:fluxcd/helm-operator-get-started
    path: charts/podinfo
    ref: master
  values:
    image:
      repository: stefanprodan/podinfo
      tag: stg-9ij63o4c
    replicaCount: 2
    hpa:
      enabled: true
      maxReplicas: 10
      cpu: 50
      memory: 128Mi
```

With Flux Helm releases it's easy to manage different configurations per environment.
When adding a new option in the chart source make sure it's turned off by default so it will not affect all environments.

If I want to create a new environment, let's say for hotfixes testing, I would do the following:
* create a new namespace definition in `namespaces/hotfix.yaml`
* create a dir `releases/hotfix`
* create a HelmRelease named `podinfo-hotfix`
* set the automation filter to `glob:hotfix-*`
* make the CI tooling publish images from my hotfix branch to `stefanprodan/podinfo:hotfix-sha`

### Production promotions with sem ver

For production, instead of tagging the images with the Git commit, I will use [Semantic Versioning](https://semver.org).

Let's assume that I want to promote the code from the `stg` branch into `master` and do a production release.
After merging `stg` into `master` via a pull request, I would cut a release by tagging `master` with version `0.4.10`.

When I push the git tag, the CI will publish a new image in the `repo/app:git_tag` format:

```bash
$ cd hack && ./ci-mock.sh -r stefanprodan/podinfo -v 0.4.10

Successfully built f176482168f8
Successfully tagged stefanprodan/podinfo:0.4.10
```

If I want to automate the production deployment based on version tags, I would use `semver` filters instead of `glob`:

```yaml
apiVersion: helm.fluxcd.io/v1
kind: HelmRelease
metadata:
  name: podinfo-prod
  namespace: prod
  annotations:
    fluxcd.io/automated: "true"
    filter.fluxcd.io/chart-image: semver:~0.4
spec:
  releaseName: podinfo-prod
  chart:
    git: git@github.com:fluxcd/helm-operator-get-started
    path: charts/podinfo
    ref: master
  values:
    image:
      repository: stefanprodan/podinfo
      tag: 0.4.10
    replicaCount: 3
```

Now if I release a new patch, let's say `0.4.11`, Flux will automatically deploy it.

```bash
$ cd hack && ./ci-mock.sh -r stefanprodan/podinfo -v 0.4.11

Successfully tagged stefanprodan/podinfo:0.4.11
```

![gitops-semver](https://github.com/stefanprodan/openfaas-flux/blob/master/docs/screens/flux-helm-semver.png)

### Managing Kubernetes secrets

In order to store secrets safely in a public Git repo you can use the Bitnami [Sealed Secrets controller](https://github.com/bitnami-labs/sealed-secrets)
and encrypt your Kubernetes Secrets into SealedSecrets.
The SealedSecret can be decrypted only by the controller running in your cluster.

The Sealed Secrets Helm chart is available on [Helm Hub](https://hub.helm.sh/charts/stable/sealed-secrets),
so I can use the Helm repository instead of a git repo. This is the sealed-secrets controller release:

```yaml
apiVersion: helm.fluxcd.io/v1
kind: HelmRelease
metadata:
  name: sealed-secrets
  namespace: adm
spec:
  releaseName: sealed-secrets
  chart:
    repository: https://kubernetes-charts.storage.googleapis.com/
    name: sealed-secrets
    version: 1.6.1
```

Note that this release is not automated, since this is a critical component I prefer to update it manually.

Install the kubeseal CLI:

```bash
brew install kubeseal
```

At startup, the sealed-secrets controller generates a RSA key and logs the public key.
Using kubeseal you can save your public key as `pub-cert.pem`,
the public key can be safely stored in Git, and can be used to encrypt secrets without direct access to the Kubernetes cluster:

```bash
kubeseal --fetch-cert \
--controller-namespace=adm \
--controller-name=sealed-secrets \
> pub-cert.pem
```

You can generate a Kubernetes secret locally with kubectl and encrypt it with kubeseal:

```bash
kubectl -n dev create secret generic basic-auth \
--from-literal=user=admin \
--from-literal=password=admin \
--dry-run \
-o json > basic-auth.json

kubeseal --format=yaml --cert=pub-cert.pem < basic-auth.json > basic-auth.yaml
```

This generates a custom resource of type `SealedSecret` that contains the encrypted credentials:

```yaml
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  name: basic-auth
  namespace: adm
spec:
  encryptedData:
    password: AgAR5nzhX2TkJ.......
    user: AgAQDO58WniIV3gTk.......
```

Delete the `basic-auth.json` file and push the `pub-cert.pem` and `basic-auth.yaml` to Git:

```bash
rm basic-auth.json
mv basic-auth.yaml /releases/dev/

git commit -a -m "Add basic auth credentials to dev namespace" && git push
```

Flux will apply the sealed secret on your cluster and sealed-secrets controller will then decrypt it into a
Kubernetes secret.

![SealedSecrets](https://github.com/fluxcd/helm-operator-get-started/blob/master/diagrams/flux-helm-operator-sealed-secrets.png)

To prepare for disaster recovery you should backup the sealed-secrets controller private key with:

```bash
kubectl get secret -n adm sealed-secrets-key -o yaml --export > sealed-secrets-key.yaml
```

To restore from backup after a disaster, replace the newly-created secret and restart the controller:

```bash
kubectl replace secret -n adm sealed-secrets-key -f sealed-secrets-key.yaml
kubectl delete pod -n adm -l app=sealed-secrets
```

### <a name="help"></a>Getting Help

If you have any questions about Helm Operator and continuous delivery:

- Read [the Helm Operator docs](https://docs.fluxcd.io/projects/helm-operator/en/latest/).
- Read [the Flux integration with the Helm operator docs](https://docs.fluxcd.io/en/latest/references/helm-operator-integration.html).
- Invite yourself to the <a href="https://slack.cncf.io" target="_blank">CNCF community</a>
  slack and ask a question on the [#flux](https://cloud-native.slack.com/messages/flux/)
  channel.
- To be part of the conversation about Helm Operator's development, join the
  [flux-dev mailing list](https://lists.cncf.io/g/cncf-flux-dev).
- [File an issue.](https://github.com/fluxcd/flux/issues/new)

Your feedback is always welcome!
