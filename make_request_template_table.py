#!/usr/bin/env python3
# -*- coding: utf-8 -*-

from blib import getparam, rmparam, msg, errmsg, site
import pywikibot, re, sys, codecs, argparse

import request_templates

parser = argparse.ArgumentParser(description="Generate table documenting request template variants.")
parser.add_argument('--direcfile', help="File containing directives.")
args = parser.parse_args()

langparam_code_to_desc = {
  "no": "no",
  "req": "'''required'''",
  "defund": "defaults to <code>und</code>",
  "nodef": "non-language-specific behavior if omitted",
  "dep": "deprecated",
  "depwarn": "deprecated, warning issued",
}

msg('{|class="wikitable"')
msg("! Template !! Aliases !! Description !! Categories !! Lang code in 1= !! Lang code in lang=")
for template, props in sorted(request_templates.request_templates, key=lambda x:x[0]):
  aliases = props.get("aliases", [])
  desc = props.get("desc", "Unknown")
  cat = props.get("cat", [])
  lang1 = props.get("lang1", "no")
  langlang = props.get("langlang", "no")
  def docat(val):
    if type(val) is tuple:
      cat, cond = val
      return "* <code><nowiki>%s</nowiki></code><br />(<nowiki>%s</nowiki>)\n" % (cat, cond)
    else:
      return "* <code><nowiki>%s</nowiki></code>\n" % val
  msg("|-")
  msg("| %-50s || %-50s || %-50s ||\n%-50s|| %-40s || %-40s" % (
    "[[Template:%s|%s]]" % (template, template),
    ", ".join("[[Template:%s|%s]]" % (alias, alias) for alias in aliases),
    desc, "".join(docat(c) for c in cat),
    langparam_code_to_desc[lang1], langparam_code_to_desc[langlang]))
msg("|}")
