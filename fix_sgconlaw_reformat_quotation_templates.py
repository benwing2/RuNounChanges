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
from blib import getparam, rmparam, set_template_name, msg, errmsg, site, tname, pname

def add_params_to_template(t, params, seen_from_params, pagemsg):
  pn = None
  for param in t.params:
    pn = pname(param)
    break
  for param, value in params:
    if re.search("^%[0-9]+$", value): # %1, %2, ... for placeholder
      if value in seen_from_params:
        value = seen_from_params[value]
      else:
        pagemsg("WARNING: Unmatched placeholder %s in replacement params" % value)
        return False
    t.add(param, value, before=pn)
  return True

def process_text_on_page(index, pagename, text):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagename, txt))
  def errandpagemsg(txt):
    errandmsg("Page %s %s: %s" % (index, pagename, txt))

  pagemsg("Processing")

  notes = []

  curtext = text + "\n"

  def reformat_template(t, from_params, totemp, to_params, text_to_incorporate=None):
    # If from-template params given, make sure they all match.
    seen_from_params = {}
    for param, value in from_params:
      if re.search("^%[0-9]+$", value): # %1, %2, ... for placeholder
        curval = getparam(t, param).strip()
        if not curval:
          pagemsg("Skipping template because expected param %s=%s doesn't have a value: %s" % (
            param, value, unicode(t)))
          return False
        seen_from_params[value] = curval
      elif getparam(t, param).strip() != value.strip():
        pagemsg("Skipping template because expected param %s=%s doesn't match: %s" % (
          param, value, unicode(t)))
        return False
    if text_to_incorporate is not None:
      for existing_param in ["passage", "text"]:
        if getparam(t, existing_param):
          pagemsg("WARNING: Can't incorporate raw passage text into {{%s}} because already has %s=: %s" %
            (fromtemp, existing_param, unicode(t)))
          return False
      text_to_incorporate = re.sub(r"\s*<br */?>\s*", " / ", text_to_incorporate)
      text_to_incorporate = re.sub(r"^''(.*)''$", r"\1", text_to_incorporate)
      t.add("passage", text_to_incorporate)
    blib.set_template_name(t, totemp)
    for param, value in from_params:
      rmparam(t, param)
    if to_params:
      if not add_params_to_template(t, to_params, seen_from_params, pagemsg):
        return False
    if text_to_incorporate is not None:
      msg_template = "reformat {{%s%s}} into {{%s%s}}, incorporating following raw passage text into passage="
    else:
      msg_template = "rename {{%s%s}} to {{%s%s}}"
    notes.append(msg_template %
        (fromtemp, "".join("|%s=%s" % (param, value) for param, value in from_params),
          totemp, "".join("|%s=%s" % (param, value) for param, value in to_params)))
    return True

  for (fromtemp, from_params), (totemp, to_params) in templates_to_rename:
    def do_reformat_template(m):
      template, text = m.groups()
      parsed = blib.parse_text(template)
      t = list(parsed.filter_templates())[0]
      origtext = m.group(0)
      if tname(t) != fromtemp:
        return origtext
      if not reformat_template(t, from_params, totemp, to_params, text_to_incorporate=text):
        return origtext
      return unicode(t) + "\n"

    curtext = re.sub(r"(\{\{%s.*?\}\})\n#+\*:\s*(.*?)\n" % re.escape(fromtemp),
        do_reformat_template, curtext)

  parsed = blib.parse_text(curtext)
  for t in parsed.filter_templates():
    tn = tname(t)
    for (fromtemp, from_params), (totemp, to_params) in templates_to_rename:
      if tn != fromtemp:
        continue
      if not reformat_template(t, from_params, totemp, to_params):
        continue
  curtext = unicode(parsed)

  return curtext.rstrip("\n"), notes

parser = blib.create_argparser("Rename and reformat quotation templates for [[User:Sgconlaw]]",
    include_pagefile=True, include_stdin=True)
parser.add_argument("--direcfile", help="File containing pairs of templates to rename (without the Template: prefix), separated by ' ||| '.",
    required=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

templates_to_rename = []
for lineno, line in blib.iter_items_from_file(args.direcfile):
  if " ||| " not in line:
    msg("Line %s: WARNING: Saw bad line in --from-to-pagefile: %s" % (lineno, line))
    continue
  fromtemp, totemp = line.split(" ||| ")
  if "|" in fromtemp:
    fromtemp, combined_params = fromtemp.split("|", 1)
    combined_params = combined_params.split("|")
    from_params = []
    for combined_param in combined_params:
      if "=" not in combined_param:
        raise ValueError("Param %s doesn't have an = sign" % combined_param)
      param, value = combined_param.split("=")
      from_params.append((param, value))
  else:
    from_params = []
  if "|" in totemp:
    totemp, combined_params = totemp.split("|", 1)
    combined_params = combined_params.split("|")
    to_params = []
    for combined_param in combined_params:
      if "=" not in combined_param:
        raise ValueError("Param %s doesn't have an = sign" % combined_param)
      param, value = combined_param.split("=")
      to_params.append((param, value))
  else:
    to_params = []
  templates_to_rename.append(((fromtemp, from_params), (totemp, to_params)))
blib.do_pagefile_cats_refs(args, start, end, process_text_on_page,
    default_refs=["Template:%s" % fromtemp for (fromtemp, from_params), (totemp, to_params) in templates_to_rename],
    edit=True, stdin=True, skip_ignorable_pages=True)
