# `kubecolors`: Color API as a Kubernetes Deployment

RESTful color API running inside a Kubernetes cluster. Create, read, update, and
delete named colors, with data distributed across sharded MongoDB instances via
consistent hashing.

Built as a milestone project for the Kubernetes section of Lauro's
[Complete Docker & Kubernetes Course on Udemy](https://www.udemy.com/course/complete-docker-kubernetes).

## Table of Contents

- [Background](#background)
- [Overview](#overview)
- [Local Deployment](#local-deployment)
- [GKE Deployment](#gke-deployment)
- [Built With](#built-with)
- [License](#license)

## Background

During my onboarding @ Redis, I had a few skill gaps to close. One of them was
Docker and Kubernetes, so I bought a [hands-on course on Udemy](https://www.udemy.com/course/complete-docker-kubernetes).

The Kubernetes section contains a project to deploy a simple service to a cluster.
I decided to take it one step further and use the project as a systems design
exercise as well.

## Overview

`kubecolors` consists of:
- `color-api`:  REST API for storing and retrieving named colors. Deployed as a 
Kubernetes Deployment, exposed via a NodePort Service.
- `mongo-shards`: Distributed **MongoDB** StatefulSet to store color data.
Sharding is implemented via application-level consistent hashing.
- Secrets are encrypted at rest with **SOPS + age**.

More on the system's design can be found in [system-design.md](system-design.md).

## Local Deployment

Clone the repo and deploy the stack to your Kubernetes cluster.

### Prerequisites

- [Docker](https://www.docker.com/)
- [kubectl](https://kubernetes.io/docs/reference/kubectl/)
- A local Kubernetes cluster (e.g. [Docker Desktop](https://www.docker.com/products/docker-desktop/), [minikube](https://minikube.sigs.k8s.io/))
- [SOPS](https://github.com/getsops/sops) and [age](https://github.com/FiloSottile/age)
- [kustomize](https://kubectl.docs.kubernetes.io/installation/kustomize/)

### Build

Build and push the `color-api` image to your own registry:

```bash
make build BUILD_TAG=myregistry/color-api:2.0.1
make push BUILD_TAG=myregistry/color-api:2.0.1
```

### Deploy

Deploy the full stack (namespace, secrets, database, backend):

```bash
make up
```

**NOTE**: all following commands to test & operate the application
require `KUBECOLORS_ENDPOINT` to be set. It's the NodePort endpoint of the
`color-api` service. You can retrieve it by inspecting the exposed NodePort:

```bash
kubectl get svc -n kubecolors
export KUBECOLORS_ENDPOINT="localhost:30080"
```

### Verify

Run smoke tests against the deployed service:

```bash
make smoke-test
```

### Seed data

You may load some sample color data via:

```bash
make load-data
```

And if you'd like to flush out sample data:

```bash
make flush
```

### Load test

[`scripts/load-test.sh`](scripts/load-test.sh) runs concurrent requests for
various operations against the service:

```bash
make load-test
```

**WARNING**: the following command WILL overload the service and may overload your
host machine as well. Ensure you have sufficient resources before running:

```bash
make load-test CONCURRENT_REQUESTS=100 RECORDS=1000 UPDATES=2000 GETS=10000
```

### Tear down

Delete all Kubernetes resources (removes `kubecolors` namespace):

```bash
make down
```

## GKE Deployment

Create a Google Kubernetes Engine (GKE) cluster and deploy via Terraform.

### Prerequisites

- Google Cloud Platform (GCP) account (you may use a [free trial account](https://cloud.google.com/free))
- Project in GCP (recommend you create a brand new project)
- **Compute Engine** and **Kubernetes Engine** APIs enabled in your GCP project (Terraform enables them automatically, but the project must have billing enabled first)
- `color-api` images built and pushed to Docker Hub (see [how to build color-api images](#deploy) above)
- [gcloud](https://cloud.google.com/cli)
- [kubectl](https://kubernetes.io/docs/reference/kubectl/)
- [Terraform](https://developer.hashicorp.com/terraform)
- [SOPS](https://github.com/getsops/sops) and [age](https://github.com/FiloSottile/age)
- [kustomize](https://kubectl.docs.kubernetes.io/installation/kustomize/)
- (OPTIONAL) Registered domain in Google Cloud Domains or other domain provider

### Create GCP infrastructure

Generate Application Default Credentials (ADC) for your GCP account and copy them
into the Terraform directory (`gcp-creds.json` is gitignored):

```bash
gcloud auth application-default login
cp ~/.config/gcloud/application_default_credentials.json kubernetes/cluster/gcp-creds.json
cp kubernetes/cluster/terraform.tfvars.example kubernetes/cluster/terraform.tfvars
# Edit terraform.tfvars: set project_id, credentials_file (e.g. gcp-creds.json), and other values
```

Place your age private key at `keys.txt` in the repo root. This file is used by
SOPS to decrypt Kubernetes secrets at deploy time. (See `.sops.yaml` for the
encryption config.)

Initialize Terraform (downloads the Google provider -- only needed once):

```bash
make infra-init
```

Create your GCP infrastructure:

```bash
make infra-apply
```

Once your GKE cluster is up and running, add it to your kubectl contexts:

```bash
gcloud container clusters get-credentials kubecolors-cluster \
    --region europe-west3 \
    --project <your-project-id>
```

### Connect a domain

Retrieve the reserved static IP addresses from Terraform:

```bash
make infra-show
```

Register a domain either in Google Cloud Domains or another domain provider. Add
the following records to your DNS settings (use the IP addresses from the output above):

```
Type   Host/Name   Value
A      dev         <dev_static_ip_address from terraform output>
A      @           <prod_static_ip_address from terraform output>
A      www         <prod_static_ip_address from terraform output>
```

Then go and edit the TLS certificate **and** Ingress manifests by placing your domain in:

- [kubernetes/overlay/dev/managed-tls-cert.yaml](kubernetes/overlay/dev/managed-tls-cert.yaml)
- [kubernetes/overlay/prod/managed-tls-cert.yaml](kubernetes/overlay/prod/managed-tls-cert.yaml)
- [kubernetes/overlay/dev/ingress.yaml](kubernetes/overlay/dev/ingress.yaml)
- [kubernetes/overlay/prod/ingress.yaml](kubernetes/overlay/prod/ingress.yaml)

### Deploy

You may deploy to either `dev` or `prod` namespaces (or both) which are managed
as `Kustomize` overlays:

```bash
make up OVERLAY=dev
make up OVERLAY=prod
```

**NOTE:** GKE cluster will need some time to provision a node and schedule pods on it.
Managed certificates and ingress rules require ~30 minutes to activate and propagate.

### Verify

Run smoke tests against the deployed service:

```bash
export KUBECOLORS_ENDPOINT="https://www.<your-custom-domain>.com"
make smoke-test
```

All other targets (loading data, load tests, metrics, flushing the DB) work as well.

### Tear down

Delete all Kubernetes resources:

```bash
make down OVERLAY=dev
make down OVERLAY=prod
```

Destroy your GKE cluster (**WARNING:** there is no *undo*, this will permanently
destroy all managed resources via Terraform):

**NOTE:** `deletion_protection` is `true` by default in `terraform.tfvars`. You
must set it to `false` and run `make infra-apply` before `make infra-destroy` will
succeed.

```bash
make infra-destroy
```

## Built With

- [Kubernetes](https://kubernetes.io/)
- [Docker](https://www.docker.com/)
- [Terraform](https://developer.hashicorp.com/terraform)
- [Google Kubernetes Engine](https://cloud.google.com/kubernetes-engine)
- [Express](https://expressjs.com/)
- [MongoDB](https://www.mongodb.com/)
- [SOPS](https://github.com/getsops/sops) and [age](https://github.com/FiloSottile/age)
- [FigJam](https://www.figma.com/figjam/) to design [architecture.png](architecture.png)

## License

This project is distributed under the [MIT license](LICENSE).
