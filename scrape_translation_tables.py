#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, msg, site, tname

def process_page(page, index):
  pagetitle = str(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  seen_trans = [pagetitle]
  parsed = blib.parse(page)
  for t in parsed.filter_templates():
    tn = tname(t)
    if tn in ["t", "t+", "t-", "t+check", "t-check"]:
      trans = blib.remove_links(getparam(t, "2"))
      if trans and trans not in seen_trans:
        seen_trans.append(trans)
  for trans in seen_trans:
    def pagemsg_with_trans(txt):
      pagemsg("%s: %s" % (trans, txt))
    if blib.safe_page_exists(pywikibot.Page(site, trans), pagemsg_with_trans):
      msg("Page %s %s: Found existing translation for %s" % (index, trans, pagetitle))

parser = blib.create_argparser("Find page-existing translations for terms", include_pagefile=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_page)
