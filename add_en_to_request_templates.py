#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site, tname

request_templates = ["rfdatek", "rfquotek"]

def process_page(page, index, parsed):
  pagetitle = str(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  if blib.page_should_be_ignored(pagetitle):
    pagemsg("Skipping ignored page")
    return None, None
      
  def hack_templates(parsed, langname):
    for t in parsed.filter_templates():
      origt = str(t)
      tn = tname(t)
      if tn in request_templates:
        if getparam(t, "lang"):
          continue
        if langname and langname != "English":
          pagemsg("WARNING: Would default to English but in %s section, skipping: %s" %
            (langname, origt))
          continue
        notes.append("add lang=en for {{%s}} with missing lang code" % tn)
        rmparam(t, "lang") # in case it's blank
        # Fetch all params.
        params = []
        for param in t.params:
          pname = str(param.name)
          params.append((pname, param.value, param.showkey))
        # Erase all params.
        del t.params[:]
        newline = "\n" if "\n" in str(t.name) else ""
        t.add("lang", "en" + newline, preserve_spacing=False)
        # Put remaining parameters in order.
        for name, value, showkey in params:
          t.add(name, value, showkey=showkey, preserve_spacing=False)
        pagemsg("Replaced <%s> with <%s>" % (origt, str(t)))

  pagemsg("Processing")

  text = str(page.text)
  notes = []

  sections = re.split("(^==[^=]*==\n)", text, 0, re.M)

  for j in range(0, len(sections), 2):
    if j == 0:
      langname = None
    else:
      m = re.search("^==(.*)==\n$", sections[j - 1])
      assert m
      langname = m.group(1)
    parsed = blib.parse_text(sections[j])
    hack_templates(parsed, langname)
    sections[j] = str(parsed)

  newtext = "".join(sections)
  return newtext, notes

parser = blib.create_argparser("Add |lang=en to request templates missing |lang",
  include_pagefile=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_page, edit=True,
  default_cats=["Language code missing/%s" % template for template in request_templates])
