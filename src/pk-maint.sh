#!/bin/sh
#
#! \file    ./src/pk-maint.sh
#! \author  Jiří Kučera, <jkucera AT redhat.com>
#! \stamp   2017-12-18 00:22:17 (UTC+01:00, DST+00:00)
#! \project pkgtools: Tools for Maintaining Fedora Packages
#! \license MIT (see ./LICENSE)
#! \version See ../VERSION
#! \fdesc   Main script.
#

PKM_NAME="$0"
PKM_NAME="${PKM_NAME##*/}"
PKM_NAME="${PKM_NAME%.*}"
export PKM_NAME

PKM_CFGDIR='@CFG_DIR@'
case "$PKM_CFGDIR" in
  @*@) PKM_CFGDIR=$(dirname $0) ;;
esac
export PKM_CFGDIR

PKM_DATADIR='@DATA_DIR@'
case "$PKM_DATADIR" in
  @*@) PKM_DATADIR=$(dirname $0) ;;
esac
export PKM_DATADIR

nl_sep='
'
tab_sep='	'
export nl_sep tab_sep

PKM_CMD=""
export PKM_CMD

##
# error $1
#
#   $1 - error message
#
# Print $1 to stderr and exit with exit code 1.
function error() {
  local T

  if [ "$PKM_CMD" ]; then
    T=" $PKM_CMD"
  else
    T=""
  fi
  echo "${PKM_NAME}$T: ERROR: $*" 1>&2
  exit 1
}

##
# warning $1
#
#   $1 - warning message
#
# Print $1 to stderr.
function warning() {
  local T

  if [ "$PKM_CMD" ]; then
    T=" $PKM_CMD"
  else
    T=""
  fi
  echo "${PKM_NAME}$T: WARNING: $*" 1>&2
}

##
# inform $1
#
#   $1 - info message
#
# Print $1 to stdout.
function inform() {
  local T

  if [ "$PKM_CMD" ]; then
    T=" $PKM_CMD"
  else
    T=""
  fi
  echo "${PKM_NAME}$T: $*"
}

##
# str_exclude $1 $2
#
#   $1 - source string
#   $2 - chars to be deleted
#
# Remove all occurrences of $2 from $1 and return the result.
function str_exclude() {
  echo $1 | tr -d "$2"
}

##
# str_commonchars $1 $2
#
#   $1, $2 - strings
#
# Return set of chars as a string that occurrs simultaneously in $1 and $2.
# The order of appearance of these chars in the result is given by $1 and there
# can be also duplicities.
function str_commonchars() {
  local T
  local U

  T=$(str_exclude "$1" "$2")
  U=$(str_exclude "$2" "$1")
  str_exclude "$1" "$T$U"
}

##
# str_chr $1 $2
#
#   $1 - string
#   $2 - chars
#
# Set $? to 0 if at least one char from $2 is alse included in $1.
# Otherwise, set $? to 1.
function str_chr() {
  local T

  T=$(str_exclude "$1" "$2")
  if [ "$T" = "$1" ]; then
    false
  else
    true
  fi
}

##
# str_contains $1 $2
#
#   $1 - string
#   $2 - chars
#
# Set $? to 0 if $1 contains all chars from $2. Otherwise, set $? to 1.
function str_contains() {
  local T

  T=$(str_commonchars "$1" "$2")
  T=$(str_exclude "$2" "$T")
  if [ "$T" ]; then
    false
  else
    true
  fi
}

##
# str_indexof $1 $2
#
#   $1 - string
#   $2 - chars
#
# Return a position (counted from 1) of the first occurrence of char from $1
# that is also contained in $2. 0 means no containment.
function str_indexof() {
  expr index "$1" "$2"
}

##
# str_firstn $1 $2
#
#   $1 - string
#   $2 - number of chars
#
# Return the first $2 chars from $1.
function str_firstn() {
  echo $1 | head -c $2
}

##
# str_cutn $1 $2
#
#   $1 - string
#   $2 - number of chars
#
# Cut the first $2 characters from $1 and return the rest.
function str_cutn() {
  echo $1 | cut -c $(($2 + 1))-
}

##
# find_command $1
#
#   $1 - command name
#
# Find $1 and return its absolute path. Empty path means that $1 is not
# installed.
function find_command() {
  command -v $1 > /dev/null 2>&1 && command -v $1
}

##
# require_command $1
#
#   $1 - command name
#
# Exit with error if $1 is not installed on the host system.
function require_command() {
  if [ -z "$(find_command $1)" ]; then
    error "$1 command is required"
  fi
}

##
# setvar $1 $2
#
#   $1 - var name
#   $2 - value
#
# Assign $2 to $1. This also defines $1.
function setvar() {
  eval "$1=\"$2\""
  export $1
}

##
# TODO
unpack() {
  :
}

require_command cat
require_command head
require_command cut
require_command tr
require_command expr
require_command mkdir
require_command ls
require_command tar
require_command gzip
require_command bzip2

PKM_VERSION='@VERSION@'
case "$PKM_VERSION" in
  @*@) PKM_VERSION=$(cat ../VERSION)
esac
export PKM_VERSION

if [ -f "${PKM_CFGDIR}/${PKM_NAME}/${PKM_NAME}rc" ]; then
  source "${PKM_CFGDIR}/${PKM_NAME}/${PKM_NAME}rc"
fi
if [ -f "~/.${PKM_NAME}rc" ]; then
  source "~/.${PKM_NAME}rc"
fi

OPTVAR_PREFIX='OPT_'
OPTSTORAGE_PREFIX=$(echo $PKM_NAME | tr 'a-z-' 'A-Z_')
export OPTVAR_PREFIX OPTSTORAGE_PREFIX

##
# make_optstorage
#
# Make a room for the options definitions.
function make_optstorage() {
  unset ${OPTSTORAGE_PREFIX}_long_opts_map
  unset ${OPTSTORAGE_PREFIX}_short_opts_map
  unset ${OPTSTORAGE_PREFIX}_long_kvopts_map
  unset ${OPTSTORAGE_PREFIX}_short_kvopts_map
  eval "declare -gA ${OPTSTORAGE_PREFIX}_long_opts_map"
  eval "declare -gA ${OPTSTORAGE_PREFIX}_short_opts_map"
  eval "declare -gA ${OPTSTORAGE_PREFIX}_long_kvopts_map"
  eval "declare -gA ${OPTSTORAGE_PREFIX}_short_kvopts_map"
  eval "${OPTSTORAGE_PREFIX}_helplines=\"\""
}

make_optstorage

##
# mkhelpline $1 $2 $3 $4
#
#   $1 - CSV list of option short names, or `-'
#   $2 - option name
#   $3 - option description
#   $4 - value suffix
#
# Make and return a line of the form
#
#   -s1, -s2, ..., -sN, --$2$4 <-- tab space --> $3
#
# where s1, s2, ..., sN are from $1. If $1 is `-', then s1 to sN are omitted.
function mkhelpline() {
  local D
  local T

  if [ "$1" = "-" ]; then
    # Flags are unused
    echo "  --$2$4${tab_sep}$3"
  else
    # Flags are present
    D="  "
    T=$(echo $1 | tr ',' ' ')
    for x in $T; do
      D="${D}-$x, "
    done
    echo "${D}--$2$4${tab_sep}$3"
  fi
}

##
# add_to_helplines $1
#
#   $1 - help line
#
# Add $1 to help screen.
function add_to_helplines() {
  local T

  eval "T=\"\$${OPTSTORAGE_PREFIX}_helplines\""
  if [ "$T" ]; then
    eval "${OPTSTORAGE_PREFIX}_helplines=\"\$${OPTSTORAGE_PREFIX}_helplines\${nl_sep}\$1\""
  else
    eval "${OPTSTORAGE_PREFIX}_helplines=\"\$1\""
  fi
}

##
# assert_longopt_undefined $1
#
#   $1 - otpion name
#
# Exit with error if $1 was already defined.
function assert_longopt_undefined() {
  local T
  local U

  eval "T=\"\${${OPTSTORAGE_PREFIX}_long_opts_map[\$1]}\""
  eval "U=\"\${${OPTSTORAGE_PREFIX}_long_kvopts_map[\$1]}\""

  if [ "$T" ] || [ "$U" ]; then
    error "option --$1 was already defined"
  fi
}

##
# assert_shortopt_undefined $1
#
#   $1 - CSV list of option short names
#
# Exit with error if at least one option from $1 is already defined.
function assert_shortopt_undefined() {
  local T
  local U

  for o in $(echo $1 | tr ',' ' '); do
    eval "T=\"\${${OPTSTORAGE_PREFIX}_short_opts_map[\$o]}\""
    eval "U=\"\${${OPTSTORAGE_PREFIX}_short_kvopts_map[\$o]}\""
    if [ "$T" ] || [ "$U" ]; then
      error "flag -$o was already defined"
    fi
  done
}

##
# rawdefopt $1 $2 $3 $4 $5 $6
#
#   $1 - CSV list of option short names, or `-'
#   $2 - option name
#   $3 - option description
#   $4 - `+' if this option is enabled by default, `-' if it is diabled; if
#        `+' or `-' are enclosed between `()', the enabled/disabled note is not
#        displayed in help line
#   $5 - `+' if this option is enabling, `-' for disabling
#   $6 - associated variable name (without $OPTVAR_PREFIX) or `-' if the name
#        should be determined automatically
#
# Define a flag-like option. If $1 is `-', short forms are not used. Also
# define a variable with a name
#
#   $6 (all letters capitalized, `-' changed to `_'), if $6 is not `-', or
#   $2 (all letters capitalized, `-' changed to `_') otherwise
#
# which is prefixed by $OPTVAR_PREFIX. Such a variable is initially set to 1 if
# $4 is `+' or `(+)'; otherwise, it is set to 0.
function rawdefopt() {
  local T

  assert_longopt_undefined "$2"
  assert_shortopt_undefined "$1"

  if [ "$4" = "+" ]; then
    T=" (enabled by default)"
  elif [ "$4" = "-" ]; then
    T=" (disabled by default)"
  else
    T=""
  fi
  T=$(mkhelpline "$1" "$2" "$3$T" "")
  add_to_helplines "$T"

  if [ "$6" = "-" ]; then
    T=$(echo $2 | tr 'a-z-' 'A-Z_')
  else
    T=$(echo $6 | tr 'a-z-' 'A-Z_')
  fi

  if [ "$4" = "+" ] || [ "$4" = "(+)" ]; then
    setvar ${OPTVAR_PREFIX}$T 1
  else # "-" || "(-)"
    setvar ${OPTVAR_PREFIX}$T 0
  fi

  if [ "$5" = "+" ]; then
    eval "${OPTSTORAGE_PREFIX}_long_opts_map[\$2]=\"setvar ${OPTVAR_PREFIX}\$T 1\""
  else
    eval "${OPTSTORAGE_PREFIX}_long_opts_map[\$2]=\"setvar ${OPTVAR_PREFIX}\$T 0\""
  fi

  if [ ! "$1" = "-" ]; then
    for x in $(echo $1 | tr ',' ' '); do
      eval "${OPTSTORAGE_PREFIX}_short_opts_map[\$x]=\"\$2\""
    done
  fi
}

##
# rawdefkvopt $1 $2 $3 $4 $5
#
#   $1 - CSV list of option short names, or `-'
#   $2 - option name
#   $3 - option description
#   $4 - option default value
#   $5 - name of value type
#
# Define a key-value option. If $1 is `-', short forms are not used. Also
# define a variable named $2 (with all letters capitalized and `-' changed to
# `_') and prefixed by $OPTVAR_PREFIX with $4 as its default value.
function rawdefkvopt() {
  local T
  local U

  assert_longopt_undefined "$2"
  assert_shortopt_undefined "$1"

  if [ "$5" ]; then
    T="=$5"
  else
    T=""
  fi
  if [ "$4" ]; then
    U="$3 (default value is \"$4\")"
  else
    U="$3"
  fi
  T=$(mkhelpline "$1" "$2" "$U" "$T")
  add_to_helplines "$T"

  T=$(echo $2 | tr 'a-z-' 'A-Z_')

  setvar ${OPTVAR_PREFIX}$T "$4"

  eval "${OPTSTORAGE_PREFIX}_long_kvopts_map[\$2]=\"\$T\""

  if [ ! "$1" = "-" ]; then
    for x in $(echo $1 | tr ',' ' '); do
      eval "${OPTSTORAGE_PREFIX}_short_kvopts_map[\$x]=\"\$T\""
    done
  fi
}

##
# defopt $1 $2 $3
#
#   $1, $2, $3 - see `rawdefopt'
#
# Shorthand for `rawdefopt $1 $2 $3 - + -'.
function defopt() {
  rawdefopt "$1" "$2" "$3" - + -
}

##
# noopt $1 $2 $3
#
#   $1, $2, $3 - see `rawdefopt'
#
# Shorthand for `rawdefopt $1 no-$2 $3 (-) - $2'.
function noopt() {
  rawdefopt "$1" "no-$2" "$3" '(-)' - "$2"
}

##
# kvopt $1 $2 $3 $4 $5
#
#   $1, $2, $3, $4, $5 - see `rawdefkvopt'
#
# Alias for `rawdefkvopt'.
function kvopt() {
  rawdefkvopt "$1" "$2" "$3" "$4" "$5"
}

##
# handle_long_kvoption $1
#
#   $1 - command line argument
#
# Handle --key=value argument.
function handle_long_kvoption() {
  local T
  local K
  local V

  K=$(expr "$1" : '^--\([^=][^=]*\)=..*$')
  V=$(expr "$1" : '^--[^=][^=]*=\(..*\)$')
  eval "T=\"\${${OPTSTORAGE_PREFIX}_long_kvopts_map[\$K]}\""

  if [ -z "$T" ]; then
    error "--$K is not key-value option"
  fi
  setvar ${OPTVAR_PREFIX}$T "$V"
}

##
# handle_long_option $1
#
#   $1 - command line argument
#
# Handle --x[=y] argument.
function handle_long_option() {
  local T
  local U

  if [ "$need_arg" ]; then
    error "expected argument, but $1 option given"
  fi

  T=$(expr "$1" : '^--\([a-zA-Z][-a-zA-Z0-9]*=..*\)$')
  if [ "$T" ]; then
    handle_long_kvoption "$1"
  else
    T=$(expr "$1" : '^--\([a-zA-Z][-a-zA-Z0-9]*\)$')
    if [ -z "$T" ]; then
      error "ill-formed option $1"
    fi
    eval "U=\"\${${OPTSTORAGE_PREFIX}_long_kvopts_map[\$T]}\""
    if [ "$U" ]; then
      error "$1: missing value"
    fi
    eval "U=\"\${${OPTSTORAGE_PREFIX}_long_opts_map[\$T]}\""
    if [ -z "$U" ]; then
      error "unknown option $1"
    fi
    eval "\${${OPTSTORAGE_PREFIX}_long_opts_map[\$T]}"
  fi
}

##
# handle_short_kvoption $1 $2
#
#   $1 - option short name
#   $2 - command line argument
#
# Handle $1 as key-value option.
function handle_short_kvoption() {
  local O
  local V

  eval "O=\"\${${OPTSTORAGE_PREFIX}_short_kvopts_map[\$1]}\""
  V=$(expr "$2" : '^-.\(.*\)$')

  if [ -z "$V" ]; then
    need_arg="$O"
  else
    setvar ${OPTVAR_PREFIX}$O "$V"
  fi
}

##
# handle_short_option $1 $2
#
#   $1 - command line argument
#   $2 - variable name the return value will be stored
#
# Handle $1 argument as follows:
#
#   - if $1 is of the form -xyz and `x' is a key-value option, then key is `x',
#     value is `yz', and returned value is empty string
#   - if $1 is of the form -xyz and `x' is a flag, then `x' is either enabled
#     or disabled (depending on its definition), and `-yz' is returned
#   - if $1 is of the form -x and `x' is a key-value option, then key is `x',
#     value is the next command-line argument, and the empty string is returned
#   - if $1 is of the form -x and `x' is a flag, then `x' is either enabled or
#     disabled (depending on its definition), and the empty string is returned
#
# Any other forms of $1 are treated as errors.
function handle_short_option() {
  local T
  local U
  local H

  if [ "$need_arg" ]; then
    error "expected argument, but $1 option given"
  fi

  H=0
  eval "$2=\"\""
  T=$(expr "$1" : '^-\([?a-zA-Z0-9]\).*$')
  if [ -z "$T" ]; then
    error "ill-formed option $1"
  fi
  eval "U=\"\${${OPTSTORAGE_PREFIX}_short_kvopts_map[\$T]}\""
  if [ "$U" ]; then
    handle_short_kvoption "$T" "$1"
    H=1
  fi
  eval "U=\"\${${OPTSTORAGE_PREFIX}_short_opts_map[\$T]}\""
  if [ $H -eq 0 ] && [ -z "$U" ]; then
    error "unknown short option -$T"
  fi
  if [ $H -eq 0 ]; then
    eval "T=\"\${${OPTSTORAGE_PREFIX}_short_opts_map[\$T]}\""
    eval "\${${OPTSTORAGE_PREFIX}_long_opts_map[\$T]}"
    T=$(expr "$1" : '^-.\(.*\)$')
    if [ "$T" ]; then
      T="-$T"
    fi
    eval "$2=\"$T\""
  fi
}

##
# handle_need_arg $1
#
#   $1 - command line argument
#
# Set $? to 0 if `need_arg' was handled. Otherwise, set $? to 1.
function handle_need_arg() {
  if [ "$need_arg" ]; then
    setvar ${OPTVAR_PREFIX}$need_arg "$1"
    need_arg=""
    true
  else
    false
  fi
}

declare -A commands
cmd_helplines=""

##
# cmd $1 $2 $3
#
#   $1 - command name
#   $2 - short command description
#   $3 - command runner
#
# Define a command.
function cmd() {
  if [ "$cmd_helplines" ]; then
    cmd_helplines="$cmd_helplines${nl_sep}  $1${tab_sep}$2"
  else
    cmd_helplines="  $1${tab_sep}$2"
  fi
  if [ "${commands[$1]}" ]; then
    error "command $1 was already defined"
  fi
  commands[$1]="$3"
}

##
# fcmd $1 $2 $3
#
#   $1, $2 - as in `cmd'
#   $3 - command as a file
#
# Define a command, where command is a script stored in $3.
function fcmd() {
  cmd "$1" "$2" "${PKM_DATADIR}/${PKM_NAME}/cmd/$3"
}

##
# icmd $1 $2 $3
#
#   $1, $2 - as in `cmd'
#   $3 - command as a function
#
# Define a command, where command is a function $3.
function icmd() {
  cmd "$1" "$2" "$3"
}

##
# usage
#
# Print this script usage to stdout.
function usage() {
  echo "Usage: $PKM_NAME [options] COMMAND [command options]"
  echo ""
  echo "where options are"
  echo ""
  eval "echo \"\$${OPTSTORAGE_PREFIX}_helplines\""
  echo ""
  echo "and commands are"
  echo ""
  echo "$cmd_helplines"
  echo ""
  echo "To get the more information about a command from the list above, try"
  echo ""
  echo "  $PKM_NAME help command"
  echo ""
  echo "or simply: $PKM_NAME command --help"
}

need_arg=""
short_args=""
nargs=0
export need_arg short_args nargs

##
# process_args $1 $2 ... $N
#
#   $1, $2, ..., $N - arguments
#
# Process given arguments, return the number of processed arguments.
function process_args() {
  need_arg=""
  short_args=""
  nargs=0
  while [ "$*" ]; do
    case "$1" in
      --*)
        handle_long_option "$1"
        ;;
      -*)
        short_args="$1"
        while [ "$short_args" ]; do
          handle_short_option "$short_args" short_args
        done
        ;;
      *)
        handle_need_arg "$1" || break
        ;;
    esac
    shift
    nargs=$((nargs + 1))
  done
  [ "$need_arg" ] && error "expected argument, but end of command line reached"
}

##
# help_usage
#
# Display help lines for `help' builtin command.
function help_usage() {
  echo "help: help [options] COMMAND"
  echo ""
  echo "Show COMMAND helplines; options are"
  echo ""
  eval "echo \"\$${OPTSTORAGE_PREFIX}_helplines\""
  echo ""
}

##
# help_cmd $1 $2 ... $N
#
#   $1, $2, ..., $N - arguments
#
# `help' builtin command.
function help_cmd() {
  OPTVAR_PREFIX='HELPOPT_'
  OPTSTORAGE_PREFIX='HELP'

  make_optstorage
  defopt h,? help "print this screen and exit"

  process_args "$@"
  shift $nargs

  [ $HELPOPT_HELP -ne 0 ] && { help_usage; exit 0; }
  [ -z "$1" ] && error "help: expected command"
  [ -z "${commands[$1]}" ] && error "help: unknown command $1"

  (${commands[$1]} --help)
}

##
# selftest_usage
#
# Display help lines for `selftest' builtin command.
function selftest_usage() {
  echo "selftest: selftest [options]"
  echo ""
  echo "Run tests for pk-maint; options are"
  echo ""
  eval "echo \"\$${OPTSTORAGE_PREFIX}_helplines\""
  echo ""
}

##
# selftest_cmd $1 $2 ... $N
#
#   $1, $2, ..., $N - arguments
#
# `selftest' builtin command.
function selftest_cmd() {
  OPTVAR_PREFIX='SELFTESTOPT_'
  OPTSTORAGE_PREFIX='SELFTEST'

  make_optstorage
  defopt h,? help "print this screen and exit"

  process_args "$@"
  shift $nargs

  [ $SELFTESTOPT_HELP -ne 0 ] && { selftest_usage; exit 0; }

  source "${PKM_DATADIR}/${PKM_NAME}/t/${PKM_NAME}.t" && runtests
}

defopt h,? help "print this screen and exit"
defopt - version "${tab_sep}print version and exit"
icmd help "${tab_sep}display help about selected command" help_cmd
icmd selftest "run tests for this script" selftest_cmd

process_args "$@"
shift $nargs

[ $OPT_HELP -ne 0 ] && { usage; exit 0; }
[ $OPT_VERSION -ne 0 ] && { echo $PKM_VERSION; exit 0; }
[ -z "$1" ] && error "expected command"
[ -z "${commands[$1]}" ] && error "unknown command $1"

PKM_CMD="$1"
shift

(${commands[$PKM_CMD]} "$@")
