#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, set_template_name, msg, errmsg, site, tname

trans_templates = blib.translation_templates + ["t-simple"]

arabic_charset = "؀-ۿݐ-ݿࢠ-ࣿﭐ-﷽ﹰ-ﻼ"

code_to_kurdish_lang = {
  "kmr": "Northern Kurdish",
  "ckb": "Central Kurdish",
  "sdh": "Southern Kurdish", 
  "lki": "Laki",
  "hac": "Gurani",
  "zza": "Zazaki",
}

def process_text_on_page(index, pagename, text):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagename, txt))
  def errandpagemsg(txt):
    errandmsg("Page %s %s: %s" % (index, pagename, txt))

  pagemsg("Processing")

  notes = []

  new_lines = []
  lines = text.split("\n")
  in_kurdish_section = False
  for line in lines:
    just_began_kurdish_section = False
    if line.startswith("* Kurdish"):
      in_kurdish_section = True
      just_began_kurdish_section = True
      translations_by_lang = {}
      kurdish_section_lines = []
    if not just_began_kurdish_section and in_kurdish_section and not line.startswith("*:"):
      in_kurdish_section = False
      translations_by_langname = []
      for code, translations in translations_by_lang.items():
        if code in code_to_kurdish_lang:
          translations_by_langname.append((code_to_kurdish_lang[code], translations))
        else:
          pagemsg("WARNING: Saw unrecognized lang code %s, not touching section: %s" % (
            code, ", ".join(translations)))
          new_lines.extend(kurdish_section_lines)
          break
      else: # no break
        new_lines.append("* Kurdish:")
        for langname, translations in sorted(translations_by_langname, key=lambda x:x[0]):
          new_lines.append("*: %s: %s" % (langname, ", ".join(translations)))
      new_lines.append(line)
    elif in_kurdish_section:
      kurdish_section_lines.append(line)
      line = re.sub(r"^\*:?\s*([A-Z][a-z]*\s*)*\s*:?\s*", "", line).strip()
      if line:
        translations_and_separators = [x.strip() for x in re.split(r"((?:\{\{.*?\}\}|[^,]*)*)", line)]
        translations = []
        for i, translation_or_sep in enumerate(translations_and_separators):
          if i % 2 == 1:
            translations.append(translation_or_sep)
        for i in range(len(translations)):
          translation = translations[i]
          translation = re.sub(r"\{\{t-needed\|ku\}\}", "{{t-needed|kmr}}", translation)
          templates_and_separators = re.split(r"(\{\{.*?\}\})", translation)
          for j in range(len(templates_and_separators)):
            if j % 2 == 0:
              # not a template
              newtext = templates_and_separators[j]
              def sub_links(newtext):
                # handle one-part links
                newtext = re.sub(r"\[\[([^" + arabic_charset + ":|]*?)\]\]", r"{{t|kmr|\1}}", newtext)
                # handle two-part links
                newtext = re.sub(r"\[\[([^" + arabic_charset + ":|]*?)\|([^" + arabic_charset + ":|]*?)\]\]",
                    r"{{t|kmr|\1|alt=\2}}", newtext)
                return newtext
              if "[[" in newtext:
                # 1. If there are commas/periods/parens/etc. or HTML comment parts in the text, link the parts individually.
                # 2. Otherwise, if the whole thing is a link, convert appropriately to {{t|kmr|...}}.
                # 3. Otherwise, we have a mixture of links and non-link text; just surround the whole thing with {{t|kmr|...}}.
                if not re.search(r"[(),.;:/]|<!--|-->", newtext):
                  if re.search(r"^\[\[[^|\[\]]*\]\]$", newtext) or re.search(r"^\[\[[^|\[\]]*\|[^|\[\]]*\]\]$", newtext):
                    newtext = sub_links(newtext)
                  else:
                    newtext = "{{t|kmr|%s}}" % newtext
                else:
                  newtext = sub_links(newtext)
                if newtext != templates_and_separators[j]:
                  pagemsg("NOTE: Converted raw link(s) '%s' to '%s'" % (templates_and_separators[j], newtext))
                templates_and_separators[j] = newtext
          translations[i] = "".join(templates_and_separators)
        for translation in translations:
          parsed = blib.parse_text(translation)
          translation_lang = None
          for t in parsed.filter_templates():
            tn = tname(t)
            if tn in trans_templates:
              lang = getparam(t, "1")
              if not translation_lang:
                translation_lang = lang
              elif translation_lang != lang:
                pagemsg("WARNING: Saw multiple langs %s and %s in single translation entry: %s" % (
                  translation_lang, lang, translation))
          if not translation_lang:
            # FIXME, maybe check the script and/or the prefix
            pagemsg("WARNING: Couldn't identify language of translation section, assuming kmr: %s" % translation)
            translation_lang = "kmr"
          if translation_lang not in translations_by_lang:
            translations_by_lang[translation_lang] = []
          translations_by_lang[translation_lang].append(translation)
    elif not just_began_kurdish_section:
      new_lines.append(line)

  text = "\n".join(new_lines)

  return text, "reformat Kurdish translations"

parser = blib.create_argparser("Reformat Kurdish translations", include_pagefile=True,
    include_stdin=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True)
