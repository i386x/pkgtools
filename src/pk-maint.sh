#!/bin/sh
#
#! \file    ./src/pk-maint.sh
#! \author  Jiří Kučera, <jkucera AT redhat.com>
#! \stamp   2017-12-18 00:22:17 (UTC+01:00, DST+00:00)
#! \project pkgtools: Tools for Maintaining Fedora Packages
#! \license MIT (see ./LICENSE)
#! \version See ./VERSION
#! \fdesc   Main script.
#

unset CDPATH

PKM_PROG="$0"
PKM_NAME="${PKM_PROG##*/}"
PKM_NAME="${PKM_NAME%.*}"
export PKM_PROG PKM_NAME

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

PKM_MAINTFILE=""
PKM_PRJROOT=""
export PKM_MAINTFILE PKM_PRJROOT

PKM_CMD=""
export PKM_CMD

PKM_DEBUG=0
export PKM_DEBUG

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
  echo "${PKM_NAME}$T: ERROR: $*" >&2
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
  echo "${PKM_NAME}$T: WARNING: $*" >&2
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
  [ "$T" != "$1" ]
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
  [ -z "$T" ]
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
# text_to_right $1 $2 $3
#
#   $1 - current text
#   $2 - text to be appended and justified
#   $3 - maximum number of chars
#
# Return the string of the length $3 starting with $1 and ending with $2. The
# space between $1 and $2 is filled by spaces. If the length of $1$2 is greater
# or equal to $3, $1$2 is returned.
function text_to_right() {
  local L

  L=$(expr length "$1$2")
  if [ $L -ge $3 ]; then
    echo "$1$2"
  else
    L=$(($3 - $L))
    echo -n "$1"
    for ((i = 0; i < $L; i++)); do
      echo -n " "
    done
    echo "$2"
  fi
}

##
# exists $1
#
#   $1 - file or directory name
#
# Return true if $1 is existing file or directory.
function exists() {
  [ -f "$1" ] || [ -d "$1" ]
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
  [ -z "$(find_command $1)" ] && error "$1 command is required"
}

relpath_resolver_='
import sys
import os

bye = sys.exit
argv = sys.argv[1:]

def error(msg, *args):
    sys.stderr.write("relpath_resolver: %s\n" % (msg % args))
    bye(1)

def p(msg, *args):
    sys.stdout.write("%s\n" % (msg % args))

if len(argv) < 2:
    error("insufficient number of arguments")

p(os.path.relpath(argv[0], argv[1]))
'

##
# compute_relpath $1 $2
#
#   $1 - path
#   $2 - start
#
# Return a path to $1 relative to $2 (wrapper around Python's os.path.relpath).
function compute_relpath() {
  python -c "${relpath_resolver_}" "$@"
}

upwards_crawler_='
import sys
import os

up = lambda p: os.path.realpath(os.path.join(p, os.pardir))
bye = sys.exit
argv = sys.argv[1:]

def error(msg, *args):
    sys.stderr.write("upwards_crawler: %s\n" % (msg % args))
    bye(1)

def gotcha(what):
    sys.stdout.write("%s\n" % what)
    bye(0)

if len(argv) < 2:
    error("insufficient number of arguments")

# Start point: path to (hypothetic) file or directory:
p = os.path.realpath(argv[0])
if not os.path.isdir(p):
    p = up(p)

# Crawl:
f = argv[1]
p_ = p
while True:
    pp = os.path.join(p, f)
    if os.path.isdir(pp) or os.path.isfile(pp):
        gotcha(pp)
    p = up(p)
    if p == p_:
        break
    p_ = p
'

##
# search_upwards $1 $2
#
#   $1 - path to start point
#   $2 - item to be searched
#
# From $1 go to upwards in directory structure, looking for $2. If $2 is found,
# return the absolute path to it. Otherwise, the result is empty.
function search_upwards() {
  python -c "${upwards_crawler_}" "$@"
}

##
# setvar_ $1 $2
#
#   $1 - var name
#   $2 - value
#
# Assign $2 to $1. This also defines $1.
function setvar_() {
  eval "$1=\"$2\""
  export $1
}

##
# setvar $1 $2
#
#   $1 - name
#   $2 - value
#
# Set project variable.
function setvar() {
  ProjectVars["$1"]="$2"
}

##
# config $1 $2 $3
#
#   $1 - command
#   $2 - variable
#   $3 - value (can be written as a code)
#
# Add a line of code that evaluates $3, add it to $2, and export $2, to $1's
# config list. When $1 is invoked, it evaluates its config list (if this
# feature is implemented in $1) which updates the environment of the recent
# subshell.
function config() {
  local T

  T="$2=\"$3\"; export $2${nl_sep}"
  if [ -z "${ProjectConfig[$1]}" ]; then
    ProjectConfig["$1"]="$T"
  else
    ProjectConfig["$1"]="${ProjectConfig[$1]}${T}"
  fi
}

templater_prologue_='
import sys
import os
import re

var_re = re.compile("(@@|@[a-zA-Z_][a-zA-Z0-9_]*)")
var_char_re = re.compile("[a-zA-Z_]")
eq_re = re.compile("=")

is_var = lambda x: len(x) >= 2 and x[0] == "@" and var_char_re.match(x[1])
bye = sys.exit

def error(msg, *args):
    sys.stderr.write("templater: %s\n" % (msg % args))
    bye(1)

class Template:
    def __init__(self, name, body):
        self.name = name
        self.body = var_re.split(body)
        for i, x in enumerate(self.body):
            if is_var(x):
                y = "%s.%s" % (self.name, x[1:])
                self.body[i] = "@%s" % y

# Defined templates
templates = {}
# A map that maps a (qualified) template variable name to template name
template_vars = {}

def add_template(name, body, **kvargs):
    templates[name] = Template(name, body)
    for k in kvargs:
        kk = "%s.%s" % (name, k)
        template_vars[kk] = kvargs[k]

'

template_defs=""

templater_='
argv = sys.argv[1:]

tape = []

if argv:
    tape.append("@%s" % argv[0])
    argv = argv[1:]

tenv = dict([eq_re.split(x, 1) for x in argv])

emit = sys.stdout.write

# Template variables resolution:
#
#   1. if a template variable is qualified, i.e. if it is of the form X.Y, then
#      (a) is X.Y in tenv?
#          - yes -> substitute it for tenv[X.Y]
#          - no -> go to (b)
#      (b) is X.Y in os.environ?
#          - yes -> substitute it for os.environ[X.Y]
#          - no -> go to (c)
#      (c) is X.Y in template_vars?
#          - yes -> substitute it for templates[template_vars[X.Y]]
#          - no -> go to (d)
#      (d) is Y in tenv?
#          - yes -> substitute it for tenv[Y]
#          - no -> go to (e)
#      (e) is Y in os.environ?
#          - yes -> substitute it for os.environ[Y]
#          - no -> error
#   2. if a template variable is not qualified, i.e. if it is of the form X,
#      then
#      (a) is X in tenv?
#          - yes -> substitute it for tenv[X]
#          - no -> go to (b)
#      (b) is X in os.environ?
#          - yes -> substitute it for os.environ[X]
#          - no -> go to (c)
#      (c) is X in templates?
#          - yes -> substitute it for templates[X]
#          - no -> error
while tape:
    t = tape.pop(0)
    if not t:
        pass
    elif t == "@@":
        emit("@")
    elif is_var(t):
        t = t[1:]
        if "." in t:
            v = t.split(".")[-1]
            if t in tenv:
                emit(tenv[t])
            elif t in os.environ:
                emit(os.environ[t])
            elif t in template_vars:
                t = template_vars[t]
                if not t in templates:
                    error("Undefined template %s!", t)
                t = templates[t]
                tape = t.body + tape
            elif v in tenv:
                emit(tenv[v])
            elif v in os.environ:
                emit(os.environ[v])
            else:
                error("Failed to substitute %s!", t)
        else:
            if t in tenv:
                emit(tenv[t])
            elif t in os.environ:
                emit(os.environ[t])
            elif t in templates:
                t = templates[t]
                tape = t.body + tape
            else:
                error("Failed to substitute %s!", t)
    else:
        emit(t)
'

##
# template $1 $2 $3 $4 ... $n
#
#   $1 - template name
#   $2 - template definition
#   $3, $4, ..., $n - TEMPLATE_VAR=TEMPLATE_NAME options
#
# Add a new template to the list of templates. By options $3 to $n are defined
# binds of template variables to another templates.
function template() {
  local K
  local V
  local T
  local D

  T="$1"
  D="$2"
  shift 2

  [ -z "$T" ] && error "$FUNCNAME: missing template name"
  expr "$T" : '^[a-zA-Z_][a-zA-Z0-9_]*$' >/dev/null 2>&1 \
  || error "$FUNCNAME: ill-formed template name '$T'"

  T="add_template(\"$T\", \"\"\"$D\"\"\""
  for P; do
    K=$(expr "$P" : '^\([a-zA-Z_][a-zA-Z0-9_]*\)=[a-zA-Z_][a-zA-Z0-9_]*$')
    [ -z "$K" ] && error "$FUNCNAME: ill-formed KEY=VALUE option '$P'"
    V=$(expr "$P" : '^.*=\(.*\)$')
    T="$T, $K = \"$V\""
  done
  T="$T)"
  template_defs="${template_defs}${T}${nl_sep}"
}

##
# eval_template $1 $2 ... $n
#
#   $1 - template name
#   $2, $3, ..., $n - environment definition (VAR=VALUE)
#
# Evaluate template within the given environment and send the result to the
# stdout.
function eval_template() {
  local A

  for P; do
    A="$A '$P'"
  done
  eval "python -c '${templater_prologue_}${template_defs}${templater_}' $A"
}

##
# addfile [groups] : FILES
#
# Add each file from FILES to the every group from `groups' including the group
# `all'.
function addfile() {
  local G

  # Gather groups:
  G="all"
  while [ $# -gt 0 ]; do
    if [ "$1" = ":" ]; then
      shift
      break
    else
      G="$G $1"
    fi
    shift
  done

  # Collect files:
  while [ $# -gt 0 ]; do
    for g in $G; do
      ProjectFiles[$g]="${ProjectFiles[$g]}$1${nl_sep}"
    done
    shift
  done
}

##
# for_files $1 $2 ... $n
#
#   $1 - group name
#   $2 - action
#   $3, $4, ..., $n - $2's arguments
#
# For each file F from ${ProjectFiles[$1]} do $2 with arguments $F $3 $4 ... $n.
function for_files() {
  local G
  local C

  G=$1; C=$2; shift 2
  for f in ${ProjectFiles[$G]}; do
    $C $f "$@"
  done
}

require_command cat
require_command head
require_command cut
require_command tr
require_command expr
require_command grep
require_command sed
require_command python

PKM_VERSION='@VERSION@'
case "$PKM_VERSION" in
  @*@) PKM_VERSION=$(cat "$(dirname $0)/../VERSION")
esac
export PKM_VERSION

declare -A ProjectVars
declare -A ProjectConfig
declare -A ProjectFiles

[ -f "${PKM_CFGDIR}/${PKM_NAME}rc" ] && source "${PKM_CFGDIR}/${PKM_NAME}rc"
[ -f "${HOME}/.${PKM_NAME}rc" ] && source "${HOME}/.${PKM_NAME}rc"

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
    setvar_ ${OPTVAR_PREFIX}$T 1
  else # "-" || "(-)"
    setvar_ ${OPTVAR_PREFIX}$T 0
  fi

  if [ "$5" = "+" ]; then
    eval "${OPTSTORAGE_PREFIX}_long_opts_map[\$2]=\"setvar_ ${OPTVAR_PREFIX}\$T 1\""
  else
    eval "${OPTSTORAGE_PREFIX}_long_opts_map[\$2]=\"setvar_ ${OPTVAR_PREFIX}\$T 0\""
  fi

  if [ "$1" != "-" ]; then
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

  setvar_ ${OPTVAR_PREFIX}$T "$4"

  eval "${OPTSTORAGE_PREFIX}_long_kvopts_map[\$2]=\"\$T\""

  if [ "$1" != "-" ]; then
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

  [ -z "$T" ] && error "--$K is not key-value option"
  setvar_ ${OPTVAR_PREFIX}$T "$V"
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

  [ "$need_arg" ] && error "expected argument, but $1 option given"

  T=$(expr "$1" : '^--\([a-zA-Z][-a-zA-Z0-9]*=..*\)$')
  if [ "$T" ]; then
    handle_long_kvoption "$1"
  else
    T=$(expr "$1" : '^--\([a-zA-Z][-a-zA-Z0-9]*\)$')
    [ -z "$T" ] && error "ill-formed option $1"
    eval "U=\"\${${OPTSTORAGE_PREFIX}_long_kvopts_map[\$T]}\""
    [ "$U" ] && error "$1: missing value"
    eval "U=\"\${${OPTSTORAGE_PREFIX}_long_opts_map[\$T]}\""
    [ -z "$U" ] && error "unknown option $1"
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
    setvar_ ${OPTVAR_PREFIX}$O "$V"
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

  [ "$need_arg" ] && error "expected argument, but $1 option given"

  H=0
  eval "$2=\"\""
  T=$(expr "$1" : '^-\([?a-zA-Z0-9]\).*$')
  [ -z "$T" ] && error "ill-formed option $1"
  eval "U=\"\${${OPTSTORAGE_PREFIX}_short_kvopts_map[\$T]}\""
  [ "$U" ] && {
    handle_short_kvoption "$T" "$1"
    H=1
  }
  eval "U=\"\${${OPTSTORAGE_PREFIX}_short_opts_map[\$T]}\""
  [ $H -eq 0 ] && [ -z "$U" ] && error "unknown short option -$T"
  if [ $H -eq 0 ]; then
    eval "T=\"\${${OPTSTORAGE_PREFIX}_short_opts_map[\$T]}\""
    eval "\${${OPTSTORAGE_PREFIX}_long_opts_map[\$T]}"
    T=$(expr "$1" : '^-.\(.*\)$')
    [ "$T" ] && T="-$T"
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
  [ "$need_arg" ] && {
    setvar_ ${OPTVAR_PREFIX}$need_arg "$1"
    need_arg=""
  }
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
  [ "${commands[$1]}" ] && error "command $1 was already defined"
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
  local T

  # Determine interpreter based on suffix:
  case "$3" in
    *.sh) T="sh " ;;
    *.py) T="python " ;;
    *) T=""
  esac
  cmd "$1" "$2" "${T}${PKM_DATADIR}/${PKM_NAME}/cmd/$3"
}

##
# icmd $1 $2 $3 [$4]
#
#   $1, $2 - as in `cmd'
#   $3 - command name
#
# Define a command, where command is a function. If $3 is an existing file,
# use it and as a command treat $3'_cmd function from that file, where $3' has
# '-' and file extension suffix removed.
function icmd() {
  local C="$3"

  [ -f "${PKM_DATADIR}/${PKM_NAME}/cmd/$C" ] && {
    source "${PKM_DATADIR}/${PKM_NAME}/cmd/$C"
    C=$(echo "$C" | sed -e 's/\..*$//g; s/-//g; s/$/_cmd/g')
  }
  cmd "$1" "$2" "$C"
}

##
# usage
#
# Print this script usage to stdout.
function usage() {
  echo "Usage: $PKM_NAME [options] [COMMAND [command options]]"
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
  echo ""
  echo "If COMMAND is not present and Maintfile is loaded, COMMAND is treated"
  echo "as 'default' with no options. If Maintfile is not loaded, COMMAND is"
  echo "treated as a missing command and no action is taken."
  echo ""
  echo "If COMMAND is present, it is first treated as builtin command. Otherwise,"
  echo "if Maintfile is loaded, it is treated as a Maintfile target. Otherwise,"
  echo "COMMAND is unknown."
  echo ""
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
  while [ $# -gt 0 ]; do
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
  echo "$PKM_CMD: $PKM_CMD [options] COMMAND"
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
  defopt - version "${tab_sep}print version and exit"

  process_args "$@"
  shift $nargs

  [ $HELPOPT_HELP -ne 0 ] && { help_usage; exit 0; }
  [ $HELPOPT_VERSION -ne 0 ] && { echo $PKM_VERSION; exit 0; }
  [ -z "$1" ] && error "expected command"
  [ -z "${commands[$1]}" ] && error "unknown command $1"

  (${commands[$1]} --help)
}

##
# selftest_usage
#
# Display help lines for `selftest' builtin command.
function selftest_usage() {
  echo "$PKM_CMD: $PKM_CMD [options]"
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
  defopt - version "${tab_sep}print the vesrion and exit"

  process_args "$@"
  shift $nargs

  [ $SELFTESTOPT_HELP -ne 0 ] && { selftest_usage; exit 0; }
  [ $SELFTESTOPT_VERSION -ne 0 ] && { echo $PKM_VERSION; exit 0; }

  source "${PKM_DATADIR}/${PKM_NAME}/t/${PKM_NAME}.t" && runtests
}

##
# edit_usage
#
# Display help lines for `edit' builtin command.
function edit_usage() {
  echo "$PKM_CMD: $PKM_CMD [options] VAR1=VAL1 VAR2=VAL2 ... VARN=VALN"
  echo ""
  echo "Read the input file, edit it, and store it to the output file or send"
  echo "it to the stdout; options are"
  echo ""
  eval "echo \"\$${OPTSTORAGE_PREFIX}_helplines\""
  echo ""
}

##
# edit_cmd $1 $2 ... $N
#
#   $1, $2, ..., $N - arguments
#
# `edit' builtin command.
function edit_cmd() {
  local C
  local D
  local T
  local U

  OPTVAR_PREFIX='EDITOPT_'
  OPTSTORAGE_PREFIX='EDIT'

  make_optstorage
  kvopt a at-sign "set the '@' escape sequence" '=@=' STR
  kvopt d delim "set the delimiter between sed's s-command parts" '|' DLM
  defopt h,? help "print this screen and exit"
  kvopt i input "set the input file" "" FILE
  kvopt o output "set the output file (default is stdout)" "" FILE
  defopt - version "${tab_sep}print the version and exit"

  process_args "$@"
  shift $nargs

  [ $EDITOPT_HELP -ne 0 ] && { edit_usage; exit 0; }
  [ $EDITOPT_VERSION -ne 0 ] && { echo $PKM_VERSION; exit 0; }
  [ -z "$EDITOPT_INPUT" ] && error "missing --input"

  C="sed"
  D="$EDITOPT_DELIM"
  for V; do
    case "$V" in
      *=*)
        T=$(expr "$V" : '^\([a-zA-Z_][a-zA-Z0-9_]*\)=.*$')
        [ -z "$T" ] && error "ill-formed VAR=VALUE argument '$V'"
        U=$(expr "$V" : '^.*=\(.*\)$')
        C="$C -e 's${D}@$T@${D}$U${D}g'"
        ;;
      *)
        error "ill-formed VAR=VALUE argument '$V'"
    esac
  done
  C="cat \"$EDITOPT_INPUT\" | $C -e 's${D}$EDITOPT_AT_SIGN${D}@${D}g'"
  [ "$EDITOPT_OUTPUT" ] && C="$C > \"$EDITOPT_OUTPUT\""
  eval "$C"
}

defopt - debug "${tab_sep}enter the debug mode"
defopt h,? help "print this screen and exit"
defopt - version "${tab_sep}print version and exit"
icmd edit "${tab_sep}edit the given input file and send it to the given output" edit_cmd
icmd help "${tab_sep}display help about selected command" help_cmd
icmd init "${tab_sep}initialize project directory" init.sh
icmd new-file "create a new source file" new-file.sh
icmd selftest "run tests for this script" selftest_cmd
fcmd stamp "${tab_sep}get the time date stamp" stamp.py

declare -A targets_

##
# target $1
#
#   $1 - target's name
#
# Add $1 to Maintfile targets.
function target() {
  targets_[$1]="$1"
}

##
# extract_targets_ $1
#
#   $1 - Maintfile
#
# Extract targets names from $1. As a target is considered every function of
# the form:
#
#   tg_name() {
#
# where `tg_name' must be settled on the line beginning and there can be any
# number of spaces around `(', `)', and `{'.
function extract_targets_() {
  local L

  L=$( \
    cat "$1" | grep -E '^tg_[a-zA-Z0-9_]+[ \t]*[(][ \t]*[)][ \t]*[{].*' \
             | sed  -E -e 's/^(tg_[a-zA-Z0-9_]+).*/\1/g' \
  )
  for l in $L; do
    targets_[${l:3}]="$l"
  done
}

##
# default
#
# Predefined Maintfile default target.
function tg_default() {
  true
}

PKM_MAINTFILE=$(search_upwards "$(pwd)" "Maintfile")
PKM_PRJROOT=$(dirname "$PKM_MAINTFILE")

[ "$PKM_MAINTFILE" ] && {
  [ -f "${PKM_PRJROOT}/.${PKM_NAME}/config" ] \
  && source "${PKM_PRJROOT}/.${PKM_NAME}/config"
  source "$PKM_MAINTFILE"
  extract_targets_ "$PKM_MAINTFILE"
  targets_['default']="tg_default"
}

process_args "$@"
shift $nargs

PKM_DEBUG=$OPT_DEBUG
[ $OPT_HELP -ne 0 ] && { usage; exit 0; }
[ $OPT_VERSION -ne 0 ] && { echo $PKM_VERSION; exit 0; }

if [ -z "$1" ]; then
  [ -z "$PKM_MAINTFILE" ] && exit 0
  PKM_CMD='default'
else
  PKM_CMD="$1"
  shift
fi

if [ "${commands[$PKM_CMD]}" ]; then
  (${commands[$PKM_CMD]} "$@")
elif [ "${targets_[$PKM_CMD]}" ]; then
  (${targets_[$PKM_CMD]} "$@")
else
  error "unknown command: $PKM_CMD"
fi
