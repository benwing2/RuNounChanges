#!/usr/bin/env python
# -*- coding: utf-8 -*-

import re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site

import rulib as ru

parser = argparse.ArgumentParser(description="Generate adjective stubs.")
parser.add_argument('--direcfile', help="File containing directives.")
args = parser.parse_args()

for line in codecs.open(args.direcfile, "r", "utf-8"):
  line = line.strip()
  els = re.split(r"\s+", line)
  els = [el.replace("_", " ") for el in els]
  adj, etym, short, defns = els[0], els[1], els[2], els[3]
  assert re.search(u"(ый|ий|о́й)$", adj)
  if etym == "-":
    etymtext = "{{rfe|lang=ru}}"
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
    m = re.search(r"^(de|la|en):(.*?)\+(.*)$", etym)
    if m:
      prefix += "{{der|ru|%s|%s}} + " % (m.group(1), m.group(2))
      etym = m.group(3)
    etymtext = "%s{{affix|ru|%s}}%s" % (prefix,
        "|".join(re.split(r"\+", etym)), suffix)

  # Create declension
  short = re.sub(r"\?.*$", "", short) # eliminate uncertainty notations
  if short == "-":
    shorttext = ""
  else:
    shorttext = "|%s" % short
  decltext = "{{ru-decl-adj|%s%s}}" % (adj, shorttext)

  # Create definition
  defnlines = []
  for defn in re.split(";", defns):
    if defn == "-":
      defnlines.append("# {{rfdef|lang=ru}}\n")
    else:
      prefix = ""
      if defn.startswith("+"):
        prefix = "{{lb|ru|attributive}} "
        defn = re.sub(r"^\+", "", defn)
      elif defn.startswith("#"):
        prefix = "{{lb|ru|figurative}} "
        defn = re.sub(r"^#", "", defn)
      elif defn.startswith("!"):
        prefix = "{{lb|ru|colloquial}} "
        defn = re.sub(r"^!", "", defn)
      defnlines.append("# %s%s\n" % (prefix, defn.replace(",", ", ")))
  defntext = "".join(defnlines)

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
  prontext = adj
  for synantrel in els[4:]:
    m = re.search(r"^(syn|ant|der|rel|comp|pron):(.*)", synantrel)
    if not m:
      msg("Element %s doesn't start with syn:, ant:, der:, rel:, comp: or pron:" % synantrel)
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
    else: # derived or related terms
      if vals == "-":
        if sartype == "der":
          dertext = ""
        else:
          reltext = ""
      else:
        lines = []
        for derrelgroup in re.split(",", vals):
          if "/" in derrelgroup:
            impfpfverbs = re.split("/", derrelgroup)
            links = []
            links.append("{{l|ru|%s|g=impf}}" % impfpfverbs[0])
            for pf in impfpfverbs[1:]:
              links.append("{{l|ru|%s|g=pf}}" % impfpfverbs[1])
            lines.append("* %s\n" % ", ".join(links))
          else:
            links = []
            for derrel in re.split(":", derrelgroup):
              links.append("{{l|ru|%s}}" % derrel)
            lines.append("* %s\n" % ", ".join(links))
        derrelguts = "====%s terms====\n%s\n" % (
            "Derived" if sartype == "der" else "Related", "".join(lines))
        if sartype == "der":
          dertext = derrelguts
        else:
          reltext = derrelguts

  msg("""%s

==Russian==

===Etymology===
%s

===Pronunciation===
* {{ru-IPA|%s}}

===Adjective===
{{ru-adj|%s%s}}

%s
====Declension====
%s

%s%s%s%s[[ru:%s]]

""" % (ru.remove_accents(adj), etymtext, prontext, adj, comptext, defntext,
  decltext, syntext, anttext, dertext, reltext, ru.remove_accents(adj)))
