# Shipyard build runners

Two self-hosted runners, both ARM64, both free (the repository is public, and
self-hosted runners never consume billed minutes regardless of plan).

| Runner | Labels | Host | Builds |
|---|---|---|---|
| `shivams-mbp` | `self-hosted, macOS, ARM64, mbp` | MacBook Pro | Go cross-compiles, darwin binaries, Homebrew formula |
| `shipyard-linux` | `self-hosted, linux, ARM64, linux-build, packaging` | Lima VM (Ubuntu 26.04) | `.deb`, `.rpm`, Arch packages, install tests |

## Why this split

`build-mbp.yml` runs on the Mac. Go cross-compiles every target from a single
host, so linux and darwin binaries are produced there.

`package.yml` runs on Linux because `.deb` and `.rpm` are Linux formats. The
Homebrew formula is macOS-only, so that job stays on the Mac.

Nothing here depends on GitHub-hosted runners, so the pipeline costs $0.

## Footprint (measured, idle)

| Metric | Value |
|---|---|
| RAM | ~91 MB total (~45 MB per process) |
| CPU | 0% |
| Disk (runner proper) | ~414 MB |
| Disk (build caches, `_work`, `_update`) | reclaimable, ~1.2 GB on the Mac |

The runner is light enough for a Pi 3/4. See "Switching to the Pi" below.

## Switching to the Pi

The workflows select on **labels**, not hostnames, so a Pi swap needs no
workflow edits.

1. Get the Pi on the network. It is currently unreachable — the Mac is on the
   5 GHz SSID and the Pi is most likely on a 2.4 GHz SSID it has lost
   credentials for. Re-enter them via `sudo raspi-config` → Network → WiFi, or
   drive it over a USB-C data cable, which works with WiFi entirely broken.

2. Install the Linux runner:

   ```bash
   mkdir -p ~/actions-runner && cd ~/actions-runner
   curl -sL -o r.tar.gz \
     https://github.com/actions/runner/releases/download/v2.327.1/actions-runner-linux-arm64-2.327.1.tar.gz
   tar xzf r.tar.gz
   ```

3. Register it with the **same labels**, so `package.yml` picks it up unchanged:

   ```bash
   TOKEN=$(gh api -X POST repos/shivam-jainn/shipyard-cli/actions/runners/registration-token --jq .token)
   ./config.sh --url https://github.com/shivam-jainn/shipyard-cli \
     --token "$TOKEN" --name 'shipyard-pi' \
     --labels 'self-hosted,linux,ARM64,linux-build,packaging' \
     --work _work --no-default-labels
   ```

4. Install `nfpm` and `zstd` (the `Install nfpm` step does this, but the verify
   step shells out to `zstd`):

   ```bash
   sudo apt-get install -y zstd
   ```

5. Remove the VM runner once the Pi is green:

   ```bash
   gh api repos/shivam-jainn/shipyard-cli/actions/runners \
     --jq '.runners[] | select(.name=="shipyard-linux") | .id'
   gh api -X DELETE repos/shivam-jainn/shipyard-cli/actions/runners/<id>
   ```

Two runners sharing the `packaging` label is fine — GitHub queues the job on
whichever is free.

## The Lima VM is disposable

```bash
limactl stop shipyard-build     # stop, keep disk
limactl delete shipyard-build   # destroy entirely
limactl start shipyard-build    # bring it back
```

The runner config lives inside the VM, so deleting the VM means re-registering.
Recreating the whole thing:

```bash
limactl start --name=shipyard-build --cpus=2 --memory=4 --disk=30
limactl shell shipyard-build -- bash -c '
  set -e
  curl -sL -o /tmp/r.tgz https://github.com/actions/runner/releases/download/v2.327.1/actions-runner-linux-arm64-2.327.1.tar.gz
  mkdir -p ~/actions-runner && tar xzf /tmp/r.tgz -C ~/actions-runner
  sudo apt-get install -y -qq golang-go zstd
  curl -sfL -o /tmp/n.tgz https://github.com/goreleaser/nfpm/releases/download/v2.41.3/nfpm_2.41.3_Linux_arm64.tar.gz
  tar xzf /tmp/n.tgz -C /tmp nfpm && sudo install -m755 /tmp/nfpm /usr/local/bin/nfpm
'
```

Then re-run steps 3 and 4 from the Pi section above.

## Host paths

Lima mounts the host home directory read-write at the same path, which is handy
for local testing but **not** something the workflow relies on. The workflow
builds entirely inside the VM.
