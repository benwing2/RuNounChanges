#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site

import rulib

def process_page(index, page, save, verbose):
  pagetitle = unicode(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  if "-" not in pagetitle:
    pagemsg("Skipping, no dash in title")
    return

  text = unicode(page.text)
  parsed = blib.parse(page)
  notes = []
  for t in parsed.filter_templates():
    origt = unicode(t)

    if unicode(t.name) in ["ru-IPA"]:
      pron = getparam(t, "1") or getparam(t, "phon")
      if not re.search(u"[̀ѐЀѝЍ]", pron):
        pagemsg("WARNING: No secondary accent in pron %s" % pron)

    if unicode(t.name) in ["ru-adj"]:
      head = getparam(t, "1")
      if head and "[[" not in head:
        def add_links(m):
          prefix = m.group(1)
          if re.search(u"[гкх]о$", prefix):
            first = prefix[:-1] + u"ий"
          else:
            first = prefix[:-1] + u"ый"
          return u"[[%s|%s]]-[[%s]]" % (rulib.remove_accents(first), prefix, m.group(2))
        t.add("1", re.sub(u"^(.*?о)-([^-]*)$", add_links, head))
      notes.append("add links to two-part adjective")
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

parser = blib.create_argparser(u"Add links to two-part adjectives")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

for index, page in blib.cat_articles("Russian adjectives", start, end):
    process_page(index, page, args.save, args.verbose)
