#!/bin/sh
#
#! \file    ./build/rm.sh
#! \author  Jiří Kučera, <jkucera AT redhat.com>
#! \stamp   2017-12-31 11:30:50 (UTC+01:00, DST+00:00)
#! \project pkgtools: Tools for Maintaining Fedora Packages
#! \license MIT (see ./LICENSE)
#! \version See ./VERSION
#! \fdesc   Remove files & directories.
#

script_dir=$(dirname $0)

vars_cfg="$script_dir/../vars.cfg"

error() {
  echo "$0: error: $*" 1>&2
  exit 1
}

[ -f "$vars_cfg" ] || error "'$vars_cfg' not found; run ./configure first"
. $vars_cfg

try_run() {
  if [ $DRY_RUN -ne 0 ]; then
    echo "[dry-run]\$ $*"
  else
    echo "Running '$*'"
    eval "$@"
  fi
}

try_remove() {
  local O

  if [ $FORCE_RM -ne 0 ]; then
    O=-f
  else
    O=-i
  fi
  try_run $rm_prog $O "$@"
}

remove_dir_content() {(
  [ -z "$1" ] && { echo "$FUNCNAME: missing name of directory (skipped)"; exit 0; }
  L=$($ls_prog -a1 "$1")
  for x in $L; do
    if [ "$x" ] && [ "$x" != "." ] && [ "$x" != ".." ]; then
      remove "$1/$x"
    fi
  done
)}

remove_dir() {
  try_remove -d "$1"
}

remove_file() {
  try_remove "$1"
}

remove() {
  if [ "$1" = "." ] || [ "$1" = ".." ]; then
    :
  elif [ -d "$1" ]; then
    remove_dir_content "$1"
    remove_dir "$1"
  elif [ -f "$1" ]; then
    remove_file "$1"
  else
    echo "$0: $1 is neither file nor directory (skipped)"
  fi
}

while [ "$*" ]; do
  case "$1" in
    --help | -h | -\?)
      echo "Usage: $0 [options] FILE1 FILE2 ... FILEn"
      echo ""
      echo "Remove FILE#, prompt the user on every FILE#. If FILE# is a directory,"
      echo "recursively remove its content and then remove empty FILE#. Non-existing"
      echo "FILE# is ignored. If FORCE_RM environment variable is distinct from 0,"
      echo "the user is not prompted. If DRY_RUN environment variable is distinct"
      echo "from 0, no actions are taken and only corresponding command is displayed."
      echo ""
      echo "Options are"
      echo ""
      echo "  -h, -?, --help	print this screen and exit"
      echo "  --version		print version and exit"
      echo ""
      exit 0
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

for F; do
  remove "$F"
done

exit 0
