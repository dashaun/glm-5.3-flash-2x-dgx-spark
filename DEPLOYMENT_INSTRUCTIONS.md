# Deployment Instructions for GLM-5.3-Flash-NVFP4-Spark on DGX Sparks

## Prerequisites
- SSH access to DGX Spark nodes (spark-dc25 and spark-a9cf)
- Docker installed on both nodes
- Sufficient disk space (~166 GB per node for model cache)

## Deployment Steps

### 1. Verify Cluster Configuration
Ensure `cluster.env` has correct hostnames:
```bash
HEAD_HOST=spark-dc25
WORKER_HOST=spark-a9cf
```

### 2. Prepare Model Cache (Offline Mode)
Download model manually on both nodes:
```bash
# On spark-dc25
HF_HUB_OFFLINE=1 huggingface-cli download --revision a608241037e4c2565356bff7ca293f2133888f88 local-inference-lab/GLM-5.3-Flash-NVFP4-Spark

# On spark-a9cf  
HF_HUB_OFFLINE=1 huggingface-cli download --revision a608241037e4c2565356bff7ca293f2133888f88 local-inference-lab/GLM-5.3-Flash-NVFP4-Spark
```

### 3. Deploy and Start Services
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

### 4. Run Load Testing
```bash
./loadtest.py
```

## Important Notes
- The model requires ~166 GB of storage per node
- Uses B12X attention backend for optimal performance
- Configured with `HF_HUB_OFFLINE=0` in model env (not 1 as noted in README)
- Requires proper InfiniBand/RoCE networking setup