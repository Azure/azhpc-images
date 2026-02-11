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
  # TODO: support additional authentication methods
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
      resource_group       = var.sig_resource_group_name
      gallery_name         = var.sig_gallery_name
      image_name           = var.sig_image_name != "" ? var.sig_image_name : local.sig_image_definition
      image_version        = local.image_version
      replication_regions  = local.sig_replication_regions
      storage_account_type = var.sig_storage_account_type
    }
  }
  
  # Base Marketplace image info
  image_publisher = local.image_publisher
  image_offer     = local.image_offer
  image_sku       = local.image_sku
  
  # Base Direct Shared Gallery image info
  dynamic "shared_image_gallery" {
    for_each = (local.direct_shared_gallery_image_id != null && local.direct_shared_gallery_image_id != "") ? [1] : []
    content {
      direct_shared_gallery_image_id = local.direct_shared_gallery_image_id
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
    Owner     = local.owner_alias
    OS        = "${var.os_family}-${var.os_version}"
    GPU       = "${local.gpu_platform}-${local.gpu_sku}"
    ManagedBy = "Packer"
    BuildTime = local.iso_format_start_time
    Source    = "azhpc-images"
  }
}
