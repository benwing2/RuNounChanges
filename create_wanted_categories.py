#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import blib, re
from blib import msg, errmsg, site
import pywikibot

def blacklist(category):
  return False
  # Formerly blacklisted because sort= should be given.
  #if " terms spelled with " in category and not re.search("^(Japanese|Okinawan) ", category):
  #  return True
  #return False

def process_page(page, index):
  global args
  pagetitle = str(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
  def errandpagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
    errmsg("Page %s %s: %s" % (index, pagetitle, txt))
  def expand_text(tempcall):
    return blib.expand_text(tempcall, pagetitle, pagemsg, args.verbose)
  if args.verbose:
    pagemsg("Processing")
  if page.exists():
    errandpagemsg("Page already exists, not overwriting")
    return
  if not pagetitle.startswith("Category:"):
    pagemsg("Page not a category, skipping")
    return
  catname = re.sub("^Category:", "", pagetitle)
  if blacklist(catname):
    pagemsg("Category is blacklisted, skipping")
    return
  num_pages = len(list(blib.cat_articles(catname)))
  num_subcats = len(list(blib.cat_subcats(catname)))
  if num_pages == 0 and num_subcats == 0:
    pagemsg("Skipping empty category")
    return
  contents = "{{auto cat}}"
  result = expand_text(contents)
  if not result:
    return
  if ("Category:Categories with invalid label" in result or
      "The automatically-generated contents of this category has errors" in result):
    pagemsg("Won't create page, would lead to errors: <%s>" % result)
  else:
    pagemsg("Creating page, output is <%s>" % result)
    comment = 'Created page with "%s"' % contents
    if args.save:
      page.text = contents
      if blib.safe_page_save(page, comment, errandpagemsg):
        errandpagemsg("Created page, comment = %s" % comment)
    else:
      pagemsg("Would create, comment = %s" % comment)

params = blib.create_argparser("Create wanted categories with {{auto cat}}", include_pagefile=True)
params.add_argument("--overwrite", help="Overwrite existing text.", action="store_true")
args = params.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_page)
