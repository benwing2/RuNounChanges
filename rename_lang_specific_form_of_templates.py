#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse
import traceback, pprint

import blib
from blib import getparam, rmparam, msg, errandmsg, site, tname
from mwparserfromhell.nodes import Template
from dataclasses import dataclass

import infltags

# We prefer the following tag variants (instead of e.g. 'pasv' for passive
# or 'ptcp' for participle).
preferred_tag_variants = {
  "pres", "past", "fut",
  "act", "pass",
  "part"
}

tag_to_dimension_table, tag_to_canonical_form_table = (
  infltags.fetch_tag_tables(preferred_tag_variants)
)


from misc_templates_to_rewrite import misc_templates_to_rewrite

# STILL TO DO:
# egy-verb form of (? lots of Egyptian-specific tags) (27)
# eo-form of (? takes actual ending, generates tags from it, would be a radical shift) (99087)
# es-verb form of (? very complicated; takes a region param that can/should be moved out) (441797)
# gl-verb form of (? very complicated) (598)
# got-nom form of (? has posttext= if comp-of=, sup-of=, presptc-of= or pastptc-of=) (2935)
# ia-form of (? takes actual ending, generates tags from it, would be a radical shift) (718)
# io-form of (? takes actual ending, generates tags from it, would be a radical shift) (10116)
# ja-verb form of (? takes Japanese params, some in Hiragana, would be a radical shift) (93)
# ka-verb-form-of (? has links to [[Appendix:Georgian verbs]]; has stuff describing object pronouns, which maybe should be posttext) (116)
# lv-adv form of (2761)
# lv-participle of (? might need lang-specific tags for "(object-of-perception form)", "(invariable form)", "(variable form)" (5163)
# mn-verb form of (? maybe? uses a module) (63)
# nl-adj form of (? would need lang-specific tag for "Predicative/adverbial form", has posttext= if comp-of= or sup-of=) (4559)
# nn-verb-form of (? maybe? uses a module) (1046)
# pt-pron def (? not only a form-of template) (24)
# sce-verb form of (? maybe? uses a module) (1)
# sw-adj form of (? might be tough) (291)
# tr-possessive form of (? includes posttext) (35)

class BadTemplateValue(Exception):
  pass

class BadRewriteSpec(Exception):
  pass

round_1_templates = [
  "cu-form of", # deleted
  "da-pl-genitive", # can delete
  "de-du contraction", # can delete
  "de-form-noun", # can delete
  "el-form-of-adv", # can delete
  "el-participle of", # can delete
  "et-nom form of", # can delete
  "fa-form-verb", # can delete
  "gmq-bot-verb-form-sup", # can delete
  "hi-form-adj", # can delete
  "hi-form-adj-verb", # can delete
  "hi-form-noun", # can delete
  "hy-form-noun", # can delete
  "ie-past and pp of", # can delete
  "is-conjugation of", # can delete
  "is-inflection of", # deprecate
  "ka-verbal for", # can delete
  "ka-verbal of", # can delete
  "ku-verb form of", # deprecate
  "liv-inflection of", # deprecate
  "lt-form-adj-is", # can delete
  "lt-form-noun", # deprecate
  "lt-form-verb", # deprecate
  "lv-definite of", # can delete
  "lv-verbal noun of", # can delete
  "mr-form-adj", # fix जागा then delete
  "mt-prep-form", # can delete
  "nb-noun-form-def-gen", # can delete
  "nb-noun-form-def-gen-pl", # can delete
  "nb-noun-form-indef-gen-pl", # can delete
  "ofs-nom form of", # can delete
  "osx-nom form of", # can delete
  "pt-adv form of", # can delete
  "pt-article form of", # can delete
  "pt-cardinal form of", # can delete
  "pt-ordinal form", # can delete
  "pt-ordinal def", # can delete
  "ro-adj-form of", # can delete
  "ro-form-adj", # can delete
  "ro-form-noun", # can delete
  "ro-form-verb", # can deprecate
  "roa-opt-noun plural of", # can delete
  "sh-form-noun", # can delete
  "sh-form-proper-noun", # can delete
  "sh-verb form of", # can delete
  "sh-form-verb", # can delete
  "sl-form-adj", # can delete
  "sl-form-noun", # can delete
  "sl-form-verb", # can delete
  "sl-verb form of", # can delete
  "tg-form-verb", # can delete
  "ur-form-adj", # can delete
  "ur-form-noun", # can delete
  "ur-form-verb", # can delete
]

round_2_templates = [
  "bg-adj form of", # deleted
  "bg-noun form of", # deleted
  "blk-past of", # deleted
  "br-noun-plural", # deleted
  "ca-adj form of", # deleted
  "ca-form of", # 95 uses, can delete after handling {{ca-val}} uses
  "de-form-adj", # deleted
  "el-form-of-verb",
  "el-verb form of",
  "en-simple past of", # in RFDO
  "enm-first-person singular of", # deleted
  "enm-first/third-person singular past of", # deleted
  "enm-inflected form of", # deleted
  "enm-plural of", # deleted
  "enm-plural past of", # deleted
  "enm-plural subjunctive of", # deleted
  "enm-plural subjunctive past of", # deleted
  "enm-second-person singular of", # deleted
  "enm-second-person singular past of", # deleted
  "enm-singular subjunctive of", # deleted
  "enm-singular subjunctive past of", # deleted
  "enm-third-person singular of", # deleted
  "es-adj form of", # deprecated
  "et-participle of", # 13 uses
  "et-verb form of", # ~ 180 uses
  "fa-adj form of", # deleted
  "fa-adj-form", # deleted
  "fi-verb form of", # deprecated
  "got-verb form of", # deprecated
  "hi-form-verb", # deleted
  "hu-inflection of", # deprecated
  "hu-participle", # deprecated
  "it-adj form of", # deprecated
  "ja-past of verb", # 17 uses
  "ja-te form of verb", # 5 uses
  "liv-conjugation of", # deleted
  "liv-participle of", # 61 uses
  "lt-būdinys", # deleted
  "lt-budinys", # deleted
  "lt-dalyvis-1", # deleted
  "lt-dalyvis", # deprecated
  "lt-dalyvis-2", # deleted
  "lt-form-adj", # deprecated
  "lt-form-part", # deprecated
  "lt-form-pronoun", # deleted
  "lt-padalyvis", # deleted
  "lt-pusdalyvis", # deleted
  "lv-comparative of", # deprecated
  "lv-negative of", # deleted
  "lv-reflexive of", # deleted
  "lv-superlative of", # deleted
  "mhr-inflection of", # 280 uses
  "pt-adj form of", # deprecated
  "pt-noun form of", # deprecated
  "sa-desiderative of", # 7 uses
  "sa-desi", # redirect to 'sa-desiderative of'
  "sa-frequentative of", # 4 uses
  "sa-freq",# redirect to 'sa-frequentative of'
  "sa-root form of", # deleted
  "sco-simple past of", # 20 uses
  "sco-past of", # 86 uses
  "sco-third-person singular of", # 95 uses
  "sga-verbnec of", # 9 uses
  "sl-participle of", # deleted
  "sv-adj-form-abs-def", # deleted
  "sv-adj-form-abs-def+pl", # deprecated
  "sv-adj-form-abs-def-m", # deprecated
  "sv-adj-form-abs-indef-n", # deprecated
  "sv-adj-form-abs-pl", # deleted
  "sv-adj-form-comp", # deleted
  "sv-adj-form-sup-attr", # deleted
  "sv-adj-form-sup-attr-m", # deleted
  "sv-adj-form-sup-pred", # deleted
  "sv-adv-form-comp", # deleted
  "sv-adv-form-sup", # deleted
  "sv-noun-form-def", # deprecated
  "sv-noun-form-def-gen", # deprecated
  "sv-noun-form-def-gen-pl", # deprecated
  "sv-noun-form-def-pl", # deprecated
  "sv-noun-form-indef-gen", # deprecated
  "sv-noun-form-indef-gen-pl", # deprecated
  "sv-noun-form-indef-pl", # deprecated
  "sv-proper-noun-gen", # deleted
  "sv-verb-form-imp", # deprecated
  "sv-verb-form-inf-pass", # deprecated
  "sv-verb-form-past", # deprecated
  "sv-verb-form-past-pass", # deprecated
  "sv-verb-form-pastpart", # deprecated
  "sv-verb-form-pre", # deprecated
  "sv-verb-form-pre-pass", # deprecated
  "sv-verb-form-prepart", # deprecated
  "sv-verb-form-subjunctive", # deleted
  "sv-verb-form-sup", # deprecated
  "sv-verb-form-sup-pass", # deprecated
  "tg-adj form of", # deleted
  "tg-adj-form", # deleted
  "tl-verb form of", # deleted
  "tr-inflection of", # deleted
]

zh_templates_under_1000 = [
  "zh-cls",
  "zh-con",
  "zh-det",
  "zh-infix",
  "zh-interj",
  "zh-inter",
  "zh-num",
  "zh-particle",
  "zh-phrase",
  "zh-post",
  "zh-pref",
  "zh-prep",
  "zh-pronoun",
  "zh-proverb",
  "zh-punctuation mark",
  "zh-suf",
]

zh_templates_1000_and_over = [
  "zh-adj",
  "zh-adjective",
  "zh-adv",
  "zh-adverb",
  "zh-hanzi",
  "zh-idiom",
  "zh-noun",
  "zh-proper noun",
  "zh-proper",
  "zh-propn",
  "zh-verb",
]

#templates_to_actually_do = round_1_templates
templates_to_actually_do = zh_templates_under_1000

# List of templates and their behavior w.r.t. initial caps and/or final period. One of the following:
#
# 1. "lcnodot": Original template doesn't have initial caps or final period; nor does the replacement.
# 2. "ucdot": Original template has initial caps and final period (possibly controllable, mostly not); our replacement
#    also has initial caps and final period, controllable.
# 3. "ignoreduc": Original template has initial caps (usually automatic, very occasionally controllable) but no final
#    period; our replacement doesn't have initial caps. Need to verify that this works.
# 4. "ignoreddot": Original template has final period (usually automatic, very occasionally controllable) but no initial
#    caps; our replacement doesn't have final period. Need to verify that this works.
# 5. "ignoreducdot": Original template has final period (usually automatic, very occasionally controllable) and initial
#    caps; our replacement doesn't have either.
templates_by_cap_and_period = [
  ("blk-past of", "lcnodot", False),
  ("bg-adj form of", "ignoreducdot", "verified"),
  ("bg-noun form of", "ignoreducdot", "verified"),
  # The following instances need to be fixed up:
  # Page 30113 нямало: WARNING: Found form-of template with pre-text: # ''[[neuter]]'' {{bg-verb form of|person=third|number=singular|tense=imperfect|mood=renarrative|verb=нямам}}
  # Page 30113 нямало: WARNING: Found form-of template with pre-text: # ''[[neuter]]'' {{bg-verb form of|person=third|number=singular|tense=aorist|mood=renarrative|verb=нямам}}
  ("bg-verb form of", "ignoreducdot", "verified"), # (all 30,114)
  ("br-noun-plural", "ignoreducdot", "verified"),
  ("ca-adj form of", "ignoreducdot", "verified"),
  ("ca-form of", "lcnodot", False),
  ("ca-verb form of", "lcnodot", False),
  ("cu-form of", "ignoreducdot", "verified"),
  ("da-pl-genitive", "lcnodot", False),
  ("de-du contraction", "ignoreduc", "verified"),
  ("de-form-adj", "ignoreddot", "verified"),
  ("de-form-noun", "lcnodot", False),
  # The following instances need to be fixed up:
  # Page 1091 abarbeitet: WARNING: Found form-of template with post-text: # {{de-verb form of|abarbeiten|3|s|g}} Used in side clauses where usually separable prefixes do not separate
  # Page 8835 geschmolzen: WARNING: Found form-of template with post-text: # {{de-verb form of|schmelzen|pp}} - [[melted]]
  # Page 36459 frägst: WARNING: Found form-of template with pre-text: # ({{de-verb form of|fragen|2|s|g}}
  # Page 41308 wend ab: WARNING: Found form-of template with post-text: # {{de-verb form of|abwenden|3|p|v}}# {{de-verb form of|abwenden|2|p|v}}# {{de-verb form of|abwenden|i|s}}
  # Page 41318 wandtest an: WARNING: Found form-of template with pre-text: # {{de-verb form of|anwenden|3|s|v}}# {{de-verb form of|anwenden|2|s|v}}
  # Page 41320 wandtet an: WARNING: Found form-of template with pre-text: # {{de-verb form of|anwenden|3|p|v}}# {{de-verb form of|anwenden|2|p|v}}
  # Page 41321 wend an: WARNING: Found form-of template with post-text: # {{de-verb form of|anwenden|3|p|v}}# {{de-verb form of|anwenden|2|p|v}}# {{de-verb form of|anwenden|i|s}}
  # Page 41331 wandtest auf: WARNING: Found form-of template with post-text: # {{de-verb form of|aufwenden|3|s|v}}# {{de-verb form of|aufwenden|2|s|v}}
  # Page 41333 wandtet auf: WARNING: Found form-of template with post-text: # {{de-verb form of|aufwenden|3|p|v}}# {{de-verb form of|aufwenden|2|p|v}}
  # Page 41334 wend auf: WARNING: Found form-of template with post-text: # {{de-verb form of|aufwenden|3|p|v}}# {{de-verb form of|aufwenden|2|p|v}}# {{de-verb form of|aufwenden|i|s}}
  # Page 41344 wandtest ein: WARNING: Found form-of template with post-text: # {{de-verb form of|einwenden|3|s|v}}# {{de-verb form of|einwenden|2|s|v}}
  # Page 41346 wandtet ein: WARNING: Found form-of template with post-text: # {{de-verb form of|einwenden|3|p|v}}# {{de-verb form of|einwenden|2|p|v}}
  # Page 41347 wend ein: WARNING: Found form-of template with post-text: # {{de-verb form of|einwenden|3|p|v}}# {{de-verb form of|einwenden|2|p|v}}# {{de-verb form of|einwenden|i|s}}
  # Page 41357 wandtest zurück: WARNING: Found form-of template with post-text: # {{de-verb form of|zurückwenden|3|s|v}}# {{de-verb form of|zurückwenden|2|s|v}}
  # Page 41359 wandtet zurück: WARNING: Found form-of template with post-text: # {{de-verb form of|zurückwenden|3|p|v}}# {{de-verb form of|zurückwenden|2|p|v}}
  # Page 41360 wend zurück: WARNING: Found form-of template with post-text: # {{de-verb form of|zurückwenden|3|p|v}}# {{de-verb form of|zurückwenden|2|p|v}}# {{de-verb form of|zurückwenden|i|s}}
  # Page 46685 biß: WARNING: Found form-of template with post-text: # {{de-verb form of|beißen|1|s|v}} {{de-superseded spelling of|biss|used=pre-1996}}
  # Page 46685 biß: WARNING: Found form-of template with post-text: # {{de-verb form of|beißen|3|s|v}} {{de-superseded spelling of|biss|used=pre-1996}}
  # Page 53520 solst: WARNING: Found form-of template with post-text: # {{de-verb form of|sollen|2|s|g|nodot=1}} {{obsolete form of|sollst|lang=de}} {{defdate|at least since the second half of the 18th century}}
  # Page 54327 wandtest um: WARNING: Found form-of template with post-text: # {{de-verb form of|umwenden|3|s|v}}# {{de-verb form of|umwenden|2|s|v}}
  # Page 54329 wandtet um: WARNING: Found form-of template with post-text: # {{de-verb form of|umwenden|3|p|v}}# {{de-verb form of|umwenden|2|p|v}}
  # Page 54330 wend um: WARNING: Found form-of template with post-text: # {{de-verb form of|umwenden|3|p|v}}# {{de-verb form of|umwenden|2|p|v}}# {{de-verb form of|umwenden|i|s}}
  # Page 54340 wandtest zu: WARNING: Found form-of template with post-text: # {{de-verb form of|zuwenden|3|s|v}}# {{de-verb form of|zuwenden|2|s|v}}
  # Page 54342 wandtet zu: WARNING: Found form-of template with post-text: # {{de-verb form of|zuwenden|3|p|v}}# {{de-verb form of|zuwenden|2|p|v}}
  # Page 54343 wend zu: WARNING: Found form-of template with post-text: # {{de-verb form of|zuwenden|3|p|v}}# {{de-verb form of|zuwenden|2|p|v}}# {{de-verb form of|zuwenden|i|s}}
  ("de-verb form of", "ignoreucdot", "verified"), # All 54,762 verified
  ("el-form-of-adv", "ignoreduc", "verified"),
  # The following instances need to be fixed up:
  # (all instances with a final period, which needs to be removed)
  # Page 105 ον: WARNING: Found form-of template with post-text: # {{lb|el|dated}} {{el-form-of-nounadj|ων|g=n|n=s|c=nav}} “being”
  # Page 109 αδελφών: WARNING: Found form-of template with post-text: # {{el-form-of-nounadj|αδελφός|c=gen|n=p}} {{g|m}}
  # Page 109 αδελφών: WARNING: Found form-of template with post-text: # {{el-form-of-nounadj|αδελφή|c=gen|n=p}} {{g|f}}
  # Page 968 αγγουριών: WARNING: Found form-of template with pre-text and post-text: # {{qualifier|neuter}} {{el-form-of-nounadj|αγγούρι|c=gen|n=p|nodot=1}} [[cucumber]].
  # Page 968 αγγουριών: WARNING: Found form-of template with pre-text and post-text: # {{qualifier|feminine}} {{el-form-of-nounadj|αγγουριά|c=gen|n=p|nodot=1}} [[cucumber]] [[plant]].
  # Page 4120 μετρητών: WARNING: Found form-of template with pre-text and post-text: # {{qf|neuter}} {{el-form-of-nounadj|μετρητά|c=gen|n=p|nodot=1}} [[cash]]
  # Page 4120 μετρητών: WARNING: Found form-of template with pre-text and post-text: # {{qf|masculine}} {{el-form-of-nounadj|μετρητής|c=gen|n=p|nodot=1}} [[meter]]
  # Page 5363 σαρκοφάγου: WARNING: Found form-of template with post-text: # {{el-form-of-nounadj|σαρκοφάγος|c=gen|n=s|nodot=1}} {{sense|feminine}} [[sarcophagus]]
  # Page 5363 σαρκοφάγου: WARNING: Found form-of template with post-text: # {{el-form-of-nounadj|σαρκοφάγος|c=gen|n=s|nodot=1}} {{sense|common gender}} [[carnivore]]
  # Page 5363 σαρκοφάγου: WARNING: Found form-of template with post-text: # {{el-form-of-nounadj|σαρκοφάγος|c=gen|n=s|nodot=1}} {{sense|feminine}} [[sarcophagus]]
  # Page 5363 σαρκοφάγου: WARNING: Found form-of template with post-text: # {{el-form-of-nounadj|σαρκοφάγος|c=gen|n=s|nodot=1}} {{sense|common gender}} [[carnivore]]
  # Page 5364 σαρκοφάγων: WARNING: Found form-of template with post-text: # {{el-form-of-nounadj|σαρκοφάγος|c=gen|n=p|nodot=1}} {{sense|feminine}} [[sarcophagus]]
  # Page 5364 σαρκοφάγων: WARNING: Found form-of template with post-text: # {{el-form-of-nounadj|σαρκοφάγος|c=gen|n=p|nodot=1}} {{sense|common gender}} [[carnivore]]
  # Page 5364 σαρκοφάγων: WARNING: Found form-of template with post-text: # {{el-form-of-nounadj|σαρκοφάγος|c=gen|n=p|nodot=1}} {{sense|feminine}} [[sarcophagus]]
  # Page 5364 σαρκοφάγων: WARNING: Found form-of template with post-text: # {{el-form-of-nounadj|σαρκοφάγος|c=gen|n=p|nodot=1}} {{sense|common gender}} [[carnivore]]
  # Page 5365 σαρκοφάγοι: WARNING: Found form-of template with post-text: # {{el-form-of-nounadj|σαρκοφάγος|c=nom|n=p|nodot=1}} {{sense|feminine}} [[sarcophagus]]
  # Page 5365 σαρκοφάγοι: WARNING: Found form-of template with post-text: # {{el-form-of-nounadj|σαρκοφάγος|c=nom|n=p|nodot=1}} {{sense|common gender}} [[carnivore]]
  # Page 5365 σαρκοφάγοι: WARNING: Found form-of template with post-text: # {{el-form-of-nounadj|σαρκοφάγος|c=voc|n=p|nodot=1}} {{sense|feminine}} [[sarcophagus]]
  # Page 5365 σαρκοφάγοι: WARNING: Found form-of template with post-text: # {{el-form-of-nounadj|σαρκοφάγος|c=voc|n=p|nodot=1}} {{sense|common gender}} [[carnivore]]
  # Page 5365 σαρκοφάγοι: WARNING: Found form-of template with post-text: # {{el-form-of-nounadj|σαρκοφάγος|c=nom|n=p|nodot=1}} {{sense|feminine}} [[sarcophagus]]
  # Page 5365 σαρκοφάγοι: WARNING: Found form-of template with post-text: # {{el-form-of-nounadj|σαρκοφάγος|c=nom|n=p|nodot=1}} {{sense|common gender}} [[carnivore]]
  # Page 5365 σαρκοφάγοι: WARNING: Found form-of template with post-text: # {{el-form-of-nounadj|σαρκοφάγος|c=voc|n=p|nodot=1}} {{sense|feminine}} [[sarcophagus]]
  # Page 5365 σαρκοφάγοι: WARNING: Found form-of template with post-text: # {{el-form-of-nounadj|σαρκοφάγος|c=voc|n=p|nodot=1}} {{sense|common gender}} [[carnivore]]
  # Page 5366 σαρκοφάγους: WARNING: Found form-of template with post-text: # {{el-form-of-nounadj|σαρκοφάγος|c=acc|n=p|nodot=1}} {{sense|feminine}} [[sarcophagus]]
  # Page 5366 σαρκοφάγους: WARNING: Found form-of template with post-text: # {{el-form-of-nounadj|σαρκοφάγος|c=acc|n=p|nodot=1}} {{sense|common gender}} [[carnivore]]
  # Page 5366 σαρκοφάγους: WARNING: Found form-of template with post-text: # {{el-form-of-nounadj|σαρκοφάγος|c=acc|n=p|nodot=1}} {{sense|feminine}} [[sarcophagus]]
  # Page 5366 σαρκοφάγους: WARNING: Found form-of template with post-text: # {{el-form-of-nounadj|σαρκοφάγος|c=acc|n=p|nodot=1}} {{sense|common gender}} [[carnivore]]
  # Page 5367 σαρκοφάγο: WARNING: Found form-of template with post-text: # {{el-form-of-nounadj|σαρκοφάγος|c=acc|n=s|nodot=1}} {{sense|feminine}} [[sarcophagus]]
  # Page 5367 σαρκοφάγο: WARNING: Found form-of template with post-text: # {{el-form-of-nounadj|σαρκοφάγος|c=acc|n=s|nodot=1}} {{sense|common gender}} [[carnivore]]
  # Page 5367 σαρκοφάγο: WARNING: Found form-of template with post-text: # {{el-form-of-nounadj|σαρκοφάγος|c=acc|n=s|nodot=1}} {{sense|feminine}} [[sarcophagus]]
  # Page 5367 σαρκοφάγο: WARNING: Found form-of template with post-text: # {{el-form-of-nounadj|σαρκοφάγος|c=acc|n=s|nodot=1}} {{sense|common gender}} [[carnivore]]
  # Page 5368 σαρκοφάγε: WARNING: Found form-of template with post-text: # {{el-form-of-nounadj|σαρκοφάγος|c=voc|n=s|nodot=1}} {{sense|feminine}} [[sarcophagus]]
  # Page 5368 σαρκοφάγε: WARNING: Found form-of template with post-text: # {{el-form-of-nounadj|σαρκοφάγος|c=voc|n=s|nodot=1}} {{sense|common gender}} [[carnivore]]
  # Page 5368 σαρκοφάγε: WARNING: Found form-of template with post-text: # {{el-form-of-nounadj|σαρκοφάγος|c=voc|n=s|nodot=1}} {{sense|feminine}} [[sarcophagus]]
  # Page 5368 σαρκοφάγε: WARNING: Found form-of template with post-text: # {{el-form-of-nounadj|σαρκοφάγος|c=voc|n=s|nodot=1}} {{sense|common gender}} [[carnivore]]
  # Page 5585 πατατάκια: WARNING: Found form-of template with post-text: # {{el-form-of-nounadj|πατατάκι|c=nom|n=p|nodot=1}}, [[potato]] [[crisps]]{{qualifier|UK}}, [[potato]] [[chips]] {{qualifier|US}}.
  # Page 11518 άγια: WARNING: Found form-of template not on definition line: * {{el-form-of-nounadj|άγιο|n=p|c=nav}}
  # Page 12237 πεζά γράμματα: WARNING: Found form-of template with post-text: # {{el-form-of-nounadj|πεζό γράμμα|n=p|nodot=1}} [[small]] or [[lowercase]] [[letters]]
  # Page 12238 μικρά γράμματα: WARNING: Found form-of template with post-text: # {{el-form-of-nounadj|μικρό γράμμα|n=p|nodot=1}} [[small]] or [[lowercase]] [[letters]]
  # Page 12239 κεφαλαία γράμματα: WARNING: Found form-of template with post-text: # {{el-form-of-nounadj|κεφαλαίο γράμμα|n=p|nodot=1}} [[capital]] or [[uppercase]] [[letters]]
  # Page 12674 φφ.: WARNING: Found form-of template with post-text: # {{el-form-of-nounadj|φ.|n=p|nodot=1}} [[pages]], [[sheets]]
  # Page 13173 αγίας: WARNING: Found form-of template not on definition line: * {{el-form-of-nounadj|άγιος|g=f|n=s|c=g}}
  # Page 13173 αγίας: WARNING: Found form-of template not on definition line: * {{el-form-of-nounadj|αγία|n=s|c=g}}
  # Page 13660 αγυιοπαίδου: WARNING: Found form-of template with pre-text: # {{q|masculine}} {{misconstruction of|lang=el|αγυιόπαιδος}} {{el-form-of-nounadj|αγυιόπαις|n=s|c=g}}
  # Page 13660 αγυιοπαίδου: WARNING: Found form-of template with pre-text: # {{q|neuter}} {{misconstruction of|lang=el|αγυιόπαιδου}} {{el-form-of-nounadj|αγυιόπαιδο|n=s|c=g}}
  # Page 16175 Ἀθήναις: WARNING: Found form-of template with post-text: # {{lb|el|Katharevousa}} {{el-form-of-nounadj|Αθήναι|c=dat|n=p}} {{el-polytonic form of|nocap=1|Αθήναις}}
  # Page 16624 γενικότερα: WARNING: Found form-of template not on definition line: {{el-form-of-nounadj|γενικός|d=c|c=nav|g=n|n=p}}
  # Page 17497 ἀρετῆς: WARNING: Found form-of template with pre-text: # {{el-polytonic form of|αρετή}} {{el-form-of-nounadj|ἀρετή|n=s|c=g}}
  # Page 18220 άγιες: WARNING: Found form-of template not on definition line: * {{el-form-of-nounadj|αγία|n=p|c=nav}}
  # Page 22393 γάϊδαρε: WARNING: Found form-of template with pre-text: # {{misspelling of|γάιδαρε|lang=el}} {{el-form-of-nounadj|γάιδαρος|c=voc|n=s}}
  # Page 22394 γάϊδαρο: WARNING: Found form-of template with pre-text: # {{misspelling of|γάιδαρο|lang=el}} {{el-form-of-nounadj|γάιδαρος|c=acc|n=s}}
  # Page 22395 γάϊδαροι: WARNING: Found form-of template with pre-text: # {{misspelling of|γάιδαροι|lang=el}} {{el-form-of-nounadj|γάιδαρος|c=nv|n=p}}
  # Page 24219 ακουομέτρου: WARNING: Found form-of template with pre-text: # {{misconstruction of|lang=el|ακοομέτρου}} {{el-form-of-nounadj|ακοόμετρο|n=s|c=g}}
  # Page 24220 ακουομέτρων: WARNING: Found form-of template with pre-text: # {{misconstruction of|lang=el|ακοομέτρων}}  {{el-form-of-nounadj|ακοόμετρο|n=p|c=g}}
  # Page 24221 ακουόμετρα: WARNING: Found form-of template with pre-text: # {{misconstruction of|lang=el|ακοόμετρα}}  {{el-form-of-nounadj|ακοόμετρο|c=nav|n=p}}
  # Page 24222 ακουογραμμάτων: WARNING: Found form-of template with pre-text: # {{misconstruction of|lang=el|ακοογραμμάτων}}  {{el-form-of-nounadj|ακοόγραμμα|c=gen|n=p}}
  # Page 24223 ακουογράμματα: WARNING: Found form-of template with pre-text: # {{misconstruction of|lang=el|ακοογράμματα}}  {{el-form-of-nounadj|ακοόγραμμα|c=nav|n=p}}
  # Page 24224 ακουογράμματος: WARNING: Found form-of template with pre-text: # {{misconstruction of|lang=el|ακοογράμματος}} {{el-form-of-nounadj|ακοόγραμμα|c=gen|n=s}}
  # Page 24225 ακουομέτρησης: WARNING: Found form-of template with pre-text: # {{misconstruction of|lang=el|ακοομέτρησης}} {{el-form-of-nounadj|ακοομέτρηση|c=gen|n=s}}
  # Page 24227 ακουομετρήσεως: WARNING: Found form-of template with pre-text: # {{misconstruction of|lang=el|ακοομετρήσεως}} {{el-form-of-nounadj|ακοομέτρηση|c=gen|n=s}}
  # Page 24229 ακουομετρήσεων: WARNING: Found form-of template with pre-text: # {{misconstruction of|lang=el|ακοομετρήσεων}} {{el-form-of-nounadj|ακοομέτρηση|c=gen|n=p}}
  # Page 24231 ακουομετρήσεις: WARNING: Found form-of template with pre-text: # {{misconstruction of|lang=el|ακοομετρήσεις}} {{el-form-of-nounadj|ακοομέτρηση|c=nav|n=p}}
  # Page 24236 ακουομετρών: WARNING: Found form-of template with pre-text: # {{misconstruction of|lang=el|ακοομετρών}}  {{el-form-of-nounadj|ακοομέτρης|c=gen|n=p}}
  # Page 24237 ακουομέτρες: WARNING: Found form-of template with pre-text: # {{misconstruction of|lang=el|ακοομέτρες}} {{el-form-of-nounadj|ακοομέτρης|c=nav|n=p}}
  # Page 24238 ακουομέτρη: WARNING: Found form-of template with pre-text: # {{misconstruction of|lang=el|ακοομέτρη}} {{el-form-of-nounadj|ακοομέτρης|c=gav|n=s}}
  # Page 24239 ακουομετρίας: WARNING: Found form-of template with pre-text: # {{misconstruction of|lang=el|ακοομετρίας}} {{el-form-of-nounadj|ακοομετρία|c=gen|n=s}}
  # Page 25215 ζα: WARNING: Found form-of template with post-text: # {{lb|el|vernacular}} {{el-form-of-nounadj|ζώο|c=nom|n=p}} {{alternative form of|ζώα||lang=el}} {{qualifier|[[animal]]s}}
  # Page 27176 ους: WARNING: Found form-of template with pre-text: # {{q|monotonic spelling of}} {{m|grc|οὕς|t=them}} {{el-form-of-nounadj|ὅς|g=m|c=acc|n=p}}
  # Page 27822 ηγουμένες: WARNING: Found form-of template with pre-text: # {{form of|Incorrectly accented form|ηγούμενες|lang=el}}: {{el-form-of-nounadj|ηγουμένη|n=p|c=nav}}
  # Page 28418 τούτοις: WARNING: Found form-of template with pre-text: # {{q|learned, dated, [[Katharevousa]]}} ''[[dative]]''{{el-form-of-nounadj|τούτος|g=mn|c=d|n=s}}
  # Page 28683 ηλικιωμένη: WARNING: Found form-of template not on definition line: * {{el-form-of-nounadj|ηλικιωμένος|g=f|n=s|c=nav}}
  # Page 29501 μπουγάζι: WARNING: Found form-of template not on definition line: : {{el-form-of-nounadj|μπουγάζι|n=s|c=nav}}
  # Page 29629 ευσεβέστατα: WARNING: Found form-of template with post-text: # {{el-form-of-nounadj|ευσεβής|d=as|g=n|n=p|c=nav}} ''Of adjective'' [[ευσεβής]]
  # Page 29633 Αγία: WARNING: Found form-of template not on definition line: * {{el-form-of-nounadj|Άγιος|g=f|n=s|c=nav}}
  # Page 29634 Άγιο: WARNING: Found form-of template not on definition line: * {{el-form-of-nounadj|Άγιος|g=n|n=s|c=nav}}
  # Page 29635 Αγίου: WARNING: Found form-of template not on definition line: * {{el-form-of-nounadj|Άγιος|g=mn|n=s|c=g}}
  # Page 29636 Άγιε: WARNING: Found form-of template not on definition line: * {{el-form-of-nounadj|Άγιος|g=m|n=s|c=v}}
  # Page 29637 Αγίας: WARNING: Found form-of template not on definition line: * {{el-form-of-nounadj|Άγιος|g=f|n=s|c=g}}
  # Page 29638 Άγιοι: WARNING: Found form-of template not on definition line: * {{el-form-of-nounadj|Άγιος|g=m|n=p|c=nv}}
  # Page 29639 Αγίων: WARNING: Found form-of template not on definition line: * {{el-form-of-nounadj|Άγιος|g=mnf|n=p|c=g}}
  # Page 29640 Αγίους: WARNING: Found form-of template not on definition line: * {{el-form-of-nounadj|Άγιος|g=m|n=p|c=a}}
  # Page 29641 Άγιες: WARNING: Found form-of template not on definition line: * {{el-form-of-nounadj|Άγιος|g=f|n=p|c=nav}}
  # Page 29642 Άγια: WARNING: Found form-of template not on definition line: * {{el-form-of-nounadj|Άγιος|g=n|n=p|c=nav}}
  # Page 29697 Κωσταντίνας: WARNING: Found form-of template with pre-text and post-text: # {{alternative form of|lang=el|Κωνσταντίνας}}, {{el-form-of-nounadj|Κωνσταντίνα|n=s|c=g}} [[Constantina]] pronounced without nu (ν)
  # Page 29698 Κωσταντίνου: WARNING: Found form-of template with pre-text and post-text: # {{alternative form of|lang=el|Κωνσταντίνου}}, {{el-form-of-nounadj|Κωνσταντίνος|n=s|c=g}} [[Constantine]] pronounced without nu (ν)
  # Page 29699 Κωσταντίνο: WARNING: Found form-of template with pre-text and post-text: # {{alternative form of|lang=el|Κωνσταντίνο}}, {{el-form-of-nounadj|Κωνσταντίνος|n=s|c=a}} [[Constantine]] pronounced without nu (ν)
  # Page 29700 Κωσταντίνε: WARNING: Found form-of template with pre-text and post-text: # {{alternative form of|lang=el|Κωνσταντίνε}}, {{el-form-of-nounadj|Κωνσταντίνος|n=s|c=v}} [[Constantine]] pronounced without nu (ν)
  # Page 29884 σοφότερου: WARNING: Found form-of template with post-text: # {{el-form-of-nounadj|σοφότερος|g=mn|n=s|c=g}}, {{comparative of|lang=el|σοφός}}
  # Page 29946 ἀρχαΐζουσα: WARNING: Found form-of template with pre-text: # {{el-polytonic form of|αρχαΐζουσα}} - {{el-form-of-nounadj|ἀρχαΐζων|g=f|n=s|c=nav}}
  # Page 29947 ἀττικίζων: WARNING: Found form-of template with pre-text: # {{el-polytonic form of|αττικίζων}} - {{el-form-of-nounadj|ἀττῐκῐ́ζων|g=n|n=s|c=nav}}
  # Page 29948 ἀττικίζουσα: WARNING: Found form-of template with pre-text: # {{el-polytonic form of|αττικίζουσα}} - {{el-form-of-nounadj|ἀττικίζων|g=f|n=s|c=nav}}
  # Page 29949 ἀττικίζον: WARNING: Found form-of template with pre-text: # {{el-polytonic form of|αττικίζον}} - {{el-form-of-nounadj|ἀττικίζων|g=n|n=s|c=nav}}
  # Page 29950 κοινολέκτου: WARNING: Found form-of template with post-text: # {{el-form-of-nounadj|κοινόλεκτος|n=s|c=g}} [[της]] κοινολέκτου
  # Page 29951 κοινόλεκτο: WARNING: Found form-of template with post-text: # {{el-form-of-nounadj|κοινόλεκτος|n=s|c=a}} [[την]] κοινολέκτο
  # Page 29964 καλομοίρα: WARNING: Found form-of template not on definition line: * {{el-form-of-nounadj|καλομοίρης|g=f|n=s|c=nav}}
  # Page 31196 σοφιών: WARNING: Found form-of template with post-text: # {{lb|el|uncommon}} {{el-form-of-nounadj|σοφία|n=p|c=g}} chiefly found in compounds ({{m|el|φιλοσοφιών}})
  # Page 31463 ἤπια: WARNING: Found form-of template with pre-text: # {{el-polytonic form of|ήπια}}. {{el-form-of-nounadj|ήπιος|g=n|c=nav|n=p}}
  ("el-form-of-nounadj", "ignoreducdot", "verified"), # All 31,580 verified
  ("el-form-of-pronoun", "ignoreducdot", "verified"),
  # The following instances need to be fixed up:
  # Page 302 κόλλησα: WARNING: Found form-of template with post-text: # {{el-form-of-verb|κολλώ|pers=1s|tense=past}} "I glued"
  # Page 375 ήπια: WARNING: Found form-of template with post-text: # {{el-form-of-verb|πίνω|pers=1s|tense=past}} "I drank"
  # Page 497 ψόφησα: WARNING: Found form-of template with post-text: # {{el-form-of-verb|ψοφάω|pers=1s|tense=past|nodot=1}}- '''[[ψοφώ]]'''.
  # Page 501 μπορεί: WARNING: Found form-of template not on definition line: {{el-form-of-verb|μπορώ|pers=3s|tense=pres}}
  # Page 1297 ψόφησες: WARNING: Found form-of template with post-text: # {{el-form-of-verb|ψοφάω|pers=2s|tense=past|nodot=1}}- '''[[ψοφώ]]'''.
  # Page 1298 ψόφησε: WARNING: Found form-of template with post-text: # {{el-form-of-verb|ψοφάω|pers=3s|tense=past|nodot=1}}- '''[[ψοφώ]]'''.
  # Page 1298 ψόφησε: WARNING: Found form-of template with post-text: # {{el-form-of-verb|ψοφάω|pers=2s|tense=past|mood=imptv|nodot=1}}- '''[[ψοφώ]]'''.
  # Page 1299 ψοφήσαμε: WARNING: Found form-of template with post-text: # {{el-form-of-verb|ψοφάω|pers=1p|tense=past|nodot=1}}- '''[[ψοφώ]]'''.
  # Page 1300 ψοφήσατε: WARNING: Found form-of template with post-text: # {{el-form-of-verb|ψοφάω|pers=2p|tense=past|nodot=1}}- '''[[ψοφώ]]'''.
  # Page 1301 ψόφησαν: WARNING: Found form-of template with post-text: # {{el-form-of-verb|ψοφάω|pers=3p|tense=past|nodot=1}}- '''[[ψοφώ]]'''.
  # Page 1317 έβλαψα: WARNING: Found form-of template with post-text: # {{el-form-of-verb|βλάπτω|pers=1s|tense=past}} & '''[[βλάφτω#Greek|βλάφτω]]''' (''<U+200E>vláfto<U+200E>'')
  # Page 1389 αδικήθηκα: WARNING: Found form-of template with post-text: # {{el-form-of-verb|αδικούμαι|pers=1s|tense=past}} ''or'' '''[[αδικιέμαι]]'''
  # Page 1751 χαίρετε: WARNING: Found form-of template with post-text: # {{el-form-of-verb|χαίρω|pers=2p|mood=imptv-i}}: (''literally'': "rejoice, be glad") 
  # Page 1786 ασκήθηκα: WARNING: Found form-of template with post-text: # {{el-form-of-verb|ασκούμαι|pers=1s|tense=past}} ''passive of'' '''[[ασκώ]]'''
  # Page 1978 αποκλείεται: WARNING: Found form-of template with post-text: # {{el-form-of-verb|αποκλείομαι|pers=3s|tense=present|active=αποκλείω}} "He/she/it is blocked, excluded"
  # Page 2057 κρεμιέμαι: WARNING: Found form-of template with post-text: # {{el-form-of-verb|κρεμώ|voice=pass}} ''and'' '''[[κρεμάω]]''': "I am hung, I hung"
  # Page 2114 έχεσα: WARNING: Found form-of template with post-text: # {{el-form-of-verb|χέζω|pers=1s|tense=past}} ''Translation'': I [[shat]].
  # Page 2265 αγαπιόμαστε: WARNING: Found form-of template with post-text: # {{el-form-of-verb|αγαπιέμαι|pers=1p|tense=present}} we are [[loved]], we [[love]] [[one another]]
  # Page 2339 κτίζομαι: WARNING: Found form-of template with post-text: # {{el-form-of-verb|κτίζω|voice=pass|nodot=1}}, {{alternative form of|χτίζομαι|lang=el}}.
  # Page 2457 αποκλείστηκα: WARNING: Found form-of template with post-text: # {{el-form-of-verb|αποκλείομαι|pers=1s|tense=past|active=αποκλείω}} "I was blocked, excluded"
  # Page 2482 εκλέγομαι: WARNING: Found form-of template with post-text: # {{el-form-of-verb|εκλέγω|voice=pass}} "I am elected"
  # Page 2528 συζητήθηκα: WARNING: Found form-of template with post-text: # {{el-form-of-verb|συζητιέμαι|pers=1s|tense=past|nodot=1}}''or'' {{l|el|συζητούμαι}}
  # Page 2756 κολλήθηκα: WARNING: Found form-of template with post-text: # {{el-form-of-verb|κολλιέμαι|pers=1s|tense=past}} "I was glued"
  # Page 2931 πείσω: WARNING: Found form-of template with pre-text and post-text: # ''[[Appendix:Glossary#active voice|active]]'' {{el-form-of-verb|πείθω|pers=1s|tense=dep}}: "persuade"
  # Page 2977 απασχολήθηκα: WARNING: Found form-of template with post-text: # {{el-form-of-verb|απασχολούμαι|pers=1s|tense=past}} ''or'' '''[[απασχολιέμαι]]'''
  # Page 3642 πειράζει: WARNING: Found form-of template with post-text: # {{el-form-of-verb|πειράζω|pers=3s|tense=present}} "He/she/it bothers, teases"
  # Page 3737 πονεί: WARNING: Found form-of template with post-text: # {{lb|el|colloquial}} {{el-form-of-verb|πονάω|pers=3s|tense=pres}}: "He/She/It hurts"
  # Page 3738 πονάει: WARNING: Found form-of template with post-text: # {{el-form-of-verb|πονάω|pers=3s|tense=pres}}: "He/She/It hurts"
  # Page 4007 βλάφθηκα: WARNING: Found form-of template with post-text: # {{lb|el|formal}} {{el-form-of-verb|βλάπτομαι|pers=1s|tense=past}}, ''passive of'' '''{{l|el|βλάπτω|tr=-}}'''
  # Page 4008 βλάφτει: WARNING: Found form-of template with post-text: # {{lb|el|colloquial}} {{el-form-of-verb|βλάφτω|pers=3s|tense=pres}}: "He/She/It damages"
  # Page 4008 βλάφτει: WARNING: Found form-of template with pre-text and post-text: # {{l|el|θα}} '''{{PAGENAME}}''' {{el-form-of-verb|βλάφτω|pers=3s|tense=fut-c|tr=-}}: "He/She/It will be damaging"
  # Page 4008 βλάφτει: WARNING: Found form-of template with pre-text and post-text: # {{l|el|να}} '''{{PAGENAME}}''' {{el-form-of-verb|βλάφτω|pers=3s|mood=subj|tr=-}}: ''That he/she/it damages"
  # Page 4035 σείστηκα: WARNING: Found form-of template with post-text: # {{el-form-of-verb|σείομαι|pers=1s|tense=past|active=σείω}} "I was shaken"
  # Page 4168 ψηφίζομαι: WARNING: Found form-of template with post-text: # {{el-form-of-verb|ψηφίζω|pers=1s|mood=ind|tense=pres|voice=pass|nodot=1}} "I am voted"
  # Page 4169 ψηφίστηκα: WARNING: Found form-of template with post-text: # {{el-form-of-verb|ψηφίζομαι|pers=1s|mood=ind|tense=past|active=ψηφίζω}} "I was voted, elected"
  # Page 4171 ψηφίζουμε: WARNING: Found form-of template with post-text: # {{el-form-of-verb|ψηφίζω|pers=1p|mood=ind|tense=pres|voice=act}} "we vote"
  # Page 4228 γραδάρισα: WARNING: Found form-of template with post-text: # {{el-form-of-verb|γραδάρω|pers=1s|tense=past}}.
  # Page 4234 χαίρε: WARNING: Found form-of template with post-text: # {{el-form-of-verb|χαίρω|pers=2s|mood=imptv-i}}: (''literally'': "rejoice, be glad") 
  # Page 4355 ἐξετέλεσα: WARNING: Found form-of template with pre-text: # {{lb|el|learned|formal|nocat=1}} {{el-polytonic form of|εξετέλεσα}} {{el-form-of-verb|εκτελώ|pers=1s|tense=past}}
  # Page 4356 εκτελέστηκα: WARNING: Found form-of template with post-text: # {{el-form-of-verb|εκτελούμαι|pers=1s|tense=past}} ''passive of'' '''{{m|el|εκτελώ|tr=-}}'''
  # Page 4357 εκτελέσθηκα: WARNING: Found form-of template with post-text: # {{lb|el|formal|nocat=1}} {{el-form-of-verb|εκτελούμαι|pers=1s|tense=past}} ''passive of'' '''{{m|el|εκτελώ|tr=-}}'''
  # Page 4358 εξετελέσθην: WARNING: Found form-of template with post-text: # {{lb|el|archaic|learned|nocat=1}} {{el-form-of-verb|εκτελούμαι|pers=1s|tense=past}} ''passive of'' '''{{m|el|εκτελώ|tr=-}}'''
  # Page 4359 ἐξετελέσθην: WARNING: Found form-of template with pre-text: # {{lb|el|learned|formal|nocat=1}} {{el-polytonic form of|εξετελέσθην}} {{el-form-of-verb|εκτελούμαι|pers=1s|tense=past}}
  # Page 4378 αποκλείετε: WARNING: Found form-of template with post-text: # {{el-form-of-verb|αποκλείω|pers=2p|tense=present|mood=ind}} "You<sup>plural</sup> block, exclude"
  # Page 4378 αποκλείετε: WARNING: Found form-of template with post-text: # {{el-form-of-verb|αποκλείω|pers=2p|tense=present|mood=imptv}} "block!, exclude!"
  # Page 4381 περικλείστηκα: WARNING: Found form-of template with post-text: # {{el-form-of-verb|περικλείομαι|pers=1s|tense=past|active=περικλείω}} "I was surrounded"
  # Page 4385 εγκλείστηκα: WARNING: Found form-of template with post-text: # {{el-form-of-verb|εγκλείομαι|pers=1s|tense=past|active=εγκλείω}} "I was confined"
  # Page 4389 εσωκλείστηκα: WARNING: Found form-of template with post-text: # {{el-form-of-verb|εσωκλείομαι|pers=1s|tense=past|active=εσωκλείω}} "I was enclosed"
  # Page 4393 εμπερικλείστηκα: WARNING: Found form-of template with post-text: # {{el-form-of-verb|εμπερικλείομαι|pers=1s|tense=past|active=εμπερικλείω}} "I was contained"
  # Page 4404 επισείστηκα: WARNING: Found form-of template with post-text: # {{el-form-of-verb|επισείομαι|pers=1s|tense=past|active=επισείω}} "I was brandished as a threat"
  # Page 4405 συγκρούστηκα: WARNING: Found form-of template with post-text: # {{el-form-of-verb|συγκρούομαι|pers=1s|tense=past}} "I collided"
  # Page 4409 κρούστηκα: WARNING: Found form-of template with post-text: # {{el-form-of-verb|κρούομαι|pers=1s|tense=past|active=κρούω}} "I was struck"
  # Page 4410 ἐκρούσθην: WARNING: Found form-of template with post-text: # {{el-form-of-verb|κρούομαι|pers=1s|tense=past|active=κρούω}} "I was struck"
  # Page 4417 ανακρούστηκα: WARNING: Found form-of template with post-text: # {{el-form-of-verb|ανακρούομαι|pers=1s|tense=past|active=ανακρούω}} "I was performed" {{q|of musical piece}}
  # Page 4420 αντικρούστηκα: WARNING: Found form-of template with post-text: # {{el-form-of-verb|αντικρούομαι|pers=1s|tense=past|active=αντικρούω}} "I was rebutted"
  # Page 4446 εξυπακούεται: WARNING: Found form-of template not on definition line: {{el-form-of-verb|εξυπακούομαι|pers=3s|tense=present|nodot=1}} a verb which is in use only as {{glossary|impersonal}} in 3rd persons. From {{af|el|εξ-|υπακούω|tr1=-|tr2=-|t1=in|t2=obey}}. A {{cal|el|fr|[[être]] [[sous-entendu]]|nocap=1}}.<ref>{{R:DSMG}}</ref> The [[Hellenistic#English|Hellenistic]] [[Koine#English|Koine]] verbal adjective {{m|grc|ἐξυπᾰκουστέον}} had the sense "must be understood, must understand a word".
  # Page 4446 εξυπακούεται: WARNING: Found form-of template with post-text: {{el-form-of-verb|εξυπακούομαι|pers=3s|tense=present|nodot=1}} a verb which is in use only as {{glossary|impersonal}} in 3rd persons. From {{af|el|εξ-|υπακούω|tr1=-|tr2=-|t1=in|t2=obey}}. A {{cal|el|fr|[[être]] [[sous-entendu]]|nocap=1}}.<ref>{{R:DSMG}}</ref> The [[Hellenistic#English|Hellenistic]] [[Koine#English|Koine]] verbal adjective {{m|grc|ἐξυπᾰκουστέον}} had the sense "must be understood, must understand a word".
  # Page 4447 εξυπακούονται: WARNING: Found form-of template with post-text: # {{el-form-of-verb|εξυπακούεται|pers=1p|tense=present}} "they are [[imply|implied]], [[understood]]"
  # Page 4448 εξυπακουόταν: WARNING: Found form-of template with post-text: # {{el-form-of-verb|εξυπακούεται|pers=1s|tense=imperfect}} "He/she/it was [[imply|implied]], [[understood]]"
  # Page 4449 εξυπακούονταν: WARNING: Found form-of template with post-text: # {{el-form-of-verb|εξυπακούεται|pers=1p|tense=imperfect}} "they were [[imply|implied]], [[understood]]"
  # Page 4458 καθείλκυσα: WARNING: Found form-of template with post-text: # {{el-form-of-verb|καθελκύω|pers=1s|tense=past|nodot=1}} ''and'' '''[[καθέλκω#Greek|καθέλκω]]'''
  # Page 4466 προσελκύστηκα: WARNING: Found form-of template with post-text: # {{el-form-of-verb|προσελκύομαι|pers=1s|tense=past|active=προσελκύω}} "I was attracted"
  # Page 4467 προσελκύσθηκα: WARNING: Found form-of template with post-text: # {{el-form-of-verb|προσελκύομαι|pers=1s|tense=past|active=προσελκύω}} "I was attracted"
  # Page 4470 φωτογραφήθηκα: WARNING: Found form-of template with pre-text: # ''alternative'' {{el-form-of-verb|φωτογραφίζομαι|pers=1s|tense=past|active=φωτογραφίζω}}
  # Page 4477 αεροφωτογραφήθηκα: WARNING: Found form-of template with pre-text: # ''alternative'' {{el-form-of-verb|αεροφωτογραφίζομαι|pers=1s|tense=past|active=αεροφωτογραφίζω}}
  # Page 4489 συγκρούσθηκα: WARNING: Found form-of template with post-text: # {{lb|el|formal|nocat=1}} {{el-form-of-verb|συγκρούομαι|pers=1s|tense=past}} "I collided"
  # Page 4490 κρούσθηκα: WARNING: Found form-of template with post-text: # {{lb|el|formal|nocat=1}} {{el-form-of-verb|κρούομαι|pers=1s|tense=past|active=κρούω}} "I was struck"
  # Page 4492 αντικρούσθηκα: WARNING: Found form-of template with post-text: # {{lb|el|formal|rare|nocat=1}} {{el-form-of-verb|αντικρούομαι|pers=1s|tense=past|active=αντικρούω}} "I was rebutted"
  # Page 4494 αποκλείσθηκα: WARNING: Found form-of template with post-text: # {{lb|el|formal|rare|nocat=1}} {{el-form-of-verb|αποκλείομαι|pers=1s|tense=past|active=αποκλείω}} "I was blocked, excluded"
  # Page 4498 εγκλείσθηκα: WARNING: Found form-of template with post-text: # {{lb|el|formal|rare|nocat=1}} {{el-form-of-verb|εγκλείομαι|pers=1s|tense=past|active=εγκλείω}} "I was confined"
  # Page 4499 περικλείσθηκα: WARNING: Found form-of template with post-text: # {{lb|el|formal|nocat=1}} {{el-form-of-verb|περικλείομαι|pers=1s|tense=past|active=περικλείω}} "I was surrounded"
  # Page 4541 απόλυσα: WARNING: Found form-of template with post-text: # {{el-form-of-verb|απολύω|pers=1s|tense=past}} Used in phrase
  # Page 4555 κώλυσα: WARNING: Found form-of template with post-text: #  {{el-form-of-verb|κωλύω|pers=1s|tense=past}} "I hindered"
  # Page 4588 ἐνέγραψα: WARNING: Found form-of template with pre-text: # ''[[polytonic#English|polytonic]] script of'' '''[[ενέγραψα]]''', {{el-form-of-verb|εγγράφω|pers=1s|tense=past}}
  # Page 4591 ἐνεγράφην: WARNING: Found form-of template with pre-text and post-text: # {{lb|el|Katharevousa}} ''{{poly}}'' {{el-form-of-verb|εγγράφω|pers=1s|tense=past}} ''{{monotonic}}''   '''[[ενεγράφην]]'''
  # Page 4620 ἤγγισα: WARNING: Found form-of template with pre-text: # ''[[polytonic#English|polytonic]] script of'' '''[[ήγγισα]]''', {{el-form-of-verb|εγγίζω|pers=1s|tense=past}}
  # Page 4650 χαράζει: WARNING: Found form-of template with post-text: # {{el-form-of-verb|χαράζω|pers=3s|tense=present}} "He/she/it cuves"
  # Page 4671 συλλέγομαι: WARNING: Found form-of template with post-text: # {{el-form-of-verb|εκλέγω|voice=pass}} "I am chosen"
  # Page 4714 αξίζει: WARNING: Found form-of template with post-text: # {{el-form-of-verb|αξίζω|pers=3s|tense=present}} "he/she/it costs; he/she/it is worthy"
  ("el-form-of-verb", "ignoreducdot", "verified"), # All 4,783 verified
  # The following instances need to be fixed up:
  # Page 80 λύνομαι: WARNING: Found form-of template not on definition line: * {{el-verb form of|λύνω|pers=1s|tense=pres|mood=ind|voice=pass}}
  # Page 86 έλυσα: WARNING: Found form-of template with post-text: # {{el-verb form of|λύνω|pers=1s|tense=past|mood=ind|voice=act}} ''and of'' {{l|el|λύω}}
  # Page 87 άρχομαι: WARNING: Found form-of template not on definition line: * {{el-verb form of|άρχω|pers=1s|mood=ind|tense=pres|voice=pass}}
  # Page 90 είμεθα: WARNING: Found form-of template with pre-text and post-text: #: ({{el-verb form of|είμαι|pers=1p|tense=pres}}: "we are")
  # Page 98 άκουσες: WARNING: Found form-of template with post-text: # {{el-verb form of|ακούω|pers=2s|tense=past}} "You listened, you heard"
  # Page 114 ήμεθα: WARNING: Found form-of template with pre-text and post-text: #: ({{el-verb form of|είμαι|pers=1p|tense=imperf}}: "we were")
  # Page 183 λύουμε: WARNING: Found form-of template with pre-text: # {{lb|el|formal|nocat=1}} {{alternative form of|lang=el|λύομεν}} {{el-verb form of|λύω|pers=1p|mood=ind|tense=pres|voice=act}}
  # Page 185 ψηφίζομε: WARNING: Found form-of template with post-text: # {{lb|el|formal|nocat=1}} {{el-verb form of|ψηφίζω|pers=1p|mood=ind|tense=pres|voice=act}} "we vote"
  # Page 194 κυνηγήθηκα: WARNING: Found form-of template with post-text: # {{el-verb form of|κυνηγιέμαι|pers=1s|tense=past|mood=ind|voice=pass|nodot=1}} ''of active'' {{l|el|κυνηγάω|tr=-}} & {{l|el|κυνηγώ|tr=-}}
  # Page 205 ακούσθηκα: WARNING: Found form-of template with post-text: # {{lb|el|formal}}  {{el-verb form of|ακούομαι|pers=1s|tense=past|nodot=1}} ''and of'' [[ακούγομαι]]
  # Page 206 ακούσθηκε: WARNING: Found form-of template with post-text: # {{lb|el|formal}} {{el-verb form of|ακούομαι|pers=3s|tense=past|nodot=1}} ''and of'' [[ακούγομαι]]
  # Page 208 πουδραρίστηκα: WARNING: Found form-of template with post-text: # {{el-verb form of|πουδράρομαι|pers=1s|tense=past}} ''passive of'' {{l|el|πουδράρω}}
  # Page 209 τρελαθεί: WARNING: Found form-of template with post-text: # {{el-verb form of|τρελαίνομαι|nonfinite=1}}, ''passive of'' '''[[τρελαίνω]]'''
  # Page 215 προσευχήθηκα: WARNING: Found form-of template with post-text: # {{el-verb form of|προσεύχομαι|pers=1s|mood=ind|tense=past|voice=}} "I prayed"
  # Page 217 ευχήθηκα: WARNING: Found form-of template with post-text: # {{el-verb form of|εύχομαι|pers=1s|mood=ind|tense=past|voice=}} "I wished"
  # Page 218 αντευχήθηκα: WARNING: Found form-of template with post-text: # {{el-verb form of|αντεύχομαι|pers=1s|mood=ind|tense=past|voice=}} "I wished back"
  # Page 219 απευχήθηκα: WARNING: Found form-of template with post-text: # {{el-verb form of|απεύχομαι|pers=1s|mood=ind|tense=past|voice=}} "I wished away"
  # Page 220 τρελάθηκα: WARNING: Found form-of template with post-text: # {{el-verb form of|τρελαίνομαι|pers=1s|tense=past}} ''passive of'' {{l|el|τρελαίνω}}
  # Page 228 στάζει: WARNING: Found form-of template with post-text: # {{el-verb form of|στάζω|pers=3s|tense=pres|voice=act}} "He/she/it [[drip]]s"
  ("el-verb form of", "ignoreducdot", "verified"),
  # NOTE: The following isn't strictly true; we convert nocap= to cap=
  # with reversed semantics rather than ignoring the capitalization.
  ("el-participle of", "ignoreduc", "verified"),
  ("en-simple past of", "lcnodot", False),
  # The following instances need to be fixed up:
  # (all instances with a final period, which needs to be removed)
  # Page 193 authors: WARNING: Found form-of template with post-text: # {{en-third-person singular of|author}}''
  # Page 221 there is: WARNING: Found form-of template with post-text: # {{en-third-person singular of|there be}}. {{n-g|Used to indicate the existence of something physical or abstract in a particular place. see also {{m|en|there are}}.}}
  # Page 275 hasta: WARNING: Found form-of template with post-text: # {{lb|en|colloquial}} {{en-third-person singular of|hafta}}: {{contraction of|has to|lang=en}}; is required to.
  # Page 287 ranks: WARNING: Found form-of template with post-text: # {{en-third-person singular of|rank}}''
  # Page 2003 shields: WARNING: Found form-of template with post-text: # {{en-third-person singular of|shield}}. Protects.
  # Page 4676 stage whispers: WARNING: Found form-of template with post-text: # {{en-third-person singular of|stage whisper}} {{alternative spelling of|stage-whispers|lang=en}}
  # Page 4884 decapitates: WARNING: Found form-of template with post-text: # {{en-third-person singular of|decapitate}}''
  # Page 4924 projectile-vomits: WARNING: Found form-of template with post-text: # {{en-third-person singular of|projectile-vomit}} {{alternative spelling of|projectile vomits|lang=en}}
  # Page 8049 gasses: WARNING: Found form-of template with pre-text: # {{alternative spelling of|gases|lang=en}}. {{en-third-person singular of|gas}}
  # Page 8080 dramatises: WARNING: Found form-of template with post-text: # {{en-third-person singular of|dramatise}}, an alternative spelling of {{m|en|dramatize}}.
  # Page 8847 smooshes: WARNING: Found form-of template with post-text: # {{en-third-person singular of|smoosh}}, alternative spelling of '''[[smush]]'''.
  # Page 8861 rip saws: WARNING: Found form-of template with post-text: # {{en-third-person singular of|rip saw}} {{alternative spelling of|ripsaws|lang=en}}
  # Page 10716 hathe: WARNING: Found form-of template with post-text: # {{lb|en|archaic}} {{en-third-person singular of|have}} {{alternative spelling of|hath|lang=en}}
  # Page 11664 sinuates: WARNING: Found form-of template with post-text: # {{en-third-person singular of|sinuate}}''
  # Page 12223 Timonises: WARNING: Found form-of template with pre-text: # {{alternative spelling of|Timonizes|lang=en}} {{en-third-person singular of|Timonise}}
  # Page 17011 carrols: WARNING: Found form-of template with post-text: # {{en-third
  # -person singular of|carrol}} ({{alternative form of|carols|nocap=yes|lang=en}}).
  # Page 19329 expells: WARNING: Found form-of template with post-text: # {{en-third-person singular of|expell}}, # {{obsolete spelling of|expels|lang=en}}
  # Page 20748 o'erloads: WARNING: Found form-of template with post-text: # {{lb|en|archaic}} {{en-third-person singular of|o'erload}}. {{contraction of|overloads|lang=en}}
  # Page 22044 sgraffitoes: WARNING: Found form-of template with post-text: # {{en-third-person singular of|sgraffito}} ({{alternative form of|sgraffitos|lang=en|nocap=1}})
  # Page 22886 feaks: WARNING: Found form-of template with post-text: # {{en-third-person singular of|feak}} ({{alternative form of|feagues|nocap=yes|lang=en}}).
  # Page 22944 rat finks: WARNING: Found form-of template with post-text: # {{en-third-person singular of|rat fink}} ({{alternative form of|ratfinks|nocap=yes|lang=en}}).
  # Page 23354 runs roughshod over: WARNING: Found form-of template with post-text: # {{en-third-person singular of|run roughshod over}} ({{alternative form of|rides roughshod over|nocap=yes|lang=en}}).
  # Page 23461 knocks one down with a feather: WARNING: Found form-of template with post-text: # {{en-third-person singular of|knock one down with a feather}} ({{alternative form of|knocks one over with a feather|nocap=yes|lang=en}}).
  # Page 23838 danicizes: WARNING: Found form-of template with post-text: # {{en-third-person singular of|danicize}}. ({{alternative case form of|Danicizes|lang=en}}.)
  # Page 23846 wig-wags: WARNING: Found form-of template with post-text: # {{en-third-person singular of|wig-wag}} ({{alternative form of|[[wigwags#Verb|wigwags]]|nocap=yes|lang=en}}).
  # Page 24123 carrolls: WARNING: Found form-of template with post-text: # {{en-third-person singular of|carroll}} ({{alternative form of|carols|nocap=yes|lang=en}}).
  # Page 24194 disenvowels: WARNING: Found form-of template with post-text: # {{en-third-person singular of|disenvowel}} ({{alternative form of|disemvowels|nocap=yes|lang=en}}).
  # Page 24272 rat-finks: WARNING: Found form-of template with post-text: # {{en-third-person singular of|rat-fink}} ({{alternative form of|ratfinks|nocap=yes|lang=en}}).
  # Page 24818 geo-fences: WARNING: Found form-of template with post-text: # {{en-third-person singular of|geo-fence}} ({{alternative form of|geofences|nocap=yes|lang=en}}).
  # Page 26142 acquites: WARNING: Found form-of template with post-text: # {{en-third-person singular of|acquite}} ({{obsolete spelling of|acquits|lang=en}}.)
  ("en-third-person singular of", "ignoreduc", "verified"), # All 26,993 verified
  # The following instances need to be fixed up:
  # Page 99 dast: WARNING: Found form-of template with pre-text and post-text: # {{lb|en|US|dialect}} [[dares|Dares]]; {{en-third person singular of|dare|lang=en}}.
  ("en-third person singular of", "ignoreduc", "verified"),
  ("enm-first-person singular of", "ignoreduc", "verified"),
  ("enm-first/third-person singular past of", "ignoreduc", "verified"),
  ("enm-plural of", "ignoreduc", "verified"),
  ("enm-plural past of", "ignoreduc", "verified"),
  ("enm-plural subjunctive of", "ignoreduc", "verified"),
  ("enm-plural subjunctive past of", "ignoreduc", "verified"),
  ("enm-second-person singular of", "ignoreduc", "verified"),
  ("enm-second-person singular past of", "ignoreduc", "verified"),
  ("enm-singular subjunctive of", "ignoreduc", "verified"),
  ("enm-singular subjunctive past of", "ignoreduc", "verified"),
  ("enm-third-person singular of", "ignoreduc", "verified"),
  # The following instances need to be fixed up:
  # Page 172 gordos: WARNING: Found form-of template with post-text: # {{es-adj form of|gordo|m|pl|nodot=y}}, [[fat]].
  ("es-adj form of", "ignoreducdot", "verified"), # All 8,521 verified
  ("et-nom form of", "ignoreducdot", "verified"),
  ("et-participle of", "ignoreducdot", "verified"),
  ("et-verb form of", "ignoreducdot", "verified"),
  ("fa-adj form of", "lcnodot", False),
  ("fa-adj-form", "lcnodot", False),
  ("fa-form-verb", "ignoreddot", "verified"),
  # The following instances need to be fixed up:
  # (all instances with a final period, which needs to be removed)
  ("fi-verb form of", "ignoreducdot", "verified"), # All 6,022 verified
  ("gmq-bot-verb-form-sup", "ignoreddot", "verified"),
  # The following instances need to be fixed up:
  # Page 944 𐌺𐌿𐌽𐌸𐍃: WARNING: Found form-of template with pre-text: # [[known]]. {{got-verb form of|𐌺𐌿𐌽𐌽𐌰𐌽|t=past|m=ptc}}
  ("got-verb form of", "ignoreducdot", "verified"),
  ("got-nom form of", "ignoreducdot", "verified"),
  # The following instances need to be fixed up:
  # Page 18 तेरी: WARNING: Found form-of template with post-text: # {{hi-form-adj||fs|तेरा}} {{hi-form-adj||fp|तेरा}}
  # Page 19 तेरे: WARNING: Found form-of template with post-text: # {{hi-form-adj|i|ms|तेरा}} {{hi-form-adj|v|ms|तेरा}} {{hi-form-adj||mp|तेरा}}
  ("hi-form-adj", "ignoreddot", "verified"),
  ("hi-form-adj-verb", "ignoreddot", "verified"),
  ("hi-form-noun", "ignoreddot", "verified"),
  ("hi-form-verb", "ignoreddot", "verified"),
  ("hu-inflection of", "lcnodot", False),
  ("hu-participle", "lcnodot", False),
  ("hy-form-noun", "lcnodot", False),
  ("ie-past and pp of", "lcnodot", False),
  ("is-conjugation of", "lcnodot", False),
  ("is-inflection of", "lcnodot", False),
  ("it-adj form of", "ignoreducdot", "verified"), # All 3,633 verified
  ("ja-past of verb", "lcnodot", False),
  ("ja-te form of verb", "lcnodot", False),
  ("ka-verbal for", "ignoreduc", "verified"),
  ("ka-verbal of", "ignoreduc", "verified"),
  ("ku-verb form of", "ignoreducdot", "verified"),
  ("liv-conjugation of", "lcnodot", False),
  ("liv-inflection of", "lcnodot", False),
  ("liv-participle of", "lcnodot", False),
  ("lt-būdinys", "ignoreddot", "verified"),
  ("lt-budinys", "ignoreddot", "verified"),
  # The following instances need to be fixed up:
  # Page 3 sapnuojąs: WARNING: Found form-of template with post-text: # {{lt-dalyvis-1|pres|a|sapnuoti}} [[dreaming]]
  # Page 4 sapnuojantis: WARNING: Found form-of template with post-text: # {{lt-dalyvis-1|pres|a|sapnuoti}} [[dreaming]]
  # Page 22 kalbantis: WARNING: Found form-of template with post-text: # {{lt-dalyvis-1|pres|a|kalbėti}} [[speaking]]
  # Page 23 kalbąs: WARNING: Found form-of template with post-text: # {{lt-dalyvis-1|pres|a|kalbėti}} [[speaking]]
  ("lt-dalyvis-1", "ignoreddot", "verified"),
  ("lt-dalyvis", "ignoreddot", "verified"),
  ("lt-dalyvis-2", "ignoreddot", "verified"),
  ("lt-form-adj", "ignoreddot", "verified"),
  ("lt-form-adj-is", "ignoreddot", "verified"),
  ("lt-form-noun", "ignoreddot", "verified"),
  ("lt-form-part", "ignoreddot", "verified"), # All 3,967 verified
  ("lt-form-pronoun", "ignoreddot", "verified"),
  ("lt-form-verb", "ignoreddot", "verified"),
  ("lt-padalyvis", "ignoreddot", "verified"),
  ("lt-pusdalyvis", "ignoreddot", "verified"),
  ("lv-comparative of", "lcnodot", False),
  ("lv-definite of", "lcnodot", False),
  ("lv-inflection of", "lcnodot", False),
  ("lv-negative of", "lcnodot", False),
  ("lv-reflexive of", "lcnodot", False),
  ("lv-superlative of", "lcnodot", False),
  ("lv-verbal noun of", "lcnodot", False),
  ("mhr-inflection of", "lcnodot", False),
  ("mr-form-adj", "ignoreddot", "verified"),
  ("mt-prep-form", "ignoreddot", "verified"),
  ("nb-noun-form-def-gen", "lcnodot", False),
  ("nb-noun-form-def-gen-pl", "lcnodot", False),
  ("nb-noun-form-indef-gen-pl", "lcnodot", False),
  ("nl-adj form of", "ignoreduc", False),
  ("ofs-nom form of", "ignoreduc", "verified"),
  ("osx-nom form of", "ignoreduc", "verified"),
  # The following instances need to be fixed up:
  # Page 202 conversa: WARNING: Found form-of template with post-text: # {{pt-adj form of|converso|f|sg}}.
  ("pt-adj form of", "ignoreducdot", "verified"), # All 15,486 verified
  ("pt-adv form of", "ignoreduc", "verified"),
  ("pt-article form of", "ignoreducdot", "verified"),
  ("pt-cardinal form of", "lcnodot", False),
  # The following instances need to be fixed up:
  # Page 70 conversa: WARNING: Found form-of template with post-text: # {{pt-noun form of|converso|f|sg}}.
  # Page 1493 galícia: WARNING: Found form-of template with post-text: # {{pt-noun form of|galício|f|sg|nodot=1}} ([[Galician]]).
  ("pt-noun form of", "ignoreducdot", "verified"),
  # The following instances need to be fixed up:
  # Page 53 3ª: WARNING: Found form-of template with post-text: # {{pt-ordinal form|3|ª}} {{abbreviation of|terceira|lang=pt}}
  ("pt-ordinal form", "ignoreducdot", "verified"),
  ("pt-ordinal def", "ignoreducdot", "verified"),
  ("ro-adj-form of", "lcnodot", False),
  ("ro-form-adj", "lcnodot", False),
  # WARNING: All non-line-final templates need a colon after them (a lot).
  ("ro-form-noun", "ignoreddot", "verified"),
  # WARNING: All non-line-final templates need a colon after them (a lot);
  # in addition, the following instances need to be fixed up:
  # Page 164 ești: WARNING: Found form-of template with post-text: # {{ro-form-verb|2s|pres|fi}} You [[are]].
  # Page 252 futeam: WARNING: Found form-of template with post-text: # {{ro-form-verb|1p|impf|fute}}we were [[fucking]]
  # Page 369 urăsc: WARNING: Found form-of template with post-text: # {{ro-form-verb|1s|pres|urî}} Ex.: I [[hate]]
  # Page 369 urăsc: WARNING: Found form-of template with post-text: # {{ro-form-verb|3p|pres|urî}} Ex.: they [[hate]]
  # Page 370 urăști: WARNING: Found form-of template with post-text: # {{ro-form-verb|2s|pres|urî}} Ex.: you [[hate]]
  # Page 371 urăște: WARNING: Found form-of template with post-text: # {{ro-form-verb|3s|pres|urî}} Ex.: he/she [[hates]]
  # Page 372 urâm: WARNING: Found form-of template with post-text: # {{ro-form-verb|1p|pres|urî}} Ex.: we [[hate]]
  ("ro-form-verb", "ignoreddot", "verified"),
  ("roa-opt-noun plural of", "ignoreducdot", "verified"),
  ("ru-participle of", "lcnodot", False),
  ("sa-desiderative of", "lcnodot", False),
  ("sa-desi", "lcnodot", False),
  ("sa-frequentative of", "lcnodot", False),
  ("sa-freq", "lcnodot", False),
  ("sa-root form of", "lcnodot", False),
  ("sco-simple past of", "lcnodot", False),
  ("sco-third-person singular of", "lcnodot", False),
  ("sga-verbnec of", "lcnodot", False),
  ("sh-form-noun", "lcnodot", False),
  ("sh-form-proper-noun", "lcnodot", False),
  ("sh-verb form of", "ignoreddot", "verified"),
  # WARNING: Lots of pages have ''negative'' pretext that could be included
  # in the template, e.g.:
  # Page 10 neću: WARNING: Found form-of template with pre-text: # ''negative'' {{sh-form-verb|1s|pres|hteti}}
  ("sh-form-verb", "ignoreddot", "verified"),
  ("sl-form-adj", "lcnodot", False),
  ("sl-form-noun", "ignoreddot", "verified"),
  ("sl-form-verb", "ignoreddot", "verified"),
  ("sl-participle of", "ignoreddot", "verified"),
  ("sl-verb form of", "ignoreddot", "verified"),
  ("sv-adj-form-abs-def", "ignoreddot", "verified"),
  ("sv-adj-form-abs-def+pl", "ignoreddot", "verified"),
  # The following instances need to be fixed up:
  # Page 144 ledes: WARNING: Found form-of template with pre-text: # ''genitive'' {{sv-adj-form-abs-def-m|led}}
  ("sv-adj-form-abs-def-m", "ignoreddot", "verified"),
  ("sv-adj-form-abs-indef-n", "ignoreddot", "verified"),
  ("sv-adj-form-abs-pl", "ignoreddot", "verified"),
  ("sv-adj-form-comp", "ignoreddot", "verified"),
  ("sv-adj-form-comp-pl", "ignoreddot", "verified"),
  ("sv-adj-form-sup-attr", "ignoreddot", "verified"),
  ("sv-adj-form-sup-attr-m", "ignoreddot", "verified"),
  ("sv-adj-form-sup-pred", "ignoreddot", "verified"),
  ("sv-adj-form-sup-pred-pl", "ignoreddot", "verified"),
  ("sv-adv-form-comp", "ignoreddot", "verified"),
  # The following instances need to be fixed up:
  # Page 1 mest: WARNING: Found form-of template with post-text: # {{sv-adv-form-sup|mycket}} [[most]]
  # Page 1 mest: WARNING: Found form-of template with post-text: # {{sv-adv-form-sup|många}} [[most]]
  ("sv-adv-form-sup", "ignoreddot", "verified"),
  ("sv-noun-form-def", "lcnodot", False),
  ("sv-noun-form-def-gen", "lcnodot", False),
  ("sv-noun-form-def-gen-pl", "lcnodot", False),
  ("sv-noun-form-def-pl", "lcnodot", False),
  ("sv-noun-form-indef-gen", "lcnodot", False),
  ("sv-noun-form-indef-gen-pl", "lcnodot", False),
  ("sv-noun-form-indef-pl", "lcnodot", False),
  ("sv-proper-noun-gen", "lcnodot", False),
  # The following instances need to be fixed up:
  # All cases with "2nd person only." etc. post-text along with 'plural of=', e.g.:
  # Page 12 given: WARNING: Found form-of template with post-text: # {{sv-verb-form-imp|ge|plural of=ge}} 2nd person only.
  # Page 83 varen: WARNING: Found form-of template with post-text: # {{sv-verb-form-imp|vara|plural of=var}} 2nd person only
  # Page 164 låtom: WARNING: Found form-of template with post-text: # {{sv-verb-form-imp|låta|plural of=låt}} 1st person only.
  # Also:
  # Page 41 lek: WARNING: Found form-of template with post-text: # {{sv-verb-form-imp|leka}} free play
  # Page 47 gack: WARNING: Found form-of template with pre-text: # {{lb|sv|obsolete}} singular {{sv-verb-form-imp|gå}}
  ("sv-verb-form-imp", "ignoreddot", "verified"),
  ("sv-verb-form-inf-pass", "ignoreddot", "verified"),
  # The following instances need to be fixed up:
  # All cases with "2nd person only." etc. post-text along with 'plural of=', e.g.:
  # Page 158 voren: WARNING: Found form-of template with post-text: # {{sv-verb-form-past|vara|plural of=var}} 2nd person only.
  # Page 689 skullen: WARNING: Found form-of template with post-text: # {{sv-verb-form-past|ska|plural of=skulle}} 2nd person only
  # Also:
  # Page 204 erhöllo: WARNING: Found form-of template with post-text: # {{sv-verb-form-past|erhålla|plural of=erhöll}} (A more common synonym is [[fick]].)
  # Page 2567 drefvo: WARNING: Found form-of template with post-text: # {{sv-verb-form-past|drifva|plural of=dref|dot=}}, {{spelling of|sv|proscribed|driva}}.
  ("sv-verb-form-past", "ignoreddot", "verified"),
  ("sv-verb-form-past-pass", "ignoreddot", "verified"),
  # FIXME: Many of the following uses are in the etymology section and need
  # lots of cleanup.
  ("sv-verb-form-pastpart", "ignoreddot", False),
  # The following instances need to be fixed up:
  # All cases with "2nd person only." etc. post-text along with 'plural of=', e.g.:
  # Page 5 given: WARNING: Found form-of template with post-text: # {{sv-verb-form-pre|ge|plural of=ger}} 2nd person only.
  # Page 14 kunnen: WARNING: Found form-of template with post-text: # {{sv-verb-form-pre|kunna|plural of=kan}} 2nd person only
  # Page 220 ären: WARNING: Found form-of template with post-text: # {{sv-verb-form-pre|vara|plural of=är}} 2nd person (you) only.
  # Page 327 sjungom: WARNING: Found form-of template with post-text: # {{sv-verb-form-pre|sjunga|plural of=sjunger}} 1st person only.
  # Also:
  # Page 41 giver: WARNING: Found form-of template with post-text: # {{sv-verb-form-pre|giva}} commonly contracted to ''[[ger]]'', based on ''[[ge]]''
  # Page 356 förbliver: WARNING: Found form-of template with post-text: # {{sv-verb-form-pre|förbliva}} commonly contracted to [[förblir]]
  ("sv-verb-form-pre", "ignoreddot", "verified"),
  ("sv-verb-form-pre-pass", "ignoreddot", "verified"),
  ("sv-verb-form-prepart", "lcnodot", False),
  # The following instances need to be fixed up:
  # Page 2 ginge: WARNING: Found form-of template with pre-text: # {{lb|sv|dated}} ''past tense'' {{sv-verb-form-subjunctive|gå}}
  # Page 3 leve: WARNING: Found form-of template with post-text: # {{sv-verb-form-subjunctive|leva}} Used to express one's wish that someone or something may live long, mostly at celebration ceremonies, primarily birthday celebrations.
  # Page 4 finge: WARNING: Found form-of template with pre-text: #{{lb|sv|dated}} ''past tense'' {{sv-verb-form-subjunctive|få}}
  # Page 6 vare: WARNING: Found form-of template with pre-text: # [[be]], ''present tense'' {{sv-verb-form-subjunctive|vara}}
  # Page 13 bekomme: WARNING: Found form-of template with pre-text: # ''present tense'' {{sv-verb-form-subjunctive|bekomma}}
  ("sv-verb-form-subjunctive", "ignoreddot", "verified"),
  # The following instances need to be fixed up:
  # Page 181 givit: WARNING: Found form-of template with post-text: # {{sv-verb-form-sup|giva}} see also ''[[gett]]''
  ("sv-verb-form-sup", "ignoreddot", "verified"),
  ("sv-verb-form-sup-pass", "ignoreddot", "verified"),
  ("tg-adj form of", "lcnodot", False),
  ("tg-adj-form", "lcnodot", False),
  ("tg-form-verb", "ignoreddot", "verified"),
  ("tl-verb form of", "ignoreducdot", "verified"),
  ("tr-inflection of", "lcnodot", False),
  ("ur-form-adj", "ignoreddot", "verified"),
  ("ur-form-noun", "ignoreddot", "verified"),
  ("ur-form-verb", "ignoreddot", "verified"),
]

templates_by_cap_and_period_map = {
  template:spec for template, spec, verified in templates_by_cap_and_period
}
verified_templates_by_cap_and_period = {
  template for template, spec, verified in templates_by_cap_and_period if verified
}

art_blk_specs = [
  ("blk-past of", (
    "verb form of",
    ("comment", "rename {{__TEMPNAME__}} to {{verb form of|art-blk}} with appropriate param changes"),
    ("error-if", ("present-except", ["1"])),
    ("set", "1", [
      "art-blk",
      ("copy", "1"),
      "",
      "past",
    ]),
  )),
]

bg_specs = [
  # NOTE: Has automatic, non-controllable initial caps and final period.
  # Both ignored.
  # NOTE: Original template sets tr=-. We don't do that.
  ("bg-adj form of", (
    "adj form of",
    ("error-if", ("present-except", ["1", "2", "3", "adj"])),
    ("set", "1", [
      "bg",
      ("copy", "adj"),
      "",
      # Template has order 3, 1, 2 but putting def/indef first makes
      # more sense.
      ("lookup", "2", {
        "extended": "extended",
        "indefinite": "indef",
        "definite": "def",
      }),
      ("lookup", "3", {
        "subject": "sbjv",
        "object": "objv",
        "": [],
      }),
      ("lookup", "1", {
        "masculine": ["m", "s"],
        "feminine": ["f", "s"],
        "neuter": ["n", "s"],
        "plural": ["p"],
      }),
    ]),
  )),

  # NOTE: Has automatic, non-controllable initial caps and final period.
  # Both ignored.
  # NOTE: Original template sets tr=-. We don't do that.
  ("bg-noun form of", (
    "noun form of",
    ("error-if", ("present-except", ["1", "2", "3", "noun"])),
    ("set", "1", [
      "bg",
      ("copy", "noun"),
      "",
      # Template has order 3, 1, 2 but putting indef/def first makes
      # more sense. Note that if "vocative" occurs in 1=, it always
      # occurs alone.
      ("lookup", "2", {
        "indefinite": "indef",
        "definite": "def",
        "vocative": "voc",
        "": [],
      }),
      ("lookup", "3", {
        "subject": "sbjv",
        "object": "objv",
        "": [],
      }),
      ("lookup", "1", {
        "singular": ["s"],
        "plural": ["p"],
        "count": ["count", "form"],
        "vocative": ["voc", "s"],
      }),
    ]),
  )),

  # NOTE: Has automatic, non-controllable initial caps and final period.
  # Both ignored.
  ("bg-verb form of", (
    "verb form of",
    ("error-if", ("present-except", ["verb", "part", "g", "f", "d", "person", "number", "tense", "mood"])),
    ("set", "1", [
      "bg",
      ("copy", "verb"),
      "",
      ("lookup", "part", {
        "adverbial participle": ["adv", "part"],
        "verbal noun": [
          # Template has the order g, d but putting def/indef first makes
          # more sense.
          ("lookup", "d", {
            "indefinite": "indef",
            "definite": "def",
          }),
          ("lookup", "g", {
            "singular": "s",
            "plural": "p",
          }),
          "vnoun"
        ],
        "": [
          ("lookup", "person", {
            "first": "1",
            "second": "2",
            "third": "3",
          }),
          ("lookup", "number", {
            "singular": "s",
            "plural": "p",
          }),
          ("lookup", "tense", {
            "present": "pres",
            "aorist": "aor",
            "imperfect": "impf",
            "": [], # can occur when mood=imperative
          }),
          ("lookup", "mood", {
            "indicative": "ind",
            "imperative": "imp",
            "renarrative": "renarr",
          }),
        ],
        True: [
          # Template has order f, g, d but putting def/indef first makes
          # more sense.
          ("lookup", "d", {
            "indefinite": "indef",
            "definite": "def",
            "": [],
          }),
          ("lookup", "f", {
            "subject form": "sbjv",
            "object form": "objv",
            "": [], # can occur esp. with non-masculine participles
          }),
          ("lookup", "g", {
            # Template doesn't include "singular" here.
            "masculine": ["m", "s"],
            "feminine": ["f", "s"],
            "neuter": ["n", "s"],
            "plural": "p",
          }),
          ("lookup", "part", {
            "present active participle": ["pres", "act", "part"],
            "past passive participle": ["past", "pass", "part"],
            "past active aorist participle": ["past", "act", "aor", "part"],
            "past active imperfect participle": ["past", "act", "impf", "part"],
          }),
        ],
      }),
    ]),
  )),
]

br_specs = [
  # NOTE: Has automatic, non-controllable initial caps and final period.
  # Both ignored.
  ("br-noun-plural", (
    "plural of",
    ("error-if", ("present-except", ["1", "2"])),
    ("set", "1", [
      "br",
      ("copy", "1"),
      ("copy", "2"),
    ]),
  )),
]

def romance_adj_form_of(lang):
  # This works for ca, es, it and pt. Romanian has its own template and French
  # uses {{masculine singular of}}, {{feminine singular of}}, etc.
  # Not all languages accept m-f or mf, but it doesn't hurt to accept them.
  # Has default initial caps and final period (controllable by nocap/nodot).
  # Both ignored.
  return (
    "adj form of",
    ("error-if", ("present-except", ["1", "2", "3", "4", "t", "nocap", "nodot"])),
    ("set", "1", [
      lang,
      ("copy", "1"),
    ]),
    ("copy", "t"), # occurs, although ignored by template
    ("set", "3", [
      "",
      ("lookup", "4", {
        "aug": "aug",
        "dim": "dim",
        "comp": "comd",
        "super": "supd",
        "": [],
      }),
      ("lookup", "2", {
        "m": "m",
        "f": "f",
        "m-f": "mf",
        "mf": "mf",
      }),
      ("lookup", "3", {
        "sg": "s",
        "pl": "p",
      }),
    ]),
  )

def ca_form_of(data):
  if data.getp("1") in ["alt form", "alt sp", "alt spel", "alt spell"]:
    if data.getp("1") == "alt form":
      template = "alt form"
    else:
      template = "alt sp"
    return (
      template,
      # nocap= ignored; doesn't include val= or val2=
      ("error-if", ("present-except", ["1", "2", "3", "nocap", "sort"])),
      ("set", "1", [
        "ca",
        ("copy", "2"),
        ("copy", "3"),
      ]),
      ("copy", "sort"),
    )
  else:
    return (
      "infl of",
      # nocap= ignored; doesn't include val= or val2=
      ("error-if", ("present-except", ["1", "2", "3", "nocap", "sort"])),
      ("set", "1", [
        "ca",
        ("copy", "2"),
        ("copy", "3"),
        ("lookup", "1", {
          "f": "f",
          "fem": "f",
          "feminine": "f",
          "fp": ["f", "p"],
          "fpl": ["f", "p"],
          "fplural": ["f", "p"],
          "mp": ["m", "p"],
          "mpl": ["m", "p"],
          "mplural": ["m", "p"],
          "m": ["m", "s"],
          "masc": ["m", "s"],
          "masculine": ["m", "s"],
        }),
      ]),
      ("copy", "sort"),
    )

ca_specs = [
  ("ca-adj form of", romance_adj_form_of("ca")),

  ("ca-form of", ca_form_of),

  ("ca-verb form of", (
    "verb form of",
    ("error-if", ("present-except", ["1", "p", "n", "g", "t", "m", "nocap", "nodot"])),
    ("set", "1", [
      "ca",
      ("copy", "1"),
      "",
      ("lookup", "p", {
        "1": "1",
        "2": "2",
        "3": "3",
        "": [], # may be mising if m=ptc
      }),
      ("lookup", "n", {
        "sg": "s",
        "pl": "p",
        "": [], # may be mising if m=ptc
      }),
      # Template ignores g= but it's extremely common with past participle forms
      ("lookup", "g", {
        "m": ["m", "s"],
        "ms": ["m", "s"],
        "f": ["f", "s"],
        "fs": ["f", "s"],
        "n": ["n", "s"],
        "ns": ["n", "s"],
        "mp": ["m", "p"],
        "mpl": ["m", "p"],
        "fp": ["f", "p"],
        "fpl": ["f", "p"],
        "np": ["n", "p"],
        "npl": ["n", "p"],
        "": [],
      }),
      ("lookup", "t", {
        "pres": "pres",
        "past": "past",
        "impf": "impf",
        "pret": "pret",
        "futr": "fut",
        "": [], # may be mising if m=impr
      }),
      ("lookup", "m", {
        "ind": "ind",
        "sub": "sub",
        "impr": "imp",
        "cond": "cond",
        "ptc": "part",
      }),
    ]),
  )),
]

cu_specs = [
  # NOTE: Has automatic, non-controllable initial caps and final period.
  # Both ignored. Only 10 uses. Categorizes into '{{{type}}} forms', which
  # should be handled by the headword; in actual use, type is always 'noun'.
  ("cu-form of", (
    "noun form of",
    ("error-if", ("present-except", ["1", "type", "case", "pl", "sc"])),
    ("set", "1", [
      "cu",
      ("copy", "1"),
      "",
      ("lookup", "case", {
        "nominative": "nom",
        "accusative": "acc",
        "dative": "dat",
        "genitive": "gen",
        "instrumental": "ins",
        "locative": "loc",
        "vocative": "voc",
      }),
      ("lookup", "pl", {
        "singular": "s",
        "dual": "d",
        "plural": "p",
      }),
    ]),
  )),
]

da_specs = [
  ("da-pl-genitive", (
    "genitive of",
    ("error-if", ("present-except", ["1"])),
    ("set", "1", [
      "da",
      ("copy", "1"),
    ])
  )),
]

de_specs = [
  # NOTE: Has automatic, non-controllable initial caps that we're ignoring.
  # Only 2 uses.
  ("de-du contraction", (
    "contraction of",
    ("comment", "rename {{__TEMPNAME__}} to {{contraction of|de|[[{{{1}}}]] [[du]]}}"),
    ("error-if", ("present-except", ["1"])),
    ("set", "1", [
      "de",
      lambda data: "[[%s]] [[du]]" % data.getp("1")
    ]),
  )),

  # NOTE: Has automatic, non-controllable final period that we're ignoring.
  # Doesn't have initial caps.
  ("de-form-adj", (
    "adj form of",
    # lang= occurs at least once, and is ignored.
    # Ignore nocat; seems to occur in all entries.
    ("error-if", ("present-except", ["deg", "1", "2", "3", "4", "nocat",
      "sort", "lang"])),
    ("set", "1", [
      "de",
      ("lookup", "1", {
        "pc": [
          ("copy", "2"),
          "",
          ["pred", "comd"],
        ],
        "ps": [
          ("copy", "2"),
          "",
          ["pred", "supd"],
        ],
        True: [
          ("copy", "4"),
          "",
          # Template has the order deg, 1, 2, 3.
          ("lookup", "1", {
            "s": "str",
            "str": "str",
            "strong": "str",
            "w": "wk",
            "weak": "wk",
            "m": "mix",
            "mix": "mix",
            "mixed": "mix",
            "sm": "str//mix",
            "ms": "str//mix",
            "smw": "str//mix//wk",
            "swm": "str//mix//wk",
            "msw": "str//mix//wk",
            "mws": "str//mix//wk",
            "wsm": "str//mix//wk",
            "wms": "str//mix//wk",
            "mw": "mix//wk",
            "wm": "mix//wk",
            "": [], # occurs when all apply; FIXME should we enumerate this explicitly?
          }),
          ("lookup", "3", {
            "n": "nom",
            "nom": "nom",
            "nominative": "nom",
            "g": "gen",
            "gen": "gen",
            "genitive": "gen",
            "d": "dat",
            "dat": "dat",
            "dative": "dat",
            "a": "acc",
            "acc": "acc",
            "accusative": "acc",
          }),
          ("lookup", "2", {
            "m": ["m", "s"],
            "masculine": ["m", "s"],
            "f": ["f", "s"],
            "feminine": ["f", "s"],
            "n": ["n", "s"],
            "neuter": ["n", "s"],
            "p": "p",
            "pl": "p",
            "plural": "p",
            "": [], # occurs when all apply; FIXME should we enumerate this explicitly?
          }),
          ("lookup", "deg", {
            "c": "comd",
            "s": "supd",
            "": [],
          }),
        ]
      }),
    ]),
    ("copy", "sort"),
  )),

  ("de-form-noun", (
    "noun form of",
    ("error-if", ("present-except", ["1", "2", "3", "sort"])),
    ("set", "1", [
      "de",
      ("copy", "2"),
      ("copy", "3"),
      ("lookup", "1", {
        "ns": ["nom", "s"],
        "sn": ["nom", "s"],
        "np": ["nom", "p"],
        "pn": ["nom", "p"],
        "gs": ["gen", "s"],
        "sg": ["gen", "s"],
        "gp": ["gen", "p"],
        "pg": ["gen", "p"],
        "ds": ["dat", "s"],
        "sd": ["dat", "s"],
        "dp": ["dat", "p"],
        "pd": ["dat", "p"],
        "as": ["acc", "s"],
        "sa": ["acc", "s"],
        "ap": ["acc", "p"],
        "pa": ["acc", "p"],
      }),
    ]),
    ("copy", "sort"),
  )),

  # NOTE: Has automatic, non-controllable initial caps and final period.
  # Both ignored.
  ("de-verb form of", (
    "verb form of",
    ("error-if", ("present-except", ["1", "2", "3", "4", "5"])),
    ("set", "1", [
      "de",
      ("copy", "1"),
      "",
      ("lookup", "2", {
        "pr": ["pres", "part"],
        "pp": ["past", "part"],
        True: [
          # Template has the order 2, 3, 4, 5. We reorder to consistently
          # use the order person, number, dependent, tense/mood.
          ("lookup", "2", {
            "1": "1",
            "2": "2",
            "3": "3",
            "i": [],
          }),
          ("lookup", "3", {
            "s": "s",
            "p": "p",
          }),
          ("lookup", "5", {
            "": [],
            True: ["dep"],
          }),
          ("lookup", "2", {
            "i": [
              "imp",
              ("lookup", "4", {
                "": [],
              }),
            ],
            True: ("lookup", "4", {
              "g": "pres",
              "v": ["pret"],
              "k1": ["sub", "I"],
              "k2": ["sub", "II"],
            }),
          }),
        ],
      }),
    ]),
  )),
]

el_specs = [
  # NOTE: Has automatic, non-controllable initial caps that we're ignoring.
  # No final period.
  ("el-form-of-adv", (
    lambda data:
      ("comparative of",
        ("comment", "rename {{__TEMPNAME__|deg=comp}} to {{comparative of|el|...|POS=adverb}}"),
        ("error-if", ("present-except", ["deg", "1", "alt", "gloss"])),
        ("set", "1", [
          "el",
          ("copy", "1"),
          ("copy", "alt"),
          ("copy", "gloss", "t"),
        ]),
        ("set", "POS", "adverb"),
      ) if data.getp("deg") == "comp" else
      ("infl of",
        ("comment", "rename {{__TEMPNAME__|deg=sup}} to {{inflection of|el|...|asupd}}"),
        ("error-if", ("present-except", ["deg", "1", "alt", "gloss"])),
        ("error-if", ("neq", "deg", "sup")),
        ("set", "1", [
          "el",
          ("copy", "1"),
          ("copy", "alt"),
          "asupd",
        ]),
        ("copy", "gloss", "t"),
        ("set", "p", "adv"),
      )
  )),

  # NOTE: Has automatic, non-controllable initial caps and controllable
  # final period (using nodot). Both ignored.
  ("el-form-of-nounadj", (
    "infl of",
    ("error-if", ("present-except", ["1", "c", "n", "g", "d", "t", "nodot"])),
    ("set", "1", [
      "el",
      ("copy", "1"),
    ]),
    ("copy", "t"),
    ("set", "3", [
      "",
      ("lookup", "c", {
        "nom": "nom",
        "n": "nom",
        "acc": "acc",
        "a": "acc",
        "gen": "gen",
        "g": "gen",
        "voc": "voc",
        "v": "voc",
        "dat": "dat",
        "av": "acc//voc",
        "ga": "gen//acc",
        "gav": "gen//acc//voc",
        "na": "nom//acc",
        "nav": "nom//acc//voc",
        "nv": "nom//voc",
      }),
      # Template has n= before g=.
      ("lookup", "g", {
        "m": "m",
        "f": "f",
        "n": "n",
        "mf": "mf",
        "mn": "mn",
        "fn": "fn",
        "mfn": "mfn",
        "": [], # doesn't apply when dealing with a noun
      }),
      ("lookup", "n", {
        "s": "s",
        "p": "p",
        "": [], # occurs with numbers
      }),
      ("lookup", "d", {
        "c": "comd",
        "rs": "rsupd",
        "as": "asupd",
        "": [],
      }),
    ]),
  )),

  ("el-form-of-pronoun", "el-form-of-nounadj"),

  # NOTE: Has automatic, non-controllable initial caps and controllable
  # final period (using nodot). Both ignored.
  ("el-form-of-verb", (
    "verb form of",
    # active= and ta= need to be removed prior to renaming this template.
    ("error-if", ("present-except", ["1", "nonfinite", "voice", "pers",
      "tense", "mood", "t", "nodot"])),
    ("set", "1", [
      "el",
      ("copy", "1"),
      "",
      ("lookup", "nonfinite", {
        True: ("lookup", "voice", {
          "act": ["act", "nonfin", "form"],
          "active": ["act", "nonfin", "form"],
          "pass": ["pass", "nonfin", "form"],
          "passive": ["pass", "nonfin", "form"],
        }),
        "": [
          ("lookup", "pers", {
            "1s": "1s",
            "2s": "2s",
            "3s": "3s",
            "1p": "1p",
            "2p": "2p",
            "3p": "3p",
            "": [], # person frequently left out when 1s passive
          }),
          ("lookup", "tense", {
            "pres": "pres",
            "present": "pres",
            "past": "spast",
            "imperfect": "impf",
            "imperf": "impf",
            "impf": "impf",
            "imp": "impf",
            "future": ["pfv", "fut"],
            "fut": ["pfv", "fut"],
            "future-cont": ["impfv", "fut"],
            "fut-c": ["impfv", "fut"],
            "fut_c": ["impfv", "fut"],
            "dependent": "dep",
            "dep": "dep",
            "": [], # tense frequently left out when mood is imperative
          }),
          # Template has mood before voice.
          ("lookup", "voice", {
            "pass": "pass",
            "act": "act",
            "": [], # voice frequently left out (when active?)
          }),
          ("lookup", "mood", {
            "imptv": "imp",
            "imptv-i": ["impfv", "imp"],
            "imptv-p": ["pfv", "imp"],
            "imptv-is": ["s", "impfv", "imp"],
            "imptv-ip": ["p", "impfv", "imp"],
            "imptv-ps": ["s", "pfv", "imp"],
            "imptv-pp": ["p", "pfv", "imp"],
            "ind": "ind",
            "subj": "sub",
            "sub": "sub",
            "": [], # mood frequently left out when tense=past
          }),
        ]
      }),
    ]),
    ("copy", "t"),
  )),

  # NOTE: Has automatic, non-controllable initial caps and controllable
  # final period (using nodot) which we will rewrite, moving the final period
  # outside of the template.
  ("el-participle of", (
    "participle of",
    ("error-if", ("present-except", ["1", "2", "gloss", "t", "tr", "nocap"])),
    ("set", "1", [
      "el",
      ("copy", "1"),
    ]),
    ("copy", "tr"),
    ("set", "3", [
      "",
      ("lookup", "2", {
        "present": ["pres"],
        "pres": ["pres"],
        "perfect": ["perf"],
        "perf": ["perf"],
        "passive perfect": ["pass", "perf"],
        "pass-perf": ["pass", "perf"],
      }),
    ]),
    ("copy", "gloss", "t"),
    ("copy", "t"),
    ("set", "cap",
      ("lookup", "nocap", {
        "": "1",
        True: [],
      }),
    ),
  )),

  ("el-verb form of", "el-form-of-verb"),
]

def en_verb_form(parts):
  return (
    "infl of", # no need for 'verb form of', I think; we can categorize without it
    # lang= occurs at least once, and is ignored.
    # nodot= occurs a few times and is ignored.
    ("error-if", ("present-except", ["1", "2", "3", "t", "gloss", "id", "lang", "nodot"])),
    ("set", "1", [
      "en",
      ("copy", "1"),
      ("copy", "2"),
      parts,
    ]),
    ("copy", "t"),
    ("copy", "gloss", "t"),
    ("copy", "3", "t"),
    ("copy", "id"),
  )

en_specs = [
  ("en-archaic second-person singular of",  en_verb_form(["st-form"])),
  ("en-archaic second-person singular past of",  en_verb_form(["st-past-form"])),
  ("en-archaic third-person singular of",  en_verb_form(["th-form"])),
  ("en-third-person singular of",  en_verb_form(["s-verb-form"])),
  ("en-simple past of",  en_verb_form(["spast"])),
  ("en-past of",  en_verb_form(["ed-form"])),
  ("en-ing form of",  en_verb_form(["ing-form"])),
]

def enm_verb_form(parts):
  return (
    "verb form of",
    ("error-if", ("present-except", ["1", "2", "t", "id"])),
    ("set", "1", [
      "enm",
      ("copy", "1"),
      ("copy", "2"),
      parts,
    ]),
    ("copy", "t"), # occurs although ignored by template
    ("copy", "id"), # occurs although ignored by template
  )

enm_specs = [
  # NOTE: All of these have automatic, non-controllable initial cap that
  # we're ignoring. Doesn't have final period. There are <= 9 uses of each
  # template.
  ("enm-first-person singular of",
      enm_verb_form(["1s", "pres", "ind"])),
  ("enm-first/third-person singular past of",
      enm_verb_form(["13", "s", "past", "ind"])),
  ("enm-plural of",
      enm_verb_form(["p", "pres", "ind"])),
  ("enm-plural past of",
      enm_verb_form(["p", "past", "ind"])),
  ("enm-plural subjunctive of",
      enm_verb_form(["p", "pres", "sub"])),
  ("enm-plural subjunctive past of",
      enm_verb_form(["p", "past", "sub"])),
  ("enm-second-person singular of",
      enm_verb_form(["2s", "pres", "ind"])),
  ("enm-second-person singular past of",
      enm_verb_form(["2s", "past", "ind"])),
  ("enm-singular subjunctive of",
      enm_verb_form(["s", "pres", "sub"])),
  ("enm-singular subjunctive past of",
      enm_verb_form(["s", "past", "sub"])),
  ("enm-third-person singular of",
      enm_verb_form(["3s", "pres", "ind"])),
]

es_specs = [
  ("es-adj form of", romance_adj_form_of("es")),
]

et_specs = [
  # Has default initial caps and final period (controllable by nocap/nodot).
  # Both ignored.
  ("et-nom form of", (
    # May be rewritten later to 'noun form of', etc.
    "infl of",
    # pos= is commonly present but ignored by the template. But it
    # contains useful information so we convert it to p=, which will also
    # help with rewriting.
    ("error-if", ("present-except", ["1", "c", "n", "pos", "nocap", "nodot"])),
    ("set", "1", [
      "et",
      ("copy", "1"),
      "",
      ("lookup", "c", {
        "nom": "nom",
        "gen": "gen",
        "par": "par",
        "ill": "ill",
        "ine": "ine",
        "ela": "ela",
        "all": "all",
        "ade": "ade",
        "abl": "abl",
        "tra": "tra",
        "ter": "ter",
        "ess": "ess",
        "abe": "abe",
        "com": "com",
      }),
      ("lookup", "n", {
        "sg": "s",
        "pl": "p",
      }),
    ]),
    ("set", "p",
      ("lookup", "pos", {
        "noun": "n",
        "pronoun": "pro",
        "adj": "a",
        "adjective": "a",
        "numeral": "num",
      }),
    ),
  )),

  # Has default initial caps and final period (controllable by nocap/nodot).
  # Both ignored.
  ("et-participle of", (
    "participle of",
    ("error-if", ("present-except", ["1", "t", "nocap", "nodot"])),
    ("set", "1", [
      "et",
      ("copy", "1"),
      "",
      ("lookup", "t", {
        "pres": ["pres", "act"],
        "pres_actv": ["pres", "act"],
        "pres_pasv": ["pres", "pass"],
        "past": ["past", "act"],
        "past_actv": ["past", "act"],
        "past_pasv": ["past", "pass"],
      }),
    ]),
  )),

  # Has default initial caps and final period (controllable by nocap/nodot).
  # Both ignored.
  ("et-verb form of", (
    # The template code supports m=ptc and categorizes specially, but
    # it never occurs.
    "verb form of",
    ("error-if", ("present-except", ["1", "p", "m", "t", "nocap", "nodot"])),
    ("set", "1", [
      "et",
      ("copy", "1"),
      "",
      ("lookup", "p", {
        "1s": "1s",
        "2s": "2s",
        "3s": "3s",
        "1p": "1p",
        "2p": "2p",
        "3p": "3p",
        # We should reorder p=pass later but it never occurs.
        "pass": "pass",
        "": [],
      }),
      ("lookup", "m", {
        "pres": "pres",
        "past": "past",
        "cond": "cond",
        "impr": "impr",
        "quot": "quot",
        "": [],
      }),
      ("lookup", "t", {
        "da": "da-infinitive",
        "conn": "conn",
        "": [],
      }),
    ]),
  )),
]

def fa_tg_adj_form_of(data, lang):
  param1 = data.getp("1")
  if param1 == "c":
    template_name = "comparative of"
  elif param1 == "s":
    template_name = "superlative of"
  else:
    raise BadTemplateValue("Unrecognized param 1=%s" % param1)
  return (
    template_name,
    ("error-if", ("present-except", ["1", "2", "3", "tr"])),
    ("set", "1", [
      lang,
      ("copy", "2"),
      ("copy", "3"),
    ]),
    ("copy", "tr"),
  )

fa_specs = [
  ("fa-adj form of", lambda data: fa_tg_adj_form_of(data, "fa")),

  ("fa-adj-form", "fa-adj form of"),

  # Has automatic, non-controllable final period that we're ignoring.
  # Doesn't have initial caps.
  ("fa-form-verb", (
    "verb form of",
    # t= is ignored by template but sometimes contains useful info.
    ("error-if", ("present-except", ["1", "2", "t"])),
    ("set", "1", [
      "fa",
      ("copy", "2"),
      "",
      ("lookup", "1", {
        "man": ["1s", "imp"],
        "imp-man": ["1s", "imp"],
        "to": ["2s", "imp"],
        "imp-to": ["2s", "imp"],
        "u": ["3s", "imp"],
        "imp-u": ["3s", "imp"],
        "mâ": ["1p", "imp"],
        "imp-mâ": ["1p", "imp"],
        "šomâ": ["2p", "imp"],
        "imp-šomâ": ["2p", "imp"],
        "ânhâ": ["3p", "imp"],
        "imp-ânhâ": ["3p", "imp"],
        "r": ["root", "form"],
        "prstem": ["pres", "stem", "form"],
        "pstem": ["past", "stem", "form"],
      }),
    ]),
    ("copy", "t"),
  )),
]

def fetch_fi_suffixes(data):
  suffixes = blib.fetch_param_chain(data.t, "suffix")
  if suffixes:
    return ",".join(suffixes)
  else:
    return []

fi_specs = [
  # Has default initial caps and final period (controllable by nocap/nodot).
  # Both ignored.
  ("fi-verb form of", (
    # The template code ignores nocat=.
    "verb form of",
    ("error-if", ("present-except", ["1", "pn", "tm", "c", "nocap", "nodot", "nocat"])),
    ("set", "1", [
      "fi",
      ("copy", "1"),
      "",
      # Template has the order pn, tm. We intersperse them to maintain the
      # consistent order person, number, tense, voice, mood.
      ("lookup", "pn", {
        "1s": ["1", "s"],
        "2s": ["2", "s"],
        "3s": ["3", "s"],
        "1p": ["1", "p"],
        "2p": ["2", "p"],
        "3p": ["3", "p"],
        "p": "p",
        "pasv": [],
        "pass": [],
        "": [], # especially in conjunction with connegative
      }),
      ("lookup", "tm", {
        "pres": "pres",
        "cond": "pres",
        "impr": "pres",
        "potn": "pres",
        "past": "past",
      }),
      ("lookup", "pn", {
        "1s": [],
        "2s": [],
        "3s": [],
        "1p": [],
        "2p": [],
        "3p": [],
        "p": [],
        "pasv": "pass",
        "pass": "pass",
        "": [], # especially in conjunction with connegative
      }),
      ("lookup", "tm", {
        "pres": "ind",
        "past": "ind",
        "cond": "cond",
        "impr": "imp",
        "potn": "potn",
        "opta": "opt",
      }),
      ("lookup", "c", {
        "": [],
        True: "conn",
      }),
    ]),
  )),

  ("fi-form of", (
    "infl of",
    ("error-if", ("present-except", [
      # silently ignore nodot=, lang=, which are also ignored by the template
      "1", "2", "t", "gloss", "pr", "case", "pl", "tense", "mood", "suffix", "suffix2", "suffix3", "nodot",
      "lang",
    ])),
    ("set", "1", [
      "fi",
      ("copy", "1"),
      "",
      ("lookup", "2", {
        "-": "form",
        "": [],
      }),
      ("lookup", "pr", {
        "1": "1",
        "1p": "1",
        "first person": "1",
        "first-person": "1",
        "2": "2",
        "2p": "2",
        "second person": "2",
        "second-person": "2",
        "3": "3",
        "3p": "3",
        "third person": "3",
        "third-person": "3",
        "passive": ("lookup", "tense", {
          "connegative": [],
          "present connegative": [],
          "past connegative": [],
          True: "pass",
        }),
        "impersonal": ("lookup", "tense", {
          "connegative": [],
          "present connegative": [],
          "past connegative": [],
          True: "pass",
        }),
        "": [],
      }),
      ("lookup", "case", {
        "nominative": "nom",
        "genitive": "gen",
        "accusative": "acc",
        "partitive": "par",
        "inessive": "ine",
        "illative": "ill",
        "elative": "ela",
        "adessive": "ade",
        "allative": "all",
        "ablative": "abl",
        "essive": "ess",
        "translative": "tra",
        "instructive": "ist",
        "abessive": "abe",
        "comitative": "com",
        "": [],
      }),
      ("lookup", "pl", {
        "s": "s",
        "singular": "s",
        "p": "p",
        "plural": "p",
        "singular and plural": "s//p",
        "": [],
      }),
      ("lookup", "tense", {
        "": [],
        "connegative": [],
        "present": "pres",
        "present connegative": "pres",
        "imperfect": "past",
        "past": "past",
        "past connegative": "past",
      }),
      ("lookup", "tense", {
        "connegative": ("lookup", "pr", {
          "passive": "pass",
          "impersonal": "pass",
          True: "act",
        }),
        "present connegative": ("lookup", "pr", {
          "passive": "pass",
          "impersonal": "pass",
          True: "act",
        }),
        "past connegative": ("lookup", "pr", {
          "passive": "pass",
          "impersonal": "pass",
          True: "act",
        }),
        True: [],
      }),
      ("lookup", "mood", {
        "": [],
        "indicative": "ind",
        "conditional": "cond",
        "imperative": "imp",
        "potential": "potn",
        "optative": "opt",
        "eventive": "eventive",
      }),
      ("lookup", "tense", {
        "connegative": "conn",
        "present connegative": "conn",
        "past connegative": "conn",
        True: [],
      }),
    ]),
    ("set", "enclitic", fetch_fi_suffixes),
    ("copy", "t"),
    ("copy", "gloss", "t"),
  )),

  ("fi-infinitive of", (
    "infl of",
    # silently ignore nodot=, which is also ignored by the template
    ("error-if", ("present-except", ["1", "c", "n", "t", "suffix", "gloss", "nocat", "nodot"])),
    ("set", "1", [
      "fi",
      ("copy", "1"),
      "",
      ("lookup", "c", {
        "": [],
        "nom": "nom",
        "gen": "gen",
        "par": "par",
        "acc": "acc",
        "ine": "ine",
        "ela": "ela",
        "ill": "ill",
        "ade": "ade",
        "abl": "abl",
        "all": "all",
        "ess": "ess",
        "tra": "tra",
        "ins": "ist", # intentional
        "ist": "ist",
        "abe": "abe",
        "com": "com",
      }),
      ("lookup", "n", {
        "": [],
        "s": "s",
        "sg": "s",
        "singular": "s",
        "p": "p",
        "pl": "p",
        "plural": "p",
      }),
      ("lookup", "c", {
        "": [],
        True: "of",
      }),
      ("lookup", "t", {
        "1": "first",
        "1l": ["long", "first"],
        "2a": ["second", "act"],
        "2p": ["second", "pass"],
        "3a": ["third", "act"],
        "3p": ["third", "pass"],
        "4": "fourth",
        "5": "fifth",
      }),
      "inf",
    ]),
    ("set", "enclitic", fetch_fi_suffixes),
    ("copy", "gloss", "t"),
    ("copy", "nocat"),
  )),

  ("fi-participle of", (
    "infl of",
    # silently ignore nocat=, nodot= and lang=, which are also ignored by the template
    ("error-if", ("present-except", ["1", "case", "plural", "pl", "t", "suffix", "gloss", "nocat", "nodot", "lang"])),
    ("set", "1", [
      "fi",
      ("copy", "1"),
      "",
      ("lookup", "case", {
        "": [],
        "nominative": "nom",
        "genitive": "gen",
        "partitive": "par",
        "accusative": "acc",
        "inessive": "ine",
        "elative": "ela",
        "illative": "ill",
        "adessive": "ade",
        "ablative": "abl",
        "allative": "all",
        "essive": "ess",
        "translative": "tra",
        "instructive": "ist",
        "abessive": "abe",
        "comitative": "com",
      }),
      ("lookup", "case", {
        "": [],
        True: ("lookup", "pl", {
          "singular": "s",
          "plural": "p",
          "": ("lookup", "plural", {
            "": "s",
            True: "p",
          }),
        }),
      }),
      ("lookup", "case", {
        "": [],
        True: "of",
      }),
      ("lookup", "t", {
        "pres": ["pres", "act", "part"],
        "pres_pasv": ["pres", "pass", "part"],
        "pres_pass": ["pres", "pass", "part"],
        "past": ["past", "act", "part"],
        "past_pasv": ["past", "pass", "part"],
        "past_pass": ["past", "pass", "part"],
        "agnt": "agentpart",
        "nega": ["negative", "part"],
      }),
    ]),
    ("set", "enclitic", fetch_fi_suffixes),
    ("copy", "gloss", "t"),
  )),
]

ga_lenition_of_specs = [
  # Has default initial caps and final period (controllable by nocap/nodot).
  # FIXME: Verify that we can ignore them.
  ("ga-lenition of", (
    "lenition of",
    # We do not include 2=, which needs to be rewritten and moved outside.
    ("error-if", ("present-except", ["1"])),
    ("set", "1", [
      "ga",
      ("copy", "1"),
    ]),
  )),
]

gmq_bot_specs = [
  # NOTE: Has automatic, non-controllable final period that we're ignoring.
  # Doesn't have initial caps.
  ("gmq-bot-verb-form-sup", (
    "supine of",
    ("error-if", ("present-except", ["1"])),
    ("set", "1", [
      "gmq-bot",
      ("copy", "1"),
    ]),
  )),
]

got_specs = [
  # Has default initial caps and final period (controllable by nocap/nodot). Both ignored.
  ("got-verb form of", (
    "verb form of",
    # lang= occurs at least once, and is ignored.
    ("error-if", ("present-except", ["1", "p", "n", "t", "tr", "v", "m",
      "nocap", "nodot", "lang"])),
    ("set", "1", [
      "got",
      ("copy", "1"),
    ]),
    ("copy", "tr"), # ignored by template but occurs
    ("set", "3", [
      "",
      ("lookup", "p", {
        "1": "1",
        "2": "2",
        "3": "3",
        "13": "13",
        "123": "123",
        "": [], # especially when m=ptc?
      }),
      ("lookup", "n", {
        "sg": "s",
        "s": "s", # error per template, but occurs
        "du": "d",
        "pl": "p",
        "p": "p", # error per template, but occurs
        "": [], # especially when m=ptc?
      }),
      ("lookup", "t", {
        "pres": "pres",
        "past": "past",
        "": [], # especially when m=imp?
      }),
      ("lookup", "v", {
        "actv": "act",
        "act": "act", # error per template, but occurs
        "pasv": "pass",
        "pass": "pass", # error per template, but occurs
        "": [], # especially when t=past?
      }),
      ("lookup", "m", {
        "ind": "ind",
        "indc": "ind", # error per template, but occurs
        "sub": "sub",
        "imp": "imp",
        "ptc": "part",
        "indimp": "ind//imp",
      }),
    ]),
  )),

  # Has default initial caps and final period (controllable by nocap/nodot). Both ignored.
  ("got-nom form of", (
    "infl of",
    ("error-if", ("present-except", [
      # lang= occurs at least once, and is ignored.
      "1", "c", "n", "g", "w", "t", "tr", "comp-of", "sup-of", "presptc-of", "pastptc-of", "nocap", "nodot", "lang"
    ])),
    ("set", "1", [
      "got",
      ("copy", "1"),
    ]),
    ("copy", "tr"),
    ("set", "3", [
      "",
      ("lookup", "w", {
        "w": "wk",
        "s": "str",
        "": [],
      }),
      ("lookup", "c", {
        "nom": "nom",
        "nomvoc": "nom//voc",
        "nomacc": "nom//acc",
        "nomaccvoc": "nom//acc//voc",
        "acc": "acc",
        "accvoc": "acc//voc",
        "gen": "gen",
        "dat": "dat",
        "datvoc": "dat//voc",
        "accdat": "acc//dat",
        "accdatvoc": "acc//dat//voc",
      }),
      ("lookup", "g", {
        "m": "m",
        "f": "f",
        "n": "n",
        "mf": "m//f",
        "mn": "m//n",
        "mfn": "m//f//n",
        "": [],
      }),
      ("lookup", "n", {
        "sg": "s",
        "s": "s", # error per template, but occurs
        "du": "d",
        "pl": "p",
        "p": "p", # error per template, but occurs
        "": [],
      }),
    ]),
    ("copy", "comp-of"),
    ("copy", "sup-of"),
    ("copy", "presptc-of", "prespart-of"),
    ("copy", "pastptc-of", "pastpart-of"),
  )),
]

def hi_ur_specs(lang):
  return [
    # NOTE: Has automatic, non-controllable final period that we're ignoring.
    # Doesn't have initial caps.
    ("%s-form-adj" % lang, (
      "adj form of",
      ("error-if", ("present-except", ["1", "2", "3"])),
      ("set", "1", [
        lang,
        ("copy", "3"),
        "",
        ("lookup", "1", {
          "d": "dir",
          "i": "obl",
          "o": "obl",
          "v": "voc",
          "": [],
        }),
        ("lookup", "2", {
          "ms": ["m", "s"],
          "mp": ["m", "p"],
          "fs": ["f", "s"],
          "fp": ["f", "p"],
        }),
      ]),
    )),

    # NOTE: Has automatic, non-controllable final period that we're ignoring.
    # Doesn't have initial caps.
    ("%s-form-adj-verb" % lang, (
      "verb form of",
      ("error-if", ("present-except", ["1", "2", "3"])),
      ("set", "1", [
        lang,
        ("copy", "3"),
        "",
        # Template has the order 1, 2.
        ("lookup", "2", {
          "ms": ["m", "s"],
          "mp": ["m", "p"],
          "fs": ["f", "s"],
          "fp": ["f", "p"],
        }),
        ("lookup", "1", {
          "h": "hab",
          "p": "pfv",
          "c": ["cont", "part"],
        }),
        ["adj", "form"],
      ]),
    )),

    # NOTE: Has automatic, non-controllable final period that we're ignoring.
    # Doesn't have initial caps.
    ("%s-form-noun" % lang, (
      "noun form of",
      # lang= occurs at least once, and is ignored.
      ("error-if", ("present-except", ["1", "2", "3", "lang"])),
      ("set", "1", [
        lang,
        ("copy", "3"),
        "",
        ("lookup", "1", {
          "d": "dir",
          "i": "obl",
          "o": "obl",
          "v": "voc",
        }),
        ("lookup", "2", {
          "s": "s",
          "p": "p",
        }),
      ]),
    )),

    # NOTE: Has automatic, non-controllable final period that we're ignoring.
    # Doesn't have initial caps.
    ("%s-form-verb" % lang, (
      "verb form of",
      ("error-if", ("present-except", ["1", "2"])),
      ("set", "1", [
        lang,
        ("copy", "2"),
        "",
        ("lookup", "1", {
          "tu": ["intim", "2s", "imp"],
          "imp-tu": ["intim", "2s", "imp"],
          "tum": ["fam", "2", "imp"],
          "imp-tum": ["fam", "2", "imp"],
          "ap": ["pol", "2", "imp"],
          "imp-ap": ["pol", "2", "imp"],
          "r": ["root", "form"],
          "i": ["obl", "inf"],
          "o": ["obl", "inf"],
          "c": ["conj", "form"],
          "a": ["pros"],
          "p": ["pros"],
        }),
      ]),
    )),
  ]

hi_specs = hi_ur_specs("hi")

hu_grammar_table = {
  "s": "s",
  "p": "p",
  "nom": "nom",
  "acc": "acc",
  "dat": "dat",
  "ins": "ins",
  "cfin": "cfin",
  "tran": "tran",
  "term": "term",
  "temp": "temp",
  "efor": "efor",
  "emod": "emod",
  "ine": "ine",
  "sup": "spe",
  "spe": "spe",
  "ade": "ade",
  "ill": "ill",
  "sub": "sbl",
  "sbl": "sbl",
  "all": "all",
  "ela": "ela",
  "del": "del",
  "abl": "abl",
  "pos": [],
  "1s": ["1", "s", "spos", "poss"],
  "2s": ["2", "s", "spos", "poss"],
  "3s": ["3", "s", "spos", "poss"],
  "4s": ["1", "p", "spos", "poss"],
  "5s": ["2", "p", "spos", "poss"],
  "6s": ["3", "p", "spos", "poss"],
  "1p": ["1", "s", "mpos", "poss"],
  "2p": ["2", "s", "mpos", "poss"],
  "3p": ["3", "s", "mpos", "poss"],
  "4p": ["1", "p", "mpos", "poss"],
  "5p": ["2", "p", "mpos", "poss"],
  "6p": ["3", "p", "mpos", "poss"],
  "1": "1",
  "2": "2",
  "3": "3",
  "": [],
}

hu_specs = [
  ("hu-inflection of", (
    # May be rewritten later to 'noun form of', etc.
    "infl of",
    # Template currently ignores both nocat= and pos=
    ("error-if", ("present-except", ["1", "2", "3", "4", "tr", "nocat", "pos"])),
    ("set", "1", [
      "hu",
      ("copy", "1"),
    ]),
    ("copy", "tr"),
    ("set", "3", [
      "",
      ("lookup", "2", hu_grammar_table),
      ("lookup", "3", hu_grammar_table),
      # 4= not allowed by template but occurs
      ("lookup", "4", hu_grammar_table),
    ]),
    # copy these just in case they're needed later, and p= will help with
    # rewriting
    ("copy", "nocat"),
    ("copy", "pos", "p"),
  )),

  ("hu-participle", (
    "participle of",
    ("error-if", ("present-except", ["1", "2", "t", "id"])),
    ("set", "1", [
      "hu",
      ("copy", "1"),
      "",
      ("lookup", "2", {
        "t": "past",
        "tt": "past",
        "ott": "past",
        "ett": "past",
        "ött": "past",
        "ó": "pres",
        "ő": "pres",
        "andó": "fut",
        "endő": "fut",
        "va": "adv",
        "ve": "adv",
        "ván": "adv",
        "vén": "adv",
        "ta": "verbal",
        "te": "verbal",
        "otta": "verbal",
        "ette": "verbal",
        "ötte": "verbal",
      }),
    ]),
    ("copy", "t"),
    ("copy", "id"),
  )),
]

hy_specs = [
  ("hy-form-noun", (
    "noun form of",
    ("error-if", ("present-except", ["1", "2", "3", "4", "5", "6", "tr"])),
    ("set", "1", [
      "hy",
      ("copy", "4"),
    ]),
    ("copy", "tr"),
    ("set", "3", [
      "",
      # Template has order 1, 2, 3, 5 but putting "def" first makes more sense.
      ("lookup", "3", {
        "d": "def",
        "def": "def",
        "i": [], # occurs in a few forms despite docs
        "": [],
      }),
      ("lookup", "1", {
        "n": "nom",
        "nom": "nom",
        "a": "acc",
        "ac": "acc",
        "acc": "acc",
        "g": "gen",
        "gen": "gen",
        "d": "dat",
        "dat": "dat",
        "ab": "abl",
        "abl": "abl",
        "i": "ins",
        "ins": "ins",
        "l": "loc",
        "loc": "loc",
      }),
      ("lookup", "2", {
        "s": "s",
        "sg": "s",
        "p": "p",
        "pl": "p",
      }),
      ("lookup", "5", {
        "1": ["1", "poss"],
        "2": ["2", "poss"],
        "": [],
      }),
      ("lookup", "6", {
        "n": ["nomz", "form"],
        "nom": ["nomz", "form"],
        "": [],
      }),
    ]),
  )),
]

is_specs = [
  ("is-conjugation of", (
    "verb form of",
    # lang= occurs at least once, and is ignored.
    ("error-if", ("present-except", ["1", "2", "3", "4", "5", "6", "7", "lang"])),
    ("set", "1", [
      "is",
      ("copy", "1"),
      "",
      ("copy", "2"),
      ("copy", "3"),
      ("copy", "4"),
      ("copy", "5"),
      ("copy", "6"),
      # The template code only looks up through 6 but some templates go
      # through 7.
      ("copy", "7"),
    ]),
  )),

  ("is-inflection of", (
    "infl of",
    # lang= occurs at least once, and is ignored.
    ("error-if", ("present-except", ["1", "2", "3", "4", "5", "6", "lang"])),
    ("set", "1", [
      "is",
      ("copy", "1"),
      "",
      ("copy", "2"),
      ("copy", "3"),
      ("copy", "4"),
      ("copy", "5"),
    ]),
    ("set", "p",
      ("lookup", "6", {
        "proper": "pn",
        "": [],
      }),
    ),
  )),
]

it_specs = [
  ("it-adj form of", romance_adj_form_of("it")),
  ("it-noun-pl", (
    "head",
    ("comment", "rename {{__TEMPNAME__}} to {{head|it|noun plural form}}"),
    ("error-if", ("present-except", ["head", "1", "g"])),
    ("set", "1", [
      "it",
      "noun plural form",
    ]),
    ("copy", "head"),
    ("set", "g",
      ("lookup", "1", {
        "m": "m-p",
        "f": "f-p",
        "mf": "mf-p",
        "": [],
      }),
    ),
    ("set", "g",
      ("lookup", "g", {
        "m": "m-p",
        "f": "f-p",
        "mf": "mf-p",
        "": [],
      }),
    ),
  ))
]

ja_specs = [
  ("ja-past of verb", (
    "verb form of",
    ("error-if", ("present-except", ["1"])),
    ("set", "1", [
      "ja",
      ("copy", "1"),
      "",
      "past",
    ]),
  )),

  ("ja-te form of verb", (
    "verb form of",
    ("error-if", ("present-except", ["1", "sort"])),
    ("set", "1", [
      "ja",
      ("copy", "1"),
      "",
      ["conj", "form"],
    ]),
    ("copy", "sort"),
  )),
]

ka_specs = [
  # NOTE: Has automatic, non-controllable initial caps that we're ignoring.
  # Doesn't have final period.
  ("ka-verbal for", (
    "verbal noun of",
    # lang= occurs at least once, and is ignored.
    ("error-if", ("present-except", ["1", "lang"])),
    ("set", "1", [
      "ka",
      ("copy", "1"),
    ]),
  )),

  ("ka-verbal of", "ka-verbal for"),
]

def ku_headword(template, pos):
  return (template,
    ("head",
      ("comment", "rename {{__TEMPNAME__}} to {{head|ku|%s}}" % pos),
      ("error-if", ("present-except", ["head", "sort", "1"])),
      ("set", "1", [
        "ku",
        pos,
      ]),
      ("copy", "1", "head"),
      ("copy", "head"),
      ("copy", "sort"),
  ))

ku_specs = [
  # NOTE: Has automatic, non-controllable initial caps and final period.
  # Both ignored.
  ("ku-verb form of", (
    "verb form of",
    ("error-if", ("present-except", ["1", "2", "3", "4"])),
    ("set", "1", [
      "ku",
      ("copy", "1"),
      "",
      ("lookup", "2", {
        "pr": ["pres", "part"],
        "pp": ["past", "part"],
        True: [
          ("lookup", "2", {
            "1": "1",
            "2": "2",
            "3": "3",
          }),
          ("lookup", "3", {
            "s": "s",
            "p": "p",
          }),
          ("lookup", "4", {
            "g": "pres",
            "ng": ["neg", "pres"],
            "v": ["pret"],
            "nv": ["neg", "pret"],
            "k1": ["sub", "I"],
            "ps": ["past", "prog"],
            "fp": ["fut", "perf"],
            "nfp": ["neg", "fut", "perf"],
            "nfs": ["neg", "fut"],
            "i": ["imp"],
            "nim": ["neg", "imp"],
            "fs": "fut",
            "pps": ["pres", "perf", "sub"],
            "spres": ["spres", "sub"],
            "plups": ["plup", "sub"],
            "pp": ["pres", "perf"],
            "npp": ["neg", "pres", "perf"],
            "p": ["plup"],
            "np": ["neg", "plup"],
            "cond1": ["cond", "I"],
            "cond2": ["cond", "II"],
          }),
        ],
      }),
    ]),
  )),
  ku_headword("ku-adv", "adverb"),
  ku_headword("ku-interj", "interjection"),
  ku_headword("ku-noun-form", "noun form"),
  ku_headword("ku-phrase", "phrase"),
  ku_headword("ku-prep", "preposition"),
  ku_headword("ku-suffix", "suffix"),
]

def copy_la_head_if_not_pagetitle(data):
  head = data.getp("1")
  if data.getp("head2") or data.getp("head3") or data.getp("head4"):
    return head
  if head != data.pagetitle:
    return head
  return []

def la_headword(template, pos):
  return (template,
    ("head",
      ("comment", "rename {{__TEMPNAME__}} to {{head|la|%s}}" % pos),
      ("error-if", ("present-except", ["1", "head2", "head3", "head4", "g", "g1", "g2", "g3", "g4", "id"])),
      ("set", "1", [
        "la",
        pos,
      ]),
      ("set", "head", copy_la_head_if_not_pagetitle),
      ("copy", "head2"),
      ("copy", "head3"),
      ("copy", "head4"),
      ("copy", "g"),
      ("copy", "g1", "g"),
      ("copy", "g2"),
      ("copy", "g3"),
      ("copy", "g4"),
      ("copy", "id"),
    )
  )

la_specs = [
  la_headword("la-adj-form", "adjective form"),
  la_headword("la-adj form", "adjective form"),
  la_headword("la-det-form", "determiner form"),
  la_headword("la-gerund-form", "gerund form"),
  la_headword("la-noun-form", "noun form"),
  la_headword("la-num-form", "numeral form"),
  la_headword("la-part-form", "participle form"),
  la_headword("la-pronoun-form", "pronoun form"),
  la_headword("la-proper noun-form", "proper noun form"),
  la_headword("la-suffix-form", "suffix form"),
  la_headword("la-verb-form", "verb form"),
]

liv_specs = [
  ("liv-conjugation of", (
    "verb form of",
    ("error-if", ("present-except", ["1", "2", "3", "4"])),
    ("set", "1", [
      "liv",
      ("copy", "4"),
      "",
      ("lookup", "1", {
        "1st": "1",
        "2nd": "2",
        "3rd": "3",
      }),
      ("lookup", "2", {
        "sg": "s",
        "pl": "p",
      }),
      ("lookup", "3", {
        "pr": ["pres", "ind"],
        "p": ["past", "ind"],
        "n": ["neg", "form"],
        "i": ["imp"],
        # Template says imperative negative.
        "in": ["neg", "imp"],
        "c": ["cond"],
        "j": ["juss"],
        "q": ["quot"],
      }),
    ]),
  )),

  ("liv-inflection of", (
    "infl of",
    # 4 is ignored by the template but specifies the part of speech
    # and used to be used for categorization. We preserve it as it
    # might be useful in the future and it helps with rewriting.
    ("error-if", ("present-except", ["1", "2", "3", "4"])),
    ("set", "1", [
      "liv",
      ("copy", "3"),
      "",
      # Template has 1 first but it "nom pl" makes more sense than "pl nom".
      ("lookup", "2", {
        "n": "nom",
        "g": "gen",
        "p": "par",
        "d": "dat",
        "ins": "ins",
        "ill": "ill",
        "in": "ine",
        "el": "ela",
        "all": "all",
        "ad": "ade",
        "ab": "abl",
        "instr": "ist",
      }),
      ("lookup", "1", {
        "sg": "s",
        "pl": "p",
        "": [],
      }),
    ]),
    ("copy", "4", "p"),
  )),

  ("liv-participle of", (
    # May be rewritten later to 'participle of'.
    "infl of",
    ("error-if", ("present-except", ["1", "2", "3", "4", "5"])),
    ("set", "1", [
      "liv",
      ("copy", "4"),
      "",
      # Template has the order 1, 2, 3, 5 but it makes more sense to put
      # sg/pl first.
      ("lookup", "5", {
        "sg": "s",
        "pl": "p",
        "": [],
      }),
      ("lookup", "1", {
        "pr": "present",
        "p": "past",
        "": [],
      }),
      ("lookup", "2", {
        "a": "act",
        "pa": "pass",
        "": [],
      }),
      ("lookup", "3", {
        "part": "part",
        "g": "ger",
        "s": "sup",
        "sa": ["sup", "abe"],
        "d": ["deb"],
      }),
    ]),
  )),
]

lt_adj_gender_number_table = {
  "m": ["m", "s"],
  "ms": ["m", "s"],
  "f": ["f", "s"],
  "fs": ["f", "s"],
  "n": ["n"],
  "mp": ["m", "p"],
  "mpl": ["m", "p"],
  "fp": ["f", "p"],
  "fpl": ["f", "p"],
}

lt_adj_case_table = {
  "n": "nom",
  "nom": "nom",
  "nominative": "nom",
  "g": "gen",
  "gen": "gen",
  "genitive": "gen",
  "d": "dat",
  "dat": "dat",
  "dative": "dat",
  "a": "acc",
  "acc": "acc",
  "accusative": "acc",
  "i": "ins",
  "inst": "ins",
  "instrumental": "ins",
  "l": "loc",
  "loc": "loc",
  "locative": "loc",
  "v": "voc",
  "voc": "voc",
  "vocative": "voc",
  "": [], # can occur when 1= is given
}

lt_specs = [
  # NOTE: Has automatic, non-controllable final period that we're ignoring.
  # Doesn't have initial caps.
  ("lt-būdinys", (
    "participle of",
    ("error-if", ("present-except", ["1"])),
    ("set", "1", [
      "lt",
      ("copy", "1"),
      "",
      # Template says '"manner of action" būdinys participle of'.
      ["adv", "budinys"],
    ]),
  )),

  ("lt-budinys", "lt-būdinys"),

  # NOTE: Has automatic, non-controllable final period that we're ignoring.
  # Doesn't have initial caps.
  ("lt-dalyvis-1", (
    "participle of",
    ("error-if", ("present-except", ["1", "2", "3"])),
    ("set", "1", [
      "lt",
      ("copy", "3"),
      "",
      ("lookup", "1", {
        "pres": "pres",
        "present": "pres",
        "past": "past",
        "pastf": ["freq", "past"],
        "fpast": ["freq", "past"],
        "fut": "fut",
        "future": "fut",
      }),
      ("lookup", "2", {
        "a": "act",
        "act": "act",
        "active": "act",
        "p": "pass",
        "pass": "pass",
        "passive": "pass",
      }),
      # Template says "dalyvis participle of" but we don't include the
      # word "dalyvis" as these are just regular participles.
    ]),
  )),

  ("lt-dalyvis", "lt-dalyvis-1"),

  # NOTE: Has automatic, non-controllable final period that we're ignoring.
  # Doesn't have initial caps.
  ("lt-dalyvis-2", (
    "infl of",
    ("error-if", ("present-except", ["1"])),
    ("set", "1", [
      "lt",
      ("copy", "1"),
      "",
      # Template says "dalyvis participle of necessity of" but we don't
      # include the word "dalyvis" as these are just regular participles.
      "partnec",
    ]),
  )),

  # NOTE: Has automatic, non-controllable final period that we're ignoring.
  # Doesn't have initial caps.
  ("lt-form-adj", (
    "adj form of",
    ("error-if", ("present-except", ["pro", "1", "2", "3", "4"])),
    ("set", "1", [
      "lt",
      ("copy", "4"),
      "",
      ("lookup", "pro", {
        "+": "pron",
        "y": "pron",
        "yes": "pron",
        "": [],
      }),
      # Template has the order 1, 2, 3. It looks better to have case before gender, and we need the
      # comparative/superlative last or we get "comparative degree ablative feminine singular", which IMO
      # looks bad.
      ("lookup", "3", lt_adj_case_table),
      ("lookup", "2", lt_adj_gender_number_table),
      ("lookup", "1", {
        # Template includes "positive" explicitly but generally we don't include it, so omit it here.
        "a": [], # positive degree
        "abs": [], # positive degree
        "p": [], # positive degree
        "pos": [], # positive degree
        "c": "comd",
        "com": "comd",
        "comp": "comd",
        "s": "supd",
        "sup": "supd",
        "": [],
      }),
    ]),
  )),

  # NOTE: Has automatic, non-controllable final period that we're ignoring.
  # Doesn't have initial caps. Categorizes into 'adjective forms', which
  # should be handled by the headword.
  ("lt-form-adj-is", (
    "adj form of",
    ("error-if", ("present-except", ["1", "2", "3"])),
    ("set", "1", [
      "lt",
      ("copy", "3"),
      "",
      # Template has the order 1, 2.
      ("lookup", "2", lt_adj_case_table),
      ("lookup", "1", lt_adj_gender_number_table),
    ]),
  )),

  # NOTE: Has automatic, non-controllable final period that we're ignoring.
  # Doesn't have initial caps. Categorizes into 'noun forms', which
  # should be handled by the headword.
  ("lt-form-noun", (
    "noun form of",
    # lang= occurs at least once, and is ignored.
    ("error-if", ("present-except", ["1", "2", "3", "lang"])),
    ("set", "1", [
      "lt",
      ("copy", "3"),
      "",
      ("lookup", "1", {
        "n": "nom",
        "nom": "nom",
        "g": "gen",
        "gen": "gen",
        "d": "dat",
        "dat": "dat",
        "a": "acc",
        "acc": "acc",
        "v": "voc",
        "voc": "voc",
        "l": "loc",
        "loc": "loc",
        "i": "ins",
        "ins": "ins",
      }),
      ("lookup", "2", {
        "s": "s",
        "p": "p",
        "": [],
      }),
    ]),
  )),

  # NOTE: Has automatic, non-controllable final period that we're ignoring.
  # Doesn't have initial caps.
  ("lt-form-part", (
    "infl of",
    ("error-if", ("present-except", ["pro", "1", "2", "3"])),
    ("set", "1", [
      "lt",
      ("copy", "3"),
      "",
      ("lookup", "pro", {
        "+": "pron",
        "y": "pron",
        "yes": "pron",
        "": [],
      }),
      # Template has the order 1, 2.
      ("lookup", "2", lt_adj_case_table),
      ("lookup", "1", lt_adj_gender_number_table),
    ]),
  )),

  # NOTE: Has automatic, non-controllable final period that we're ignoring.
  # Doesn't have initial caps. Categorizes into 'pronoun forms', which
  # should be handled by the headword.
  ("lt-form-pronoun", (
    "infl of",
    # Template handles class= and displays pre-text, but it never occurs.
    ("error-if", ("present-except", ["1", "2", "3", "4"])),
    ("set", "1", [
      "lt",
      ("copy", "3"),
      "",
      # Template has the order 1, 4, 2.
      ("lookup", "1", {
        "1s": "1s",
        "2s": "2s",
        "3s": "3s",
        "1d": "1d",
        "2d": "2d",
        "3d": "3d",
        "1p": "1p",
        "2p": "2p",
        "3p": "3p",
        "": [],
      }),
      ("lookup", "2", {
        "n": "nom",
        "nom": "nom",
        "g": "gen",
        "gen": "gen",
        "d": "dat",
        "dat": "dat",
        "a": "acc",
        "acc": "acc",
        "l": "loc",
        "loc": "loc",
        "i": "ins",
        "ins": "ins",
      }),
      ("lookup", "4", {
        "ms": ["m", "s"],
        "fs": ["f", "s"],
        "mp": ["m", "p"],
        "fp": ["f", "p"],
        "": [],
      }),
    ]),
  )),

  # NOTE: Has automatic, non-controllable final period that we're ignoring.
  # Doesn't have initial caps. Categorizes into 'verb forms', which
  # should be handled by the headword.
  ("lt-form-verb", (
    "verb form of",
    # lang= occurs at least once, and is ignored.
    ("error-if", ("present-except", ["1", "2", "3", "4", "lang"])),
    ("set", "1", [
      "lt",
      ("copy", "3"),
      "",
      ("lookup", "1", {
        "1s": "1s",
        "2s": "2s",
        "3s": "3s",
        "1p": "1p",
        "2p": "2p",
        "3p": "3p",
      }),
      ("lookup", "2", {
        "pres": "pres",
        "present": "pres",
        "past": "past",
        "pastf": ["freq", "past"],
        "fpast": ["freq", "past"],
        "fut": "fut",
        "future": "fut",
        "sub": "sub",
        "subjunctive": "sub",
        "imp": "imp",
        "impr": "imp",
        "imperative": "imp",
      }),
      ("lookup", "4", {
        "ref": "refl",
        "reflexive": "refl",
        "refshort": ["refl", "short", "form"],
        "reflexive shortened": ["refl", "short", "form"],
        "": [],
      }),
    ]),
  )),

  # NOTE: Has automatic, non-controllable final period that we're ignoring.
  # Doesn't have initial caps.
  ("lt-padalyvis", (
    "participle of",
    ("error-if", ("present-except", ["1", "2"])),
    ("set", "1", [
      "lt",
      ("copy", "2"),
      "",
      ("lookup", "1", {
        "pres": "pres",
        "present": "pres",
        "past": "past",
        "pastf": ["freq", "past"],
        "fpast": ["freq", "past"],
        "fut": "fut",
        "future": "fut",
      }),
      ["adv", "padalyvis"],
    ]),
  )),

  # NOTE: Has automatic, non-controllable final period that we're ignoring.
  # Doesn't have initial caps.
  ("lt-pusdalyvis", (
    "participle of",
    ("error-if", ("present-except", ["1"])),
    ("set", "1", [
      "lt",
      ("copy", "1"),
      "",
      ["adv", "pusdalyvis"],
    ]),
  )),
]

lv_grammar_table = {
  "m": "m",
  "f": "f",
  "s": "s",
  "p": "p",
  "d": "d",
  "prx": "prox",
  "dst": "dstl",
  "nom": "nom",
  "acc": "acc",
  "dat": "dat",
  "gen": "gen",
  "ins": "ins",
  "voc": "voc",
  "loc": "loc",
  "1st": "1",
  "2nd": "2",
  "3rd": "3",
  "prs": "pres",
  "pst": "past",
  "past": "past",
  "fut": "fut",
  "ind": "ind",
  "imp": "imp",
  "deb": "deb",
  "cnj": "conj",
  "cnd": "cond",
  "psv": "pass",
  "act": "act",
  "": [],
}

lv_specs = [
  ("lv-adv form of", (
    "infl of",
    # lang= and extrawidth= occur at least once each, and are ignored.
    ("error-if", ("present-except", ["1", "2", "lang", "extrawidth"])),
    ("set", "1", [
      "lv",
      ("copy", "1"),
      "",
      "adv",
      "form"
    ]),
    ("set", "p",
      ("lookup", "2", {
        "vpart": "part",
        "": [],
      }),
    ),
  )),

  ("lv-comparative of", (
    "infl of",
    ("error-if", ("present-except", ["1", "2"])),
    ("set", "1", [
      "lv",
      ("copy", "1"),
      "",
      ("lookup", "2", {
        "def": "def",
        "": "indef"
      }),
      "comd",
    ]),
  )),

  ("lv-definite of", (
    "infl of",
    ("error-if", ("present-except", ["1"])),
    ("set", "1", [
      "lv",
      ("copy", "1"),
      "",
      "def",
    ]),
  )),

  ("lv-inflection of", (
    # May be rewritten later to 'noun form of', etc.
    "infl of",
    # lang= occurs at least once, and is ignored.
    ("error-if", ("present-except", ["1", "2", "3", "4", "5", "6", "lang"])),
    ("set", "1", [
      "lv",
      ("copy", "1"),
      "",
      ("lookup", "2", lv_grammar_table),
      ("lookup", "3", lv_grammar_table),
      ("lookup", "4", lv_grammar_table),
      ("lookup", "5", lv_grammar_table),
    ]),
    # not necessary; no longer categorizes
    #("set", "p",
    #  ("lookup", "6", {
    #    "proper": "pn",
    #    "adj": "adj",
    #    "num": "num",
    #    "v": "v",
    #    "vpart": "part",
    #    "pro": "pro",
    #    "": [],
    #  }),
    #),
  )),

  ("lv-negative of", (
    "infl of",
    ("error-if", ("present-except", ["1"])),
    ("set", "1", [
      "lv",
      ("copy", "1"),
      "",
      ["neg", "form"],
    ]),
  )),

  ("lv-participle of", (
    "participle of",
    # lang= occurs at least once, and is ignored.
    ("error-if", ("present-except", ["1", "2", "3", "4", "5"])),
    ("set", "1", [
      "lv",
      ("copy", "1"),
      "",
      ("lookup", "4", {
        "adv": "adv",
        "def": "def",
        "indef": "indef",
        "": "indef",
      }),
      ("lookup", "5", {
        "obj": "objper",
        "inv": "invar",
        "var": "var",
        "": [],
      }),
      ("lookup", "2", lv_grammar_table),
      ("lookup", "3", lv_grammar_table),
    ]),
  )),

  ("lv-reflexive of", (
    "reflexive of",
    ("error-if", ("present-except", ["1"])),
    ("set", "1", [
      "lv",
      ("copy", "1"),
    ]),
  )),

  ("lv-superlative of", (
    "superlative of",
    ("error-if", ("present-except", ["1"])),
    ("set", "1", [
      "lv",
      ("copy", "1"),
    ]),
  )),

  ("lv-verbal noun of", (
    "verbal noun of",
    ("error-if", ("present-except", ["1"])),
    ("set", "1", [
      "lv",
      ("copy", "1"),
    ]),
  )),
]

mr_specs = [
  # NOTE: Has automatic, non-controllable final period that we're ignoring.
  # Doesn't have initial caps.
  ("mr-form-adj", (
    "adj form of",
    ("error-if", ("present-except", ["1", "2", "3", "tr"])),
    ("set", "1", [
      "mr",
      ("copy", "3"),
    ]),
    ("copy", "tr"),
    ("set", "3", [
      "",
      ("lookup", "1", {
        "d": "dir",
        "i": "indir",
        "o": "indir",
        "v": "voc",
        "": [],
      }),
      ("lookup", "2", {
        "ms": ["m", "s"],
        "mp": ["m", "p"],
        "fs": ["f", "s"],
        "fp": ["f", "p"],
        "ns": ["n", "s"],
        "np": ["n", "p"],
      }),
    ]),
  )),
]

mhr_grammar_table = {
  "nom": "nom",
  "acc": "acc",
  "dat": "dat",
  "gen": "gen",
  "com": "com",
  "cmp": "comc",
  "ine": "ine",
  "sil": ["short", "ill"],
  "lil": ["long", "ill"],
  "lat": "lat",
  "1st": "1",
  "2nd": "2",
  "3rd": "3",
  "1s": "1s",
  "2s": "2s",
  "3s": "3s",
  "1p": "1p",
  "2p": "2p",
  "3p": "3p",
  "0": [],
  "s": "s",
  "p": "p",
  "pos": "possd",
  "prs": "pres",
  "pst": "past",
  "fut": "fut",
  "ind": "ind",
  "imp": "imp",
  "psv": "pass",
  "act": "act",
  "": [],
}


mhr_specs = [
  # NOTE: If 2!=nom, categorizes into one of:
  # -- 6==adj -> adjective forms
  # -- 6==num -> numeral forms
  # -- 6==v -> verb forms
  # -- 6==vpart -> participle forms
  # -- 6==pro -> pronoun forms
  # -- 6==proper -> proper noun forms
  # -- 6==<anything else> -> noun forms
  # This should be handled by the headword. In practice, it seems this
  # template is only ever used for noun forms.
  ("mhr-inflection of", (
    "noun form of",
    ("error-if", ("present-except", ["1", "2", "3", "4", "5", "6"])),
    ("set", "1", [
      "mhr",
      ("copy", "1"),
      "",
      # Original template inserts "non-possessed" whenever not a
      # possessive form.
      ("lookup", "2", mhr_grammar_table),
      ("lookup", "3", mhr_grammar_table),
      ("lookup", "4", mhr_grammar_table),
      ("lookup", "5", mhr_grammar_table),
    ]),
  )),
]

mt_specs = [
  # NOTE: Has automatic, non-controllable final period that we're ignoring.
  # Doesn't have initial caps.
  ("mt-prep-form", (
    "infl of",
    ("error-if", ("present-except", ["1", "2"])),
    ("set", "1", [
      "mt",
      ("copy", "2"),
      "",
      ("lookup", "1", {
        "1s": ["1s"],
        "2s": ["2s"],
        "3sm": ["3", "m", "s"],
        "3sf": ["3", "f", "s"],
        "1p": ["1p"],
        "2p": ["2p"],
        "3p": ["3p"],
      }),
    ]),
    ("set", "p", "pre"),
  )),
]

nb_specs = [
  ("nb-noun-form-def-gen", (
    "noun form of",
    ("error-if", ("present-except", ["1"])),
    ("set", "1", [
      "nb",
      ("copy", "1"),
      "",
      ["def", "gen", "s"],
    ]),
  )),

  ("nb-noun-form-def-gen-pl", (
    "noun form of",
    ("error-if", ("present-except", ["1"])),
    ("set", "1", [
      "nb",
      ("copy", "1"),
      "",
      ["def", "gen", "p"],
    ]),
  )),

  ("nb-noun-form-indef-gen-pl", (
    "noun form of",
    ("error-if", ("present-except", ["1"])),
    ("set", "1", [
      "nb",
      ("copy", "1"),
      "",
      ["indef", "gen", "p"],
    ]),
  )),
]

nl_verb_form_of_p = ("lookup", "p", {
  "1": "1",
  "2": "2",
  "2-u": "2-u",
  "2-gij": "2-gij",
  "3": "3",
  "12": "12",
  "13": "13",
  "23": "23",
  "123": "123",
  "": [],
})
nl_verb_form_of_n = ("lookup", "n", {
  "sg": "s",
  "pl": "p",
  "": [],
})
nl_verb_form_of_sub = ("lookup", "sub", {
  "": [],
  True: "dep",
})
nl_verb_form_of_t = ("lookup", "t", {
  "pres": "pres",
  "past": "past",
  "": [],
})

nl_specs = [
  ("nl-noun form of",
    lambda data: (
      "plural of" if data.getp("1") == "pl" else "diminutive of",
      ("error-if", ("present-except", ["1", "2", "3"])),
      ("set", "1", [
        "nl",
        ("copy", "2"),
      ]),
      ("copy", "3", "t"),
    ) if data.getp("1") in ["pl", "dim"] else (
      "infl of",
      ("error-if", ("present-except", ["1", "2", "3"])),
      ("set", "1", [
        "nl",
        ("copy", "2"),
        "",
        ("copy", "1"),
        "s",
      ]),
      ("copy", "3", "t"),
    )
  ),
  ("nl-verb form of", (
    "infl of",
    # nodot= is ignored by the template but occurs.
    ("error-if", ("present-except", ["1", "2", "p", "n", "t", "m", "sub", "nodot"])),
    ("set", "1", [
      "nl",
      ("copy", "1"),
      "",
      nl_verb_form_of_p,
      nl_verb_form_of_n,
      nl_verb_form_of_sub,
      nl_verb_form_of_t,
      ("lookup", "m", {
        "imp": "imp",
        "ptc": "part",
        "subj": "sub",
        "ind": "ind",
        # If ind+sub is specified, we want to split this into two tag sets because the second tag set has a label
        # "dated or formal" associated with it.
        "ind+subj": ["ind", ";",
          nl_verb_form_of_p,
          nl_verb_form_of_n,
          nl_verb_form_of_sub,
          nl_verb_form_of_t,
          "sub",
        ],
        "": "ind",
      }),
    ]),
    ("copy", "2", "t"),
  )),
  ("nl-adj form of",
    lambda data: (
      "comparative of" if data.getp("1") == "comp" else "superlative of",
      ("error-if", ("present-except", ["1", "2", "3"])),
      ("set", "1", [
        "nl",
        ("copy", "2"),
      ]),
      ("copy", "3", "t"),
    ) if data.getp("1") in ["comp", "sup"] else (
      "infl of",
      ("error-if", ("present-except", ["1", "2", "3", "comp-of", "sup-of"])),
      ("set", "1", [
        "nl",
        ("copy", "2"),
        "",
        ("lookup", "1", {
          "infl": "infl",
          "pred": "pred",
          "part": "par",
        }),
      ]),
      ("copy", "3", "t"),
      ("copy", "comp-of"),
      ("copy", "sup-of"),
    )
  ),
]

def get_nn_verb_form_of_lemmas(data):
  lemmas = []
  no_end = data.getp("no_end")
  if no_end:
    lemmas.append(no_end)
  no_end2 = data.getp("no_end2")
  if no_end2:
    lemmas.append(no_end2)
  arg2 = data.getp("2")
  if arg2:
    lemmas.append(arg2 + "a")
  arg3 = data.getp("3")
  if arg3:
    lemmas.append(arg3 + "a")
  return ",".join(lemmas)

nn_specs = [
  ("nn-verb-form of", (
    "infl of",
    # lang= occurs at least once, and is ignored.
    ("error-if", ("present-except", ["1", "2", "3", "no_end", "no_end2", "lang"])),
    ("set", "1", [
      "nn",
      get_nn_verb_form_of_lemmas,
      "",
      ("lookup", "1", {
        "past tense": "past",
        "past": "past",
        "simple past": "past",
        "present tense": "pres",
        "present": "pres",
        "imperative": "imp",
        "imperativ": "imp",
        "present tense and imperative": ["pres", ";", "imp"],
        "past participle": ["past", "part"],
        "indefinite singular past participle": ["past", "part"],
        "definite singular past participle": ["def", "s", "past", "part"],
        "neuter past participle": ["indef", "n", "s", "past", "part"],
        "plural past participle": ["p", "past", "part"],
        "plural and definite singular past participle": ["p", "past", "part", ";", "def", "s", "past", "part"],
        "past participle definite singular and plural": ["p", "past", "part", ";", "def", "s", "past", "part"],
        "masculine and feminine past participle": ["past", "part"],
        "masculine, feminine and neuter past participle": ["past", "part"],
        "present participle": ["pres", "part"],
        "passive infinitive": ["pass", "inf"],
        "passive": ["pass", "inf"],
        "supine": ["sup"],
      }),
    ]),
  )),
]

ofs_specs = [
  # NOTE: Has default initial caps (controllable through nocap) that we
  # are ignoring. Doesn't have final period. Only 5 uses.
  ("ofs-nom form of", (
    "noun form of",
    ("error-if", ("present-except", ["1", "2", "c", "n", "g", "w", "nocap"])),
    ("set", "1", [
      "ofs",
      ("copy", "1"),
      ("copy", "2"),
      # Template has the order c, n, g, w but the order w, c, g, n makes
      # more sense.
      ("lookup", "w", {
        "w": "wk",
        "s": "str",
        "": [],
      }),
      ("lookup", "c", {
        "nom": "nom",
        "nomacc": "nom//acc",
        "acc": "acc",
        "gen": "gen",
        "dat": "dat",
        "accdat": "acc//dat",
      }),
      ("lookup", "g", {
        "m": "m",
        "f": "f",
        "n": "n",
        "mf": "mf",
        "mn": "mn",
        "mfn": "mfn",
        "": [],
      }),
      ("lookup", "n", {
        "sg": "s",
        "pl": "p",
        "": [],
      }),
    ]),
  )),
]

osx_specs = [
  # NOTE: Has default initial caps (controllable through nocap) that we
  # are ignoring. Doesn't have final period. Only 22 uses.
  ("osx-nom form of", (
    "infl of",
    ("error-if", ("present-except", ["1", "2", "c", "n", "g", "w", "nocap"])),
    ("set", "1", [
      "osx",
      ("copy", "1"),
      ("copy", "2"),
      # Template has the order c, n, g, w but the order w, c, g, n makes
      # more sense.
      ("lookup", "w", {
        "w": "wk",
        "s": "str",
        "": [],
      }),
      ("lookup", "c", {
        "nom": "nom",
        "nomacc": "nom//acc",
        "acc": "acc",
        "gen": "gen",
        "dat": "dat",
        "accdat": "acc//dat",
        "ins": "ins",
      }),
      ("lookup", "g", {
        "m": "m",
        "f": "f",
        "n": "n",
        "mf": "mf",
        "mn": "mn",
        "mfn": "mfn",
        "": [],
      }),
      ("lookup", "n", {
        "sg": "s",
        "pl": "p",
      }),
    ]),
  )),
]

pt_specs = [
  ("pt-adj form of", romance_adj_form_of("pt")),

  # NOTE: Has default initial caps (controllable through nocap) that we
  # are ignoring. Doesn't have final period. Only 11 uses.
  ("pt-adv form of", (
    lambda data: (
      "comparative of",
      ("error-if", ("present-except", ["1", "2", "nocap"])),
      ("set", "1", [
        "pt",
        ("copy", "1"),
      ]),
      ("set", "p", "adv"),
    ) if data.getp("2") == "comp" else (
      "superlative of",
      ("error-if", ("present-except", ["1", "2", "nocap"])),
      ("set", "1", [
        "pt",
        ("copy", "1"),
      ]),
      ("set", "p", "adv"),
    ) if data.getp("2") == "sup" else (
      "feminine of",
      ("error-if", ("present-except", ["1", "2", "nocap"])),
      ("set", "1", [
        "pt",
        ("copy", "1"),
      ]),
      ("set", "p", "adv"),
    )
  )),

  # Has default initial caps and final period (controllable by nocap/nodot).
  # Both ignored.
  ("pt-article form of", (
    "infl of",
    ("error-if", ("present-except", ["1", "2", "3", "nocap", "nodot"])),
    ("set", "1", [
      "pt",
      ("copy", "1"),
      "",
      ("lookup", "2", {
        "m": "m",
        "f": "f",
      }),
      ("lookup", "3", {
        "sg": "s",
        "pl": "p",
      }),
    ]),
    ("set", "p", "art"),
  )),

  ("pt-cardinal form of", (
    "feminine of",
    ("error-if", ("present-except", ["1"])),
    ("set", "1", [
      "pt",
      ("copy", "1"),
    ]),
    ("set", "p", "cnum"),
  )),

  # Has default initial caps and final period (controllable by nocap/nodot).
  # Both ignored.
  ("pt-noun form of", (
    "noun form of",
    ("error-if", ("present-except", ["1", "2", "3", "4", "t", "nocap", "nodot"])),
    ("set", "1", [
      "pt",
      ("copy", "1"),
    ]),
    ("copy", "t"), # ignored by template but sometimes present
    ("set", "3", [
      "",
      ("lookup", "4", {
        "aug": "aug",
        "dim": "dim",
        "": [],
      }),
      ("lookup", "2", {
        "m": "m",
        "f": "f",
        "mf": "mf", # not accepted by template but present
        "m-f": "mf", # not accepted by template but present
        "onlym": [],
        "onlyf": [],
      }),
      ("lookup", "3", {
        "sg": "s",
        "pl": "p",
      }),
    ]),
  )),

  # NOTE: Has automatic, non-controllable initial caps and final period.
  # Both ignored.
  ("pt-ordinal form", (
    "infl of",
    ("error-if", ("present-except", ["1", "2"])),
    ("set", "1", [
      "pt",
      lambda data:
        data.getp("1") + ("o" if data.getp("2") in ["a", "os", "as"] else "º"),
      "",
      ("lookup", "2", {
        "a": ["f", "s"],
        "os": ["m", "p"],
        "as": ["f", "p"],
        "ª": ["f", "s"],
        "ºs": ["m", "p"],
        "ªs": ["f", "p"],
      }),
    ]),
    ("set", "p", "onum"),
  )),

  ("pt-ordinal def", "pt-ordinal form"),
]

# NOTE: Has automatic, non-controllable final period that we're ignoring.
# Doesn't have initial caps. Categorizes into 'noun forms', which should be
# handled by the headword.
def ro_form_noun(data):
  number_table = {
    "s": "s",
    "p": "p",
  }
  case_table = {
    "n": "nom",
    "a": "acc",
    "g": "gen",
    "d": "dat",
    "v": "voc",
    "na": "nom//acc",
    "an": "nom//acc",
    "gd": "gen//dat",
    "dg": "gen//dat",
    "nagd": "nom//acc//gen//dat",
    "nadg": "nom//acc//gen//dat",
  }

  if data.getp("1") in ["i", "d", ""]:
    return (
      "noun form of",
      # lang= occurs at least once, and is ignored.
      ("error-if", ("present-except", ["1", "2", "3", "4", "lang"])),
      ("set", "1", [
        "ro",
        ("copy", "4"),
        "",
        ("lookup", "1", {
          "i": "indef",
          "d": "def",
          "": [],
        }),
        # Template has the order 2, 3.
        ("lookup", "3", case_table),
        ("lookup", "2", number_table),
      ]),
    )
  else:
    return (
      "noun form of",
      # lang= occurs at least once, and is ignored.
      # def=y occurs a few times and is ignored; already definite.
      ("error-if", ("present-except", ["1", "2", "3", "lang", "def"])),
      ("set", "1", [
        "ro",
        ("copy", "3"),
        "",
        "def",
        # Template has the order 1, 2.
        ("lookup", "2", case_table),
        ("lookup", "1", number_table),
      ]),
    )

ro_specs = [
  ("ro-adj-form of", (
    # Categorizes into 'adjective forms', should be handled by headword
    "adj form of",
    ("error-if", ("present-except", ["def", "1", "2", "3"])),
    ("set", "1", [
      "ro",
      ("copy", "3"),
      "",
      ("lookup", "def", {
        "y": "def",
        "yes": "def",
        "": [],
      }),
      # Template has the order 1, 2.
      ("lookup", "2", {
        "n": "nom",
        "nom": "nom",
        "nominative": "nom",
        "a": "acc",
        "acc": "acc",
        "accusative": "acc",
        "g": "gen",
        "gen": "gen",
        "genitive": "gen",
        "d": "dat",
        "dat": "dat",
        "dative": "dat",
        "v": "voc",
        "voc": "voc",
        "vocative": "voc",
        "": [],
      }),
      ("lookup", "1", {
        "m": ["m", "s"],
        "ms": ["m", "s"],
        "f": ["f", "s"],
        "fs": ["f", "s"],
        "n": ["n", "s"],
        "ns": ["n", "s"],
        "mp": ["m", "p"],
        "mpl": ["m", "p"],
        "fp": ["f", "p"],
        "fpl": ["f", "p"],
        "np": ["n", "p"],
        "npl": ["n", "p"],
        "p": "p",
      }),
    ]),
  )),

  ("ro-form-adj", "ro-adj-form of"),

  ("ro-form-noun", ro_form_noun),

  ("ro-form-verb", (
    # NOTE: Has automatic, non-controllable final period that we're ignoring.
    # Doesn't have initial caps. Categorizes into 'verb forms', which should be
    # handled by the headword.
    "verb form of",
    ("error-if", ("present-except", ["1", "2", "3"])),
    ("set", "1", [
      "ro",
      ("copy", "3"),
      "",
      ("lookup", "1", {
        "1s": "1s",
        "2s": "2s",
        "3s": "3s",
        "1p": "1p",
        "2p": "2p",
        "3p": "3p",
      }),
      ("lookup", "2", {
        "pres": ["pres", "ind"],
        "present": ["pres", "ind"],
        "impf": ["impf", "ind"],
        "imperfect": ["impf", "ind"],
        "perf": ["sim", "perf", "ind"],
        "perfect": ["sim", "perf", "ind"],
        "pret": ["sim", "perf", "ind"],
        "preterite": ["sim", "perf", "ind"],
        "imperfect": ["impf", "ind"],
        "plu": ["plup", "ind"],
        "plus": ["plup", "ind"],
        "plup": ["plup", "ind"],
        "pluperfect": ["plup", "ind"],
        "sub": ["pres", "sub"],
        "subj": ["pres", "sub"],
        "subjunctive": ["pres", "sub"],
        "impr": ["imp"],
        "imp": ["imp"], # a bug, but we can handle it; occurs once
        "imperative": ["imp"],
      }),
    ]),
  )),
]

roa_opt_specs = [
  # Has default initial caps and final period (controllable by nocap/nodot).
  # Both ignored.
  ("roa-opt-noun plural of", (
    "noun form of",
    ("error-if", ("present-except", ["1", "nocap", "nodot"])),
    ("set", "1", [
      "roa-opt",
      ("copy", "1"),
      "",
      "p",
    ]),
  )),
]

# FIXME: There should be a directive saying: append to the list,
# starting at the lowest nonexistent element.
def ru_get_nonblank_tags(data):
  tags = []
  for param in ["3", "4", "5", "6"]:
    val = data.getp(param)
    if val:
      tags.append(val)
  return tags

ru_specs = [
  ("ru-participle of", (
    "participle of",
    # lang= occurs at least once, and is ignored.
    ("error-if", ("present-except", ["1", "2", "3", "4", "5", "6", "tr",
      "gloss", "pos", "nocat", "lang"])),
    ("set", "1", [
      "ru",
      ("copy", "1"),
    ]),
    ("copy", "tr"),
    # FIXME. Verify this works.
    ("set", "3", [
      ("copy", "2"),
      ru_get_nonblank_tags,
    ]),
    ("copy", "gloss", "t"),
    ("copy", "pos"),
    ("copy", "nocat"),
  )),
]

sa_specs = [
  ("sa-desiderative of", (
    "verb form of",
    ("error-if", ("present-except", ["1"])),
    ("set", "1", [
      "sa",
      ("copy", "1"),
      "",
      "desid"
    ]),
  )),

  ("sa-desi", "sa-desiderative of"),

  ("sa-frequentative of", (
    "verb form of",
    ("error-if", ("present-except", ["1"])),
    ("set", "1", [
      "sa",
      ("copy", "1"),
      "",
      ["freq//inten"],
    ]),
  )),

  ("sa-freq", "sa-frequentative of"),

  ("sa-root form of", (
    "infl of",
    ("error-if", ("present-except", ["1"])),
    ("set", "1", [
      "sa",
      ("copy", "1"),
      "",
      ["root", "form"],
    ]),
  )),

]

sco_specs = [
  ("sco-simple past of", (
    "verb form of",
    ("error-if", ("present-except", ["1", "2"])),
    ("set", "1", [
      "sco",
      ("copy", "1"),
      ("copy", "2"),
      "spast"
    ]),
  )),

  ("sco-third-person singular of", (
    "verb form of",
    # lang= occurs at least once, and is ignored.
    ("error-if", ("present-except", ["1", "2", "lang"])),
    ("set", "1", [
      "sco",
      ("copy", "1"),
      ("copy", "2"),
      ["3s", "spres", "ind"],
    ]),
  )),
]

sga_specs = [
  ("sga-verbnec of", (
    "infl of",
    ("error-if", ("present-except", ["1"])),
    ("set", "1", [
      "sga",
      ("copy", "1"),
      "",
      "verbnec"
    ]),
  )),
]

sh_case_map = {
  "n": "nom",
  "nom": "nom",
  "g": "gen",
  "gen": "gen",
  "d": "dat",
  "dat": "dat",
  "a": "acc",
  "acc": "acc",
  "v": "voc",
  "voc": "voc",
  "l": "loc",
  "loc": "loc",
  "i": "ins",
  "ins": "ins",
}

sh_specs = [
  # NOTE: Categorizes into "noun forms", but this should be handled by
  # the headword.
  ("sh-form-noun", (
    "noun form of",
    # ignore sc=Cyrl.
    ("error-if", ("present-except", ["1", "2", "3", "sc"])),
    ("set", "1", [
      "sh",
      ("copy", "3"),
      "",
      ("lookup", "1", sh_case_map),
      ("lookup", "2", {
        "s": "s",
        "p": "p",
      }),
    ]),
  )),

  # NOTE: Categorizes into "proper noun forms", but this should be handled by
  # the headword. Otherwise identical to {{sh-form-noun}}.
  ("sh-form-proper-noun", (
    "infl of",
    # ignore sc=Cyrl.
    ("error-if", ("present-except", ["1", "2", "3", "sc"])),
    ("set", "1", [
      "sh",
      ("copy", "3"),
      "",
      ("lookup", "1", sh_case_map),
      ("lookup", "2", {
        "s": "s",
        "p": "p",
      }),
    ]),
    ("set", "p", "pn"),
  )),

  # NOTE: Has automatic, non-controllable final period that we're ignoring.
  # Doesn't have initial caps.
  ("sh-verb form of", (
    lambda data:
      ("verbal noun of",
        ("comment", "rename {{__TEMPNAME__|vn}} to {{verbal noun of|sh}}"),
        # ignore sc=Cyrl.
        ("error-if", ("present-except", ["1", "2", "3", "sc"])),
        ("error-if", ("neq", "2", "")),
        ("set", "1", [
          "sh",
          ("copy", "3")
        ])
      ) if data.getp("1") == "vn" else
      ("verb form of",
        # ignore sc=Cyrl.
        ("error-if", ("present-except", ["1", "2", "3", "4", "sc"])),
        ("set", "1", [
          "sh",
          ("copy", "3"),
          ("copy", "4"),
          ("lookup", "1", {
            "1s": "1s",
            "2s": "2s",
            "3s": "3s",
            "1p": "1p",
            "2p": "2p",
            "3p": "3p",
          }),
          ("lookup", "2", {
            "pres": "pres",
            "present": "pres",
            "fut": "fut",
            "future": "fut",
            "imp": "imp",
            "imper": "imp",
            "imperative": "imp",
            "aor": "aor",
            "aorist": "aor",
            "impf": "impf",
            "imperfect": "impf",
          }),
        ]),
      )
  )),

  ("sh-form-verb", "sh-verb form of"),

  ("sh-verb-form of", "sh-verb form of"),

  ("sh-verb-form-of", "sh-verb form of"),
]

def sl_check_1_is_m(data, should_return):
  if data.getp("1") == "m":
    return should_return
  else:
    raise BadTemplateValue("Expected 1=m with output of %s" %
      "|".join(should_return)
    )

sl_specs = [
  ("sl-form-adj", (
    "adj form of",
    ("error-if", ("present-except", ["1", "2", "3", "4"])),
    ("set", "1", [
      "sl",
      ("copy", "4"),
      "",
      # Template has the order 1, 2, 3.
      ("lookup", "3", {
        "n": "nom",
        "g": "gen",
        "d": "dat",
        "a": "acc",
        "l": "loc",
        "i": "ins",
        "nd": lambda data: sl_check_1_is_m(data, ["def", "nom"]),
        "dn": lambda data: sl_check_1_is_m(data, ["def", "nom"]),
        "ad": lambda data: sl_check_1_is_m(data, ["def", "acc"]),
        "da": lambda data: sl_check_1_is_m(data, ["def", "acc"]),
        "ai": lambda data: sl_check_1_is_m(data, ["indef", "acc"]),
        "ia": lambda data: sl_check_1_is_m(data, ["indef", "acc"]),
        "aa": lambda data: sl_check_1_is_m(data, ["an", "acc"]),
      }),
      ("lookup", "1", {
        "m": "m",
        "f": "f",
        "n": "n",
      }),
      ("lookup", "2", {
        "s": "s",
        "d": "d",
        "p": "p",
      }),
    ]),
  )),

  # NOTE: Has automatic, non-controllable final period that we're ignoring.
  # Doesn't have initial caps.
  ("sl-form-noun", (
    "noun form of",
    ("error-if", ("present-except", ["1", "2", "3"])),
    ("set", "1", [
      "sl",
      ("copy", "3"),
      "",
      ("lookup", "1", {
        "n": "nom",
        "nom": "nom",
        "g": "gen",
        "gen": "gen",
        "d": "dat",
        "dat": "dat",
        "a": "acc",
        "acc": "acc",
        "l": "loc",
        "loc": "loc",
        "i": "ins",
        "ins": "ins",
      }),
      ("lookup", "2", {
        "s": "s",
        "d": "d",
        "p": "p",
      }),
    ]),
  )),

  # NOTE: Has automatic, non-controllable final period that we're ignoring.
  # Doesn't have initial caps.
  ("sl-form-verb", (
    "verb form of",
    ("error-if", ("present-except", ["1", "2", "3"])),
    ("set", "1", [
      "sl",
      ("copy", "3"),
      "",
      ("lookup", "1", {
        "1s": "1s",
        "2s": "2s",
        "3s": "3s",
        "1d": "1d",
        "2d": "2d",
        "3d": "3d",
        "1p": "1p",
        "2p": "2p",
        "3p": "3p",
      }),
      ("lookup", "2", {
        "pres": "pres",
        "present": "pres",
        "fut": "fut",
        "future": "fut",
        "imp": "imp",
        "imperative": "imp",
      }),
    ]),
  )),

  # NOTE: Has automatic, non-controllable final period that we're ignoring.
  # Doesn't have initial caps.
  ("sl-participle of", (
    # May be rewritten later to 'participle of', etc.
    "infl of",
    ("error-if", ("present-except", ["1", "2"])),
    ("set", "1", [
      "sl",
      ("copy", "2"),
      "",
      ("lookup", "1", {
        "pr-a": ["pres", "act", "part"],
        "pa-a": ["past", "act", "part"],
        "pa-p": ["past", "pass", "part"],
        "s": ["sup"],
        "pr-g": ["pres", "act", "ger"],
        "pa-g": ["past", "act", "ger"],
      }),
    ]),
  )),

  ("sl-verb form of", "sl-form-verb"),
]

def sv_form(template, parts, with_plural_of=False):
  return (
    template,
    ("error-if", ("present-except", ["1", "2", "dot"] + (["plural of"] if with_plural_of else []))),
    ("set", "1", [
      "sv",
      ("copy", "1"),
      ("copy", "2"),
      parts,
    ])
  )

def sv_adj_form(parts):
  return sv_form("adj form of", parts)
def sv_noun_form(parts):
  return sv_form("noun form of", parts)
def sv_verb_form(parts):
  return sv_form("verb form of", parts)
def sv_verb_form_with_plural(parts):
  return sv_form("verb form of", parts, with_plural_of=True)

sv_specs = [
  # NOTE: All of the following adjective, adverb and verb forms have automatic,
  # non-controllable final periods that we're ignoring. Don't have initial
  # caps. No final period for the noun forms.
  # First five templates include the word "absolute" that we omit.
  ("sv-adj-form-abs-def", sv_adj_form(["def"])),
  ("sv-adj-form-abs-def+pl", sv_adj_form(["def", "s", ";", "p"])),
  ("sv-adj-form-abs-def-m", sv_adj_form(["def", "natm", "s"])),
  ("sv-adj-form-abs-indef-n", sv_adj_form(["indef", "n", "s"])),
  ("sv-adj-form-abs-pl", sv_adj_form(["p"])),
  ("sv-adj-form-comp", (
    "comparative of",
    ("error-if", ("present-except", ["1"])),
    ("set", "1", [
      "sv",
      ("copy", "1"),
    ]),
  )),
  # Template says "superlative attributive".
  ("sv-adj-form-sup-attr", sv_adj_form(["attr", "supd"])),
  # Template says "superlative attributive singular masculine".
  ("sv-adj-form-sup-attr-m", sv_adj_form(["attr", "natm", "s", "supd"])),
  # Template says "superlative predicative".
  ("sv-adj-form-sup-pred", sv_adj_form(["pred", "supd"])),
  ("sv-adv-form-comp", (
    "comparative of",
    ("error-if", ("present-except", ["1"])),
    ("set", "1", [
      "sv",
      ("copy", "1"),
    ]),
    ("set", "POS", "adverb"),
  )),
  ("sv-adv-form-sup", (
    "superlative of",
    ("error-if", ("present-except", ["1"])),
    ("set", "1", [
      "sv",
      ("copy", "1"),
    ]),
    ("set", "POS", "adverb"),
  )),
  ("sv-noun-form-def", sv_noun_form(["def", "s"])),
  ("sv-noun-form-def-gen", sv_noun_form(["def", "gen", "s"])),
  ("sv-noun-form-def-gen-pl", sv_noun_form(["def", "gen", "p"])),
  ("sv-noun-form-def-pl", sv_noun_form(["def", "p"])),
  ("sv-noun-form-indef-gen", sv_noun_form(["indef", "gen", "s"])),
  ("sv-noun-form-indef-gen-pl", sv_noun_form(["indef", "gen", "p"])),
  ("sv-noun-form-indef-pl", sv_noun_form(["indef", "p"])),
  ("sv-proper-noun-gen", (
    "infl of",
    ("error-if", ("present-except", ["1", "2"])),
    ("set", "1", [
      "sv",
      ("copy", "1"),
      ("copy", "2"),
      "gen",
    ]),
  )),
  ("sv-verb-form-imp", lambda data: (
    sv_verb_form_with_plural(["1", "p", "imp"]) if data.getp("plural of") and data.pagetitle.endswith("m")
    else sv_verb_form_with_plural(["2", "p", "imp"]) if data.getp("plural of")
    else sv_verb_form(["imp"]))),
  # Template says "infinitive passive".
  ("sv-verb-form-inf-pass", sv_verb_form(["pass", "inf"])),
  # Contrary to what we said above, this one in particular has the final
  # period controllable by |dot=, which can override it. Pretty sure it
  # never occurs.
  ("sv-verb-form-past", lambda data: (
    sv_verb_form_with_plural(["1", "p", "past", "ind"]) if data.getp("plural of") and data.pagetitle.endswith("m")
    else sv_verb_form_with_plural(["2", "p", "past", "ind"]) if data.getp("plural of") and data.pagetitle.endswith("n")
    else sv_verb_form_with_plural(["p", "past", "ind"]) if data.getp("plural of")
    else sv_verb_form(["past", "ind"]))),
  ("sv-verb-form-past-pass", lambda data: (
    sv_verb_form_with_plural(["p", "past", "pass", "ind"]) if data.getp("plural of")
    else sv_verb_form(["past", "pass", "ind"]))),
  # Contrary to what we said above, this one in particular also has the final
  # period controllable by |dot=, which can override it. Pretty sure it
  # never occurs.
  ("sv-verb-form-pastpart", sv_verb_form(["past", "part"])),
  ("sv-verb-form-pre", lambda data: (
    sv_verb_form_with_plural(["1", "p", "pres", "ind"]) if data.getp("plural of") and data.pagetitle.endswith("m")
    else sv_verb_form_with_plural(["2", "p", "pres", "ind"]) if data.getp("plural of") and data.pagetitle.endswith("n")
    else sv_verb_form_with_plural(["p", "pres", "ind"]) if data.getp("plural of")
    else sv_verb_form(["pres", "ind"]))),
  ("sv-verb-form-pre-pass", sv_verb_form(["pres", "pass", "ind"])),
  # Contrary to what we said above, this one in particular doesn't have a
  # final period.
  ("sv-verb-form-prepart", sv_verb_form(["pres", "part"])),
  ("sv-verb-form-subjunctive", sv_verb_form(["sub"])),
  ("sv-verb-form-sup", sv_verb_form(["sup"])),
  # Template says "supine passive".
  ("sv-verb-form-sup-pass", sv_verb_form(["pass", "sup"])),
]

tg_specs = [
  ("tg-adj form of", lambda data: fa_tg_adj_form_of(data, "tg")),

  ("tg-adj-form", "tg-adj form of"),

  # NOTE: Has automatic, non-controllable final period that we're ignoring.
  # Doesn't have initial caps.
  ("tg-form-verb", (
    "verb form of",
    ("error-if", ("present-except", ["1", "2"])),
    ("set", "1", [
      "fa",
      ("copy", "2"),
      "",
      ("lookup", "1", {
        "man": ["1s", "imp"],
        "imp-man": ["1s", "imp"],
        "tu": ["2s", "imp"],
        "imp-tu": ["2s", "imp"],
        "vay": ["3s", "imp"],
        "imp-vay": ["3s", "imp"],
        "mo": ["1p", "imp"],
        "imp-mo": ["1p", "imp"],
        "šomo": ["2p", "imp"],
        "imp-šomo": ["2p", "imp"],
        "onho": ["3p", "imp"],
        "imp-onho": ["3p", "imp"],
        "r": ["root", "form"],
        "prstem": ["pres", "stem", "form"],
        "pstem": ["past", "stem", "form"],
      }),
    ]),
  )),
]

tl_specs = [
  # NOTE: Has automatic, non-controllable initial caps and final period.
  # Both ignored. Categorizes into 'verb forms', which should be handled
  # by the headword.
  ("tl-verb form of", (
    "verb form of",
    # most uses have |nocat=1; ignore since there's no categorization
    ("error-if", ("present-except", ["1", "2", "nocat"])),
    ("set", "1", [
      "tl",
      ("copy", "1"),
      "",
      ("lookup", "2", {
        "comp": ["compl", "asp"],
        "prog": ["prog", "asp"],
        "cont": ["contem", "asp"],
      }),
    ]),
  )),
]

tr_grammar_table = {
  "s": "s",
  "p": "p",
  "nom": "nom",
  "acc": "acc",
  "dat": "dat",
  "abl": "abl",
  "pos": "poss",
  "1s": ["1s", "spos"],
  "2s": ["2s", "spos"],
  "3s": ["3s", "spos"],
  "4s": ["1p", "spos"],
  "5s": ["2p", "spos"],
  "6s": ["3p", "spos"],
  "1p": ["1s", "mpos"],
  "2p": ["2s", "mpos"],
  "3p": ["3s", "mpos"],
  "4p": ["1p", "mpos"],
  "5p": ["2p", "mpos"],
  "6p": ["3p", "mpos"],
  "1": "1",
  "2": "2",
  "3": "3",
  "aor": "aor",
  "cond": "cond",
  "pres": "pres",
  "def": "def",
  "inf": "inf",
  "": [],
}

tr_specs = [
  ("tr-inflection of", (
    "infl of",
    ("error-if", ("present-except", ["1", "2", "3"])),
    ("set", "1", [
      "tr",
      ("copy", "1"),
      "",
      ("lookup", "2", {
        "pos": [
          ("lookup", "3", tr_grammar_table),
          "poss",
        ],
      }),
    ]),
  )),
]

ur_specs = hi_ur_specs("ur")

def zh_headword(template, pos):
  return (template,
    ("head",
      ("comment", "rename {{__TEMPNAME__}} to {{head|zh|%s}}" % pos),
      ("error-if", ("present-except", [])),
      ("set", "1", [
        "zh",
        pos,
      ])
    )
  )

zh_specs = [
  zh_headword("zh-adj", "adjective"),
  zh_headword("zh-adjective", "adjective"),
  zh_headword("zh-adv", "adverb"),
  zh_headword("zh-adverb", "adverb"),
  zh_headword("zh-cls", "classifier"),
  zh_headword("zh-con", "conjunction"),
  zh_headword("zh-det", "determiner"),
  zh_headword("zh-hanzi", "Han character"),
  zh_headword("zh-idiom", "idiom"),
  zh_headword("zh-infix", "infix"),
  zh_headword("zh-interj", "interjection"),
  zh_headword("zh-inter", "interjection"),
  zh_headword("zh-noun", "noun"),
  zh_headword("zh-num", "numeral"),
  zh_headword("zh-particle", "particle"),
  zh_headword("zh-phrase", "phrase"),
  zh_headword("zh-post", "postposition"),
  zh_headword("zh-pref", "prefix"),
  zh_headword("zh-prep", "preposition"),
  zh_headword("zh-pronoun", "pronoun"),
  zh_headword("zh-proper noun", "proper noun"),
  zh_headword("zh-proper", "proper noun"),
  zh_headword("zh-propn", "proper noun"),
  zh_headword("zh-proverb", "proverb"),
  zh_headword("zh-punctuation mark", "punctuation mark"),
  zh_headword("zh-suf", "suffix"),
  zh_headword("zh-verb", "verb"),
]

def non_lang_specific_tagged_form_of(tags, tempname="infl of", ignore_nocat=True):
  return tuple([
    tempname,
    ("comment", "rename {{__TEMPNAME__}} to {{%s|...|%s}}" % (tempname, "|".join(tags))),
    # ignore nodot=, nocap=; ignore nocat= in most circumstances
    ("error-if", ("present-except", ["1", "2", "3", "4", "sc", "tr", "g", "t", "gloss", "pos", "cap", "nodot", "nocap",
                                     "nocat"])),
    ("set", "1", [
      ("copy", "1"),
      ("copy", "2"),
    ]),
    ("copy", "tr"),
    ("copy", "g"),
    ("set", "3", [
      ("copy", "3"),
      tags,
    ]),
    ("copy", "sc"),
    ("copy", "t"),
    ("copy", "4", "t"),
    ("copy", "gloss", "t"),
    ("copy", "pos"),
    ("copy", "cap"),
  ] + ([("copy", "nocat")] if not ignore_nocat else [])
  )

def non_lang_specific_participle_tagged_form_of(tags, ignore_nocat=True):
  return non_lang_specific_tagged_form_of(tags, "participle of", ignore_nocat=ignore_nocat)

misc_non_lang_specific_specs = [
  ("attributive form of", non_lang_specific_tagged_form_of(["attr", "form"])),
  ("definite singular of", non_lang_specific_tagged_form_of(["def", "s"])),
  ("definite plural of", non_lang_specific_tagged_form_of(["def", "p"])),
  ("dual of", non_lang_specific_tagged_form_of(["d"])),
  ("elative of", non_lang_specific_tagged_form_of(["elad"])),
  ("equative of", non_lang_specific_tagged_form_of(["equd"], ignore_nocat=False)),
  ("imperative of", non_lang_specific_tagged_form_of(["imp"])),
  ("indefinite plural of", non_lang_specific_tagged_form_of(["indef", "p"])),
  ("passive of", non_lang_specific_tagged_form_of(["pass"])),
  ("passive past tense of", non_lang_specific_tagged_form_of(["pass", "past"])),
  ("past tense of", non_lang_specific_tagged_form_of(["past"])),
  ("present tense of", non_lang_specific_tagged_form_of(["pres"])),
  ("singulative of", non_lang_specific_tagged_form_of(["sgl"])),
  ("superlative attributive of", non_lang_specific_tagged_form_of(["attr", "supd"])),
  ("superlative predicative of", non_lang_specific_tagged_form_of(["pred", "supd"])),
  ("supine of", non_lang_specific_tagged_form_of(["sup"])),
]

participle_non_lang_specific_specs = [
  ("future participle of", non_lang_specific_participle_tagged_form_of(["fut"])),
  ("perfect participle of", non_lang_specific_participle_tagged_form_of(["perf"])),
  ("present active participle of", non_lang_specific_participle_tagged_form_of(["pres", "act"])),
  ("past active participle of", non_lang_specific_participle_tagged_form_of(["past", "act"])),
  ("past passive participle of", non_lang_specific_participle_tagged_form_of(["past", "pass"])),
  ("future passive participle of", non_lang_specific_participle_tagged_form_of(["fut", "pass"])),
]

templates_to_rename_specs = (
  art_blk_specs +
  bg_specs +
  br_specs +
  ca_specs +
  cu_specs +
  da_specs +
  de_specs +
  el_specs +
  en_specs +
  enm_specs +
  es_specs +
  et_specs +
  fa_specs +
  fi_specs +
  gmq_bot_specs +
  got_specs +
  hi_specs +
  hu_specs +
  hy_specs +
  is_specs +
  it_specs +
  ja_specs +
  ka_specs +
  ku_specs +
  la_specs +
  liv_specs +
  lt_specs +
  lv_specs +
  mhr_specs +
  mr_specs +
  mt_specs +
  nb_specs +
  nl_specs +
  nn_specs +
  ofs_specs +
  osx_specs +
  pt_specs +
  ro_specs +
  roa_opt_specs +
  ru_specs +
  sa_specs +
  sco_specs +
  sga_specs +
  sh_specs +
  sl_specs +
  sv_specs +
  tg_specs +
  tl_specs +
  tr_specs +
  ur_specs +
  misc_templates_to_rewrite +
  zh_specs +
  misc_non_lang_specific_specs +
  participle_non_lang_specific_specs +
  []
)

def rewrite_to_foo_form_of(data, comment):
  t = data.t
  origt = str(t)
  tn = tname(t)
  if tn in ["inflection of", "infl of"]:
    pos = data.getp("p")
    if pos in ["n", "noun"]:
      rmparam(t, "p")
      blib.set_template_name(t, "noun form of")
    elif pos in ["a", "adj", "adjective"]:
      rmparam(t, "p")
      blib.set_template_name(t, "adj form of")
    elif pos in ["v", "verb"]:
      rmparam(t, "p")
      blib.set_template_name(t, "verb form of")
  newtn = tname(t)
  if newtn != tn:
    comment = re.sub(r"(to|with \{\{)%s([|\}])" % tn, r"\1%s\2" % newtn, comment)
  if str(t) != origt:
    data.pagemsg("rewrite_to_foo_form_of: Replaced %s with %s" %
      (origt, str(t)))

  return comment

def rewrite_to_pres_past_participle_of(data, comment):
  t = data.t
  origt = str(t)
  tn = tname(t)
  if tn in ["inflection of", "infl of", "verb form of"]:
    max_numbered = 0
    for param in t.params:
      pname = str(param.name).strip()
      if re.search("^[0-9]$", pname) and int(pname) > max_numbered:
        max_numbered = int(pname)
    if max_numbered == 5 and data.getp("4") == "pres" and data.getp("5") == "part":
      rmparam(t, "4")
      rmparam(t, "5")
      if not getparam(t, "3"):
        rmparam(t, "3")
      blib.set_template_name(t, "present participle of")
    elif max_numbered == 5 and data.getp("4") == "past" and data.getp("5") == "part":
      rmparam(t, "4")
      rmparam(t, "5")
      if not getparam(t, "3"):
        rmparam(t, "3")
      blib.set_template_name(t, "past participle of")
  newtn = tname(t)
  if newtn != tn:
    comment = re.sub(r"(to|with \{\{)%s([|\}])" % tn, r"\1%s\2" % newtn, comment)

  if str(t) != origt:
    data.pagemsg("rewrite_to_pres_past_participle_of: Replaced %s with %s" %
      (origt, str(t)))

  return comment

def rewrite_to_general_participle_of(data, comment):
  t = data.t
  origt = str(t)
  tn = tname(t)
  if tn in ["inflection of", "infl of", "verb form of"]:
    max_numbered = 0
    for param in t.params:
      pname = str(param.name).strip()
      if re.search("^[0-9]$", pname) and int(pname) > max_numbered:
        max_numbered = int(pname)
    if data.getp(str(max_numbered)) == "part":
      rmparam(t, str(max_numbered))
      blib.set_template_name(t, "participle of")
  newtn = tname(t)
  if newtn != tn:
    comment = re.sub(r"(to|with \{\{)%s([|\}])" % tn, r"\1%s\2" % newtn, comment)

  if str(t) != origt:
    data.pagemsg("rewrite_to_general_participle_of: Replaced %s with %s" %
      (origt, str(t)))

  return comment

def rewrite_person_number_of(data, comment):
  t = data.t
  origt = str(t)
  tn = tname(t)
  if tn in ["inflection of", "infl of", "verb form of", "noun form of", "adj form of",
      "participle of"]:
    first_rewrite_param = None
    first_rewrite_val = None
    for param in t.params:
      pname = str(param.name).strip()
      if re.search("^[0-9]$", pname) and int(pname) > 1:
        pval = data.getp(pname)
        prevval = data.getp(str(int(pname) - 1))
        if pval in ["s", "d", "p"] and prevval in ["1", "2", "3"]:
          first_rewrite_param = int(pname) - 1
          first_rewrite_val = prevval + pval
          break
    if first_rewrite_param:
      # Fetch all params.
      params = []
      for param in t.params:
        pname = str(param.name).strip()
        if re.search("^[0-9]$", pname):
          if int(pname) < first_rewrite_param:
            params.append((str(param.name), param.value, param.showkey))
          elif int(pname) == first_rewrite_param:
            params.append((str(param.name), first_rewrite_val, param.showkey))
          elif int(pname) >= first_rewrite_param + 2:
            params.append((str(int(pname) - 1), param.value, param.showkey))
        else:
          params.append((str(param.name), param.value, param.showkey))
      # Erase all params.
      del t.params[:]
      # Put back new params.
      for pname, pval, showkey in params:
        t.add(pname, pval, showkey=showkey, preserve_spacing=False)

  if str(t) != origt:
    data.pagemsg("rewrite_person_number_of: Replaced %s with %s" %
      (origt, str(t)))

  return comment

post_rewrite_hooks = [
  rewrite_to_foo_form_of,
  rewrite_to_pres_past_participle_of,
  #rewrite_to_general_participle_of,
  #rewrite_person_number_of,
]

templates_to_rename_map = {}

def initialize_templates_to_rename_map(do_all, do_specified):
  global templates_to_actually_do, templates_to_actually_do_set
  if do_all:
    templates_to_actually_do = [template for template, spec in templates_to_rename_specs]
  if do_specified:
    templates_to_actually_do = re.split(",", do_specified)
  templates_to_actually_do_set = set(templates_to_actually_do)

  for template, spec in templates_to_rename_specs:
    if isinstance(spec, str):
      templates_to_rename_map[template] = templates_to_rename_map[spec]
    else:
      templates_to_rename_map[template] = spec


def flatten_list(value):
  return [y for x in value for y in (x if type(x) is list else [x])]

@dataclass
class TemplateData:
  index: int
  pagetitle: str
  t: Template
  pagemsg: callable

  def getp(self, param):
    return getparam(self.t, param)

def expand_set_value(value, data):
  t = data.t
  def check(cond, err):
    if not cond:
      raise BadRewriteSpec("Error expanding set value for template %s: %s; value=%s" %
          (str(t), err, value))
  if callable(value):
    return expand_set_value(value(data), data)
  if isinstance(value, str):
    return value
  if isinstance(value, list):
    return flatten_list([expand_set_value(x, data) for x in value])
  check(isinstance(value, tuple),
      "wrong type %s of %s, not tuple" % (type(value), value))
  check(len(value) >= 1, "empty value")
  direc = value[0]
  if direc == "copy":
    check(len(value) == 2, "wrong length %s of value %s, != 2" %
        (len(value), value))
    if t.has(value[1]):
      return getparam(t, value[1])
    else:
      return None
  elif direc == "lookup":
    check(len(value) == 3, "wrong length %s of value %s, != 3" %
        (len(value), value))
    lookval = getparam(t, value[1]).strip()
    table = value[2]
    check(type(table) is dict, "wrong type %s of %s, not dict" % (type(table), table))
    if lookval in table:
      return expand_set_value(table[lookval], data)
    elif True in table:
      return expand_set_value(table[True], data)
    else:
      raise BadTemplateValue("Unrecognized value %s=%s" % (value[1], lookval))
  else:
    check(False, "Unrecognized directive %s" % direc)

def expand_spec(spec, data):
  t = data.t
  def check(cond, err):
    if not cond:
      raise BadRewriteSpec("Error expanding spec for template %s: %s; spec=%s" %
          (str(t), err, spec))
  if callable(spec):
    return expand_spec(spec(data), data)
  check(type(spec) is tuple, "wrong type %s of %s, not tuple" % (type(spec), spec))
  check(len(spec) >= 1, "empty spec")
  oldname = tname(t)
  newname = spec[0]
  if callable(newname):
    newname = newname(data)
  expanded_specs = []
  comment = None
  for subspec in spec[1:]:
    check(len(subspec) >= 1, "empty subspec")
    if subspec[0] == "error-if":
      check(len(subspec) == 2, "wrong length %s of subspec %s, != 2" %
          (len(subspec), subspec))
      check(len(subspec[1]) >= 1, "empty subspec[1]")
      errtype = subspec[1][0]
      if errtype == "present-except":
        check(len(subspec[1]) == 2, "wrong length %s of subspec[1] %s, != 2" %
            (len(subspec[1]), subspec[1]))
        allowed_params = set(subspec[1][1])
        for param in t.params:
          pname = str(param.name).strip()
          if pname not in allowed_params:
            raise BadTemplateValue(
                "Disallowed param %s=%s" % (pname, getparam(t, pname)))
      elif errtype == "eq":
        check(len(subspec[1]) == 3, "wrong length %s of subspec[1] %s, != 3" %
            (len(subspec[1]), subspec[1]))
        if getparam(t, subspec[1][1]) == subspec[1][2]:
          raise BadTemplateValue(
            "Disallowed value: %s=%s" % (subspec[1][1], subspec[1][2]))
      elif errtype == "neq":
        check(len(subspec[1]) == 3, "wrong length %s of subspec[1] %s, != 3" %
            (len(subspec[1]), subspec[1]))
        if getparam(t, subspec[1][1]) != subspec[1][2]:
          raise BadTemplateValue(
            "Disallowed value: %s=%s, expected %s" % (
              subspec[1][1], getparam(t, subspec[1][1]), subspec[1][2]))
      else:
        check(False, "Unrecognized error-if subtype: %s" % errtype)

    elif subspec[0] == "set":
      check(len(subspec) == 3, "wrong length %s of subspec %s, != 3" %
          (len(subspec), subspec))
      _, param, newval = subspec
      check(isinstance(param, str),
          "wrong type %s of %s, not str" % (type(param), param))
      newval = expand_set_value(newval, data)
      if newval is None:
        pass
      elif isinstance(newval, str):
        expanded_specs.append((param, newval))
      else:
        check(type(newval) is list, "wrong type %s of %s, not list" % (type(newval), newval))
        while len(newval) > 0 and newval[-1] is None:
          del newval[-1]
        if re.search("^[0-9]+$", param):
          intparam = int(param)
          for val in newval:
            expanded_specs.append((str(intparam), "" if val is None else val))
            intparam += 1
        else:
          index = 1
          for val in newval:
            if val is not None:
              expanded_specs.append(
                (param if index == 1 else "param%s" % index, val))
            index += 1

    elif subspec[0] == "copy":
      check(len(subspec) in [2, 3], "wrong length %s of subspec %s, not in [2, 3]" %
          (len(subspec), subspec))
      fromparam = subspec[1]
      if len(subspec) == 2:
        toparam = fromparam
      else:
        toparam = subspec[2]
      if t.has(fromparam):
        expanded_specs.append((toparam, getparam(t, fromparam)))

    elif subspec[0] == "copylist":
      check(len(subspec) in [2, 3], "wrong length %s of subspec %s, not in [2, 3]" %
          (len(subspec), subspec))
      fromparam = subspec[1]
      if len(subspec) == 2:
        toparam = fromparam
      else:
        toparam = subspec[2]

      # This code is somewhat hairy because we allow e.g. list-copying from
      # 3, 4, ... to base4, base5, ...

      # First analyze `fromparam` into the non-numeric base (which might be
      # blank), the numeric index at the end, and a flag indicating if the
      # numeric index is missing. If missing, we look for both e.g. "tr"
      # and "tr1", as well as "tr2", "tr3", ... (looking for both "tr" and
      # "tr1" is compatible with the way that [[Module:parameters]] does
      # things); else we only look for params with a numeric index that's at
      # least as great as the specified index. So if you say to list-copy
      # "tr" to "alttr", it will copy "tr" to "alttr", "tr1" to "alttr1",
      # "tr2" to "alttr2", etc. But if you say to list-copy "tr1" to "alttr1",
      # it won't copy "tr" to "alttr" but will copy the rest.
      m = re.search("^(.*?)([0-9]+)$", fromparam)
      if m:
        frombase, fromind = m.groups()
        fromind = int(fromind)
        fromfirstblank = False
      else:
        frombase = fromparam
        fromind = 1
        fromfirstblank = True

      # Same analysis for `toparam`.
      m = re.search("^(.*?)([0-9]+)$", toparam)
      if m:
        tobase, toind = m.groups()
        tofirstblank = False
      else:
        tobase = toparam
        toind = 1
        tofirstblank = True

      # Now, go through all the existing parameters, looking for any
      # parameters that match the `fromparam` spec.
      for param in t.params:
        pname = str(param.name).strip()
        m = re.search("^(.*?)([0-9]*)$", pname)
        pbase, pind = m.groups()
        # For a parameter to match, it must have the same non-numeric base
        # and have a numeric index that's at least as great as the
        # `fromparam`'s numeric index, or if the param has no index, the
        # `fromparam` must also have no index.
        if pbase == frombase and (not pind and fromfirstblank or
            pind and int(pind) >= fromind):
          fromoffset = (int(pind) if pind else 1) - fromind
          check(fromoffset >= 0, "negative offset %s of fromoffset" % fromoffset)
          actual_toind = toind + fromoffset
          # Normally, if we're processing the first from-parameter and
          # the first to-parameter has no index, store the value of the
          # from-parameter into the indexless to-parameter. But don't do
          # that if the first from-parameter has index "1"; if we're asked
          # to list-copy "tr" to "alttr", we want "tr" copied into "alttr"
          # but "tr1" copied into "alttr1".
          if actual_toind == 1 and tofirstblank and pind != "1":
            actual_toparam = tobase
          else:
            actual_toparam = "%s%s" % (tobase, actual_toind)
          expanded_specs.append((actual_toparam, str(param.value)))

    elif subspec[0] == "copyallbut":
      check(len(subspec) == 2, "wrong length %s of subspec %s, != 2" %
          (len(subspec), subspec))
      exclude_params = subspec[1]

      # Go through all the existing parameters, excluding any that are
      # listed in exclude_params. An individual entry is either a string
      # naming a param, or a tuple ("list", "PARAM") for a list. In a list,
      # if the param ends with a number, only numbered params from that
      # number up will be excluded.
      for param in t.params:
        pname = str(param.name).strip()
        m = re.search("^(.*?)([0-9]*)$", pname)
        pbase, pind = m.groups()
        excludeme = False
        for ename in exclude_params:
          if isinstance(ename, str):
            if ename == pname:
              excludeme = True
              break
          else:
            check(type(ename) is tuple, "wrong type %s of %s, not tuple" % (type(ename), ename))
            check(len(ename) == 2, "wrong length %s of ename %s, != 2" %
                (len(ename), ename))
            check(ename[0] == "list", 'ename[0] should == "list" but == %s' % ename[0])
            check(isinstance(ename[1], str),
                "wrong type %s of %s, not str" % (type(ename[1]), ename[1]))
            m = re.search("^(.*?)([0-9]*)$", ename)
            ebase, eind = m.groups()
            if not eind:
              if pbase == ebase:
                excludeme = True
                break
            else:
              if pind and int(pind) >= int(eind):
                excludeme = True
                break
        if not excludeme:
          expanded_specs.append(
            (str(param.name), str(param.value), str(param.showkey)))

    elif subspec[0] == "comment":
      check(len(subspec) == 2, "wrong length %s of subspec %s, != 2" %
          (len(subspec), subspec))
      _, comment = subspec
      comment = expand_set_value(comment, data)
      check(isinstance(comment, str),
          "wrong type %s of %s, not str" % (type(comment), comment))
      comment = comment.replace("__TEMPNAME__", oldname).replace("__NEWNAME__", newname)

    else:
      check(False, "Unrecognized directive: %s" % subspec[0])

  if not comment:
    # If the old template is prefixed with the first param of the replacement,
    # it is probably a language code and we're replacing a language-specific
    # template with a general template; in that case, include the language code
    # in the comment.
    for spec in expanded_specs:
      if spec[0] == "1" and oldname.startswith(spec[1] + "-"):
        comment = "rename {{%s}} to {{%s|%s}} with appropriate param changes" % (
            oldname, newname, spec[1])
        break

  if not comment:
    comment = "rename {{%s}} to {{%s}} with appropriate param changes" % (
        oldname, newname)

  return newname, expanded_specs, comment

def process_text_on_page(index, pagetitle, text):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")
  notes = []

  # We do want to change user pages with these templates on them.
  if blib.page_should_be_ignored(pagetitle, allow_user_pages=True):
    pagemsg("WARNING: Page has a prefix or suffix indicating it should not be touched, skipping")
    return

  parsed = blib.parse_text(text)

  for t in parsed.filter_templates():
    origt = str(t)
    tn = tname(t)
    if tn in templates_to_actually_do_set:
      data = TemplateData(index, pagetitle, t, pagemsg)
      template_spec = templates_to_rename_map[tn]
      try:
        new_name, new_params, comment = expand_spec(template_spec, data)
      except BadTemplateValue as e:
        pagemsg("WARNING: %s: %s" % (str(e), origt))
        continue
      except BadRewriteSpec as e:
        errandmsg("INTERNAL ERROR: %s: Processing template %s" % (str(e), origt))
        pagemsg("Spec being processed:")
        pprint.pprint(template_spec)
        traceback.print_exc()
        continue
      blib.set_template_name(t, new_name)
      # Erase all params.
      del t.params[:]
      # Put back new params
      for param in new_params:
        if len(param) == 2:
          pname, pval = param
          t.add(pname, pval, preserve_spacing=False)
        else:
          pname, pval, showkey = param
          t.add(pname, pval, showkey=showkey, preserve_spacing=False)

      # Now apply post-rewrite hooks
      for hook in post_rewrite_hooks:
        comment = hook(data, comment)

      notes.append(comment)

    if str(t) != origt:
      pagemsg("Replaced <%s> with <%s>" % (origt, str(t)))

  text = str(parsed)

  if args.lang_for_combine_inflection_of:
    retval = blib.find_modifiable_lang_section(text, None if args.partial_page else args.lang_for_combine_inflection_of, pagemsg)
    if retval is None:
      pagemsg("WARNING: Couldn't find %s section" % args.lang_for_combine_inflection_of)
      return text, notes
    sections, j, secbody, sectail, has_non_lang = retval
    dont_combine_tags = args.dont_combine_tags.split(",") if args.dont_combine_tags else None
    secbody = infltags.combine_adjacent_inflection_of_calls(secbody, notes, pagemsg, verbose=args.verbose)
    parsed = blib.parse_text(secbody)
    for t in parsed.filter_templates():
      tn = tname(t)
      if tn in infltags.inflection_of_templates:
        origt = str(t)
        tags, params, lang, term, tr, alt = infltags.extract_tags_and_nontag_params_from_inflection_of(
            t, notes)
        # Now combine adjacent tags into multipart tags.
        def warn(text):
          pagemsg("WARNING: %s" % text)
        tags, this_notes = infltags.combine_adjacent_tags_into_multipart(
          tn, lang, term, tags, tag_to_dimension_table, pagemsg, warn,
          tag_to_canonical_form_table=tag_to_canonical_form_table, dont_combine_tags=dont_combine_tags
        )
        notes.extend(this_notes)
        infltags.put_back_new_inflection_of_params(t, notes, tags, params, lang, term, tr, alt,
          convert_to_more_specific_template=False)
        if str(t) != origt:
          pagemsg("Replaced %s with %s" % (origt, str(t)))
    secbody = str(parsed)
    sections[j] = secbody + sectail
    text = "".join(sections)

  return text, notes

def process_text_on_page_for_check_ignore(index, pagetitle, text):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
  def errandpagemsg(txt):
    errandmsg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")
  notes = []

  # We do want to change user pages with these templates on them.
  if blib.page_should_be_ignored(pagetitle, allow_user_pages=True):
    pagemsg("WARNING: Page has a prefix or suffix indicating it should not be touched, skipping")
    return

  parsed = blib.parse_text(text)

  for t in parsed.filter_templates():
    tn = tname(t)
    if tn in templates_to_process_for_check_ignore:
      foundit = False
      for m in re.finditer(r"^(.*?)%s(.*?)$" % re.escape(str(t)), text, re.M):
        foundit = True
        pretext = m.group(1)
        posttext = m.group(2)
        if not pretext.startswith("#"):
          pagemsg("WARNING: Found form-of template not on definition line: %s" % m.group(0))
        has_pretext = not re.search(r"^[#:]*\s*(\{\{(?:lb|label|sense|senseid|tlb|q|qualifier|qf)\|[^}]*?\}\}\s*)?$", pretext)
        has_posttext = posttext != ""
        if has_pretext and has_posttext:
          pagemsg("WARNING: Found form-of template with pre-text and post-text: %s" % m.group(0))
        elif has_pretext:
          pagemsg("WARNING: Found form-of template with pre-text: %s" % m.group(0))
        elif has_posttext:
          pagemsg("WARNING: Found form-of template with post-text: %s" % m.group(0))
      if not foundit:
        errandpagemsg("WARNING: Couldn't find form-of template on page: %s" % str(t))

parser = blib.create_argparser("Rename various lang-specific form-of templates to more general variants",
    include_pagefile=True, include_stdin=True)
parser.add_argument("--do-all", help="Do all templates instead of default list",
    action="store_true")
parser.add_argument("--do-specified", help="Do specified comma-separated templates instead of default list")
parser.add_argument("--check-ignores", help="Check whether there may be problems ignoring intial cap or final dot", action="store_true")
parser.add_argument("--lang-for-combine-inflection-of", help="Language name of section whose {{inflection of}} calls will be combined")
parser.add_argument("--dont-combine-tags", help="Comma-separated list of tags not to combine with other tags")
parser.add_argument("--check-ignores-include-ucdot", help="Whether checking ignore issues, include type 'ucdot' to see whether it can be converted to 'lcnodot'", action="store_true")
parser.add_argument("--partial-page", action="store_true", help="Input was generated with 'find_regex.py --lang LANG' and has no ==LANG== header.")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

initialize_templates_to_rename_map(args.do_all, args.do_specified)
if args.check_ignores:
  templates_to_process_for_check_ignore = {}
  for template in templates_to_actually_do:
    if template not in templates_by_cap_and_period_map:
      errandmsg("WARNING: Template:%s not in templates_by_cap_and_period_map, not sure its ignoring behavior, skipping" %
          template)
    elif template in verified_templates_by_cap_and_period:
      errandmsg("Skipping already-verified Template:%s" % template)
    else:
      ignore_type = templates_by_cap_and_period_map[template]
      if ignore_type not in ["lcnodot", "ucdot"] or (
        ignore_type == "ucdot" and args.check_ignores_include_ucdot
      ):
        errandmsg("Processing references to Template:%s [ignore_type=%s]" %
            (template, ignore_type))
        templates_to_process_for_check_ignore[template] = ignore_type

  blib.do_pagefile_cats_refs(args, start, end, process_text_on_page_for_check_ignore, edit=True, stdin=True,
     default_refs=["Template:%s" % template for template in templates_to_process_for_check_ignore])

else:
  blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True,
      default_refs=["Template:%s" % template for template in templates_to_actually_do])
