#!/bin/bash
##############################################################################
# Build and install dynolog and dyno-relay-logger
##############################################################################

set -ex
source ${UTILS_DIR}/utilities.sh

if [[ "$GPU" == "NVIDIA" ]]; then

    ORIGINAL_PATH="$PATH"
    DYNOLOG_INSTALL_DIR=/opt/dynolog/bin
    mkdir -p $DYNOLOG_INSTALL_DIR

    dynolog_metadata=$(get_component_config "dynolog")
    DYNOLOG_VERSION=$(jq -r '.version' <<< $dynolog_metadata)
    DYNOLOG_URL=$(jq -r '.url' <<< $dynolog_metadata)

    drl_metadata=$(get_component_config "dyno_relay_logger")
    DRL_VERSION=$(jq -r '.version' <<< $drl_metadata)
    DRL_URL=$(jq -r '.url' <<< $drl_metadata)

    ##########################################################################
    # Install build dependencies, tracking newly installed packages
    ##########################################################################
    NEWLY_INSTALLED_PKGS=()

    pkg_is_installed() {
        local pkg="$1"
        if command -v dpkg-query &>/dev/null; then
            dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q "install ok installed"
        elif command -v rpm &>/dev/null; then
            rpm -q "$pkg" &>/dev/null
        fi
    }

    install_and_track() {
        local manager="$1"
        shift
        local to_install=()
        for pkg in "$@"; do
            if pkg_is_installed "$pkg"; then
                echo "Package '$pkg' is already installed, skipping"
            else
                to_install+=("$pkg")
            fi
        done
        if [[ ${#to_install[@]} -gt 0 ]]; then
            $manager install -y "${to_install[@]}"
            NEWLY_INSTALLED_PKGS+=("${to_install[@]}")
        fi
    }

    if [[ $DISTRIBUTION == "azurelinux3.0" ]]; then
        install_and_track tdnf cmake cargo ninja-build build-essential
    elif [[ $DISTRIBUTION == *"ubuntu"* ]]; then
        install_and_track apt-get cmake cargo ninja-build build-essential
        install_and_track apt-get g++ pkg-config uuid-dev libssl-dev
    elif [[ $DISTRIBUTION == almalinux* ]] || [[ $DISTRIBUTION == rocky* ]]; then
        install_and_track yum cmake cargo ninja-build
    fi

    export RUSTUP_HOME=/tmp/cargo-rust
    export CARGO_HOME=/tmp/cargo-rust
    export RUSTUP_INIT_SKIP_PATH_CHECK=yes
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    export PATH="$RUSTUP_HOME/bin:$PATH"

    ##########################################################################
    # Build and install dynolog
    ##########################################################################
    git clone --recurse-submodules -j8 --branch v${DYNOLOG_VERSION}  $DYNOLOG_URL /tmp/dynolog
    pushd /tmp/dynolog
    ./scripts/build.sh -DCMAKE_POLICY_VERSION_MINIMUM=3.5
    mv build/dynolog/src/dynolog $DYNOLOG_INSTALL_DIR
    mv build/release/dyno $DYNOLOG_INSTALL_DIR
    popd
    rm -rf /tmp/dynolog

    cat <<-EOF > /etc/systemd/system/dynolog.service
[Unit]
Description=dynolog
After=nvidia-dcgm.service

[Service]
Environment="GLOG_logtostderr=1" "GLOG_minloglevel=2"
ExecStart=/opt/dynolog/bin/dynolog -enable_ipc_monitor=true -enable_gpu_monitor=true -kernel_monitor_reporting_interval_s=10 -dcgm_lib_path=/usr/lib/libdcgm.so -dcgm_reporting_interval_s=10 -use_udsrelay=true -dcgm_fields="100,155,204,1001,1002,1003,1004,1005,1006,1007,1008,1009,1010,1011,1012"
Restart=always
RestartSec=60s
User=root
Group=root
WorkingDirectory=/tmp

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable dynolog.service

    ##########################################################################
    # Build and install dyno-relay-logger
    ##########################################################################
    git clone --recurse-submodules -j8 --branch v${DRL_VERSION} $DRL_URL /tmp/dyno-relay-logger
    pushd /tmp/dyno-relay-logger
    mkdir build && cd build
    cmake .. -DCMAKE_POLICY_VERSION_MINIMUM=3.5 -DCMAKE_BUILD_TYPE=Release
    cmake --build . -j$(nproc)
    mv dynorelaylogger $DYNOLOG_INSTALL_DIR
    mv dynorelayloggerinfo $DYNOLOG_INSTALL_DIR
    popd
    rm -rf /tmp/dyno-relay-logger

    cat <<-EOF > /etc/systemd/system/dyno-relay-logger.service
[Unit]
Description=dyno-relay-logger
After=nvidia-dcgm.service

[Service]
Environment="GLOG_logtostderr=1" "GLOG_minloglevel=2"
ExecStart=/opt/dynolog/bin/dynorelaylogger --forward=aehubs
Restart=always
RestartSec=60s
User=root
Group=root
WorkingDirectory=/tmp

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable dyno-relay-logger.service

    ##########################################################################
    # Remove build dependencies that were not originally installed
    ##########################################################################
    if [[ ${#NEWLY_INSTALLED_PKGS[@]} -gt 0 ]]; then
        echo "Removing newly installed build dependencies: ${NEWLY_INSTALLED_PKGS[*]}"
        if [[ $DISTRIBUTION == "azurelinux3.0" ]]; then
            tdnf remove -y "${NEWLY_INSTALLED_PKGS[@]}" || true
        elif [[ $DISTRIBUTION == *"ubuntu"* ]]; then
            apt-get remove -y "${NEWLY_INSTALLED_PKGS[@]}" || true
            apt-get autoremove -y || true
        elif [[ $DISTRIBUTION == almalinux* ]] || [[ $DISTRIBUTION == rocky* ]]; then
            yum remove -y "${NEWLY_INSTALLED_PKGS[@]}" || true
        fi
    fi

    # delete build tools
    rm -rf $RUSTUP_HOME

    write_component_version "dynolog" ${DYNOLOG_VERSION}
    write_component_version "dyno_relay_logger" ${DRL_VERSION}

fi
