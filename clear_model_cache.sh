#!/bin/bash
# Script to clear model cache on DGX Spark nodes for GLM-5.3-Flash model

# This script should be run from the macOS host to clear model cache on remote nodes

# Source the lib.sh to get access to the helper functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

echo "=== Clearing GLM-5.3-Flash Model Cache ==="
echo ""

# Define the model ID and revision from the model environment
MODEL_ID="local-inference-lab/GLM-5.3-Flash-NVFP4-Spark"
MODEL_REVISION="a608241037e4c2565356bff7ca293f2133888f88"

# Function to clear cache on a node
clear_node_cache() {
    local node=$1
    local host=$(node_host "$node")
    
    echo "Clearing cache on $node ($host)..."
    
    # Get home directory
    local home
    home=$(rsh "$host" "echo \$HOME")
    
    # Define cache directory using the same logic as start.sh
    local cache_dir="$home/.cache/huggingface/hub/models--${MODEL_ID//\//--}"
    
    echo "Cache directory on $node: $cache_dir"
    
    # Check if cache exists and remove it
    if rsh "$host" "test -d '$cache_dir'"; then
        echo "Removing cache directory on $node..."
        rsh "$host" "rm -rf '$cache_dir'"
        echo "Cache cleared on $node"
    else
        echo "No cache directory found on $node"
    fi
    
    # Verify removal
    if rsh "$host" "test -d '$cache_dir'"; then
        echo "Warning: Cache directory still exists on $node"
    else
        echo "Successfully cleared cache on $node"
    fi
}

# Clear cache on both nodes
echo "Clearing model cache on both DGX Spark nodes..."

# Test SSH connectivity first
echo "Testing SSH connectivity to nodes..."
if ! rsh "spark-dc25" "true" 2>/dev/null; then
    echo "Cannot connect to spark-dc25 - please check SSH configuration"
    exit 1
fi

if ! rsh "spark-a9cf" "true" 2>/dev/null; then
    echo "Cannot connect to spark-a9cf - please check SSH configuration"
    exit 1
fi

echo "SSH connectivity verified."

# Clear cache on head node
clear_node_cache "head"

# Clear cache on worker node  
clear_node_cache "worker"

echo ""
echo "=== Cache Clearing Complete ==="
echo "Next steps to resolve the vLLM startup issue:"
echo "1. Manually download the model in offline mode on each node:"
echo "   On spark-dc25: HF_HUB_OFFLINE=1 huggingface-cli download --revision $MODEL_REVISION $MODEL_ID"
echo "   On spark-a9cf: HF_HUB_OFFLINE=1 huggingface-cli download --revision $MODEL_REVISION $MODEL_ID"
echo "2. Run './start.sh containers' to restart containers"
echo "3. Run './start.sh serve' to start vLLM service"