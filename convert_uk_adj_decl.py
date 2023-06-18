#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, tname, pname, msg, site

import uklib

def process_page(page, index, parsed):
  pagetitle = str(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  notes = []

  pagemsg("Processing")

  head = None
  for t in parsed.filter_templates():
    origt = str(t)
    tn = tname(t)
    if tn == "uk-adj":
      head = getparam(t, "1")
      if getparam(t, "head2"):
        pagemsg("WARNING: Can't handle head2= yet in {{rfinfl}}")
        head = None
    elif tn == "rfinfl" and getparam(t, "1") == "uk" and getparam(t, "2") == "adjective":
      if not head:
        pagemsg("WARNING: Found {{rfinfl}} and don't have head: %s" % origt)
      elif " " in head:
        pagemsg("Found {{rfinfl}} but head %s has space in it, skipping" % head)
      else:
        rmparam(t, "2")
        t.add("1", head)
        blib.set_template_name(t, "uk-adecl")
        notes.append("add Ukrainian adjective declension for %s" % head)
    elif tn == "uk-decl-adj":
      word = getparam(t, "1") + getparam(t, "2")
      if uklib.needs_accents(word):
        pagemsg("WARNING: Word %s needs accent: %s" % (word, origt))
        continue
      t.add("1", word)
      rmparam(t, "2")
      blib.set_template_name(t, "uk-adecl")
      notes.append("convert {{uk-decl-adj}} to {{uk-adecl}}")
    elif tn == "uk-adj-table":
      notesval = getparam(t, "notes")
      if notesval:
        notesval = re.sub("^: ", "", notesval)
        if not re.search(r"\.\s*$", notesval):
          notesval = re.sub(r"(\s*)$", r".\1", notesval)
        t.add("footnote", notesval, before="notes", preserve_spacing=False)
        rmparam(t, "notes")
      blib.set_template_name(t, "uk-adecl-manual")
      notes.append("convert {{uk-adj-table}} to {{uk-adecl-manual}}")
    if origt != str(t):
      pagemsg("Replaced %s with %s" % (origt, str(t)))

  return str(parsed), notes

parser = blib.create_argparser(u"Convert old Ukrainian adjective declension templates to new ones",
    include_pagefile=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_page,
    default_cats=["Ukrainian adjectives", "Ukrainian pronouns", "Ukrainian determiners"], edit=True)
