#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site, tname

import lalib
from lalib import remove_macrons

def process_text_on_page(index, pagetitle, text):
  global args

  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  if not args.stdin:
    pagemsg("Processing")

  # Greatly speed things up when --stdin by ignoring non-Latin pages
  if "==Latin==" not in text:
    return None, None

  retval = lalib.find_latin_section(text, pagemsg)
  if retval is None:
    return None, None
  sections, j, secbody, sectail, has_non_latin = retval
  parsed = blib.parse_text(secbody)
  for t in parsed.filter_templates():
    tn = tname(t)
    if tn in lalib.la_headword_templates:
      head = lalib.la_get_headword_from_template(t, pagetitle, pagemsg)
      no_macrons_head = remove_macrons(blib.remove_links(head))
      if pagetitle.startswith("Reconstruction"):
        unprefixed_title = "*" + re.sub(".*/", "", pagetitle)
      else:
        unprefixed_title = pagetitle
      if no_macrons_head != unprefixed_title:
        pagemsg("WARNING: Bad Latin head: %s" % unicode(t))
  return None, None

def process_page(page, index, parsed):
  pagetitle = unicode(page.title())
  text = unicode(page.text)
  return process_text_on_page(index, pagetitle, text)

parser = blib.create_argparser("Check for bad Latin forms")
parser.add_argument("--stdin", help="Read dump from stdin.", action="store_true")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

if args.stdin:
  blib.parse_dump(sys.stdin, process_text_on_page)
else:
  for i, page in blib.cat_articles("Latin non-lemma forms", start, end):
    blib.do_edit(page, i, process_page, save=args.save, verbose=args.verbose)
