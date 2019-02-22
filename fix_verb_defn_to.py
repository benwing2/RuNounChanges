#!/usr/bin/env python
#coding: utf-8

#    find_regex.py is free software: you can redistribute it and/or modify
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

# Add 'to' to Russian verb defns when missing.

import blib, re, codecs
import pywikibot

import blib
from blib import getparam, rmparam, msg, site

def process_page(index, page, save, verbose):
  pagetitle = unicode(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  if verbose:
    pagemsg("Processing")

  if ":" in pagetitle and verbose:
    pagemsg("WARNING: Colon in page title, skipping page")
    return

  text = unicode(page.text)
  notes = []

  foundrussian = False
  sections = re.split("(^==[^=]*==\n)", text, 0, re.M)
  newtext = text

  for j in xrange(2, len(sections), 2):
    if sections[j-1] == "==Russian==\n":
      if foundrussian:
        pagemsg("WARNING: Found multiple Russian sections, skipping page")
        return
      foundrussian = True

      subsections = re.split("(^==.*==\n)", sections[j], 0, re.M)
      for k in xrange(2, len(subsections), 2):
        if not subsections[k].startswith("{{ru-verb|"):
          continue
        m = re.search("^===*([^=]*)=*==\n$", subsections[k-1])
        subsectitle = m.group(1)
        if subsectitle in ["Etymology", "Pronunciation"]:
          continue

        def add_to_to_defn(m):
          defn = m.group(1)
          mm = re.search(r"^((?:(?:''.*?''|\{\{.*?\}\}|\(.*?\)) *)* *)(.*?)((?:(?:''.*?''|\{\{.*?\}\}|\(.*?\)) *)* *)$", defn)
          if not mm:
            pagemsg("WARNING: Something wrong, can't parse defn line: %s" % defn)
          else:
            prefdefn, maindefn, sufdefn = mm.groups()
            if maindefn:
              indiv_defns = re.split(", *", maindefn)
              indiv_defns = ["to " + x if not x.startswith("to ") else x for x in indiv_defns]
              maindefn = ", ".join(indiv_defns)
              newdefn = prefdefn + maindefn + sufdefn
              if newdefn != defn:
                pagemsg("Replacing defn <%s> with <%s>" % (defn, newdefn))
                defn = newdefn
          return "^# " + defn + "\n"

        newtext = re.sub("^# (.*)\n", add_to_to_defn, newtext, 0, re.M)

      sections[j] = "".join(subsections)

  newtext = "".join(sections)

  if newtext != text:
    if verbose:
      pagemsg("Replacing <%s> with <%s>" % (text, newtext))
    assert notes
    comment = "; ".join(blib.group_notes(notes))
    if save:
      pagemsg("Saving with comment = %s" % comment)
      page.text = newtext
      page.save(comment=comment)
    else:
      pagemsg("Would save with comment = %s" % comment)

parser = blib.create_argparser("Add 'to' to Russian verb defns when missing")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

for category in ["Russian verbs"]:
  msg("Processing category: %s" % category)
  for i, page in blib.cat_articles(category, start, end):
    process_page(i, page, args.save, args.verbose)
