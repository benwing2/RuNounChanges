#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site

import rulib as ru
import runounlib as runoun

def process_page(index, page, save, verbose):
  pagetitle = unicode(page.title())
  subpagetitle = re.sub(".*:", "", pagetitle)
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  if ":" in pagetitle:
    pagemsg("WARNING: Colon in page title, skipping")
    return

  def expand_text(tempcall):
    return blib.expand_text(tempcall, pagetitle, pagemsg, verbose)

  parsed = blib.parse(page)

  headword_templates = []
  for t in parsed.filter_templates():
    if unicode(t.name) in ["ru-noun", "ru-proper noun"]:
      headword_templates.append(t)

  headword_template = None
  if len(headword_templates) > 1:
    pagemsg("WARNING: Multiple old-style headword templates, not sure which one to use, using none")
    for ht in headword_templates:
      pagemsg("Ignored headword template: %s" % unicode(ht))
  elif len(headword_templates) == 0:
    pagemsg("WARNING: No old-style headword templates")
  else:
    headword_template = headword_templates[0]
    pagemsg("Found headword template: %s" % unicode(headword_template))

  num_z_decl = 0
  for t in parsed.filter_templates():
    if unicode(t.name) == "ru-decl-noun-z":
      num_z_decl += 1
      pagemsg("Found z-decl template: %s" % unicode(t))
      ru_noun_table_template = runoun.convert_zdecl_to_ru_noun_table(t,
          subpagetitle, pagemsg, headword_template=headword_template)
      if not ru_noun_table_template:
        pagemsg("WARNING: Unable to convert z-decl template: %s" % unicode(t))
        continue

      generate_template = re.sub(r"^\{\{ru-noun-table",
          "{{ru-generate-noun-args", unicode(ru_noun_table_template))
      if unicode(headword_template.name) == "ru-proper noun":
        generate_template = re.sub(r"\}\}$", "|ndef=sg}}", generate_template)

      def pagemsg_with_proposed(text):
        pagemsg("Proposed ru-noun-table template: %s" %
            unicode(ru_noun_table_template))
        pagemsg(text)

      generate_result = expand_text(unicode(generate_template))
      if not generate_result:
        pagemsg_with_proposed("WARNING: Error generating noun args, skipping")
        continue
      args = ru.split_generate_args(generate_result)

      # This will check number mismatch and animacy mismatch
      new_genders = runoun.check_old_noun_headword_forms(headword_template,
          args, subpagetitle, pagemsg_with_proposed)
      if new_genders == None:
        continue

      origt = unicode(t)
      t.name = "ru-noun-table"
      del t.params[:]
      for param in ru_noun_table_template.params:
        t.add(param.name, param.value)
      pagemsg("Replacing z-decl %s with regular decl %s" %
          (origt, unicode(t)))

  if num_z_decl > 1:
    pagemsg("WARNING: Found multiple z-decl templates (%s)" % num_z_decl)

  comment = "Replace ru-decl-noun-z with ru-noun-table"
  if save:
    pagemsg("Saving with comment = %s" % comment)
    page.text = unicode(parsed)
    page.save(comment=comment)
  else:
    pagemsg("Would save with comment = %s" % comment)

parser = blib.create_argparser("Convert ru-decl-noun-z into ru-noun-table")
args = parser.parse_args()
start, end = blib.get_args(args.start, args.end)

for index, page in blib.references("Template:ru-decl-noun-z", start, end):
  process_page(index, page, args.save, args.verbose)
