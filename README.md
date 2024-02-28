[![Build Status](https://dev.azure.com/hpc-platform-team/hpc-image-val/_apis/build/status/hpc-image-build?branchName=master)](https://dev.azure.com/hpc-platform-team/hpc-image-val/_build/latest?definitionId=3&branchName=master)

|OS Version|Status Badge|
|----------|------------|
|Ubuntu 20.04|[![Build Status](https://dev.azure.com/hpc-platform-team/hpc-image-val/_apis/build/status/hpc-image-build?branchName=master&jobName=Validate_Virtual_Machine&configuration=Validate_Virtual_Machine%20ubuntu_20.04)](https://dev.azure.com/hpc-platform-team/hpc-image-val/_build/latest?definitionId=3&branchName=master)
|Ubuntu 22.04|[![Build Status](https://dev.azure.com/hpc-platform-team/hpc-image-val/_apis/build/status/hpc-image-build?branchName=master&jobName=Validate_Virtual_Machine&configuration=Validate_Virtual_Machine%20ubuntu_22.04)](https://dev.azure.com/hpc-platform-team/hpc-image-val/_build/latest?definitionId=3&branchName=master)
|AlmaLinux 8.7|[![Build Status](https://dev.azure.com/hpc-platform-team/hpc-image-val/_apis/build/status/hpc-image-build?branchName=master&jobName=Validate_Virtual_Machine&configuration=Validate_Virtual_Machine%20alma8.7)](https://dev.azure.com/hpc-platform-team/hpc-image-val/_build/latest?definitionId=3&branchName=master)

# Azhpc Images

This repository contains installation scripts for HPC images in Azure Marketplace, specifically [CentOS-HPC](https://azuremarketplace.microsoft.com/en-us/marketplace/apps/openlogic.centos-hpc), [Ubuntu-HPC](https://azuremarketplace.microsoft.com/en-us/marketplace/apps/microsoft-dsvm.ubuntu-hpc), and [AlmaLinux-HPC](https://azuremarketplace.microsoft.com/en-us/marketplace/apps/almalinux.almalinux-hpc).

Note: CentOS 7 is currently the only supported CentOS version, which will continue to receive community security patches and bug fix updates until June 2024. Therefore, we are not releasing any new CentOS HPC images to Azure marketplace. You can still use our CentOS HPC images, but it is suggested to consider moving to our AlmaLinux HPC images alternatives in Azure marketplace.

## Preparing HPC Red Hat Enterprise Linux Image

Red Hat publishes a collection of marketplace images for different 
applications and licensing models. To use RHEL and get all the software and drivers
included in the azhpc-images we recommend that you build a custom image using 
the scripts in this repository.

The following usage has been verified using the RHEL 7.9 marketplace image 
`RedHat:RHEL:79-gen2:7.9.2021121602`
and a Standard_NC6s_v2 VM. Create a VM with this configuration
and use the script contained in this project.

```bash
sudo ./rhel-hpc-7_9-install.sh
```

Once this command is run successfully, then you can use the documented procedure
for [capturing a linux image](https://docs.microsoft.com/azure/virtual-machines/linux/capture-image).

>Note: Accelerated Networking with IB networking isn't
supported in the RHEL-HPC prepared image. Use `AcceleratedNetworking = False`.


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
