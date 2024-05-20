#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse, unicodedata

import blib
from blib import getparam, rmparam, msg, errmsg, site, tname
from collections import defaultdict

total_qualifiers = defaultdict(int)
qualifiers_by_lang = defaultdict(lambda: defaultdict(int))

blib.getData()

def process_text_on_page(index, pagename, text):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagename, txt))
  def errandpagemsg(txt):
    errandmsg("Page %s %s: %s" % (index, pagename, txt))

  if not re.search(r"\{\{ *a(ccent)? *\|", text):
    return
  sections, sections_by_lang, section_langs = blib.split_text_into_sections(text, pagemsg)
  for j, lang in section_langs:
    sectext = sections[j]
    if not re.search(r"\{\{ *a(ccent)? *\|", sectext):
      continue
    parsed = blib.parse_text(sectext)
    for t in parsed.filter_templates():
      tn = tname(t)
      if tn in ["a", "accent"]:
        params = blib.fetch_param_chain(t, "1")
        for index, param in enumerate(params):
          param = param.strip()
          if index == 0:
            pseudo_langname = None
            pseudo_langtype = None
            if param in blib.languages_byCode:
              pseudo_langname = blib.languages_byCode[param]["canonicalName"]
              pseudo_langtype = "full"
            elif param in blib.etym_languages_byCode:
              pseudo_langname = blib.etym_languages_byCode[param]["canonicalName"]
              pseudo_langtype = "etym-only"
            if pseudo_langtype:
              if len(params) == 1:
                pagemsg("WARNING: Saw qualifier '%s' same as language code for %s language '%s' in lang section '%s' but only one qualifier: %s" % (
                  param, pseudo_langtype, pseudo_langname, lang, str(t)))
              else:
                pagemsg("WARNING: Saw qualifier '%s' same as language code for %s language '%s' in lang section '%s' and multiple qualifiers: %s" % (
                  param, pseudo_langtype, pseudo_langname, lang, str(t)))
          total_qualifiers[param] += 1
          qualifiers_by_lang[param][lang] += 1

parser = blib.create_argparser("Analyze usage of qualifiers in {{a}}/{{accent}}",
                               include_pagefile=True, include_stdin=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True)

msg("%-50s %5s: %s" % ("Qualifier", "Count", "Count-by-lang"))
msg("----------------------------------------------------")
for qualifier, count in sorted(list(total_qualifiers.items()), key=lambda x:-x[1]):
  by_lang = "; ".join("%s (%s)" % (lang, langcount)
                      for lang, langcount in sorted(list(qualifiers_by_lang[qualifier].items()), key=lambda x:-x[1]))
  msg("%-50s %5s: %s" % (qualifier, count, by_lang))
