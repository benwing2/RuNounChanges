#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import re, sys, argparse

from blib import msg, errmsg, remove_links
import uklib
import bglib
import generate_pos

lang = None
langname = None
module = None

parser = argparse.ArgumentParser(description="Generate adjective stubs.")
parser.add_argument('--direcfile', help="File containing directives.", required=True)
parser.add_argument('--lang', help="Language: uk, bg, pt", choices=["uk", "bg", "pt"])
parser.add_argument('--pos', help="Specify part of speech (v, n, pn, adj, adjform, adv, pcl, pred, prep, conj, int) instead of including it as first field.")
args = parser.parse_args()

def unhandled_lang():
  raise ValueError("Internal error: Unhandled language %s" % lang)

if args.lang == "uk":
  lang = "uk"
  langname = "Ukrainian"
  module = uklib
  nomcase = "nom"
elif args.lang == "bg":
  lang = "bg"
  langname = "Bulgarian"
  module = bglib
  nomcase = "indef"
elif args.lang == "pt":
  lang = "pt"
  langname = "Portuguese"
  module = None
  nomcase = None
else:
  raise ValueError("Unrecognized language '%s': Should be 'uk', 'bg' or 'pt'" % args.lang)


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
  "note",
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
  "ref",
]

opt_arg_regex = r"^(%s):(.*)" % "|".join(props)

# Form for adjectives, nouns and proper nouns:
#
# TERM ETYM DECL DEF ...
#
# where ... is 0 or more additional specifications, each preceded by a
# prefix such as rel: (for related terms) or alt: (for alternative forms).
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
# parts go directly into parameters of {{af}}. If the field consists of
# -, the etym section will contain a request for etymology; if the field
# is --, the etym section will be omitted (used for participles and such).
# For substantivized adjectives, the etym section can begin with sm:, sf:
# sn: or sp: for substantivized masculine, feminine, neuter or plural, and
# the etym section will say "Substantivized [gender] of {{m|uk|TERM}}."
# For borrowed terms, the field should be prefixed with a language code
# followed by a colon, e.g. "fr:attitude". If what follows contains no + sign,
# the etym section will use {{bor+|uk|LANG|TERM}}; else {{af|...}} will be
# used; e.g. "fr:spectral+-ный" becomes {{af|uk|spectral|-ный|lang1=fr}}.
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
# {{lb|uk|...}}. The following are recognized:
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
#    {{given name|uk|REMAINDER}}.
#
# In place of a normal definition, the definition can consist of a single
# "-", in which case a request for definition is substituted, or begin with
# "ux:", in which case the remainder of the line is a usage example and
# is substituted into {{uxi|uk|...}}.
#
# (describe additional specs)

# Split text on a separator, but not if separator is preceded by
# a backslash, and remove such backslashes
def do_split(sep, text):
  elems = re.split(r"(?<![\\])%s" % sep, text)
  return [re.sub(r"\\n", "\n", re.sub(r"\\(%s)" % sep, r"\1", elem)) for elem in elems]

def increase_indent(text):
  return re.sub("^=(.*)=$", r"==\1==", text, 0, re.M)

def fatal(line, text):
  errmsg("ERROR: Processing line %s: %s" % (peeker.lineno, line))
  errmsg("ERROR: %s" % text)
  raise ValueError

def get_els_and_pos(line, error):
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
  return els, pos

# Generate page text for a given LINE. Return three values: HEADERTEXT, BODYTEXT, FOOTERTEXT.
# ETYMNUM is the number of the etymology section to insert in the etymology header,
# or None to not do this. If ETYMNUM is given, all sections are indented one more level.
# PRONUNS is a list of terms to use to generate the pronunciation, or None to not incldue
# a pronunciation section.  PRONUNS_AT_TOP should be True to place the pronunciations
# above the etymology (which only makes sense when ETYMNUM == 1), else False.
def process_line(line, pagename, etymnum, pronuns, pronuns_at_top):
  def error(text):
    fatal(line, text)

  def check_stress(word):
    word = re.sub(r"|.*", "", word)
    if word.startswith("-") or word.endswith("-"):
      # Allow unstressed prefix (e.g. разо-) and unstressed suffix (e.g. -овать)
      return
    if module and module.needs_accents(word, split_dash=True):
      error("Word %s missing an accent" % word)

  els, pos = get_els_and_pos(line, error)

  if pos == "v":
    if lang == "bg":
      if len(els) < 6:
        error("Expected six fields, saw only %s" % len(els))
      term, etym, aspect, pairedverb, conj, defns = els[0], els[1], els[2], els[3], els[4], els[5]
      remainder = els[6:]
    elif lang == "uk":
      if len(els) < 5:
        error("Expected five fields, saw only %s" % len(els))
      term, etym, pairedverb, conj, defns = els[0], els[1], els[2], els[3], els[4]
      remainder = els[5:]
    elif lang == "pt":
      if len(els) < 4:
        error("Expected four fields, saw only %s" % len(els))
      term, etym, conj, defns = els[0], els[1], els[2], els[3]
      pairedverb = None
      remainder = els[4:]
    else:
      unhandled_lang()
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
  # purposes (other than uk-noun), we remove everything (but still leave
  # primary accents).
  term = module.remove_non_primary_accents(term) if module else term
  headterm = term.split(",")
  term = remove_links(term).split(",")
  for t in term:
    check_stress(t)
    if "=" in t:
      error("Equal sign in term '%s', possible misplaced declension properties" % t)
  headterm_parts = []
  for num, ht in enumerate(headterm):
    if num == 0:
      headterm_parts.append(ht)
    else:
      headterm_parts.append("head%s=%s" % (num + 1, ht))
  headterm = "|".join(headterm_parts)
  if lang == "pt" and len(term) == 1 and term[0] == pagename:
    full_headterm = ""
  else:
    full_headterm = "|head=%s" % headterm

  # Handle etymology
  adjformtext = ""
  plformtext = ""
  etymheader = "===Etymology%s===\n" % (etymnum and " %s" % etymnum or "")
  if etym == "?":
    error("Etymology consists of bare question mark")
  elif etym == "??":
    etymtext = "%s{{unk|%s}}.\n\n" % (etymheader, lang)
  elif etym == "-":
    etymtext = "%s{{rfe|%s}}\n\n" % (etymheader, lang)
  elif etym == "--":
    if etymnum:
      etymtext = etymheader + "\n"
    else:
      etymtext = ""
  elif re.search(r"^(part|adj|partadj)([fnp]):", etym):
    m = re.search(r"^(part|adj|partadj)([fnp]):(.*)", etym)
    forms = {"f":["%s|f|s" % nomcase], "n":["%s|n|s" % nomcase], "p":["%s|p" % nomcase]}
    infleclines = ["# {{inflection of|%s|%s||%s}}" %
        (lang, m.group(3), form) for form in forms[m.group(2)]]
    if m.group(1) in ["adj", "partadj"]:
      adjinfltext = """===Adjective===
{{head|%s|adjective form%s}}

%s\n\n""" % (lang, full_headterm, "\n".join(infleclines))
    else:
      adjinfltext = ""
    if m.group(1) in ["part", "partadj"]:
      partinfltext = """===Participle===
{{head|%s|participle form%s}}

%s\n\n""" % (lang, full_headterm, "\n".join(infleclines))
    else:
      partinfltext = ""
    adjformtext = partinfltext + adjinfltext
    if etymnum:
      etymtext = etymheader + "\n"
    else:
      etymtext = ""
  elif re.search(r"^pl:", etym):
    m = re.search(r"^pl:(.*)", etym)
    forms = "%s|p" % nomcase
    inflecline = "# {{inflection of|%s|%s||%s}}" % (lang, m.group(1), forms)
    plformtext = """===Noun===
{{head|%s|noun form%s}}

%s\n\n""" % (lang, full_headterm, inflecline)
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
      etymtext = "Deverbal from {{m|%s|%s}}." % (lang, sourceterm)
    elif etym.startswith("ppp:"):
      _, sourceterm = do_split(":", etym)
      etymtext = "Past passive participle of {{m|%s|%s}}." % (lang, sourceterm)
    elif etym.startswith("back:"):
      _, sourceterm = do_split(":", etym)
      etymtext = "{{back-form|%s|%s}}" % (lang, sourceterm)
    elif etym.startswith("raw:"):
      etymtext = re.sub(", *", ", ", re.sub("^raw:", "", etym))
    elif etym.startswith("inh:"):
      _, inhlang, inhterm = do_split(":", etym)
      etymtext = "Inherited from {{inh|%s|%s|%s}}." % (lang, inhlang, inhterm)
    elif ":" in etym and "+" not in etym:
      nocap = False
      use_der = False
      if etym.startswith("?"):
        prefix = "Perhaps "
        nocap = True
        etym = re.sub(r"^\?", "", etym)
      elif etym.startswith("<<"):
        prefix = "Ultimately from "
        nocap = True
        use_der = True
        etym = re.sub(r"^<<", "", etym)
      else:
        prefix = ""
      m = re.search(r"^([a-zA-Z.-]+):(.*)", etym)
      if not m:
        error("Bad etymology form: %s" % etym)
      etymtext = "%s{{%s|%s|%s|%s%s}}." % (prefix, ("der" if use_der else "bor+"), lang, m.group(1), m.group(2),
        "|nocap=1" if nocap else "")
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
      if "{{" in etym:
        error("Saw {{ in etymology text, probably needs to be prefixed with 'raw:': %s" % etym)
      etymtext = "%s{{af|%s|%s}}%s" % (prefix or "From ", lang,
          "|".join(do_split(r"\+", re.sub(", *", ", ", etym))),
          suffix or ".")
    etymtext = "%s%s\n\n" % (etymheader, etymtext)

  # Create definition
  if re.search(opt_arg_regex, defns):
    error("Found optional-argument prefix in definition: %s" % defns)
  defntext, addlprops = generate_pos.generate_defn(defns, pos_to_full_pos[pos].lower(), lang)
  if not defntext:
    error(addlprops)
  split_defntext = re.split("'''", defntext)
  if len(split_defntext) % 2 == 0:
    error("Unmatched triple-quote in definition: %s" % defntext)

  # Create conjugation
  if pos == "v":
    if len(term) > 1:
      error("Multiple terms not currently supported: %s" % ",".join(term))
    if lang == "bg":
      # Bulgarian verb handling
      if aspect not in ["impf", "pf", "both"]:
        error("Bad aspect '%s', expected 'impf', 'pf' or 'both'" % aspect)
      reflexiveonly = False
      if conj.startswith("ro"):
        reflexiveonly = True
        conj = conj[2:]
      conjparts = conj.split(".")
      is_impers = "impers" in conjparts
      non_refl_verb = re.sub(" с[еи]$", "", term[0])
      if conjparts[0] in ["1", "2"]:
        if is_impers:
          if not re.search("[еи]́?$", non_refl_verb):
            error("Impersonal conjugation 1/2 verb %s should end in -е or -и" % term[0])
        else:
          if not re.search("[ая]́?$", non_refl_verb):
            error("Conjugation 1/2 verb %s should end in -а or -я" % term[0])
        conjclass = "%s.%s." % (conjparts[0], conjparts[1])
        restconjparts = conjparts[2:]
      elif conjparts[0] == "irreg":
        conjclass = "%s." % conjparts[0]
        restconjparts = conjparts[1:]
      else:
        if is_impers:
          if not re.search("[ая]$", non_refl_verb):
            error("Impersonal conjugation 3 verb %s should end in -а or -я" % term[0])
        else:
          if not re.search("[ая]м$", non_refl_verb):
            error("Conjugation 3 verb %s should end in -ам or -ям" % term[0])
        conjclass = ""
        restconjparts = conjparts
      has_transitivity = "tr" in restconjparts or "intr" in restconjparts
      is_reflexive = re.search(" (се|си)$", term[0])
      if (is_reflexive or reflexiveonly) and has_transitivity:
        error("Reflexive verb %s can't be specified as transitive or intransitive: %s" % (term[0], conj))
      elif not (is_reflexive or reflexiveonly) and not has_transitivity:
        error("Non-reflexive verb %s must be specified as transitive or intransitive: %s" % (term[0], conj))
      restconj = ".".join(restconjparts)
      conj = conjclass + aspect + (".%s" % restconj if restconj not in ["-", ""] else "")
      conjlines = []
      if not reflexiveonly:
        conjlines.append("{{bg-conj|%s<%s>}}" % (term[0], conj))
      oui = addlprops.get("oui", [])
      if ("(refl)" in defns or "(reflexive)" in defns or term[0] + " се" in oui) and not is_reflexive:
        reflconj = re.sub(r"\.(tr|intr)", "", conj)
        conjlines.append("{{bg-conj|%s се<%s>}}" % (term[0], reflconj))
      if ("(reflsi)" in defns or term[0] + " си" in oui) and not is_reflexive:
        reflconj = re.sub(r"\.(tr|intr)", "", conj)
        conjlines.append("{{bg-conj|%s си<%s>}}" % (term[0], reflconj))
      conjtext = "\n".join(conjlines)

    elif lang == "uk":
      # Ukrainian verb handling
      conjparts = conj.split(".")
      if not re.search("ти(с[яь])?$", term[0]):
        error("Term %s is supposed to be a verb but doesn't end that way" % term[0])
      non_refl_verb = re.sub("с[яь]$", "", term[0])
      if (conjparts[0] == "1a" and not re.search("[аяі]́?ти$", non_refl_verb) or
          conjparts[0] in ["2a", "2b"] and not re.search("[ую]ва́?ти$", non_refl_verb) or
          conjparts[0] == "3a" and not re.search("нути$", non_refl_verb) or
          conjparts[0] in ["3b", "3c"] and not re.search("ну́ти$", non_refl_verb) or
          conjparts[0] == "4a" and not re.search("[иї]ти$", non_refl_verb) or
          conjparts[0] in ["4b", "4c"] and not re.search("[иї]́ти$", non_refl_verb) or
          conjparts[0] in ["5a", "6a"] and not re.search("[аія]ти$", non_refl_verb) or
          conjparts[0] in ["5b", "5c", "6b", "6c"] and not re.search("[аія]́ти$", non_refl_verb)):
          error("Unrecognized ending for conjugation %s verb %s" % (conjparts[0], term[0]))
          if not re.search("[ая]м$", non_refl_verb):
            error("Conjugation 3 verb %s should end in -ам or -ям" % term[0])
      has_transitivity = "tr" in conjparts or "intr" in conjparts
      has_ppp_spec = "ppp" in conjparts or "-ppp" in conjparts
      is_reflexive = re.search("с[яь]$", term[0])
      if is_reflexive and has_transitivity:
        error("Reflexive verb %s can't be specified as transitive or intransitive: %s" % (term[0], conj))
      elif not is_reflexive and not has_transitivity:
        error("Non-reflexive verb %s must be specified as transitive or intransitive: %s" % (term[0], conj))
      if is_reflexive and has_ppp_spec:
        error("Reflexive verb %s can't be specified for having/not having a PPP: %s" % (term[0], conj))
      elif not is_reflexive and not has_ppp_spec and "tr" in conjparts:
        error("Non-reflexive transitive verb %s must be specified for having/not having a PPP: %s" % (term[0], conj))
      aspect = None
      for a in ["impf", "pf", "both"]:
        if a in conjparts:
          if aspect:
            error("Two aspects '%s' and '%s' seen for %s: %s" (aspect, a, term[0], conj))
          aspect = a
      if not aspect:
        error("No aspect in conjugation %s of term %s" % (conj, term[0]))
      conjtext = "{{%s-conj|%s<%s>}}" % (lang, term[0], conj)

    elif lang == "pt":
      if " " in term[0]:
        error("Can't handle spaces in term: %s" % term[0])
      # Portuguese verb handling
      is_reflexive = re.search("-se$", term[0])
      if conj == "<>":
        conj = ""
        hconjtext = ""
      else:
        hconjtext = "|" + conj
      conjlines = []
      conjlines.append("{{pt-conj%s}}" % hconjtext)
      if ("(refl)" in defns or "(reflexive)" in defns) and not is_reflexive:
        conjlines.append("{{pt-conj|%s-se%s}}" % (term[0], conj))
      conjtext = "\n".join(conjlines)

    else:
      unhandled_lang()

    if lang != "pt":
      if pairedverb != "-":
        hconjtext = "|%s=%s" % ("impf" if aspect == "pf" else "pf", pairedverb)
      else:
        hconjtext = ""
      hconjtext = aspect + hconjtext

  # Create declension
  is_invar_gender = None
  if pos in ["n", "pn", "adj"]:
    if lang == "bg" and decl.startswith("?!"):
      decl = decl[2:]
      attn_comp_text = "{{attn|bg|does this have a comparative?}}"
    else:
      attn_comp_text = ""
    if decl.startswith("inv:"):
      is_invar_gender = re.sub("^inv:", "", decl)
    else:
      if lang == "bg":
        # Bulgarian noun/adjective handling
        if "(m)" in decl:
          gender = "m"
        elif "(f)" in decl:
          gender = "f"
        elif "(n)" in decl:
          gender = "n"
        elif "/n:pl" in decl:
          gender = "p"
        elif re.search("[ая]́?$", term[0]):
          gender = "f"
        elif re.search("[еоиую]́?$", term[0]):
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
        noun_header_text = "%s|%s%s" % (headterm, gender, hdecltext)

      elif lang == "uk":
        # Ukrainian noun/adjective handling
        # decltext is the term+declension as used in the declension template,
        # hdecltext is the term+declension+extra props (such as |adv=го́ло)
        # as used in the headword template
        if decl.startswith("!"):
          decl = decl[1:]
          hdecltext = decl
        else:
          if len(term) > 1:
            error("With multiple terms, must use ! with explicit declension")
          if not decl.startswith("<"):
            error("Declension must start with '<' or '!': %s" % decl)
          if pos == "adj" and decl == "<>":
            decl = ""
          hdecltext = "%s%s" % (term[0], decl)
        # Eliminate masculine/feminine equiv, adjective/adverb, etc. from actual decl
        decltext = re.sub(r"\|([mf]|adv|absn|adj|dim|g)[0-9]*=[^|]*?(?=\||$)", "", hdecltext)
        noun_header_text = hdecltext
        # Eliminate declension from hdecltext
        hdecltext = re.sub(r"^.*?(?=\||$)", "", decl)

      elif lang == "pt":
        # Portuguese noun/adjective handling
        if decl == "-":
          if pos == "noun":
            error("Noun declension cannot be '-', but must include a gender")
          pt_header_text = ""
        else:
          pt_header_text = "|" + decl

      else:
        unhandled_lang()

  for t in term:
    if lang == "bg":
      if pos == "adj" and not is_invar_gender and re.search("[аеоуяю]́?$", t):
        error("Term %s is supposed to be an adjective but ends in vowel other than -и" % t)
    elif lang == "uk":
      if pos == "adj" and not is_invar_gender and not re.search("[оіїє]́?в$|[иії]́?[нй]$", t):
        error("Term %s is supposed to be an adjective but doesn't end in adjectival ending" % t)
    if lang != "pt":
      if pos == "adj" and not is_invar_gender and re.search("r\|(m|f|adj|g)", hdecltext):
        error("Term %s is supposed to be an adjective but has noun properties in the declension: %s" % (t, hdecltext))
      if pos == "n" and not is_invar_gender and re.search(r"\|(adv|absn)", hdecltext):
        error("Term %s is supposed to be a noun but has adjective properties in the declension: %s" % (t, hdecltext))

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
  reftext = ""
  cattext = ""
  filetext = ""
  if not pronuns:
    prontext = ""
  elif lang == "pt":
    if len(pronuns) == 1 and pronuns[0] == pagename:
      prontext = "{{pt-IPA}}\n"
    else:
      prontext = "{{pt-IPA|%s}}\n" % ",".join(pronuns)
  elif len(pronuns) > 1:
    prontext = "".join("* {{%s-IPA|%s|ann=y}}\n" % (lang, p) for p in pronuns)
  else:
    prontext = "* {{%s-IPA|%s}}\n" % (lang, pronuns[0])
  notetext = ""
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
            links.append("{{l|%s|%s}}" % (lang, synant))
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
      prons = do_split(",", vals)
      for pron in prons:
        check_stress(pron)
      if lang == "pt":
        prontext = "{{pt-IPA|%s}}\n" % ",".join(prons)
      elif len(prons) > 1:
        prontext = "".join("* {{%s-IPA|%s|ann=y}}\n" % (lang, p) for p in prons)
      else:
        prontext = "* {{%s-IPA|%s}}\n" % (lang, prons[0])
    elif sartype == "comp":
      comptext = ""
      for i, comp in enumerate(do_split(",", vals)):
        if i == 0:
          comptext += "|%s" % comp
        else:
          comptext += "|comp%s=%s" % (i + 1, comp)
    elif sartype == "note":
      vals = re.sub(r"\[\[(.*?)\]\]", r"{{m|%s|\1}}" % lang, vals)
      vals = re.sub(r"\(\((.*?)\)\)", r"{{m|%s|\1}}" % lang, vals)
      vals = re.sub(r"g\((.*?)\)", r"{{glossary|\1}}", vals)
      vals = re.sub(r",\s*", ", ", vals)
      notetext += " {{i|%s}}" % vals
    elif sartype == "tlb":
      defn, labels = generate_pos.parse_off_labels(vals)
      if defn:
        labels = labels + [defn]
      notetext += " {{tlb|%s|%s}}" % (lang, "|".join(labels))
    elif sartype == "alt":
      if "{{" in vals:
        alttext += "* %s\n" % vals
      else:
        alttext += "* {{alt|%s|%s}}\n" % (lang, vals.replace(",", "|"))
    elif lang != "pt" and sartype == "part":
      verbs, parttypes, partdecl = do_split(":", vals)
      infleclines = []
      for verb in do_split(",", verbs):
        for parttype in do_split(",", parttypes):
          infleclines.append("# {{%s-participle of|%s||%s}}" % (lang, verb, parttype))
      parttext = """===Participle===
{{head|%s|participle%s}}

%s\n\n""" % (lang, full_headterm, "\n".join(infleclines))
      if "adv" in parttype:
        partdecltext = ""
      elif len(term) > 1:
        error("Don't yet know how to handle participle with multiple terms")
      else:
        partdecltext = """====Declension====
{{%s-adecl|%s%s}}\n\n""" % (lang, term[0], partdecl)
      parttext += partdecltext
    elif sartype == "nadjf":
      check_stress(vals)
      nadjftext = """===Adjective===
{{head|%s|adjective form%s}}

# {{inflection of|%s|%s||%s|n|s}}\n\n""" % (lang, full_headterm, lang, vals, nomcase)
    elif sartype == "ppp":
      check_stress(vals)
      ppptext = """===Participle===
{{%s-part|%s|pass}}

# {{inflection of|%s|%s||%s|m|s|past|pass|part}}\n\n""" % (lang, headterm, lang, vals, nomcase)
    elif sartype == "wiki":
      for val in do_split(",", vals):
        if val:
          wikitext += "{{wikipedia|lang=%s|%s}}\n" % (lang, val)
        else:
          wikitext += "{{wikipedia|lang=%s}}\n" % lang
    elif sartype == "enwiki":
      assert vals
      for val in do_split(",", vals):
        enwikitext += "{{wikipedia|%s}}\n" % val
    elif sartype == "cat":
      assert vals
      cattext += "{{cln|%s|%s}}\n" % (lang, "|".join(do_split(",", vals)))
    elif sartype == "tcat":
      assert vals
      cattext += "{{topics|%s|%s}}\n" % (lang, "|".join(do_split(",", vals)))
    elif sartype == "ref":
      assert vals
      for val in do_split(",", vals):
        if lang == "pt" and val in ["Infopédia", "Priberam", "Michaelis", "Aulete", "Dicio"]:
          reftext += "* {{R:pt:%s}}\n" % val
        else:
          reftext += "* {{%s}}\n" % val
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
                links.append("{{l|%s|%s}}" % (lang, impfpfverbs[0]))
              else:
                links.append("{{l|%s|%s|g=impf}}" % (lang, impfpfverbs[0]))
              for pf in impfpfverbs[1:]:
                if "|" in pf:
                  links.append("{{l|%s|%s}}" % (lang, pf))
                else:
                  links.append("{{l|%s|%s|g=pf}}" % (lang, pf))
            elif derrel.startswith("{"):
              links.append(derrel)
            else:
              check_stress(derrel)
              links.append("{{l|%s|%s}}" % (lang, derrel))
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

  if alttext:
    alttext = "===Alternative forms===\n%s\n" % alttext
  if reftext:
    reftext = "===References===\n%s\n" % reftext
  if lang == "pt":
    if pos in ["n", "pn"]:
      maintext = """{{pt-%s%s}}%s

%s
""" % (pos_to_full_pos[pos].lower(), pt_header_text, notetext, defntext)
    elif pos == "adj":
      maintext = """{{pt-adj%s%s}}%s

%s
""" % (pt_header_text, comptext, notetext, defntext)
    elif pos == "adv":
      maintext = """{{pt-adv%s}}%s

%s
""" % (comptext, notetext, defntext)
    elif pos == "v":
      maintext = """{{pt-verb%s}}%s

%s
====Conjugation====
%s

""" % (hconjtext, notetext, defntext, conjtext)
    else:
      maintext = """{{head|%s|%s%s}}%s

%s
""" % (lang, pos_to_full_pos[pos].lower(), full_headterm, notetext, defntext)
  elif is_invar_gender:
    if pos == "n":
      maintext = """{{%s-noun|%s|%s|%s}}%s

%s
""" % (lang, headterm, is_invar_gender, "indecl=1" if lang == "bg" else "-", notetext, defntext)
    elif pos == "pn":
      maintext = """{{%s-proper noun|%s|%s|%s}}%s

%s
""" % (lang, headterm, is_invar_gender,  "indecl=1" if lang == "bg" else "-", notetext, defntext)
    elif pos == "adj":
      maintext = """{{%s-adj|%s|indecl=1}}

%s
""" % (lang, headterm, defntext)
    else:
      error("Invalid part of speech for indeclinable")
  else:
    if pos == "n":
      maintext = """{{%s-noun|%s}}%s

%s
====Declension====
{{%s-ndecl|%s}}

""" % (lang, noun_header_text, notetext, defntext, lang, decltext)
    elif pos == "pn":
      maintext = """{{%s-proper noun|%s}}%s

%s
====Declension====
{{%s-ndecl|%s}}

""" % (lang, noun_header_text, notetext, defntext, lang, decltext)
    elif pos == "adj":
      maintext = """{{%s-adj|%s%s}}%s

%s
====Declension====
{{%s-adecl|%s}}%s

""" % (lang, headterm, hdecltext, notetext, defntext, lang, decltext, attn_comp_text)
    elif pos == "v":
      maintext = """{{%s-verb|%s|%s}}%s

%s
====Conjugation====
%s

""" % (lang, headterm, hconjtext, notetext, defntext, conjtext)
    elif pos == "adv":
      maintext = """{{%s-adv|%s%s}}%s

%s
""" % (lang, headterm, comptext, notetext, defntext)
    else:
      full_pos = pos_to_full_pos[pos]
      maintext = """{{head|%s|%s%s}}%s

%s
""" % (lang, full_pos.lower(), full_headterm, notetext, defntext)

  if defns == "--":
    maintext = ""

  usagetext = "====Usage notes====\n%s\n\n" % "\n".join(usagelines) if usagelines else ""

  # If both adjective and participle header, or adverb and neuter-adjective inflection header,
  # move related-terms text and usage notes text to level 3
  if maintext and (parttext or nadjftext or ppptext) and reltext:
    reltext = re.sub("^====Related terms====", "===Related terms===", reltext)
    usagetext = re.sub("^====Usage notes====", "===Usage notes===", usagetext)

  # If any categories, put an extra newline after them so they end with two
  # newlines, as with other textual snippets
  if cattext:
    cattext += "\n"

  headertext = """%s==%s==
%s%s%s
""" % (alsotext, langname, enwikitext, wikitext, filetext)

  if prontext:
    prontext = "===Pronunciation===\n%s\n" % prontext
  if pronuns_at_top:
    assert etymnum == 1
    headertext = "%s%s" % (headertext, prontext)
    prontext = ""

  if etymnum:
    inside_etymtext = ""
  else:
    inside_etymtext = etymtext
  bodytext = """%s%s%s%s%s%s%s===%s===
%s%s%s%s%s%s%s%s%s""" % (
    alttext, inside_etymtext, prontext, parttext, ppptext, adjformtext, plformtext, pos_to_full_pos[pos],
    maintext, usagetext, syntext, anttext, dertext, nadjftext, reltext, seetext, reftext)
  if etymnum:
    bodytext = etymtext + increase_indent(bodytext)

  footertext = cattext

  return headertext, bodytext, footertext

peeker = generate_pos.Peeker(open(args.direcfile, "r", encoding="utf-8"))
nextpage = 0

def get_lemmas(line):
  line_els, pos = get_els_and_pos(line, lambda msg: fatal(line, msg))
  lemmas = line_els[0]
  starts_with_exclamation_point = False
  if lemmas.startswith("!"):
    starts_with_exclamation_point = True
    lemmas = lemmas[1:]
  lemmas = remove_links(lemmas).split(",")
  first_lemma_no_accents = module.remove_accents(lemmas[0]) if module else lemmas[0]
  prons = None
  for el in line_els:
    if el.startswith("pron:"):
      prons = do_split(",", el[5:])
      break
  return lemmas, first_lemma_no_accents, starts_with_exclamation_point, prons

while True:
  line = peeker.get_next_line()
  if line == None:
    break
  # Skip lines consisting entirely of comments
  if line.startswith("#"):
    continue
  line = line.strip()
  lemmas, first_lemma_no_accents, starts_with_exclamation_point, pronuns = get_lemmas(line)
  if starts_with_exclamation_point:
    fatal(line, "Out-of-place exclamation point in lemma: %s" % line)
  etym_sections = []
  etym_lines = [line]
  prev_pronuns = None
  pronuns = pronuns or lemmas
  pronuns_at_top = True

  while True:
    nextline = peeker.peek_next_line(0)
    if nextline == None:
      break
    # Skip lines consisting entirely of comments
    if nextline.startswith("#"):
      peeker.get_next_line()
      continue
    nextline = nextline.strip()
    nextline_lemmas, nextline_first_lemma_no_accents, starts_with_exclamation_point, nextline_prons = (
      get_lemmas(nextline)
    )
    if starts_with_exclamation_point and first_lemma_no_accents != nextline_first_lemma_no_accents:
      fatal(line, "If lemma %s starts with exclamation point, it must be the same as previous lemma %s without accents" % (
        ",".join(nextline_lemmas), ",".join(lemmas)))
    if first_lemma_no_accents != nextline_first_lemma_no_accents:
      break
    if not starts_with_exclamation_point:
      etym_sections.append((etym_lines, pronuns))
      if prev_pronuns and set(prev_pronuns) != set(pronuns):
        pronuns_at_top = False
      prev_pronuns = pronuns
      etym_lines = []
      pronuns = []
    etym_lines.append(nextline)
    if nextline_prons:
      pronuns = nextline_prons
    else:
      for l in nextline_lemmas:
        if l not in pronuns:
          pronuns.append(l)
    peeker.get_next_line()

  if etym_lines:
    etym_sections.append((etym_lines, pronuns))
    if prev_pronuns and set(prev_pronuns) != set(pronuns):
      pronuns_at_top = False

  nextpage += 1

  def output_page(text):
    msg("Page %s %s: ------- begin text --------\n%s\n------- end text --------" % (
      nextpage, first_lemma_no_accents, text.rstrip("\n")))

  overall_headertext = ""
  overall_bodytext = ""
  overall_footertext = ""
  for etymnum, (etym_section, pronuns) in enumerate(etym_sections):
    for lemmanum, lemmaline in enumerate(etym_section):
      skip_pronun = lemmanum > 0 or pronuns_at_top and etymnum > 0
      headertext, bodytext, footertext = process_line(lemmaline, first_lemma_no_accents,
          None if len(etym_sections) == 1 or lemmanum > 0 else etymnum + 1,
          None if skip_pronun else pronuns,
          pronuns_at_top and etymnum == 0 and len(etym_sections) > 1)
      if etymnum == 0 and lemmanum == 0:
        overall_headertext = headertext
      overall_bodytext += bodytext
      overall_footertext += footertext
  output_page("%s%s%s" % (overall_headertext, overall_bodytext, overall_footertext))
