#!/usr/bin/python
# -*- coding: utf-8 -*-

import re

stress_patterns = ["1", "2", "3", "4", "4*", "5", "6", "6*"]
decls = [
    ["1st", "hard", "feminine", [
      [u"-а", u"-ы (-и after velars and sibilants)", [None]],
      [u"-а", u"-ы", [u"ц"]],
      [u"-а", u"-и", ["velar", "sibilant"]],
    ]],
    ["1st", "soft", "feminine", [
      [u"-я", u"-и", [None, "i", u"ь"]]
    ]],
    ["2nd", "hard", "masculine", [
      [u"a consonant (-ъ old-style)", u"-ы (-и after velars and sibilants)",
        [None]],
      [u"-ц (-цъ old-style)", u"-ы", [u"ц"]],
      [u"a velar (plus -ъ old-style)", u"-и", ["velar"]],
      [u"a sibilant (plus -ъ old-style)", u"-и", ["sibilant"]],
    ]],
    ["2nd", "soft", "masculine", [
      [u"-ь", u"-и", [None]]
    ]],
    ["2nd", "palatal", "masculine", [
      [u"й", u"-и", [None, "i"]]
    ]],
    ["2nd", "hard", "neuter", [
      [u"-о (-e after sibilants and ц)", u"-а", [None]],
      [u"-о", u"-а", ["velar"]],
      [u"-е", u"-а", ["sibilant", u"ц"]],
    ]],
    ["2nd", "soft", "neuter", [
      [u"-е (stressed usually -ё)", u"-я", [None, "i", u"ь"]]
    ]],
    ["3rd", "", "feminine (some neuter)", [
      [u"-ь (neuter in -мя)", u"-и (neuter in -мена or -мёна)", [None]]
    ]],
    ["invariable", None, None, [
      [None, None, [None]]
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
    (u"suffix -мя", u"-мена"), (u"suffix -мя", u"-мёна"),
]
sgendings = [u"-ё", u"stressed -е", u"-ьё"]
cases = ["nominative", "genitive", "dative", "accusative", "instrumental",
    "prepositional"]
numbers = ["singular", "plural"]
extra_cases = ["locative", "partitive", "vocative"]

def create_cat(cat, args):
  print ("Russian %s: {{runouncatboiler|%s}}" % (re.sub("~", "nominals", cat),
      "|".join(args))).encode("utf-8")

for s in stress_patterns:
  create_cat("~ with stress pattern %s" % s, ["stress", s])
for c in extra_cases:
  create_cat("~ with %s" % c, ["extracase", c])
for c in cases:
  for n in numbers:
    create_cat("~ with irregular %s %s" % (c, n),
        ["irregcase", "%s %s" % (c, n)])
for decl, hard, gender, sgplstems in decls:
  if decl == "invariable":
    create_cat("invariable ~", ["decl", "invariable"])
    continue
  elif decl == "1st":
    cat = "1st-declension %s ~" % hard
  elif decl == "2nd":
    cat = "2nd-declension %s normally-%s ~" % (hard, gender)
  else:
    assert(decl == "3rd")
    cat = "3rd-declension ~"
  for sg, pl, stems in sgplstems:
    for stem in stems:
      if not stem:
        create_cat(cat, ["decl", decl, hard, gender, sg, pl])
      else:
        create_cat("%s-stem %s" % (stem, cat),
            ["decl", decl, hard, gender, sg, pl, stem])

for sg, pl in endings:
  cat = "~ ending in %s with plural %s" % (sg, pl)
  create_cat(cat, ["sgpl", sg, pl])
for sg in sgendings:
  cat = "~ ending in %s" % sg
  create_cat(cat, ["sg", sg])
