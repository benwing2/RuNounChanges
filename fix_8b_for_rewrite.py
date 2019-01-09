#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, errmsg, site

import rulib as ru

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
    if unicode(t.name) in ["ru-conj", "ru-conj-old"]:
      param1 = getparam(t, "1")
      param2 = getparam(t, "2")
      if not param2.startswith("8b"):
        continue
      param3 = getparam(t, "3")
      param4 = getparam(t, "4")
      param5 = getparam(t, "5")
      assert not getparam(t, "6")
      if getparam(t, "past_m"):
        errmsg("WARNING: Has past_m=%s" % getparam(t, "past_m"))
      pap = getparam(t, "pap") or getparam(t, "past_adv_part")
      if pap:
        errmsg("WARNING: Has pap=%s" % pap)
      pap2 = getparam(t, "pap2") or getparam(t, "past_adv_part2")
      if pap2:
        errmsg("WARNING: Has pap2=%s" % pap2)
      param4 = ru.make_unstressed(param4)
      # Fetch non-numbered params.
      non_numbered_params = []
      for param in t.params:
        pname = unicode(param.name)
        if not re.search(r"^[0-9]+$", pname) and pname not in ["lang", "nocat", "tr"]:
          non_numbered_params.append((pname, param.value))
      # Erase all params.
      del t.params[:]
      # Put back numbered params.
      t.add("1", param1)
      t.add("2", param2)
      t.add("3", param3)
      t.add("4", param4)
      if param5:
        t.add("5", param5)
      # Put back non-numbered params.
      for name, value in non_numbered_params:
        t.add(name, value)
    newt = unicode(t)
    if origt != newt:
      pagemsg("Replaced %s with %s" % (origt, newt))
      notes.append("rewrite class 8b verb to correspond to module changes")

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

parser = blib.create_argparser(u"Rewrite class 8b verbs to correspond to module changes")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

for category in ["Russian class 8b verbs"]:
  msg("Processing category: %s" % category)
  for i, page in blib.cat_articles(category, start, end):
    process_page(i, page, args.save, args.verbose)
