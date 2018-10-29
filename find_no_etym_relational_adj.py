#!/usr/bin/env python
#coding: utf-8

#    find_no_etym_relational_adj.py is free software: you can redistribute it and/or modify
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

# Try to construct etymologies of adjectives in -ный, -ной, -овый, -евый, -овой, -евой from nouns.

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site

import rulib

def first_palatalization(term):
  conversion = [
    (u"ск", u"щ"),
    (u"к", u"ч"),
    (u"г", u"ж"),
    (u"х", u"ш"),
    (u"ц", u"ч"),
  ]
  for ending, converted in conversion:
    if term.endswith(ending):
      return re.sub(ending + "$", converted, term)
  return term

def process_page(index, page, save, verbose, adjs):
  pagetitle = unicode(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  def expand_text(tempcall):
    return blib.expand_text(tempcall, pagetitle, pagemsg, verbose)

  pagemsg("Processing")

  # ending and whether final consonant is palatal
  endings = [
    (u"ия", True),
    (u"я", True),
    (u"е", True),
    (u"ь", True),
    (u"и", True),
    (u"а", False),
    (u"о", False),
    (u"ы", False),
  ]
  stems = []
  for ending, is_palatal in endings:
    if pagetitle.endswith(ending):
      stem = re.sub(ending + "$", "", pagetitle)
      stems.append((stem, is_palatal))
  if not stems:
    stems.append((pagetitle, False))
  possible = []
  # Try -ный and -ной
  for stem, palatal in stems:
    stems_to_try = []
    def frob(stem):
      stem = first_palatalization(stem)
      if stem.endswith(u"л"):
        stem += u"ь"
      return stem
    to_try_1 = frob(stem)
    to_try_2 = rulib.dereduce_stem(stem, False)
    if to_try_2:
      to_try_2 = frob(rulib.remove_accents(to_try_2))
    to_try_3 = rulib.dereduce_stem(stem, True)
    if to_try_3:
      to_try_3 = frob(rulib.remove_accents(to_try_3))
    stems_to_try.append(to_try_1)
    if to_try_2:
      stems_to_try.append(to_try_2)
    if to_try_3 and to_try_3 != to_try_2:
      stems_to_try.append(to_try_3)
    for stem_to_try in stems_to_try:
      possible.append((stem_to_try + u"ный", u"-ный"))
      possible.append((stem_to_try + u"ной", u"-ной"))
  # Try -овый/-евый and -овой/-евой
  for stem, palatal in stems:
    stems_to_try = []
    stems_to_try.append(stem)
    reduced = rulib.reduce_stem(stem)
    if reduced:
      stems_to_try.append(reduced)
    for stem_to_try in stems_to_try:
      if re.search("[" + rulib.sib_c + "]$", stem_to_try):
        possible.append((stem_to_try + u"евый", u"-евый"))
        # stressed variant
        possible.append((stem_to_try + u"овый", u"-овый"))
        possible.append((stem_to_try + u"евой", u"-евой"))
      elif palatal:
        possible.append((stem_to_try + u"евый", u"-евый"))
        # stressed variant
        possible.append((stem_to_try + u"ёвый", u"-ёвый"))
        possible.append((stem_to_try + u"евой", u"-евой"))
      else:
        possible.append((stem_to_try + u"овый", u"-овый"))
        possible.append((stem_to_try + u"овой", u"-овой"))
  for possible_adj, suffix in possible:
    if possible_adj in adjs:
      msg("%s %s+%s no-etym possible-relational" %
        (possible_adj, pagetitle, suffix))

parser = blib.create_argparser(u"Find etymologies for relational adjectives in -ный, -ной, -овый, -евый, -овой, -евой")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

adjs = []
for i, page in blib.cat_articles("Russian adjectives"):
  adjs.append(page.title())

for category in ["Russian nouns"]:
  for i, page in blib.cat_articles(category, start, end):
    process_page(i, page, args.save, args.verbose, adjs)
