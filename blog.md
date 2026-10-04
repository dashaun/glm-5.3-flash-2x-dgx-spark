# GLM-5.3-Flash on Two DGX Sparks: The Weights Were Never There

```
(Worker_TP1 pid=289) INFO [model_runner.py:390] Loading model from scratch...
```

That was the last line in the log. Twenty minutes later it was still the last line. The containers were up, Ray saw both GPUs, `vllm serve` had a PID. Nothing was crashing, so nothing looked broken.

## What was actually happening

The model cache told the story:

```
head:   4.7G   0 safetensors in the snapshot, 16 *.incomplete blobs
worker: 18G    no refs/main at all,           8 *.incomplete blobs
```

`local-inference-lab/GLM-5.3-Flash-NVFP4-Spark` is 58 files and 174.8 GiB. Neither node had it. The model env had `HF_HUB_OFFLINE=0`, right under a comment saying "never reach out to the Hub at startup." So vLLM did the polite thing and started downloading 175 GiB on each node, with no token, at 8 MiB/s on one Spark and 40 MiB/s on the other. "Loading model from scratch" meant "see you in six hours."

An earlier pass at this went down the wrong road. It saw root-owned directories in `~/.cache/huggingface` and decided the problem was ownership. It wasn't. The container runs as root and writes into the bind-mounted cache, so root-owned directories are just what that looks like. That detour came with `sudo chown`, a `pip install` on the host and a pile of "clear the cache" scripts. None of it touched the actual problem, and all of it broke the one rule this repo has: install nothing on the Sparks.

## Fix the config, then make preflight honest

First, the flag:

```bash
MODEL_CONTAINER_ENV=(
  ...
  HF_HUB_OFFLINE=1
)
```

Then the part that should have caught this on day one. Preflight checked for `refs/main`, the snapshot directory and `*.incomplete` blobs. A snapshot with `config.json` and zero weights passed all three. Now it checks every file the index references:

```bash
missing=$(rsh "$host" bash -c 'cd "$1" && test -f model.safetensors.index.json || { echo model.safetensors.index.json; exit; }
  grep -oE "\"[^\"]+\.safetensors\"" model.safetensors.index.json | tr -d "\"" | sort -u |
    while read -r f; do test -e "$f" || echo "$f"; done' _ "$dir/snapshots/$ref")
```

That check paid for itself an hour later.

## Download once, then let QSFP do the rest

Both Sparks sit behind the same internet uplink. I measured it: the head alone pulled 15 MiB/s, and both together pulled 19. Downloading on both nodes means paying for every byte twice on a shared pipe.

The two Sparks also have a 200 Gb QSFP link between them. So: split the files, download half on each node inside its container, then swap halves container to container.

```bash
# token goes over stdin, never into a process list or onto the host's disk
printf '%s\n' "$HF_TOKEN" | ssh spark-head "docker exec -i vllm_node bash -c 'read -r HF_TOKEN; export HF_TOKEN HF_HUB_OFFLINE=0; exec hf download $MODEL --revision $REV <even shards>'"
```

The swap is tar piped through a few lines of Python socket code, since the image has no `nc`. 78.8 GiB went across in 73 seconds.

Then preflight failed:

```
ERR 9 weight file(s) missing on spark-head, e.g. model-hf-nonexpert-00001-of-00004.safetensors
```

I had split on `model-000NN` shards. The repo also ships `hf-nonexpert`, `mtp` and `inputscales` files that the index points at. Without the new check, vLLM would have tried to fetch them at startup, this time against `HF_HUB_OFFLINE=1`, and failed. One more 15 GiB download on the head, one more swap, and preflight went green.

A few things that bit along the way:

- **Quoting through `ssh`.** `ssh host docker exec c bash -c '...'` re-splits the command on the host, so only the first word runs in the container. Keep the container script inside both quote levels.
- **`refs/main`.** `hf download --revision <sha>` doesn't write it, and preflight wants it. I copied it over with the head's shards.
- **Stale `.incomplete` blobs.** The aborted vLLM downloads left 36 GiB of them, and preflight rejects them. Delete them once nothing is downloading.
- **"of-00036".** The shard names say 36. There are 35.

## Result

```
ok healthy after 283s — API: http://spark-head:8000/v1
```

Weights loaded in 35 seconds per rank, the full model load took 71 seconds at 89 GiB per rank, and CUDA graph capture took 34 seconds. Ask it to reply with exactly "ok" and it thinks for 73 tokens and says `ok`.

If your startup log goes quiet at "Loading model from scratch," check the snapshot before you check anything else:

```bash
cd ~/.cache/huggingface/hub/models--<org>--<model>/snapshots/*/ && ls *.safetensors | wc -l
```
