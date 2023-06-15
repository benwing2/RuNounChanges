#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

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

def process_text_on_page(index, pagetitle, pagetext):
  global args
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  if not args.stdin:
    pagemsg("Processing")

  notes = []

  # Split into (sub)sections
  splitsections = re.split("(^===*[^=\n]+=*==\n)", pagetext, 0, re.M)
  # Extract off pagehead and recombine section headers with following text
  pagehead = splitsections[0]
  sections = []
  for i in range(1, len(splitsections)):
    if (i % 2) == 1:
      sections.append("")
    sections[-1] += splitsections[i]

  def m_und_uder(m):
    destcode, sourcecode, term_code = m.groups()
    origtext = m.group(0)
    if destcode in blib.families_byCode or etym_language_to_parent.get(destcode, "NONE") in blib.families_byCode:
      pass
    else:
      pagemsg("WARNING: Saw {{etyl|%s|%s}} {{m|und|...}} where destination is not a family, not changing" %
        (destcode, sourcecode))
      return origtext
    newtext = "{{uder|%s|%s}}%s" % (sourcecode, destcode, term_code)
    notes.append("replace {{etyl|...}} for destination family (+ {{m|und|...}}) with {{uder|%s|%s}}" %
        (sourcecode, destcode))
    pagemsg("Replacing <%s> with <%s> for destination family with 'und' term code" % (origtext, newtext))
    return newtext

  def replace_with_uder(m):
    etyltemp, m_langcode, vbar = m.groups()
    origtext = m.group(0)
    mm = re.search(r"^\{\{etyl\|(.*?)\|(.*?)\}\}$", etyltemp)
    if not mm:
      pagemsg("WARNING: Something wrong, can't match template call %s" % etyltemp)
      return origtext
    etym_langcode, from_langcode = mm.groups()
    if etym_langcode != m_langcode:
      display_msg = False
      if (etym_langcode in blib.etym_languages_byCode and m_langcode in blib.etym_languages_byCode
          and blib.etym_languages_byCode[etym_langcode]["canonicalName"] == blib.etym_languages_byCode[m_langcode]["canonicalName"]):
        pagemsg("Saw etym lang %s in {{etyl}} and etym lang %s in {{m}}, which are aliases of each other"
            % (etym_langcode, m_langcode))
        display_msg = True
      elif m_langcode == from_langcode:
        pagemsg("WARNING: Saw source language code %s as destination, assuming a mistake, using destination %s" % (
          from_langcode, etym_langcode))
      elif etym_language_to_parent.get(etym_langcode, "NONE") != m_langcode:
        pagemsg("WARNING: Mismatched language codes, saw %s vs. %s in %s {{m|%s|...}}"
          % (etym_langcode, m_langcode, etyltemp, m_langcode))
        return origtext
      else:
        display_msg = True
      if display_msg:
        pagemsg("Using etym language code %s in place of parent or alias %s" % (
          etym_langcode, m_langcode))
    newtext = "{{uder|%s|%s|" % (from_langcode, etym_langcode)
    notes.append("absorb {{etyl|...}} {{m|...}} into {{uder|%s|%s}}" % (from_langcode, etym_langcode))
    pagemsg("Replacing <%s> with <%s>, absorbing {{m|..." % (origtext, newtext))
    return newtext

  def swap_etyl_uder(m):
    destcode, sourcecode = m.groups()
    origtext = m.group(0)
    newtext = "{{uder|%s|%s|-}}" % (sourcecode, destcode)
    notes.append("swap {{etyl|...}} into {{uder|%s|%s}}" % (sourcecode, destcode))
    pagemsg("Replacing <%s> with <%s>, swapping langcodes" % (origtext, newtext))
    return newtext

  # Go through each section in turn, looking for Etymology sections
  for i in range(len(sections)):
    if re.match("^===*Etymology( [0-9]+)?=*==", sections[i]):
      text = sections[i]
      # First try for {{etyl|DESTFAMILY|SOURCE}} {{m|und|...
      while True:
        new_text = re.sub(r"\{\{etyl\|([A-Za-z0-9.-]+)\|([A-Za-z0-9.-]+)\}\}( +\{\{(?:m|mention)\|und\|)",
          m_und_uder, text, 0, re.M)
        if new_text == text:
          break
        sections[i] = new_text
        text = new_text
      # First try for {{etyl|DEST|SOURCE}} {{m|SOURCE|...
      while True:
        new_text = re.sub(r"(\{\{etyl\|[A-Za-z0-9.-]+\|[A-Za-z0-9.-]+\}\})(?: +\{\{(?:m|mention)\|)([A-Za-z0-9.-]+)(\|)",
          replace_with_uder, text, 0, re.M)
        if new_text == text:
          break
        sections[i] = new_text
        text = new_text
      # Then do remaining {{etyl|DEST|SOURCE}} not followed by {{m|...
      while True:
        new_text = re.sub(r"\{\{etyl\|([A-Za-z0-9.-]+)\|([A-Za-z0-9.-]+)\}\}(?! +\{\{(?:m|mention)\|)",
          swap_etyl_uder, text, 0, re.M)
        if new_text == text:
          break
        sections[i] = new_text
        text = new_text

  return pagehead + "".join(sections), notes

if __name__ == "__main__":
  parser = blib.create_argparser("Replace {{etyl}} with {{uder}}", include_pagefile=True, include_stdin=True)
  args = parser.parse_args()
  start, end = blib.parse_start_end(args.start, args.end)

  blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True, default_refs=["Template:etyl"], ref_namespaces=[0])
