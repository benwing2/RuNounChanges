#!/usr/bin/env python
# -*- coding: utf-8 -*-

import re
import pywikibot
import blib
from blib import msg, errandmsg, site

adj_decls = [
  ["hard-stem stem-stressed", (u"-ий", u"-а", u"-е", u"-і")],
  ["hard-stem ending-stressed", (u"-и́й", u"-а́", u"-е́", u"-і́")],
  ["soft-stem", (u"-ій", u"-я", u"-є", u"-і")],
  [u"ц-stem", (u"-ий", u"-я", u"-е", u"-і")],
  ["vowel-stem", (u"-їй", u"-я", u"-є", u"-ї")],
  ["possessive", (u"-", u"-а", u"-е", u"-і")],
]

noun_stress_patterns = ["a", "b", "c", "d", "d'", "e", "f", "f'"]
adj_stress_patterns = ["a", "b"]
noun_genders = ["masculine", "feminine", "neuter"]
adj_genders = noun_genders + ["plural-only"]
noun_stem_types = ["hard", "soft", "velar-stem", "semisoft", "j-stem", "third-declension",
    "fourth-declension", "t-stem", "n-stem"]
adj_stem_types = ["hard", "soft", "c-stem", "j-stem", "possessive", "surname"]
vowel_alts = [u"і-е", u"і-о", u"і-ьо", u"е-і", u"о-і"]

def create_cat(cat, catargs, extratext=None):
  global args
  if args.pos == "verb":
    pos = "verb"
    shortpos = "verb"
  elif args.pos == "adj":
    pos = "adjective"
    shortpos = "adj"
  elif args.pos == "noun":
    pos = "noun"
    shortpos = "noun"
  else:
    assert False, "Invalid pos %s" % args.pos
  cat = "Ukrainian " + cat.replace("~", "%ss" % pos)
  text = "{{uk-%s cat%s}}" % (shortpos, "".join("|" + arg for arg in catargs))
  if extratext:
    text += "\n%s" % extratext
  num_pages = len(list(blib.cat_articles(cat)))
  if num_pages == 0:
    return
  cat = "Category:" + cat
  page = pywikibot.Page(site, cat)
  if not args.overwrite and page.exists():
    msg("Page %s already exists, not overwriting" % cat)
    return
  page.text = str(text)
  changelog = "Creating '%s' with text '%s'" % (cat, text)
  msg("Changelog = %s" % changelog)
  if args.save:
    blib.safe_page_save(page, changelog, errandmsg)

parser = blib.create_argparser(u"Create Ukrainian noun/verb/adjective categories")
parser.add_argument('--overwrite', help="Overwrite categories", action="store_true")
parser.add_argument('--pos', help="Part of speech of categories to create",
    choices=['noun', 'verb', 'adj'], required=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

if args.pos == "adj":
  for ty, endings in adj_decls:
    create_cat(ty + " ~", ["adj"] + list(endings))

if args.pos == "noun":
  for s in noun_stress_patterns:
    create_cat("~ with accent pattern %s" % s, [])
  for vowel_alt in vowel_alts:
    create_cat("~ with %s alternation" % vowel_alt, [])

  # create_cat("indeclinable ~", [""])
  for gender in noun_genders:
    for stem_type in noun_stem_types:
      create_cat("%s %s-form ~" % (stem_type, gender), [])
      create_cat(u"%s masculine ~ in -о" % stem_type, [])
      for stress in noun_stress_patterns:
        create_cat("%s %s-form accent-%s ~" % (stem_type, gender, stress), [])
        create_cat(u"%s masculine accent-%s ~ in -о" % (stem_type, stress), [])
  create_cat("adjectival ~", ["with adjectival endings."])
  for gender in adj_genders:
    for stem_type in adj_stem_types:
      create_cat("%s %s adjectival ~" % (stem_type, gender), [])
      for stress in adj_stress_patterns:
        create_cat("%s %s adjectival accent-%s ~" % (stem_type, gender, stress), [])
  create_cat("~ with reducible stem", ["with a reducible stem, where an extra vowel is inserted before the last stem consonant in the nominative singular and/or genitive plural."])
  create_cat("~ with irregular stem", ["with an irregular stem, which occurs in all cases except the nominative singular and maybe the accusative singular."], extratext="[[Category:Ukrainian irregular nouns]]")
  create_cat("~ with irregular plural stem", ["with an irregular plural stem, which occurs in all cases."], extratext="[[Category:Ukrainian irregular nouns]]")
  create_cat("~ with multiple accent patterns", ["with multiple accent patterns. See [[Template:uk-ndecl]]."])
  create_cat("~ with multiple stems", ["with multiple stems."])

if args.pos == "verb":
  for class_ in range(1, 16):
    create_cat("class %s ~" % class_, [])
  for subclass in ["1a", "2a", "2b", "3a", u"3°a", "3b", u"3°b", "3c", u"3°c",
      "4a", "4b", "4c", "5a", "5b", "5c",
      "6a", u"6°a", "6b", u"6°b", "6c", u"6°c",
      "7a", "7b", "7c", "8a", "8b", "8c", "9a", "9b", "10a", "10c",
      "11a", "11b", "12a", "12b", "13b", "14a", "14b", "14c",
      "15a"
  ]:
    create_cat("class %s ~" % subclass, [])
