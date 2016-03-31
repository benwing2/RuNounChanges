#!/usr/bin/env python
# -*- coding: utf-8 -*-

import re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site

import rulib as ru

parser = argparse.ArgumentParser(description="Generate verb stubs for class-1a verbs.")
parser.add_argument('--direcfile', help="File containing pages to fix.")
args = parser.parse_args()

for line in codecs.open(args.direcfile, "r", "utf-8"):
  line = line.strip()
  els = re.split(r"\s+", line)
  verb, etym, aspect, corverbs, conj = els[0], els[1], els[2], els[3], els[4]
  assert re.search(u"(ть(ся)?|ти́?(сь)?|чь(ся)?)$", verb)
  isrefl = re.search(u"(ся|сь)$", verb)
  if etym == "-":
    etymtext = "{{rfe|lang=ru}}"
  elif etym == "r":
    assert isrefl
    etymtext = re.sub(u"^(.*?)(ся|сь)$", r"{{affix|ru|\1|-\2}}", verb)
  elif etym.startswith("?"):
    etymtext = "Probably {{affix|ru|%s}}." % "|".join(re.split(r"\+",
      re.sub(r"^\?", "", etym)))
  else:
    etymtext = "{{affix|ru|%s}}" % "|".join(re.split(r"\+", etym))
  headword_aspect = re.sub("-.*", "", aspect)
  assert headword_aspect in ["pf", "impf"]
  corverbtext = ""
  if corverbs != "-":
    corverbno = 1
    for corverb in re.split(",", corverbs):
      corverbtext += "|%s%s=%s" % (
          "pf" if headword_aspect == "impf" else "impf",
          "" if corverbno == 1 else str(corverbno), corverb)
      corverbno += 1
  verbbase = re.sub(u"(ся|сь)$", "", verb)
  passivetext = ("\n# {{passive of|lang=ru|%s}}" % verbbase
      if etym == "r" else "")
  if conj.startswith("4a"):
    assert verbbase.endswith(u"ить")
    conjargs = re.sub(u"ить", "", verbbase)
  elif conj.startswith("4b"):
    assert verbbase.endswith(u"и́ть")
    conjargs = re.sub(u"и́ть", "", verbbase)
  elif conj.startswith("4c"):
    assert verbbase.endswith(u"и́ть")
    conjargs = ru.make_ending_stressed(re.sub(u"и́ть", "", verbbase))
  elif conj.startswith("1a"):
    conjargs = re.sub(u"ть$", "", verbbase)
  else:
    conjargs = re.sub(r"^.*?\|", "", conj)
    conj = re.sub(r"\|.*$", "", conj)
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
    m = re.search(r"^(syn|ant|der|rel):(.*)", synantrel)
    if not m:
      msg("Element %s doesn't start with syn:, ant:, der: or rel:" % synantrel)
    assert m
    sartype, vals = m.groups()
    if sartype in ["syn", "ant"]:
      lines = []
      for synantgroup in re.split(";", vals):
        sensetext = ""
        if synantgroup.startswith("*"):
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
    else: # derived or related terms
      lines = []
      for derrelgroup in re.split(",", vals):
        if "/" in derrelgroup:
          impf, pf = re.split("/", derrelgroup)
          lines.append("* {{l|ru|%s|g=impf}}, {{l|ru|%s|g=pf}}\n" % (impf, pf))
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

===Verb===
{{ru-verb|%s|%s%s}}

# {{rfdef|lang=ru}}%s

====Conjugation====
{{ru-conj|%s|%s%s|%s}}

%s%s%s%s[[ru:%s]]

""" % (ru.remove_accents(verb), etymtext, verb, verb, headword_aspect,
  corverbtext, passivetext, conj, aspect, "-refl" if isrefl else "", conjargs,
  syntext, anttext, dertext, reltext, ru.remove_accents(verb)))
