#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, errandmsg, site, tname

all_he_form_of_templates = [
  "he-Cohortative of",
  "he-Defective spelling of",
  "he-Excessive spelling of",
  "he-Form of adj",
  "he-Form of noun",
  "he-Form of prep",
  "he-Form of sing cons",
  "he-Future of",
  "he-Imperative of",
  "he-Infinitive of",
  "he-Jussive of",
  "he-Past of",
  "he-Present of",
  "he-Vav-imperfect of",
  "he-Vav imperfect of",
  "he-Vav-perfect of",
  "he-Vav perfect of",
  "he-cohortative of",
  "he-defective spelling of",
  "he-excessive spelling of",
  "he-form of adj",
  "he-form of noun",
  "he-form of sing cons",
  "he-form of prep",
  "he-future of",
  "he-imperative of",
  "he-infinitive of",
  "he-jussive of",
  "he-past of",
  "he-present of",
  "he-vav-imperfect of",
  "he-vav imperfect of",
  "he-vav-perfect of",
  "he-vav perfect of",
]

def process_page(page, index, parsed, move_dot):
  pagetitle = unicode(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")
  notes = []

  text = unicode(page.text)

  if move_dot:
    templates_to_replace = []

    for t in parsed.filter_templates():
      tn = tname(t)
      if tn in all_he_form_of_templates:
        dot = getparam(t, ".")
        if dot:
          origt = unicode(t)
          rmparam(t, ".")
          newt = unicode(t) + dot
          templates_to_replace.append((origt, newt))

    for curr_template, repl_template in templates_to_replace:
      found_curr_template = curr_template in text
      if not found_curr_template:
        pagemsg("WARNING: Unable to locate template: %s" % curr_template)
        continue
      found_repl_template = repl_template in text
      if found_repl_template:
        pagemsg("WARNING: Already found template with period: %s" % repl_template)
        continue
      newtext = text.replace(curr_template, repl_template)
      newtext_text_diff = len(newtext) - len(text)
      repl_curr_diff = len(repl_template) - len(curr_template)
      ratio = float(newtext_text_diff) / repl_curr_diff
      if ratio == int(ratio):
        if int(ratio) > 1:
          pagemsg("WARNING: Replaced %s occurrences of curr=%s with repl=%s"
              % (int(ratio), curr_template, repl_template))
      else:
        pagemsg("WARNING: Something wrong, length mismatch during replacement: Expected length change=%s, actual=%s, ratio=%.2f, curr=%s, repl=%s"
            % (repl_curr_diff, newtext_text_diff, ratio, curr_template,
              repl_template))
      text = newtext
      notes.append("move .= outside of {{he-*}} template")

  return text, notes

parser = blib.create_argparser("Clean up {{he-*}} templates")
parser.add_argument('--move-dot', help="Move .= outside of template",
    action="store_true")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

for template in all_he_form_of_templates:
  for i, page in blib.references("Template:%s" % template, start, end):
    blib.do_edit(page, i,
      lambda page, index, parsed:
        process_page(page, index, parsed, args.move_dot),
      save=args.save, verbose=args.verbose
    )
