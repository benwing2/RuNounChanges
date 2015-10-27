#!/usr/bin/env python
# -*- coding: utf-8 -*-

import re
import pywikibot

dosave = False
overwrite = True

stress_patterns = ["a", "b", "b'", "c", "d", "d'", "e", "f", "f'", "f''"]
genders = ["masculine", "feminine", "neuter"]
stem_types = ["hard-stem", "soft-stem", "velar-stem", "sibilant-stem",
  u"ц-stem", "vowel-stem", "i-stem", "3rd-declension"]
genders_stems_stress = [["masculine", [
    ["hard-stem", ["a", "b", "c", "d", "e"]], # d maybe only кол
    ["soft-stem", ["a", "b", "c", "e", "f"]],
    ["velar-stem", ["a", "b", "c", "d", "e"]],
    ["sibilant-stem", ["a", "b", "c", "e"]],
    [u"ц-stem", ["a", "b"]],
    ["vowel-stem", ["a", "b", "c"]],
    ["i-stem", ["a", "b", "c"]], # b/c only the word кий
  ]],
  ["feminine", [
    ["hard-stem", ["a", "b", "d", "d'", "e", "f", "f'"]], # e maybe only бу́бна
    ["soft-stem", ["a", "b", "d", "d'", "e", "f"]], # d' maybe only земля́
    ["velar-stem", ["a", "b", "d", "d'", "f", "f'"]],
    ["sibilant-stem", ["a", "b", "d", "d'", "f"]],
    [u"ц-stem", ["a", "b", "d"]], # b maybe only маца́; d maybe only овца́
    ["vowel-stem", ["a", "b", "d"]],
    ["i-stem", ["a", "b"]], # b maybe only лития́, судия́, паремия́, алия́
    ["3rd-declension", ["a", "b'", "e", "f''"]],
  ]],
  ["neuter", [
    ["hard-stem", ["a", "b", "c", "d", "f"]], # f maybe only тавро́
    ["soft-stem", ["a", "c"]],
    ["velar-stem", ["a", "b", "c", "d", "e"]], # d maybe only молоко́; e maybe only у́хо
    ["sibilant-stem", ["a", "f"]], # f maybe only плечо́
    [u"ц-stem", ["a", "b", "c", "d", "f"]], # b maybe only ружьецо́, деревцо́; c maybe only се́рдце, де́ревце; d maybe only лицо́; f maybe only крыльцо́
    ["vowel-stem", ["a", "b", "d"]],
    ["i-stem", ["a", "b"]],
    ["3rd-declension", ["c"]],
  ]],
]

adj_decls = [
    ["a", "masculine", [
      [u"-ый", u"-ые", ["hard-stem"]],
      [u"-ый", u"-ые", [u"ц-stem"]],
      [u"-ий", u"-ие", ["velar-stem", "sibilant-stem"]],
      [u"-ий", u"-ьи", ["long possessive"]],
      [u"a consonant (-ъ old-style)", u"-ы", ["short possessive"]],
      [u"a consonant (-ъ old-style)", u"-ы", ["mixed possessive"]],
      [u"a consonant (-ъ old-style)", u"-ы", ["proper possessive"]],
    ]],
    ["a", "feminine", [
      [u"-ая", u"-ые", ["hard-stem"]],
      [u"-aя", u"-ые", [u"ц-stem"]],
      [u"-ая", u"-ие", ["velar-stem", "sibilant-stem"]],
      [u"-ья", u"-ьи", ["long possessive"]],
      [u"-а", u"-ы", ["short possessive"]],
      [u"-а", u"-ы", ["mixed possessive"]],
      [u"-а", u"-ы", ["proper possessive"]],
    ]],
    ["a", "neuter", [
      [u"-ое", u"-ые", ["hard-stem"]],
      [u"-ее", u"-ые", [u"ц-stem"]],
      [u"-ое", u"-ие", ["velar-stem"]],
      [u"-ее", u"-ие", ["sibilant-stem"]],
      [u"-ье", u"-ьи", ["long possessive"]],
      [u"-о", u"-ы", ["short possessive"]],
      [u"-о", u"-ы", ["mixed possessive"]],
      [u"-о", u"-ы", ["proper possessive"]],
    ]],
    ["a", "plural-only", [
      ["", u"-ые", ["hard-stem"]],
      ["", u"-ые", [u"ц-stem"]],
      ["", u"-ие", ["velar-stem", "sibilant-stem"]],
      ["", u"-ьи", ["long possessive"]],
      ["", u"-ы", ["short possessive"]],
      ["", u"-ы", ["mixed possessive"]],
      ["", u"-ы", ["proper possessive"]],
    ]],
    ["b", "masculine", [
      [u"-о́й", u"-ы́е", ["hard-stem"]],
      [u"-о́й", u"-ы́е", [u"ц-stem"]],
      [u"-о́й", u"-и́е", ["velar-stem", "sibilant-stem"]],
      [u"-и́й", u"-ьи́", ["long possessive"]],
      [u"a consonant (-ъ old-style)", u"-ы́", ["short possessive"]],
      [u"a consonant (-ъ old-style)", u"-ы́", ["mixed possessive"]],
      [u"a consonant (-ъ old-style)", u"-ы́", ["proper possessive"]],
    ]],
    ["b", "feminine", [
      [u"-а́я", u"-ы́е", ["hard-stem"]],
      [u"-áя", u"-ы́е", [u"ц-stem"]],
      [u"-а́я", u"-и́е", ["velar-stem", "sibilant-stem"]],
      [u"-ья́", u"-ьи́", ["long possessive"]],
      [u"-а́", u"-ы́", ["short possessive"]],
      [u"-а́", u"-ы́", ["mixed possessive"]],
      [u"-а́", u"-ы́", ["proper possessive"]],
    ]],
    ["b", "neuter", [
      [u"-о́е", u"-ы́е", ["hard-stem"]],
      [u"-о́е", u"-ы́е", [u"ц-stem"]],
      [u"-о́е", u"-и́е", ["velar-stem", "sibilant-stem"]],
      [u"-ье́", u"-ьи́", ["long possessive"]],
      [u"-о́", u"-ы́", ["short possessive"]],
      [u"-о́", u"-ы́", ["mixed possessive"]],
      [u"-о́", u"-ы́", ["proper possessive"]],
    ]],
    ["b", "plural-only", [
      ["", u"-ы́е", ["hard-stem"]],
      ["", u"-ы́е", [u"ц-stem"]],
      ["", u"-и́е", ["velar-stem", "sibilant-stem"]],
      ["", u"-ьи́", ["long possessive"]],
      ["", u"-ы́", ["short possessive"]],
      ["", u"-ы́", ["mixed possessive"]],
      ["", u"-ы́", ["proper possessive"]],
    ]],
    ["", "masculine", [
      [u"-ий", u"-ие", ["soft-stem", "vowel-stem"]],
    ]],
    ["", "feminine", [
      [u"-яя", u"-ие", ["soft-stem", "vowel-stem"]],
    ]],
    ["", "neuter", [
      [u"-ее", u"-ие", ["soft-stem", "vowel-stem"]],
    ]],
    ["", "plural-only", [
      ["", u"-ие", ["soft-stem", "vowel-stem"]],
    ]],
]

endings = [
    ("a consonant", u"-а"), ("a consonant", u"-ья"),
    (u"-ъ", u"-а"), (u"-ъ", u"-ья"),
    (u"-о", u"-ья"), (u"-о", u"-ы"), (u"-о", u"-и"),
    (u"-ь", u"-ья"),
    (u"suffix -ёнок", u"-ята"), (u"suffix -онок", u"-ата"),
    (u"suffix -ёнокъ", u"-ята"), (u"suffix -онокъ", u"-ата"),
    (u"suffix -ёночек", u"-ятки"), (u"suffix -оночек", u"-атки"),
    (u"suffix -ёночекъ", u"-ятки"), (u"suffix -оночекъ", u"-атки"),
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

def create_cat(cat, args, adj=False):
  if adj:
    cat = "Category:Russian " + cat.replace("~", "adjectives")
    text = "{{ruadjcatboiler|%s}}" % "|".join(args)
  else:
    cat = "Category:Russian " + cat.replace("~", "nouns")
    text = "{{runouncatboiler|%s}}" % "|".join(args)
  page = pywikibot.Page(site, cat)
  if not overwrite and page.exists():
    msg("Page %s already exists, not overwriting" % cat)
    return
  page.text = unicode(text)
  changelog = "Creating '%s' with text '%s'" % (cat, text)
  msg("Changelog = %s" % changelog)
  if dosave:
    page.save(comment = changelog)

def create_adj_cat(cat, args):
  create_cat(cat, args, adj=True)

for s in stress_patterns:
  create_cat("~ with accent pattern %s" % s, ["stress", s])
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
    create_cat("%s %s-form ~" % (stem_type, gender), ["stemgender"])
for gender, stem_stresses in genders_stems_stress:
  for stem, stresses in stem_stresses:
    for stress in stresses:
      create_cat("%s %s-form accent-%s ~" % (stem, gender, stress), ["stemgenderstress"])

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
  create_cat(cat, ["sgpl"])
for sg in sgendings:
  cat = "~ ending in %s" % sg
  create_cat(cat, ["sg"])

short_adj_stress_patterns = [
    ("a", "stem stress on all short forms"),
    ("b", "ending stress on all short forms (except the masculine singular)"),
    ("c", "ending stress on the feminine singular, stem stress on the other forms"),
    ("a'", "stem or ending stress on the feminine singular, stem stress on the other forms"),
    ("b'", "stem or ending stress on the plural, ending stress on the other forms (except the masculine singular)"),
    ("c'", "stem or ending stress on the plural, ending stress on the feminine singular and stem stress on the neuter singular"),
    ("c''", "stem or ending stress on the neuter singular and plural, ending stress on the feminine singular")]

adj_patterns = [
    ("hard-stem", "stem-stressed", u"-ый", u"-ая", u"-ое", u"-ые"),
    ("soft-stem", "stem-stressed", u"-ий", u"-яя", u"-ее", u"-ие"),
    ("velar-stem", "stem-stressed", u"-ий", u"-ая", u"-ое", u"-ие"),
    ("sibilant-stem", "stem-stressed", u"-ий", u"-ая", u"-ее", u"-ие"),
    (u"ц-stem", "stem-stressed", u"-ый", u"-ая", u"-ее", u"-ые"),
    ("vowel-stem", "stem-stressed", u"-ий", u"-яя", u"-ее", u"-ие"),
    ("hard-stem", "ending-stressed", u"-о́й", u"-а́я", u"-о́е", u"-ы́е"),
    ("velar-stem", "ending-stressed", u"-о́й", u"-а́я", u"-о́е", u"-и́е"),
    ("sibilant-stem", "ending-stressed", u"-о́й", u"-а́я", u"-о́е", u"-и́е"),
    (u"ц-stem", "ending-stressed", u"-о́й", u"-а́я", u"-о́е", u"-ы́е"),
    ("long", "possessive", u"-ий", u"-ья", u"-ье", u"-ьи"),
    ("mixed", "possessive", u"a consonant (-ъ old style)", u"-а", u"-о", u"-ы"),
    ("short", "possessive", u"a consonant (-ъ old style)", u"-а", u"-о", u"-ы"),
    ("proper", "possessive", u"a consonant (-ъ old style)", u"-а", u"-о", u"-ы"),
]

#for stress, expl in short_adj_stress_patterns:
#  create_adj_cat("~ with short accent pattern " + stress, ["shortaccent", expl])
#
#for stem, stress, m, f, n, p in adj_patterns:
#  create_adj_cat("%s %s ~" % (stem, stress), ["adj", m, f, n, p])
