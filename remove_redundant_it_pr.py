#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, tname, pname, msg, site

vowels = u"aeiouàèéìòóùAEIOUÀÈÉÌÒÓÙ"
V = "[" + vowels + "]"

def process_text_on_page(index, pagetitle, text):
  global args
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
  def expand_text(tempcall, suppress_errors):
    return blib.expand_text(tempcall, pagetitle, pagemsg, args.verbose, suppress_errors=suppress_errors)
  def getpron(pron, suppress_errors):
    return expand_text("{{#invoke:it-pronunciation|to_phonemic_bot|%s}}" % pron, suppress_errors)

  notes = []

  if "it-pr" not in text:
    return

  # Short words shouldn't get defaulted, even though a word like 'libro' will get a default pronunciation,
  # because this isn't so obvious.
  if not re.search(V + ".*" + V + ".*" + V, pagetitle):
    pagemsg("Skipping page without at least three vowels")
    return

  parsed = blib.parse_text(text)

  for t in parsed.filter_templates():
    tn = tname(t)
    origt = str(t)
    def getp(param):
      return getparam(t, param)
    if tn in ["it-pr"]:
      pagemsg("Saw %s" % str(t))
      if getp("2"):
        pagemsg("Skipping multiple pronunciations: %s" % str(t))
        continue
      pron = getp("1")
      if not pron:
        continue
      origpron = pron
      if "," in pron:
        pagemsg("Skipping multiple pronunciations: %s" % str(t))
        continue
      if "*" in pron or "!" in pron or u"°" in pron:
        pagemsg("Skipping pron with initial/final symbol: %s" % str(t))
        continue
      m = re.search("^(.*?)(<.*>)$", pron)
      if m:
        pron, mods = m.groups()
      else:
        mods = ""
      orig_base_pron = pron
      if pron == "+":
        pass
      elif pron == pagetitle:
        pron = "+"
      else:
        default_phonemic = getpron(pagetitle, suppress_errors=True)
        if not default_phonemic:
          continue
        pron_phonemic = getpron(pron, suppress_errors=False)
        if not pron_phonemic:
          continue
        if default_phonemic == pron_phonemic:
          pagemsg("Respelling '%s' produces phonemic /%s/, same as default: %s" % (pron, pron_phonemic, str(t)))
          pron = "+"
        else:
          pagemsg("Respelling '%s' produces phonemic /%s/, while pagename as respelling produces /%s/: %s"
              % (pron, pron_phonemic, default_phonemic, str(t)))
      newpron = pron + mods
      if newpron == "+":
        newpron = ""
      if newpron != origpron:
        pagemsg("Replacing respelling '%s' with '%s'" % (origpron, newpron))
        if not newpron:
          rmparam(t, "1")
          notes.append("remove redundant respelling '%s' from {{it-pr}}" % orig_base_pron)
        else:
          t.add("1", newpron)
          notes.append("replace defaultable respelling '%s' with + in {{it-pr}}" % orig_base_pron)
      if str(t) != origt:
        pagemsg("Replaced %s with %s" % (origt, str(t)))

  return str(parsed), notes

parser = blib.create_argparser("Remove redundant respellings in {{it-pr}}",
  include_pagefile=True, include_stdin=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True,
  default_refs=["Template:it-pr"])
