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

  def fix_up_section(sectext, warn_on_multiple_heads):
    parsed = blib.parse_text(sectext)

    heads = set()
    pronun_templates = []
    for t in parsed.filter_templates():
      tn = tname(t)
      if lalib.la_template_is_head(t):
        heads |= set(blib.remove_links(x) for x in lalib.la_get_headword_from_template(t, pagetitle, pagemsg))
      elif tn == "la-IPA":
        pronun_templates.append(t)
    if len(heads) > 1:
      if warn_on_multiple_heads:
        pagemsg("WARNING: Found multiple possible heads, not modifying: %s" % ",".join(heads))
      return sectext
    if len(heads) == 0:
      pagemsg("WARNING: Found no possible heads, not modifying: %s" % ",".join(heads))
      return sectext
    newsectext = re.sub(r"\{\{a\|Classical\}\} \{\{IPA(char)?\|.*?\}\}", "{{la-IPA|%s}}" % list(heads)[0], sectext)
    newsectext = re.sub(r"^\* \{\{IPA(char)?\|.*?\|lang=la\}\}", "{{la-IPA|%s}}" % list(heads)[0], newsectext, 0, re.M)
    if newsectext != sectext:
      notes.append("replaced manual Latin pronun with {{la-IPA|%s}}" % list(heads)[0])
      sectext = newsectext
    # Recompute pronun templates as we may have added one.
    parsed = blib.parse_text(sectext)
    pronun_templates = []
    for t in parsed.filter_templates():
      tn = tname(t)
      if tn == "la-IPA":
        pronun_templates.append(t)
    if "{{a|Ecclesiastical}} {{IPA" in sectext:
      if len(pronun_templates) == 0:
        pagemsg("WARNING: Found manual Ecclesiastical pronunciation but not {{la-IPA}} template")
      elif len(pronun_templates) > 1:
        pagemsg("WARNING: Found manual Ecclesiastical pronunciation and multiple {{la-IPA}} templates: %s" %
          ",".join(unicode(tt) for tt in pronun_templates))
      else:
        origt = unicode(pronun_templates[0])
        pronun_templates[0].add("eccl", "yes")
        pagemsg("Replaced %s with %s" % (origt, unicode(pronun_templates[0])))
        newsectext = re.sub(r"^\* \{\{a\|Ecclesiastical\}\} \{\{IPA(char)?\|.*?\}\}\n", "",
            sectext, 0, re.M)
        if newsectext == sectext:
          pagemsg("WARNING: Unable to remove manual Ecclesiastical prounciation")
        else:
          notes.append("removed manual Ecclesiastical pronunciation and added |eccl=yes to {{la-IPA}}")
          sectext = newsectext
    return sectext

  # If there are multiple Etymology sections, the pronunciation may be above all of
  # them if all have the same pronunciation, else it will be within each section.
  # Cater to both situations. We first try without splitting on etym sections; if that
  # doesn't change anything, it may be because there were multiple heads found and
  # separate pronunciation sections, so we then try splitting on etym sections.
  has_etym_1 = "==Etymology 1==" in secbody
  newsecbody = fix_up_section(secbody, warn_on_multiple_heads=not has_etym_1)
  if newsecbody != secbody:
    secbody = newsecbody
  elif has_etym_1:
    etym_sections = re.split("(^===Etymology [0-9]+===\n)", secbody, 0, re.M)
    for k in range(2, len(etym_sections), 2):
      etym_sections[k] = fix_up_section(etym_sections[k], warn_on_multiple_heads=True)
    secbody = "".join(etym_sections)

  sections[j] = secbody + sectail
  return "".join(sections), notes

parser = blib.create_argparser("Replace manual Latin pronun with {{la-IPA}}",
  include_pagefile=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_page, edit=True)
