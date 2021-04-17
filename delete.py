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
  this_comment = comment or 'delete page'
  if page.exists():
    if args.save:
      page.delete('%s (content was "%s")' % (this_comment, unicode(page.text)))
      errandpagemsg("Deleted (comment=%s)" % this_comment)
    else:
      pagemsg("Would delete (comment=%s)" % this_comment)
  else:
    pagemsg("Skipping, page doesn't exist")

params = blib.create_argparser("Delete pages", include_pagefile=True)
params.add_argument("--comment", help="Specify the change comment to use")
params.add_argument("--direcfile", help="File containing pages to delete, optionally with comments after ' ||| '.")
args = params.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

comment = args.comment and args.comment.decode("utf-8")
direcfile = args.direcfile and args.direcfile.decode("utf-8")

if direcfile:
  lines = [x.strip() for x in codecs.open(direcfile, "r", "utf-8")]
  for index, line in blib.iter_items(lines, start, end):
    if " ||| " in line:
      pagetitle, page_comment = line.split(" ||| ")
    else:
      pagetitle = line
      page_comment = comment
    page = pywikibot.Page(site, pagetitle)
    process_page(page, index, args, page_comment)
else:
  def do_process_page(page, index):
    return process_page(page, index, args, comment)
  blib.do_pagefile_cats_refs(args, start, end, do_process_page)
