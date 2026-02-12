# =============================================================================
# HPC Image Builder - Variables
# =============================================================================
# All variable definitions for HPC image builds
# 
# This Packer configuration allows you to build Azure HPC images using the
# same scripts used for official Azure Marketplace HPC images.
# =============================================================================

variable "iso_format_start_time" {
  type        = string
  description = "ISO format start time (e.g., 2024-02-05T10:02:00Z), optionally passed from pipeline for tracking purposes"
  default     = env("ISO_FORMAT_START_TIME")
}
locals {
  iso_format_start_time = coalesce(var.iso_format_start_time, timestamp())
}

variable "os_family" {
  type        = string
  description = "OS family: ubuntu, alma, or azurelinux"
  default     = "ubuntu"
  
  validation {
    condition     = contains(["ubuntu", "alma", "azurelinux"], var.os_family)
    error_message = "OS family must be one of: ubuntu, alma, or azurelinux."
  }
}

variable "distro_version" {
  type        = string
  description = "Distro version (e.g., 22.04, 24.04, 8.10, 9.6, 3.0)"
  default     = "22.04"
}

variable "vm_size" {
  type        = string
  description = "VM SKU to use for image building"
  default     = env("GPU_SIZE_OPTION")
}
locals {
  vm_size = coalesce(var.vm_size, "Standard_ND96asr_v4")
}

locals {
  gpu_sku = (
    local.vm_size == "Standard_ND40rs_v2" ? "V100" :
    local.vm_size == "Standard_ND96isr_MI300X_v5" ? "MI300X" :
    local.vm_size == "Standard_ND128isr_NDR_GB200_v6" ? "GB200" :
    "A100"
  )
  gpu_platform = (
    local.gpu_sku == "MI300X" ? "AMD" : "NVIDIA"
  )
}

variable "azure_resource_group" {
  type        = string
  description = "Azure resource group where the build VM will be created"
  default     = env("RESOURCE_GRP_NAME")
}
locals {
  azure_resource_group = coalesce(var.azure_resource_group, "hpc-image-build-${substr(replace(lower(uuidv4()), "-", ""), 0, 6)}-rg")
}

variable "azure_location" {
  type        = string
  description = "Azure location for the build VM and resulting image"
  default     = env("RESOURCE_GRP_LOCATION")
}
locals {
  azure_location = coalesce(var.azure_location, "southcentralus")
}

variable "externally_managed_resource_group" {
  type        = string
  description = "Whether the resource group already exists, hence externally managed by e.g. Azure Pipelines, in which case the pipeline itself is responsible for cleanup."
  default     = env("EXTERNALLY_MANAGED_RESOURCE_GROUP")
}
locals {
  externally_managed_resource_group = try(convert(lower(var.externally_managed_resource_group), bool), false)
}

locals {
  temp_resource_group_name = local.externally_managed_resource_group ? null : local.azure_resource_group # create rg if not externally managed
  location = local.externally_managed_resource_group ? null : local.azure_location # location is only needed if Packer is creating the RG
  build_resource_group_name = local.externally_managed_resource_group ? local.azure_resource_group : null # use existing rg if externally managed
}

variable "enable_first_party_specifics" {
  type        = bool
  description = "Whether to enable first-party-specific operations, such as certain Azure tags, MDE installation, etc."
  default     = false
}

variable "skip_validation" {
  type        = bool
  description = "Skip test and health check validation (useful for faster debugging)"
  default     = false
}

variable "build_requestedforemail" {
  type        = string
  description = "Email of the user who requested the build. Auto-populated in environment by Azure DevOps."
  default     = env("BUILD_REQUESTEDFOREMAIL")
}

variable "build_requestedfor" {
  type        = string
  description = "Alias of the user who requested the build. Auto-populated in environment by Azure DevOps."
  default     = env("BUILD_REQUESTEDFOR")
}

variable "build_buildid" {
  type        = string
  description = "Build ID of the current build. Auto-populated in environment by Azure DevOps."
  default     = env("BUILD_BUILDID")
}

variable "owner_alias" {
  type        = string
  description = "Your alias for Azure resource tagging"
  default     = null
}

variable "current_user" {
  type        = string
  description = "current user as specified in environment variable (Linux)"
  default     = env("USER")
}

variable "current_username" {
  type        = string
  description = "current username as specified in environment variable (Windows)"
  default     = env("USERNAME")
}

locals {
  owner_alias   = coalesce(
    var.owner_alias,
    var.build_requestedforemail,
    var.build_requestedfor,
    var.current_user,
    var.current_username,
    "packer-user"
  )
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
# Custom Base Image Details
# =============================================================================

# TODO: allow building from custom SIG or community gallery

variable "image_publisher" {
  type        = string
  description = "Custom base image publisher"
  default     = null
}

variable "image_offer" {
  type        = string
  description = "Custom base image offer"
  default     = null
}

variable "image_sku" {
  type        = string
  description = "Custom base image SKU"
  default     = null
}

variable "direct_shared_gallery_image_id" {
  type        = string
  description = "Direct Shared Gallery Image ID for base image"
  default     = null
}

# =============================================================================
# Image Metadata Variables
# =============================================================================

variable "image_version" {
  type        = string
  description = "Image version string (e.g., 2412.22.1)"
  default     = env("IMAGE_VERSION")
  validation {
    condition     = var.image_version == null || var.image_version == "" || can(regex("^\\d+\\.\\d+\\.\\d+$", var.image_version))
    error_message = "Image version must be in the format major.minor.patch (e.g., 2412.22.1)."
  }
}
locals {
  image_version = coalesce(var.image_version, formatdate("YYYY.MMDD.hhmmss", local.iso_format_start_time))
}

variable "retain_vm_on_fail" {
  type        = string
  description = "Retain the VM (and the resource group) if the build fails"
  default     = env("RETAIN_VM_ON_FAIL")
}
locals {
  retain_vm_on_fail = try(convert(lower(var.retain_vm_on_fail), bool), true)
}

variable "retain_vm_always" {
  type        = string
  description = "Retain the VM (and the resource group) even if an artifact-less build succeeds. Useful for manual experimentation purposes."
  default     = env("RETAIN_VM_ALWAYS")
}
locals {
  retain_vm_always = try(convert(lower(var.retain_vm_always), bool), false)
}

variable "create_vhd" {
  type        = string
  description = "Whether to export image to VHD after build"
  default     = env("CREATE_VHD")
}
locals {
  create_vhd = try(convert(lower(var.create_vhd), bool), false)
}

variable "create_image" {
  type        = string
  description = "Whether to create managed image or SIG image after build"
  default     = env("CREATE_IMAGE")
}

variable "is_experimental_image" {
  type        = string
  description = "1P internally-used experimental image marker for publishing to fallback catch-all SIG image definition"
  default     = env("IS_EXPERIMENTAL_IMAGE")
}
locals {
  is_experimental_image = try(convert(lower(var.is_experimental_image), bool), false)
}

variable "publish_to_sig" {
  type        = string
  description = "Publish image to Shared Image Gallery"
  default     = env("CREATE_IMAGE")
}
locals {
  publish_to_sig = try(convert(lower(var.publish_to_sig), bool), false)
  # SIG currently takes dependency on managed image creation
  create_image = try(convert(lower(var.create_image), bool), true) || local.publish_to_sig
  skip_create_artifacts = !local.create_vhd && !local.create_image
}

variable "managed_image_resource_group_name" {
  type        = string
  description = "Azure resource group for the managed image output"
  default     = null
}
locals {
  # defaults to capturing into the build resource group, which may be ephemeral
  # (note that SIG capture requires managed image capture ATM, VM-to-SIG is yet to be implemented by Packer)
  managed_image_resource_group_name = coalesce(var.managed_image_resource_group_name, local.azure_resource_group)
}

variable "vhd_resource_group_name" {
  type        = string
  description = "Azure resource group for the storage account holding VHD blob output"
  default     = "azhpc-images-rg"
}

variable "vhd_storage_account" {
  type        = string
  description = "Azure storage account for VHD blob output"
  default     = "azhpcstor"
}

variable "vhd_container_name" {
  type        = string
  description = "Azure storage container name for VHD blob output"
  default     = "azhpc-vhd-store"
}

# =============================================================================
# Shared Image Gallery (SIG) Variables
# =============================================================================

variable "sig_subscription_id" {
  type        = string
  description = "Subscription ID for the Shared Image Gallery (uses current subscription if empty)"
  default     = ""
}

variable "sig_resource_group_name" {
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

variable "sig_replication_regions" {
  type        = list(string)
  description = "Regions to replicate the image to (defaults to the build VM's region if not set)"
  default     = null
}
locals {
  sig_replication_regions = var.sig_replication_regions == null ? [local.azure_location] : var.sig_replication_regions
}

variable "sig_storage_account_type" {
  type        = string
  description = "Storage account type for the gallery image version"
  default     = "Premium_LRS"
}

variable "build_id" {
  type        = string
  description = "Build identifier for tracking"
  default     = ""
}

# =============================================================================
# Azure Linux Specific Variables
# =============================================================================

variable "azl_base_image_type" {
  type        = string
  description = "Azure Linux base image type: Marketplace-FIPS, Marketplace-Non-FIPS, 1P-FIPS, 1P-Non-FIPS (Marketplace-Non-FIPS for non-Azure Linux distros)"
  default     = env("BASE_IMAGE")
  validation {
    condition     = var.azl_base_image_type == null || contains(["Marketplace-FIPS", "Marketplace-Non-FIPS", "1P-FIPS", "1P-Non-FIPS", ""], var.azl_base_image_type)
    error_message = "Azure Linux base image type must be one of the following if set: Marketplace-FIPS, Marketplace-Non-FIPS, 1P-FIPS, 1P-Non-FIPS."
  }
}
locals {
  azl_base_image_type = coalesce(var.azl_base_image_type, "Marketplace-Non-FIPS")
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

# =============================================================================
# HPC Image Builder - Local Values
# =============================================================================
# Computed values and mappings for the build process
# =============================================================================

locals {
  numeric_timestamp = formatdate("YYYYMMDDHHmm", locals.iso_format_start_time)
  
  # Image naming components
  distro_version_safe = replace(var.distro_version, ".", "-")
  
  # Azure Linux base image type suffix (only for azurelinux)
  azl_type_suffix = var.os_family == "azurelinux" ? (
    local.azl_base_image_type == "Marketplace" ? "-mkt-fips" :
    local.azl_base_image_type == "Marketplace-Non-FIPS" ? "-mkt" :
    local.azl_base_image_type == "1P-FIPS" ? "-1p-fips" :
    local.azl_base_image_type == "1P-Non-FIPS" ? "-1p" :
    ""
  ) : ""
  
  architecture = local.vm_size == "Standard_ND128isr_NDR_GB200_v6" ? "aarch64" : "x86_64"

  # Final image name construction
  # Format: {os_family}-{distro_version}[-{azl_suffix}]-{gpu_platform}-{gpu_sku}-{architecture}-{timestamp}
  image_name = "${var.os_family}-${local.distro_version_safe}${local.azl_type_suffix}-${local.gpu_platform}-${local.gpu_sku}-hpc-${local.architecture}-${local.numeric_timestamp}"

  builtin_marketplace_base_image_details = {
    "aarch64" = {
      "Marketplace-Non-FIPS" = {
        "ubuntu" = {
          "24.04" = ["Canonical", "ubuntu-24_04-lts", "server-arm64"]
        }
      }
    },
    "x86_64" = {
      "Marketplace-Non-FIPS" = {
        "ubuntu" = {
          "22.04" = ["Canonical", "0001-com-ubuntu-server-jammy", "22_04-lts-gen2"],
          "24.04" = ["Canonical", "ubuntu-24_04-lts", "server"]
        },
        "alma" = {
          "8.10" = ["almalinux", "almalinux-x86_64", "8-gen2"],
          "9.7" = ["almalinux", "almalinux-x86_64", "9-gen2"]
        },
        "azurelinux" = {
          "3.0" = ["MicrosoftCBLMariner", "azure-linux-3", "azure-linux-3-gen2"]
        }
      },
      "Marketplace-FIPS" = {
        "azurelinux" = {
          "3.0" = ["MicrosoftCBLMariner", "azure-linux-3", "azure-linux-3-gen2-fips"]
        }
      }
    }
  }

  # these images are only accessible by 1P
  builtin_direct_shared_gallery_base_image_details = {
    "x86_64" = {
      "1P-Non-FIPS" = {
        "azurelinux" = {
          "3.0" = "/sharedGalleries/CblMariner.1P/images/azure-linux-3-gen2/versions/latest"
        }
      },
      "1P-FIPS" = {
        "azurelinux" = {
          "3.0" = "/sharedGalleries/CblMariner.1P/images/azure-linux-3-gen2-fips/versions/latest"
        }
      }
    }
  }

  use_direct_shared_gallery_base_image = local.azl3_base_image_type == "1P-FIPS" || local.azl3_base_image_type == "1P-Non-FIPS" || (var.direct_shared_gallery_image_id != null && var.direct_shared_gallery_image_id != "")
  custom_base_image_detail = compact([var.image_publisher, var.image_offer, var.image_sku])
  marketplace_base_image_detail = local.use_direct_shared_gallery_base_image ? [null, null, null] : (local.custom_base_image_detail != [] ? local.custom_base_image_detail : builtin_marketplace_base_image_details[local.architecture][local.azl3_base_image_type][var.os_family][var.distro_version])
  image_publisher = marketplace_base_image_detail[0]
  image_offer = marketplace_base_image_detail[1]
  image_sku = marketplace_base_image_detail[2]
  direct_shared_gallery_image_id = local.use_direct_shared_gallery_base_image ? coalesce(var.direct_shared_gallery_image_id, local.builtin_direct_shared_gallery_base_image_details[local.architecture][local.azl3_base_image_type][var.os_family][var.distro_version]) : null

  # Distribution string for azhpc-images scripts
  distribution = "${var.os_family}${var.distro_version}"

  # These values are reserved for 1P internal SIG
  internal_sig_image_definition_platform = local.gpu_platform == "AMD" ? "ROCm-" : ""
  internal_sig_image_definition_sku = local.gpu_sku == "V100" ? "V100-" : (local.gpu_sku == "GB200" ? "GB200-" : "")
  internal_sig_image_definition_details = {
    "Marketplace-Non-FIPS" = {
      "ubuntu" = {
        "22.04" = "UbuntuHPC-22.04-${local.internal_sig_image_definition_platform}${local.internal_sig_image_definition_sku}gen2",
        "24.04" = "UbuntuHPC-24.04-${local.internal_sig_image_definition_platform}${local.internal_sig_image_definition_sku}gen2"
      },
      "alma" = {
        "8.10"  = "AlmaLinuxHPC-8.10-${local.internal_sig_image_definition_platform}${local.internal_sig_image_definition_sku}gen2",
        "9.7"   = "AlmaLinuxHPC-9.7-${local.internal_sig_image_definition_platform}${local.internal_sig_image_definition_sku}gen2"
      },
      "azurelinux" = {
        "3.0"   = "AzureLinuxHPC-3.0-NonFIPS-${local.internal_sig_image_definition_platform}${local.internal_sig_image_definition_sku}gen2-TL"
      }
    },
    "Marketplace-FIPS" = {
      "azurelinux" = {
        "3.0"   = "AzureLinuxHPC-3.0-${local.internal_sig_image_definition_platform}${local.internal_sig_image_definition_sku}gen2-TL"
      }
    },
    "1P-FIPS" = {
      "azurelinux" = {
        "3.0"   = "AzureLinuxHPC-3.0-1P-${local.internal_sig_image_definition_platform}${local.internal_sig_image_definition_sku}gen2-2"
      }
    },
    "1P-Non-FIPS" = {
      "azurelinux" = {
        "3.0"   = "AzureLinuxHPC-3.0-1P-NonFIPS-${local.internal_sig_image_definition_platform}${local.internal_sig_image_definition_sku}gen2-2"
      }
    }
  }
  internal_sig_image_definition = local.is_experimental_image ? "Experimental" : local.internal_sig_image_definition_details[local.azl_base_image_type][var.os_family][var.distro_version]
}
