#!/usr/bin/env python
#coding: utf-8

#    find_no_etym_suffixed.py is free software: you can redistribute it and/or modify
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

# Try to construct etymologies of adjectives and nouns with various suffixes
# from nouns and verbs.

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

def find_noun_lemmas(parsed, pagetitle, errpagemsg, expand_text):
  noun_lemmas = []
  for t in parsed.filter_templates():
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
  return noun_lemmas

def process_page(index, page, save, verbose, all_derived_lemmas):
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
    (u"ывать", False),
    (u"ивать", False),
    (u"ать", False),
    (u"ять", True),
    (u"еть", True),
    (u"ить", True),
    (u"нуть", False),
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
  def append_possible(stem_to_try, suffix):
    possible.append((stem_to_try.lower() + suffix, suffix))
  # Try -ный/-ной, -ка, -ко
  for stem, palatal in stems:
    stems_to_try = []
    def frob(stem):
      stem = first_palatalization(stem)
      if stem.endswith(u"л"):
        stem += u"ь"
      if re.search("[" + rulib.vowel + "]$", stem):
        stem += u"й"
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
      append_possible(stem_to_try, u"ный")
      append_possible(stem_to_try, u"ной")
      append_possible(stem_to_try, u"ский")
      append_possible(stem_to_try, u"ской")
      append_possible(stem_to_try, u"ник")
      append_possible(stem_to_try, u"чик")
      append_possible(stem_to_try, u"щик")
      append_possible(stem_to_try, u"ка")
      append_possible(stem_to_try, u"ко")
      append_possible(stem_to_try, u"ство")
  # Try -овый/-евый/-ёвый/-овой/-евой, -ик, -ок/-ек/-ёк
  for stem, palatal in stems:
    stems_to_try = []
    stems_to_try.append(stem)
    reduced = rulib.reduce_stem(stem)
    if reduced:
      stems_to_try.append(reduced)
    for stem_to_try in stems_to_try:
      if stem_to_try.endswith(u"й"):
        stem_to_try = stem_to_try[:-1]
      append_possible(stem_to_try, u"овый")
      append_possible(stem_to_try, u"евый")
      append_possible(stem_to_try, u"ёвый")
      append_possible(stem_to_try, u"овой")
      append_possible(stem_to_try, u"евой")
      stem_to_try = first_palatalization(stem_to_try)
      append_possible(stem_to_try, u"еский")
      append_possible(stem_to_try, u"ический")
      append_possible(stem_to_try, u"ество")
      append_possible(stem_to_try, u"ик")
      append_possible(stem_to_try, u"ок")
      append_possible(stem_to_try, u"ек")
      append_possible(stem_to_try, u"ёк")
      append_possible(stem_to_try, u"ец")

  would_output = False
  for possible_derived, suffix in possible:
    if possible_derived in all_derived_lemmas:
      would_output = True
  if not would_output:
    return

  text = unicode(page.text)

  if rulib.check_for_alt_yo_terms(text, pagemsg):
    return

  base_lemmas = []

  for possible_derived, suffix in possible:
    if possible_derived in all_derived_lemmas:
      derived_section = blib.find_lang_section(possible_derived, "Russian", pagemsg)
      if not derived_section:
        errpagemsg("WARNING: Couldn't find Russian section for derived term %s" %
            possible_derived)
        continue
      if "==Etymology" in derived_section:
        pagemsg("Skipping derived term %s because it already has an etymology" %
          possible_derived)
        continue
      derived_defns = rulib.find_defns(derived_section)
      if not derived_defns:
        errpagemsg("WARNING: Couldn't find definitions for derived term %s" %
            possible_derived)
        continue

      derived_parsed = blib.parse_text(derived_section)
      derived_lemmas = find_noun_lemmas(derived_parsed, possible_derived, errpagemsg,
        lambda tempcall: blib.expand_text(tempcall, possible_derived, pagemsg, verbose))
      for t in derived_parsed.filter_templates():
        if tname(t) == "ru-adj":
          lemmas = blib.fetch_param_chain(t, "1", "head", possible_derived)
          trs = blib.fetch_param_chain(t, "tr", "tr")
          if trs:
            lemmas = ["%s//%s" % (lemma, tr) for lemma, tr in zip(lemmas, trs)]
          for lemma in lemmas:
            add_if_not(derived_lemmas, lemma)

      if not derived_lemmas:
        errpagemsg("WARNING: No derived term lemmas for %s" % possible_derived)
        return

      if not base_lemmas:
        base_parsed = blib.parse_text(text)
        base_lemmas = find_noun_lemmas(base_parsed, pagetitle, errpagemsg, expand_text)

        for t in base_parsed.filter_templates():
          if tname(t) == "ru-verb":
            lemmas = blib.fetch_param_chain(t, "1", "head", pagetitle)
            trs = blib.fetch_param_chain(t, "tr", "tr")
            if trs:
              lemmas = ["%s//%s" % (lemma, tr) for lemma, tr in zip(lemmas, trs)]
            for lemma in lemmas:
              add_if_not(base_lemmas, lemma)

        if not base_lemmas:
          errpagemsg("WARNING: No base lemmas")
          return

        base_lemmas = [rulib.remove_monosyllabic_accents(x) for x in base_lemmas]

        warnings = []
        if len(base_lemmas) > 1:
          warnings.append("multiple-lemmas")
        if any("//" in lemma for lemma in base_lemmas):
          warnings.append("translit-in-lemma")

        base_section = blib.find_lang_section_from_text(text, "Russian", pagemsg)
        if not base_section:
          errpagemsg("WARNING: Couldn't find Russian section for base")
          return

        base_defns = rulib.find_defns(base_section)
        if not base_defns:
          errpagemsg("WARNING: Couldn't find definitions for base")
          return

      def concat_defns(defns):
        return ";".join(defns).replace("_", r"\u").replace(" ", "_")

      suffixes_with_stress = []
      for suf in [suffix, rulib.make_beginning_stressed(suffix),
          rulib.make_ending_stressed(suffix)]:
        for derived_lemma in derived_lemmas:
          if derived_lemma.endswith(suf):
            add_if_not(suffixes_with_stress, suf)
      msg("%s %s+-%s%s no-etym possible-suffixed %s //// %s" %
        (",".join(derived_lemmas), ",".join(base_lemmas),
          ",".join(suffixes_with_stress),
          " WARNING:%s" % ",".join(warnings) if warnings else "",
          concat_defns(base_defns), concat_defns(derived_defns)))

parser = blib.create_argparser(u"Find etymologies for adjectives and nouns with common suffixes")
parser.add_argument("--nouns", action='store_true', help="Do derivatives of nouns instead of adjectives")
parser.add_argument("--base-lemmafile", help="File containing base lemmas")
parser.add_argument("--derived-lemmafile", help="File containing derived lemmas")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

derived_lemmas = []
if args.derived_lemmafile:
  derived_lemmas = [rulib.remove_accents(x.strip()) for x in codecs.open(args.derived_lemmafile, "r", "utf-8")]
else:
  for i, page in blib.cat_articles("Russian nouns" if args.nouns else "Russian adjectives"):
    derived_lemmas.append(page.title())

if args.base_lemmafile:
  for i, pagename in blib.iter_items([rulib.remove_accents(x.strip()) for x in codecs.open(args.base_lemmafile, "r", "utf-8")]):
    page = pywikibot.Page(site, pagename)
    process_page(i, page, args.save, args.verbose, derived_lemmas)
else:
  for category in ["Russian proper nouns", "Russian nouns", "Russian verbs"]:
    for i, page in blib.cat_articles(category, start, end):
      process_page(i, page, args.save, args.verbose, derived_lemmas)
