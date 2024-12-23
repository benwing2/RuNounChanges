#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import re
import pywikibot
import blib
from blib import site, msg, errandmsg

dosave = True
overwrite = False
donouns = False
doadjs = False
doverbs = True

stress_patterns = ["a", "b", "b'", "c", "d", "d'", "e", "f", "f'", "f''"]
genders = ["masculine", "feminine", "neuter"]
stem_types = ["hard-stem", "soft-stem", "velar-stem", "sibilant-stem",
  "ц-stem", "vowel-stem", "i-stem", "3rd-declension"]
genders_stems_stress = [["masculine", [
    ["hard-stem", ["a", "b", "c", "d", "e"]], # d maybe only кол
    ["soft-stem", ["a", "b", "c", "e", "f"]],
    ["velar-stem", ["a", "b", "c", "d", "e"]],
    ["sibilant-stem", ["a", "b", "c", "e"]],
    ["ц-stem", ["a", "b"]],
    ["vowel-stem", ["a", "b", "c"]],
    ["i-stem", ["a", "b", "c"]], # b/c only the word кий
  ]],
  ["feminine", [
    ["hard-stem", ["a", "b", "d", "d'", "e", "f", "f'"]], # e maybe only бу́бна
    ["soft-stem", ["a", "b", "d", "d'", "e", "f"]], # d' maybe only земля́
    ["velar-stem", ["a", "b", "d", "d'", "f", "f'"]],
    ["sibilant-stem", ["a", "b", "d", "d'", "f"]],
    ["ц-stem", ["a", "b", "d"]], # b maybe only маца́; d maybe only овца́
    ["vowel-stem", ["a", "b", "d"]],
    ["i-stem", ["a", "b"]], # b maybe only лития́, судия́, паремия́, алия́
    ["3rd-declension", ["a", "b'", "e", "f''"]],
  ]],
  ["neuter", [
    ["hard-stem", ["a", "b", "c", "d", "f"]], # f maybe only тавро́
    ["soft-stem", ["a", "c"]],
    ["velar-stem", ["a", "b", "c", "d", "e"]], # d maybe only молоко́; e maybe only у́хо
    ["sibilant-stem", ["a", "f"]], # f maybe only плечо́
    ["ц-stem", ["a", "b", "c", "d", "f"]], # b maybe only ружьецо́, деревцо́; c maybe only се́рдце, де́ревце; d maybe only лицо́; f maybe only крыльцо́
    ["vowel-stem", ["a", "b", "d"]],
    ["i-stem", ["a", "b"]],
    ["3rd-declension", ["c"]],
  ]],
]

adj_decls = [
    ["a", "masculine", [
      ["-ый", "-ые", ["hard-stem"]],
      ["-ый", "-ые", ["ц-stem"]],
      ["-ий", "-ие", ["velar-stem", "sibilant-stem"]],
      ["-ий", "-ьи", ["long possessive"]],
      ["a consonant (-ъ old-style)", "-ы", ["short possessive"]],
      ["a consonant (-ъ old-style)", "-ы", ["mixed possessive"]],
      ["a consonant (-ъ old-style)", "-ы", ["proper possessive"]],
    ]],
    ["a", "feminine", [
      ["-ая", "-ые", ["hard-stem"]],
      ["-aя", "-ые", ["ц-stem"]],
      ["-ая", "-ие", ["velar-stem", "sibilant-stem"]],
      ["-ья", "-ьи", ["long possessive"]],
      ["-а", "-ы", ["short possessive"]],
      ["-а", "-ы", ["mixed possessive"]],
      ["-а", "-ы", ["proper possessive"]],
    ]],
    ["a", "neuter", [
      ["-ое", "-ые", ["hard-stem"]],
      ["-ее", "-ые", ["ц-stem"]],
      ["-ое", "-ие", ["velar-stem"]],
      ["-ее", "-ие", ["sibilant-stem"]],
      ["-ье", "-ьи", ["long possessive"]],
      ["-о", "-ы", ["short possessive"]],
      ["-о", "-ы", ["mixed possessive"]],
      ["-о", "-ы", ["proper possessive"]],
    ]],
    ["a", "plural-only", [
      ["", "-ые", ["hard-stem"]],
      ["", "-ые", ["ц-stem"]],
      ["", "-ие", ["velar-stem", "sibilant-stem"]],
      ["", "-ьи", ["long possessive"]],
      ["", "-ы", ["short possessive"]],
      ["", "-ы", ["mixed possessive"]],
      ["", "-ы", ["proper possessive"]],
    ]],
    ["b", "masculine", [
      ["-о́й", "-ы́е", ["hard-stem"]],
      ["-о́й", "-ы́е", ["ц-stem"]],
      ["-о́й", "-и́е", ["velar-stem", "sibilant-stem"]],
      ["-и́й", "-ьи́", ["long possessive"]],
      ["a consonant (-ъ old-style)", "-ы́", ["short possessive"]],
      ["a consonant (-ъ old-style)", "-ы́", ["mixed possessive"]],
      ["a consonant (-ъ old-style)", "-ы́", ["proper possessive"]],
    ]],
    ["b", "feminine", [
      ["-а́я", "-ы́е", ["hard-stem"]],
      ["-áя", "-ы́е", ["ц-stem"]],
      ["-а́я", "-и́е", ["velar-stem", "sibilant-stem"]],
      ["-ья́", "-ьи́", ["long possessive"]],
      ["-а́", "-ы́", ["short possessive"]],
      ["-а́", "-ы́", ["mixed possessive"]],
      ["-а́", "-ы́", ["proper possessive"]],
    ]],
    ["b", "neuter", [
      ["-о́е", "-ы́е", ["hard-stem"]],
      ["-о́е", "-ы́е", ["ц-stem"]],
      ["-о́е", "-и́е", ["velar-stem", "sibilant-stem"]],
      ["-ье́", "-ьи́", ["long possessive"]],
      ["-о́", "-ы́", ["short possessive"]],
      ["-о́", "-ы́", ["mixed possessive"]],
      ["-о́", "-ы́", ["proper possessive"]],
    ]],
    ["b", "plural-only", [
      ["", "-ы́е", ["hard-stem"]],
      ["", "-ы́е", ["ц-stem"]],
      ["", "-и́е", ["velar-stem", "sibilant-stem"]],
      ["", "-ьи́", ["long possessive"]],
      ["", "-ы́", ["short possessive"]],
      ["", "-ы́", ["mixed possessive"]],
      ["", "-ы́", ["proper possessive"]],
    ]],
    ["", "masculine", [
      ["-ий", "-ие", ["soft-stem", "vowel-stem"]],
    ]],
    ["", "feminine", [
      ["-яя", "-ие", ["soft-stem", "vowel-stem"]],
    ]],
    ["", "neuter", [
      ["-ее", "-ие", ["soft-stem", "vowel-stem"]],
    ]],
    ["", "plural-only", [
      ["", "-ие", ["soft-stem", "vowel-stem"]],
    ]],
]

endings = [
    ("a consonant", "-а"), ("a consonant", "-ья"),
    ("-ъ", "-а"), ("-ъ", "-ья"),
    ("-о", "-ья"), ("-о", "-ы"), ("-о", "-и"),
    ("-ь", "-ья"),
    ("suffix -ёнок", "-ята"), ("suffix -онок", "-ата"),
    ("suffix -ёнокъ", "-ята"), ("suffix -онокъ", "-ата"),
    ("suffix -ёночек", "-ятки"), ("suffix -оночек", "-атки"),
    ("suffix -ёночекъ", "-ятки"), ("suffix -оночекъ", "-атки"),
    ("suffix -ин", "-e"), ("suffix -инъ", "-е"),
]
sgendings = ["-ё", "stressed -е", "-ьё"]
cases = ["nominative", "genitive", "dative", "accusative", "instrumental",
    "prepositional"]
numbers = ["singular", "plural"]
extra_cases = ["locative", "partitive", "vocative"]

def create_cat(cat, args, adj=False, verb=False):
  if verb:
    cat = "Category:Russian " + cat.replace("~", "verbs")
    text = "{{ruverbcatboiler}}"
  elif adj:
    cat = "Category:Russian " + cat.replace("~", "adjectives")
    text = "{{ruadjcatboiler|%s}}" % "|".join(args)
  else:
    cat = "Category:Russian " + cat.replace("~", "nouns")
    text = "{{runouncatboiler|%s}}" % "|".join(args)
  page = pywikibot.Page(site, cat)
  if not overwrite and page.exists():
    msg("Page %s already exists, not overwriting" % cat)
    return
  page.text = str(text)
  changelog = "Creating '%s' with text '%s'" % (cat, text)
  msg("Changelog = %s" % changelog)
  if dosave:
    blib.safe_page_save(page, changelog, errandmsg)

def create_adj_cat(cat, args):
  create_cat(cat, args, adj=True)

if donouns:
  for s in stress_patterns:
    create_cat("~ with accent pattern %s" % s, ["stress", s])
  for c in extra_cases:
    create_cat("~ with %s" % c, ["extracase", c])
  for c in cases:
    for n in numbers:
      create_cat("~ with irregular %s %s" % (c, n),
          ["irregcase", "%s %s" % (c, n)])

  # create_cat("indeclinable ~", ["stemgender"])
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
    ("hard-stem", "stem-stressed", "-ый", "-ая", "-ое", "-ые"),
    ("soft-stem", "-", "-ий", "-яя", "-ее", "-ие"),
    ("velar-stem", "stem-stressed", "-ий", "-ая", "-ое", "-ие"),
    ("sibilant-stem", "stem-stressed", "-ий", "-ая", "-ее", "-ие"),
    ("ц-stem", "stem-stressed", "-ый", "-ая", "-ее", "-ые"),
    ("vowel-stem", "-", "-ий", "-яя", "-ее", "-ие"),
    ("hard-stem", "ending-stressed", "-о́й", "-а́я", "-о́е", "-ы́е"),
    ("velar-stem", "ending-stressed", "-о́й", "-а́я", "-о́е", "-и́е"),
    ("sibilant-stem", "ending-stressed", "-о́й", "-а́я", "-о́е", "-и́е"),
    ("ц-stem", "ending-stressed", "-о́й", "-а́я", "-о́е", "-ы́е"),
    ("long", "possessive", "-ий", "-ья", "-ье", "-ьи"),
    ("mixed", "possessive", "a consonant (-ъ old style)", "-а", "-о", "-ы"),
    ("short", "possessive", "a consonant (-ъ old style)", "-а", "-о", "-ы"),
]

if doadjs:
  for stress, expl in short_adj_stress_patterns:
    create_adj_cat("~ with short accent pattern " + stress, ["shortaccent", expl])

  for stem, stress, m, f, n, p in adj_patterns:
    create_adj_cat("%s ~" % stem if stress == "-" else "%s %s ~" % (stem, stress), ["adj", m, f, n, p])

  create_adj_cat("ending-stressed ~", ["misc", "This category contains Russian adjectives where the ending is stressed. They end in {{lang|ru|-о́й}}, or in some cases {{lang|ru|-и́н}}, {{lang|ru|-о́в}}, or {{lang|ru|-ёв}}."])
  create_adj_cat("~ with short forms", ["misc", "This category contains Russian adjectives that have short forms. Short forms are used {{glossary|predicative|predicatively}} and generally only for adjectives that are qualitative, i.e. can be modified with adverbs such as [[very]], [[completely]], [[somewhat]], [[more]], etc."])
  create_adj_cat("~ with missing short forms", ["misc", "This category contains Russian adjectives that have short forms but where some of the short forms are missing. Short forms are used predicatively and generally only for adjectives that are qualitative, i.e. can be modified with adverbs such as [[very]], [[completely]], [[somewhat]], [[more]], etc."])
  create_adj_cat("~ with irregular short stem", ["misc", "This category contains Russian adjectives where the stem of the short forms is irregular compared with the stem of the remaining forms. Examples are {{m|ru|солёный||[[salty]]}} (short forms {{lang|ru|со́лон, солона́, со́лоно, солоны́/со́лоны}}); {{m|ru|ма́ленький||[[small]]}} (short forms {{lang|ru|мал, мала́, мало́, малы́}}); and {{m|ru|большо́й||[[big]]}} (short forms {{lang|ru|вели́к, велика́, велико́, велики́}}). (In the latter two cases, the short forms come from the synonymous adjectives {{m|ru|ма́лый}} and {{m|ru|вели́кий}}, respectively.)"])
  create_adj_cat("~ with reducible short stem", ["misc", "This category contains Russian adjectives where the stem of the short forms is {{glossary|reducible}}; specifically, the short masculine singular has an extra vowel inserted before the final consonant, compared with all other forms. Examples are most adjectives in {{m|ru|-кий}} and {{m|ru|-ный}}, e.g. {{m|ru|лёгкий||[[light]], [[easy]]}} with short masculine singular {{m|ru|лёгок}} and {{m|ru|де́льный||[[efficient]], [[sensible]]}} with short masculine singular {{m|ru|де́лен}}."])
  create_adj_cat("~ with Zaliznyak short form special case 1", ["misc", "This category contains Russian adjectives where the lemma form ends in {{lang|ru|-нный}} or {{lang|ru|-нний}} (with two {{lang|ru|н}}'s) but the short masculine singular ends in simply {{lang|ru|-н}} (i.e. with only one {{lang|ru|н}}). Examples are {{m|ru|самоуве́ренный||[[self-confident]]}}, with short masculine singular {{m|ru|самоуве́рен}} (short feminine singular {{m|ru|самуове́ренна}}, etc.); and {{m|ru|вы́спренний||[[grandiloquent]]}}, with short masculine singular {{m|ru|вы́спрен}} (short feminine singular {{m|ru|вы́спрення}}, etc.). Contrast [[:Category:Russian adjectives with Zaliznyak short form special case 2|special case 2]], where only one {{lang|ru|-н}} is present in '''all''' short forms."])
  create_adj_cat("~ with Zaliznyak short form special case 2", ["misc", "This category contains Russian adjectives where the lemma form ends in {{lang|ru|-нный}} (with two {{lang|ru|н}}'s) but all short forms end in only one {{lang|ru|-н}}. An example is {{m|ru|подве́рженный||[[subject]] to, [[liable]] to, [[prone]] to}}}, with short forms {{lang|ru|подве́ржен, подве́ржена, подве́ржено, подве́ржены}}. All past passive participles in {{lang|ru|-нный}} decline this way in their short forms, and most or all adjectives that decline this way are past passive participles in origin. Contrast [[:Category:Russian adjectives with Zaliznyak short form special case 1|special case 1]], where only the short masculine singular is irregular in having only a single {{lang|ru|-н}}. Note that many terms decline both ways, declining as special case 2 as a participle and as special case 1 as an adjective. An example is {{m|ru|отвлечённый}}, with short forms {{lang|ru|отвлечён, отвлечена́, отвлечено́, отвлечены́}} when functioning as the past passive participle of {{m|ru|отвле́чь||to [[distract]], to [[divert]]}} but with short forms {{lang|ru|отвлечён, отвлечённа, отвлечённо, отвлечённы}} when functioning as an adjective meaning \"abstract\". For yet other terms, there are three possibilities: special case 2 as a participle, and either special case 1 or 2 as an adjective, depending on meaning. Often the meaning difference is between experiencing a given feeling and expressing that feeling; for example, {{m|ru|влюблённый}} has short forms {{lang|ru|влюблён, влюблена́, влюблено́, влюблены́}} when functioning as the past passive participle of {{m|ru|влюби́ть||to [[cause]] to [[fall in love]]}} and also when functioning as an adjective meaning \"amorous (i.e. experiencing feelings of love, of a person)\", but has short forms {{lang|ru|влюблён, влюблённа, влюблённо, влюблённы}} when functioning as an adjective meaning \"amorous (i.e. expressing feelings of love, of a look, tone, etc.)\"."])
  create_adj_cat("proper-name ~", ["misc", "This category contains Russian proper names (normally, surnames) that decline as adjectives. These are similar to possessive adjectives and have the same endings, i.e. {{m|ru|-ин}} or {{m|ru|-ов}}/{{m|ru|-ев}}/{{m|ru|-ёв}}, but lack the neuter gender and decline slightly differently from possessive adjectives. For example, the surname {{m|ru|По́пов}} has prepositional singular {{m|ru|По́пове}}, while the possessive adjective {{m|ru|сы́нов||[[son]]'s}} has prepositional singular {{m|ru|сы́новом}}."])
  create_adj_cat("short-form-only ~", ["misc", "This category contains Russian adjectives that exist '''only''' as short forms. This means they function only as {{glossary|predicative}} adjectives. Examples are {{m|ru|рад||[[glad]]}}, {{m|ru|до́лжен||[[obligated]], [[must]], [[have to]], [[ought]]}}, and {{m|ru|гора́зд||[[skillful]], [[capable]]}}."])


  # Additional adjectival categories to create:
  #
  # Russian adjectives with irregular short masculine singular
  # Russian adjectives with irregular [etc.]
  # Russian ending-stressed adjectives
  # Russian adjectives with short forms
  # Russian adjectives with missing short forms
  # Russian adjectives with irregular short stem
  # Russian adjectives with reducible short stem
  # Russian adjectives with Zaliznyak short form special case 1
  # Russian adjectives with Zaliznyak short form special case 2
  # Russian proper-name adjectives
  # Russian short-form-only adjectives

if doverbs:
  for subclass in ["1a", "2a", "2b", "3a", "3°a", "3b", "3c",
      "4a", "4b", "4c", "5a", "5b", "5c",
      "6a", "6°a", "6b", "6°b", "6c", "6°c",
      "7a", "7b", "8a", "8b", "9a", "9b", "10a", "10c",
      "11a", "11b", "12a", "12b", "13a", "14a", "14b", "14c",
      "15a", "16a", "16b"
  ]:
    create_cat("class %s ~" % subclass, [], verb=True)
