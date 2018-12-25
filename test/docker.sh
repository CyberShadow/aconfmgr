#!/bin/bash
set -eu

# This script is run inside a Docker container from .travis.yml.

cd "$(dirname "$0")"

t/all.sh
