#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, tname, pname, msg, site

def process_text_on_page(index, pagetitle, text):
  global args
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  if ":" in pagetitle:
    pagemsg("Skipping non-mainspace title")
    return

  notes = []

  retval = blib.find_modifiable_lang_section(text, None if args.partial_page else "Spanish", pagemsg,
    force_final_nls=True)
  if retval is None:
    return
  sections, j, secbody, sectail, has_non_lang = retval

  subsections = re.split("(^==+[^=\n]+==+\n)", secbody, 0, re.M)

  for k in xrange(2, len(subsections), 2):
    def replace_demonym_noun(m, demonym_gender):
      raw_toponym = m.group(1)
      toponym = None
      mm = re.search(r"^\[\[([^\[\]|={}]*)\]\]$", raw_toponym)
      if mm:
        toponym = mm.group(1)
      if not mm:
        mm = re.search(r"^\{\{w\|([^\[\]|={}]*)\}\}$", raw_toponym)
        if mm:
          toponym = "w:%s" % mm.group(1)
      if not mm:
        mm = re.search(r"^\[\[[wW]:([^\[\]|={}]*)\|([^\[\]|={}]*)\]\]$", raw_toponym)
        if mm:
          link, display = mm.groups()
          mmm = re.search("^([a-zA-Z0-9_-]+):(.*)$", link)
          if mmm:
            wikilang, link = mmm.groups()
          else:
            wikilang = None
          if link == display:
            if wikilang:
              toponym = "w:%s:%s" % (wikilang, link)
            else:
              toponym = "w:%s" % link
          else:
            if wikilang:
              toponym = "{{w|lang=%s|%s|%s}}" % (wikilang, link, display)
            else:
              toponym = "{{w|%s|%s}}" % (link, display)
      if not mm:
        if re.search(u"^[A-ZÁÉÍÓÚÝÑ][^\[\]|={}]*$", raw_toponym):
          toponym = raw_toponym
      if not toponym:
        pagemsg("WARNING: Unable to parse raw toponym: %s" % raw_toponym)
        return m.group(0)
      notes.append("templatize raw demonym definition for Spanish toponym '%s'" % raw_toponym)
      if demonym_gender:
        demonym_gender = "|g=%s" % demonym_gender
      return "{{demonym-noun|es|%s%s}}" % (toponym, demonym_gender)

    if "==Noun==" in subsections[k - 1]:
      demonym_gender = None
      parsed = blib.parse_text(subsections[k])
      for t in parsed.filter_templates():
        tn = tname(t)
        if tn == "es-noun":
          g = blib.fetch_param_chain(t, "1", "g")
          if g in [["m"], ["f"]]:
            demonym_gender = g[0]
          elif g in [["mf"], ["mfbysense"], ["m", "f"]]:
            demonym_gender = ""
          elif g not in [["m-p"], ["f-p"], ["mf-p"], ["mfbysense-p"]]:
            pagemsg("WARNING: Unable to determine demonym gender from headword template: %s" % unicode(t))
          break
      if demonym_gender is not None:
        subsections[k] = re.sub("^# *someone from (.*)$", lambda m: replace_demonym_noun(m, demonym_gender), subsections[k], 0, re.M)

  secbody = "".join(subsections)
  # Strip extra newlines added to secbody
  sections[j] = secbody.rstrip("\n") + sectail
  text = "".join(sections)

  return text, notes

parser = blib.create_argparser("Templatize Spanish demonyms", include_pagefile=True, include_stdin=True)
parser.add_argument("--partial-page", action="store_true", help="Input was generated with 'find_regex.py --lang Italian' and has no ==Italian== header.")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True)
