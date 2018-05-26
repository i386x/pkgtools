#
#! \file    ./src/pk-maint/cmd/init.sh
#! \author  Jiří Kučera, <jkucera AT redhat.com>
#! \stamp   2017-12-29 13:54:32 (UTC+01:00, DST+00:00)
#! \project pkgtools: Tools for Maintaining Fedora Packages
#! \license MIT (see ./LICENSE)
#! \version See ./VERSION
#! \fdesc   Initialize project maintenance directory.
#

require_command touch
require_command mkdir
require_command git

function init_usage() {
  echo "$PKM_CMD: $PKM_CMD [options]"
  echo ""
  echo "Initialize a project. This involves the following:"
  echo ""
  echo "  1. create .pk-maint"
  echo "  2. create .git"
  echo "  3. create Maintfile"
  echo "  4. create .gitignore"
  echo ""
  echo "Existing files and directories remain untouched; options are"
  echo ""
  eval "echo \"\$${OPTSTORAGE_PREFIX}_helplines\""
  echo ""
}

function init_cmd() {
  local E
  local G
  local V
  local T

  OPTVAR_PREFIX='INITOPT_'
  OPTSTORAGE_PREFIX='INIT'

  make_optstorage
  defopt - gopkg "${tab_sep}this package is golang package"
  defopt h,? help "print this screen and exit"
  defopt v verbose "${tab_sep}print what has been created"
  defopt - version "${tab_sep}print the version and exit"

  process_args "$@"
  shift $nargs

  [ $INITOPT_HELP -ne 0 ] && { init_usage; exit 0; }
  [ $INITOPT_VERSION -ne 0 ] && { echo $PKM_VERSION; exit 0; }
  V=""
  [ $INITOPT_VERBOSE -ne 0 ] && V="-v"
  E=eval
  [ $PKM_DEBUG -ne 0 ] && { V="-v"; E=echo; }
  G=""
  [ $INITOPT_GOPKG -ne 0 ] && G="gopkg-"

  # Check if we are in initialized repository:
  T=$(search_upwards "$(pwd)" ".${PKM_NAME}")
  [ "$T" ] && {
    [ "$V" ] && echo "already initialized"
    exit 0
  }

  # 1. create .pk-maint directory:
  exists ".${PKM_NAME}" || {
    [ "$V" ] && echo "making .${PKM_NAME} directory"
    [ $PKM_DEBUG -ne 0 ] || mkdir ".${PKM_NAME}"
  }

  # 1.1. create .pk-maint/config:
  exists ".${PKM_NAME}/config" || {
    [ "$V" ] && echo "creating file .${PKM_NAME}/config"
    [ $PKM_DEBUG -ne 0 ] || touch ".${PKM_NAME}/config"
  }

  # 2. if there is no .git directory, run `git init`:
  exists ".git" || { [ $PKM_DEBUG -ne 0 ] || git init; }

  # 3. if there is no Maintfile, create it:
  T=${PWD##*/}
  T=${T%%-maint}
  if [ "$T" ]; then
    XPROJECT="$T"
    XPKG_NAME="$T"
  else
    XPROJECT="???"
    XPKG_NAME=""
  fi
  [[ "$XPROJECT" =~ ^golang-.*$ ]] && G="gopkg-"
  $E "sh $PKM_PROG --init new-file $V -r.git -T${G}Maintfile -d\"Project maintenance script.\" Maintfile XPROJECT=\"$XPROJECT\" XAUTHOR_NAME=\"$(newfile_guess_author_name)\" XAUTHOR_EMAIL=\"$(newfile_guess_author_email)\" XPKG_NAME=\"$XPKG_NAME\""

  # 4. if there is no .gitignore, create it:
  $E "sh $PKM_PROG --init new-file $V -Tpkm-gitignore .gitignore"
}
