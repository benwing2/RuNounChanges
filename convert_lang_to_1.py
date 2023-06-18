#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, msg, site, tname

from form_of_templates import (
  language_specific_alt_form_of_templates,
  language_specific_form_of_templates,
  form_of_templates
)

form_of_template_list = []
for form_of_spec in form_of_templates:
  form_of_template_list.append(form_of_spec[0])
  if "aliases" in form_of_spec[1]:
    form_of_template_list.extend(form_of_spec[1]["aliases"])
request_templates = [
  "etystub", "rfap", "rfc", "rfc-header", "rfc-pron-n", "rfc-sense",
  "rfclarify", "rfd", "rfd-redundant", "rfd-sense",
  "rfdate", "rfdatek", "rfdecl", "rfdef", "rfe", "rfelite",
  "rfex", "rfform", "rfi", "rfinfl", "rfm", "rfp", "rfp-old", "rfquote",
  "rfquote-sense", "rfquotek", "rfref", "rfv", "rfv-etym", "rfv-pron",
  "rfv-sense", "tea room", "tea room sense",
]
multicolumn_templates = [
  "columns", "col", "col-u",
  "col1", "col2", "col3", "col4", "col5",
  "col1-u", "col2-u", "col3-u", "col4-u", "col5-u",
  "rel2", "rel3", "rel4",
  "der2", "der3", "der4",
]
quote_templates = [
  "quote-av", "quote-book", "quote-hansard", "quote-journal",
  "quote-newsgroup", "quote-song", "quote-us-patent", "quote-web",
  "quote-wikipedia", "quote-text", "quote-video game",
]
headtempboiler_templates = [
  "headtempboiler", "headtempboiler:suffix", "headtempboiler:letter",
  "headtempboiler:number", "headtempdocboiler",
  "headtempdocboiler:suffix", "headtempdocboiler:letter",
  "headtempdocboiler:number"
]
metatempboiler_templates = [
  "meta-diacritical mark", "meta-phrase", "meta-punctuation mark"
]
misc_templates = [
  "&lit", "abbreviated", "audio", "audio-IPA", "audio-pron", "citation", "citations",
  "cuneiform", "elements", "enum", "given name", "historical given name", "homophones",
  "homophone", "hmp", "hot word", "hyphenation", "hyph", "IPA", "IPA letters",
  "named-after", "no entry", "only used in", "patronymic", "picdicimg", "picdiclabel",
  "rhymes", "rhyme", "seeCites", "seemoreCites", "seeSynonyms", "SI-unit", "SI-unit-np",
  "surname", "term-context", "tcx", "trademark erosion",
  "was fwotd", "X2IPA", "x2IPA", "x2ipa", "x2rhymes", "Zodiac",
]

template_renamings = {
  "defn": "rfdef",
}

# approximately sorted from least to most number of uses
form_of_templates_1000_uses_or_less = [
  "masculine of", # 0 uses
  "neuter plural of", # 0 uses
  "masculine noun of", # 1 uses
  "misromanization of", # 2 uses
  "rfform", # 2 uses
  "men's speech form of", # 3 uses
  "monotonic form of", # 3 uses
  "accusative of", # 5 uses
  "alternative reconstruction of", # 5 uses
  "broad form of", # 5 uses
  "future participle of", # 5 uses
  "neuter plural past participle of", # 5 uses
  "nominative singular of", # 5 uses
  "present active participle of", # 5 uses
  "diminutive plural of", # 6 uses
  "standard spelling of", # 6 uses
  "pronunciation variant of", # 7 uses
  "frequentative of", # 8 uses
  "uncommon form of", # 8 uses
  "construed with", # 9 uses
  "perfect participle of", # 9 uses
  "aphetic form of", # 10 uses
  "nominalization of", # 10 uses
  "dual of", # 14 uses
  "deliberate misspelling of", # 16 uses
  "vocative plural of", # 16 uses
  "accusative singular of", # 18 uses
  "honorific alternative case form of", # 18 uses
  "standard form of", # 18 uses
  "mixed mutation of", # 19 uses
  "past passive participle of", # 19 uses
  "iterative of", # 21 uses
  "accusative plural of", # 22 uses
  "nomen sacrum form of", # 22 uses
  "slender form of", # 22 uses
  "equative of", # 27 uses
  "eggcorn of", # 28 uses
  "hard mutation of", # 30 uses
  "passive participle of", # 35 uses
  "informal spelling of", # 37 uses
  "supine of", # 37 uses
  "syncopic form of", # 37 uses
  "uncommon spelling of", # 38 uses
  "perfective form of", # 39 uses
  "participle of", # 41 uses
  "harmonic variant of", # 42 uses
  "euphemistic spelling of", # 44 uses
  "singular of", # 46 uses
  "active participle of", # 47 uses
  "past active participle of", # 47 uses
  "combining form of", # 50 uses
  "pejorative of", # 52 uses
  "t-prothesis of", # 56 uses
  "alternative plural of", # 64 uses
  "euphemistic form of", # 65 uses
  "elongated form of", # 74 uses
  "alternative typography of", # 75 uses
  "informal form of", # 84 uses
  "nuqtaless form of", # 84 uses
  "passive past tense of", # 89 uses
  "genitive plural of", # 90 uses
  "superlative attributive of", # 90 uses
  "superlative predicative of", # 92 uses
  "obsolete typography of", # 95 uses
  "causative of", # 96 uses
  "dative singular of", # 101 uses
  "former name of", # 113 uses
  "endearing form of", # 134 uses
  "nonstandard form of", # 144 uses
  "misconstruction of", # 146 uses
  "medieval spelling of", # 157 uses
  "negative of", # 159 uses
  "pronunciation spelling of", # 186 uses
  "ellipsis of", # 189 uses
  "dated spelling of", # 192 uses
  "elative of", # 197 uses
  "agent noun of", # 218 uses
  "nominative plural of", # 238 uses
  "aspirate mutation of", # 305 uses
  "h-prothesis of", # 318 uses
  "singulative of", # 322 uses
  "abstract noun of", # 327 uses
  "rare form of", # 350 uses
  "neuter singular past participle of", # 356 uses
  "augmentative of", # 432 uses
  "nasal mutation of", # 453 uses
  "rare spelling of", # 584 uses
  "nonstandard spelling of", # 601 uses
  "imperfective form of", # 635 uses
  "attributive form of", # 707 uses
  "dated form of", # 761 uses
  "eclipsis of", # 773 uses
  "vocative singular of", # 774 uses
  "apocopic form of", # 786 uses
  "superseded spelling of", # 787 uses
  "soft mutation of", # 840 uses
  "acronym of", # 853 uses
  "past tense of", # 874 uses
  "archaic spelling of", # 903 uses
]

# approximately sorted from least to most number of uses
form_of_templates_1000_to_5000_uses = [
  "lenition of", # 1014 uses
  "short for", # 1041 uses
  "contraction of", # 1051 uses
  "clipping of", # 1061 uses
  "adj form of", # 1070 uses
  "neuter singular of", # 1070 uses
  "spelling of", # 1200 uses
  "alternative case form of", # 1378 uses
  "imperative of", # 1426 uses
  "dative of", # 1619 uses
  "reflexive of", # 1640 uses
  "archaic form of", # 1870 uses
  "dative plural of", # 1980 uses
  "eye dialect of", # 2036 uses
  "present tense of", # 2431 uses
  "passive of", # 2492 uses
  "feminine of", # 2529 uses
  "genitive singular of", # 3536 uses
  "genitive of", # 3670 uses
  "form of", # 4023 uses
  "female equivalent of", # 4656 uses
  "indefinite plural of", # 4799 uses
  "obsolete form of", # 4916 uses
]

# approximately sorted from least to most number of uses
form_of_templates_5000_to_20000_uses = [
  "definite plural of", # 5103 uses
  "definite singular of", # 5240 uses
  "misspelling of", # 5782 uses
  "noun form of", # 5865 uses
  "verbal noun of", # 5987 uses
  "abbreviation of", # 6235 uses
  "obsolete spelling of", # 6256 uses
  "initialism of", # 6761 uses
  "diminutive of", # 7199 uses
  "feminine singular past participle of", # 7294 uses
  "feminine plural past participle of", # 7458 uses
  "masculine plural past participle of", # 7463 uses
  "comparative of", # 8054 uses
  "superlative of", # 8126 uses
  "verb form of", # 9614 uses
  "romanization of", # 10994 uses
  "synonym of", # 12661 uses
  "gerund of", # 13038 uses
]

# approximately sorted from least to most number of uses
form_of_templates_20000_to_100000_uses = [
  "past participle of", # 22547 uses
  "alternative spelling of", # 25283 uses
  "masculine plural of", # 30997 uses
  "feminine plural of", # 35009 uses
  "feminine singular of", # 35089 uses
  "present participle of", # 48229 uses
  "alternative form of", # 80654 uses
]

# approximately sorted from least to most number of uses
form_of_templates_more_than_100000_uses = [
  "plural of", # 423977 uses
  "inflection of", # 1912109 uses
]
# inflection of progress as of 20191018, 1045pm
#1/338400/506000 = 167600 to go
#505000/527450/701000 = 173550 to go
#700000/776150/951000 = 174850 to go
#950000/1048300/1251000 = 202700 to go
#1250000/1420900/1551000 = 130100 to go
#1550000/1677200/2000000 = 322800 to go

# approximately sorted from least to most number of uses
request_templates_1000_uses_or_less = [
  "rfp-old", # 3 uses
  "rfform", # 5 uses
  "tea room sense", # 17 uses
  "rfref", # 21 uses
  "rfdecl", # 34 uses
  "rfd-redundant", # 43 uses
  "rfm", # 66 uses
  "rfc-sense", # 86 uses
  "rfd-sense", # 102 uses
  "tea room", # 100 uses
  "rfquote-sense", # 140 uses
  "rfv-pron", # 164 uses
  "rfdatek", # 290 uses
  "rfquote", # 421 uses
  "rfv-sense", # 499 uses
  "rfv-etym", # 681 uses
  "rfex", # 756 uses
  "rfclarify", # 836 uses
  "rfc-pron-n", # 841 uses
  "rfc", # 936 uses
]

# approximately sorted from least to most number of uses
request_templates_1000_to_5000_uses = [
  "rfv", # 1424 uses
  "rfc-header", # 1546 uses
  "rfd", # 1768 uses
  "rfi", # 2832 uses
  "rfelite", # 4188 uses
  "rfap", # 4232 uses
  "etystub", # 4242 uses
]

# approximately sorted from least to most number of uses
request_templates_5000_to_20000_uses = [
  "rfp", # 5367 uses
  "rfquotek", # 9323 uses
  "rfinfl", # 16337 uses
]

# approximately sorted from least to most number of uses
request_templates_more_than_20000_uses = [
  "rfe", # 34200 uses
  "rfdef", # 65117 uses
]

# approximately sorted from least to most number of uses
misc_templates_1000_uses_or_less = [
  "trademark erosion", # 6 uses
  "x2rhymes", # 8 uses
  "X2IPA", # 22 uses
  "audio-pron", # 41 uses
  "Zodiac", # 77 uses
  "hot word", # 107 uses
  "audio-IPA", # 120 uses
  "historical given name", # 124 uses
  "picdicimg", # 128 uses
  "picdiclabel", # 158 uses
  "only used in", # 340 uses
  "named-after", # 460 uses
]

# approximately sorted from least to most number of uses
misc_templates_1000_to_5000_uses = [
  "elements", # 1686 uses
  "seemoreCites", # 1823 uses
  "&lit", # 2053 uses
  "was fwotd", # 2571 uses
  "no entry", # 2846 uses
  "term-context", # 3196 uses
]

# approximately sorted from least to most number of uses
misc_templates_5000_to_20000_uses = [
  "seeCites", # 5559 uses
]

# approximately sorted from least to most number of uses
misc_templates_20000_to_100000_uses = [
  "citation", # 25746 uses
  "given name", # 29449 uses
  "surname", # 53168 uses
  "homophones", # 64011 uses
  "rhymes", # 88788 uses
]

# approximately sorted from least to most number of uses
misc_templates_more_than_100000_uses = [
  "hyphenation", # 184462 uses
  "audio", # 238200 uses
  "IPA", # 569580 uses
]

non_alias_multicolumn_templates = [
  "columns", "col", "col-u",
  "col1", "col2", "col3", "col4", "col5",
  "col1-u", "col2-u", "col3-u", "col4-u", "col5-u",
]

templates_to_move_lang = (
  form_of_template_list + request_templates + multicolumn_templates +
  quote_templates + headtempboiler_templates + metatempboiler_templates +
  misc_templates
)

#templates_to_iterate_over = ["form of", "synonym of"] + quote_templates
#templates_to_iterate_over = ["rhyme", "rhymes", "hyph", "hyphenation"]
# templates_to_iterate_over = ["quote-text", "rhymes", "hyph", "hyphenation"]
# templates_to_iterate_over = form_of_templates_1000_uses_or_less_already_done
#templates_to_iterate_over = (
#  form_of_templates_1000_uses_or_less_not_done_yet +
#  form_of_templates_1000_to_5000_uses
#)
#templates_to_iterate_over = request_templates_1000_uses_or_less
#templates_to_iterate_over = misc_templates_1000_uses_or_less
#templates_to_iterate_over = (
#  form_of_templates_1000_to_5000_uses_not_done_yet +
#  misc_templates_1000_to_5000_uses +
#  request_templates_1000_to_5000_uses
#)
#templates_to_iterate_over = non_alias_multicolumn_templates
#templates_to_iterate_over = ["etystub", "eye dialect of"] + (
#  form_of_templates_5000_to_20000_uses +
#  request_templates_5000_to_20000_uses
#)
#templates_to_iterate_over = ["defn"]
#templates_to_iterate_over = (
#  misc_templates_20000_to_100000_uses +
#  form_of_templates_20000_to_100000_uses +
#  request_templates_more_than_20000_uses
#)
#templates_to_iterate_over = ["rfm", "tea room", "rfdatek", "rfc",
#  "rfc-header", "rfquotek"]
#templates_to_iterate_over = ["alternative form of", "present participle of"]
#templates_to_iterate_over = ["citation"]
#templates_to_iterate_over = ["alternative spelling of"]
#templates_to_iterate_over = ["past participle of"]
#templates_to_iterate_over = [
#  "masculine plural of",
#  "feminine plural of",
#  "feminine singular of"
#]
#templates_to_iterate_over = ["rfdef", "rfe"]
#templates_to_iterate_over = ["past participle form of", "audio"]
#templates_to_iterate_over = ["plural of"]
#templates_to_iterate_over = ["IPA"]
#templates_to_iterate_over = ["inflection of"]
#templates_to_iterate_over = ["seeCites"]
#templates_to_iterate_over = ["elements"]
#templates_to_iterate_over = metatempboiler_templates
#templates_to_iterate_over = ["abbreviated", "cuneiform", "patronymic", "IPA letters",
#  "seeSynonyms", "SI-unit", "SI-unit-np"]
templates_to_iterate_over = ["quote-video game"]

#templates_to_remove_empty_dot = (
#  form_of_template_list + language_specific_form_of_templates
#)
#templates_to_check_for_empty_dot = (
#  alt_form_of_templates + language_specific_alt_form_of_templates
#)
#templates_to_remove_nodot = (
#  form_of_template_list + language_specific_form_of_templates
#)
templates_to_remove_empty_dot = []
templates_to_check_for_empty_dot = []
templates_to_remove_nodot = []

def process_page(page, index, parsed):
  pagetitle = str(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")
  notes = []

  for t in parsed.filter_templates():
    origt = str(t)
    tn = tname(t)
    if tn in templates_to_remove_nodot:
      if t.has("nodot"):
        rmparam(t, "nodot")
        notes.append("remove effectless nodot= from {{%s}}" % tn)
    if tn in templates_to_remove_empty_dot:
      if t.has("dot"):
        if getparam(t, "dot") and getparam(t, "dot") != "<nowiki/>":
          pagemsg("WARNING: non-empty dot= in form_of_t template: %s" % str(t))
        rmparam(t, "dot")
        notes.append("remove effectless empty dot= from {{%s}}" % tn)
    if tn in templates_to_check_for_empty_dot:
      if t.has("dot") and (not getparam(t, "dot") or getparam(t, "dot") == "<nowiki/>"):
        pagemsg("WARNING: empty dot= in alt_form_of_t template: %s" % str(t))
        rmparam(t, "dot")
        t.add("nodot", "1")
        notes.append("convert empty dot= to nodot=1 in {{%s}}" % tn)
    if tn in templates_to_move_lang:
      lang = getparam(t, "lang")
      if lang:
        # Fetch all params.
        params = []
        for param in t.params:
          pname = str(param.name)
          if pname.strip() != "lang":
            params.append((pname, param.value, param.showkey))
        # Erase all params.
        del t.params[:]
        t.add("1", lang)
        # Put remaining parameters in order.
        for name, value, showkey in params:
          if re.search("^[0-9]+$", name):
            t.add(str(int(name) + 1), value, showkey=showkey, preserve_spacing=False)
          else:
            t.add(name, value, showkey=showkey, preserve_spacing=False)
        notes.append("move lang= to 1= in {{%s}}" % tn)
    if tn in template_renamings:
      blib.set_template_name(t, template_renamings[tn])
      notes.append("rename {{%s}} to {{%s}}" % (tn, template_renamings[tn]))

    if str(t) != origt:
      pagemsg("Replaced <%s> with <%s>" % (origt, str(t)))

  return str(parsed), notes

parser = blib.create_argparser("Move lang= to 1=", include_pagefile=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_page, edit=True,
    default_refs=["Template:%s" % template for template in templates_to_iterate_over],
    #ref_namespaces=[10]
    #default_refs=["Template:tracking/form-of/form-of-t/unused/nodot"]
)
