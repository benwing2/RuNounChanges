#!/usr/bin/env python
# -*- coding: utf-8 -*-

import re, sys, codecs, argparse

from blib import msg, errmsg, remove_links
import bglib
import generate_pos

parser = argparse.ArgumentParser(description="Generate adjective stubs.")
parser.add_argument('--direcfile', help="File containing directives.")
parser.add_argument('--pos', help="Specify part of speech (v, n, pn, adj, adjform, adv, pcl, pred, prep, conj, int) instead of including it as first field.")
args = parser.parse_args()

pos_to_full_pos = {
  # The first four are special-cased
  "v": "Verb",
  "n": "Noun",
  "pn": "Proper noun",
  "adj": "Adjective",
  "adjform": "Adjective form",
  "adv": "Adverb",
  "pcl": "Particle",
  "pred": "Predicative",
  "prep": "Preposition",
  "conj": "Conjunction",
  "int": "Interjection",
  # supported only for altyo:
  "part": "Participle",
}

props = [
  "also",
  "syn",
  "ant",
  "der",
  "rel",
  "see",
  "tlb",
  "pron",
  "comp",
  "alt",
  "part",
  "nadjf",
  "ppp",
  "wiki",
  "enwiki",
  "cat",
  "tcat",
  "usage",
  "file",
]

opt_arg_regex = r"^(%s):(.*)" % "|".join(props)

# Form for adjectives, nouns and proper nouns:
#
# TERM ETYM DECL DEF ...
#
# where ... is 0 or more additional specifications, each preceded by a
# prefix suchas rel: (for related terms) or alt: (for alternative forms).
#
# Form for other parts of speech is similar:
#
# TERM ETYM DEF ...
#
# If --pos is given, there should be an additional first column noting the
# part of speech (n = noun, adj = adjective, adv = adverb, etc. see
# pos_to_full_pos above).
#
# An underscore is replaced with a space in any field except for the
# declension field, which can have underscores in it legitimately (e.g.
# "a|short_m=-"). To indicate a space in the declension field, use \s,
# and to indicate an underscore elsewhere, use \u.
#
# TERM is normally the term itself, but can consist of the form TERM//TRANSLIT
# for explicitly-specified translit.
#
# DECL is the declension that follows the term in the declensional template,
# and in the headword template of nouns. If it consists of -, no declension
# specification is used. If it consists of --, the declension consists of
# literal - (for adjectives, to indicate that no short forms exist). DECL
# can have ... to represent position of term in it, or begin with ! to
# indicate that what follows should be used literally as the declension
# (otherwise, the declension is placed after the term, separated by a vertical
# bar). For nouns, DECL can contain |m=..., |f=... and/or |g=..., |g2=..., etc.
# to specify masculine/feminine equivalents or genders, as are found in the
# headword template; these will automatically be removed when creating the
# declension template.
#
# ETYM normally consists of one or more parts separated by + symbols; the
# parts go directly into parameters of {{affix}}. If the field consists of
# -, the etym section will contain a request for etymology; if the field
# is --, the etym section will be omitted (used for participles and such).
# For substantivized adjectives, the etym section can begin with sm:, sf:
# sn: or sp: for substantivized masculine, feminine, neuter or plural, and
# the etym section will say "Substantivized [gender] of {{m|bg|TERM}}."
# For borrowed terms, the field should be prefixed with a language code
# followed by a colon, e.g. "fr:attitude". If what follows contains no + sign,
# the etym section will use {{bor|bg|LANG|TERM}}; else {{affix|...}} will be
# used; e.g. "fr:spectral+-ный" becomes {{affix|bg|spectral|-ный|lang1=fr}}.
# The etym section can begin with ?, indicating that the etymology is
# uncertain (it will be prefixed with "Perhaps from" or "Perhaps borrowed from"
# as appropriate), or with <<, indicating an ultimate etymology (it will be
# prefixed with "Ultimately from" or "Ultimately borrowed from" as
# appropriate).
#
# DEF consists of one or more definitions, separated by semicolons; each
# definition goes on its own line. The definition will be normally used
# directly, except that underscores should be used in place of spaces and
# a space will be added after any comma not followed by a space. Use \; to
# indicate a literal semicolon. Each definition can begin with one or
# labels, which are placed at the beginning of the definition using
# {{lb|bg|...}}. The following are recognized:
#
# + = relational
# # = figurative
# (f) = figurative
# (or) = put the word "or" in the label
# (also) = put the word "also" in the label
# (d) = dated
# (p) = poetic
# (h) = historical
# (n) = nonstandard
# (lc) = low colloquial
# (v) = vulgar
# ! = colloquial
# (c) = colloquial
# (l) = literary
# (tr) = transitive
# (in) = intransitive
# (io) = imperfective only
# (po) = perfective only
# (im) = impersonal
# (pej) = pejorative
# (vul) = vulgar
# (reg) = regional
# (joc) = jocular
#
# After any labels, the definition can consist of one of the following special
# forms:
#
# 1. "altof:TERM" if it is an alternative form of another term
# 2. "dim:TERM" or "dim:TERM:DEFN", for a diminutive form of another term,
#    optionally followed by a definition (the definition is for the diminutive
#    term, not the source term)
# 3. "aug:TERM" or "aug:TERM:DEFN", for an augmentative form of another term,
#    optionally followed by a definition (the definition is for the
#    augmentative term, not the source term)
# 4. "gn:REMAINDER", for a given name; generates
#    {{given name|bg|REMAINDER}}.
#
# In place of a normal definition, the definition can consist of a single
# "-", in which case a request for definition is substituted, or begin with
# "ux:", in which case the remainder of the line is a usage example and
# is substituted into {{uxi|bg|...}}.
#
# (describe additional specs)

# Split text on a separator, but not if separator is preceded by
# a backslash, and remove such backslashes
def do_split(sep, text):
  elems = re.split(r"(?<![\\])%s" % sep, text)
  return [re.sub(r"\\(%s)" % sep, r"\1", elem) for elem in elems]

def increase_indent(text):
  return re.sub("^=(.*)=$", r"==\1==", text, 0, re.M)

def process_line(line, etymnum=None, skip_pronun=False):
  def error(text):
    errmsg("ERROR: Processing line: %s" % line)
    errmsg("ERROR: %s" % text)
    assert False

  def check_stress(word):
    word = re.sub(r"|.*", "", word)
    if word.startswith("-") or word.endswith("-"):
      # Allow unstressed prefix (e.g. разо-) and unstressed suffix (e.g. -овать)
      return
    if bglib.needs_accents(word, split_dash=True):
      error("Word %s missing an accent" % word)

  els = do_split(r"\s+", line)
  if args.pos:
    pos = args.pos
  else:
    pos = els[0]
    del els[0]
  if pos not in pos_to_full_pos:
    error("Unrecognized part of speech %s" % pos)

  # Replace _ with space, but not in the declension, where there may be
  # an underscore, e.g. a|short_m=-; but allow \s to stand for a space in
  # the declension, and \u for underscore elsewhere
  els = [el.replace(r"\s", " ") if i == 2 and (pos in ["n", "pn", "adj"]) else el.replace("_", " ").replace(r"\u", "_") for i, el in enumerate(els)]
  if pos == "v":
    if len(els) < 6:
      error("Expected six fields, saw only %s" % len(els))
    term, etym, aspect, pairedverb, conj, defns = els[0], els[1], els[2], els[3], els[4], els[5]
    remainder = els[6:]
  elif pos in ["n", "pn", "adj"]:
    if len(els) < 4:
      error("Expected four fields, saw only %s" % len(els))
    term, etym, decl, defns = els[0], els[1], els[2], els[3]
    remainder = els[4:]
  else:
    if len(els) < 3:
      error("Expected three fields, saw only %s" % len(els))
    term, etym, defns = els[0], els[1], els[2]
    remainder = els[3:]
  if term.startswith("!"):
    # ! is for continuing another entry without starting a new etym section.
    # Already processed in the outer loop.
    term = term[1:]
  # The original term may links and/or secondary/tertiary accents.
  # For pronunciation purposes, we remove the links but keep the
  # secondary/tertiary accents. For headword purposes, we remove the
  # secondary/tertiary accents but keep the links. For declension
  # purposes (other than bg-noun), we remove everything (but still leave
  # primary accents).
  pronterm = remove_links(term).split(",")
  term = bglib.remove_non_primary_accents(term)
  headterm = term.split(",")
  headterm_parts = []
  for num, ht in enumerate(headterm):
    if num == 0:
      headterm_parts.append(ht)
    else:
      headterm_parts.append("head%s=%s" % (num + 1, ht))
  headterm = "|".join(headterm_parts)
  term = remove_links(term).split(",")
  for t in term:
    check_stress(t)
    if "=" in t:
      error("Equal sign in term '%s', possible misplaced declension properties" % t)

  # Handle etymology
  adjformtext = ""
  etymheader = "===Etymology%s===\n" % (etymnum and " %s" % etymnum or "")
  if etym == "?":
    error("Etymology consists of bare question mark")
  elif etym == "-":
    etymtext = "%s{{rfe|bg}}\n\n" % etymheader
  elif etym == "--":
    if etymnum:
      etymtext = etymheader + "\n"
    else:
      etymtext = ""
  elif re.search(r"^(part|adj|partadj)([fnp]):", etym):
    m = re.search(r"^(part|adj|partadj)([fnp]):(.*)", etym)
    forms = {"f":["indef|f|s"], "n":["indef|n|s"], "p":["indef|p"]}
    infleclines = ["# {{inflection of|bg|%s||%s}}" %
        (m.group(3), form) for form in forms[m.group(2)]]
    if m.group(1) in ["adj", "partadj"]:
      adjinfltext = """===Adjective===
{{head|bg|adjective form|head=%s}}

%s\n\n""" % (headterm, "\n".join(infleclines))
    else:
      adjinfltext = ""
    if m.group(1) in ["part", "partadj"]:
      partinfltext = """===Participle===
{{head|bg|participle form|head=%s}}

%s\n\n""" % (headterm, "\n".join(infleclines))
    else:
      partinfltext = ""
    adjformtext = partinfltext + adjinfltext
    if etymnum:
      etymtext = etymheader + "\n"
    else:
      etymtext = ""
  else:
    if etym.startswith("acr:"):
      _, fullexpr, meaning = do_split(":", etym)
      etymtext = "{{acronym|%s||%s}}." % (fullexpr, meaning)
    elif etym.startswith("deverb:"):
      _, sourceterm = do_split(":", etym)
      etymtext = "Deverbal from {{m|bg|%s}}." % sourceterm
    elif etym.startswith("ppp:"):
      _, sourceterm = do_split(":", etym)
      etymtext = "Past passive participle of {{m|bg|%s}}." % sourceterm
    elif etym.startswith("back:"):
      _, sourceterm = do_split(":", etym)
      etymtext = "{{back-form|bg|%s}}" % sourceterm
    elif etym.startswith("raw:"):
      etymtext = re.sub(", *", ", ", re.sub("^raw:", "", etym))
    elif etym.startswith("inh:"):
      _, inhlang, inhterm = do_split(":", etym)
      etymtext = "Inherited from {{inh|bg|%s|%s}}." % (inhlang, inhterm)
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
      etymtext = "%s{{bor|bg|%s|%s}}." % (prefix, m.group(1), m.group(2))
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
      etymtext = "%s{{affix|bg|%s%s}}%s" % (prefix,
          "|".join(do_split(r"\+", re.sub(", *", ", ", etym))), langtext,
          suffix)
    etymtext = "%s%s\n\n" % (etymheader, etymtext)

  # Create conjugation
  if pos == "v":
    if len(term) > 1:
      error("Multiple terms not currently supported: %s" % ",".join(term))
    if aspect not in ["impf", "pf", "both"]:
      error("Bad aspect '%s', expected 'impf', 'pf' or 'both'" % aspect)
    conjparts = conj.split(".")
    if conjparts[0] in ["1", "2", "irreg"]:
      conjclass = "%s.%s." % (conjparts[0], conjparts[1])
      restconj = ".".join(conjparts[2:])
    else:
      conjclass = ""
      restconj = conj
    starts_with_transitivity = re.search(r"^(tr|intr)", restconj)
    is_reflexive = re.search(u" (се|си)$", term[0])
    if is_reflexive and starts_with_transitivity:
      error("Reflexive verb %s can't be specified as transitive or intransitive: %s" % (term[0], conj))
    elif not is_reflexive and not starts_with_transitivity:
      error("Non-reflexive verb %s must be specified as transitive or intransitive: %s" % (term[0], conj))
    conj = conjclass + aspect + (".%s" % restconj if restconj != "-" else "")
    conjtext = "{{bg-conj|%s<%s>}}" % (term[0], conj)
    if ("(refl)" in defns or "(reflexive)" in defns) and not is_reflexive:
      reflconj = re.sub(r"\.(tr|intr)", "", conj)
      conjtext += u"\n{{bg-conj|%s се<%s>}}" % (term[0], reflconj)
    if "(reflsi)" in defns and not is_reflexive:
      reflconj = re.sub(r"\.(tr|intr)", "", conj)
      conjtext += u"\n{{bg-conj|%s си<%s>}}" % (term[0], reflconj)
    if pairedverb != "-":
      hconjtext = "|%s=%s" % ("impf" if aspect == "pf" else "pf", pairedverb)
    else:
      hconjtext = ""
    hconjtext = aspect + hconjtext

  # Create declension
  is_invar_gender = None
  if pos in ["n", "pn", "adj"]:
    if decl.startswith("?!"):
      decl = decl[2:]
      attn_comp_text = "{{attn|bg|does this have a comparative?}}"
    else:
      attn_comp_text = ""
    if decl.startswith("inv:"):
      is_invar_gender = re.sub("^inv:", "", decl)
    else:
      if "(m)" in decl:
        gender = "m"
      elif "(f)" in decl:
        gender = "f"
      elif "(n)" in decl:
        gender = "n"
      elif "/n:pl" in decl:
        gender = "p"
      elif re.search(u"[ая]́?$", term[0]):
        gender = "f"
      elif re.search(u"[еоиую]́?$", term[0]):
        gender = "n"
      else:
        gender = "m"
      # decltext is the term+declension as used in the declension template,
      # hdecltext is the "declension" (actually just extra props such as |adv=го́ло)
      # as used in the headword template
      if decl.startswith("!"):
        decl = decl[1:]
        decltext = decl
      else:
        if len(term) > 1:
          error("With multiple terms, must use ! with explicit declension")
        if not decl.startswith("<"):
          error("Declension must start with '<' or '!': %s" % decl)
        decltext = "%s%s" % (term[0], decl)
      # Eliminate masculine/feminine equiv, adjective/adverb, etc. from actual decl
      decltext = re.sub(r"\|([mf]|adv|absn|adj|dim|g)[0-9]*=[^|]*?(?=\||$)", "", decltext)
      # Eliminate declension from hdecltext
      hdecltext = re.sub(r"^.*?(?=\||$)", "", decl)

  for t in term:
    if pos == "adj" and not is_invar_gender and re.search(u"[аеоуяю]́?$", t):
      error(u"Term %s is supposed to be an adjective but ends in vowel other than -и" % t)
    if pos == "adj" and not is_invar_gender and re.search("r\|(m|f|adj|g)", hdecltext):
      error("Term %s is supposed to be an adjective but has noun properties in the declension: %s" % (t, hdecltext))
    if pos == "n" and not is_invar_gender and re.search(r"\|(adv|absn)", hdecltext):
      error("Term %s is supposed to be a noun but has adjective properties in the declension: %s" % (t, hdecltext))

  # Create definition
  if re.search(opt_arg_regex, defns):
    error("Found optional-argument prefix in definition: %s" % defns)
  defntext = generate_pos.generate_defn(defns, pos_to_full_pos[pos].lower(), "bg")

  alsotext = ""
  alttext = ""
  parttext = ""
  nadjftext = ""
  ppptext = ""
  usagelines = []
  syntext = ""
  anttext = ""
  dertext = None
  reltext = None
  seetext = None
  comptext = ""
  wikitext = ""
  enwikitext = ""
  cattext = ""
  filetext = ""
  if len(pronterm) > 1:
    prontext = "".join("* {{bg-IPA|%s|ann=y}}\n" % pt for pt in pronterm)
  else:
    prontext = "* {{bg-IPA|%s}}\n" % pronterm[0]
  tlbtext = ""
  for synantrel in remainder:
    if synantrel.startswith("#"):
      break # ignore comments
    m = re.search(opt_arg_regex, synantrel)
    if not m:
      error("Element %s doesn't start with one of %s" % (synantrel, ", ".join("%s:" % prop for prop in props)))
    sartype, vals = m.groups()
    if sartype == "also":
      alsotext = "{{also|%s}}\n" % vals.replace(",", "|")
    elif sartype in ["syn", "ant"]:
      lines = []
      for synantgroup in do_split(";", vals):
        sensetext = ""
        if synantgroup.startswith("*(") or synantgroup.startswith("("):
          m = re.search(r"^\*?\((.*?)\)(.*)$", synantgroup)
          sensetext = "{{sense|%s}} " % re.sub(", *", ", ", m.group(1))
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
            links.append("{{l|bg|%s}}" % synant)
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
        prontext += "* {{bg-IPA|%s}}\n" % pron
    elif sartype == "comp":
      comptext = ""
      for i, comp in enumerate(do_split(",", vals)):
        if i == 0:
          comptext += "|%s" % comp
        else:
          comptext += "|comp%s=%s" % (i + 1, comp)
    elif sartype == "tlb":
      tlbtext = " {{tlb|bg|%s}}" % vals
    elif sartype == "alt":
      lines = []
      for altform in do_split(",", vals):
        if altform.startswith("{"):
          lines.append("* %s\n" % altform)
        else:
          check_stress(altform)
          lines.append("* {{l|bg|%s}}\n" % altform)
      alttext = "===Alternative forms===\n%s\n" % "".join(lines)
    elif sartype == "part":
      verbs, parttypes, partdecl = do_split(":", vals)
      infleclines = []
      for verb in do_split(",", verbs):
        for parttype in do_split(",", parttypes):
          infleclines.append("# {{bg-participle of|%s||%s}}" % (verb, parttype))
      parttext = """===Participle===
{{head|bg|participle|head=%s}}

%s\n\n""" % (headterm, "\n".join(infleclines))
      if "adv" in parttype:
        partdecltext = ""
      elif len(term) > 1:
        error("Don't yet know how to handle participle with multiple terms")
      else:
        partdecltext = """====Declension====
{{bg-adecl|%s%s}}\n\n""" % (term[0], partdecl)
      parttext += partdecltext
    elif sartype == "nadjf":
      check_stress(vals)
      nadjftext = """===Adjective===
{{head|bg|adjective form|head=%s}}

# {{inflection of|bg|%s||indef|n|s}}\n\n""" % (headterm, vals)
    elif sartype == "ppp":
      check_stress(vals)
      ppptext = """===Participle===
{{bg-part|%s|pass}}

# {{inflection of|bg|%s||indef|m|s|past|pass|part}}\n\n""" % (headterm, vals)
    elif sartype == "wiki":
      for val in do_split(",", vals):
        if val:
          wikitext += "{{wikipedia|lang=bg|%s}}\n" % val
        else:
          wikitext += "{{wikipedia|lang=bg}}\n"
    elif sartype == "enwiki":
      assert vals
      for val in do_split(",", vals):
        enwikitext += "{{wikipedia|%s}}\n" % val
    elif sartype == "cat":
      assert vals
      cattext += "".join("[[Category:Bulgarian %s]]\n" % val for val in do_split(",", vals))
    elif sartype == "tcat":
      assert vals
      cattext += "".join("{{C|bg|%s}}\n" % val for val in do_split(",", vals))
    elif sartype == "usage":
      assert vals
      usageline = re.sub(", *", ", ", vals)
      if not usageline.startswith("*"):
        usageline = "* " + usageline
      usagelines.append(usageline)
    elif sartype == "file":
      filename, text = do_split(":", vals)
      filetext += "[[File:%s|thumb|%s]]\n" % (filename, text)
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
        # don't split on \,
        for derrelgroup in do_split(",", vals):
          derrelgroup = re.sub(r",\s*", ", ", derrelgroup)
          links = []
          for derrel in do_split(":", derrelgroup):
            if "/" in derrel:
              impfpfverbs = do_split("/", derrel)
              for impfpfverb in impfpfverbs:
                check_stress(impfpfverb)
              if "|" in impfpfverbs[0]:
                links.append("{{l|bg|%s}}" % impfpfverbs[0])
              else:
                links.append("{{l|bg|%s|g=impf}}" % impfpfverbs[0])
              for pf in impfpfverbs[1:]:
                if "|" in pf:
                  links.append("{{l|bg|%s}}" % pf)
                else:
                  links.append("{{l|bg|%s|g=pf}}" % pf)
            elif derrel.startswith("{"):
              links.append(derrel)
            else:
              check_stress(derrel)
              links.append("{{l|bg|%s}}" % derrel)
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

  multidefntext = generate_pos.generate_multiline_defn(peeker)
  if multidefntext:
    if defns != "-" and defns != "--":
      error("Inline and multiline definitions both specified")
    else:
      defntext = multidefntext

  #if reltext == None:
  #  error("No related terms; should specify some or use rel:- to disable them")
  reltext = reltext or ""
  dertext = dertext or ""
  seetext = seetext or ""

  if is_invar_gender:
    if pos == "n":
      maintext = """{{bg-noun|%s|%s|indecl=1}}%s

%s
""" % (headterm, is_invar_gender, tlbtext, defntext)
    elif pos == "pn":
      maintext = """{{bg-proper noun|%s|%s|indecl=1}}%s

%s
""" % (headterm, is_invar_gender, tlbtext, defntext)
    elif pos == "adj":
      maintext = """{{bg-adj|%s|indecl=1}}

%s
""" % (headterm, defntext)
    else:
      error("Invalid part of speech for indeclinable")
  else:
    if pos == "n":
      maintext = """{{bg-noun|%s|%s%s}}%s

%s
====Declension====
{{bg-ndecl|%s}}

""" % (headterm, gender, hdecltext, tlbtext, defntext, decltext)
    elif pos == "pn":
      maintext = """{{bg-proper noun|%s|%s%s}}%s

%s
====Declension====
{{bg-ndecl|%s}}

""" % (headterm, gender, hdecltext, tlbtext, defntext, decltext)
    elif pos == "adj":
      maintext = """{{bg-adj|%s%s}}%s

%s
====Declension====
{{bg-adecl|%s}}%s

""" % (headterm, hdecltext, tlbtext, defntext, decltext, attn_comp_text)
    elif pos == "v":
      maintext = """{{bg-verb|%s|%s}}%s

%s
====Conjugation====
%s

""" % (headterm, hconjtext, tlbtext, defntext, conjtext)
    elif pos == "adv":
      maintext = """{{bg-adv|%s%s}}%s

%s
""" % (headterm, comptext, tlbtext, defntext)
    else:
      full_pos = pos_to_full_pos[pos]
      maintext = """{{head|bg|%s|head=%s}}%s

%s
""" % (full_pos.lower(), headterm, tlbtext, defntext)

  if defns == "--":
    maintext = ""

  # If both adjective and participle header, or adverb and neuter-adjective inflection header,
  # move related-terms text to level 3
  if maintext and (parttext or nadjftext or ppptext) and reltext:
    reltext = re.sub("^====Related terms====", "===Related terms===", reltext)

  # If any categories, put an extra newline after them so they end with two
  # newlines, as with other textual snippets
  if cattext:
    cattext += "\n"

  usagetext = "===Usage notes===\n%s\n\n" % "\n".join(usagelines) if usagelines else ""

  headertext = """%s==Bulgarian==
%s%s%s
""" % (alsotext, enwikitext, wikitext, filetext)

  prontext = "===Pronunciation===\n%s\n" % prontext
  if skip_pronun == "attop":
    headertext = "%s%s" % (headertext, prontext)
  if skip_pronun:
    prontext = ""

  if etymnum:
    inside_etymtext = ""
  else:
    inside_etymtext = etymtext
  bodytext = """%s%s%s%s%s%s===%s===
%s%s%s%s%s%s%s%s""" % (
    alttext, inside_etymtext, prontext, parttext, ppptext, adjformtext, pos_to_full_pos[pos],
    maintext, usagetext, syntext, anttext, dertext, nadjftext, reltext, seetext)
  if etymnum:
    bodytext = etymtext + increase_indent(bodytext)

  footertext = "%s\n" % cattext

  return headertext, bodytext, footertext

peeker = generate_pos.Peeker(codecs.open(args.direcfile, "r", "utf-8"))
nextpage = 0
while True:
  line = peeker.get_next_line()
  if line == None:
    break
  # Skip lines consisting entirely of comments
  if line.startswith("#"):
    continue
  line = line.strip()
  els = do_split(r"\s+", line)
  if args.pos:
    lemma = els[0]
  else:
    lemma = els[1]
  if lemma.startswith("!"):
    error("Out-of-place exclamation point in lemma: %s" % lemma)
  lemma = remove_links(lemma)
  seen_lemmas = {lemma}
  lemma = bglib.remove_accents(lemma).split(",")[0]
  morelines = []
  single_etym = False
  while True:
    nextline = peeker.peek_next_line(0)
    if nextline == None:
      break
    # Skip lines consisting entirely of comments
    if nextline.startswith("#"):
      peeker.get_next_line()
      continue
    nextline = nextline.strip()
    nextline_els = do_split(r"\s+", nextline)
    if args.pos:
      nextline_lemma = nextline_els[0]
    else:
      nextline_lemma = nextline_els[1]
    starts_with_exclamation_point = False
    if nextline_lemma.startswith("!"):
      starts_with_exclamation_point = True
      nextline_lemma = nextline_lemma[1:]
    nextline_lemma_with_accents = remove_links(nextline_lemma)
    nextline_lemma = bglib.remove_accents(nextline_lemma_with_accents).split(",")[0]
    if starts_with_exclamation_point and lemma == nextline_lemma:
      single_etym = True
    elif lemma != nextline_lemma:
      break
    peeker.get_next_line()
    morelines.append(nextline)
    seen_lemmas.add(nextline_lemma_with_accents)

  nextpage += 1

  def output_page(text):
    msg("Page %s %s: ------- begin text --------\n%s\n------- end text --------" % (
      nextpage, lemma, text.rstrip("\n")))

  if morelines:
    headertext, bodytext1, footertext = process_line(line, None if single_etym else 1,
        skip_pronun="attop" if len(seen_lemmas) == 1 and not single_etym else False)
    morebodytext = []
    for etymnum, nextline in enumerate(morelines):
      headertext2, bodytext2, footertext2 = process_line(
        nextline, None if single_etym else etymnum + 2,
        skip_pronun=single_etym or len(seen_lemmas) == 1
      )
      morebodytext.append(bodytext2)
    output_page("%s%s%s%s" % (headertext, bodytext1, "".join(morebodytext), footertext))
  else:
    headertext, bodytext, footertext = process_line(line)
    output_page("%s%s%s" % (headertext, bodytext, footertext))
