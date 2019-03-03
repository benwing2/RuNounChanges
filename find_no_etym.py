#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site

import rulib

def process_page(index, page):
  pagetitle = unicode(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  def errpagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
    errmsg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  pagetext = unicode(page.text)

  section = blib.find_lang_section_from_text(pagetext, "Russian", pagemsg)
  if not section:
    errpagemsg("WARNING: Couldn't find Russian section")
    return

  if "==Etymology" in section:
    return
  if rulib.check_for_alt_yo_terms(section, pagemsg):
    return
  parsed = blib.parse_text(section)
  for t in parsed.filter_templates():
    if unicode(t.name) in ["ru-participle of"]:
      pagemsg("Skipping participle")
      return

  msg("%s no-etym" % pagetitle)

parser = blib.create_argparser("Find terms without etymology")
parser.add_argument('--cats', default="Russian lemmas", help="Categories to do (can be comma-separated list)")
parser.add_argument('--refs', help="References to do (can be comma-separated list)")
parser.add_argument('--lemmafile', help="File of lemmas to process. May have accents.")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

if args.lemmafile:
  lemmas = []
  for i, pagename in blib.iter_items([rulib.remove_accents(x.strip()) for x in codecs.open(args.lemmafile, "r", "utf-8")]):
    page = pywikibot.Page(site, pagename)
    process_page(i, page)
elif args.refs:
  for ref in re.split(",", args.refs):
    msg("Processing references to: %s" % ref)
    for i, page in blib.references(ref, start, end):
      process_page(i, page)
else:
  for cat in re.split(",", args.cats):
    msg("Processing category: %s" % cat)
    for i, page in blib.cat_articles(cat, start, end):
      process_page(i, page)
