#!/bin/bash
set -ex

source ${UTILS_DIR}/utilities.sh

# Load gcc
set CC=/usr/bin/gcc
set GCC=/usr/bin/gcc

INSTALL_PREFIX=/opt

# Setup module files for MPIs
MPI_MODULE_FILES_DIRECTORY=${MODULE_FILES_DIRECTORY}/mpi
mkdir -p ${MPI_MODULE_FILES_DIRECTORY}

if [[ "$GPU" == "AMD" ]]; then
    # AMD has regression on higher versions of HPC-X
    hpcx_metadata=$(get_component_config "hpcx_amd")
elif [[ "$(sku_network_mode)" == "no_rdma" ]]; then
    # Non-IB SKUs skip DOCA-OFED. Use inbox HPC-X (UCX linked against kernel-native rdma-core)
    hpcx_metadata=$(get_component_config "hpcx_inbox")
else
    hpcx_metadata=$(get_component_config "hpcx")
fi
HPCX_VERSION=$(jq -r '.version' <<< $hpcx_metadata)
HPCX_SHA256=$(jq -r '.sha256' <<< $hpcx_metadata)
HPCX_DOWNLOAD_URL=$(jq -r '.url' <<< $hpcx_metadata)

TARBALL=$(basename $HPCX_DOWNLOAD_URL)
HPCX_FOLDER=$(basename $HPCX_DOWNLOAD_URL .tbz)

download_and_verify ${HPCX_DOWNLOAD_URL} ${HPCX_SHA256}
tar -xvf ${TARBALL}

mv ${HPCX_FOLDER} ${INSTALL_PREFIX}
HPCX_PATH=${INSTALL_PREFIX}/${HPCX_FOLDER}
# Fix relocated HPC-X .la/.pc metadata before rebuilds consume the bundled UCX, HCOLL, and SHARP trees.
HPCX_DIR=${HPCX_PATH} ${HPCX_PATH}/utils/hpcx_fix_ladir.sh
HCOLL_PATH=${HPCX_PATH}/hcoll
SHARP_PATH=${HPCX_PATH}/sharp
UCX_PATH=${HPCX_PATH}/ucx
LIBFABRIC_PATH=/opt/libfabric
write_component_version "HPCX" $HPCX_VERSION

USE_INTERNAL_PMIX=false
if [[ "$DISTRIBUTION" == "ubuntu26.04" ]] || [[ "$DISTRIBUTION" == "azurelinux3.0" ]] || [[ "$DISTRIBUTION" == almalinux10* ]] || [[ "$DISTRIBUTION" == rocky10* ]] || [[ "$DISTRIBUTION" == rhel10* ]]; then
    # AZL3 lacks PMIx package published by CycleCloud team
    # Ubuntu 26.04 and EL10 have no external PMIx v5 to align to either
    USE_INTERNAL_PMIX=true
elif [[ "${TARGET_NODE_TYPE:-azure_vm_regular}" == "baremetal_3p" ]]; then
    # Baremetal 3p nodes must also avoid the external PMIx due to script-bastardization-induced package conflict
    USE_INTERNAL_PMIX=true
else
    pmix_metadata=$(get_component_config "pmix")
    PMIX_VERSION=$(jq -r '.version' <<< $pmix_metadata)
    PMIX_PATH=${INSTALL_PREFIX}/pmix/${PMIX_VERSION:0:-2}
fi

if [[ "$USE_INTERNAL_PMIX" == true ]]; then
    # Open MPI builds PMIx, hwloc and libevent from its own 3rd-party sources into its prefix.
    # Pointing these at HPC-X's ompi5 tree instead puts that directory, which also holds the
    # vendor libmpi/libopen-pal, ahead of the rebuild in every RUNPATH and shadows it at runtime.
    OMPI_DEPS_ARGS=(--with-pmix=internal --with-hwloc=internal --with-libevent=internal)
else
    OMPI_DEPS_ARGS=("--with-pmix=${PMIX_PATH}")
fi

REBUILD_HPCX=true
if [[ "$USE_INTERNAL_PMIX" == true ]] && [[ "$GPU" == "NVIDIA" ]] && sku_uses_ucx; then
    REBUILD_HPCX=false
fi

if [[ "$REBUILD_HPCX" == true ]]; then
    HPCX_REBUILD_ARGS=()
    if [[ "$GPU" == "AMD" ]]; then
        if [[ ! -d /opt/rocm ]]; then
            echo "ROCm must be installed before rebuilding HPC-X UCX with ROCm support."
            exit 1
        fi
        if sku_uses_ucx; then
            HPCX_REBUILD_ARGS+=(--rebuild-ucx --ucx-extra-config "--with-rocm=/opt/rocm")
        fi
    elif [[ "$GPU" == "NVIDIA" ]]; then
        HPCX_REBUILD_ARGS+=(--cuda)
    fi

    # Supplying --ompi-extra-config replaces the original HPC-X configure options. Restore the compatible vendor options here.
    HPCX_REBUILD_OMPI_ARGS=(--enable-mpi1-compatibility --without-xpmem --with-slurm --enable-orterun-prefix-by-default "${OMPI_DEPS_ARGS[@]}")

    if ! sku_uses_ucx; then
        HPCX_REBUILD_OMPI_ARGS+=(--without-ucx "--with-ofi=${LIBFABRIC_PATH}")
    else
        HPCX_REBUILD_ARGS+=(--with-hcoll)
        HPCX_REBUILD_OMPI_ARGS+=(--with-platform=contrib/platform/mellanox/optimized)
        if [[ "$GPU" == "AMD" ]]; then
            UCX_PATH=${HPCX_PATH}/ucx/hpcx-rebuild
            HPCX_REBUILD_OMPI_ARGS+=(--with-rocm=/opt/rocm)
        fi
    fi
    HPCX_REBUILD_ARGS+=(--ompi-extra-config "${HPCX_REBUILD_OMPI_ARGS[*]}")
    ${HPCX_PATH}/utils/hpcx_rebuild.sh "${HPCX_REBUILD_ARGS[@]}"

    # A rebuilt binary resolving libmpi outside hpcx-rebuild means the vendor Open MPI is
    # shadowing the rebuild, which otherwise fails silently at runtime.
    rebuilt_libmpi=$(ldd ${HPCX_PATH}/hpcx-rebuild/bin/ompi_info | awk '$1 ~ /^libmpi\.so/ {print $3}')
    if [[ "${rebuilt_libmpi}" != "${HPCX_PATH}/hpcx-rebuild/lib/"* ]]; then
        echo "Rebuilt HPC-X ompi_info loads ${rebuilt_libmpi:-<unresolved>} instead of the rebuilt libmpi."
        exit 1
    fi

    # hpcx_rebuild.sh installs into hpcx-rebuild but writes module/init files that compose the
    # MPI prefix as hpcx-rebuild$mpi_version, a directory it never creates. Only this suffix is
    # dropped; mpi_version still has legitimate uses such as ompi5/tests.
    for hpcx_rebuild_entrypoint in ${HPCX_PATH}/modulefiles/hpcx-rebuild ${HPCX_PATH}/hpcx-rebuild.sh; do
        [[ -e "${hpcx_rebuild_entrypoint}" ]] || continue
        sed -i --follow-symlinks -E \
            -e 's|/hpcx-rebuild\$\{mpi_version\}|/hpcx-rebuild|g' \
            -e 's|/hpcx-rebuild\$mpi_version|/hpcx-rebuild|g' \
            -e 's|/hpcx-rebuild[0-9]+|/hpcx-rebuild|g' \
            "${hpcx_rebuild_entrypoint}"
    done

    cp -r ${HPCX_PATH}/ompi/tests ${HPCX_PATH}/hpcx-rebuild
fi

if [[ "$USE_INTERNAL_PMIX" == true ]]; then
    # Report the PMIx actually shipped: the rebuild installs its internal copy, otherwise the
    # vendor ompi5 tree is used as-is.
    if [[ "$REBUILD_HPCX" == true ]]; then
        HPCX_PMIX_PKG_CONFIG_PATH=${HPCX_PATH}/hpcx-rebuild/lib/pkgconfig
    else
        HPCX_PMIX_PKG_CONFIG_PATH=${HPCX_PATH}/ompi5/lib/pkgconfig
    fi
    PMIX_VERSION=$(PKG_CONFIG_PATH=${HPCX_PMIX_PKG_CONFIG_PATH} pkg-config --modversion pmix)
    write_component_version "PMIX" "${PMIX_VERSION}"
fi

# hpcx_rebuild.sh installs fresh Open MPI and, on AMD, UCX metadata under this tree; fix those generated .la/.pc files too.
HPCX_DIR=${HPCX_PATH} ${HPCX_PATH}/utils/hpcx_fix_ladir.sh

cat > /etc/ld.so.conf.d/hpcx-sharp.conf <<EOF
${SHARP_PATH}/lib
EOF
cat > /etc/ld.so.conf.d/hpcx-ucx.conf <<EOF
${UCX_PATH}/lib
EOF
ldconfig

# Make HPC-X component metadata visible to pkg-config even when mpi/hpcx is not loaded.
# The HPC-X module still prepends these paths to PKG_CONFIG_PATH, but /usr/local
# pkgconfig symlinks let module-free builds resolve the same HCOLL, SHARP, and UCX.
HPCX_SYSTEM_PKGCONFIG_DIRS=(/usr/local/lib/pkgconfig)
if [[ $DISTRIBUTION == almalinux* ]] || [[ $DISTRIBUTION == rocky* ]] || [[ $DISTRIBUTION == rhel* ]] || [[ $DISTRIBUTION == "azurelinux3.0" ]]; then
    HPCX_SYSTEM_PKGCONFIG_DIRS+=(/usr/local/lib64/pkgconfig)
fi
for pkgconfig_dir in "${HPCX_SYSTEM_PKGCONFIG_DIRS[@]}"; do
    mkdir -p "${pkgconfig_dir}"
    for pc_file in ${HCOLL_PATH}/lib/pkgconfig/*.pc ${SHARP_PATH}/lib/pkgconfig/*.pc ${UCX_PATH}/lib/pkgconfig/*.pc; do
        [[ -f "${pc_file}" ]] || continue
        ln -sf "${pc_file}" "${pkgconfig_dir}/$(basename "${pc_file}")"
    done
done

if [[ $DISTRIBUTION == almalinux* ]] || [[ $DISTRIBUTION == rocky* ]] || [[ $DISTRIBUTION == rhel* ]] || [[ $DISTRIBUTION == "azurelinux3.0" ]]; then
    # exclude ucx from updates
    dnf_pin_packages "ucx*"
fi

# HPC-X
# mpi/hpcx is the public HPC-X entrypoint.
if [[ "$REBUILD_HPCX" == true ]]; then
    HPCX_MODULE="${HPCX_PATH}/modulefiles/hpcx-rebuild"
else
    HPCX_MODULE="${HPCX_PATH}/modulefiles/hpcx"
fi
HPCX_NON_UCX_EXTRAS=""
if ! sku_uses_ucx; then
    # On non-UCX SKUs:
    # - Force PML cm (MTL-based) instead of ob1 (BTL-based). ob1 auto-selects BTL openib
    #   which initializes against rdma-core but can't move data on MANA-only hardware, causing hangs.
    # - Use libfabric tcp provider explicitly (auto-detection fails due to docker bridge 172.17.0.1).
    # - Disable UCC (tl_ucp probes verbs on MANA and fails) and hcoll (requires Mellanox IB HCA).
    read -r -d '' HPCX_NON_UCX_EXTRAS << 'EXTRAS' || true
setenv          OMPI_MCA_pml cm
setenv          OMPI_MCA_mtl_ofi_provider_include tcp
setenv          OMPI_MCA_coll_ucc_enable 0
setenv          OMPI_MCA_coll_hcoll_enable 0
EXTRAS
fi
cat << EOF >> ${MPI_MODULE_FILES_DIRECTORY}/hpcx-${HPCX_VERSION}
#%Module 1.0
#
#  HPCx ${HPCX_VERSION}
#
conflict        mpi
module load ${HPCX_MODULE}
${HPCX_NON_UCX_EXTRAS}
EOF

ln -s ${MPI_MODULE_FILES_DIRECTORY}/hpcx-${HPCX_VERSION} ${MPI_MODULE_FILES_DIRECTORY}/hpcx-pmix-${HPCX_VERSION}

ln -s ${MPI_MODULE_FILES_DIRECTORY}/hpcx-${HPCX_VERSION} ${MPI_MODULE_FILES_DIRECTORY}/hpcx
ln -s ${MPI_MODULE_FILES_DIRECTORY}/hpcx-pmix-${HPCX_VERSION} ${MPI_MODULE_FILES_DIRECTORY}/hpcx-pmix

# Install MVAPICH
# Skips:
#   * GB-family nodes (ubuntu24.04 and azurelinux3.0) — MVAPICH is not
#     supported on those distribution/SKU-family combinations.
#   * Ubuntu 26.04 — MVAPICH 4.1's bundled libfabric does not build with
#     resolute's gcc 15 (the OPX provider's OPX_COMPILE_TIME_ASSERT macro
#     parses as a bare `if(0){...}` outside of a function and is rejected),
#     and its UCR provider uses an old gdrcopy API incompatible with
#     gdrcopy 2.5.x. Disabling those two providers (--enable-opx=no
#     --enable-ucr=no) unblocks libfabric, but resolute's gcc 15 then
#     hangs/OOMs on MVAPICH's collectives source. Skip until MVAPICH
#     publishes a release that builds cleanly against gcc 15.
if ! [[ ("${DISTRIBUTION}" == "ubuntu24.04" || "${DISTRIBUTION}" == "azurelinux3.0") && "${SKU_FAMILY}" == "gb-family" ]] && \
   [[ "${DISTRIBUTION}" != "ubuntu26.04" ]]; then
    mvapich_metadata=$(get_component_config "mvapich")
    MVAPICH_VERSION=$(jq -r '.version' <<< $mvapich_metadata)
    MVAPICH_SHA256=$(jq -r '.sha256' <<< $mvapich_metadata)
    MVAPICH_DOWNLOAD_URL=$(jq -r '.url' <<< $mvapich_metadata)
    TARBALL=$(basename $MVAPICH_DOWNLOAD_URL)
    MVAPICH_FOLDER=$(basename $MVAPICH_DOWNLOAD_URL .tar.gz)

    download_and_verify $MVAPICH_DOWNLOAD_URL $MVAPICH_SHA256
    tar -xvf ${TARBALL}
    pushd ${MVAPICH_FOLDER}
    # Error exclusive to Ubuntu 22.04
    # configure: error: The Fortran compiler gfortran will not compile files that call
    # the same routine with arguments of different types.
    # Each step on its own line so set -e catches a configure or make failure
    # — the original `cmd && cmd && cmd` form only triggered set -e on the
    # last command, masking earlier breakage on new distros (caught when
    # adding ubuntu26.04 support).
    mvapich_transport_args=""
    # MVAPICH_TRANSPORT_LIB_PATH captures the lib dir of the transport (UCX or libfabric)
    # that MVAPICH is linked against. It is surfaced via the modulefile so the dynamic
    # linker finds the matching libucs/libuct/libucp (or libfabric) at runtime instead of
    # the system DOCA-OFED copy from /etc/ld.so.cache, which has a different ABI when
    # HPC-X is pinned to an older release (e.g. AMD GPU images on HPC-X 2.18).
    if sku_uses_ucx; then
        mvapich_transport_args="--with-ucx=${UCX_PATH}"
        MVAPICH_TRANSPORT_LIB_PATH="${UCX_PATH}/lib"
    else
        mvapich_transport_args="--with-device=ch4:ofi --with-libfabric=${LIBFABRIC_PATH}"
        MVAPICH_TRANSPORT_LIB_PATH="${LIBFABRIC_PATH}/lib"
    fi
    ./configure $(if [[ $DISTRIBUTION == *"ubuntu"* ]] || [[ $DISTRIBUTION == "azurelinux3.0" ]]; then echo "FFLAGS=-fallow-argument-mismatch"; fi) --prefix=${INSTALL_PREFIX}/mvapich-${MVAPICH_VERSION} --enable-g=none --enable-fast=yes ${mvapich_transport_args}
    make -j$(nproc)
    make install
    popd
    write_component_version "MVAPICH" ${MVAPICH_VERSION}

    # On non-UCX SKUs (OFI transport), force the tcp provider (auto-detection picks
    # the legacy sockets provider because MPICH4 requests shared-AV which tcp lacks)
    # and disable CMA (process_vm_readv fails with ptrace_scope=1 on sibling processes).
    MVAPICH_NON_UCX_EXTRAS=""
    if ! sku_uses_ucx; then
        read -r -d '' MVAPICH_NON_UCX_EXTRAS << 'EXTRAS' || true
setenv          FI_PROVIDER tcp
setenv          MPIR_CVAR_CH4_CMA_ENABLE 0
EXTRAS
    fi
    cat << EOF >> ${MPI_MODULE_FILES_DIRECTORY}/mvapich-${MVAPICH_VERSION}
#%Module 1.0
#
#  MVAPICH ${MVAPICH_VERSION}
#
conflict        mpi
prepend-path    PATH            /opt/mvapich-${MVAPICH_VERSION}/bin
prepend-path    LD_LIBRARY_PATH /opt/mvapich-${MVAPICH_VERSION}/lib:${MVAPICH_TRANSPORT_LIB_PATH}
prepend-path    MANPATH         /opt/mvapich-${MVAPICH_VERSION}/share/man
setenv          MPI_BIN         /opt/mvapich-${MVAPICH_VERSION}/bin
setenv          MPI_INCLUDE     /opt/mvapich-${MVAPICH_VERSION}/include
setenv          MPI_LIB         /opt/mvapich-${MVAPICH_VERSION}/lib
setenv          MPI_MAN         /opt/mvapich-${MVAPICH_VERSION}/share/man
setenv          MPI_HOME        /opt/mvapich-${MVAPICH_VERSION}
${MVAPICH_NON_UCX_EXTRAS}
EOF
    ln -s ${MPI_MODULE_FILES_DIRECTORY}/mvapich-${MVAPICH_VERSION} ${MPI_MODULE_FILES_DIRECTORY}/mvapich
fi

# Install Open MPI (deprecated)
if [[ "$DISTRIBUTION" != "ubuntu26.04" ]]; then
    ompi_metadata=$(get_component_config "ompi")
    OMPI_VERSION=$(jq -r '.version' <<< $ompi_metadata)
    OMPI_SHA256=$(jq -r '.sha256' <<< $ompi_metadata)
    OMPI_DOWNLOAD_URL=$(jq -r '.url' <<< $ompi_metadata)
    TARBALL=$(basename $OMPI_DOWNLOAD_URL)
    OMPI_FOLDER=$(basename $OMPI_DOWNLOAD_URL .tar.gz)

    download_and_verify $OMPI_DOWNLOAD_URL $OMPI_SHA256
    tar -xvf $TARBALL
    cd $OMPI_FOLDER
    if [[ "$USE_INTERNAL_PMIX" == true ]]; then
        PMIX_FLAG="${OMPI_DEPS_ARGS[*]}"
    elif [[ $DISTRIBUTION == "azurelinux3.0" || "${TARGET_NODE_TYPE:-azure_vm_regular}" == "baremetal_3p" ]]; then
        PMIX_FLAG="--with-pmix"
    else
        PMIX_FLAG="--with-pmix=${PMIX_PATH}"
    fi
    # OMPI_TRANSPORT_LIB_PATH: see MVAPICH_TRANSPORT_LIB_PATH above. Same rationale —
    # pin runtime UCX/libfabric to the install Open MPI was linked against.
    if sku_uses_ucx; then
        ./configure LD_LIBRARY_PATH=$LD_LIBRARY_PATH:${HCOLL_PATH}/lib --prefix=${INSTALL_PREFIX}/openmpi-${OMPI_VERSION} --with-ucx=${UCX_PATH} --with-hcoll=${HCOLL_PATH} ${PMIX_FLAG} --enable-mpirun-prefix-by-default --with-platform=contrib/platform/mellanox/optimized
        OMPI_TRANSPORT_LIB_PATH="${UCX_PATH}/lib"
    else
        # Drop --with-ucx, --with-hcoll (uses UCX internally), --with-platform (Mellanox-specific).
        ./configure --prefix=${INSTALL_PREFIX}/openmpi-${OMPI_VERSION} --without-ucx --with-ofi=${LIBFABRIC_PATH} ${PMIX_FLAG} --enable-mpirun-prefix-by-default
        OMPI_TRANSPORT_LIB_PATH="${LIBFABRIC_PATH}/lib"
    fi
    make -j$(nproc)
    make install
    cd ..
    write_component_version "OMPI" ${OMPI_VERSION}

    # On non-UCX SKUs, Open MPI standalone (built --without-ucx --with-ofi) has the same
    # PML auto-selection issue as HPC-X: ob1 wins over cm, but ob1's BTL tcp is confused
    # by the docker bridge (172.17.0.1 on all nodes). Fix with pml=cm + tcp provider.
    OMPI_NON_UCX_EXTRAS=""
    if ! sku_uses_ucx; then
        read -r -d '' OMPI_NON_UCX_EXTRAS << 'EXTRAS' || true
setenv          OMPI_MCA_pml cm
setenv          OMPI_MCA_mtl_ofi_provider_include tcp
EXTRAS
    fi
    cat << EOF >> ${MPI_MODULE_FILES_DIRECTORY}/openmpi-${OMPI_VERSION}
#%Module 1.0
#
#  OpenMPI ${OMPI_VERSION}
#
conflict        mpi
prepend-path    PATH            /opt/openmpi-${OMPI_VERSION}/bin
prepend-path    LD_LIBRARY_PATH /opt/openmpi-${OMPI_VERSION}/lib:${HCOLL_PATH}/lib:${OMPI_TRANSPORT_LIB_PATH}
prepend-path    MANPATH         /opt/openmpi-${OMPI_VERSION}/share/man
setenv          MPI_BIN         /opt/openmpi-${OMPI_VERSION}/bin
setenv          MPI_INCLUDE     /opt/openmpi-${OMPI_VERSION}/include
setenv          MPI_LIB         /opt/openmpi-${OMPI_VERSION}/lib
setenv          MPI_MAN         /opt/openmpi-${OMPI_VERSION}/share/man
setenv          MPI_HOME        /opt/openmpi-${OMPI_VERSION}
${OMPI_NON_UCX_EXTRAS}
EOF
    ln -s ${MPI_MODULE_FILES_DIRECTORY}/openmpi-${OMPI_VERSION} ${MPI_MODULE_FILES_DIRECTORY}/openmpi
fi

if [[ $DISTRIBUTION == almalinux* ]] || [[ $DISTRIBUTION == rocky* ]] || [[ $DISTRIBUTION == rhel* ]] || [[ $DISTRIBUTION == "azurelinux3.0" ]]; then
    # exclude openmpi, perftest from updates
    dnf_pin_packages "openmpi" "perftest"
fi

if [[ "$ARCHITECTURE" != "aarch64" ]]; then
    # Install Intel MPI
    impi_metadata=$(get_component_config "impi")
    IMPI_VERSION=$(jq -r '.version' <<< $impi_metadata)
    IMPI_SHA256=$(jq -r '.sha256' <<< $impi_metadata)
    IMPI_DOWNLOAD_URL=$(jq -r '.url' <<< $impi_metadata)
    IMPI_OFFLINE_INSTALLER=$(basename $IMPI_DOWNLOAD_URL)

    download_and_verify $IMPI_DOWNLOAD_URL $IMPI_SHA256
    bash $IMPI_OFFLINE_INSTALLER -s -a -s --eula accept

    impi_2021_version=${IMPI_VERSION:0:-2}
    mv ${INSTALL_PREFIX}/intel/oneapi/mpi/${impi_2021_version}/etc/modulefiles/mpi ${INSTALL_PREFIX}/intel/oneapi/mpi/${impi_2021_version}/etc/modulefiles/impi
    write_component_version "IMPI" ${IMPI_VERSION}

    IMPI_FI_PROVIDER="mlx"
    if [[ "$(sku_network_mode)" == "no_rdma" ]]; then
        IMPI_FI_PROVIDER="tcp"
    fi

    cat << EOF >> ${MPI_MODULE_FILES_DIRECTORY}/impi_${impi_2021_version}
#%Module 1.0
#
#  Intel MPI ${impi_2021_version}
#
conflict        mpi
module load /opt/intel/oneapi/mpi/${impi_2021_version}/etc/modulefiles/impi/${impi_2021_version}
setenv          MPI_BIN         /opt/intel/oneapi/mpi/${impi_2021_version}/bin
setenv          MPI_INCLUDE     /opt/intel/oneapi/mpi/${impi_2021_version}/include
setenv          MPI_LIB         /opt/intel/oneapi/mpi/${impi_2021_version}/lib
setenv          MPI_MAN         /opt/intel/oneapi/mpi/${impi_2021_version}/share/man
setenv          MPI_HOME        /opt/intel/oneapi/mpi/${impi_2021_version}
setenv          FI_PROVIDER     ${IMPI_FI_PROVIDER}
EOF

    ln -s ${MPI_MODULE_FILES_DIRECTORY}/impi_${impi_2021_version} ${MPI_MODULE_FILES_DIRECTORY}/impi-2021

    if [[ $DISTRIBUTION == "almalinux8.10" ]] || [[ $DISTRIBUTION == "rocky8.10" ]] || [[ $DISTRIBUTION == rhel8* ]]; then
        cat << EOF >> ${MPI_MODULE_FILES_DIRECTORY}/impi_${impi_2021_version}
# see https://community.intel.com/t5/Intel-MPI-Library/Suspected-unfixed-Intel-MPI-race-condition-in-collectives/td-p/1693452 for Intel MPI bug
setenv          I_MPI_STARTUP_MODE         pmi_shm
EOF
    fi
fi    



# cleanup downloaded tarballs and other installation files/folders
rm -rf *.tbz *.tar.gz *offline.sh
(
    shopt -s dotglob nullglob
    rm -rf -- */ || true
)
