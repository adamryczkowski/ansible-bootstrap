# ComfyUI Playbook for krita-ai-diffusion

This Ansible playbook installs and configures [ComfyUI](https://github.com/comfyanonymous/ComfyUI) as a backend for the [krita-ai-diffusion](https://github.com/Acly/krita-ai-diffusion) plugin on Ubuntu 24.04 LTS.

## What This Playbook Does

### 1. System Dependencies Installation

Installs required system packages:

- Python 3 with pip and venv
- Git and Git LFS
- Build tools (build-essential)
- Graphics libraries (libgl1, libglib2.0-0, libsm6, libxrender1, libxext6)
- FFmpeg for video processing

### 2. ComfyUI Installation via comfy-cli

Uses the official [comfy-cli](https://github.com/Comfy-Org/comfy-cli) tool (v1.5.3+) for installation:

- Creates a dedicated Python virtual environment for comfy-cli
- Installs comfy-cli from PyPI
- Installs ComfyUI with ComfyUI-Manager to the specified directory (default: `~/comfy`)
- Configures PyTorch for the specified GPU type (NVIDIA, AMD, or CPU)

### 3. Required Custom Nodes for krita-ai-diffusion

Automatically installs the following required custom nodes:

| Node | Repository | Purpose |
|------|------------|---------|
| ControlNet Preprocessors | [Fannovel16/comfyui_controlnet_aux](https://github.com/Fannovel16/comfyui_controlnet_aux) | Image preprocessing for ControlNet |
| IP-Adapter | [cubiq/ComfyUI_IPAdapter_plus](https://github.com/cubiq/ComfyUI_IPAdapter_plus) | Image prompt adapter support |
| Inpaint Nodes | [Acly/comfyui-inpaint-nodes](https://github.com/Acly/comfyui-inpaint-nodes) | Advanced inpainting capabilities |
| External Tooling Nodes | [Acly/comfyui-tooling-nodes](https://github.com/Acly/comfyui-tooling-nodes) | Integration with external tools |

### 4. Optional Custom Nodes

Can optionally install additional nodes for extended functionality:

| Node | Repository | Purpose |
|------|------------|---------|
| GGUF | [city96/ComfyUI-GGUF](https://github.com/city96/ComfyUI-GGUF) | Load .gguf model format |
| Nunchaku | [nunchaku-tech/ComfyUI-nunchaku](https://github.com/nunchaku-tech/ComfyUI-nunchaku) | Nunchaku svdq model support |

### 5. Systemd User Service (Optional)

Creates a systemd user service for running ComfyUI as a background service:

- Automatic restart on failure
- Configurable listen address and port
- User-level service (no root required after installation)

## Requirements

- **Target OS**: Ubuntu 22.04 LTS or Ubuntu 24.04 LTS
- **Python**: 3.9 or higher (included in Ubuntu 22.04+)
- **Ansible**: 2.14 or higher
- **GPU** (optional but recommended):
  - NVIDIA GPU with CUDA support
  - AMD GPU with ROCm support
  - Intel GPU with oneAPI support
  - CPU-only mode available

## Usage

### Basic Usage

```bash
ansible-playbook playbooks/comfyui.yml -i inventory/your-inventory
```

### With Custom Variables

```bash
ansible-playbook playbooks/comfyui.yml -i inventory/your-inventory \
  -e "comfyui_username=myuser" \
  -e "comfyui_gpu_type=nvidia" \
  -e "comfyui_listen_address=0.0.0.0" \
  -e "comfyui_port=8188"
```

### Install Optional Nodes

```bash
ansible-playbook playbooks/comfyui.yml -i inventory/your-inventory \
  -e "comfyui_install_optional_nodes=true"
```

## Configuration Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `comfyui_username` | `{{ target_user \| default(ansible_user) }}` | User to install ComfyUI for |
| `comfyui_install_dir` | `/home/{{ comfyui_username }}/comfy` | Installation directory |
| `comfyui_gpu_type` | `nvidia` | GPU type: `nvidia`, `amd`, `intel`, `cpu` |
| `comfyui_install_manager` | `true` | Install ComfyUI-Manager |
| `comfyui_enable_service` | `true` | Create systemd user service |
| `comfyui_port` | `8188` | ComfyUI server port |
| `comfyui_listen_address` | `127.0.0.1` | Listen address (`0.0.0.0` for network access) |
| `comfyui_install_optional_nodes` | `false` | Install optional custom nodes |
| `comfyui_extra_nodes` | `[]` | Additional custom nodes to install |

## Post-Installation Steps

### 1. Download a Diffusion Model

ComfyUI requires at least one diffusion model (checkpoint) to function. Download a model and place it in the checkpoints directory:

```bash
# Example: Download SD 1.5 model
cd ~/comfy/ComfyUI/models/checkpoints/
wget https://huggingface.co/runwayml/stable-diffusion-v1-5/resolve/main/v1-5-pruned-emaonly.safetensors
```

Popular model sources:

- **SD 1.5**: [runwayml/stable-diffusion-v1-5](https://huggingface.co/runwayml/stable-diffusion-v1-5)
- **SDXL**: [stabilityai/stable-diffusion-xl-base-1.0](https://huggingface.co/stabilityai/stable-diffusion-xl-base-1.0)
- **Flux**: [black-forest-labs/FLUX.1-schnell](https://huggingface.co/black-forest-labs/FLUX.1-schnell)

### 2. Start ComfyUI

#### Manual Start

```bash
# Local access only
comfy launch

# Network access (for remote Krita connections)
comfy launch -- --listen 0.0.0.0 --port 8188
```

#### Using Systemd Service

```bash
# Start the service
systemctl --user start comfyui

# Enable auto-start on boot
systemctl --user enable comfyui

# Check status
systemctl --user status comfyui

# View logs
journalctl --user -u comfyui -f
```

### 3. Configure krita-ai-diffusion Plugin

1. Open Krita
2. Go to **Settings > Configure Krita > Python Plugin Manager**
3. Enable **"AI Image Diffusion"**
4. Restart Krita
5. Go to **Settings > Dockers > AI Image Diffusion**
6. Set server URL to: `http://localhost:8188` (or your server's IP if remote)

## Updating ComfyUI

The comfy-cli tool makes updating easy:

```bash
# Update ComfyUI
comfy update

# Update all custom nodes
comfy node update all

# Update comfy-cli itself
pip install --upgrade comfy-cli
```

## Troubleshooting

### ComfyUI Won't Start

1. Check Python version: `python3 --version` (must be 3.9+)
2. Verify GPU drivers are installed (for NVIDIA: `nvidia-smi`)
3. Check logs: `journalctl --user -u comfyui -f`

### Custom Nodes Not Working

1. Restart ComfyUI after installing nodes
2. Check node dependencies: `comfy node deps-in-workflow`
3. Reinstall problematic node: `comfy node reinstall <node-name>`

### Connection Refused from Krita

1. Ensure ComfyUI is running: `systemctl --user status comfyui`
2. Check listen address (use `0.0.0.0` for network access)
3. Verify firewall allows port 8188: `sudo ufw allow 8188`

## Sources

This playbook was created based on official documentation from:

1. [ComfyUI CLI Documentation](https://docs.comfy.org/comfy-cli/getting-started)
2. [comfy-cli GitHub Repository](https://github.com/Comfy-Org/comfy-cli)
3. [krita-ai-diffusion GitHub Repository](https://github.com/Acly/krita-ai-diffusion)
4. [krita-ai-diffusion ComfyUI Setup Guide](https://github.com/Acly/krita-ai-diffusion/blob/main/docs/src/content/docs/comfyui-setup.mdx)
5. [ComfyUI GitHub Repository](https://github.com/comfyanonymous/ComfyUI)

## License

MIT License - See the main project LICENSE file.
