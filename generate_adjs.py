#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import re, sys, argparse

from blib import msg, errmsg, remove_links
import blib
import rulib
import generate_pos

parser = blib.create_argparser("Generate derived-verb tables.")
parser.add_argument('--direcfile', help="File containing directives.", required=True)
parser.add_argument('--pos', action="store_true",
    help="First field is part of speech (n, adj, adv, pcl, pred, prep, conj, int).")
parser.add_argument('--adverb', action="store_true",
    help="Directive file contains adverbs instead of adjectives.")
parser.add_argument('--noun', action="store_true",
    help="Directive file contains nouns instead of adjectives.")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

pos_to_full_pos = {
  # The first three are special-cased
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

opt_arg_regex = r"^(also|syn|ant|der|rel|see|comp|pron|alt|part|wiki|enwiki|cat|tcat|usage|file):(.*)"

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
# the etym section will say "Substantivized [gender] of {{m|ru|TERM}}."
# For borrowed terms, the field should be prefixed with a language code
# followed by a colon, e.g. "fr:attitude". If what follows contains no + sign,
# the etym section will use {{bor|ru|LANG|TERM}}; else {{affix|...}} will be
# used; e.g. "fr:spectral+-ный" becomes {{affix|ru|spectral|-ный|lang1=fr}}.
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
# {{lb|ru|...}}. The following are recognized:
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
#    {{given name|lang=ru|REMAINDER}}.
# 5. "altyo:TERM" or "altyo:TERM:REST", for non-ё forms of words properly
#    spelled with ё. For nouns, REST needs to include the gender, e.g.
#    "altyo:распространённость:f-in".
#
# In place of a normal definition, the definition can consist of a single
# "-", in which case a request for definition is substituted, or begin with
# "ux:", in which case the remainder of the line is a usage example and
# is substituted into {{uxi|ru|...}}.
#
# (describe additional specs)

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
  if len(els) == 2 and els[1].startswith("altyo:"):
    altyoparts = do_split(":", els[1])
    assert len(altyoparts) in [2, 3]
    pos_to_altyo = {
      "n": u"ru-noun-alt-ё",
      "pn": u"ru-proper noun-alt-ё",
      "adj": u"ru-adj-alt-ё",
      "v": u"ru-verb-alt-ё"
    }
    if pos in pos_to_altyo:
      altyotemp = pos_to_altyo[pos]
      if len(altyoparts) == 2:
        yoline = "{{%s|%s}}" % (altyotemp, altyoparts[1])
      else:
        yoline = "{{%s|%s|%s}}" % (altyotemp, altyoparts[1],
          altyoparts[2])
    else:
      assert pos in pos_to_full_pos
      fullpos = pos_to_full_pos[pos]
      if len(altyoparts) == 2:
        yoline = u"{{ru-pos-alt-ё|%s|%s}}" % (altyoparts[1], fullpos.lower())
      else:
        error("With misc. part of speech, gender/aspect not supported")
    msg("""%s

==Russian==

===%s===
%s


""" % (rulib.remove_accents(altyoparts[1]).replace(u"ё", u"е"),
      pos_to_full_pos[pos], yoline))
    continue

  # Replace _ with space, but not in the declension, where there may be
  # an underscore, e.g. a|short_m=-; but allow \s to stand for a space in
  # the declension, and \u for underscore elsewhere
  els = [el.replace(r"\s", " ") if i == 2 and (pos in ["n", "pn", "adj"]) else el.replace("_", " ").replace(r"\u", "_") for i, el in enumerate(els)]
  if pos not in ["n", "pn", "adj"]:
    term, etym, defns = els[0], els[1], els[2]
    remainder = els[3:]
  else:
    if len(els) < 4:
      error("Expected four fields, saw only %s" % len(els))
    term, etym, decl, defns = els[0], els[1], els[2], els[3]
    if decl.startswith("?"):
      error("Declension starts with ?, need to fix: %s" % decl)
    remainder = els[4:]
  translit = None
  if "//" in term:
    term, translit = do_split("//", term)
  # The original term may have translit, links and/or secondary/tertiary accents.
  # For pronunciation purposes, we remove the translit and links but keep the
  # secondary/tertiary accents. For headword purposes, we remove the
  # secondary/tertiary accents but keep the translit and links. For declension
  # purposes (other than ru-noun+), we remove everything (but still leave
  # primary accents).
  pronterm = remove_links(term) # FIXME: Reverse-translit translit if present
  term = rulib.remove_non_primary_accents(term)
  translit = rulib.remove_tr_non_primary_accents(translit)
  headterm = term
  term = remove_links(term)
  declterm = "%s//%s" % (term, translit) if translit else term
  if pos == "adj":
    assert re.search(u"((ый|ий|о́й)(ся)?|[оеё]́?в|и́?н)$", term)
  trtext = translit and "|tr=" + translit or ""
  check_stress(term)

  # Handle etymology
  adjformtext = ""
  if etym == "?":
    error("Etymology consists of bare question mark")
  elif etym == "-":
    etymtext = "===Etymology===\n{{rfe|lang=ru}}\n\n"
  elif etym == "--":
    etymtext = ""
  elif re.search(r"^(part|adj|partadj)([fnp]):", etym):
    m = re.search(r"^(part|adj|partadj)([fnp]):(.*)", etym)
    forms = {"f":["nom|f|s"], "n":["nom|n|s", "acc|n|s"], "p":["nom|p", "in|acc|p"]}
    infleclines = ["# {{inflection of|lang=ru|%s||%s}}" %
        (m.group(3), form) for form in forms[m.group(2)]]
    if m.group(1) in ["adj", "partadj"]:
      adjinfltext = """===Adjective===
{{head|ru|adjective form|head=%s%s}}

%s\n\n""" % (headterm, trtext, "\n".join(infleclines))
    else:
      adjinfltext = ""
    if m.group(1) in ["part", "partadj"]:
      partinfltext = """===Participle===
{{head|ru|participle form|head=%s%s}}

%s\n\n""" % (headterm, trtext, "\n".join(infleclines))
    else:
      partinfltext = ""
    adjformtext = partinfltext + adjinfltext
    etymtext = ""
  else:
    if etym.startswith("acr:"):
      _, fullexpr, meaning = do_split(":", etym)
      etymtext = "{{ru-etym acronym of|%s||%s}}." % (fullexpr, meaning)
    elif etym.startswith("deverb:"):
      _, sourceterm = do_split(":", etym)
      etymtext = "Deverbal from {{m|ru|%s}}." % sourceterm
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
      m = re.search(r"^([a-zA-Z.-]+):(.*)", etym)
      if m:
        langtext = "|lang1=%s" % m.group(1)
        etym = m.group(2)
      else:
        langtext = ""
      etymtext = "%s{{affix|ru|%s%s}}%s" % (prefix,
          "|".join(do_split(r"\+", re.sub(", *", ", ", etym))), langtext,
          suffix)
    etymtext = "===Etymology===\n%s\n\n" % etymtext

  # Create declension
  is_invar_gender = None
  if pos in ["n", "pn", "adj"]:
    decl = decl.replace("?", "") # eliminate uncertainty notations
    if decl.startswith("inv:"):
      is_invar_gender = re.sub("^inv:", "", decl)
    else:
      if decl == "-":
        hdecltext = declterm
      elif decl == "--":
        hdecltext = "%s|-" % declterm
      elif "..." in decl:
        hdecltext = decl.replace("...", declterm)
      elif decl.startswith("!"):
        hdecltext = decl[1:]
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
  defntext, _ = generate_pos.generate_defn(defns, pos_to_full_pos[pos].lower(), "ru")

  alsotext = ""
  alttext = ""
  parttext = ""
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
  prontext = "* {{ru-IPA|%s}}\n" % pronterm
  for synantrel in remainder:
    if synantrel.startswith("#"):
      break # ignore comments
    m = re.search(opt_arg_regex, synantrel)
    if not m:
      error("Element %s doesn't start with also:, syn:, ant:, der:, rel:, see:, comp:, pron:, alt: or part:" % synantrel)
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
      for i, comp in enumerate(do_split(",", vals)):
        if comp == "+":
          basicdecl = re.sub(r"\|.*", "", decl)
          if "b(2)" in basicdecl:
            error("Can't have comp:+ with b(2) in decl")
          basicdecl = basicdecl.replace("*", "")
          basicdecl = basicdecl.replace("(1)", "")
          basicdecl = basicdecl.replace("(2)", "")
          basicdecl = set([re.sub(":.*", "", x) for x in re.split(",", basicdecl)])
          if len(basicdecl) > 1:
            error("Can't have comp:+ with multiple decls (yet?)")
            if basicdecl != "a":
              comp = "+" + basicdecl
        elif "+" not in comp:
          check_stress(comp)
        if i == 0:
          comptext += "|%s" % comp
        else:
          comptext += "|comp%s=%s" % (i + 1, comp)
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
    elif sartype == "part":
      verbs, parttypes, partshort = do_split(":", vals)
      infleclines = []
      for verb in do_split(",", verbs):
        for parttype in do_split(",", parttypes):
          infleclines.append("# {{ru-participle of|%s||%s}}" % (verb, parttype))
      parttext = """===Participle===
{{head|ru|participle|head=%s%s}}

%s\n\n""" % (headterm, trtext, "\n".join(infleclines))
      if "adv" in parttype:
        partdecltext = ""
      else:
        partdecltext = """====Declension====
{{ru-decl-adj|%s%s}}\n\n""" % (declterm,
          "" if partshort == "-" else "|" + partshort)
      parttext += partdecltext
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
                links.append("{{l|ru|%s}}" % impfpfverbs[0])
              else:
                links.append("{{l|ru|%s|g=impf}}" % impfpfverbs[0])
              for pf in impfpfverbs[1:]:
                if "|" in pf:
                  links.append("{{l|ru|%s}}" % pf)
                else:
                  links.append("{{l|ru|%s|g=pf}}" % pf)
            elif derrel.startswith("{"):
              links.append(derrel)
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

  multidefntext = generate_pos.generate_multiline_defn(peeker)
  if multidefntext:
    if defns != "-" and defns != "--":
      error("Inline and multiline definitions both specified")
    else:
      defntext = multidefntext

  if reltext == None:
    error("No related terms; should specify some or use rel:- to disable them")
  dertext = dertext or ""
  seetext = seetext or ""

  if is_invar_gender:
    if pos == "n":
      maintext = """{{ru-noun|%s%s|%s|-}}

%s
""" % (headterm, trtext, is_invar_gender, defntext)
    elif pos == "pn":
      maintext = """{{ru-proper noun|%s%s|%s|-}}

%s
""" % (headterm, trtext, is_invar_gender, defntext)
    elif pos == "adj":
      maintext = """{{ru-adj|%s%s%s}} {{i|indeclinable}}

%s
""" % (headterm, trtext, comptext, defntext)
    else:
      error("Invalid part of speech for indeclinable")
  else:
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
{{ru-decl-adj%s}}

""" % (headterm, trtext, comptext, defntext, decltext)
    elif pos == "adv":
      maintext = """{{ru-adv|%s%s%s}}

%s
""" % (headterm, trtext, comptext, defntext)
    else:
      full_pos = pos_to_full_pos[pos]
      maintext = """{{head|ru|%s|head=%s%s}}

%s
""" % (full_pos.lower(), headterm, trtext, defntext)

  if defns == "--":
    maintext = ""

  # If both adjective and participle header, move related-terms text to level 3
  if maintext and parttext and reltext:
    reltext = re.sub("^====Related terms====", "===Related terms===", reltext)

  # If any categories, put an extra newline after them so they end with two
  # newlines, as with other textual snippets
  if cattext:
    cattext += "\n"

  usagetext = "===Usage notes===\n%s\n\n" % "\n".join(usagelines) if usagelines else ""

  msg("""%s

%s==Russian==
%s%s%s
%s%s===Pronunciation===
%s
%s%s===%s===
%s%s%s%s%s%s%s%s
""" % (rulib.remove_accents(term), alsotext, enwikitext, wikitext, filetext,
  alttext, etymtext, prontext, parttext, adjformtext, pos_to_full_pos[pos],
  maintext, usagetext, syntext, anttext, dertext, reltext, seetext, cattext))
