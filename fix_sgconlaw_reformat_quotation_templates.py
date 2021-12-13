#!/usr/bin/env python
# -*- coding: utf-8 -*-

# Rename quotation templates. In the process, we move passage text outside of the template inside. For example,
# if the --direcfile specifies 'RQ:Browne Errors ||| RQ:Browne Pseudodoxia Epidemica', we replace
#
# #* {{RQ:Browne Errors}}
# #*: Preventive physic [...] preventeth sickness in the healthy, or the '''recourse''' thereof in the valetudinary.
#
# with:
#  
# #* {{RQ:Browne Pseudodoxia Epidemica|passage=Preventive physic [...] preventeth sickness in the healthy, or the '''recourse''' thereof in the valetudinary.}}
#
# If 'RQ:Browne Errors' occurs without raw passage text following, we just replace with 'RQ:Browne Pseudodoxia Epidemica'.

import pywikibot, re, sys, codecs, argparse

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

  for fromtemp, totemp in templates_to_rename:
    def reformat_template(m):
      template, text = m.groups()
      parsed = blib.parse_text(template)
      t = list(parsed.filter_templates())[0]
      if tname(t) != fromtemp:
        return m.group(0)
      for existing_param in ["passage", "text"]:
        if getparam(t, existing_param):
          pagemsg("WARNING: Can't incorporate raw passage text into {{%s}} because already has %s=: %s" %
            (fromtemp, existing_param, unicode(t)))
          return m.group(0)
      text = re.sub(r"\s*<br */?>\s*", " / ", text)
      text = re.sub(r"^''(.*)''$", r"\1", text)
      t.add("passage", text)
      blib.set_template_name(t, totemp)
      notes.append("reformat {{%s}} into {{%s}}, incorporating following raw passage text into passage=" %
          (fromtemp, totemp))
      return unicode(t) + "\n"

    curtext = re.sub(r"(\{\{%s.*?\}\})\n#+\*:\s*(.*?)\n" % re.escape(fromtemp),
        reformat_template, curtext)

  parsed = blib.parse_text(curtext)
  for t in parsed.filter_templates():
    tn = tname(t)
    if tn in templates_to_rename_dict:
      blib.set_template_name(t, templates_to_rename_dict[tn])
      notes.append("rename {{%s}} to {{%s}}" % (tn, templates_to_rename_dict[tn]))
  curtext = unicode(parsed)

  return curtext.rstrip("\n"), notes

parser = blib.create_argparser("Rename and reformat quotation templates for [[User:Sgconlaw]]",
    include_pagefile=True, include_stdin=True)
parser.add_argument("--direcfile", help="File containing pairs of templates to rename (without the Template: prefix), separated by ' ||| '.",
    required=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

templates_to_rename = []
direcfile_lines = [x.strip() for x in codecs.open(args.direcfile, "r", "utf-8")]
for line in direcfile_lines:
  if " ||| " not in line:
    msg("WARNING: Saw bad line in --from-to-pagefile: %s" % line)
    continue
  fromtemp, totemp = line.split(" ||| ")
  templates_to_rename.append((fromtemp, totemp))
templates_to_rename_dict = dict(templates_to_rename)
blib.do_pagefile_cats_refs(args, start, end, process_text_on_page,
    default_refs=["Template:%s" % fromtemp for fromtemp, totemp in templates_to_rename],
    edit=True, stdin=True)
