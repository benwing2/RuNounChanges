#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import blib, re, codecs
from blib import msg, errmsg, site
import pywikibot
from pywikibot.data.api import APIError

def delete_page(page, comment, errandpagemsg):
  for i in range(11):
    try:
      page.delete(comment)
      return
    except APIError as e:
      if "missingtitle" in str(e):
        errandpagemsg("WARNING: APIError due to page no longer existing, skipping: %s" % e)
        return
      if i == 10:
        raise e
      errandpagemsg("WARNING: APIError, try #%s: %s" % (i + 1, e))

def process_page(page, index, args, comment):
  pagetitle = str(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
  def errandpagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
    errmsg("Page %s %s: %s" % (index, pagetitle, txt))
  if args.verbose:
    pagemsg("Processing")
  catname = re.sub("^Category:", "", pagetitle)
  num_pages = len(list(blib.cat_articles(catname)))
  num_subcats = len(list(blib.cat_subcats(catname)))
  if num_pages > 0 or num_subcats > 0:
    errandpagemsg("Skipping (not empty): num_pages=%s, num_subcats=%s" % (
      num_pages, num_subcats))
    return
  this_comment = comment or 'delete empty category'
  if page.exists():
    if args.save:
      delete_page(page, '%s (content was "%s")' % (this_comment, str(page.text)), errandpagemsg)
      errandpagemsg("Deleted (comment=%s)" % this_comment)
    else:
      pagemsg("Would delete (comment=%s)" % this_comment)
  else:
    pagemsg("Skipping, page doesn't exist")

params = blib.create_argparser("Delete empty category pages", include_pagefile=True)
params.add_argument("--comment", help="Specify the change comment to use")
args = params.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

def do_process_page(page, index):
  return process_page(page, index, args, args.comment)
blib.do_pagefile_cats_refs(args, start, end, do_process_page)
