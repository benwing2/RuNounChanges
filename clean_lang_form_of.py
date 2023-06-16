#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, errandmsg, site, tname

sv_verb_templates_with_plural_of = [
  "sv-verb-form-imp",
  "sv-verb-form-past",
  "sv-verb-form-past-pass",
  "sv-verb-form-pre",
]

sv_noun_templates_with_obsoleted_by = [
  "sv-noun-form-def-pl",
]

ca_templates_with_val = [
  "ca-form of",
]

nl_templates_with_comp_of_sup_of = [
  "nl-adj form of",
]

el_templates_with_active = [
  "el-form-of-verb",
  "el-verb form of",
]

# WARNING! Not idempotent.
el_templates_to_move_dot = [
  "el-participle of",
]

def init_all_templates(move_dot):
  global all_templates

  all_templates = (
#    sv_verb_templates_with_plural_of +
#    sv_noun_templates_with_obsoleted_by +
#    ca_templates_with_val +
#    nl_templates_with_comp_of_sup_of +
#    el_templates_with_active +
#    (el_templates_to_move_dot if move_dot else []) +
    []
  )


def process_text_on_page(index, pagetitle, text):
  global args
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  notes = []

  parsed = blib.parse_text(text)

  templates_to_replace = []

  # begin original process_page() code
  for t in parsed.filter_templates():
    tn = tname(t)

    if tn in sv_verb_templates_with_plural_of and tn in all_templates:
      plural_of = getparam(t, "plural of")
      if plural_of:
        origt = str(t)
        rmparam(t, "plural of")
        newt = "{{sv-obs verb pl|%s}} %s" % (plural_of, str(t))
        templates_to_replace.append((origt, newt, "move plural of= in {{%s}} to {{sv-obs verb pl}} outside of template" % tn))

    if tn in sv_noun_templates_with_obsoleted_by and tn in all_templates:
      obsoleted_by = getparam(t, "obsoleted by")
      if obsoleted_by:
        origt = str(t)
        rmparam(t, "obsoleted by")
        newt = "{{sv-obs noun form|%s}} %s" % (obsoleted_by, str(t))
        templates_to_replace.append((origt, newt, "move plural of= in {{%s}} to {{sv-obs noun form}} outside of template" % tn))

    if tn in ca_templates_with_val and tn in all_templates:
      val = getparam(t, "val")
      val2 = getparam(t, "val2")
      if val:
        origt = str(t)
        rmparam(t, "val")
        rmparam(t, "val2")
        newt = "%s {{ca-val|%s%s}}" % (str(t), val, "|" + val2 if val2 else "")
        templates_to_replace.append((origt, newt, "move val= in {{%s}} to {{ca-val}} outside of template" % tn))

    if tn in nl_templates_with_comp_of_sup_of and tn in all_templates:
      comp_of = getparam(t, "comp-of")
      sup_of = getparam(t, "sup-of")
      if comp_of:
        comp_of = ", the {{nc comp of|nl|%s}}" % comp_of
      if sup_of:
        sup_of = ", the {{nc sup of|nl|%s}}" % sup_of
      if comp_of or sup_of:
        origt = str(t)
        rmparam(t, "comp-of")
        rmparam(t, "sup-of")
        newt = "%s%s%s" % (str(t), comp_of, sup_of)
        templates_to_replace.append((origt, newt, "move comp-of=/sup-of== in {{%s}} to {{nc comp of}}/{{nc sup of}} outside of template" % tn))

    if tn in el_templates_with_active and tn in all_templates:
      active = getparam(t, "active")
      ta = getparam(t, "ta")
      if active:
        origt = str(t)
        rmparam(t, "active")
        rmparam(t, "ta")
        newt = "%s, {{nc pass of|el|%s%s}}" % (str(t), active, "|t=" + ta if ta else "")
        templates_to_replace.append((origt, newt, "move active= in {{%s}} to {{nc pass of}} outside of template" % tn))

    if tn in el_templates_to_move_dot and tn in all_templates:
      origt = str(t)
      nodot = getparam(t, "nodot")
      rmparam(t, "nodot") # in case it's blank
      if nodot:
        templates_to_replace.append((origt, str(t), "remove nodot= from {{%s}}, with changed semantics" % tn))
      else:
        newt = "%s." % str(t)
        templates_to_replace.append((origt, newt, "add explicit final period to {{%s}} when nodot= not specified, due to change in semantics" % tn))

  for curr_template, repl_template, note in templates_to_replace:
    text, replaced = blib.replace_in_text(text, curr_template, repl_template, pagemsg)
    if replaced:
      notes.append(note)
  # end original process_page() code

  # begin original process_page_2() code
  newtext = re.sub(r"(\{\{en-third-person singular of.*?\}\}.*?)\.$", r"\1", text, 0, re.M)
  if newtext != text:
    notes.append("remove final period after {{en-third-person singular of}}")
    text = newtext
  newtext = re.sub(r"(\{\{el-form-of-nounadj.*?\}\}.*?)\.$", r"\1", text, 0, re.M)
  if newtext != text:
    notes.append("remove final period after {{el-form-of-nounadj}}")
    text = newtext
  newtext = re.sub(r"(\{\{fi-verb form of.*?\}\}.*?)\.$", r"\1", text, 0, re.M)
  if newtext != text:
    notes.append("remove final period after {{fi-verb form of}}")
    text = newtext
  newtext = re.sub(r"(\{\{ro-form-noun.*?\}\})([^:\n])", r"\1:\2", text, 0, re.M)
  if newtext != text:
    notes.append("add colon after non-final {{ro-form-noun}}")
    text = newtext
  newtext = re.sub(r"(\{\{ro-form-verb.*?\}\})([^:\n])", r"\1:\2", text, 0, re.M)
  if newtext != text:
    notes.append("add colon after non-final {{ro-form-verb}}")
    text = newtext
  # end original process_page_2() code

  return text, notes

parser = blib.create_argparser("Clean up various form-of templates needing text moved outside of template into separate template",
    include_pagefile=True, include_stdin=True)
parser.add_argument('--move-dot', help="Move .= outside of template", action="store_true")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

init_all_templates(args.move_dot)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True,
  default_refs=["Template:%s" % template for template in all_templates])
