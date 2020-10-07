#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, errmsg, site, tname, pname

def process_text_on_page(index, pagetitle, text):
  global args

  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  m = re.search("^Category:(Japanese|Okinawan) terms spelled with (.*) read as (.*)$", pagetitle)
  if not m:
    pagemsg("Skipped")
    return

  lang, spelling, reading = m.groups()
  langcode = lang == "Japanese" and "ja" or "ryu"
  spelling_page = pywikibot.Page(site, spelling)
  def pagemsg_with_spelling(txt):
    pagemsg("%s: %s" % (spelling, txt))
  def errandpagemsg_with_spelling(txt):
    pagemsg_with_spelling(txt)
    errmsg("Page %s %s: %s: %s" % (index, pagetitle, spelling, txt))
  if not blib.safe_page_exists(spelling_page, pagemsg_with_spelling):
    pagemsg_with_spelling("Spelling page doesn't exist, skipping")
    return
  text = blib.safe_page_text(spelling_page, pagemsg_with_spelling)
  retval = blib.find_modifiable_lang_section(text, lang, pagemsg_with_spelling)
  if retval is None:
    pagemsg("WARNING: Couldn't find %s section" % lang)
    return
  sections, j, secbody, sectail, has_non_lang = retval

  parsed = blib.parse_text(secbody)
  saw_readings_template = False
  for t in parsed.filter_templates():
    tn = tname(t)
    if tn == "%s-readings" % langcode:
      saw_readings_template = True
      reading_types = []
      for reading_type in ["goon", "kanon", "toon", "soon", "kanyoon", "on", "kun", "nanori"]:
        readings = getparam(t, reading_type).strip()
        if readings:
          readings = re.split(r"\s*,\s*", readings)
          readings = [re.sub("[<-].*", "", r) for r in readings]
          if reading in readings:
            reading_types.append(reading_type)
      if reading_types:
        contents = "{{%s-readingcat|%s|%s|%s}}" % (langcode, spelling, reading, "|".join(reading_types))
        comment = 'Created page with "%s"' % contents
        if args.save:
          spelling_page.text = contents
          try:
            spelling_page.save(comment)
            errandpagemsg_with_spelling("Created page, comment = %s" % comment)
          except pywikibot.exceptions.LockedPage as e:
            errandpagemsg_with_spelling("WARNING: Error when trying to save: %s" % unicode(e))
        else:
          pagemsg_with_spelling("Would create, comment = %s" % comment)
      else:
        pagemsg_with_spelling("WARNING: Can't find reading %s among readings listed in %s" %
          (reading, unicode(t).replace("\n", r"\n")))

  if not saw_readings_template:
    pagemsg_with_spelling("WARNING: Couldn't find reading template {{%s-readings}}" % langcode)

parser = blib.create_argparser("Create 'Japanese terms spelled with FOO read as BAR' categories",
  include_pagefile=True, include_stdin=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page,
  edit=True, stdin=True)
