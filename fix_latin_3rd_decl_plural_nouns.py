#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, tname, msg, errandmsg, site

import lalib

def compare_new_and_old_templates(oldt, newt, pagetitle, pagemsg, errandpagemsg):
  global args
  def expand_text(tempcall):
    return blib.expand_text(tempcall, pagetitle, pagemsg, args.verbose)

  def generate_old_forms():
    old_generate_template = re.sub(r"^\{\{la-ndecl\|", "{{la-generate-noun-forms|", oldt)
    old_generate_template = re.sub(r"^\{\{la-adecl\|", "{{la-generate-adj-forms|", old_generate_template)
    old_result = expand_text(old_generate_template)
    if not old_result:
      return None
    return old_result

  def generate_new_forms():
    new_generate_template = re.sub(r"^\{\{la-ndecl\|", "{{User:Benwing2/la-new-generate-noun-forms|", newt)
    new_generate_template = re.sub(r"^\{\{la-adecl\|", "{{User:Benwing2/la-new-generate-adj-forms|", new_generate_template)
    new_result = expand_text(new_generate_template)
    if not new_result:
      return None
    return new_result

  return blib.compare_new_and_old_template_forms(oldt, newt, generate_old_forms,
    generate_new_forms, pagemsg, errandpagemsg)

def process_page(page, index, parsed):
  pagetitle = str(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
  def errandpagemsg(txt):
    errandmsg("Page %s %s: %s" % (index, pagetitle, txt))

  notes = []

  pagemsg("Processing")

  bad_compare = False

  for t in parsed.filter_templates():
    origt = str(t)
    tn = tname(t)
    if tn == "la-ndecl":
      while True:
        lemmaspec = getparam(t, "1")
        if " " in lemmaspec:
          pagemsg("Space in lemma+spec, skipping")
          break
        m = re.search("^(.*)<(.*)>$", lemmaspec)
        if not m:
          pagemsg("WARNING: Unable to parse lemma+spec %s, skipping: %s" % (
            lemmaspec, origt))
          break
        lemma, spec = m.groups()
        split_spec = spec.split(".")
        decl = split_spec[0]
        subtypes = split_spec[1:]
        if decl != "3" or "pl" not in subtypes:
          break
        if "Greek" in subtypes:
          pagemsg("WARNING: .Greek and .pl in lemma spec %s, not able to handle, skipping: %s" % (
            lemmaspec, origt))
          break
        if "/" in lemma:
          base, stem2 = lemma.split("/")
        else:
          base = lemma
          stem2 = lalib.infer_3rd_decl_stem(base)

        # implement autodetection of the types we care about (N, I, pure)
        if "N" not in subtypes and "-I" not in subtypes:
          if (base.endswith("is") and base[:-2] == stem2 or
              base.islower() and base.endswith(u"ēs") and base[:-2] == stem2):
            subtypes += ["I"]
        if ("-N" not in subtypes and "M" not in subtypes and "F" not in subtypes and
            "-I" not in subtypes and "-pure" not in subtypes):
          if (base.endswith("e") and base[:-1] == stem2 or
              base.endswith("al") and base[:-2] + u"āl" == stem2 or
              base.endswith("ar") and base[:-2] + u"ār" == stem2):
            subtypes += ["N", "I", "pure"]
        if ("-N" not in subtypes and "M" not in subtypes and "F" not in subtypes):
          if (base.endswith("us") and base[:-2] + "or" == stem2 or
              base.endswith("us") and base[:-2] + "er" == stem2 or
              base.endswith("ma") and base[:-2] + "mat" == stem2 or
              base.endswith("men") and base[:-2] + "min" == stem2):
            subtypes += ["N"]

        if "N" in subtypes and "I" in subtypes:
          newlemma = stem2 + "ia"
          subtypes = [x for x in subtypes if x != "N" and x != "I"]
          if "pure" in subtypes:
            subtypes = [x for x in subtypes if x != "pure"]
          else:
            subtypes = subtypes + ["-pure"]
        elif "N" in subtypes:
          newlemma = stem2 + "a"
          subtypes = [x for x in subtypes if x != "N"]
        else:
          newlemma = stem2 + u"ēs"
        subtypes = [x for x in subtypes if x != "-I"]
        newspec = ".".join([decl] + subtypes)
        t.add("1", "%s<%s>" % (newlemma, newspec))
        pagemsg("Replaced %s with %s" % (origt, str(t)))
        notes.append("convert 3rd-declension plural term to have plural lemma in {{la-ndecl}}")
        break
      if not compare_new_and_old_templates(origt, str(t), pagetitle, pagemsg, errandpagemsg):
        bad_compare = True

  if bad_compare:
    return None, None
  return str(parsed), notes

parser = blib.create_argparser("Fix Latin 3rd-decl plural nouns to specify plural lemma, and check new against old {{la-ndecl}} code",
  include_pagefile=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_page, edit=True,
  default_refs=["Template:la-ndecl", "Template:la-adecl"])
