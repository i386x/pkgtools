#
#! \file    ./src/pk-maint/t/pk-maint.t
#! \author  Jiří Kučera, <jkucera AT redhat.com>
#! \stamp   2017-12-20 19:47:22 (UTC+01:00, DST+00:00)
#! \project pkgtools: Tools for Maintaining Fedora Packages
#! \license MIT (see ./LICENSE)
#! \version See ./VERSION
#! \fdesc   Main script tests.
#

require_command expr
require_command cat
require_command rm

PK_MAINT_TESTSET=""
PK_MAINT_NTESTS=0
PK_MAINT_SUCCEEDS=0
PK_MAINT_FAILS=0

function add_test() {
  if [ -z "$PK_MAINT_TESTSET" ]; then
    PK_MAINT_TESTSET="test_$1"
  else
    PK_MAINT_TESTSET="$PK_MAINT_TESTSET test_$1"
  fi
  PK_MAINT_NTESTS=$(($PK_MAINT_NTESTS + 1))
}

function runtests() {
  inform "Running tests..."
  for t in $PK_MAINT_TESTSET; do
    $t
  done
  echo "...done"
  echo ""
  inform "Overall tests statistics:"
  echo "- total tests ran:		$PK_MAINT_NTESTS"
  echo "- total tests succeeded:	$PK_MAINT_SUCCEEDS"
  echo "- total tests failed:		$PK_MAINT_FAILS"
}

test_error() {
  local E
  local T
  local U
  local F

  echo "  Testing 'error'..."
  F=0

  (error "XXX") 1> /var/tmp/stdout.$$ 2> /var/tmp/stderr.$$
  E=$?
  T=$(cat /var/tmp/stdout.$$)
  U=$(cat /var/tmp/stderr.$$); U=$(expr "$U" : '.*\(XXX\).*')
  rm /var/tmp/stdout.$$ /var/tmp/stderr.$$

  [ $E -eq 1 ] || { echo "  > Expected exit code 1"; F=1; }
  [ -z "$T" ] || { echo "  > 'error' writes to stdout"; F=1; }
  [ "$U" = "XXX" ] || { echo "  > 'error' does not write to stderr"; F=1; }

  [ $F -ne 0 ] && { echo "  FAILED"; PK_MAINT_FAILS=$(($PK_MAINT_FAILS + 1)); }
  [ $F -eq 0 ] && { echo "  ...OK"; PK_MAINT_SUCCEEDS=$(($PK_MAINT_SUCCEEDS + 1)); }
}
add_test error

test_warning() {
  local E
  local T
  local U
  local F

  echo "  Testing 'warning'..."
  F=0

  (warning "XXX") 1> /var/tmp/stdout.$$ 2> /var/tmp/stderr.$$
  E=$?
  T=$(cat /var/tmp/stdout.$$)
  U=$(cat /var/tmp/stderr.$$); U=$(expr "$U" : '.*\(XXX\).*')
  rm /var/tmp/stdout.$$ /var/tmp/stderr.$$

  [ $E -eq 0 ] || { echo "  > Expected exit code 0"; F=1; }
  [ -z "$T" ] || { echo "  > 'warning' writes to stdout"; F=1; }
  [ "$U" = "XXX" ] || { echo "  > 'warning' does not write to stderr"; F=1; }

  [ $F -ne 0 ] && { echo "  FAILED"; PK_MAINT_FAILS=$(($PK_MAINT_FAILS + 1)); }
  [ $F -eq 0 ] && { echo "  ...OK"; PK_MAINT_SUCCEEDS=$(($PK_MAINT_SUCCEEDS + 1)); }
}
add_test warning

test_inform() {
  local E
  local T
  local U
  local F

  echo "  Testing 'inform'..."
  F=0

  (inform "XXX") 1> /var/tmp/stdout.$$ 2> /var/tmp/stderr.$$
  E=$?
  T=$(cat /var/tmp/stdout.$$); T=$(expr "$T" : '.*\(XXX\).*')
  U=$(cat /var/tmp/stderr.$$)
  rm /var/tmp/stdout.$$ /var/tmp/stderr.$$

  [ $E -eq 0 ] || { echo "  > Expected exit code 0"; F=1; }
  [ "$T" = "XXX" ] || { echo "  > 'inform' does not write to stdout"; F=1; }
  [ -z "$U" ] || { echo "  > 'inform' writes to stderr"; F=1; }

  [ $F -ne 0 ] && { echo "  FAILED"; PK_MAINT_FAILS=$(($PK_MAINT_FAILS + 1)); }
  [ $F -eq 0 ] && { echo "  ...OK"; PK_MAINT_SUCCEEDS=$(($PK_MAINT_SUCCEEDS + 1)); }
}
add_test inform

test_str_exclude() {
  local T
  local F

  echo "  Testing 'str_exclude'..."
  F=0

  T=$(str_exclude "abcd" "")
  [ "$T" = "abcd" ] || { echo "  > 'str_exclude' should return 'abcd'"; F=1; }
  T=$(str_exclude "" "abcd")
  [ -z "$T" ] || { echo "  > 'str_exclude' should return empty string"; F=1; }
  T=$(str_exclude "abbcbcdde" "bdx")
  [ "$T" = "acce" ] || { echo "  > 'str_exclude' should return 'acce'"; F=1; }
  T=$(str_exclude "abcde" "aabbdc")
  [ "$T" = "e" ] || { echo "  > 'str_exclude' should return 'e'"; F=1; }

  [ $F -ne 0 ] && { echo "  FAILED"; PK_MAINT_FAILS=$(($PK_MAINT_FAILS + 1)); }
  [ $F -eq 0 ] && { echo "  ...OK"; PK_MAINT_SUCCEEDS=$(($PK_MAINT_SUCCEEDS + 1)); }
}
add_test str_exclude

test_str_commonchars() {
  local T
  local F

  echo "  Testing 'str_commonchars'..."
  F=0

  T=$(str_commonchars "" "")
  [ -z "$T" ] || { echo "  > 'str_commonchars' should return empty string"; F=1; }
  T=$(str_commonchars "abcd" "")
  [ -z "$T" ] || { echo "  > 'str_commonchars' should return empty string"; F=1; }
  T=$(str_commonchars "" "efgh")
  [ -z "$T" ] || { echo "  > 'str_commonchars' should return empty string"; F=1; }
  T=$(str_commonchars "abcd" "efgh")
  [ -z "$T" ] || { echo "  > 'str_commonchars' should return empty string"; F=1; }

  T=$(str_commonchars "abcdef" "defghi")
  [ "$T" = "def" ] || { echo "  > 'str_commonchars' should return 'def'"; F=1; }
  T=$(str_commonchars "dabfcdbefe" "hdexeffghii")
  [ "$T" = "dfdefe" ] || { echo "  > 'str_commonchars' should return 'dfdefe'"; F=1; }

  [ $F -ne 0 ] && { echo "  FAILED"; PK_MAINT_FAILS=$(($PK_MAINT_FAILS + 1)); }
  [ $F -eq 0 ] && { echo "  ...OK"; PK_MAINT_SUCCEEDS=$(($PK_MAINT_SUCCEEDS + 1)); }
}
add_test str_commonchars

test_str_chr() {
  local E
  local F

  echo "  Testing 'str_chr'..."
  F=0

  str_chr "" ""; E=$?
  [ $E -eq 1 ] || { echo "  > 'str_chr' should return 'false'"; F=1; }
  str_chr "abc" ""; E=$?
  [ $E -eq 1 ] || { echo "  > 'str_chr' should return 'false'"; F=1; }
  str_chr "" "abc"; E=$?
  [ $E -eq 1 ] || { echo "  > 'str_chr' should return 'false'"; F=1; }
  str_chr "abc" "x"; E=$?
  [ $E -eq 1 ] || { echo "  > 'str_chr' should return 'false'"; F=1; }
  str_chr "abcdefgh" "xyzduvw"; E=$?
  [ $E -eq 0 ] || { echo "  > 'str_chr' should return 'true'"; F=1; }

  [ $F -ne 0 ] && { echo "  FAILED"; PK_MAINT_FAILS=$(($PK_MAINT_FAILS + 1)); }
  [ $F -eq 0 ] && { echo "  ...OK"; PK_MAINT_SUCCEEDS=$(($PK_MAINT_SUCCEEDS + 1)); }
}
add_test str_chr

test_str_contains() {
  local E
  local F

  echo "  Testing 'str_contains'..."
  F=0

  str_contains "" ""; E=$?
  [ $E -eq 0 ] || { echo "  > 'str_contains' should return 'true'"; F=1; }
  str_contains "abc" ""; E=$?
  [ $E -eq 0 ] || { echo "  > 'str_contains' should return 'true'"; F=1; }
  str_contains "" "abc"; E=$?
  [ $E -eq 1 ] || { echo "  > 'str_contains' should return 'false'"; F=1; }
  str_contains "abc" "bac"; E=$?
  [ $E -eq 0 ] || { echo "  > 'str_contains' should return 'true'"; F=1; }
  str_contains "abc" "back"; E=$?
  [ $E -eq 1 ] || { echo "  > 'str_contains' should return 'false'"; F=1; }
  str_contains "black" "back"; E=$?
  [ $E -eq 0 ] || { echo "  > 'str_contains' should return 'true'"; F=1; }
  str_contains "back" "black"; E=$?
  [ $E -eq 1 ] || { echo "  > 'str_contains' should return 'false'"; F=1; }
  str_contains "black" "cablack"; E=$?
  [ $E -eq 0 ] || { echo "  > 'str_contains' should return 'true'"; F=1; }

  [ $F -ne 0 ] && { echo "  FAILED"; PK_MAINT_FAILS=$(($PK_MAINT_FAILS + 1)); }
  [ $F -eq 0 ] && { echo "  ...OK"; PK_MAINT_SUCCEEDS=$(($PK_MAINT_SUCCEEDS + 1)); }
}
add_test str_contains

test_str_indexof() {
  local I
  local F

  echo "  Testing 'str_indexof'..."
  F=0

  I=$(str_indexof "" "")
  [ $I -eq 0 ] || { echo "  > 'str_indexof' should return '0'"; F=1; }
  I=$(str_indexof "" "?")
  [ $I -eq 0 ] || { echo "  > 'str_indexof' should return '0'"; F=1; }
  I=$(str_indexof "abc" "?/")
  [ $I -eq 0 ] || { echo "  > 'str_indexof' should return '0'"; F=1; }
  I=$(str_indexof "ab?xcd?/" "xy?")
  [ $I -eq 3 ] || { echo "  > 'str_indexof' should return '3'"; F=1; }

  [ $F -ne 0 ] && { echo "  FAILED"; PK_MAINT_FAILS=$(($PK_MAINT_FAILS + 1)); }
  [ $F -eq 0 ] && { echo "  ...OK"; PK_MAINT_SUCCEEDS=$(($PK_MAINT_SUCCEEDS + 1)); }
}
add_test str_indexof

test_str_firstn() {
  local T
  local F

  echo "  Testing 'str_firstn'..."
  F=0

  T=$(str_firstn "" 0)
  [ -z "$T" ] || { echo "  > 'str_firstn' should return empty string"; F=1; }
  T=$(str_firstn "a" 0)
  [ -z "$T" ] || { echo "  > 'str_firstn' should return empty string"; F=1; }
  T=$(str_firstn "abc" 0)
  [ -z "$T" ] || { echo "  > 'str_firstn' should return empty string"; F=1; }
  T=$(str_firstn "" 1)
  [ -z "$T" ] || { echo "  > 'str_firstn' should return empty string"; F=1; }
  T=$(str_firstn "" 2)
  [ -z "$T" ] || { echo "  > 'str_firstn' should return empty string"; F=1; }
  T=$(str_firstn "" 3)
  [ -z "$T" ] || { echo "  > 'str_firstn' should return empty string"; F=1; }
  T=$(str_firstn "abc" 1)
  [ "$T" = "a" ] || { echo "  > 'str_firstn' should return 'a'"; F=1; }
  T=$(str_firstn "abc" 2)
  [ "$T" = "ab" ] || { echo "  > 'str_firstn' should return 'ab'"; F=1; }
  T=$(str_firstn "abc" 3)
  [ "$T" = "abc" ] || { echo "  > 'str_firstn' should return 'abc'"; F=1; }
  T=$(str_firstn "abc" 4)
  [ "$T" = "abc" ] || { echo "  > 'str_firstn' should return 'abc'"; F=1; }
  T=$(str_firstn "abc" 5)
  [ "$T" = "abc" ] || { echo "  > 'str_firstn' should return 'abc'"; F=1; }

  [ $F -ne 0 ] && { echo "  FAILED"; PK_MAINT_FAILS=$(($PK_MAINT_FAILS + 1)); }
  [ $F -eq 0 ] && { echo "  ...OK"; PK_MAINT_SUCCEEDS=$(($PK_MAINT_SUCCEEDS + 1)); }
}
add_test str_firstn

test_str_cutn() {
  local T
  local F

  echo "  Testing 'str_cutn'..."
  F=0

  T=$(str_cutn "" 0)
  [ -z "$T" ] || { echo "  > 'str_cutn' should return empty string"; F=1; }
  T=$(str_cutn "a" 0)
  [ "$T" = "a" ] || { echo "  > 'str_cutn' should return 'a'"; F=1; }
  T=$(str_cutn "abc" 0);
  [ "$T" = "abc" ] || { echo "  > 'str_cutn' should return 'abc'"; F=1; }
  T=$(str_cutn "" 1)
  [ -z "$T" ] || { echo "  > 'str_cutn' should return empty string"; F=1; }
  T=$(str_cutn "" 2)
  [ -z "$T" ] || { echo "  > 'str_cutn' should return empty string"; F=1; }
  T=$(str_cutn "" 3)
  [ -z "$T" ] || { echo "  > 'str_cutn' should return empty string"; F=1; }
  T=$(str_cutn "abc" 1)
  [ "$T" = "bc" ] || { echo "  > 'str_cutn' should return 'bc'"; F=1; }
  T=$(str_cutn "abc" 2)
  [ "$T" = "c" ] || { echo "  > 'str_cutn' should return 'c'"; F=1; }
  T=$(str_cutn "abc" 3)
  [ -z "$T" ] || { echo "  > 'str_cutn' should return empty string"; F=1; }
  T=$(str_cutn "abc" 4)
  [ -z "$T" ] || { echo "  > 'str_cutn' should return empty string"; F=1; }
  T=$(str_cutn "abc" 5)
  [ -z "$T" ] || { echo "  > 'str_cutn' should return empty string"; F=1; }

  [ $F -ne 0 ] && { echo "  FAILED"; PK_MAINT_FAILS=$(($PK_MAINT_FAILS + 1)); }
  [ $F -eq 0 ] && { echo "  ...OK"; PK_MAINT_SUCCEEDS=$(($PK_MAINT_SUCCEEDS + 1)); }
}
add_test str_cutn

test_text_to_right() {
  local T
  local F

  echo "  Testing 'text_to_right'..."
  F=0

  T=$(text_to_right "" "" 0)
  [ ",$T," = ",," ] || { echo "  > 'text_to_right' should return empty string"; F=1; }
  T=$(text_to_right "" "" 1)
  [ ",$T," = ", ," ] || { echo "  > 'text_to_right' should return one space"; F=1; }
  T=$(text_to_right "" "" 10)
  [ ",$T," = ",          ," ] || { echo "  > 'text_to_right' should return 10 spaces"; F=1; }
  T=$(text_to_right "" "x" 10)
  [ ",$T," = ",         x," ] || { echo "  > 'text_to_right' should return '         x'"; F=1; }
  T=$(text_to_right "" "xyz" 10)
  [ ",$T," = ",       xyz," ] || { echo "  > 'text_to_right' should return '       xyz'"; F=1; }
  T=$(text_to_right "A" "" 10)
  [ ",$T," = ",A         ," ] || { echo "  > 'text_to_right' should return 'A         '"; F=1; }
  T=$(text_to_right "ABC" "" 10)
  [ ",$T," = ",ABC       ," ] || { echo "  > 'text_to_right' should return 'ABC       '"; F=1; }
  T=$(text_to_right "A" "x" 10)
  [ ",$T," = ",A        x," ] || { echo "  > 'text_to_right' should return 'A        x'"; F=1; }
  T=$(text_to_right "ABC" "xyz" 10)
  [ ",$T," = ",ABC    xyz," ] || { echo "  > 'text_to_right' should return 'ABC    xyz'"; F=1; }
  T=$(text_to_right "ABCDEF" "wxyz" 10)
  [ ",$T," = ",ABCDEFwxyz," ] || { echo "  > 'text_to_right' should return 'ABCDEFwxyz'"; F=1; }
  T=$(text_to_right "ABCDEF" "uvwxyz" 10)
  [ ",$T," = ",ABCDEFuvwxyz," ] || { echo "  > 'text_to_right' should return 'ABCDEFuvwxyz'"; F=1; }

  [ $F -ne 0 ] && { echo "  FAILED"; PK_MAINT_FAILS=$(($PK_MAINT_FAILS + 1)); }
  [ $F -eq 0 ] && { echo "  ...OK"; PK_MAINT_SUCCEEDS=$(($PK_MAINT_SUCCEEDS + 1)); }
}
add_test text_to_right

test_setvar_() {
  local T
  local F

  echo "  Testing 'setvar_'..."
  F=0

  # Test if `FOO' is unset:
  [ "${FOO-x}" = "x" ] || { echo "  > 'FOO' should be unset"; F=1; }
  T=FOO; setvar_ $T 42
  # Now, `FOO' should be `42':
  [ "${FOO-x}" = "42" ] || { echo "  > 'FOO' should be 42"; F=1; }
  # Unset `FOO':
  [ "${FOO-x}" = "x" ] || unset FOO
  # Test if `FOO' is unset:
  [ "${FOO-x}" = "x" ] || { echo "  > 'FOO' should be unset"; F=1; }

  [ $F -ne 0 ] && { echo "  FAILED"; PK_MAINT_FAILS=$(($PK_MAINT_FAILS + 1)); }
  [ $F -eq 0 ] && { echo "  ...OK"; PK_MAINT_SUCCEEDS=$(($PK_MAINT_SUCCEEDS + 1)); }
}
add_test setvar_
