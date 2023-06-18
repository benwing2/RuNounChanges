#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, msg, site, tname

#back_formation_templates = ["back-formation", "back-form", "backform", "bac", "bf"]
#templates_to_move_lang = back_formation_templates + [
#  "blend", "blend of",
#  "clipping",
#  "deverbal", "deverbative",
#  "doublet", "doublet of", "etymtwin",
#  "ellipsis",
#  "rebracketing", "metanalysis",
#  "reduplication", "reduplicated",
#  "univerbation"
#]
#templates_to_move_lang = [
#  "pre", "prefix",
#  "suf", "suffix",
#  "con", "confix",
#  "com", "compound",
#  "infix",
#  "circumfix"
#]
templates_to_move_lang = [
  "onomatopoeic", "Onomatopoeic", "onom",
  "unknown", "unk", "unk.",
]

rename_templates = {
  "blend of": "blend",
  "deverbative": "deverbal",
  "backform": "back-form",
  "bac": "back-form",
  "etymtwin": "doublet",
  "doublet of": "doublet",
  "metanalysis": "rebracketing",
  "reduplicated": "reduplication",
  "Onomatopoeic": "onomatopoeic",
  "unk.": "unk",
}

def process_page(page, index, parsed):
  pagetitle = str(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")
  notes = []

  # WARNING: Not idempotent, already run.

  #to_add_period = []

  #for t in parsed.filter_templates():
  #  tn = tname(t)
  #  if tn in back_formation_templates:
  #    if not getparam(t, "nodot"):
  #      to_add_period.append(str(t))

  #text = str(page.text)
  #for curr_template in to_add_period:
  #  repl_template = curr_template + "."
  #  found_curr_template = curr_template in text
  #  if not found_curr_template:
  #    pagemsg("WARNING: Unable to locate template: %s" % curr_template)
  #    continue
  #  found_repl_template = repl_template in text
  #  if found_repl_template:
  #    pagemsg("WARNING: Already found template with period: %s" % repl_template)
  #    continue
  #  newtext = text.replace(curr_template, repl_template)
  #  newtext_text_diff = len(newtext) - len(text)
  #  repl_curr_diff = len(repl_template) - len(curr_template)
  #  ratio = float(newtext_text_diff) / repl_curr_diff
  #  if ratio == int(ratio):
  #    if int(ratio) > 1:
  #      pagemsg("WARNING: Replaced %s occurrences of curr=%s with repl=%s"
  #          % (int(ratio), curr_template, repl_template))
  #  else:
  #    pagemsg("WARNING: Something wrong, length mismatch during replacement: Expected length change=%s, actual=%s, ratio=%.2f, curr=%s, repl=%s"
  #        % (repl_curr_diff, newtext_text_diff, ratio, curr_template,
  #          repl_template))
  #  text = newtext
  #  notes.append("add period to back-formation template without nodot=")

  #parsed = blib.parse_text(text)

  for t in parsed.filter_templates():
    origt = str(t)
    tn = tname(t)
    #if tn in back_formation_templates:
    #  if getparam(t, "nodot"):
    #    rmparam(t, "nodot")
    #    notes.append("remove nodot= from {{%s}}" % tn)
    if tn in rename_templates:
      blib.set_template_name(t, rename_templates[tn])
      notes.append("rename {{%s}} to {{%s}}" % (tn, rename_templates[tn]))
    if tn in templates_to_move_lang:
      lang = getparam(t, "lang")
      if lang:
        # Fetch all params.
        params = []
        for param in t.params:
          pname = str(param.name)
          if pname.strip() != "lang":
            params.append((pname, param.value, param.showkey))
        # Erase all params.
        del t.params[:]
        t.add("1", lang)
        # Put remaining parameters in order.
        for name, value, showkey in params:
          if re.search("^[0-9]+$", name):
            t.add(str(int(name) + 1), value, showkey=showkey, preserve_spacing=False)
          else:
            t.add(name, value, showkey=showkey, preserve_spacing=False)
        notes.append("move lang= to 1= in {{%s}}" % tn)

    if str(t) != origt:
      pagemsg("Replaced <%s> with <%s>" % (origt, str(t)))

  return str(parsed), notes

parser = blib.create_argparser("Clean up etymology-related templates, moving lang= to 1= and renaming some")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

for template in templates_to_move_lang:
  msg("Processing references to Template:%s" % template)
  for i, page in blib.references("Template:%s" % template, start, end):
    blib.do_edit(page, i, process_page, save=args.save, verbose=args.verbose)
