#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, tname, pname, msg, site

def process_text_on_page(index, pagetitle, text):
  global args
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  notes = []

  parsed = blib.parse_text(text)

  for t in parsed.filter_templates():
    tn = tname(t)
    origt = str(t)
    def getp(param):
      return getparam(t, param)
    if tn == "pl-decl-adj-ki":
      param1 = getp("1")
      param2 = getp("2")
      blib.set_template_name(t, "pl-decl-adj-auto")
      rmparam(t, "2")
      rmparam(t, "1")
      if ":" in pagetitle and pagetitle != param1 + "ki":
        pagemsg("WARNING: Param 1=%s doesn't agree with pagetitle: %s" % (param1, origt))
        t.add("1", param1 + "ki")
      if param2:
        t.add("olddat", param2)
      notes.append("Convert {{pl-decl-adj-ki}} to {{pl-decl-adj-auto}}")
    elif tn in ["pl-decl-adj-y", "pl-adj-y"]:
      if getp("head"):
        pagemsg("WARNING: Saw head=, not changing: %s" % origt)
      else:
        param1 = getp("1")
        blib.set_template_name(t, "pl-decl-adj-auto")
        rmparam(t, "2")
        rmparam(t, "1")
        if ":" in pagetitle and pagetitle != param1 + "y":
          pagemsg("WARNING: Param 1=%s doesn't agree with pagetitle: %s" % (param1, origt))
          t.add("1", param1 + "y")
        notes.append("Convert {{%s}} to {{pl-decl-adj-auto}}" % tn)
    elif tn == "pl-decl-adj-i":
      param1 = getp("1")
      param2 = getp("2")
      blib.set_template_name(t, "pl-decl-adj-auto")
      rmparam(t, "2")
      rmparam(t, "1")
      if param1:
        if param2 in ["g", "gi"]:
          should_pagetitle = param1 + "gi"
        elif param2 in ["l", "li"]:
          should_pagetitle = param1 + "li"
        else:
          should_pagetitle = param1 + "i"
        if ":" in pagetitle and pagetitle != should_pagetitle:
          pagemsg("WARNING: Param 1=%s doesn't agree with pagetitle (pagetitle should be %s): %s" %
              (param1, should_pagetitle, origt))
          t.add("1", should_pagetitle)
      notes.append("Convert {{pl-decl-adj-i}} to {{pl-decl-adj-auto}}")
    elif tn == "pl-decl-adj-owy":
      param1 = getp("1")
      blib.set_template_name(t, "pl-decl-adj-auto")
      rmparam(t, "2")
      rmparam(t, "1")
      if ":" in pagetitle and pagetitle != param1 + "owy":
        pagemsg("WARNING: Param 1=%s doesn't agree with pagetitle: %s" % (param1, origt))
        t.add("1", param1 + "owy")
      notes.append("Convert {{pl-decl-adj-owy}} to {{pl-decl-adj-auto}}")

  return str(parsed), notes

parser = blib.create_argparser("Convert {{pl-decl-adj-*}} to {{pl-decl-adj-auto}}",
  include_pagefile=True, include_stdin=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True,
    default_refs=["Template:pl-decl-adj-ki", "Template:pl-decl-adj-y", "Template:pl-decl-adj-i",
      "Template:pl-decl-adj-owy"])
