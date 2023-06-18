#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse
import unicodedata

import blib
from blib import getparam, rmparam, msg, errmsg, site, tname, pname

def process_text_on_page(index, pagetitle, text):
  global args

  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  m = re.search(u"^Category:(Japanese|Okinawan) terms with (.*) replaced by daiyōji (.*)$", pagetitle)
  if not m:
    pagemsg("Skipped")
    return

  notes = []

  lang, orig_kanji, daiyoji = m.groups()
  langcode = lang == "Japanese" and "ja" or "ryu"

  daiyoji_readings = []

  def check_secbody_for_readings(secbody):
    parsed = blib.parse_text(secbody)
    saw_daiyoji_template = False
    for t in parsed.filter_templates():
      tn = tname(t)
      if tn == "%s-daiyouji" % langcode:
        t_daiyoyi = getparam(t, "1")
        t_orig_kanji = getparam(t, "2")
        if t_daiyoyi == daiyoji and t_orig_kanji == orig_kanji:
          saw_daiyoji_template = True
          # Don't look at sort= because it may not be the actual reading of the daiyōji char but the reading of the
          # entire term, e.g. for [[条虫]].
    if not saw_daiyoji_template:
      return False

    saw_kanjitab = False
    must_continue = False
    for ch in contents_title:
      if 0xD800 <= ord(ch) <= 0xDFFF:
        pagemsg_with_contents("WARNING: Surrogates in page name, skipping: %s" % ord(ch))
        must_continue = True
        break
    if must_continue:
      return False
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
      return False
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
        saw_daiyoji_in_contents = False
        for i, (ch, contents_reading) in enumerate(zip(kanji_in_contents_title, readings)):
          if ch == daiyoji:
            saw_daiyoji_in_contents = True
            if contents_reading not in daiyoji_readings:
              daiyoji_readings.append(contents_reading)
              if not notes:
                notes.append("add sort key %s based on {{%s-kanjitab}} on page [[%s]]" %
                    (contents_reading, langcode, contents_title))
        if not saw_daiyoji_in_contents:
          pagemsg_with_contents("WARNING: Didn't see daiyoji in contents: %s" % str(t))
          continue
    return saw_kanjitab

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
    saw_templates = False
    if "Etymology 1" in secbody:
      etym_sections = re.split("(^===Etymology [0-9]+===\n)", secbody, 0, re.M)
      for k in range(2, len(etym_sections), 2):
        this_saw_templates = check_secbody_for_readings(etym_sections[k])
        saw_templates = saw_templates or this_saw_templates
    else:
      saw_templates = check_secbody_for_readings(secbody)
    if not saw_templates:
      pagemsg_with_contents("WARNING: Didn't see {{%s-daiyouji}} or {{%s-kanjitab}}" % (langcode, langcode))

  if daiyoji_readings:
    if len(daiyoji_readings) > 1:
      pagemsg("WARNING: Saw multiple daiyoji readings %s" % ",".join(daiyoji_readings))
    else:
      contents = "{{auto cat|sort=%s}}" % daiyoji_readings[0]
      return contents, notes
  else:
    pagemsg("WARNING: Can't find reading %s by looking through category contents" % reading)


parser = blib.create_argparser(u"Create 'Japanese terms with FOO replaced by daiyōji BAR' categories",
  include_pagefile=True, include_stdin=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page,
  edit=True, stdin=True)
