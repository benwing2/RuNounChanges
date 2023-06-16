#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site, tname

def process_page(page, index, template):
  pagetitle = str(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")
  notes = []

  parsed = blib.parse(page)

  for t in parsed.filter_templates():
    tn = tname(t)
    if tn == template:
      for i in range(2, 10):
        if getparam(t, str(i)):
          break
      else:
        pagemsg("Found %s template without parts: %s" % (template, str(t)))

parser = blib.create_argparser("Find templates without any parts")
parser.add_argument("--templates",
    help=u"""Comma-separated list of names of template to check for.""")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

for template in args.templates.split(","):
  msg("Processing references to Template:%s" % template)
  for i, page in blib.references("Template:%s" % template, start, end):
    process_page(page, i, template)
