#!/usr/bin/env python
# -*- coding: utf-8 -*-

import re, sys, codecs, argparse

from blib import msg
import rulib as ru

parser = argparse.ArgumentParser(description="Generate adjective stubs.")
parser.add_argument('--direcfile', help="File containing directives.")
parser.add_argument('--adverb', action="store_true",
    help="Directive file contains adverbs instead of adjectives.")
args = parser.parse_args()

for line in codecs.open(args.direcfile, "r", "utf-8"):
  line = line.strip()
  els = re.split(r"\s+", line)
  els = [el.replace("_", " ") for el in els]
  isadv = args.adverb
  if isadv:
    term, etym, defns = els[0], els[1], els[2]
    remainder = els[3:]
  else:
    term, etym, short, defns = els[0], els[1], els[2], els[3]
    remainder = els[4:]
    assert re.search(u"(ый|ий|о́й)$", term)
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
    m = re.search(r"^(de|fr|la|en):(.*?)\+(.*)$", etym)
    if m:
      prefix += "{{der|ru|%s|%s}} + " % (m.group(1), m.group(2))
      etym = m.group(3)
    etymtext = "===Etymology===\n%s{{affix|ru|%s}}%s\n\n" % (prefix,
        "|".join(re.split(r"\+", etym)), suffix)

  # Create declension
  if not isadv:
    short = re.sub(r"\?.*$", "", short) # eliminate uncertainty notations
    if short == "-":
      shorttext = ""
    else:
      shorttext = "|%s" % short
    decltext = "{{ru-decl-adj|%s%s}}" % (term, shorttext)

  # Create definition
  defnlines = []
  for defn in re.split(";", defns):
    if defn == "-":
      defnlines.append("# {{rfdef|lang=ru}}\n")
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
        elif defn.startswith("!"):
          labels.append("colloquial")
          defn = re.sub(r"^!", "", defn)
        else:
          break
      if labels:
        prefix = "{{lb|ru|%s}} " % "|".join(labels)
      if defn.startswith("altof:"):
        defnline = "{{alternative form of|lang=ru|%s}}" % (
            re.sub("^altof:", "", defn))
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
      comptext = "|%s" % vals
    elif sartype == "pron":
      prontext = "%s" % vals
    elif sartype == "alt":
      lines = []
      for altform in re.split(",", vals):
        lines.append("* {{l|ru|%s}}\n" % altform)
      alttext = "===Alternative forms===\n%s\n" % "".join(lines)
    elif sartype == "part":
      verbs, parttypes, partshort = re.split(":", vals)
      infleclines = []
      for verb in re.split(",", verbs):
        for parttype in re.split(",", parttypes):
          infleclines.append("# {{ru-participle of|%s||%s}}" % (verb, parttype))
      parttext = """===Participle===
{{head|ru|participle|head=%s}}

%s

====Declension====
{{ru-decl-adj|%s%s}}\n\n""" % (term, "\n".join(infleclines), term,
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
              links.append("{{l|ru|%s}}" % derrel)
          lines.append("* %s\n" % ", ".join(links))
        derrelguts = "====%s terms====\n%s\n" % (
            "Derived" if sartype == "der" else "Related", "".join(lines))
        if sartype == "der":
          dertext = derrelguts
        else:
          reltext = derrelguts

  if isadv:
    msg("""%s

==Russian==

%s%s===Pronunciation===
* {{ru-IPA|%s}}

===Adverb===
{{ru-adv|%s}}

%s
%s%s%s%s[[ru:%s]]

""" % (ru.remove_accents(term), alttext, etymtext, prontext, term,
    defntext, syntext, anttext, dertext, reltext,
    ru.remove_accents(term)))
  else:
    msg("""%s

==Russian==

%s%s===Pronunciation===
* {{ru-IPA|%s}}

%s===Adjective===
{{ru-adj|%s%s}}

%s
====Declension====
%s

%s%s%s%s[[ru:%s]]

""" % (ru.remove_accents(term), alttext, etymtext, prontext, parttext, term,
    comptext, defntext, decltext, syntext, anttext, dertext, reltext,
    ru.remove_accents(term)))
