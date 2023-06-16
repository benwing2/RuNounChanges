#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site

def process_page(page, index, parsed):
  global args
  verbose = args.verbose
  pagetitle = str(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  def expand_text(tempcall):
    return blib.expand_text(tempcall, pagetitle, pagemsg, verbose)

  parsed = blib.parse(page)

  headword_template = None
  see_template = None
  for t in parsed.filter_templates():
    if str(t.name) in ["ru-noun+", "ru-proper noun+"]:
      if headword_template:
        pagemsg("WARNING: Multiple headword templates, skipping")
        return
      headword_template = t
    if str(t.name) in ["ru-decl-noun-see"]:
      if see_template:
        pagemsg("WARNING: Multiple ru-decl-noun-see templates, skipping")
        return
      see_template = t
  if not headword_template:
    pagemsg("WARNING: No ru-noun+ or ru-proper noun+ templates, skipping")
    return
  if not see_template:
    pagemsg("WARNING: No ru-decl-noun-see templates, skipping")
    return

  del see_template.params[:]
  for param in headword_template.params:
    see_template.add(param.name, param.value)
  see_template.name = "ru-noun-table"

  if str(headword_template.name) == "ru-proper noun+":
    # Things are trickier for proper nouns because they default to n=sg, whereas
    # ru-noun-table defaults to n=both. We have to expand both templates and
    # fetch the value of n, and set it in ru-noun-table if not the same.

    # 1. Generate args for headword proper-noun template, using |ndef=sg
    #    because ru-proper noun+ defaults to sg and ru-generate-noun-args
    #    would otherwise default to both.
    headword_generate_template = re.sub(r"^\{\{ru-proper noun\+", "{{ru-generate-noun-args",
        str(headword_template))
    headword_generate_template = re.sub(r"\}\}$", "|ndef=sg}}", headword_generate_template)
    headword_generate_result = expand_text(headword_generate_template)
    if not headword_generate_result:
      pagemsg("WARNING: Error generating ru-proper noun+ args")
      return None
    # 2. Fetch actual value of n.
    headword_args = blib.split_generate_args(headword_generate_result)
    headword_n = headword_args["n"]
    # 3. If sg, we always need to set n=sg explicitly in ru-noun-table.
    if headword_n == "s":
      see_template.add("n", "sg")
    # 4. If pl, leave alone, since both will default to plural only if the
    #    lemma is pl, else n=pl needs to be set for both.
    elif headword_n == "p":
      pass
    # 5. If both, n=both had to have been set explicitly in the headword,
    #    but it's the default in ru-noun-table unless the lemma is plural.
    #    So remove n=both, generate the arguments, and see if the actual
    #    value of args.n is b (for "both"); if not, set n=both.
    else:
      assert headword_n == "b"
      rmparam(see_template, "n")
      see_generate_template = re.sub(r"^\{\{ru-noun-table", "{{ru-generate-noun-args",
          str(see_template))
      see_generate_result = expand_text(see_generate_template)
      if not see_generate_result:
        pagemsg("WARNING: Error generating ru-noun-table args")
        return None
      see_args = blib.split_generate_args(see_generate_result)
      if see_args["n"] != "b":
        see_template.add("n", "both")

  return str(parsed), "Replace ru-decl-noun-see with ru-noun-table, taken from headword template (%s)" % str(headword_template.name)

parser = blib.create_argparser("Convert ru-decl-noun-see into ru-noun-table decl template, taken from headword ru-(proper )noun+ template",
  include_pagefile=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_page, edit=True,
  default_refs=["Template:ru-decl-noun-see"])
