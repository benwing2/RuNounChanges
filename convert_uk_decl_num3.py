#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, tname, pname, msg, errandmsg, site

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
    if tn == "uk-decl-num3":
      def clean_part(part):
        return blib.remove_links(part).replace(" ", "").strip()
      acc = clean_part(getp("4"))
      if "," in acc:
        nom = clean_part(getp("1"))
        gen = clean_part(getp("2"))
        dat = clean_part(getp("3"))
        ins = clean_part(getp("5"))
        loc = clean_part(getp("6"))
        acc_parts = acc.split(",")
        if len(acc_parts) == 2:
          acc_in, acc_an = acc_parts
        for param in t.params:
          pn = pname(param)
          pv = str(param.value)
          if not re.search("^[1-6]$", pn):
            pagemsg("WARNING: Unrecognized param: %s=%s" % (pn, pv))
            return
        del t.params[:]
        blib.set_template_name(t, "uk-adecl-manual")
        t.add("special", "plonly\n", preserve_spacing=False)
        t.add("nom_p", nom + "\n", preserve_spacing=False)
        t.add("gen_p", gen + "\n", preserve_spacing=False)
        t.add("dat_p", dat + "\n", preserve_spacing=False)
        t.add("acc_p_in", acc_in + "\n", preserve_spacing=False)
        t.add("acc_p_an", "%s,%s\n" % (acc_in, acc_an), preserve_spacing=False)
        t.add("ins_p", ins + "\n", preserve_spacing=False)
        t.add("loc_p", loc + "\n", preserve_spacing=False)
        notes.append("replace {{uk-decl-num3}} with {{uk-adecl-manual}}")
        pagemsg("Replaced %s with %s" % (origt, str(t)))

  return str(parsed), notes

parser = blib.create_argparser("Convert {{uk-decl-num3}} to {{uk-adecl-manual}}", include_pagefile=True, include_stdin=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True,
    default_refs=["Template:uk-decl-num3"])
