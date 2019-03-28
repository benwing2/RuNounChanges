#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site, tname

from form_of_templates import (
  language_specific_alt_form_of_templates,
  alt_form_of_templates,
  language_specific_form_of_templates,
  form_of_templates
)

# templates_to_move_lang = alt_form_of_templates + form_of_templates
templates_to_move_lang = []
templates_to_remove_empty_dot = (
  form_of_templates + language_specific_form_of_templates
)
templates_to_check_for_empty_dot = (
  alt_form_of_templates + language_specific_alt_form_of_templates
)
#templates_to_remove_nodot = (
#  form_of_templates + language_specific_form_of_templates
#)
templates_to_remove_nodot = []

def process_page(page, index, parsed):
  pagetitle = unicode(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")
  notes = []

  for t in parsed.filter_templates():
    origt = unicode(t)
    tn = tname(t)
    if tn in templates_to_remove_nodot:
      if t.has("nodot"):
        rmparam(t, "nodot")
        notes.append("remove effectless nodot= from {{%s}}" % tn)
    if tn in templates_to_remove_empty_dot:
      if t.has("dot"):
        if getparam(t, "dot") and getparam(t, "dot") != "<nowiki/>":
          pagemsg("WARNING: non-empty dot= in form_of_t template: %s" % unicode(t))
        rmparam(t, "dot")
        notes.append("remove effectless empty dot= from {{%s}}" % tn)
    if tn in templates_to_check_for_empty_dot:
      if t.has("dot") and (not getparam(t, "dot") or getparam(t, "dot") == "<nowiki/>"):
        pagemsg("WARNING: empty dot= in alt_form_of_t template: %s" % unicode(t))
        rmparam(t, "dot")
        t.add("nodot", "1")
        notes.append("convert empty dot= to nodot=1 in {{%s}}" % tn)
    if tn in templates_to_move_lang:
      lang = getparam(t, "lang")
      if lang:
        # Fetch all params.
        params = []
        for param in t.params:
          pname = unicode(param.name)
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

    if unicode(t) != origt:
      pagemsg("Replaced <%s> with <%s>" % (origt, unicode(t)))

  return unicode(parsed), notes

parser = blib.create_argparser("Move lang= to 1= and remove effectless nodot= in form-of templates")
parser.add_argument('--pagefile', help="File containing pages to fix.")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

#for template in templates_to_move_lang:
#  msg("Processing references to Template:%s" % template)
#  for i, page in blib.references("Template:%s" % template, start, end):
#    blib.do_edit(page, i, process_page, save=args.save, verbose=args.verbose)
#for ref in ["Template:tracking/form-of/form-of-t/unused/nodot"]:
#  msg("Processing references to %s" % ref)
#  for i, page in blib.references(ref, start, end):
#    blib.do_edit(page, i, process_page, save=args.save, verbose=args.verbose)
lines = [x.strip() for x in codecs.open(args.pagefile, "r", "utf-8")]
for i, page in blib.iter_items(lines, start, end):
    blib.do_edit(pywikibot.Page(site, page), i, process_page, save=args.save, verbose=args.verbose)
