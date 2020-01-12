#!/bin/bash
source ./lib.bash

# Test installing base-devel if needed.
TestNeedAUR
# shellcheck disable=SC2016
TestNeedAURPackage auracle-git 78e0ab5a1d51705e762b1ca5b409b30b82b897c9 'source=("${source[@]/%/#commit=181e42cb1a780001c2c6fe6cda2f7f1080b249e5}")'

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
TestCreatePackage test-package-base foreign "$(printf pkgbuild=%q "$pkgbuild")" pkg_fn=test-subpackage-1-1-any.pkg.tar.zst
TestAddConfig AddPackage --foreign test-subpackage
unset pkgbuild

TestPhase_Run #################################################################
AconfApply

TestPhase_Check ###############################################################
diff -u <(cat /testfile.txt) <(printf 'File contents')

TestDone ######################################################################
