aconfmgr test suite
===================

aconfmgr is tested very thoroughly. The following checks are done as part of CI for every push:

- The source code is analyzed using [ShellCheck](https://www.shellcheck.net/).
  All warnings are considered a failure, and need to be addressed by source code changes,
  or by adding an [ignore directive](https://github.com/koalaman/shellcheck/wiki/Ignore) when appropriate.

- The test suite is executed in mock and integration mode.
  During this, [bashcov](https://github.com/infertux/bashcov) is used to collect test coverage.

- Coverage results are collated, then uploaded to [Coveralls](https://coveralls.io/github/CyberShadow/aconfmgr).

To run the test suite locally, simply run `make` in the current directory.
This runs all checks except running the test suite in integration mode.

To also run the test suite in integration mode (slower), run `make testsuite-integration`.
The Docker service needs to be running and accessible by the current user.

For details, see:

- [test/GNUmakefile](https://github.com/CyberShadow/aconfmgr/blob/master/test/GNUmakefile),
  the makefile describing the test process.

- [.github/workflows/test.yml](https://github.com/CyberShadow/aconfmgr/blob/master/.github/workflows/test.yml),
  the GitHub Actions workflow file.


Test scripts
------------

Each test case in the test suite is specified in a self-contained test script (`test/t/t-*.sh`).
Test scripts source the test library, which in turn sources aconfmgr source files.
Test cases generally consist of setup, run, and check sections.

For details, see
[t-0_sample.sh](https://github.com/CyberShadow/aconfmgr/blob/master/test/t/t-0_sample.sh),
a sample dummy test case for illustration purposes.


Mock mode
---------

In the "mock" mode of the test suite, the environment is mocked by creating a virtual filesystem and package database.
File operations such as `cp`, `cat`, `stat`, etc. and package management programs (`pacman`) are redefined to work on this virtual filesystem.

This allows running the test suite without `sudo`, containers, or any other prerequisites.

To run a single test in mock mode, simply execute it.

For details, see
[test/t/lib-mocks.bash](https://github.com/CyberShadow/aconfmgr/blob/master/test/t/lib-mocks.bash) and
[test/t/mocks/](https://github.com/CyberShadow/aconfmgr/tree/master/test/t/mocks),
which contain the implementation for mocked commands.


Integration mode
----------------

In the "integration" mode, the test suite is executed inside a Docker container containing a minimal installation of Arch Linux.
The test suite will create the container during execution.

To run a single test in integration mode, run `./t-test_file_name_here.sh -i`.
The Docker service needs to be running and accessible by the current user.

For details, see the [test/docker](https://github.com/CyberShadow/aconfmgr/tree/master/test/docker) directory.

Under CI, the integration tests are split up into a few shards which run in parallel.
For details, see the [print-test-list.sh](https://github.com/CyberShadow/aconfmgr/blob/master/test/print-test-list.sh) script.


AUR integration testing
-----------------------

When running in integration mode, some tests cover integration with AUR or AUR helpers.
For this purpose, a local instance of AUR and all necessary components (aurweb, API, git / ssh access) is created and started inside a Docker container.
The test suite will create the container during execution.

For details, see the [test/docker/aur](https://github.com/CyberShadow/aconfmgr/tree/master/test/docker/aur) directory.


Matrix tests
------------

Matrix tests are tests which generate every possible combination of the relevant thing being tested.
E.g. for filesystem objects, the relevant properties would be the object kind (file / directory / symbolic link), contents, and attributes.
These properties are varied for every location where the file can occur (filesystem, package, or aconfmgr configuration).

Each particular instance of these parameters is identified by a spec, which looks something like `00-2311-1221-0133`.
Each digit represents the value for a particular property.

Because the full test matrix is very large, it is not run as part of CI.
Only particular specs which have been observed to fail previously (regressions) are tested.

For details, see the files `*matrix*.sh` and `m-*.sh` in the test suite.


Dependency pinning
------------------

All dependencies of the test suite are pinned to a known-working version.
This is to ensure that the test suite does not break unexpectedly,
and allows distinguishing whether test failures occur due to changes in aconfmgr or one of the dependencies.

To ensure that aconfmgr and its test suite keeps working with the latest version of its dependencies,
the pinned versions are regularly bumped by [a bot](https://github.com/CyberShadow-Renovate).
If CI execution succeeds with the new dependency version, it is automatically merged into master.

The following dependencies are thus pinned / updated:

- Arch Linux base tarball (used to build Docker containers to run the test suite in integration mode)
- ShellCheck (bash source linter)
- AUR helpers.
