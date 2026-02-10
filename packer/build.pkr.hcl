# =============================================================================
# HPC Image Builder - Build Definition
# =============================================================================
# Provisioners for building HPC images using azhpc-images install scripts
# =============================================================================

build {
  name    = "hpc_build"
  sources = ["source.azure-arm.hpc"]
  
  # # --------------------------------------------------------------------------
  # # Add ipTags to the temporary public IP (runs on build agent, not VM)
  # # --------------------------------------------------------------------------
  # # This is required for security/S360 related tagging
  # provisioner "shell-local" {
  #   environment_vars = [
  #     "RG_NAME=${build.TempResourceGroupName}",
  #     "PIP_NAME=${build.TempPublicIPAddressName}"
  #   ]
  #   command = "python scripts/add-ip-tags.py"
  # }
  
  # # --------------------------------------------------------------------------
  # # Display build configuration
  # # --------------------------------------------------------------------------
  # provisioner "shell" {
  #   inline = [
  #     "echo '=========================================='",
  #     "echo 'HPC Image Build Configuration'",
  #     "echo '=========================================='",
  #     "echo ''",
  #     "echo '=== Operating System ==='",
  #     "echo 'OS Family:               ${var.os_family}'",
  #     "echo 'OS Version:              ${var.os_version}'",
  #     "echo 'Distribution:            ${local.distribution}'",
  #     "echo 'Publisher:               ${local.image_publisher}'",
  #     "echo 'Offer:                   ${local.image_offer}'",
  #     "echo 'SKU:                     ${local.image_sku}'",
  #     "echo ''",
  #     "echo '=== GPU Configuration ==='",
  #     "echo 'GPU SKU:                 ${local.gpu_sku}'",
  #     "echo 'GPU Platform:            ${local.gpu_platform}'",
  #     "echo ''",
  #     "echo '=== Azure Infrastructure ==='",
  #     "echo 'VM Size:                 ${local.vm_size}'",
  #     "echo 'Resource Group:          ${var.azure_resource_group}'",
  #     "echo 'Location:                ${var.azure_location}'",
  #     "echo ''",
  #     "echo '=== Image Naming ==='",
  #     "echo 'Image Name:              ${local.image_name}'",
  #     "echo 'Timestamp:               ${local.timestamp}'",
  #     "echo ''",
  #     "echo '=== Source Code Info ==='",
  #     "echo 'azhpc-images Repo:       ${var.azhpc_repo_url}'",
  #     "echo 'azhpc-images Branch:     ${var.azhpc_branch}'",
  #     "echo 'azhpc-images Commit:     ${var.azhpc_commit}'",
  #     "echo ''",
  #     "echo '=== Output Configuration ==='",
  #     "echo 'Create VHD:              ${var.create_vhd}'",
  #     "echo 'VHD Storage Account:     ${var.vhd_storage_account != "" ? var.vhd_storage_account : "(not set)"}'",
  #     "echo 'Publish to SIG:          ${var.publish_to_sig}'",
  #     "echo 'SIG Gallery:             ${var.sig_gallery_name}'",
  #     "echo 'SIG Resource Group:      ${var.sig_resource_group}'",
  #     "echo 'SIG Image Definition:    ${local.sig_image_definition}'",
  #     "echo 'SIG Image Version:       ${local.sig_version}'",
  #     "echo 'SIG Replication Regions: ${join(", ", var.sig_replication_regions)}'",
  #     "echo ''",
  #     "echo '=========================================='",
  #     "echo 'Starting Provisioning...'",
  #     "echo '=========================================='",
  #     "echo ''",
  #   ]
  # }
   
  # # --------------------------------------------------------------------------
  # # Prerequisites: Upload mdatp onboarding package (if available)
  # # --------------------------------------------------------------------------
  # provisioner "shell" {
  #   inline = ["mkdir -p /tmp/mdatp"]
  # }
  
  # dynamic "provisioner" {
  #   labels   = ["file"]
  #   for_each = var.mdatp_path != "" ? [1] : []
  #   content {
  #     source      = "${var.mdatp_path}/"
  #     destination = "/tmp/mdatp"
  #   }
  # }
  
  # # --------------------------------------------------------------------------
  # # Prerequisites: LTS kernel, package updates, mdatp
  # # --------------------------------------------------------------------------
  # provisioner "shell" {
  #   script = "scripts/prerequisites.sh"
  #   environment_vars = [
  #     "OS_FAMILY=${var.os_family}",
  #     "OS_VERSION=${var.os_version}",
  #     "GPU_SKU=${local.gpu_sku}",
  #     "INSTALL_MDATP=${var.install_mdatp}",
  #     "GB200_PARTUUID=${var.gb200_partuuid}",
  #     "AKS_HOST_IMAGE=${var.aks_host_image}",
  #     "DEBIAN_FRONTEND=noninteractive"
  #   ]
  #   execute_command = "chmod +x {{ .Path }}; {{ .Vars }} sudo -E bash '{{ .Path }}'"
  # }
  
  # provisioner "shell" {
  #   script            = "scripts/prerequisites-reboot.sh"
  #   execute_command   = "chmod +x {{ .Path }}; {{ .Vars }} sudo -E bash '{{ .Path }}'"
  #   expect_disconnect = true
  # }
  
  # provisioner "shell" {
  #   pause_before    = "60s"
  #   max_retries     = 10
  #   script          = "scripts/prerequisites-post-reboot.sh"
  #   environment_vars = ["OS_FAMILY=${var.os_family}"]
  #   execute_command = "chmod +x {{ .Path }}; {{ .Vars }} sudo -E bash '{{ .Path }}'"
  # }
  
  # # --------------------------------------------------------------------------
  # # Upload azhpc-images repository to VM
  # # --------------------------------------------------------------------------
  # provisioner "file" {
  #   source      = var.azhpc_path
  #   destination = "/tmp/azhpc-images"
  # }
  
  # provisioner "shell" {
  #   script = "scripts/prepare-azhpc-environment.sh"
  #   environment_vars = [
  #     "AZHPC_SUBMODULE_PATH=/tmp/azhpc-images",
  #     "GPU_SKU=${local.gpu_sku}",
  #     "AZHPC_COMMIT=${var.azhpc_commit}",
  #     "AZHPC_REPO_URL=${var.azhpc_repo_url}",
  #     "AZHPC_BRANCH=${var.azhpc_branch}",
  #     "AKS_HOST_IMAGE=${var.aks_host_image}"
  #   ]
  #   execute_command = "chmod +x {{ .Path }}; {{ .Vars }} sudo -E bash '{{ .Path }}'"
  # }
  
  # # --------------------------------------------------------------------------
  # # Run monolithic install.sh from azhpc-images
  # # --------------------------------------------------------------------------
  # provisioner "shell" {
  #   inline = [
  #     "python3 /opt/azhpc-images/packer/scripts/run-install.py --os ${var.os_family} --version ${var.os_version} --gpu-platform ${local.gpu_platform} --gpu-sku ${local.gpu_sku}${var.aks_host_image ? " --aks" : ""}${var.image_version != "" ? " --image-version ${var.image_version}" : ""}"
  #   ]
  #   environment_vars = [
  #     "DEBIAN_FRONTEND=noninteractive"
  #   ]
  #   execute_command = "chmod +x {{ .Path }}; {{ .Vars }} sudo -E bash '{{ .Path }}'"
  # }

  # # --------------------------------------------------------------------------
  # # Finalization (verify build artifacts)
  # # --------------------------------------------------------------------------
  # provisioner "shell" {
  #   inline = [
  #     "python3 /opt/azhpc-images/packer/scripts/finalize.py"
  #   ]
  #   execute_command = "chmod +x {{ .Path }}; {{ .Vars }} sudo -E bash '{{ .Path }}'"
  # }

  # # --------------------------------------------------------------------------
  # # Collect build artifacts (component versions)
  # # --------------------------------------------------------------------------
  # provisioner "shell" {
  #   inline = [
  #     "mkdir -p /tmp/build-artifacts",
  #     "cp /opt/azurehpc/component_versions.txt /tmp/build-artifacts/ 2>/dev/null || echo 'component_versions not found'",
  #     "cp /opt/azurehpc/trivy-report-rootfs.json /tmp/build-artifacts/ 2>/dev/null || echo 'trivy-report not found'",
  #     "sudo chmod -R 644 /tmp/build-artifacts/* 2>/dev/null || true",
  #     "ls -la /tmp/build-artifacts/"
  #   ]
  # }
  
  # # --------------------------------------------------------------------------
  # # Validation (pre-reboot)
  # # --------------------------------------------------------------------------
  # provisioner "shell" {
  #   inline = [
  #     "python3 /opt/azhpc-images/packer/scripts/validate-image.py pre-reboot --gpu-platform ${local.gpu_platform} --gpu-sku ${local.gpu_sku}${var.aks_host_image ? " --aks" : ""}${var.skip_validation ? " --skip" : ""}"
  #   ]
  #   execute_command = "chmod +x {{ .Path }}; {{ .Vars }} sudo -E bash '{{ .Path }}'"
  # }
  
  # provisioner "shell" {
  #   inline = [
  #     "python3 /opt/azhpc-images/packer/scripts/validation-reboot.py${var.skip_validation ? " --skip" : ""}"
  #   ]
  #   execute_command   = "chmod +x {{ .Path }}; {{ .Vars }} sudo -E bash '{{ .Path }}'"
  #   expect_disconnect = true
  # }
  
  # # --------------------------------------------------------------------------
  # # Validation (post-reboot)
  # # --------------------------------------------------------------------------
  # provisioner "shell" {
  #   pause_before = "900s"
  #   max_retries  = 10
  #   inline = [
  #     "python3 /opt/azhpc-images/packer/scripts/validate-image.py post-reboot --gpu-platform ${local.gpu_platform} --gpu-sku ${local.gpu_sku}${var.aks_host_image ? " --aks" : ""}${var.skip_validation ? " --skip" : ""}"
  #   ]
  #   execute_command = "chmod +x {{ .Path }}; {{ .Vars }} sudo -E bash '{{ .Path }}'"
  # }
  
  # # --------------------------------------------------------------------------
  # # Build summary
  # # --------------------------------------------------------------------------
  # provisioner "shell" {
  #   inline = [
  #     "echo '=========================================='",
  #     "echo 'HPC Image Build Complete'",
  #     "echo '=========================================='",
  #     "echo 'Image: ${local.image_name}'",
  #     "echo 'OS: ${var.os_family} ${var.os_version}'",
  #     "echo 'GPU: ${local.gpu_platform} ${local.gpu_sku}'",
  #     "echo ''",
  #     "cat /opt/packer/azhpc-build-info.txt 2>/dev/null || true",
  #     "echo ''",
  #     "echo 'Installed Components:'",
  #     "cat /opt/azurehpc/component_versions.txt 2>/dev/null || true",
  #     "echo '=========================================='",
  #   ]
  # }

  # --------------------------------------------------------------------------
  # Deprovision: Prepare VM for image capture
  # --------------------------------------------------------------------------
  provisioner "shell" {
    name           = "Clear history and deprovision"
    skip_clean      = true  # waagent deprovision kills SSH, so Packer can't clean up
    inline_shebang = "/bin/bash -e"
    inline = [
      "cd /opt/azhpc-images/utils",
      "sudo ./clear_history.sh"
    ]
  }
  
  # --------------------------------------------------------------------------
  # Post-processor: Generate build manifest
  # --------------------------------------------------------------------------
  post-processor "manifest" {
    output     = "build-manifest-${local.timestamp}.json"
    strip_path = true
    custom_data = {
      os_family  = var.os_family
      os_version = var.os_version
      gpu_platform = local.gpu_platform
      gpu_sku  = local.gpu_sku
      image_name = local.image_name
    }
  }
}
