#!/usr/bin/env python
#coding: utf-8

#    find_dim_in_etym.py is free software: you can redistribute it and/or modify
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

# Find uses of {{diminutive of}} in Etymology sections.

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site

import rulib

def process_page(index, page, verbose):
  pagetitle = unicode(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  text = unicode(page.text)
  russian = blib.find_lang_section_from_text(text, "Russian", pagemsg)
  if not russian:
    pagemsg("Couldn't find Russian section for %s" % pagetitle)
    return

  subsections = re.split("(^===+[^=\n]+===+\n)", russian, 0, re.M)
  # Go through each subsection in turn, looking for subsection
  # matching the POS with an appropriate headword template whose
  # head matches the inflected form
  for j in xrange(2, len(subsections), 2):
    if "==Etymology" in subsections[j - 1]:
      parsed = blib.parse_text(subsections[j])
      for t in parsed.filter_templates():
        tname = unicode(t.name)
        if tname == "diminutive of":
          pagemsg("WARNING: Found diminutive-of in etymology: %s" %
            unicode(t))

parser = blib.create_argparser(u"Find uses of {{diminutive of}} in Etymology sections")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

for category in ["Russian diminutive nouns", "Russian diminutive adjectives"]:
  for i, page in blib.cat_articles(category, start, end):
    process_page(i, page, args.verbose)
