# =============================================================================
# HPC Image Builder - Build Definition
# =============================================================================
# Provisioners for building HPC images using azhpc-images install scripts
# =============================================================================

build {
  name    = "hpc_build"
  sources = ["source.azure-arm.hpc"]
  
  provisioner "shell-local" {
    name           = "Tarball local public keys"
    inline_shebang = var.default_inline_shebang
    inline         = ["cd ~/.ssh && tar -cf /tmp/packer_pubkeys.tar *.pub 2>/dev/null || tar -cf /tmp/packer_pubkeys.tar --files-from /dev/null"]
  }

  provisioner "file" {
    name        = "Upload public keys tarball"
    source      = "/tmp/packer_pubkeys.tar"
    destination = "/tmp/packer_pubkeys.tar"
    generated   = true
  }

  provisioner "shell" {
    name           = "Install public keys into authorized_keys"
    inline_shebang = var.default_inline_shebang
    inline         = [
      "mkdir -p ~/.ssh && chmod 700 ~/.ssh",
      "tar -xf /tmp/packer_pubkeys.tar -C /tmp 2>/dev/null && cat /tmp/*.pub >> ~/.ssh/authorized_keys || true",
      "[[ -n \"${var.public_key}\" ]] && echo \"${var.public_key}\" >> ~/.ssh/authorized_keys || true",
      "chmod 600 ~/.ssh/authorized_keys",
      "rm -f /tmp/packer_pubkeys.tar /tmp/*.pub",
    ]
  }

  provisioner "shell-local" {
    name           = "(1P specific) add ip tags to public IP"
    inline_shebang = var.default_inline_shebang
    inline         = [
      "set -o pipefail",
      "[[ \"${var.enable_first_party_specifics}\" == false ]] && exit 0",
      "public_ip_name=$(az network public-ip list -g ${local.azure_resource_group} --query '[0].name' -o tsv)",
      "az network public-ip update -g ${local.azure_resource_group} -n $public_ip_name --ip-tags FirstPartyUsage=/Unprivileged",
    ]
  }

  provisioner "shell-local" {
    name           = "(1P specific) download mdatp onboarding package"
    inline_shebang = var.default_inline_shebang
    inline         = [
      "[[ \"${var.enable_first_party_specifics}\" == false ]] && exit 0",
      "az storage blob download -f /tmp/WindowsDefenderATPOnboardingPackage.zip -c atponboardingpackage -n WindowsDefenderATPOnboardingPackage.zip --account-name azhpcstoralt --auth-mode login",
      "unzip -o /tmp/WindowsDefenderATPOnboardingPackage.zip -d /tmp",
      "chmod +r /tmp/MicrosoftDefenderATPOnboardingLinuxServer.py"
    ]
  }

  provisioner "file" {
    name        = "(1P specific) upload mdatp onboarding package"
    only        = var.enable_first_party_specifics ? ["source.azure-arm.hpc"] : []
    source      = "/tmp/MicrosoftDefenderATPOnboardingLinuxServer.py"
    destination = "/tmp/MicrosoftDefenderATPOnboardingLinuxServer.py"
    generated   = true
  }

  provisioner "shell" {
    name           = "(1P specific) install mdatp with onboarding script"
    inline_shebang = var.default_inline_shebang
    inline         = [
      "set -o pipefail",
      "[[ \"${var.enable_first_party_specifics}\" == false ]] && exit 0",
      "curl -sSL https://raw.githubusercontent.com/microsoft/mdatp-xplat/refs/heads/master/linux/installation/mde_installer.sh | sudo bash -s -- --install --onboard /tmp/MicrosoftDefenderATPOnboardingLinuxServer.py --channel prod",
      "sudo mdatp threat policy set --type potentially_unwanted_application --action off",
      "rm -f /tmp/MicrosoftDefenderATPOnboardingLinuxServer.py"
    ]
  }
  
  provisioner "shell" {
    name             = "Install prerequisites (LTS kernel, package updates)"
    script           = "scripts/prerequisites.sh"
    execute_command  = "chmod +x {{ .Path }}; {{ .Vars }} sudo -E bash '{{ .Path }}'"
    environment_vars = [
      "OS_FAMILY=${local.os_family}",
      "DISTRO_VERSION=${local.distro_version}",
      "GPU_SKU=${local.gpu_sku}",
      "GB200_PARTUUID=${var.gb200_partuuid}",
      "AKS_HOST_IMAGE=${local.aks_host_image}",
      "DEBIAN_FRONTEND=noninteractive"
    ]
  }

  provisioner "shell" {
    name              = "Reboot"
    inline_shebang    = var.default_inline_shebang
    skip_clean        = true
    expect_disconnect = true
    inline            = [
      "sudo shutdown -r now"
    ]
  }

  provisioner "shell" {
    name           = "Clean up old kernels"
    pause_before   = "2m"
    inline_shebang = var.default_inline_shebang
    inline         = [
      "if command -v dnf &> /dev/null; then sudo dnf remove -y --oldinstallonly || true; fi",
    ]
  }

  provisioner "shell" {
    name           = "List all installed packages prior to HPC component installation"
    inline_shebang = var.default_inline_shebang
    inline         = [
      "if command -v dnf &> /dev/null; then sudo dnf list installed; fi",
      "if command -v dpkg-query &> /dev/null; then dpkg-query -l; fi",
    ]
  }

  provisioner "shell-local" {
    name           = "(1P specific) download and extract Azure Linux prebuilts"
    inline_shebang = var.default_inline_shebang
    inline         = [
      "[[ \"${var.enable_first_party_specifics}\" == false ]] && exit 0",
      "[[ \"${var.skip_hpc}\" == true ]] && exit 0",
      "[[ \"${local.os_family}\" != azurelinux ]] && exit 0",
      "az storage blob download -f /tmp/azlinux_hpc_test_rpms_x86_64_${var.azl_prebuilt_version}.tar.gz -c azurelinux-prebuilt -n azlinux_hpc_test_rpms_x86_64_${var.azl_prebuilt_version}.tar.gz --account-name azhpcstoralt --auth-mode login",
      "tar -xvf /tmp/azlinux_hpc_test_rpms_x86_64_${var.azl_prebuilt_version}.tar.gz -C ${path.root}/..",
    ]
  }

  provisioner "shell-local" {
    name           = "(1P specific) download and extract GB200 prebuilts"
    inline_shebang = var.default_inline_shebang
    inline         = [
      "[[ \"${var.enable_first_party_specifics}\" == false ]] && exit 0",
      "[[ \"${var.skip_hpc}\" == true ]] && exit 0",
      "[[ \"${local.os_family}\" != ubuntu || \"${local.distro_version}\" != 24.04 || \"${local.gpu_sku}\" != GB200 ]] && exit 0",
      "az storage blob download -f /tmp/u24_gb200_internal_${var.gb200_internal_bits_version}.tar.gz -c u24-gb200-internal -n u24_gb200_internal_${var.gb200_internal_bits_version}.tar.gz --account-name azhpcstoralt --auth-mode login",
      "tar -xvf /tmp/u24_gb200_internal_${var.gb200_internal_bits_version}.tar.gz -C ${path.root}/..",
    ]
  }

  provisioner "shell" {
    name           = "Create azhpc-images directory"
    inline_shebang = var.default_inline_shebang
    inline         = [
      "mkdir -p /home/${var.ssh_username}/azhpc-images"
    ]
  }

  provisioner "file" {
    source      = "${path.root}/../" 
    destination = "/home/${var.ssh_username}/azhpc-images"
  }

  provisioner "shell" {
    name              = "Reboot"
    inline_shebang    = var.default_inline_shebang
    skip_clean        = true
    expect_disconnect = true
    inline            = [
      "[[ \"${var.skip_hpc}\" == true ]] && exit 0",
      "sudo shutdown -r now"
    ]
  }

  provisioner "shell" {
    name            = "Install HPC components"
    pause_before    = "2m"
    execute_command = "chmod +x {{ .Path }}; {{ .Vars }} sudo -E bash '{{ .Path }}'"
    inline          = [
      "[[ \"${var.skip_hpc}\" == true ]] && exit 0",
      "cd /home/${var.ssh_username}/azhpc-images/distros/${local.os_script_folder_name}/; bash ${local.install_script_name} ${local.gpu_platform} ${local.gpu_sku}",
    ]
  }

  provisioner "shell" {
    name              = "Reboot"
    inline_shebang    = var.default_inline_shebang
    skip_clean        = true
    expect_disconnect = true
    inline            = [
      "[[ \"${var.skip_hpc}\" == true ]] && exit 0",
      "sudo shutdown -r now"
    ]
  }

  provisioner "shell" {
    name           = "Add image version to component_versions.txt"
    pause_before   = "2m"
    inline_shebang = var.default_inline_shebang
    inline = [
      "sudo mkdir -p /opt/azurehpc",
      "(cat /opt/azurehpc/component_versions.txt 2>/dev/null || echo '{}') | python3 -c 'import json,sys;d=json.load(sys.stdin);d[\"ImageVersion\"]=\"${local.image_version}\";print(json.dumps(d,indent=2))' | sudo tee /opt/azurehpc/component_versions.txt >/dev/null"
    ]
  }

  provisioner "shell" {
    name     = "Trivy vulnerability scanning (standalone step for testing purposes)"
    execute_command = "chmod +x {{ .Path }}; {{ .Vars }} sudo -E bash '{{ .Path }}'"
    inline    = [
      "[[ \"${var.skip_hpc}\" != true ]] && exit 0",
      "cd /home/${var.ssh_username}/azhpc-images/distros/${local.os_script_folder_name}/; ARCHITECTURE=$(uname -m) bash ../../components/trivy_scan.sh",
    ]
  }

  provisioner "shell" {
    name           = "List all installed packages after HPC component installation"
    inline_shebang = var.default_inline_shebang
    inline         = [
      "if command -v dnf &> /dev/null; then sudo dnf list installed; fi",
      "if command -v dpkg-query &> /dev/null; then dpkg-query -l; fi",
    ]
  }

  provisioner "shell-local" {
    name           = "create local directory for manifests"
    inline_shebang = var.default_inline_shebang
    inline         = [
      "mkdir -p /tmp/image_manifests"
    ]
  }

  provisioner "shell" {
    name           = "Display all image manifests in /opt/azurehpc for debugging purposes"
    inline_shebang = var.default_inline_shebang
    inline         = [
      "cat /opt/azurehpc/trivy-report-rootfs.json",
      "cat /opt/azurehpc/trivy-cyclonedx-rootfs.json",
      "cat /opt/azurehpc/component_versions.txt"
    ]
  }

  provisioner "file" {
    direction   = "download"
    generated   = true
    source      = "/opt/azurehpc/trivy-report-rootfs.json"
    destination = "/tmp/image_manifests/trivy-report-rootfs.json"
  }

  provisioner "file" {
    direction   = "download"
    generated   = true
    source      = "/opt/azurehpc/trivy-cyclonedx-rootfs.json"
    destination = "/tmp/image_manifests/trivy-cyclonedx-rootfs.json"
  }

  provisioner "file" {
    direction   = "download"
    generated   = true
    source      = "/opt/azurehpc/component_versions.txt"
    destination = "/tmp/image_manifests/component-versions.json"
  }
  
  provisioner "shell" {
    name           = "Run tests (pre-reboot)"
    inline_shebang = var.default_inline_shebang
    inline         = [
      "[[ \"${var.skip_validation}\" == true ]] && exit 0",
      "[[ \"${var.skip_hpc}\" == true ]] && exit 0",
      "[[ \"${local.gpu_sku}\" == \"GB200\" ]] && exit 0",
      "/opt/azurehpc/test/run-tests.sh ${local.gpu_platform} ${local.aks_test_flag}"
    ]
  }
  
  provisioner "shell" {
    name              = "Reboot"
    inline_shebang    = var.default_inline_shebang
    skip_clean        = true
    expect_disconnect = true
    inline            = [
      "[[ \"${var.skip_validation}\" == true ]] && exit 0",
      "[[ \"${var.skip_hpc}\" == true ]] && exit 0",
      "sudo shutdown -r now"
    ]
  }

  provisioner "shell" {
    name           = "Run tests (post-reboot)"
    inline_shebang = var.default_inline_shebang
    pause_before   = "15m"
    inline         = [
      "[[ \"${var.skip_validation}\" == true ]] && exit 0",
      "[[ \"${var.skip_hpc}\" == true ]] && exit 0",
      "/opt/azurehpc/test/run-tests.sh ${local.gpu_platform} ${local.aks_test_flag}"
    ]
  }

  provisioner "shell" {
    name           = "Run health checks"
    execute_command = "chmod +x {{ .Path }}; {{ .Vars }} sudo -E bash '{{ .Path }}'"
    inline         = [
      "[[ \"${var.skip_validation}\" == true ]] && exit 0",
      "[[ \"${var.skip_hpc}\" == true ]] && exit 0",
      "[[ \"${local.gpu_sku}\" == \"GB200\" ]] && exit 0",
      "/opt/azurehpc/test/azurehpc-health-checks/run-health-checks.sh -o /opt/azurehpc/test/azurehpc-health-checks/health.log -v",
      "cat /opt/azurehpc/test/azurehpc-health-checks/health.log | grep --ignore-case 'Health checks completed with exit code: 0.'",
    ]
  }

  # --------------------------------------------------------------------------
  # Deprovision: Prepare VM for image capture
  # --------------------------------------------------------------------------
  provisioner "shell" {
    name           = "Clear history and deprovision"
    # skip_clean      = true  # TODO: uncomment once we migrate back epilog
    inline_shebang = "/bin/bash -e"
    inline = local.skip_create_artifacts ? [
      "echo 'Skipping clear history and deprovision (skip_create_artifacts=true)'"
    ] : [
      "cd /home/${var.ssh_username}/azhpc-images/utils",
      "sudo ./clear_history.sh"
    ]
  }

  provisioner "shell" {
    name           = "Clear history and deprovision (temporary epilog)"
    skip_clean     = true
    inline_shebang = "/bin/bash -e"
    inline = local.skip_create_artifacts ? [
      "echo 'Skipping deprovision epilog (skip_create_artifacts=true)'"
    ] : [
      "cd /home/${var.ssh_username}/azhpc-images/utils",
      "sudo ./clear_history_epilog.sh"
    ]
  }

  provisioner "shell-local" {
    # forcing an error exit prevents the VM from being deleted by Packer (and is currently the only way to do this)
    # This has the slight side effect of always "failing" the build, but since build-only + always retain is for debugging purposes only, this is an acceptable tradeoff
    inline_shebang = var.default_inline_shebang
    inline = [
      "[[ \"${local.retain_vm_always}\" == true && \"${local.skip_create_artifacts}\" == true ]] && exit 1 || true"
    ]
  }
  
  error-cleanup-provisioner "shell-local" {
    inline_shebang = var.default_inline_shebang
    inline = [
      "echo 'Build failed for resource group ${local.azure_resource_group}'",
      "[[ \"${local.retain_vm_on_fail}\" == true || \"${local.retain_vm_always}\" == true || \"${local.externally_managed_resource_group}\" == true ]] && exit 0; az group delete --name ${local.azure_resource_group} --yes"
    ]
  }

  # --------------------------------------------------------------------------
  # Post-processor: Generate build manifest
  # --------------------------------------------------------------------------
  post-processor "manifest" {
    output     = "/tmp/image_manifests/manifest.json"
    strip_path = true
    custom_data = {
      managed_image_shared_image_gallery_id = local.publish_to_sig ? "/subscriptions/${var.sig_subscription_id != "" ? var.sig_subscription_id : build.SubscriptionID}/resourceGroups/${var.sig_resource_group_name}/providers/Microsoft.Compute/galleries/${var.sig_gallery_name}/images/${local.sig_image_name}/versions/${local.image_version}" : "",
      vhd_blob_name = local.create_vhd ? "${local.image_name}.vhd" : ""
    }
  }
}
