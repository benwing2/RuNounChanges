#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, tname, msg, errandmsg, site

import lalib

def process_page(page, index, template):
  pagetitle = str(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
  def errandpagemsg(txt):
    errandmsg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  notes = []

  text = str(page.text)
  if "{{la-verb|" in text:
    newtext = re.sub(r"\{\{la-verb\|.*?\}\}", template, text, 1)
    if newtext != text:
      notes.append("convert Vulgar Latin {{la-verb}} to new-style")
      return newtext, notes
  return None, None

parser = blib.create_argparser("Fix Vulgar Latin verb entries to use new-style {{la-verb}}")
parser.add_argument("--direcfile", help="List of directives to process.",
    required=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

for i, line in blib.iter_items_from_file(args.direcfile, start, end):
  m = re.search("^Page [0-9]+ (Reconstruction:.*): WARNING: Saw verb headword template but no conjugation template: ({{la-verb.*}})$", line)
  if m:
    page, template = m.groups()
    def do_process_page(page, index, parsed):
      return process_page(page, index, template)
    blib.do_edit(pywikibot.Page(site, page), i, do_process_page, save=args.save,
        verbose=args.verbose, diff=args.diff)
