#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, msg, site, tname

# col templates
templates_to_rename = {
  "der1": "col1",
  "ant2": "col2",
  "coord2": "col2",
  "hyp2": "col2",
  "syn2": "col2",
  "desc3": "col3",
  "hyp3": "col3",
  "syn3": "col3",
  "ant4": "col4",
  "hyp4": "col4",
  "syn4": "col4",
  "der5": "col5",
  "rel5": "col5",
  "der2-u": "col2-u",
  "der3-u": "col3-u",
  "der4-u": "col4-u",
  "der5-u": "col5-u",
}

templates_to_clean = templates_to_rename.keys() + [
  "der2", "der3", "der4",
  "rel2", "rel3", "rel4",
]
  
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
      blib.set_template_name(t, templates_to_rename[tn])
      notes.append("rename {{%s}} to {{%s}}" % (tn, templates_to_rename[tn]))
    if tn in templates_to_clean:
      # First move lang= to 1=
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

      # Then remove unnecessary links
      lang = getparam(t, "1").strip()
      num = 2
      oldt = str(t)
      while True:
        link = getparam(t, str(num))
        if not link:
          break
        m = re.search(r"^(\s*)\{\{l\|%s\|([^|{}]*)\}\}(\s*)$" % lang, link)
        if m:
          t.add(str(num), "%s%s%s" % m.groups(), preserve_spacing=False)
        m = re.search(r"^(\s*)\[\[([^|\[\]]*)\]\](\s*)$", link)
        if m:
          t.add(str(num), "%s%s%s" % m.groups(), preserve_spacing=False)
        num += 1
      if oldt != str(t):
        notes.append("remove unnecessary links in {{%s}}" % tn)

    if str(t) != origt:
      pagemsg("Replaced <%s> with <%s>" % (origt, str(t)))

  return str(parsed), notes

parser = blib.create_argparser("In multicolumn templates, orphan lesser-used ones, move lang= to 1= and remove unnecessary links")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

for template in templates_to_clean:
  for i, page in blib.references("Template:%s" % template, start, end):
    blib.do_edit(page, i, process_page, save=args.save, verbose=args.verbose)
