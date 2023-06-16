#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site, tname

templates_to_rewrite = {
  "sv-compound": ["compound", "sv"],
  "ar-singulative of": ["singulative of", "ar"],
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
    if tn in templates_to_rewrite:
      new_template_name, lang = templates_to_rewrite[tn]
      # Fetch all params.
      params = []
      for param in t.params:
        pname = str(param.name)
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
      blib.set_template_name(t, new_template_name)
      notes.append("rename {{%s}} to {{%s|%s}}" %
        (tn, new_template_name, lang))

    if str(t) != origt:
      pagemsg("Replaced <%s> with <%s>" % (origt, str(t)))

  return str(parsed), notes

parser = blib.create_argparser("Rename language-specific templates to generic templates")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

for template in templates_to_rewrite:
  msg("Processing references to Template:%s" % template)
  for i, page in blib.references("Template:%s" % template, start, end):
    blib.do_edit(page, i, process_page, save=args.save, verbose=args.verbose)
