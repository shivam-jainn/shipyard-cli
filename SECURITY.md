# Security Policy

## Reporting a vulnerability

Please **do not open a public issue** for a security vulnerability.

Report it privately via GitHub's security advisory form:

<https://github.com/shivam-jainn/shipyard-cli/security/advisories/new>

Include the affected version or image tag, what you observed, and how to
reproduce it. You can expect an acknowledgement within a few days.

## Supported versions

| Channel | Tag pattern | Fixes provided |
| :--- | :--- | :--- |
| stable | `v0.0.1` | Yes, patch releases only |
| test | `v0.0.1-alpha.N`, `-beta.N`, `-rc.N` | Yes, until superseded by stable |
| dev | `v0.0.1-dev.N` | No, rebuild from `develop` |

Pre-release tags are published for evaluation. Anything found in them is
treated as a live issue and fixed on the next patch of the relevant channel.

## Threat model

Shipyard is a CLI that executes AI agents, so it should be assumed to run
arbitrary agent code. It is a developer tool, not a sandbox boundary: the
engine runs commands, invokes the Docker CLI, and executes Python rubrics.

In scope:

- The `shipyard` binary, this repository's source, and the container image
- `install.sh`, which downloads and executes a published artifact
- The release pipeline, including artifact and checksum generation

Out of scope:

- Behaviour of agent code that Shipyard is asked to run
- Anything in the private `shipyard-core` engine repository, which is not
  distributed and is not covered by this policy
- Denial of service caused by an intentionally heavy workload
- Findings that require an attacker to already control your machine

## Verifying what you installed

Every release ships a checksum file and an SPDX SBOM. The image is signed
with provenance attestation.

```bash
# After downloading a release tarball
sha256sum -c checksums.txt
```

```bash
# Confirm the image you pulled is the one that was published
docker buildx imagetools inspect ghcr.io/shivam-jainn/shipyard-cli:test
```

If a checksum does not match, do not run the binary. Re-download it and
report the discrepancy.

## Build integrity

The CLI depends on a private engine repository, so this repository **cannot
be built by anyone outside the project**. It can be read, but not compiled.
Distribution is artifacts-only, and that is intentional.

The release pipeline is hardened against a compromised runner:

- The engine is fetched with a **read-only** deploy key, so a compromised
  runner cannot write to the engine repository
- Binaries are built with `CGO_ENABLED=0` and `-trimpath`, and stripped of
  symbols and DWARF
- Every build is covered by `govulncheck` and CodeQL
