#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, tname, msg, site

import lalib

def compare_new_and_old_templates(t, pagetitle, pagemsg, errandpagemsg):
  global args
  def expand_text(tempcall):
    return blib.expand_text(tempcall, pagetitle, pagemsg, args.verbose)

  old_generate_template = re.sub(r"^\{\{la-ndecl\|", "{{la-generate-noun-forms|", t)
  old_result = expand_text(old_generate_template)
  if not old_result:
    old_forms = None
  else:
    old_forms = blib.split_generate_args(old_result)
  if old_forms is None:
    errandpagemsg("WARNING: Error generating old forms, can't compare")
    return False
  new_generate_template = re.sub(r"^\{\{la-ndecl\|", "{{User:Benwing2/la-new-generate-noun-forms|", t)
  new_result = expand_text(new_generate_template)
  if not new_result:
    errandpagemsg("WARNING: Error generating new forms, can't compare")
    return False
  new_forms = blib.split_generate_args(new_result)
  for form in set(old_forms.keys() + new_forms.keys()):
    if form not in new_forms:
      pagemsg("WARNING: form %s=%s in old forms but missing in new forms" % (
        form, old_forms[form]))
      return False
    if form not in old_forms:
      pagemsg("WARNING: form %s=%s in new forms but missing in old forms" % (
        form, new_forms[form]))
      return False
    if new_forms[form] != old_forms[form]:
      pagemsg("WARNING: form %s=%s in old forms but =%s in new forms" % (
        form, old_forms[form], new_forms[form]))
      return False
  pagemsg("Old and new implementations of %s compare the same" % t)
  return True

def process_page(index, page):
  pagetitle = unicode(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
  def errandpagemsg(txt):
    errandmsg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  parsed = blib.parse_text(unicode(page.text))

  for t in parsed.filter_templates():
    tn = tname(t)
    if tn == "la-ndecl":
      compare_new_and_old_templates(unicode(t), pagetitle, pagemsg, errandpagemsg)

parser = blib.create_argparser("Check potential changes to {{la-ndecl}} implementation")
parser.add_argument("--pagefile", help="List of pages to process.")
parser.add_argument("--cats", help="List of categories to process.")
parser.add_argument("--refs", help="List of references to process.")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

if args.pagefile:
  pages = [x.rstrip('\n') for x in codecs.open(args.pagefile, "r", "utf-8")]
  for i, page in blib.iter_items(pages, start, end):
    process_page(i, pywikibot.Page(site, page))
else:
  if not args.cats and not args.refs:
    cats = []
    refs = ["Template:la-ndecl"]
  else:
    cats = args.cats and [x.decode("utf-8") for x in args.cats.split(",")] or []
    refs = args.refs and [x.decode("utf-8") for x in args.refs.split(",")] or []

  for cat in cats:
    for i, page in blib.cat_articles(cat, start, end):
      process_page(i, page)
  for ref in refs:
    for i, page in blib.references(ref, start, end):
      process_page(i, page)
