#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, msg, site, tname

blib.getData()

templates = [
  "sa-ima1s",
  "sa-ima3p",
  "sa-ima3s",
  "sa-imp3s",
  "sa-poa3s",
  "sa-pra1d",
  "sa-pra1p",
  "sa-pra1s",
  "sa-pra2s",
]

def process_page(page, index, parsed, remove_manual_cats=False):
  pagetitle = str(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")
  notes = []

  text = str(page.text)

  for t in templates:
    newtext = re.sub(r"\n*\{\{%s\}\}" % t, "", text)
    if newtext != text:
      notes.append("remove unneeded category template {{%s}}" % t)
      text = newtext

  newtext = re.sub(r"\n*\[\[Category:Sanskrit(.*?)[_ ]verb[_ ](.*?)forms([_ ].*?)?\]\]", "", text)
  if newtext != text:
    notes.append("remove unneeded manual category spec(s)")
    text = newtext

  return text, notes

parser = blib.create_argparser("Remove unnecessary {{sa-*}} category templates")
parser.add_argument("--delete-templates", action="store_true")
parser.add_argument("--remove-manual-cats", action="store_true")
parser.add_argument("--delete-verb-subcats", action="store_true")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

if args.remove_manual_cats:
  for i, catpage in blib.cat_subcats("Sanskrit verb forms", recurse=True):
    msg("In category %s:" % str(catpage.title()))
    for j, page in blib.cat_articles(catpage, start, end):
      msg("Page %s" % str(page.title()))
      blib.do_edit(page, j,
        lambda p, index, parsed: process_page(p, index, parsed, remove_manual_cats=True),
        save=args.save, verbose=args.verbose)
elif args.delete_verb_subcats:
  for i, catpage in blib.cat_subcats("Sanskrit verb forms", recurse=True):
    msg("In category %s:" % str(catpage.title()))
    if catpage.isEmptyCategory():
      msg("Category %s is empty, deleting" % str(catpage.title()))
      if args.save:
        catpage.delete("Remove empty, unnecessary verb-form category")
elif args.delete_templates:
  for template in templates:
    msg("Deleting Template:%s" % template)
    if args.save:
      page = pywikibot.Page(site, "Template:%s" % template)
      page.delete("Remove unnecessary {{sa-*}} category templates")
else:
  for template in templates:
    msg("Processing references to Template:%s" % template)
    for i, page in blib.references("Template:%s" % template, start, end):
      blib.do_edit(page, i, process_page, save=args.save, verbose=args.verbose)

