#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, set_template_name, msg, errandmsg, site, tname

def process_masc_page(index, page, fem):
  notes = []
  pagetitle = str(page.title())
  orig_fem = fem
  def pagemsg(txt):
    msg("Page %s %s: %s: %s" % (index, orig_fem, pagetitle, txt))
  def expand_text(tempcall):
    return blib.expand_text(tempcall, pagetitle, pagemsg, args.verbose)

  prev_fr_noun = False
  parsed = blib.parse_text(str(page.text))
  for t in parsed.filter_templates():
    origt = str(t)
    tn = tname(t)
    if tn in ["fr-noun"]:
      if prev_fr_noun:
        pagemsg("WARNING: Saw two {{fr-noun}} templates, not changing: %s and %s" % (prev_fr_noun, str(t)))
        return
      prev_fr_noun = str(t)
      default_fem = expand_text("{{#invoke:fr-headword|make_feminine|%s}}" % pagetitle)
      if not default_fem:
        return
      if fem == default_fem:
        pagemsg("Substituting '+' for default feminine %s: %s" % (fem, str(t)))
        fem = "+"
      else:
        pagemsg("Feminine %s not equal to default feminine %s, not substituting: %s" % (fem, default_fem, str(t)))
      fems = blib.fetch_param_chain(t, "f")
      if fem in fems:
        pagemsg("Feminine %s already in feminine(s) %s: %s" % (fem, ",".join(fems), str(t)))
      elif orig_fem in fems:
        pagemsg("Replacing default feminine %s with + in %s: %s" % (orig_fem, ",".join(fems), str(t)))
        fems = [fem if f == orig_fem else f for f in fems]
        blib.set_param_chain(t, fems, "f")
        notes.append("replace default feminine %s with + in {{fr-noun}}" % orig_fem)
      else:
        fems.append(fem)
        blib.set_param_chain(t, fems, "f")
        notes.append("add female equivalent %s%s to {{fr-noun}}" % (fem, "" if fem == orig_fem else " (%s)" % orig_fem))

    if origt != str(t):
      pagemsg("Replaced %s with %s" % (origt, str(t)))

  return str(parsed), notes


def process_text_on_page(index, pagetitle, text):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
  def errandpagemsg(txt):
    errandmsg("Page %s %s: %s" % (index, pagetitle, txt))

  if "female equivalent of" not in text and "femeq" not in text:
    return

  #pagemsg("Processing")

  parsed = blib.parse_text(text)
  for t in parsed.filter_templates():
    origt = str(t)
    tn = tname(t)
    if tn in ["female equivalent of", "femeq"]:
      lang = getparam(t, "1")
      if lang != "fr":
        pagemsg("WARNING: Can't handle lang %s: %s" % (lang, str(t)))
        continue
      masc = getparam(t, "2")
      mascpage = pywikibot.Page(site, masc)
      if not blib.safe_page_exists(mascpage, errandpagemsg):
        pagemsg("WARNING: Masculine %s doesn't exist: %s" % (masc, str(t)))
        continue
      def do_process(page, index, parsed):
        return process_masc_page(index, page, pagetitle)
      blib.do_edit(mascpage, index, do_process, save=args.save, verbose=args.verbose, diff=args.diff)

parser = blib.create_argparser("Copy {{female equivalent of}} nouns to the f= of the corresponding masculine",
  include_pagefile=True, include_stdin=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, default_cats=["French female equivalent nouns"],
    edit=True, stdin=True)
