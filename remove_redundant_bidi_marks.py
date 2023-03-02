#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, errandmsg, site, tname, pname
from bidi.algorithm import get_display

def remove_bidi_marks(text):
  return re.sub(u"[\u200E\u200F]", "", text)

def process_text_chunk(text, pagemsg):
  notes = []

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
    return
  no_marks_display_form = remove_bidi_marks(display_form)
  try:
    display_form_text_no_marks = get_display(text_no_marks)
  except Exception as e:
    if args.verbose:
      msgtext = "\nText: <%s>" % text_no_marks
    else:
      msgtext = ""
    pagemsg("WARNING: Error running bidi algorithm: %s%s" % (e, msgtext))
    return
  if no_marks_display_form == display_form_text_no_marks:
    notes.append("remove redundant Unicode bidi marks")
    pagemsg("Removing redundant bidi marks from text")
    return text_no_marks, notes
  if args.verbose:
    msgtext = ": <%s>" % text
  else:
    msgtext = ""
  pagemsg("WARNING: Can't remove bidi marks%s" % msgtext)
  return

def process_text_on_page(index, pagetitle, text):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  if pagetitle.startswith("Template:") or pagetitle.startswith("Module:"):
    pagemsg("Skipping Template:/Module: page")
    return

  notes = []

  retval = process_text_chunk(text, pagemsg)
  if retval is True: # no BIDI markers to begin with
    return
  if retval is None: # Error running algorithm or can't remove
    lines = text.split("\n")
    changed = False
    for lineind, line in enumerate(lines):
      def linemsg(txt):
        pagemsg("Line %s: %s: line=%s" % (lineind, txt, line))
      retval = process_text_chunk(line, linemsg)
      if retval is True: # no BIDI markers in line to begin with
        continue
      if retval is None: # Error running algorithm or can't remove
        continue
      lines[lineind], this_notes = retval
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
