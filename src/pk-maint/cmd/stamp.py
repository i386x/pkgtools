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
  --format=STR      set the format string (in Python syntax)
  -h, -?, --help    print this screen and exit
  --version         print the version and exit

The format string is ordinary Python format string supporting the following
fields:

  %%(tm_year)d      as in time.struct_time
  %%(tm_mon)d       as in time.struct_time
  %%(tm_mday)d      as in time.struct_time
  %%(tm_hour)d      as in time.struct_time
  %%(tm_min)d       as in time.struct_time
  %%(tm_sec)d       as in time.struct_time
  %%(tm_wday)d      as in time.struct_time
  %%(tm_yday)d      as in time.struct_time
  %%(tm_zone)s      as in time.struct_time
  %%(zone_sign)s    time zone (excluding DST) offset sign (+/-)
  %%(zone_hour)d    time zone (excluding DST) offset hour
  %%(zone_min)d     time zone (excluding DST) offset minute
  %%(zone_sec)d     time zone (excluding DST) offset second
  %%(dst_sign)s     DST sign (+/-)
  %%(dst_hour)d     DST hour
  %%(dst_min)d      DST minute
  %%(dst_sec)d      DST second
  %%(zd_sign)s      time zone (including DST) offset sign (+/-)
  %%(zd_hour)d      time zone (including DST) offset hour
  %%(zd_min)d       time zone (including DST) offset minute
  %%(zd_sec)d       time zone (including DST) offset second

WARNING: Since this script can evaluate code that can be passed throught
--format parameter, use this script carefully and as internal auxiliary
tool only.

"""

help_given = False
version_given = False
file_given = None
format_string = \
    "%(tm_year)04d-%(tm_mon)02d-%(tm_mday)02d" \
    " " \
    "%(tm_hour)02d:%(tm_min)02d:%(tm_sec)02d" \
    " " \
    "%(zd_sign)s%(zd_hour)02d%(zd_min)02d"

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

p("%s\n", format_string % tm_vars)
