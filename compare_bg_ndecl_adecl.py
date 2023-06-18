#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, tname, msg, errandmsg, site

import lalib

def compare_new_and_old_templates(t, pagetitle, pagemsg, errandpagemsg):
  global args
  def expand_text(tempcall):
    return blib.expand_text(tempcall, pagetitle, pagemsg, args.verbose)

  def generate_old_forms():
    old_generate_template = re.sub(r"^\{\{bg-ndecl\|", "{{bg-generate-noun-forms|", t)
    old_generate_template = re.sub(r"^\{\{bg-adecl\|", "{{bg-generate-adj-forms|", old_generate_template)
    old_result = expand_text(old_generate_template)
    if not old_result:
      return None
    return old_result

  def generate_new_forms():
    new_generate_template = re.sub(r"^\{\{bg-ndecl\|", "{{User:Benwing2/bg-generate-noun-forms|", t)
    new_generate_template = re.sub(r"^\{\{bg-adecl\|", "{{User:Benwing2/bg-generate-adj-forms|", new_generate_template)
    new_result = expand_text(new_generate_template)
    if not new_result:
      return None
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
    if tn == "bg-ndecl" or tn == "bg-adecl":
      compare_new_and_old_templates(str(t), pagetitle, pagemsg, errandpagemsg)

parser = blib.create_argparser("Check potential changes to {{bg-ndecl}} or {{bg-adecl}} implementation",
    include_pagefile=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_page,
    default_refs=["Template:bg-ndecl", "Template:bg-adecl"])
