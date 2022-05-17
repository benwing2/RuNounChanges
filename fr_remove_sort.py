#!/usr/bin/env python
# -*- coding: utf-8 -*-

#    fr_remove_sort.py is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.

# Go through all the French terms we can find and remove sort=.

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site

fr_head_templates = ["fr-noun", "fr-proper noun", "fr-proper-noun",
  "fr-verb", "fr-adj", "fr-adv", "fr-phrase", "fr-adj form", "fr-adj-form",
  "fr-abbr", "fr-diacritical mark", "fr-intj", "fr-letter",
  "fr-past participle", "fr-prefix", "fr-prep", "fr-pron",
  "fr-punctuation mark", "fr-suffix", "fr-verb form", "fr-verb-form"]

def process_page(page, index, parsed):
  pagetitle = unicode(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  if ":" in pagetitle:
    pagemsg("WARNING: Colon in page title, skipping")
    return

  text = unicode(page.text)

  notes = []
  parsed = blib.parse_text(text)
  for t in parsed.filter_templates():
    origt = unicode(t)
    name = unicode(t.name)
    if name in fr_head_templates:
      rmparam(t, "sort")
    newt = unicode(t)
    if origt != newt:
      pagemsg("Replacing %s with %s" % (origt, newt))
      notes.append("remove sort= from {{%s}}" % name)

  return unicode(parsed), notes

parser = blib.create_argparser("Remove sort= from French terms",
  include_pagefile=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_page, edit=True,
  default_cats=["French lemmas", "French non-lemma forms"])
