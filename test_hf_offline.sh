#!/bin/bash

# Test script to verify HF_HUB_OFFLINE behavior with GLM model

echo "=== Testing HF_HUB_OFFLINE settings ==="

# Test 1: Check current model configuration
echo "1. Current model configuration:"
grep -E "(MODEL_ID|HF_HUB_OFFLINE)" models/glm-5.3-flash-nvfp4-spark.env

# Test 2: Check if model cache exists
echo -e "\n2. Checking Hugging Face cache:"
if [ -d "$HOME/.cache/huggingface/hub/" ]; then
    echo "   Cache directory exists"
    ls -la "$HOME/.cache/huggingface/hub/" 2>/dev/null | head -5
else
    echo "   Cache directory does not exist"
fi

# Test 3: Check if model is available locally
echo -e "\n3. Checking for local model files:"
if [ -d "/Users/dashaun/fun/dashaun/glm-5.3-flash-2x-dgx-spark/models/local-inference-lab/GLM-5.3-Flash-NVFP4-Spark" ]; then
    echo "   Local model directory exists"
    ls -la "/Users/dashaun/fun/dashaun/glm-5.3-flash-2x-dgx-spark/models/local-inference-lab/GLM-5.3-Flash-NVFP4-Spark" 2>/dev/null | head -5
else
    echo "   Local model directory does not exist"
fi

# Test 4: Show environment variables that would be set
echo -e "\n4. Environment variables that would be set:"
echo "   HF_HUB_OFFLINE=1 (current)"
echo "   Would this cause issues with model loading?"

echo -e "\n=== Test Complete ==="