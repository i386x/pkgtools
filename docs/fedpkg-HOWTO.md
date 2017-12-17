# Fedora Packaging Guidelines

Assume you have FAS account, Bugzilla account, and sponsorship.

## Setup your environment

As a user, generate your Kerberos ticket:
```sh
KRB5_TRACE=/dev/stdout kinit your_login@FEDORAPROJECT.ORG
```

**Tip**: `klist -A` displays your tickets.

## Getting a package

All Fedora packages are at https://src.fedoraproject.org/ .

Login to https://src.fedoraproject.org/.

Fork your package's repo.

**Tip**: Prefer Firefox for communication with https://src.fedoraproject.org/.

Clone your package by running `fedpkg clone <package>`.

Change `origin` to be your forked repo:
```sh
git remote set-url origin <ssh_url_to_your_forked_repo>
# <ssh_url_to_your_forked_repo> is at the bottom of your forked repo's main
# page
```

**Tip**: `git remote -v` shows your tracked remote repos.

## Doing a changes

1. Clean all untracked files (if there are any):
```sh
fedpkg clean
```

1. Prepare your package:
```sh
# Run commands in %prep section; this downloads and unpacks source tarball from
# upstream and applies patches:
fedpkg prep
```

1. Make your contributions.

## Useful utilities and tricks

### Some useful utilities
```sh
# ld-linux.so.2 dynamic loader:
dnf install /lib/ld-linux.so.2
```

Debugging:
```sh
# GNU debugger:
gdb
# - load program:
gdb ./<elf_executable>
# - load program with arguments:
gdb --args ./<elf_executable> [arguments]
# - gdb commands:
#       `bt`   - print stack back trace
#       `quit` - exit from gdb

# Start tracing shared libraries:
LD_DEBUG
# - show how shared objects are searched, loaded, and initialized:
LD_DEBUG=libs ./<elf_binary> [arguments]
```
**Tip**: If something is missing (debug information, symbols, ...) `gdb`
provides you a hint or command how to install it.

Shared libraries:
```sh
# Involved files and directories:
/etc/ld.so.conf
/etc/ld.so.conf.d
/etc/ld.so.cache
/etc/ld.so.preload
/usr/lib
/usr/lib64

# Dynamic loaders/linkers:
/lib/ld.so
/lib/ld-linux.so.<N> # <N> is vesrion, i.e. 1, 2, ...
# - configuring:
ldconfig

# Library path:
LD_LIBRARY_PATH
# - run program, add the current directory to the library search path:
LD_LIBRARY_PATH=.:$LD_LIBRARY_PATH ./<elf_binary> [arguments]

# Library preloading:
LD_PRELOAD
# - run program with <lib> preloaded:
LD_PRELOAD=<lib> ./<elf_binary> [arguments]
```
See also http://tldp.org/HOWTO/Program-Library-HOWTO/shared-libraries.html.

**Tip**: If no from the above works, the shared library is probably plugin.
Consult the documentation and/or source code of maintained package how to deal
with it.

ELF/COFF/coredumps analysis:
```sh
# Read ELF binary:
readelf
# - info about used shared libraries:
readelf -d <elf_binary>
ldd <elf_binary>
# - all information:
readelf -a <elf_binary>

# Patch ELF binary:
patchelf
# - set/add R(UN)PATH:
patchelf --set-rpath <rpath> <elf_binary>

# RPATH manipulation:
chrpath
# - change RPATH in <elf_binary> to <new_rpath>:
chrpath -r <new_rpath> <elf_binary>

# See lot of info about ELF/COFF binary:
objdump
# - show all headers:
objdump -x <elf_binary>

# Open the last coredump in gdb:
coredumpctl gdb
```

Performance:
```sh
# Show system resources usage:
top
```
**Chromium tip**: `Shift + Esc` launch the task manager with PID and CPU usage
information per tab.

Tricks:
```sh
# View the content of binary file in hex+ASCII:
hexdump -Cv <file> | less

# Unpack tarball:
gzip -dc <tarball.tar.gz> | tar -xvvof -
bzip2 -dc <tarball.tar.bz2> | tar -xvvof -
```
