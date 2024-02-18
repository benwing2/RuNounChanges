#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse, time
import difflib
import blib
from blib import site, msg, errandmsg, group_notes, iter_items

def process_item(index, item):
  pagetitle = item["title"]

  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  def errandpagemsg(txt):
    errandmsg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("------------ Processing ------------")
  revid = item["revid"]
  old_revid = item["parentid"]
  page = pywikibot.Page(site, pagetitle)
  pagetext = page.getOldVersion(revid)
  oldtext = page.getOldVersion(old_revid)
  newlines = pagetext.splitlines(True)
  oldlines = oldtext.splitlines(True)
  diff = difflib.unified_diff(oldlines, newlines)
  dangling_newline = False
  for line in diff:
    dangling_newline = not line.endswith('\n')
    sys.stdout.write(line)
    if dangling_newline:
      sys.stdout.write("\n")
  if dangling_newline:
    sys.stdout.write("\\ No newline at end of file\n")

parser = blib.create_argparser("Show contributions of a user")
parser.add_argument("--user", help="User to do.")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

for index, item in blib.get_contributions(args.user, start, end):
  process_item(index, item)
