# GLM-5.3-Flash-2x-DGX-Spark

Serve `local-inference-lab/GLM-5.3-Flash-NVFP4-Spark` (165B params, NVFP4) on two DGX Sparks with vLLM, tensor parallel 2 over Ray. Everything runs from your workstation over SSH. Nothing gets installed on the Sparks; the software lives in the `eugr/spark-vllm-b12x` image.

## Prerequisites

- Two DGX Sparks reachable over SSH (Tailscale, DNS or `~/.ssh/config`), linked by QSFP
- Docker on both, with the pinned image pulled
- ~175 GiB free per node for the model cache
- A Hugging Face token for the one-time download

## Setup

### 1. Configure the cluster

```bash
cp cluster.env.example cluster.env   # git-ignored; set HEAD_HOST, WORKER_HOST
./network.sh discover                # fills ETH_IF, IB_HCA, IB_GID_INDEX, HEAD_IP, WORKER_IP
```

### 2. Download the model on both nodes

The containers run with `HF_HUB_OFFLINE=1`, so vLLM never pulls weights at startup. Download them once per node inside the container, which writes to the bind-mounted `~/.cache/huggingface` on the host. The token goes over stdin so it never shows up in a process list or on disk:

```bash
./start.sh containers
read -rs HF_TOKEN
for h in spark-head spark-worker; do
  # ssh re-splits its command on the host: keep the container script inside both quote levels.
  printf '%s\n' "$HF_TOKEN" | ssh "$h" "docker exec -i vllm_node bash -c 'read -r HF_TOKEN; export HF_TOKEN HF_HUB_OFFLINE=0; exec hf download local-inference-lab/GLM-5.3-Flash-NVFP4-Spark --revision a608241037e4c2565356bff7ca293f2133888f88'" &
done; wait
```

Interrupted downloads resume. `./start.sh preflight` refuses to continue until every file referenced by `model.safetensors.index.json` is present on both nodes. That's 35 `model-000NN` shards (named "of-00036") plus the `hf-nonexpert`, `mtp` and `inputscales` files.

**Faster on a shared uplink.** Both Sparks usually share one internet connection, so downloading on both nodes pays for every byte twice. The QSFP link between them is far faster (measured ~1.1 GB/s). Pass `hf download` a subset of filenames on each node, then stream each node's snapshot symlinks and blobs to the other container over the QSFP IPs (tar into a Python socket; the image has no `nc`). After that:
- Copy `refs/main` from a node that has it. `hf download --revision <sha>` doesn't write it.
- Once no download is running, delete leftover `blobs/*.incomplete` files. Preflight rejects them.
- Spot-check a few blobs with `sha256sum`. An LFS blob's filename is its SHA-256.

### 3. Start

```bash
./start.sh          # preflight containers ray mods serve wait
./status.sh
```

`./start.sh help` lists the individual steps. Each one is safe to re-run.

## Results

Measured on 2026-10-03 with the pinned image and the `SERVE_ARGS` in the model file:

| Step | Time |
|---|---|
| Weight load (per rank, from local cache) | ~35 s |
| Model load total (89 GiB per rank) | 71 s |
| CUDA graph capture | 34 s |
| `vllm serve` launch to `/health` OK | 283 s |

While serving, each node shows only 1–2 GiB of host memory available (`--gpu-memory-utilization 0.85` on unified memory). Leave the Sparks to vLLM.

## Configuration

- `cluster.env`: hosts, QSFP IPs, RoCE devices, image digest, ports, timeouts
- `models/glm-5.3-flash-nvfp4-spark.env`: model ID and revision, container env, `vllm serve` flags

Container env changes need `./stop.sh && ./start.sh`. `SERVE_ARGS` changes need only `./stop.sh serve && ./start.sh serve`.

## Scripts

- `start.sh`: bring the cluster up step by step
- `stop.sh`: stop vLLM (`serve`) or everything
- `status.sh`: containers, Ray, vLLM, health (read-only)
- `network.sh`: discover and verify the QSFP/RoCE links
- `loadtest.py`: load the live API (standard library only)

## Troubleshooting

- **Health never goes green and the log stops at "Loading model from scratch".** The weights aren't cached, so vLLM is trying to download them. Run `./start.sh preflight` to see what's missing, then do step 2.
- **Preflight says "incomplete download" but nothing is downloading.** An aborted download left `blobs/*.incomplete` files behind. Check that no `hf download` or `vllm serve` is running, then delete them.
- **Root-owned directories under `~/.cache/huggingface`.** That's expected. The container runs as root and writes to the bind-mounted cache. The directories are world-readable, so preflight can still check them over SSH.

## Sources

- Adapted from [deepseek-v4-flash-2x-dgx-spark](https://github.com/dashaun/deepseek-v4-flash-2x-dgx-spark).
- Model settings from [eugr/spark-vllm-docker](https://github.com/eugr/spark-vllm-docker) `recipes/glm-5.3-flash.yaml` (commit 53bd8e0). See `NOTICE`.
- Model: [local-inference-lab/GLM-5.3-Flash-NVFP4-Spark](https://huggingface.co/local-inference-lab/GLM-5.3-Flash-NVFP4-Spark) @ `a608241`.

## License

Apache-2.0. See `LICENSE`.
