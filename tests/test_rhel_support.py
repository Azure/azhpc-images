import json
import os
import pathlib
import subprocess
import tempfile
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[1]
PREREQUISITES = ROOT / "packer/scripts/prerequisites.sh"


class RhelPrerequisitesTests(unittest.TestCase):
    def run_lvm(self, overrides=""):
        script = f"""
set -euo pipefail
source <(sed -n '/^configure_rhel_lvm()/,/^}}/p' '{PREREQUISITES}')
findmnt() {{ echo xfs; }}
lvs() {{ echo 1073741824.00; }}
vgs() {{ echo 100; }}
lvextend() {{ echo "lvextend $*"; }}
xfs_growfs() {{ echo "xfs_growfs $*"; }}
df() {{ :; }}
{overrides}
configure_rhel_lvm
"""
        return subprocess.run(["bash", "-c", script], text=True, capture_output=True)

    def test_grows_volumes_then_filesystems(self):
        result = self.run_lvm()
        self.assertEqual(result.returncode, 0, result.stderr)
        expected = [
            f"lvextend -L {size * 1024**3}B /dev/rootvg/{volume}"
            for volume, size in [("homelv", 10), ("tmplv", 11), ("rootlv", 14), ("varlv", 12)]
        ]
        expected.append("lvextend -l +100%FREE /dev/rootvg/usrlv")
        expected.extend(
            f"xfs_growfs /dev/rootvg/{volume}"
            for volume in ["homelv", "tmplv", "rootlv", "varlv", "usrlv"]
        )
        self.assertEqual(result.stdout.splitlines(), expected)

    def test_already_grown_volumes_are_not_shrunk(self):
        result = self.run_lvm("lvs() { echo 21474836480.00; }; vgs() { echo 0; }")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn("lvextend", result.stdout)
        self.assertEqual(result.stdout.count("xfs_growfs"), 5)

    def test_allocation_failure_is_fatal(self):
        result = self.run_lvm("lvextend() { return 5; }")
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn("xfs_growfs", result.stdout)

    def test_rejects_unexpected_filesystem_before_resizing(self):
        result = self.run_lvm("findmnt() { echo ext4; }")
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn("lvextend", result.stdout)

    def test_filesystem_failure_is_fatal(self):
        result = self.run_lvm("xfs_growfs() { return 1; }")
        self.assertNotEqual(result.returncode, 0)


class RhelRepositoryTests(unittest.TestCase):
    def lookup(self, repository_kind, output, status=0):
        script = f"""
source '{ROOT / 'utils/utilities.sh'}'
dnf() {{ printf '%s\\n' "$REPOSITORY_OUTPUT"; return {status}; }}
get_rhel_rhui_repo '{repository_kind}'
"""
        return subprocess.run(
            ["bash", "-c", script], text=True, capture_output=True,
            env={**os.environ, "REPOSITORY_OUTPUT": output},
        )

    def test_finds_rhel8_and_rhel9_repositories(self):
        for major in (8, 9):
            for kind, name in (
                ("baseos", f"rhel-{major}-for-x86_64-baseos-rhui-rpms"),
                ("codeready-builder", f"codeready-builder-for-rhel-{major}-x86_64-rhui-rpms"),
            ):
                with self.subTest(major=major, kind=kind):
                    output = f"repo id repo name status\n{name} RHEL disabled\n{name}-debug RHEL disabled\n{name}-source RHEL disabled\n{name}-eus RHEL disabled"
                    result = self.lookup(kind, output)
                    self.assertEqual(result.returncode, 0, result.stderr)
                    self.assertEqual(result.stdout.strip(), name)

    def test_missing_or_ambiguous_repository_fails(self):
        for output in ("baseos Alma enabled", "rhui-baseos-first enabled\nrhui-baseos-second enabled"):
            result = self.lookup("baseos", output)
            self.assertNotEqual(result.returncode, 0)

    def test_dnf_failure_propagates(self):
        result = self.lookup("baseos", "rhui-baseos enabled", status=4)
        self.assertEqual(result.returncode, 4)


class RhelInstallerTests(unittest.TestCase):
    stages = """
install_utils install_doca install_nvidiagpudriver install_pmix install_mpis
install_lustre_client install_mpifileutils install_nccl install_docker install_dcgm
install_amd_libs install_intel_libs hpc-tuning install_waagent install_hpcdiag
install_aznfs install_monitoring_tools install_azure_persistent_rdma_naming
copy_test_file install_health_checks write_kernel_os_version install_azsecpack_prereqs
disable_cloudinit setup_sku_customizations trivy_scan network-config clear_history
""".split()

    def run_installer(self, distro, arguments, failure=""):
        with tempfile.TemporaryDirectory() as directory:
            for stage in self.stages:
                stub = pathlib.Path(directory) / f"{stage}.sh"
                stub.write_text('''#!/bin/bash
printf '%s\\n' "${0##*/} $GPU $SKU $*"
if [[ "${0##*/}" == "$FAIL_COMPONENT.sh" ]]; then exit 42; fi
''')
                stub.chmod(0o755)
            launcher = '''
source() {
    [[ "$1" == ../../utils/set_properties.sh ]] || exit 99
    export COMPONENT_DIR="$PWD" UTILS_DIR="$PWD"
}
rm() { :; }
export -f source rm
bash "$@"
'''
            return subprocess.run(
                ["bash", "-c", launcher, "test", str(ROOT / "distros" / distro / "install.sh"), *arguments],
                cwd=directory, text=True, capture_output=True,
                env={**os.environ, "FAIL_COMPONENT": failure},
            )

    def test_installer_order_and_arguments(self):
        for distro in ("rhel8.10", "rhel9.x"):
            for sku in ("A100", "V100"):
                with self.subTest(distro=distro, sku=sku):
                    result = self.run_installer(distro, ["NVIDIA", sku])
                    self.assertEqual(result.returncode, 0, result.stderr)
                    expected = []
                    for stage in self.stages:
                        argument = sku if stage == "install_nvidiagpudriver" else "NVIDIA" if stage == "install_health_checks" else ""
                        expected.append(f"{stage}.sh NVIDIA {sku} {argument}")
                    self.assertEqual(result.stdout.splitlines(), expected)

    def test_rejects_missing_arguments_and_unsupported_gpu(self):
        for distro in ("rhel8.10", "rhel9.x"):
            for arguments in ([], ["NVIDIA"], ["AMD", "MI300X"]):
                with self.subTest(distro=distro, arguments=arguments):
                    result = self.run_installer(distro, arguments)
                    self.assertNotEqual(result.returncode, 0)
                    self.assertNotIn("install_utils.sh", result.stdout)

    def test_stops_when_local_helper_or_component_fails(self):
        for distro in ("rhel8.10", "rhel9.x"):
            for failure in ("install_utils", "install_doca", "network-config"):
                with self.subTest(distro=distro, failure=failure):
                    result = self.run_installer(distro, ["NVIDIA", "A100"], failure)
                    self.assertEqual(result.returncode, 42, result.stderr)
                    executed = [line.split()[0] for line in result.stdout.splitlines()]
                    self.assertEqual(executed, [f"{stage}.sh" for stage in self.stages[:self.stages.index(failure) + 1]])


class RhelConfigurationTests(unittest.TestCase):
    def test_component_lookup_for_both_releases_and_gpu_variants(self):
        components = ["doca", "hpcx", "mvapich", "nvidia", "cuda", "gdrcopy", "lustre", "pmix", "ompi"]
        for distribution in ("rhel8.10", "rhel9.8"):
            for sku in ("A100", "V100"):
                with self.subTest(distribution=distribution, sku=sku):
                    script = f"""
set -euo pipefail
source '{ROOT / 'utils/utilities.sh'}'
COMPONENT_VERSIONS=$(jq -c . '{ROOT / 'versions.json'}')
for component in {' '.join(components)}; do
    get_component_config "$component" | jq -c .
done
"""
                    result = subprocess.run(
                        ["bash", "-c", script], text=True, capture_output=True,
                        env={**os.environ, "DISTRIBUTION": distribution, "SKU": sku,
                             "GPU": "NVIDIA", "ARCHITECTURE": "x86_64",
                             "TARGET_NODE_TYPE": "azure_vm_regular"},
                    )
                    self.assertEqual(result.returncode, 0, result.stderr)
                    configs = dict(zip(components, map(json.loads, result.stdout.splitlines())))
                    self.assertEqual(len(configs), len(components))
                    for component, config in configs.items():
                        self.assertIsInstance(config, dict, component)
                        self.assertTrue(config, component)
                    self.assertEqual(configs["cuda"]["driver"]["distribution"], distribution.split(".")[0])
                    self.assertEqual(configs["cuda"]["driver"]["version"], "12.9" if sku == "V100" else "13.0")

    def test_image_test_matrices_are_populated(self):
        matrix = json.loads((ROOT / "tests/test-matrix_NVIDIA.json").read_text())
        for distribution in ("rhel8.10", "rhel9.8"):
            selected = matrix[distribution]["azure_vm_regular"]["common"]
            self.assertIn("check_lustre", selected["components"])
            self.assertIn("check_cuda", selected["components"])
            self.assertIn("check_azure_persistent_rdma_naming", selected["services"])


if __name__ == "__main__":
    unittest.main()