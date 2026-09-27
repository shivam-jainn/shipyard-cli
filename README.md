# Shipyard CLI ⚓

<p align="center">
  <strong>The <code>shipyard</code> command-line interface for building, running, and scoring evaluations of autonomous AI agents.</strong>
</p>

<p align="center">
  <a href="https://github.com/shivam-jainn/shipyard-cli/actions"><img src="https://img.shields.io/badge/build-passing-brightgreen.svg" alt="Build Status"></a>
  <a href="https://golang.org"><img src="https://img.shields.io/badge/Go-1.22+-00ADD8?logo=go" alt="Go Version"></a>
  <a href="https://github.com/shivam-jainn/shipyard-web"><img src="https://img.shields.io/badge/docs-shipyard--web-black.svg" alt="Documentation"></a>
  <a href="https://github.com/shivam-jainn/shipyard-cli/blob/main/LICENSE"><img src="https://img.shields.io/badge/License-Proprietary-red.svg" alt="License: Proprietary"></a>
</p>

---

## Repository Role

This repository is the **command-line binary only**. The evaluation engine lives in [`shipyard-core`](https://github.com/shivam-jainn/shipyard-core) and is consumed as a Go module dependency.

| Repository | Role |
| :--- | :--- |
| [`shipyard-core`](https://github.com/shivam-jainn/shipyard-core) | Evaluation engine, agent plugins, sandboxes, ATIF capture, rubrics. Go library. |
| **`shipyard-cli`** (this repo) | The `shipyard` binary, cobra commands, and release pipeline. |
| [`shipyard-web`](https://github.com/shivam-jainn/shipyard-web) | Documentation site and marketing pages. |
| [`shipyard-ci`](https://github.com/shivam-jainn/shipyard-ci) | CI/CD integrations that gate evals in your pipelines. |
| [`shipyard-registry`](https://github.com/shivam-jainn/shipyard-registry) | Prebuilt evalsets and reference agents. |

---

## Requirements

- Go 1.26+
- Docker (for `docker` sandbox environments; use `--env local` to run without it)

The engine dependency is resolved through a `replace` directive pointing at `../shipyard-core`, so clone both repositories side by side:

```bash
git clone https://github.com/shivam-jainn/shipyard-cli.git
cd shipyard-cli
git clone https://github.com/shivam-jainn/shipyard-core.git ../shipyard-core
```

---

## Quickstart

```bash
make init      # download and verify dependencies
make build     # build bin/shipyard
make install   # install to /opt/homebrew/bin or $GOPATH/bin
```

Scaffold and run an evaluation:

```bash
shipyard init eval fix-memory-leak
shipyard run ./fix-memory-leak
```

---

## Commands

| Command | Description |
| :--- | :--- |
| `shipyard init` | Scaffold an `eval` or `evalset` from a built-in template. |
| `shipyard run` | Execute an eval or evalset and score it. |
| `shipyard version` | Print the active version. |
| `shipyard completion` | Generate a shell completion script. |

### Useful flags for `shipyard run`

- `--agent <name>`: Override the agent driver.
- `--provider <name>`: Override the LLM provider (`openai`, `anthropic`, `gemini`, `ollama`, ...).
- `--model <name>`: Override the model name.
- `--command <cmd>`: Override agent execution command.
- `--env <type>`: Override the sandbox type (`docker`, `local`, `custom`).
- `--keep-env`: Retain the sandbox after completion for post-mortem debugging.

### Runtime overrides

Agents, models, providers, and sandbox environments can be swapped on the fly without editing config files.

---

## Development

```bash
make test      # run unit and integration tests
make build     # cross-compile (GOOS=linux GOARCH=amd64 make build)
make clean     # remove build artifacts
```

Version stamping is injected at link time and can be overridden at runtime with the `SHIPYARD_VERSION` environment variable (see [`.env.example`](.env.example)).

---

## Releases

Tagged `v*` pushes build stripped, `-trimpath` binaries for `linux` and `darwin` on `amd64` and `arm64` via [`.github/workflows/release.yml`](.github/workflows/release.yml), and attach them to the GitHub release.

---

## License

**Proprietary — all rights reserved.** This repository is not open source and is not licensed under any open source license.

You may **not** copy, reproduce, redistribute, sublicense, publish, fork, mirror, or create derivative works of this software without prior written authorization. See [LICENSE](LICENSE) for the full terms.
