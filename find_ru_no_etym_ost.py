#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, msg, errandmsg, site, tname

import rulib

nouns = []

def process_text_on_page(index, pagetitle, text):
  global args
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
  def errandpagemsg(txt):
    errandmsg("Page %s %s: %s" % (index, pagetitle, txt))

  notes = []

  if not re.search("[иы]й$", pagetitle):
    pagemsg("Skipping adjective not in -ый or -ий")
    return

  noun = re.sub("[иы]й$", "ость", pagetitle)
  if noun not in nouns:
    return

  if rulib.check_for_alt_yo_terms(text, pagemsg):
    return

  parsed = blib.parse_text(text)

  for t in parsed.filter_templates():
    tn = tname(t)
    if tn == "ru-adj":
      heads = blib.fetch_param_chain(t, "1", "head", pagetitle)
      if len(heads) > 1:
        pagemsg("Skipping adjective with multiple heads: %s" % ",".join(heads))
        continue
      noun_page = pywikibot.Page(site, noun)
      noun_text = blib.safe_page_text(page, errandpagemsg)
      if not noun_text:
        pagemsg("Page %s doesn't exist or is empty" % noun)
        continue
      nounsection = blib.find_lang_section_from_text(noun_text, "Russian", pagemsg)
      if not nounsection:
        pagemsg("Couldn't find Russian section for %s" % noun)
        continue
      if "==Etymology" in nounsection:
        pagemsg("Noun %s already has etymology" % noun)
        continue
      tr = getparam(t, "tr")
      if tr:
        msg("%s %s+tr1=%s+-ость no-etym" % (noun, heads[0], tr))
      else:
        msg("%s %s+-ость no-etym" % (noun, heads[0]))

# Pages specified using --pages or --pagefile may have accents, which will be stripped.
parser = blib.create_argparser("Try to construct etymologies of nouns in -ость from adjectives",
    include_pagefile=True, include_stdin=True, canonicalize_pagename=rulib.remove_accents)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

for i, page in blib.cat_articles("Russian nouns"):
  nouns.append(str(page.title()))

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True,
  default_cats=["Russian adjectives"])
