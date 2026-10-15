#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/lib.bash"

# Overlapping content filters must follow configuration order, not hash order.

TestPhase_Setup ###############################################################

for path in /etc/first/connection /etc/second/connection /etc/third/connection
do
	TestAddFile "$path" $'name=example\ntimestamp=123\n'
done
unset path

TestAddConfig 'function KeepContent() { cat ; }'
TestAddConfig 'function StripTimestamp() { grep -v "^timestamp=" ; }'

TestAddConfig AddFileContentFilter '/etc/first/*' KeepContent
TestAddConfig AddFileContentFilter '/etc/first/connection' StripTimestamp
TestAddConfig 'printf "name=example\n" > "$(CreateFile /etc/first/connection)"'

TestAddConfig AddFileContentFilter '/etc/second/connection' StripTimestamp
TestAddConfig AddFileContentFilter '/etc/second/*' KeepContent
TestAddConfig 'printf "name=example\ntimestamp=123\n" > "$(CreateFile /etc/second/connection)"'

TestAddConfig AddFileContentFilter '/etc/third/connection' KeepContent
TestAddConfig AddFileContentFilter '/etc/third/*' KeepContent
TestAddConfig AddFileContentFilter '/etc/third/connection' StripTimestamp
TestAddConfig 'printf "name=example\n" > "$(CreateFile /etc/third/connection)"'

TestPhase_Run #################################################################
AconfSave

TestPhase_Check ###############################################################

TestExpectConfig <<EOF
EOF

TestDone ######################################################################
