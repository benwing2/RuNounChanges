#!/usr/bin/env python
# -*- coding: utf-8 -*-

# Rename declension templates for irregular and old (pre-reform) nouns as follows:
# 
# {{temp|ru-adj-table}} -> {{temp|ru-decl-adj-irreg}}
# {{temp|ru-decl-noun}} -> {{temp|ru-decl-noun-irreg}}
# {{temp|ru-decl-noun-unc}} -> {{temp|ru-decl-noun-irreg-unc|n=sg}} {{i|displays "singular" at the top of the table}}
# {{temp|ru-decl-noun-pl}} -> {{temp|ru-decl-noun-irreg-unc|n=pl}} {{i|displays "singular" at the top of the table}}
# [no equivalent] -> {{temp|ru-decl-noun-irreg-unc|n=none}} {{i|doesn't display either "singular" or "plural" at the top of the table}}
# {{temp|ru-noun-old}} -> {{temp|ru-noun-table|old=1}}
# {{temp|ru-adj-old}} -> {{temp|ru-decl-adj|old=1}}

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, tname, msg, site

def process_page(index, page, save, verbose):
  pagetitle = unicode(page.title())
  subpagetitle = re.sub("^.*:", "", pagetitle)
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  if ":" in pagetitle:
    pagemsg("WARNING: Colon in page title, skipping page")
    return

  text = unicode(page.text)
  notes = []

  parsed = blib.parse_text(text)
  for t in parsed.filter_templates():
    if tname(t) == "ru-adj-table":
      blib.set_template_name(t, "ru-decl-adj-irreg")
      notes.append("renamed ru-adj-table -> ru-decl-adj-irreg")
    elif tname(t) == "ru-decl-noun":
      blib.set_template_name(t, "ru-decl-noun-irreg")
      notes.append("renamed ru-decl-noun -> ru-decl-noun-irreg")
    else:
      newname = None
      newarg = None
      newval = None
      if tname(t) == "ru-decl-noun-unc":
        newname = "ru-decl-noun-irreg-unc"
        newarg = "n"
        newval = "none" if "{{head|ru|numeral" else "sg"
      elif tname(t) == "ru-decl-noun-pl":
        newname = "ru-decl-noun-irreg-unc"
        newarg = "n"
        newval = "pl"
      elif tname(t) == "ru-noun-old":
        newname = "ru-noun-table"
        newarg = "old"
        newval = "1"
      elif tname(t) == "ru-adj-old":
        newname = "ru-decl-adj"
        newarg = "old"
        newval = "1"
      if newname:
        notes.append("renamed %s -> %s|%s=%s" % (tname(t), newname, newarg, newval))
        has_newline = "" #"\n" if "\n" in unicode(t.name) else ""
        t.name = newname
        if t.has("1"):
          before = "1"
        elif t.has("nom_m"):
          before = "nom_m"
        else:
          pagemsg("WARNING: Don't know where to insert %s=%s, inserting at end: %s" % (
            newarg, newval, unicode(t)))
          before = None
        if before:
          t.add(newarg, newval + has_newline, before=before)
        else:
          t.add(newarg, newval + has_newline)

  newtext = unicode(parsed)

  if newtext != text:
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

parser = blib.create_argparser(u"Rename declension templates for irregular and old (pre-reform) nouns")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

for template in ["ru-adj-table", "ru-decl-noun", "ru-decl-noun-unc",
  "ru-decl-noun-pl", "ru-noun-old", "ru-adj-old"]:
  msg("Processing references to Template:%s" % template)
  for i, page in blib.references("Template:%s" % template, start, end):
    process_page(i, page, args.save, args.verbose)
