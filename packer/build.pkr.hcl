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
    inline = [
      "mkdir -p ~/.ssh && chmod 700 ~/.ssh",
      "tar -xf /tmp/packer_pubkeys.tar -C /tmp 2>/dev/null && cat /tmp/*.pub >> ~/.ssh/authorized_keys || true",
      "[[ -n \"${var.public_key}\" ]] && echo \"${var.public_key}\" >> ~/.ssh/authorized_keys || true",
      "chmod 600 ~/.ssh/authorized_keys",
      "rm -f /tmp/packer_pubkeys.tar /tmp/*.pub",
    ]
  }

  # Ubuntu 26.04 ships sudo-rs (Trifecta Tech Foundation's Rust rewrite) as
  # the default for /usr/bin/sudo. sudo-rs deliberately does not implement
  # bare `-E` / `--preserve-env` (upstream wontfix, sudo-rs#1299), and many
  # of our provisioners and downstream scripts rely on `sudo -E` and on
  # legacy sudoers semantics (env_keep, SETENV:). Both `sudo` (classic GNU)
  # and `sudo-rs` are installed simultaneously on a stock 26.04 image: the
  # `sudo` package ships /usr/bin/sudo.ws, sudo-rs ships /usr/bin/sudo-rs
  # and a neutral-name copy at /usr/lib/cargo/bin/sudo, and /usr/bin/sudo
  # itself is an update-alternatives symlink defaulting to sudo-rs. We flip
  # the alternative back to classic GNU sudo.
  provisioner "shell" {
    name           = "(Ubuntu 26.04) Switch /usr/bin/sudo alternative to classic GNU sudo"
    except         = (local.os_family == "ubuntu" && local.distro_version == "26.04") ? [] : ["azure-arm.hpc"]
    inline_shebang = var.default_inline_shebang
    inline = [
      "sudo update-alternatives --display sudo || true",
      "sudo update-alternatives --set sudo /usr/bin/sudo.ws",
      "sudo --version | head -n1",
      "sudo --version | grep -qiv 'sudo-rs'",
    ]
  }

  provisioner "shell-local" {
    name           = "(1P specific) add ip tags to public IP"
    except         = var.enable_first_party_specifics ? [] : ["azure-arm.hpc"]
    inline_shebang = var.default_inline_shebang
    inline = [
      "set -o pipefail",
      "public_ip_name=$(az network public-ip list -g ${local.azure_resource_group} --query '[0].name' -o tsv)",
      "az network public-ip update -g ${local.azure_resource_group} -n $public_ip_name --ip-tags FirstPartyUsage=/Unprivileged",
    ]
  }

  provisioner "shell-local" {
    name           = "(1P specific) download mdatp onboarding package"
    except         = var.enable_first_party_specifics ? [] : ["azure-arm.hpc"]
    inline_shebang = var.default_inline_shebang
    inline = [
      "az storage blob download -f /tmp/WindowsDefenderATPOnboardingPackage.zip -c atponboardingpackage -n WindowsDefenderATPOnboardingPackage.zip --account-name azhpcstoralt --auth-mode login",
      "unzip -o /tmp/WindowsDefenderATPOnboardingPackage.zip -d /tmp",
      "chmod +r /tmp/MicrosoftDefenderATPOnboardingLinuxServer.py"
    ]
  }

  provisioner "file" {
    name        = "(1P specific) upload mdatp onboarding package"
    except      = var.enable_first_party_specifics ? [] : ["azure-arm.hpc"]
    source      = "/tmp/MicrosoftDefenderATPOnboardingLinuxServer.py"
    destination = "/tmp/MicrosoftDefenderATPOnboardingLinuxServer.py"
    generated   = true
  }

  provisioner "shell" {
    name           = "(1P specific) install mdatp with onboarding script"
    except         = var.enable_first_party_specifics ? [] : ["azure-arm.hpc"]
    inline_shebang = var.default_inline_shebang
    inline = [
      <<-EOF
        set -o pipefail

        curl -sSL https://raw.githubusercontent.com/microsoft/mdatp-xplat/refs/heads/master/linux/installation/mde_installer.sh -o /tmp/mde_installer.sh
        chmod +x /tmp/mde_installer.sh

        installer_channel=prod
        if [[ -r /etc/os-release ]]; then
          # shellcheck disable=SC1091
          . /etc/os-release
          if [[ "$${ID:-}" == "ubuntu" && "$${VERSION_ID:-}" == "26.04" ]]; then
            echo "[mdatp] Ubuntu 26.04 detected; patching mde_installer.sh and using prod channel."
            sed -i 's#\^(20\.04|22\.04|24\.04)\$#^(20.04|22.04|24.04|26.04)$#' /tmp/mde_installer.sh
            sed -i 's#elif { \[ "$DISTRO" = "debian" \] && \[ "$VERSION" = "13" \]; }; then#elif { [ "$DISTRO" = "debian" ] \&\& [ "$VERSION" = "13" ]; } || { [ "$DISTRO" = "ubuntu" ] \&\& [ "$VERSION" = "26.04" ]; }; then#' /tmp/mde_installer.sh
            sed -i 's#\[\[ $VERSION != "24\.04" \]\]; then#[[ $VERSION != "24.04" ]] \&\& [[ $VERSION != "26.04" ]]; then#' /tmp/mde_installer.sh
          fi
        fi

        sudo bash /tmp/mde_installer.sh --install --onboard /tmp/MicrosoftDefenderATPOnboardingLinuxServer.py --channel "$${installer_channel}"
        sudo mdatp threat policy set --type potentially_unwanted_application --action off
        rm -f /tmp/MicrosoftDefenderATPOnboardingLinuxServer.py /tmp/mde_installer.sh
      EOF
    ]
  }

  provisioner "shell" {
    name            = "Install prerequisites (LTS kernel, package updates)"
    script          = "scripts/prerequisites.sh"
    execute_command = "chmod +x {{ .Path }}; {{ .Vars }} sudo -E bash '{{ .Path }}'"
    environment_vars = [
      "OS_FAMILY=${local.os_family}",
      "DISTRO_VERSION=${local.distro_version}",
      "GPU_SKU=${local.gpu_sku}",
      "TARGET_NODE_TYPE=${local.target_node_type}",
      "NVLINK_RACKSCALE=${local.nvlink_rackscale}",
      "KERNEL_VERSION=${local.kernel_version}",
      "USE_UBUNTU_PROPOSED_SUITE=${var.use_ubuntu_proposed_suite}",
      "USE_UBUNTU_PPA_REPO=${var.use_ubuntu_ppa_repo}",
      "UBUNTU_PPA_REPO_NAME=${var.ubuntu_ppa_repo_name}",
      "UBUNTU_PPA_KERNEL_PATCH_VERSION=${var.ubuntu_ppa_kernel_patch_version}",
      "GB200_PARTUUID=${var.gb200_partuuid}",
      "REFRESH_MODE=${local.refresh_mode}",
      "DEBIAN_FRONTEND=noninteractive"
    ]
  }

  provisioner "shell" {
    name              = "Reboot"
    inline_shebang    = var.default_inline_shebang
    skip_clean        = true
    expect_disconnect = true
    pause_after       = "2m"
    inline = [
      "(sleep 5; sudo shutdown -r now) &"
    ]
  }

  provisioner "shell" {
    name           = "Clean up old kernels"
    inline_shebang = var.default_inline_shebang
    inline = [
      "if command -v dnf &> /dev/null; then sudo dnf remove -y --oldinstallonly || true; fi",
    ]
  }

  provisioner "shell" {
    name           = "List all installed packages prior to HPC component installation"
    inline_shebang = var.default_inline_shebang
    inline = [
      "if command -v dnf &> /dev/null; then sudo dnf list installed; fi",
      "if command -v dpkg-query &> /dev/null; then dpkg-query -l; fi",
    ]
  }

  // Placeholder, will check whether VR200 really needs internal bits
  provisioner "shell-local" {
    name           = "download and extract Azure Linux prebuilts for GB200"
    except         = (!var.skip_hpc && !local.refresh_mode && local.os_family == "azurelinux" && local.nvlink_rackscale) ? [] : ["azure-arm.hpc"]
    inline_shebang = var.default_inline_shebang
    inline = [
      "if [[ -z \"${var.internal_bits_container_name}\" || -z \"${var.internal_bits_blob_name}\" || \"${var.internal_bits_container_name}\" =~ ^[Nn]one$ || \"${var.internal_bits_blob_name}\" =~ ^[Nn]one$ ]]; then echo 'Skipping internal bits download: INTERNAL_BITS_CONTAINER_NAME or INTERNAL_BITS_BLOB_NAME is unset/None'; exit 0; fi",
      "az storage blob download -f ./${var.internal_bits_blob_name} -c ${var.internal_bits_container_name} -n ${var.internal_bits_blob_name} --account-name azhpcstoralt --auth-mode login",
      "mkdir -p ${path.root}/../prebuilt",
      "tar -xvf ./${var.internal_bits_blob_name} -C ${path.root}/.."
    ]
  }

  // Placeholder, will check whether VR200 really needs internal bits
  provisioner "shell-local" {
    name           = "(1P specific) download and extract GB200 prebuilts"
    except         = (var.enable_first_party_specifics && !var.skip_hpc && !local.refresh_mode && local.os_family == "ubuntu" && local.distro_version == "24.04" && local.nvlink_rackscale) ? [] : ["azure-arm.hpc"]
    inline_shebang = var.default_inline_shebang
    inline = [
      "if [[ -z \"${var.internal_bits_container_name}\" || -z \"${var.internal_bits_blob_name}\" || \"${var.internal_bits_container_name}\" =~ ^[Nn]one$ || \"${var.internal_bits_blob_name}\" =~ ^[Nn]one$ ]]; then echo 'Skipping internal bits download: INTERNAL_BITS_CONTAINER_NAME or INTERNAL_BITS_BLOB_NAME is unset/None'; exit 0; fi",
      "az storage blob download -f /tmp/${var.internal_bits_blob_name} -c ${var.internal_bits_container_name} -n ${var.internal_bits_blob_name} --account-name azhpcstoralt --auth-mode login",
      "tar -xvf /tmp/${var.internal_bits_blob_name} -C ${path.root}/..",
    ]
  }

  provisioner "shell" {
    name           = "Create azhpc-images directory"
    inline_shebang = var.default_inline_shebang
    inline = [
      "mkdir -p /home/${local.ssh_username}/azhpc-images"
    ]
  }

  provisioner "file" {
    source      = "${path.root}/../"
    destination = "/home/${local.ssh_username}/azhpc-images"
  }

  provisioner "shell-local" {
    name           = "Clean up local internal bits"
    inline_shebang = var.default_inline_shebang
    inline = [
      "if [[ -e ${path.root}/../internal_bits ]]; then chmod -R u+rwX ${path.root}/../internal_bits && rm -rf ${path.root}/../internal_bits; fi",
      "if [[ -e ${path.root}/../prebuilt ]]; then chmod -R u+rwX ${path.root}/../prebuilt && rm -rf ${path.root}/../prebuilt; fi"
    ]
  }

  provisioner "file" {
    name        = "(Baremetal 1P) Upload baremetal overlay files"
    except      = (local.target_node_type == "baremetal_1p") ? [] : ["azure-arm.hpc"]
    source      = "${path.root}/../../baremetal/"
    destination = "/home/${local.ssh_username}/azhpc-images"
  }

  provisioner "shell" {
    name              = "Reboot"
    except            = (var.skip_hpc || local.refresh_mode) ? ["azure-arm.hpc"] : []
    inline_shebang    = var.default_inline_shebang
    skip_clean        = true
    expect_disconnect = true
    pause_after       = "2m"
    inline = [
      "(sleep 5; sudo shutdown -r now) &"
    ]
  }

  provisioner "shell" {
    name            = "Install HPC components"
    except          = (var.skip_hpc || local.refresh_mode) ? ["azure-arm.hpc"] : []
    execute_command = "chmod +x {{ .Path }}; {{ .Vars }} sudo -E bash '{{ .Path }}'"
    environment_vars = [
      "TARGET_NODE_TYPE=${local.target_node_type}",
      "NVLINK_RACKSCALE=${local.nvlink_rackscale}",
      "REFRESH_MODE=${local.refresh_mode}",
    ]
    inline = [
      "cd /home/${local.ssh_username}/azhpc-images/distros/${local.os_script_folder_name}/; if [[ \"${local.target_node_type}\" == \"baremetal_1p\" ]]; then bash ${local.install_script_name} ${local.gpu_platform} ${local.gpu_sku} \"${var.ado_access_token}\" \"${local.baremetal_1p_login_user}\" \"${var.baremetal_1p_login_passwd}\"; else bash ${local.install_script_name} ${local.gpu_platform} ${local.gpu_sku}; fi",
    ]
  }

  provisioner "shell" {
    name              = "Reboot"
    except            = (var.skip_hpc || local.refresh_mode) ? ["azure-arm.hpc"] : []
    inline_shebang    = var.default_inline_shebang
    skip_clean        = true
    expect_disconnect = true
    pause_after       = "5m"
    inline = [
      "(sleep 5; sudo shutdown -r now) &"
    ]
  }

  provisioner "shell" {
    name            = "(Refresh mode) Regenerate component_versions.txt from installed packages"
    except          = (local.refresh_mode && !var.skip_hpc) ? [] : ["azure-arm.hpc"]
    execute_command = "chmod +x {{ .Path }}; {{ .Vars }} sudo -E bash '{{ .Path }}'"
    inline = [
      "cd /home/${local.ssh_username}/azhpc-images/components; bash refresh_component_versions.sh ${local.gpu_platform}",
    ]
  }

  provisioner "shell" {
    name           = "Add image version to component_versions.txt"
    inline_shebang = var.default_inline_shebang
    inline = [
      "sudo mkdir -p /opt/azurehpc",
      "sudo python3 -c 'import json,pathlib;p=pathlib.Path(\"/opt/azurehpc/component_versions.txt\");d=json.loads(p.read_text()) if p.exists() else {};d[\"ImageVersion\"]=\"${local.image_version}\";p.write_text(json.dumps(d,indent=2)+\"\\n\")'",
      "sudo chmod 644 /opt/azurehpc/component_versions.txt"
    ]
  }

  provisioner "shell" {
    name            = "Trivy vulnerability scanning (standalone step for testing purposes)"
    except          = var.skip_hpc ? [] : ["azure-arm.hpc"]
    execute_command = "chmod +x {{ .Path }}; {{ .Vars }} sudo -E bash '{{ .Path }}'"
    inline = [
      "cd /home/${local.ssh_username}/azhpc-images/distros/${local.os_script_folder_name}/; ARCHITECTURE=$(uname -m) bash ../../components/trivy_scan.sh",
    ]
  }

  provisioner "shell" {
    name           = "List all installed packages after HPC component installation"
    inline_shebang = var.default_inline_shebang
    inline = [
      "if command -v dnf &> /dev/null; then sudo dnf list installed; fi",
      "if command -v dpkg-query &> /dev/null; then dpkg-query -l; fi",
    ]
  }

  provisioner "shell-local" {
    name           = "create local directory for manifests"
    inline_shebang = var.default_inline_shebang
    inline = [
      "mkdir -p /tmp/image_manifests"
    ]
  }

  provisioner "shell" {
    name           = "Display all image manifests in /opt/azurehpc for debugging purposes"
    inline_shebang = var.default_inline_shebang
    inline = [
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
    name              = "Reboot"
    inline_shebang    = var.default_inline_shebang
    skip_clean        = true
    expect_disconnect = true
    pause_after       = "15m"
    inline = [
      "(sleep 5; sudo shutdown -r now) &"
    ]
  }

  provisioner "shell" {
    name           = "Run tests (post-reboot)"
    except         = (!local.skip_validation && !var.skip_hpc) ? [] : ["azure-arm.hpc"]
    inline_shebang = var.default_inline_shebang
    environment_vars = [
      "TARGET_NODE_TYPE=${local.target_node_type}"
    ]
    inline = [
      "/opt/azurehpc/test/run-tests.sh ${local.gpu_platform}"
    ]
  }

  provisioner "shell" {
    name            = "Run health checks"
    except          = (!local.skip_validation && !var.skip_hpc && local.gpu_sku != "GB200" && local.gpu_sku != "VR200" && local.gpu_sku != "NCv6") ? [] : ["azure-arm.hpc"]
    execute_command = "chmod +x {{ .Path }}; {{ .Vars }} sudo -E bash '{{ .Path }}'"
    inline = [
      "/opt/azurehpc/test/azurehpc-health-checks/run-health-checks.sh -o /opt/azurehpc/test/azurehpc-health-checks/health.log -v",
      "cat /opt/azurehpc/test/azurehpc-health-checks/health.log | grep --ignore-case 'Health checks completed with exit code: 0.'",
    ]
  }

  # --------------------------------------------------------------------------
  # Deprovision: Prepare VM for image capture
  # --------------------------------------------------------------------------
  provisioner "shell" {
    name = "Clear history and deprovision"
    # skip_clean      = true  # TODO: uncomment once we migrate back epilog
    inline_shebang = "/bin/bash -e"
    environment_vars = [
      "TARGET_NODE_TYPE=${local.target_node_type}"
    ]
    inline = local.skip_create_artifacts ? [
      "echo 'Skipping clear history and deprovision (skip_create_artifacts=true)'"
      ] : [
      "cd /home/${local.ssh_username}/azhpc-images/utils",
      "sudo -E ./clear_history.sh"
    ]
  }

  provisioner "shell" {
    name           = "Clear history and deprovision (temporary epilog)"
    skip_clean     = true
    inline_shebang = "/bin/bash -e"
    environment_vars = [
      "TARGET_NODE_TYPE=${local.target_node_type}"
    ]
    inline = local.skip_create_artifacts ? [
      "echo 'Skipping deprovision epilog (skip_create_artifacts=true)'"
      ] : [
      "cd /home/${local.ssh_username}/azhpc-images/utils",
      "sudo -E ./clear_history_epilog.sh"
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
      # If retaining the VM, display its public IP for SSH debugging, then exit 0
      <<-EOF
      if [[ "${local.retain_vm_on_fail}" == true || "${local.retain_vm_always}" == true || "${local.externally_managed_resource_group}" == true ]]; then
        PUBLIC_IP=$(az vm list-ip-addresses \
          --resource-group "${local.azure_resource_group}" \
          --query "[0].virtualMachine.network.publicIpAddresses[0].ipAddress" \
          --output tsv 2>/dev/null)
        if [[ -n "$PUBLIC_IP" ]]; then
          echo "##[section]VM retained — SSH with: ssh ${local.ssh_username}@$PUBLIC_IP"
        else
          echo "##[warning]Could not determine public IP for VMs in ${local.azure_resource_group}"
        fi
        exit 0
      fi
      az group delete --name "${local.azure_resource_group}" --yes
      EOF
    ]
  }

  # --------------------------------------------------------------------------
  # Post-processor: Generate build manifest
  # --------------------------------------------------------------------------
  post-processor "manifest" {
    output     = "/tmp/image_manifests/manifest.json"
    strip_path = true
    custom_data = {
      managed_image_shared_image_gallery_id = local.create_image ? "/subscriptions/${var.sig_subscription_id != "" ? var.sig_subscription_id : build.SubscriptionID}/resourceGroups/${var.sig_resource_group_name}/providers/Microsoft.Compute/galleries/${var.sig_gallery_name}/images/${local.sig_image_name}/versions/${local.image_version}" : "",
      vhd_blob_name                         = local.create_vhd ? "${local.image_name}.vhd" : ""
    }
  }
}
