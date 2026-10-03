# Resolving GLM-5.3-Flash Model Loading Issues on DGX Spark Cluster

## The Problem

We encountered a frustrating issue while trying to deploy the GLM-5.3-Flash-NVFP4-Spark model on a two-node DGX Spark cluster. Despite setting `HF_HUB_OFFLINE=1` to enable offline mode, the vLLM service would fail to start with errors indicating it couldn't find the model in the cache. The error message pointed to a missing model file at `/home/dashaun/.cache/huggingface/hub/models--local-inference-lab--GLM-5.3-Flash-NVFP4-Spark/refs/main`, suggesting the model wasn't properly cached.

## Initial Investigation

Our investigation revealed several key issues:

1. **Incorrect Model Cache Ownership**: While the model cache directory existed, it was owned by `root` instead of the `dashaun` user. This caused permission issues when vLLM tried to access the cached files.

2. **Incomplete Model Cache**: Even though the cache directory existed, it contained only a few files and was missing critical model components.

3. **Offline Mode Limitations**: Setting `HF_HUB_OFFLINE=1` doesn't completely prevent all network activity - the system still attempts to access the model cache, which failed due to ownership issues.

4. **Container Environment Mismatch**: The container environment correctly set `HF_HUB_OFFLINE=1`, but the model download process still attempted to access the cache, leading to failures.

## The Solution Approach

Rather than relying solely on automated cache clearing, we took a systematic approach to resolve the issues:

### Step 1: Identify Root Cause
We first identified that the model cache directories existed but had incorrect ownership (root vs dashaun) and incomplete files. The `clear_model_cache.sh` script was failing due to shell compatibility issues with `printenv HOME` on the DGX nodes.

### Step 2: Fix Script Compatibility
We corrected the `clear_model_cache.sh` script by replacing `printenv HOME` with `echo $HOME` to ensure proper shell compatibility across different environments.

### Step 3: Clear Cache on Both Nodes
We executed the fixed `clear_model_cache.sh` script to clear the model cache on both DGX Spark nodes (spark-dc25 and spark-a9cf), ensuring both nodes started with clean caches.

### Step 4: Manual Offline Model Download
Due to permission restrictions preventing automatic downloads, we manually downloaded the model in offline mode on both nodes using the exact revision hash (`a608241037e4c2565356bff7ca293f2133888f88`). This involved:
- Using `huggingface_hub` library to download the model
- Setting `HF_HUB_OFFLINE=1` to enforce offline mode
- Verifying the model cache was populated with correct revision files

### Step 5: Verify Consistency Across Nodes
We ensured both nodes had identical model cache states with the correct revision, which was essential for successful Ray cluster operation.

## Why This Approach Worked

The core insight was that the offline mode setting alone wasn't sufficient to prevent the permission-related issues that were blocking the vLLM service. The solution addressed multiple interconnected problems:

1. **Permission Issues**: By clearing the cache and manually downloading in offline mode, we ensured proper ownership and file completeness.
2. **Script Compatibility**: The fix to `clear_model_cache.sh` made it work reliably across different shell environments.
3. **Consistent State**: Ensuring both nodes had identical, complete model caches was crucial for the distributed Ray cluster setup.

## Key Technical Details

- **Model Revision**: The exact model revision `a608241037e4c2565356bff7ca293f2133888f88` was required to match expected hash.
- **Node Consistency**: Both DGX Spark nodes (spark-dc25 and spark-a9cf) needed synchronized model cache states.
- **Cache Integrity**: We verified that model cache directories contained proper file linking and content.
- **Environment Variables**: The container environment correctly set `HF_HUB_OFFLINE=1` but required manual intervention due to permission restrictions.

## Result

After implementing this solution, the vLLM service started successfully on both nodes. The model was properly loaded in offline mode, and the distributed Ray cluster operated as expected. This approach demonstrates the importance of considering not just environment settings but also file permissions, cache state consistency, and shell compatibility when deploying complex AI models in distributed environments.

The solution highlights the nuanced challenges of offline AI model deployment in production environments where permission constraints and distributed systems requirements must all align for successful operation.