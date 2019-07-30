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

  notes = []

  if " " in pagetitle:
    pagemsg("WARNING: Space in page title, skipping")
    return None, None
  pagemsg("Processing")

  for t in parsed.filter_templates():
    origt = unicode(t)
    tn = tname(t)
    if tn == "la-ndecl":
      lemmaspec = getparam(t, "1")
      m = re.search("^(.*)<(.*)>$", lemmaspec)
      if not m:
        pagemsg("WARNING: Unable to parse lemma+spec %s, skipping: %s" % (
          lemmaspec, origt))
        continue
      lemma, spec = m.groups()
      decl, *subtypes = spec.split(".")
      if "pl" not in subtypes:
        pagemsg("WARNING: .pl not in lemma spec %s, skipping: %s" % (
          spec, origt))
        continue
      if "Greek" in subtypes:
        pagemsg("WARNING: .Greek and .pl in lemma spec %s, not able to handle, skipping: %s" % (
          lemmaspec, origt))
        continue
      if "/" in lemma:
        base, stem2 = lemma.split("/")
      else:
        base = lemma
        stem2 = lalib.infer_3rd_decl_stem(base)
      if "N" in subtypes and "I" in subtypes:
        newlemma = stem2 + "ia"
        subtypes = [x for x in subtypes if x != "N" and x != "I"]
        if "pure" in subtypes:
          subtypes = [x for x in subtypes if x != "pure"]
        else:
          subtypes = subtypes + ["-pure"]
      elif "N" in subtypes:
        newlemma = stem2 + "a"
        subtypes = [x for x in subtypes if x != "N"]
      else:
        newlemma = stem2 + u"ēs"
      newspec = ".".join([decl] + subtypes)
      t.add("1", "%s<%s>" % (newlemma, newspec))
      pagemsg("Replaced %s with %s" % (origt, unicode(t)))
      notes.append("convert 3rd-declension plural term to have plural lemma in {{la-ndecl}}")

  return unicode(parsed), notes

parser = blib.create_argparser("Fix Latin 3rd-decl plural nouns to specify plural lemma")
parser.add_argument("--pagefile", help="List of pages to process.", required=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

pages = [x.rstrip('\n') for x in codecs.open(args.pagefile, "r", "utf-8")]
for i, page in blib.iter_items(pages, start, end):
  blib.do_edit(pywikibot.Page(site, page), i, process_page, save=args.save,
    verbose=args.verbose, diff=args.diff)
