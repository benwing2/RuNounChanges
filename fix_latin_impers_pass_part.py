#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, tname, msg, site

import lalib

def correct_nom_sg_n_participle(page, index, participle, lemma):
  pagetitle = unicode(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  text = unicode(page.text)
  origtext = text

  retval = lalib.find_latin_section(text, pagemsg)
  if retval is None:
    return None, None

  sections, j, secbody, sectail, has_non_latin = retval

  if "===Etymology 1===" in secbody:
    pagemsg("WARNING: Multiple etymologies, don't know what to do")
    return None, None

  notes = []

  subsections = re.split("(^===[^=\n]*===\n)", secbody, 0, re.M)

  participle_text = """{{head|la|participle|[[indeclinable]]|head=%s}}

# {{inflection of|la|%s||perf|pasv|part}}\n\n""" % (participle, lemma)
  saw_participle = False
  for k in range(2, len(subsections), 2):
    if subsections[k - 1] == "===Participle===\n":
      if saw_participle:
        pagemsg("WARNING: Saw multiple participles, skipping")
        return None, None
      saw_participle = True
      subsections[k] = participle_text
      notes.append("correct participle %s of %s to be impersonal" %
          (participle, lemma))
  secbody = "".join(subsections)
  if not saw_participle:
    for k in range(2, len(subsections), 2):
      insert_before = False
      if subsections[k - 1] == "===References===\n":
        pagemsg("Inserting new participle subsection before references subsection")
        insert_before = True
      elif re.search(r"\{\{inflection of.*\|sup", subsections[k]):
        pagemsg("Inserting new participle subsection before supine subsection")
        insert_before = True
      if insert_before:
        subsections[k - 1:k - 1] = ["===Participle===\n" + participle_text]
        secbody = "".join(subsections)
        break
    else:
      # no break
      if not secbody.endswith("\n\n"):
        secbody += "\n\n"
      secbody += "===Participle===\n" + participle_text
    notes.append("add impersonal participle %s of %s" % (participle, lemma))

  sections[j] = secbody + sectail
  return "".join(sections), notes

def process_page(index, page, save, verbose, diff):
  pagetitle = unicode(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
  def errandpagemsg(txt):
    errandmsg("Page %s %s: %s" % (index, pagetitle, txt))
  def expand_text(tempcall):
    return blib.expand_text(tempcall, pagetitle, pagemsg, verbose)

  pagemsg("Processing")

  parsed = blib.parse(page)

  for t in parsed.filter_templates():
    if tname(t) == "la-conj":
      args = lalib.generate_verb_forms(unicode(t), errandpagemsg, expand_text)
      supforms = args.get("sup_acc", "")
      if supforms:
        supforms = supforms.split(",")
        for supform in supforms:
          non_impers_part = re.sub("um$", "us", supform)
          pagemsg("Line to delete: part %s allbutnomsgn {{la-adecl|%s}}" % (
            non_impers_part, non_impers_part))
          def do_correct_nom_sg_n_participle(page, index, parsed):
            return correct_nom_sg_n_participle(page, index, supform,
                args["1s_pres_actv_indc"])
          blib.do_edit(pywikibot.Page(site,
            lalib.remove_macrons(supform)), index,
            do_correct_nom_sg_n_participle, save=save, verbose=verbose,
            diff=diff)

parser = blib.create_argparser("Fix Latin impersonal passive participles and output deletion lines for non-impersonal variants",
  include_pagefile=True)
parser.add_argument("--ignore", help="Comma-separated pages to ignore.")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

ignore_pages = []
if args.ignore:
  ignore_pages = args.ignore.decode("utf-8").split(",")

def do_process_page(page, index, parsed):
  if unicode(page.title()) not in ignore_pages:
    return process_page(index, page, args.save, args.verbose, args.diff)
  return None, None

blib.do_pagefile_cats_refs(args, start, end, do_process_page, edit=True,
  default_cats=["Latin verbs with impersonal passive"])
