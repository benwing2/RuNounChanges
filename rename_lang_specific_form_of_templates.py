#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse
import traceback, pprint

import blib
from blib import getparam, rmparam, msg, errandmsg, site, tname

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
# pt-verb-form-of (? maybe? uses a module) (94585)
# pt-verb form of (? very complicated; takes a region param that can/should be moved out) (29193)
# sce-verb form of (? maybe? uses a module) (1)
# sw-adj form of (? might be tough) (291)
# tr-possessive form of (? includes posttext) (35)

class BadTemplateValue(Exception):
  pass

class BadRewriteSpec(Exception):
  pass

templates_to_actually_do = [
  "cu-form of",
  "da-pl-genitive",
  "de-du contraction",
  "de-form-noun",
  "el-form-of-adv",
  "el-participle of",
  "et-nom form of",
  "fa-form-verb",
  "gmq-bot-verb-form-sup",
  "hi-form-adj",
  "hi-form-adj-verb",
  "hi-form-noun",
  "hy-form-noun",
  "ie-past and pp of",
  "is-conjugation of",
  "is-inflection of",
  "ka-verbal for",
  "ka-verbal of",
  "ku-verb form of",
  "liv-inflection of",
  "lt-form-adj-is",
  "lt-form-noun",
  "lt-form-verb",
  "lv-definite of",
  "lv-verbal noun of",
  "mr-form-adj",
  "mt-prep-form",
  "nb-noun-form-def-gen",
  "nb-noun-form-def-gen-pl",
  "nb-noun-form-indef-gen-pl",
  "ofs-nom form of",
  "osx-nom form of",
  "pt-adv form of",
  "pt-article form of",
  "pt-cardinal form of",
  "pt-ordinal form",
  "pt-ordinal def",
  "ro-adj-form of",
  "ro-form-adj",
  "ro-form-noun",
  "ro-form-verb",
  "roa-opt-noun plural of",
  "sh-form-noun",
  "sh-form-proper-noun",
  "sh-verb form of",
  "sh-form-verb",
  "sl-form-adj",
  "sl-form-noun",
  "sl-form-verb",
  "sl-verb form of",
  "tg-form-verb",
  "ur-form-adj",
  "ur-form-noun",
  "ur-form-verb",
]

# List of templates and their behavior w.r.t. initial caps
# final period. One of the following:
#
# 1. "lcnodot": Original template doesn't have initial caps
#    or final period; nor does the replacement.
# 2. "ucdot": Original template has initial caps and final
#    period (possibly controllable, mostly not); our
#    replacement also has initial caps and final period,
#    controllable.
# 3. "ignoreduc": Original template has initial caps (usually
#    automatic, very occasionally controllable) but no final
#    period; our replacement doesn't have initial caps. Need
#    to verify that this works.
# 4. "ignoreddot": Original template has final period (usually
#    automatic, very occasionally controllable) but no initial
#    caps; our replacement doesn't have final period. Need
#    to verify that this works.
# 5. "ignoreducdot": Original template has final period (usually
#    automatic, very occasionally controllable) and initial
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
  ("chm-inflection of", "lcnodot", False),
  ("cu-form of", "ignoreducdot", "verified"),
  ("da-pl-genitive", "lcnodot", False),
  ("de-du contraction", "ignoreduc", "verified"),
  ("de-form-adj", "ignoreddot", "verified"),
  ("de-form-noun", "lcnodot", False),
  # The following instances need to be fixed up:
  # Page 1091 abarbeitet: WARNING: Found form-of template with post-text: # {{de-verb form of|abarbeiten|3|s|g}} Used in side clauses where usually separable prefixes do not separate
  ("de-verb form of", "ucdot", False), # First 3000 verified
  ("el-form-of-adv", "ignoreduc", "verified"),
  # The following instances need to be fixed up:
  # (all instances with a final period)
  # Page 105 ον: WARNING: Found form-of template with post-text: # {{lb|el|dated}} {{el-form-of-nounadj|ων|g=n|n=s|c=nav}} “being”
  # Page 109 αδελφών: WARNING: Found form-of template with post-text: # {{el-form-of-nounadj|αδελφός|c=gen|n=p}} {{g|m}}
  # Page 109 αδελφών: WARNING: Found form-of template with post-text: # {{el-form-of-nounadj|αδελφή|c=gen|n=p}} {{g|f}}
  # Page 968 αγγουριών: WARNING: Found form-of template with pre-text and post-text: # {{qualifier|neuter}} {{el-form-of-nounadj|αγγούρι|c=gen|n=p|nodot=1}} [[cucumber]].
  # Page 968 αγγουριών: WARNING: Found form-of template with pre-text and post-text: # {{qualifier|feminine}} {{el-form-of-nounadj|αγγουριά|c=gen|n=p|nodot=1}} [[cucumber]] [[plant]].
  ("el-form-of-nounadj", "ignoreducdot", "verified"),
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
  ("el-form-of-verb", "ignoreducdot", "verified"),
  # Most cases of 'el-participle of' use nodot=1; check whether can
  # get away without dot.
  ("el-participle of", "ucdot", False), # FIXME
  ("en-simple past of", "lcnodot", False),
  # The following instances need to be fixed up:
  # [etc]; need to review carefully; have a script remove final periods
  ("en-third-person singular of", "ignoreduc", False), # FIXME
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
  ("es-adj form of", "ucdot", False), # First 3000 verified
  ("et-nom form of", "ignoreducdot", "verified"),
  ("et-participle of", "ignoreducdot", "verified"),
  ("et-verb form of", "ignoreducdot", "verified"),
  ("fa-adj form of", "lcnodot", False),
  ("fa-adj-form", "lcnodot", False),
  ("fa-form-verb", "ignoreddot", "verified"),
  # The following instances need to be fixed up:
  # Page 84 onhan: WARNING: Found form-of template with post-text: # {{fi-verb form of|pn=3s|tm=pres|olla|nodot=1}} + suffix {{m|fi|-han}}.
  ("fi-verb form of", "ucdot", False), # First 3000 verified
  ("gmq-bot-verb-form-sup", "ignoreddot", "verified"),
  # The following instances need to be fixed up:
  # Page 944 𐌺𐌿𐌽𐌸𐍃: WARNING: Found form-of template with pre-text: # [[known]]. {{got-verb form of|𐌺𐌿𐌽𐌽𐌰𐌽|t=past|m=ptc}}
  ("got-verb form of", "ignoreducdot", "verified"),
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
  ("it-adj form of", "ucdot", False), # First 3000 verified
  ("ja-past of verb", "lcnodot", False),
  ("ja-te form of verb", "lcnodot", False),
  ("ka-verbal for", "ignoreduc", "verified"),
  ("ka-verbal of", "ignoreduc", "verified"),
  ("ku-verb form of", "ignoreducdot", "verified"),
  ("liv-conjugation of", "lcnodot", False),
  ("liv-inflection of", "lcnodot", False),
  ("liv-participle of", "lcnodot", False),
  (u"lt-būdinys", "ignoreddot", "verified"),
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
  ("lt-form-part", "ignoreddot", False), # First 3000 verified
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
  ("mr-form-adj", "ignoreddot", "verified"),
  ("mt-prep-form", "ignoreddot", "verified"),
  ("nb-noun-form-def-gen", "lcnodot", False),
  ("nb-noun-form-def-gen-pl", "lcnodot", False),
  ("nb-noun-form-indef-gen-pl", "lcnodot", False),
  ("ofs-nom form of", "ignoreduc", "verified"),
  ("osx-nom form of", "ignoreduc", "verified"),
  # The following instances need to be fixed up:
  # Page 202 conversa: WARNING: Found form-of template with post-text: # {{pt-adj form of|converso|f|sg}}.
  ("pt-adj form of", "ucdot", False), # First 3000 verified
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
  ("bg-adj form of", (
    "adj form of",
    ("error-if", ("present-except", ["1", "2", "3", "adj"])),
    ("set", "1", [
      "bg",
      ("copy", "adj"),
      "",
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
      ("lookup", "2", {
        "extended": "extended",
        "indefinite": "indef",
        "definite": "def",
      }),
    ]),
  )),

  # NOTE: Has automatic, non-controllable initial caps and final period.
  # Both ignored.
  ("bg-noun form of", (
    "noun form of",
    ("error-if", ("present-except", ["1", "2", "3", "noun"])),
    ("set", "1", [
      "bg",
      ("copy", "noun"),
      "",
      ("lookup", "3", {
        "subject": "sbjv",
        "object": "objv",
        "": [],
      }),
      ("lookup", "1", {
        "singular": ["s"],
        "plural": ["p"],
        "count": ["count"],
        "vocative": ["voc"],
      }),
      ("lookup", "2", {
        "indefinite": "indef",
        "definite": "def",
        "vocative": "voc",
        "": [],
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
          ("lookup", "g", {
            "singular": "s",
            "plural": "p",
          }),
          ("lookup", "d", {
            "indefinite": "indef",
            "definite": "def",
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
          ("lookup", "f", {
            "subject form": "sbjv",
            "object form": "objv",
            "": [], # can occur esp. with non-masculine participles
          }),
          ("lookup", "g", {
            "masculine": "m",
            "feminine": "f",
            "neuter": "n",
            "plural": "p",
          }),
          ("lookup", "d", {
            "indefinite": "indef",
            "definite": "def",
            "": [],
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
    "noun form of",
    ("error-if", ("present-except", ["1", "2"])),
    ("set", "1", [
      "br",
      ("copy", "1"),
      ("copy", "2"),
      "p",
    ]),
  )),
]

def romance_adj_form_of(lang, lcnodot=False):
  # This works for ca, es, it and pt. Romanian has its own template and French
  # uses {{masculine singular of}}, {{feminine singular of}}, etc.
  # Not all languages accept m-f or mf, but it doesn't hurt to accept them.
  # Has default initial caps and final period (controllable by nocap/nodot).
  # Both ignored for ca.
  if lcnodot:
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
  else:
    return (
      "Adj form of",
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
      ("copy", "nocap"),
      ("copy", "nodot"),
    )

def ca_form_of(t, pagemsg):
  if getparam(t, "1") in ["alt form", "alt sp", "alt spel", "alt spell"]:
    if getparam(t, "1") == "alt form":
      template = "alt form"
    else:
      template = "alt sp"
    return (
      template,
      ("error-if", ("present-except", ["1", "2", "3"])), # doesn't include val= or val2=
      ("set", "1", [
        "ca",
        ("copy", "2"),
        ("copy", "3"),
      ]),
    )
  else:
    return (
      "inflection of",
      ("error-if", ("present-except", ["1", "2", "3"])), # doesn't include val= or val2=
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
    )

ca_specs = [
  ("ca-adj form of", romance_adj_form_of("ca", lcnodot=True)),

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

chm_grammar_table = {
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


chm_specs = [
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
  ("chm-inflection of", (
    "noun form of",
    ("error-if", ("present-except", ["1", "2", "3", "4", "5", "6"])),
    ("set", "1", [
      "chm",
      ("copy", "1"),
      "",
      ("lookup", "2", {
        "1s": [],
        "2s": [],
        "3s": [],
        "1p": [],
        "2p": [],
        "3p": [],
        "0": [],
        True: "npossd",
      }),
      ("lookup", "2", chm_grammar_table),
      ("lookup", "3", chm_grammar_table),
      ("lookup", "4", chm_grammar_table),
      ("lookup", "5", chm_grammar_table),
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
      lambda t, pagemsg: "[[%s]] [[du]]" % getparam(t, "1")
    ]),
  )),

  # NOTE: Has automatic, non-controllable final period that we're ignoring.
  # Doesn't have initial caps.
  ("de-form-adj", (
    "adj form of",
    # lang= occurs at least once, and is ignored.
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
          ("lookup", "deg", {
            "c": "comd",
            "s": "supd",
            "": [],
          }),
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
        ]
      }),
    ]),
    ("copy", "nocat"),
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
  ("de-verb form of", (
    "Verb form of",
    ("error-if", ("present-except", ["1", "2", "3", "4", "5"])),
    ("set", "1", [
      "de",
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
            "i": "imp",
          }),
          ("lookup", "3", {
            "s": "s",
            "p": "p",
          }),
          ("lookup", "2", {
            "i": ("lookup", "4", {
              "": [],
            }),
            True: ("lookup", "4", {
              "g": "pres",
              "v": ["pret"],
              "k1": ["sub", "I"],
              "k2": ["sub", "II"],
            }),
          }),
          ("lookup", "5", {
            "": [],
            True: ["dep", "form"],
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
    lambda t, pagemsg:
      ("comparative of",
        ("comment", "rename {{__TEMPNAME__|deg=comp}} to {{comparative of|el|...|POS=adverb}}"),
        ("error-if", ("present-except", ["deg", "1", "alt", "gloss"])),
        ("set", "1", [
          "el",
          ("copy", "1"),
          ("copy", "alt"),
          ("copy", "gloss"),
        ]),
        ("set", "POS", "adverb"),
      ) if getparam(t, "deg") == "comp" else
      ("inflection of",
        ("comment", "rename {{__TEMPNAME__|deg=sup}} to {{inflection of|el|...|asupd}}"),
        ("error-if", ("present-except", ["deg", "1", "alt", "gloss"])),
        ("error-if", ("neq", "deg", "sup")),
        ("set", "1", [
          "el",
          ("copy", "1"),
          ("copy", "alt"),
          "asupd",
        ]),
        ("set", "p", "adv"),
        ("copy", "gloss", "t"),
      )
  )),

  # NOTE: Has automatic, non-controllable initial caps and controllable
  # final period (using nodot). Both ignored.
  ("el-form-of-nounadj", (
    "inflection of",
    ("error-if", ("present-except", ["1", "c", "n", "g", "d", "t", "nodot"])),
    ("set", "1", [
      "ofs",
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
      ("lookup", "n", {
        "s": "s",
        "p": "p",
        "": [], # occurs with numbers
      }),
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
    ("error-if", ("present-except", ["1", "nonfinite", "voice", "pers",
      # We ignore active= and ta=. They are used in posttext that says
      # "passive of {{m|el|{{{active}}}|t={{{ta|}}}}}". This isn't easy
      # to do in the general {{verb form of}} template, isn't how other
      # non-lemma forms are formatted and is of questionable value.
      # FIXME: Consider moving outside of template.
      "tense", "mood", "t", "active", "ta", "nodot"])),
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
          ("lookup", "voice", {
            "pass": "pass",
            "act": "act",
            "": [], # voice frequently left out (when active?)
          }),
        ]
      }),
    ]),
    ("copy", "t"),
  )),

  # NOTE: Has automatic, non-controllable initial caps and controllable
  # final period (using nodot).
  ("el-participle of", (
    "Participle of",
    ("error-if", ("present-except", ["1", "2", "gloss", "t", "tr", "nodot", "nocap"])),
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
    ("copy", "nodot"),
    ("copy", "nocap"),
  )),
]

en_specs = [
  ("en-simple past of", (
    "verb form of",
    ("error-if", ("present-except", ["1", "2"])),
    ("set", "1", [
      "en",
      ("copy", "1"),
      ("copy", "2"),
      "spast"
    ]),
  )),

  # NOTE: Has automatic, non-controllable initial caps that we're ignoring.
  # Doesn't have final period.
  ("en-third-person singular of", (
    "verb form of",
    # lang= occurs at least once, and is ignored.
    ("error-if", ("present-except", ["1", "2", "lang"])),
    ("set", "1", [
      "en",
      ("copy", "1"),
      ("copy", "2"),
      ["3s", "spres", "ind"],
    ]),
  )),
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
      enm_verb_form(["1", "s", "pres", "ind"])),
  ("enm-first/third-person singular past of",
      enm_verb_form(["13", "s", "past", "ind"])),
  ("enm-plural of",
      enm_verb_form(["p", "pres", "ind"])),
  ("enm-plural past of",
      enm_verb_form(["p", "past", "ind"])),
  ("enm-plural subjunctive of",
      enm_verb_form(["p", "pres", "sub"])),
  ("enm-plural subjunctive past of",
      enm_verb_form(["p", "sub", "past"])),
  ("enm-second-person singular of",
      enm_verb_form(["2", "s", "pres", "ind"])),
  ("enm-second-person singular past of",
      enm_verb_form(["2", "s", "past", "ind"])),
  ("enm-singular subjunctive of",
      enm_verb_form(["s", "pres", "sub"])),
  ("enm-singular subjunctive past of",
      enm_verb_form(["s", "sub", "past"])),
  ("enm-third-person singular of",
      enm_verb_form(["3", "s", "pres", "ind"])),
]

es_specs = [
  ("es-adj form of", romance_adj_form_of("es")),
]

et_specs = [
  # Has default initial caps and final period (controllable by nocap/nodot).
  # Both ignored.
  ("et-nom form of", (
    # May be rewritten later to 'noun form of', etc.
    "inflection of",
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
    ("copy", "pos", "p"),
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

def fa_tg_adj_form_of(t, pagemsg, lang):
  param1 = getparam(t, "1")
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
  ("fa-adj form of", lambda t, pagemsg: fa_tg_adj_form_of(t, pagemsg, "fa")),

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
        "man": ["1", "s", "imp"],
        "imp-man": ["1", "s", "imp"],
        "to": ["2", "s", "imp"],
        "imp-to": ["2", "s", "imp"],
        "u": ["3", "s", "imp"],
        "imp-u": ["3", "s", "imp"],
        u"mâ": ["1", "p", "imp"],
        u"imp-mâ": ["1", "p", "imp"],
        u"šomâ": ["2", "p", "imp"],
        u"imp-šomâ": ["2", "p", "imp"],
        u"ânhâ": ["3", "p", "imp"],
        u"imp-ânhâ": ["3", "p", "imp"],
        "r": ["root"],
        "prstem": ["pres", "stem"],
        "pstem": ["past", "stem"],
      }),
    ]),
    ("copy", "t"),
  )),
]

fi_specs = [
  # Has default initial caps and final period (controllable by nocap/nodot).
  ("fi-verb form of", (
    # The template code ignores nocat=.
    "Verb form of",
    ("error-if", ("present-except", ["1", "pn", "tm", "c", "nocap", "nodot", "nocat"])),
    ("set", "1", [
      "fi",
      ("copy", "1"),
      "",
      ("lookup", "pn", {
        "1s": "1s",
        "2s": "2s",
        "3s": "3s",
        "1p": "1p",
        "2p": "2p",
        "3p": "3p",
        "p": "p",
        "pasv": "pass",
        "pass": "pass",
        "": [], # especially in conjunction with connegative
      }),
      ("lookup", "tm", {
        "pres": ["pres", "ind"],
        "past": ["past", "ind"],
        "cond": "cond",
        "impr": "imp",
        "potn": "potn",
      }),
      ("lookup", "c", {
        "": [],
        True: "conn",
      }),
    ]),
    ("copy", "nocap"),
    ("copy", "nodot"),
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
  # Has default initial caps and final period (controllable by nocap/nodot).
  # Both ignored.
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
        ("lookup", "1", {
          "h": "hab",
          "p": "pfv",
          "c": ["cont", "part"],
        }),
        ("lookup", "2", {
          "ms": ["m", "s"],
          "mp": ["m", "p"],
          "fs": ["f", "s"],
          "fp": ["f", "p"],
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
          "i": "indir",
          "o": "indir",
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
          "tu": ["intim", "2", "s", "imp"],
          "imp-tu": ["intim", "2", "s", "imp"],
          "tum": ["fam", "2", "imp"],
          "imp-tum": ["fam", "2", "imp"],
          "ap": ["pol", "2", "imp"],
          "imp-ap": ["pol", "2", "imp"],
          "r": ["root"],
          "i": ["obl", "inf"],
          "o": ["obl", "inf"],
          "c": ["conj"],
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
  "pos": "poss",
  "1s": ["1s", ",", "spos"],
  "2s": ["2s", ",", "spos"],
  "3s": ["3s", ",", "spos"],
  "4s": ["1p", ",", "spos"],
  "5s": ["2p", ",", "spos"],
  "6s": ["3p", ",", "spos"],
  "1p": ["1s", ",", "ppos"],
  "2p": ["2s", ",", "ppos"],
  "3p": ["3s", ",", "ppos"],
  "4p": ["1p", ",", "ppos"],
  "5p": ["2p", ",", "ppos"],
  "6p": ["3p", ",", "ppos"],
  "1": "1",
  "2": "2",
  "3": "3",
  "": [],
}

hu_specs = [
  ("hu-inflection of", (
    # May be rewritten later to 'noun form of', etc.
    "inflection of",
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
    ("error-if", ("present-except", ["1", "2"])),
    ("set", "1", [
      "hu",
      ("copy", "1"),
      "",
      ("lookup", "2", {
        "t": "past",
        "tt": "past",
        "ott": "past",
        "ett": "past",
        u"ött": "past",
        u"ó": "pres",
        u"ő": "pres",
        u"andó": "fut",
        u"endő": "pres",
        "va": "adv",
        "ve": "adv",
        u"ván": "adv",
        u"vén": "adv",
      }),
    ]),
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
      ("lookup", "3", {
        "d": "def",
        "def": "def",
        "i": [], # occurs in a few forms despite docs
        "": [],
      }),
      ("lookup", "5", {
        "1": ["1", "poss"],
        "2": ["2", "poss"],
        "": [],
      }),
      ("lookup", "6", {
        "n": "nomz",
        "nom": "nomz",
        "": [],
      }),
      lambda t, pagemsg:
        "form" if getparam(t, "5") in ["1", "2"] or getparam(t, "6") in ["n", "nom"] else [],
    ]),
  )),
]

ie_specs = [
  ("ie-past and pp of", (
    "verb form of",
    ("error-if", ("present-except", ["1"])),
    ("set", "1", [
      "ie",
      ("copy", "1"),
      "",
      "past",
      "and",
      "pass",
      "part",
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
    "inflection of",
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
      "conj",
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
        "n": ["neg"],
        "i": ["imp"],
        "in": ["imp", "neg"],
        "c": ["cond"],
        "j": ["juss"],
        "q": ["quot"],
      }),
    ]),
  )),

  ("liv-inflection of", (
    "inflection of",
    # 4 is ignored by the template but specifies the part of speech
    # and used to be used for categorization. We preserve it as it
    # might be useful in the future and it helps with rewriting.
    ("error-if", ("present-except", ["1", "2", "3", "4"])),
    ("set", "1", [
      "liv",
      ("copy", "3"),
      "",
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
    "inflection of",
    ("error-if", ("present-except", ["1", "2", "3", "4", "5"])),
    ("set", "1", [
      "liv",
      ("copy", "4"),
      "",
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
      ("lookup", "5", {
        "sg": "s",
        "pl": "p",
        "": [],
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
  (u"lt-būdinys", (
    "participle of",
    ("error-if", ("present-except", ["1"])),
    ("set", "1", [
      "lt",
      ("copy", "1"),
      "",
      ["adv", "budinys"],
    ]),
  )),

  ("lt-budinys", u"lt-būdinys"),

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
        "active": "active",
        "p": "pass",
        "pass": "pass",
        "passive": "pass",
      }),
    ]),
  )),

  ("lt-dalyvis", "lt-dalyvis-1"),

  # NOTE: Has automatic, non-controllable final period that we're ignoring.
  # Doesn't have initial caps.
  ("lt-dalyvis-2", (
    "inflection of",
    ("error-if", ("present-except", ["1"])),
    ("set", "1", [
      "lt",
      ("copy", "1"),
      "",
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
      ("lookup", "1", {
        "a": "posd",
        "abs": "posd",
        "p": "posd",
        "pos": "posd",
        "c": "comd",
        "com": "comd",
        "comp": "comd",
        "s": "supd",
        "sup": "supd",
        "": [],
      }),
      ("lookup", "2", lt_adj_gender_number_table),
      ("lookup", "3", lt_adj_case_table),
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
      ("lookup", "1", lt_adj_gender_number_table),
      ("lookup", "2", lt_adj_case_table),
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
    "inflection of",
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
      ("lookup", "1", lt_adj_gender_number_table),
      ("lookup", "2", lt_adj_case_table),
    ]),
    ("set", "p", "part"),
  )),

  # NOTE: Has automatic, non-controllable final period that we're ignoring.
  # Doesn't have initial caps. Categorizes into 'pronoun forms', which
  # should be handled by the headword.
  ("lt-form-pronoun", (
    "inflection of",
    # template handles class= and displays pre-text, but it never occurs
    ("error-if", ("present-except", ["1", "2", "3", "4"])),
    ("set", "1", [
      "lt",
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
        "": [],
      }),
      ("lookup", "4", {
        "ms": ["m", "s"],
        "fs": ["f", "s"],
        "mp": ["m", "p"],
        "fp": ["f", "p"],
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
    ]),
    ("set", "p", "pron"),
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
        "refshort": ["refl", "short"],
        "reflexive shortened": ["refl", "short"],
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
  ("lv-comparative of", (
    "inflection of",
    ("error-if", ("present-except", ["1", "2", "3"])),
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
    ("set", "p",
      ("lookup", "3", {
        "vpart": "part",
        "": [],
      })
    ),
  )),

  ("lv-definite of", (
    "inflection of",
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
    "inflection of",
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
    ("set", "p",
      ("lookup", "6", {
        "proper": "pn",
        "adj": "adj",
        "num": "num",
        "v": "v",
        "vpart": "part",
        "pro": "pro",
        True: [],
      }),
    ),
  )),

  ("lv-negative of", (
    "inflection of",
    ("error-if", ("present-except", ["1"])),
    ("set", "1", [
      "lv",
      ("copy", "1"),
      "",
      "neg",
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
    "inflection of",
    ("error-if", ("present-except", ["1", "2"])),
    ("set", "1", [
      "lv",
      ("copy", "1"),
      "",
      "supd",
    ]),
    ("set", "p",
      ("lookup", "2", {
        "vpart": "part",
        "": [],
      })
    ),
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
    ("error-if", ("present-except", ["1", "2", "3"])),
    ("set", "1", [
      "mr",
      ("copy", "3"),
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

mt_specs = [
  # NOTE: Has automatic, non-controllable final period that we're ignoring.
  # Doesn't have initial caps.
  ("mt-prep-form", (
    "inflection of",
    ("error-if", ("present-except", ["1", "2"])),
    ("set", "1", [
      "mt",
      ("copy", "2"),
      "",
      ("lookup", "1", {
        "1s": ["1", "s"],
        "2s": ["1", "s"],
        "3sm": ["3", "m", "s"],
        "3sf": ["3", "f", "s"],
        "1p": ["1", "p"],
        "2p": ["2", "p"],
        "3p": ["3", "p"],
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
      "def",
      "gen",
    ]),
  )),

  ("nb-noun-form-def-gen-pl", (
    "noun form of",
    ("error-if", ("present-except", ["1"])),
    ("set", "1", [
      "nb",
      ("copy", "1"),
      "",
      "def",
      "gen",
      "p",
    ]),
  )),

  ("nb-noun-form-indef-gen-pl", (
    "noun form of",
    ("error-if", ("present-except", ["1"])),
    ("set", "1", [
      "nb",
      ("copy", "1"),
      "",
      "indef",
      "gen",
      "p",
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
      ("lookup", "c", {
        "nom": "nom",
        "nomacc": "nom//acc",
        "acc": "acc",
        "gen": "gen",
        "dat": "dat",
        "accdat": "acc//dat",
      }),
      ("lookup", "n", {
        "sg": "s",
        "pl": "p",
        "": [],
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
      ("lookup", "w", {
        "w": "wk",
        "s": "str",
        "": [],
      }),
    ]),
  )),
]

osx_specs = [
  # NOTE: Has default initial caps (controllable through nocap) that we
  # are ignoring. Doesn't have final period. Only 22 uses.
  ("osx-nom form of", (
    "inflection of",
    ("error-if", ("present-except", ["1", "2", "c", "n", "g", "w", "nocap"])),
    ("set", "1", [
      "osx",
      ("copy", "1"),
      ("copy", "2"),
      ("lookup", "c", {
        "nom": "nom",
        "nomacc": "nom//acc",
        "acc": "acc",
        "gen": "gen",
        "dat": "dat",
        "accdat": "acc//dat",
        "ins": "ins",
      }),
      ("lookup", "n", {
        "sg": "s",
        "pl": "p",
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
      ("lookup", "w", {
        "w": "wk",
        "s": "str",
        "": [],
      }),
    ]),
  )),
]

pt_specs = [
  ("pt-adj form of", romance_adj_form_of("pt")),

  # NOTE: Has default initial caps (controllable through nocap) that we
  # are ignoring. Doesn't have final period. Only 11 uses.
  ("pt-adv form of", (
    "inflection of",
    ("error-if", ("present-except", ["1", "2", "nocap"])),
    ("set", "1", [
      "pt",
      ("copy", "1"),
      "",
      ("lookup", "2", {
        "f": "f",
        "comp": "comd",
        "sup": "supd",
      }),
    ]),
    ("set", "p", "adv"),
  )),

  # Has default initial caps and final period (controllable by nocap/nodot).
  # Both ignored.
  ("pt-article form of", (
    "inflection of",
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
    "inflection of",
    ("error-if", ("present-except", ["1", "2"])),
    ("set", "1", [
      "pt",
      lambda t, pagemsg:
        getparam(t, "1") + ("o" if getparam(t, "2") in ["a", "os", "as"] else u"º"),
      "",
      ("lookup", "2", {
        "a": ["f", "s"],
        "os": ["m", "p"],
        "as": ["f", "p"],
        u"ª": ["f", "s"],
        u"ºs": ["m", "p"],
        u"ªs": ["f", "p"],
      }),
    ]),
    ("set", "p", "onum"),
  )),

  ("pt-ordinal def", "pt-ordinal form"),
]

# NOTE: Has automatic, non-controllable final period that we're ignoring.
# Doesn't have initial caps. Categorizes into 'noun forms', which should be
# handled by the headword.
def ro_form_noun(t, pagemsg):
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

  if getparam(t, "1") in ["i", "d", ""]:
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
        ("lookup", "2", number_table),
        ("lookup", "3", case_table),
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
        ("lookup", "1", number_table),
        ("lookup", "2", case_table),
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
        "perf": ["sperf", "ind"],
        "perfect": ["sperf", "ind"],
        "pret": ["sperf", "ind"],
        "preterite": ["sperf", "ind"],
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
    "plural of",
    ("error-if", ("present-except", ["1", "nocap", "nodot"])),
    ("set", "1", [
      "roa-opt",
      ("copy", "1"),
    ]),
  )),
]

# FIXME: There should be a directive saying: append to the list,
# starting at the lowest nonexistent element.
def ru_get_nonblank_tags(t, pagemsg):
  tags = []
  for param in ["3", "4", "5", "6"]:
    val = getparam(t, param)
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
      ("copy", "2"),
    ]),
    ("copy", "tr"),
    ("set", "4", ru_get_nonblank_tags),
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
    "inflection of",
    ("error-if", ("present-except", ["1"])),
    ("set", "1", [
      "sa",
      ("copy", "1"),
      "",
      ["root"],
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
    "inflection of",
    ("error-if", ("present-except", ["1"])),
    ("set", "1", [
      "sga",
      ("copy", "1"),
      "",
      "verbnec"
    ]),
  )),
]

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
      }),
    ]),
  )),

  # NOTE: Categorizes into "proper noun forms", but this should be handled by
  # the headword. Otherwise identical to {{sh-form-noun}}.
  ("sh-form-proper-noun", "sh-form-noun"),

  # NOTE: Has automatic, non-controllable final period that we're ignoring.
  # Doesn't have initial caps.
  ("sh-verb form of", (
    lambda t, pagemsg:
      ("verbal noun of",
        ("comment", "rename {{__TEMPNAME__|vn}} to {{verbal noun of|sh}}"),
        # ignore sc=Cyrl.
        ("error-if", ("present-except", ["1", "2", "3", "sc"])),
        ("error-if", ("neq", "2", "")),
        ("set", "1", [
          "sh",
          ("copy", "3")
        ])
      ) if getparam(t, "1") == "vn" else
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
            "future": "fut",
            "present": "pres",
            "p": "p",
          }),
        ]),
      )
  )),

  ("sh-form-verb", "sh-verb form of"),

  ("sh-verb-form of", "sh-verb form of"),

  ("sh-verb-form-of", "sh-verb form of"),
]

def sl_check_1_is_m(t, pagemsg, should_return):
  if getparam(t, "1") == "m":
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
      ("lookup", "3", {
        "n": "nom",
        "g": "gen",
        "d": "dat",
        "a": "acc",
        "l": "loc",
        "i": "ins",
        "nd": lambda t, pagemsg: sl_check_1_is_m(t, pagemsg, ["def", "nom"]),
        "dn": lambda t, pagemsg: sl_check_1_is_m(t, pagemsg, ["def", "nom"]),
        "ad": lambda t, pagemsg: sl_check_1_is_m(t, pagemsg, ["def", "acc"]),
        "da": lambda t, pagemsg: sl_check_1_is_m(t, pagemsg, ["def", "acc"]),
        "ai": lambda t, pagemsg: sl_check_1_is_m(t, pagemsg, ["indef", "acc"]),
        "ia": lambda t, pagemsg: sl_check_1_is_m(t, pagemsg, ["indef", "acc"]),
        "aa": lambda t, pagemsg: sl_check_1_is_m(t, pagemsg, ["an", "acc"]),
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
    "inflection of",
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

def sv_form(template, parts):
  return (
    template,
    ("error-if", ("present-except", ["1", "2"])),
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

sv_specs = [
  # NOTE: All of the following adjective, adverb and verb forms have automatic,
  # non-controllable final periods that we're ignoring. Don't have initial
  # caps. No final period for the noun forms.
  ("sv-adj-form-abs-def", sv_adj_form(["def"])),
  ("sv-adj-form-abs-def+pl", sv_adj_form(["s", "def", "and", "p"])),
  ("sv-adj-form-abs-def-m", sv_adj_form(["def", "natm"])),
  ("sv-adj-form-abs-indef-n", sv_adj_form(["indef", "n"])),
  ("sv-adj-form-abs-pl", sv_adj_form(["p"])),
  ("sv-adj-form-comp", sv_adj_form(["comd"])),
  ("sv-adj-form-sup-attr", sv_adj_form(["sup", "attr"])),
  ("sv-adj-form-sup-attr-m", sv_adj_form(["sup", "attr", "s", "m"])),
  ("sv-adj-form-sup-pred", sv_adj_form(["sup", "pred"])),
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
  ("sv-noun-form-def", sv_noun_form(["def", "sg"])),
  ("sv-noun-form-def-gen", sv_noun_form(["def", "gen", "sg"])),
  ("sv-noun-form-def-gen-pl", sv_noun_form(["def", "gen", "pl"])),
  ("sv-noun-form-def-pl", sv_noun_form(["def", "pl"])),
  ("sv-noun-form-indef-gen", sv_noun_form(["indef", "gen", "sg"])),
  ("sv-noun-form-indef-gen-pl", sv_noun_form(["indef", "gen", "pl"])),
  ("sv-noun-form-indef-pl", sv_noun_form(["indef", "pl"])),
  ("sv-proper-noun-gen", (
    "inflection of",
    ("error-if", ("present-except", ["1", "2"])),
    ("set", "1", [
      "sv",
      ("copy", "1"),
      ("copy", "2"),
      "gen",
    ]),
    ("set", "p", "pn"),
  )),
  ("sv-verb-form-imp", sv_verb_form(["imp"])),
  ("sv-verb-form-inf-pass", sv_verb_form(["inf", "pass"])),
  # Contrary to what we said above, this one in particular has the final
  # period controllable by |dot=, which can override it. Pretty sure it
  # never occurs.
  ("sv-verb-form-past", sv_verb_form(["past"])),
  ("sv-verb-form-past-pass", sv_verb_form(["past", "pass"])),
  # Contrary to what we said above, this one in particular also has the final
  # period controllable by |dot=, which can override it. Pretty sure it
  # never occurs.
  ("sv-verb-form-pastpart", sv_verb_form(["past", "part"])),
  ("sv-verb-form-pre", sv_verb_form(["pres"])),
  ("sv-verb-form-pre-pass", sv_verb_form(["pres", "pass"])),
  # Contrary to what we said above, this one in particular doesn't have a
  # final period.
  ("sv-verb-form-prepart", sv_verb_form(["pres", "part"])),
  ("sv-verb-form-subjunctive", sv_verb_form(["sub"])),
  ("sv-verb-form-sup", sv_verb_form(["sup"])),
  ("sv-verb-form-sup-pass", sv_verb_form(["sup", "pass"])),
]

tg_specs = [
  ("tg-adj form of", lambda t, pagemsg: fa_tg_adj_form_of(t, pagemsg, "tg")),

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
        "man": ["1", "s", "imp"],
        "imp-man": ["1", "s", "imp"],
        "tu": ["2", "s", "imp"],
        "imp-tu": ["2", "s", "imp"],
        "vay": ["3", "s", "imp"],
        "imp-vay": ["3", "s", "imp"],
        "mo": ["1", "p", "imp"],
        "imp-mo": ["1", "p", "imp"],
        u"šomo": ["2", "p", "imp"],
        u"imp-šomo": ["2", "p", "imp"],
        "onho": ["3", "p", "imp"],
        "imp-onho": ["3", "p", "imp"],
        "r": ["root"],
        "prstem": ["pres", "stem"],
        "pstem": ["past", "stem"],
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
  "1s": ["1s", ",", "spos"],
  "2s": ["2s", ",", "spos"],
  "3s": ["3s", ",", "spos"],
  "4s": ["1p", ",", "spos"],
  "5s": ["2p", ",", "spos"],
  "6s": ["3p", ",", "spos"],
  "1p": ["1s", ",", "ppos"],
  "2p": ["2s", ",", "ppos"],
  "3p": ["3s", ",", "ppos"],
  "4p": ["1p", ",", "ppos"],
  "5p": ["2p", ",", "ppos"],
  "6p": ["3p", ",", "ppos"],
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
    "inflection of",
    ("error-if", ("present-except", ["1", "2", "3"])),
    ("set", "1", [
      "tr",
      ("copy", "1"),
      "",
      ("lookup", "2", tr_grammar_table),
      ("lookup", "3", tr_grammar_table),
    ]),
  )),
]

ur_specs = hi_ur_specs("ur")

templates_to_rename_specs = (
  art_blk_specs +
  bg_specs +
  br_specs +
  ca_specs +
  chm_specs +
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
  ie_specs +
  is_specs +
  it_specs +
  ja_specs +
  ka_specs +
  ku_specs +
  liv_specs +
  lt_specs +
  lv_specs +
  mr_specs +
  mt_specs +
  nb_specs +
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
  []
)

def rewrite_to_foo_form_of(t, pagemsg, comment):
  tn = tname(t)
  if tn in ["inflection of", "Inflection of"]:
    pos = getparam(t, "p")
    if pos in ["n", "noun"]:
      rmparam(t, "p")
      blib.set_template_name("noun form of" if tn == "inflection of" else "Noun form of")
    elif pos in ["a", "adj", "adjective"]:
      rmparam(t, "p")
      blib.set_template_name("adj form of" if tn == "inflection of" else "Adj form of")
    elif pos in ["v", "verb"]:
      rmparam(t, "p")
      blib.set_template_name("verb form of" if tn == "inflection of" else "Verb form of")
  newtn = tname(t)
  if newtn != tn:
    comment = re.sub(r"(to|with \{\{)%s([|\}])" % tn, r"\1%s\2" % newtn, comment)
  return t, comment

def rewrite_to_participle_of(t, pagemsg, comment):
  tn = tname(t)
  if tn in ["inflection of", "Inflection of"]:
    max_numbered = 0
    for param in t.params:
      pname = unicode(param.name).strip()
      if re.search("^[0-9]$", pname) and int(pname) > max_numbered:
        max_numbered = int(pname)
    if getparam(t, str(max_numbered)) == "part":
      rmparam(t, "part")
      blib.set_template_name("participle of" if tn == "inflection of" else "Participle of")
  newtn = tname(t)
  if newtn != tn:
    comment = re.sub(r"(to|with \{\{)%s([|\}])" % tn, r"\1%s\2" % newtn, comment)
  return t, comment

post_rewrite_hooks = [rewrite_to_foo_form_of, rewrite_to_participle_of]

templates_to_rename_map = {}

def initialize_templates_to_rename_map(do_all, do_specified):
  global templates_to_actually_do
  if do_all:
    templates_to_actually_do = [template for template, spec in templates_to_rename_specs]
  if do_specified:
    templates_to_actually_do = re.split(",", do_specified)

  for template, spec in templates_to_rename_specs:
    if template in templates_to_actually_do:
      if isinstance(spec, basestring):
        templates_to_rename_map[template] = templates_to_rename_map[spec]
      else:
        templates_to_rename_map[template] = spec


def flatten_list(value):
  return [y for x in value for y in (x if type(x) is list else [x])]

def expand_set_value(value, t, pagemsg):
  def check(cond, err):
    if not cond:
      raise BadRewriteSpec("Error expanding set value for template %s: %s; value=%s" %
          (unicode(t), err, value))
  if callable(value):
    return expand_set_value(value(t, pagemsg), t, pagemsg)
  if isinstance(value, basestring):
    return value
  if isinstance(value, list):
    return flatten_list([expand_set_value(x, t, pagemsg) for x in value])
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
      return expand_set_value(table[lookval], t, pagemsg)
    elif True in table:
      return expand_set_value(table[True], t, pagemsg)
    else:
      raise BadTemplateValue("Unrecognized value %s=%s" % (value[1], lookval))
  else:
    check(False, "Unrecognized directive %s" % direc)

def expand_spec(spec, t, pagemsg):
  def check(cond, err):
    if not cond:
      raise BadRewriteSpec("Error expanding spec for template %s: %s; spec=%s" %
          (unicode(t), err, spec))
  if callable(spec):
    return expand_spec(spec(t, pagemsg), t, pagemsg)
  check(type(spec) is tuple, "wrong type %s of %s, not tuple" % (type(spec), spec))
  check(len(spec) >= 1, "empty spec")
  oldname = tname(t)
  newname = spec[0]
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
          pname = unicode(param.name).strip()
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
      check(isinstance(param, basestring),
          "wrong type %s of %s, not basestring" % (type(param), param))
      newval = expand_set_value(newval, t, pagemsg)
      if newval is None:
        pass
      elif isinstance(newval, basestring):
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
        pname = unicode(param.name).strip()
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
          expanded_specs.append((actual_toparam, unicode(param.value)))

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
        pname = unicode(param.name).strip()
        m = re.search("^(.*?)([0-9]*)$", pname)
        pbase, pind = m.groups()
        excludeme = False
        for ename in exclude_params:
          if isinstance(ename, basestring):
            if ename == pname:
              excludeme = True
              break
          else:
            check(type(ename) is tuple, "wrong type %s of %s, not tuple" % (type(ename), ename))
            check(len(ename) == 2, "wrong length %s of ename %s, != 2" %
                (len(ename), ename))
            check(ename[0] == "list", 'ename[0] should == "list" but == %s' % ename[0])
            check(isinstance(ename[1], basestring),
                "wrong type %s of %s, not basestring" % (type(ename[1]), ename[1]))
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
            (unicode(param.name), unicode(param.value), unicode(param.showkey)))

    elif subspec[0] == "comment":
      check(len(subspec) == 2, "wrong length %s of subspec %s, != 2" %
          (len(subspec), subspec))
      _, comment = subspec
      comment = expand_set_value(comment, t, pagemsg)
      check(isinstance(comment, basestring),
          "wrong type %s of %s, not basestring" % (type(comment), comment))
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

def process_page(page, index, parsed):
  pagetitle = unicode(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")
  notes = []

  if re.search("^(User|Template|Module|MediaWiki):", pagetitle):
    pagemsg("WARNING: Page in a blacklisted namespace, skipping")
    return None, None

  for t in parsed.filter_templates():
    origt = unicode(t)
    tn = tname(t)
    if tn in templates_to_rename_map:
      template_spec = templates_to_rename_map[tn]
      try:
        new_name, new_params, comment = expand_spec(template_spec, t, pagemsg)
      except BadTemplateValue as e:
        pagemsg("WARNING: %s: %s" % (unicode(e.message), origt))
        continue
      except BadRewriteSpec as e:
        errandmsg("INTERNAL ERROR: %s: Processing template %s" % (unicode(e.message), origt))
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
          t.add(pname, pval, showkey=showkey, spreserve_spacing=False)

      # Now apply post-rewrite hooks
      for hook in post_rewrite_hooks:
        t, comment = hook(t, pagemsg, comment)

      notes.append(comment)

    if unicode(t) != origt:
      pagemsg("Replaced <%s> with <%s>" % (origt, unicode(t)))

  return unicode(parsed), notes

def process_page_for_check_ignore(page, index, template, ignore_type):
  pagetitle = unicode(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
  def errandpagemsg(txt):
    errandmsg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  if re.search("^(User|Template|Module|MediaWiki):", pagetitle):
    pagemsg("WARNING: Page in a blacklisted namespace, skipping")
    return None, None

  text = unicode(page.text)

  parsed = blib.parse_text(text)

  for t in parsed.filter_templates():
    tn = tname(t)
    if tn == template:
      foundit = False
      for m in re.finditer(r"^(.*?)%s(.*?)$" % re.escape(unicode(t)), text, re.M):
        foundit = True
        pretext = m.group(1)
        posttext = m.group(2)
        if not pretext.startswith("#"):
          pagemsg("WARNING: Found form-of template not on definition line: %s" % m.group(0))
        has_pretext = not re.search(r"^[#:]*\s*(\{\{(?:lb|label|sense|senseid|tlb)\|[^}]*?\}\}\s*)?$", pretext)
        has_posttext = posttext != ""
        if has_pretext and has_posttext:
          pagemsg("WARNING: Found form-of template with pre-text and post-text: %s" % m.group(0))
        elif has_pretext:
          pagemsg("WARNING: Found form-of template with pre-text: %s" % m.group(0))
        elif has_posttext:
          pagemsg("WARNING: Found form-of template with post-text: %s" % m.group(0))
      if not foundit:
        errandpagemsg("WARNING: Couldn't find form-of template on page: %s" % unicode(t))

parser = blib.create_argparser("Rename various lang-specific form-of templates to more general variants")
parser.add_argument('--do-all', help="Do all templates instead of default list",
    action="store_true")
parser.add_argument('--do-specified', help="Do specified comma-separated templates instead of default list")
parser.add_argument('--check-ignores', help="Check whether there may be problems ignoring intial cap or final dot", action="store_true")
parser.add_argument('--check-ignores-include-ucdot', help="Whether checking ignore issues, include type 'ucdot' to see whether it can be converted to 'lcnodot'", action="store_true")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

initialize_templates_to_rename_map(args.do_all, args.do_specified)
if args.check_ignores:
  for template in templates_to_actually_do:
    if template not in templates_by_cap_and_period_map:
      errandmsg("WARNING: The following template is not in templates_by_cap_and_period_map, and will be skipped: Template:%s" %
          template)
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
        for i, page in blib.references("Template:%s" % template, start, end):
          process_page_for_check_ignore(page, i, template,
              ignore_type)

else:
  for template in templates_to_actually_do:
    errandmsg("Processing references to Template:%s" % template)
    for i, page in blib.references("Template:%s" % template, start, end):
      blib.do_edit(page, i, process_page, save=args.save, verbose=args.verbose)
