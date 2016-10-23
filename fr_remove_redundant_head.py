#!/usr/bin/env python
#coding: utf-8

#    fr_remove_redundant_head.py is free software: you can redistribute it and/or modify
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

# Go through all the French terms we can find and remove redundant head=.

import pywikibot, re, sys, codecs, argparse
import unicodedata

import blib
from blib import getparam, rmparam, msg, site

fr_head_templates = ["fr-noun", "fr-proper noun", "fr-proper-noun",
  "fr-verb", "fr-adj", "fr-adv", "fr-phrase", "fr-adj form", "fr-adj-form",
  "fr-abbr", "fr-diacritical mark", "fr-intj", "fr-letter",
  "fr-past participle", "fr-prefix", "fr-prep", "fr-pron",
  "fr-punctuation mark", "fr-suffix", "fr-verb form", "fr-verb-form"]

exclude_punc_chars = u"-־׳״'.·*[]"
punc_chars = "".join("\\" + unichr(i) for i in xrange(sys.maxunicode)
    if unicodedata.category(unichr(i)).startswith('P') and
    unichr(i) not in exclude_punc_chars)

def link_text(text):
  words = re.split("([" + punc_chars + r"\s]+)", text)
  linked_words = [("[[" + word + "]]"
    if (i % 2) == 0 and "[" not in word and "]" not in word else word)
    for i, word in enumerate(words)]
  return "".join(linked_words)

def process_page(index, page, save, verbose):
  pagetitle = unicode(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  if ":" in pagetitle:
    pagemsg("WARNING: Colon in page title, skipping")
    return

  text = unicode(page.text)

  notes = []
  parsed = blib.parse_text(text)
  for t in parsed.filter_templates():
    origt = unicode(t)
    name = unicode(t.name)
    if name in fr_head_templates:
      head = getparam(t, "head")
      if head:
        linked_pagetitle = link_text(pagetitle)
        linked_head = link_text(head)
        if linked_pagetitle == linked_head:
          pagemsg("Removing redundant head=%s" % head)
          rmparam(t, "head")
        else:
          pagemsg("Not removing non-redundant head=%s" % head)
    newt = unicode(t)
    if origt != newt:
      pagemsg("Replacing %s with %s" % (origt, newt))
      notes.append("remove redundant head= from {{%s}}" % name)

  newtext = unicode(parsed)
  if newtext != text:
    assert notes
    comment = "; ".join(notes)
    if save:
      pagemsg("Saving with comment = %s" % comment)
      page.text = newtext
      page.save(comment=comment)
    else:
      pagemsg("Would save with comment = %s" % comment)

parser = blib.create_argparser("Remove redundant head= from French terms")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

for cat in ["French lemmas", "French non-lemma forms"]:
  msg("Processing category: %s" % cat)
  for i, page in blib.cat_articles(cat, start, end):
    process_page(i, page, args.save, args.verbose)
