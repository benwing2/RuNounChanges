#!/usr/bin/env python
#coding: utf-8

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

# Go through all the terms we can find looking for pages that are
# missing a headword declaration.

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site

import rulib

def process_page(index, page, save, verbose):
  pagetitle = unicode(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  def expand_text(tempcall):
    return blib.expand_text(tempcall, pagetitle, pagemsg, verbose)

  pagemsg("Processing")

  parsed = blib.parse(page)
  for t in parsed.filter_templates():
    if unicode(t.name).startswith("ru-conj-") and getparam(t, "1").startswith("pf"):
      m = re.search(r"^\{\{ru-conj-(.*?)\|(.*)\}\}$", unicode(t), re.S)
      verbtype, params = m.groups()
      tempcall = "{{ru-generate-verb-forms|type=%s|%s}}" % (verbtype, params)
      result = expand_text(tempcall)
      if not result:
        pagemsg("WARNING: Error generating forms, skipping")
        continue
      args = rulib.split_generate_args(result)
      if "past_pasv_part" in args:
        for form in re.split(",",args["past_pasv_part"]):
          form = re.sub("//.*", "", form)
          pagemsg("Found perfective past passive participle: %s" % form)

parser = blib.create_argparser(u"Find Russian terms without a proper headword line")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

for category in ["Russian verbs"]:
  for i, page in blib.cat_articles(category, start, end):
    process_page(i, page, args.save, args.verbose)
