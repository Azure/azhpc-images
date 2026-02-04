# =============================================================================
# HPC Image Builder - Local Values
# =============================================================================
# Computed values and mappings for the build process
# =============================================================================

locals {
  timestamp = formatdate("YYYYMMDDHHmm", timestamp())
  
  # VM size based on GPU requirements
  # Uses GPU VMs when building GPU images for full hardware validation
  vm_size = (
    var.gpu_vendor == "nvidia" && var.gpu_model == "v100" ? "Standard_ND40rs_v2" :
    var.gpu_vendor == "nvidia" && var.gpu_model == "a100" ? "Standard_ND96asr_v4" :
    var.gpu_vendor == "nvidia" && var.gpu_model == "h100" ? "Standard_NC40ads_H100_v5" :
    var.gpu_vendor == "nvidia" && var.gpu_model == "gb200" ? "Standard_ND128isr_NDR_GB200_v6" :
    var.gpu_vendor == "amd" && var.gpu_model == "mi300x" ? "Standard_ND96isr_MI300X_v5" :
    "Standard_D8s_v5"  # Fallback for unknown GPU models
  )
  
  # Image naming components
  os_version_safe = replace(var.os_version, ".", "-")
  
  # Azure Linux base image type suffix (only for azurelinux)
  azl_type_suffix = var.os_family == "azurelinux" ? (
    var.azl_base_image_type == "Marketplace" ? "-mkt-fips" :
    var.azl_base_image_type == "Marketplace-Non-FIPS" ? "-mkt" :
    var.azl_base_image_type == "1P-FIPS" ? "-1p-fips" :
    var.azl_base_image_type == "1P-Non-FIPS" ? "-1p" :
    ""
  ) : ""
  
  # Final image name construction
  # Format: {os_family}-{os_version}[-{azl_suffix}]-{gpu_vendor}-{gpu_model}-x86_64-{timestamp}
  image_name = "${var.os_family}-${local.os_version_safe}${local.azl_type_suffix}-${var.gpu_vendor}-${var.gpu_model}-hpc-x86_64-${local.timestamp}"

  # Marketplace image mappings
  image_publisher = (
    var.os_family == "ubuntu" ? "Canonical" :
    var.os_family == "alma" ? "almalinux" :
    var.os_family == "azurelinux" ? "microsoftcblmariner" :
    "Canonical"
  )
  
  image_offer = (
    var.os_family == "ubuntu" && var.os_version == "22.04" ? "0001-com-ubuntu-server-jammy" :
    var.os_family == "ubuntu" && var.os_version == "24.04" ? "ubuntu-24_04-lts" :
    var.os_family == "alma" ? "almalinux-x86_64" :
    var.os_family == "azurelinux" ? "azure-linux-3" :
    "0001-com-ubuntu-server-jammy"
  )
  
  image_sku = (
    var.os_family == "ubuntu" && var.os_version == "22.04" ? "22_04-lts-gen2" :
    var.os_family == "ubuntu" && var.os_version == "24.04" ? "server" :
    var.os_family == "alma" && var.os_version == "8.10" ? "8-gen2" :
    var.os_family == "alma" && var.os_version == "9.6" ? "9-gen2" :
    var.os_family == "alma" && var.os_version == "9.7" ? "9-gen2" :
    var.os_family == "azurelinux" && var.os_version == "3.0" && var.azl_base_image_type == "Marketplace" ? "azure-linux-3-gen2-fips" :
    var.os_family == "azurelinux" && var.os_version == "3.0" && var.azl_base_image_type == "Marketplace-Non-FIPS" ? "azure-linux-3-gen2" :
    var.os_family == "azurelinux" && var.os_version == "3.0" ? "azure-linux-3-gen2-fips" :
    "22_04-lts-gen2"
  )

  # Azure Linux 1P Shared Gallery image support
  use_azl_shared_gallery = var.os_family == "azurelinux" && (var.azl_base_image_type == "1P-FIPS" || var.azl_base_image_type == "1P-Non-FIPS")
  
  azl_sig_image_name = (
    var.azl_base_image_type == "1P-FIPS" ? "azure-linux-3-gen2-fips" :
    var.azl_base_image_type == "1P-Non-FIPS" ? "azure-linux-3-gen2" :
    ""
  )

  # GPU platform for scripts (uppercase for compatibility)
  gpu_platform = var.gpu_vendor == "nvidia" ? "NVIDIA" : "AMD"

  # Distribution string for azhpc-images scripts
  distribution = "${var.os_family}${var.os_version}"

  # Shared Image Gallery (SIG) computed values
  # Image definition: {os_family}-{os_version}-hpc-{gpu_vendor}-{gpu_model}
  sig_image_definition = "${var.os_family}-${local.os_version_safe}-hpc-${var.gpu_vendor}-${var.gpu_model}"
  
  # Auto-generate version from timestamp: YYYY.MMDD.HHmm (e.g., 2026.0205.1002)
  sig_version = formatdate("YYYY.MMDD.hhmm", timestamp())
}
