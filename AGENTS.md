# AGENTS.md

Guidance for coding agents working in this repo. Read `README.md` for the setup, results and sources.

## What this is

Shell tooling, run from a macOS workstation, that serves GLM-5.3-Flash-NVFP4-Spark on two DGX Sparks.
- **Nodes:** `HEAD_HOST` and `WORKER_HOST` from `cluster.env`, a local git-ignored copy of `cluster.env.example`. `CLUSTER_ENV` selects another file, and the environment can override `HEAD_HOST`/`WORKER_HOST`/`HEAD_IP`/`WORKER_IP`.
- **Model split:** vLLM with tensor parallelism 2 over Ray.
- **Image:** `eugr/spark-vllm-b12x`.
- **Control:** everything goes over SSH (Tailscale hostnames) and `docker` on the hosts.

## Hard constraints

- **Install nothing on the Spark hosts** (no apt, pip or systemd units). All software lives in the container image.
  - Allowed host side effects: the `vllm_node` containers, Docker logs, and the compile-cache directories `~/.cache/vllm`, `~/.cache/flashinfer` and `~/.triton`.
  - The README's one-time host settings (static QSFP IPs, disabling the desktop, the sysctl) are for the **user** to apply. Agents never run `sudo` or change host configuration, and scripts must never do so either.
- **Copy no files onto the hosts.** Stream them into the containers instead (`tar … | ssh host docker exec -i …`) or run commands over SSH.
- **Keep scripts on this machine.** Hosts are driven only through `rsh`, `rdocker` and `cexec` in `lib.sh`.
- **Bash 3.2 compatibility** (macOS `/bin/bash`): no associative arrays, `mapfile`, `${var,,}` or `wait -n`. Expand possibly-empty arrays as `${arr[@]+"${arr[@]}"}` because of `set -u`.
- **`loadtest.py` uses only the Python standard library.**
- **Don't add `--rm`** to the containers. It can leave a container stuck in the "Dead" state if its automatic removal races with `docker rm`, and without it, exited containers stay available for inspection.
- **Pin images by digest** in `cluster.env`, and change the digest only on purpose, identically for both nodes.
- **No site-specific values in committed files.** Hostnames, IPs and usernames belong only in the local `cluster.env`. Use generic placeholders in `cluster.env.example`, docs and scripts, and keep that template in sync when adding settings.

## Configuration

- **`cluster.env`:** hosts, QSFP IPs, `ETH_IF`, `IB_HCA`, `IB_GID_INDEX`, image, ports, timeouts.
- **Network values** (`ETH_IF`, `IB_HCA`, `IB_GID_INDEX`, `HEAD_IP`, `WORKER_IP`) come from `./network.sh discover`. It only reads sysfs, `ip` and `ping` on the hosts, and rewrites just those keys in `cluster.env`, keeping comments. `network.sh` sets `LIB_REQUIRE` before sourcing `lib.sh` because the IPs may not be known yet.
- **`models/<MODEL>.env`:** `MODEL_ID`, `MODEL_REVISION`, `TP_SIZE`, `MODS`, `MODEL_CONTAINER_ENV` (set at `docker run` so Ray workers inherit it), and `SERVE_ARGS`.
- **Adding a model:** create a new `models/*.env` and switch `MODEL=`. Don't hard-code model details in scripts.
- **Changes that need a full restart:** container-level settings (env vars, image, `IB_HCA`) require `./stop.sh && ./start.sh`.
- **Changes that need only a vLLM restart:** `SERVE_ARGS` changes need `./stop.sh serve && ./start.sh serve`.

## Script conventions

- **Steps:** each `start.sh` step is a `step_*` function. It must be safe to re-run, skip work already done, and exit through `die` with a message naming the command that fixes the problem.
- **Both nodes:** use `on_nodes FUNC` for per-node work. It runs in parallel with `[head]`/`[worker]` prefixes.
- **Remote commands:** `rsh` quotes each argument once with `printf %q`. Pass arguments as separate words, not pre-quoted strings. Use `rsh_in`/`rdocker_in` only when stdin must be forwarded; everything else uses `ssh -n`.
- **`docker inspect`:** it prints an empty line before failing on a missing container. Capture the output and check that it isn't empty (see `container_state`), rather than using `|| echo`.
- **Output:** use `log`, `ok`, `warn` and `die`.

## Verifying changes

1. Run `/bin/bash -n` on every `.sh` file and on the env files, and `shellcheck -x -s bash *.sh`, which must be clean. Suppress a finding only with an inline `# shellcheck disable=SCxxxx # reason`.
2. Run `./start.sh help` (local only).
3. Run `./start.sh preflight` and `./network.sh verify` (both read-only on the hosts; `verify` sends jumbo pings, which is safe while serving).
4. Run `./status.sh` (read-only).

Commands that affect the running service need the user's go-ahead first: `stop.sh`, `start.sh serve`, `start.sh nccl-test` (needs vLLM stopped), and `loadtest.py` (loads the live API).