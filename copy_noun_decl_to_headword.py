#!/usr/bin/env python3
# -*- coding: utf-8 -*-

# Copy the declension in ru-noun-table to ru-noun+, preserving any m=, f=,
# g=, etc. in the latter.

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, msg, site

# import runounlib

def process_page(page, index, parsed):
  global args
  verbose = args.verbose
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
  num_ru_noun_table_cleaned_subs = 0
  num_ru_noun_table_link_copied_subs = 0
  num_ru_noun_subs = 0
  num_ru_proper_noun_subs = 0
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
          (replaced, this_num_ru_noun_table_cleaned_subs,
              this_num_ru_noun_table_link_copied_subs, this_num_ru_noun_subs,
              this_num_ru_proper_noun_subs) = retval
          subsections[k] = replaced
          num_ru_noun_table_cleaned_subs += this_num_ru_noun_table_cleaned_subs
          num_ru_noun_table_link_copied_subs += this_num_ru_noun_table_link_copied_subs
          num_ru_noun_subs += this_num_ru_noun_subs
          num_ru_proper_noun_subs += this_num_ru_proper_noun_subs
      sections[j] = "".join(subsections)

  new_text = "".join(sections)

  if new_text == text:
    pass
  else:
    notes = []
    if num_ru_noun_table_cleaned_subs > 0:
      notes.append("remove extra params from ru-noun-table%s" % (
        "" if num_ru_noun_table_cleaned_subs == 1 else " (%s)" % num_ru_noun_table_cleaned_subs))
    if num_ru_noun_table_link_copied_subs > 0:
      notes.append("copy ru-noun+ or ru-proper noun+ params to ru-noun-table to add links%s" % (
        "" if num_ru_noun_table_link_copied_subs == 1 else " (%s)" % num_ru_noun_table_link_copied_subs))
    if num_ru_noun_subs > 0:
      notes.append("copy ru-noun-table params to ru-noun+%s" % (
        "" if num_ru_noun_subs == 1 else " (%s)" % num_ru_noun_subs))
    if num_ru_proper_noun_subs > 0:
      notes.append("copy ru-noun-table params to ru-proper noun+%s" % (
        "" if num_ru_proper_noun_subs == 1 else " (%s)" % num_ru_proper_noun_subs))
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
  if len(noun_table_templates) < 1:
    if noun_old_templates:
      pagemsg("WARNING: No ru-noun-table templates but found ru-noun-old template(s): %s" %
          ", ".join(str(x) for x in noun_old_templates))
    return str(parsed), 0, 0, 0, 0

  for t in parsed.filter_templates():
    if str(t.name) in ["ru-noun", "ru-proper noun"]:
      pagemsg("Found ru-noun or ru-proper noun, skipping")
      return None

  headword_templates = []

  for t in parsed.filter_templates():
    if str(t.name) in ["ru-noun+", "ru-proper noun+"]:
      headword_templates.append(t)

  if len(headword_templates) > 1:
    pagemsg("WARNING: Found multiple headword templates, skipping")
    return None
  if len(headword_templates) < 1:
    return str(parsed), 0, 0, 0, 0

  noun_table_template = noun_table_templates[0]
  noun_old_template = noun_old_templates[0] if len(noun_old_templates) == 1 else None
  headword_template = headword_templates[0]
  decl_templates = [x for x in [noun_table_template, noun_old_template] if x]

  if verbose:
    pagemsg("Found headword template: %s" % str(headword_template))
    pagemsg("Found decl template: %s" % str(noun_table_template))
    if noun_old_template:
      pagemsg("Found old decl template: %s" % str(noun_old_template))

  orig_headword_template = str(headword_template)
  orig_noun_table_template = str(noun_table_template)

  genders = blib.fetch_param_chain(headword_template, "g", "g")
  masculines = blib.fetch_param_chain(headword_template, "m", "m")
  feminines = blib.fetch_param_chain(headword_template, "f", "f")
  notrcat = getparam(headword_template, "notrcat")
  filtered_headword_params = []
  for param in headword_template.params:
    name = str(param.name)
    if re.search("^[gmf][0-9]*$", name) or name == "notrcat":
      pass
    else:
      filtered_headword_params.append((param.name, param.value))
  filtered_headword_template = blib.parse_text("{{ru-noun+}}").filter_templates()[0]
  for name, value in filtered_headword_params:
    filtered_headword_template.add(name, value)

  ru_noun_table_cleaned = 0
  ru_noun_table_link_copied = 0
  ru_noun_changed = 0
  ru_proper_noun_changed = 0

  new_decl_params = []
  for param in noun_table_template.params:
    name = str(param.name)
    if re.search("^[gmf][0-9]*$", name):
      pagemsg("WARNING: Found g=, m= or f= in noun-table, removing: %s" %
          str(noun_table_template))
    else:
      new_decl_params.append((param.name, param.value))
  del noun_table_template.params[:]
  for name, value in new_decl_params:
    noun_table_template.add(name, value)
  if orig_noun_table_template != str(noun_table_template):
    ru_noun_table_cleaned = 1

  modified_noun_table_template = blib.parse_text("{{ru-noun-table}}").filter_templates()[0]
  for param in noun_table_template.params:
    modified_noun_table_template.add(param.name, param.value)

  # If proper noun and n is both then we need to add n=both because
  # proper noun+ defaults to n=sg
  if str(headword_template.name) == "ru-proper noun+":
    generate_template = re.sub(r"^\{\{ru-noun-table", "{{ru-generate-noun-args",
        str(noun_table_template))
    generate_result = expand_text(generate_template)
    if not generate_result:
      pagemsg("WARNING: Error generating noun args, skipping")
      return None
    args = blib.split_generate_args(generate_result)

    # If proper noun and n is both then we need to add n=both because
    # proper noun+ defaults to n=sg
    if args["n"] == "b" and not getparam(modified_noun_table_template, "n"):
      pagemsg("Adding n=both to headword template")
      modified_noun_table_template.add("n", "both")
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
        pagemsg("Removing n=sg from headword template")
        rmparam(modified_noun_table_template, "n")
      else:
        pagemsg("WARNING: Unable to remove n= from headword template because n=%s" %
            ndef_args["n"])

  new_headword_template = re.sub(r"^\{\{ru-noun-table", "{{ru-noun+",
      str(modified_noun_table_template))
  existing_filtered_headword_template = str(filtered_headword_template)
  change_existing_headword = False
  if existing_filtered_headword_template != new_headword_template:
    if "[" in existing_filtered_headword_template and "[" not in new_headword_template:
      if blib.remove_links(existing_filtered_headword_template) == new_headword_template:
        pagemsg("Headword has links but decl doesn't and they're otherwise the same, copying headword to decl")
        del noun_table_template.params[:]
        for param in filtered_headword_template.params:
          noun_table_template.add(param.name, param.value)
        ru_noun_table_link_copied = 1
        ru_noun_table_cleaned = 0
      else:
        pagemsg("WARNING: Existing headword template %s would be overwritten with %s but links would be erased, not doing it, check manually"
            % (existing_filtered_headword_template, new_headword_template))
        return None
    else:
      pagemsg("WARNING: Existing headword template %s will be overwritten with %s"
          % (existing_filtered_headword_template, new_headword_template))
      change_existing_headword = True

  if change_existing_headword:
    del headword_template.params[:]
    for param in modified_noun_table_template.params:
      headword_template.add(param.name, param.value)
    blib.set_param_chain(headword_template, genders, "g", "g")
    blib.set_param_chain(headword_template, masculines, "m", "m")
    blib.set_param_chain(headword_template, feminines, "f", "f")
    if notrcat:
      headword_template.add("notrcat", notrcat)
    
  #genders = runounlib.check_old_noun_headword_forms(headword_template, args,
  #    subpagetitle, pagemsg)
  #if genders == None:
  #  return None

  #new_params = []
  #for param in noun_table_template.params:
  #  new_params.append((param.name, param.value))

  #params_to_preserve = runounlib.fix_old_headword_params(headword_template,
  #    new_params, genders, pagemsg)
  #if params_to_preserve == None:
  #  return None

  new_noun_table_template = str(noun_table_template)
  if new_noun_table_template != orig_noun_table_template:
    pagemsg("Replacing noun table %s with %s" % (orig_noun_table_template,
      new_noun_table_template))

  new_headword_template = str(headword_template)
  if new_headword_template != orig_headword_template:
    pagemsg("Replacing headword %s with %s" % (orig_headword_template,
      new_headword_template))
    if str(headword_template.name) == "ru-noun+":
      ru_noun_changed = 1
    else:
      ru_proper_noun_changed = 1

  return str(parsed), ru_noun_table_cleaned, ru_noun_table_link_copied, ru_noun_changed, ru_proper_noun_changed

parser = blib.create_argparser("Copy the declension in ru-noun-table to ru-noun+, preserving any m=, f=, g=, etc. in the latter.",
  include_pagefile=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_page, edit=True,
  default_refs=["Template:ru-noun+", "Template:ru-proper noun+"])
