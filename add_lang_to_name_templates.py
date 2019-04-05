#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site, tname

borrowed_langs = {}

name_templates = ["given name", "surname"]
blib.getData()

def process_page(page, index, parsed):
  pagetitle = unicode(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  if blib.page_should_be_ignored(pagetitle):
    pagemsg("Skipping ignored page")
    return None, ""
      
  def hack_templates(parsed, langname):
    if langname not in blib.languages_byCanonicalName:
      langnamecode = None
    else:
      langnamecode = blib.languages_byCanonicalName[langname]["code"]

    for t in parsed.filter_templates():
      origt = unicode(t)
      tn = tname(t)
      if tn in name_templates:
        if getparam(t, "lang"):
          continue
        if langname != "English":
          pagemsg("WARNING: Would default to English but in %s section: %s" %
            (langname, origt))
        if not langnamecode:
          pagemsg("WARNING: Unrecognized language %s, unable to add language to %s" % (langname, origt))
          continue
        notes.append("infer lang=%s for {{%s}} based on section it's in" % (langnamecode, tn))
        # Fetch all params.
        params = []
        for param in t.params:
          pname = unicode(param.name)
          params.append((pname, param.value, param.showkey))
        # Erase all params.
        del t.params[:]
        newline = "\n" if "\n" in unicode(t.name) else ""
        t.add("lang", langnamecode + newline, preserve_spacing=False)
        # Put remaining parameters in order.
        for name, value, showkey in params:
          t.add(name, value, showkey=showkey, preserve_spacing=False)
        pagemsg("Replaced <%s> with <%s>" % (origt, unicode(t)))

  pagemsg("Processing")

  text = unicode(page.text)
  notes = []

  sections = re.split("(^==[^=]*==\n)", text, 0, re.M)

  for j in xrange(2, len(sections), 2):
    m = re.search("^==(.*)==\n$", sections[j - 1])
    assert m
    langname = m.group(1)
    parsed = blib.parse_text(sections[j])
    hack_templates(parsed, langname)
    sections[j] = unicode(parsed)

  newtext = "".join(sections)
  return newtext, notes

parser = blib.create_argparser("Add language to name templates, based on the section it's within")
parser.add_argument('--pagefile', help="File containing pages to fix.")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

if args.pagefile:
  lines = [x.strip() for x in codecs.open(args.pagefile, "r", "utf-8")]
  for i, page in blib.iter_items(lines, start, end):
    blib.do_edit(pywikibot.Page(site, page), i, process_page, save=args.save,
        verbose=args.verbose)
else:
  for ref in name_templates:
    msg("Processing references to Template:%s" % ref)
    for i, page in blib.references("Template:%s" % ref, start, end):
      blib.do_edit(page, i, process_page, save=args.save, verbose=args.verbose)
