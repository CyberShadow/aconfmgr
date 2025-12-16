#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/lib.bash"

# Test AUR functionality using yaourt.

TestNeedAUR
TestNeedAURPackage yaourt edf3615e311b6065b9eee29c9699ff6ed0f232b9
TestNeedAURPackage package-query 6b57e7497422c41c362b92a5c47e9b7a4a30746c
AconfMakePkg yaourt
TestAddConfig AddPackage --foreign yaourt
TestAURHelper yaourt '' false
TestDone
