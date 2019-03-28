#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site, tname

rename_templates = {
  # deftempboiler
  "ao": "abbrof",
  "abb": "abbrof",
  "abbreviation": "abbreviation of",
  "clipped form of": "clipping of",
  "clip": "clipof",
  "eclipsed": "eclipsis of",
  "eggcorn": "eggcorn of",
  "io": "initof",
  "lenited": "lenition of",
  "common misspelling of": "misspelling of",
  "rarspell": "raresp",
  "rarespell": "raresp",
  "short form of": "short for",
  "short of": "short for",
  "shortfor": "short for",
  "standspell": "standsp",
  "deprecated spelling of": "superseded spelling of",
  "superseded form of": "superseded spelling of",
  # form_of_templates
  "alternative capitalisation of": "alternative case form of",
  "alternative capitalization of": "alternative case form of",
  "altcaps": "altcase",
  "alternate form of": "alternative form of",
  "alt form": "altform",
  "alt form of": "altform",
  "alt-form": "altform",
  "alternate spelling of": "alternative spelling of",
  "altspelling": "altsp",
  "altspell": "altsp",
  "alt-sp": "altsp",
  "alt spell of": "altsp",
  "attributive of": "attributive form of",
  "comparative form of": "comparative of",
  "definite and plural of": "e-form of",
  "anapodoton of": "ellipsis of",
  "ellipse of": "ellipsis of",
  "fem form": "femform",
  "feminine past participle of": "feminine singular past participle of",
  "honoraltcaps": "honoraltcase",
  "conjugation of": "inflection of",
  "men's form of": "men's speech form of",
  "neuter of": "neuter singular of",
  "neuter past participle of": "neuter singular past participle of",
  "obs-sp": "obssp",
  "passive form of": "passive of",
  "past passive of": "passive past of",
  "passive past tense of": "passive past of",
  "past participle": "past participle of",
  "past tense of": "past of",
  "definite plural of": "plural definite of",
  "indefinite plural of": "plural indefinite of",
  "plural form of": "plural of",
  "present tense of": "present of",
  "definite singular of": "singular definite of",
  "superlative form of": "superlative of",
  "alternative term for": "synonym of",
  "altname": "synof",
  "synonym": "synof",
  "alternative name of": "synonym of",
  "syn-of", "synof",
  "syn of": "synof",
}

def process_page(page, index, parsed):
  pagetitle = unicode(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")
  notes = []

  for t in parsed.filter_templates():
    origt = unicode(t)
    tn = tname(t)
    if tn in rename_templates:
      blib.set_template_name(t, rename_templates[tn])
      notes.append("standardize {{%s}} to {{%s}}" % (tn, rename_templates[tn]))

    if unicode(t) != origt:
      pagemsg("Replaced <%s> with <%s>" % (origt, unicode(t)))

  return unicode(parsed), notes

parser = blib.create_argparser("Standardize names of form-of templates")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

for template in rename_templates:
  msg("Processing references to Template:%s" % template)
  for i, page in blib.references("Template:%s" % template, start, end):
    blib.do_edit(page, i, process_page, save=args.save, verbose=args.verbose)
