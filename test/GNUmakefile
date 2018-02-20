# Common macros

SRC=../aconfmgr $(wildcard ../src/*.bash)
TMP=tmp

# Default target

test : shellcheck testsuite
ci : test coverage

# Download shellcheck

SHELLCHECK_VERSION=0.4.6
SHELLCHECK_TAR_SHA1=38e134ec6df457c7a65d2a6eae446ec91a4c6f0c
SHELLCHECK_TAR_DIR=shellcheck-v$(SHELLCHECK_VERSION)
SHELLCHECK_TAR_FN=$(SHELLCHECK_TAR_DIR).linux.x86_64.tar.xz
SHELLCHECK_TAR_URL_BASE=https://shellcheck.storage.googleapis.com/
SHELLCHECK_TAR_URL=$(SHELLCHECK_TAR_URL_BASE)$(SHELLCHECK_TAR_FN)
SHELLCHECK_TAR=$(TMP)/$(SHELLCHECK_TAR_FN)
SHELLCHECK=$(TMP)/$(SHELLCHECK_TAR_DIR)/shellcheck

$(SHELLCHECK_TAR) : | $(TMP)
	curl --fail --output $@.tmp $(SHELLCHECK_TAR_URL)
	printf "%s %s\n" $(SHELLCHECK_TAR_SHA1) $@.tmp | sha1sum -c
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
BASH_BIN=$(TMP)/bash/bin/bash

$(BASH_TAR) : | $(TMP)
	curl --fail --output $@.tmp $(BASH_TAR_URL)
	printf "%s %s\n" $(BASH_TAR_SHA1) $@.tmp | sha1sum -c
	mv $@.tmp $@

$(BASH_BIN) : $(BASH_TAR)
	rm -rf $(TMP)/$(BASH_TAR_DIR)
	tar zxf $(BASH_TAR) -C $(TMP)
	cd $(TMP)/$(BASH_TAR_DIR) && ./configure --prefix=$(realpath $(TMP))/bash
	make -C $(TMP)/$(BASH_TAR_DIR) install

# Use built bash with BUILD_BASH=1 (on Travis CI)

ifeq (,$(BUILD_BASH))
 BASH=$(shell command -v bash 2> /dev/null)
 BASH_DEP=
else
 BASH=$(BASH_BIN)
 BASH_DEP=$(BASH_BIN)
endif

# Create temporary directory

$(TMP) :
	mkdir -p $@

# ShellCheck rule

SHELLCHECK_OK=$(TMP)/.shellcheck-ok
shellcheck : $(SHELLCHECK_OK)
$(SHELLCHECK_OK) : $(SRC) $(SHELLCHECK) $(MULTISHELLCHECK)
	SHELLCHECK=$(SHELLCHECK) bash $(MULTISHELLCHECK) ../aconfmgr
	touch "$@"

# Test suite

TESTSUITE=$(wildcard t/*sh)
TESTSUITE_OK=$(TMP)/.testsuite-ok
testsuite : $(TESTSUITE_OK)
$(TESTSUITE_OK) : $(SRC) $(TESTSUITE) $(BASH_DEP)
	$(BASH) t/all.sh
	touch "$@"

# Coverage

COVERAGE_REPORT=$(TMP)/coverage/index.html
coverage : $(COVERAGE_REPORT)
$(COVERAGE_REPORT) : $(SRC) $(TESTSUITE) $(BASH_DEP) .simplecov
	bashcov --bash-path $(BASH) --root=.. t/all.sh

.PHONY: test ci shellcheck testsuite coverage
