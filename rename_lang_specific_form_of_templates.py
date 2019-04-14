#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, errandmsg, site, tname


# STILL TO DO:
# bg-verb form of (30114)
# ca-verb form of (78127)
# de-verb form of (? has 5=t -> "subordinate clause form") (54761)
# egy-verb form of (? lots of Egyptian-specific tags) (27)
# el-form-of-nounadj/el-form-of-pronoun (31472)
# el-form-of-verb (4657)
# en-simple-past-of (? other en-* form-of templates can't be generalized) (1043)
# en-third-person singular of (? other en-* form-of templates can't be generalized) (26938)
# eo-form of (? takes actual ending, generates tags from it, would be a radical shift) (99087)
# es-verb form of (? very complicated; takes a region param that can/should be moved out) (441797)
# ff-fuc-form of (0, DELETE)
# fi-verb form of (6022)
# gl-verb form of (? very complicated) (598)
# got-nom form of (? has posttext= if comp-of=, sup-of=, presptc-of= or pastptc-of=) (2935)
# hu-inflection of (9786)
# hu-participle (994)
# ia-form of (? takes actual ending, generates tags from it, would be a radical shift) (718)
# io-form of (? takes actual ending, generates tags from it, would be a radical shift) (10116)
# ja-past of verb (3)
# ja-te form of verb (5)
# ja-verb form of (? takes Japanese params, some in Hiragana, would be a radical shift) (93)
# ka-verb-form-of (? has links to [[Appendix:Georgian verbs]]; has stuff describing object pronouns, which maybe should be posttext) (116)
# lt-būdinys/lt-budinys (? would need language-specific tag for būdinys) (184)
# lt-dalyvis-1/lt-dalyvis (1085)
# lt-dalyvis-2 (118)
# lt-form-pronoun (? if class=determiner, has text "([[use]]d as a [[determiner]])") (51)
# lt-padalyvis (? would need language-specific tag for padalyvis) (466)
# lt-pusdalyvis (? would need language-specific tag for pusdalyvis) (117)
# lv-adv form of (2761)
# lv-inflection of (106703)
# lv-participle of (? might need lang-specific tags for "(object-of-perception form)", "(invariable form)", "(variable form)" (5163)
# mn-verb form of (? maybe? uses a module) (63)
# nb-noun-form-indef-pl (0, DELETE)
# nl-adj form of (? would need lang-specific tag for "Predicative/adverbial form", has posttext= if comp-of= or sup-of=) (4559)
# nn-verb-form of (? maybe? uses a module) (???)
# no-noun-form-def (0, DELETE)
# no-noun-form-def-pl (0, DELETE)
# pt-article form of (? says "of article ..." before link; might not be necessary) (6)
# pt-noun form of (1517)
# pt-ordinal form/pt-ordinal def (? would be a radical shift) (153)
# pt-pron def (? not only a form-of template) (24)
# pt-verb-form-of (? maybe? uses a module) (???)
# pt-verb form of (? very complicated; takes a region param that can/should be moved out) (29193)
# ru-participle of (47321)
# sce-verb form of (? maybe? uses a module) (1)
# sco-simple-past-of (? 'sco-past of' is hard to generalize) (17)
# sco-third-person singular of (? 'sco-past of' is hard to generalize) (91)
# sv-adj-form-abs-def (3)
# sv-adj-form-abs-def+pl (2072)
# sv-adj-form-abs-def-m (1274)
# sv-adj-form-abs-indef-n (1630)
# sv-adj-form-abs-pl (6)
# sv-adj-form-comp (724)
# sv-adj-form-comp-pl (1)
# sv-adj-form-sup-attr (486)
# sv-adj-form-sup-attr-m (14)
# sv-adj-form-sup-pred (509)
# sv-adj-form-sup-pred-pl (1)
# sv-adv-form-comp (11)
# sv-adv-form-sup (7)
# sv-noun-form-adj (1)
# sv-noun-form-def (10063)
# sv-noun-form-def-gen (8327)
# sv-noun-form-def-gen-pl (6928)
# sv-noun-form-def-pl (? if 'obsoleted by=', displays extra 'Obsolete form of' pre-text, maybe should go into separate template) (7574)
# sv-noun-form-indef-gen (7680)
# sv-noun-form-indef-gen-pl (6869)
# sv-noun-form-indef-pl (7430)
# sv-proper-noun-gen (198)
# sv-verb-form-imp (? if 'plural of=', displays extra 'Obsolete plural form of' pre-text, maybe should go into separate template) (567)
# sv-verb-form-inf-pass (1641)
# sv-verb-form-past (? if 'plural of=', displays extra 'Obsolete plural form of' pre-text, maybe should go into separate template) (2567)
# sv-verb-form-past-pass (? if 'plural of=', displays extra 'Obsolete plural form of' pre-text, maybe should go into separate template) (1631)
# sv-verb-form-pastpart (1814)
# sv-verb-form-pre (? if 'plural of=', displays extra 'Obsolete plural form of' pre-text, maybe should go into separate template) (2687)
# sv-verb-form-pre-pass (2067)
# sv-verb-form-prepart (2028)
# sv-verb-form-pres-pass (0, DELETE)
# sv-verb-form-subjunctive (14)
# sv-verb-form-sup (2187)
# sv-verb-form-sup-pass (1680)
# sw-adj form of (? might be tough) (???)
# tr-inflection of (22)
# tr-possessive form of (? includes posttext) (35)

class BadTemplateValue(Exception):
  pass

templates_to_actually_do = {
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
}

art_blk_specs = [
  ("blk-past of", (
    "inflection of",
    ("comment", "rename {{__TEMPNAME__}} to {{inflection of|art-blk}} with appropriate param changes"),
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
  ("bg-adj form of", (
    "Inflection of",
    ("error-if", ("present-except", ["1", "2", "3", "adj"])),
    ("set", "1", [
      "bg",
      ("copy", "adj"),
      "",
      ("lookup", "3", {
        "subject": "subje",
        "object": "obj",
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
    ("set", "POS", "a"),
  )),

  ("bg-noun form of", (
    "Inflection of",
    ("error-if", ("present-except", ["1", "2", "3", "noun"])),
    ("set", "1", [
      "bg",
      ("copy", "adj"),
      "",
      ("lookup", "3", {
        "subject": "subje",
        "object": "obj",
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
    ("set", "POS", "n"),
  )),
]

br_specs = [
  # NOTE: Has automatic, non-controllable initial caps that we're ignoring.
  ("br-noun-plural", (
    "inflection of",
    ("error-if", ("present-except", ["1", "2"])),
    ("set", "1", [
      "br",
      ("copy", "1"),
      ("copy", "2"),
      "p",
    ]),
    ("set", "POS", "n"),
  )),
]

def romance_adj_form_of(lang):
  # This works for ca, es, it and pt. Romanian has its own template and French
  # uses {{masculine singular of}}, {{feminine singular of}}, etc.
  # Not all languages accept m-f or mf, but it doesn't hurt to accept them.
  return (
    "Inflection of",
    ("error-if", ("present-except", ["1", "2", "3", "4", "nocap", "nodot"])),
    ("set", "1", [
      lang,
      ("copy", "1"),
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
        # FIXME! Consider enabling mf == m//f in [[Module:form of/data]]
        "m-f": "m//f",
        "mf": "m//f",
      }),
      ("lookup", "3", {
        "sg": "s",
        "pl": "p",
      }),
    ]),
    ("set", "POS", "a"),
    ("copy", "nocap"),
    ("copy", "nodot"),
  )

ca_specs = [
  ("ca-adj form of", romance_adj_form_of("ca")),
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
  "1s": ["1", "s"],
  "1p": ["1", "p"],
  "2s": ["2", "s"],
  "2p": ["2", "p"],
  "3s": ["3", "s"],
  "3p": ["3", "p"],
  "0": [],
  "s": "s",
  "p": "p",
  "pos": "possessed",
  "prs": "pres",
  "pst": "past",
  "fut": "fut",
  "ind": "ind",
  "imp": "imp",
  "psv": "pass",
  "act": "act",
  "": [],
}

# NOTE: If 2!=nom, categorizes into one of:
# -- 6==adj -> adjective forms
# -- 6==num -> numeral forms
# -- 6==v -> verb forms
# -- 6==vpart -> participle forms
# -- 6==pro -> pronoun forms
# -- 6==proper -> proper noun forms
# -- 6==<anything else> -> noun forms
# This should be handled by the headword, but we should check.
chm_inflection_of = (
  "inflection of",
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
      True: "non-possessed"
    }),
    ("lookup", "2", chm_grammar_table),
    ("lookup", "3", chm_grammar_table),
    ("lookup", "4", chm_grammar_table),
    ("lookup", "5", chm_grammar_table),
  ]),
)

chm_specs = [
  ("chm-inflection of", chm_inflection_of),
]

cu_specs = [
  # NOTE: Has automatic, non-controllable initial caps and final period; we
  # should consider ignoring that. Only 10 uses. Categorizes into
  # '{{{type}}} forms', which should be handled by the headword; in actual
  # use, type is always 'noun'.
  ("cu-form of", (
    "Inflection of",
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
    "inflection of",
    ("error-if", ("present-except", ["deg", "1", "2", "3", "4", "nocat", "sort"])),
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
    "inflection of",
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
]

el_specs = [
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
        ])
      ) if getparam(t, "deg") == "comp" else
      ("inflection of",
        ("comment", "rename {{__TEMPNAME__|deg=sup}} to {{inflection of|el|...|asupd}}"),
        ("error-if", ("present-except", ["deg", "1", "alt", "gloss"])),
        ("error-if", ("neq", "deg", "sup")),
        ("set", "1", [
          "el",
          ("copy", "1"),
          # FIXME: In [[Module:form of/templates]], add alt= alias for numbered
          # display form
          ("copy", "alt"),
          # FIXME: In [[Module:form of/data]], add
          # "asupd" = "absolute superlative degree"
          # "rsupd" = "relative superlative degree"
          "asupd",
        ]),
        ("copy", "gloss", "t"),
      )
  )),

  ("el-participle of", (
    "Inflection of",
    ("error-if", ("present-except", ["1", "2", "gloss", "t", "nodot"])),
    ("set", "1", [
      "el",
      ("copy", "1"),
      "",
      ("lookup", "2", {
        "present": ["pres", "part"],
        "pres": ["pres", "part"],
        "perfect": ["perf", "part"],
        "perf": ["perf", "part"],
        "passive perfect": ["pass", "perf", "part"],
        "pass-perf": ["pass", "perf", "part"],
      }),
    ]),
    ("copy", "gloss", "t"),
    ("copy", "t"),
    ("copy", "nodot"),
  )),
]

def enm_verb_form(parts):
  return (
    "inflection of",
    ("error-if", ("present-except", ["1", "2"])),
    ("set", "1", [
      "enm",
      ("copy", "1"),
      ("copy", "2"),
      parts,
    ])
  )

enm_specs = [
  # NOTE: All of these have automatic, non-controllable initial cap that
  # we're ignoring. Doesn't have final period. There are <= 9 uses of each
  # template.
  ("enm-first-person singular of",
      enm_verb_form(["1", "s", "pres", "ind"])),
  ("enm-first/third-person singular past of",
      # FIXME: In [[Module:form of/data]], add:
      # 13 = [[Appendix:Glossary#first person|first]] and [[Appendix:Glossary#third person|third person]]
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
  ("et-nom form of", (
    "Inflection of",
    ("error-if", ("present-except", ["1", "c", "n"])),
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
  )),

  ("et-participle of", (
    "Inflection of",
    ("error-if", ("present-except", ["1", "t", "nocap", "nodot"])),
    ("set", "1", [
      "et",
      ("copy", "1"),
      "",
      ("lookup", "t", {
        "pres": ["pres", "act", "part"],
        "pres_actv": ["pres", "act", "part"],
        "pres_pasv": ["pres", "pass", "part"],
        "past": ["past", "act", "part"],
        "past_actv": ["past", "act", "part"],
        "past_pasv": ["past", "pass", "part"],
      }),
    ]),
    ("copy", "nocap"),
    ("copy", "nodot"),
  )),

  ("et-verb form of", (
    # The template code supports m=ptc and categorizes specially, but
    # it never occurs.
    "Inflection of",
    ("error-if", ("present-except", ["1", "p", "m", "t"])),
    ("set", "1", [
      "et",
      ("copy", "1"),
      "",
      ("lookup", "p", {
        "1s": ["1", "s"],
        "2s": ["2", "s"],
        "3s": ["3", "s"],
        "1p": ["1", "p"],
        "2p": ["2", "p"],
        "3p": ["3", "p"],
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

  ("fa-form-verb", (
    "inflection of",
    ("error-if", ("present-except", ["1", "2"])),
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
        # FIXME: In [[Module:form of/data]], add "root" and "stem"
        "r": ["root"],
        "prstem": ["pres", "stem"],
        "pstem": ["past", "stem"],
      }),
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
  ("got-verb form of", (
    "Inflection of",
    ("error-if", ("present-except", ["1", "p", "n", "t", "v", "m", "nocap", "nodot"])),
    ("set", "1", [
      "got",
      ("copy", "1"),
      "",
      ("lookup", "p", {
        "1": "1",
        "2": "2",
        "3": "3",
        "13": "13",
        "123": "123",
      }),
      ("lookup", "n", {
        "sg": "s",
        "du": "d",
        "pl": "p",
      }),
      ("lookup", "t", {
        "pres": "pres",
        "past": "past",
      }),
      ("lookup", "v", {
        "actv": "act",
        "pasv": "pass",
      }),
      ("lookup", "m", {
        "ind": "ind",
        "sub": "sub",
        "imp": "imp",
        "ptc": "part",
        "indimp": "ind//imp",
      }),
    ]),
    ("copy", "nocap"),
    ("copy", "nodot"),
  )),
]

def hi_ur_specs(lang):
  return [
    # NOTE: Has automatic, non-controllable final period that we're ignoring.
    # Doesn't have initial caps.
    ("%s-form-adj" % lang, (
      "inflection of",
      ("error-if", ("present-except", ["1", "2", "3"])),
      ("set", "1", [
        lang,
        ("copy", "3"),
        "",
        ("lookup", "1", {
          "d": "dir",
          # FIXME: In [[Module:form of/data]], add "indir" = "indirect case",
          # I think same as "oblique case"
          "i": "indir",
          "o": "indir",
          "v": "vocative",
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
      "inflection of",
      ("error-if", ("present-except", ["1", "2", "3"])),
      ("set", "1", [
        lang,
        ("copy", "3"),
        "",
        ("lookup", "1", {
          # FIXME: In [[Module:form of/data]], add
          #  "hab" = "habitual" (aspect),
          #  "cont" = "continuous" (aspect) (same as progressive?)
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
      ]),
      ["adj", "form"],
    )),

    # NOTE: Has automatic, non-controllable final period that we're ignoring.
    # Doesn't have initial caps.
    ("%s-form-noun" % lang, (
      "inflection of",
      ("error-if", ("present-except", ["1", "2", "3"])),
      ("set", "1", [
        lang,
        ("copy", "3"),
        "",
        ("lookup", "1", {
          "d": "dir",
          # FIXME: In [[Module:form of/data]], add "indir" = "indirect case",
          # I think same as "oblique case"
          "i": "indir",
          "o": "indir",
          "v": "vocative",
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
      "inflection of",
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

hu_specs = [
  ("hy-form-noun", (
    "inflection of",
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
      }),
      ("lookup", "5", {
        "1": ["1", "possuf"],
        "2": ["2", "possuf"],
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

hy_specs = [
  ("hy-form-noun", (
    "inflection of",
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
    "inflection of",
    ("error-if", ("present-except", ["1"])),
    ("set", "1", [
      "ie",
      ("copy", "1"),
      "",
      "past",
      "and",
      "past",
      "part",
    ]),
  )),
]

is_specs = [
  ("is-conjugation of", (
    "inflection of",
    ("error-if", ("present-except", ["1", "2", "3", "4", "5", "6"])),
    ("set", "1", [
      "is",
      ("copy", "1"),
      "",
      ("copy", "2"),
      ("copy", "3"),
      ("copy", "4"),
      ("copy", "5"),
      ("copy", "6"),
    ]),
  )),

  ("is-inflection of", (
    "inflection of",
    ("error-if", ("present-except", ["1", "2", "3", "4", "5"])),
    ("set", "1", [
      "is",
      ("copy", "1"),
      "",
      ("copy", "2"),
      ("copy", "3"),
      ("copy", "4"),
      ("copy", "5"),
    ]),
  )),
]

it_specs = [
  ("it-adj form of", romance_adj_form_of("it")),
]

ka_specs = [
  ("ka-verbal for", (
    "verbal noun of",
    ("error-if", ("present-except", ["1"])),
    ("set", "1", [
      "ka",
      ("copy", "1"),
    ]),
  )),

  ("ka-verbal of", "ka-verbal for"),
]

ku_specs = [
  ("ku-verb form of", (
    "inflection of",
    ("error-if", ("present-except", ["1", "2", "3"])),
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
    "inflection of",
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
    ("error-if", ("present-except", ["1", "2", "3"])),
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
      }),
    ]),
  )),

  ("liv-participle of", (
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
}

lt_specs = [
  # NOTE: Has automatic, non-controllable final period that we're ignoring.
  # Doesn't have initial caps. Categorizes into 'adjective forms', which
  # should be handled by the headword, or 'pronominal adjective forms' if
  # "pron" in tags, which maybe should be handled by headword (FIXME).
  ("lt-form-adj", (
    "inflection of",
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
    "inflection of",
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
    "inflection of",
    ("error-if", ("present-except", ["1", "2", "3"])),
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
      }),
    ]),
  )),

  # NOTE: Has automatic, non-controllable final period that we're ignoring.
  # Doesn't have initial caps. FIXME: Categorizes into
  # 'dalyvis participle forms', or (if pro= is given)
  # 'pronominal dalyvis participle forms'.
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
      ("set", "POS", "part"),
    ]),
  )),

  # NOTE: Has automatic, non-controllable final period that we're ignoring.
  # Doesn't have initial caps. Categorizes into 'verb forms', which
  # should be handled by the headword.
  ("lt-form-verb", (
    "inflection of",
    ("error-if", ("present-except", ["1", "2", "3", "4"])),
    ("set", "1", [
      "lt",
      ("copy", "3"),
      "",
      ("lookup", "1", {
        "1s": ["1", "s"],
        "1p": ["1", "p"],
        "2s": ["2", "s"],
        "2p": ["2", "p"],
        "3s": ["3", "s"],
        "3p": ["3", "p"],
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
      }),
    ]),
  )),
]

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
    ("set", "POS",
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
    ("set", "POS",
      ("lookup", "2", {
        "vpart": "part",
        "": [],
      })
    ),
  )),

  ("lv-verbal noun of", (
    "reflexive of",
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
    "inflection of",
    ("error-if", ("present-except", ["1", "2", "3"])),
    ("set", "1", [
      "mr",
      ("copy", "3"),
      "",
      ("lookup", "1", {
        "d": "dir",
        # FIXME: In [[Module:form of/data]], add "indir" = "indirect case",
        # I think same as "oblique case"
        "i": "indir",
        "o": "indir",
        "v": "vocative",
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
  )),
]

nb_specs = [
  ("nb-noun-form-def-gen", (
    "inflection of",
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
    "inflection of",
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
    "inflection of",
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
  # NOTE: Capitalizes initial letter, we are ignoring that and ignoring
  # nocap=. Only 5 uses.
  ("ofs-nom form of", (
    "inflection of",
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
      }),
      ("lookup", "g", {
        "m": "m",
        "f": "f",
        "n": "n",
        "mf": "m//f",
        "mn": "m//n",
        "mfn": "m//f//n",
      }),
      # FIXME: In [[Module:form of/data]], add "wk" = "weak", "str" = "strong";
      # these are tag_type="inflection" or "class" I think
      ("lookup", "w", {
        "w": "wk",
        "s": "str",
      }),
    ]),
  )),
]

osx_specs = [
  # NOTE: Capitalizes initial letter, we are ignoring that and ignoring
  # nocap=. Only 22 uses.
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
      }),
      ("lookup", "w", {
        "w": "wk",
        "s": "str",
      }),
    ]),
  )),
]

pt_specs = [
  ("pt-adj form of", romance_adj_form_of("pt")),

  # NOTE: Capitalizes initial letter, we are ignoring that and ignoring
  # nocap=. Doesn't have final period. Only 11 uses.
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
  )),

  # NOTE: Capitalizes initial letter, we are ignoring that and ignoring
  # nocap=. Only 10 uses.
  ("pt-cardinal form of", (
    "feminine of",
    ("error-if", ("present-except", ["1"])),
    ("set", "1", [
      "pt",
      ("copy", "1"),
    ]),
  )),
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
      "inflection of",
      ("error-if", ("present-except", ["1", "2", "3", "4"])),
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
      "inflection of",
      ("error-if", ("present-except", ["1", "2", "3"])),
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
    "inflection of",
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
      }),
    ]),
  )),

  ("ro-form-adj", "ro-adj-form of"),

  ("ro-form-noun", ro_form_noun),

  ("ro-form-verb", (
    # NOTE: Has automatic, non-controllable final period that we're ignoring.
    # Doesn't have initial caps. Categorizes into 'verb forms', which should be
    # handled by the headword.
    "inflection of",
    ("error-if", ("present-except", ["1", "2", "3"])),
    ("set", "1", [
      "ro",
      ("copy", "3"),
      "",
      ("lookup", "1", {
        # FIXME: In [[Module:form of/data]], consider adding common
        # combinations, specifically 1s/2s/3s, 1d/2d/3d, 1p/2p/3p
        # FIXME: In [[Module:form of/data]], add:
        # 12 = [[Appendix:Glossary#first person|first]] and [[Appendix:Glossary#second person|second person]]
        # 13 = [[Appendix:Glossary#first person|first]] and [[Appendix:Glossary#third person|third person]]
        # 123 = [[Appendix:Glossary#first person|first]], [[Appendix:Glossary#second person|second]] and [[Appendix:Glossary#third person|third person]] (with appropriate spans for serial commas, and fix ucfirst() to handle those spans)
        "1s": ["1", "s"],
        "2s": ["2", "s"],
        "3s": ["3", "s"],
        "1p": ["1", "p"],
        "2p": ["2", "p"],
        "3p": ["3", "p"],
      }),
      ("lookup", "2", {
        "pres": ["pres", "ind"],
        "present": ["pres", "ind"],
        "impf": ["impf", "ind"],
        "imperfect": ["impf", "ind"],
        # FIXME: In [[Module:form of/data]], add sperf=simple perfect,
        # spast=simple past
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
        # FIXME: In [[Module:form of/data]], add impv=imperative
        "impr": ["imp"],
        "imperative": ["imp"],
      }),
    ]),
  )),
]

roa_opt_specs = [
  ("roa-opt-noun plural of", (
    "Plural of",
    ("error-if", ("present-except", ["1"])),
    ("set", "1", [
      "roa-opt",
      ("copy", "1"),
    ]),
  )),
]

sh_specs = [
  # NOTE: Categorizes into "noun forms", but this should be handled by
  # the headword.
  ("sh-form-noun", (
    "inflection of",
    ("error-if", ("present-except", ["1", "2", "3"])),
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

  ("sh-verb form of", (
    lambda t, pagemsg:
      ("verbal noun of",
        ("comment", "rename {{__TEMPNAME__|vn}} to {{verbal noun of|sh}}"),
        ("error-if", ("present-except", ["1", "2", "3"])),
        ("error-if", ("neq", "2", "")),
        ("set", "1", [
          "sh",
          ("copy", "3")
        ])
      ) if getparam(t, "1") == "vn" else
      ("inflection of",
        ("error-if", ("present-except", ["1", "2", "3"])),
        ("set", "1", [
          "sh",
          ("copy", "3"),
          "",
          ("lookup", "1", {
            "1s": ["1", "s"],
            "2s": ["2", "s"],
            "3s": ["3", "s"],
            "1p": ["1", "s"],
            "2p": ["2", "p"],
            "3p": ["3", "p"],
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
    "inflection of",
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

  ("sl-form-noun", (
    "inflection of",
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

  ("sl-form-verb", (
    "inflection of",
    ("error-if", ("present-except", ["1", "2", "3"])),
    ("set", "1", [
      "sl",
      ("copy", "3"),
      "",
      ("lookup", "1", {
        "1s": ["1", "s"],
        "2s": ["2", "s"],
        "3s": ["3", "s"],
        "1d": ["1", "d"],
        "2d": ["2", "d"],
        "3d": ["3", "d"],
        "1p": ["1", "s"],
        "2p": ["2", "p"],
        "3p": ["3", "p"],
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

  # FIXME: Add [[Module:form of/cat]], where for sl,
  # categorizes into 'participles' if 'part' in tags,
  # categorizes into 'verbal nouns' if 'sup' or 'ger' in tags;
  # should probably canonicalize the abbreviations before calling
  # code to find category

  # NOTE: Has automatic, non-controllable final period that we're ignoring.
  # Doesn't have initial caps.
  ("sl-participle of", (
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

def sv_form(parts):
  return (
    "inflection of",
    ("error-if", ("present-except", ["1", "2"])),
    ("set", "1", [
      "sv",
      ("copy", "1"),
      ("copy", "2"),
      parts,
    ])
  )

sv_specs = [
  ("sv-adj-form-abs-def", sv_form(["def"])),
  ("sv-adj-form-abs-def+pl", sv_form(["s", "def", "and", "p"])),
  ("sv-adj-form-abs-def-m", sv_form(["def", "natm"])),
  ("sv-adj-form-abs-indef-n", sv_form(["indef", "n"])),
  ("sv-adj-form-abs-pl", sv_form(["p"])),
  ("sv-adj-form-comp", sv_form(["comd"])),
  ("sv-adj-form-comp-pl", sv_form(["comd", "p"])),
  ("sv-adj-form-sup-attr", sv_form(["sup", "attr"])),
  ("sv-adj-form-sup-attr-m", sv_form(["sup", "attr", "s", "m"])),
  ("sv-adj-form-sup-pred", sv_form(["sup", "pred"])),
  ("sv-adj-form-sup-pred-pl", sv_form(["sup", "pred", "p"])),
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
# sv-noun-form-adj (1)
# sv-noun-form-def (10063)
# sv-noun-form-def-gen (8327)
# sv-noun-form-def-gen-pl (6928)
# sv-noun-form-def-pl (? if 'obsoleted by=', displays extra 'Obsolete form of' pre-text, maybe should go into separate template) (7574)
# sv-noun-form-indef-gen (7680)
# sv-noun-form-indef-gen-pl (6869)
# sv-noun-form-indef-pl (7430)
# sv-proper-noun-gen (198)
# sv-verb-form-imp (? if 'plural of=', displays extra 'Obsolete plural form of' pre-text, maybe should go into separate template) (567)
# sv-verb-form-inf-pass (1641)
# sv-verb-form-past (? if 'plural of=', displays extra 'Obsolete plural form of' pre-text, maybe should go into separate template) (2567)
# sv-verb-form-past-pass (? if 'plural of=', displays extra 'Obsolete plural form of' pre-text, maybe should go into separate template) (1631)
# sv-verb-form-pastpart (1814)
# sv-verb-form-pre (? if 'plural of=', displays extra 'Obsolete plural form of' pre-text, maybe should go into separate template) (2687)
# sv-verb-form-pre-pass (2067)
# sv-verb-form-prepart (2028)
# sv-verb-form-pres-pass (0, DELETE)
# sv-verb-form-subjunctive (14)
# sv-verb-form-sup (2187)
# sv-verb-form-sup-pass (1680)
]

tg_specs = [
  ("tg-adj form of", lambda t, pagemsg: fa_tg_adj_form_of(t, pagemsg, "tg")),

  ("tg-adj-form", "tg-adj form of"),

  ("tg-form-verb", (
    "inflection of",
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
        # FIXME: In [[Module:form of/data]], add "root" and "stem"
        "r": ["root"],
        "prstem": ["pres", "stem"],
        "pstem": ["past", "stem"],
      }),
    ]),
  )),
]

tl_specs = [
  # NOTE: Has automatic, non-controllable initial caps and final period that
  # we're ignoring. Categorizes into 'verb forms', which should be
  # handled by the headword.
  ("tl-verb form of", (
    "inflection of",
    ("error-if", ("present-except", ["1", "2"])),
    ("set", "1", [
      "tl",
      ("copy", "1"),
      "",
      ("lookup", "2", {
        # FIXME: In [[Module:form of/data]], add (or maybe as lang-specific)
        # "compl" = "complete aspect"
        # "rcompl" = "recently complete aspect"
        # "contem" = "contemplative aspect"
        "comp": ["compl", "asp"],
        "prog": ["prog", "asp"],
        "cont": ["contem", "asp"],
      }),
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
  enm_specs +
  es_specs +
  et_specs +
  fa_specs +
  gmq_bot_specs +
  got_specs +
  hi_specs +
  hu_specs +
  hy_specs +
  ie_specs +
  is_specs +
  it_specs +
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
  sh_specs +
  sl_specs +
  sv_specs +
  tg_specs +
  tl_specs +
  ur_specs +
  []
)

templates_to_rename_map = {}
for template, spec in templates_to_rename_specs:
  if not templates_to_actually_do or template in templates_to_actually_do:
    if isinstance(spec, basestring):
      templates_to_rename_map[template] = templates_to_rename_map[spec]
    else:
      templates_to_rename_map[template] = spec

def flatten_list(value):
  return [y for x in value for y in (x if type(x) is list else [x])]

def expand_set_value(value, t, pagemsg):
  if callable(value):
    return expand_set_value(value(t, pagemsg), t, pagemsg)
  if isinstance(value, basestring):
    return value
  if isinstance(value, list):
    return flatten_list([expand_set_value(x, t, pagemsg) for x in value])
  assert(isinstance(value, tuple))
  assert(len(value) >= 1)
  direc = value[0]
  if direc == "copy":
    assert len(value) == 2
    if t.has(value[1]):
      return getparam(t, value[1])
    else:
      return None
  elif direc == "lookup":
    assert len(value) == 3
    lookval = getparam(t, value[1])
    table = value[2]
    assert type(table) is dict
    if lookval in table:
      return expand_set_value(table[lookval], t, pagemsg)
    elif True in table:
      return expand_set_value(table[True], t, pagemsg)
    else:
      raise BadTemplateValue("Unrecognized value %s=%s" % (value[1], lookval))
  else:
    assert False, "Unrecognized directive %s" % direc

def expand_spec(spec, t, pagemsg):
  if callable(spec):
    return expand_spec(spec(t, pagemsg), t, pagemsg)
  assert type(spec) is tuple
  assert len(spec) >= 1
  oldname = tname(t)
  newname = spec[0]
  expanded_specs = []
  comment = None
  for subspec in spec[1:]:
    assert len(subspec) >= 1

    if subspec[0] == "error-if":
      assert len(subspec) == 2
      assert len(subspec[1]) >= 1
      errtype = subspec[1][0]
      if errtype == "present-except":
        assert len(subspec[1]) == 2
        allowed_params = set(subspec[1][1])
        for param in t.params:
          pname = unicode(param.name).strip()
          if pname not in allowed_params:
            raise BadTemplateValue(
                "Disallowed param %s=%s" % (pname, getparam(t, pname)))
      elif errtype == "eq":
        assert len(subspec[1]) == 3
        if getparam(t, subspec[1][1]) == subspec[1][2]:
          raise BadTemplateValue(
            "Disallowed value: %s=%s" % (subspec[1][1], subspec[1][2]))
      elif errtype == "neq":
        assert len(subspec[1]) == 3
        if getparam(t, subspec[1][1]) != subspec[1][2]:
          raise BadTemplateValue(
            "Disallowed value: %s=%s, expected %s" % (
              subspec[1][1], getparam(t, subspec[1][1]), subspec[1][2]))
      else:
        assert False, "Unrecognized error-if subtype: %s" % errtype

    elif subspec[0] == "set":
      assert len(subspec) == 3
      _, param, newval = subspec
      assert(isinstance(param, basestring))
      newval = expand_set_value(newval, t, pagemsg)
      if newval is None:
        pass
      elif isinstance(newval, basestring):
        expanded_specs.append((param, newval))
      else:
        assert(type(newval) is list)
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
      assert len(subspec) in [2, 3]
      fromparam = subspec[1]
      if len(subspec) == 2:
        toparam = fromparam
      else:
        toparam = subspec[2]
      if t.has(fromparam):
        expanded_specs.append((toparam, getparam(t, fromparam)))

    elif subspec[0] == "copylist":
      assert len(subspec) in [2, 3]
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
          assert(fromoffset >= 0)
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
      assert len(subspec) == 2
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
            assert type(ename) is tuple
            assert len(ename) == 2
            assert ename[0] == "list"
            assert isinstance(ename[1], basestring)
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
      assert len(subspec) == 2
      _, comment = subspec
      comment = expand_set_value(comment, t, pagemsg)
      assert(isinstance(comment, basestring))
      comment = comment.replace("__TEMPNAME__", oldname).replace("__NEWNAME__", newname)

    else:
      assert False, "Unrecognized directive: %s" % subspec[0]

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
      notes.append(comment)

    if unicode(t) != origt:
      pagemsg("Replaced <%s> with <%s>" % (origt, unicode(t)))

  return unicode(parsed), notes

parser = blib.create_argparser("Rename various lang-specific form-of templates to more general variants")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

for template, spec in templates_to_rename_specs:
  if not templates_to_actually_do or template in templates_to_actually_do:
    for i, page in blib.references("Template:%s" % template, start, end):
      blib.do_edit(page, i, process_page, save=args.save, verbose=args.verbose)
