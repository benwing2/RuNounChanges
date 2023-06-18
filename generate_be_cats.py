#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import re
import pywikibot
import blib
from blib import msg, errandmsg, site

noun_stress_patterns = ["a", "b", "c", "d", "e", "f"]
adj_stress_patterns = ["a", "b"]
noun_genders = ["masculine", "feminine", "neuter"]
adj_genders = noun_genders + ["plural-only"]
noun_stem_types = ["hard", "soft", "velar-stem", "soft third-declension",
    "hard third-declension", "fourth-declension", "t-stem", "n-stem"]
adj_stem_types = ["hard", "soft", "velar-stem", "possessive", "surname"]
vowel_alts = ["а-е", "а-о", "а-во", "ы-о", "о-ы", "во-а"]

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
  cat = "Belarusian " + cat.replace("~", "%ss" % pos)
  text = "{{be-%s cat%s}}" % (shortpos, "".join("|" + arg for arg in catargs))
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

parser = blib.create_argparser("Create Belarusian noun/verb/adjective categories")
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
      create_cat("%s masculine ~ in -а" % stem_type, [])
      for stress in noun_stress_patterns:
        create_cat("%s %s-form accent-%s ~" % (stem_type, gender, stress), [])
        create_cat("%s masculine accent-%s ~ in -а" % (stem_type, stress), [])
  create_cat("adjectival ~", ["with adjectival endings."])
  for gender in adj_genders:
    for stem_type in adj_stem_types:
      create_cat("%s %s adjectival ~" % (stem_type, gender), [])
      for stress in adj_stress_patterns:
        create_cat("%s %s adjectival accent-%s ~" % (stem_type, gender, stress), [])
  create_cat("~ with reducible stem", ["with a reducible stem, where an extra vowel is inserted before the last stem consonant in the nominative singular and/or genitive plural."])
  create_cat("~ with irregular stem", ["with an irregular stem, which occurs in all cases except the nominative singular and maybe the accusative singular."], extratext="[[Category:Belarusian irregular nouns]]")
  create_cat("~ with irregular plural stem", ["with an irregular plural stem, which occurs in all cases."], extratext="[[Category:Belarusian irregular nouns]]")
  create_cat("~ with multiple accent patterns", ["with multiple accent patterns. See [[Template:be-ndecl]]."])
  create_cat("~ with multiple stems", ["with multiple stems."])

if args.pos == "verb":
  for class_ in range(1, 17):
    create_cat("class %s ~" % class_, [])
  for subclass in ["1a", "2a", "2b", "3a", "3°a", "3b", "3c",
      "4a", "4b", "4c", "5a", "5b", "5c",
      "6a", "6°a", "6b", "6°b", "6c", "6°c",
      "7a", "7b", "8a", "8b", "8c", "9a", "9b", "10a", "10c",
      "11a", "11b", "12a", "12b", "13b", "14a", "14b", "14c",
      "15a", "16a", "16b"
  ]:
    create_cat("class %s ~" % subclass, [])
