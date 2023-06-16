#!/usr/bin/env python3
# -*- coding: utf-8 -*-

# Go through looking for pages with strange pronunciations -- either
# pronunciation missing a * at the beginning or a pronunciation with
# some additional text surrounding it.

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site

def process_page(page, index, fix_star):
  pagetitle = str(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  pagetext = page.text
  notes = []

  for m in re.finditer(r"^(.*)(\{\{ru-IPA(?:\|[^}]*)?\}\})(.*)$", pagetext,
      re.M):
    pretext = m.group(1)
    ruIPA = m.group(2)
    posttext = m.group(3)
    wholeline = m.group(0)
    if not pretext.startswith("* "):
      pagemsg("WARNING: ru-IPA doesn't start with '* ': %s" % wholeline)
    pretext_no_star = re.sub(r"^\*?\s*", "", pretext)
    if pretext_no_star or posttext:
      pagemsg("WARNING: pre-text or post-text with ru-IPA: %s" % wholeline)
  if args.fix_star:
    def fix_star(m):
      wholeline = m.group(0)
      if not wholeline.startswith("* "):
        return "* " + wholeline
      else:
        return wholeline
    newtext = re.sub(r"^(.*)(\{\{ru-IPA(?:\|[^}]*)?\}\})(.*)$", fix_star,
        pagetext, 0, re.M)
    if newtext != pagetext:
      notes.append("add missing * to ru-IPA lines")
      pagetext = newtext
    return pagetext, notes

parser = blib.create_argparser("Find strange Russian pronun lines",
  include_pagefile=True)
parser.add_argument("--fix-star", action="store_true",
  help="Fix pronun lines missing * at beginning")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

def do_process_page(page, index, parsed):
  return process_page(page, index, args.fix_star)

blib.do_pagefile_cats_refs(args, start, end, do_process_page, edit=True,
  default_cats=["Russian lemmas", "Russian non-lemma forms"])
