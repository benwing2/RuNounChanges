#!/usr/bin/env python3
# -*- coding: utf-8 -*-

# Go through a dump finding links to nonexistent pages.

import pywikibot, re, sys, argparse, codecs

import blib
from blib import getparam, rmparam, msg, site
from collections import defaultdict

blib.getLanguageData()

templates_to_check = {}
for template in [
  "l", "link",
  "m", "mention",
  "m+",
  "cog", "cognate",
  "nc", "ncog", "noncog", "noncognate",
]:
  templates_to_check[template] = ["1", "2"]
for template in ["inh", "inherited", "bor", "borrowed", "der", "derived"]:
  templates_to_check[template] = ["2", "3"]

def zh_l(t, note):
  for page in getparam(t, "1").split("/"):
    note("zh", page)

def ko_l(t, note):
  for param in ["1", "2", "3", "4"]:
    # Yuck yuck yuck! The following is from [[Module:ko]], which allows
    # Hanja, Hangul, translit and gloss params in any order and has a complex
    # algorithm to disambiguate them.
    # FIXME: This needs changing for Python 3.
    val = getparam(t, param)
    if re.search(u"[가-힣㐀-䶵一-鿌\uF900-\uFADF𠀀-𯨟]", val):
      note("ko", val)

def ja_l(t, note):
  note("ja", getparam(t, "1").replace("%", ""))

def vi_l(t, note):
  note("vi", getparam(t, "1"))
  note("vi", getparam(t, "2"))

def vi_link(t, note):
  note("vi", getparam(t, "1"))

templates_to_check.update({
  "zh-l": zh_l,
  "zh-m": zh_l,
  "ko-l": ko_l,
  "ja-l": ja_l,
  "ja-r": ja_l,
  "vi-l": vi_l,
  "vi-link": vi_link,
})

def read_existing_pages(filename):
  pages_with_langs = {}
  for line in codecs.getreader("utf-8")(gzip.open(filename, "rb"), errors="replace"):
    line = line.rstrip("\n")
    if re.search("^Page [0-9]+ .*: WARNING: .*", line):
      msg("Skipping warning: %s" % line)
    else:
      m = re.search("^Page [0-9-]+ (.*): Langs=(.*?)$", line)
      if not m:
        msg("WARNING: Unrecognized line: %s" % line)
      else:
        pages_with_langs[m.group(1)] = set(m.group(2).split(","))
  return pages_with_langs

unrecognized_pages_by_lang_with_count = {}
unrecognized_pages_by_lang_with_source_pages = {}

def process_text_on_page(index, pagetitle, pagetext):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  def note_unrecognized_link(lang, page):
    if lang not in unrecognized_pages_by_lang_with_count:
      unrecognized_pages_by_lang_with_count[lang] = defaultdict(int)
    unrecognized_pages_by_lang_with_count[lang][page] += 1
    if lang not in unrecognized_pages_by_lang_with_source_pages:
      unrecognized_pages_by_lang_with_source_pages[lang] = {}
    if page not in unrecognized_pages_by_lang_with_source_pages[lang]:
      unrecognized_pages_by_lang_with_source_pages[lang][page] = set()
    else:
      unrecognized_pages_by_lang_with_source_pages[lang][page].add(pagetitle)

  def note_link(lang, page):
    if not page:
      return
    if not lang and page not in pages_with_langs:
      note_unrecognized_link(lang, page)
    elif lang and (page not in pages_with_langs or lang not in pages_with_langs[page]):
      note_unrecognized_link(lang, page)

  # Look for raw links.
  for m in re.finditer(r"\[\[(.*?)\]\]", pagetext):
    linkparts = m.group(1).split("|")
    if linkparts > 2:
      pagemsg("WARNING: Link has more than two parts: %s" % m.group(0))
    else:
      page = linkparts[0]
      if "#" in page:
        page, anchor = page.split("#", 1)
        if anchor in blib.languages_byCanonicalName:
          note_link(blib.languages_byCanonicalName[anchor]["code"], page)
        else:
          note_link(None, page)
      else:
        note_link(None, page)

  # Look for templated links.
  for t in blib.parse_text(pagetext).filter_templates():
    pass

parser = blib.create_argparser(u"Find red links", include_pagefile=True, include_stdin=True)
parser.add_argument("--existing-pages", help="Gzipped file containing existing pages by language",
  required=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

pages_with_langs = read_existing_pages(args.existing_pages)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, stdin=True)
