#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site

non_adjectival_names = [
  u"Дарвин"
]

def process_page(index, page, save, verbose):
  pagetitle = unicode(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  if pagetitle in non_adjectival_names:
    pagemsg("Skipping explicitly-specified non-adjectival name")
    return

  text = unicode(page.text)
  parsed = blib.parse(page)
  notes = []

  proper_noun_headword = None
  surname_template = None
  ru_adj11_template = None

  for t in parsed.filter_templates():
    tname = unicode(t.name)
    if tname == "ru-proper noun":
      pagemsg("WARNING: Found old ru-proper noun: %s" % unicode(t))
    elif tname == "ru-proper noun+":
      name = getparam(t, "1")
      if not (not getparam(t, 2) or getparam(t, "2") == "+" and not getparam(t, "3")):
        pagemsg("WARNING: Complex proper noun header, not sure how to handle: %s" % unicode(t))
      else:
        if re.search(u"([оеё]́?в|и́?н)$", name):
          new_fem = name + u"а"
        elif re.search(u"ый$", name):
          new_fem = re.sub(u"ый$", u"ая", name)
        elif re.search(u"о́й$", name):
          new_fem = re.sub(u"о́й$", u"а́я", name)
        elif re.search(u"[кгхчшжщ]ий$", name):
          new_fem = re.sub(u"ий$", u"ая", name)
        else:
          new_fem = None
          if re.search(u"ий$", name):
            pagemsg(u"WARNING: Name ending in non-velar/hushing consonant + -ий: %s" % unicode(t))
        if new_fem:
          if getparam(t, "2") != "+":
            pagemsg("WARNING: Adjectival name not correctly conjugated in headword, fixing: %s" % unicode(t))
            origt = unicode(t)
            t.add("2", "+", before="a")
            notes.append("add adjectival + to %s" % name)
            pagemsg("Replacing %s with %s" % (origt, unicode(t)))
          existing_fem = getparam(t, "f")
          if existing_fem:
            if new_fem != existing_fem:
              pagemsg("WARNING: New feminine %s different from existing feminine %s, not changing: %s" %
                  (new_fem, existing_fem, unicode(t)))
          else:
            origt = unicode(t)
            t.add("f", new_fem)
            notes.append("add feminine %s to %s" % (new_fem, name))
            pagemsg("Replacing %s with %s" % (origt, unicode(t)))

  newtext = unicode(parsed)

  if newtext != text:
    if verbose:
      pagemsg("Replacing <<%s>> with <<%s>>" % (text, newtext))
    comment = "; ".join(notes)
    if save:
      pagemsg("Saving with comment = %s" % comment)
      page.text = newtext
      page.save(comment=comment)
    else:
      pagemsg("Would save with comment = %s" % comment)
  else:
    pagemsg("Skipping")

parser = blib.create_argparser("Add feminines to Russian proper names")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

for cat in ["Russian surnames"]:
  msg("Processing category: %s" % cat)
  for i, page in blib.cat_articles(cat, start, end):
    process_page(i, page, args.save, args.verbose)
