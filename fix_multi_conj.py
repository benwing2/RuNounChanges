#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site

import rulib

def process_page(page, index, parsed):
  pagetitle = str(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  text = str(page.text)
  notes = []

  parsed = blib.parse(page)
  verbtype = None
  num_conjs = 0
  conj_templates = []
  mixed_verb_types = False
  for t in parsed.filter_templates():
    origt = str(t)
    if str(t.name) in ["ru-conj"]:
      num_conjs += 1
      new_verbtype = getparam(t, "1")
      if verbtype and new_verbtype != verbtype:
        pagemsg("Found page with multiple conjugations of different verb types: %s and %s" %
            (verbtype, new_verbtype))
        mixed_verb_types = True
      verbtype = new_verbtype
      conj_templates.append(t)
  if not mixed_verb_types and num_conjs > 1:
    pagemsg("Found %s conjugations of the same type, can potentially combine: types %s" % (
      num_conjs, " ".join(getparam(t, "2") for t in conj_templates)))
  elif num_conjs == 1:
    return
  elif num_conjs == 0:
    pagemsg("WARNING: No verb conjugations on page, skipping")
    return

  def fetch_numbered_params(t):
    p = []
    for i in range(1,10):
      val = getparam(t, str(i)) or ""
      p.append(val)
    for i in range(8,-1,-1):
      if p[i]:
        break
      else:
        del p[i]
    return p

  def combine_verbs(m):
    verb1 = m.group(1)
    verb2 = m.group(3)
    if m.group(2):
      pagemsg("WARNING: Would combine verbs but found text '%s' needing to go into a note, skipping: %s and %s" %
          (m.group(2), verb1, verb2))
      return m.group(0)
    t1 = blib.parse_text(verb1).filter_templates()[0]
    t2 = blib.parse_text(verb2).filter_templates()[0]
    for t in [t1, t2]:
      for param in t.params:
        if not re.search("^[0-9]+$", str(param.name)):
          pagemsg("Verb conjugation has non-numeric args, skipping: %s" %
              str(t))
          return m.group(0)
    params = fetch_numbered_params(t1)
    params.append("or")
    newparams = fetch_numbered_params(t2)
    if len(newparams) < 2:
      pagemsg("WARNING: Something wrong, no verb type in ru-conj: %s" %
          str(t2))
      return m.group(0)
    vt1 = getparam(t1, "1")
    vt2 = getparam(t2, "1")
    if vt1 != vt2:
      pagemsg("WARNING: Can't combine verbs of different verb types: %s and %s" %
          (verb1, verb2))
      return m.group(0)
    del newparams[0]
    params.extend(newparams)
    blib.set_param_chain(t1, params, "1", "")
    pagemsg("Combining verb conjugations %s and %s" % (
      getparam(t1, "2"), getparam(t2, "2")))
    pagemsg("Replaced %s with %s" % (m.group(0).replace("\n", r"\n"), str(t1)))
    notes.append("combined verb conjugations %s and %s" % (
      getparam(t1, "2"), getparam(t2, "2")))
    return str(t1)

  new_text = re.sub(r"(\{\{ru-conj\|[^{}]*\}\})\s*''or(.*?)''\s*(\{\{ru-conj\|[^{}]*\}\})",
      combine_verbs, text)
  return new_text, notes

parser = blib.create_argparser("Fix verbs with multiple conjugations to be a single conjugation if possible",
  include_pagefile=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_page, edit=True,
  default_cats=["Russian verbs"])
