#!/bin/bash
sed -i 's/^SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
