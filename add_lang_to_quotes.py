#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site, tname

borrowed_langs = {}

quote_templates = ["quote-book", "quote-hansard", "quote-journal",
  "quote-newsgroup", "quote-song", "quote-us-patent", "quote-video",
  "quote-web", "quote-wikipedia",
  # aliases
  "quote-news", "quote-magazine",
  # misc garbage
  "quote-poem", "quote-text",
]
blib.getData()

def process_page(page, index, parsed):
  pagetitle = unicode(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  text = unicode(page.text)
  notes = []

  sections = re.split("(^==[^=]*==\n)", text, 0, re.M)

  for j in xrange(2, len(sections), 2):
    m = re.search("^==(.*)==\n$", sections[j - 1])
    assert m
    langname = m.group(1)
    subsections = re.split("(^==.*==\n)", sections[j], 0, re.M)
    for k in xrange(2, len(subsections), 2):
      m = re.search("^===*([^=]*)=*==\n$", subsections[k - 1])
      assert m
      subsectitle = m.group(1)
      parsed = blib.parse_text(subsections[k])
      for t in parsed.filter_templates():
        origt = unicode(t)
        tn = tname(t)
        if tn in quote_templates:
          if getparam(t, "lang"):
            continue
          lang = getparam(t, "language")
          if lang:
            notes.append("Convert language=%s to lang=%s in %s" % (lang, lang, tn))
          else:
            if subsectitle.startswith("Etymology") or subsectitle.startswith("Pronunciation"):
              pagemsg("WARNING: Found template in %s section for language %s, might be different language, skipping: %s" % (
                subsectitle, langname, origt))
              continue
            if langname not in blib.languages_byCanonicalName:
              pagemsg("WARNING: Unrecognized language %s, unable to add language to %s" % (langname, tn))
              continue
            lang = blib.languages_byCanonicalName[langname]["code"]
            if lang == "en" and (getparam(t, "translation") or getparam(t, "t")):
              pagemsg("WARNING: Translation section in putative English quote, skipping: %s" % origt)
              continue
            if lang == "mul":
              notes.append("Infer lang=en for %s in Translingual section and add nocat=1" % tn)
            else:
              notes.append("Infer lang=%s for %s based on section it's in" % (lang, tn))
          rmparam(t, "language")
          # Fetch all params.
          params = []
          for param in t.params:
            pname = unicode(param.name)
            params.append((pname, param.value, param.showkey))
          # Erase all params.
          del t.params[:]
          if lang == "mul":
            nocat = True
            lang = "en"
          else:
            nocat = False
          # Put lang parameter.
          newline = "\n" if "\n" in unicode(t.name) else ""
          t.add("lang", lang + newline, preserve_spacing=False)
          if nocat:
            t.add("nocat", "1" + newline, preserve_spacing=False)
          # Put remaining parameters in order.
          for name, value, showkey in params:
            t.add(name, value, showkey=showkey, preserve_spacing=False)
          pagemsg("Replaced <%s> with <%s>" % (origt, unicode(t)))
      subsections[k] = unicode(parsed)
    sections[j] = "".join(subsections)

  newtext = "".join(sections)
  return newtext, notes

parser = blib.create_argparser("Add language to quote-* templates, based on the section it's within")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

for cat in ["Undetermined terms with quotations"]:
  msg("Processing category %s" % cat)
  for i, page in blib.cat_articles(cat, start, end):
    blib.do_edit(page, i, process_page, save=args.save, verbose=args.verbose)
