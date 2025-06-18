#!/bin/bash

echo "user.max_user_namespaces=0" > /etc/sysctl.d/userns.conf
sysctl -p /etc/sysctl.d/userns.conf
