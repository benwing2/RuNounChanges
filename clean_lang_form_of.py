#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, errandmsg, site, tname

sv_templates_with_plural_of = [
  "sv-verb-form-imp",
  "sv-verb-form-past",
  "sv-verb-form-past-pass",
  "sv-verb-form-pre",
]

sv_templates_with_obsoleted_by = [
  "sv-noun-form-def-pl",
]

ca_templates_with_val = [
  "ca-form of",
]

nl_templates_with_comp_of_sup_of = [
  "nl-adj form of",
]

all_templates = (
  sv_templates_with_plural_of +
  sv_templates_with_obsoleted_by +
  ca_templates_with_val +
  nl_templates_with_comp_of_sup_of +
  []
)

def process_page(page, index, parsed):
  pagetitle = unicode(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")
  notes = []

  text = unicode(page.text)

  if ":" in pagetitle and not re.search(
      "^(Citations|Appendix|Reconstruction|Transwiki|Talk|Wiktionary|[A-Za-z]+ talk):", pagetitle):
    pagemsg("WARNING: Colon in page title and not a recognized namespace to include, skipping page")
    return None, None

  templates_to_replace = []

  for t in parsed.filter_templates():
    tn = tname(t)

    if tn in sv_templates_with_plural_of:
      plural_of = getparam(t, "plural of")
      if plural_of:
        origt = unicode(t)
        rmparam(t, "plural of")
        newt = "{{sv-obs pl|%s}}, %s" % (plural_of, unicode(t))
        templates_to_replace.append((origt, newt, "move plural of= in {{%s}} to {{sv-obs pl}} outside of template" % tn))

    if tn in sv_templates_with_obsoleted_by:
      obsoleted_by = getparam(t, "obsoleted by")
      if obsoleted_by:
        origt = unicode(t)
        rmparam(t, "obsoleted by")
        newt = "{{sv-obs by|%s}}, %s" % (obsoleted_by, unicode(t))
        templates_to_replace.append((origt, newt, "move plural of= in {{%s}} to {{sv-obs by}} outside of template" % tn))

    if tn in ca_templates_with_val:
      val = getparam(t, "val")
      val2 = getparam(t, "val2")
      if val:
        origt = unicode(t)
        rmparam(t, "val")
        rmparam(t, "val2")
        newt = "%s ({{ca-val|%s%s}})" % (unicode(t), val, "|" + val2 if val2 else "")
        templates_to_replace.append((origt, newt, "move val= in {{%s}} to {{ca-val}} outside of template" % tn))

    if tn in nl_templates_with_comp_of_sup_of:
      comp_of = getparam(t, "comp-of")
      sup_of = getparam(t, "sup-of")
      if comp_of:
        comp_of = ", the {{nc comp of|nl|%s}}" % comp_of
      if sup_of:
        sup_of = ", the {{nc sup of|nl|%s}}" % sup_of
      if comp_of or sup_of:
        origt = unicode(t)
        rmparam(t, "comp-of")
        rmparam(t, "sup-of")
        newt = "%s%s%s" % (unicode(t), comp_of, sup_of)
        templates_to_replace.append((origt, newt, "move comp-of=/sup-of== in {{%s}} to {{nc comp of}}/{{nc sup of}} outside of template" % tn))

  for curr_template, repl_template, note in templates_to_replace:
    text, replaced = blib.replace_in_text(text, curr_template, repl_template, pagemsg)
    if replaced:
      notes.append(note)

  return text, notes

parser = blib.create_argparser("Clean up various form-of templates needing text moved outside of template into separate template")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

for template in all_templates:
  errandmsg("Processing references to Template:%s" % template)
  for i, page in blib.references("Template:%s" % template, start, end):
    blib.do_edit(page, i, process_page, save=args.save, verbose=args.verbose)
