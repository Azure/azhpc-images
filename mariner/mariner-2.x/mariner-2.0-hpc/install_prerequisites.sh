#!/bin/bash
set -ex

# jq is needed to parse the component versions from the requirements.json file
tdnf install -y jq