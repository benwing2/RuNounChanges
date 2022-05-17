#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site

parser = blib.create_argparser(u"Find verbs with impersonal conjugations")
parser.add_argument('--verbfile', help="File listing verbs to check.")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

for i, line in blib.iter_items(codecs.open(args.verbfile, "r", "utf-8"), start, end):
  page = pywikibot.Page(site, line.strip())
  if "-impers|" in page.text:
    msg("Page %s %s: Found impersonal conjugation" % (i, unicode(page.title())))
  else:
    msg("Page %s %s: No impersonal conjugation" % (i, unicode(page.title())))
