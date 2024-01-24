#!/bin/bash
set -ex

# jq is needed to parse the component versions from the requirements.json file
apt-get update
apt-get install -y jq
