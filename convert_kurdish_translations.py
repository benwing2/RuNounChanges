#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, set_template_name, msg, errmsg, site, tname

northern_kurdish_lemmas = set()
for i, art in blib.cat_articles("Northern Kurdish lemmas"):
  northern_kurdish_lemmas.add(str(art.title()))
central_kurdish_lemmas = set()
for i, art in blib.cat_articles("Central Kurdish lemmas"):
  central_kurdish_lemmas.add(str(art.title()))

trans_templates = ["t", "t+", "t-", "tt", "tt+", "t-check", "t+check", "t-needed"]

arabic_charset = "؀-ۿݐ-ݿࢠ-ࣿﭐ-﷽ﹰ-ﻼ"

def process_text_on_page(index, pagename, text):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagename, txt))
  def errandpagemsg(txt):
    errandmsg("Page %s %s: %s" % (index, pagename, txt))

  pagemsg("Processing")

  notes = []

  def check_charset(t):
    langcode = getparam(t, "1")
    lemma = getparam(t, "2")
    is_arabic = re.search("^[%s]" % arabic_charset, lemma)
    if is_arabic and langcode == "kmr":
      pagemsg("WARNING: Arabic script but Northern Kurdish: %s" % str(t))
    elif not is_arabic and langcode == "ckb":
      pagemsg("WARNING: Latin script but Central Kurdish: %s" % str(t))

  def replace_trans(m, newlangcode, newlangname):
    prefix, transtext = m.groups()
    parsed = blib.parse_text(transtext)
    for t in parsed.filter_templates():
      origt = str(t)
      tn = tname(t)
      if tn in trans_templates:
        if getparam(t, "1") == "ku":
          t.add("1", newlangcode)
          rmparam(t, "sc")
          pagemsg("Replaced %s with %s based on language prefix of translation entry" % (origt, str(t)))
          notes.append("{{%s|ku}} -> {{%s|%s}} based on language prefix of translation entry" % (tn, tn, newlangcode))
      elif tn == "t-simple":
        if getparam(t, "1") == "ku":
          if getparam(t, "langname" != "Kurdish"):
            pagemsg("WARNING: Something wrong, t-simple|ku without langname=Kurdish: %s" % str(t))
          else:
            t.add("1", newlangcode)
            t.add("langname", newlangname)
            pagemsg("Replaced %s with %s based on prefix" % (origt, str(t)))
            notes.append("{{t-simple|ku|langname=Kurdish}} -> {{t-simple|%s|langname=%s}} based on language prefix" % (newlangcode, newlangname))
    transtext = str(parsed)
    return prefix + transtext

  text = re.sub("^(\*:? *Kurmanji: *)(.*)$", lambda m: replace_trans(m, "kmr", "Northern Kurdish"), text, 0, re.M)
  text = re.sub("^(\*:? *Sorani: *)(.*)$", lambda m: replace_trans(m, "ckb", "Central Kurdish"), text, 0, re.M)

  def replace_trans_by_lemma(m):
    prefix, transtext = m.groups()
    parsed = blib.parse_text(transtext)
    for t in parsed.filter_templates():
      origt = str(t)

      def check_lemma(lemma):
        lemma = blib.remove_links(lemma)
        if lemma in northern_kurdish_lemmas:
          return "kmr", "Northern Kurdish", "existence of Northern Kurdish lemma"
        elif lemma in central_kurdish_lemmas:
          return "ckb", "Central Kurdish", "existence of Central Kurdish lemma"
        elif lemma in known_northern_kurdish_terms:
          return "kmr", "Northern Kurdish", "Kurdish Wiktionary"
        elif lemma in known_central_kurdish_terms:
          return "ckb", "Central Kurdish", "Kurdish Wiktionary"
        elif re.search("^[%s]" % arabic_charset, lemma):
          return "ckb", "Central Kurdish", "Arabic charset"
        else:
          return "kmr", "Northern Kurdish", "Latin charset"

      tn = tname(t)
      if tn in trans_templates:
        if getparam(t, "1") == "ku":
          lemma = getparam(t, "2")
          newlangcode, newlangname, source = check_lemma(lemma)
          if newlangcode:
            t.add("1", newlangcode)
            rmparam(t, "sc")
            pagemsg("Replaced %s with %s based on %s" % (origt, str(t), source))
            notes.append("{{%s|ku}} -> {{%s|%s}} based on %s" % (tn, tn, newlangcode, source))
      elif tn == "t-simple":
        if getparam(t, "1") == "ku":
          if getparam(t, "langname" != "Kurdish"):
            pagemsg("WARNING: Something wrong, t-simple|ku without langname=Kurdish: %s" % str(t))
          else:
            lemma = getparam(t, "2")
            newlangcode, newlangname, source = check_lemma(lemma)
            if newlangcode:
              t.add("1", newlangcode)
              t.add("langname", newlangname)
              pagemsg("Replaced %s with %s based on %s" % (origt, str(t), source))
              notes.append("{{t-simple|ku|langname=Kurdish}} -> {{t-simple|%s|langname=%s}} based on %s" %
                  (newlangcode, newlangname, source))
    transtext = str(parsed)
    return prefix + transtext

  text = re.sub("^(\*:? *Kurdish: *)(.*)$", replace_trans_by_lemma, text, 0, re.M)

  for m in re.finditer("^\*:? *(.*?): *(.*)$", text, re.M):
    prefix, transtext = m.groups()
    parsed = blib.parse_text(transtext)
    for t in parsed.filter_templates():
      origt = str(t)
      tn = tname(t)
      if tn in trans_templates or tn == "t-simple":
        if getparam(t, "1") == "ku":
          lemma = getparam(t, "2")
          pagemsg("Unable to convert lemma %s for lang %s: %s" % (lemma, prefix, origt))

  for m in re.finditer("^(.*)$", text, re.M):
    (transtext,) = m.groups()
    parsed = blib.parse_text(transtext)
    for t in parsed.filter_templates():
      origt = str(t)
      tn = tname(t)
      if tn in trans_templates or tn == "t-simple":
        if getparam(t, "1") == "ku":
          lemma = getparam(t, "2")
          pagemsg("Unable to convert lemma %s: %s" % (lemma, transtext))
        check_charset(t)

  return text, notes

parser = blib.create_argparser("Convert 'Kurdish' translations to Northern Kurdish or Central Kurdish as possible", include_pagefile=True,
    include_stdin=True)
parser.add_argument("--known-kmr", help="File of known Northern Kurdish terms")
parser.add_argument("--known-ckb", help="File of known Central Kurdish terms")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

if args.known_kmr:
  known_northern_kurdish_terms = set(blib.yield_items_from_file(args.known_kmr))
else:
  known_northern_kurdish_terms = set()
if args.known_ckb:
  known_central_kurdish_terms = set(blib.yield_items_from_file(args.known_ckb))
else:
  known_central_kurdish_terms = set()
blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True)
