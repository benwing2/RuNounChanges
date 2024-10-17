#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, msg, site

blib.getData()

lang_letter = "[\w,-]"
lang_letter_or_space = "[\w, -]"

# Compile a map from etym language code to its corresponding full language.
etym_language_to_parent = {}
for code, spec in blib.etym_languages_byCode.items():
  if "full" in spec: # etym-lang families don't have the key "full"
    etym_language_to_parent[code] = spec["full"]

# Compile a map from all language names (including for etym languages) to a tuple
# (LANGCODES, ETYMCODE, ISETYMCANON) where LANGCODES is a list of zero or more
# tuples of (CODE, ISCANON) where CODE is a non-etym lang code and ISCANON is True
# if this language name is the canonical name of that code; ETYMCODE is the best etym
# code associated with this language name or None if no etym codes associated with
# this language name, and ISETYMCANON is True if the language name is the canonical
# name of ETYMCODE. We accumulate the list of all non-etym lang codes because we have
# the non-etym lang code specified already and need to match, but need to adjudicate
# among multiple codes for a given etym language because we have to pick one code to
# use when the language name is encountered.
language_name_to_code = {}
def add_name_with_code(name, code, iscanon, isetym):
  if name in language_name_to_code:
    langcodes, otheretymcode, otherisetymcanon = language_name_to_code[name]
    if not isetym:
      langcodes.append((code, iscanon))
    elif otheretymcode is None:
      language_name_to_code[name] = (langcodes, code, iscanon)
    else:
      if iscanon and not otherisetymcanon:
        msg("Preferring new %s over existing %s because their name %s is the canonical name of new %s but not existing %s" % (
          code, otheretymcode, name, code, otheretymcode))
        setnew = True
      elif otherisetymcanon and not iscanon:
        msg("Preferring existing %s over new %s because their name %s is the canonical name of existing %s but not new %s" % (
          otheretymcode, code, name, otheretymcode, code))
        setnew = False
      elif re.search("^[a-z][a-z]$", code):
        msg("Preferring new %s over existing %s (name %s) because new %s looks like a two-letter regular language code" % (
          code, otheretymcode, name, code))
        setnew = True
      elif re.search("^[a-z][a-z]$", otheretymcode):
        msg("Preferring existing %s over new %s (name %s) because existing %s looks like a two-letter regular language code" % (
          otheretymcode, code, name, otheretymcode))
        setnew = False
      elif re.search("^[a-z][a-z][a-z]$", code):
        msg("Preferring new %s over existing %s (name %s) because new %s looks like a regular three-letter language code" % (
          code, otheretymcode, name, code))
        setnew = True
      elif re.search("^[a-z][a-z][a-z]$", otheretymcode):
        msg("Preferring existing %s over new %s (name %s) because existing %s looks like a regular three-letter language code" % (
          otheretymcode, code, name, otheretymcode))
        setnew = False
      elif "-" in code:
        msg("Preferring new %s over existing %s (name %s) because new %s has a hyphen in it" % (
          code, otheretymcode, name, code))
        setnew = True
      elif "-" in otheretymcode:
        msg("Preferring existing %s over new %s (name %s) because existing %s has a hyphen in it" % (
          otheretymcode, code, name, otheretymcode))
        setnew = False
      elif "." in code:
        msg("Preferring new %s over existing %s (name %s) because new %s has a period in it" % (
          code, otheretymcode, name, code))
        setnew = True
      elif "." in otheretymcode:
        msg("Preferring existing %s over new %s (name %s) because existing %s has a period in it" % (
          otheretymcode, code, name, otheretymcode))
        setnew = False
      elif len(code) < len(otheretymcode):
        msg("Preferring new %s over existing %s (name %s) because new %s is shorter" % (
          code, otheretymcode, name, code))
        setnew = True
      elif len(otheretymcode) < len(code):
        msg("Preferring existing %s over new %s (name %s) because existing %s is shorter" % (
          otheretymcode, code, name, otheretymcode))
        setnew = False
      else:
        msg("Preferring new %s over existing %s (name %s) because %s is new" % (
          code, otheretymcode, name, code))
        setnew = True
      if setnew:
        language_name_to_code[name] = (langcodes, code, iscanon)
  else:
    if isetym:
      language_name_to_code[name] = ([], code, iscanon)
    else:
      language_name_to_code[name] = ([(code, iscanon)], None, None)

for code, desc in blib.languages_byCode.items():
  add_name_with_code(desc["canonicalName"], code, True, False)
  if "aliases" in desc:
    for alias in desc["aliases"]:
      add_name_with_code(alias, code, False, False)
  # Not safe to add otherNames, which may be varieties, and information will be lost. E.g.
  # Replacing <Jèrriais {{m|nrf|lanchi}}> with <{{cog|nrf|lanchi}}> (BAD).
  #if "otherNames" in desc:
  #  for othername in desc["otherNames"]:
  #    add_name_with_code(othername, code, False, False)
for code, desc in blib.etym_languages_byCode.items():
  add_name_with_code(desc["canonicalName"], code, True, True)
  if "aliases" in desc:
    for alias in desc["aliases"]:
      add_name_with_code(alias, code, False, True)
  # Not safe to add otherNames, which may be varieties, and information will be lost.
  #if "otherNames" in desc:
  #  for othername in desc["otherNames"]:
  #    add_name_with_code(othername, code, False, True)

# 2024-10-15: temporary hack for recently renamed language Venetian -> Venetan (still in dump)
if "Venetan" in language_name_to_code:
  language_name_to_code["Venetian"] = language_name_to_code["Venetan"]

def process_text_on_page(index, pagetitle, pagetext):
  global args
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  notes = []

  if not args.stdin:
    pagemsg("Processing")

  # Split into (sub)sections
  splitsections = re.split("(^===*[^=\n]+=*==\n)", pagetext, 0, re.M)
  # Extract off pagehead and recombine section headers with following text
  pagehead = splitsections[0]
  sections = []
  for i in range(1, len(splitsections)):
    if (i % 2) == 1:
      sections.append("")
    sections[-1] += splitsections[i]

  def replace_with_cog(m):
    at_beg, cogs, at_end = m.groups()
    origtext = m.group(0)
    warnings = []
    def warning(txt):
      warnings.append(txt)
    # {{etyl}} is obsolete
    #if langname.startswith("{{etyl"):
    #  mm = re.search(r"^\{\{etyl\|(.*?)\|-\}\}$", langname)
    #  if not mm:
    #    warning("Something wrong, can't match template call %s" % langname)
    #    return origtext
    #  etym_langcode = mm.group(1)
    #  if etym_langcode != langcode and etym_language_to_parent.get(etym_langcode, "NONE") != langcode:
    #    pagemsg("WARNING: Mismatched language codes, saw %s vs. %s in %s {{m|%s|...}}"
    #      % (etym_langcode, langcode, langname, langcode))
    #    return origtext
    #  if langcode != etym_langcode:
    #    pagemsg("Using etym language code %s in place of parent %s" % (
    #      etym_langcode, langcode))
    #  newtext = "%s%s%s{{cog|%s|" % (punct, cognate_with, cog, etym_langcode)
    #  pagemsg("Replacing <%s> with <%s>" % (origtext, newtext))
    #  return newtext

    raw_cognates = re.split("([A-Z]%s+(?: %s+)*? +\{\{(?:[ml]|term)\|[A-Za-z0-9.-]+\|(?:[^{}]|\{\{[^{}]*?\}\})*\}\})" % (
      lang_letter, lang_letter), cogs, 0, re.U)
    processed_parts = []
    for i, raw_cognate_part in enumerate(raw_cognates):
      if i % 2 == 0:
        processed_parts.append(raw_cognate_part)
      else:
        def process():
          m = re.search("^([A-Z]%s+(?: %s+)*?) +\{\{(?:[ml]|term)\|([A-Za-z0-9.-]+)(\|(?:[^{}]|\{\{[^{}]*?\}\})*\}\})$" % (
            lang_letter, lang_letter), raw_cognate_part, re.U)
          assert m
          raw_langname, langcode, guts = m.groups()
          dialectal = ""
          langname = raw_langname
          # Remove stray comma at end, which appears occasionally.
          langname = re.sub(" *, *$", "", langname)
          if " and " in langname or ", " in langname:
            langnames = re.split("(?:,* and |, )", langname)
          else:
            m = re.search("^dialectal (.*)$", langname)
            if m:
              langname = m.group(1)
              dialectal = "dialectal "
            if not m:
              m = re.search("^(.*) dialect(?:al)?$", langname)
              if m:
                langname = m.group(1)
                dialectal = "dialectal "
            langnames = [langname]
          langcodes = []
          langcodes_for_checking = []
          if langcode in blib.language_aliases_to_canonical:
            langcode = blib.language_aliases_to_canonical[langcode]
          langname_code_info = []
          for langname in langnames:
            if langname not in language_name_to_code:
              warning("Saw unrecognized lang name <%s> (lang code=%s)" % (langname, langcode))
              return raw_cognate_part
            this_langcodes, etymcode, isetymcanon = language_name_to_code[langname]
            langname_code_info.append((langname, language_name_to_code[langname]))
            is_etym_lang = not not etymcode
            is_etym_lang_matching_langcode = is_etym_lang and (
              etymcode == langcode or
              etym_language_to_parent[etymcode] == langcode
            )
            is_non_etym_lang = False
            is_non_etym_lang_canon = False
            is_non_etym_lang_matching_langcode = False
            is_non_etym_lang_canon_matching_langcode = False
            best_non_etym_code = None
            for code, iscanon in this_langcodes:
              is_non_etym_lang = True
              is_non_etym_lang_canon = is_non_etym_lang_canon or iscanon
              if langcode == code:
                best_non_etym_code = code
                is_non_etym_lang_matching_langcode = True
                is_non_etym_lang_canon_matching_langcode = iscanon
                break
              elif iscanon or best_non_etym_code is None:
                best_non_etym_code = code
            if etymcode and best_non_etym_code:
              pagemsg("NOTE: Language name could be both etym lang %s (canon=%s) and non-etym lang %s (canon=%s)" % (
                etymcode, isetymcanon, best_non_etym_code, is_non_etym_lang_canon))
            use_etym_code = False
            if is_etym_lang_matching_langcode:
              use_etym_code = (
                not is_non_etym_lang_matching_langcode or isetymcanon or not is_non_etym_lang_canon_matching_langcode
              )
            elif is_etym_lang:
              use_etym_code = (
                not is_non_etym_lang or isetymcanon or not is_non_etym_lang_canon
              )
            if use_etym_code:
              pagemsg("Using etym language code %s for %s language name %s" % (
                etymcode, "canonical" if isetymcanon else "non-canonical", langname))
              langcode_to_use = etymcode
            else:
              assert is_non_etym_lang
              langcode_to_use = best_non_etym_code
              pagemsg("Using full language code %s for %s language name %s" % (
                best_non_etym_code, "canonical" if is_non_etym_lang_canon else "non-canonical", langname))
            langcodes.append(langcode_to_use)
            langcodes_for_checking.append(langcode_to_use)
            if use_etym_code:
              langcodes_for_checking.append(etym_language_to_parent[etymcode])
          if langcode not in langcodes_for_checking:
            def expected(this_langcodes, etymcode):
              return (etymcode and "lang code(s) %s or etym-lang parent lang code %s" % (
                  ",".join([code for code, _ in this_langcodes] + ([etymcode] if etymcode else [])),
                  etym_language_to_parent[etymcode]) or
                "lang code(s) %s" % ",".join(code for code, _ in this_langcodes))
            if len(langnames) == 1:
              warning("lang name <%s> isn't a name of lang code %s or any etym language descending from it; expected %s" % (
                langname, langcode, expected(this_langcodes, etymcode)))
            else:
              warning("none of the lang names <%s> are a name of lang code %s or an etym language descending from it; expected %s" % (
                ",".join(langnames), langcode, "; ".join(
                  "%s: %s" % (langname, expected(this_langcodes, etymcode))
                  for langname, (this_langcodes, etymcode, _) in langname_code_info)))
            return raw_cognate_part
          notes.append("use %s{{cog|%s|...}} for cognates in place of %s {{m|%s|...}}" % (
            dialectal, ",".join(langcodes), raw_langname, langcode))
          return "%s{{cog|%s%s" % (dialectal, ",".join(langcodes), guts)
        processed_parts.append(process())
    newtext = "".join(processed_parts)
    if cogs != newtext:
      pagemsg("Replacing <%s> with <%s>" % (cogs, newtext))
    if warnings:
      warntxt = "; ".join(warnings)
      if args.begin_end:
        pagemsg("WARNING: %s; <begin> %s <end>" % (warntxt, origtext))
      else:
        pagemsg("WARNING: %s" % warntxt)
    return "%s%s%s" % (at_beg, newtext, at_end)

  # Go through each section in turn, looking for Etymology sections

  #match_etyl_re_arm = r"|\{\{etyl\|[A-Za-z0-9.-]+\|-\}\}"
  match_etyl_re_arm = ""
  match_cognate_re = r"^(.*?(?:^|[;:,.] +|\()(?:[Aa]lso +)?(?:[Cc]ognate +(?:with +|of +|to +)|[Cc]ognates +include +|(?:[Cc]ompare|[Cc]f\.) +(?:with +|to +)?)(?:also +)?(?:the +)?)((?:(?:(?:[A-Z]%s+(?: %s+)*? +)?\{\{(?:cog|[ml]|term)\|[A-Za-z0-9.,-]+\|(?:[^{}]|\{\{[^{}]*?\}\})*\}\}|[A-Z]%s+(?: %s+)*? +'''?\[*%s+(?:\|%s+)?\]*'''?)[,;]? *(?:(?:and|or) +(?:also +)?|/ *)?)*[A-Z]%s+(?: %s+)*?%s +\{\{(?:[ml]|term)\|[A-Za-z0-9.-]+\|(?:[^{}]|\{\{[^{}]*?\}\})*\}\})(.*?)$" % (
    lang_letter, lang_letter, lang_letter, lang_letter, lang_letter_or_space, lang_letter_or_space, lang_letter,
    lang_letter, match_etyl_re_arm)
  for i in range(len(sections)):
    if re.match("^===*Etymology( [0-9]+)?=*==", sections[i]):
      text = sections[i]
      while True:
        new_text = re.sub(match_cognate_re, replace_with_cog, text, 0, re.M | re.U)
        if new_text == text:
          break
        sections[i] = new_text
        text = new_text

  return pagehead + "".join(sections), notes

if __name__ == "__main__":
  parser = blib.create_argparser("Use {{cog}} for cognates in place of LANG {{m|CODE|...}}",
    include_pagefile=True, include_stdin=True)
  parser.add_argument("--begin-end",
    help="""Output in begin-end format for use with push_manual_changes.py.""",
    action="store_true")
  args = parser.parse_args()
  start, end = blib.parse_start_end(args.start, args.end)

  blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True, default_refs=["Template:m"], ref_namespaces=[0])
