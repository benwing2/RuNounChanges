#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, tname, msg, site

import lalib

def investigate_possible_adj(index, adj_pagename, adv, adv_defns):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, adj_pagename, txt))
  pagemsg("Trying for adverb %s" % adv)
  page = pywikibot.Page(site, adj_pagename)
  if not page.exists():
    pagemsg("Doesn't exist for adverb %s" % adv)
    return

  text = unicode(page.text)

  retval = lalib.find_latin_section(text, pagemsg)
  if retval is None:
    return

  sections, j, secbody, sectail, has_non_latin = retval

  subsections = re.split("(^===+[^=\n]+===+\n)", secbody, 0, re.M)

  for k in range(2, len(subsections), 2):
    parsed = blib.parse_text(subsections[k])
    for t in parsed.filter_templates():
      origt = unicode(t)
      tn = tname(t)
      if tn in ["la-adj", "la-part"]:
        adj = lalib.la_get_headword_from_template(t, adj_pagename, pagemsg)[0]
        adj_defns = lalib.find_defns(subsections[k])
        msg("%s /// %s /// %s /// %s" % (adv, adj, ";".join(adv_defns), ";".join(adj_defns)))

def process_page(page, index):
  pagetitle = unicode(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  notes = []

  if " " in pagetitle:
    pagemsg("WARNING: Space in page title, skipping")
    return
  pagemsg("Processing")

  text = unicode(page.text)

  retval = lalib.find_latin_section(text, pagemsg)
  if retval is None:
    return

  sections, j, secbody, sectail, has_non_latin = retval

  subsections = re.split("(^===+[^=\n]+===+\n)", secbody, 0, re.M)

  for k in range(2, len(subsections), 2):
    parsed = blib.parse_text(subsections[k])
    for t in parsed.filter_templates():
      origt = unicode(t)
      tn = tname(t)
      if tn == "la-adv":
        adv = blib.remove_links(getparam(t, "1")) or pagetitle
        macron_stem, is_stem = lalib.infer_adv_stem(adv)
        if not is_stem:
          pagemsg("WARNING: Couldn't infer stem from adverb %s, not standard: %s" % (
            adv, origt))
          continue
        adv_defns = lalib.find_defns(subsections[k])
        possible_adjs = []
        stem = lalib.remove_macrons(macron_stem)
        possible_adjs.append(stem + "us")
        possible_adjs.append(stem + "is")
        if stem.endswith("nt"):
          possible_adjs.append(stem[:-2] + "ns")
        if stem.endswith("plic"):
          possible_adjs.append(stem[:-2] + "ex")
        if stem.endswith("c"):
          possible_adjs.append(stem[:-1] + "x")
        if re.search("[aeiou]r$", stem):
          possible_adjs.append(stem)
        elif stem.endswith("r"):
          possible_adjs.append(stem[:-1] + "er")
        if adv.endswith(u"iē"):
          possible_adjs.append(stem + "ius")
        for possible_adj in possible_adjs:
          investigate_possible_adj(index, possible_adj, adv, adv_defns)

parser = blib.create_argparser("Find corresponding adjectives for Latin adverbs",
    include_pagefile=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_page,
    default_cats=["Latin adverbs"])
