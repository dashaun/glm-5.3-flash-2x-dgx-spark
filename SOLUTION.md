# Solution for GLM-5.3-Flash Model Loading Issue on DGX Spark Cluster

## Problem Summary
The vLLM service fails to start on the DGX Spark cluster when trying to load the GLM-5.3-Flash model in offline mode. The root cause is that model cache directories are owned by `root` instead of the user (`dashaun`), preventing proper access during model loading.

## Root Cause Analysis
1. **Model Cache Ownership**: The Hugging Face cache directories are owned by `root` instead of `dashaun`
2. **Offline Mode Limitations**: While `HF_HUB_OFFLINE=1` is set, the model cache still needs to be properly accessible
3. **Permission Issues**: Container processes run as `root` and cannot access user-owned cache directories
4. **Incomplete Cache**: Model cache directories exist but contain incomplete or corrupted files

## Resolution Steps

### Step 1: Clear Existing Model Cache
```bash
./clear_model_cache.sh
```

### Step 2: Download Model in Offline Mode (Manual Process)
Due to permission limitations, manually download the model on each node:

On spark-dc25:
```bash
HF_HUB_OFFLINE=1 huggingface-cli download --revision a608241037e4c2565356bff7ca293f2133888f88 local-inference-lab/GLM-5.3-Flash-NVFP4-Spark
```

On spark-a9cf:
```bash
HF_HUB_OFFLINE=1 huggingface-cli download --revision a608241037e4c2565356bff7ca293f2133888f88 local-inference-lab/GLM-5.3-Flash-NVFP4-Spark
```

### Step 3: Verify Cache Integrity
Check that the model cache is correctly populated on both nodes:
```bash
ssh spark-dc25 "ls -la /home/dashaun/.cache/huggingface/hub/models--local-inference-lab--GLM-5.3-Flash-NVFP4-Spark"
ssh spark-a9cf "ls -la /home/dashaun/.cache/huggingface/hub/models--local-inference-lab--GLM-5.3-Flash-NVFP4-Spark"
```

### Step 4: Start vLLM Service
```bash
./start.sh containers
./start.sh serve
```

## Alternative Solutions

### Option 1: Fix Ownership Permissions
Try running the permission fixing script:
```bash
./fix_permissions.sh
```

### Option 2: Modify Container Startup
Update the container startup to properly handle cache permissions by modifying the container environment to ensure proper ownership.

## Verification Steps
1. Run `./status.sh` to check cluster status
2. Run `./start.sh serve` to start vLLM service
3. Check that `vllm serve` is running with `./status.sh`
4. Run load tests with `./loadtest.py` to verify functionality

## Key Findings
- The model cache directories exist but are owned by `root` instead of `dashaun`
- Container environments run as `root` and cannot access user-owned cache directories
- Manual model downloading in offline mode is required due to permission restrictions
- Both nodes must have consistent model cache with correct revision (a608241037e4c2565356bff7ca293f2133888f88)

## Technical Details
- Model ID: `local-inference-lab/GLM-5.3-Flash-NVFP4-Spark`
- Model Revision: `a608241037e4c2565356bff7ca293f2133888f88`
- Cache Directory: `/home/dashaun/.cache/huggingface/hub/models--local-inference-lab--GLM-5.3-Flash-NVFP4-Spark`
- Container Image: `eugr/spark-vllm-b12x@sha256:8e7e062186f841453ef0ec6f713043c5b65447decc3835206685128c18e42262`

## Additional Notes
- The `clear_model_cache.sh` script has been fixed to address shell compatibility issues
- The `simple_clear_cache.sh` script provides an alternative approach with hardcoded paths
- The `fix_permissions.sh` script attempts to fix ownership issues but may face sudo restrictions
- Ensure both nodes have synchronized model cache directories with the correct revision