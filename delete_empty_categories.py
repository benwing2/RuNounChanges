#!/usr/bin/env python
#coding: utf-8

#    delete.py is free software: you can redistribute it and/or modify
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

def process_page(page, index, args, comment):
  pagetitle = unicode(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
  def errandpagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
    errmsg("Page %s %s: %s" % (index, pagetitle, txt))
  if args.verbose:
    pagemsg("Processing")
  catname = re.sub("^Category:", "", pagetitle)
  num_pages = len(list(blib.cat_articles(catname)))
  num_subcats = len(list(blib.cat_subcats(catname)))
  if num_pages > 0 or num_subcats > 0:
    errandpagemsg("Skipping (not empty): num_pages=%s, num_subcats=%s" % (
      num_pages, num_subcats))
    return
  this_comment = comment or 'delete empty category'
  if page.exists():
    if args.save:
      page.delete('%s (content was "%s")' % (this_comment, unicode(page.text)))
      errandpagemsg("Deleted (comment=%s)" % this_comment)
    else:
      pagemsg("Would delete (comment=%s)" % this_comment)
  else:
    pagemsg("Skipping, page doesn't exist")

params = blib.create_argparser("Delete empty category pages", include_pagefile=True)
params.add_argument("--comment", help="Specify the change comment to use")
args = params.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

comment = args.comment and args.comment.decode("utf-8")

def do_process_page(page, index):
  return process_page(page, index, args, comment)
blib.do_pagefile_cats_refs(args, start, end, do_process_page)
