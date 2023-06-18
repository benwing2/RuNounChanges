#!/usr/bin/env python3
# -*- coding: utf-8 -*-

# Find redlinks (non-existent pages) and yellow links (non-existent language section)
# on a set of pages.

import unicodedata
import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, msg, site, tname


punc_chars = "".join("\\" + unichr(i) for i in range(sys.maxunicode)
    if unicodedata.category(unichr(i)).startswith('P'))

tbl = dict.fromkeys(i for i in range(sys.maxunicode)
                          if unicodedata.category(unichr(i)).startswith('P'))
def remove_punctuation(text):
      return text.translate(tbl)

blib.getData()

def remove_diacritics(text, langcode):
  if langcode not in blib.languages_byCode:
    return text
  if "entryNamePatterns" in blib.languages_byCode[langcode]:
    for entry in blib.languages_byCode[langcode]["entryNamePatterns"]:
      from_ = entry["from"]
      from_ = from_.replace("%p", "[" + punc_chars + "]")
      to_ = entry["to"]
      to_ = re.sub("%([0-9]+)", r"\\\1", to_)
      text = re.sub(from_, to_, text)
  if "entryNameRemoveDiacritics" in blib.languages_byCode[langcode]:
    diacritics_to_remove = blib.languages_byCode[langcode]["entryNameRemoveDiacritics"]
    text = unicodedata.normalize(
      "NFC", re.sub("[" + diacritics_to_remove + "]", "", unicodedata.normalize("NFD", text))
    )
  return text

def process_page(page, index, templates):
  pagetitle = str(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
  parsed = blib.parse_text(str(page.text))
  for t in parsed.filter_templates():
    if tname(t) in templates:
      lang = getparam(t, "1")
      if lang not in blib.languages_byCode:
        pagemsg("WARNING: Unrecognized language code %s" % lang)
        continue
      langname = blib.languages_byCode[lang]["canonicalName"]
      term = getparam(t, "2")
      pagenm = remove_diacritics(term, lang)
      if not pagenm:
        continue
      if pagenm.startswith("*"):
        pagenm = "Reconstruction:%s/%s" % (langname, pagenm[1:])
      page = pywikibot.Page(site, pagenm)
      if blib.safe_page_exists(page, pagemsg):
        text = str(page.text)
        if re.search("#redirect", text, re.I):
          outtext = "exists as redirect"
        elif "==%s==" % langname in text:
          outtext = "exists"
        else:
          outtext = "exists only in some other language"
      else:
        outtext = "does not exist"
      end
      if term == pagenm:
        pagemsg("%s [[%s]] %s" % (langname, pagenm, outtext))
      else:
        pagemsg("%s [[%s|%s]] %s" % (langname, pagenm, term, outtext))

parser = blib.create_argparser(u"Find red/yellow links", include_pagefile=True)
parser.add_argument("--templates", help="Comma-separated list of templates to check", required=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

templates = args.templates.split(",")
def do_process_page(page, index):
  process_page(page, index, templates)
blib.do_pagefile_cats_refs(args, start, end, do_process_page)
