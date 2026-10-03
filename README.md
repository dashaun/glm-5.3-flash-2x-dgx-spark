# GLM-5.3-Flash-2x-DGX-Spark

This repository contains the necessary scripts and configurations to deploy and run the GLM-5.3-Flash-NVFP4-Spark model on a 2x DGX Spark cluster using vLLM with tensor parallelism 2.

## Overview

This setup deploys the GLM-5.3-Flash model (165B parameters, ~166 GB) on two DGX Spark nodes using vLLM with Ray distributed execution. The model uses NVFP4 quantization and is optimized for the DGX Spark architecture with B12X attention backend.

## Architecture

- **Model**: GLM-5.3-Flash-NVFP4-Spark (165B parameters)
- **Deployment**: 2x DGX Spark nodes with TP=2 over Ray
- **Framework**: vLLM with B12X attention backend
- **Quantization**: NVFP4 (165B params, ~166 GB)
- **Communication**: InfiniBand with RoCE devices

## Prerequisites

- Two DGX Spark nodes (spark-dc25 and spark-a9cf)
- Tailscale or direct SSH access to both nodes
- Pre-downloaded model in offline mode
- Docker installed on both nodes
- Sufficient disk space (~166 GB per node for model cache)

## Setup Instructions

### 1. Configure Cluster Settings

Edit `cluster.env` to set your cluster configuration:
```bash
HEAD_HOST=spark-dc25
WORKER_HOST=spark-a9cf
HEAD_IP=192.168.200.1
WORKER_IP=192.168.200.2
```

### 2. Configure Model Settings

The model is pre-configured in `models/glm-5.3-flash-nvfp4-spark.env` with:
- Model ID: `local-inference-lab/GLM-5.3-Flash-NVFP4-Spark`
- Revision: `a608241037e4c2565356bff7ca293f2133888f88`
- Tensor Parallel Size: 2
- HF_HUB_OFFLINE=1 (for offline mode)

### 3. Prepare Model Cache

Since this uses offline mode, you must manually download the model:
```bash
# On spark-dc25
HF_HUB_OFFLINE=1 huggingface-cli download --revision a608241037e4c2565356bff7ca293f2133888f88 local-inference-lab/GLM-5.3-Flash-NVFP4-Spark

# On spark-a9cf
HF_HUB_OFFLINE=1 huggingface-cli download --revision a608241037e4c2565356bff7ca293f2133888f88 local-inference-lab/GLM-5.3-Flash-NVFP4-Spark
```

### 4. Deploy and Start Services

```bash
# Clear existing model cache
./clear_model_cache.sh

# Start containers
./start.sh containers

# Start vLLM service
./start.sh serve

# Check status
./status.sh
```

## Scripts Overview

- `start.sh` - Main orchestration script for deployment
- `stop.sh` - Stop vLLM service and containers
- `status.sh` - Show cluster status and health
- `loadtest.py` - Load testing script for validation
- `clear_model_cache.sh` - Clear model cache on both nodes
- `fix_permissions.sh` - Attempt to fix model cache ownership issues

## Key Features

- **Offline Mode Support**: Uses `HF_HUB_OFFLINE=1` to prevent internet access
- **Tensor Parallelism**: 2x DGX Spark with TP=2 over Ray
- **B12X Optimizations**: Uses B12X attention backend for performance
- **Persistent Caching**: Mounts compile caches for faster restarts
- **NCCL Integration**: Uses InfiniBand with RoCE for efficient communication

## Troubleshooting

### Model Loading Issues
If vLLM fails to start due to model loading issues:
1. Verify model cache is properly downloaded in offline mode
2. Check that model cache directories are owned by the correct user
3. Ensure both nodes have synchronized model cache with correct revision

### Permission Issues
If you encounter permission issues:
1. Run `./clear_model_cache.sh` to reset cache state
2. Manually download model in offline mode on both nodes
3. Verify cache directory ownership on both nodes

## Performance Considerations

- The model requires ~166 GB of storage per node
- Uses B12X attention backend for optimal performance
- Configured with `gpu-memory-utilization 0.87` for stable operation
- Uses `--max-model-len 500000` to manage memory pressure
- Implements speculative decoding for improved throughput

## Documentation

- **SOLUTION.md**: Complete solution for model loading issues
- **VERIFY.md**: Step-by-step verification process

## License

This project is licensed under the Apache-2.0 License - see the LICENSE file for details.