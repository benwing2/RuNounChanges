#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, msg, site

parser = blib.create_argparser("Find verbs with impersonal conjugations")
parser.add_argument('--verbfile', help="File listing verbs to check.")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

for i, line in blib.iter_items_from_file(args.verbfile, start, end):
  page = pywikibot.Page(site, line)
  if "-impers|" in page.text:
    msg("Page %s %s: Found impersonal conjugation" % (i, str(page.title())))
  else:
    msg("Page %s %s: No impersonal conjugation" % (i, str(page.title())))
