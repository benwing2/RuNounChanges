#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site

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
    if unicode(t.name) in ["ru-conj-7a", "ru-conj-7b"]:
      past_stem = getparam(t, "4")
      vowel_end = re.search(u"[аэыоуяеиёю́]$", past_stem)
      past_m = getparam(t, "past_m")
      past_f = getparam(t, "past_f")
      past_n = getparam(t, "past_n")
      past_pl = getparam(t, "past_pl")
      if past_m or past_f or past_n or past_pl:
        upast_stem = ru.make_unstressed(past_stem)
        expected_past_m = past_stem + (u"л" if vowel_end else "")
        expected_past_f = upast_stem + u"ла́"
        expected_past_n = upast_stem + u"ло́"
        expected_past_pl = upast_stem + u"ли́"
        if ((not past_m or expected_past_m == past_m) and
            expected_past_f == past_f and
            expected_past_n == past_n and
            expected_past_pl == past_pl):
          msg("Would remove past overrides and add arg5=b")
        else:
          msg("WARNING: Remaining past overrides: past_m=%s, past_f=%s, past_n=%s, past_pl=%s, expected_past_m=%s, expected_past_f=%s, expected_past_n=%s, expected_past_pl=%s" %
              (past_m, past_f, past_n, past_pl, expected_past_m, expected_past_f, expected_past_n, expected_past_pl))
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

parser = blib.create_argparser(u"Convert class-7 past overrides to past stress pattern")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

for category in ["Russian class 7 verbs"]:
  msg("Processing category: %s" % category)
  for i, page in blib.cat_articles(category, start, end):
    process_page(i, page, args.save, args.verbose)
