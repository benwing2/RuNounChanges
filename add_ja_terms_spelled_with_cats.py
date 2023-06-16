#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse
import unicodedata

import blib
from blib import getparam, rmparam, msg, errmsg, site, tname, pname

allowed_reading_types = ["goon", "kanon", "toon", "soon", "kanyoon", "on", "kun", "nanori"]

canonicalize_reading_types = {
  "kanon": "kan'on",
  "toon": u"tōon",
  "soon": u"sōon",
  "kanyoon": u"kan'yōon",
}

def process_text_on_page(index, pagetitle, text):
  global args

  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  m = re.search("^Category:(Japanese|Okinawan) terms spelled with (.*) read as (.*)$", pagetitle)
  if not m:
    pagemsg("Skipped")
    return

  notes = []

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
  spelling_page_text = blib.safe_page_text(spelling_page, pagemsg_with_spelling)
  retval = blib.find_modifiable_lang_section(spelling_page_text, lang, pagemsg_with_spelling)
  if retval is None:
    pagemsg_with_spelling("WARNING: Couldn't find %s section" % lang)
    return
  sections, j, secbody, sectail, has_non_lang = retval

  parsed = blib.parse_text(secbody)
  saw_readings_template = False
  reading_types = []
  for t in parsed.filter_templates():
    tn = tname(t)
    if tn == "%s-readings" % langcode:
      saw_readings_template = True
      for reading_type in allowed_reading_types:
        readings = getparam(t, reading_type).strip()
        if readings:
          readings = re.split(r"\s*,\s*", readings)
          readings = [re.sub("[<-].*", "", r) for r in readings]
          if reading in readings:
            reading_type = canonicalize_reading_types.get(reading_type, reading_type)
            pagemsg_with_spelling("Appending reading type %s based on %s" % (reading_type, str(t)))
            if reading_type not in reading_types:
              reading_types.append(reading_type)
              notes.append("add %s reading based on {{%s-readings}} on page [[%s]]" % (reading_type, langcode, spelling))
      if not reading_types:
        pagemsg_with_spelling("WARNING: Can't find reading %s among readings listed in %s" %
          (reading, str(t).replace("\n", r"\n")))

  if not saw_readings_template:
    pagemsg_with_spelling("WARNING: Couldn't find reading template {{%s-readings}}" % langcode)

  if reading_types:
    contents = "{{auto cat|%s}}" % "|".join(reading_types)
    return contents, notes
  else:
    pagemsg_with_spelling("WARNING: Can't find reading %s on page" % reading)

  for i, contents_page in blib.cat_articles(re.sub("^Category:", "", pagetitle)):
    contents_title = str(contents_page.title())
    def pagemsg_with_contents(txt):
      pagemsg("%s: %s" % (contents_title, txt))
    def errandpagemsg_with_contents(txt):
      pagemsg_with_contents(txt)
      errmsg("Page %s %s: %s: %s" % (index, pagetitle, contents_title, txt))
    contents_page_text = blib.safe_page_text(contents_page, pagemsg_with_contents)
    retval = blib.find_modifiable_lang_section(contents_page_text, lang, pagemsg_with_contents)
    if retval is None:
      pagemsg_with_contents("WARNING: Couldn't find %s section" % lang)
      return
    sections, j, secbody, sectail, has_non_lang = retval

    saw_kanjitab = False
    must_continue = False
    for ch in contents_title:
      if 0xD800 <= ord(ch) <= 0xDFFF:
        pagemsg_with_contents("WARNING: Surrogates in page name, skipping: %s" % ord(ch))
        must_continue = True
        break
    if must_continue:
      continue
    chars_in_contents_title = [x for x in contents_title]
    for i, ch in enumerate(chars_in_contents_title):
      if ch == u"々": # kanji repeat char
        if i == 0:
          pagemsg_with_contents(u"Repeat char 々 found at beginning of contents title")
          must_continue = True
          break
        else:
          chars_in_contents_title[i] = chars_in_contents_title[i - 1]
    if must_continue:
      continue
    kanji_in_contents_title = [x for x in chars_in_contents_title if unicodedata.name(x).startswith("CJK UNIFIED IDEOGRAPH")]
    parsed = blib.parse_text(secbody)
    for t in parsed.filter_templates():
      tn = tname(t)
      if tn == "%s-kanjitab" % langcode:
        saw_kanjitab = True
        readings = []
        for i in range(1, 10):
          contents_reading = getparam(t, str(i))
          if contents_reading:
            readings.append(contents_reading)
        if len(kanji_in_contents_title) != len(readings):
          pagemsg_with_contents("WARNING: Saw %s chars in contents title but %s readings %s, skipping: %s" % (
            len(kanji_in_contents_title), len(readings), ",".join(readings), str(t)))
          continue
        yomi = getparam(t, "yomi")
        if not yomi:
          pagemsg_with_contents("WARNING: No yomi, skipping: %s" % str(t))
          continue
        if "," in yomi or re.search("[0-9]$", yomi):
          yomi = yomi.split(",")
        if type(yomi) is list:
          expanded_yomi = []
          for y in yomi:
            m = re.search("^(.*?)([0-9]+)$", y)
            if m:
              baseyomi, numyomi = m.groups()
              numyomi = int(numyomi)
              expanded_yomi.extend([baseyomi] * numyomi)
            else:
              expanded_yomi.append(y)
          if expanded_yomi != yomi:
            pagemsg_with_contents("Expanding yomi %s to %s" % (",".join(yomi), ",".join(expanded_yomi)))
          yomi = expanded_yomi
        if type(yomi) is list and len(yomi) != len(kanji_in_contents_title):
          pagemsg_with_contents("WARNING: %s values in yomi=%s but %s chars in contents, skipping: %s" % (
            len(yomi), ",".join(yomi), len(kanji_in_contents_title), str(t)))
          continue
        saw_spelling_in_contents = False
        must_continue = False
        for i, (ch, contents_reading) in enumerate(zip(kanji_in_contents_title, readings)):
          if ch == spelling:
            saw_spelling_in_contents = True
            if contents_reading == reading:
              if type(yomi) is list:
                reading_type = yomi[i]
              else:
                reading_type = yomi
              yomi_to_canonical_reading_type = {
                "o": "on",
                "on": "on",
                "kanon": "kanon",
                "goon": "goon",
                "soon": "soon",
                "toon": "toon",
                "kan": "kanyoon",
                "kanyo": "kanyoon",
                "kanyoon": "kanyoon",
                "k": "kun",
                "kun": "kun",
                "juku": "jukujikun",
                "jukuji": "jukujikun",
                "jukujikun": "jukujikun",
                "n": "nanori",
                "nanori": "nanori",
                "ok": "jubakoyomi",
                "j": "jubakoyomi",
                "ko": "yutoyomi",
                "y": "yutoyomi",
                "irr": "irregular",
                "irreg": "irregular",
                "irregular": "irregular",
              }
              if reading_type not in yomi_to_canonical_reading_type:
                pagemsg_with_contents("WARNING: Unrecognized reading type %s: %s" % (reading_type, str(t)))
                must_continue = True
                break
              reading_type = yomi_to_canonical_reading_type[reading_type]
              if reading_type not in allowed_reading_types:
                pagemsg_with_contents("WARNING: Disallowed reading type %s: %s" % (reading_type, str(t)))
                must_continue = True
                break
              reading_type = canonicalize_reading_types.get(reading_type, reading_type)
              pagemsg_with_contents("Appending reading type %s based on %s" % (reading_type, str(t)))
              if reading_type not in reading_types:
                reading_types.append(reading_type)
                notes.append("add %s reading based on {{%s-kanjitab}} on page [[%s]]" % (reading_type, langcode, contents_title))
        if must_continue:
          continue
        if not saw_spelling_in_contents:
          pagemsg_with_contents("WARNING: Didn't see spelling in contents: %s" % str(t))
          continue
    if not saw_kanjitab:
      pagemsg_with_contents("WARNING: Didn't see {{%s-kanjitab}}" % langcode)

  if reading_types:
    contents = "{{auto cat|%s}}" % "|".join(reading_types)
    return contents, notes
  else:
    pagemsg_with_spelling("WARNING: Can't find reading %s by looking through category contents" % reading)


parser = blib.create_argparser("Create 'Japanese terms spelled with FOO read as BAR' categories",
  include_pagefile=True, include_stdin=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page,
  edit=True, stdin=True)
