#!/usr/bin/env python
# -*- coding: utf-8 -*-

#    create_pages.py is free software: you can redistribute it and/or modify
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

import blib, re, codecs
from blib import msg, errmsg, site
import pywikibot

def blacklist(category):
  return False
  # Formerly blacklisted because sort= should be given.
  #if " terms spelled with " in category and not re.search("^(Japanese|Okinawan) ", category):
  #  return True
  #return False

def process_page(page, index):
  global args
  pagetitle = unicode(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
  def errandpagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
    errmsg("Page %s %s: %s" % (index, pagetitle, txt))
  def expand_text(tempcall):
    return blib.expand_text(tempcall, pagetitle, pagemsg, args.verbose)
  if args.verbose:
    pagemsg("Processing")
  if page.exists():
    errandpagemsg("Page already exists, not overwriting")
    return
  if not pagetitle.startswith("Category:"):
    pagemsg("Page not a category, skipping")
    return
  catname = re.sub("^Category:", "", pagetitle)
  if blacklist(catname):
    pagemsg("Category is blacklisted, skipping")
    return
  num_pages = len(list(blib.cat_articles(catname)))
  num_subcats = len(list(blib.cat_subcats(catname)))
  if num_pages == 0 and num_subcats == 0:
    pagemsg("Skipping empty category")
    return
  contents = u"{{auto cat}}"
  result = expand_text(contents)
  if not result:
    return
  if ("Category:Categories with invalid label" in result or
      "The automatically-generated contents of this category has errors" in result):
    pagemsg("Won't create page, would lead to errors: <%s>" % result)
  else:
    pagemsg("Creating page, output is <%s>" % result)
    comment = 'Created page with "%s"' % contents
    if args.save:
      page.text = contents
      if blib.safe_page_save(page, comment, errandpagemsg):
        errandpagemsg("Created page, comment = %s" % comment)
    else:
      pagemsg("Would create, comment = %s" % comment)

params = blib.create_argparser("Create wanted categories with {{auto cat}}", include_pagefile=True)
params.add_argument("--overwrite", help="Overwrite existing text.", action="store_true")
args = params.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_page)
