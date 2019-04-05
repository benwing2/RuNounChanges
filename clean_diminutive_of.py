#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site, tname

def process_page(page, index, parsed):
  pagetitle = unicode(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")
  notes = []

  for t in parsed.filter_templates():
    origt = unicode(t)
    tn = tname(t)
    if tn in ["diminutive of", "dim of"]:
      if t.has("pos"):
        pos = re.sub("s$", "", getparam(t, "pos"))
        t.add("POS", pos, before="pos")
        rmparam(t, "pos")
        notes.append("Convert plural pos= to singular POS= in {{%s}}" % tn)

    if unicode(t) != origt:
      pagemsg("Replaced <%s> with <%s>" % (origt, unicode(t)))

  return unicode(parsed), notes

parser = blib.create_argparser("Convert plural pos= to singular POS= in {{diminutive of}}")
parser.add_argument('--pagefile', help="Pages to do")
args = parser.parse_args()

start, end = blib.parse_start_end(args.start, args.end)
lines = [x.strip() for x in codecs.open(args.pagefile, "r", "utf-8")]
for i, page in blib.iter_items(lines, start, end):
  blib.do_edit(pywikibot.Page(site, page), i, process_page, save=args.save, verbose=args.verbose)
