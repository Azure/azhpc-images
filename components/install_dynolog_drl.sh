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
    # Install build dependencies (kept after for debugging)
    ##########################################################################

    if [[ $DISTRIBUTION == "azurelinux3.0" ]]; then
        dnf install -y cmake rust cargo ninja-build build-essential
    elif [[ $DISTRIBUTION == *"ubuntu"* ]]; then
        apt-get install -y cmake rustc-1.82 cargo-1.82 ninja-build build-essential
        apt-get install -y g++ pkg-config uuid-dev libssl-dev
        export PATH="/usr/lib/rust-1.82/bin:$PATH"
    elif [[ $DISTRIBUTION == almalinux* ]] || [[ $DISTRIBUTION == rocky* ]]; then
        dnf install -y cmake rust cargo ninja-build libuuid-devel gcc-toolset-12
        if [[ $DISTRIBUTION == almalinux8.10 ]] || [[ $DISTRIBUTION == rocky8.10 ]]; then
            dnf install -y openssl3-devel
        else
            dnf install -y openssl-devel
        fi
        source /opt/rh/gcc-toolset-12/enable
    fi

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

    ldconfig
    DCGM_LIB=$(ldconfig -p | awk '/libdcgm\.so(\.[0-9]+)* / {print $NF; exit}')
    [[ -z "$DCGM_LIB" ]] && { echo "FATAL: libdcgm.so not found"; exit 1; }

    # NOTE: picking more than one subgroup in the same letter group induces multiplexing in DCGM that tanks performance when MPI ranks per node
    # is equal to number of cores
    # A.1: 1002 sm_active, 1003 sm_occupancy, 1004 tensor_active, 1006 fp64_active
    # A.2: 1008 fp16_active, 1013 tensor_imma_active, 1014 tensor_hmma_active
    # A.3: 1007 fp32_active
    # B.0: 1005 dram_active
    # C.0: 1009 pcie_tx, 1010 pcie_rx
    # D.0: 1001 gr_engine_active
    # E.0: 1011 nvlink_tx, 1012 nvlink_rx
    cat <<-EOF > /etc/systemd/system/dynolog.service
[Unit]
Description=dynolog
After=nvidia-dcgm.service

[Service]
Environment="GLOG_logtostderr=1" "GLOG_minloglevel=2"
ExecStart=/opt/dynolog/bin/dynolog -enable_ipc_monitor=true -enable_gpu_monitor=true -kernel_monitor_reporting_interval_s=10 -dcgm_lib_path=${DCGM_LIB} -dcgm_reporting_interval_s=10 -use_udsrelay=true -dcgm_fields="100,155,204,1001,1005,1008,1009,1010,1011,1012,1013,1014"
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
    if [[ $DISTRIBUTION == almalinux8.10 ]] || [[ $DISTRIBUTION == rocky8.10 ]]; then
        # workaround for openssl 3.0 on almalinux/rocky 8.10 - dyno-relay-logger cmake fails to find openssl 3.0 without these variables set
        export OPENSSL_DIR=/usr
        export OPENSSL_INCLUDE_DIR=/usr/include/openssl3
        export OPENSSL_LIB_DIR=/usr/lib64/openssl3
        cmake .. -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
            -DCMAKE_BUILD_TYPE=Release \
            -DOPENSSL_ROOT_DIR=/usr/include/openssl3 \
            -DOPENSSL_INCLUDE_DIR=/usr/include/openssl3 \
            -DOPENSSL_CRYPTO_LIBRARY=/usr/lib64/openssl3/libcrypto.so \
            -DOPENSSL_SSL_LIBRARY=/usr/lib64/openssl3/libssl.so
    elif [[ $DISTRIBUTION == *"ubuntu"* ]]; then
        # On Ubuntu, OpenSSL libs are in the multiarch path, not /usr/lib or /usr/lib64
        export OPENSSL_LIB_DIR=/usr/lib/$(dpkg-architecture -qDEB_HOST_MULTIARCH)
        cmake .. -DCMAKE_POLICY_VERSION_MINIMUM=3.5 -DCMAKE_BUILD_TYPE=Release
    else
        cmake .. -DCMAKE_POLICY_VERSION_MINIMUM=3.5 -DCMAKE_BUILD_TYPE=Release
    fi
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

    write_component_version "dynolog" ${DYNOLOG_VERSION}
    write_component_version "dyno_relay_logger" ${DRL_VERSION}

fi
