#!/bin/bash
source ./lib.bash

# Test installing base-devel if needed.
TestNeedAUR
TestNeedAURPackage cower b81f1903b442d0e631a2958801e36955118ccbc0

TestPhase_Setup ###############################################################

read -r -d '' pkgbuild <<'EOF' || true
pkgbase=test-package-base
pkgname=(test-subpackage)
pkgver=1
pkgrel=1
arch=(any)
source=(files.tar)
md5sums=(SKIP)

package_test-subpackage() {
	tar xf "$srcdir"/files.tar -C "$pkgdir"
}
EOF

TestAddPackageFile test-package-base /testfile.txt 'File contents'
TestCreatePackage test-package-base foreign "$(printf pkgbuild=%q "$pkgbuild")" pkg_fn=test-subpackage-1-1-any.pkg.tar.xz
TestAddConfig AddPackage --foreign test-subpackage
unset pkgbuild

TestPhase_Run #################################################################
AconfApply

TestPhase_Check ###############################################################
diff -u <(cat /testfile.txt) <(printf 'File contents')

TestDone ######################################################################
