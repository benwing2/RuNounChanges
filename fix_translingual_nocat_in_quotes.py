#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, msg, site, tname

quote_templates = ["quote-av", "quote-book", "quote-hansard",
  "quote-journal", "quote-newsgroup", "quote-song", "quote-us-patent",
  "quote-video", "quote-web", "quote-wikipedia",
  # aliases
  "quote-news", "quote-magazine",
  # misc garbage
  "quote-poem", "quote-text",
]
blib.getData()

def process_page(page, index, parsed):
  pagetitle = str(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  if blib.page_should_be_ignored(pagetitle):
    pagemsg("Skipping ignored page")
    return None, ""
      
  def hack_templates(parsed, subsectitle):
    for t in parsed.filter_templates():
      origt = str(t)
      tn = tname(t)
      if tn in quote_templates:
        if not getparam(t, "nocat"):
          continue
        if getparam(t, "lang").strip() != "en":
          continue
        notes.append("convert nocat=1 in lang=en Translingual section to termlang=mul")
        # Fetch all params.
        params = []
        for param in t.params:
          pname = str(param.name)
          if pname.strip() != "nocat":
            params.append((pname, param.value, param.showkey))
        # Erase all params.
        del t.params[:]
        # Put lang and termlang parameters.
        newline = "\n" if "\n" in str(t.name) else ""
        t.add("lang", "en" + newline, preserve_spacing=False)
        t.add("termlang", "mul" + newline, preserve_spacing=False)
        # Put remaining parameters in order.
        for name, value, showkey in params:
          t.add(name, value, showkey=showkey, preserve_spacing=False)
        pagemsg("Replaced <%s> with <%s>" % (origt, str(t)))

  pagemsg("Processing")

  text = str(page.text)
  notes = []

  sections = re.split("(^==[^=]*==\n)", text, 0, re.M)

  for j in range(2, len(sections), 2):
    m = re.search("^==(.*)==\n$", sections[j - 1])
    assert m
    langname = m.group(1)
    if langname != "Translingual":
      continue
    subsections = re.split("(^==.*==\n)", sections[j], 0, re.M)
    for k in range(2, len(subsections), 2):
      m = re.search("^===*(.*?)=*==\n$", subsections[k - 1])
      assert m
      subsectitle = m.group(1)
      parsed = blib.parse_text(subsections[k])
      hack_templates(parsed, subsectitle)
      subsections[k] = str(parsed)
    sections[j] = "".join(subsections)

  newtext = "".join(sections)
  return newtext, notes

parser = blib.create_argparser("Convert nocat=1 in Translingual quote-* templates to termlang=en")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

for cat in ["Quotations using nocat parameter"]:
  msg("Processing category %s" % cat)
  for i, page in blib.cat_articles(cat, start, end):
    blib.do_edit(page, i, process_page, save=args.save, verbose=args.verbose)
