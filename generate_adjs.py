#!/usr/bin/env python
# -*- coding: utf-8 -*-

import re, sys, codecs, argparse

from blib import msg, errmsg
import rulib
import generate_pos

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
  # The first four are special-cased
  "n": "Noun",
  "pn": "Proper noun",
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
  els = [el.replace(r"\s", " ") if i == 2 and (pos in ["n", "pn", "adj"]) else el.replace("_", " ") for i, el in enumerate(els)]
  if pos not in ["n", "pn", "adj"]:
    term, etym, defns = els[0], els[1], els[2]
    remainder = els[3:]
  else:
    term, etym, decl, defns = els[0], els[1], els[2], els[3]
    if decl.startswith("?"):
      error("Declension starts with ?, need to fix: %s" % decl)
    remainder = els[4:]
  translit = None
  declterm = term
  adjrefl = False
  if "//" in term:
    term, translit = re.split("//", term)
  if pos == "adj":
    if term.endswith(u"ся"):
      adjrefl = True
      if "//" in declterm:
        msg("Can't handle reflexive adjectives with manual translit yet")
        assert False
      declterm = re.sub(u"ся$", "", term)
      assert re.search(u"(ый|ий|о́й)$", declterm)
    else:
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
  if pos in ["n", "pn", "adj"]:
    decl = decl.replace("?", "") # eliminate uncertainty notations
    if decl == "-":
      hdecltext = declterm
    elif "..." in decl:
      hdecltext = decl.replace("...", declterm)
    else:
      hdecltext = "%s|%s" % (declterm, decl)
    # hdecltext is the declension as used in the headword template,
    # decltext is the declension as used in the declension template
    hdecltext = "|" + hdecltext
    decltext = hdecltext
    # Eliminate masculine/feminine equiv from actual decl
    decltext = re.sub(r"\|[mf]=[^|]*?(\||$)", r"\1", decltext)
    # Eliminate gender from actual decl
    decltext = re.sub(r"\|g[0-9]*=[^|]*?(\||$)", r"\1", decltext)
    # ru-proper noun+ defaults to n=sg but ru-decl-noun defaults to n=both.
    # The specified declension is for ru-proper noun+ so convert it to work
    # with ru-decl-noun by removing n=both or adding n=sg as necessary.
    if pos == "pn":
      if "|n=both" in hdecltext:
        decltext = decltext.replace("|n=both", "")
      elif "|n=" not in hdecltext:
        decltext = decltext + "|n=sg"

  # Create definition
  if re.search(opt_arg_regex, defns):
    error("Found optional-argument prefix in definition: %s" % defns)
  defntext = generate_pos.generate_defn(defns)

  alsotext = ""
  alttext = ""
  parttext = ""
  syntext = ""
  anttext = ""
  dertext = None
  reltext = None
  seetext = None
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

%s\n\n""" % (term, trtext, "\n".join(infleclines))
      if "adv" in parttype:
        partdecltext = ""
      else:
        partdecltext = """====Declension====
{{ru-decl-adj|%s%s%s}}\n\n""" % (declterm,
          "" if partshort == "-" else "|" + partshort,
          u"|suffix=ся" if adjrefl else "")
      parttext += partdecltext
    else: # derived or related terms or see also
      if ((sartype == "der" and dertext != None) or
          (sartype == "rel" and reltext != None) or
          (sartype == "see" and seetext != None)):
        error("Multiple occurrences of '%s'" % sartype)
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
  dertext = dertext or ""
  seetext = seetext or ""

  if pos == "n":
    maintext = """{{ru-noun+%s}}

%s
====Declension====
{{ru-noun-table%s}}

""" % (hdecltext, defntext, decltext)
  elif pos == "pn":
    maintext = """{{ru-proper noun+%s}}

%s
====Declension====
{{ru-noun-table%s}}

""" % (hdecltext, defntext, decltext)
  elif pos == "adj":
    maintext = """{{ru-adj|%s%s%s}}

%s
====Declension====
{{ru-decl-adj%s%s}}

""" % (term, trtext, comptext, defntext, decltext,
      u"|suffix=ся" if adjrefl else "")
  elif pos == "adv":
    maintext = """{{ru-adv|%s%s}}

%s
""" % (term, trtext, defntext)
  else:
    full_pos = pos_to_full_pos[pos]
    maintext = """{{head|ru|%s|head=%s%s}}

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
%s===%s===
%s%s%s%s%s%s[[ru:%s]]

""" % (rulib.remove_accents(term), alsotext, alttext, etymtext, prontext,
  parttext, pos_to_full_pos[pos], maintext, syntext, anttext, dertext,
  reltext, seetext, rulib.remove_accents(term)))
