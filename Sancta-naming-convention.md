# Sancta Naming & Conventions Guide

## Core Principles

1.  Home before bunker: names evoke calm place + clear thresholds
    (doors, rooms).
2.  One pattern everywhere: same skeleton across DNS, repos, services,
    infra.
3.  Shortest unique string wins: fast typing, easy radio test.
4.  Environments are suffixes, never prefixes: `-dev`, `-stg`, `-prd`.
5.  No ambiguous synonyms: pick one noun per function (Gate, Archive,
    Port, Vigil, Choir, Home).
6.  Machine-safe slugs: lowercase, `a–z0–9-`, no underscores for
    resource names; code follows language conventions.

## Product Modules

-   **Sancta Home** --- personal OS / dashboards
-   **Sancta Gate** --- identity, authn/z, policy enforcement
-   **Sancta Archive** --- encrypted data + immutable audit
-   **Sancta Choir** --- agent runtime/orchestration
-   **Sancta Port** --- bridges to external networks/services
-   **Sancta Vigil** --- telemetry, SIEM, detections, auto-response

Short slugs: `home`, `gate`, `archive`, `choir`, `port`, `vigil`.

## Domains & DNS

**Public (porch only):** - `porch.savinov.eu` → landing, consent pages,
status, legal

**Private (everything else):** - Zone: `sancta.home.arpa` -
`home.sancta.home.arpa`, `gate.sancta.home.arpa`, etc.

Pattern: `<module>-<role>-<env>-<seq>.sancta.home.arpa`

Example: `gate-api-prd-01.sancta.home.arpa`

## Environments

-   Codes: `dev`, `stg`, `prd`
-   Region codes optional: `md1`, `eu1`
-   Ordering: `<name>-<env>[-<region>]`

## Repositories

-   Monorepo: `sancta`
-   If split: `sancta-home`, `sancta-gate`, etc.
-   Infra: `sancta-iac`
-   Policies: `sancta-policy`

## Services & Containers

Pattern: `sancta-<module>-<component>`

Example: `sancta-gate-api`

Images: `ghcr.io/alexandru-savinov/<service>:<semver>`

Kubernetes: namespace `sancta-gate`, deployment `sancta-gate-api`, etc.

## Git & Releases

-   Branches: `feat/gate/mfa-flow`
-   Commits: `feat(gate): add WebAuthn passkeys`
-   SemVer tags

## APIs

-   Base path per module: `/gate/v1/...`
-   Resource nouns plural, snake in JSON, camel in code
-   Example: `/archive/v1/records`

## Policies

Roles: `owner`, `family`, `guest`, `service`, `agent`

Policy IDs: `<module>/policy/v<major>/<short-name>`

Example Rego: `policy/gate/v1/read_photos.rego`

## Storage

Data classes: `public`, `private`, `secret`, `evidence`

Example key: `pri/photos/2025/08/16/IMG_3211.heic`

## Logging

Fields: `ts`, `module`, `service`, `actor_did`, `action`, `decision`

Correlation ID: `sc-<yyyymmdd>-<6char>`

## Infrastructure as Code

Terraform resource: `sancta_<module>_<component>_<env>`

Example: `sancta_gate_api_prd`

## Secrets

Pattern: `sancta-<module>-<component>-keys`

Rotate with date suffix if needed.

## Public Porch (savinov.eu)

-   `porch.savinov.eu` for public site
-   `.well-known/security.txt` and `.well-known/did.json`

## Devices & Physical

Pattern: `<room>-<device>-<seq>` (e.g. `entry-doorlock-01`)

## Examples

**Docker Compose:**

``` yaml
services:
  gate-api:
    image: ghcr.io/alexandru-savinov/sancta-gate-api:1.2.0
    container_name: sancta-gate-api-dev
    environment:
      - SANCTA_ENV=dev
    networks: [ sancta-net ]
```

**Terraform:**

``` hcl
resource "digitalocean_droplet" "sancta_port_gw_prd_01" {
  name   = "sancta-port-gw-prd-01"
  region = "fra1"
}
```

**Kubernetes:**

``` yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sancta-gate-api
spec:
  replicas: 2
```
