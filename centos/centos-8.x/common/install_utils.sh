#!/bin/bash
set -ex

# Install pre-reqs and development tools
yum groupinstall -y "Development Tools"
yum install -y numactl \
    numactl-devel \
    libxml2-devel \
    byacc \
    environment-modules \
    gtk2 \
    atk \
    cairo \
    tcl \
    tk \
    m4 \
    tcsh \
    gcc-gfortran \
    python36-devel \
    elfutils-libelf-devel \
    kernel-rpm-macros \
    glibc-devel \
    libudev-devel \
    binutils \
    binutils-devel \
    selinux-policy-devel \
    kernel-headers \
    nfs-utils \
    fuse-libs \
    libpciaccess \
    cmake \
    libnl3-devel \
    libarchive
