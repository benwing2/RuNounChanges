#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse, time
import blib
from blib import site, msg, errmsg, group_notes, iter_items

# clean_etym_templates.py had a bug in it that it wasn't idempotent w.r.t. adding a
# period after back-formation templates without nodot=, leading it to add extraneous
# periods in some cases. This script undoes the damage.

def process_page(page, index, parsed):
  pagetitle = str(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  def errpagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
    errmsg("Page %s %s: %s" % (index, pagetitle, txt))

  revisions = list(page.revisions(total=1))
  for rev in revisions:
    if rev['user'] != 'WingerBot' or (
        not rev['comment'].startswith('add period to back-formation template without nodot=')):
      errpagemsg("WARNING: Can't revert page, another change happened since then")
    else:
      oldrevid = rev['_parent_id']
      if oldrevid:
        oldtext = page.getOldVersion(oldrevid)
        return oldtext, "Undo faulty addition of period after back-formation template"

parser = blib.create_argparser("Undo extraneously-added periods after back-formation templates",
  include_pagefile=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_page, edit=True)
