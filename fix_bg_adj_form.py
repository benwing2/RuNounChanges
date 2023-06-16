#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, errandmsg, site, tname, pname

import bglib

adjs_to_accents = {}

def snarf_adj_accents():
  for index, page in blib.cat_articles("Bulgarian adjectives"):
    pagetitle = str(page.title())
    def pagemsg(txt):
      msg("Page %s %s: %s" % (index, pagetitle, txt))
    parsed = blib.parse(page)
    for t in parsed.filter_templates():
      if tname(t) == "bg-adj":
        adj = getparam(t, "1")
        if not adj:
          pagemsg("WARNING: Missing headword in adj: %s" % str(t))
          continue
        if bglib.needs_accents(adj):
          pagemsg("WARNING: Adjective %s missing an accent: %s" % (adj, str(t)))
          continue
        unaccented_adj = bglib.remove_accents(adj)
        if unaccented_adj in adjs_to_accents and adjs_to_accents[unaccented_adj] != adj:
          pagemsg("WARNING: Two different accents possible for %s: %s and %s: %s" % (
            unaccented_adj, adjs_to_accents[unaccented_adj], adj, str(t)))
        adjs_to_accents[unaccented_adj] = adj

def process_page(page, index, parsed):
  pagetitle = str(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
  def errandpagemsg(txt):
    errandmsg("Page %s %s: %s" % (index, pagetitle, txt))

  notes = []

  pagemsg("Processing")

  for t in parsed.filter_templates():
    if tname(t) == "bg-adj-form":
      origt = str(t)
      must_continue = False
      for param in t.params:
        if pname(param) not in ["1", "2", "3", "head"]:
          pagemsg("WARNING: Saw unrecognized param %s=%s: %s" % (pname(param), str(param.value), origt))
          must_continue = True
          break
      if must_continue:
        continue
      rmparam(t, "1")
      rmparam(t, "2")
      head = getparam(t, "head")
      rmparam(t, "head")
      g = getparam(t, "3")
      rmparam(t, "3")
      blib.set_template_name(t, "head")
      t.add("1", "bg")
      t.add("2", "adjective form")
      if head:
        t.add("head", head)
      else:
        if bglib.needs_accents(pagetitle):
          pagemsg("WARNING: Can't add head= to {{bg-adj-form}} missing it because pagetitle is multisyllabic: %s" %
              str(t))
        else:
          t.add("head", pagetitle)
      if g:
        t.add("g", g)
      pagemsg("Replaced %s with %s" % (origt, str(t)))
      notes.append("replace {{bg-adj-form}} with {{head|bg|adjective form}}")

  headt = None
  saw_infl_after_head = False
  saw_headt = False
  saw_inflt = False
  for t in parsed.filter_templates():
    tn = tname(t)
    origt = str(t)
    saw_infl = False
    already_fetched_forms = False
    if tn == "head" and getparam(t, "1") == "bg" and getparam(t, "2") == "adjective form":
      saw_headt = True
      if headt and not saw_infl_after_head:
        pagemsg("WARNING: Saw two head templates %s and %s without intervening inflection" % (
          str(headt), origt))
      saw_infl_after_head = False
      headt = t
    if tn == "bg-adj form of":
      saw_inflt = True
      if not headt:
        pagemsg("WARNING: Saw {{bg-adj form of}} without head template: %s" % origt)
        continue
      must_continue = False
      for param in t.params:
        if pname(param) not in ["1", "2", "3", "adj"]:
          pagemsg("WARNING: Saw unrecognized param %s=%s: %s" % (pname(param), str(param.value), origt))
          must_continue = True
          break
      if must_continue:
        continue
      saw_infl_after_head = True
      adj = getparam(t, "adj")
      if not adj:
        pagemsg("WARNING: Didn't see adj=: %s" % origt)
        continue
      infls = []
      param2 = getparam(t, "2")
      if param2 == "indefinite":
        infls.append("indef")
      elif param2 == "definite":
        infls.append("def")
      elif param2 == "extended":
        infls.append("voc")
      else:
        pagemsg("WARNING: Saw unrecognized 2=%s: %s" % (param2, origt))
        continue
      param3 = getparam(t, "3")
      if param3 == "subject":
        infls.append("sbjv")
      elif param3 == "object":
        infls.append("objv")
      elif param3:
        pagemsg("WARNING: Saw unrecognized 3=%s: %s" % (param3, origt))
        continue
      param1 = getparam(t, "1")
      if param1 == "masculine":
        infls.extend(["m", "s"])
      elif param1 == "feminine":
        infls.extend(["f", "s"])
      elif param1 == "neuter":
        infls.extend(["n", "s"])
      elif param1 == "plural":
        infls.append("p")
      else:
        pagemsg("WARNING: Saw unrecognized 1=%s: %s" % (param1, origt))
        continue
      blib.set_template_name(t, "inflection of")
      del t.params[:]
      t.add("1", "bg")
      if adj in adjs_to_accents:
        adj = adjs_to_accents[adj]
      else:
        pagemsg("WARNING: Unable to find accented equivalent of %s: %s" % (adj, origt))
      t.add("2", adj)
      t.add("3", "")
      for i, infl in enumerate(infls):
        t.add(str(i + 4), infl)
      pagemsg("Replaced %s with %s" % (origt, str(t)))
      notes.append("convert {{bg-adj form of}} to {{inflection of}}")
      tn = tname(t)
    elif tn == "inflection of" and getparam(t, "1") == "bg":
      saw_inflt = True

  if saw_headt and not saw_inflt:
    pagemsg("WARNING: Saw head template %s but no inflection template" % str(headt))

  return str(parsed), notes

parser = blib.create_argparser(u"Convert Bulgarian adjective forms to standard templates",
    include_pagefile=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

snarf_adj_accents()

blib.do_pagefile_cats_refs(args, start, end, process_page,
  default_cats=["Bulgarian adjective forms"], edit=True)
