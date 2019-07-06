#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, tname, msg, site

import lalib

def process_page(page, index, parsed):
  pagetitle = unicode(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  text = unicode(page.text)
  origtext = text

  retval = lalib.find_latin_section(text, pagemsg)
  if retval is None:
    return None, None

  sections, j, secbody, sectail, has_non_latin = retval

  notes = []

  parsed = blib.parse_text(secbody)

  for t in parsed.filter_templates():
    tn = tname(t)
    if tn in ["l", "m", "alternative form of", "alt form"]:
      if tn in ["l", "m"]:
        lang = getparam(t, "1")
        termparam = 2
      elif getparam(t, "lang"):
        lang = getparam(t, "lang")
        termparam = 1
      else:
        lang = getparam(t, "1")
        termparam = 2
      if lang != "la":
        #pagemsg("WARNING: Wrong language in template: %s" % unicode(t))
        continue
      term = getparam(t, str(termparam))
      alt = getparam(t, str(termparam + 1))
      gloss = getparam(t, str(termparam + 2))
      if alt and lalib.remove_macrons(alt) == term:
        origt = unicode(t)
        t.add(str(termparam), alt)
        if gloss:
          t.add(str(termparam + 1), "")
        else:
          rmparam(t, str(termparam + 1))
        pagemsg("Replaced %s with %s" % (origt, unicode(t)))
        notes.append("move alt param to link param in %s" % tn)

  secbody = unicode(parsed)
  sections[j] = secbody + sectail
  return "".join(sections), notes

parser = blib.create_argparser("Move alt param to term param in {{l}}, {{m}}, {{alternative form of}}, {{alt form}}")
parser.add_argument("--pagefile", help="List of pages to process.", required=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

pages = [x.rstrip('\n') for x in codecs.open(args.pagefile, "r", "utf-8")]
for i, page in blib.iter_items(pages, start, end):
  blib.do_edit(pywikibot.Page(site, page), i, process_page, save=args.save,
      verbose=args.verbose)
