#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, msg, site

import rulib

def process_page(page, index, parsed):
  pagetitle = str(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  text = str(page.text)
  newtext = text

  newtext = re.sub(r"\{\{ru-noun form\|[^|=]*\|([^|=]*)\|tr=.*?\}\}\n\n# \{\{alternative (?:form|spelling) of\|(.*?)\|lang=ru\}\}\n\n\[\[Category:Russian spellings with е instead of ё\]\]",
      r"{{ru-pos-alt-ё|\2|noun form|g=\1}}", newtext)
  newtext = re.sub(r"\{\{head\|ru\|([^|=]*)\|.*?g=(.*?)(?:\|.*?)?\}\}\n\n# \{\{alternative (?:form|spelling) of\|(.*?)\|lang=ru\}\}\n\n\[\[Category:Russian spellings with е instead of ё\]\]",
      r"{{ru-pos-alt-ё|\3|\1|g=\2}}", newtext)

  if newtext == text and u"[[Category:Russian spellings with е instead of ё]]" in text:
    pagemsg(u"WARNING: Unable to match manual alt-ё form")

  return newtext, u"Replaced manual alt-ё specification with {{ru-pos-alt-ё}}"

parser = blib.create_argparser(u"Replace manual alt-ё specification with {{ru-pos-alt-ё}}",
  include_pagefile=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_page, edit=True,
  default_cats=[u"Russian spellings with е instead of ё"])
