#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse, unicodedata

import blib
from blib import getparam, rmparam, msg, errmsg, site, tname

blib.getData()

def nfd(text):
  return unicodedata.normalize("NFD", text)

def process_text_on_page(index, pagename, text):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagename, txt))
  def errandpagemsg(txt):
    errandmsg("Page %s %s: %s" % (index, pagename, txt))

  origtext = text
  notes = []
  new_lines = []
  lines = text.split("\n")
  in_translation_section = False
  for lineind, line in enumerate(lines):
    if re.search(r"^\{\{(trans-top|checktrans-top|trans-top-see|trans-top-also)[|}]", line):
      if in_translation_section:
        pagemsg("WARNING: Nested translation sections, skipping page, nested opening line follows: %s" % line)
        return
      in_translation_section = True
      opening_trans_line = line
      prev_lang = ""
      translation_lines = []
      new_lines.append(line)
    elif line.startswith("{{trans-bottom"):
      if not in_translation_section:
        pagemsg("WARNING: Found {{trans-bottom}} not in a translation section")
      else:
        if not opening_trans_line.startswith("{{checktrans"):
          translation_lines = [(nfd(lang), lineind, line) for lang, lineind, line in translation_lines]
          new_translation_lines = sorted(translation_lines)
          if translation_lines != new_translation_lines:
            translation_lines = new_translation_lines
            notes.append("sort translation lines")
        for lang, lineind, transline in translation_lines:
          new_lines.append(transline)
      new_lines.append(line)
      in_translation_section = False
    elif in_translation_section:
      if line.startswith("{{multitrans|"):
        translation_lines.append(("", lineind, line))
      elif line.startswith("}}") or line.startswith("<!-- close multitrans") or line.startswith("<!-- close {{multitrans"):
        translation_lines.append(("\U0010FFFF", lineind, line))
      else:
        newline = line.replace("\u00A0", " ")
        if newline != line:
          line = newline
          notes.append("replace NBSP with regular space in translation section")
        if not line.strip():
          notes.append("skip blank line in translation section")
          continue
        def replace_ttbc(m):
          langcode = m.group(1)
          if langcode in blib.languages_byCode:
            langname = blib.languages_byCode[langcode]["canonicalName"]
            notes.append("replace {{ttbc|%s}} with %s" % (langcode, langname))
            return langname
          pagemsg("WARNING: Unrecognized langcode %s in {{ttbc}}: %s" % (langcode, line))
          return m.group(0)
        line = re.sub(r"\{\{ttbc\|([^{}|=]*)\}\}", replace_ttbc, line)
        m = re.search(r"^\*\*( *\w[^:{}]*?: *\{\{.*)$", line)
        if m:
          line = "*:" + m.group(1)
          notes.append("replace ** with *: in translation section")
        m = re.search(r"^(\*:* *)(\w[^:{}]*?)( *\{\{.*)$", line)
        if m:
          init, potential_lang, rest = m.groups()
          if potential_lang in blib.languages_byCanonicalName:
            pagemsg("Adding missing colon after language %s: %s" % (potential_lang, line))
            line = init + potential_lang + ":" + rest
            notes.append("add missing colon after language name '%s' in translation section" % (potential_lang))
        m = re.search(r"^\* *: *([^:]*):(.*)$", line)
        if m:
          indented_lang, rest = m.groups()
          if indented_lang in ["Acehnese", "Ambonese Malay", "Baba Malay", "Balinese", "Banda", "Banjarese", "Batavian", "Buginese", "Brunei", "Brunei Malay", "Ende", "Indonesian", "Jambi Malay", "Javanese", "Kelantan-Pattani Malay", "Madurese", "Makasar", "Minangkabau", "Nias", "Sarawak Malay", "Sarawakian", "Sikule", "Simeulue", "Singkil", "Sundanese", "Terengganu Malay"]:
            # Javanese variants: Central Javanese, Western Javanese, Kaili, Krama, Ngoko, Old Javanese
            pagemsg("Found %s translation indented under %s, unindenting: %s" % (indented_lang, prev_lang, line))
            line = "* %s:%s" % (indented_lang, rest)
            translation_lines.append((indented_lang, lineind, line))
            notes.append("unindent translation for %s under %s" % (indented_lang, prev_lang))
          else:
            if indented_lang not in ["Carakan", "Roman", "Jawi", "Rumi", "Arabic", "Latin"] and prev_lang in ["Indonesian", "Javanese", "Malay"]:
              pagemsg("WARNING: Found unhandled indented language %s under %s: %s" % (indented_lang, prev_lang, line))
            translation_lines.append((prev_lang, lineind, line))
        else:
          m = re.search(r"^\* *(\w[^:]*):(.*)$", line)
          if not m:
            pagemsg("WARNING: Unrecognized line in translation section: %s" % line)
            translation_lines.append((prev_lang, lineind, line))
          else:
            lang, rest = m.groups()
            prev_lang = lang
            translation_lines.append((lang, lineind, line))
    else:
      new_lines.append(line)

  text = "\n".join(new_lines)

  if text != origtext and not notes:
    notes.append("sort translation lines")
    pagemsg("WARNING: Adding default changelog 'sort translation lines'")
  return text, notes

parser = blib.create_argparser("Sort translations, unindent translations under Malayic and correct misc translation table issues",
                               include_pagefile=True, include_stdin=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True)
