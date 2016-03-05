#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site

parser = blib.create_argparser(u"List pages, lemmas and/or non-lemmas")
parser.add_argument('--cats', default="lemma,nonlemma", help="Categories to do (lemma, nonlemma or comma-separated list)")
args = parser.parse_args()
start, end = blib.get_args(args.start, args.end)

categories = []
for cattype in re.split(",", args.cats):
  if cattype == "lemma":
    categories.append("Russian lemmas")
  elif cattype == "nonlemma":
    categories.append("Russian non-lemma forms")
  else:
    raise RuntimeError("Invalid value %s, should be 'lemma' or 'nonlemma'" %
        cattype)
for category in categories:
  msg("Processing category: %s" % category)
  for i, page in blib.cat_articles(category, start, end):
    msg("Page %s %s: Processing" % (i, unicode(page.title())))
