# =============================================================================
# HPC Image Builder - Variables
# =============================================================================
# All variable definitions for HPC image builds
# 
# This Packer configuration allows you to build Azure HPC images using the
# same scripts used for official Azure Marketplace HPC images.
# =============================================================================

variable "os_family" {
  type        = string
  description = "OS family: ubuntu, alma, or azurelinux"
  default     = "ubuntu"
  
  validation {
    condition     = contains(["ubuntu", "alma", "azurelinux"], var.os_family)
    error_message = "OS family must be one of: ubuntu, alma, or azurelinux."
  }
}

variable "os_version" {
  type        = string
  description = "OS version (e.g., 22.04, 24.04, 8.10, 9.6, 3.0)"
  default     = "22.04"
}

variable "gpu_vendor" {
  type        = string
  description = "GPU vendor: nvidia or amd"
  
  validation {
    condition     = contains(["nvidia", "amd"], var.gpu_vendor)
    error_message = "GPU vendor must be one of: nvidia, amd."
  }
}

variable "gpu_model" {
  type        = string
  description = "GPU model (e.g., a100, h100, v100, gb200, mi300x)"
}

variable "azure_resource_group" {
  type        = string
  description = "Azure resource group where images will be created"
  default     = "hpc-images-rg"
}

variable "azure_location" {
  type        = string
  description = "Azure location for the build VM and resulting image"
  default     = "westus2"
}

variable "skip_validation" {
  type        = bool
  description = "Skip test and health check validation (useful for faster debugging)"
  default     = false
}

variable "owner_alias" {
  type        = string
  description = "Your alias for Azure resource tagging"
  default     = ""
}

# =============================================================================
# Source Code Tracking Variables
# =============================================================================

variable "azhpc_commit" {
  type        = string
  description = "Git commit hash of azhpc-images (auto-detected by build.sh)"
  default     = "unknown"
}

variable "azhpc_path" {
  type        = string
  description = "Absolute path to azhpc-images directory (auto-detected by build.sh)"
  default     = ".."
}

variable "mdatp_path" {
  type        = string
  description = "Path to mdatp onboarding package directory (empty to skip mdatp installation)"
  default     = ""
}

variable "azhpc_repo_url" {
  type        = string
  description = "Git remote URL of azhpc-images (auto-detected by build.sh)"
  default     = "unknown"
}

variable "azhpc_branch" {
  type        = string
  description = "Git branch of azhpc-images (auto-detected by build.sh)"
  default     = "unknown"
}

# =============================================================================
# Image Metadata Variables
# =============================================================================

variable "image_version" {
  type        = string
  description = "Image version string (e.g., 2412.22.1)"
  default     = ""
}

variable "create_vhd" {
  type        = bool
  description = "Whether to export image to VHD after build"
  default     = false
}

variable "vhd_storage_account" {
  type        = string
  description = "Azure storage account for VHD output (required when using hpc_vhd source)"
  default     = ""
}

variable "vhd_container_name" {
  type        = string
  description = "Azure storage container name for VHD output"
  default     = "vhds"
}

# =============================================================================
# Shared Image Gallery (SIG) Variables
# =============================================================================

variable "publish_to_sig" {
  type        = bool
  description = "Publish image to Shared Image Gallery"
  default     = false
}

variable "sig_subscription_id" {
  type        = string
  description = "Subscription ID for the Shared Image Gallery (uses current subscription if empty)"
  default     = ""
}

variable "sig_resource_group" {
  type        = string
  description = "Resource group containing the Shared Image Gallery"
  default     = "hpc-images-rg"
}

variable "sig_gallery_name" {
  type        = string
  description = "Name of the Shared Image Gallery"
  default     = "AzHPCImageReleaseCandidates"
}

variable "sig_image_name" {
  type        = string
  description = "Image definition name in the gallery (auto-generated if empty)"
  default     = ""
}

variable "sig_image_version" {
  type        = string
  description = "Image version (e.g., 1.0.0). Auto-generated from timestamp if empty"
  default     = ""
}

variable "sig_replication_regions" {
  type        = list(string)
  description = "Regions to replicate the image to"
  default     = ["westus2"]
}

variable "sig_storage_account_type" {
  type        = string
  description = "Storage account type for the gallery image version"
  default     = "Standard_LRS"
  
  validation {
    condition     = contains(["Standard_LRS", "Standard_ZRS", "Premium_LRS"], var.sig_storage_account_type)
    error_message = "Storage account type must be one of: Standard_LRS, Standard_ZRS, Premium_LRS."
  }
}

variable "build_id" {
  type        = string
  description = "Build identifier for tracking"
  default     = ""
}

# =============================================================================
# ADO Pipeline Variables (used by Azure DevOps pipelines)
# =============================================================================

variable "upload_sbom_to_kusto" {
  type        = bool
  description = "Upload SBOM and Trivy reports to Kusto after build (ADO pipeline)"
  default     = false
}

variable "major_version" {
  type        = string
  description = "Major version (YYMM format) for SBOM metadata"
  default     = ""
}

variable "minor_version" {
  type        = string
  description = "Minor version (DD format) for SBOM metadata"
  default     = ""
}

variable "patch_version" {
  type        = string
  description = "Patch version (counter) for SBOM metadata"
  default     = ""
}

variable "is_experimental_image" {
  type        = bool
  description = "Flag indicating if this is an experimental image"
  default     = false
}

variable "pipeline_start_time" {
  type        = string
  description = "ISO format pipeline start time (ADO pipeline)"
  default     = ""
}

# =============================================================================
# Azure Linux Specific Variables
# =============================================================================

variable "azl_base_image_type" {
  type        = string
  description = "Azure Linux base image type: Marketplace (FIPS), Marketplace-Non-FIPS, 1P-FIPS, 1P-Non-FIPS"
  default     = "Marketplace"
  
  validation {
    condition     = contains(["Marketplace", "Marketplace-Non-FIPS", "1P-FIPS", "1P-Non-FIPS"], var.azl_base_image_type)
    error_message = "Azure Linux base image type must be one of: Marketplace, Marketplace-Non-FIPS, 1P-FIPS, 1P-Non-FIPS."
  }
}

variable "azl_prebuilt_version" {
  type        = string
  description = "Version for Azure Linux prebuilt artifacts (e.g., 0.0.17)"
  default     = "0.0.17"
}

# =============================================================================
# GB200 Specific Variables
# =============================================================================

variable "gb200_internal_bits_version" {
  type        = string
  description = "Version for Ubuntu 24.04 GB200 internal bits (e.g., 0.0.1)"
  default     = "0.0.1"
}

variable "gb200_partuuid" {
  type        = string
  description = "Disk PartUUID for GB200 builds (required for GB200 SKU). Set to 'None' for non-GB200 builds."
  default     = "None"
}

# =============================================================================
# AKS Host Image Variables
# =============================================================================

variable "aks_host_image" {
  type        = bool
  description = "Build AKS host image instead of standard HPC image (uses install_aks.sh)"
  default     = false
}

# =============================================================================
# Microsoft Defender for Endpoint (mdatp) Variables
# =============================================================================

variable "install_mdatp" {
  type        = bool
  description = "Install and onboard Microsoft Defender for Endpoint"
  default     = true
}

variable "mdatp_storage_account" {
  type        = string
  description = "Azure storage account containing mdatp onboarding package"
  default     = "azhpcstoralt"
}

variable "mdatp_container" {
  type        = string
  description = "Azure storage container containing mdatp onboarding package"
  default     = "atponboardingpackage"
}

variable "mdatp_blob_name" {
  type        = string
  description = "Blob name for mdatp onboarding package"
  default     = "WindowsDefenderATPOnboardingPackage.zip"
}
