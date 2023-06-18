#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, msg, errandmsg, site, tname, pname

def process_text_on_page(index, pagetitle, text):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  notes = []

  pagemsg("Processing")

  retval = blib.find_modifiable_lang_section(text, "Georgian", pagemsg)
  if retval is None:
    pagemsg("WARNING: Couldn't find Georgian section")
    return
  sections, j, secbody, sectail, has_non_lang = retval

  #newtext = re.sub(r"====[ ]?Declension[ ]?====\n\{\{ka-decl-adj-auto\}\}\n", "", secbody)
  #newtext = re.sub(r"====[ ]?Declension[ ]?====\n\{\{ka-adj-decl.*?\}\}\n", "", newtext)
  #if secbody != newtext:
  #  notes.append("remove Georgian adjectival declension for noun")
  #  secbody = newtext

  newtext = re.sub(r"\{\{ka-noun-c\|.*plural.*\}\}", "{{ka-infl-noun|-}}", secbody)
  newtext = re.sub(r"\{\{ka-noun-c\|.*\}\}", "{{ka-infl-noun}}", newtext)
  if secbody != newtext:
    notes.append("convert {{ka-noun-c}} to {{ka-infl-noun}}")
    secbody = newtext
  
  newtext = re.sub("\{\{ka-noun-a\|.*plural.*\}\}", "{{ka-infl-noun|-}}", secbody)
  newtext = re.sub("\{\{ka-noun-a\|.*\}\}", "{{ka-infl-noun}}", newtext)
  if secbody != newtext:
    notes.append("convert {{ka-noun-a}} to {{ka-infl-noun}}")
    secbody = newtext
  
  newtext = re.sub("\{\{ka-noun-o\|.*plural.*\}\}", "{{ka-infl-noun|-}}", secbody)
  newtext = re.sub("\{\{ka-noun-o\|.*\}\}", "{{ka-infl-noun}}", newtext)
  if secbody != newtext:
    notes.append("convert {{ka-noun-o}} to {{ka-infl-noun}}")
    secbody = newtext
  
  newtext = re.sub("\{\{ka-noun-u\|.*plural.*\}\}", "{{ka-infl-noun|-}}", secbody)
  newtext = re.sub("\{\{ka-noun-u\|.*\}\}", "{{ka-infl-noun}}", newtext)
  if secbody != newtext:
    notes.append("convert {{ka-noun-u}} to {{ka-infl-noun}}")
    secbody = newtext
  
  newtext = re.sub("\{\{ka-noun-e\|.*plural.*\}\}", "{{ka-infl-noun|-}}", secbody)
  newtext = re.sub("\{\{ka-noun-e\|.*\}\}", "{{ka-infl-noun}}", newtext)
  if secbody != newtext:
    notes.append("convert {{ka-noun-e}} to {{ka-infl-noun}}")
    secbody = newtext

  newtext = re.sub("\{\{ka\-noun-c-2\|.*?\|.*?\|(.*?)\|.*plural.*\}\}", r"{{ka-infl-noun|\1|-}}", secbody)
  newtext = re.sub("\{\{ka\-noun-c-2\|.*?\|.*?\|(.*?)\|.*\}\}", r"{{ka-infl-noun|\1}}", newtext)
  if secbody != newtext:
    notes.append("convert {{ka-noun-c-2}} to {{ka-infl-noun}}")
    secbody = newtext
  
  #newtext = re.sub(r"==\s*Declension\s*==", "==Inflection==", secbody)
  #if secbody != newtext:
  #  notes.append("==Declension== -> ==Inflection== in Georgian section")
  #  secbody = newtext

  sections[j] = secbody + sectail
  return "".join(sections), notes

parser = blib.create_argparser("Convert {{ka-noun-*}} to {{ka-infl-noun}}",
    include_pagefile=True, include_stdin=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page,
    default_refs=["Template:ka-noun-c-2", "Template:ka-noun-c", "Template:ka-noun-ou",
      "Template:ka-noun-a", "Template:ka-noun-e"], edit=True, stdin=True)
