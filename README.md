# `kubecolors`: Color API as a Kubernetes Deployment

RESTful color API running inside a Kubernetes cluster. Create, read, update, and
delete named colors, with data distributed across sharded MongoDB instances via
consistent hashing.

Built as a milestone project for the Kubernetes section of Lauro's
[Complete Docker & Kubernetes Course on Udemy](https://www.udemy.com/course/complete-docker-kubernetes).

## Table of Contents

- [Background](#background)
- [Overview](#overview)
- [Deployment](#deployment)
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

More on the system's design can be found inside [system-design.md](system-design.md)

## Deployment

Clone the repo and deploy the stack to your Kubernetes cluster.

### Prerequisites

- [Docker](https://www.docker.com/)
- [kubectl](https://kubernetes.io/docs/reference/kubectl/)
- A local Kubernetes cluster (e.g. [Docker Desktop](https://www.docker.com/products/docker-desktop/), [minikube](https://minikube.sigs.k8s.io/))
- [SOPS](https://github.com/getsops/sops) and [age](https://github.com/FiloSottile/age)

### Build

Build and push the `color-api` image to your own registry:

```bash
make build BUILD_TAG=myregistry/color-api:2.0.0
make push BUILD_TAG=myregistry/color-api:2.0.0
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

## Built With

- [Kubernetes](https://kubernetes.io/)
- [Docker](https://www.docker.com/)
- [Express](https://expressjs.com/)
- [MongoDB](https://www.mongodb.com/)
- [SOPS](https://github.com/getsops/sops) and [age](https://github.com/FiloSottile/age)
- [FigJam](https://www.figma.com/figjam/) to design [architecture.png](architecture.png)

## License

This project is distributed under the [MIT license](LICENSE).
