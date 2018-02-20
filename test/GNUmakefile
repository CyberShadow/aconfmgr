# Common macros

SRC=../aconfmgr $(wildcard ../src/*.bash)
TMP=tmp

# Default target

test : shellcheck

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

MULTISHELLCHECK=$(TMP)/multishellcheck
MULTISHELLCHECK_SHA1=6775ac8a4441851c4210f2c2fdabe5b02b4ae398
MULTISHELLCHECK_URL=https://raw.githubusercontent.com/CyberShadow/multishellcheck/$(MULTISHELLCHECK_SHA1)/multishellcheck
$(MULTISHELLCHECK) : | $(TMP)
	curl --output $@ $(MULTISHELLCHECK_URL)

# Create temporary directory

$(TMP) :
	mkdir -p $@

# ShellCheck rule

SHELLCHECK_OK=$(TMP)/.shellcheck-ok
shellcheck : $(SHELLCHECK_OK)
$(SHELLCHECK_OK) : $(SRC) $(SHELLCHECK) $(MULTISHELLCHECK)
	PATH=$(PATH):$(TMP) bash $(MULTISHELLCHECK) ../aconfmgr
	touch "$@"

