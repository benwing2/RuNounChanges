#!/usr/bin/env python
#coding: utf-8

#    find_pppp.py is free software: you can redistribute it and/or modify
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

# Go through all the terms we can find looking for pages that are
# missing a headword declaration.

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site

import rulib

def process_page(index, page, save, verbose, fixdirecs):
  pagetitle = unicode(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  def expand_text(tempcall):
    return blib.expand_text(tempcall, pagetitle, pagemsg, verbose)

  pagemsg("Processing")

  text = unicode(page.text)
  parsed = blib.parse(page)
  notes = []
  saw_paired_verb = False
  for t in parsed.filter_templates():
    if unicode(t.name) == "ru-verb":
      saw_paired_verb = False
      if getparam(t, "2") in ["impf", "both"]:
        verb = getparam(t, "1")
        pfs = blib.fetch_param_chain(t, "pf", "pf")
        impfs = blib.fetch_param_chain(t, "impf", "impf")
        for otheraspect in pfs + impfs:
          if verb[0:2] == otheraspect[0:2]:
            saw_paired_verb = True
    if (unicode(t.name) in ["ru-conj"] and getparam(t, "2") == "impf" and
        not saw_paired_verb):
      if getparam(t, "ppp") or getparam(t, "past_pasv_part") or (
          re.search(r"\+p|\[?\([78]\)\]?", getparam(t, "1"))):
        pass
      else:
        pagemsg("Apparent unpaired transitive imperfective without PPP")
        if pagetitle in fixdirecs:
          direc = fixdirecs[pagetitle]
          assert direc in ["fixed", "paired", "intrans", "+p", "|ppp=-"]
          origt = unicode(t)
          if direc == "+p":
            t.add("1", getparam(t, "1") + "+p")
            notes.append("add missing past passive participle to transitive unpaired imperfective verb")
            pagemsg("Add missing PPP, replace %s with %s" % (origt, unicode(t)))
          elif direc == "|ppp=-":
            t.add("ppp", "-")
            notes.append("note transitive unpaired imperfective verb as lacking past passive participle")
            pagemsg("Note no PPP, replace %s with %s" % (origt, unicode(t)))
          elif direc == "paired":
            pagemsg("Verb actually is paired")
          elif direc == "fixed":
            pagemsg("WARNING: Unfixed verb marked as fixed")
          elif direc == "intrans":
            pagemsg("WARNING: Transitive verb marked as intrans")

  new_text = unicode(parsed)

  if new_text != text:
    if verbose:
      pagemsg("Replacing <%s> with <%s>" % (text, new_text))
    assert notes
    comment = "; ".join(notes)
    if save:
      pagemsg("Saving with comment = %s" % comment)
      page.text = new_text
      page.save(comment=comment)
    else:
      pagemsg("Would save with comment = %s" % comment)

parser = blib.create_argparser(u"Find Russian terms without a proper headword line")
parser.add_argument('--fix-pagefile', help="File containing pages to fix.")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

if args.fix_pagefile:
  fixdireclines = [
    x.strip() for x in codecs.open(args.fix_pagefile, "r", "utf-8")]
  fixdirecs = {}
  fixpages = []
  for line in fixdireclines:
    verb, direc = re.split(" ", line)
    fixdirecs[verb] = direc
    fixpages.append(verb)
  for i, page in blib.iter_items(fixpages, start, end):
    process_page(i, pywikibot.Page(site, page), args.save, args.verbose, fixdirecs)
else:
  for category in ["Russian verbs"]:
    for i, page in blib.cat_articles(category, start, end):
      process_page(i, page, args.save, args.verbose, {})
