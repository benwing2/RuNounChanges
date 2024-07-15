#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, msg, site, tname

def process_text_on_page(index, pagetitle, text):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
  if pagetitle.startswith("Module:"):
    return

  pagemsg("Processing")
  notes = []

  to_move_refs = []

  parsed = blib.parse_text(text)
  for t in parsed.filter_templates():
    tn = tname(t)
    if tn == "etydate":
      def getp(param):
        return getparam(t, param)
      ref1 = getp("ref")
      ref1n = getp("refn")
      ref2 = getp("ref2")
      ref2n = getp("ref2n")
      ref3 = getp("ref3")
      ref3n = getp("ref3n")
      if ref1 or ref1n or ref2 or ref2n or ref3 or ref3n:
        origt = str(t)
        m = re.search(re.escape(origt) + "([.,;:])", text)
        if m:
          punct = m.group(1)
        else:
          punct = ""
        if punct in [":", ";"]:
          pagemsg("WARNING: Previous change didn't move past colon or semicolon: %s" % origt)
        origt_with_punct = origt + punct
        refadds = []
        def process_ref(refparam, refnparam):
          ref = getp(refparam)
          refn = getp(refnparam)
          if not ref and not refn:
            return
          if ref:
            refparamval = "|%s" % ref
          else:
            refparamval = ""
          if refn:
            refadd = "{{ref%s|name=%s}}" % (refparamval, refn)
          else:
            refadd = "{{ref%s}}" % refparamval
          refadds.append(refadd)
          rmparam(t, refparam)
          rmparam(t, refnparam)
        process_ref("ref", "refn")
        process_ref("ref2", "ref2n")
        process_ref("ref3", "ref3n")
        newt = str(t) + punct + "".join(refadds)
        if newt != origt_with_punct:
          pagemsg("Replacing <%s> with <%s>" % (origt_with_punct, newt))
          to_move_refs.append((origt_with_punct, newt))

  for curr_template, repl_template in to_move_refs:
    newtext, did_replace = blib.replace_in_text(text, curr_template, repl_template, pagemsg)
    if did_replace:
      if newtext != text:
        notes.append("move refs inside of {{etydate}} outside and after any period or comma")
        text = newtext

  return text, notes

parser = blib.create_argparser("Move refs inside of {{etydate}} outside and after any period or comma",
    include_pagefile=True, include_stdin=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, default_refs=["Template:etydate"], edit=True,
                           stdin=True)
