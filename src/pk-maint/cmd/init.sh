#
#! \file    ./src/pk-maint/cmd/init.sh
#! \author  Jiří Kučera, <jkucera AT redhat.com>
#! \stamp   2017-12-29 13:54:32 (UTC+01:00, DST+00:00)
#! \project pkgtools: Tools for Maintaining Fedora Packages
#! \license MIT (see ./LICENSE)
#! \version See ./VERSION
#! \fdesc   Initialize project maintenance directory.
#

require_command pwd
require_command git

function init_usage() {
  echo "$PKM_CMD: $PKM_CMD [options]"
  echo ""
  echo "Initialize a project. This involves the following:"
  echo ""
  echo "  1. create .git"
  echo "  2. create Maintfile"
  echo "  3. create .gitignore"
  echo ""
  echo "Existing files and directories remain untouched; options are"
  echo ""
  eval "echo \"\$${OPTSTORAGE_PREFIX}_helplines\""
  echo ""
}

function init_cmd() {
  local E
  local V
  local T

  OPTVAR_PREFIX='INITOPT_'
  OPTSTORAGE_PREFIX='INIT'

  make_optstorage
  defopt h,? help "print this screen and exit"
  defopt v verbose "${tab_sep}print what has been created"
  defopt - version "${tab_sep}print the version and exit"

  process_args "$@"
  shift $nargs

  [ $INITOPT_HELP -ne 0 ] && { init_usage; exit 0; }
  [ $INITOPT_VERSION -ne 0 ] && { echo $PKM_VERSION; exit 0; }
  V=""
  [ $INITOPT_VERBOSE -ne 0 ] && { V="-v"; }

  # Check if we are in initialized repository:
  T=$(search_upwards "$(pwd)" ".git")
  [ "$T" ] && {
    [ "$V" ] && echo "already initialized"
    exit 0
  }

  # 1. if there is no .git directory, run `git init`:
  if [ -d ".git" ]; then
    [ "$V" ] && echo ".git directory already exists"
  else
    git init; E=$?
    [ $E -ne 0 ] && exit $E
    [ -d ".git" ] || error ".git is not an existing directory and cannot be created"
  fi

  # 2. if there is no Maintfile, create it:
  eval "sh $PKM_PROG new-file $V -r.git -TMaintfile -d\"Project maintenance script.\" Maintfile"; E=$?
  [ $E -ne 0 ] && exit $E

  # 3. if there is no .gitignore, create it:
  eval "sh $PKM_PROG new-file $V -Tplain .gitignore"
}
