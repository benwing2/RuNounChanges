#!/usr/bin/env python
# -*- coding: utf-8 -*-

# Go through all the pages in 'Category:R:vep:UVVV with red link' looking
# for {{R:vep:UVVV}} templates, and check the pages in those templates to
# see if they exist.

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site

def process_page(page, index):
  pagetitle = str(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  parsed = blib.parse(page)
  for t in parsed.filter_templates():
    if str(t.name) == "R:vep:UVVV":
      refpages = blib.fetch_param_chain(t, "1", "")
      for refpage in refpages:
        if not pywikibot.Page(site, refpage).exists():
          pagemsg("Page [[%s]] does not exist" % refpage)

parser = blib.create_argparser(u"Find red links in pages in Category:R:vep:UVVV with red link",
  include_pagefile=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_page,
    default_cats=["R:vep:UVVV with red link"])
