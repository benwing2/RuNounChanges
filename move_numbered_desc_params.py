#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, set_template_name, msg, errmsg, site, tname

def process_text_on_page(index, pagename, text):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagename, txt))
  def errandpagemsg(txt):
    errandmsg("Page %s %s: %s" % (index, pagename, txt))

  if "desc" not in text:
    return

  #pagemsg("Processing")

  notes = []

  parsed = blib.parse_text(text)
  for t in parsed.filter_templates():
    origt = str(t)
    tn = tname(t)
    if tn in ["desc", "descendant", "desctree", "descendants tree"]:
      if t.has("4"):
        gloss = getparam(t, "4")
        if gloss:
          t.add("t", gloss, before="4")
          notes.append("move 4= to t= in {{%s}}" % tn)
        else:
          notes.append("remove extraneous 4= in {{%s}}" % tn)
        rmparam(t, "4")

      if t.has("3"):
        alt = getparam(t, "3")
        if alt:
          t.add("alt", alt, before="3")
          notes.append("move 3= to alt= in {{%s}}" % tn)
        else:
          notes.append("remove extraneous 3= in {{%s}}" % tn)
        rmparam(t, "3")

      need_to_move_genders = False
      for i in range(2, 20):
        if t.has("g%s" % i):
          need_to_move_genders = True
          break
      if need_to_move_genders:
        genders = []
        g = getparam(t, "g")
        if g:
          genders.append(g)
        for i in range(2, 20):
          g = getparam(t, "g%s" % i)
          rmparam(t, "g%s" % i)
          if g:
            genders.append(g)
        t.add("g", ",".join(genders))
        notes.append("consolidate genders in {{%s}}" % tn)

    if origt != str(t):
      pagemsg("Replaced %s with %s" % (origt, str(t)))

  return str(parsed), notes

parser = blib.create_argparser("Move 3=/4= in {{desc}}/{{desctree}} to alt=/t=, consolidate genders", include_pagefile=True,
    include_stdin=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, default_refs=["Template:desc", "Template:desctree"],
    edit=True, stdin=True)
