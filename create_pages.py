#!/usr/bin/env python
#coding: utf-8

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
from blib import msg, errandmsg, site
import pywikibot

def process_page(page, index, args, contents):
  pagetitle = unicode(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
  def errandpagemsg(txt):
    errandmsg("Page %s %s: %s" % (index, pagetitle, txt))
  if args.verbose:
    pagemsg("Processing")
  if page.exists():
    errandpagemsg("Page already exists, not overwriting")
    return
  comment = 'Created page with "%s"' % contents
  if args.save:
    page.text = contents
    if blib.safe_page_save(page, comment, errandpagemsg):
      errandpagemsg("Created page, comment = %s" % comment)
  else:
    pagemsg("Would create, comment = %s" % comment)

params = blib.create_argparser("Create pages", include_pagefile=True)
params.add_argument("--contents", help="Contents of pages", required=True)
args = params.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

contents = args.contents.decode("utf-8")

def do_process_page(page, index):
  return process_page(page, index, args, contents)
blib.do_pagefile_cats_refs(args, start, end, do_process_page)
