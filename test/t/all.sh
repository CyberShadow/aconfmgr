#!/bin/bash
set -eu

cd "$(dirname "$0")"

for t in ./t-*.sh
do
	$BASH "$t"
done
