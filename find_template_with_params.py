#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site, tname

def process_page(page, index, template, params):
  pagetitle = unicode(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")
  notes = []

  parsed = blib.parse(page)

  for t in parsed.filter_templates():
    tn = tname(t)
    if tn == template:
      for param in params:
        if t.has(param):
          pagemsg("Found %s template with %s param: %s" %
              (template, param, unicode(t)))

parser = blib.create_argparser("Find templates with specified params")
parser.add_argument("--template",
    help=u"""Template to check params of.""")
parser.add_argument("--params",
    help=u"""Comma-separated list of params to check for.""")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

template = args.template.decode('utf-8')
msg("Processing references to Template:%s" % template)
params = re.split(",", args.params.decode('utf-8'))
for i, page in blib.references("Template:%s" % template, start, end):
  process_page(page, i, template, params)
