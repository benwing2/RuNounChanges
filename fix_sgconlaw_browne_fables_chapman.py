#!/usr/bin/env python3
# -*- coding: utf-8 -*-

# Move text outside of {{RQ:Browne Errors}}, {{RQ:L'Estrange Fables}} and {{RQ:Chapman Odyssey}} inside,
# with some renaming of templates and args. Specifically, we replace:
#
# #* {{RQ:Browne Errors}}
# #*: Preventive physic [...] preventeth sickness in the healthy, or the '''recourse''' thereof in the valetudinary.
#
# with:
#  
# #* {{RQ:Browne Pseudodoxia Epidemica|passage=Preventive physic [...] preventeth sickness in the healthy, or the '''recourse''' thereof in the valetudinary.}}
#
# and
#
# #* {{RQ:L'Estrange Fables|passage=[passage]}} or
# #* {{RQ:L'Estrange Fables}}
# #*: [passage]
#
# with:
#
# #* {{RQ:L'Estrange Fables of Aesop|passage=[passage]}}
#
# and
#
# #* {{RQ:Chapman Odyssey}}
# #*: The doors of plank were; their '''close''' exquisite.
#
# with:
#
# #* {{RQ:Homer Chapman Odysseys|passage=The doors of plank were; their '''close''' exquisite.}}

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, set_template_name, msg, errmsg, site, tname

def process_text_on_page(index, pagename, text):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagename, txt))
  def errandpagemsg(txt):
    errandmsg("Page %s %s: %s" % (index, pagename, txt))

  pagemsg("Processing")

  notes = []

  curtext = text + "\n"

  def replace_browne_errors(m):
    template, text = m.groups()
    parsed = blib.parse_text(template)
    t = list(parsed.filter_templates())[0]
    if tname(t) != "RQ:Browne Errors":
      return m.group(0)
    text = re.sub(r"\s*<br */?>\s*", " / ", text)
    text = re.sub(r"^''(.*)''$", r"\1", text)
    t.add("passage", text)
    blib.set_template_name(t, "RQ:Browne Pseudodoxia Epidemica")
    notes.append("reformat {{RQ:Browne Errors}} into {{RQ:Browne Pseudodoxia Epidemica}}")
    return str(t) + "\n"

  curtext = re.sub(r"(\{\{RQ:Browne Errors.*?\}\})\n#+\*:\s*(.*?)\n",
      replace_browne_errors, curtext)

  def replace_lestrange_fables(m):
    template, text = m.groups()
    parsed = blib.parse_text(template)
    t = list(parsed.filter_templates())[0]
    if tname(t) != "RQ:L'Estrange Fables":
      return m.group(0)
    text = re.sub(r"\s*<br */?>\s*", " / ", text)
    text = re.sub(r"^''(.*)''$", r"\1", text)
    t.add("passage", text)
    blib.set_template_name(t, "RQ:L'Estrange Fables of Aesop")
    notes.append("reformat {{RQ:L'Estrange Fables}} into {{RQ:L'Estrange Fables of Aesop}}")
    return str(t) + "\n"

  curtext = re.sub(r"(\{\{RQ:L'Estrange Fables.*?\}\})\n#+\*:\s*(.*?)\n",
      replace_lestrange_fables, curtext)

  parsed = blib.parse_text(curtext)
  for t in parsed.filter_templates():
    tn = tname(t)
    if tn == "RQ:L'Estrange Fables":
      blib.set_template_name(t, "RQ:L'Estrange Fables of Aesop")
      notes.append("rename {{RQ:L'Estrange Fables}} to {{RQ:L'Estrange Fables of Aesop}}")
  curtext = str(parsed)

  def replace_chapman_odyssey(m):
    template, text = m.groups()
    parsed = blib.parse_text(template)
    t = list(parsed.filter_templates())[0]
    if tname(t) != "RQ:Chapman Odyssey":
      return m.group(0)
    text = re.sub(r"\s*<br */?>\s*", " / ", text)
    text = re.sub(r"^''(.*)''$", r"\1", text)
    t.add("passage", text)
    blib.set_template_name(t, "RQ:Homer Chapman Odysseys")
    notes.append("reformat {{RQ:Chapman Odyssey}} into {{RQ:Homer Chapman Odysseys}}")
    return str(t) + "\n"

  curtext = re.sub(r"(\{\{RQ:Chapman Odyssey.*?\}\})\n#+\*:\s*(.*?)\n",
      replace_chapman_odyssey, curtext)

  return curtext.rstrip("\n"), notes

parser = blib.create_argparser("Reformat {{RQ:Browne Errors}}, {{RQ:L'Estrange Fables}} and {{RQ:Chapman Odyssey}}",
    include_pagefile=True, include_stdin=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page,
    default_refs=["Template:RQ:Browne Errors", "Template:RQ:L'Estrange Fables", "Template:RQ:Chapman Odyssey"],
    edit=True, stdin=True)
