#!/usr/bin/env python
#coding: utf-8

#    put_attributive_first.py is free software: you can redistribute it and/or modify
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
import rulib

def process_term(index, term, save, verbose):
  pagetitle = term

  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  def errpagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
    errmsg("Page %s %s: %s" % (index, pagetitle, txt))

  # Load page
  page = pywikibot.Page(site, pagetitle)

  if not blib.try_repeatedly(lambda: page.exists(), pagemsg,
      "check page existence"):
    pagemsg("Page doesn't exist, can't add etymology")
    return

  notes = []
  pagetext = unicode(page.text)

  def put_attributive_first(m):
    labels = m.group(1).split('|')
    if 'attributive' in labels:
      labels_wo_attributive = [label for label in labels if label != 'attributive']
      labels = ['attributive'] + labels_wo_attributive
    return '{{lb|ru|%s}}' % '|'.join(labels)
  newtext = re.sub(r'\{\{lb\|ru\|(.*?)\}\}', put_attributive_first, pagetext)

  if newtext != pagetext:
    notes.append("put attributive label first")
    if verbose:
      pagemsg("Replacing <%s> with <%s>" % (pagetext, newtext))
    assert notes
    comment = "; ".join(group_notes(notes))
    if save:
      pagemsg("Saving with comment = %s" % comment)
      page.text = newtext
      page.save(comment=comment)
    else:
      pagemsg("Would save with comment = %s" % comment)

if __name__ == "__main__":
  parser = blib.create_argparser("Put attributive label first")
  parser.add_argument('--direcfile', help="File containing pages to do.")
  args = parser.parse_args()
  start, end = blib.parse_start_end(args.start, args.end)

  lines = codecs.open(args.direcfile, "r", "utf-8")
  for i, term in iter_items(lines, start, end):
    term = term.strip()
    process_term(i, term, args.save, args.verbose)
