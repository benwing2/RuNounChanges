#!/usr/bin/env python3
# -*- coding: utf-8 -*-

# Go through all the terms we can find looking for pages that are
# missing a headword declaration.

# NOTES on how past passive participles are formed and when they're present:
#
# Participles exist only in transitive verbs, in perfective verbs as well
# as imperfective verbs not marked with the shaded circle sign. However,
# verbs marked with an x form participles with difficulty, and verbs marked
# with an x inside of a square lack participles.
#
# Verbs in -ать and -ять (except type 14) form participles by replacing -ть
# in the infinitive with -нный. If the stress is on the last syllable of the
# infinitive, it is one syllable to the left in the participle (if possible),
# else on the same syllable as the infinitive. However, verbs in -а́ть and
# -я́ть with the circled-7 mark have participles in -а́нный and -я́нный (there
# aren't very many of these). When the stress is moved relative to the
# infinitive, е changes to ё if the ё symbol is present.
#
# Verbs of type 4 and verbs in -еть of type 5 form participles by adding
# -енный (stressed -ённый) to the base of the 1sg present/future (i.e.
# iotated in the same way as the 1sg, if it is iotated). Verbs of type 4 have
# the stress on the same syllable as in the 3sg present/future (i.e. -ённый
# if type b, else somewhere on the stem with -енный); but verbs of type 4b
# with the circled-8 mark have the ending -енный with the stress on the last
# syllable of the stem, i.e. one syllable to the left compared with the
# infinitive). Verbs of type 5 have the stress as in -ать verbs (one syllable
# to the left of the infinitive if the infinitive stress is on the ending and
# the circled-7 mark isn't present, else in the same place as the infinitive).
#
# Verbs of type 1 in -еть form participles by replacing -еть with -ённый.
# The only such verbs with participles are одоле́ть, преодоле́ть, and verbs
# in -печатле́ть.
#
# Verbs of type 7 and 8 form participles by adding -енный (stressed -ённый)
# to the base of the 3sg present/future. The stress is on the same syllable
# as in the feminine singular past.
#
# Verbs of type 3 (3˚) and 10 form participles by adding -тый to the base
# of the infinitive. These verbs have the stress as in -ать verbs (one
# syllable to the left of the infinitive if the infinitive stress is on the
# ending, else in the same place as the infinitive).
#
# Verbs of type 9, 11, 12, 14, 15, 16 form participles by adding -тый to
# the masculine singular past (minus final -л if it's present). Stress is
# as in the masculine singular past.

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, msg, site

import rulib

# Form the past passive participle from the verb type, infinitive and
# other parts. For the moment we don't try to get the stress right,
# and return a form without stress or ё.
def form_ppp(verbtype, pagetitle, args):
  def form_ppp_1(verbtype, pagetitle, args):
    def first_entry(forms):
      forms = re.sub(",.*", "", forms)
      return re.sub("//.*", "", forms)
    if not re.search("^[0-9]+", verbtype):
      return None
    verbtype = int(re.sub("^([0-9]+).*", r"\1", verbtype))
    if ((pagetitle.endswith("ать") or pagetitle.endswith("ять")) and
        verbtype != 14):
      return re.sub("ть$", "нный", pagetitle)
    if pagetitle.endswith("еть") and verbtype == 1:
      return re.sub("ть$", "нный", pagetitle)
    if verbtype in [4, 5]:
      sg1 = args["pres_1sg"] if "pres_1sg" in args else args["futr_1sg"]
      if not sg1 or sg1 == "-":
        return None
      sg1 = first_entry(sg1)
      assert re.search("[ую]́?$", sg1)
      return re.sub("[ую]́?$", "енный", sg1)
    if verbtype in [7, 8]:
      sg3 = args["pres_3sg"] if "pres_3sg" in args else args["futr_3sg"]
      sg3 = first_entry(sg3)
      assert re.search("[её]́?т$", sg3)
      return re.sub("[её]́?т$", "енный", sg3)
    if verbtype in [3, 10]:
      return re.sub("ть$", "тый", pagetitle)
    assert verbtype in [9, 11, 12, 14, 15, 16]
    pastm = first_entry(args["past_m"])
    return re.sub("л?$", "тый", pastm)

  retval = form_ppp_1(verbtype, pagetitle, args)
  if retval:
    return rulib.make_unstressed_ru(retval)
  else:
    return None

def process_page(page, index, parsed):
  global args
  pagetitle = str(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  def expand_text(tempcall):
    return blib.expand_text(tempcall, pagetitle, pagemsg, args.verbose)

  pagemsg("Processing")

  manual_ppp_forms = ["past_pasv_part", "past_pasv_part2", "past_pasv_part3",
    "past_pasv_part4", "ppp", "ppp2", "ppp3", "ppp4"]
  text = str(page.text)
  parsed = blib.parse(page)
  notes = []
  for t in parsed.filter_templates():
    origt = str(t)
    tname = str(t.name)
    if tname == "ru-conj":
      manual_ppps = []
      for form in manual_ppp_forms:
        ppp = getparam(t, form)
        if ppp and ppp != "-":
          manual_ppps.append(ppp)
      if not manual_ppps:
        continue
      if [x for x in t.params if str(x.value) == "or"]:
        pagemsg("WARNING: Skipping multi-arg conjugation: %s" % str(t))
        continue
      curvariant = getparam(t, "2")
      if "+p" in curvariant or "(7)" in curvariant or "(8)" in curvariant:
        pagemsg("WARNING: Found both manual PPP and PPP variant, something wrong: %s" %
            str(t))
        continue
      t2 = blib.parse_text(str(t)).filter_templates()[0]
      for form in manual_ppp_forms:
        rmparam(t2, form)
      variants_to_try = ["+p"]
      if "ё" in re.sub("ённый$", "", manual_ppps[0]):
        variants_to_try.append("+pё")
      if "жденный" in manual_ppps[0] or "ждённый" in manual_ppps[0]:
        variants_to_try.append("+pжд")
      notsamemsgs = []
      for variant in variants_to_try:
        t2.add("2", curvariant + variant)
        tempcall = re.sub(r"\{\{ru-conj", "{{ru-generate-verb-forms", str(t2))
        result = expand_text(tempcall)
        if not result:
          pagemsg("WARNING: Error generating forms, skipping")
          continue
        args = blib.split_generate_args(result)
        if "past_pasv_part" not in args:
          pagemsg("WARNING: Something wrong, no past passive participle generated: %s" % str(t))
          continue
        auto_ppps = []
        for form in manual_ppp_forms:
          if form in args:
            for ppp in re.split(",", args[form]):
              if ppp and ppp != "-":
                auto_ppps.append(ppp)
        if manual_ppps == auto_ppps:
          pagemsg("Manual PPP's %s same as auto-generated PPP's, switching to auto"
              % ",".join(manual_ppps))
          for form in manual_ppp_forms:
            rmparam(t, form)
          t.add("2", curvariant + variant)
          notes.append("replaced manual PPP's with variant %s" % variant)
          break
        else:
          notsamemsgs.append("WARNING: Manual PPP's %s not same as auto-generated PPP's %s: %s" %
            (",".join(manual_ppps), ",".join(auto_ppps), str(t)))
      else: # no break in for loop
        for m in notsamemsgs:
          pagemsg(m)

    newt = str(t)
    if origt != newt:
      pagemsg("Replaced %s with %s" % (origt, newt))

  return str(parsed), notes

parser = blib.create_argparser("Infer the past passive participle variant from the actual PPP",
  include_pagefile=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_page, edit=True,
  default_cats=["Russian verbs"])
