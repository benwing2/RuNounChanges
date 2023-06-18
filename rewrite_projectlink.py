#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, msg, site, tname, pname
from collections import defaultdict

seen_projects = defaultdict(int)

def process_text_on_page(index, pagetitle, text):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  if blib.page_should_be_ignored(pagetitle):
    return

  if not args.stdin:
    pagemsg("Processing")

  notes = []
  parsed = blib.parse_text(text)
  for t in parsed.filter_templates():
    origt = str(t)
    def getp(param):
      return getparam(t, param)
    tn = tname(t)
    if tn == "projectlink":
      project = getp("1")
      if "{" in project:
        pagemsg("WARNING: Saw brace in 1=, not changing: %s" % str(t))
        continue
      elif not project:
        pagemsg("WARNING: Saw blank 1=, not changing: %s" % str(t))
        continue
      project = re.sub("^[Ww]iki", "", project)
      movelang = False
      if project == "quotes":
        project = "quote"
      if project == "quote":
        newname = "R:wquote"
        movelang = True
      elif project == "source":
        newname = "R:wsource"
        movelang = True
      elif project == "books":
        newname = "R:wbooks"
        movelang = True
      elif project == "versity":
        newname = "R:wversity"
        movelang = True
      elif project == "news":
        newname = "R:wnews"
        movelang = True
      elif project == "pedia":
        newname = "pedia"
      elif project == "species":
        newname = "specieslite"
      elif project == "1911":
        newname = "R:Britannica 1911"
      elif project == "1922":
        newname = "R:Britannica 1922"
      elif project == "AmCyc":
        newname = "R:American Cyclopedia"
      elif project == "Collier's":
        newname = "R:Collier's"
      elif project == "NIE":
        newname = "R:New International Encyclopedia"
      elif project == "NSRW":
        newname = "R:New Student's Reference Work"
      elif project == "Americana":
        newname = "R:Americana"
      elif project == "commons":
        newname = "R:commons"
      elif project == "meta":
        newname = "R:metawiki"
      else:
        pagemsg("WARNING: Unknown project '%s', not changing: %s" % (project, str(t)))
        continue
      # FIXME, eliminate disambig, dab manually
      if movelang:
        term = getp("2")
        alt = getp("3")
        origlang = getp("lang")
        lang = origlang or "en"
        named_params = []
        for param in t.params:
          pn = pname(param)
          pv = str(param.value)
          if pn not in ["1", "2", "e", "lang"]:
            named_params.append((pn, pv))
        del t.params[:]
        t.add("1", lang)
        if term or alt:
          t.add("2", term)
        if alt:
          t.add("3", alt)
        for pn, pv in named_params:
          t.add(pn, pv, preserve_spacing=False)
        blib.set_template_name(t, newname)
      else:
        link = getp("2")
        alt = getp("3")
        if alt:
          rmparam(t, "1")
          t.add("1", link or "", before="2")
          rmparam(t, "2")
          t.add("2", alt, before="3")
          rmparam(t, "3")
        elif link:
          rmparam(t, "1")
          t.add("1", link, before="2")
          rmparam(t, "2")
          rmparam(t, "3")
        else:
          rmparam(t, "1")
          rmparam(t, "2")
          rmparam(t, "3")
      seen_projects[project] += 1
      blib.set_template_name(t, newname)
      if movelang:
        if not origlang:
          notes.append("rename {{projectlink|%s}} -> {{%s|en}}" % (project, newname))
        else:
          notes.append("rename {{projectlink|%s|lang=%s}} -> {{%s|%s}}" % (project, lang, newname, lang))
      else:
        notes.append("rename {{projectlink|%s}} -> {{%s}}" % (project, newname))

    if origt != str(t):
      pagemsg("Replaced %s with %s" % (origt, str(t)))

  return str(parsed), notes

parser = blib.create_argparser(u"Rewrite {{projectlink}}", include_pagefile=True, include_stdin=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True, default_refs=["Template:projectlink"])

msg("Seen projects:")
msg("--------------")
for project, count in sorted(seen_projects.items(), key=lambda x: -x[1]):
  msg("%30s = %s" % (project, count))

