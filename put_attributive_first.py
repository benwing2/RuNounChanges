#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse
import blib
from blib import site, msg, errmsg

def process_page(page, index, parsed):
  pagetitle = str(page.title())

  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  def errpagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
    errmsg("Page %s %s: %s" % (index, pagetitle, txt))

  if not blib.try_repeatedly(lambda: page.exists(), pagemsg,
      "check page existence"):
    pagemsg("Page doesn't exist, can't add etymology")
    return

  notes = []
  pagetext = str(page.text)

  def put_attributive_first(m):
    labels = m.group(1).split('|')
    if 'attributive' in labels:
      labels_wo_attributive = [label for label in labels if label != 'attributive']
      labels = ['attributive'] + labels_wo_attributive
    return '{{lb|ru|%s}}' % '|'.join(labels)
  newtext = re.sub(r'\{\{lb\|ru\|(.*?)\}\}', put_attributive_first, pagetext)

  if newtext != pagetext:
    notes.append("put attributive label first")
  return newtext, notes

if __name__ == "__main__":
  parser = blib.create_argparser("Put attributive label first",
    include_pagefile=True)
  args = parser.parse_args()
  start, end = blib.parse_start_end(args.start, args.end)

  blib.do_pagefile_cats_refs(args, start, end, process_page, edit=True)
