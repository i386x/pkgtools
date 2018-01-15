#                                                         -*- coding: utf-8 -*-
#! \file    ./src/pk-maint/cmd/stamp.py
#! \author  Jiří Kučera, <jkucera AT redhat.com>
#! \stamp   2018-01-02 09:42:20 (UTC+01:00, DST+00:00)
#! \project pkgtools: Tools for Maintaining Fedora Packages
#! \license MIT (see ./LICENSE)
#! \version See ./VERSION
#! \fdesc   Generate time date stamp to stdout.
#

import sys
import os
import time
import re

up = os.path.pardir

here = os.path.dirname(os.path.realpath(__file__))
me = os.path.basename(os.path.realpath(__file__))
prog = os.environ.get('PKM_CMD', me)
pkm = os.environ.get('PKM_NAME', "")
pkm_prog = "%s %s" % (pkm, prog) if pkm else prog
version = '@VERSION@'
if version[0] == '@':
    with open(os.path.join(here, up, up, up, 'VERSION'), 'r') as fd:
        version = fd.read()

helplines="""\
%(prog)s: %(prog)s [options]

Print the time date stamp of now to stdout. If --file is given, print the ctime
of FILE instead; options are

  --file=FILE       print the time date stamp of FILE
  --format=STR      set the format string (see below)
  -h, -?, --help    print this screen and exit
  --version         print the version and exit

The format strings are similar to those from time.strftime, the following
directives are supported:

  %%%%              a literal '%%' character
  %%Y              year as a decimal number (e.g. 2008)
  %%m              month as a decimal number [01, 12]
  %%d              day of the month as a decimal number [01, 31]
  %%H              hour as a decimal number [00, 23]
  %%M              minute as a decimal number [00, 59]
  %%S              second as a decimal number [00, 61]
  %%w              weekday as a decimal number [0, 6] (Monday is 0)
  %%j              day of the year as a decimal number [001, 366]
  %%Z              time zone name
  %%[!*][0123]z    time zone offset; the parts between [] are flags with the
                  following meaning:

                    ! - time zone offset excluding DST
                    * - DST offset only
                    0 - offset sign only
                    1 - offset hours only
                    2 - offset minutes only
                    3 - offset seconds only

"""

ff_re = re.compile("(%%|%[YmdHMSwjZ]|%[!*]?[0-3]?z)")
ff_tab = {
    '%%': '%%',
    '%Y': '%(tm_year)04d',
    '%m': '%(tm_mon)02d',
    '%d': '%(tm_mday)02d',
    '%H': '%(tm_hour)02d',
    '%M': '%(tm_min)02d',
    '%S': '%(tm_sec)02d',
    '%w': '%(tm_wday)d',
    '%j': '%(tm_yday)03d',
    '%Z': '%(tm_zone)s',
    '%!0z': '%(zone_sign)s',
    '%!1z': '%(zone_hour)02d',
    '%!2z': '%(zone_min)02d',
    '%!3z': '%(zone_sec)02d',
    '%!z': '%(zone_sign)s%(zone_hour)02d%(zone_min)02d',
    '%*0z': '%(dst_sign)s',
    '%*1z': '%(dst_hour)02d',
    '%*2z': '%(dst_min)02d',
    '%*3z': '%(dst_sec)02d',
    '%*z': '%(dst_sign)s%(dst_hour)02d%(dst_min)02d',
    '%0z': '%(zd_sign)s',
    '%1z': '%(zd_hour)02d',
    '%2z': '%(zd_min)02d',
    '%3z': '%(zd_sec)02d',
    '%z': '%(zd_sign)s%(zd_hour)02d%(zd_min)02d'
}

def e(s):
    r = ""
    for x in s:
        if x == '%':
            r += '%%'
        else:
            r += x
    return r

def f(s):
    l = ff_re.split(s)
    r = ""
    for x in l:
        r += ff_tab.get(x, e(x))
    return r

help_given = False
version_given = False
file_given = None
format_string = "%Y-%m-%d %H:%M:%S %z"

def p(s, *args, **kwargs):
    if args:
        sys.stdout.write(s % args)
    elif kwargs:
        sys.stdout.write(s % kwargs)
    else:
        sys.stdout.write(s)

bye = sys.exit

def error(msg, *args):
    sys.stderr.write("%s: ERROR: %s\n" % (pkm_prog, msg % args))
    bye(1)

for x in sys.argv[1:]:
    if x in [ '--help', '-h', '-?' ]:
        help_given = True
    elif x == '--version':
        version_given = True
    elif x.startswith('--format='):
        format_string = x[len('--format='):]
        if format_string == "":
            error("ill-formed option %r", x)
    elif x.startswith('--file='):
        file_given = x[len('--file='):]
        if file_given == "":
            error("ill-formed option %r", x)
    else:
        error("invalid options %r", x)

if help_given:
    p(helplines, prog = prog)
    bye(0)

if version_given:
    p(version)
    bye(0)

stamp = time.localtime()

if file_given:
    with open(file_given, 'r') as fd:
        stamp = time.localtime(os.fstat(fd.fileno()).st_ctime)

def s2hms(t):
    t = abs(t)
    h = t // 3600
    t = t % 3600
    m = t // 60
    s = t % 60
    return (h, m, s)

def tm_zone(ts):
    if hasattr(ts, 'tm_zone'):
        return ts.tm_zone
    if time.daylight != 0 and ts.tm_isdst == 1:
        return time.tzname[1]
    return time.tzname[0]

def tz_offset():
    return -time.timezone

def az_offset():
    if time.daylight != 0 and time.altzone != 0:
        return -time.altzone
    return 0

def zone(ts):
    x = tz_offset()
    y = s2hms(x)
    return ('-' if x < 0 else '+', y[0], y[1], y[2])

def dst(ts):
    if time.daylight == 0 or ts.tm_isdst != 1:
        return ('+', 0, 0, 0)
    x = az_offset() - tz_offset()
    y = s2hms(x)
    return ('-' if x < 0 else '+', y[0], y[1], y[2])

def zd(ts):
    if time.daylight == 0 or ts.tm_isdst != 1:
        return zone(ts)
    x = az_offset()
    y = s2hms(x)
    return ('-' if x < 0 else '+', y[0], y[1], y[2])

tm_vars = dict(
    tm_year = stamp.tm_year,
    tm_mon = stamp.tm_mon,
    tm_mday = stamp.tm_mday,
    tm_hour = stamp.tm_hour,
    tm_min = stamp.tm_min,
    tm_sec = stamp.tm_sec,
    tm_wday = stamp.tm_wday,
    tm_yday = stamp.tm_yday,
    tm_zone = tm_zone(stamp)
)
tm_vars['zone_sign'], tm_vars['zone_hour'], \
    tm_vars['zone_min'], tm_vars['zone_sec'] = zone(stamp)
tm_vars['dst_sign'], tm_vars['dst_hour'], \
    tm_vars['dst_min'], tm_vars['dst_sec'] = dst(stamp)
tm_vars['zd_sign'], tm_vars['zd_hour'], \
    tm_vars['zd_min'], tm_vars['zd_sec'] = zd(stamp)

p("%s\n", f(format_string) % tm_vars)
