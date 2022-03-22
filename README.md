[![Build Status](https://dev.azure.com/hpc-platform-team/hpc-image-val/_apis/build/status/hpc-image-val?branchName=master)](https://dev.azure.com/hpc-platform-team/hpc-image-val/_build/latest?definitionId=3&branchName=master)

|OS Version|Status Badge|
|----------|------------|
|CentOS 7.6|[![Build Status](https://dev.azure.com/hpc-platform-team/hpc-image-val/_apis/build/status/hpc-image-val?branchName=master&jobName=Validate_Virtual_Machine&configuration=Validate_Virtual_Machine%20centos76)](https://dev.azure.com/hpc-platform-team/hpc-image-val/_build/latest?definitionId=3&branchName=master)|
|CentOS 7.7|[![Build Status](https://dev.azure.com/hpc-platform-team/hpc-image-val/_apis/build/status/hpc-image-val?branchName=master&jobName=Validate_Virtual_Machine&configuration=Validate_Virtual_Machine%20centos77)](https://dev.azure.com/hpc-platform-team/hpc-image-val/_build/latest?definitionId=3&branchName=master)|
|CentOS 7.8|[![Build Status](https://dev.azure.com/hpc-platform-team/hpc-image-val/_apis/build/status/hpc-image-val?branchName=master&jobName=Validate_Virtual_Machine&configuration=Validate_Virtual_Machine%20centos78)](https://dev.azure.com/hpc-platform-team/hpc-image-val/_build/latest?definitionId=3&branchName=master)|
|CentOS 7.9|[![Build Status](https://dev.azure.com/hpc-platform-team/hpc-image-val/_apis/build/status/hpc-image-val?branchName=master&jobName=Validate_Virtual_Machine&configuration=Validate_Virtual_Machine%20centos79)](https://dev.azure.com/hpc-platform-team/hpc-image-val/_build/latest?definitionId=3&branchName=master)|
|CentOS 8.1|[![Build Status](https://dev.azure.com/hpc-platform-team/hpc-image-val/_apis/build/status/hpc-image-val?branchName=master&jobName=Validate_Virtual_Machine&configuration=Validate_Virtual_Machine%20centos81)](https://dev.azure.com/hpc-platform-team/hpc-image-val/_build/latest?definitionId=3&branchName=master)|
|Ubuntu 18.04|[![Build Status](https://dev.azure.com/hpc-platform-team/hpc-image-val/_apis/build/status/hpc-image-val?branchName=master&jobName=Validate_Virtual_Machine&configuration=Validate_Virtual_Machine%20ubuntu1804)](https://dev.azure.com/hpc-platform-team/hpc-image-val/_build/latest?definitionId=3&branchName=master)|
|Ubuntu 18.04 LTS Gen1|[![Build Status](https://dev.azure.com/hpc-platform-team/hpc-image-val/_apis/build/status/hpc-image-val?branchName=master&jobName=Validate_Virtual_Machine&configuration=Validate_Virtual_Machine%20ubuntu1804LTSv1)](https://dev.azure.com/hpc-platform-team/hpc-image-val/_build/latest?definitionId=3&branchName=master)|
|Ubuntu 18.04 LTS Gen2|[![Build Status](https://dev.azure.com/hpc-platform-team/hpc-image-val/_apis/build/status/hpc-image-val?branchName=master&jobName=Validate_Virtual_Machine&configuration=Validate_Virtual_Machine%20ubuntu1804LTSv2)](https://dev.azure.com/hpc-platform-team/hpc-image-val/_build/latest?definitionId=3&branchName=master)|
|Ubuntu 20.04|[![Build Status](https://dev.azure.com/hpc-platform-team/hpc-image-val/_apis/build/status/hpc-image-val?branchName=master&jobName=Validate_Virtual_Machine&configuration=Validate_Virtual_Machine%20ubuntu2004)](https://dev.azure.com/hpc-platform-team/hpc-image-val/_build/latest?definitionId=3&branchName=master)


# Azhpc Images

This repository contains installation scripts for HPC images in Azure Marketplace.

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
