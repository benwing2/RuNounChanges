#!/usr/bin/env python
# -*- coding: utf-8 -*-

import re, sys, codecs, argparse

from blib import msg, errmsg
import rulib

parser = argparse.ArgumentParser(description="Generate adjective stubs.")
parser.add_argument('--direcfile', help="File containing directives.")
parser.add_argument('--pos', action="store_true",
    help="First field is part of speech (n, adj, adv, pcl, pred, prep, conj, int).")
parser.add_argument('--adverb', action="store_true",
    help="Directive file contains adverbs instead of adjectives.")
parser.add_argument('--noun', action="store_true",
    help="Directive file contains nouns instead of adjectives.")
args = parser.parse_args()

pos_to_full_pos = {
  # The first three are special-cased
  "n": "Noun",
  "adj": "Adjective",
  "adv": "Adverb",
  "pcl": "Particle",
  "pred": "Predicative",
  "prep": "Preposition",
  "conj": "Conjunction",
  "int": "Interjection"
}

opt_arg_regex = r"^(also|syn|ant|der|rel|see|comp|pron|alt|part):(.*)"

# Form for adjectives and nouns:
#
# TERM ETYM DECL DEF ...
#
# where DECL can have ... to represent position of term in it (otherwise,
# the declension is placed after the term, separated by a vertical bar).
# (For adjectives, DECL is used for the short adjective declension.)
#
# Form for adverbs:
#
# TERM ETYM DEF ...

for line in codecs.open(args.direcfile, "r", "utf-8"):

  def error(text):
    errmsg("ERROR: Processing line: %s" % line)
    errmsg("ERROR: %s" % text)
    assert False

  def check_stress(word):
    word = re.sub(r"|.*", "", word)
    if word.startswith("-") or word.endswith("-"):
      # Allow unstressed prefix (e.g. разо-) and unstressed suffix (e.g. -овать)
      return
    if rulib.needs_accents(word, split_dash=True):
      error("Word %s missing an accent" % word)

  line = line.strip()
  els = re.split(r"\s+", line)
  if args.pos:
    pos = els[0]
    assert pos in pos_to_full_pos
    del els[0]
  else:
    if args.adverb:
      pos = "adv"
    elif args.noun:
      pos = "n"
    else:
      pos = "adj"
  # Replace _ with space, but not in the declension, where there may be
  # an underscore, e.g. a|short_m=-; but allow \s to stand for a space in
  # the declension
  els = [el.replace(r"\s", " ") if i == 2 and (pos == "n" or pos == "adj") else el.replace("_", " ") for i, el in enumerate(els)]
  if pos != "n" and pos != "adj":
    term, etym, defns = els[0], els[1], els[2]
    remainder = els[3:]
  else:
    term, etym, decl, defns = els[0], els[1], els[2], els[3]
    if decl.startswith("?"):
      error("Declension starts with ?, need to fix: %s: Processing line: %s" % decl)
    remainder = els[4:]
  translit = None
  declterm = term
  if "//" in term:
    term, translit = re.split("//", term)
  if pos == "adj":
    assert re.search(u"(ый|ий|о́й)$", term)
  trtext = translit and "|tr=" + translit or ""
  check_stress(term)
  if etym == "?":
    error("Etymology consists of bare question mark")
  elif etym == "-":
    etymtext = "===Etymology===\n{{rfe|lang=ru}}\n\n"
  elif etym == "--":
    etymtext = ""
  else:
    m = re.search(r"^s([mfnp]):(.*)", etym)
    if m:
      gender = {"m":"masculine", "f":"feminine", "n":"neuter", "p":"plural"}
      etymtext = "Substantivized %s of {{m|ru|%s}}." % (gender[m.group(1)],
          m.group(2))
    elif ":" in etym and "+" not in etym:
      prefix = ""
      if etym.startswith("?"):
        prefix = "Perhaps borrowed from "
        etym = re.sub(r"^\?", "", etym)
      elif etym.startswith("<<"):
        prefix = "Ultimately borrowed from "
        etym = re.sub(r"^<<", "", etym)
      m = re.search(r"^([a-zA-Z.-]+):(.*)", etym)
      if not m:
        error("Bad etymology form: %s" % etym)
      etymtext = "%s{{bor|ru|%s|%s%s}}." % (prefix, m.group(1), m.group(2),
          prefix and "|notext=1" or "")
    else:
      prefix = ""
      suffix = ""
      if etym.startswith("?"):
        prefix = "Perhaps from "
        suffix = "."
        etym = re.sub(r"^\?", "", etym)
      elif etym.startswith("<<"):
        prefix = "Ultimately from "
        suffix = "."
        etym = re.sub(r"^<<", "", etym)
      m = re.search(r"^([a-zA-Z.-]+):(.*)", etym)
      if m:
        langtext = "|lang1=%s" % m.group(1)
        etym = m.group(2)
      else:
        langtext = ""
      etymtext = "%s{{affix|ru|%s%s}}%s" % (prefix,
          "|".join(re.split(r"\+", etym)), langtext, suffix)
    etymtext = "===Etymology===\n%s\n\n" % etymtext

  # Create declension
  if pos == "n" or pos == "adj":
    decl = decl.replace("?", "") # eliminate uncertainty notations
    if decl == "-":
      decltext = declterm
    elif "..." in decl:
      decltext = decl.replace("...", declterm)
    else:
      decltext = "%s|%s" % (declterm, decl)

  # Create definition
  defnlines = []
  if re.search(opt_arg_regex, defns):
    error("Found optional-argument prefix in definition: %s" % defns)
  # the following regex uses a negative lookbehind so we split on a semicolon
  # but not on a backslashed semicolon, which we then replace with a regular
  # semicolon in the next line
  for defn in re.split(r"(?<![\\]);", defns):
    defn = defn.replace(r"\;", ";")
    if defn == "-":
      defnlines.append("# {{rfdef|lang=ru}}\n")
    elif defn.startswith("ux:"):
      defnlines.append("#: {{ru-ux|%s|inline=y}}\n" % (
        re.sub("^ux:", "", defn)))
    else:
      labels = []
      prefix = ""
      while True:
        if defn.startswith("+"):
          labels.append("attributive")
          defn = re.sub(r"^\+", "", defn)
        elif defn.startswith("#"):
          labels.append("figurative")
          defn = re.sub(r"^#", "", defn)
        elif defn.startswith("(f)"):
          labels.append("figurative")
          defn = re.sub(r"^\(f\)", "", defn)
        elif defn.startswith("(d)"):
          labels.append("dated")
          defn = re.sub(r"^\(d\)", "", defn)
        elif defn.startswith("(p)"):
          labels.append("poetic")
          defn = re.sub(r"^\(p\)", "", defn)
        elif defn.startswith("(n)"):
          labels.append("nonstandard")
          defn = re.sub(r"^\(n\)", "", defn)
        elif defn.startswith("(v)"):
          labels.append("vernacular")
          defn = re.sub(r"^\(v\)", "", defn)
        elif defn.startswith("!"):
          labels.append("colloquial")
          defn = re.sub(r"^!", "", defn)
        elif defn.startswith("(c)"):
          labels.append("colloquial")
          defn = re.sub(r"^\(c\)", "", defn)
        elif defn.startswith("(l)"):
          labels.append("literary")
          defn = re.sub(r"^\(l\)", "", defn)
        else:
          break
      if labels:
        prefix = "{{lb|ru|%s}} " % "|".join(labels)
      if defn.startswith("altof:"):
        defnline = "{{alternative form of|lang=ru|%s}}" % (
            re.sub("^altof:", "", defn))
      elif defn.startswith("dim:"):
        dimparts = re.split(":", defn)
        assert len(dimparts) in [2, 3]
        defnline = "{{diminutive of|lang=ru|%s}}" % dimparts[1]
        if len(dimparts) == 3:
          defnline = "%s: %s" % (defnline, dimparts[2])
      else:
        defnline = defn.replace(",", ", ")
      defnlines.append("# %s%s\n" % (prefix, defnline))
  defntext = "".join(defnlines)

  alsotext = ""
  alttext = ""
  parttext = ""
  syntext = ""
  anttext = ""
  dertext = ""
  reltext = None
  seetext = ""
  comptext = ""
  prontext = "* {{ru-IPA|%s}}\n" % term
  for synantrel in remainder:
    m = re.search(opt_arg_regex, synantrel)
    if not m:
      error("Element %s doesn't start with also:, syn:, ant:, der:, rel:, see:, comp:, pron:, alt: or part:" % synantrel)
    sartype, vals = m.groups()
    if sartype == "also":
      alsotext = "{{also|%s}}\n" % vals.replace(",", "|")
    elif sartype in ["syn", "ant"]:
      lines = []
      for synantgroup in re.split(";", vals):
        sensetext = ""
        if synantgroup.startswith("*("):
          m = re.search(r"^\*\((.*?)\)(.*)$", synantgroup)
          sensetext = "{{sense|%s}} " % m.group(1)
          synantgroup = m.group(2)
        elif synantgroup.startswith("*"):
          sensetext = "{{sense|FIXME}} "
          synantgroup = re.sub(r"\*", "", synantgroup)
        else:
          sensetext = ""
        links = []
        for synant in re.split(",", synantgroup):
          check_stress(synant)
          links.append("{{l|ru|%s}}" % synant)
        lines.append("* %s%s\n" % (sensetext, ", ".join(links)))
      synantguts = "====%s====\n%s\n" % (
          "Synonyms" if sartype == "syn" else "Antonyms",
          "".join(lines))
      if sartype == "syn":
        syntext = synantguts
      else:
        anttext = synantguts
    elif sartype == "comp":
      comptext = ""
      for i, comp in enumerate(re.split(",", vals)):
        check_stress(comp)
        if i == 0:
          comptext += "|%s" % comp
        else:
          comptext += "|comp%s=%s" % (i + 1, comp)
    elif sartype == "pron":
      prontext = ""
      check_stress(vals)
      for i, pron in enumerate(re.split(",", vals)):
        check_stress(pron)
        prontext += "* {{ru-IPA|%s}}\n" % pron
    elif sartype == "alt":
      lines = []
      for altform in re.split(",", vals):
        check_stress(altform)
        lines.append("* {{l|ru|%s}}\n" % altform)
      alttext = "===Alternative forms===\n%s\n" % "".join(lines)
    elif sartype == "part":
      verbs, parttypes, partshort = re.split(":", vals)
      infleclines = []
      for verb in re.split(",", verbs):
        for parttype in re.split(",", parttypes):
          infleclines.append("# {{ru-participle of|%s||%s}}" % (verb, parttype))
      parttext = """===Participle===
{{head|ru|participle|head=%s%s}}

%s

====Declension====
{{ru-decl-adj|%s%s}}\n\n""" % (term, trtext, "\n".join(infleclines), declterm,
    "" if partshort == "-" else "|" + partshort)
    else: # derived or related terms or see also
      if vals == "-":
        if sartype == "der":
          dertext = ""
        elif sartype == "rel":
          reltext = ""
        else:
          seetext = ""
      else:
        lines = []
        for derrelgroup in re.split(",", vals):
          links = []
          for derrel in re.split(":", derrelgroup):
            if "/" in derrel:
              impfpfverbs = re.split("/", derrel)
              for impfpfverb in impfpfverbs:
                check_stress(impfpfverb)
              if "|" in impfpfverbs[0]:
                links.append("{{l|ru|%s}}" % impfpfverbs[0])
              else:
                links.append("{{l|ru|%s|g=impf}}" % impfpfverbs[0])
              for pf in impfpfverbs[1:]:
                if "|" in pf:
                  links.append("{{l|ru|%s}}" % pf)
                else:
                  links.append("{{l|ru|%s|g=pf}}" % pf)
            else:
              check_stress(derrel)
              links.append("{{l|ru|%s}}" % derrel)
          lines.append("* %s\n" % ", ".join(links))
        derrelguts = "====%s====\n%s\n" % (
            "Derived terms" if sartype == "der" else
            "Related terms" if sartype == "rel" else "See also", "".join(lines))
        if sartype == "der":
          dertext = derrelguts
        elif sartype == "rel":
          reltext = derrelguts
        else:
          seetext = derrelguts

  if reltext == None:
    error("No related terms; should specify some or use rel:- to disable them")

  if pos == "n":
    maintext = """===Noun===
{{ru-noun+|%s}}

%s
====Declension====
{{ru-noun-table|%s}}

""" % (decltext, defntext, decltext)
  elif pos == "adj":
    maintext = """===Adjective===
{{ru-adj|%s%s%s}}

%s
====Declension====
{{ru-decl-adj|%s}}

""" % (term, trtext, comptext, defntext, decltext)
  elif pos == "adv":
    maintext = """===Adverb===
{{ru-adv|%s%s}}

%s
""" % (term, trtext, defntext)
  else:
    full_pos = pos_to_full_pos[pos]
    maintext = """===%s===
{{head|ru|%s|head=%s%s}}

%s
""" % (full_pos, full_pos.lower(), term, trtext, defntext)

  if defns == "--":
    maintext = ""

  # If both adjective and participle header, move related-terms text to level 3
  if maintext and parttext and reltext:
    reltext = re.sub("^====Related terms====", "===Related terms===", reltext)

  msg("""%s

%s==Russian==

%s%s===Pronunciation===
%s
%s%s%s%s%s%s%s[[ru:%s]]

""" % (rulib.remove_accents(term), alsotext, alttext, etymtext, prontext,
  parttext, maintext, syntext, anttext, dertext, reltext, seetext,
  rulib.remove_accents(term)))
