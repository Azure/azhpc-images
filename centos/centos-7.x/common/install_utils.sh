#!/bin/bash
set -ex

# Install pre-reqs and development tools
yum groupinstall -y "Development Tools"
yum install -y numactl \
    numactl-devel \
    libxml2-devel \
    byacc \
    environment-modules \
    python-devel \
    python-setuptools \
    gtk2 \
    atk \
    cairo \
    tcl \
    tk \
    m4 \
    texinfo \
    glibc-devel \
    glibc-static \
    libudev-devel \
    binutils \
    binutils-devel \
    selinux-policy-devel \
    kernel-headers \
    nfs-utils \
    fuse-libs \
    libpciaccess \
    nfs-utils
