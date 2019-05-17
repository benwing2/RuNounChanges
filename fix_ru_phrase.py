#!/usr/bin/env python
# -*- coding: utf-8 -*-

# Fix ru-phrase templates to use 1= instead of head=.

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site

def process_page(index, page, save, verbose):
  pagetitle = unicode(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  text = unicode(page.text)
  parsed = blib.parse(page)
  notes = []
  for t in parsed.filter_templates():
    if unicode(t.name) == "ru-phrase":
      if t.has("tr"):
        pagemsg("WARNING: Has tr=: %s" % unicode(t))
      if t.has("head"):
        if t.has("1"):
          pagemsg("WARNING: Has both head= and 1=: %s" % unicode(t))
        else:
          notes.append("ru-phrase: convert head= to 1=")
          origt = unicode(t)
          head = getparam(t, "head")
          rmparam(t, "head")
          tr = getparam(t, "tr")
          rmparam(t, "tr")
          t.add("1", head)
          if tr:
            t.add("tr", tr)
          pagemsg("Replacing %s with %s" % (origt, unicode(t)))

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

parser = blib.create_argparser(u"Fix ru-phrase templates to use 1= instead of head=")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

for i, page in blib.references("Template:ru-phrase", start, end):
  process_page(i, page, args.save, args.verbose)
