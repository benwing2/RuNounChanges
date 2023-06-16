#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, tname, msg, site

import lalib

def compare_new_and_old_templates(t, pagetitle, pagemsg, errandpagemsg):
  global args
  def expand_text(tempcall):
    return blib.expand_text(tempcall, pagetitle, pagemsg, args.verbose)

  def generate_old_forms():
    old_generate_template = re.sub(r"^\{\{la-conj\|", "{{la-generate-verb-forms|", t)
    old_result = expand_text(old_generate_template)
    if not old_result:
      return None
    return old_result

  def generate_new_forms():
    new_generate_template = re.sub(r"^\{\{la-conj\|", "{{User:Benwing2/la-new-generate-verb-forms|", t)
    new_result = expand_text(new_generate_template)
    if not new_result:
      return None
    # Omit linked_* variants, which won't be present in the old forms
    new_result = "|".join(x for x in new_result.split("|") if not x.startswith("linked_"))
    return new_result

  return blib.compare_new_and_old_template_forms(t, t, generate_old_forms,
    generate_new_forms, pagemsg, errandpagemsg)

def process_page(page, index):
  pagetitle = str(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
  def errandpagemsg(txt):
    errandmsg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  parsed = blib.parse_text(str(page.text))

  for t in parsed.filter_templates():
    tn = tname(t)
    if tn == "la-conj":
      compare_new_and_old_templates(str(t), pagetitle, pagemsg, errandpagemsg)

parser = blib.create_argparser("Check potential changes to {{la-conj}} implementation",
    include_pagefile=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_page,
    default_refs=["Template:la-conj"])
