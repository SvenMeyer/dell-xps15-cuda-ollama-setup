# Dell XPS 15 Power Management Suite

Comprehensive power management solution for Dell XPS 15 laptops running Manjaro Linux, with specific focus on NVIDIA GPU and Ollama LLM support.

## Features
- Optimized power management (4-14W depending on mode)
- CUDA support for Ollama and other ML workloads
- Automated setup and configuration
- Power monitoring and management tools

## Quick Start
```bash
# Clone repository
git clone https://github.com/yourusername/dell-xps-power-management.git
cd dell-xps-power-management

# Run setup
sudo ./setup.sh

# Install power management tool
sudo cp scripts/opm /usr/local/bin/
```

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
