# HPC Torset Tool

A tool to categorize hosts by ToRsets on a SHARP-enabled cluster to facilitate topology aware placement of jobs.

## Install

Prepare a venv:

```bash
python3 -m venv torset-env
source torset-env/bin/activate
```

```bash
pip install -r requirements.txt
```

## Usage

```bash
 python3 torset-tool.py --hosts <path-to-host-file> --pkey_path  <path-to-ssh-private-key>  --sharp_cmd_path <path-to-sharp-cmd> --output_dir  <path-to-output-dir>
```

### Outputs

This will create a number of files in the <output> directory:

- guids.txt: A file with the InfiniBand device Port GUIDs from every host
- topology.txt: A file with the InfiniBand fabric topology output from `sharp_cmd`
- torset-NN_hosts.txt: A set of files with the hosts belonging to each torset.
