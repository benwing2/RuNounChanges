#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, tname, pname, msg, site

import belib

def process_page(page, index, parsed):
  pagetitle = str(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  notes = []

  pagemsg("Processing")
  text = str(page.text)

  retval = blib.find_modifiable_lang_section(text, "Hungarian", pagemsg)
  if retval is None:
    pagemsg("WARNING: Couldn't find Hungarian section")
    return
  sections, j, secbody, sectail, has_non_lang = retval
  if "==Alternative forms==" in secbody:
    pagemsg("WARNING: Skipping page with 'Alternative forms' section")
    return

  parsed = blib.parse_text(secbody)
  for t in parsed.filter_templates():
    origt = str(t)
    tn = tname(t)
    if tn in ["compound", "affix", "af"] and getparam(t, "1") == "hu" and not getparam(t, "pos"):
      t.add("pos", "noun")
    if origt != str(t):
      pagemsg("Replaced %s with %s" % (origt, str(t)))
      notes.append("add pos=noun to {{%s|hu}}" % tn)
  sections[j] = str(parsed) + sectail
  text = "".join(sections)
  return text, notes

parser = blib.create_argparser(u"Add pos=noun to Hungarian compound words",
    include_pagefile=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_page,
    default_cats=["Hungarian compound words"], edit=True)
