#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, tname, pname, msg, site

def process_text_on_page(index, pagetitle, text):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
  def expand_text(tempcall):
    return blib.expand_text(tempcall, pagetitle, pagemsg, args.verbose)

  notes = []

  parsed = blib.parse_text(text)

  for t in parsed.filter_templates():
    def getp(param):
      return getparam(t, param)
    tn = tname(t)
    if tn in ["auto cat", "autocat"] and getp("setwiki"):
      origt = str(t)
      setwiki = getp("setwiki")
      hacked_t = list(blib.parse_text(origt).filter_templates())[0]
      rmparam(hacked_t, "setwiki")
      auto_cat_text = expand_text(str(hacked_t))
      m = re.search(r"'''English Wikipedia''' has an article on:.*?'''\[\[w:(.*?)\|", auto_cat_text, re.S)
      if m:
        default_wikipedia = m.group(1)
        pagemsg("Found default Wikipedia article: %s" % default_wikipedia)
        if default_wikipedia == setwiki:
          pagemsg("Removing setwiki=%s, same as default Wikipedia article" % setwiki)
          rmparam(t, "setwiki")
          notes.append("remove redundant setwiki= from {{%s}}" % tn)
        else:
          pagemsg("WARNING: Not removing setwiki=%s, different from default Wikipedia article '%s'" % (
            setwiki, default_wikipedia))
  text = str(parsed)
  return text, notes

parser = blib.create_argparser("Remove redundant setwiki= links from {{auto cat}} language categories", include_pagefile=True, include_stdin=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True,
  default_cats=["All languages"])
