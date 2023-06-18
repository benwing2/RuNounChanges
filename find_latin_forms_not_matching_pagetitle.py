#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, msg, site, tname

import lalib
from lalib import remove_macrons

def process_text_on_page(index, pagetitle, text):
  global args

  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  if not args.stdin:
    pagemsg("Processing")

  retval = lalib.find_latin_section(text, pagemsg)
  if retval is None:
    return None, None
  sections, j, secbody, sectail, has_non_latin = retval
  parsed = blib.parse_text(secbody)
  for t in parsed.filter_templates():
    tn = tname(t)
    if tn in lalib.la_headword_templates:
      for head in lalib.la_get_headword_from_template(t, pagetitle, pagemsg):
        no_macrons_head = remove_macrons(blib.remove_links(head))
        if pagetitle.startswith("Reconstruction"):
          unprefixed_title = "*" + re.sub(".*/", "", pagetitle)
        else:
          unprefixed_title = pagetitle
        if no_macrons_head != unprefixed_title:
          pagemsg("WARNING: Bad Latin head: %s" % str(t))
  return None, None

parser = blib.create_argparser("Check for bad Latin forms",
  include_pagefile=True, include_stdin=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page,
  stdin=True, only_lang="Latin", default_cats=["Latin non-lemma forms"])
