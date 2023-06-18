#!/usr/bin/env python3
# -*- coding: utf-8 -*-

# Replace quote-poem -> quote-book and change params.
# Replace quote-magazine and quote-news -> quote-journal.
# Replace quote-Don Quixote -> RQ:Don Quixote.

import pywikibot, re, sys, argparse
import mwparserfromhell as mw

import blib
from blib import getparam, rmparam, set_template_name, msg, errmsg, site, tname

def process_page(page, index, parsed):
  pagetitle = str(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  if ":" in pagetitle and not re.search(
      "^(Citations|Appendix|Reconstruction|Transwiki|Talk|Wiktionary|[A-Za-z]+ talk):", pagetitle):
    pagemsg("WARNING: Colon in page title and not a recognized namespace to include, skipping page")
    return None, None

  text = str(page.text)
  notes = []

  def move_param(t, fr, to, frob_from=None):
    if t.has(fr):
      oldval = getparam(t, fr)
      if not oldval.strip():
        rmparam(t, fr)
        pagemsg("Removing blank param %s" % fr)
        return
      if frob_from:
        newval = frob_from(oldval)
        if not newval or not newval.strip():
          return
      else:
        newval = oldval

      if getparam(t, to).strip():
          pagemsg("WARNING: Would replace %s= -> %s= but %s= is already present: %s"
              % (fr, to, to, str(t)))
      elif oldval != newval:
        rmparam(t, to) # in case of blank param
        # If either old or new name is a number, use remove/add to automatically set the
        # showkey value properly; else it's safe to just change the name of the param,
        # which will preserve its location.
        if re.search("^[0-9]+$", fr) or re.search("^[0-9]+$", to):
          rmparam(t, fr)
          t.add(to, newval)
        else:
          tfr = t.get(fr)
          tfr.name = to
          tfr.value = newval
        pagemsg("%s=%s -> %s=%s" % (fr, oldval.replace("\n", r"\n"), to,
          newval.replace("\n", r"\n")))
      else:
        rmparam(t, to) # in case of blank param
        # See comment above.
        if re.search("^[0-9]+$", fr) or re.search("^[0-9]+$", to):
          rmparam(t, fr)
          t.add(to, newval)
        else:
          t.get(fr).name = to
        pagemsg("%s -> %s" % (fr, to))

  for t in parsed.filter_templates():
    tn = tname(t)
    origt = str(t)
    changed = False
    if tn in ["quote-magazine", "quote-news"]:
      blib.set_template_name(t, "quote-journal")
      notes.append("%s -> quote-journal" % tn)
      changed = True
    if tn in ["quote-Don Quixote"]:
      blib.set_template_name(t, "RQ:Don Quixote")
      notes.append("quote-Don Quixote -> RQ:Don Quixote")
      changed = True
    if tn == "quote-poem":
      move_param(t, "title", "chapter")
      move_param(t, "poem", "chapter")
      move_param(t, "work", "title")
      move_param(t, "7", "t")
      move_param(t, "6", "text")
      move_param(t, "5", "url")
      move_param(t, "4", "title")
      move_param(t, "3", "chapter")
      blib.set_template_name(t, "quote-book")
      changed = origt != str(t)
      if changed:
        notes.append("quote-poem -> quote-book with fixed params")

    if changed:
      pagemsg("Replacing %s with %s" % (origt, str(t)))

  return parsed, notes

parser = blib.create_argparser("quote-poem -> quote-book with changed params; quote-magazine/quote-news -> quote-journal; quote-Don Quixote -> RQ:Don Quixote")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

for template in ["quote-poem", "quote-magazine", "quote-news", "quote-Don Quixote"]:
  msg("Processing references to Template:%s" % template)
  errmsg("Processing references to Template:%s" % template)
  for i, page in blib.references("Template:%s" % template, start, end,
      includelinks=True):
    blib.do_edit(page, i, process_page, save=args.save, verbose=args.verbose)
