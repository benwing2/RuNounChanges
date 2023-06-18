#!/usr/bin/env python3
# -*- coding: utf-8 -*-

# Convert ru-noun to ru-noun+, ru-proper noun to ru-proper noun+, transfer
# manual translit in headword to declension template (ru-noun-table).

# FIXME:
#
# 1. (DONE) Skip stuff not in main namespace.
# 2. Add debug code to print out full current and new text of page so I can
#    verify that nothing bad is happening.

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, msg, site

import runounlib

def process_page(page, index, parsed):
  pagetitle = str(page.title())
  subpagetitle = re.sub("^.*:", "", pagetitle)
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  if ":" in pagetitle:
    pagemsg("WARNING: Colon in page title, skipping")
    return

  text = str(page.text)

  foundrussian = False
  sections = re.split("(^==[^=]*==\n)", text, 0, re.M)
  num_ru_noun_subs = 0
  num_ru_proper_noun_subs = 0
  num_replace_bian = 0
  transferred_tr = []
  for j in range(2, len(sections), 2):
    if sections[j-1] == "==Russian==\n":
      if foundrussian:
        pagemsg("WARNING: Found multiple Russian sections, skipping")
        return
      foundrussian = True

      subsections = re.split("(^===[^=]*===\n)", sections[j], 0, re.M)
      for k in range(2, len(subsections), 2):
        retval = process_page_section(index, page, subsections[k], verbose)
        if retval:
          (replaced, this_num_ru_noun_subs, this_num_ru_proper_noun_subs,
              this_num_replace_bian, this_transferred_tr) = retval
          subsections[k] = replaced
          num_ru_noun_subs += this_num_ru_noun_subs
          num_ru_proper_noun_subs += this_num_ru_proper_noun_subs
          num_replace_bian += this_num_replace_bian
          transferred_tr.extend(this_transferred_tr)
      sections[j] = "".join(subsections)

  new_text = "".join(sections)

  if new_text == text:
    pagemsg("WARNING: Can't find headword or decl template, skipping")
  else:
    notes = []
    if num_ru_noun_subs == 1:
      notes.append("convert ru-noun to ru-noun+")
    elif num_ru_noun_subs > 1:
      notes.append("convert ru-noun to ru-noun+ (%s)" % num_ru_noun_subs)
    if num_ru_proper_noun_subs == 1:
      notes.append("convert ru-proper noun to ru-proper noun+")
    elif num_ru_proper_noun_subs > 1:
      notes.append("convert ru-proper noun to ru-proper noun+ (%s)" % num_ru_proper_noun_subs)
    if num_replace_bian == 1:
      notes.append("replace a=bi in decl template")
    elif num_replace_bian > 1:
      notes.append("replace a=bi in decl template (%s)" % num_replace_bian)
    if transferred_tr:
      notes.append("transfer %s to decl template" % (
        ",".join("tr=%s" % x for x in transferred_tr)))
    assert notes
    return new_text, notes

def process_page_section(index, page, section, verbose):
  pagetitle = str(page.title())
  subpagetitle = re.sub("^.*:", "", pagetitle)
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  def expand_text(tempcall):
    return blib.expand_text(tempcall, pagetitle, pagemsg, verbose)

  if not page.exists():
    pagemsg("WARNING: Page doesn't exist, skipping")
    return None

  parsed = blib.parse_text(section)

  noun_table_templates = []
  noun_old_templates = []

  for t in parsed.filter_templates():
    if str(t.name) == "ru-decl-noun-see":
      pagemsg("Found ru-decl-noun-see, skipping")
      return None

  for t in parsed.filter_templates():
    if str(t.name) == "ru-noun-table":
      noun_table_templates.append(t)
    if str(t.name) == "ru-noun-old":
      noun_old_templates.append(t)

  if len(noun_table_templates) > 1:
    pagemsg("WARNING: Found multiple ru-noun-table templates, skipping")
    return None
  if len(noun_old_templates) > 1:
    pagemsg("WARNING: Found multiple ru-noun-old templates, skipping")
    return None
  if not noun_table_templates and not noun_old_templates:
    return str(parsed), 0, 0, 0, []

  for t in parsed.filter_templates():
    if str(t.name) in ["ru-noun+", "ru-proper noun+"]:
      pagemsg("Found ru-noun+ or ru-proper noun+, skipping")
      return None

  headword_templates = []

  for t in parsed.filter_templates():
    if str(t.name) in ["ru-noun", "ru-proper noun"]:
      headword_templates.append(t)

  if len(headword_templates) > 1:
    pagemsg("WARNING: Found multiple headword templates, skipping")
    return None
  if len(headword_templates) < 1:
    return str(parsed), 0, 0, 0, []

  noun_table_template = noun_table_templates[0] if len(noun_table_templates) == 1 else None
  noun_old_template = noun_old_templates[0] if len(noun_old_templates) == 1 else None
  if noun_old_template and not noun_table_template:
    noun_table_template = noun_old_template
    noun_old_template = None
  headword_template = headword_templates[0]
  frobbed_manual_translit = []
  decl_templates = [x for x in [noun_table_template, noun_old_template] if x]

  if verbose:
    pagemsg("Found headword template: %s" % str(headword_template))
    pagemsg("Found decl template: %s" % str(noun_table_template))
    if noun_old_template:
      pagemsg("Found old decl template: %s" % str(noun_old_template))

  # Retrieve headword translit and maybe transfer to decl
  headword_tr = getparam(headword_template, "tr")
  if headword_tr:
    if verbose:
      pagemsg("Found headword manual translit tr=%s" % headword_tr)
    if "," in headword_tr:
      pagemsg("WARNING: Comma in headword manual translit, skipping: %s" %
          headword_tr)
      return None
    # Punt if multi-arg-set, can't handle yet
    for decl_template in decl_templates:
      for param in decl_template.params:
        if not param.showkey:
          val = str(param.value)
          if val == "or":
            pagemsg("WARNING: Manual translit and multi-decl templates, can't handle, skipping: %s" % str(decl_template))
            return None
          if val == "-" or val == "_" or val.startswith("join:"):
            pagemsg("WARNING: Manual translit and multi-word templates, can't handle, skipping: %s" % str(decl_template))
            return None
      for i in range(2, 10):
        if getparam(headword_template, "tr%s" % i):
          pagemsg("WARNING: Headword template has translit param tr%s, can't handle, skipping: %s" % (
            i, str(headword_template)))
          return None
      if runounlib.arg1_is_stress(getparam(decl_template, "1")):
        lemma_arg = "2"
      else:
        lemma_arg = "1"
      lemmaval = getparam(decl_template, lemma_arg)
      if not lemmaval:
        lemmaval = subpagetitle
      if "//" in lemmaval:
        m = re.search("^(.*?)//(.*)$", lemmaval)
        if m.group(2) != headword_tr:
          pagemsg("WARNING: Found existing manual translit in decl template %s, but doesn't match headword translit %s; skipping" % (
            lemmaval, headword_tr))
          return None
        else:
          pagemsg("Already found manual translit in decl template %s" %
              lemmaval)
      else:
        lemmaval += "//" + headword_tr
        orig_decl_template = str(decl_template)
        decl_template.add(lemma_arg, lemmaval)
        pagemsg("Replacing decl %s with %s" % (orig_decl_template,
          str(decl_template)))
        frobbed_manual_translit = [headword_tr]

  genders = blib.fetch_param_chain(headword_template, "2", "g")

  bian_replaced = 0

  # Change a=bi in decl to a=ia or a=ai, depending on order of anim/inan in
  # headword template
  for decl_template in decl_templates:
    if getparam(decl_template, "a") in ["b", "bi", "bian", "both"]:
      saw_in = -1
      saw_an = -1
      for i,g in enumerate(genders):
        if re.search(r"\bin\b", g) and saw_in < 0:
          saw_in = i
        if re.search(r"\ban\b", g) and saw_an < 0:
          saw_an = i
      if saw_in >= 0 and saw_an >= 0:
        orig_decl_template = str(decl_template)
        if saw_in < saw_an:
          pagemsg("Replacing a=bi with a=ia in decl template")
          decl_template.add("a", "ia")
          bian_replaced = 1
        else:
          pagemsg("Replacing a=bi with a=ai in decl template")
          decl_template.add("a", "ai")
          bian_replaced = 1
        pagemsg("Replacing decl %s with %s" % (orig_decl_template,
          str(decl_template)))

  generate_template = re.sub(r"^\{\{ru-noun-old", "{{ru-generate-noun-args|old=1",
    re.sub(r"^\{\{ru-noun-table", "{{ru-generate-noun-args",
      str(noun_table_template)))
  generate_result = expand_text(generate_template)
  if not generate_result:
    pagemsg("WARNING: Error generating noun args, skipping")
    return None
  args = blib.split_generate_args(generate_result)

  genders = runounlib.check_old_noun_headword_forms(headword_template, args,
      subpagetitle, pagemsg)
  if genders == None:
    return None

  new_params = []
  for param in noun_table_template.params:
    new_params.append((param.name, param.value))

  orig_headword_template = str(headword_template)
  params_to_preserve = runounlib.fix_old_headword_params(headword_template,
      new_params, genders, pagemsg)
  if params_to_preserve == None:
    return None

  if str(headword_template.name) == "ru-proper noun":
    # If proper noun and n is both then we need to add n=both because
    # proper noun+ defaults to n=sg
    if args["n"] == "b" and not getparam(headword_template, "n"):
      pagemsg("Adding n=both to headword tempate")
      headword_template.add("n", "both")
    # Correspondingly, if n is sg then we can usually remove n=sg;
    # but we need to check that the number is actually sg with n=sg
    # removed because of the possibility of plurale tantum lemmas
    if args["n"] == "s":
      generate_template_with_ndef = generate_template.replace("}}", "|ndef=sg}}")
      generate_template_with_ndef = re.sub(r"\|n=s[^=|{}]*", "",
          generate_template_with_ndef)
      generate_result = expand_text(generate_template_with_ndef)
      if not generate_result:
        pagemsg("WARNING: Error generating noun args, skipping")
        return None
      ndef_args = blib.split_generate_args(generate_result)
      if ndef_args["n"] == "s":
        existing_n = getparam(headword_template, "n")
        if existing_n and not re.search(r"^s", existing_n):
          pagemsg("WARNING: Something wrong: Found n=%s, not singular" %
              existing_n)
        else:
          pagemsg("Removing n=sg from headword tempate")
          rmparam(headword_template, "n")
      else:
        pagemsg("WARNING: Unable to remove n= from headword template because n=%s" %
            ndef_args["n"])

  headword_template.params.extend(params_to_preserve)
  ru_noun_changed = 0
  ru_proper_noun_changed = 0
  if str(headword_template.name) == "ru-noun":
    headword_template.name = "ru-noun+"
    ru_noun_changed = 1
  else:
    headword_template.name = "ru-proper noun+"
    ru_proper_noun_changed = 1
  if str(noun_table_template).startswith("{{ru-noun-old"):
    headword_template.add("old", "1")

  pagemsg("Replacing headword %s with %s" % (orig_headword_template, str(headword_template)))

  return str(parsed), ru_noun_changed, ru_proper_noun_changed, bian_replaced, frobbed_manual_translit

parser = blib.create_argparser("Convert ru-noun to ru-noun+, ru-proper noun to ru-proper noun+",
  include_pagefile=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_page, edit=True,
  #default_refs=["Template:ru-noun", "Template:ru-proper noun"],
  default_refs=["Template:tracking/ru-headword/bad-ru-noun"])
