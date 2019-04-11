#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, errandmsg, site, tname


class BadTemplateValue(Exception):
  pass

def sl_check_1_is_m(t, pagemsg, should_return):
  if getparam(t, "1") == "m":
    return should_return
  else:
    raise BadTemplateValue("Expected 1=m with output of %s" %
      "|".join(should_return)
    )

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
    ("comment", "rename {{%s}} to {{%s|%s}}" % (tname(t), template_name, lang)),
  )

# NOTE: Has automatic, non-controllable final period that we're ignoring.
# Doesn't have initial caps. Categorizes into 'noun forms', which should be
# handled by the headword.
def ro_form_noun(t, pagemsg):
  number_table = {
    "s": "s",
    "p": "p",
  })
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
  })

  if getparam(t, "1") in ["i", "d", ""]:
    return (
      "inflection of",
      ("comment", "rename {{__TEMPNAME__}} to {{inflection of|ro|...}}"),
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
      ("comment", "rename {{__TEMPNAME__}} to {{inflection of|ro|...}}"),
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

templates_to_rename_specs = [
  ("da-pl-genitive", (
    "genitive of",
    ("comment", "rename {{__TEMPNAME__}} to {{genitive of|da|...}}"),
    ("error-if", ("present-except", ["1"])),
    ("set", "1", [
      "da",
      ("copy", "1"),
    ])
  )),
  ("de-form-noun", (
    "inflection of",
    ("comment", "rename {{__TEMPNAME__}} to {{inflection of|de|...}}"),
    ("error-if", ("present-except", ["1", "2", "3"])),
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
  )),
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
  ("et-nom form of", (
    "Inflection of",
    ("comment", "rename {{__TEMPNAME__}} to {{Inflection of|et}}"),
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
  ("et-verb form of", (
    # The template code supports m=ptc and categorizes specially, but
    # it never occurs.
    "Inflection of",
    ("comment", "rename {{__TEMPNAME__}} to {{Inflection of|et}}"),
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
  ("fa-adj form of", lambda t, pagemsg: fa_tg_adj_form_of(t, pagemsg, "fa")),
  ("fa-adj-form", "fa-adj form of"),
  ("ka-verbal for", (
    "verbal noun of",
    ("comment", "rename {{__TEMPNAME__}} to {{verbal noun of|ka}}"),
    ("error-if", ("present-except", ["1"])),
    ("set", "1", [
      "ka",
      ("copy", "1"),
    ]),
  ),
  ("ka-verbal of", "ka-verbal for"),
  ("liv-inflection of", (
    "inflection of",
    ("comment", "rename {{__TEMPNAME__}} to {{inflection of|liv|...}}"),
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
  ("lt-form-noun", (
    "inflection of",
    ("comment", "rename {{__TEMPNAME__}} to {{inflection of|lt|...}}"),
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
  ("lv-reflexive of", (
    "reflexive of",
    ("comment", "rename {{__TEMPNAME__}} to {{reflexive of|lv|...}}"),
    ("error-if", ("present-except", ["1"])),
    ("set", "1", [
      "lv",
      ("copy", "1"),
    ]),
  )),
  ("lv-verbal noun of", (
    "reflexive of",
    ("comment", "rename {{__TEMPNAME__}} to {{verbal noun of|lv|...}}"),
    ("error-if", ("present-except", ["1"])),
    ("set", "1", [
      "lv",
      ("copy", "1"),
    ]),
  )),
  # NOTE: Has automatic, non-controllable final period that we're ignoring.
  # Doesn't have initial caps.
  ("mr-form-adj", (
    "inflection of",
    ("comment", "rename {{__TEMPNAME__}} to {{inflection of|mr|...}}"),
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
  ("mt-prep-form", (
    "inflection of",
    ("comment", "rename {{__TEMPNAME__}} to {{inflection of|mt|...}}"),
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
  ("nb-noun-form-def-gen", (
    "inflection of",
    ("comment", "rename {{__TEMPNAME__}} to {{inflection of|nb|...}}"),
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
    ("comment", "rename {{__TEMPNAME__}} to {{inflection of|nb|...}}"),
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
    ("comment", "rename {{__TEMPNAME__}} to {{inflection of|nb|...}}"),
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
  # NOTE: Capitalizes initial letter, we are ignoring that and ignoring
  # nocap=. Only 5 uses.
  ("ofs-nom form of", (
    "inflection of",
    ("comment", "rename {{__TEMPNAME__}} to {{inflection of|ofs|...}}"),
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
  # NOTE: Capitalizes initial letter, we are ignoring that and ignoring
  # nocap=. Only 22 uses.
  ("osx-nom form of", (
    "inflection of",
    ("comment", "rename {{__TEMPNAME__}} to {{inflection of|osx|...}}"),
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
  # NOTE: Capitalizes initial letter, we are ignoring that and ignoring
  # nocap=. Only 11 uses.
  ("pt-adv form of", (
    "inflection of",
    ("comment", "rename {{__TEMPNAME__}} to {{inflection of|pt|...}}"),
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
  # nocap=. Only 11 uses.
  ("pt-cardinal form of", (
    "feminine of",
    ("comment", "rename {{__TEMPNAME__}} to {{feminine of|pt|...}}"),
    ("error-if", ("present-except", ["1"])),
    ("set", "1", [
      "pt",
      ("copy", "1"),
    ]),
  )),
  ("ro-adj-form of", (
    # Categorizes into 'adjective forms', should be handled by headword
    "inflection of",
    ("comment", "rename {{__TEMPNAME__}} to {{inflection of|ro|...}}"),
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
    ("comment", "rename {{__TEMPNAME__}} to {{inflection of|ro|...}}"),
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
  ("roa-opt-noun plural of", (
    "Plural of",
    ("comment", "rename {{__TEMPNAME__}} to {{Plural of|roa-opt|...}}"),
    ("error-if", ("present-except", ["1"])),
    ("set", "1", [
      "roa-opt",
      ("copy", "1"),
    ]),
  )),
  ("sh-form-noun", (
    "inflection of",
    ("comment", "rename {{__TEMPNAME__}} to {{inflection of|sh|...}}"),
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
        ("comment", "rename {{__TEMPNAME__}} to {{inflection of|sh|...}}"),
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
  ("sl-form-adj", (
    "inflection of",
    ("comment", "rename {{__TEMPNAME__}} to {{inflection of|sl|...}}"),
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
    ("comment", "rename {{__TEMPNAME__}} to {{inflection of|sl|...}}"),
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
    ("comment", "rename {{__TEMPNAME__}} to {{inflection of|sl|...}}"),
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
    ("comment", "rename {{__TEMPNAME__}} to {{inflection of|sl|...}}"),
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
  ("tg-adj form of", lambda t, pagemsg: fa_tg_adj_form_of(t, pagemsg, "tg")),
  ("tg-adj-form", "tg-adj form of"),
  # NOTE: Has automatic, non-controllable initial caps and final period that
  # we're ignoring. Categorizes into 'verb forms', which should be
  # handled by the headword.
  ("tl-verb form of", (
    "inflection of",
    ("comment", "rename {{__TEMPNAME__}} to {{inflection of|tl|...}}"),
    ("error-if", ("present-except", ["1", "2"])),
    ("set", "1", [
      "tl",
      ("copy", "1"),
      "",
      ("lookup", "2", {
        # FIXME: In [[Module:form of/data]], add
        # "compl" = "complete aspect"
        # "rcompl" = "recently complete aspect"
        # "contem" = "contemplative aspect"
        "comp": ["compl", "asp"],
        "prog": ["prog", "asp"],
        "cont": ["contem", "asp"],
      }),
    ]),
  )),
  # NOTE: Has automatic, non-controllable final period that we're ignoring.
  # Doesn't have initial caps.
  ("ur-form-adj", (
    "inflection of",
    ("comment", "rename {{__TEMPNAME__}} to {{inflection of|ur|...}}"),
    ("error-if", ("present-except", ["1", "2", "3"])),
    ("set", "1", [
      "ur",
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
  ("ur-form-noun", (
    "inflection of",
    ("comment", "rename {{__TEMPNAME__}} to {{inflection of|ur|...}}"),
    ("error-if", ("present-except", ["1", "2", "3"])),
    ("set", "1", [
      "ur",
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
]

templates_to_rename_map = {}
for template, spec in templates_to_rename_specs:
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
    else:
      raise BadTemplateValue("Unrecognized value %s=%s" % (value[1], lookval))
  else:
    assert False, "Unrecognized directive %s" % direc

def expand_spec(spec, t, pagemsg):
  if callable(spec):
    return expand_spec(spec(t, pagemsg), t, pagemsg)
  assert type(spec) is tuple
  assert len(spec) >= 1
  newname = spec[0]
  expanded_specs = []
  comment = "rename {{%s}} to {{%s}} with appropriate param changes" % (
      tname(t), newname)
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
      comment = comment.replace("__TEMPNAME__", tname(t)).replace("__NEWNAME__", newname)

    else:
      assert False, "Unrecognized directive: %s" % subspec[0]

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
  for i, page in blib.references("Template:%s" % template, start, end):
    blib.do_edit(page, i, process_page, save=args.save, verbose=args.verbose)
