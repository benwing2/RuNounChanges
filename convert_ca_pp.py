#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, tname, pname, msg, site
from convert_ca_adj_noun import make_feminine, make_plural

old_template = "ca-pp-old"

def process_text_on_page(index, pagetitle, text):
  global args
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  notes = []

  if old_template not in text:
    return

  if ":" in pagetitle:
    pagemsg("Skipping non-mainspace title")
    return

  pagemsg("Processing")

  parsed = blib.parse_text(text)

  lemma = pagetitle

  for t in parsed.filter_templates():
    tn = tname(t)
    def getp(param):
      return getparam(t, param)
    if tn == old_template:
      origt = unicode(t)
      must_continue = False
      for param in t.params:
        pn = pname(param)
        pv = unicode(param.value)
        if pn not in ["1", "f", "feminine", "mpl", "mp", "masculine plural", "fpl", "fp", "feminine plural"]:
          pagemsg("WARNING: Saw unrecognized param %s=%s: %s" % (pn, pv, unicode(t)))
          must_continue = True
          break
      if must_continue:
        continue
      f = getp("f") or getp("feminine")
      mpl = getp("mpl") or getp("mp") or getp("masculine plural")
      fpl = getp("fpl") or getp("fp") or getp("feminine plural")
      p1 = getp("1")
      if p1 and (f or mpl or fpl):
        pagemsg("WARNING: Saw both 1= and f=/mpl=/fpl=, skipping: %s" % unicode(t))
        continue
      if not p1 and not (f and mpl and fpl):
        pagemsg("WARNING: Some of f=/mpl=/fpl= missing, skipping: %s" % unicode(t))
        continue
      if f.endswith("ssa") or f.endswith("na"):
        pagemsg("WARNING: Feminine %s ends in -ssa or -na, can't handle yet: %s" % unicode(t))
        continue
      if p1:
        pass
      else:
        deff = make_feminine(lemma)
        defmpl = make_plural(lemma, "m")
        deffpl = make_plural(f, "m")
        if deff == f:
          f = None
        if [mpl] != defmpl:
          pagemsg("WARNING: Masculine plural %s not same as default masculine plural %s, can't handle yet: %s"
            % (mpl, ",".join(defmpl), unicode(t)))
          continue
        if [fpl] != deffpl:
          pagemsg("WARNING: Feminine plural %s not same as default feminine plural %s, can't handle yet: %s"
            % (fpl, ",".join(deffpl), unicode(t)))
          continue
      del t.params[:]
      if f:
        t.add("1", f)
      blib.set_template_name(t, "ca-pp")
      notes.append("convert {{%s}} to new form" % old_template)
      if origt != unicode(t):
        pagemsg("Replaced %s with %s" % (origt, unicode(t)))

  return unicode(parsed), notes

parser = blib.create_argparser("Convert {{%s}} templates to new format" % old_template,
  include_pagefile=True, include_stdin=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True,
    default_refs=["Template:%s" % old_template])
