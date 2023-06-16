#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, tname, pname, msg, site

blib.getData()

def process_text_on_page(index, pagetitle, text):
  global args
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
  origtext = text
  notes = []
  sections = re.split("(^==[^\n=]*==\n)", text, 0, re.M)
  for j in range(2, len(sections), 2):
    m = re.search("^==(.*?)==\n$", sections[j - 1])
    if not m:
      pagemsg("WARNING: Something wrong, can't parse section from %s" %
        sections[j - 1].strip())
      continue
    thislangname = m.group(1)
    if thislangname not in blib.languages_byCanonicalName:
      pagemsg("WARNING: Unrecognized section lang %s" % thislangname)
      continue
    thislangcode = blib.languages_byCanonicalName[thislangname]["code"]
    def replace_name_translit(m):
      origline = m.group(0)
      source_lang, name_type, template, period = m.groups()
      if source_lang not in blib.languages_byCanonicalName:
        pagemsg("WARNING: Unrecognized source lang %s, can't parse: <from> %s <to> %s <end>" %
          (source_lang, origline, origline))
        return origline
      source_lang_code = blib.languages_byCanonicalName[source_lang]["code"]
      parsed = blib.parse_text(template)
      t = list(parsed.filter_templates())[0]
      lang = getparam(t, "1")
      name = getparam(t, "2")
      alt = getparam(t, "3")
      eq = blib.remove_links(getparam(t, "4"))
      if source_lang_code != lang:
        pagemsg("WARNING: Source lang code %s for %s != template lang code %s, can't parse: <from> %s <to> %s <end>" %
          (source_lang_code, source_lang, lang, origline, origline))
        return origline
      if alt:
        pagemsg("WARNING: Can't handle alt=%s in %s: <from> %s <to> %s <end>" %
          (alt, str(t), origline, origline))
        return origline
      for param in t.params:
        pn = pname(param)
        if pn not in ["1", "2", "3", "4", "sc"]:
          pagemsg("WARNING: Can't handle %s=%s in %s: <from> %s <to> %s <end>" %
            (pn, str(param.value), origline, origline))
          return origline
      return "{{name translit|%s|%s|%s|type=%s%s}}%s" % (thislangcode, source_lang_code, name, name_type,
          "|eq=%s" % eq if eq else "", period)
    newsec = re.sub(r"'*(?:\{\{(?:non-gloss definition|non-gloss|ngd|n-g)\|)*A \[*transliteration\]* of the ([A-Z][a-z]*) (male given name|female given name|surname|patronymic) (\{\{[lm]\|[a-zA-Z-]*\|[^{}]*?\}\})\}*'*(\.?)'*}*", replace_name_translit, sections[j])
    if newsec != sections[j]:
      notes.append("templatize {{name translit}} usage for lang '%s'" % thislangname)
      sections[j] = newsec
  return "".join(sections), notes

parser = blib.create_argparser("Templatize 'A transliteration of LANG name NAME' into {{name translit}}",
  include_pagefile=True, include_stdin=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True)
