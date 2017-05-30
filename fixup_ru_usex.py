#!/usr/bin/env python
# -*- coding: utf-8 -*-

# Fix up Russian usage examples:
#
# 1. Convert ux|ru|inline=y to uxi|ru.
# 2. Clean up links containing #Russian and/or two-part links that can be
#    simplified to one-part links because the two parts are identical
#    modulo accents.
# 3. Remove redundant transliteration.

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site

import rulib as ru
import runounlib as runoun

def process_page(index, page, save, verbose):
  pagetitle = unicode(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  def expand_text(tempcall):
    return blib.expand_text(tempcall, pagetitle, pagemsg, verbose)

  pagemsg("Processing")

  text = unicode(page.text)
  parsed = blib.parse(page)
  notes = []
  for t in parsed.filter_templates():
    origt = unicode(t)
    if unicode(t.name) == "ux" and getparam(t, "1") == "ru" and t.has("inline"):
      inline = getparam(t, "inline")
      if inline and inline not in ["0", "n", "no", "false"]:
        t.name = "uxi"
        notes.append("ux -> uxi and remove inline=")
      else:
        notes.append("remove unneeded inline=%s" % inline)
      rmparam(t, "inline")
    if unicode(t.name) in ["ux", "uxi"] and getparam(t, "1") == "ru":
      pval = getparam(t, "2")
      newpval = runoun.fixup_link(pval)
      if pval != newpval:
        t.add("2", newpval)
        notes.append("canonicalize two-part links in %s|ru" % unicode(t.name))
      pval = getparam(t, "tr")
      if pval:
        auto_translit = expand_text("{{xlit|ru|%s}}" % getparam(t, "2"))
        if auto_translit == pval:
          rmparam(t, "tr")
          notes.append("remove redundant translit in %s|ru" % unicode(t.name))
        else:
          pagemsg("WARNING: Non-redundant translit in %s" % unicode(t))
    newt = unicode(t)
    if origt != newt:
      pagemsg("Replaced %s with %s" % (origt, newt))

  new_text = unicode(parsed)

  if new_text != text:
    if verbose:
      pagemsg("Replacing <%s> with <%s>" % (text, new_text))
    assert notes
    comment = "; ".join(blib.group_notes(notes))
    if save:
      pagemsg("Saving with comment = %s" % comment)
      page.text = new_text
      page.save(comment=comment)
    else:
      pagemsg("Would save with comment = %s" % comment)

parser = blib.create_argparser(u"Remove inline=, converting ux|ru to uxi|ru as necessary, canonicalize two-part links and remove redundant translit")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

for i, page in blib.cat_articles("Russian lemmas", start, end):
  process_page(i, page, args.save, args.verbose)
