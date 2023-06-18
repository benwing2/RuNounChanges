#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, msg, errmsg, site, tname

def process_subpage(origpage, origindex, page, index):
  origpagetitle = str(origpage.title())
  pagetitle = str(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s %s: %s" % (origindex, origpagetitle, index, pagetitle, txt))

  #if pagetitle.startswith("Template:"):
  pagemsg("Found one")

def process_page(page, index):
  global args
  pagetitle = str(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
  def errpagemsg(txt):
    errmsg("Page %s %s: %s" % (index, pagetitle, txt))
  errpagemsg("Processing references")
  if not args.table_of_uses:
    pagemsg("Processing references")
  aliases = []
  for i, subpage in blib.references(pagetitle, namespaces=[10], only_template_inclusion=False, filter_redirects=args.redirects_only):
    aliases.append(str(subpage.title()))
    if not args.table_of_uses:
      process_subpage(page, index, subpage, i)
  if args.table_of_uses:
    msg("%s%s" % (pagetitle.replace("Template:", ""),
      aliases and "," + ",".join(x.replace("Template:", "") for x in aliases) or ""))

parser = blib.create_argparser("Find templates transcluding a given page",
  include_pagefile=True)
parser.add_argument("--redirects-only",
    help="""Only output redirects.""", action='store_true')
parser.add_argument("--table-of-uses", action='store_true',
    help="""Output in table_of_uses.py input format.""")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_page)
