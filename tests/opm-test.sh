#!/bin/bash

echo "=== Ollama Power Management Test Script ==="
echo "Starting test sequence at $(date)"

# Function to show current power state
show_power() {
    echo -e "\nPower Status:"
    echo "============"
    echo -n "GPU Power: "
    nvidia-smi --query-gpu=power.draw --format=csv,noheader
    echo -n "PCIe State: "
    cat /sys/bus/pci/devices/0000:01:00.0/power_state
    echo "Ollama Service: $(systemctl is-active ollama)"
}

# Test sequence
echo -e "\n1. Initial State"
show_power

echo -e "\n2. Starting Ollama"
opm on
sleep 5
show_power

echo -e "\n3. Running Quick Inference"
ollama run qwen2.5-coder:7b "Say hi" --verbose
sleep 5
show_power

echo -e "\n4. Stopping Ollama"
opm off
sleep 5
show_power

echo -e "\nTest completed at $(date)"