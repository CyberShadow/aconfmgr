#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/lib.bash"

# Test that when several file content filters match a file,
# the most recently added one takes precedence.

TestPhase_Setup ###############################################################

for path in /first/connection /second/connection /third/connection
do
	TestAddFile "$path" $'name=example\ntimestamp=123\n'
done
unset path

TestAddConfig 'function KeepContent() { cat ; }'
TestAddConfig 'function StripTimestamp() { grep -v "^timestamp=" ; }'

TestAddConfig AddFileContentFilter '/first/*' KeepContent
TestAddConfig AddFileContentFilter '/first/connection' StripTimestamp
TestAddConfig 'printf "name=example\n" > "$(CreateFile /first/connection)"'

TestAddConfig AddFileContentFilter '/second/connection' StripTimestamp
TestAddConfig AddFileContentFilter '/second/*' KeepContent
TestAddConfig 'printf "name=example\ntimestamp=123\n" > "$(CreateFile /second/connection)"'

TestAddConfig AddFileContentFilter '/third/connection' KeepContent
TestAddConfig AddFileContentFilter '/third/*' KeepContent
TestAddConfig AddFileContentFilter '/third/connection' StripTimestamp
TestAddConfig 'printf "name=example\n" > "$(CreateFile /third/connection)"'

TestPhase_Run #################################################################
AconfSave

TestPhase_Check ###############################################################

TestExpectConfig <<EOF
EOF

TestDone ######################################################################
