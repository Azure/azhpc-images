# =============================================================================
# HPC Image Builder - Source Definition
# =============================================================================
# Azure ARM builder configuration for HPC images
# =============================================================================

packer {
  required_version = ">= 1.14.0"
  
  required_plugins {
    azure = {
      version = "~> 2.5.2"
      source  = "github.com/hashicorp/azure"
    }
  }
}

source "azure-arm" "hpc" {
  # Authentication - uses Azure CLI credentials
  # Make sure you're logged in with: az login
  use_azure_cli_auth = true

  # RG for build VM; see locals for distinction
  temp_resource_group_name  = local.temp_resource_group_name
  location                  = local.location
  build_resource_group_name = local.build_resource_group_name
  
  # Output: Create managed image in your resource group
  managed_image_resource_group_name = local.create_image ? local.managed_image_resource_group_name : null
  managed_image_name                = local.create_image ? local.image_name : null
  
  # Output: Also create VHD in storage account (optional)
  resource_group_name    = local.create_vhd ? var.vhd_resource_group_name : null
  storage_account        = local.create_vhd ? var.vhd_storage_account : null
  capture_container_name = local.create_vhd ? var.vhd_container_name : null
  capture_name_prefix    = local.create_vhd ? local.image_name : null
  
  # Output: Publish to Shared Image Gallery (optional)
  dynamic "shared_image_gallery_destination" {
    for_each = local.publish_to_sig ? [1] : []
    content {
      subscription         = var.sig_subscription_id != "" ? var.sig_subscription_id : null
      resource_group       = var.sig_resource_group
      gallery_name         = var.sig_gallery_name
      image_name           = var.sig_image_name != "" ? var.sig_image_name : local.sig_image_definition
      image_version        = var.sig_image_version != "" ? var.sig_image_version : local.sig_version
      replication_regions  = local.sig_replication_regions
      storage_account_type = var.sig_storage_account_type
    }
  }
  
  # Marketplace image selection (when NOT using 1P shared gallery)
  image_publisher = !local.use_azl_shared_gallery ? local.image_publisher : null
  image_offer     = !local.use_azl_shared_gallery ? local.image_offer : null
  image_sku       = !local.use_azl_shared_gallery ? local.image_sku : null
  
  # Azure Linux 1P Shared Gallery support (for Azure-internal 1P images)
  dynamic "shared_image_gallery" {
    for_each = local.use_azl_shared_gallery ? [1] : []
    content {
      direct_shared_gallery_image_id = "/sharedGalleries/CblMariner.1P/images/${local.azl_sig_image_name}/versions/latest"
    }
  }
  
  # VM Configuration
  os_type         = "Linux"
  vm_size         = local.vm_size
  os_disk_size_gb = 128
  
  # SSH Configuration
  communicator           = "ssh"
  ssh_username           = "packer"
  ssh_timeout            = "30m"
  ssh_handshake_attempts = 100
  ssh_pty                = true

  # Resource tagging for tracking and governance
  azure_tags = {
    Owner     = var.owner_alias != "" ? var.owner_alias : "packer-user"
    OS        = "${var.os_family}-${var.os_version}"
    GPU       = "${local.gpu_platform}-${local.gpu_sku}"
    ManagedBy = "Packer"
    BuildTime = local.timestamp
    Source    = "azhpc-images"
  }
}
