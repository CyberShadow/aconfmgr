# aconfmgr: A configuration manager for Arch Linux

`aconfmgr` is a package to track, manage, and restore the configuration of an Arch Linux system.
Its goals are:

- Quickly configure a new system, or restore an existing system according to a saved configuration
- Track temporary/undesired changes to the system's configuration
- Identify obsolete packages and maintain a lean system

`aconfmgr` tracks the list of installed packages (both native and external), as well as changes to configuration files (`/etc/`).
Since the system configuration is described as shell scripts, it is trivially extensible.

![screenshot](https://dump.thecybershadow.net/8172adadc91ceb38588eb22581f485d9/composed.png)

## Table of Contents

* [Usage](#usage)
  * [Installation](#installation)
  * [First run](#first-run)
  * [Maintenance](#maintenance)
  * [Restoring](#restoring)
* [Modus operandi](#modus-operandi)
  * [Packages](#packages)
* [Advanced Usage](#advanced-usage)
  * [Configuration syntax](#configuration-syntax)
  * [Ignoring some changes](#ignoring-some-changes)
    * [Ignoring files](#ignoring-files)
    * [Ignoring packages](#ignoring-packages)
  * [Inlining files](#inlining-files)
    * [Inlining file content entirely](#inlining-file-content-entirely)
    * [Inlining file edits](#inlining-file-edits)
  * [Managing multiple systems](#managing-multiple-systems)
* [Comparisons](#comparisons)
  * [aconfmgr vs. Puppet/Ansible](#aconfmgr-vs-puppetansible)
  * [aconfmgr vs. NixOS](#aconfmgr-vs-nixos)
  * [aconfmgr vs. lostfiles](#aconfmgr-vs-lostfiles)
  * [aconfmgr vs. etckeeper](#aconfmgr-vs-etckeeper)
* [Limitations](#limitations)
* [License](#license)

## Usage

### Installation

Simply clone (or [download](https://github.com/CyberShadow/aconfmgr/archive/master.zip)+unzip) the GitHub repository. `aconfmgr` will install dependencies as needed during execution. [An AUR package is also available](https://aur.archlinux.org/packages/aconfmgr-git/).

### First run

Run `aconfmgr save` to transcribe the system's configuration to the configuration directory. This will create the file `99-unsorted.sh` in the configuration directory, as well as other files describing the system configuration. (The configuration directory will usually be `~/.config/aconfmgr`, or `./config` if running directly from git, or it can be overridden with `-c`.)

On the first run, `aconfmgr` will likely include some files which you may not want to include in your system configuration. These can be temporary or auto-generated files which are not directly owned by a package. To prevent `aconfmgr` from including these files in the configuration, create e.g. `10-ignores.sh` in the configuration directory, with the lines e.g. `IgnorePath '/path/to/file.ext'` or `IgnorePath '/path/to/dir/*'`. (See [ignoring files](#ignoring-files) for details.) Delete everything from the configuration directory except that file and re-run `aconfmgr save` to regenerate a configuration minding these ignore rules.

Once `aconfmgr save` finishes, you should review the contents of `99-unsorted.sh`, and sort it into one or more new files (e.g.: `10-base.sh`, `20-drivers.sh`, `30-gui.sh`, `50-misc.sh` ...). The files should have a `.sh` extension, and use `bash` syntax. I suggest adding a comment for each package describing why installing the package was needed, so it is clear when the package is no longer needed and can be removed.

During this process, you may identify packages or system changes which are no longer needed. Do not sort them into your configuration files - instead, delete the file `99-unsorted.sh`, and run `aconfmgr apply`. This will synchronize the system state against your configuration, thus removing the omitted packages. (You will be given a chance to confirm all changes before they are applied.)

Note: you don't need to run `aconfmgr` via `sudo`. It will elevate as necessary by invoking `sudo` itself.

### Maintenance

The configuration directory should be versioned using a version control system (e.g. Git). Ideally, the file `99-unsorted.sh` should not be versioned - it will only be created when the current configuration does not reflect the current system state, therefore indicating that there are system changes that have not been accounted for.

Periodic maintenance consists of running `aconfmgr save`; if this results in uncommitted changes to the configuration directory, then there are unaccounted system changes. The changes should be reviewed, sorted, documented, committed and pushed.

### Restoring

To restore a system to its earlier state, or to set up a new system, simply make sure the correct configuration is in the configuration directory and run `aconfmgr apply`. You will be able to preview and confirm any actual system changes.

## Modus operandi

The `aconfmgr` script has two subcommands:

- `aconfmgr save` calculates the difference between the current system's configuration and the configuration described by the configuration directory, and writes it back to the configuration directory.
- `aconfmgr apply` applies the difference between the configuration described by the configuration directory and the current system's configuration, installing/removing packages and creating/editing configuration files.

The configuration directory contains shell scripts, initially generated by the `save` subcommand, and then usually edited by the user. Evaluating these scripts will *compile* a system configuration description in the `output` directory. The difference between that directory's contents, and the actual current system configuration, dictates the actions ultimately taken by `aconfmgr`.

`aconfmgr save` will write the difference to the file `99-unsorted.sh` (under the configuration directory) as a series of shell commands which attempt to bring the configuration up to date with the current system. When starting with an empty configuration, this difference will consist of the entire system description. Since the script only appends to that file, it may end up undoing configuration changes done earlier in the scripts (e.g. removing packages from the package list). It is up to the user to refactor the configuration to remove redundancies, document changes, and improve maintainability.

`aconfmgr apply` will apply the differences to the actual system.

The contracts of both commands are that they are mutually idempotent: after a successful invocation of either, invoking either command immediately after will be a no-op.

### Packages

Background: On Arch Linux, every installed package is installed either explicitly, or as a dependency for another package. Packages can also have mandatory (hard) or optional dependencies. You can view this information using `pacman -Qi <package>` ("Install Reason", "Depends On", "Optional Deps").

`aconfmgr` only tracks explicitly-installed packages, ignoring their hard dependencies. Therefore:

- `aconfmgr save` will only save installed packages that are marked as explicitly installed.
- Installed packages that are neither explicitly installed, nor are hard dependencies of other installed packages, are considered prunable orphans and will be removed.
- Packages that are only optional dependencies of other packages must be listed explicitly, otherwise they will be pruned.
- `aconfmgr apply` removes unlisted packages by unpinning them (setting their install reason as "installed as a dependency"), after which it prunes all orphan packages. If the package is still required by another package, it will remain on the system (until it is no longer required); otherwise, it is removed.
- Packages that are installed and explicitly listed in the configuration will have their install reason set to "explicitly installed".

## Advanced Usage

### Configuration syntax

The configuration files use `bash` syntax. The easiest way to learn the syntax is to run `aconfmgr save` and examine its output (`99-unsorted.sh`).

Some simple helper functions are defined in `src/helpers.bash` (sourced automatically). You are encouraged to examine their implementation - their main goal is not so much to provide an API as simply to make the generated configuration terser and more readable. As such, their use is in no way required, and they can be substituted with their underlying implementations.

The list of provided helper functions:

- `AddPackage [--foreign] PACKAGE...` - Adds a package to the list of packages to be installed.
- `RemovePackage [--foreign] PACKAGE...` - Removes an earlier-added package to the list of packages to be installed.
- `IgnorePackage [--foreign] PACKAGE...` - Adds a package to the list of packages to be ignored.
- `CopyFile PATH [MODE [OWNER [GROUP]]]` - Copies a file from the `files` subdirectory to the output.
- `CopyFileTo SRC-PATH DST-PATH [MODE [OWNER [GROUP]]]` - As above, but allows source and output paths to vary.
- `CreateFile PATH [MODE [OWNER [GROUP]]]` - Creates an empty file, to be included in the output. Prints its absolute path to standard output.
- `GetPackageOriginalFile PACKAGE PATH` - Extracts the original file from a package's archive for inclusion in the output. Prints its absolute path to standard output.
- `CreateLink PATH TARGET [OWNER [GROUP]]` - Creates a symbolic link with the specified target.
- `RemoveFile PATH` - Removes an earlier-added file.
- `SetFileProperty PATH TYPE VALUE` - Sets a file property.
- `IgnorePath PATTERN` - Adds the specified pattern to the list of ignored paths.

### Ignoring some changes

#### Ignoring files

Some files will inevitably neither belong to or match any installed packages, nor can be considered part of the system configuration. This can include:

* Temporary / cache / auto-generated / lock / pipe / pid / timestamp / database / backup / log files
* Files managed by third-party package managers, esp. programming languages' package managers (pip, gem, npm)
* Virtual machine disk images

Other files may not be desirable to include in the managed system configuration because they are security-sensitive (e.g. sshd private keys).

To declare a group of files to be ignored by `aconfmgr`, you can use the provided `IgnorePath` function, e.g.:

```bash
IgnorePath '/var/lib/pacman/local/*' # package metadata
IgnorePath '/var/lib/pacman/sync/*.db' # repos
IgnorePath '/var/lib/pacman/sync/*.db.sig' # repo sigs
```

Make sure to quote the pattern argument to prevent globbing at configuration parse time.

#### Ignoring packages

To ignore the presence of some packages on the system, you can use the `IgnorePackage` function:

```bash
IgnorePackage linux-git
```

`aconfmgr save` will not update the configuration based on ignored packages' presence or absence, and `aconfmgr apply` will not install or uninstall them. The packages should also not be present in the configuration's package list, of course. To ignore a foreign package (e.g. a non-AUR foreign package), use the `--foreign` switch (e.g. `IgnorePackage --foreign my-flobulator`).

### Inlining files

In the output generated by `aconfmgr save`, non-empty new or modified files are copied in their entirety to the configuration directory, under the `/files/` subdirectory, accompanied by a `Copyfile` invocation. However, this can sometimes be wasteful or unwieldy if the file consists of a single line, or has one line changed out of a thousand. This section describes some techniques to move the edits into the configuration files entirely.

#### Inlining file content entirely

Instead of copying, the file's can be inlined using a `bash` heredoc, or even an `echo`:

```bash
# Enable Magic SysRq
echo "kernel.sysrq = 1" > "$(CreateFile /etc/sysctl.d/99-sysrq.conf)"

# https://wiki.archlinux.org/index.php/Getty#Have_boot_messages_stay_on_tty1
cat > "$(CreateFile /etc/systemd/system/getty@tty1.service.d/noclear.conf)" <<EOF
[Service]
TTYVTDisallocate=no
EOF
```

#### Inlining file edits

It is also possible to generate an output file that is a modification of the original. For this purpose, the helper function `GetPackageOriginalFile` is provided. The function will extract the indicated file from the archive in pacman's package cache, downloading it first if necessary.

```bash
# Append some options to systemd's system.conf
cat >> "$(GetPackageOriginalFile systemd /etc/systemd/system.conf)" <<EOF
RuntimeWatchdogSec=10min
ShutdownWatchdogSec=10min
DefaultTimeoutStartSec=30s
DefaultTimeoutStopSec=30s
EOF

# Specify locales
f="$(GetPackageOriginalFile glibc /etc/locale.gen)"
sed -i 's/^#\(en_US.UTF-8\)/\1/g' "$f"
sed -i 's/^#\(en_DK.UTF-8\)/\1/g' "$f" # for ISO timestamps
```

The [Augeas](http://augeas.net/) package can assist in editing configuration files:

```bash
AconfNeedProgram augtool augeas n # Install augeas now, if needed
aug() { augtool --root="$output_dir/files" "$@" ; }

# DNS
GetPackageOriginalFile filesystem /etc/resolv.conf > /dev/null
aug set '/files/etc/resolv.conf/nameserver[101]' 127.0.0.1 # dnsmasq
aug set '/files/etc/resolv.conf/nameserver[102]' 8.8.8.8 # Google
aug set '/files/etc/resolv.conf/nameserver[103]' 8.8.4.4 # Google
```

### Managing multiple systems

You can use the same configuration repository to manage multiple sufficiently-similar systems. One way of doing so is e.g. Git branches (having one main branch plus one branch per machine, and periodically merge in changes from the main branch into the machine-specific branches); however, it is simpler to use shell scripting:

```bash
AddPackage coreutils
# ... more common packages ...

if [[ "$HOSTNAME" == "home.example.com" ]]
then
	AddPackage nvidia
	AddPackage nvidia-utils
	# ... more packages only for the home system ...
fi
```

## Comparisons

### aconfmgr vs. Puppet/Ansible

Although `aconfmgr` calls itself a configuration manager, it has a number of core distinctions from the more well-known ones. One big distinction is that `aconfmgr` manages only one system - the one it is running on. It does not depend on any background services or network agents to work.

Another big distinction is the scope, and the direction of the flow of information. To clarify:

- Puppet and Ansible have limited discovery abilities, whereas `aconfmgr` attempts to discover and save the system configuration in its entirety. There is no Puppet/Ansible command that can be run to save a running system's configuration to a file which, when executed, will produce a similarly-configured system; however, this is the goal of `aconfmgr save`.

- Puppet and Ansible manage the system's configuration insofar as it is defined by the configuration file, whereas `aconfmgr` manages the entire system; as such, the absence of an item in the configuration file indicates its absence on the system. This is not true for [Puppet](http://www.puppetcookbook.com/posts/remove-package.html) or [Ansible](http://stackoverflow.com/questions/29914253/remove-package-ansible-playbook), where, to remove a package, one must first push a configuration file that explicitly indicates that the package is to be removed, only after which can all mentions of the package be removed from the configuration file.

### aconfmgr vs. NixOS

There are some similarities between the [NixOS configuration file](https://nixos.org/nixos/manual/) and `aconfmgr`: they both attempt to describe the entire system configuration from a text file, with any changes in the configuration reflecting on the system. However, while `NixOS` forbids directly editing files under its control, `aconfmgr` doesn't. As with Puppet/Ansible, `aconfmgr` differs in that it provides a mechanism to transcribe changes in system state back to the configuration, making it idempotent.

Another difference is that `NixOS` provides a specialized syntax for many common configuration settings of managed software (e.g. allowing syntax such as `boot.loader.grub.device = "/dev/sda";`). `aconfmgr` doesn't provide this directly, though this can be achieved to some extent using tools such as [Augeas](#inlining-file-edits), without also sacrificing the extent of possible configuration to only [the predefined set of available options](https://nixos.org/nixos/manual/options.html).

### aconfmgr vs. lostfiles

[lostfiles](https://github.com/graysky2/lostfiles) is a "simple script that identifies files not owned and not created by any Arch Linux package". `aconfmgr` provides a superset of its functionality, not least the ability to save exclusions to a configuration file.

### aconfmgr vs. etckeeper

[etckeeper](https://joeyh.name/code/etckeeper) allows storing `/etc` in a version control system. `aconfmgr` allows this as well, although it does not directly provide a way to automatically merge configuration files with upstream package versions. This can be done manually, by [inlining file changes](#inlining-files).

## Limitations

- Dependencies where more than one package provides something (e.g. `fcron` and `cronie` provide `cron`) are not tracked, and the desired dependency must be pinned or added to the configuration manually.
- Installing AUR packages that depend on virtual packages (such as `java-environment`) is not currently implemented. The desired dependency can be manually specified in the configuration, or a supported AUR helper can be used instead.
- Changes in file attributes only (not content) are currently not detected.
- Files owned by a package that have been deleted on the system are currently not tracked.
- Empty directories and directory attributes are not tracked.

## License

Copyright (c) 2016 aconfmgr authors.

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
