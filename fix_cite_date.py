#!/usr/bin/env python
# -*- coding: utf-8 -*-

# Replace dates of the form "1 January, 2012" with "1 January 2012"
# (remove the comma) in quotation/citation templates.

import pywikibot, re, sys, codecs, argparse
import mwparserfromhell as mw

import blib
from blib import getparam, rmparam, set_template_name, msg, errmsg, site

import rulib

replace_templates = [
    "cite-book", "cite-journal", "cite-newsgroup", "cite-video game",
    "cite-web",
    "quote-book", "quote-hansard", "quote-journal", "quote-newsgroup",
    "quote-song", "quote-us-patent", "quote-video", "quote-web",
    "quote-wikipedia"
    ]

months = ["January", "February", "March", "April", "May", "June", "July",
    "August", "September", "October", "November", "December",
    "Jan", "Feb", "Mar", "Apr", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov",
    "Dec"]

month_re = "(?:%s)" % "|".join(months)

def process_page(index, page, save, verbose):
  pagetitle = unicode(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  if not page.exists():
    pagemsg("WARNING: Page doesn't exist")
    return

  if ":" in pagetitle and not re.search(
      "^(Citations|Appendix|Reconstruction|Transwiki|Talk|Wiktionary|[A-Za-z]+ talk):", pagetitle):
    pagemsg("WARNING: Colon in page title and not a recognized namespace to include, skipping page")
    return

  text = unicode(page.text)
  notes = []

  parsed = blib.parse_text(text)
  for t in parsed.filter_templates():
    tname = unicode(t.name)
    origt = unicode(t)
    if tname.strip() in replace_templates:
      date = getparam(t, "date")
      if date.strip():
        newdate = re.sub(r"^(\s*[0-9]+\s+%s\s*),(\s*[0-9]+\s*)$" % month_re,
            r"\1\2", date)
        if date != newdate:
          # We do this instead of t.add() because if there's a final newline,
          # it will appear in the value but t.add() will try to preserve the
          # newline separately and you'll get two newlines.
          t.get("date").value = newdate
          pagemsg(("Replacing %s with %s" % (origt, unicode(t))).replace("\n", r"\n"))
          notes.append("fix date in %s" % tname.strip())

  newtext = unicode(parsed)
  if text != newtext:
    if verbose:
      pagemsg("Replacing <%s> with <%s>" % (text, newtext))
    assert notes
    comment = "; ".join(blib.group_notes(notes))
    if save:
      pagemsg("Saving with comment = %s" % comment)
      page.text = newtext
      page.save(comment=comment)
    else:
      pagemsg("Would save with comment = %s" % comment)

if __name__ == "__main__":
  parser = blib.create_argparser("Fix date in cite/quote templates")
  args = parser.parse_args()
  start, end = blib.parse_start_end(args.start, args.end)

  for template in replace_templates:
    msg("Processing references to Template:%s" % template)
    errmsg("Processing references to Template:%s" % template)
    for i, page in blib.references("Template:%s" % template, start, end,
        includelinks=True):
      process_page(i, page, args.save, args.verbose)
