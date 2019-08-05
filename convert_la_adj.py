#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, getrmparam, tname, msg, errandmsg, site

import lalib

def compare_new_and_old_templates(origt, newt, pagetitle, pagemsg, errandpagemsg):
  global args
  def expand_text(tempcall):
    return blib.expand_text(tempcall, pagetitle, pagemsg, args.verbose)

  def generate_old_forms():
    return lalib.generate_adj_forms(origt, errandpagemsg, expand_text, return_raw=True)

  def generate_new_forms():
    new_generate_template = re.sub(r"^\{\{la-adecl\|", "{{User:Benwing2/la-new-generate-adj-forms|", newt)
    new_result = expand_text(new_generate_template)
    if not new_result:
      return None
    return new_result

  return blib.compare_new_and_old_template_forms(origt, newt, generate_old_forms,
    generate_new_forms, pagemsg, errandpagemsg)

def convert_template_to_new(t, pagetitle, pagemsg, errandpagemsg):
  origt = unicode(t)
  tn = tname(t)
  m = re.search(r"^la-(.*)$", tn)
  if not m:
    pagemsg("WARNING: Something wrong, can't parse adj decl template name: %s" % tn)
    return None
  decl_suffix = m.group(1)
  if decl_suffix not in lalib.la_adj_decl_suffix_to_decltype:
    pagemsg("WARNING: Unrecognized adj decl template name: %s" % tn)
    return None
  decl, compute_props = lalib.la_adj_decl_suffix_to_decltype[decl_suffix]
  stem1 = getparam(t, "1").strip()
  stem2 = getparam(t, "2").strip()
  num = getrmparam(t, "num")
  specified_subtypes = getrmparam(t, "type")
  if specified_subtypes:
    specified_subtypes = specified_subtypes.split("-")
  else:
    specified_subtypes = []
  lemma, stem2, decl, subtypes = (
    compute_props(stem1, stem2, decl, specified_subtypes, num, None, True,
      pagetitle, pagemsg)
  )
  if num == "sg":
    subtypes.append("sg")
  decl += "+"
  blib.set_template_name(t, "la-adecl")
  # Fetch all params
  named_params = []
  for param in t.params:
    pname = unicode(param.name)
    if pname.strip() in ["1", "2", "noun"]:
      continue
    named_params.append((pname, param.value, param.showkey))
  # Erase all params
  del t.params[:]
  # Put back params
  if stem2:
    lemma += "/" + stem2
  subtypes = [decl] + subtypes
  if subtypes != ["+"]:
    lemma += "<%s>" % ".".join(subtypes)
  t.add("1", lemma)
  for name, value, showkey in named_params:
    t.add(name, value, showkey=showkey, preserve_spacing=False)
  pagemsg("Replaced %s with %s" % (origt, unicode(t)))
  if compare_new_and_old_templates(origt, unicode(t), pagetitle, pagemsg, errandpagemsg):
    return t
  else:
    return None

def process_page(page, index, parsed):
  pagetitle = unicode(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
  def errandpagemsg(txt):
    errandmsg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  notes = []

  for t in parsed.filter_templates():
    tn = tname(t)
    if tn == "la-decl-multi":
      pagemsg("Skipping la-decl-multi for now: %s" % unicode(t))
    elif tn == "la-decl-irreg" and getparam(t, "noun"):
      pagemsg("Skipping noun la-decl-irreg: %s" % unicode(t))
    elif tn in lalib.la_adj_decl_templates:
      if convert_template_to_new(t, pagetitle, pagemsg, errandpagemsg):
        notes.append("converted {{%s}} to {{la-adecl}}" % tn)
      else:
        return None, None

  return unicode(parsed), notes

parser = blib.create_argparser("Convert Latin adj decl templates to new form",
    include_pagefile=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_page,
  default_cats=["Latin adjectives"], edit=True)
