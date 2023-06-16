#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site, tname

import rulib

quote_templates = ["quote-book", "quote-hansard", "quote-journal",
  "quote-news", "quote-newsgroup", "quote-song", "quote-us-patent",
  "quote-video", "quote-web", "quote-wikipedia"]

quote_templates_text_param_6 = ["quote-book", "quote-newsgroup", "quote-song",
  "quote-us-patent", "quote-web"]
quote_templates_text_param_7 = ["quote-journal", "quote-news", "quote-video"]
quote_templates_text_param_8 = ["quote-hansard"]

def process_page(page, index, parsed):
  pagetitle = str(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  text = str(page.text)
  newtext = text
  parsed = blib.parse(page)
  notes = []
  for t in parsed.filter_templates():
    origt = str(t)
    tn = tname(t)
    # pagemsg("tn=%s" % str(tn))
    if tn in quote_templates:
      text_param = None
      if tn in quote_templates_text_param_6:
        text_param = "6"
      elif tn in quote_templates_text_param_7:
        text_param = "7"
      elif tn in quote_templates_text_param_8:
        text_param = "8"
      textval = ""
      if text_param:
        textval = getparam(t, text_param)
      if not textval:
        text_param = "text"
        textval = getparam(t, text_param)
      if not textval:
        text_param = "passage"
        textval = getparam(t, text_param)
      # pagemsg("%s=%s" % (text_param, textval))
      textval = textval.strip()
      if re.search(r"^\{\{ja-usex\|.*\}\}$", textval, re.S):
        rmparam(t, text_param)
        newnewtext = re.sub(r"(\n#+\*) *%s" % re.escape(origt),
          r"\1 %s\1: %s" % (str(t), textval), newtext)
        if newtext == newnewtext:
          pagemsg("WARNING: Can't find quote template in text: %s" % origt)
        else:
          newtext = newnewtext
          notes.append("move ja-usex call outside of %s call" % tn)
      elif "{{ja-usex|" in textval:
        pagemsg("WARNING: Found {{ja-usex| embedded in quote text but not whole param: %s" %
            origt)

  return newtext, notes

parser = blib.create_argparser("Move ja-usex calls outside of quote-*",
  include_pagefile=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_page, edit=True,
  default_refs=["Template:ja-usex"])
