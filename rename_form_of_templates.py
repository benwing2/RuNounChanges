#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, msg, site, tname

rename_templates = {
  "ao": "abbr of",
  "abb": "abbr of",
  "abbreviation": "abbreviation of",
  "alternative capitalisation of": "alternative case form of",
  "alternative capitalization of": "alternative case form of",
  "altcaps": "alt case",
  "altcase": "alt case",
  "alternate form of": "alternative form of",
  "altform": "alt form",
  "alt form of": "alt form",
  "alt-form": "alt form",
  "alternate spelling of": "alternative spelling of",
  "altspelling": "alt sp",
  "altspell": "alt sp",
  "alt-sp": "alt sp",
  "alt spell of": "alt sp",
  "attributive of": "attributive form of",
  "clipped form of": "clipping of",
  "clip": "clip of",
  "comparative form of": "comparative of",
  "eclipsed": "eclipsis of",
  "eggcorn": "eggcorn of",
  "anapodoton of": "ellipsis of",
  "ellipse of": "ellipsis of",
  "eye-dialect of": "eye dialect of",
  "eye dialect": "eye dialect of",
  "feminine past participle of": "feminine singular past participle of",
  "honoraltcaps": "honor alt case",
  "conjugation of": "inflection of",
  "io": "init of",
  "lenited": "lenition of",
  "men's form of": "men's speech form of",
  "common misspelling of": "misspelling of",
  "misspell": "missp",
  "neuter of": "neuter singular of",
  "neuter past participle of": "neuter singular past participle of",
  "obssp": "obs sp",
  "obs-sp": "obs sp",
  "passive form of": "passive of",
  "past passive of": "passive past of",
  "passive past tense of": "passive past of",
  "past participle": "past participle of",
  "past of": "past tense of",
  "definite plural of": "plural definite of",
  "indefinite plural of": "plural indefinite of",
  "plural form of": "plural of",
  "present of": "present tense of",
  "rareform": "rare form of",
  "rarspell": "rare sp",
  "rarespell": "rare sp",
  "short form of": "short for",
  "short of": "short for",
  "shortfor": "short for",
  "definite singular of": "singular definite of",
  "standspell": "stand sp",
  "superlative form of": "superlative of",
  "deprecated spelling of": "superseded spelling of",
  "superseded form of": "superseded spelling of",
  "alternative term for": "synonym of",
  "altname": "syn of",
  "synonym": "syn of",
  "alternative name of": "synonym of",
  "syn-of": "syn of",
  "synof": "syn of",
  # language-specific
  "kyūjitai spelling of": "ja-kyujitai spelling of",
  "kyujitai spelling of": "ja-kyujitai spelling of",
  "kyujitai of": "ja-kyu sp",
  "kyujitai": "ja-kyu sp",
  "kyu": "ja-kyu sp",
}

def process_page(page, index, parsed):
  pagetitle = str(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")
  notes = []

  for t in parsed.filter_templates():
    origt = str(t)
    tn = tname(t)
    if tn in rename_templates:
      blib.set_template_name(t, rename_templates[tn])
      notes.append("standardize {{%s}} to {{%s}}" % (tn, rename_templates[tn]))

    if str(t) != origt:
      pagemsg("Replaced <%s> with <%s>" % (origt, str(t)))

  return str(parsed), notes

parser = blib.create_argparser("Standardize names of form-of templates")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

for template in sorted(rename_templates.keys()):
  msg("Processing references to Template:%s" % template)
  for i, page in blib.references("Template:%s" % template, start, end):
    blib.do_edit(page, i, process_page, save=args.save, verbose=args.verbose)
