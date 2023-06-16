#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import re, sys, codecs, argparse

from blib import msg, errmsg
import rulib
import generate_pos

parser = argparse.ArgumentParser(description="Generate verb stubs.")
parser.add_argument('--reqdef', help="Require a definition.", action="store_true")
parser.add_argument('--direcfile', help="File containing directives.", required=True)
args = parser.parse_args()

# Split text on a separator, but not if separator is preceded by
# a backslash, and remove such backslashes
def do_split(sep, text):
  elems = re.split(r"(?<![\\])%s" % sep, text)
  return [re.sub(r"\\(%s)" % sep, r"\1", elem) for elem in elems]

peeker = generate_pos.Peeker(open(args.direcfile, "r", encoding="utf-8"))
while True:
  line = peeker.get_next_line()
  if line == None:
    break
  line = line.strip()

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

  # Skip lines consisting entirely of comments
  if line.startswith("#"):
    continue
  els = do_split(r"\s+", line)

  if len(els) == 2 and els[1].startswith("altyo:"):
    altyoparts = do_split(":", els[1])
    if len(altyoparts) != 3:
      error("Expected verb and aspect with altyo:")
    yoline = u"{{ru-verb-alt-ё|%s|%s}}" % (altyoparts[1], altyoparts[2])
    msg("""%s

==Russian==

===Verb===
%s


""" % (rulib.remove_accents(altyoparts[1]).replace(u"ё", u"е"), yoline))
    continue

  # Replace _ with space, but not in the conjugation, where param names
  # may well have an underscore in them; but allow \s to stand for a space in
  # the conjugation, and \u to stand for an underscore elsewhere.
  els = [el.replace(r"\s", " ") if i == 4 else el.replace("_", " ").replace(r"\u", "_") for i, el in enumerate(els)]
  if len(els) < 5:
    error("Expected five fields, saw only %s" % len(els))
  verb, etym, aspect, corverbs, conj = els[0], els[1], els[2], els[3], els[4]
  translit = None
  declverb = verb
  if "//" in verb:
    verb, translit = do_split("//", verb)
  assert re.search(u"(ть(ся)?|ти́?(сь)?|чь(ся)?)$", verb)
  trtext = translit and "|tr=" + translit or ""
  check_stress(verb)
  isrefl = re.search(u"(ся|сь)$", verb)
  if etym == "?":
    error("Etymology consists of bare question mark")
  elif etym == "-":
    etymtext = "===Etymology===\n{{rfe|lang=ru}}\n\n"
  elif etym == "--":
    etymtext = ""
  else:
    if etym.startswith("acr:"):
      _, fullexpr, meaning = do_split(":", etym)
      etymtext = "{{ru-etym acronym of|%s||%s}}." % (fullexpr, meaning)
    elif etym.startswith("back:"):
      _, sourceterm = do_split(":", etym)
      etymtext = "{{back-form|lang=ru|%s}}" % sourceterm
    elif etym.startswith("raw:"):
      etymtext = re.sub(", *", ", ", re.sub("^raw:", "", etym))
    elif ":" in etym and "+" not in etym:
      if etym.startswith("?"):
        prefix = "Perhaps borrowed from "
        etym = re.sub(r"^\?", "", etym)
      elif etym.startswith("<<"):
        prefix = "Ultimately borrowed from "
        etym = re.sub(r"^<<", "", etym)
      else:
        prefix = "Borrowed from "
      m = re.search(r"^([a-zA-Z.-]+):(.*)", etym)
      if not m:
        error("Bad etymology form: %s" % etym)
      etymtext = "%s{{bor|ru|%s|%s}}." % (prefix, m.group(1), m.group(2))
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
        m = re.search(r"^([a-zA-Z.-]+):(.*)", etym)
        if m:
          langtext = "|lang1=%s" % m.group(1)
          etym = m.group(2)
        else:
          langtext = ""
        etymtext = "%s{{affix|ru|%s%s}}%s" % (prefix,
            "|".join(do_split(r"\+", etym)), langtext, suffix)
    etymtext = "===Etymology===\n%s\n\n" % etymtext
  headword_aspect = re.sub("-.*", "", aspect)
  assert headword_aspect in ["pf", "impf", "both"]
  if corverbs == "-":
    corverbs = []
  else:
    corverbs = do_split(",", corverbs)
  corverbtext = ""
  corverbno = 1
  for corverb in corverbs:
    if "?" in corverb:
      error("? in corresponding aspect-pair verb '%s'" % corverb)
    check_stress(corverb)
    corverbtext += "|%s%s=%s" % (
        "impf" if headword_aspect == "pf" or corverb.startswith("*") else "pf",
        "" if corverbno == 1 else str(corverbno), re.sub(r"^\*", "", corverb))
    corverbno += 1
  verbbase = re.sub(u"(ся|сь)$", "", verb)
  trverbbase = translit and re.sub(u"(sja|sʹ)$", "", translit)
  passivetext = ("# {{passive of|lang=ru|%s%s}}\n" % (verbbase,
    trverbbase and "|tr=%s" % trverbbase or "") if etym == "r" else "")

  if "|" not in conj:
    conjargs = "%s%s" % (verb, "//" + translit if translit else "")
  else:
    conjargs = re.sub(r"^.*?\|", "", conj)
    conj = re.sub(r"\|.*$", "", conj)
  if aspect.startswith("both"):
    pfaspect = re.sub("^both", "pf", aspect)
    impfaspect = re.sub("^both", "impf", aspect)
    conjtext = """''imperfective''
{{ru-conj|%s|%s|%s}}
''perfective''
{{ru-conj|%s|%s|%s}}""" % (impfaspect, conj, conjargs, pfaspect, conj, conjargs)
  else:
    conjtext = "{{ru-conj|%s|%s|%s}}" % (aspect, conj, conjargs)

  alttext = ""
  usagetext = ""
  syntext = ""
  anttext = ""
  dertext = None
  reltext = None
  seetext = None
  prontext = "* {{ru-IPA|%s}}\n" % verb
  notetext = ""
  defntext = None
  wikitext = ""
  enwikitext = ""
  cattext = ""
  for synantrel in els[5:]:
    if synantrel.startswith("#"):
      break # ignore comments
    alternation_no_syn_ant = "der|rel|see|pron|alt|def|note|wiki|enwiki|usage|cat|tcat"
    prefix_regex = "(syn|ant|%s):" % alternation_no_syn_ant
    prefix_regex_no_syn_ant = "(%s):" % alternation_no_syn_ant
    m = re.search(r"^%s(.*)" % prefix_regex, synantrel)
    if not m:
      error("Element %s doesn't start with syn:, ant:, der:, rel:, see:, pron:, alt:, def:, note:, wiki:, enwiki:, usage:, cat: or tcat:" % synantrel)
    sartype, vals = m.groups()
    if re.search(prefix_regex_no_syn_ant if sartype == "def" else prefix_regex, vals):
      error("Saw stray prefix inside of text: %s" % synantrel)
    if sartype in ["syn", "ant"]:
      lines = []
      for synantgroup in do_split(";", vals):
        sensetext = ""
        if synantgroup.startswith("*(") or synantgroup.startswith("("):
          m = re.search(r"^\*?\((.*?)\)(.*)$", synantgroup)
          sensetext = "{{sense|%s}} " % m.group(1)
          synantgroup = m.group(2)
        elif synantgroup.startswith("*"):
          sensetext = "{{sense|FIXME}} "
          synantgroup = re.sub(r"\*", "", synantgroup)
        else:
          sensetext = ""
        links = []
        for synant in do_split(",", synantgroup):
          if synant.startswith("{"):
            links.append(synant)
          else:
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
      for i, pron in enumerate(do_split(",", vals)):
        check_stress(pron)
        prontext += "* {{ru-IPA|%s}}\n" % pron
    elif sartype == "alt":
      lines = []
      for altform in do_split(",", vals):
        if altform.startswith("{"):
          lines.append("* %s\n" % altform)
        else:
          check_stress(altform)
          lines.append("* {{l|ru|%s}}\n" % altform)
      alttext = "===Alternative forms===\n%s\n" % "".join(lines)
    elif sartype == "def":
      defntext, _ = generate_pos.generate_defn(vals, "verb")
    elif sartype == "note":
      vals = re.sub(r"\[\[(.*?)\]\]", r"{{m|ru|\1}}", vals)
      vals = re.sub(r"\(\((.*?)\)\)", r"{{m|ru|\1}}", vals)
      vals = re.sub(r"g\((.*?)\)", r"{{glossary|\1}}", vals)
      vals = re.sub(r",\s*", ", ", vals)
      notetext = " {{i|%s}}" % vals
    elif sartype == "wiki":
      for val in do_split(",", vals):
        if val:
          wikitext += "{{wikipedia|lang=ru|%s}}\n" % val
        else:
          wikitext += "{{wikipedia|lang=ru}}\n"
    elif sartype == "enwiki":
      assert vals
      for val in do_split(",", vals):
        enwikitext += "{{wikipedia|%s}}\n" % val
    elif sartype == "cat":
      assert vals
      cattext += "".join("[[Category:Russian %s]]\n" % val for val in do_split(",", vals))
    elif sartype == "tcat":
      assert vals
      cattext += "".join("{{C|ru|%s}}\n" % val for val in do_split(",", vals))
    elif sartype == "usage":
      assert vals
      usagetext = re.sub(", *", ", ", vals)
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
        for derrelgroup in do_split(",", vals):
          links = []
          for derrel in do_split(":", derrelgroup):
            # Handle #ref, which we replace with the corresponding reflexive
            # verb pair for non-reflexive verbs and vice-versa
            gender_arg = ("|g=impf|g2=pf" if headword_aspect == "both" else
                "|g=" + headword_aspect)
            if "#ref" in derrel:
              assert not translit # FIXME, can't handle it yet
              # * at the beginning of an aspect-paired verb forces
              # imperfective; used with aspect "both"
              corverb_impf_override = any(corverb for corverb in corverbs
                  if corverb.startswith("*"))
              if isrefl:
                refverb = re.sub(u"с[ья]$", "", verb) + gender_arg
                correfverbs = []
                for corverb in corverbs:
                  correfverbs.append("%s|g=%s" % (
                    re.sub(u"с[ья]$", "", re.sub(r"^\*", "", corverb)),
                    "impf" if headword_aspect == "pf" or
                      corverb.startswith("*") else "pf"))
              else:
                refverb = (re.search(u"и́?$", verb) and verb + u"сь" or
                    rulib.try_to_stress(verb) + u"ся") + gender_arg
                correfverbs = []
                for corverb in corverbs:
                  impf_override = corverb.startswith("*")
                  corverb = re.sub(r"^\*", "", corverb)
                  correfverbs.append("%s|g=%s" % (
                      (re.search(u"и́?$", corverb) and corverb + u"сь" or
                        rulib.try_to_stress(corverb) + u"ся"),
                      "impf" if headword_aspect == "pf" or impf_override
                        else "pf"))
              if headword_aspect == "pf" or corverb_impf_override:
                refverbs = correfverbs + [refverb]
              else:
                refverbs = [refverb] + correfverbs
              derrel = re.sub("#ref", "/".join(refverbs), derrel)

            if "/" in derrel:
              impfpfverbs = do_split("/", derrel)
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
    defntext = generate_pos.generate_multiline_defn(peeker)
  if defntext == None:
    if args.reqdef:
      error("No definition; should specify one or use def:-")
    else:
      defntext = "# {{rfdef|lang=ru}}\n"
  if reltext == None:
    error("No related terms; should specify some or use rel:- to disable them")
  dertext = dertext or ""
  seetext = seetext or ""

  # If any categories, put an extra newline after them so they end with two
  # newlines, as with other textual snippets
  if cattext:
    cattext += "\n"

  if usagetext:
    usagetext = "====Usage notes====\n%s\n\n" % usagetext

  msg("""%s

==Russian==
%s%s
%s%s===Pronunciation===
%s
===Verb===
{{ru-verb|%s%s|%s%s}}%s

%s%s
====Conjugation====
%s

%s%s%s%s%s%s%s
""" % (rulib.remove_accents(verb), enwikitext, wikitext, alttext, etymtext,
  prontext, verb, trtext, headword_aspect, corverbtext, notetext,
  defntext, passivetext, conjtext, usagetext, syntext, anttext, dertext,
  reltext, seetext, cattext))
