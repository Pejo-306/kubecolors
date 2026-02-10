# System Design for `kubecolors`

This document describes the architecture and requirements of the system `kubecolors`.

## Problem Statement

Design a RESTful color service and deploy it with Kubernetes.

## Requirements

### Functional

#### FR-1: CRUD colors

- Users can create, read, update, and delete named colors
- Required attributes: `key`, `hex`
- Colors are identified by a unique `key`
- `hex` must be a valid hex color code (e.g. `#ff0000`)

#### FR-2: Default color endpoint

- A root endpoint returns a color and the hostname of the serving pod
- If no `colorKey` is provided, the default color `#000000` (black) is returned
- Supports plain text and JSON response formats

### Non-functional

#### NFR-1: Even data distribution

- Color data should be distributed evenly across database shards

### Constraints

#### C-1: Kubernetes runtime

- The entire service is deployed in a single Kubernetes namespace `kubecolors`

#### C-2: Single microservice architecture

- The system consists of a single microservice `color-api` deployed as a
  Kubernetes Deployment

#### C-3: Web engine

- `color-api` uses [Express](https://expressjs.com/) to process requests

#### C-4: Backend data store

- [MongoDB](https://www.mongodb.com/) is used as a primary data storage engine
- [MongoDB](https://www.mongodb.com/) is deployed as a Kubernetes StatefulSet

#### C-5: Development tech stack

- [Node](https://nodejs.org/) for JavaScript runtime engine
- [npm](https://www.npmjs.com/) for package management

#### C-6: Secret management

- Credentials are stored in the Git repository, encrypted with
  [SOPS](https://github.com/getsops/sops) + [age](https://github.com/FiloSottile/age)
- Secrets are decrypted at deploy time and applied to the cluster

#### C-7: Single point of access

- Users interact with `color-api` through a single NodePort Service endpoint

### Assumptions

**NOTE**: the below assumptions were retroactively added to solve various
[technical deep dives](#technical-deep-dives).

#### A-1: Daily active users
- Assume 100,000 daily active users (DAU)

#### A-2: Write volume
- Assume 5 colors/user/day => 182.5 million colors/year

#### A-3: Data retention
- Assume 1 year data retention

#### A-4: String field encoding
- Assume string fields are stored in data stores with **UTF-8** encoding
- 1 character in **UTF-8** = 1-4 bytes
- Assume 90% of stored characters are 1 byte, 10% are stored with 4 bytes

#### A-5: Conservative string field length
- Assume `Color.key` is 50 characters on average (90% of keys)
- Assume `Color.key` is 100 characters maximum (10% of keys)

### Non-requirements

The following is explicitly out-of-scope for this project:

- Continuous development (it's a practice project with a tight scope)
- AI-assisted features
- Production-level readiness (HA, redundancy, auto-scaling, monitoring, alerting)

## API Specification

### `color-api` REST API

| Method & Endpoint                | Action             | Behavior    |
|----------------------------------|--------------------|-------------|
| **GET** `/up`                    | Startup check      | <ul> <li>**200**: with text **ok**</li> </ul> |
| **GET** `/health`                | Liveness check     | <ul> <li>**200**: with text **ok**</li> </ul> |
| **GET** `/ready`                 | Readiness check    | <ul> <li>**200**: with text **ok** if all database shards are connected</li> <li>**503**: if any database shard is not ready</li> </ul> |
| **GET** `/api/`                  | Hostname of serving pod        | <ul> <li>optionally receives `colorKey` as query parameter</li> <li>optionally receives `format` as query parameter (`json`)</li> <li>**200**: default color `#000000` and hostname if no `colorKey`</li> <li>**200**: color hex and hostname if `colorKey` exists</li> <li>**404**: if color with `colorKey` doesn't exist</li> </ul> |
| **GET** `/api/color`             | Get all colors     | <ul> <li>**200**: all colors across all shards</li> </ul> |
| **GET** `/api/color/:key`        | Get a color        | <ul> <li>**200**: color information</li> <li>**404**: if color with `:key` doesn't exist</li> </ul> |
| **POST** `/api/color/:key`       | Create a color     | <ul> <li>expects `color` in request body (hex color code)</li> <li>**201**: persist color</li> <li>**400**: if `color` is not a valid hex color code</li> <li>**400**: if color with `:key` already exists</li> </ul> |
| **PUT** `/api/color/:key`        | Update a color     | <ul> <li>expects `color` in request body (hex color code)</li> <li>**200**: updated color</li> <li>**400**: if `color` is not a valid hex color code</li> <li>**404**: if color with `:key` doesn't exist</li> </ul> |
| **DELETE** `/api/color/:key`     | Delete a color     | <ul> <li>**204**: color deleted</li> <li>**404**: if color with `:key` doesn't exist</li> </ul> |


## Data Models

### `Color` data model

| Field  | Type       | Required | Notes                |
|--------|------------|----------|----------------------|
| `key`  | **string** | ✓        | <ul> <li>unique identifier for the color</li> </ul> |
| `hex`  | **string** | ✓        | <ul> <li>must match `^#([0-9a-fA-F]{6})$`</li> </ul> |


## High Level Design

![Architecture](architecture.png)

Notes:
- All resources are deployed in the `kubecolors` namespace
- `color-api` Deployment exposed via a NodePort Service
- MongoDB StatefulSet with a headless Service for stable DNS names
- Application-level consistent hashing distributes color keys across database shards
- A ConfigMap provides shard topology configuration to `color-api` pods
- Secrets are encrypted at rest with SOPS + age and decrypted at deploy time

## Technical Deep Dives

### DD-1: Color data model

How do we represent color values in our data store?

#### [REJECTED] RGB tuple

Store each color as three separate integer fields: `{r, g, b}`.

**Pros**
- Easy to manipulate individual color channels programmatically
- Standard programmatic representation

**Cons**
- 3 fields instead of 1 per color record
- More complex validation (each field must be 0-255)
- Requires conversion for display in web contexts (CSS, HTML)

**Rejected** due to unnecessary complexity for a key-value color store.

#### [REJECTED] Integer

Store the color as a single integer (e.g. `16711680` for red).

**Pros**
- Compact storage (4 bytes)
- Fast equality comparisons

**Cons**
- Not human-readable (what color is `16711680`?)
- Requires conversion for display
- Hard to debug and inspect data directly in the database

**Rejected** due to poor readability.

#### [ACCEPTED] Hex string

Store the color as a hex string (e.g. `#ff0000`).

**Pros**
- Human-readable
- Single field
- Simple regex validation (`^#([0-9a-fA-F]{6})$`)
- Directly usable in CSS/HTML without conversion

**Cons**
- Slightly more storage than integer (7 bytes vs 4 bytes)
- String comparison instead of integer comparison

**Accepted** due to human readability and direct web usability.

### DD-2: Sharding

How do we distribute color data across multiple MongoDB instances?

#### [REJECTED] No sharding

Use a single MongoDB instance for all data.

**Pros**
- Simple, no routing logic needed

**Cons**
- Single point of failure
- Limited storage capacity
- Can't distribute data across multiple instances
- Doesn't address [NFR-1](#nfr-1-even-data-distribution)

**Rejected** due to inability to distribute data.

#### [REJECTED] Sequential ID (counter)

Use a monotonic counter to assign each color to a shard via `counter % shardCount`.

**Pros**
- Simple to implement
- Even distribution under uniform writes

**Cons**
- Adding or removing a shard changes the modulus and invalidates all existing
  assignments
- Requires full data migration on topology change

**Rejected** due to fragility on shard topology changes.

#### [REJECTED] Simple hash

Hash the color key, then assign to a shard via `hash(key) % shardCount`.

**Pros**
- Even distribution
- No ordering dependency

**Cons**
- Same modulus problem as counter -- adding or removing a shard remaps nearly
  all keys
- Requires full data migration on topology change

**Rejected** due to same remapping problem as sequential ID.

#### [REJECTED] Consistent hashing (without virtual nodes)

Place each physical shard at a single point on a hash ring. Route keys to the
nearest shard clockwise.

**Pros**
- Adding or removing a shard only remaps keys from one adjacent range
- Minimal data migration on topology change

**Cons**
- Uneven distribution -- with few physical nodes, some shards get
  disproportionately more keys (hotspots)

**Rejected** due to uneven data distribution with few nodes.

#### [ACCEPTED] Consistent hashing with virtual nodes

Place multiple virtual nodes per physical shard on the hash ring. Each shard
is represented by many points on the ring, ensuring even coverage.

**Pros**
- Even distribution regardless of number of physical shards
- Minimal remapping on topology changes
- Hashing algorithm is not critical -- any fast, non-cryptographic hash suffices

**Cons**
- Slightly more complex implementation (sorted ring of virtual nodes,
  wrap-around lookup)

**Accepted** due to even distribution and resilience to topology changes.

The `Ring` class in `color-api` implements this approach. Each physical shard
is mapped to 64 virtual nodes on the ring. The ring is sorted by hash value.
To find the shard for a given key, the key is hashed and the ring is walked
clockwise until the first virtual node with a hash >= the key hash is found.
If no such node exists, it wraps around to the first node in the ring.

### DD-3: Secret management in Git repository

How do we manage database credentials that need to live in the Git repository?

#### [REJECTED] Plain text secrets in repository

Store credentials as plain text in Kubernetes Secret manifests.

**Pros**
- Simple, no additional tooling needed

**Cons**
- Anyone with repository access can read credentials
- Security violation

**Rejected** due to exposing secrets in plain text.

#### [REJECTED] External vault

Use an external secrets management service (HashiCorp Vault, AWS Secrets Manager,
etc.).

**Pros**
- Industry standard
- Centralized secrets management
- Audit trails and access control

**Cons**
- Requires external infrastructure
- Additional operational complexity
- Overkill for a practice project

**Rejected** due to unnecessary complexity for project scope.

#### [ACCEPTED] SOPS + age

Encrypt secret values in-place within Kubernetes Secret manifests using
[SOPS](https://github.com/getsops/sops) with [age](https://github.com/FiloSottile/age)
as the encryption backend.

**Pros**
- Secrets are versioned alongside code in Git
- No external infrastructure required
- Simple CLI workflow (`sops --encrypt` / `sops --decrypt`)
- `age` is modern, simple, and easy to use

**Cons**
- Requires SOPS + age CLI tools installed locally
- Key management is manual (age key file must be distributed to operators)

**Accepted** because the author wanted hands-on experience with SOPS.

SOPS is configured via `.sops.yaml` with `encrypted_regex: ^(data|stringData)$`,
which encrypts only the secret values while leaving the rest of the manifest
(metadata, labels, etc.) in plain text for readability.

### DD-4: How many colors do we need to store?

How much data do we expect to save in a year?

Assume [A-1](#a-1-daily-active-users), [A-2](#a-2-write-volume), [A-3](#a-3-data-retention),
[A-4](#a-4-string-field-encoding), and [A-5](#a-5-conservative-string-field-length).

`Color.hex` is always 7 ASCII characters (`#` + 6 hex digits), stored with 1 byte each:

```math
Color.hex = 7 \text{ characters} \times 1 \text{ byte} = 7 \text{ bytes}
```

The size of `Color` records is:

```math
sizeof(Color) = sizeof(Color.key) + sizeof(Color.hex)
```

For 90% of records (average keys, 1-byte characters):

```math
sizeof_{90\%}(Color) = 50 \text{ bytes} + 7 \text{ bytes} = 57 \text{ bytes}
```

For 10% of records (max keys, 4-byte characters):

```math
sizeof_{10\%}(Color) = 100 \times 4 \text{ bytes} + 7 \text{ bytes} = 407 \text{ bytes}
```

For 1 year we store **182.5 million** colors [A-2](#a-2-write-volume):

```math
data_{1y} = 90\% \times 182.5 \text{ mil.} \times 57 \text{ bytes} + 10\% \times 182.5 \text{ mil.} \times 407 \text{ bytes} \approx 17 \text{ GB}
```

### DD-5: How big should PersistentVolumes be?

How much storage do we allocate per MongoDB shard?

From [DD-4](#dd-4-how-many-colors-do-we-need-to-store), the total raw data volume
is approximately **17 GB/year** across all shards.

Per shard (with 3 shards):

```math
data_{shard} = \frac{17 \text{ GB}}{3} \approx 5.7 \text{ GB/shard/year}
```

Factor in MongoDB overhead for indexes, journaling, and internal metadata
(approximately 2x raw data):

```math
storage_{shard} = 5.7 \text{ GB} \times 2 \approx 11.4 \text{ GB/shard/year}
```

Add a ~50% growth margin for headroom:

```math
recommended_{shard} = 11.4 \text{ GB} \times 1.5 \approx 17 \text{ GB/shard}
```

Each MongoDB shard should be provisioned with approximately **17 GB** of
PersistentVolume storage to comfortably hold 1 year of data with overhead
and growth margin.

### DD-6: Resource limits and capacity planning

How do we size CPU and memory limits for `color-api` and MongoDB pods?

Assume [A-1](#a-1-daily-active-users) and [A-2](#a-2-write-volume).

**Request throughput estimation:**

Write throughput:

```math
writes = \frac{100{,}000 \text{ DAU} \times 5 \text{ colors/day}}{86{,}400 \text{ sec/day}} \approx 5.8 \text{ writes/sec (avg)}
```

Assume a 10:1 read-to-write ratio:

```math
reads \approx 58 \text{ reads/sec (avg)}
```

Assume peak usage is 10x average:

```math
peak_{total} \approx (5.8 + 58) \times 10 \approx 640 \text{ req/sec}
```

**`color-api` sizing:**

With 5 replicas, each pod handles:

```math
peak_{pod} = \frac{640}{5} \approx 128 \text{ req/sec/pod}
```

Express.js can comfortably handle this throughput. Current limits of **500m CPU**
and **128Mi memory** per pod are sufficient.

**MongoDB sizing:**

With 3 shards, each shard handles:

```math
peak_{shard} = \frac{640}{3} \approx 213 \text{ req/sec/shard}
```

Current limits of **1000m CPU** and **512Mi memory** per shard are sufficient
for this level of throughput.
