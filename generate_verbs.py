#!/usr/bin/env python
# -*- coding: utf-8 -*-

import re, sys, codecs, argparse

from blib import msg, errmsg
import rulib
import generate_pos

parser = argparse.ArgumentParser(description="Generate verb stubs.")
parser.add_argument('--reqdef', help="Require a definition.", action="store_true")
parser.add_argument('--direcfile', help="File containing directives.")
args = parser.parse_args()

def check_stress(word):
  word = re.sub(r"|.*", "", word)
  if word.startswith("-") or word.endswith("-"):
    # Allow unstressed prefix (e.g. разо-) and unstressed suffix (e.g. -овать)
    return
  if rulib.needs_accents(word):
    msg("Word %s missing an accent" % word)
    assert False

for line in codecs.open(args.direcfile, "r", "utf-8"):
  def error(text):
    errmsg("ERROR: Processing line: %s" % line)
    errmsg("ERROR: %s" % text)
    assert False

  line = line.strip()
  els = re.split(r"\s+", line)
  # Replace _ with space, but not in the conjugation, where param names
  # may well have an underscore in them; but allow \s to stand for a space in
  # the conjugation, and \u to stand for an underscore elsewhere.
  els = [el.replace(r"\s", " ") if i == 4 else el.replace("_", " ").replace(r"\u", "_") for i, el in enumerate(els)]
  verb, etym, aspect, corverbs, conj = els[0], els[1], els[2], els[3], els[4]
  assert re.search(u"(ть(ся)?|ти́?(сь)?|чь(ся)?)$", verb)
  check_stress(verb)
  isrefl = re.search(u"(ся|сь)$", verb)
  if etym == "?":
    error("Etymology consists of bare question mark")
  elif etym == "-":
    etymtext = "===Etymology===\n{{rfe|lang=ru}}\n\n"
  elif etym == "--":
    etymtext = ""
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
      m = re.search(r"^([a-z-]+):(.*)", etym)
      if m:
        langtext = "|lang1=%s" % m.group(1)
        etym = m.group(2)
      else:
        langtext = ""
      etymtext = "%s{{affix|ru|%s%s}}%s" % (prefix,
          "|".join(re.split(r"\+", etym)), langtext, suffix)
  headword_aspect = re.sub("-.*", "", aspect)
  assert headword_aspect in ["pf", "impf", "both"]
  if corverbs == "-":
    corverbs = []
  else:
    corverbs = re.split(",", corverbs)
  corverbtext = ""
  corverbno = 1
  for corverb in corverbs:
    if "?" in corverb:
      error("? in corresponding aspect-pair verb '%s'" % corverb)
    check_stress(corverb)
    corverbtext += "|%s%s=%s" % (
        "impf" if headword_aspect == "pf" else "pf",
        "" if corverbno == 1 else str(corverbno), corverb)
    corverbno += 1
  verbbase = re.sub(u"(ся|сь)$", "", verb)
  passivetext = ("# {{passive of|lang=ru|%s}}\n" % verbbase
      if etym == "r" else "")

  if "|" not in conj:
    if conj.startswith("6a") or conj.startswith(u"6°a") or conj.startswith("6oa"):
      assert re.search(u"[ая]ть$", verbbase)
      conjargs = re.sub(u"[ая]ть$", "", verbbase)
    elif conj.startswith("6b") or conj.startswith(u"6°b") or conj.startswith("6ob"):
      assert rulib.is_monosyllabic(verbbase) or re.search(u"[ая]́ть$", verbbase)
      conjargs = re.sub(u"[ая]́?ть$", "", verbbase)
    elif conj.startswith("6c") or conj.startswith(u"6°c") or conj.startswith("6oc"):
      assert rulib.is_monosyllabic(verbbase) or re.search(u"[ая]́ть$", verbbase)
      conjargs = rulib.make_ending_stressed(re.sub(u"[ая]́?ть$", "", verbbase))
    elif conj.startswith("5a"):
      assert re.search(u"[еая]ть$", verbbase)
      conjargs = "%s|%s" % (re.sub(u"[еая]ть$", "", verbbase),
          rulib.try_to_stress(re.sub(u"ть$", "", verbbase)))
    elif conj.startswith("5b"):
      assert rulib.is_monosyllabic(verbbase) or re.search(u"[еая]́ть$", verbbase)
      conjargs = "%s|%s" % (re.sub(u"[еая]́?ть$", "", verbbase),
          re.sub(u"ть$", "", verbbase))
    elif conj.startswith("5c"):
      assert rulib.is_monosyllabic(verbbase) or re.search(u"[еая]́ть$", verbbase)
      conjargs = "%s|%s" % (rulib.make_ending_stressed(re.sub(u"[еая]́?ть$", "", verbbase)),
          rulib.try_to_stress(re.sub(u"ть$", "", verbbase)))
    elif conj.startswith("4a"):
      assert verbbase.endswith(u"ить")
      conjargs = re.sub(u"ить", "", verbbase)
    elif conj.startswith("4b"):
      assert rulib.is_monosyllabic(verbbase) or verbbase.endswith(u"и́ть")
      conjargs = re.sub(u"и́?ть", "", verbbase)
    elif conj.startswith("4c"):
      assert rulib.is_monosyllabic(verbbase) or verbbase.endswith(u"и́ть")
      conjargs = rulib.make_ending_stressed(re.sub(u"и́?ть", "", verbbase))
    elif conj.startswith("3a") or conj.startswith(u"3°a") or conj.startswith("3oa"):
      assert verbbase.endswith(u"нуть")
      conjargs = re.sub(u"нуть$", "", verbbase)
    elif conj.startswith("3b"):
      assert rulib.is_monosyllabic(verbbase) or verbbase.endswith(u"ну́ть")
      conjargs = re.sub(u"у́?ть$", "", verbbase)
    elif conj.startswith("3c"):
      assert rulib.is_monosyllabic(verbbase) or verbbase.endswith(u"ну́ть")
      conjargs = rulib.make_ending_stressed(re.sub(u"у́?ть", "", verbbase))
    elif conj.startswith("2a") or conj.startswith("2b"):
      assert re.search(u"ва́?ть$", verbbase)
      conjargs = re.sub(u"ть$", "", verbbase)
    elif conj.startswith("1a"):
      conjargs = rulib.try_to_stress(re.sub(u"ть$", "", verbbase))
    else:
      msg("Unrecognized conjugation type and no arguments: %s" % conj)
      assert False
  else:
    conjargs = re.sub(r"^.*?\|", "", conj)
    conj = re.sub(r"\|.*$", "", conj)
  reflsuf = "-refl" if isrefl else ""
  if aspect.startswith("both"):
    pfaspect = re.sub("^both", "pf", aspect)
    impfaspect = re.sub("^both", "impf", aspect)
    conjtext = """''imperfective''
{{ru-conj|%s|%s%s|%s}}
''perfective''
{{ru-conj|%s|%s%s|%s}}""" % (conj, impfaspect, reflsuf, conjargs,
    conj, pfaspect, reflsuf, conjargs)
  else:
    conjtext = "{{ru-conj|%s|%s%s|%s}}" % (conj, aspect, reflsuf, conjargs)

  alttext = ""
  syntext = ""
  anttext = ""
  dertext = ""
  reltext = None
  seetext = ""
  prontext = "* {{ru-IPA|%s}}\n" % verb
  notetext = ""
  defntext = None
  for synantrel in els[5:]:
    m = re.search(r"^(syn|ant|der|rel|see|pron|alt|def|note):(.*)", synantrel)
    if not m:
      msg("Element %s doesn't start with syn:, ant:, der:, rel:, see:, pron:, alt:, def: or note:" % synantrel)
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
    elif sartype == "def":
      defntext = generate_pos.generate_defn(vals)
    elif sartype == "note":
      notetext = " {{i|%s}}" % vals
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
            # Handle #ref, which we replace with the corresponding reflexive
            # verb pair for non-reflexive verbs and vice-versa
            gender_arg = ("|g=impf|g2=pf" if headword_aspect == "both" else
                "|g=" + headword_aspect)
            if "#ref" in derrel:
              if isrefl:
                refverb = re.sub(u"с[ья]$", "", verb) + gender_arg
                correfverbs = []
                for corverb in corverbs:
                  correfverbs.append("%s|g=%s" % (
                    re.sub(u"с[ья]$", "", corverb),
                    "impf" if headword_aspect == "pf" else "pf"))
              else:
                refverb = (re.search(u"и́?$", verb) and verb + u"сь" or
                    rulib.try_to_stress(verb) + u"ся") + gender_arg
                correfverbs = []
                for corverb in corverbs:
                  correfverbs.append("%s|g=%s" % (
                      (re.search(u"и́?$", corverb) and corverb + u"сь" or
                        rulib.try_to_stress(corverb) + u"ся"),
                      "impf" if headword_aspect == "pf" else "pf"))
              if headword_aspect == "impf":
                refverbs = [refverb] + correfverbs
              else:
                refverbs = correfverbs + [refverb]
              derrel = re.sub("#ref", "/".join(refverbs), derrel)

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

  if defntext == None:
    if args.reqdef:
      error("No definition; should specify one or use def:-")
    else:
      defntext = "# {{rfdef|lang=ru}}\n"
  if reltext == None:
    error("No related terms; should specify some or use rel:- to disable them")

  msg("""%s

==Russian==

%s===Etymology===
%s

===Pronunciation===
%s
===Verb===
{{ru-verb|%s|%s%s}}%s

%s%s
====Conjugation====
%s

%s%s%s%s%s[[ru:%s]]

""" % (rulib.remove_accents(verb), alttext, etymtext, prontext,
  verb, headword_aspect, corverbtext, notetext,
  defntext, passivetext, conjtext, syntext, anttext, dertext,
  reltext, seetext, rulib.remove_accents(verb)))
