# Releasing Shipyard

How versions move from a commit to a published artifact across the four
repositories. The short version:

```
feature branch ──PR──> develop ──────────────> main ────tag──> release
                      (auto dev build)      (promote)   (prod artifact)
```

## The three channels

A channel is a stream of versions. Every repository publishes to the same
three, and the CLI's `install.sh` can install from any of them.

| Channel | Where it is cut from | Tag shape | GitHub release | Container tags |
| :--- | :--- | :--- | :--- | :--- |
| `dev` | `develop`, automatically on every push | `v0.0.0-dev.<run>` | prerelease, pruned to the newest | `:dev` |
| `test` | `develop` | `v0.0.1-alpha.1`, `-beta.1`, `-rc.1` | prerelease, kept | `:test` |
| `stable` | `main` | `v0.0.1` | full release | `:latest`, `:stable`, `:<version>` |

The tag alone decides the channel. The release workflow **refuses to publish**
a stable tag that is not reachable from `main`, or a test/dev tag that is not
reachable from `develop`, so a release cannot be cut from the wrong branch.

## Cutting a stable release

```bash
# 1. make sure develop is green and has what you want to ship
git checkout develop && git pull

# 2. open the release PR; it auto-merges once required checks pass
gh workflow run promote.yml --repo shivam-jainn/shipyard-cli
# or pass an explicit version:
gh workflow run promote.yml --repo shivam-jainn/shipyard-cli -f version=0.0.1
# add -f dry_run=true to open the PR without merging

# 3. tag the merge commit on main. This triggers the release pipeline.
git checkout main && git pull
git tag v0.0.1
git push origin v0.0.1
```

The pipeline then cross-compiles, smoke-tests, checksums, generates an SBOM,
attests provenance, publishes the GitHub release, pushes the container, and
updates the `dist` channel manifest.

## Cutting a test release

Test releases come off `develop` the same way, with a prerelease tag:

```bash
git checkout develop && git pull
git tag v0.0.1-rc.1
git push origin v0.0.1-rc.1
```

## Installing

```bash
# production
curl -fsSL https://raw.githubusercontent.com/shivam-jainn/shipyard-cli/main/install.sh | sh

# specific channel
curl -fsSL https://raw.githubusercontent.com/shivam-jainn/shipyard-cli/main/install.sh \
  | sh -s -- --channel test

# pinned, for production
curl -fsSL https://raw.githubusercontent.com/shivam-jainn/shipyard-cli/main/install.sh \
  | sh -s -- --version v0.0.1
```

`shipyard version` reports the version, the CLI commit, the engine commit, and
the channel, so you can always tell what a given binary is.

## Engine versions

`shipyard-core` is private and is not distributed. It is tagged `core/v0.0.1`
when you want an immutable snapshot. Every released CLI binary records the
engine commit it was built against, so any published artifact traces back to
an exact engine state.

## What is public

| Repository | Visibility | Why |
| :--- | :--- | :--- |
| `shipyard-cli` | public | the distributed binary and its source |
| `shipyard-ci` | public | the integration templates, useless without the CLI |

The evaluation engine is a private module dependency. Because the CLI's source
is public but the engine is not, an outsider who clones `shipyard-cli` cannot
build it: the engine module is unreachable. That is intended. Distribution is
through the checksummed release artifacts and the container image.
