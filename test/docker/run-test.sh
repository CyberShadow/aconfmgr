#!/usr/bin/env bash
set -eEuo pipefail
shopt -s lastpipe

# Run specified integration test.
# Invoked from ../GNUmakefile.

cd "$(dirname "$0")"/../t

test=$1

# shellcheck disable=SC2174
mkdir -p -m755 ../tmp/integ  # Integration tmp directory

args=(
	"${DOCKER-docker}" run
	--rm
)

# Add --userns=keep-id for Podman to avoid user namespace permission issues
if [[ "${DOCKER-docker}" == *podman* ]]
then
	args+=(--userns=keep-id)
fi

args+=(
	-v "$PWD/../..:/aconfmgr:ro"
	-v "$PWD/../tmp/integ:/aconfmgr/test/tmp:rw"
	--add-host aur.archlinux.org:127.0.0.1
	--add-host faur.fosskers.ca:127.0.0.1
	-e GITHUB_ACTIONS
	--env 'ACONFMGR_INTEGRATION=1'
	--env 'ACONFMGR_IN_CONTAINER=1'
	--env 'GIT_CEILING_DIRECTORIES=/aconfmgr'
	--user aconfmgr
	--ulimit "nofile=1024:16384"  # https://github.com/moby/moby/issues/45436
	aconfmgr
	/aconfmgr/test/docker/run-test-inner.sh "$test"
) ; "${args[@]}"
