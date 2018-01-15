#!/bin/sh
#
#! \file    ./build/install.sh
#! \author  Jiří Kučera, <jkucera AT redhat.com>
#! \stamp   2017-12-30 17:31:59 (UTC+01:00, DST+00:00)
#! \project pkgtools: Tools for Maintaining Fedora Packages
#! \license MIT (see ./LICENSE)
#! \version See ./VERSION
#! \fdesc   Install project files.
#

script_dir=$(dirname $0)

vars_cfg="$script_dir/../vars.cfg"

last_command=""
last_error=0
last_stderr=""

error() {
  echo "$0: error: $*" >&2
  exit 1
}

guess_dir_mode() {
  case "$1" in
    /bin   | /bin/*   | /usr/bin   | /usr/bin/*   | \
    /lib   | /lib/*   | /usr/lib   | /usr/lib/*   | \
    /lib64 | /lib64/* | /usr/lib64 | /usr/lib64/* | \
    /sbin  | /sbin/*  | /usr/sbin  | /usr/sbin/*)
      mode="555"
      ;;
    /etc | /etc/*)
      mode="644"
      ;;
    /home        | /home/*        | \
    /usr/include | /usr/include/* | \
    /usr/libexec | /usr/libexec/* | \
    /usr/share   | /usr/share/*   | \
    /var         | /var/*)
      mode="755"
      ;;
    *)
      error "you shouldn't install to '$1' directory"
  esac
}

guess_file_mode() {
  case "$1" in
    *.so)
      # shared objects should be executable
      mode="755"
      ;;
    Makefile*)
      # any variation of Makefile should be regular
      mode="644"
      ;;
    /bin/*   | /usr/bin/*   | \
    /lib/*   | /usr/lib/*   | \
    /lib64/* | /usr/lib64/* | \
    /sbin/*  | /usr/sbin/*  | \
    /usr/libexec/*)
      # anything that goes here should be executable
      mode="755"
      ;;
    *.*)
      # any file containing dot that not meets the requirements above should be
      # regular
      mode="644"
      ;;
    *)
      # file without dot in its name is probably executable
      mode="755"
  esac
}

[ -f "$vars_cfg" ] || error "'$vars_cfg' not found; run ./configure first"
. $vars_cfg

try_run() {
  last_command="$*"
  [ $DRY_RUN -eq 0 ] && {
    ("$@") >/dev/null 2>/var/tmp/stderr.$$
    last_error=$?
    last_stderr=$($cat_prog /var/tmp/stderr.$$)
    $rm_prog -f /var/tmp/stderr.$$
  }
}

check=0
dflag=0
mode=""
verbose=$VERBOSE

while [ $# -gt 0 ]; do
  case "$1" in
    --check)
      check=1
      ;;
    -d)
      dflag=1
      ;;
    --help | -h | -\?)
      echo "Usage: $0 [options] SRC DEST"
      echo "       $0 [options] -d DIR"
      echo "       $0 [options] --check FILE"
      echo ""
      echo "Copy SRC to DEST, or make a DIR, or check if FILE is NOT installed. If"
      echo "DRY_RUN environment variable is not 0, no actions are taken and only"
      echo "corresponding command is displayed to the user."
      echo ""
      echo "Options are"
      echo ""
      echo "  --check		check if FILE is not installed; fails if it is"
      echo "  -d			first argument after options is a directory to be created"
      echo "  -h, -?, --help	print this screen and exit"
      echo "  -mOOO			create DEST/DIR with mode OOO"
      echo "  -v			be verbose"
      echo "  --version		print version and exit"
      echo ""
      exit 0
      ;;
    -m*)
      mode=$($expr_prog "$1" : '^-m\([0-7][0-7][0-7]\)$')
      [ -z "$mode" ] && error "ill-formed -m option"
      ;;
    -v)
      verbose=1
      ;;
    --version)
      cat "$script_dir/../VERSION"
      exit 0
      ;;
    *)
      break
  esac
  shift
done

# Handle --check first
[ $check -ne 0 ] && {
  [ -z "$1" ] && error "end of command line reached while looking for ITEM argument"

  case "$1" in
    # slash -> path to file or directory
    */*)
      [ -d "$1" ] && error "'$1' is already installed"
      [ -f "$1" ] && error "'$1' is already installed"
      ;;
    # command
    *)
      command -v "$1" >/dev/null 2>&1 && error "'$1' is already installed"
  esac

  exit 0
}

# Making a directory instead of copying files
[ $dflag -ne 0 ] && {
  [ -z "$1" ] && error "end of command line reached while looking for DIR argument"
  [ -z "$mode" ] && guess_dir_mode "$1"

  [ $verbose -ne 0 ] && echo -n "creating '$1' with mode $mode: "
  [ $DRY_RUN -ne 0 ] && [ $verbose -ne 0 ] && echo "ok"
  try_run $mkdir_prog -p "$1"
  [ $DRY_RUN -ne 0 ] && [ "$last_command" ] && echo "[dry-run]\$ $last_command"
  [ $last_error -ne 0 ] && {
    [ $verbose -ne 0 ] && echo "failed"
    [ "$last_stderr" ] && echo $last_stderr >&2
    exit $last_error
  }
  try_run $chmod_prog $mode "$1"
  [ $DRY_RUN -ne 0 ] && [ "$last_command" ] && echo "[dry-run]\$ $last_command"
  [ $last_error -ne 0 ] && {
    [ $verbose -ne 0 ] && echo "failed"
    [ "$last_stderr" ] && echo $last_stderr >&2
    exit $last_error
  }
  [ $verbose -ne 0 ] && [ $DRY_RUN -eq 0 ] && echo "ok"

  exit 0
}

# Copy file SRC to DEST
[ -z "$1" ] && error "end of command line reached while looking for SRC argument"
[ -z "$2" ] && error "end of command line reached while looking for DEST argument"
[ -z "$mode" ] && guess_file_mode "$2"

[ $verbose -ne 0 ] && echo -n "copying '$1' to '$2' with mode $mode: "
[ $DRY_RUN -ne 0 ] && [ $verbose -ne 0 ] && echo "ok"
try_run $cp_prog "$1" "$2"
[ $DRY_RUN -ne 0 ] && [ "$last_command" ] && echo "[dry-run]\$ $last_command"
[ $last_error -ne 0 ] && {
  [ $verbose -ne 0 ] && echo "failed"
  [ "$last_stderr" ] && echo $last_stderr >&2
  exit $last_error
}
try_run $chmod_prog $mode "$2"
[ $DRY_RUN -ne 0 ] && [ "$last_command" ] && echo "[dry-run]\$ $last_command"
[ $last_error -ne 0 ] && {
  [ $verbose -ne 0 ] && echo "failed"
  [ "$last_stderr" ] && echo $last_stderr >&2
  exit $last_error
}
[ $verbose -ne 0 ] && [ $DRY_RUN -eq 0 ] && echo "ok"

exit 0
