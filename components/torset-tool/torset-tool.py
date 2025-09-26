import os
import sys
import argparse
from loguru import logger
from pathlib import Path
from pssh.clients.ssh import ParallelSSHClient, SSHClient

def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument('--hosts', type=str, help='Path to host file')
    parser.add_argument('--pkey_path', type=str, help='Path to user private key')
    parser.add_argument('--sharp_cmd_path', type=str, help='Path to sharp_cmd')
    parser.add_argument('--output_dir', type=str, help='Output directory for generated files')
    return parser.parse_args()
       
def run_parallel_cmd(hosts, private_key, cmd):
    try:
        client = ParallelSSHClient(hosts,pkey=f'{private_key}')
        output = client.run_command(cmd)
        client.join(output)
        return output
    except Exception as e:
        raise Exception(f"Error running command: {cmd}: {str(e)}")
        
def run_command(command):
    try:
        os.system(command)
    except Exception as e:
        return str(e)        
                
class TorsetTool:

    output_dir: Path
    guids_file: Path
    guid_to_host_map: dict = {}
    hosts_file: Path
    topo_file: Path
    device_guids_per_switch: list = []
    host_to_torset_map: dict = {}
    torsets: dict = {}
    
    def __init__(self, output_dir: Path, hosts_file: Path, sharp_cmd_path: Path):
        self.hosts_file = hosts_file
        self.sharp_cmd_path = sharp_cmd_path
        self.output_dir = output_dir
        self.guids_file = f"{output_dir}/guids.txt"
        self.topo_file = f"{output_dir}/topology.txt"
       
    def retrieve_guids(self, private_key) -> dict:
        cmd = 'ibstatus | grep mlx5_ib | cut -d" " -f3 | xargs -I% ibstat "%" | grep "Port GUID" | cut -d: -f2'
        with open(self.hosts_file, 'r') as f:
            hosts = [host.strip() for host in f.readlines()]
        output = run_parallel_cmd(hosts, private_key, cmd)
        for host_out in output:
            for guid in host_out.stdout:
                # Querying GUIDs from ibstat will have pattern 0x0099999999999999, but Sharp will return 0x99999999999999
                # - So we need to remove the leading 00 after 0x
                self.guid_to_host_map[guid.replace('0x00', '0x').strip()]=host_out.host
                
    def write_guids_to_file(self):
        with open(self.guids_file, 'w') as f:
            for guid in self.guid_to_host_map.keys():
                f.write(f"{guid}\n")      

    def generate_topo_file(self):
        create_topo_cmd = f"SHARP_SMX_UCX_INTERFACE=mlx5_ib0:1 {self.sharp_cmd_path}/sharp/bin/sharp_cmd topology --ib-dev mlx5_ib0:1  --guids_file {self.guids_file} --topology_file {self.topo_file}"
        run_command(create_topo_cmd)

    def group_guids_per_switch(self) -> list:
        guids_per_switch = []
        with open(self.topo_file, 'r') as f:
            for line in f:
                if 'Nodes=' not in line:
                    continue
                # 'SwitchName=ibsw2 Nodes=0x155dfffd341acb,0x155dfffd341b0b'
                guids_per_switch.append(line.strip().split(' ')[1].split('=')[1])
        return guids_per_switch

    def identify_torsets(self) -> dict:
        host_to_torset_map = {}
        for device_guids_one_switch in self.device_guids_per_switch:
            device_guids = device_guids_one_switch.strip().split(",")
            # increment torset index for each new torset
            torset_index = len(set(host_to_torset_map.values()))
            for guid in device_guids:
                host = self.guid_to_host_map[guid]
                if host in host_to_torset_map:
                    continue
                host_to_torset_map[host] = f"torset-{torset_index:02}"
        return host_to_torset_map

    def group_hosts_by_torset(self) -> dict:
        torsets = {}
        for host, torset in self.host_to_torset_map.items():
            if torset not in torsets:
                torsets[torset] = [host]
            else:
                torsets[torset].append(host)
        return torsets 
        
    def write_hosts_by_torset(self) -> None:
        for torset, hosts in self.torsets.items():
            output_file = f"{self.output_dir}/{torset}_hosts.txt"
            with open(output_file, 'w') as f:
                for host in hosts:
                    f.write(f"{host}\n")        

def main():
    args = parse_args()
    Path(args.output_dir).mkdir(exist_ok=True)
    logger.add(f"{args.output_dir}/torset-tool.log", rotation = "500 MB", enqueue= True, level="INFO")
    torset_tool = TorsetTool(args.output_dir, args.hosts, args.sharp_cmd_path)
    
    logger.info("Running ibstat on hosts to collect InfiniBand device GUIDs")
    guid_to_host_map = torset_tool.retrieve_guids(args.pkey_path)
    logger.info("Finished collecting InfiniBand device GUIDs from hosts")
    torset_tool.write_guids_to_file()
    logger.info(f"Finished writing guids to {torset_tool.guids_file}") 
    torset_tool.generate_topo_file()
    logger.info(f"Topology file generated at {torset_tool.topo_file}")
    torset_tool.device_guids_per_switch =  torset_tool.group_guids_per_switch()
    logger.info("Finished grouping device guids per switch")
    torset_tool.host_to_torset_map = torset_tool.identify_torsets()
    logger.info("Identified torsets for hosts")
    torset_tool.torsets = torset_tool.group_hosts_by_torset()
    logger.info("Finished grouping hosts by torsets")
    torset_tool.write_hosts_by_torset()
    logger.info(f"Hosts grouped by torset are written to files in {torset_tool.output_dir} directory")

if __name__ == '__main__':
    main()