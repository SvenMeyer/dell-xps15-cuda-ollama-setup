# Dell XPS 15 Power Management and CUDA Setup Guide

A comprehensive guide for optimizing power consumption and CUDA performance on Dell XPS 15 laptops running Manjaro Linux, with specific focus on Ollama LLM support.

## Table of Contents
1. [Overview and Prerequisites](#1-overview-and-prerequisites)
2. [Basic Power Optimization](#2-basic-power-optimization)
3. [NVIDIA Setup](#3-nvidia-setup)
4. [Ollama Configuration](#4-ollama-configuration)
5. [Power Management Tools](#5-power-management-tools)
6. [Automated Setup](#6-automated-setup)
7. [Troubleshooting](#7-troubleshooting)

## 1. Overview and Prerequisites

### System Specifications
- System: Dell XPS 15 9530
- CPU: Intel i7-13700H
- GPU: NVIDIA RTX 4070 Laptop (8GB)
- OS: Manjaro Linux XFCE
- Kernel: Linux 6.12.4-1-MANJARO

### Expected Outcomes
- Idle Power: ~3.45W (hybrid mode, no network)
- With USB-Ethernet: ~6W
- Ollama Active: ~11-14W
- Active Inference: ~20-35W

### Power Management Strategy
Our approach focuses on:
1. Boot into hybrid mode (allows GPU access without reboot)
2. Keep Ollama service disabled by default
3. Enable Ollama only when needed via `opm` tool
4. Maintain flexibility while optimizing power

### Required Packages
```bash
sudo pacman -S --needed \
    nvidia \
    nvidia-utils \
    cuda \
    cuda-tools \
    optimus-manager \
    powertop \
    nvidia-settings \
    nvtop \
    s-tui
```

## 2. Basic Power Optimization

### BIOS Configuration
1. Enter BIOS (F2 during boot)
2. Navigate to "Storage" section
3. Change "SATA/NVMe Operation" from "RAID On" to "AHCI/NVMe"
4. Save and exit

### PowerTOP Setup
```bash
# Install PowerTOP
sudo pacman -S powertop

# Create service file
sudo tee /etc/systemd/system/powertop.service << 'EOF'
[Unit]
Description=PowerTOP auto tune

[Service]
Type=oneshot
Environment="TERM=dumb"
ExecStart=/usr/bin/powertop --auto-tune
RemainAfterExit=true

[Install]
WantedBy=multi-user.target
EOF

# Enable service
sudo systemctl enable powertop.service
```

### GRUB Configuration
```bash
# Edit GRUB configuration
sudo mousepad /etc/default/grub
```

Update the following line:
```bash
GRUB_CMDLINE_LINUX_DEFAULT="nosplash acpi_osi=Linux pcie_aspm=force intel_pstate=passive i915.enable_rc6=1 i915.enable_fbc=1 nmi_watchdog=0 libata.force=noncq"
```

Apply changes:
```bash
sudo update-grub
```

## 3. NVIDIA Setup

### Driver Installation
```bash
# Install NVIDIA drivers and tools
sudo pacman -S --needed nvidia nvidia-utils cuda cuda-tools
```

### Optimus Manager Configuration
```bash
# Install Optimus Manager
sudo pacman -S optimus-manager

# Create configuration
sudo tee /etc/optimus-manager/optimus-manager.conf << 'EOF'
[optimus]
switching=hybrid
pci_power_control=yes
pci_remove=no
pci_power_setup=yes
startup_mode=hybrid
startup_auto=yes

[intel]
driver=modesetting
modeset=yes
tearfree=yes

[nvidia]
dynamic_power_management=fine
options=overclocking,triple_buffer
dynamic_power_management_memory=yes
EOF

# Disable Ollama service from auto-starting
sudo systemctl disable ollama
```

### NVIDIA Power Management
```bash
# Create NVIDIA power management rules
sudo tee /etc/udev/rules.d/80-nvidia-pm.rules << 'EOF'
# Enable runtime PM for NVIDIA VGA/3D controller devices
ACTION=="bind", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x030000", TEST=="power/control", ATTR{power/control}="auto"
ACTION=="bind", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x030200", TEST=="power/control", ATTR{power/control}="auto"

# Enable runtime PM for NVIDIA Audio devices
ACTION=="bind", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x040300", TEST=="power/control", ATTR{power/control}="auto"
EOF

# Set power limits
sudo nvidia-smi -pm 1
sudo nvidia-smi -pl 35
```

## 4. Ollama Configuration

### Installation
```bash
# Install Ollama
curl -fsSL https://ollama.com/install.sh | sh

# Create CUDA configuration directory
sudo mkdir -p /etc/systemd/system/ollama.service.d

# Create CUDA configuration
sudo tee /etc/systemd/system/ollama.service.d/cuda.conf << 'EOF'
[Service]
Environment="NVIDIA_VISIBLE_DEVICES=all"
Environment="CUDA_VISIBLE_DEVICES=0"
Environment="OLLAMA_CUDA=1"
Environment="CUDA_MODULE_LOADING=LAZY"
Environment="CUDA_CACHE_DISABLE=0"
Environment="NVIDIA_DRIVER_CAPABILITIES=compute,utility"
Environment="OLLAMA_KEEP_ALIVE=0"
EOF

# Reload systemd
sudo systemctl daemon-reload
```

### Power Management Script (opm)
```bash
# Create the opm script
sudo tee /usr/local/bin/opm << 'EOF'
#!/bin/bash

case "$1" in
    "on")
        echo "=== Enabling NVIDIA GPU and Ollama ==="
        sudo systemctl start ollama
        echo "Ollama ready. Current power state:"
        nvidia-smi --query-gpu=power.draw --format=csv,noheader
        ;;
        
    "off")
        echo "=== Stopping Ollama Service ==="
        sudo systemctl stop ollama
        echo "Waiting for power state to stabilize..."
        sleep 3
        echo "Current power draw:"
        nvidia-smi --query-gpu=power.draw --format=csv,noheader
        echo -e "\nPCIe State:"
        cat /sys/bus/pci/devices/0000:01:00.0/power_state
        ;;
        
    "gpu-switch")
        echo "=== Switching GPU Mode ==="
        if [ "$2" != "integrated" ] && [ "$2" != "hybrid" ]; then
            echo "Error: gpu-switch requires either 'integrated' or 'hybrid' as parameter"
            echo
            echo "integrated - Completely disable NVIDIA GPU (lowest power, ~4W)"
            echo "            Use this when you won't need CUDA for an extended period"
            echo "            Requires reboot to take effect"
            echo
            echo "hybrid     - Enable NVIDIA GPU for CUDA (higher idle power, ~6-14W)"
            echo "            Required for running Ollama and other CUDA applications"
            echo "            Requires reboot to take effect"
            exit 1
        fi
        optimus-manager --switch "$2"
        echo "GPU switch to $2 mode requested. Will take effect after reboot."
        ;;
        
    "status")
        echo "=== Current Power Status ==="
        echo -e "\nOptimus Manager Status:"
        optimus-manager --status
        echo -e "\nOllama Service Status:"
        systemctl status ollama --no-pager
        echo -e "\nPower Draw:"
        nvidia-smi --query-gpu=power.draw --format=csv,noheader
        echo -e "\nPCIe State:"
        cat /sys/bus/pci/devices/0000:01:00.0/power_state
        ;;
        
    *)
        echo "Usage: $0 {on|off|gpu-switch|status}"
        echo
        echo "Basic Power Management:"
        echo "  on     - Start Ollama service"
        echo "  off    - Stop Ollama service (reduces power immediately)"
        echo "  status - Show current power and service status"
        echo
        echo "Advanced GPU Control:"
        echo "  gpu-switch {integrated|hybrid} - Switch GPU power modes:"
        echo "    integrated - Completely disable NVIDIA GPU (lowest power, ~4W)"
        echo "                Use this when you won't need CUDA for an extended period"
        echo "    hybrid     - Enable NVIDIA GPU for CUDA (higher idle power, ~6-14W)"
        echo "                Required for running Ollama and other CUDA applications"
        echo "    Note: GPU switch requires a reboot to take effect"
        exit 1
        ;;
esac
EOF

# Make script executable
sudo chmod +x /usr/local/bin/opm
```

### Model Setup and Testing
```bash
# Start Ollama service
opm on

# Pull test model
ollama pull qwen2.5-coder:7b

# Test model (with performance stats)
ollama run --verbose qwen2.5-coder:7b "Say hi"

# Stop service after testing
opm off
```

## 5. Power Management Tools

### Power States Overview
| State | Power Draw | Description |
|-------|------------|-------------|
| Hybrid (idle) | ~3.45W | GPU available but idle, no network |
| Hybrid + Network | ~6W | With USB-Ethernet adapter |
| Ollama Service | ~11-14W | Service running, even when idle |
| Active Inference | ~20-35W | During model execution |

### Known Power Reading Issues
> **Note**: The NVIDIA driver occasionally reports incorrect power readings (e.g., 588W) through nvidia-smi. This is a known sensor reporting issue that doesn't affect actual power consumption. Use PowerTOP for accurate system-wide power measurements.

### Monitoring Tools

#### PowerTOP
```bash
# Real-time power monitoring (requires sudo)
sudo powertop

# Common readings:
# - Base system: ~6W
# - With USB-Ethernet: +2W
# - Ollama service: +8W
```

#### NVTOP
```bash
# GPU-specific monitoring (no sudo required)
nvtop

# Monitored metrics:
# - GPU utilization
# - Memory usage
# - Power consumption
# - Temperature
```

#### Power State Verification
```bash
# Check PCIe power state
cat /sys/bus/pci/devices/0000:01:00.0/power_state
# D0 = Full power
# D3 = Power saving (only available in integrated mode)

# Check GPU power draw
nvidia-smi --query-gpu=power.draw --format=csv,noheader

# Check Ollama service status
systemctl status ollama
```

### Test Script
```bash
# Create power test script
sudo tee /usr/local/bin/power-test << 'EOF'
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
EOF

sudo chmod +x /usr/local/bin/power-test
```

## 6. Automated Setup

### Configuration Backup
```bash
# Create backup script
sudo tee /usr/local/bin/power-config-backup << 'EOF'
#!/bin/bash

# Create backup directory
BACKUP_DIR="$HOME/nvidia-power-setup/$(date +%Y%m%d)"
mkdir -p "$BACKUP_DIR/configs"

# Backup configuration files
echo "Backing up configuration files..."
FILES_TO_BACKUP=(
    "/etc/optimus-manager/optimus-manager.conf"
    "/etc/systemd/system/powertop.service"
    "/etc/systemd/system/ollama.service.d/cuda.conf"
    "/etc/udev/rules.d/80-nvidia-pm.rules"
    "/etc/default/grub"
    "/usr/local/bin/opm"
    "/usr/local/bin/power-test"
)

for file in "${FILES_TO_BACKUP[@]}"; do
    if [ -f "$file" ]; then
        dir="$BACKUP_DIR/configs$(dirname "$file")"
        mkdir -p "$dir"
        sudo cp "$file" "$dir/"
        echo "Backed up: $file"
    else
        echo "Warning: $file not found"
    fi
done

# Fix permissions
sudo chown -R $USER:$USER "$BACKUP_DIR"

echo "Backup completed in: $BACKUP_DIR"
EOF

sudo chmod +x /usr/local/bin/power-config-backup
```

### System Setup Script
```bash
# Create setup script
sudo tee /usr/local/bin/power-setup << 'EOF'
#!/bin/bash

echo "=== Dell XPS 15 Power Management Setup ==="
echo "This script will configure power management for NVIDIA and Ollama"

# Check for root privileges
if [ "$EUID" -ne 0 ]; then 
    echo "Please run as root"
    exit 1
fi

# Function to handle errors
handle_error() {
    echo "Error: $1"
    exit 1
}

echo "1. Installing required packages..."
pacman -S --needed \
    nvidia nvidia-utils cuda cuda-tools \
    optimus-manager powertop nvidia-settings \
    nvtop s-tui || handle_error "Package installation failed"

echo "2. Creating configuration directories..."
mkdir -p /etc/systemd/system/ollama.service.d

echo "3. Configuring CUDA for Ollama..."
cat > /etc/systemd/system/ollama.service.d/cuda.conf << 'EEOF'
[Service]
Environment="NVIDIA_VISIBLE_DEVICES=all"
Environment="CUDA_VISIBLE_DEVICES=0"
Environment="OLLAMA_CUDA=1"
Environment="CUDA_MODULE_LOADING=LAZY"
Environment="CUDA_CACHE_DISABLE=0"
Environment="NVIDIA_DRIVER_CAPABILITIES=compute,utility"
Environment="OLLAMA_KEEP_ALIVE=0"
EEOF

echo "4. Setting up power management..."
nvidia-smi -pm 1
nvidia-smi -pl 35

echo "5. Installing management scripts..."
cp /path/to/opm /usr/local/bin/
cp /path/to/power-test /usr/local/bin/
chmod +x /usr/local/bin/opm
chmod +x /usr/local/bin/power-test

echo "6. Enabling PowerTOP..."
systemctl enable powertop.service

echo "7. Setting up NVIDIA power management rules..."
cat > /etc/udev/rules.d/80-nvidia-pm.rules << 'EEOF'
# Enable runtime PM for NVIDIA VGA/3D controller devices
ACTION=="bind", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x030000", TEST=="power/control", ATTR{power/control}="auto"
ACTION=="bind", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x030200", TEST=="power/control", ATTR{power/control}="auto"
# Enable runtime PM for NVIDIA Audio devices
ACTION=="bind", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x040300", TEST=="power/control", ATTR{power/control}="auto"
EEOF

echo "Setup complete! Please reboot your system."
echo "After reboot, run 'power-test' to verify configuration"
EOF

sudo chmod +x /usr/local/bin/power-setup
```

## 7. Troubleshooting

### Common Issues

#### High Power Consumption
```bash
# Symptom: Power stays high (~14W) even when idle
# Check 1: Verify Ollama service status
systemctl status ollama

# Check 2: Verify GPU power state
nvidia-smi --query-gpu=pstate,power.draw,clocks.current.graphics --format=csv,noheader

# Solution: Stop Ollama service if not needed
opm off
```

#### Incorrect Power Readings
```bash
# Symptom: nvidia-smi shows impossible values (e.g., 588W)
# This is a known sensor reporting issue

# Workaround 1: Use PowerTOP for accurate readings
sudo powertop

# Workaround 2: Wait a few seconds and check again
sleep 3 && nvidia-smi --query-gpu=power.draw --format=csv,noheader
```

#### Model Loading Issues
```bash
# Symptom: Model fails to load or is slow
# Check 1: Verify CUDA availability
python3 -c "import torch; print(torch.cuda.is_available())"

# Check 2: Verify GPU memory
nvidia-smi

# Solution: Clear Ollama cache if needed
rm -rf ~/.ollama/models
```

### Performance Optimization

#### Memory Management
```bash
# Check memory usage
nvidia-smi --query-gpu=memory.used,memory.total --format=csv,noheader

# If memory is full:
opm off
sleep 2
opm on
```

#### Power States
| Issue | Check | Solution |
|-------|--------|----------|
| Stuck in D0 | `cat /sys/bus/pci/devices/0000:01:00.0/power_state` | Stop Ollama service |
| High idle power | `nvidia-smi` | Verify no background CUDA processes |
| USB power drain | `powertop` | Disable unused USB ports |

### Recovery Procedures

#### Reset Power Management
```bash
# Full power management reset
sudo tee /usr/local/bin/power-reset << 'EOF'
#!/bin/bash
echo "Resetting power management..."

# Stop services
sudo systemctl stop ollama
sudo systemctl stop powertop

# Reset NVIDIA settings
sudo nvidia-smi --reset-gpu-metrics
sudo nvidia-smi -pm 1
sudo nvidia-smi -pl 35

# Reset PCIe power management
echo auto > /sys/bus/pci/devices/0000:01:00.0/power/control

# Restart services
sudo systemctl start powertop
echo "Reset complete. Use 'opm on' to start Ollama if needed."
EOF

sudo chmod +x /usr/local/bin/power-reset
```

#### Configuration Recovery
```bash
# Restore from backup
cd ~/nvidia-power-setup/YYYYMMDD
sudo cp -r configs/* /
sudo systemctl daemon-reload
```

### Best Practices

1. **Daily Usage**
   - Start Ollama only when needed: `opm on`
   - Stop when finished: `opm off`
   - Monitor power: `powertop`

2. **Performance Mode**
   ```bash
   # Before intensive tasks
   opm on
   # Wait 5 seconds before running models
   sleep 5
   ```

3. **Power Saving Mode**
   ```bash
   # For maximum battery life
   opm off
   optimus-manager --switch integrated
   # Requires reboot
   ```

4. **Regular Maintenance**
   ```bash
   # Weekly cleanup
   rm -rf ~/.ollama/models  # Clear model cache
   power-config-backup      # Backup configurations
   power-test              # Verify power management
   ```

### System Information Commands
```bash
# Create system info script
sudo tee /usr/local/bin/sysinfo << 'EOF'
#!/bin/bash
echo "=== System Information ==="
echo "Kernel: $(uname -r)"
echo "NVIDIA Driver: $(nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null)"
echo "CUDA Version: $(nvcc --version 2>/dev/null | grep release | awk '{print $6}')"
echo "Ollama Version: $(ollama --version 2>/dev/null)"
echo
echo "=== Power Status ==="
opm status
EOF

sudo chmod +x /usr/local/bin/sysinfo
```
