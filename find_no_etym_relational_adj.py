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
from blib import getparam, rmparam, msg, errmsg, site, tname

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

def add_if_not(lst, item):
  if item not in lst:
    lst.append(item)

def process_page(index, page, save, verbose, adjs):
  pagetitle = unicode(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  def errpagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
    errmsg("Page %s %s: %s" % (index, pagetitle, txt))

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

  would_output = False
  for possible_adj, suffix in possible:
    if possible_adj in adjs:
      would_output = True
  if not would_output:
    return

  text = unicode(page.text)

  if rulib.check_for_obsolete_terms(text, pagemsg):
    return

  noun_lemmas = []

  for possible_adj, suffix in possible:
    if possible_adj in adjs:
      adj_section = blib.find_lang_section(possible_adj, "Russian", pagemsg)
      if not adj_section:
        errpagemsg("WARNING: Couldn't find Russian section for adjective %s" %
            possible_adj)
        continue
      if "==Etymology" in adj_section:
        pagemsg("Skipping adjective %s because it already has an etmology" %
          possible_adj)
        continue
      adj_defns = rulib.find_defns(adj_section)
      if not adj_defns:
        errpagemsg("WARNING: Could find definitions for adjective %s" %
            possible_adj)
        continue

      adj_lemmas = []
      adj_parsed = blib.parse_text(adj_section)
      for t in adj_parsed.filter_templates():
        if tname(t) == "ru-adj":
          for lemma in blib.fetch_param_chain(t, "1", "head", possible_adj):
            add_if_not(adj_lemmas, lemma)

      if not adj_lemmas:
        errpagemsg("WARNING: No adjective lemmas for %s" % possible_adj)
        return

      if not noun_lemmas:
        noun_parsed = blib.parse_text(text)
        for t in noun_parsed.filter_templates():
          if tname(t) in ["ru-noun+", "ru-proper noun+"]:
            lemmaarg = rulib.fetch_noun_lemma(t, expand_text)
            if lemmaarg is None:
              errpagemsg("WARNING: Error generating noun forms: %s" % unicode(t))
              return
            else:
              for lemma in re.split(",", lemmaarg):
                add_if_not(noun_lemmas, lemma)
          elif tname(t) in ["ru-noun", "ru-proper noun"]:
            for lemma in blib.fetch_param_chain(t, "1", "head", pagetitle):
              add_if_not(noun_lemmas, lemma)

        if not noun_lemmas:
          errpagemsg("WARNING: No noun lemmas")
          return

        warnings = []
        if len(noun_lemmas) > 1:
          warnings.append("multiple-lemmas")
        if any("//" in lemma for lemma in noun_lemmas):
          warnings.append("translit-in-lemma")

        noun_section = blib.find_lang_section_from_text(text, "Russian", pagemsg)
        if not noun_section:
          errpagemsg("WARNING: Couldn't find Russian section for noun")
          return

        noun_defns = rulib.find_defns(noun_section)
        if not noun_defns:
          errpagemsg("WARNING: Couldn't find definitions for noun")
          return

      def concat_defns(defns):
        return ";".join(defns).replace("_", r"\u").replace(" ", "_")
      msg("%s %s+%s%s no-etym possible-relational %s %s" %
        (",".join(adj_lemmas), ",".join(noun_lemmas), suffix,
          " WARNING:%s" % ",".join(warnings) if warnings else "",
          concat_defns(noun_defns), concat_defns(adj_defns)))

parser = blib.create_argparser(u"Find etymologies for relational adjectives in -ный, -ной, -овый, -евый, -овой, -евой")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

adjs = []
for i, page in blib.cat_articles("Russian adjectives"):
  adjs.append(page.title())

for category in ["Russian nouns"]:
  for i, page in blib.cat_articles(category, start, end):
    process_page(i, page, args.save, args.verbose, adjs)
