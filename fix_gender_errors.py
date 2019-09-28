#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site

def process_page(index, page, genders):
  pagetitle = unicode(page.title())
  subpagetitle = re.sub(".*:", "", pagetitle)
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  parsed = blib.parse(page)

  headword_template = None

  for t in parsed.filter_templates():
    if unicode(t.name) in ["ru-noun+", "ru-proper noun+"]:
      if headword_template:
        pagemsg("WARNING: Multiple headword templates, skipping")
        return
      headword_template = t
  if not headword_template:
    pagemsg("WARNING: No headword templates, skipping")
    return

  orig_template = unicode(headword_template)
  rmparam(headword_template, "g")
  rmparam(headword_template, "g2")
  rmparam(headword_template, "g3")
  rmparam(headword_template, "g4")
  rmparam(headword_template, "g5")
  for gnum, g in enumerate(genders):
    param = "g" if gnum == 0 else "g" + str(gnum+1)
    headword_template.add(param, g)
  pagemsg("Replacing %s with %s" % (orig_template, unicode(headword_template)))

  return unicode(parsed), "Fix headword gender, substituting new value %s" % ",".join(genders)

parser = blib.create_argparser("Fix gender errors introduced by fix_ru_noun.py")
parser.add_argument('--direcfile', help="File containing pages and warnings to process",
  required=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

# * Page 3574 [[коала]]: WARNING: Gender mismatch, existing=m-an,f-an, new=f-an
lines = [x.strip() for x in codecs.open(args.pagefile, "r", "utf-8")]
for i, line in blib.iter_items(lines, start, end):
  m = re.search("^\* Page [0-9]+ \[\[(.*?)\]\]: WARNING: Gender mismatch, existing=(.*?), new=.*?$", line)
  if not m:
    msg("WARNING: Can't process line: %s" % line)
  else:
    page, genders = m.groups()
    msg("Page %s %s: Processing: %s" % (i, page, line))
    def do_process_page(page, index, parsed):
      return process_page(index, page, re.split(",", genders))
    blib.do_edit(pywikibot.Page(site, page), i, do_process_page, save=args.save,
      verbose=args.verbose, diff=args.diff)
