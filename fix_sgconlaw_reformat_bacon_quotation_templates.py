#!/usr/bin/env python3
# -*- coding: utf-8 -*-

# Rename Bacon quotation templates. In the process, we move passage text outside of the template inside. For example,
# if the --direcfile specifies 'RQ:Bacon Of The True Greatness ||| Of the True Greatness of Kingdoms and Estates', we replace
#
# #* {{RQ:Bacon Of The True Greatness}}
# #*: wealth {{...}}'''respondent''' {{...}}to payment and contributions
#
# with:
#  
# #* {{RQ:Bacon Essayes|chapter=Of the True Greatness of Kingdoms and Estates|passage=wealth {{...}}'''respondent''' {{...}}to payment and contributions}}
#
# If 'RQ:Bacon Of The True Greatness' occurs without raw passage text following, we just replace with 'RQ:Bacon Essayes|chapter=Of the True Greatness of Kingdoms and Estates'.

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

  for fromtemp, chapter in templates_to_rename:
    def reformat_template(m):
      template, text = m.groups()
      parsed = blib.parse_text(template)
      t = list(parsed.filter_templates())[0]
      if tname(t) != fromtemp:
        return m.group(0)
      for existing_param in ["passage", "text"]:
        if getparam(t, existing_param):
          pagemsg("WARNING: Can't incorporate raw passage text into {{%s}} because already has %s=: %s" %
            (fromtemp, existing_param, str(t)))
          return m.group(0)
      text = re.sub(r"\s*<br */?>\s*", " / ", text)
      text = re.sub(r"^''(.*)''$", r"\1", text)
      t.add("chapter", chapter)
      t.add("passage", text)
      blib.set_template_name(t, "RQ:Bacon Essayes")
      notes.append("reformat {{%s}} into {{RQ:Bacon Essayes|chapter=%s}}, incorporating following raw passage text into passage=" %
          (fromtemp, chapter))
      return str(t) + "\n"

    curtext = re.sub(r"(\{\{%s.*?\}\})\n#+\*:\s*(.*?)\n" % re.escape(fromtemp),
        reformat_template, curtext)

  parsed = blib.parse_text(curtext)
  for t in parsed.filter_templates():
    tn = tname(t)
    if tn in templates_to_rename_dict:
      chapter = templates_to_rename_dict[tn]
      t.add("chapter", chapter)
      blib.set_template_name(t, chapter)
      notes.append("rename {{%s}} to {{RQ:Bacon Essayes|chapter=%s}}" % (tn, chapter))
  curtext = str(parsed)

  return curtext.rstrip("\n"), notes

parser = blib.create_argparser("Rename and reformat Bacon quotation templates for [[User:Sgconlaw]]",
    include_pagefile=True, include_stdin=True)
parser.add_argument("--direcfile", help="File containing templates to rename (without the Template: prefix) and the `chapter` parameter, separated by ' ||| '.",
    required=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

templates_to_rename = []
for lineno, line in blib.iter_items_from_file(args.direcfile):
  if " ||| " not in line:
    msg("Line %s: WARNING: Saw bad line in --from-to-pagefile: %s" % (lineno, line))
    continue
  fromtemp, chapter = line.split(" ||| ")
  templates_to_rename.append((fromtemp, chapter))
templates_to_rename_dict = dict(templates_to_rename)
blib.do_pagefile_cats_refs(args, start, end, process_text_on_page,
    default_refs=["Template:%s" % fromtemp for fromtemp, chapter in templates_to_rename],
    edit=True, stdin=True, filter_pages=lambda pagename: ':' not in pagename)
