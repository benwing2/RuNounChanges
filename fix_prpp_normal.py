#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, tname, msg, site

def process_page(index, page, save, verbose):
  pagetitle = unicode(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  text = unicode(page.text)
  parsed = blib.parse(page)
  notes = []
  for t in parsed.filter_templates():
    origt = unicode(t)
    if tname(t) == "ru-conj" and getparam(t, 1) == "impf":
      t.add("prpp", "+")
      notes.append("added |prpp=+ to imperfective %s" % pagetitle)
    newt = unicode(t)
    if origt != newt:
      pagemsg("Replaced %s with %s" % (origt, newt))

  new_text = unicode(parsed)

  if new_text != text:
    if verbose:
      pagemsg("Replacing <%s> with <%s>" % (text, new_text))
    assert notes
    comment = "; ".join(notes)
    if save:
      pagemsg("Saving with comment = %s" % comment)
      page.text = new_text
      page.save(comment=comment)
    else:
      pagemsg("Would save with comment = %s" % comment)

parser = blib.create_argparser(u"Find Russian terms with bad past passive participles")
parser.add_argument('--fix-verbs', help="File containing verbs to fix.")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

fixverbs = [x.strip() for x in codecs.open(args.fix_verbs, "r", "utf-8")]
for i, page in blib.iter_items(fixverbs, start, end):
  process_page(i, pywikibot.Page(site, page), args.save, args.verbose)
