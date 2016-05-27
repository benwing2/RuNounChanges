#!/usr/bin/env python
# -*- coding: utf-8 -*-

import re, sys, codecs, argparse

from blib import msg
import rulib

parser = argparse.ArgumentParser(description="Generate adjective stubs.")
parser.add_argument('--direcfile', help="File containing directives.")
parser.add_argument('--adverb', action="store_true",
    help="Directive file contains adverbs instead of adjectives.")
args = parser.parse_args()

def check_stress(word):
  word = re.sub(r"|.*", "", word)
  if word.startswith("-") or word.endswith("-"):
    # Allow unstressed prefix (e.g. разо-) and unstressed suffix (e.g. -овать)
    return
  if rulib.needs_accents(word, split_dash=True):
    msg("Word %s missing an accent" % word)
    assert False

for line in codecs.open(args.direcfile, "r", "utf-8"):
  line = line.strip()
  els = re.split(r"\s+", line)
  isadv = args.adverb
  # Replace _ with space, but not in the short form, where there may be
  # an underscore, e.g. a|short_m=-
  els = [el if i == 2 and not isadv else el.replace("_", " ") for i, el in enumerate(els)]
  if isadv:
    term, etym, defns = els[0], els[1], els[2]
    remainder = els[3:]
  else:
    term, etym, short, defns = els[0], els[1], els[2], els[3]
    if short.startswith("?"):
      msg("Short adjective declension starts with ?, need to fix: %s" % short)
      assert False
    remainder = els[4:]
  translit = None
  declterm = term
  if "//" in term:
    term, translit = re.split("//", term)
  if not isadv:
    assert re.search(u"(ый|ий|о́й)$", term)
  trtext = translit and "|tr=" + translit or ""
  check_stress(term)
  if etym == "-":
    etymtext = "===Etymology===\n{{rfe|lang=ru}}\n\n"
  elif etym == "--":
    etymtext = ""
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
    etymtext = "===Etymology===\n%s{{affix|ru|%s%s}}%s\n\n" % (prefix,
        "|".join(re.split(r"\+", etym)), langtext, suffix)

  # Create declension
  if not isadv:
    short = re.sub(r"\?.*$", "", short) # eliminate uncertainty notations
    if short == "-":
      shorttext = ""
    else:
      shorttext = "|%s" % short
    decltext = "{{ru-decl-adj|%s%s}}" % (declterm, shorttext)

  # Create definition
  defnlines = []
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
        defnline = "{{diminutive of|lang=ru|%s}}" % (
            re.sub("^dim:", "", defn))
      else:
        defnline = defn.replace(",", ", ")
      defnlines.append("# %s%s\n" % (prefix, defnline))
  defntext = "".join(defnlines)

  alttext = ""
  parttext = ""
  syntext = ""
  anttext = ""
  dertext = ""
  reltext = """====Related terms====
* {{l|ru|}}
* {{l|ru|}}
* {{l|ru|}}
* {{l|ru|}}
* {{l|ru|}}
* {{l|ru|}}

"""
  comptext = ""
  prontext = term
  for synantrel in remainder:
    m = re.search(r"^(syn|ant|der|rel|comp|pron|alt|part):(.*)", synantrel)
    if not m:
      msg("Element %s doesn't start with syn:, ant:, der:, rel:, comp:, pron:, alt: or part:" % synantrel)
    assert m
    sartype, vals = m.groups()
    if sartype in ["syn", "ant"]:
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
      check_stress(vals)
      prontext = "%s" % vals
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
    else: # derived or related terms
      if vals == "-":
        if sartype == "der":
          dertext = ""
        else:
          reltext = ""
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
        derrelguts = "====%s terms====\n%s\n" % (
            "Derived" if sartype == "der" else "Related", "".join(lines))
        if sartype == "der":
          dertext = derrelguts
        else:
          reltext = derrelguts

  if isadv:
    maintext = """===Adverb===
{{ru-adv|%s%s}}

%s
""" % (term, trtext, defntext)
  else:
    maintext = """===Adjective===
{{ru-adj|%s%s%s}}

%s
====Declension====
%s

""" % (term, trtext, comptext, defntext, decltext)
  if defns == "--":
    maintext = ""

  # If both adjective and participle header, move related-terms text to level 3
  if maintext and parttext and reltext:
    reltext = re.sub("^====Related terms====", "===Related terms===", reltext)

  msg("""%s

==Russian==

%s%s===Pronunciation===
* {{ru-IPA|%s}}

%s%s%s%s%s%s[[ru:%s]]

""" % (rulib.remove_accents(term), alttext, etymtext, prontext, parttext,
  maintext, syntext, anttext, dertext, reltext, rulib.remove_accents(term)))
