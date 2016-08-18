#!/usr/bin/env python
# -*- coding: utf-8 -*-

# Find places where ru-verb is missing or its aspect(s) don't agree with the
# aspect(s) in ru-conj-*. Maybe fix them by copying the aspect from ru-verb
# to ru-conj-*.

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site

import rulib as ru

def process_page(index, page, fix, save, verbose):
  pagetitle = unicode(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  text = unicode(page.text)
  notes = []

  parsed = blib.parse(page)
  headword_aspects = set()
  found_multiple_headwords = False
  for t in parsed.filter_templates():
    tname = unicode(t.name)
    if tname == "ru-verb":
      if headword_aspects:
        found_multiple_headwords = True
      headword_aspects = set()
      aspect = getparam(t, "2")
      if aspect in ["pf", "impf"]:
        headword_aspects.add(aspect)
      elif aspect == "both":
        headword_aspects.add("pf")
        headword_aspects.add("impf")
      elif aspect == "?":
        pagemsg("WARNING: Found aspect '?'")
      else:
        pagemsg("WARNING: Found bad aspect value '%s' in ru-verb" % aspect)
    elif tname == "ru-conj" and tname != "ru-conj-verb-see":
      aspect = re.sub("-.*", "", getparam(t, "2"))
      if aspect not in ["pf", "impf"]:
        pagemsg("WARNING: Found bad aspect value '%s' in ru-conj" %
            getparam(t, "2"))
      else:
        if not headword_aspects:
          pagemsg("WARNING: No ru-verb preceding ru-conj: %s" % unicode(t))
        elif aspect not in headword_aspects:
          pagemsg("WARNING: ru-conj aspect %s not in ru-verb aspect %s" %
              (aspect, ",".join(headword_aspects)))
  if fix:
    if found_multiple_headwords:
      pagemsg("WARNING: Multiple ru-verb headwords, not fixing")
    elif not headword_aspects:
      pagemsg("WARNING: No ru-verb headwords, not fixing")
    elif len(headword_aspects) > 1:
      pagemsg("WARNING: Multiple aspects in ru-verb, not fixing")
    else:
      for t in parsed.filter_templates():
        origt = unicode(t)
        tname = unicode(t.name)
        if tname == "ru-conj" and tname != "ru-conj-verb-see":

          param1 = getparam(t, "2")
          param1 = re.sub("^(pf|impf)((-.*)?)$", r"%s\2" % list(headword_aspects)[0], param1)
          t.add("2", param1)
        newt = unicode(t)
        if origt != newt:
          pagemsg("Replaced %s with %s" % (origt, newt))
          notes.append("overrode conjugation aspect with %s" % list(headword_aspects)[0])

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

parser = blib.create_argparser(u"Find incorrect verb aspects")
parser.add_argument('--pagefile', help="File containing pages to fix.")
parser.add_argument('--fix', action="store_true", help="Fix errors by copying aspect from headword to conjugation")
args = parser.parse_args()
start, end = blib.get_args(args.start, args.end)

if args.pagefile:
  lines = [x.strip() for x in codecs.open(args.pagefile, "r", "utf-8")]
  for i, page in blib.iter_items(lines, start, end):
    process_page(i, pywikibot.Page(site, page), args.fix, args.save,
      args.verbose)
else:
  for category in ["Russian verbs"]:
    msg("Processing category: %s" % category)
    for i, page in blib.cat_articles(category, start, end):
      process_page(i, page, args.fix, args.save, args.verbose)
