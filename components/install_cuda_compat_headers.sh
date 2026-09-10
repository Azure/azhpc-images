#!/bin/bash
set -ex

source ${UTILS_DIR}/utilities.sh

cuda_metadata=$(get_component_config "cuda")
CUDA_DRIVER_VERSION=$(jq -r '.driver.version' <<< "$cuda_metadata")

if [[ "$DISTRIBUTION" != "ubuntu26.04" || "$SKU" != "V100" || "$CUDA_DRIVER_VERSION" != "12.9" ]]; then
	echo "CUDA compatibility headers are not required for $DISTRIBUTION/$SKU/CUDA $CUDA_DRIVER_VERSION"
	exit 0
fi

CUDA_INCLUDE_DIR=/usr/local/cuda-${CUDA_DRIVER_VERSION}/targets/x86_64-linux/include
CUDA_MATH_HEADER=${CUDA_INCLUDE_DIR}/crt/math_functions.h
CUDA_MATH_HEADER_SHA256=2f2189d1752d862e96122f985484c89e16bd03a485a01e1f114514f738a2ed4f
COMPAT_ROOT=/opt/azurehpc/cuda-${CUDA_DRIVER_VERSION}-glibc-compat
COMPAT_INCLUDE_DIR=${COMPAT_ROOT}/include
COMPAT_PATCH=${COMPONENT_DIR}/patches/cuda-12.9-glibc-2.42-math.patch

# TODO(ubuntu26.04): Remove this CUDA 13.2 compatibility backport when NVIDIA
# publishes a Volta-capable toolkit whose headers support glibc 2.42 and newer.
apt-get install -y patch
echo "${CUDA_MATH_HEADER_SHA256}  ${CUDA_MATH_HEADER}" | sha256sum --check --strict
rm -rf "${COMPAT_ROOT}"
mkdir -p "${COMPAT_INCLUDE_DIR}/crt"

for header in "${CUDA_INCLUDE_DIR}"/*; do
	header_name=$(basename "${header}")
	if [[ "${header_name}" != "crt" ]]; then
		ln -s "${header}" "${COMPAT_INCLUDE_DIR}/${header_name}"
	fi
done

for header in "${CUDA_INCLUDE_DIR}/crt"/*; do
	header_name=$(basename "${header}")
	if [[ "${header_name}" == "math_functions.h" ]]; then
		cp "${header}" "${COMPAT_INCLUDE_DIR}/crt/${header_name}"
	else
		ln -s "${header}" "${COMPAT_INCLUDE_DIR}/crt/${header_name}"
	fi
done

patch --batch --forward --fuzz=0 "${COMPAT_INCLUDE_DIR}/crt/math_functions.h" < "${COMPAT_PATCH}"

cat > /etc/profile.d/cuda-v100-compat.sh <<EOF
CUDA_V100_COMPAT_INCLUDE=${COMPAT_INCLUDE_DIR}
CUDA_V100_NVCC_FLAGS="\${NVCC_PREPEND_FLAGS:-}"
case " \${CUDA_V100_NVCC_FLAGS} " in
    *" -I\${CUDA_V100_COMPAT_INCLUDE} "*) ;;
	*) CUDA_V100_NVCC_FLAGS="-I\${CUDA_V100_COMPAT_INCLUDE}\${CUDA_V100_NVCC_FLAGS:+ \${CUDA_V100_NVCC_FLAGS}}" ;;
esac
case " \${CUDA_V100_NVCC_FLAGS} " in
	*" -ccbin="*|*" -ccbin "*|*" --compiler-bindir="*|*" --compiler-bindir "*) ;;
	*) CUDA_V100_NVCC_FLAGS="-ccbin=/usr/bin/g++-14\${CUDA_V100_NVCC_FLAGS:+ \${CUDA_V100_NVCC_FLAGS}}" ;;
esac
export NVCC_PREPEND_FLAGS="\${CUDA_V100_NVCC_FLAGS}"
unset CUDA_V100_COMPAT_INCLUDE CUDA_V100_NVCC_FLAGS
EOF
chmod 644 /etc/profile.d/cuda-v100-compat.sh

# Verify that the compatibility overlay did not modify CUDA package contents.
dpkg --verify cuda-crt-12-9 cuda-nvcc-12-9