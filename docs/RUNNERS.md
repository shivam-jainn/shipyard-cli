# Shipyard build runners

Self-hosted runners are all ARM64 and free (self-hosted runners never consume
billed minutes regardless of plan).

| Runner | Labels | Host | Builds |
|---|---|---|---|
| `shivams-mbp` | `self-hosted, macOS, ARM64, mbp` | MacBook Pro | Go cross-compiles, darwin binaries, Homebrew formula |
| `shipyard-pi` (+`-2`, `-3`) | `self-hosted, linux, ARM64, pi, linux-build, packaging` | Raspberry Pi 5 (Debian 13) | build, vet, test, cross-compile, installer self-test, `.deb`/`.rpm`/Arch, install tests |

`shipyard-cli` gets three instances because a single runner serves **one job at a
time**, and `ci.yml` has a four-leg `cross-compile` matrix that wants to run in
parallel. On one instance those legs queue behind each other and every push takes
several minutes. The extra instances carry identical labels, so GitHub schedules
whichever is free.

The workflows select on **labels**, never on hostnames, so the Pi picked up the
packaging work with no workflow edits.

## What the Pi runs

| Job | Runner | Why |
| :--- | :--- | :--- |
| `ci.yml` build, vet, format, test | Pi | needs Docker for the `pkg/engine` tests; the Pi has a working daemon |
| `ci.yml` cross-compile | Pi | Go cross-compiles the whole matrix from one host |
| `ci.yml` installer self-test | Pi | shell only |
| `security.yml` govulncheck | Pi | Go toolchain already present |
| `package.yml` deb/rpm/arch | Pi | `.deb` and `.rpm` are Linux formats; a macOS host cannot build them |
| `ci.yml` **race** | GitHub-hosted | see below |
| `security.yml` CodeQL | GitHub-hosted | ~1 GB bundle and its own database directory |
| `release.yml` | GitHub-hosted | multi-arch image builds need QEMU |
| `package.yml` Homebrew | `shivams-mbp` | macOS only, by definition |
| `build-mbp.yml` | `shivams-mbp` | darwin targets and the macOS-native matrix |

## The one job that cannot run on the Pi

`go test -race` does not run on the Pi at all:

```
ThreadSanitizer: unsupported VMA range
FATAL: Found 47 - Supported 48
```

The arm64 kernel's 48-bit virtual address layout produces more memory regions
than the race detector's shadow mapping supports, so ThreadSanitizer aborts
before the first test executes. It is a property of the kernel, not the runner
configuration — no runner-side setting changes it. That job stays on a
GitHub-hosted `ubuntu-latest` runner.

A visible consequence: the cross-compile matrix builds `linux/amd64` from the
arm64 Pi, and that binary cannot be executed there without QEMU. The smoke test
runs on the `linux/arm64` leg instead.

## Pi host setup

The Pi is reached over Tailscale as `pi` in `~/.ssh/config`.

```bash
ssh pi
```

Installed:

| Tool | Version | Notes |
| :--- | :--- | :--- |
| Go | 1.26.8 | `/usr/local/go`, symlinked into `/usr/local/bin`, `go` on PATH via `/etc/profile.d/golang.sh` |
| Bun | 1.4.2 | `~/.bun/bin`, symlinked into `~/bin` |
| Actions runner | 2.337.0 | one instance per repository, see below |
| Docker | 29.7.2 | required by the `pkg/engine` integration tests |
| nfpm | 2.41.3 | `/usr/local/bin`, used by `package.yml` |
| rpm, zstd, dpkg-dev | distro | `package.yml` shells out to these to verify packages |

## One runner instance per repository

A self-hosted runner belongs to exactly one repository or one organization, and
these repositories live under a **user** account rather than an organization, so
there is no account-wide runner to register against. Each repository served by
the Pi therefore gets its own runner instance.

Only the three repositories whose builds take minutes are on the Pi.
`shipyard-ci` and `shipyard-registry` each run a single validation job that
finishes in seconds, so they use `ubuntu-latest` instead; a self-hosted runner
makes them no faster and would just hold ~135 MB resident while idle.

```
~/actions-runner-shipyard-cli        # labels: ... linux-build, packaging
~/actions-runner-shipyard-cli-2      # extra capacity, same labels
~/actions-runner-shipyard-cli-3      # extra capacity, same labels
~/actions-runner-shipyard-core
~/actions-runner-shipyard-web
```

All five are named `shipyard-pi`, and each is registered with the `pi` label plus
`linux-build,packaging` for the CLI, so `package.yml`'s
`runs-on: [self-hosted, linux-build, packaging]` matches without modification.

Each is a systemd service, so they survive a reboot:

```bash
ssh pi 'systemctl status actions-runner-shipyard-cli'
ssh pi 'sudo systemctl restart actions-runner-shipyard-web'
ssh pi 'journalctl -u actions-runner-shipyard-core -f'
```

### `PrivateTmp` must stay off

The unit files set `NoNewPrivileges=true` but deliberately **not** `PrivateTmp=true`.

`PrivateTmp=true` gives each job a private `/tmp`. The Docker daemon runs in the
host namespace and cannot see it, so a container bind-mounting a path under
`/tmp` gets an **empty directory**. `go test` writes each eval to `t.TempDir()`,
which is under `/tmp`, so every sandboxed engine test in `shipyard-core` was
mounting an empty eval directory and failing:

```
python3: can't open file '/tmp/TestRunSingleEval.../tests/rubric.py':
[Errno 2] No such file or directory
```

Reproduced directly — inside a `PrivateTmp=true` unit, a file written to `/tmp`
is invisible to a container mounting it:

```bash
ssh pi 'sudo systemd-run --wait --pipe --property=PrivateTmp=true \
  /bin/sh -c "mkdir -p /tmp/p && echo hi > /tmp/p/f.txt && \
    docker run --rm -v /tmp/p:/work alpine cat /work/f.txt"'
# -> cat: /work/f.txt: No such file or directory
```

If a sandboxed test fails with a missing file under `/tmp`, check this first.

### Re-registering

Registration tokens are short-lived, so an instance has to be re-registered if
it is ever moved or its credentials are lost. Generate a token for the target
repository, then re-run `config.sh` in that instance's directory:

```bash
TOKEN=$(gh api -X POST repos/shivam-jainn/shipyard-cli/actions/runners/registration-token --jq .token)
ssh pi "cd ~/actions-runner-shipyard-cli && ./config.sh --unattended \
  --url https://github.com/shivam-jainn/shipyard-cli \
  --token '$TOKEN' --name shipyard-pi \
  --labels 'self-hosted,linux,ARM64,pi,linux-build,packaging' \
  --work _work --no-default-labels --replace"
```

## Footprint

The Pi has four cores and 7.9 GiB of RAM, comfortably more than the ~91 MB the
two runners need at idle. `_work` holds build caches and is reclaimable.

```bash
ssh pi 'du -sh ~/actions-runner-shipyard-*'
```

Build caches grow between runs and are safe to clear when nothing is in flight:

```bash
ssh pi 'rm -rf ~/actions-runner-shipyard-cli/_work/*/src ~/actions-runner-shipyard-cli/_work/*/_temp'
```

