# Branching strategy

Three long-lived branches, each one an environment. Code moves up exactly one
tier at a time, and never down.

```
  feature/*  ──PR──▶  develop  ──PR──▶  staging  ──PR──▶  main
             dev         test              prod
```

| Branch | Environment | Channel | Who consumes it |
|---|---|---|---|
| `develop` | integration | `dev` | you, on every push. `./install.sh --channel dev` |
| `staging` | pre-production | `test` | QA, integration checks. `./install.sh --channel test` |
| `main` | production | `stable` | everyone. `./install.sh --channel stable` |

`develop` is the only branch you push to directly. `staging` and `main` are
protected: they accept pull requests only, and only from the branch directly
below them.

## Why promotion is a pull request and not a merge

A promotion PR is the audit record. It shows exactly which commits reached
production, it runs the full suite against the target branch before anything
lands, and it leaves a revert path — revert the merge commit on `main` and the
Promote workflow carries the revert forward on the next release.

Merging `develop` straight into `main` would make it impossible to tell whether
anything was ever validated in a pre-production environment, which is the one
question a release is supposed to answer.

## Cutting a release

Promotions are one click each:

```bash
# develop -> staging, publishes the test channel
gh workflow run promote.yml -f target=staging

# staging -> main, publishes the stable channel
gh workflow run promote.yml -f target=production -f version=0.0.2
```

The workflow refuses to skip a tier. `develop` cannot reach `main` directly, and
`production` additionally requires a stable `MAJOR.MINOR.PATCH` version, because
the stable channel carries no prerelease suffix.

Once the production PR merges, tag it:

```bash
git checkout main && git pull
git tag v0.0.2 && git push origin v0.0.2
```

That tag drives the Release workflow, which publishes binaries, the container
image, the SBOM and the provenance attestation, then repoints `stable` in the
`dist` channel manifest.

### Tag provenance is enforced, not trusted

`Release` checks the tagged commit is reachable from the branch that owns the
channel, and refuses otherwise:

| Tag | Must be reachable from |
|---|---|
| `v1.2.3` | `main` |
| `v1.2.3-rc.1` | `staging` |
| `v0.0.0-dev.123` | `develop` |

Tagging production from `develop` by hand fails the run. That is deliberate: the
branch policy is the thing that makes the three tiers mean something.

## Working on a change

```bash
git checkout develop && git pull
git checkout -b feat/short-description
# ... work ...
git push -u origin feat/short-description
gh pr create --base develop
```

Feature branches are throwaway. Rebase or merge `develop` into them as needed and
delete them once the PR lands. Nothing long-lived forks from `main`.

## Fixing something in production

Hotfixes go the same way round as everything else, with one extra step. Branch
from `main`, fix, then promote *back down* so the fix is not lost at the next
`develop` -> `staging` promotion:

```bash
git checkout main && git pull
git checkout -b fix/the-thing
# ... fix, add a regression test ...
git push -u origin fix/the-thing
gh pr create --base main --title "fix: the thing"
```

Then merge `main` into `develop` and `develop` into `staging`, so the fix is
present on every branch and the next promotion does not revert it.

```bash
git checkout develop && git merge main && git push
git checkout staging && git merge develop && git push
```

Doing this promptly matters: a fix that sits on `main` alone is one promotion
away from being silently undone.

## CI, and where it runs

CI runs on every push and pull request targeting `develop`, `staging` or `main`.

| Workflow | Runs on | Notes |
|---|---|---|
| `ci.yml` | Pi | build, vet, format, test, cross-compile, installer self-test |
| `ci.yml` (`race` job) | GitHub-hosted | see below |
| `security.yml` | Pi + GitHub-hosted | CodeQL hosted, govulncheck on the Pi |
| `build-mbp.yml` | MacBook Pro | darwin binaries and Homebrew formula |
| `package.yml` | Pi + MacBook Pro | `.deb`/`.rpm`/Arch on the Pi, Homebrew on the Mac |
| `release.yml` | GitHub-hosted | multi-arch image builds need QEMU |

### The one job that cannot run on the Pi

`go test -race` fails on the Pi before it runs a single test:

```
ThreadSanitizer: unsupported VMA range
FATAL: Found 47 - Supported 48
```

That is the arm64 kernel's 48-bit virtual address layout producing more memory
regions than the race detector's shadow mapping has room for. It is a property of
the kernel, not of the runner configuration, so no amount of tuning on the Pi
fixes it. The race job therefore stays on a GitHub-hosted `ubuntu-latest`
runner. Every other job in the repository runs on the Pi.

This is also why the cross-compile smoke test runs on the `linux/arm64` leg: the
matrix builds `linux/amd64` from an arm64 host, and that binary cannot execute
here without QEMU.

See [docs/RUNNERS.md](docs/RUNNERS.md) for the runner hosts themselves.

## Branch protection

`main`, `staging` and `develop` are protected. `main` and `staging` require a
pull request, a passing `CI / Build & Test`, a passing `CI / Test (race)`, and
allow no force-push and no branch deletion. `develop` allows direct pushes,
because that is where day-to-day work lands, but still blocks force-push and
deletion.

The promotion workflow merges with `--auto`, so it waits for those checks rather
than racing them.

## Housekeeping

Deleting a branch on `main` would strand its commits, so protection forbids it.
Once a release is out and the branches have moved on, the old promotion PRs and
branches can be pruned with:

```bash
gh pr list --base main --state closed --limit 50
```
