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
$(TESTSUITE_OK) : $(SRC) $(TESTSUITE)
	t/all.sh
	touch "$@"

# Coverage

COVERAGE_REPORT=../coverage/index.html
coverage : $(COVERAGE_REPORT)
$(COVERAGE_REPORT) : $(SRC) $(TESTSUITE) .simplecov
	bashcov --root=.. t/all.sh

.PHONY: test ci shellcheck testsuite coverage
