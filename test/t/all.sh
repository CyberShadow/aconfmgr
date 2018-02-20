#!/bin/bash
set -eu

cd "$(dirname "$0")"

./t-sample.sh
./t-save.sh
