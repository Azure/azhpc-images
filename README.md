[![Build Status](https://dev.azure.com/hpc-platform-team/hpc-image-val/_apis/build/status/hpc-image-build?branchName=master)](https://dev.azure.com/hpc-platform-team/hpc-image-val/_build/latest?definitionId=3&branchName=master)

|OS Version|Status Badge|
|----------|------------|
|Ubuntu 20.04|[![Build Status](https://dev.azure.com/hpc-platform-team/hpc-image-val/_apis/build/status/hpc-image-build?branchName=master&jobName=Validate_Virtual_Machine&configuration=Validate_Virtual_Machine%20ubuntu_20.04)](https://dev.azure.com/hpc-platform-team/hpc-image-val/_build/latest?definitionId=3&branchName=master)
|Ubuntu 22.04|[![Build Status](https://dev.azure.com/hpc-platform-team/hpc-image-val/_apis/build/status/hpc-image-build?branchName=master&jobName=Validate_Virtual_Machine&configuration=Validate_Virtual_Machine%20ubuntu_22.04)](https://dev.azure.com/hpc-platform-team/hpc-image-val/_build/latest?definitionId=3&branchName=master)
|AlmaLinux 8.10|[![Build Status](https://dev.azure.com/hpc-platform-team/hpc-image-val/_apis/build/status/hpc-image-build?branchName=master&jobName=Validate_Virtual_Machine&configuration=Validate_Virtual_Machine%20alma8.10)](https://dev.azure.com/hpc-platform-team/hpc-image-val/_build/latest?definitionId=3&branchName=master)

# Azure HPC/AI VM Images

This repository houses a collection of scripts meticulously crafted for installing High-Performance Computing (HPC) and Artificial Intelligence (AI) libraries, along with tools essential for building Azure HPC/AI images. Whether you're provisioning compute-intensive workloads or crafting advanced AI models in the cloud, these scripts streamline the process, ensuring efficiency and reliability in your deployments.

Following are the current supported HPC/AI VM images that are available in Azure Marketplace:
- [Ubuntu-HPC](https://azuremarketplace.microsoft.com/en-us/marketplace/apps/microsoft-dsvm.ubuntu-hpc) 22.04 (microsoft-dsvm:ubuntu-hpc:2204:latest)
- [Ubuntu-HPC](https://azuremarketplace.microsoft.com/en-us/marketplace/apps/microsoft-dsvm.ubuntu-hpc) 20.04 (microsoft-dsvm:ubuntu-hpc:2004:latest)
- [AlmaLinux-HPC](https://azuremarketplace.microsoft.com/en-us/marketplace/apps/almalinux.almalinux-hpc) 8.10 (almalinux:almalinux-hpc:8_10-hpc-gen2:latest)

# How to Use

To build an image, you need to install [Packer](https://developer.hashicorp.com/packer/integrations/hashicorp/azure) and log in to [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/get-started-with-azure-cli). Create a Packer variable input file `image.pkrvars.hcl` like this:

```
# Use any appropriate VM SKU you have access to.
# Check image.pkr.hcl for more input variables, e.g pushing to a compute gallery.
gpu_size_option = "Standard_ND96asr_v4"
```

Then, run ` packer build -var-file="image.pkrvars.hcl" --use-sequential-evaluation -parallel-builds=1 -on-error=run-cleanup-provisioner image.pkr.hcl` to build an image. By default the command creates a VM, tries to run the scripts to create a managed image, then cleans up all Azure resources created. Use `retain_vm_always` or `retain_vm_on_fail` with `public_key` to access the build VM for troubleshooting.

# Kernel Update/Patching

Generally, OS kernel updates break compatibility of HPC components we install, e.g., Lustre. In our HPC images, the kernel is excluded from updates for this reason.

- Ubuntu 22.04: [https://github.com/Azure/azhpc-images/blob/master/ubuntu/ubuntu-22.x/ubuntu-22.04-hpc/install_prerequisites.sh#L5](https://github.com/Azure/azhpc-images/blob/master/ubuntu/ubuntu-22.x/ubuntu-22.04-hpc/install_prerequisites.sh#L5)
- AlmaLinux 8.10: [https://github.com/Azure/azhpc-images/blob/master/alma/common/install_utils.sh#L66](https://github.com/Azure/azhpc-images/blob/master/alma/common/install_utils.sh#L67)

We implement it this way, since lots of kernel dependencies are installed which are highly coupled to a specific kernel version. Thus, kernel updates are not encouraged in our HPC images.

Our HPC image releasing primary cadence is quarterly. In between releases, if we get flagged for security issues, we quickly apply the patch and release a hotfix in an adhoc fashion which can be done within a week or two.

Please keep using our latest HPC images. If any compliance issues (e.g., security bugs) are identified, please also report them (and patches, if any) to us. We will apply the fix and release the patched images as a hotfix.

# Contributing

This project welcomes contributions and suggestions.  Most contributions require you to agree to a
Contributor License Agreement (CLA) declaring that you have the right to, and actually do, grant us
the rights to use your contribution. For details, visit https://cla.opensource.microsoft.com.

When you submit a pull request, a CLA bot will automatically determine whether you need to provide
a CLA and decorate the PR appropriately (e.g., status check, comment). Simply follow the instructions
provided by the bot. You will only need to do this once across all repos using our CLA.

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/).
For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or
contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.
