#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse, unicodedata

import blib
from blib import getparam, rmparam, tname, pname, msg, site

conventional_names = {
  "beginning": "Beginning Mandarin",
  "elementary": "Elementary Mandarin",
  "intermediate": "Intermediate Mandarin",
  "advanced": "Advanced Mandarin",
  "antonymous": "Chinese antonymous compounds",
  "disyllabic": "Chinese disyllabic morphemes",
  "variant": "Chinese variant forms",
  "simplified": "Chinese simplified forms",
  "obsolete": "Chinese obsolete terms",
  "wasei kango": "Wasei kango",
  "twice-borrowed": "Chinese twice-borrowed terms",
  "tcm": "zh:Traditional Chinese medicine",
  "phrasebook": "Chinese phrasebook",
  "short": "Chinese short forms",
  "genericized trademark": "Chinese genericized trademarks",
  "taboo": "Chinese terms arising from taboo avoidance",
  "triplicated": "Triplicated Chinese characters",
  "duplicated": "Duplicated Chinese characters",
  "quadruplicated": "Quadruplicated Chinese characters",
  "stratagem": "Thirty-Six Stratagems",
  "juxtapositional idiom": "Chinese juxtapositional idioms",
  "pseudo-idiom": "Chinese pseudo-idioms",
  "contranym": "Chinese contranyms",
  "xiehouyu": "Chinese xiehouyu",
  "character shape word": "Chinese terms making reference to character shapes",
  "mandarin informal terms": "Mandarin informal terms",

  "reduplicative diminutive nouns": "Chinese reduplicative diminutive nouns",
  "reduplicative diminutive proper nouns": "Chinese reduplicative diminutive proper nouns",
  "reduplicative diminutive pronouns": "Chinese reduplicative diminutive pronouns",
}

def process_text_on_page(index, pagetitle, text):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  notes = []

  parsed = blib.parse_text(text)
  origtemps = []
  cat_zh_items = []
  cat_cmn_items = []
  cln_zh_items = []
  cln_cmn_items = []
  topics_zh_items = []

  def append(lst, item):
    if item not in lst:
      lst.append(item)

  for t in parsed.filter_templates():
    def getp(param):
      return getparam(t, param)
    tn = tname(t)
    if tn == "zh-cat":

      origtemps.append(str(t))
      terms = blib.fetch_param_chain(t, "1")
      must_continue = False
      for i, term in enumerate(terms):
        termind = i + 1
        lcterm = term.lower()
        if lcterm in conventional_names:
          cat = conventional_names[lcterm]
          m = re.search("^(Chinese )(.*)$", cat)
          if m:
            append(cln_zh_items, m.group(2))
          if not m:
            m = re.search("^(Mandarin )(.*)$", cat)
            if m:
              append(cln_cmn_items, m.group(2))
          if not m:
            m = re.search("^(zh:)(.*)$", cat)
            if m:
              append(topics_zh_items, m.group(2))
          if not m:
            m = re.search("Chinese", cat)
            if m:
              append(cat_zh_items, cat)
          if not m:
            m = re.search("Mandarin", cat)
            if m:
              append(cat_cmn_items, cat)
          if not m:
            append(cat_zh_items, cat)
        else:
          append(topics_zh_items, term)

  newlines = []
  if cat_zh_items:
    newlines.append("{{cat|zh|%s}}" % "|".join(cat_zh_items))
  if cat_cmn_items:
    newlines.append("{{cat|cmn|%s}}" % "|".join(cat_cmn_items))
  if cln_zh_items:
    newlines.append("{{cln|zh|%s}}" % "|".join(cln_zh_items))
  if cln_cmn_items:
    newlines.append("{{cln|cmn|%s}}" % "|".join(cln_cmn_items))
  if topics_zh_items:
    newlines.append("{{C|zh|%s}}" % "|".join(topics_zh_items))

  if not newlines:
    if origtemps:
      pagemsg("WARNING: Something wrong, no replacement text but saw original template(s) %s"
        % ",".join(origtemps))
  else:
    if len(origtemps) > 1:
      pagemsg("Saw %s original templates, removing all but last one" % len(origtemps))
      for origtemp in origtemps[:-1]:
        if "\n" + origtemp + "\n" in text:
          text, did_replace = blib.replace_in_text(text, "\n" + origtemp + "\n", "\n", pagemsg, no_found_repl_check=True)
        else:
          text, did_replace = blib.replace_in_text(text, origtemp, "", pagemsg, no_found_repl_check=True)
        if not did_replace:
          return
    origtemp = origtemps[-1]
    if re.search("^" + re.escape(origtemp) + "$", text, re.M):
      repltext = "\n".join(newlines)
    else:
      # If the {{zh-cat}} occurs along with something else (e.g. a defn) on the line, it might not be safe to replace
      # with multiple lines.
      repltext = "".join(newlines)
    text, did_replace = blib.replace_in_text(text, origtemp, repltext, pagemsg)
    if not did_replace:
      return
    notes.append("convert {{zh-cat}} to generic template(s)")
    newtext = re.sub("  +", " ", text)
    if newtext != text:
      notes.append("compress multiple spaces into one")
      text = newtext
    newtext = text.replace(" \n", "\n")
    if newtext != text:
      notes.append("remove space at end of line")
      text = newtext

  return text, notes

parser = blib.create_argparser("Convert {{zh-cat}} to generic template(s)",
                               include_pagefile=True, include_stdin=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True)
