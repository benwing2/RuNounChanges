#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, tname, msg, site

import lalib

def process_page(page, index, headword_template, decl_template):
  pagetitle = str(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  text = str(page.text)
  origtext = text

  retval = lalib.find_latin_section(text, pagemsg)
  if retval is None:
    return None, None

  sections, j, secbody, sectail, has_non_latin = retval

  notes = []

  parsed = blib.parse_text(secbody)
  num_noun_headword_templates = 0
  num_ndecl_templates = 0
  num_adecl_templates = 0
  for t in parsed.filter_templates():
    tn = tname(t)
    if tn in ["la-noun", "la-proper noun"]:
      num_noun_headword_templates += 1
    if tn == "la-ndecl":
      num_ndecl_templates += 1
    if tn == "la-adecl":
      num_adecl_templates += 1
    # FIXME, also add something for manually-specified declensions (synaeresis?)
  if "\n===Declension===\n" in secbody:
    pagemsg("WARNING: Saw misindented Declension header")
  if num_adecl_templates >= 1:
    pagemsg("WARNING: Saw {{la-adecl}} in noun section")
  if num_ndecl_templates + num_adecl_templates >= num_noun_headword_templates:
    pagemsg("WARNING: Already seen %s decl template(s) >= %s headword template(s), skipping" % (
      num_ndecl_templates + num_adecl_templates, num_noun_headword_templates))
    return None, None

  subsections = re.split("(^==+[^=\n]+==+\n)", secbody, 0, re.M)

  num_declension_headers = 0
  for k in range(1, len(subsections), 2):
    if "Declension" in subsections[k] or "Inflection" in subsections[k]:
      num_declension_headers += 1
  if num_declension_headers >= num_noun_headword_templates:
    pagemsg("WARNING: Already seen %s Declension/Inflection header(s) >= %s headword template(s), skipping" % (
      num_declension_headers, num_noun_headword_templates))
    return None, None

  for k in range(2, len(subsections), 2):
    if headword_template in subsections[k]:
      pagemsg("Inserting declension section after subsection %s" % k)
      subsections[k] = subsections[k].rstrip('\n') + "\n\n"
      num_equal_signs = len(re.sub("^(=+).*", r"\1", subsections[k - 1].strip()))
      subsections[k + 1:k + 1] = [
        "%sDeclension%s\n%s\n\n" % (
          "=" * (num_equal_signs + 1), "=" * (num_equal_signs + 1),
          decl_template
        )
      ]
      notes.append("add section for Latin declension %s" % decl_template)
      break
  else:
    pagemsg("WARNING: Couldn't locate headword template, skipping: %s" % headword_template)
    return None, None
  secbody = "".join(subsections)
  sections[j] = secbody + sectail
  text = "".join(sections)
  text = re.sub("\n\n\n+", "\n\n", text)
  if not notes:
    notes.append("convert 3+ newlines to 2")
  return text, notes

parser = blib.create_argparser("Add missing declension to Latin terms")
parser.add_argument("--direcfile", help="File of output directives from make_latin_missing_decl.py", required=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

for lineno, line in blib.iter_items_from_file(args.direcfile, start, end):
  m = re.search("^Page [0-9]+ (.*?): For noun (.*?), declension (.*?)$", line)
  if not m:
    msg("Line %s: Unrecognized line, skipping: %s" % (lineno, line))
  else:
    pagename, headword_template, decl_template = m.groups()
    def do_process_page(page, index, parsed):
      return process_page(page, index, headword_template, decl_template)
    blib.do_edit(pywikibot.Page(site, pagename), lineno, do_process_page, save=args.save,
        verbose=args.verbose, diff=args.diff)
