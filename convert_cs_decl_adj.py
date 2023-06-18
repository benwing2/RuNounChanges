#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, tname, pname, msg, site

def process_text_on_page(index, pagetitle, text):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  notes = []

  parsed = blib.parse_text(text)

  for t in parsed.filter_templates():
    def getp(param):
      return getparam(t, param)
    tn = tname(t)
    origt = str(t)
    if tn == "cs-adj":
      comp = getp("1")
      sup = getp("2")
      if comp == "-" and sup == "-":
        rmparam(t, "2")
        notes.append("remove {{cs-adj}} sup=- cooccurring with comp=-")
      elif comp and sup:
        if sup == "nej" + comp:
          rmparam(t, "2")
          notes.append("remove {{cs-adj}} sup=nej+comp (predictable)")
        else:
          pagemsg("WARNING: Both comp=%s and sup=%s, but the latter isn't predictable from the former: %s" %
            (comp, sup, str(t)))
    elif tn == "cs-decl-adj-auto":
      constructed_pagename = getp("1") + getp("2") + getp("3")
      if constructed_pagename != pagetitle:
        pagemsg("WARNING: Weird params in %s, don't concatenate to pagename" % str(t))
        continue
      rmparam(t, "3")
      rmparam(t, "2")
      rmparam(t, "1")
      blib.set_template_name(t, "cs-adecl")
      notes.append("replace {{cs-decl-adj-auto}} with {{cs-adecl}}")
    elif tn == "cs-decl-adj-poss":
      constructed_pagename = getp("1") + getp("2")
      if constructed_pagename != pagetitle:
        pagemsg("WARNING: Weird params in %s, don't concatenate to pagename" % str(t))
        continue
      rmparam(t, "3")
      rmparam(t, "2")
      rmparam(t, "1")
      blib.set_template_name(t, "cs-adecl")
      notes.append("replace {{cs-decl-adj-poss}} with {{cs-adecl}}")
    elif tn == "cs-decl-adj-soft":
      par1 = getp("1")
      if pagetitle != par1 + u"í":
        pagemsg("WARNING: Weird 1=%s in %s" % (par1, str(t)))
        continue
      rmparam(t, "1")
      blib.set_template_name(t, "cs-adecl")
      notes.append("replace {{cs-decl-adj-soft}} with {{cs-adecl}}")
    elif tn == "cs-decl-adj-hard":
      par1 = getp("1")
      if pagetitle != par1 + u"ý":
        pagemsg("WARNING: Weird 1=%s in %s" % (par1, str(t)))
        continue
      par2 = getp("2")
      if par2:
        if par2 != "ma":
          pagemsg("WARNING: Weird 2=%s in %s" % (par2, str(t)))
          continue
        par3 = getp("3")
        if par1.endswith("sk"):
          pal2 = par1[:-2] + u"št"
        elif par1.endswith("ck"):
          pal2 = par1[:-2] + u"čt"
        elif par1.endswith("k"):
          pal2 = par1[:-1] + "c"
        elif par1.endswith("ch"):
          pal2 = par1[:-2] + u"š"
        elif par1.endswith("h"):
          pal2 = par1[:-1] + "z"
        elif par1.endswith("r"):
          pal2 = par1[:-1] + u"ř"
        else:
          pal2 = par1
        should_par3 = pal2 + u"í"
        if par3 != should_par3:
          pagemsg("WARNING: 3=%s should equal %s but doesn't: %s" % (par3, should_par3, str(t)))
          continue
      rmparam(t, "3")
      rmparam(t, "2")
      rmparam(t, "1")
      blib.set_template_name(t, "cs-adecl")
      notes.append("replace {{cs-decl-adj-hard}} with {{cs-adecl}}")
    if origt != str(t):
      pagemsg("Replaced %s with %s" % (origt, str(t)))

  text = str(parsed)
  return text, notes

parser = blib.create_argparser("Convert {{cs-decl-adj*}} to {{cs-adecl}} and clean {{cs-adj}}", include_pagefile=True, include_stdin=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True,
  default_cats=["Czech adjectives"])
