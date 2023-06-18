#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, msg, site

blib.getData()

# Compile a map from etym language code to its first non-etym-language ancestor.
etym_language_to_parent = {}
for code in blib.etym_languages_byCode:
  parent = code
  while parent in blib.etym_languages_byCode:
    parent = blib.etym_languages_byCode[parent]["parent"]
  etym_language_to_parent[code] = parent

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

for code, desc in blib.languages_byCode.iteritems():
  add_name_with_code(desc["canonicalName"], code, True, False)
  for othername in desc["otherNames"]:
    add_name_with_code(othername, code, False, False)
for code, desc in blib.etym_languages_byCode.iteritems():
  add_name_with_code(desc["canonicalName"], code, True, True)
  for othername in desc["otherNames"]:
    add_name_with_code(othername, code, False, True)

def process_text_on_page(index, pagetitle, pagetext):
  global args
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

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
    punct, cognate_with, cog, langname, tempname, langcode, vbar = m.groups()
    origtext = m.group(0)
    if langname.startswith("{{etyl"):
      mm = re.search(r"^\{\{etyl\|(.*?)\|-\}\}$", langname)
      if not mm:
        pagemsg("WARNING: Something wrong, can't match template call %s" % langname)
        return origtext
      etym_langcode = mm.group(1)
      if etym_langcode != langcode and etym_language_to_parent.get(etym_langcode, "NONE") != langcode:
        pagemsg("WARNING: Mismatched language codes, saw %s vs. %s in %s {{m|%s|...}}"
          % (etym_langcode, langcode, langname, langcode))
        return origtext
      if langcode != etym_langcode:
        pagemsg("Using etym language code %s in place of parent %s" % (
          etym_langcode, langcode))
      newtext = "%s%s%s{{cog|%s|" % (punct, cognate_with, cog, etym_langcode)
      pagemsg("Replacing <%s> with <%s>" % (origtext, newtext))
      return newtext

    if langname not in language_name_to_code:
      pagemsg("WARNING: Saw unrecognized lang name <%s> (lang code=%s)" % (
        langname, langcode))
      return origtext
    langcodes, etymcode, isetymcanon = language_name_to_code[langname]
    is_etym_lang = etymcode and etym_language_to_parent[etymcode] == langcode
    is_non_etym_lang_canon = False
    is_non_etym_lang = False
    for code, iscanon in langcodes:
      if langcode == code:
        is_non_etym_lang = True
        is_non_etym_lang_canon = iscanon
        break
    if is_etym_lang and is_non_etym_lang:
      pagemsg("NOTE: Language name could be both etym lang %s (canon=%s) and non-etym lang %s (canon=%s)" % (
        etymcode, isetymcanon, langcode, is_non_etym_lang_canon))
    if is_etym_lang and (not is_non_etym_lang or isetymcanon or not is_non_etym_lang_canon):
      pagemsg("Using etym language code %s in place of parent %s for language name %s" % (
        etymcode, langcode, langname))
      langcode_to_use = etymcode
    elif is_non_etym_lang:
      langcode_to_use = langcode
    else:
      pagemsg("WARNING: lang name <%s> isn't a name of lang code %s or any etym language descending from it; expected %s" % (
        langname, langcode,
        langcodes and etymcode and "lang code(s) %s or etym parent lang code %s" % (
          ",".join(code for code, _ in langcodes), etym_language_to_parent[etymcode]) or
        langcodes and "lang code(s) %s" % ",".join(code for code, _ in langcodes) or
        "etym parent lang code %s" % etym_language_to_parent[etymcode]))
      return origtext
    newtext = "%s%s%s{{cog|%s|" % (punct, cognate_with, cog, langcode_to_use)
    pagemsg("Replacing <%s> with <%s>" % (origtext, newtext))
    return newtext

  # Go through each section in turn, looking for Etymology sections
  for i in range(len(sections)):
    if re.match("^===*Etymology( [0-9]+)?=*==", sections[i]):
      text = sections[i]
      while True:
        new_text = re.sub(r"(^|[;:,.] +|\()((?:[Aa]lso +)?(?:[Cc]ognate +(?:with +|of +|to +)|[Cc]ognates +include +|[Cc]ompare +(?:with +|to +)?)(?:also +)?(?:the +)?)((?:\{\{(?:cog|[ml]|term)\|[A-Za-z0-9.-]+\|(?:[^{}]|\{\{[^{}]*?\}\})*\}\},? *(?:(?:and|or) +(?:also +)?|/ *)?)*?)([A-Z][A-Za-z-]+(?: [A-Za-z-]+)*?|\{\{etyl\|[A-Za-z0-9.-]+\|-\}\})( +\{\{(?:[ml]|term)\|)([A-Za-z0-9.-]+)(\|)",
          replace_with_cog, text, 0, re.M)
        if new_text == text:
          break
        sections[i] = new_text
        text = new_text

  return pagehead + "".join(sections), "Use {{cog}} for cognates in place of LANG {{m|CODE|...}} or {{etyl|CODE|-}} {{m|CODE|...}}"

if __name__ == "__main__":
  parser = blib.create_argparser("Use {{cog}} for cognates in place of LANG {{m|CODE|...}} or {{etyl|CODE|-}} {{m|CODE|...}}",
    include_pagefile=True, include_stdin=True)
  args = parser.parse_args()
  start, end = blib.parse_start_end(args.start, args.end)

  blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True, default_refs=["Template:m"], ref_namespaces=[0])
