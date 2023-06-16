#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, tname, msg, site

import lalib

def process_page(page, index, parsed):
  pagetitle = str(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  text = str(page.text)
  origtext = text

  retval = lalib.find_latin_section(text, pagemsg)
  if retval is None:
    return None, None

  sections, j, secbody, sectail, has_non_latin = retval

  subsections = re.split("(^==.*==\n)", secbody, 0, re.M)

  if len(subsections) != 3:
    pagemsg("WARNING: Not right # of sections (expected 1): %s" %
        ",".join(subsections[k].strip() for k in range(1, len(subsections), 2)))
    return None, None

  if subsections[1] != "===Verb===\n":
    pagemsg("WARNING: Expected ===Verb=== in subsections[1] but saw %s" %
        subsections[1].strip())
    return None, None

  parsed = blib.parse_text(subsections[2])
  infl = None
  lemma = None
  infloft = None
  for t in parsed.filter_templates():
    if tname(t) == "la-verb-form":
      if infl:
        pagemsg("WARNING: Saw more than one {{la-verb-form}} call: %s" %
            str(t))
        return None, None
      infl = getparam(t, "1")
    elif tname(t) == "inflection of":
      if lemma:
        pagemsg("WARNING: Saw more than one {{inflection of}} call: %s" %
            str(t))
        return None, None
      if getparam(t, "lang"):
        lemma = getparam(t, "1")
      else:
        lemma = getparam(t, "2")
      infloft = t
    else:
      pagemsg("WARNING: Saw unexpected template: %s" % str(t))
      return None, None
  if not infl or not lemma:
    pagemsg("WARNING: Didn't find both inflection %s and lemma %s" % (
      infl, lemma))
    return None, None
  infl = re.sub(u" (esse|īrī)$", "", infl)
  if infl.endswith(u"us"):
    if infl.endswith(u"ūrus"):
      partdesc = "Future active participle"
      head_template = "{{la-future participle|%s}}" % infl[:-2]
      infl_template = "{{la-decl-1&2|%s}}" % infl[:-2]
    else:
      if "perf|act" in str(infloft):
        partdesc = "Perfect active participle"
      else:
        partdesc = "Perfect passive participle"
      head_template = "{{la-perfect participle|%s}}" % infl[:-2]
      infl_template = "{{la-decl-1&2|%s}}" % infl[:-2]
    sectext = """
===Etymology===
%s of {{m|la|%s}}.

===Pronunciation===
* {{la-IPA|%s}}

===Participle===
%s

# {{rfdef|la}}

====Declension====
%s""" % (partdesc, lemma, infl, head_template, infl_template)
    comment = "correct Latin form to participle"
  elif infl.endswith("um"):
    sectext = """
===Etymology===
From {{m|la|%s}}.

===Pronunciation===
* {{la-IPA|%s}}

===Gerund===
{{la-gerund|%s}}

# {{rfdef|la}}

====Declension====
{{la-decl-gerund|%s}}

===Participle===
{{la-part-form|%s}}

# {{inflection of|la|%s||acc|m|s|;|nom//acc//voc|n|s}}""" % (
    lemma, infl, infl[:-2], infl[:-2], infl, infl[:-2] + "us"
  )
    comment = "correct Latin form to gerund/participle form"
  else:
    pagemsg("WARNING: Unrecognized ending for participle/gerund %s" % infl)
    return None, None

  sections[j] = sectext + sectail
  return "".join(sections), comment

parser = blib.create_argparser("Fix Latin forms wrongly specified as infinitives that should be participles or gerunds",
  include_pagefile=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_page, edit=True)
