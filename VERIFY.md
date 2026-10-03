# Verification Plan for GLM-5.3-Flash Model Loading Solution

## Prerequisites
- Access to DGX Spark cluster with spark-dc25 and spark-a9cf nodes
- SSH access to both nodes configured properly
- User account with appropriate permissions
- Model environment variables correctly set

## Step-by-Step Verification Process

### 1. Confirm Initial State
```bash
# Check if cache directories exist and their ownership
ssh spark-dc25 "ls -la /home/dashaun/.cache/huggingface/hub/"
ssh spark-a9cf "ls -la /home/dashaun/.cache/huggingface/hub/"

# Check model cache directory specifically
ssh spark-dc25 "ls -la /home/dashaun/.cache/huggingface/hub/models--local-inference-lab--GLM-5.3-Flash-NVFP4-Spark"
ssh spark-a9cf "ls -la /home/dashaun/.cache/huggingface/hub/models--local-inference-lab--GLM-5.3-Flash-NVFP4-Spark"
```

### 2. Execute Cache Clearing
```bash
# Run the fixed cache clearing script
./clear_model_cache.sh

# Verify cache directories are cleared
ssh spark-dc25 "ls -la /home/dashaun/.cache/huggingface/hub/models--local-inference-lab--GLM-5.3-Flash-NVFP4-Spark 2>/dev/null || echo 'Cache cleared on spark-dc25'"
ssh spark-a9cf "ls -la /home/dashaun/.cache/huggingface/hub/models--local-inference-lab--GLM-5.3-Flash-NVFP4-Spark 2>/dev/null || echo 'Cache cleared on spark-a9cf'"
```

### 3. Manual Model Download in Offline Mode
```bash
# Download model on spark-dc25
ssh spark-dc25 "HF_HUB_OFFLINE=1 huggingface-cli download --revision a608241037e4c2565356bff7ca293f2133888f88 local-inference-lab/GLM-5.3-Flash-NVFP4-Spark"

# Download model on spark-a9cf
ssh spark-a9cf "HF_HUB_OFFLINE=1 huggingface-cli download --revision a608241037e4c2565356bff7ca293f2133888f88 local-inference-lab/GLM-5.3-Flash-NVFP4-Spark"
```

### 4. Verify Cache Integrity
```bash
# Check that model cache is properly populated
ssh spark-dc25 "ls -la /home/dashaun/.cache/huggingface/hub/models--local-inference-lab--GLM-5.3-Flash-NVFP4-Spark"
ssh spark-a9cf "ls -la /home/dashaun/.cache/huggingface/hub/models--local-inference-lab--GLM-5.3-Flash-NVFP4-Spark"

# Verify the revision matches expected value
ssh spark-dc25 "ls -la /home/dashaun/.cache/huggingface/hub/models--local-inference-lab--GLM-5.3-Flash-NVFP4-Spark/snapshots/a608241037e4c2565356bff7ca293f2133888f88"
ssh spark-a9cf "ls -la /home/dashaun/.cache/huggingface/hub/models--local-inference-lab--GLM-5.3-Flash-NVFP4-Spark/snapshots/a608241037e4c2565356bff7ca293f2133888f88"
```

### 5. Test vLLM Service Startup
```bash
# Start containers
./start.sh containers

# Start vLLM service
./start.sh serve

# Check status
./status.sh
```

### 6. Validate Service Health
```bash
# Check if vLLM service is responding
ssh spark-dc25 "curl -sf http://127.0.0.1:8000/health"
ssh spark-a9cf "curl -sf http://127.0.0.1:8000/health"
```

### 7. Run Load Tests
```bash
# Run load tests to validate functionality
./loadtest.py
```

## Expected Outcomes
1. Cache directories should be cleared before model download
2. Model should download successfully in offline mode on both nodes
3. Cache directories should contain correct revision files
4. vLLM service should start successfully on both nodes
5. Health checks should return successful responses
6. Load tests should execute without errors

## Troubleshooting
If any step fails:
- Check SSH connectivity to both nodes
- Verify that HF_HUB_OFFLINE=1 is properly set
- Ensure correct model revision is used
- Confirm that the model ID matches expectations
- Check that sufficient disk space is available on both nodes