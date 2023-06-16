#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, tname, pname, msg, site

def process_text_on_page(index, pagetitle, text):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  def expand_text(tempcall):
    return blib.expand_text(tempcall, pagetitle, pagemsg, args.verbose)

  def convert_traditional_to_simplified(langcode, trad):
    trad_simp = expand_text("{{#invoke:User:Benwing2/languages/utilities|generateForms|%s|%s}}" % (langcode, trad))
    if not trad_simp:
      return trad_simp
    if "||" in trad_simp:
      trad, simp = trad_simp.split("||", 1)
      return simp
    else:
      return trad_simp

  notes = []

  parsed = blib.parse_text(text)

  def dispchar(ch):
    return "%s (%s)" % (ch, ch.encode("unicode_escape"))

  def check_simplified_matches_traditional(trad, simp, langcode, langname, prefix):
    if simp == trad:
      pagemsg("%s simplified form %s same as %s traditional %s, removing" % (prefix, simp, langname, trad))
      return trad
    trad_to_simp = convert_traditional_to_simplified(langcode, trad)
    if not trad_to_simp:
      return False
    if trad_to_simp == simp:
      pagemsg("%s simplified form %s matches %s traditional %s, removing" % (prefix, simp, langname, trad))
      return trad
    rev_trad_to_simp = convert_traditional_to_simplified(langcode, simp)
    if not rev_trad_to_simp:
      return False
    if rev_trad_to_simp == trad:
      pagemsg("%s simplified form %s and %s traditional %s given in reverse order from what's expected, still removing"
        % (prefix, trad, langname, simp))
      return simp
    pagemsg("WARNING: %s simplified form %s doesn't match auto-generated simplified %s from %s traditional %s%s: %s"
      % (prefix, dispchar(simp), dispchar(trad_to_simp), langname, dispchar(trad),
        ("; assuming params reversed, 'simplified' %s doesn't match auto-generated 'simplified' %s from 'traditional' %s, either"
        % (dispchar(trad), dispchar(rev_trad_to_simp), dispchar(simp)) if rev_trad_to_simp != simp else ""),
        str(t)))
    return False

  for t in parsed.filter_templates():
    def getp(param):
      return getparam(t, param)
    tn = tname(t)
    if tn in ["pinyin reading of", "pinread", "pinof"]:
      trad = getp("tas") or getp("t") or getp("trad") or getp("tra") or getp("1")
      simp = getp("s") or getp("simp") or getp("sim") or getp("2")
      if simp:
        trad = check_simplified_matches_traditional(trad, simp, "cmn", "Mandarin", "First")
        if not trad:
          continue
      trad2 = getp("t2") or getp("trad2") or getp("tra2") or getp("3")
      simp2 = getp("s2") or getp("simp2") or getp("sim2") or getp("4")
      if simp2:
        trad2 = check_simplified_matches_traditional(trad2, simp2, "cmn", "Mandarin", "Second")
        if not trad2:
          continue
      remaining_params = [x for x in [getp("5"), getp("6"), getp("7"), getp("8"), getp("9"), getp("10")] if x]
      for param in t.params:
        pn = pname(param)
        pv = str(param.value)
        if pn not in [
          "tas", "t", "trad", "tra", "1",
          "s", "simp", "sim", "2",
          "t2", "trad2", "tra2", "3",
          "s2", "simp2", "sim2", "4",
          "5", "6", "7", "8", "9", "10",
          "lang", "def", # ignored
        ]:
          pagemsg("WARNING: Unrecognized parameter %s=%s in {{pinyin reading of}} template %s"
            % (pn, pv, str(t)))
          break
      else: # no break
        all_numeric = [x for x in [trad, trad2] + remaining_params if x]
        origt = str(t)
        del t.params[:]
        blib.set_param_chain(t, all_numeric, "1")
        blib.set_template_name(t, "cmn-pinyin of")
        if origt != str(t):
          pagemsg("Replaced %s with %s" % (origt, str(t)))
          notes.append("convert {{pinyin reading of}} to {{cmn-pinyin of}}, standardize params and remove unnecessary simplified variants")

    elif tn == "yue-jyutping of":
      trad = getp("tas") or getp("trad") or getp("tra") or getp("1")
      simp = getp("sim") or getp("simp") or getp("2")
      if simp:
        trad = check_simplified_matches_traditional(trad, simp, "yue", "Cantonese", "First")
        if not trad:
          continue
      trad2 = getp("tra2") or getp("trad2") or getp("3")
      simp2 = getp("sim2") or getp("simp2") or getp("4")
      if simp2:
        trad2 = check_simplified_matches_traditional(trad2, simp2, "yue", "Cantonese", "Second")
        if not trad2:
          continue
      remaining_params = [x for x in [getp("5")] if x]
      for param in t.params:
        pn = pname(param)
        pv = str(param.value)
        if pn not in [
          "tas", "trad", "tra", "1",
          "sim", "simp", "2",
          "tra2", "trad2", "3",
          "sim2", "simp2", "4",
          "5",
        ]:
          pagemsg("WARNING: Unrecognized parameter %s=%s in {{yue-jyutping of}} template %s"
            % (pn, pv, str(t)))
          break
      else: # no break
        all_numeric = [x for x in [trad, trad2] + remaining_params if x]
        origt = str(t)
        del t.params[:]
        blib.set_param_chain(t, all_numeric, "1")
        if origt != str(t):
          pagemsg("Replaced %s with %s" % (origt, str(t)))
          notes.append("standardize params in {{yue-jyutping of}} and remove unnecessary simplified variants")

  text = str(parsed)
  return text, notes

parser = blib.create_argparser("Clean {{pinyin reading of}} and {{yue-jyutping of}}", include_pagefile=True, include_stdin=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True,
  default_refs=["Template:pinyin reading of", "Template:yue-jyutping of"])
