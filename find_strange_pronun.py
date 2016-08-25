#!/usr/bin/env python
#coding: utf-8

#    find_strange_pronun.py is free software: you can redistribute it and/or modify
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

# Go through looking for pages with strange pronunciations -- either
# pronunciation missing a * at the beginning or a pronunciation with
# some additional text surrounding it.

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site

def process_page(index, page, fix_star, save, verbose):
  pagetitle = unicode(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  pagetext = page.text
  notes = []

  for m in re.finditer(r"^(.*)(\{\{ru-IPA(?:\|[^}]*)?\}\})(.*)$", pagetext,
      re.M):
    pretext = m.group(1)
    ruIPA = m.group(2)
    posttext = m.group(3)
    wholeline = m.group(0)
    if not pretext.startswith("* "):
      pagemsg("WARNING: ru-IPA doesn't start with '* ': %s" % wholeline)
    pretext_no_star = re.sub(r"^\*?\s*", "", pretext)
    if pretext_no_star or posttext:
      pagemsg("WARNING: pre-text or post-text with ru-IPA: %s" % wholeline)
  if args.fix_star:
    def fix_star(m):
      wholeline = m.group(0)
      if not wholeline.startswith("* "):
        return "* " + wholeline
      else:
        return wholeline
    newtext = re.sub(r"^(.*)(\{\{ru-IPA(?:\|[^}]*)?\}\})(.*)$", fix_star,
        pagetext, 0, re.M)
    if newtext != pagetext:
      notes.append("add missing * to ru-IPA lines")
      if verbose:
        pagemsg("Replacing <%s> with <%s>" % (pagetext, newtext))
      assert notes
      comment = "; ".join(notes)
      if save:
        pagemsg("Saving with comment = %s" % comment)
        page.text = newtext
        page.save(comment=comment)
      else:
        pagemsg("Would save with comment = %s" % comment)

parser = blib.create_argparser(u"Find strange Russian pronun lines")
parser.add_argument('--pagefile', help="File containing pages to fix.")
parser.add_argument("--fix-star", action="store_true",
  help="Fix pronun lines missing * at beginning")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

if args.pagefile:
  lines = [x.strip() for x in codecs.open(args.pagefile, "r", "utf-8")]
  for i, page in blib.iter_items(lines, start, end):
    process_page(i, pywikibot.Page(site, page), args.fix_star, args.save,
        args.verbose)
else:
  for category in ["Russian lemmas", "Russian non-lemma forms"]:
    msg("Processing category: %s" % category)
    for i, page in blib.cat_articles(category, start, end):
      process_page(i, page, args.fix_star, args.save, args.verbose)
