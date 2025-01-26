# Dell XPS 15 Power Management Suite

Comprehensive power management solution for Dell XPS 15 laptops running Manjaro Linux, with specific focus on NVIDIA GPU and Ollama LLM support.

## Features
- Optimized power management (4-14W depending on mode)
- CUDA support for Ollama and other ML workloads
- Automated setup and configuration
- Power monitoring and management tools

## Quick Start
```bash
# Clone repository and enter directory
git clone https://github.com/SvenMeyer/dell-xps15-cuda-ollama-setup.git
cd dell-xps15-cuda-ollama-setup

# Install power management script
sudo cp scripts/opm /usr/local/bin/
sudo chmod +x /usr/local/bin/opm

# Check current power status
opm status
```

Note: Full automated setup script is under development. For now, please follow the manual setup steps in [Complete Setup Guide](docs/XPS15-CUDA-ollama-setup.md).

## Documentation
- [Complete Setup Guide](docs/XPS15-Power-CUDA-Guide.md)
- [Power Management](docs/power-management.md)
- [Ollama Configuration](docs/ollama-setup.md)
- [Troubleshooting](docs/troubleshooting.md)

## System Requirements
- Dell XPS 15 (tested on 9530)
- Manjaro Linux
- NVIDIA RTX GPU (tested with 4070)

## License
MIT License - See [LICENSE](LICENSE) file
