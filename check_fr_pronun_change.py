#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, tname, pname, msg, site

def process_page(page, index):
  global args
  pagetitle = unicode(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
  def expand_text(tempcall):
    return blib.expand_text(tempcall, pagetitle, pagemsg, args.verbose)

  parsed = blib.parse(page)

  for t in parsed.filter_templates():
    tn = tname(t)
    if tn == "fr-IPA":
      posval = getparam(t, "pos")
      pos_arg = "|pos=%s" % posval if posval else ""
      max_arg = 1
      for pronarg in range(2, 30):
        if getparam(t, str(pronarg)):
          max_arg = pronarg
      for pronarg in range(1, max_arg + 1):
        pronval = getparam(t, str(pronarg)) or pagetitle
        pron = expand_text("{{#invoke:fr-pron|show|%s%s|check_new_module=1}}" % (pronval, pos_arg))
        if " || " in pron:
          pronold, pronnew = pron.split(" || ")
          pagemsg("WARNING: {{fr-IPA|%s%s}} == %s in old but %s in new" %
              (pronval, pos_arg, pronold, pronnew))
        else:
          pagemsg("{{fr-IPA|%s%s}} == %s in both old and new" % (pronval, pos_arg, pron))

parser = blib.create_argparser("Check for change in {{fr-IPA}}", include_pagefile=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_page, default_refs=["Template:fr-IPA"])
