# Azure HPC Image Builder (Packer)

Build your own Azure HPC/AI images using HashiCorp Packer with the same scripts used for official Azure Marketplace HPC images.

## Overview

This Packer configuration allows you to create custom Azure HPC images with:
- **NVIDIA GPU support**: A100, H100, V100, GB200
- **AMD GPU support**: MI300X
- **AKS Host Images**: For Azure Kubernetes Service nodes
- **Multiple OS options**: Ubuntu 22.04/24.04, AlmaLinux 8.10/9.7, Azure Linux 3.0

## Prerequisites

1. **Python 3.6+** - Pre-installed on most systems
   ```bash
   python --version  # Should be 3.6 or higher
   ```

2. **Azure CLI** - Install and login
   ```bash
   # Install: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli
   az login
   ```

3. **HashiCorp Packer** (v1.14.0+)
   ```bash
   # Install: https://www.packer.io/downloads
   packer version  # Should be 1.14.0 or higher
   ```

4. **Azure Resource Group** - Create one for your images
   ```bash
   az group create --name hpc-images-rg --location westus2
   ```

5. **GPU VM Quota** - For GPU images, ensure you have quota for:
   - NVIDIA A100: `Standard_ND96asr_v4`
   - NVIDIA H100: `Standard_NC40ads_H100_v5`
   - NVIDIA V100: `Standard_ND40rs_v2`
   - NVIDIA GB200: `Standard_ND128isr_NDR_GB200_v6`
   - AMD MI300X: `Standard_ND96isr_MI300X_v5`

## Quick Start

```bash
# Clone the repository
git clone https://github.com/Azure/azhpc-images
cd azhpc-images/packer

# Initialize Packer plugins
packer init .

# Build Ubuntu 22.04 HPC image with NVIDIA A100
python build.py -o ubuntu -v 22.04 -g nvidia -m a100

# Build AlmaLinux 9.7 HPC image with AMD MI300X
python build.py -o alma -v 9.7 -g amd -m mi300x

# Build and export to VHD
python build.py -o ubuntu -v 22.04 -g nvidia -m a100 \
  --create-vhd --storage-account mystorageaccount

# Build and publish to Shared Image Gallery
python build.py -o ubuntu -v 22.04 -g nvidia -m a100 \
  --publish-to-sig --sig-gallery-name AzHPCImageReleaseCandidates

# Build GB200 AKS host image
python build.py -o ubuntu -v 24.04 -g nvidia -m gb200 --aks-host
```

## Usage Examples

### Build Ubuntu 22.04 for NVIDIA A100

```bash
python build.py -o ubuntu -v 22.04 -g nvidia -m a100
# Output: ubuntu-22-04-NVIDIA-A100-hpc-x86_64-202502041530
```

### Build AlmaLinux 8.10 for AMD MI300X

```bash
python build.py -o alma -v 8.10 -g amd -m mi300x
```

### Quick Debug Build (Skip Validation)

```bash
python build.py -o ubuntu -v 22.04 -g nvidia -m a100 --skip-validation
```

### Build GB200 Image

For NVIDIA GB200, you must specify the PARTUUID for non-AKS builds:

```bash
python build.py -o ubuntu -v 24.04 -g nvidia -m gb200 \
  --gb200-partuuid "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
```

### Build AKS Host Image

For AKS host images (uses `install_aks.sh`), add `--aks-host`. PARTUUID is not needed for AKS:

```bash
python build.py -o ubuntu -v 24.04 -g nvidia -m gb200 --aks-host
```

### Export Image to VHD

Packer can create a VHD blob alongside the managed image during the build:

```bash
python build.py -o ubuntu -v 22.04 -g nvidia -m a100 \
  --create-vhd \
  --storage-account mystorageaccount
```

The VHD will be created at: `https://<storage-account>.blob.core.windows.net/vhds/<image-name>.vhd`

### Publish to Shared Image Gallery

Publish images directly to an Azure Shared Image Gallery (SIG) for easier distribution and versioning:

```bash
# First, create the image definition (one-time setup)
az sig image-definition create \
  --resource-group my-rg \
  --gallery-name AzHPCImageReleaseCandidates \
  --gallery-image-definition ubuntu-22-04-hpc-nvidia-a100 \
  --publisher AzureHPC \
  --offer Ubuntu \
  --sku 22.04-hpc-a100 \
  --os-type Linux \
  --os-state Generalized \
  --hyper-v-generation V2

# Then build and publish
python build.py -o ubuntu -v 22.04 -g nvidia -m a100 \
  --publish-to-sig \
  --sig-gallery-name AzHPCImageReleaseCandidates \
  --sig-image-name ubuntu-22-04-hpc-nvidia-a100
```

**SIG Options:**

| Option | Default | Description |
|--------|---------|-------------|
| `--publish-to-sig` | false | Enable publishing to SIG |
| `--sig-resource-group-name` | `hpc-images-rg` | Resource group containing the gallery |
| `--sig-gallery-name` | `AzHPCImageReleaseCandidates` | Gallery name |
| `--sig-image-name` | auto | Image definition (auto-generated if empty) |
| `--image-version` | auto | Version (auto-generated as `YYYY.MMDD.hhmmss`) |
| `--sig-replication-regions` | build location | Comma-separated list of replication regions |

## Command Reference

```
python build.py [OPTIONS]

IMAGE OPTIONS:
    -o, --os OS             OS family: ubuntu, alma, azurelinux
    -v, --version VERSION   OS version (22.04, 24.04, 8.10, 9.7, 3.0)
    -g, --gpu VENDOR        GPU vendor: nvidia, amd (required)
    -m, --model MODEL       GPU model: a100, h100, v100, gb200, mi300x (required)

AZURE OPTIONS:
    --location LOCATION     Azure location (default: westus2)
    --owner ALIAS           Owner tag for resources

OUTPUT OPTIONS:
    --create-vhd            Also create VHD in storage account
    --vhd-resource-group-name RG  Resource group for VHD storage (default: hpc-images-rg)
    --storage-account NAME  Storage account for VHD output
    --publish-to-sig        Publish image to Shared Image Gallery
    --sig-resource-group-name RG  Resource group containing the SIG
    --sig-gallery-name NAME Gallery name (default: AzHPCImageReleaseCandidates)
    --sig-image-name NAME   Image definition name (auto-generated if empty)
    --image-version VER     Image version (auto-generated if empty)
    --sig-replication-regions REGIONS  Comma-separated replication regions

SPECIAL BUILD OPTIONS:
    --aks-host              Build AKS host image (uses install_aks.sh)
    --gb200-partuuid UUID   Disk PARTUUID for GB200 non-AKS builds

DEBUG OPTIONS:
    --skip-validation       Skip tests and health checks
    --hold-on-error         Keep VM on error for debugging
    -h, --help              Show help
```

## File Structure

```
packer/
├── build.py                    # Main entry point (cross-platform)
├── variables.pkr.hcl           # Packer input variables and computed locals
├── source.pkr.hcl              # Azure ARM builder config
├── build.pkr.hcl               # Build provisioners
└── scripts/
    ├── utils.py                # Shared Python utilities
    ├── add-ip-tags.py          # Azure IP tagging for internal access
    ├── prerequisites.sh        # LTS kernel, package updates, mdatp
    ├── prerequisites-reboot.sh # Reboot after prerequisites
    ├── prerequisites-post-reboot.sh # Post-reboot verification
    ├── prepare-azhpc-environment.sh # Setup azhpc-images on VM
    ├── run-install.py          # Run distro install.sh
    ├── finalize.py             # Verify build artifacts
    ├── validate-image.py       # Tests and health checks
    └── validation-reboot.py    # Reboot for validation
```

## Customization

### Adding Custom Components

Edit the install scripts in `../distros/<os>/` to add custom packages:

```bash
# Example: Add custom package to Ubuntu 22.04
vi ../distros/ubuntu22.04/install.sh
```

### Modifying Component Versions

All component versions are defined in `../versions.json`:

```json
{
  "cuda": "12.4.1",
  "nccl": "2.21.5",
  "hpcx": "2.19"
}
```

## Troubleshooting

### Build Fails - Debug Mode

Use `--hold-on-error` to keep the VM running for debugging:

```bash
python build.py -o ubuntu -v 22.04 -g nvidia -m a100 --hold-on-error
```

### Quota Issues

1. Check your subscription quota in Azure Portal
2. Request quota increase for the required VM SKU
3. Consider using a different region with more capacity

### Authentication Issues

```bash
# Ensure you're logged in
az account show

# If using service principal
az login --service-principal -u <app-id> -p <password> --tenant <tenant>
```

## Related Resources

- [Azure HPC VM Images Documentation](https://docs.microsoft.com/en-us/azure/virtual-machines/workloads/hpc/configure)
- [Azure HPC Marketplace Images](https://azuremarketplace.microsoft.com/en-us/marketplace/apps/microsoft-dsvm.ubuntu-hpc)
- [HashiCorp Packer Documentation](https://www.packer.io/docs)
