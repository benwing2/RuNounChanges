#!/usr/bin/env python
# -*- coding: utf-8 -*-

# Fix up noun forms, using {{ru-noun form}} instead of {{head|ru|noun form}}

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site

import rulib as ru
import runounlib as runoun

def getrmparam(t, param):
  value = getparam(t, param)
  rmparam(t, param)
  return value

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
    origt = unicode(t)
    if unicode(t.name) == "head" and getparam(t, "1") == "ru" and getparam(t, "2") == "noun form":
      if getparam(t, "3"):
        pagemsg("WARNING: Found param 3 in {{head|ru|noun form}}: %s" %
            unicode(t))
        return
      rmparam(t, "1")
      rmparam(t, "2")
      head = getrmparam(t, "head")
      head2 = getrmparam(t, "head2")
      tr = getrmparam(t, "tr")
      tr2 = getrmparam(t, "tr2")
      g = getrmparam(t, "g")
      g2 = getrmparam(t, "g2")
      g3 = getrmparam(t, "g3")
      if len(t.params) > 0:
        pagemsg("WARNING: Extra params in noun form template: %s" %
            unicode(t))
        return
      t.name = "ru-noun form"
      if head or g:
        t.add("1", head)
      if head2:
        t.add("head2", head2)
      if g:
        t.add("2", g)
      if g2:
        t.add("g2", g2)
      if g3:
        t.add("g3", g3)
      if tr:
        t.add("tr", tr)
      if tr2:
        t.add("tr2", tr2)
      newt = unicode(t)
      if origt != newt:
        pagemsg("Replaced %s with %s" % (origt, newt))
        notes.append("convert {{head|ru|noun form}} to {{ru-noun form}}")
    elif unicode(t.name) == "ru-noun form":
      if getparam(t, "head") and getparam(t, "1"):
        pagemsg("WARNING: ru-noun form has both params 1= and head=: %s" %
            unicode(t))
        return
      if getparam(t, "g") and getparam(t, "2"):
        pagemsg("WARNING: ru-noun form has both params 2= and g=: %s" %
            unicode(t))
        return
      head = getrmparam(t, "1") or getrmparam(t, "head")
      head2 = getrmparam(t, "head2")
      tr = getrmparam(t, "tr")
      tr2 = getrmparam(t, "tr2")
      g = getrmparam(t, "2") or getrmparam(t, "g")
      g2 = getrmparam(t, "g2")
      g3 = getrmparam(t, "g3")
      if len(t.params) > 0:
        pagemsg("WARNING: Extra params in noun form template: %s" %
            unicode(t))
        return
      if head or g:
        t.add("1", head)
      if head2:
        t.add("head2", head2)
      if g:
        t.add("2", g)
      if g2:
        t.add("g2", g2)
      if g3:
        t.add("g3", g3)
      if tr:
        t.add("tr", tr)
      if tr2:
        t.add("tr2", tr2)
      newt = unicode(t)
      if origt != newt:
        pagemsg("Replaced %s with %s" % (origt, newt))
        notes.append("canonicalize ru-noun form")

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

parser = blib.create_argparser(u"Canonicalize {{head|ru|noun form}} and {{ru-noun form}}")
args = parser.parse_args()
start, end = blib.get_args(args.start, args.end)

for category in ["Russian noun forms"]:
  msg("Processing category: %s" % category)
  for i, page in blib.cat_articles(category, start, end):
    process_page(i, page, args.save, args.verbose)
