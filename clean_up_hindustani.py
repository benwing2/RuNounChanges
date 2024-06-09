#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, tname, pname, msg, site

def process_text_on_page(index, pagetitle, text):
  global args
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  notes = []

  retval = blib.find_modifiable_lang_section(text, None if args.partial_page else args.langname, pagemsg,
    force_final_nls=True)
  if retval is None:
    return
  sections, j, secbody, sectail, has_non_lang = retval

  subsections = re.split("(^==+[^=\n]+==+\n)", secbody, 0, re.M)

  subsections, subsections_by_header, subsection_headers, subsection_levels = blib.split_text_into_subsections(
      secbody, pagemsg)
  for desc_ind in subsections_by_header.get("Descendants", []):
    lines = subsections[desc_ind].split("\n")
    prev_is_hindustani = False
    prev_hindustani_stars = ""
    prev_hindustani_bor = False
    prev_hindustani_der = False
    prev_hindustani_tr = None
    for lineind, line in enumerate(lines):
      def linemsg(txt):
        pagemsg("Descendants line %s: %s" % (lineind + 1, txt))
      m = re.search(r"^([*:]*)", line)
      initial_stars = m.group(1)
      if prev_is_hindustani and len(initial_stars) <= len(prev_hindustani_stars):
        prev_is_hindustani = False
      m = re.search(r"^[*:]*\s*\{\{desc\|(hi|ur)\|", line)
      if m:
        if not prev_is_hindustani:
          linemsg("WARNING: Saw Hindi/Urdu descendant not under Hindustani: %s" % line)
        else:
          expected_initial_stars = prev_hindustani_stars + ":"
          if expected_initial_stars != initial_stars:
            pagemsg("Convert initial stars for Hindi/Urdu descendant under Hindustani label from %s to %s" % (
              initial_stars, expected_initial_stars))
            notes.append("correct initial stars for Hindi/Urdu descendant under Hindustani label")
            initial_stars = expected_initial_stars

      m = re.search(r"^([*:]*)\s*\{*([→⇒]?)\}*\s*Hindustani:*(.*)$", line)
      if m:
        initial_stars, arrow, after = m.groups()
        if arrow == "→":
          bor_der = "|bor=1"
        elif arrow == "⇒":
          bor_der = "|der=1"
        else:
          bor_der = ""
        after = after.strip()
        if after:
          after = " " + after
        newline = "%s {{desc|inc-hnd%s|-}}%s" % (initial_stars, bor_der, after)
        pagemsg("Replace <%s> with <%s>" % (line, newline))
        notes.append("templatize 'Hindustani' in Descendants section")
        line = newline
      m = re.search(r"^([*:]*)\s*(\{\{desc\|ind-hnd\b[^{}]*\}\})(.*)$", line)
      if m:
        initial_stars, hindustani_template, after = m.groups()
        hindustani_t = list(blib.parse_text(hindustani_template).filter_templates())[0]
        assert tname(hindustani_t) == "desc"
        def getp(param):
          return getparam(t, param)
        if getp("1") != "inc-hnd":
          linemsg("WARNING: Something likely wrong, saw Hindustani descendant template with wrong lang code: %s" % line)
          continue
        prev_is_hindustani = True
        if getp("2") != "-":
          pagemsg("WARNING: Saw Hindustani descendant without - in 2=: %s" % str(t))
        prev_hindustani_bor = getp("bor")
        prev_hindustani_der = getp("der")
        prev_hindustani_stars = initial_stars
        after = after.strip()
        if "{" in after:
          pagemsg("WARNING: Template follows Hindustani descendant template, not removing: %s" % line)
          prev_hindustani_tr = ""
          newline = "%s %s %s" % (initial_stars, str(hindustani_t), after)
          if newline != line:
            pagemsg("Replace <%s> with <%s>" % (line, newline))
            notes.append("clean Hindustani descendant template")
          continue
        prev_hindustani_tr = after
        newline = "%s %s" % (initial_stars, str(hindustani_t))
        if newline != line:
          pagemsg("Replace <%s> with <%s>" % (line, newline))
          if after:
            notes.append("clean Hindustani descendant template, removing trailing translit")
          else:
            notes.append("clean Hindustani descendant template")
        continue


  secbody = "".join(subsections)
  # Strip extra newlines added to secbody
  sections[j] = secbody.rstrip("\n") + sectail
  if args.langname == "Italian": # why this special case?
    newsecj = re.sub(r"(\{\{it-noun[^{}]*\}\}\n)([^\n])", r"\1" + "\n" + r"\2", sections[j])
    if newsecj != sections[j]:
      notes.append("add missing newline after {{it-noun}}")
      sections[j] = newsecj
  text = "".join(sections)
  newtext = re.sub(r"\n\n\n+", "\n\n", text)
  if text != newtext:
    notes.append("convert 3+ newlines to 2 newlines")
  text = newtext
  return text, notes

parser = blib.create_argparser("Move {{wikipedia}} lines to top of etym section",
  include_pagefile=True, include_stdin=True)
parser.add_argument("--partial-page", action="store_true", help="Input was generated with 'find_regex.py --lang LANG' and has no ==LANG== header.")
parser.add_argument("--langname", help="Only do this language name (optional).")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True)
