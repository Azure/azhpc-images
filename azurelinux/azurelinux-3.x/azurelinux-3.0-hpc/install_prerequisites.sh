#!/bin/bash
set -ex

# jq is needed to parse the component versions from the versions.json file
tdnf install -y jq
