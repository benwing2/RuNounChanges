#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, errandmsg, site, tname, pname
from bidi.algorithm import get_display

def remove_bidi_marks(text):
  return re.sub(u"[\u200E\u200F]", "", text)

def process_text_on_page(index, pagetitle, text):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  notes = []

  pagemsg("Processing")

  text_no_marks = remove_bidi_marks(text)
  if text == text_no_marks:
    return
  try:
    display_form = get_display(text)
  except Exception as e:
    pagemsg("WARNING: Error running bidi algorithm: %s\nText: <%s>" % (e, text))
    return
  no_marks_display_form = remove_bidi_marks(display_form)
  try:
    display_form_text_no_marks = get_display(text_no_marks)
  except Exception as e:
    pagemsg("WARNING: Error running bidi algorithm: %s\nText: <%s>" % (e, text_no_marks))
    return
  if no_marks_display_form == display_form_text_no_marks:
    notes.append("remove redundant Unicode bidi marks")
    pagemsg("Removing redundant bidi marks from text")
    return text_no_marks, notes
  pagemsg("WARNING: Can't remove bidi marks: <%s>" % text)
  return

parser = blib.create_argparser("Remove redundant Unicode bidi marks",
    include_pagefile=True, include_stdin=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True)
