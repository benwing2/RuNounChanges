#!/usr/bin/env python
# -*- coding: utf-8 -*-

from blib import getparam, rmparam, msg, errmsg, site
import pywikibot, re, sys, codecs, argparse

parser = argparse.ArgumentParser(description="Generate table documenting form-of template variants.")
parser.add_argument('--direcfile', help="File containing directives.")
args = parser.parse_args()

msg('{|class="wikitable"')
msg("! Template !! Initial capital !! Final period !! Supports from=, from2=, ... || Supports POS=")
for line in codecs.open(args.direcfile, "r", "utf-8"):
  direcs = line.rstrip('\n').split(',')
  template = direcs[0]
  withcap = False
  withdot = False
  withfrom = False
  withPOS = False
  for direc in direcs[1:]:
    if direc == "cap":
      withcap = True
    elif direc == "dot":
      withdot = True
    elif direc == "from":
      withfrom = True
    elif direc == "POS":
      withPOS = True
    else:
      assert False, "Unrecognized directive %s" % direc
  def dobool(val):
    return val and "'''yes'''" or "no"
  msg("|-")
  msg("| %-50s || %-9s || %-9s || %-9s || %-9s" % ("[[%s]]" % template, dobool(withcap),
    dobool(withdot), dobool(withfrom), dobool(withPOS)))
msg("|}")
