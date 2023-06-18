#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, tname, msg, site

import lalib

def process_page(page, index, sectext, comment):
  pagetitle = str(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  retval = lalib.find_latin_section(str(page.text), pagemsg)
  if retval is None:
    return None, None

  sectext = re.sub(r"^==Latin==\n", "", sectext) + "\n\n"
  sections, j, secbody, sectail, has_non_latin = retval

  notes = []

  sections[j] = sectext
  notes.append(comment)
  return "".join(sections).rstrip("\n"), notes

parser = blib.create_argparser("Push manual changes for Latin sections to Wiktionary.")
parser.add_argument("--textfile", help="File with page titles and section text, with at least four newlines on each side of the title.", required=True)
parser.add_argument("--comment", help="Comment to use when saving pages.", required=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

fulltext = open(args.textfile, "r", encoding="utf-8").read()

titles_and_text = re.split(r"\n\n\n\n+", fulltext)

assert len(titles_and_text) % 2 == 0

title_and_text_pairs = []
for i in range(0, len(titles_and_text), 2):
  title_and_text_pairs.append((titles_and_text[i], titles_and_text[i + 1]))

for i, (pagetitle, pagetext) in blib.iter_items(title_and_text_pairs, start, end, get_name=lambda x: x[0]):
  def handler(page, index, parsed):
    return process_page(page, index, pagetext, args.comment)
  blib.do_edit(pywikibot.Page(site, pagetitle), i, handler, save=args.save,
      verbose=args.verbose)
