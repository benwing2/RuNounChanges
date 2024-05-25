#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse, unicodedata

import blib
from blib import getparam, rmparam, msg, errmsg, site, tname
from collections import defaultdict
import json

accent_qualifier_data = None
total_qualifiers = defaultdict(int)
qualifiers_by_lang = defaultdict(lambda: defaultdict(int))
pages_for_qualifiers_by_lang = defaultdict(lambda: defaultdict(set))
too_many_pages_for_qualifiers_by_lang = defaultdict(lambda: defaultdict(bool))
accent_labels_seen = defaultdict(int)
accent_aliases_seen = defaultdict(int)
labels_aliases = defaultdict(set)
labels_langs = defaultdict(set)

blib.getData()

def process_text_on_page(index, pagename, text):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagename, txt))
  def errandpagemsg(txt):
    errandmsg("Page %s %s: %s" % (index, pagename, txt))

  if not re.search(r"\{\{ *(IPA|a(ccent)?) *\|", text):
    return
  sections, sections_by_lang, section_langs = blib.split_text_into_sections(text, pagemsg)
  def record_qual_and_lang(qual, lang):
    total_qualifiers[qual] += 1
    qualifiers_by_lang[qual][lang] += 1
    if not too_many_pages_for_qualifiers_by_lang[qual][lang]:
      pageset = pages_for_qualifiers_by_lang[qual][lang]
      if pagename not in pageset:
        if len(pageset) < 10:
          pageset.add(pagename)
        else:
          too_many_pages_for_qualifiers_by_lang[qual][lang] = True
  for j, lang in section_langs:
    sectext = sections[j]
    if not re.search(r"\{\{ *(IPA|a(ccent)?) *\|", sectext):
      continue
    parsed = blib.parse_text(sectext)
    for t in parsed.filter_templates():
      tn = tname(t)
      if tn in ["a", "accent"]:
        params = blib.fetch_param_chain(t, "1")
        for paramind, param in enumerate(params):
          param = param.strip()
          if paramind == 0:
            pseudo_langname = None
            pseudo_langtype = None
            if param in blib.languages_byCode:
              pseudo_langname = blib.languages_byCode[param]["canonicalName"]
              pseudo_langtype = "full"
            elif param in blib.etym_languages_byCode:
              pseudo_langname = blib.etym_languages_byCode[param]["canonicalName"]
              pseudo_langtype = "etym-only"
            if pseudo_langtype:
              pass
              #if len(params) == 1:
              #  pagemsg("WARNING: Saw qualifier '%s' same as language code for %s language '%s' in lang section '%s' but only one qualifier: %s" % (
              #    param, pseudo_langtype, pseudo_langname, lang, str(t)))
              #else:
              #  pagemsg("WARNING: Saw qualifier '%s' same as language code for %s language '%s' in lang section '%s' and multiple qualifiers: %s" % (
              #    param, pseudo_langtype, pseudo_langname, lang, str(t)))
          record_qual_and_lang(param, lang)
      if tn == "IPA":
        pass

parser = blib.create_argparser("Analyze usage of qualifiers in {{a}}/{{accent}}",
                               include_pagefile=True, include_stdin=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

def read_aliases():
  global accent_qualifier_data
  def pagemsg(txt):
    msg("Page 0: %s" % txt)
  def errandpagemsg(txt):
    errandmsg("Page 0: %s" % txt)
  def expand_text(tempcall):
    return blib.expand_text(tempcall, "foo", pagemsg, args.verbose)
  accent_qualifier_data = json.loads(expand_text("{{#invoke:accent qualifier|output_data_module}}"))

read_aliases()

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True)

msg("%-50s %5s: %s" % ("Qualifier", "Count", "Count-by-lang"))
msg("----------------------------------------------------")
for qualifier, count in sorted(list(total_qualifiers.items()), key=lambda x:-x[1]):
  qualifier_alias_label = None
  if qualifier in accent_qualifier_data["aliases"]:
    qualifier_alias_label = accent_qualifier_data["aliases"][qualifier]
    rec = "-> %s" % qualifier_alias_label
    accent_aliases_seen[qualifier] += 1
  elif qualifier in accent_qualifier_data["labels"]:
    rec = "label"
    accent_labels_seen[qualifier] += 1
  else:
    rec = "unknown"
  def get_langcount_and_pages(lang, langcount):
    labels_langs[qualifier_alias_label or qualifier].add(lang)
    if too_many_pages_for_qualifiers_by_lang[qualifier][lang]:
      return str(langcount)
    else:
      return "%s: %s" % (langcount, ",".join(sorted(list(pages_for_qualifiers_by_lang[qualifier][lang]))))
  by_lang = "; ".join("%s (%s)" % (lang, get_langcount_and_pages(lang, langcount))
                      for lang, langcount in sorted(list(qualifiers_by_lang[qualifier].items()), key=lambda x:-x[1]))

  msg("%-50s (%s) %5s: %s" % (qualifier, rec, count, by_lang))

for alias, label in accent_qualifier_data["aliases"].items():
  labels_aliases[label].add(alias)
  if label not in accent_qualifier_data["labels"]:
    msg("-- WARNING: Saw alias '%s' of nonexistent label '%s'" % (alias, label))

for label, labelobj in sorted(list(accent_qualifier_data["labels"].items()), key=lambda x: x[0].lower()):
  display = labelobj.get("display", None)
  link = labelobj.get("link", None)
  if link is None:
    actual_display = display
  else:
    actual_display = display or link
  if actual_display is None:
    msg("-- WARNING: Neither link= or display= specified")
  langs = labels_langs[label]
  langcodes = set()
  for lang in langs:
    if lang not in blib.languages_byCanonicalName:
      msg("-- WARNING: Can't convert language '%s' to language code" % lang)
    else:
      langcode = blib.languages_byCanonicalName[lang]["code"]
      langcodes.add(langcode)
  aliases = labels_aliases[label]
  msg('labels["%s"] = {' % label)
  if aliases:
    msg('\taliases = {%s},' % ", ".join('"%s"' % alias for alias in sorted(list(aliases))))
  msg('\tlangs = {%s},' % ", ".join('"%s"' % langcode for langcode in sorted(list(langcodes))))
  if link == label:
    msg('\tWikipedia = true,')
  elif link:
    msg('\tWikipedia = "%s",' % link)
  if actual_display is None:
    msg('\tdisplay = false,')
  elif actual_display != label:
    msg('\tdisplay = "%s",' % actual_display)
  msg("}")
  msg("")
