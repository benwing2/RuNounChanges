#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, msg, errandmsg, site, tname, pname
from bidi.algorithm import get_display

L2R = "\u200E"
R2L = "\u200F"
bidi_c = "[%s%s]" % (L2R, R2L)

def remove_bidi_marks(text):
  return re.sub(bidi_c, "", text)

def process_text_chunk(text, pagemsg, with_fallback=False):
  notes = []

  def do_fallback_removal(text):
    if not with_fallback:
      return text
    # Assume it's safe to remove multiple bidi marks in a row of the same sort.
    text_no_multiple = re.sub(R2L + "+", R2L, re.sub(L2R + "+", L2R, text))
    if text_no_multiple != text:
      text = text_no_multiple
      notes.append("compress repeated Unicode bidi marks")
      pagemsg("Compressing repeated Unicode bidi marks")
    # Assume it's safe to remove L2R marks at the end of a template argument or link.
    text_no_template_l2r = re.sub(r"%s([|}\]])" % L2R, r"\1", text)
    if text_no_template_l2r != text:
      text = text_no_template_l2r
      notes.append("remove Unicode L2R mark at end of template argument or link")
      pagemsg("Removing Unicode L2R mark at end of template argument or link")
    if re.search(bidi_c, text):
      if args.verbose:
        msgtext = ": <%s>" % text
      else:
        msgtext = ""
      pagemsg("WARNING: Bidi marks remain after processing%s" % msgtext)
    return text

  text_no_marks = remove_bidi_marks(text)
  if text == text_no_marks:
    return True
  try:
    display_form = get_display(text)
  except Exception as e:
    if args.verbose:
      msgtext = "\nText: <%s>" % text
    else:
      msgtext = ""
    pagemsg("WARNING: Error running bidi algorithm: %s%s" % (e, msgtext))
    text = do_fallback_removal(text)
    return text, notes
  no_marks_display_form = remove_bidi_marks(display_form)
  try:
    display_form_text_no_marks = get_display(text_no_marks)
  except Exception as e:
    if args.verbose:
      msgtext = "\nText: <%s>" % text_no_marks
    else:
      msgtext = ""
    pagemsg("WARNING: Error running bidi algorithm: %s%s" % (e, msgtext))
    text = do_fallback_removal(text)
    return text, notes
  if no_marks_display_form == display_form_text_no_marks:
    notes.append("remove redundant Unicode bidi marks")
    pagemsg("Removing redundant bidi marks from text")
    return text_no_marks, notes
  text = do_fallback_removal(text)
  return text, notes

def process_text_on_page(index, pagetitle, text):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  if pagetitle.startswith("Template:") or pagetitle.startswith("Module:"):
    if args.verbose:
      pagemsg("Skipping Template:/Module: page")
    return

  notes = []

  retval = process_text_chunk(text, pagemsg)
  if retval is True: # no bidi markers to begin with
    return
  newtext, new_notes = retval
  if not new_notes: # Error running algorithm or can't remove
    lines = text.split("\n")
    changed = False
    for lineind, line in enumerate(lines):
      def linemsg(txt):
        pagemsg("Line %s: %s: line=%s" % (lineind, txt, line))
      retval = process_text_chunk(line, linemsg, with_fallback=True)
      if retval is True: # no bidi markers in line to begin with
        continue
      newline, this_notes = retval
      if not this_notes: # Error running algorithm or can't remove
        continue
      lines[lineind] = newline
      notes.extend(this_notes)
      changed = True
    if changed:
      text = "\n".join(lines)
      return text, notes
    return
  return retval

parser = blib.create_argparser("Remove redundant Unicode bidi marks",
    include_pagefile=True, include_stdin=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True)
