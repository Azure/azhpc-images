# usage: packer build -var-file="image.pkrvars.hcl" --use-sequential-evaluation -parallel-builds=1 image.pkr.hcl
packer {
  required_plugins {
    azure = {
      source  = "github.com/hashicorp/azure"
      version = "~> 2"
    }
  }
}

# https://github.com/hashicorp/packer/issues/11362

variable "username" {
  type    = string
  default = env("USERNAME")
}
locals {
  username = coalesce(var.username, "hpcuser")
}

variable "resource_grp_location" {
  type        = string
  description = "Location of the resource group"
  default     = env("RESOURCE_GRP_LOCATION")
}
locals {
  resource_grp_location = coalesce(var.resource_grp_location, "southcentralus")
}

variable "resource_grp_name" {
  type        = string
  description = "Location of the resource group"
  default     = env("RESOURCE_GRP_NAME")
}
locals {
  resource_grp_name = coalesce(var.resource_grp_name, "hpc-image-build-${substr(replace(lower(uuidv4()), "-", ""), 0, 6)}-rg")
}

variable "images_repo_url" {
  type        = string
  description = "GitHub repository URL for azhpc-images"
  default     = env("IMAGES_REPO_URL")
}
locals {
  images_repo_url = coalesce(var.images_repo_url, "https://github.com/Azure/azhpc-images")
}

variable "target_branch" {
  type        = string
  description = "Branch to use from the repo"
  default     = env("TARGET_BRANCH")
}
locals {
  target_branch = coalesce(var.target_branch, "master")
}

variable "architecture" {
  type        = string
  description = "Architecture to use for the image"
  # TODO: find out what env var to use
  default     = "amd64"
}
locals {
  architecture = coalesce(var.architecture, "amd64")
}

variable "os_version" {
  type        = string
  description = "OS version to use for the image"
  default     = env("OS_VERSION")
}
locals {
  os_version = coalesce(var.os_version, "ubuntu_22.04")
}

variable "gpu_size_option" {
  type        = string
  description = "VM SKU to use for image building"
  default     = env("GPU_SIZE_OPTION")
}
locals {
  gpu_size_option = coalesce(var.gpu_size_option, "Standard_ND96asr_v4")
}

locals {
  base_image_details = {
    "amd64" = {
      "ubuntu_22.04" = {
        "image_publisher" = "Canonical",
        "image_offer"     = "0001-com-ubuntu-server-jammy",
        "image_sku"       = "22_04-lts-gen2",
      },
      "alma8" = {
        "image_publisher" = "almalinux",
        "image_offer"     = "almalinux-x86_64",
        "image_sku"       = "8-gen2"
      },
      "mariner2.0" = {
        "image_publisher" = "MicrosoftCBLMariner",
        "image_offer"     = "cbl-mariner",
        "image_sku"       = "cbl-mariner-2-gen2"
      }
    }
  }

  image_publisher = local.base_image_details[local.architecture][local.os_version]["image_publisher"]
  image_offer     = local.base_image_details[local.architecture][local.os_version]["image_offer"]
  image_sku       = local.base_image_details[local.architecture][local.os_version]["image_sku"]

  
  # TODO: image name and tags should include more metadata for provenance
  image_name = "HPC-Image-${local.os_version}"
}

source "azure-arm" "hpc" {
  image_publisher                   = local.image_publisher
  image_offer                       = local.image_offer
  image_sku                         = local.image_sku
  build_resource_group_name         = local.resource_grp_name
  managed_image_resource_group_name = local.resource_grp_name
  managed_image_name                = local.image_name
  os_type                           = "Linux"
  vm_size                           = local.gpu_size_option
}

source "null" "rg" {
  communicator = "none"
}

build {
  name    = "resource_group"
  sources = [
    "source.null.rg"
  ]
  provisioner "shell-local" {
    inline = [
      # check if the resource group already exists; if not, create it
      "az group show --name ${local.resource_grp_name} || az group create --name ${local.resource_grp_name} --location ${local.resource_grp_location}",
    ]
  }
}

build {
  name    = "azhpc_images"
  sources = [
    "source.azure-arm.hpc"
    ]
}