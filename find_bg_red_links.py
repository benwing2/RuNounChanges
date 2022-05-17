#!/usr/bin/env python
# -*- coding: utf-8 -*-

# Find redlinks (non-existent pages).

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site

parser = blib.create_argparser(u"Find red links")
parser.add_argument("--pagefile", help="File containing pages to check")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

lemmas = set()
msg("Reading Bulgarian lemmas")
for i, page in blib.cat_articles("Bulgarian lemmas", start, end):
  lemmas.add(unicode(page.title()))

lines = [x.strip() for x in codecs.open(args.pagefile, "r", "utf-8")]
words = lines

for i, line in blib.iter_items(words, start, end):
  pagename, freq = line.split("\t")
  m = re.search(u"[^-Ѐ-џҊ-ԧꚀ-ꚗ]", pagename)
  def fmsg(txt):
    msg("Page %s [[%s]]: %s (freq %s)" % (i, pagename, txt, freq))
  if m:
    fmsg("skipped due to non-Cyrillic characters")
  else:
    for pagenm, pagetype in [(pagename, ""),
        (pagename.capitalize(), " (capitalized)"),
        (pagename.upper(), " (uppercased)")]:
      if pagenm in lemmas:
        fmsg("exists%s" % pagetype)
        break
      else:
        page = pywikibot.Page(site, pagenm)
        if page.exists():
          text = unicode(page.text)
          if re.search("#redirect", text, re.I):
            fmsg("exists%s as redirect" % pagetype)
          elif re.search(r"\{\{superlative of\|bg\|", text):
            fmsg("exists%s as superlative" % pagetype)
          elif "==Bulgarian==" in text:
            fmsg("exists%s as non-lemma" % pagetype)
          else:
            fmsg("exists%s only in some other language" % pagetype)
          break
    else:
      fmsg("does not exist")
