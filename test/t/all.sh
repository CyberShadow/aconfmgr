#!/bin/bash
set -eu

cd "$(dirname "$0")"

$BASH ./t-sample.sh
$BASH ./t-save.sh
