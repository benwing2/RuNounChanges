#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, errandmsg, site, tname, pname

import lalib
from lalib import remove_macrons

def process_text_on_page(index, pagetitle, text):
  global args

  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
  def errandpagemsg(txt):
    errandmsg("Page %s %s: %s" % (index, pagetitle, txt))

  if not args.stdin:
    pagemsg("Processing")

  # Greatly speed things up when --stdin by ignoring non-Latin pages
  if "==Latin==" not in text:
    return None, None

  if not re.search("la-(noun|proper noun|pronoun|verb|adj|num|suffix)-form", text):
    return None, None

  retval = lalib.find_latin_section(text, pagemsg)
  if retval is None:
    return None, None
  
  sections, j, secbody, sectail, has_non_latin = retval

  parsed = blib.parse_text(secbody)
  for t in parsed.filter_templates():
    tn = tname(t)
    if tn in ["la-noun-form", "la-proper noun-form", "la-pronoun-form", "la-verb-form",
        "la-adj-form", "la-num-form", "la-suffix-form"]:
      if not getparam(t, "1"):
        pagemsg("WARNING: Missing 1=: %s" % unicode(t))
      for param in t.params:
        pn = pname(param)
        if pn not in ["1", "g", "g2", "g3", "g4"]:
          pagemsg("WARNING: Extraneous param %s=: %s" % (pn, unicode(t)))
  return None, None

def process_page(page, index, parsed):
  pagetitle = unicode(page.title())
  text = unicode(page.text)
  return process_text_on_page(index, pagetitle, text)

parser = blib.create_argparser("Check for Latin non-lemma forms with bad params")
parser.add_argument("--stdin", help="Read dump from stdin.", action="store_true")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

if args.stdin:
  blib.parse_dump(sys.stdin, process_text_on_page)
else:
  for i, page in blib.cat_articles("Latin non-lemma forms", start, end):
    blib.do_edit(page, i, process_page, save=args.save, verbose=args.verbose)
