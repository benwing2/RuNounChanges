#!/usr/bin/env python
# -*- coding: utf-8 -*-

from blib import getparam, rmparam, msg, errmsg, site
import pywikibot, re, sys, codecs, argparse

import form_of_templates

parser = argparse.ArgumentParser(description="Generate table documenting form-of template variants.")
parser.add_argument('--direcfile', help="File containing directives.")
args = parser.parse_args()

if not args.direcfile:
  msg('{|class="wikitable"')
  msg("! Template !! Aliases !! Category !! Initial capital !! Final period !! Supports from=, from2=, ... || Supports POS=")
  for template, props in form_of_templates.form_of_templates:
    aliases = props.get("aliases", [])
    withcap = props.get("withcap", False)
    withdot = props.get("withdot", False)
    withfrom = props.get("withfrom", False)
    withPOS = props.get("withPOS", False)
    cat = props.get("cat", None)
    def dobool(val):
      return val and "'''yes'''" or "no"
    msg("|-")
    msg("| %-80s || %-50s || %-50s || %-9s || %-9s || %-9s || %-9s" % (
      "[[Template:%s|%s]]" % (template, template),
      ", ".join("[[Template:%s|%s]]" % (alias, alias) for alias in aliases),
      "<code><nowiki>LANG %s</nowiki></code>" % cat if cat else "",
      dobool(withcap), dobool(withdot), dobool(withfrom), dobool(withPOS)))
  msg("|}")
else:
  msg('{|class="wikitable"')
  msg("! Template !! Category !! Initial capital !! Final period !! Supports from=, from2=, ... || Supports POS=")
  for line in codecs.open(args.direcfile, "r", "utf-8"):
    direcs = line.rstrip('\n').split(',')
    template = direcs[0]
    withcap = False
    withdot = False
    withfrom = False
    withPOS = False
    cat = None
    for direc in direcs[1:]:
      if direc == "cap":
        withcap = True
      elif direc == "dot":
        withdot = True
      elif direc == "from":
        withfrom = True
      elif direc == "POS":
        withPOS = True
      elif direc.startswith("cat="):
        cat = re.sub("^cat=", "", direc)
      else:
        assert False, "Unrecognized directive %s" % direc
    def dobool(val):
      return val and "'''yes'''" or "no"
    msg("|-")
    msg("| %-50s || %-50s || %-9s || %-9s || %-9s || %-9s" % ("[[%s]]" % template,
      "<code><nowiki>LANG %s</nowiki></code>" % cat if cat else "",
      dobool(withcap), dobool(withdot), dobool(withfrom), dobool(withPOS)))
  msg("|}")
