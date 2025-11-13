#
# aconfmgr test suite
#
# Main targets:
# - check - run all checks
# - coverage - create coverage report in tmp/coverage/index.html
# - clean - delete temporary/intermediate files
#
# Other targets:
# - lint - lint source code only
# - testsuite - run test suite only
# - testsuite-integration - run test suite in integration mode
#
# Options:
# - BUILD_BASH=1 - build/use bash and coreutils from source
#                  (useful for testing on old / non-Arch systems)
#

# Common macros

SRC=../aconfmgr $(wildcard ../src/*.bash)
TMP=tmp

# Use bash instead of /bin/sh for all recipes
SHELL = /bin/bash

# Enable pipefail for all recipes so that piped commands propagate failures
.SHELLFLAGS = -e -o pipefail -c

# Entry point targets

check : lint testsuite
ci : check coverage
lint : shellcheck style

# Create temporary directory

$(TMP) :
	mkdir -p $@

# Download shellcheck

SHELLCHECK_VERSION=0.11.0
SHELLCHECK_TAR_SHA512=25df28923d7d89cfdb9fa8aeef762a887f2bd4ebfbcd43ae71068c60e9458d66250b0f8d6fd66b4bc03723e6cdd47983c547e3ab4f3ea2cbc4bc4028842cc7b9
SHELLCHECK_TAR_DIR=shellcheck-v$(SHELLCHECK_VERSION)
SHELLCHECK_TAR_FN=$(SHELLCHECK_TAR_DIR).linux.x86_64.tar.xz
SHELLCHECK_TAR_URL_BASE=https://github.com/koalaman/shellcheck/releases/download/v$(SHELLCHECK_VERSION)/
SHELLCHECK_TAR_URL=$(SHELLCHECK_TAR_URL_BASE)$(SHELLCHECK_TAR_FN)
SHELLCHECK_TAR=$(TMP)/$(SHELLCHECK_TAR_FN)
SHELLCHECK=$(TMP)/$(SHELLCHECK_TAR_DIR)/shellcheck
SHELLCHECK_ARGS=

$(SHELLCHECK_TAR) : | $(TMP)
	curl --fail --location --output $@.tmp $(SHELLCHECK_TAR_URL)
	printf "%s %s\n" $(SHELLCHECK_TAR_SHA512) $@.tmp | sha512sum -c
	mv $@.tmp $@

$(SHELLCHECK) : | $(SHELLCHECK_TAR)
	tar Jxf $(SHELLCHECK_TAR) -C $(TMP) $(SHELLCHECK_TAR_DIR)/shellcheck

# Download multishellcheck

MULTISHELLCHECK_SHA1=b5348a91c7a325c588fc0c6b827b38fcd5be3d64
MULTISHELLCHECK_URL=https://raw.githubusercontent.com/CyberShadow/multishellcheck/$(MULTISHELLCHECK_SHA1)/multishellcheck
MULTISHELLCHECK=$(TMP)/multishellcheck-$(MULTISHELLCHECK_SHA1)
$(MULTISHELLCHECK) : | $(TMP)
	curl --output $@ $(MULTISHELLCHECK_URL)

# Download and build bash (for CI)

BASH_VERSION=4.4.18
BASH_TAR_SHA1=6cf9b3c23930ba8a721fee177d1558e5b7cb6104
BASH_TAR_DIR=bash-$(BASH_VERSION)
BASH_TAR_FN=$(BASH_TAR_DIR).tar.gz
BASH_TAR_URL_BASE=https://ftp.gnu.org/gnu/bash/
BASH_TAR_URL=$(BASH_TAR_URL_BASE)$(BASH_TAR_FN)
BASH_TAR=$(TMP)/$(BASH_TAR_FN)
BASH_BIN_DIR=$(TMP)/bash/bin
BASH_BIN=$(BASH_BIN_DIR)/bash

$(BASH_TAR) : | $(TMP)
	curl --fail --output $@.tmp $(BASH_TAR_URL)
	printf "%s %s\n" $(BASH_TAR_SHA1) $@.tmp | sha1sum -c
	mv $@.tmp $@

$(BASH_BIN) : $(BASH_TAR)
	rm -rf $(TMP)/$(BASH_TAR_DIR)
	tar zxf $(BASH_TAR) -C $(TMP)
	cd $(TMP)/$(BASH_TAR_DIR) && ./configure --prefix=$(realpath $(TMP))/bash
	make -C $(TMP)/$(BASH_TAR_DIR) install

# Download and build coreutils (for CI)

COREUTILS_VERSION=8.29
COREUTILS_TAR_SHA1=63d522f430f0f9fceca71e4b52b414999531915c
COREUTILS_TAR_DIR=coreutils-$(COREUTILS_VERSION)
COREUTILS_TAR_FN=$(COREUTILS_TAR_DIR).tar.xz
COREUTILS_TAR_URL_BASE=https://ftp.gnu.org/gnu/coreutils/
COREUTILS_TAR_URL=$(COREUTILS_TAR_URL_BASE)$(COREUTILS_TAR_FN)
COREUTILS_TAR=$(TMP)/$(COREUTILS_TAR_FN)
COREUTILS_BIN_DIR=$(TMP)/coreutils/bin

$(COREUTILS_TAR) : | $(TMP)
	curl --fail --output $@.tmp $(COREUTILS_TAR_URL)
	printf "%s %s\n" $(COREUTILS_TAR_SHA1) $@.tmp | sha1sum -c
	mv $@.tmp $@

$(COREUTILS_BIN_DIR) : $(COREUTILS_TAR)
	rm -rf $(TMP)/$(COREUTILS_TAR_DIR)
	tar Jxf $(COREUTILS_TAR) -C $(TMP)
	cd $(TMP)/$(COREUTILS_TAR_DIR) && ./configure --prefix=$(realpath $(TMP))/coreutils
	make -C $(TMP)/$(COREUTILS_TAR_DIR) install

# Use built bash/coreutils with BUILD_BASH=1 (currently unused)

ifeq (,$(BUILD_BASH))
 BASH=$(shell command -v bash 2> /dev/null)
 BASH_DEP=
 PATH_PREFIX=
else
 BASH=$(realpath $(BASH_BIN))
 BASH_DEP=$(BASH_BIN) $(COREUTILS_BIN_DIR)
 PATH_PREFIX=$(realpath $(COREUTILS_BIN_DIR)):$(realpath $(BASH_BIN_DIR)):
endif

# ShellCheck rule

SHELLCHECK_OK=$(TMP)/.shellcheck-ok
shellcheck : $(SHELLCHECK_OK)
$(SHELLCHECK_OK) : $(SRC) $(SHELLCHECK) $(MULTISHELLCHECK)
	SHELLCHECK=$(SHELLCHECK) bash $(MULTISHELLCHECK) ../aconfmgr $(SHELLCHECK_ARGS)
	touch "$@"

# Test suite

TESTSUITE_LIB=$(wildcard t/lib*.bash t/mocks/*)
TESTSUITE_TESTS:=$(addprefix t/, $(addsuffix .sh, $(shell ./print-test-list.sh)))
TESTSUITE_TESTS_OK=$(patsubst t/%.sh,tmp/test/%/.ok,$(TESTSUITE_TESTS))
TESTSUITE=$(TESTSUITE_LIB) $(TESTSUITE_TESTS)

tmp/test/%/.ok : t/%.sh $(SRC) $(TESTSUITE_LIB) $(BASH_DEP)
	mkdir -p $(dir $@)
	cd t && PATH=$(PATH_PREFIX)$(PATH) $(BASH) $(<:t/%=%) 2>&1 | tee ../$(dir $@)test.log
	touch "$@"

testsuite : $(TESTSUITE_TESTS_OK)

# Test suite (integration mode)

TESTSUITE_INTEG_TESTS_OK=$(patsubst t/%.sh,tmp/integ/test/%/.ok,$(TESTSUITE_TESTS))

tmp/integ/test/%/.ok : t/%.sh $(SRC) $(TESTSUITE_LIB) docker-image
	mkdir -p $(dir $@)
	docker/run-test.sh $(<:t/%=%) 2>&1 | tee $(dir $@)test.log
	touch "$@"

testsuite-integration : $(TESTSUITE_INTEG_TESTS_OK)

# Coverage

COVERAGE_REPORT=$(TMP)/coverage/index.html
coverage : $(COVERAGE_REPORT)
$(COVERAGE_REPORT) : $(SRC) $(TESTSUITE) $(BASH_DEP) .simplecov
	PATH=$(PATH_PREFIX)$(PATH) bashcov --bash-path $(BASH) --root=.. t/all.sh

# Docker image (integration testing)

ARCH_DATE=2024.12.01
ARCH_TAR_FN=archlinux-bootstrap-$(ARCH_DATE)-x86_64.tar.zst
ARCH_TAR_URL=https://archive.archlinux.org/iso/$(ARCH_DATE)/$(ARCH_TAR_FN)
ARCH_TAR_SHA256=13f3bbdf447c1e67cd812f008e439ec007e84cdd6c9e1f197bb3bba7a0ae6070
ARCH_TAR_DIR=$(TMP)/arch
ARCH_TAR=$(ARCH_TAR_DIR)/$(ARCH_TAR_FN)

$(ARCH_TAR_DIR) : | $(TMP)
	mkdir -p $@

$(ARCH_TAR) : | $(ARCH_TAR_DIR)
	curl --fail --output $@.tmp $(ARCH_TAR_URL)
	printf "%s %s\n" $(ARCH_TAR_SHA256) $@.tmp | sha256sum -c
	mv $@.tmp $@

DOCKER=docker

$(TMP)/.docker-image-ok-arch : $(ARCH_TAR) docker/Dockerfile.arch
	$(DOCKER) build \
		-t aconfmgr-arch \
		-f - \
		--build-arg arch_tar="$(ARCH_TAR_FN)" \
		--build-arg arch_date=$(subst .,/,$(ARCH_DATE)) \
		"$(ARCH_TAR_DIR)" \
		< docker/Dockerfile.arch
	touch "$@"

DOCKER_IMAGE_OK=$(TMP)/.docker-image-ok
$(DOCKER_IMAGE_OK) : $(DOCKER_IMAGE_ARCH_OK) docker/Dockerfile $(wildcard docker/aur/*) ../.dockerignore
	$(DOCKER) build \
		-t aconfmgr \
		-f docker/Dockerfile \
		--build-arg aconfmgr_uid=$(shell id -u) \
		..
	touch "$@"

docker-image : $(DOCKER_IMAGE_OK)

# Style

STYLE_OK=$(TMP)/.style-ok
style : $(STYLE_OK)
$(STYLE_OK) : $(SRC) $(TESTSUITE) lint.sh
	./lint.sh $(SRC) $(TESTSUITE) lint.sh
	touch "$@"

# Clean-up

clean :
	rm -rf $(TMP)

# GNU make directives

.PHONY: check ci lint shellcheck style testsuite testsuite-integration coverage docker-image clean
