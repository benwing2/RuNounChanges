#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site, tname

def process_page(page, index):
  pagetitle = unicode(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  #if pagetitle.startswith("Template:"):
  pagemsg("Found one")

parser = blib.create_argparser("Find templates transcluding a given page")
parser.add_argument("--refs",
    help=u"""Comma-separated list of pages to check.""")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

for ref in args.refs.split(","):
  msg("Processing references to %s" % ref)
  for i, page in blib.references(ref, start, end):
    process_page(page, i)
