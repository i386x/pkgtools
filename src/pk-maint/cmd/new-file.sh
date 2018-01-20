#
#! \file    ./src/pk-maint/cmd/new-file.sh
#! \author  Jiří Kučera, <jkucera AT redhat.com>
#! \stamp   2018-01-04 16:50:09 (UTC+01:00, DST+00:00)
#! \project pkgtools: Tools for Maintaining Fedora Packages
#! \license MIT (see ./LICENSE)
#! \version See ./VERSION
#! \fdesc   Create a new file.
#

require_command touch
require_command stat

function newfile_usage() {
  echo "$PKM_CMD: $PKM_CMD [options] FILE [VAR=VALUE args]"
  echo ""
  echo "Create a new source FILE according to chosen or guessed template;"
  echo "options are"
  echo ""
  eval "echo \"\$${OPTSTORAGE_PREFIX}_helplines\""
  echo ""
}

function newfile_guess_template() {
  local T

  newfile_at_guess_template_begin T "$1"
  if [ "$T" ]; then
    echo "$T"
  else
    case "$1" in
      *.asm)
        T="ASM"
        ;;
      *.c)
        T="C"
        ;;
      *.h)
        T="H"
        ;;
      Makefile | *.mk )
        T="MAKEFILE"
        ;;
      Maintfile)
        T="MAINTFILE"
        ;;
      [pP][lL][aA][iI][nN] | [eE][mM][pP][tT][yY])
        T="PLAIN"
        ;;
      *)
        newfile_on_guess_template_fail T "$1"
    esac
    echo "$T"
  fi
}

function newfile_cmd() {
  local F
  local V
  local R
  local E

  OPTVAR_PREFIX='NEWFILEOPT_'
  OPTSTORAGE_PREFIX='NEWFILE'

  make_optstorage
  kvopt d fdesc "set file description" "" STR
  defopt h,? help "print this screen and exit"
  kvopt r root "file or directory name that determines the project root" ".${PKM_NAME}" FILE
  kvopt T template "force the template, don't guess it" "" NAME
  defopt - version "${tab_sep}print the version and exit"
  defopt v verbose "${tab_sep}don't be quite"

  process_args "$@"
  shift $nargs

  [ $NEWFILEOPT_HELP -ne 0 ] && { newfile_usage; exit 0; }
  [ $NEWFILEOPT_VERSION -ne 0 ] && { echo $PKM_VERSION; exit 0; }
  [ -z "$1" ] && error "missing FILE"
  F="$1"
  shift
  V=$NEWFILEOPT_VERBOSE
  R="$NEWFILEOPT_ROOT"

  # Test if file was already created:
  [ -f "$F" ] && {
    [ $V -ne 0 ] && echo "File '$F' already exists."
    exit 0
  }
  [ -d "$F" ] && error "'$F' is an existing directory."

  # What will be the initial content of created file?
  T="$NEWFILEOPT_TEMPLATE"
  [ -z "$T" ] && {
    T=$(newfile_guess_template "$F")
  }
  [ -z "$T" ] && {
    [ $V -ne 0 ] && echo "Template for '$F' is not set, '$F' will be created as plain."
    T="PLAIN"
  }
  T=$(echo "$T" | tr 'a-z-' 'A-Z_')

  # The rest of options should be in a VAR=VALUE form:
  for P; do
    case "$P" in
      *=*)
        expr "$P" : '^[a-zA-Z_][a-zA-Z0-9_]*=.*$' >/dev/null 2>&1 \
        || error "ill-formed VAR=VALUE option '$P'"
        ;;
      *)
        error "ill-formed VAR=VALUE option '$P'"
    esac
  done

  # In a subsehll:
  (
    # 1. try create a file (we need this because the stamp):
    touch "$F"; E=$?
    [ $E -ne 0 ] && exit $E
    # 2. load new-file configuration:
    [ "${ProjectConfig[$PKM_CMD]}" ] && {
      eval "${ProjectConfig[$PKM_CMD]}"; E=$?
      [ $E -ne 0 ] && exit $E
    }
    # 3. write the template to created file:
    eval_template "NEWFILE_${T}_TEMPLATE" "$@" > "$F"
  )
  E=$?

  [ $V -ne 0 ] && [ $E -eq 0 ] && {
    T=$(stat -c%A "$F")
    echo "File '$F' was successfully created with rights '$T'."
  }

  exit $E
}
