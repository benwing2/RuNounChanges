#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, errandmsg, site, tname

# col templates
templates_to_rename = {
  "bg-adjective extended of":
    ["bg-adj form of", "masculine", "extended"],
  "bg-adjective neuter of":
    ["bg-adj form of", "neuter", "indefinite"],
  "bg-plural count of":
    ["bg-noun form of", "count"],
  "bg-singular definite object form of":
    ["bg-noun form of", "singular", "definite", "object"],
  "bg-singular definite subject form of":
    ["bg-noun form of", "singular", "definite", "subject"],
}

def process_page(page, index, parsed):
  pagetitle = str(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")
  notes = []

  for t in parsed.filter_templates():
    origt = str(t)
    tn = tname(t)
    if tn in templates_to_rename:
      template_specs = templates_to_rename[tn]
      new_name, new_params = template_specs[0], template_specs[1:]
      main_entry_param = "adj" if new_name == "bg-adj form of" else "noun"
      blib.set_template_name(t, new_name)
      # Fetch all params.
      params = []
      old_1 = getparam(t, "1")
      for param in t.params:
        pname = str(param.name)
        if pname.strip() in ["1", "lang", "sc"]:
          continue
        if pname.strip() in ["2", "3", "4"]:
          errandmsg("WARNING: Found %s= in %s" % (pname.strip(), origt))
        params.append((pname, param.value, param.showkey))
      # Erase all params.
      del t.params[:]
      # Put back basic params
      for param_index, paramval in enumerate(new_params):
        t.add(str(param_index + 1), paramval)
      if not old_1:
        errandmsg("WARNING: No 1= in %s" % origt)
      else:
        t.add(main_entry_param, old_1)
      # Put remaining parameters in order.
      for name, value, showkey in params:
        t.add(name, value, showkey=showkey, preserve_spacing=False)
      notes.append("rename {{%s}} to {{%s|%s|%s={{{1}}}}}" % (tn,
        new_name, "|".join(new_params), main_entry_param))

    if str(t) != origt:
      pagemsg("Replaced <%s> with <%s>" % (origt, str(t)))

  return str(parsed), notes

parser = blib.create_argparser("Rename overly specific {{bg-*}} templates to more general ones")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

for template in templates_to_rename:
  for i, page in blib.references("Template:%s" % template, start, end):
    blib.do_edit(page, i, process_page, save=args.save, verbose=args.verbose)
