#!/usr/bin/env python
# -*- coding: utf-8 -*-

#    find_pppp.py is free software: you can redistribute it and/or modify
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

# Find Russian perfective verbs with explicit past passive participles

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site

def process_page(index, page, save, verbose):
  pagetitle = unicode(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  def expand_text(tempcall):
    return blib.expand_text(tempcall, pagetitle, pagemsg, verbose)

  pagemsg("Processing")

  parsed = blib.parse(page)
  for t in parsed.filter_templates():
    if unicode(t.name) in ["ru-conj", "ru-conj-old"] and getparam(t, "1").startswith("pf"):
      if tname == "ru-conj":
        tempcall = re.sub(r"\{\{ru-conj", "{{ru-generate-verb-forms", unicode(t))
      else:
        tempcall = re.sub(r"\{\{ru-conj-old", "{{ru-generate-verb-forms|old=y", unicode(t))
      result = expand_text(tempcall)
      if not result:
        pagemsg("WARNING: Error generating forms, skipping")
        continue
      args = blib.split_generate_args(result)
      for base in ["past_pasv_part", "ppp"]:
        for i in ["", "2", "3", "4", "5", "6", "7", "8", "9"]:
          val = getparam(t, base + i)
          if val and val != "-":
            val = re.sub("//.*", "", val)
            pagemsg("Found perfective past passive participle: %s" % val)

parser = blib.create_argparser(u"Find Russian perfective verbs with explicit past passive participles")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

for category in ["Russian verbs"]:
  for i, page in blib.cat_articles(category, start, end):
    process_page(i, page, args.save, args.verbose)
