#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, errandmsg, site, tname, pname

blib.getData()

def process_text_on_page(index, pagetitle, text):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  global args
  def expand_text(tempcall):
    return blib.expand_text(tempcall, pagetitle, pagemsg, args.verbose)

  notes = []

  pagemsg("Processing")

  parsed = blib.parse_text(text)
  for t in parsed.filter_templates():
    origt = str(t)
    tn = tname(t)
    if tn == "autocat":
      blib.set_template_name(t, "auto cat")
      notes.append("{{autocat}} -> {{auto cat}}")
    elif tn == "langcatboiler":
      m = re.search("^Category:(.* Language)$", pagetitle)
      if not m:
        m = re.search("^Category:(.*) language$", pagetitle)
      if not m:
        pagemsg("WARNING: Can't parse page title")
        continue
      langname = m.group(1)
      t_lang = getparam(t, "1")
      if langname not in blib.languages_byCanonicalName:
        pagemsg("WARNING: Unrecognized language name: %s" % langname)
        continue
      langobj = blib.languages_byCanonicalName[langname]
      if langobj["code"] != t_lang:
        pagemsg("WARNING: Auto-determined code %s for language name %s != manually specified %s" % (
          langobj["code"], langname, t_lang))
        continue
      numbered_params = []
      non_numbered_params = []
      for param in t.params:
        pn = pname(param)
        pv = str(param.value).strip()
        if pn == "1" or not pv:
          pass
        elif re.search("^[0-9]+$", pn):
          numbered_params.append(pv)
        elif pn not in ["setwiki", "setwikt", "setsister", "entryname"]:
          pagemsg("WARNING: Unrecognized param %s=%s, skipping: %s" % (pn, pv, str(t)))
          return
        elif (pn in ["setwiki", "setsister"] and pv == langname + " language" or
            pn == "entryname" and pv == langname or
            pn == "setwikt" and pv == langobj["code"]):
          pagemsg("WARNING: Unnecessary param %s=%s, omitting: %s" % (pn, pv, str(t)))
        else:
          non_numbered_params.append((pn, pv))
      if len(numbered_params) == 0:
        if langobj["type"] == "reconstructed" or langobj["family"] == "art":
          pagemsg("Reconstructed or constructed language, allowing no countries")
        else:
          pagemsg("WARNING: No countries and not reconstructed or constructed language, adding UNKNOWN")
          numbered_params.append("UNKNOWN")
      blib.set_template_name(t, "auto cat")
      del t.params[:]
      for index, numbered_param in enumerate(numbered_params):
        t.add(str(index + 1), numbered_param, preserve_spacing=False)
      for name, value in non_numbered_params:
        t.add(name, value, preserve_spacing=False)
      notes.append("convert {{%s}} to {{auto cat}}" % tn)

    if str(t) != origt:
      pagemsg("Replaced <%s> with <%s>" % (origt, str(t)))

  return str(parsed), notes

parser = blib.create_argparser("Convert {{langcatboiler}} to {{auto cat}}",
    include_pagefile=True, include_stdin=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, default_refs=["Template:langcatboiler"], edit=True, stdin=True)
