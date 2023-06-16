#!/usr/bin/env python3
# -*- coding: utf-8 -*-

# Given the file from ruwikt of words where е is pronounced hard, check
# the words in enwikt to see their pronunciations.

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site

def process_page(index, page, phon, softphon, variant, verbose, lemmas):
  pagetitle = str(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  if not page.exists():
    pagemsg("Page doesn't exist, should have pron phon=%s%s" % (phon,
      variant and " with variant %s" % variant or ""))
    return
  if "==Russian==" not in page.text:
    pagemsg("Page doesn't have Russian section, should have pron phon=%s%s" % (
      phon, variant and " with variant %s" % variant or ""))
    return
  if lemmas and pagetitle not in lemmas:
    pagemsg("Page doesn't have a lemma on it, should have pron phon=%s%s" % (
      phon, variant and " with variant %s" % variant or ""))
    return

  parsed = blib.parse_text(page.text)
  prons = []
  for t in parsed.filter_templates():
    tname = str(t.name)
    if tname in ["ru-IPA"]:
      tphon = getparam(t, "phon")
      if tphon:
        prons.append("phon=%s" % tphon)
      else:
        prons.append(getparam(t, "1") or pagetitle)
  altexpected = None
  phon = "phon=%s" % phon
  if not variant:
    expected = [phon]
  elif variant == "=":
    expected = [phon, softphon]
    altexpected = [softphon, phon]
  elif variant == u"+е":
    expected = [softphon, phon]
  elif variant == u"+э":
    expected = [phon, softphon]
  else:
    pagemsg("WARNING: Bad variant %s, skipping" % variant)
    return
  if altexpected:
    if prons == expected or prons == altexpected:
      pagemsg("Found pronunciation %s matching expected pronunciation %s or %s"
          % (",".join(prons), ",".join(expected), ",".join(altexpected)))
    else:
      pagemsg("WARNING: Mismatched pronunciation, found %s, expected %s or %s"
          % (",".join(prons), ",".join(expected), ",".join(altexpected)))
  else:
    if prons == expected:
      pagemsg("Found pronunciation %s matching expected pronunciation %s"
          % (",".join(prons), ",".join(expected)))
    else:
      pagemsg("WARNING: Mismatched pronunciation, found %s, expected %s"
          % (",".join(prons), ",".join(expected)))
    
parser = blib.create_argparser(u"Check for words in enwikt that should have hard е")
parser.add_argument('--direcfile', help=u"File containing words from ruwikt page Приложение:Русские_слова_с_твёрдым_парным_согласным_перед_Е specifying words that should have hard е")
parser.add_argument('--lemmafile', help="File containing lemmas, needed to check for non-lemmas that look like lemmas")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

if not args.direcfile:
  raise RuntimeError("--direcfile required")
if not args.lemmafile:
  lemmas = None
else:
  lemmas = set(blib.yield_items_from_file(args.lemmafile))
for i, line in blib.iter_items_from_file(args.direcfile, start, end):
  if not line.startswith("*"):
    msg("Page %s ???: Ignoring line: %s" % (i, line))
  else:
    m = re.search(ur"^\*\[\[([^\[\]|]*?)\|([^\[\]]*?)\]\]( \{(=|\+э|\+е)\}\??)?$", line)
    if not m:
      msg("Page %s ???: WARNING: Can't parse line: %s" % (i, line))
    else:
      phon = m.group(2)
      phon = re.sub(ur"\{\{red\|е\}\}", u"э", phon)
      phon = re.sub(ur"\{\{red\|е́\}\}", u"э́", phon)
      phon = re.sub(ur"\{\{red\|ѐ\}\}", u"э̀", phon)
      softphon = m.group(2)
      softphon = re.sub(ur"\{\{red\|(.*?)\}\}", r"\1", softphon)
      process_page(i, pywikibot.Page(site, m.group(1)), phon, softphon,
          m.group(4), args.verbose, lemmas)
