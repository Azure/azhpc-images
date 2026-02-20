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
  description = "OS family: ubuntu, alma, rocky or azurelinux"
  default     = "ubuntu"
}

variable "distro_version" {
  type        = string
  description = "Distro version (e.g., 22.04, 24.04, 8.10, 9.6, 3.0)"
  default     = "24.04"
}

variable "os_version" {
  type        = string
  description = "OS version consistent with internal ADO pipeline convention (ubuntu_24.04, ubuntu_22.04, alma8.10, alma9.7, rocky8.10, rocky9.6, azurelinux3.0)"
  default     = env("OS_VERSION")
}

locals {
  # derive os_version from os_family + distro_version if not explicitly set
  os_version = coalesce(var.os_version, var.os_family == "ubuntu" ? "${var.os_family}_${var.distro_version}" : "${var.os_family}${var.distro_version}")
  os_version_regex = "^(?P<os_family>[a-zA-Z]+)[-_]?(?P<distro_version>[0-9]+(?:\\.[0-9]+)?)$"
  os_family  = regex(local.os_version_regex, local.os_version)["os_family"]
  distro_version = regex(local.os_version_regex, local.os_version)["distro_version"]
  os_script_folder_name = "${local.os_family == "alma" ? "almalinux" : local.os_family}${local.distro_version}"
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

variable "use_spot_instances" {
  type        = string
  description = "Whether to use spot instances for the build VM"
  default     = env("USE_SPOT_INSTANCES")
}
locals {
  use_spot_instances = try(convert(lower(var.use_spot_instances), bool), false)
}

variable "ssh_username" {
  type        = string
  description = "SSH username for the build VM"
  default     = "hpcuser"
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
  default     = false
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

variable "skip_hpc" {
  type        = bool
  description = "Whether to skip HPC-specific provisioning steps for testing purposes"
  default     = false
}

variable "skip_validation" {
  type        = bool
  description = "Skip test and health check validation (useful for faster debugging)"
  default     = false
}

variable "public_key" {
  type        = string
  description = "additional public key to add to the build VM for SSH access"
  default     = env("PUBLIC_KEY")
}

variable "default_inline_shebang" {
  type        = string
  description = "Default shebang line for inline shell provisioners (e.g., /bin/bash -xe)"
  default     = "/bin/bash -xe"
}

variable "private_virtual_network_with_public_ip" {
  type        = bool
  description = "Whether to use a private virtual network with a public IP for the build VM."
  default     = false
}
locals {
  private_virtual_network_with_public_ip = try(convert(lower(var.private_virtual_network_with_public_ip), bool), false) || var.enable_first_party_specifics
}

variable "virtual_network_name" {
  type        = string
  description = "Name of a pre-existing virtual network to use for the build VM"
  default     = null
}

variable "virtual_network_subnet_name" {
  type        = string
  description = "Name of a pre-existing subnet within the specified virtual network to use for the build VM"
  default     = null
}

variable "virtual_network_resource_group_name" {
  type        = string
  description = "Name of the resource group containing the specified virtual network"
  default     = null
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

locals {
  owner_alias   = try(coalesce(
    var.owner_alias,
    var.build_requestedforemail,
    var.build_requestedfor,
    var.current_user,
  ), null)
}

# TiP (Test in Production) session - convenience variable for GB-Family SKUs
# If provided, adds 'TipNode.SessionId' tag to target specific hardware rack
variable "tip_session_id" {
  type        = string
  description = "TiP Session ID for GB-Family SKUs. Specify 'None' or leave empty for non-GB-Family SKUs."
  default     = env("TIP_SESSION_ID")
}
locals {
  tip_session_id = coalesce(var.tip_session_id, "None")
}

variable "extra_tags" {
  type        = map(string)
  description = "Additional tags to apply to all Azure resources created during the build. Useful for cost tracking, compliance, or custom metadata."
  default     = {}
}

locals {
  first_party_tags = var.enable_first_party_specifics ? merge({
    "OptOutOfBakedInExtensions" = "",
    "SkipASMAzSecPack" = "true"
    },
    (local.tip_session_id != "None" && local.tip_session_id != null && local.tip_session_id != "") ? {"TipNode.SessionId" = local.tip_session_id} : {}
  ) : {}
  owner_tag = (local.owner_alias != null && local.owner_alias != "") ? {"Owner" = local.owner_alias} : {}
  buildid_tag = (var.build_buildid != null && var.build_buildid != "") ? {"BuildId" = var.build_buildid} : {}
  all_tags = merge(
    local.first_party_tags,
    local.owner_tag,
    local.buildid_tag,
    var.extra_tags,
  )
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
  create_image = try(convert(lower(var.create_image), bool), false) || local.publish_to_sig
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
  default     = "azhpc-images-rg"
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

variable "sig_storage_account_type" {
  type        = string
  description = "Storage account type for the gallery image version"
  default     = "Premium_LRS"
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
  default     = env("AZL3_PREBUILT_VERSION")
}

# =============================================================================
# GB200 Specific Variables
# =============================================================================

variable "gb200_internal_bits_version" {
  type        = string
  description = "Version for Ubuntu 24.04 GB200 internal bits (e.g., 0.0.1)"
  default     = env("U24GB200_INTERNALBITS_VERSION")
}

variable "gb200_partuuid" {
  type        = string
  description = "Disk PartUUID for GB200 builds (required for GB200 SKU). Set to 'None' for non-GB200 builds."
  default     = env("PARTUUID")
}

# =============================================================================
# AKS Host Image Variables
# =============================================================================

variable "aks_host_image" {
  type        = string
  description = "Build AKS host image instead of standard HPC image (uses install_aks.sh)"
  default     = env("AKS_HOST_IMAGE")
}
locals {
  aks_host_image = try(convert(lower(var.aks_host_image), bool), false)
  install_script_name = local.aks_host_image ? "install_aks.sh" : "install.sh"
  aks_test_flag = local.aks_host_image ? "-aks-host" : ""
}

# =============================================================================
# HPC Image Builder - Local Values
# =============================================================================
# Computed values and mappings for the build process
# =============================================================================

locals {
  numeric_timestamp = formatdate("YYYYMMDDHHmm", local.iso_format_start_time)
  
  # Image naming components
  distro_version_safe = replace(local.distro_version, ".", "-")
  
  # Azure Linux base image type suffix (only for azurelinux)
  azl_type_suffix = local.os_family == "azurelinux" ? (
    local.azl_base_image_type == "Marketplace" ? "-mkt-fips" :
    local.azl_base_image_type == "Marketplace-Non-FIPS" ? "-mkt" :
    local.azl_base_image_type == "1P-FIPS" ? "-1p-fips" :
    local.azl_base_image_type == "1P-Non-FIPS" ? "-1p" :
    ""
  ) : ""
  
  architecture = local.vm_size == "Standard_ND128isr_NDR_GB200_v6" ? "aarch64" : "x86_64"

  image_name = "${local.os_family}-${local.distro_version_safe}-${local.azl_type_suffix}-${local.gpu_platform}-${local.gpu_sku}-hpc-${local.architecture}-${local.numeric_timestamp}"

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

  use_direct_shared_gallery_base_image = local.azl_base_image_type == "1P-FIPS" || local.azl_base_image_type == "1P-Non-FIPS" || (var.direct_shared_gallery_image_id != null && var.direct_shared_gallery_image_id != "")
  custom_base_image_detail = compact([var.image_publisher, var.image_offer, var.image_sku])
  marketplace_base_image_detail = local.use_direct_shared_gallery_base_image ? [null, null, null] : (length(local.custom_base_image_detail) > 0 ? local.custom_base_image_detail : local.builtin_marketplace_base_image_details[local.architecture][local.azl_base_image_type][local.os_family][local.distro_version])
  image_publisher = local.marketplace_base_image_detail[0]
  image_offer = local.marketplace_base_image_detail[1]
  image_sku = local.marketplace_base_image_detail[2]
  direct_shared_gallery_image_id = local.use_direct_shared_gallery_base_image ? coalesce(var.direct_shared_gallery_image_id, local.builtin_direct_shared_gallery_base_image_details[local.architecture][local.azl_base_image_type][local.os_family][local.distro_version]) : null

  # Distribution string for azhpc-images scripts
  distribution = "${local.os_family}${local.distro_version}"

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
  internal_sig_image_definition = local.is_experimental_image ? "Experimental" : local.internal_sig_image_definition_details[local.azl_base_image_type][local.os_family][local.distro_version]
}
