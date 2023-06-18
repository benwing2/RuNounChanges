#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse
from collections import defaultdict

import blib
from blib import getparam, rmparam, msg, errandmsg, site, tname

def process_text_on_page(index, pagetitle, text):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  #pagemsg("Processing")

  if blib.page_should_be_ignored(pagetitle):
    #pagemsg("WARNING: Page should be ignored")
    return

  if "inflection of" not in text:
    return

  parsed = blib.parse_text(text)

  templates_to_replace = []

  for t in parsed.filter_templates():
    origt = str(t)
    tn = tname(t)

    if tn in ["inflection of"]:
      if getparam(t, "lang"):
        term_param = 1
      else:
        term_param = 2
      for param in t.params:
        pname = str(param.name).strip()
        pval = str(param.value).strip()
        if re.search("^[0-9]+$", pname):
          if int(pname) >= term_param + 2:
            if pval in ["and", "or", ";", ";<!--\n-->"] or "/" in pval or "," in pval:
              pagemsg("Found template: %s" % origt)
              break

  return

parser = blib.create_argparser("Find 'inflection of' tags with |and|, |or|, |;|, comma or slash in them")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.parse_dump(sys.stdin, process_text_on_page, startprefix=start, endprefix=end)
