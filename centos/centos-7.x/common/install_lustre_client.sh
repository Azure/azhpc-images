#!/bin/bash
set -ex

# Install packages required to facilitate DKMS-based installations
yum install -y asciidoc audit-libs-devel automake bc \
               bison device-mapper-devel elfutils-devel \
               elfutils-libelf-devel expect flex gcc gcc-c++ git \
               glib2 glib2-devel hmaccalc keyutils-libs-devel krb5-devel ksh \
               libattr-devel libblkid-devel libselinux-devel libtool \
               libuuid-devel libyaml-devel lsscsi make ncurses-devel \
               net-snmp-devel net-tools newt-devel \
               parted patchutils pciutils-devel perl-ExtUtils-Embed \
               pesign redhat-rpm-config rpm-build systemd-devel \
               tcl-devel tk-devel wget xmlto yum-utils zlib-devel

# Install the kernel packages
yum install -y kernel \
               kernel-devel \
               kernel-headers \
               kernel-abi-whitelists \
               kernel-tools \
               kernel-tools-libs \
               kernel-tools-libs-devel

# Install the EPEL repository definition. EPEL provides the DKMS software
yum install -y epel-release

cat << EOF >> /etc/yum.repos.d/lustre-client.repo
[lustre-client]
name=lustre-client
baseurl=https://downloads.whamcloud.com/public/lustre/latest-release/el7/client
# exclude=*debuginfo*
gpgcheck=0
EOF

# Install the Lustre client user-space tools and DKMS kernel module package
yum --nogpgcheck --enablerepo=lustre-client install -y lustre-client-dkms lustre-client
