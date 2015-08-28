#!/usr/bin/env python
# -*- coding: utf-8 -*-

import re
import pywikibot

dosave = False

stress_patterns = ["1", "2", "3", "4", "4*", "5", "6", "6*"]
genders = ["masculine", "feminine", "neuter"]
stem_types = ["hard-stem", "soft-stem", "velar-stem", "sibilant-stem",
  u"ц-stem", "vowel-stem", "i-stem", "3rd-declension"]
genders_stems_stress = [["masculine", [
    ["hard-stem", ["1", "2", "3", "5"]],
    ["soft-stem", ["1", "2", "3", "5", "6"]],
    ["velar-stem", ["1", "2", "3", "4", "5"]],
    ["sibilant-stem", ["1", "2", "3", "5"]],
    [u"ц-stem", ["1", "2"]],
    ["vowel-stem", ["1", "2", "3"]],
    ["i-stem", ["1"]],
  ]],
  ["feminine", [
    ["hard-stem", ["1", "2", "4", "6"]], # FIXME: Check for 4*, 6*
    ["soft-stem", ["1", "2", "4", "5", "6"]],
    ["velar-stem", ["1", "2", "4", "6"]],
    ["sibilant-stem", ["1", "2", "4", "6"]],
    [u"ц-stem", ["1"]],
    ["vowel-stem", ["1", "2", "4", "5", "6"]], # FIXME: Check this
    ["i-stem", ["1"]],
    ["3rd-declension", ["1", "5"]],
  ]],
  ["neuter", [
    ["hard-stem", ["1", "2", "3", "4"]],
    ["soft-stem", ["1", "3"]],
    ["velar-stem", ["1", "2"]],
    ["sibilant-stem", ["1"]],
    [u"ц-stem", ["1", "3"]],
    ["vowel-stem", ["1", "2", "4"]],
    ["i-stem", ["1", "2"]],
    ["3rd-declension", ["3"]],
  ]],
]

adj_decls = [
    ["1", "masculine", [
      [u"-ый", u"-ые", ["hard-stem"]],
      [u"-ый", u"-ые", [u"ц-stem"]],
      [u"-ий", u"-ие", ["velar-stem", "sibilant-stem"]],
    ]],
    ["1", "feminine", [
      [u"-ая", u"-ые", ["hard-stem"]],
      [u"-aя", u"-ые", [u"ц-stem"]],
      [u"-ая", u"-ие", ["velar-stem", "sibilant-stem"]],
    ]],
    ["1", "neuter", [
      [u"-ое", u"-ые", ["hard-stem"]],
      [u"-ее", u"-ые", [u"ц-stem"]],
      [u"-ое", u"-ие", ["velar-stem"]],
      [u"-ее", u"-ие", ["sibilant-stem"]],
    ]],
    ["2", "masculine", [
      [u"-о́й", u"-ы́е", ["hard-stem"]],
      [u"-о́й", u"-ы́е", [u"ц-stem"]],
      [u"-о́й", u"-и́е", ["velar-stem", "sibilant-stem"]],
    ]],
    ["2", "feminine", [
      [u"-а́я", u"-ы́е", ["hard-stem"]],
      [u"-áя", u"-ы́е", [u"ц-stem"]],
      [u"-а́я", u"-и́е", ["velar-stem", "sibilant-stem"]],
    ]],
    ["2", "neuter", [
      [u"-о́е", u"-ы́е", ["hard-stem"]],
      [u"-о́е", u"-ы́е", [u"ц-stem"]],
      [u"-о́е", u"-и́е", ["velar-stem", "sibilant-stem"]],
    ]],
    ["", "masculine", [
      [u"-ий", u"-ие", ["soft-stem", "vowel-stem"]],
      [u"-ий", u"-ьи", ["long possessive"]],
      [u"a consonant (-ъ old-style)", u"-ы", ["short possessive"]],
      [u"a consonant (-ъ old-style)", u"-ы", ["mixed possessive"]],
    ]],
    ["", "feminine", [
      [u"-яя", u"-ие", ["soft-stem", "vowel-stem"]],
      [u"-ья", u"-ьи", ["long possessive"]],
      [u"-а", u"-ы", ["short possessive"]],
      [u"-а", u"-ы", ["mixed possessive"]],
    ]],
    ["", "neuter", [
      [u"-ее", u"-ие", ["soft-stem", "vowel-stem"]],
      [u"-ье", u"-ьи", ["long possessive"]],
      [u"-о", u"-ы", ["short possessive"]],
      [u"-о", u"-ы", ["mixed possessive"]],
    ]],
]

endings = [
    ("a consonant", u"-а"), ("a consonant", u"-ья"),
    (u"-ъ", u"-а"), (u"-ъ", u"-ья"),
    (u"-о", u"-ья"), (u"-о", u"-ы"), (u"-о", u"-и"),
    (u"-ь", u"-ья"),
    (u"suffix -ёнок", u"-ята"), (u"suffix -онок", u"-ата"),
    (u"suffix -ёнокъ", u"-ята"), (u"suffix -онокъ", u"-ата"),
    (u"suffix -ин", u"-e"), (u"suffix -инъ", u"-е"),
]
sgendings = [u"-ё", u"stressed -е", u"-ьё"]
cases = ["nominative", "genitive", "dative", "accusative", "instrumental",
    "prepositional"]
numbers = ["singular", "plural"]
extra_cases = ["locative", "partitive", "vocative"]

site = pywikibot.Site()

def msg(text):
  print text.encode('utf-8')

def create_cat(cat, args):
  cat = "Category:Russian " + cat.replace("~", "nominals")
  text = "{{runouncatboiler|%s}}" % "|".join(args)
  page = pywikibot.Page(site, cat)
  page.text = unicode(text)
  changelog = "Creating '%s' with text '%s'" % (cat, text)
  msg("Changelog = %s" % changelog)
  if dosave:
    page.save(comment = changelog)

for s in stress_patterns:
  create_cat("~ with stress pattern %s" % s, ["stress", s])
for c in extra_cases:
  create_cat("~ with %s" % c, ["extracase", c])
for c in cases:
  for n in numbers:
    create_cat("~ with irregular %s %s" % (c, n),
        ["irregcase", "%s %s" % (c, n)])

create_cat("invariable ~", ["stemgender"])
for gender in genders:
  for stem_type in stem_types:
    if gender == "masculine" and stem_type == "3rd-declension":
      continue
    create_cat("%s %s-type ~" % (stem_type, gender), ["stemgender"])
for gender, stem_stresses in genders_stems_stress:
  for stem, stresses in stem_stresses:
    for stress in stresses:
      create_cat("%s %s-type accent-%s ~" % (stem, gender, stress), ["stemgenderstress"])

for stress, gender, sgplstems in adj_decls:
  for sg, pl, stems in sgplstems:
    for stem in stems:
      if stress:
        create_cat("%s %s accent-%s adjectival ~" % (stem, gender, stress),
            ["adj", sg, pl])
      else:
        create_cat("%s %s adjectival ~" % (stem, gender),
            ["adj", sg, pl])

for sg, pl in endings:
  cat = "~ ending in %s with plural %s" % (sg, pl)
  create_cat(cat, ["sgpl", sg, pl])
for sg in sgendings:
  cat = "~ ending in %s" % sg
  create_cat(cat, ["sg", sg])
