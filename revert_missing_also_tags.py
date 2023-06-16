#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse, time
import blib
from blib import site, msg, errmsg, group_notes, iter_items

# add_ru_etym.py had a bug in it that erased {{also|...}} and similar tags
# at the top of a page, before any language sections. This script undoes the
# damage.

def restore_removed_pagehead(index, pagetitle, comment, oldrevid):
  global args
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  def errpagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
    errmsg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing page with comment = %s" % comment)
  if re.search('(add|replace).*Etymology section', comment):
    page = pywikibot.Page(site, pagetitle)
    oldtext = page.getOldVersion(oldrevid)
    oldtext_pagehead = re.split("(^==[^=\n]+==\n)", oldtext, 0, re.M)[0]
    if oldtext_pagehead:
      newtext_pagehead = re.split("(^==[^=\n]+==\n)", page.text, 0, re.M)[0]
      if newtext_pagehead != oldtext_pagehead:
        if newtext_pagehead:
          errpagemsg("WARNING: Something weird, old page has pagehead <%s> and new page has different pagehead <%s>" % (
            oldtext_pagehead, newtext_pagehead))
          return
        pagemsg("Adding old pagehead <%s> to new page" % oldtext_pagehead)
        pagetext = page.text
        newtext = oldtext_pagehead + pagetext

        def do_process_page(pg, ind, parsed):
          return newtext, ["Restore missing page head: %s" % oldtext_pagehead.strip()]
        blib.do_edit(page, index, do_process_page, save=args.save,
          verbose=args.verbose, diff=args.diff)

def process_item(index, item):
  restore_removed_pagehead(index, item['title'], item['comment'], item['parentid'])

def process_page(page, index):
  pagetitle = str(page.title())
  revisions = list(page.revisions(total=50))
  for rev in revisions:
    if rev['user'] == 'WingerBot':
      oldrevid = rev['_parent_id']
      if oldrevid:
        restore_removed_pagehead(index, pagetitle, rev['comment'], oldrevid)

parser = blib.create_argparser("Undo wrongly-erased {{also|...}} tags from the top of a page",
  include_pagefile=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

if args.pagefile or args.pages or args.cats or args.refs:
  blib.do_pagefile_cats_refs(args, start, end, process_page)
else:
  for i, item in blib.get_contributions("WingerBot", start, end):
    process_item(i, item)
