#!/usr/bin/env python
#coding: utf-8

#    find_no_etym_defn.py is free software: you can redistribute it and/or modify
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

# Fetch definitions of specified Russian terms.

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site

import rulib

def process_page(index, page, verbose):
  pagetitle = unicode(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  def expand_text(tempcall):
    return blib.expand_text(tempcall, pagetitle, pagemsg, verbose)

  pagemsg("Processing")

  text = unicode(page.text)

  if rulib.check_for_alt_yo_terms(text, pagemsg):
    return

  section = blib.find_lang_section_from_text(text, "Russian", pagemsg) 
  if not section:
    pagemsg("Couldn't find Russian section for %s" % pagetitle)
    return

  defns = rulib.find_defns(section)
  if not defns:
    pagemsg("Couldn't find definitions for %s" % pagetitle)
    return

  msg("%s %s" % (pagetitle, ';'.join(defns)))

parser = blib.create_argparser(u"Find etymologies for nouns in -ость")
parser.add_argument('--cats', default="Russian lemmas", help="Categories to do (can be comma-separated list)")
parser.add_argument('--refs', help="References to do (can be comma-separated list)")
parser.add_argument('--lemmafile', help="File of lemmas to process. May have accents.")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

if args.lemmafile:
  lemmas = []
  for i, pagename in blib.iter_items([ru.remove_accents(x.strip()) for x in codecs.open(args.lemmafile, "r", "utf-8")]):
    page = pywikibot.Page(site, pagename)
    process_page(i, page, args.verbose)
elif args.refs:
  for ref in re.split(",", args.refs):
    msg("Processing references to: %s" % ref)
    for i, page in blib.references(ref, start, end):
      process_page(i, page, args.verbose)
else:
  for cat in re.split(",", args.cats):
    msg("Processing category: %s" % cat)
    lemmas = []
    if cat == "Russian verbs":
      for i, page in blib.cat_articles(cat):
        lemmas.append(page.title())
    for i, page in blib.cat_articles(cat, start, end):
      process_page(i, page, args.verbose)
