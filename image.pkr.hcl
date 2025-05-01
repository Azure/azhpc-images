# usage: packer build -var-file="image.pkrvars.hcl" --use-sequential-evaluation -parallel-builds=1 -on-error=abort image.pkr.hcl
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
  default = "amd64"
}
locals {
  architecture = coalesce(var.architecture, "amd64")
}

variable "gpu_platform" {
  type        = string
  description = "GPU platform to use for the image"
  default     = env("GPU_PLATFORM")
}
locals {
  gpu_platform = coalesce(var.gpu_platform, "NVIDIA")
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

variable "public_key" {
  type        = string
  description = "Public key to use for SSH access for debugging purposes"
  default     = env("PUBLIC_KEY")
}
locals {
  public_key = var.public_key
}

# TODO: allow specifying vnet and subnet

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
  inline_shebang = "/bin/bash -e"

  hpc_install_command = {
    "ubuntu_22.04" = "cd /home/${local.username}/azhpc-images/ubuntu/ubuntu-22.x/ubuntu-22.04-hpc; sudo bash install.sh ${local.gpu_platform}"
    "alma8" = "cd /home/${local.username}/azhpc-images/alma/alma-8.x/alma-8.10-hpc; sudo ./install.sh"
    "mariner2.0" = "cd /home/${local.username}/azhpc-images/mariner/mariner-2.x/mariner-2.0-hpc; sudo ./install.sh"
  }

  test_dir = "/opt/azurehpc/test"
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
  os_disk_size_gb                   = 64
  ssh_username                      = local.username
  azure_tags = {
    SkipASMAzSecPack   = "true"
    SkipASMAV          = "true"
    SkipLinuxAzSecPack = "true"
  }
}

source "null" "rg" {
  communicator = "none"
}

build {
  name = "resource_group"
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
  name = "azhpc_images"
  sources = [
    "source.azure-arm.hpc"
  ]
  provisioner "shell" {
    name = "add SSH key"
    inline = [
      # add the public key to the VM
      "echo \"${local.public_key}\" >> /home/${local.username}/.ssh/authorized_keys",
    ]
  }

  provisioner "shell" {
    name = "clone azhpc-images repo"
    inline_shebang = local.inline_shebang
    inline = [
      # if os_version is not ubuntu*, use yum to install git
      "if [[ \"${local.os_version}\" != *\"ubuntu\"* ]]; then sudo yum install -y git; fi",
      # clone the azhpc-images repo
      "git clone --branch ${local.target_branch} ${local.images_repo_url} /home/${local.username}/azhpc-images",
    ]
  }

  provisioner "shell" {
    name = "switch to 5.15 LTS kernel for Ubuntu 22.04"
    inline_shebang = local.inline_shebang
    inline = [
    <<-EOF
    if [[ "${local.os_version}" == *"ubuntu_22.04"* ]]; then
      sudo sed -i 's/GRUB_DEFAULT=0/GRUB_DEFAULT=saved\nGRUB_SAVEDEFAULT=true/' /etc/default/grub

      sudo apt update
      sudo apt install -y linux-azure-lts-22.04
      sudo apt-mark hold linux-azure-lts-22.04
      sudo apt-get purge -y linux-azure
      sudo apt-get purge -y linux-azure-6.*

      sudo sed -i "s/#\$nrconf{kernelhints} = -1;/\$nrconf{kernelhints} = -1;/g" /etc/needrestart/needrestart.conf

      version=$(dpkg-query -l | grep linux-azure-lts-22.04 | awk '{print $3}' | awk -F. 'OFS="." {print $1,$2,$3,$4}' | sed 's/\(.*\)\./\1-/')
      sudo grub-set-default "Advanced options for Ubuntu>Ubuntu, with Linux $version-azure"
      sudo update-grub
    fi
    EOF
    ]
  }

  provisioner "shell" {
    name = "adjust mariner settings"
    inline_shebang = local.inline_shebang
    inline = [
      "if [[ \"${local.os_version}\" == *\"mariner\"* ]]; then sudo sed -i 's/lockdown=integrity//' /boot/grub2/grub.cfg &&  sudo sed -i '/umask 027/d' /etc/profile; fi",
    ]
  }

  provisioner "shell" {
    name = "reboot"
    expect_disconnect = true
    inline = [
      "sudo shutdown -r now",
    ]
  }

  provisioner "shell" {
    name = "list installed packages pre-specialization"
    inline_shebang = local.inline_shebang
    inline = [
      "if [[ \"${local.os_version}\" == *\"ubuntu\"* ]]; then dpkg-query -l; else yum list installed; fi",
    ]
  }

  # provisioner "shell" {
  #   name = "install HPC components onto the virtual machine"
  #   inline_shebang = local.inline_shebang
  #   inline = [
  #     local.hpc_install_command[local.os_version],
  #   ]
  # }

  # provisioner "shell" {
  #   name = "list installed packages post-specialization"
  #   inline_shebang = local.inline_shebang
  #   inline = [
  #     "if [[ \"${local.os_version}\" == *\"ubuntu\"* ]]; then dpkg-query -l; else yum list installed; fi",
  #   ]
  # }

  # provisioner "shell" {
  #   name = "display the build version of the image"
  #   inline_shebang = local.inline_shebang
  #   inline = [
  #     "curl -s -H Metadata:true \"http://169.254.169.254/metadata/instance?api-version=2019-06-04\" | /usr/bin/env python3 -c \"import sys, json; print(json.load(sys.stdin)['compute']['version'])\""
  #   ]
  # }

  # provisioner "shell" {
  #   name = "run tests"
  #   inline_shebang = local.inline_shebang
  #   inline = [
  #     "/opt/azurehpc/test/run-tests.sh ${local.gpu_platform} --mofed-lts false"
  #   ]
  # }

  # provisioner "shell" {
  #   name = "reboot"
  #   expect_disconnect = true
  #   inline = [
  #     "sudo shutdown -r now",
  #   ]
  # }

  # provisioner "shell" {
  #   name = "run tests after reboot"
  #   inline_shebang = local.inline_shebang
  #   inline = [
  #     "${local.test_dir}/run-tests.sh ${local.gpu_platform} --mofed-lts false"
  #   ]
  # }

  # provisioner "shell" {
  #   name = "run health check after reboot"
  #   inline_shebang = local.inline_shebang
  #   inline = [
  #     <<-EOF
  #     health_check_script="${local.test_dir}/azurehpc-health-checks/run-health-checks.sh"
  #     health_log="${local.test_dir}/azurehpc-health-checks/health.log"
  #     sudo -i $health_check_script -o $health_log -v
  #     if ! grep --ignore-case fail $health_log
  #     then
  #         echo "Health Check - Passed !"
  #     else
  #         echo "Health Check - Failed !"
  #         exit 1
  #     fi
  #     EOF
  #   ]
  # }

  provisioner "shell-local" {
    name = "SSH into remote machine and collect metadata for tagging"
    inline_shebang = local.inline_shebang
    inline = [
      <<-EOF
      temp_file=$(mktemp)
      echo '${build.SSHPrivateKey}' > $temp_file
      ssh -i $temp_file -o StrictHostKeyChecking=no ${build.User}@${build.Host} "/home/${local.username}/azhpc-images/common/collect_metadata.py ${local.os_version}" > /tmp/metadata-${local.resource_grp_name}.txt
      EOF
    ]
  }

  provisioner "shell" {
    name = "clear history and deprovision"
    inline_shebang = local.inline_shebang
    inline = [
      <<-EOF
      pushd /home/${local.username}/azhpc-images/common
      # Clear installation, log and other unwanted files
      sudo ./clear_history.sh
      popd

      # Remove the AzNHC log
      sudo rm -f /opt/azurehpc/test/azurehpc-health-checks/health.log

      # Uninstall the OMS Agent
      wget https://raw.githubusercontent.com/microsoft/OMS-Agent-for-Linux/master/installer/scripts/uninstall.sh
      sudo chmod +x ./uninstall.sh
      sudo ./uninstall.sh
    
      # Switch to the root user
      sudo -s <<HERE
      # Disable root account
      usermod root -p '!!'
    
      # Deprovision the user
      waagent -deprovision+user -force
    
      # Delete the last line of the file /etc/sysconfig/network-scripts/ifcfg-eth0 -> cloud-init issue on alma distros
      if [[ ${local.os_version} == "alma"* ]]
      then
          sed -i '$ d' /etc/sysconfig/network-scripts/ifcfg-eth0
      fi

      # Clear the sudoers.d folder - last user information
      rm -rf /etc/sudoers.d/*
    
      # Delete /1 folder
      rm -rf /1
    
      touch /var/run/utmp
      # clear command history
      export HISTSIZE=0 && history -c && sync
      HERE
      EOF
    ]
  }

  # provisioner "shell-local" {
  #   # forcing an error exit prevents the VM from being deleted (and is currently the only way to do this).
  #   inline = [
  #     "exit 1"
  #   ]
  # }

}

build {
  name = "cleanup_resource_group"
  sources = [
    "source.null.rg"
  ]
  provisioner "shell-local" {
    inline = [
      "az group delete --name ${local.resource_grp_name} --yes --no-wait",
    ]
  }
}