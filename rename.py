#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import blib, re
from blib import msg, errmsg, site
import pywikibot

def rename_page(index, page, totitle, comment, refrom, reto):
  pagetitle = str(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
  def errandpagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
    errmsg("Page %s %s: %s" % (index, pagetitle, txt))
  zipped_fromto = zip(refrom, reto)
  def replace_text(text):
    for fromval, toval in zipped_fromto:
      text = re.sub(fromval, toval, text)
    return text
  this_comment = comment or zipped_fromto and "rename based on regex %s" % (
    ", ".join("%s -> %s" % (f, t) for f, t in zipped_fromto)
  ) or "rename page"
  if not blib.safe_page_exists(page, errandpagemsg):
    pagemsg("Skipping because page doesn't exist")
    return
  if args.verbose:
    pagemsg("Processing")
  if not totitle:
    totitle = replace_text(totitle)
  if totitle == pagetitle:
    pagemsg("WARNING: Regex doesn't match, not renaming to same name")
  else:
    new_page = pywikibot.Page(site, totitle)
    if blib.safe_page_exists(new_page, errandpagemsg):
      errandpagemsg("Destination page %s already exists, not moving" %
        totitle)
    elif args.save:
      try:
        page.move(totitle, reason=this_comment, movetalk=True, noredirect=True)
        errandpagemsg("Renamed to %s" % totitle)
      except pywikibot.PageRelatedError as error:
        errandpagemsg("Error moving to %s: %s" % (totitle, error))
    else:
      pagemsg("Would rename to %s (comment=%s)" % (totitle, this_comment))

def delete_page(index, page, comment):
  pagetitle = str(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
  def errandpagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
    errmsg("Page %s %s: %s" % (index, pagetitle, txt))
  if args.verbose:
    pagemsg("Processing")
  this_comment = comment or "delete page"
  if blib.safe_page_exists(page, errandpagemsg):
    if args.save:
      existing_text = blib.safe_page_text(page, errandpagemsg, bad_value_ret=None)
      if existing_text is not None:
        page.delete('%s (content was "%s")' % (this_comment, existing_text))
        errandpagemsg("Deleted (comment=%s)" % this_comment)
    else:
      pagemsg("Would delete (comment=%s)" % this_comment)
  else:
    pagemsg("Skipping, page doesn't exist")

params = blib.create_argparser("Rename pages", include_pagefile=True)
params.add_argument("-f", "--from", help="From regex, can be specified multiple times",
    metavar="FROM", dest="from_", action="append")
params.add_argument("-t", "--to", help="To regex, can be specified multiple times",
    action="append")
params.add_argument("--rename-comment", "--comment", help="Specify the change comment to use when renaming")
params.add_argument("--delete-comment", help="Specify the change comment to use when deleting")
params.add_argument("--delete-from-direcfile", action="store_true",
    help="If only a single page given in --direcfile, delete it.")
params.add_argument("--direcfile", help="File containing pairs of from/to pages to rename, separated by ' ||| '.")
args = params.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

from_ = list(args.from_) if args.from_ else []
to = list(args.to) if args.to else []

if len(from_) != len(to):
  raise ValueError("Same number of --from and --to arguments must be specified")

if args.delete_from_direcfile:
  pages_to_delete = []
  pages_to_rename = []
  for index, line in blib.iter_items_from_file(args.direcfile, start, end):
    if " ||| " not in line:
      pages_to_delete.append((index, line))
    else:
      frompage, topage = line.split(" ||| ")
      pages_to_rename.append((index, frompage, topage))
  for index, page in pages_to_delete:
    delete_page(index, pywikibot.Page(blib.site, page), args.delete_comment)
  for index, frompage, topage in pages_to_rename:
    rename_page(index, pywikibot.Page(blib.site, frompage), topage, args.rename_comment, from_, to)
elif args.direcfile:
  for index, line in blib.iter_items_from_file(args.direcfile, start, end):
    if " ||| " not in line:
      if args.delete_from_direcfile:
        msg("Line %s: WARNING: Saw bad line in --from-to-pagefile: %s" % (index, line))
      continue
    frompage, topage = line.split(" ||| ")
    rename_page(index, pywikibot.Page(blib.site, frompage), topage, args.rename_comment, from_, to)
else:
  def do_process_page(page, index):
    return rename_page(index, page, None, args.rename_comment, from_, to)
  blib.do_pagefile_cats_refs(args, start, end, do_process_page)
