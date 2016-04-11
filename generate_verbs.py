#!/usr/bin/env python
# -*- coding: utf-8 -*-

import re, sys, codecs, argparse

from blib import msg
import rulib as ru

parser = argparse.ArgumentParser(description="Generate verb stubs.")
parser.add_argument('--direcfile', help="File containing directives.")
args = parser.parse_args()

for line in codecs.open(args.direcfile, "r", "utf-8"):
  line = line.strip()
  els = re.split(r"\s+", line)
  # Replace _ with space, but not in the conjugation, where param names
  # may well have an underscore in them
  els = [el if i == 4 else el.replace("_", " ") for i, el in enumerate(els)]
  verb, etym, aspect, corverbs, conj = els[0], els[1], els[2], els[3], els[4]
  assert re.search(u"(ть(ся)?|ти́?(сь)?|чь(ся)?)$", verb)
  isrefl = re.search(u"(ся|сь)$", verb)
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
    if etym == "r":
      assert isrefl
      etymtext = re.sub(u"^(.*?)(ся|сь)$", r"{{affix|ru|\1|-\2}}", verb)
    else:
      m = re.search(r"^(de|la|en):(.*?)\+(.*)$", etym)
      if m:
        prefix += "{{der|ru|%s|%s}} + " % (m.group(1), m.group(2))
        etym = m.group(3)
      etymtext = "%s{{affix|ru|%s}}%s" % (prefix,
          "|".join(re.split(r"\+", etym)), suffix)
  headword_aspect = re.sub("-.*", "", aspect)
  assert headword_aspect in ["pf", "impf", "both"]
  corverbtext = ""
  if corverbs != "-":
    corverbno = 1
    for corverb in re.split(",", corverbs):
      corverbtext += "|%s%s=%s" % (
          "impf" if headword_aspect == "pf" else "pf",
          "" if corverbno == 1 else str(corverbno), corverb)
      corverbno += 1
  verbbase = re.sub(u"(ся|сь)$", "", verb)
  passivetext = ("\n# {{passive of|lang=ru|%s}}" % verbbase
      if etym == "r" else "")

  if "|" not in conj:
    if conj.startswith("4a"):
      assert verbbase.endswith(u"ить")
      conjargs = re.sub(u"ить", "", verbbase)
    elif conj.startswith("4b"):
      assert verbbase.endswith(u"и́ть")
      conjargs = re.sub(u"и́ть", "", verbbase)
    elif conj.startswith("4c"):
      assert verbbase.endswith(u"и́ть")
      conjargs = ru.make_ending_stressed(re.sub(u"и́ть", "", verbbase))
    elif conj.startswith("3a") or conj.startswith(u"3°a") or conj.startswith("3oa"):
      assert verbbase.endswith(u"нуть")
      conjargs = re.sub(u"нуть$", "", verbbase)
    elif conj.startswith("3b"):
      assert verbbase.endswith(u"ну́ть")
      conjargs = re.sub(u"у́ть$", "", verbbase)
    elif conj.startswith("3c"):
      assert verbbase.endswith(u"ну́ть")
      conjargs = ru.make_ending_stressed(re.sub(u"у́ть", "", verbbase))
    elif conj.startswith("2a") or conj.startswith("2b"):
      assert re.search(u"ва́?ть$", verbbase)
      conjargs = re.sub(u"ть$", "", verbbase)
    elif conj.startswith("1a"):
      conjargs = re.sub(u"ть$", "", verbbase)
    else:
      msg("Unrecognized conjugation type and no arguments: %s" % conj)
      assert False
  else:
    conjargs = re.sub(r"^.*?\|", "", conj)
    conj = re.sub(r"\|.*$", "", conj)
  reflsuf = "-refl" if isrefl else ""
  if aspect == "both":
    conjtext = """''imperfective''
{{ru-conj|%s|impf%s|%s}}
''perfective''
{{ru-conj|%s|pf%s|%s}}""" % (conj, reflsuf, conjargs, conj, reflsuf, conjargs)
  else:
    conjtext = "{{ru-conj|%s|%s%s|%s}}" % (conj, aspect, reflsuf, conjargs)

  alttext = ""
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
  for synantrel in els[5:]:
    m = re.search(r"^(syn|ant|der|rel|alt):(.*)", synantrel)
    if not m:
      msg("Element %s doesn't start with syn:, ant:, der: or rel:" % synantrel)
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
    elif sartype == "alt":
      lines = []
      for altform in re.split(",", vals):
        lines.append("* {{l|ru|%s}}\n" % altform)
      alttext = "===Alternative forms===\n%s\n" % "".join(lines)
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
              links.append("{{l|ru|%s|g=impf}}" % impfpfverbs[0])
              for pf in impfpfverbs[1:]:
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

  msg("""%s

==Russian==

%s===Etymology===
%s

===Pronunciation===
* {{ru-IPA|%s}}

===Verb===
{{ru-verb|%s|%s%s}}

# {{rfdef|lang=ru}}%s

====Conjugation====
%s

%s%s%s%s[[ru:%s]]

""" % (ru.remove_accents(verb), alttext, etymtext, verb, verb, headword_aspect,
  corverbtext, passivetext, conjtext, syntext, anttext, dertext, reltext,
  ru.remove_accents(verb)))
