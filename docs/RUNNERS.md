# Shipyard build runners

Two self-hosted runners, both ARM64, both free (the repository is public, and
self-hosted runners never consume billed minutes regardless of plan).

| Runner | Labels | Host | Builds |
|---|---|---|---|
| `shivams-mbp` | `self-hosted, macOS, ARM64, mbp` | MacBook Pro | Go cross-compiles, darwin binaries, Homebrew formula |
| `shipyard-pi` | `self-hosted, linux, ARM64, pi, linux-build, packaging` | Raspberry Pi 5 (Debian 13) | `.deb`, `.rpm`, Arch packages, install tests |

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
there is no account-wide runner to register against. The Pi therefore runs five
separate runner instances, one per repository:

```
~/actions-runner-shipyard-cli        # labels: ... linux-build, packaging
~/actions-runner-shipyard-web
~/actions-runner-shipyard-core
~/actions-runner-shipyard-ci
~/actions-runner-shipyard-registry
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

## The Lima VM

`shipyard-linux` is also registered to `shipyard-cli` and still holds the
`linux-build,packaging` labels. It belongs to a Lima VM that is currently
stopped:

```bash
limactl list                    # shipyard-build  Stopped
limactl stop shipyard-build     # stop, keep disk
limactl delete shipyard-build   # destroy entirely
```

It is harmless while stopped: GitHub only schedules to runners that are online,
so jobs go to the Pi. Two runners sharing the `packaging` label is fine, and
whichever is free takes the job. Delete the registration once the VM is retired:

```bash
gh api repos/shivam-jainn/shipyard-cli/actions/runners \
  --jq '.runners[] | select(.name=="shipyard-linux") | .id'
gh api -X DELETE repos/shivam-jainn/shipyard-cli/actions/runners/<id>
```

To bring the VM back instead, recreate the runner inside it and re-run the
registration step above:

```bash
limactl start --name=shipyard-build --cpus=2 --memory=4 --disk=30
limactl shell shipyard-build -- bash -c '
  set -e
  curl -sL -o /tmp/r.tgz https://github.com/actions/runner/releases/download/v2.337.0/actions-runner-linux-arm64-2.337.0.tar.gz
  mkdir -p ~/actions-runner && tar xzf /tmp/r.tgz -C ~/actions-runner
  sudo apt-get install -y -qq zstd
  curl -sfL -o /tmp/n.tgz https://github.com/goreleaser/nfpm/releases/download/v2.41.3/nfpm_2.41.3_Linux_arm64.tar.gz
  tar xzf /tmp/n.tgz -C /tmp nfpm && sudo install -m755 /tmp/nfpm /usr/local/bin/nfpm
'
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
