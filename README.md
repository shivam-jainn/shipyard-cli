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
| **`shipyard-cli`** (this repo) | The `shipyard` command-line binary. |
| [`shipyard-web`](https://github.com/shivam-jainn/shipyard-web) | Documentation site and marketing pages. |
| [`shipyard-ci`](https://github.com/shivam-jainn/shipyard-ci) | CI/CD integrations that gate evals in your pipelines. |
| [`shipyard-registry`](https://github.com/shivam-jainn/shipyard-registry) | Prebuilt evalsets and reference agents. |

---

## Requirements

- macOS or Linux, amd64 or arm64
- Docker, for `docker` sandbox environments (use `--env local` to run without it)
- `python3`, because the engine runs every rubric as `python3 <script>`
- `git`, since evalsets may reference remote agent repositories

**There is no Go requirement to install Shipyard.** You install a prebuilt binary.

---

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/shivam-jainn/shipyard-cli/main/install.sh | sh
```

That installs the latest **stable** release. The installer verifies the
SHA256 checksum before writing anything, and it only needs `curl` and `tar`.

```bash
# follow the test channel while you evaluate a new CLI
curl -fsSL https://raw.githubusercontent.com/shivam-jainn/shipyard-cli/main/install.sh \
  | sh -s -- --channel test

# pin an exact version, which is what you want in CI
curl -fsSL https://raw.githubusercontent.com/shivam-jainn/shipyard-cli/main/install.sh \
  | sh -s -- --version v0.1.0
```

| Channel | Tracks | Use for |
| :--- | :--- | :--- |
| `stable` | latest non-prerelease | production |
| `test` | latest `-alpha` / `-beta` / `-rc` | validating a release against your evals |
| `dev` | latest `-dev` build | debugging the CLI itself |

Or run it as a container, which is the easiest way to get Docker-in-Docker
sandboxing:

```bash
docker run --rm -it -v "$PWD:/src" -v /var/run/docker.sock:/var/run/docker.sock \
  ghcr.io/shivam-jainn/shipyard-cli:latest run ./my-eval
```

Verify, and uninstall:

```bash
shipyard version     # version, CLI commit, engine commit, channel
./install.sh --uninstall
```

---

## Quickstart

```bash
shipyard init eval fix-memory-leak
shipyard run ./fix-memory-leak
```

Inspect what ran:

```bash
shipyard version          # which build this is
cat fix-memory-leak/rollouts/*/metrics.json
```

Rollouts are written to `<eval-path>/rollouts/<run-id>/` containing
`trajectory.json`, `metrics.json`, `rubrics.json`, and `artifacts/`.

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

## License

**Proprietary — all rights reserved.** This repository is not open source and is not licensed under any open source license.

You may **not** copy, reproduce, redistribute, sublicense, publish, fork, mirror, or create derivative works of this software without prior written authorization. See [LICENSE](LICENSE) for the full terms.
