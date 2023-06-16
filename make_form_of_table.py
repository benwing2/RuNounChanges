#!/usr/bin/env python3
# -*- coding: utf-8 -*-

from blib import msg
import pywikibot, re, sys, codecs, argparse

import form_of_templates

parser = argparse.ArgumentParser(description="Generate table documenting form-of template variants.")
parser.add_argument('--direcfile', help="File containing directives.")
args = parser.parse_args()

if not args.direcfile:
  msg('{|class="wikitable"')
  msg("! Template !! Aliases !! Category !! Takes inflection tags !! Initial capital !! Final period !! Supports from=, from2=, ... || Supports p=/POS=")
  for template, props in form_of_templates.form_of_templates:
    aliases = props.get("aliases", [])
    withtags = props.get("withtags", False)
    withcap = props.get("withcap", False)
    withdot = props.get("withdot", False)
    withfrom = props.get("withfrom", False)
    withPOS = props.get("withPOS", False)
    cats = props.get("cat", [])
    if type(cats) is not list:
      cats = [cats]
    def dobool(val):
      return val and "'''yes'''" or "no"
    msg("|-")
    msg("| %-80s || %-50s || %-50s || %-9s || %-9s || %-9s || %-9s || %-9s" % (
      "[[Template:%s|%s]]" % (template, template),
      ", ".join("[[Template:%s|%s]]" % (alias, alias) for alias in aliases),
      ", ".join("<code><nowiki>LANG %s</nowiki></code>" % cat for cat in cats),
      dobool(withtags), dobool(withcap), dobool(withdot), dobool(withfrom), dobool(withPOS)))
  msg("|}")
else:
  msg('{|class="wikitable"')
  msg("! Template !! Category !! Takes inflection tags !! Initial capital !! Final period !! Supports from=, from2=, ... || Supports p=/POS=")
  for line in codecs.open(args.direcfile, "r", "utf-8"):
    direcs = line.rstrip('\n').split(',')
    template = direcs[0]
    withtags = False
    withcap = False
    withdot = False
    withfrom = False
    withPOS = False
    cat = None
    for direc in direcs[1:]:
      if direc == "tags":
        withtags = True
      elif direc == "cap":
        withcap = True
      elif direc == "dot":
        withdot = True
      elif direc == "from":
        withfrom = True
      elif direc == "POS":
        withPOS = True
      elif direc.startswith("cat="):
        cat = re.sub("^cat=", "", direc).split(",")
      else:
        assert False, "Unrecognized directive %s" % direc
    def dobool(val):
      return val and "'''yes'''" or "no"
    msg("|-")
    msg("| %-50s || %-50s || %-9s || %-9s || %-9s || %-9s || %-9s" % ("[[%s]]" % template,
      ", ".join("<code><nowiki>LANG %s</nowiki></code>" % cat for cat in cats),
      dobool(withtags), dobool(withcap), dobool(withdot), dobool(withfrom), dobool(withPOS)))
  msg("|}")
