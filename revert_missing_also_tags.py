#!/usr/bin/env python
#coding: utf-8

#    revert_missing_also_tags.py is free software: you can redistribute it and/or modify
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

import pywikibot, re, sys, codecs, argparse, time
import blib
from blib import site, msg, errmsg, group_notes, iter_items

# add_ru_etym.py had a bug in it that erased {{also|...}} and similar tags
# at the top of a page, before any language sections. This script undoes the
# damage.

def restore_removed_pagehead(index, pagetitle, comment, oldrevid, save, verbose):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  def errpagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
    errmsg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing page with comment = %s" % comment)
  if re.search('(add|replace).*Etymology section', comment):
    page = pywikibot.Page(site, pagetitle)
    oldtext = page.getOldVersion(oldrevid)
    oldtext_pagehead = re.split("(^==[^=\n]+==\n)", oldtext, 0, re.M)[0]
    if oldtext_pagehead:
      newtext_pagehead = re.split("(^==[^=\n]+==\n)", page.text, 0, re.M)[0]
      if newtext_pagehead != oldtext_pagehead:
        if newtext_pagehead:
          errpagemsg("WARNING: Something weird, old page has pagehead <%s> and new page has different pagehead <%s>" % (
            oldtext_pagehead, newtext_pagehead))
          return
        pagemsg("Adding old pagehead <%s> to new page" % oldtext_pagehead)
        pagetext = page.text
        newtext = oldtext_pagehead + pagetext

        if verbose:
          pagemsg("Replacing <%s> with <%s>" % (pagetext, newtext))
        notes = ['Restore missing page head: %s' % oldtext_pagehead.strip()]
        comment = "; ".join(group_notes(notes))
        if save:
          pagemsg("Saving with comment = %s" % comment)
          page.text = newtext
          page.save(comment=comment)
        else:
          pagemsg("Would save with comment = %s" % comment)

def process_item(index, item, save, verbose):
  restore_removed_pagehead(index, item['title'], item['comment'], item['parentid'],
      save, verbose)

def process_page(index, pagetitle, save, verbose):
  page = pywikibot.Page(site, pagetitle)
  revisions = list(page.revisions(total=50))
  for rev in revisions:
    if rev['user'] == 'WingerBot':
      oldrevid = rev['_parent_id']
      if oldrevid:
        restore_removed_pagehead(index, pagetitle, rev['comment'], oldrevid, save, verbose)

parser = blib.create_argparser(u"Undo wrongly-erased {{also|...}} tags from the top of a page")
parser.add_argument("--lemmafile",
    help=u"""List of lemmas to process, without accents.""")
parser.add_argument("--lemmas",
    help=u"""Comma-separated list of lemmas to process.""")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

if args.lemmafile:
  lemmas_to_process = [x.strip() for x in codecs.open(args.lemmafile, "r", "utf-8")]
elif args.lemmas:
  lemmas_to_process = re.split(",", args.lemmas.decode("utf-8"))
else:
  lemmas_to_process = []

if lemmas_to_process:
  for i, pagetitle in blib.iter_items(lemmas_to_process, start, end):
    process_page(i, pagetitle, args.save, args.verbose)
else:
  for i, item in blib.get_contributions("WingerBot", start, end):
    process_item(i, item, args.save, args.verbose)
