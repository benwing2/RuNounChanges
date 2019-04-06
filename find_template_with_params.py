#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site, tname

def process_page(page, index, template, params, negate):
  pagetitle = unicode(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")
  notes = []

  parsed = blib.parse(page)

  paramset = set(params)

  for t in parsed.filter_templates():
    tn = tname(t)
    if tn == template:
      for tparam in t.params:
        pname = unicode(param.name).strip()
        if negate:
          if pname not in paramset:
            pagemsg("Found %s template with unrecognized param %s: %s" %
                (template, param, unicode(t)))
        else:
          if pname in paramset:
            pagemsg("Found %s template with %s param: %s" %
                (template, param, unicode(t)))

parser = blib.create_argparser("Find templates with specified params")
parser.add_argument("--templates",
    help=u"""Comma-separated lsit of templates to check params of.""")
parser.add_argument("--params",
    help=u"""Comma-separated list of params to check for.""")
parser.add_argument("--negate",
    help=u"""Check if any params NOT in '--params' are present.""")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

templates = re.split(",", args.templates.decode('utf-8'))

for template in templates:
  msg("Processing references to Template:%s" % template)
  params = re.split(",", args.params.decode('utf-8'))
  for i, page in blib.references("Template:%s" % template, start, end):
    process_page(page, i, template, params, args.negate)
