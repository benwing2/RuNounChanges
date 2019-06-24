#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse
from collections import defaultdict

import blib
from blib import getparam, rmparam, msg, errandmsg, site, tname

skip_pages = [
  u"náhádleeh",
  u"hoditłééʼ",
  u"придти",
  "gumawa",
  "kuna",
  "hakuna",
  "pana",
  "Mussulmen",
  "hippotamus",
  "walrii",
  "fetii",
  "walri",
  "kneen",
  "calveren",
  "lambren",
  u"escrivões",
  "octopii",
  "kifunze",
  "yupo",
  "mna",
  # Gets tripped up by # {{lb|la|grammar}} [[ablative case|ablative]] of [[causing]] [[fact]]
  "ablativus rei efficientis",
  # Gets tripped up by # {{lb|la|grammar}} [[ablative case|ablative]] of [[instrument]]
  "ablativus instrumenti",
  # Gets tripped up by # {{lb|la|grammar}} [[ablative case|ablative]] of [[means]]
  "ablativus modi",
  # Gets tripped up by # {{n-g|form of {{m|mn|-жээ}} before {{m|mn|уу}}}}
  u"-ж",
]

inflection_of_templates = [
  "inflection of",
  "noun form of",
  "verb form of",
  "adj form of",
  "participle of"
]

joiner_tags = ['and', 'or', '/', ',', '&']
semicolon_tags = [';', ';<!--\n-->']

tags_for_raw_and_form_of_conversion = [
  "nominative",
  "accusative",
  "genitive",
  "dative",
  "vocative",
  "instrumental",
  "locative",
  "ablative",
  "oblique",
  "singular",
  "dual",
  "plural",
  "masculine",
  "feminine",
  "neuter",
  "present",
  "past",
  "preterite?",
  "future",
  "perfect",
  "aorist",
  "person",
  "indicative",
  "subjunctive",
  "imperative",
  "conditional",
  "definite",
  "indefinite",
  "participle",
  "infinitive",
  "comparative",
  "superlative",
  "perfective",
  "imperfective",
  "animate",
  "inanimate",
  "durative",
  "iterative",
]

raw_and_form_of_alternation_re = "(?:%s)" % "|".join("[%s%s]%s" %
  (tag[0].upper(), tag[0], tag[1:]) for tag in tags_for_raw_and_form_of_conversion
)

subtag_replacements = [
  (" +", " "),
  (" of$", ""),
  (r"\{\{glossary(?:\|[^{}|]*)?\|([^{}|]*)\}\}", r"\1"),
  ("(past|present|future) tense?", r"\1"),
  (" mood((?: form)?)$", r"\1"),
  ("(%s) form$" % raw_and_form_of_alternation_re, r"\1"),
  (" of the verb$", ""),
  (" of the (weak|strong|mixed) declension$", r" \1"),
  (" for all genders$", "all-gender"),
  ("the ", ""),
  (" case$", ""),
  (" articulation$", ""),
  (" voice", ""),
  (" '*or'* ", " and "),
  (" '*&'* ", " and "),
  (" *, *", " "),
  ("'", ""),
  ("[()]", ""),
  ("1st", "first"),
  ("2nd", "second"),
  ("3rd", "third"),
  ("4th", "fourth"),
  (r"1\. (person)?", "first-person"),
  (r"2\. (person)?", "second-person"),
  (r"3\. (person)?", "third-person"),
  (r"4\. (person)?", "fourth-person"),
  ("first person", "first-person"),
  ("second person", "second-person"),
  ("third person", "third-person"),
  ("fourth person", "fourth-person"),
  ("spatial person", "spatial-person"),
  ("first-? ", "first-person "),
  ("second-? ", "second-person "),
  ("third-? ", "third-person "),
  ("fourth-? ", "fourth-person "),
  ("2rd-person", "second-person"),
  ("3nd-person", "third-person"),
  ("3-rd person", "third-person"),
  ("past historic", "phis"),
  ("alternative form of the", "alternative"),
  ("as well as", "and"),
  (u"genitive-accusative", "genitive and accusative"),
  (u"dative-accusative", "dative and accusative"),
  (u"dative-locative", "dative and locative"),
  ("present active particle", "present active participle"),
  ("plural noun", "plural"),
  ("conditional mood", "conditional"),
  ("feminine-singular", "feminine singular"),
  ("past participle common gender", "common past participle"),
  ("dative of the negative form", "negative dative"),
  ("feminine of past participle", "feminine singular past participle"),
  ("plural feminine of past participle", "feminine plural past participle"),
  ("plural; imperative", "plural imperative"),
]

tag_replacements = {
  "first person": "1",
  "second person": "2",
  "third person": "3",
  "per": "perf",
  "pas": "pass",
  "pst": "past",
  "personal and animate masculine": ["pers//an", "m"],
  "(impersonal)": "impers",
  "positive": "posd",
  "(single possession)": "spos",
  "(multiple possessions)": "mpos",
  "negative conjugation": ["neg", "form"],
  "archaiac": "archaic",
  "honorofic": "honorific",
  "innesive": "inessive",
  "contraced": "contracted",
  "persent": "present",
  "preterit": "preterite",
  "pretertite": "preterite",
  "particple": "participle",
  "singularform": "singular",
  "singularimperative": "s|imp",
  "passiv": "passive",
  "indiactive": "indicative",
  "femalinine": "feminine",
  "female": "feminine",
  "femal": "feminine",
  "indefinitive": "indefinite",
  "indfinite": "indefinite",
  "defnite": "definite",
  "imperatve": "imperative",
  "plurak": "plural",
  "sing.": "s",
  "pl.": "p",
  "m;": ["m", ";"],
}

cases = {
  "nom": "nom",
  "nominative": "nom",
  "acc": "acc",
  "accc": "acc",
  "accusative": "acc",
  "accusative,": "acc",
  "voc": "voc",
  "vocative": "voc",
  "gen": "gen",
  "genitive": "gen",
  "dat": "dat",
  "dative": "dat",
  "ins": "ins",
  "instrumental": "ins",
  "abl": "abl",
  "ablative": "abl",
  "loc": "loc",
  "locative": "loc",
  "obl": "obl",
  "oblique": "obl",
  "par": "par",
  "partitive": "par",
  "pre": "pre",
  "prep": "pre",
  "prepositional": "pre",
  "ill": "ill",
  "illative": "ill",
}

tenses_aspects = {
  "pres": "pres",
  "fut": "fut",
  "futr": "fut",
  "impf": "impf",
  "imperf": "impf",
  "pret": "pret",
  "perf": "perf",
  "perfect": "perf",
  "plup": "plup",
  "aor": "aor",
}

aspects = {
  "pfv": "pfv",
  "perfective": "pfv",
  "impfv": "impfv",
  "imperfective": "impfv",
}

definitenesses = {
  "def": "def",
  "definite": "def",
  "indef": "indef",
  "indefinite": "indef",
}

animacies = {
  "an": "an",
  "animate": "an",
  "in": "in",
  "inan": "in",
  "inanimate": "in",
  "pr": "pr",
  "pers": "pr",
  "personal": "pr",
}

genders = {
  "m": "m",
  "masculine": "m",
  "f": "f",
  "feminine": "f",
  "n": "n",
  "neuter": "n",
  "c": "c",
  "common": "c",
  "nv": "nv",
  "nonvirile": "nv",
}

persons = {
  "1": "1",
  "first-person": "1",
  "2": "2",
  "second-person": "2",
  "3": "3",
  "third-person": "3",
}

# We don't combine numbers across |and| because there are several cases like
# def|s|and|p and 1|s|,|s|possession that shouldn't be combined. But we
# do combine across |;|, because it is safe.

numbers = {
  "s": "s",
  "sg": "s",
  "singular": "s",
  "d": "d",
  "du": "d",
  "dual": "d",
  "p": "p",
  "pl": "p",
  "plural": "p",
}

moods = {
  "ind": "ind",
  "indc": "ind",
  "indic": "ind",
  "indicative": "ind",
  "sub": "sub",
  "subj": "sub",
  "subjunctive": "sub",
  "imp": "imp",
  "impr": "imp",
  "impv": "imp",
  "imperative": "imp",
  "opt": "opt",
  "opta": "opt",
  "optative": "opt",
  "juss": "juss",
  "jussive": "juss",
}

strengths = {
  "str": "str",
  "strong": "str",
  "wk": "wk",
  "weak": "wk",
  "weak,": "wk",
  "mix": "mix",
  "mixed": "mix",
}

voices = {
  "act": "act",
  "actv": "act",
  "active": "act",
  "mid": "mid",
  "midl": "mid",
  "middle": "mid",
  "pass": "pass",
  "pasv": "pass",
  "passive": "pass",
  "mp": "mp",
  "mpass": "mp",
  "mpasv": "mp",
  "mpsv": "mp",
  "mediopassive": "mp",
  "refl": "refl",
  "reflexive": "refl",
}

degrees = {
  "comparative": "comd",
  "comd": "comd",
  "superlative": "supd",
  "supd": "supd",
}

multitag_replacements = [
  ("pr|inf", "pinf"),
  ("strong,|weak,|and|mixed", "str//wk//mix"),
  ("n|and|acc|and|voc", "n|nom//acc//voc"),
  # Lower Sorbian
  ("gen|and|an|acc|and|loc", "gen//an:acc//loc"),
  ("gen|and|an|acc", "gen//an:acc"),
  # Manx
  ("p|/|formal", "p//formal"),
  ("formal|/|p", "p//formal"),
  # Pali
  ("pres|and|impr|mid", "pres//imp|mid"),
  ("pres|and|imp|mid", "pres//imp|mid"),
  ("pres|and|imp|act", "pres//imp|act"),
  ("voc|s|and|p", "voc|s//p"),
  ("nom|s|and|p", "nom|s//p"),
  ("nom|s|and|pl", "nom|s//p"),
  # Old Irish
  ("past|subj|and|cond", "past:sub//cond"),
  ("gen|s|and|gen|d|and|gen|p", "gen|s//d//p"),
  ("absolute|and|relative", "abs//rel"),
  ("impf|indc|and|past|subj", "impf:ind//past:sub"),
  ("pret|and|past|subj", "pret//past:sub"),
  # Irish
  ("pres|indc|and|pres|subj|and|impr|autonomous",
    "pres:ind//pres:sub//imp|autonomous"),
  ("pres|indc|and|impr|and|pres|subj|autonomous",
    "pres:ind//pres:sub//imp|autonomous"),
  ("pres|indc|autonomous|and|pres|subj|autonomous|and|impr|autonomous",
    "pres:ind//pres:sub//imp|autonomous"),
  ("pres|indc|and|pres|subj|and|impr", "pres:ind//pres:sub//imp"),
  ("pres|indc|and|pres|subj", "pres|ind//sub"),
  ("pres|actv|indc|and|pres|actv|subj", "pres|act|ind//sub"),
  ("3|p|pres|indc|dependent|and|pres|subj",
    "3|p|pres|indc|dependent|;|3|p|pres|subj"),
  ("nom|and|voc|and|dat|and|strong|gen", "nom//voc//dat//str:gen"),
  ("nom|and|voc|and|strong|gen|and|dat", "nom//voc//dat//str:gen"),
  ("nom|and|voc|and|strong|gen|p|and|dat|p",
    "nom//voc//dat//str:gen|p"),
  ("nom|and|voc|and|plural|and|strong|gen|p",
    "nom//voc//dat//str:gen|p"),
  ("nom|and|voc|and|dat|p|and|strong|gen|p",
    "nom//voc//dat//str:gen|p"),
  ("nonrelative|and|relative", "nonrelative//relative"),
  ("dat|s|and|nom|p", "dat|s|;|nom|p"),
  ("past|and|cond", "past//cond"),
  ("impr|and|pres|subj", "imp//pres:sub"),
  ("pres|indc|and|imperative", "pres:ind//imp"),
  ("pres|and|impr", "pres//imp"),
  ("gen|s|and|all cases|p", "gen|s|;|all-case|p"),
  ("gen|s|and|nom|and|dat|p", "gen|s|;|nom//dat|p"),
  ("nom|and|strong|gen|p", "nom|p|;|str|gen|p"),
  # Welsh
  ("impf|indc|/|impf|subj|/|cond|and|impr", "impf:ind//impf:sub//cond//impr"),
  ("impf|indc|/|impf|subj|/|cond", "impf:ind//impf:sub//cond"),
  ("impf|indc|/|impr|subj|/|cond", "impf:ind//impf:sub//cond"),
  ("impf|indc|/|cond|and|impf|subj", "impf:ind//impf:sub//cond"),
  ("impf|indc|and|subj|/|cond", "impf:ind//impf:sub//cond"),
  ("impf|indc|/|cond", "impf:ind//cond"),
  ("impf|indc|/|subj|and|cond", "impf:ind//impf:sub//cond"),
  ("imperf|/|cond|and|impr", "impf//cond//imp"),
  ("impf|/|cond", "impf//cond"),
  ("imperf|/|cond", "impf//cond"),
  ("pres|indc|/|fut|and|impr", "pres:ind//fut//imp"),
  ("pres|indc|/|futr|and|impr", "pres:ind//fut//imp"),
  ("pres|indc|/|fut", "pres:ind//fut"),
  ("pres|indc|/|futr", "pres:ind//fut"),
  ("pres|indc|/|future", "pres:ind//fut"),
  ("pres|subj|/|futr", "pres:sub//fut"),
  ("pres|habitual|/|futr", "pres:hab//fut"),
  ("pres|indc|and|futr|/|pres|habitual", "pres:ind//fut//pres:hab"),
  ("futr|/|pres|habitual|and|impr", "fut//pres:hab//imp"),
  # Italian
  ("1|s|2|s|and|3|s", "1//2//3|s"),
  ("1|s|and|2|s|and|3|s", "1//2//3|s"),
  ("1|s|,|2|s|,|and|3|s", "1//2//3|s"),
  ("2|s|and|3|s", "2//3|s"),
  ("first-person|singular|second-person|singular|and|third-person|singular", "1//2//3|s"),
  ("1|s|and|2|s", "1//2|s"),
  # Next two for Middle Dutch and Limburgish?
  ("s|and|p|imp", "s//p|imp"),
  ("s|and|p|impr", "s//p|imp"),
  ("gen|s|and|p", "gen|s//p"),
  ("1|s|and|3|p", "1:s//3:p"),
  ("3|s|and|2|p", "3:s//2:p"),
  ("acc|s|and|ins|s", "acc//ins|s"),
  ("dat|s|and|loc|s", "dat//loc|s"),
  ("voc|s|and|gen|s", "voc//gen|s"),
  ("acc|s|and|nom|p", "acc:s//nom:p"),
  ("gen|s|and|nom|p", "gen:s//nom:p"),
  # The following for Ancient Greek
  ("gen|s|and|acc|p", "gen:s//acc:p"),
  ("first|s", "1|s"),
  ("second|s", "2|s"),
  ("first|p", "1|p"),
  ("second|p", "2|p"),
  ("d|and|p", "d//p"),
  ("s|and|d|and|p", "s//d//p"),
  ("s|and|d", "s//d"),
  ("Epic|and|Attic", ["{{lb|grc|Epic}}//{{lb|grc|Attic}}"]),
  # Danish
  ("def|s|and|p", "def|s|;|p"),
  ("def|and|p", "def|s|;|p"),
  ("p|and|def", "def|s|;|p"),
  ("def|form|and|p", "def|s|;|p"),
  ("past|part|def|and|p", "def|s|past|part|;|p|past|part"),
  ("supd|def|and|p", "def|s|supd|;|p|supd"),
  ("p|and|def|s|past|part", "def|s|past|part|;|p|past|part"),
  # Czech? Polish?
  ("m|an|acc|p|and|m|in|acc|p", "m|an//in|acc|p"),
  ("m|an|and|in|acc|p", "m|an//in|acc|p"),
  ("pr|and|an|m", "pr//an|m"),
  # Polish
  ("m|in|and|f|and|n", "m:in//f//n"),
  # Italian?
  ("3|s|pres|indc|and|2|s|impr",
    "3|s|pres|ind|;|2|s|imp"),
  # Ancient Greek
  ("1|s|futr|actv|indc|and|aor|actv|subj", "1|s|fut|act|ind|;|1|s|aor|act|sub"),
  ("1|s|fut|indc|and|aor|subj|actv", "1|s|fut|act|ind|;|1|s|aor|act|sub"),
  ("1|actv|and|3|mp|s|pres|indc|contracted", "1|s|pres|act|ind|contracted|;|3|s|pres|mpass|ind|contracted"),
  ("3|actv|and|2|mid|s|fut|indc", "3|s|fut|act|ind|;|2|s|fut|mid|ind"),
  ("3|actv|and|2|mid|s|aor|subj", "3|s|aor|act|sub|;|2|s|aor|mid|sub"),
  ("3|actv|and|2|mp|s|pres|indc", "3|s|pres|act|ind|;|2|s|pres|mpass|ind"),
  ("3|indc|and|2|imp|s|perf|actv", "3|s|perf|act|ind|;|2|s|perf|act|imp"),
  ("2|d|perf|imp|and|plup|indc|actv", "2|d|perf|act|imp|;|2|d|plup|act|ind"),
  ("2|p|perf|imp|and|plup|indc|actv", "2|p|perf|act|imp|;|2|p|plup|act|ind"),
  ("fut|contracted|and|aor|3|d|actv|opt", "3|d|fut|act|opt|contracted|;|3|d|aor|act|opt"),
  ("fut|contracted|and|aor|1|p|mid|opt", "1|p|fut|mid|opt|contracted|;|1|p|aor|mid|opt"),
  # Middle English
  ("dat|s|and|gen|p", "dat|s|;|gen|p"),
  # Navajo
  ("s|and|duoplural", "s//duoplural"),
  # misc
  ("sim|past|and|past|part", "sim|past|;|past|part"),
  ("past|and|past|part", "past|;|past|part"),
]

new_multitag_replacements = []
for repl in multitag_replacements:
  if len(repl) == 2:
    fro, to = repl
    exact = "|;|" in to
  else:
    fro, to, exact = repl
    assert exact == "exact"
  fro = fro if type(fro) is list else fro.split("|")
  to = to if type(to) is list else to.split("|")
  new_multitag_replacements.append((fro, to, exact))
multitag_replacements = new_multitag_replacements

multipart_list_tag_to_parts = {
  "1s": ["1", "s"],
  "2s": ["2", "s"],
  "3s": ["3", "s"],
  "1d": ["1", "d"],
  "2d": ["2", "d"],
  "3d": ["3", "d"],
  "1p": ["1", "p"],
  "2p": ["2", "p"],
  "3p": ["3", "p"],
  "mf": ["m//f"],
  "mn": ["m//n"],
  "fn": ["f//n"],
  "mfn": ["m//f//n"],
}

# Map from names of dimensions to map from tag to canonical form,
# for combining across |and|
dimensions_to_tags = {
  "case": cases,
  "tense/aspect": tenses_aspects,
  "aspect": aspects,
  "mood": moods,
  "person": persons,
  "gender": genders,
  "strength": strengths,
  "degree": degrees,
}

# Map from tag to dimension it's in, for combining across |and|
combinable_tags_by_dimension = {
  tag: dim for dim, tagdict in dimensions_to_tags.iteritems() for tag in tagdict
}

# Map from tag to its canonical form, for combining across |and|
tag_to_canonical_form = {
  tag: canontag for dim, tagdict in dimensions_to_tags.iteritems() for tag, canontag in tagdict.iteritems()
}

# Map from names of dimensions to map from tag to canonical form,
# for combining across |;|
dimensions_to_tags_across_semicolon = dict(dimensions_to_tags)
dimensions_to_tags_across_semicolon["number"] = numbers
dimensions_to_tags_across_semicolon["definiteness"] = definitenesses
dimensions_to_tags_across_semicolon["animacy"] = animacies
dimensions_to_tags_across_semicolon["voice"] = voices

# Map from tag to dimension it's in, for combining across |;|
combinable_tags_by_dimension_across_semicolon = {
  tag: dim for dim, tagdict in dimensions_to_tags_across_semicolon.iteritems() for tag in tagdict
}

# Map from tag to its canonical form, for combining across |;|
tag_to_canonical_form_across_semicolon = {
  tag: canontag for dim, tagdict in dimensions_to_tags_across_semicolon.iteritems() for tag, canontag in tagdict.iteritems()
}

tag_to_canonical_form_table = None
combinable_tags_by_dimension_table = None

order_of_dimensions = [
  "person", "clusivity", "class", "state", "animacy", "case", "gender",
  "number", "tense-aspect", "voice-valence", "mood", "comparison",
  "non-finite",
  # Unclear:
  #"attitude",
  #"register",
  #"deixis",
  #"sound change",
  #"misc grammar"
]

indexed_order_of_dimensions = {y:x for x, y in enumerate(order_of_dimensions)}

additional_good_tags = {
  "&", # occurs in some places in place of "and"
  "alternative",
  "transgressive",
  "all-gender",
  "duoplural",
  "realis",
  "irrealis",
  "fourth-person", # Navajo
  "spatial-person", # Navajo
  "usitative", # Navajo
  "si-perfective", # Navajo
  "durative",
  "modal", # Mongolian
  "postpositional", # Georgian
  "augmented", # lang=nci (?)
  "determinate", # Maltese
  "admirative", # Albanian
}

tags_with_spaces = defaultdict(int)

bad_tags = defaultdict(int)

bad_tags_during_split_canonicalization = defaultdict(int)

good_tags = set() | additional_good_tags

num_total_templates = 0
num_templates_with_bad_tags = 0

matching_textfile_lines = set()

def remove_comment_continuations(text):
  return text.replace("<!--\n-->", "").strip()

# Split tags into tag sets.
def split_tags_into_tag_sets(tags):
  tag_set_group = []
  cur_tag_set = []
  for tag in tags:
    if tag in semicolon_tags:
      if cur_tag_set:
        tag_set_group.append(cur_tag_set)
      cur_tag_set = []
    else:
      cur_tag_set.append(tag)
  if cur_tag_set:
    tag_set_group.append(cur_tag_set)
  return tag_set_group

def combine_tag_set_group(group):
  result = []
  for tag_set in group:
    if result:
      result.append(";")
    result.extend(tag_set)
  return result

form_of_dimensions_to_tags = {}
# Map from tag to dimension it's in, derived from form-of data
form_of_combinable_tags_by_dimension = {}
# Map from tag to its canonical form, derived from form-of data
form_of_tag_to_canonical_form = {}

def set_form_of_tables():
  global form_of_combinable_tags_by_dimension
  global form_of_tag_to_canonical_form
  form_of_combinable_tags_by_dimension = {
    tag: dim for dim, tagdict in form_of_dimensions_to_tags.iteritems() for tag in tagdict
  }
  form_of_tag_to_canonical_form = {
    tag: canontag for dim, tagdict in form_of_dimensions_to_tags.iteritems() for tag, canontag in tagdict.iteritems()
  }
  #for tag, dim in form_of_combinable_tags_by_dimension.iteritems():
  #  print "form_of_combinable_tags_by_dimension[%s] = %s" % (tag, dim)
  #for tag, canontag in form_of_tag_to_canonical_form.iteritems():
  #  print "form_of_tag_to_canonical_form[%s] = %s" % (tag, canontag)

def parse_form_of_data(lines):
  curtag = None
  tag_type = None
  shortcuts = None
  for line in lines:
    line = line.strip()
    m = re.search('^tags\["(.*?)"\] = \{$', line)
    if m:
      curtag = m.group(1)
      good_tags.add(curtag)
    if line == "}":
      if curtag and tag_type:
        aliases = (shortcuts or []) + [curtag]
        if tag_type not in form_of_dimensions_to_tags:
          form_of_dimensions_to_tags[tag_type] = {}
        canon_alias = aliases[0]
        for alias in aliases:
          form_of_dimensions_to_tags[tag_type][alias] = canon_alias
      curtag = None
      tag_type = None
      shortcuts = None
    m = re.search('^\s*tag_type = "(.*?)",$', line)
    if m:
      tag_type = m.group(1)
    m = re.search('^\s*shortcuts = \{(.*?)\},$', line)
    if m:
      shortcuts = [x.strip().strip('"') for x in m.group(1).split(',')]
      for shortcut in shortcuts:
        good_tags.add(shortcut)
    m = re.search('^\s*shortcuts\["(.*?)"\] =', line)
    if m:
      good_tags.add(m.group(1))


####### Statistics #######

# For each tag set with multipart tags, count how many multipart tags
# there are in the tag set
multipart_tag_stats_by_num_axes = defaultdict(int)
# For each tag set, create a tuple of the dimensions that the multipart
# tags occur in, e.g. ("person", "number") means there is a multipart tag
# along the "person" dimension followed by a multipart tag along the
# "number" dimension.
detailed_multipart_tag_stats = defaultdict(int)
# Same as previous, but use a set instead of a tuple.
detailed_multipart_tag_stats_as_set = defaultdict(int)
num_tag_sets = 0

def record_stats_on_tag_set(tag_set):
  global args
  if args.use_form_of_groups:
    combinable_tags_by_dimension_table = form_of_combinable_tags_by_dimension
  else:
    combinable_tags_by_dimension_table = combinable_tags_by_dimension_across_semicolon

  global num_tag_sets
  num_tag_sets += 1
  multipart_dims = []
  for tag in tag_set:
    if "//" in tag:
      indiv_tags = tag.split("//")
      multipart_dims.append(combinable_tags_by_dimension_table.get(indiv_tags[0], "unknown"))
  multipart_tag_stats_by_num_axes[len(multipart_dims)] += 1
  detailed_multipart_tag_stats[tuple(multipart_dims)] += 1
  detailed_multipart_tag_stats_as_set[frozenset(multipart_dims)] += 1

def output_stats_on_tag_set():
  msg("Num tag sets seen = %s" % num_tag_sets)
  for key, val in sorted(multipart_tag_stats_by_num_axes.iteritems(),
      key=lambda x:-x[1]):
    msg("Num tag sets with %s multipart tags = %6s (%.2f%%)" %
        (key, val, val * 100.0 / num_tag_sets))
  msg("Tag sets by ordered dimensions of multipart tags:")
  for key, val in sorted(detailed_multipart_tag_stats.iteritems(),
      key=lambda x:-x[1]):
    msg("%-40s = %6s (%.2f%%)" %
        (", ".join(key), val, val * 100.0 / num_tag_sets))
  msg("Tag sets by unordered dimensions of multipart tags:")
  for key, val in sorted(detailed_multipart_tag_stats_as_set.iteritems(),
      key=lambda x:-x[1]):
    msg("%-40s = %6s (%.2f%%)" %
        (", ".join(sorted(list(key))), val, val * 100.0 / num_tag_sets))

# Sort tags, but leave unknown tags and tags of certain categories where
# they are (which means we can't move a tag across such a tag).
def sort_tags(tags):
  global args
  if args.use_form_of_groups:
    combinable_tags_by_dimension_table = form_of_combinable_tags_by_dimension
  else:
    combinable_tags_by_dimension_table = combinable_tags_by_dimension_across_semicolon
  # split into groups of sortable tags.
  tag_groups = []
  tag_group = []
  for tag in tags:
    indiv_tags = tag.split("//")
    dim = combinable_tags_by_dimension_table.get(indiv_tags[0], "unknown")
    if dim in order_of_dimensions:
      tag_group.append((tag, dim))
    else:
      tag_groups.append((tag_group, [tag]))
      tag_group = []
  if tag_group:
    tag_groups.append((tag_group, []))
  sorted_tags = []
  # sort within each group of sortable tags.
  for tag_group, unsortable in tag_groups:
    if len(tag_group) > 1:
      tag_group = sorted(tag_group,
        key=lambda x: indexed_order_of_dimensions[x[1]])
    for tag, dim in tag_group:
      sorted_tags.append(tag)
    sorted_tags.extend(unsortable)
  return sorted_tags

def canonicalize_tag_1(tag, shorten, pagemsg, add_to_bad_tags_split_canon=False):
  global args

  if re.search(r"([Tt]he|[A]n) \[*[Aa]ct\]*\b", tag):
    pagemsg("WARNING: Saw 'the/an act of', not a valid tag, rejecting: %s" % tag)
    return None

  def maybe_shorten(tag):
    if shorten:
      return tag_to_canonical_form_table.get(tag, tag)
    else:
      return tag
  # Canonicalize a tag into either a single tag or a sequence of tags.
  # Return value is None if the tag isn't recognized, else a string or
  # a list of strings.
  if tag in good_tags:
    return maybe_shorten(tag)
  if tag in tag_replacements:
    return maybe_shorten(tag_replacements[tag])
  # Try removing links; [[FOO]] -> FOO, [[FOO|BAR]] -> BAR
  newtag = re.sub(r'\[\[(?:[^\[\]\|]*?\|)?([^\[\]\|]*?)\]\]', r'\1', tag)
  if newtag != tag:
    repl = canonicalize_tag(newtag, shorten, pagemsg)
    if repl:
      return repl
  # Try lowercasing
  lowertag = tag.lower()
  if lowertag != tag:
    repl = canonicalize_tag(lowertag, shorten, pagemsg)
    if repl:
      return repl
  if " " in tag:
    newtag = tag
    for fro, to in subtag_replacements:
      newtag = re.sub(fro, to, newtag)
    split_tags = newtag.split(" ")
    canon_split_tags = [canonicalize_tag(t, True, pagemsg, add_to_bad_tags_split_canon=True) for t in split_tags]
    if args.debug:
      pagemsg("canonicalize_tag_1: Output after splitting = %s" % canon_split_tags)
    if None not in canon_split_tags:
      return canon_split_tags
  if "/" in tag:
    if "//" in tag:
      split_tags = tag.split("//")
    else:
      split_tags = tag.split("/")
    canon_split_tags = [canonicalize_tag(t, shorten, pagemsg) for t in split_tags]
    if all(isinstance(t, basestring) for t in canon_split_tags):
      return "//".join(canon_split_tags)
    else:
      pagemsg("WARNING: Found slash in tag and wasn't able to canonicalize completely: %s" % tag)
  if ":" in tag and "/" not in tag:
    split_tags = tag.split(":")
    canon_split_tags = [canonicalize_tag(t, shorten, pagemsg) for t in split_tags]
    if all(isinstance(t, basestring) for t in canon_split_tags):
      return ":".join(canon_split_tags)
    else:
      pagemsg("WARNING: Found colon in tag and wasn't able to canonicalize completely: %s" % tag)
  if add_to_bad_tags_split_canon:
    bad_tags_during_split_canonicalization[tag] += 1
  return None

def canonicalize_tag(tag, shorten, pagemsg, add_to_bad_tags_split_canon=False):
  # pagemsg("canonicalize_tag(%s, %s): Called" % (tag, shorten))
  retval = canonicalize_tag_1(tag, shorten, pagemsg, add_to_bad_tags_split_canon)
  # pagemsg("canonicalize_tag(%s, %s): Returned %s" % (tag, shorten, retval))
  return retval

def process_text_on_page(pagetitle, index, text):
  global args

  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")
  notes = []
  # List of (LANG, LEMMA, TAG) triplets for tags that come from
  # {{form of}}. We shorten those to their canonical abbreviated
  # form but don't do the same to tags originally in {{inflection of}}.
  shortenable_tags = []

  if blib.page_should_be_ignored(pagetitle):
    pagemsg("WARNING: Page should be ignored")
    return None, None

  global tag_to_canonical_form_table
  global combinable_tags_by_dimension_table

  if args.use_form_of_groups:
    tag_to_canonical_form_table = form_of_tag_to_canonical_form
    combinable_tags_by_dimension_table = form_of_combinable_tags_by_dimension
  else:
    tag_to_canonical_form_table = tag_to_canonical_form_across_semicolon
    combinable_tags_by_dimension_table = combinable_tags_by_dimension_across_semicolon

  def convert_raw_section(text, section_langcode, infer_langcode):
    def parse_gloss_from_posttext(posttext):
      gloss = ""
      mmm = re.search(ur" *\([‘'\"]([^‘'\"(){}]*)[’'\"]\)\.?(.*?)$",
          posttext)
      if mmm:
        gloss, posttext = mmm.groups()
        gloss = "|t=%s" % gloss
      return gloss, posttext

    def replace_raw(m, only_canonicalize):
      langcode = section_langcode
      newtext = None
      pound_sign, pretext, tags, posttext = m.groups()
      pretext = pound_sign + pretext
      tags = re.sub(" *[Oo]f$", "", tags)
      if only_canonicalize and canonicalize_tag(tags, True, pagemsg) is None:
        pagemsg("WARNING: Unable to canonicalize tags \"%s\": %s" % (tags, m.group(0)))
        return m.group(0)

      # Check for template link
      mm = re.search(r"^'* *(\{\{(?:m|l|l-self)\|[^{}]*?\}\})'*\.?(.*?)$", posttext)
      if mm:
        link_text, postposttext = mm.groups()
        linkt = blib.parse_text(link_text).filter_templates()[0]
        link_langcode = getparam(linkt, "1")
        lemma = getparam(linkt, "2")
        if link_langcode != langcode:
          if not infer_langcode:
            pagemsg("WARNING: Lang code %s in link doesn't match section lang code %s: %s" % (
              link_langcode, langcode, m.group(0)))
            return m.group(0)
          else:
            langcode = link_langcode
        gloss, postposttext = parse_gloss_from_posttext(postposttext)
        alttext = ""
        this_gloss = ""
        tr = ""
        ts = ""
        extraparams = ""
        for param in linkt.params:
          pname = unicode(param.name).strip()
          pval = unicode(param.value).strip()
          if pname in ["1", "2"]:
            continue
          elif pname in ["3", "alt"]:
            alttext = pval
          elif pname in ["4", "t", "gloss"]:
            this_gloss = "|t=%s" % pval
          elif pname == "tr":
            tr = "|tr=%s" % pval
          elif pname == "ts":
            ts = "|ts=%s" % pval
          elif pname in ["sc", "g", "g2", "g3", "g4", "g5", "pos", "id", "lit"]:
            extraparams += "|%s=%s" % (pname, pval)
          else:
            pagemsg("WARNING: Unrecognized param %s=%s in link template %s: %s" % (
              pname, pval, unicode(linkt), m.group(0)))
            return m.group(0)
        if this_gloss and gloss:
          pagemsg("WARNING: Both gloss in link and after link: %s" % m.group(0))
          return m.group(0)
        lemma = re.sub("#.*$", "", lemma)
        alttext = re.sub(r"^('+)(.*?)\1$", r"\2", alttext)
        newtext = "%s{{inflection of|%s|%s%s%s|%s|%s%s%s}}%s" % (
            pretext, langcode, lemma, tr, ts, alttext, tags, this_gloss or gloss,
            extraparams, postposttext)
        shortenable_tags.append((langcode, lemma, tags))

      # Check for raw link
      mm = re.search(r"^'* *\[\[([^\[\]]*?)\]\]'*\.?(.*?)$", posttext)
      if mm:
        lemma, postposttext = mm.groups()
        gloss, postposttext = parse_gloss_from_posttext(postposttext)
        lemma_parts = lemma.split("|")
        if len(lemma_parts) == 1:
          newtext = "%s{{inflection of|%s|%s||%s%s}}%s" % (
            pretext, langcode, lemma, tags, gloss, postposttext)
          shortenable_tags.append((langcode, lemma, tags))
        elif len(lemma_parts) == 2:
          link, alttext = lemma_parts
          link = re.sub("#.*$", "", link)
          alttext = re.sub(r"^('+)(.*?)\1$", r"\2", alttext)
          if link and link != alttext:
            newtext = "%s{{inflection of|%s|%s|%s|%s%s}}%s" % (
              pretext, langcode, link, alttext, tags, gloss, postposttext)
            shortenable_tags.append((langcode, link, tags))
          else:
            # Probably a link to the same page
            newtext = "%s{{inflection of|%s|%s||%s%s}}%s" % (
              pretext, langcode, alttext, tags, gloss, postposttext)
            shortenable_tags.append((langcode, alttext, tags))
        else:
          pagemsg("WARNING: Too many arguments to raw link: %s" % m.group(0))
          return m.group(0)

      # Check for just bold, italic or bold-italic text
      mm = re.search(r"^'''* *([^'{}\[\]]*?) *'''*\.?(.*?)$", posttext)
      if mm:
        lemma, postposttext = mm.groups()
        gloss, postposttext = parse_gloss_from_posttext(postposttext)
        newtext = "%s{{inflection of|%s|%s||%s%s}}%s" % (
          pretext, langcode, lemma, tags, gloss, postposttext)
        shortenable_tags.append((langcode, lemma, tags))

      # Check for just a single word
      mm = re.search(r"^([a-zA-Z]+)\.?($|:.*?$)$", posttext)
      if mm:
        lemma, postposttext = mm.groups()
        gloss, postposttext = parse_gloss_from_posttext(postposttext)
        newtext = "%s{{inflection of|%s|%s||%s%s}}%s" % (
          pretext, langcode, lemma, tags, gloss, postposttext)
        shortenable_tags.append((langcode, lemma, tags))
      if newtext is None:
        pagemsg("WARNING: Unable to parse raw inflection-of defn: %s" % m.group(0))
        return m.group(0)
      if matching_textfile_lines and m.group(0) not in matching_textfile_lines:
        pagemsg("WARNING: Modifying line not in --matching-textfile: %s" %
            m.group(0))
      pagemsg("Replacing <%s> with <%s>" % (m.group(0), newtext))
      notes.append("replaced raw inflection-of defn with {{inflection of|%s}}" % langcode)
      return newtext

    def replace_raw_any(m):
      return replace_raw(m, only_canonicalize=False)

    def replace_raw_only_canonicalize(m):
      return replace_raw(m, only_canonicalize=True)

    newtext = text
    # Try both with and without a surrounding {{non-gloss definition|...}}
    # or {{n-g|...}}, to handle cases like:
    # # {{non-gloss definition|accusative form of {{m|nov|tu}}}}
    for with_non_gloss_defn in [False, True]:
      if with_non_gloss_defn:
        non_gloss_pretext = r"\{\{(?:non-gloss definition|n-g)\|"
        non_gloss_posttext = r"\}\}"
      else:
        non_gloss_pretext = ""
        non_gloss_posttext = ""
      # Handle defn lines with the inflection text italicized.
      # NOTE: The expression (?![#:*]) below is a negative lookahead assertion.
      # We want to allow definition lines with a # or ## not followed by a
      # space, but ignore definition lines like #:, #*, #*: or ##*:.
      # The whole expression (#+(?: +|(?![#:*]))) means "one or more # signs,
      # followed either by one or more spaces or not followed by #, * or :".
      # We need to include the # sign in the negative lookahead or we will
      # allow lines beginning with ##*:.
      newtext = re.sub(r"^(#+(?: +|(?![#:*])))%s(.*?)'' *([^'\n]*%s[^'\n]*[Oo]f)'' (.*?)%s$" % (
        non_gloss_pretext, raw_and_form_of_alternation_re, non_gloss_posttext),
        replace_raw_any, newtext, 0, re.M)
      # Handle defn lines with the inflection text not italicized, possibly
      # with a preceding label. We restrict the lemma to either be a single
      # alphabetic word or some text preceded by left bracket, left brace or
      # single quote, to avoid parsing arbitrary definitions with "of" in them.
      newtext = re.sub(r"^(#+(?: +|(?![#:*])))%s((?:\{\{.*?\}\} *)?\(?)(.* [Oo]f) ([[{'].*?|[a-zA-Z]+\.?)%s$" % (
        non_gloss_pretext, non_gloss_posttext), replace_raw_only_canonicalize,
        newtext, 0, re.M)
      # As previously, but allowing a preceding raw link, to handle case like:
      # # [[that]]; ''genitive singular masculine form of [[tas]]''
      # # [[shone]], singular past tense form of ''[[skína]]'' (to shine)
      newtext = re.sub(r"^(#+(?: +|(?![#:*])))%s(\[\[.*?\]\][:;,] *\(?)(.* [Oo]f) ([[{'].*?|[a-zA-Z]+\.?)%s$" % (
        non_gloss_pretext, non_gloss_posttext), replace_raw_only_canonicalize,
        newtext, 0, re.M)
    return newtext

  def convert_raw(text):
    if args.langcode:
      return convert_raw_section(text, args.langcode, infer_langcode=True)
    sections = re.split("(^==[^=\n]+==\n)", text, 0, re.M)
    for j in xrange(2, len(sections), 2):
      m = re.search("^==(.*)==\n$", sections[j - 1])
      assert m
      langname = m.group(1)
      if langname not in blib.languages_byCanonicalName:
        pagemsg("WARNING: Unrecognized language %s" % langname)
      else:
        langcode = blib.languages_byCanonicalName[langname]["code"]
        newsection = convert_raw_section(sections[j], langcode, infer_langcode=False)
        sections[j] = newsection
    return "".join(sections)

  if args.convert_raw:
    if pagetitle in skip_pages:
      pagemsg("Page in skip_pages, not applying --convert-raw")
    else:
      text = convert_raw(text)

  def convert_form_of(text):
    parsed = blib.parse_text(text)
    for t in parsed.filter_templates():
      origt = unicode(t)
      tn = tname(t)
      if tn == "form of":
        lang = getparam(t, "lang")
        if lang:
          lang_in_lang = True
          tags = getparam(t, "1")
          lemma = getparam(t, "2")
          alt = getparam(t, "3")
          gloss = getparam(t, "4")
        else:
          lang_in_lang = False
          lang = getparam(t, "1")
          tags = getparam(t, "2")
          lemma = getparam(t, "3")
          alt = getparam(t, "4")
          gloss = getparam(t, "5")
        tr = getparam(t, "tr")
        sc = getparam(t, "sc")
        id = getparam(t, "id")
        if not gloss:
          gloss = getparam(t, "t") or getparam(t, "gloss")
        if re.search(raw_and_form_of_alternation_re, tags):
          for param in t.params:
            pname = unicode(param.name).strip()
            pval = unicode(param.value).strip()
            # Igore nodot
            if (pname in ["lang", "1", "2", "3", "4", "tr", "t", "gloss", "sc", "id", "nodot"] or
                not lang_in_lang and pname == "5"):
              continue
            pagemsg("WARNING: Unrecognized param %s=%s in otherwise convertible form-of: %s" % (
              pname, pval, unicode(t)))
            break
          else:
            # no break
            # Erase all params.
            del t.params[:]

            # Put back new params.
            blib.set_template_name(t, "inflection of")
            t.add("1", lang)
            t.add("2", lemma)
            if tr:
              t.add("tr", tr)
            t.add("3", alt)
            t.add("4", tags)
            if gloss:
              t.add("t", gloss)
            if sc:
              t.add("sc", sc)
            if id:
              t.add("id", id)
            shortenable_tags.append((lang, lemma, tags))
            notes.append("replaced {{form of}} containing inflection tags with {{inflection of}}")
            pagemsg("Replacing %s with %s" % (origt, unicode(t)))
    return unicode(parsed)

  if args.convert_form_of:
    if pagetitle in skip_pages:
      pagemsg("Page in skip_pages, not applying --convert-form-of")
    else:
      text = convert_form_of(text)

  def combine_adjacent(text):
    subsections = re.split("(^==+[^=\n]+==+\n)", text, 0, re.M)
    for j in xrange(0, len(subsections), 2):
      for template in inflection_of_templates:
        def combine_adjacent_inflections(m):
          inflections = re.split(r"(\{\{%s\|.*\}\})" % template, m.group(0))
          prev_lang = None
          prev_lemma = None
          prev_alt = None
          prev_tr = None
          prev_gloss = None
          prev_tags = None
          prev_misc_params = None
          j = 1
          while j < len(inflections):
            parsed = blib.parse_text(inflections[j])
            templates = list(parsed.filter_templates())
            assert len(templates) > 0
            t = templates[0]
            assert tname(t) == template
            if t.has("lang"):
              this_lang = getparam(t, "lang")
              this_lemma = getparam(t, "1")
              this_alt = getparam(t, "2")
              first_tag = 3
            else:
              this_lang = getparam(t, "1")
              this_lemma = getparam(t, "2")
              this_alt = getparam(t, "3")
              first_tag = 4
            this_tr = getparam(t, "tr")
            this_gloss = getparam(t, "t") or getparam(t, "gloss")
            this_misc_params = []
            this_tags = []
            for param in t.params:
            # Extract the tags and the non-tag parameters.
              pname = unicode(param.name).strip()
              pval = unicode(param.value).strip()
              if re.search("^[0-9]+$", pname):
                if int(pname) >= first_tag:
                  if pval:
                    this_tags.append(pval)
              elif pname not in ["lang", "tr", "alt", "t", "gloss"]:
                this_misc_params.append((pname, pval, param.showkey))
            if (prev_lang == this_lang and prev_lemma == this_lemma and
                prev_alt == this_alt and prev_tr == this_tr and
                prev_gloss == this_gloss and prev_misc_params == this_misc_params):
              # Can combine prev with this.
              this_tags = prev_tags + [";"] + this_tags
              notes.append("combined adjacent calls to {{%s}}" % template)

              # Erase all params.
              del t.params[:]

              # Put back new params.
              # Strip comment continuations and line breaks. Such cases generally have linebreaks after semicolons
              # as well, but we remove those. (FIXME, consider preserving them.)
              t.add("1", remove_comment_continuations(this_lang))
              t.add("2", remove_comment_continuations(this_lemma))
              this_tr = remove_comment_continuations(this_tr)
              if this_tr:
                t.add("tr", this_tr)
              t.add("3", remove_comment_continuations(this_alt))
              next_tag_param = 4
              for tag in this_tags:
                t.add(str(next_tag_param), tag)
                next_tag_param += 1
              this_gloss = remove_comment_continuations(this_gloss)
              if this_gloss:
                t.add("t", this_gloss)
              for pname, pval, showkey in this_misc_params:
                t.add(pname, pval, showkey=showkey, preserve_spacing=False)

              # Replace prev + this with combination.
              pagemsg("Replaced %s + %s with %s" % (inflections[j - 2],
                inflections[j], unicode(t)))
              inflections[j] = unicode(parsed)
              del inflections[j-2:j]
              # Don't increment j; this happened effectively because we
              # deleted the preceding {{inflection of}}/etc. call
            elif prev_lang:
              if prev_lang != this_lang:
                difftype = "languages"
              elif prev_lemma != this_lemma:
                difftype = "lemmas"
              elif prev_alt != this_alt:
                difftype = "alt display texts"
              elif prev_tr != this_tr:
                difftype = "transliterations"
              elif prev_gloss != this_gloss:
                difftype = "glosses"
              else:
                difftype = "misc params"
              pagemsg("Unable to combine %s with %s because %s differ" % (
                inflections[j - 2], inflections[j], difftype))
              j += 2
            else:
              j += 2

            prev_lang = this_lang
            prev_lemma = this_lemma
            prev_alt = this_alt
            prev_tr = this_tr
            prev_gloss = this_gloss
            prev_tags = this_tags
            prev_misc_params = this_misc_params

          return "".join(inflections)

        # Look for adjacent calls to {{inflection of}} with the same
        # definition line text preceding (usually #). Inside of
        # {{inflection of}}, allow balanced sets of {{...}} template
        # calls. We only want {{inflection of}} calls that span the
        # entire line; we want to disallow lines like
        #   # {{inflection of|...}}: foo bar {{g|m}}
        newsubsection = re.sub(r"^([#*]+) \{\{%s\|(?:[^{}\n]|\{\{[^{}\n]*\}\})*\}\}(?:\n\1 \{\{%s\|(?:[^{}\n]|\{\{[^{}\n]*\}\})*\}\})+$" %
            (template, template),
            combine_adjacent_inflections, subsections[j], 0, re.M)
        if args.verbose and newsubsection != subsections[j]:
          pagemsg("Replaced <<%s>> with <<%s>>" % (subsections[j], newsubsection))
        subsections[j] = newsubsection
    return "".join(subsections)

  if args.combine_adjacent:
    text = combine_adjacent(text)

  parsed = blib.parse_text(text)

  templates_to_replace = []

  for t in parsed.filter_templates():
    origt = unicode(t)
    tn = tname(t)

    if tn in inflection_of_templates:

      # (1) Extract the tags and the non-tag parameters. Remove empty tags.

      params = []
      if getparam(t, "lang"):
        lang = getparam(t, "lang")
        term_param = 1
        notes.append("moved lang= in {{%s}} to 1=" % tn)
      else:
        lang = getparam(t, "1")
        term_param = 2
      tr = getparam(t, "tr")
      term = getparam(t, str(term_param))
      alt = getparam(t, "alt") or getparam(t, str(term_param + 1))
      tags = []
      for param in t.params:
        pname = unicode(param.name).strip()
        pval = unicode(param.value).strip()
        if re.search("^[0-9]+$", pname):
          if int(pname) >= term_param + 2:
            if pval:
              tags.append(pval)
            else:
              notes.append("removed empty tags from {{%s}}" % tn)
        elif pname not in ["lang", "tr", "alt"]:
          params.append((pname, pval, param.showkey))

      # (2) Canonicalize tags on a tag-by-tag basis. This may involve applying the
      # replacements listed in tag_replacements or subtag_replacements, and may
      # involve splitting tags on spaces if each component is a recognized tag.

      canon_tags = []

      for tag in tags:
        if tag in semicolon_tags:
          repl = tag
        else:
          # Canonicalize the tag. Convert to canonical abbreviated form
          # if the tag came from a raw or {{form of}} inflection originally.
          # Note that we also abbreviate this way when splitting a tag
          # on spaces.
          repl = canonicalize_tag(tag, (lang, term, tag) in shortenable_tags, pagemsg)
        if repl is None:
          if ' ' in tag:
            pagemsg("WARNING: Bad multiword tag '%s', can't canonicalize" % tag)
            repl = tag
          else:
            pagemsg("WARNING: Bad tag %s, can't canonicalize" % tag)
            repl = tag
        elif repl != tag:
          notemsg = ("canonicalized multiword inflection tag '%s' to %s" if ' ' in tag else
            "canonicalized inflection tag %s to %s")
          notes.append(notemsg % (tag, "|".join(repl) if type(repl) is list else repl))
        if type(repl) is list:
          canon_tags.extend(repl)
        else:
          canon_tags.append(repl)

      tags = canon_tags

      # (3) Apply multi-tag substitutions, e.g. "strong,|weak,|and|mixed" -> "str//wk/mix".

      canon_tags = []
      i = 0
      while i < len(tags):
        for fro, to, exact in multitag_replacements:
          if exact and (i > 0 or len(tags) != len(fro)):
            continue
          if i + len(fro) <= len(tags):
            for j in range(len(fro)):
              if fro[j] != tags[i + j]:
                break
            else:
              if type(to) is list:
                canon_tags.extend(to)
                notes.append("replaced inflection tag sequence %s with %s" % ("|".join(fro), "|".join(to)))
              else:
                canon_tags.append(to)
                notes.append("replaced inflection tag sequence %s with %s" % ("|".join(fro), to))
              i += len(fro)
              break
        else:
          # no break; we considered and rejected all multitag replacements
          canon_tags.append(tags[i])
          i += 1
      tags = canon_tags

      # (4) Canonicalize tags by combining e.g. 'nom|and|voc' to 'nom//voc'.

      canon_tags = []
      i = 0
      while i < len(tags):

        # Check for foo|and|bar|and|baz|and|bat|and|quux where foo, bar, baz,
        # bat and quux are in the same dimension.
        if i <= len(tags) - 9 and (
          tags[i] in combinable_tags_by_dimension and
          tags[i + 1] in joiner_tags and
          tags[i + 2] in combinable_tags_by_dimension and
          tags[i + 3] in joiner_tags and
          tags[i + 4] in combinable_tags_by_dimension and
          tags[i + 5] in joiner_tags and
          tags[i + 6] in combinable_tags_by_dimension and
          tags[i + 7] in joiner_tags and
          tags[i + 8] in combinable_tags_by_dimension and
          combinable_tags_by_dimension[tags[i]] == combinable_tags_by_dimension[tags[i + 2]] and
          combinable_tags_by_dimension[tags[i + 2]] == combinable_tags_by_dimension[tags[i + 4]] and
          combinable_tags_by_dimension[tags[i + 4]] == combinable_tags_by_dimension[tags[i + 6]] and
          combinable_tags_by_dimension[tags[i + 6]] == combinable_tags_by_dimension[tags[i + 8]]
        ):
          dim = combinable_tags_by_dimension[tags[i]]
          tag1 = tag_to_canonical_form[tags[i]]
          tag2 = tag_to_canonical_form[tags[i + 2]]
          tag3 = tag_to_canonical_form[tags[i + 4]]
          tag4 = tag_to_canonical_form[tags[i + 6]]
          tag5 = tag_to_canonical_form[tags[i + 8]]
          orig_tags = "|".join(tags[i:i + 9])
          combined_tag = "%s//%s//%s//%s//%s" % (tag1, tag2, tag3, tag4, tag5)
          canon_tags.append(combined_tag)
          notes.append("combined %s tags %s into %s" % (dim, orig_tags, combined_tag))
          i += 9

        # Check for foo|and|bar|and|baz|and|bat where foo, bar, baz and bat
        # are in the same dimension.
        elif i <= len(tags) - 7 and (
          tags[i] in combinable_tags_by_dimension and
          tags[i + 1] in joiner_tags and
          tags[i + 2] in combinable_tags_by_dimension and
          tags[i + 3] in joiner_tags and
          tags[i + 4] in combinable_tags_by_dimension and
          tags[i + 5] in joiner_tags and
          tags[i + 6] in combinable_tags_by_dimension and
          combinable_tags_by_dimension[tags[i]] == combinable_tags_by_dimension[tags[i + 2]] and
          combinable_tags_by_dimension[tags[i + 2]] == combinable_tags_by_dimension[tags[i + 4]] and
          combinable_tags_by_dimension[tags[i + 4]] == combinable_tags_by_dimension[tags[i + 6]]
        ):
          dim = combinable_tags_by_dimension[tags[i]]
          tag1 = tag_to_canonical_form[tags[i]]
          tag2 = tag_to_canonical_form[tags[i + 2]]
          tag3 = tag_to_canonical_form[tags[i + 4]]
          tag4 = tag_to_canonical_form[tags[i + 6]]
          orig_tags = "|".join(tags[i:i + 7])
          combined_tag = "%s//%s//%s//%s" % (tag1, tag2, tag3, tag4)
          canon_tags.append(combined_tag)
          notes.append("combined %s tags %s into %s" % (dim, orig_tags, combined_tag))
          i += 7

        # Check for foo|and|bar|and|baz where foo, bar and baz
        # are in the same dimension.
        elif i <= len(tags) - 5 and (
          tags[i] in combinable_tags_by_dimension and
          tags[i + 1] in joiner_tags and
          tags[i + 2] in combinable_tags_by_dimension and
          tags[i + 3] in joiner_tags and
          tags[i + 4] in combinable_tags_by_dimension and
          combinable_tags_by_dimension[tags[i]] == combinable_tags_by_dimension[tags[i + 2]] and
          combinable_tags_by_dimension[tags[i + 2]] == combinable_tags_by_dimension[tags[i + 4]]
        ):
          dim = combinable_tags_by_dimension[tags[i]]
          tag1 = tag_to_canonical_form[tags[i]]
          tag2 = tag_to_canonical_form[tags[i + 2]]
          tag3 = tag_to_canonical_form[tags[i + 4]]
          orig_tags = "|".join(tags[i:i + 5])
          combined_tag = "%s//%s//%s" % (tag1, tag2, tag3)
          canon_tags.append(combined_tag)
          notes.append("combined %s tags %s into %s" % (dim, orig_tags, combined_tag))
          i += 5

        # Check for foo|bar|and|baz where foo, bar and baz
        # are in the same dimension.
        elif i <= len(tags) - 4 and (
          tags[i] in combinable_tags_by_dimension and
          tags[i + 1] in combinable_tags_by_dimension and
          tags[i + 2] in joiner_tags and
          tags[i + 3] in combinable_tags_by_dimension and
          combinable_tags_by_dimension[tags[i]] == combinable_tags_by_dimension[tags[i + 1]] and
          combinable_tags_by_dimension[tags[i + 1]] == combinable_tags_by_dimension[tags[i + 3]]
        ):
          dim = combinable_tags_by_dimension[tags[i]]
          tag1 = tag_to_canonical_form[tags[i]]
          tag2 = tag_to_canonical_form[tags[i + 1]]
          tag3 = tag_to_canonical_form[tags[i + 3]]
          orig_tags = "|".join(tags[i:i + 4])
          combined_tag = "%s//%s//%s" % (tag1, tag2, tag3)
          canon_tags.append(combined_tag)
          notes.append("combined %s tags %s into %s" % (dim, orig_tags, combined_tag))
          i += 4

        # Check for foo|and|bar where foo and bar are in the same dimension.
        elif i <= len(tags) - 3 and (
          tags[i] in combinable_tags_by_dimension and
          tags[i + 1] in joiner_tags and
          tags[i + 2] in combinable_tags_by_dimension and
          combinable_tags_by_dimension[tags[i]] == combinable_tags_by_dimension[tags[i + 2]]
        ):
          dim = combinable_tags_by_dimension[tags[i]]
          tag1 = tag_to_canonical_form[tags[i]]
          tag2 = tag_to_canonical_form[tags[i + 2]]
          orig_tags = "|".join(tags[i:i + 3])
          combined_tag = "%s//%s" % (tag1, tag2)
          canon_tags.append(combined_tag)
          notes.append("combined %s tags %s into %s" % (dim, orig_tags, combined_tag))
          i += 3

        else:
          canon_tags.append(tags[i])
          i += 1

      tags = canon_tags

      # (5) When multiple tag sets separated by semicolon, combine adjacent
      # ones that differ in only one tag in a given dimension. Repeat this
      # until no changes in case we can reduce along multiple dimensions, e.g.
      #
      # {{inflection of|canus||dat|m|p|;|dat|f|p|;|dat|n|p|;|abl|m|p|;|abl|f|p|;|abl|n|p|lang=la}}
      #
      # which can be reduced to
      #
      # {{inflection of|la|canus||dat//abl|m//f//n|p}}
      while True:
        # First, canonicalize 1s etc. into 1|s
        canonicalized_tags = []
        for tag in tags:
          if tag in multipart_list_tag_to_parts:
            canonicalized_tags.extend(multipart_list_tag_to_parts[tag])
          else:
            canonicalized_tags.append(tag)

        old_canonicalized_tags = canonicalized_tags

        # Then split into tag sets.
        tag_set_group = split_tags_into_tag_sets(canonicalized_tags)

        # Try combining in two different styles ("adjacent-first" =
        # do two passes, where the first pass only combines adjacent
        # tag sets, while the second pass combines nonadjacent tag sets;
        # "all-first" = do one pass combining nonadjacent tag sets).
        # Sometimes one is better, sometimes the other.
        #
        # An example where adjacent-first is better:
        #
        # {{inflection of|medius||m|acc|s|;|n|nom|s|;|n|acc|s|;|n|voc|s|lang=la}}
        #
        # all-first results in
        #
        # {{inflection of|la|medius||m//n|acc|s|;|n|nom//voc|s}}
        #
        # which isn't ideal.
        #
        # If we do adjacent-first, we get
        #
        # {{inflection of|la|medius||m|acc|s|;|n|nom//acc//voc|s}}
        #
        # which is much better.
        #
        # The opposite happens in
        #
        # {{inflection of|βουλόμενος||n|nom|s|;|m|acc|s|;|n|acc|s|;|n|voc|s|lang=grc}}
        #
        # where all-first results in
        #
        # {{inflection of|grc|βουλόμενος||n|nom//acc//voc|s|;|m|acc|s}}
        #
        # which is better than the result from adjacent-first, which is
        #
        # {{inflection of|grc|βουλόμενος||n|nom//voc|s|;|m//n|acc|s}}
        #
        # To handle this conundrum, we try both, and look to see which one
        # results in fewer "combinations" (where a tag with // in it counts
        # as a combination). If both are different but have the same # of
        # combinations, we prefer adjacent-first, we seems generally a better
        # approach.

        tag_set_group_by_style = {}
        notes_by_style = {}

        # Split a possibly multipart tag into the components and
        # canonicalize them.
        def split_and_canonicalize_tag(tag):
          return [tag_to_canonical_form_table.get(tg, tg) for tg in tag.split("//")]

        for combine_style in ["adjacent-first", "all-first"]:
          # Now, we do two passes. The first pass only combines adjacent
          # tag sets, while the second pass combines nonadjacent tag sets.
          # Copy tag_set_group, since we destructively modify the list.
          tag_sets = list(tag_set_group)
          this_notes = []
          if combine_style == "adjacent-first":
            combine_passes = ["adjacent", "all"]
          else:
            combine_passes = ["all"]
          for combine_pass in combine_passes:
            tag_ind = 0
            while tag_ind < len(tag_sets):
              if combine_pass == "adjacent":
                if tag_ind == 0:
                  prev_tag_range = []
                else:
                  prev_tag_range = [tag_ind - 1]
              else:
                prev_tag_range = range(tag_ind)
              for prev_tag_ind in prev_tag_range:
                cur_tag_set = tag_sets[prev_tag_ind]
                tag_set = tag_sets[tag_ind]
                if len(cur_tag_set) == len(tag_set):
                  mismatch_ind = None
                  for i, (tag1, tag2) in enumerate(zip(cur_tag_set, tag_set)):
                    tag1 = split_and_canonicalize_tag(tag1)
                    tag2 = split_and_canonicalize_tag(tag2)
                    if set(tag1) == set(tag2):
                      continue
                    if mismatch_ind is not None:
                      break
                    dims1 = [combinable_tags_by_dimension_table.get(tag, "unknown") for tag in tag1]
                    dims2 = [combinable_tags_by_dimension_table.get(tag, "unknown") for tag in tag2]
                    unique_dims = set(dims1 + dims2)
                    if len(unique_dims) == 1 and unique_dims != {"unknown"}:
                      mismatch_ind = i
                    else:
                      break
                  else:
                    # No break, we either match perfectly or are combinable
                    if mismatch_ind is None:
                      pagemsg("WARNING: Two identical tag sets: %s and %s in %s" % (
                        "|".join(cur_tag_set), "|".join(tag_set), unicode(t)))
                      del tag_sets[tag_ind]
                      break
                    else:
                      tag1 = cur_tag_set[mismatch_ind]
                      tag2 = tag_set[mismatch_ind]
                      tag1 = split_and_canonicalize_tag(tag1)
                      tag2 = split_and_canonicalize_tag(tag2)
                      combined_tag = "//".join(tag1 + tag2)
                      new_tag_set = []
                      for i in xrange(len(cur_tag_set)):
                        if i == mismatch_ind:
                          new_tag_set.append(combined_tag)
                        else:
                          cur_canon_tag = split_and_canonicalize_tag(cur_tag_set[i])
                          canon_tag = split_and_canonicalize_tag(tag_set[i])
                          assert set(cur_canon_tag) == set(canon_tag)
                          new_tag_set.append(cur_tag_set[i])
                      combine_msg = "tag sets %s and %s into %s" % (
                        "|".join(cur_tag_set), "|".join(tag_set), "|".join(new_tag_set)
                      )
                      pagemsg("Combining %s" % combine_msg)
                      this_notes.append("combined %s" % combine_msg)
                      tag_sets[prev_tag_ind] = new_tag_set
                      del tag_sets[tag_ind]
                      break
              else:
                # No break from inner for-loop. Break from that loop indicates
                # that we found that the current tag set can be combined with
                # a preceding tag set, did the combination and deleted the
                # current tag set. The next iteration then processes the same
                # numbered tag set again (which is actually the following tag
                # set, because we deleted the tag set before it). No break
                # indicates that we couldn't combine the current tag set with
                # any preceding tag set, and need to advance to the next one.
                tag_ind += 1
          tag_set_group_by_style[combine_style] = tag_sets
          notes_by_style[combine_style] = this_notes

        if tag_set_group_by_style["adjacent-first"] != tag_set_group_by_style["all-first"]:
          def num_combinations(group):
            num_combos = 0
            for tag_set in group:
              for tag in tag_set:
                if "//" in tag:
                  num_combos += 1
            return num_combos
          def join_tag_set_group(group):
            return "|".join(combine_tag_set_group(group))

          num_adjacent_first_combos = num_combinations(tag_set_group_by_style["adjacent-first"])
          num_all_first_combos = num_combinations(tag_set_group_by_style["all-first"])
          if num_adjacent_first_combos < num_all_first_combos:
            pagemsg("Preferring adjacent-first result %s (%s combinations) to all-first result %s (%s combinations)" % (
              join_tag_set_group(tag_set_group_by_style["adjacent-first"]),
              num_adjacent_first_combos,
              join_tag_set_group(tag_set_group_by_style["all-first"]),
              num_all_first_combos
            ))
            tag_set_group = tag_set_group_by_style["adjacent-first"]
            notes.extend(notes_by_style["adjacent-first"])
          elif num_all_first_combos < num_adjacent_first_combos:
            pagemsg("Preferring all-first result %s (%s combinations) to adjacent-first result %s (%s combinations)" % (
              join_tag_set_group(tag_set_group_by_style["all-first"]),
              num_all_first_combos,
              join_tag_set_group(tag_set_group_by_style["adjacent-first"]),
              num_adjacent_first_combos
            ))
            tag_set_group = tag_set_group_by_style["all-first"]
            notes.extend(notes_by_style["all-first"])
          else:
            pagemsg("Adjacent-first and all-first combination style different but same #combinations %s, preferring adjacent-first result %s to all-first result %s" % (
              num_adjacent_first_combos,
              join_tag_set_group(tag_set_group_by_style["adjacent-first"]),
              join_tag_set_group(tag_set_group_by_style["all-first"])
            ))
            tag_set_group = tag_set_group_by_style["adjacent-first"]
            notes.extend(notes_by_style["adjacent-first"])
        else:
          # Both are the same, pick either one
          tag_set_group = tag_set_group_by_style["adjacent-first"]
          notes.extend(notes_by_style["adjacent-first"])

        canonicalized_tags = []
        for tag_set in tag_set_group:
          if canonicalized_tags:
            canonicalized_tags.append(";")
          canonicalized_tags.extend(tag_set)
        if canonicalized_tags == old_canonicalized_tags:
          break
        # FIXME, we should consider reversing the transformation 1s -> 1|s,
        # but it's complicated to figure out when the transformation occurred;
        # not really important as both are equivalent
        tags = canonicalized_tags

      # (6) Record statistics on multipart tags, unrecognized ("bad") tags,
      # tags with spaces in them, etc.  # Maybe sort the tags.

      # Record statistics on multipart tags
      tag_sets = split_tags_into_tag_sets(tags)
      for tag_set in tag_sets:
        record_stats_on_tag_set(tag_set)

      # Note stats on bad tags
      has_bad_tags = False
      has_joiner = False
      for tag in tags:
        if tag in joiner_tags:
          has_joiner = True
        if " " in tag:
          tags_with_spaces[tag] += 1
        if tag not in semicolon_tags:
          split_tags = [tg for split_tag in tag.split("//") for tg in split_tag.split(":")]
          for split_tag in split_tags:
            if split_tag not in good_tags:
              bad_tags[split_tag] += 1
              has_bad_tags = True
              pagemsg("Saw bad tag: %s" % split_tag)

      # Maybe sort tags
      sorted_tags_info = ""
      if args.sort_tags:
        sorted_tag_sets = [sort_tags(tag_set) for tag_set in tag_sets]
        new_tags = combine_tag_set_group(sorted_tag_sets)
        if new_tags != tags:
          notes.append("sorted tags")
          sorted_tags_info = " (sorted tags)"
          tags = new_tags

      # (7) Put back the new parameters.

      # Erase all params.
      del t.params[:]

      # Put back new params.

      # Strip comment continuations and line breaks. Such cases generally
      # have linebreaks after semicolons as well, but we remove those.
      # (FIXME, consider preserving them.)
      t.add("1", remove_comment_continuations(lang))
      t.add("2", remove_comment_continuations(term))
      tr = remove_comment_continuations(tr)
      if tr:
        t.add("tr", tr)

      if tags == ["p"]:
        # Convert to 'plural of'.
        blib.set_template_name(t, "plural of")
        altparam = remove_comment_continuations(alt)
        if altparam:
          t.add("3", altparam)
        notes.append("replaced {{inflection of|...|p}} with {{plural of}}")

      else:
        t.add("3", remove_comment_continuations(alt))
        next_tag_param = 4

        # Put back the tags into the template and note stats on bad tags
        for tag in tags:
          t.add(str(next_tag_param), tag)
          next_tag_param += 1

      # Finally, put back misc. tags.
      for pname, pval, showkey in params:
        t.add(pname, pval, showkey=showkey, preserve_spacing=False)

      if origt != unicode(t):
        if not notes:
          notes.append("canonicalized {{%s}}" % tn)
        pagemsg("Replaced %s with %s%s" % (origt, unicode(t), sorted_tags_info))

      global num_total_templates
      num_total_templates += 1
      global num_templates_with_bad_tags
      if has_bad_tags:
        num_templates_with_bad_tags += 1
      if has_joiner:
        pagemsg("WARNING: Template has unconverted joiner: %s" % unicode(t))

  return unicode(parsed), notes

def process_page(page, index, parsed):
  pagetitle = unicode(page.title())
  text = unicode(page.text)
  return process_text_on_page(pagetitle, index, text)

parser = blib.create_argparser("Clean up bad inflection tags")
parser.add_argument("--pagefile", help="List of pages to process.")
parser.add_argument("--textfile", help="File containing page text or defn line text to process.")
parser.add_argument("--matching-textfile", help="File containing defn lines to match against; if we change a line not listed, output a warnings.")
parser.add_argument("--langcode", help="Specify lang code to use, instead of inferring it from headings.")
parser.add_argument("--form-of-files", help="Comma-separated list of files containing form-of data.")
parser.add_argument("--use-form-of-groups", help="Use groups specified in form-of data for combining across semicolons.",
    action="store_true")
parser.add_argument("--combine-adjacent", help="Combine adjacent calls to 'inflection of'.", action="store_true")
parser.add_argument("--convert-raw", help="Convert raw inflection definitions to {{inflection of}}.", action="store_true")
parser.add_argument("--convert-form-of", help="Convert {{form of}} inflection definitions to {{inflection of}}.", action="store_true")
parser.add_argument("--sort-tags", help="Sort tags by dimension.", action="store_true")
parser.add_argument("--debug", help="Output debug info about canonicalization.", action="store_true")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

if args.convert_raw:
  blib.getData()

def fetch_page_titles_and_text(textfile):
  with codecs.open(textfile, "r", "utf-8") as fp:
    text = fp.read()
  if '\001' in text:
    pages = text.split('\001')
    title_text_split = '\n'
  else:
    pages = re.split('\nPage [0-9]+ ', '\n' + text)
    title_text_split = ': Found (?:template: |match for regex: |subsection with combinable .*?:\n)'
  for index, page in enumerate(pages):
    if not page.strip(): # e.g. first entry
      continue
    split_vals = re.split(title_text_split, page, 1)
    if len(split_vals) < 2:
      msg("Page %s: Skipping bad text: %s" % (index + 1, page))
      continue
    yield split_vals

if args.matching_textfile:
  matching_textfile_lines = set(
    text for title, text in fetch_page_titles_and_text(args.matching_textfile)
  )

if args.form_of_files:
  files = args.form_of_files.split(',')
  for f in files:
    with codecs.open(f, 'r', "utf-8") as fp:
      parse_form_of_data(fp)
  set_form_of_tables()

if args.textfile:
  titles_and_text = fetch_page_titles_and_text(args.textfile)
  for index, (pagetitle, pagetext) in blib.iter_items(titles_and_text, start,
      end, get_name=lambda title_and_text: title_and_text[0]):
    newtext, notes = process_text_on_page(pagetitle, index, pagetext)
    if newtext and newtext != pagetext:
      msg("Page %s %s: Would save with comment = %s" % (index, pagetitle,
        "; ".join(blib.group_notes(notes))))

elif args.pagefile:
  pages = [x.rstrip('\n') for x in codecs.open(args.pagefile, "r", "utf-8")]
  for i, page in blib.iter_items(pages, start, end):
    blib.do_edit(pywikibot.Page(site, page), i, process_page, save=args.save,
        verbose=args.verbose)

output_stats_on_tag_set()

msg("Fraction of templates with bad tags = %s / %s = %.2f%%" % (
  num_templates_with_bad_tags, num_total_templates,
  float(num_templates_with_bad_tags) * 100 / float(num_total_templates)
))

def print_table(table):
  for key, val in sorted(table.iteritems(), key=lambda x: -x[1]):
    msg("%s = %s" % (key, val))

msg("Bad tags:")
print_table(bad_tags)
msg("Bad tags during split canonicalization:")
print_table(bad_tags_during_split_canonicalization)
msg("Tags with spaces:")
print_table(tags_with_spaces)
