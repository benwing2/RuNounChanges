#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, errmsg, site

parser = blib.create_argparser(u"List pages, lemmas and/or non-lemmas")
parser.add_argument('--tempfile', help="Templates and aliases to do")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

lines = [x.strip() for x in codecs.open(args.tempfile, "r", "utf-8")]

for ref_and_aliases in lines:
  split_refs = re.split(",", ref_and_aliases)
  mainref = "Template:%s" % split_refs[0]
  aliases = split_refs[1:]
  refs = [(mainref, None)]
  for alias in aliases:
    refs.append(("Template:%s" % alias, mainref))
  for alias, mainref in refs:
    errmsg("Processing references to: %s" % alias)
    num_refs = len(list(blib.references(alias, start, end)))
    msg("| [[%s]] || %s || %s" % (alias, mainref and "[[%s]]" % mainref or "(none)",
      num_refs))
