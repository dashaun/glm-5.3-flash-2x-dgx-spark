#!/bin/bash
# Script to fix model cache permissions on DGX Spark nodes

echo "=== Fixing GLM-5.3-Flash Model Cache Permissions ==="
echo ""

# Source the lib.sh to get access to the helper functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

# Define the model ID and revision from the model environment
MODEL_ID="local-inference-lab/GLM-5.3-Flash-NVFP4-Spark"
MODEL_REVISION="a608241037e4c2565356bff7ca293f2133888f88"

# Function to fix permissions on a node
fix_node_permissions() {
    local node=$1
    local host=$(node_host "$node")
    
    echo "Fixing permissions on $node ($host)..."
    
    # Try to fix ownership of huggingface cache directory
    echo "Attempting to fix huggingface cache permissions on $node..."
    if ssh "$host" "sudo chown -R dashaun:dashaun /home/dashaun/.cache/huggingface 2>/dev/null || echo 'Failed to change ownership'"; then
        echo "Successfully changed ownership on $node"
    else
        echo "Warning: Failed to change ownership on $node"
    fi
    
    # Check if we can access the model cache directory
    local cache_dir="/home/dashaun/.cache/huggingface/hub/models--${MODEL_ID//\//--}"
    
    echo "Checking cache directory on $node: $cache_dir"
    if ssh "$host" "test -d '$cache_dir'"; then
        echo "Cache directory exists on $node"
        # Try to check if we can access it
        if ssh "$host" "ls -la '$cache_dir' 2>/dev/null"; then
            echo "Successfully accessed cache directory on $node"
        else
            echo "Warning: Cannot access cache directory on $node"
        fi
    else
        echo "No cache directory found on $node"
    fi
}

echo "Fixing permissions on both DGX Spark nodes..."

# Test SSH connectivity first
echo "Testing SSH connectivity to nodes..."
if ! ssh "spark-dc25" "true" 2>/dev/null; then
    echo "Cannot connect to spark-dc25 - please check SSH configuration"
    exit 1
fi

if ! ssh "spark-a9cf" "true" 2>/dev/null; then
    echo "Cannot connect to spark-a9cf - please check SSH configuration"
    exit 1
fi

echo "SSH connectivity verified."

# Fix permissions on head node
fix_node_permissions "head"

# Fix permissions on worker node  
fix_node_permissions "worker"

echo ""
echo "=== Permission Fixing Complete ==="
echo "Note: Due to sudo restrictions, we cannot fully fix the ownership issue."
echo "Manual intervention might be required to change ownership to dashaun."
echo "Alternatively, you can try downloading the model manually in offline mode:"
echo "On spark-dc25: HF_HUB_OFFLINE=1 huggingface-cli download --revision $MODEL_REVISION $MODEL_ID"
echo "On spark-a9cf: HF_HUB_OFFLINE=1 huggingface-cli download --revision $MODEL_REVISION $MODEL_ID"