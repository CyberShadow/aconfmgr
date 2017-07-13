# Common macros

SRC=../aconfmgr $(wildcard ../src/*.bash)
TMP=tmp

# Default target

test : shellcheck

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
$(SHELLCHECK_OK) : $(SRC) $(MULTISHELLCHECK)
	bash $(MULTISHELLCHECK) ../aconfmgr
	touch "$@"

