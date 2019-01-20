#!/usr/bin/env python
#coding: utf-8

#    attributive_to_relational.py is free software: you can redistribute it and/or modify
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

def process_page(index, page, save, verbose):
  pagetitle = page.title()

  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  def errpagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
    errmsg("Page %s %s: %s" % (index, pagetitle, txt))

  if not blib.try_repeatedly(lambda: page.exists(), pagemsg,
      "check page existence"):
    pagemsg("Page doesn't exist, can't add etymology")
    return

  notes = []
  pagetext = unicode(page.text)

  def attributive_to_relational(m):
    labels = ['relational' if x == 'attributive' else x for x in m.group(1).split('|')]
    return '{{lb|ru|%s}}' % '|'.join(labels)
  newtext = re.sub(r'\{\{lb\|ru\|(.*?)\}\}', attributive_to_relational, pagetext)
  pagehead, sections = blib.split_text_into_sections(newtext, "Russian")
  # Go through each section in turn, looking for existing language section
  for i in xrange(len(sections)):
    m = re.match("^==([^=\n]+)==$", sections[i], re.M)
    if not m:
      pagemsg("Can't find language name in text: [[%s]]" % (sections[i]))
    elif m.group(1) == "Russian":
      lines = sections[i].split('\n')
      for line in lines:
        if '{{i|attributive}}' in line:
          pagemsg("Found {{i|attributive}}: %s" % line)
        elif 'attributive' in line:
          pagemsg("Found bare attributive: %s" % line)
      sections[i] = sections[i].replace('{{i|attributive}}', '{{i|relational}}')
      break
  else:
    errpagemsg("Can't find Russian section")
    return

  newtext = pagehead + ''.join(sections)

  if newtext != pagetext:
    notes.append("attributive -> relational")
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
  parser = blib.create_argparser("Convert attributive labels to relational")
  parser.add_argument('--lemmafile', help="File containing pages to do.")
  parser.add_argument('--cats', help="Categories to do, comma-separated.")
  args = parser.parse_args()
  start, end = blib.parse_start_end(args.start, args.end)

  if args.lemmafile:
    lines = codecs.open(args.lemmafile, "r", "utf-8")
    for i, term in iter_items(lines, start, end):
      term = term.strip()
      process_page(i, pywikibot.Page(site, term), args.save, args.verbose)
  else:
    for cat in re.split(",", args.cats):
      msg("Processing category: %s" % cat)
      for i, page in blib.cat_articles(cat, start, end):
        process_page(i, page, args.save, args.verbose)
