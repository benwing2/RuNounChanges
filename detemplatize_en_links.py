#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, tname, pname, msg, site

def process_text_on_page(index, pagetitle, text):
  global args
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
  origtext = text
  notes = []

  def get_templated_self_link(link):
    if args.self_links_use_raw:
      return "[[#English|%s]]" % link
    else:
      return "{{l|en|%s}}" % link

  def fix_sec_links(sectext):
    lines = sectext.split("\n")
    new_lines = []
    for line in lines:
      if line.startswith("#"):
        if args.convert_raw_self_links:
          template_split_re = r"(\{\{(?:[^{}]|\{\{[^{}]*\}\})*\}\})"
          # Split templates and only change non-template text
          split_templates = re.split(template_split_re, line)
          for l in xrange(0, len(split_templates), 2):
            while True:
              newtext = re.sub(r"^#(.*?)\[\[%s\]\]" % pagetitle, r"#\1" + get_templated_self_link(pagetitle),
                  split_templates[l], 0, re.M)
              if newtext == split_templates[l]:
                break
              changed = True
              notes.append("replace raw self link to English terms with templated one")
              split_templates[l] = newtext
          line = "".join(split_templates)
        else:
          def replace_templated(m):
            origm1 = m.group(1)
            m1 = origm1
            if "[[" not in m1:
              m1 = "[[%s]]" % m1
            m1_new = m1.replace("[[%s]]" % pagetitle, get_templated_self_link(pagetitle))
            saw_self_link = False
            if m1_new != m1:
              saw_self_link = True
              m1 = m1_new
            if m1 != get_templated_self_link(origm1):
              notes.append("replace templated link to English terms in defns with raw link(s)" + (
                ", keeping self-links templated" if saw_self_link else ""))
            return m1
          line = re.sub(r"\{\{l\|en\|((?:[^{}|]|\[\[[^{}\[\]]*\]\])*?)\}\}", replace_templated, line)
      new_lines.append(line)
    return "\n".join(new_lines)

  if args.lang:
    retval = blib.find_modifiable_lang_section(text, None if args.partial_page else args.lang, pagemsg)
    if retval is None:
      pagemsg("WARNING: Couldn't find %s section" % args.lang)
      return
    sections, j, secbody, sectail, has_non_lang = retval

    secbody = fix_sec_links(secbody)
    sections[j] = secbody + sectail
    text = "".join(sections)
  else:
    text = fix_sec_links(text)

  return text, notes

parser = blib.create_argparser("Fix raw self links to English terms on the same page",
  include_pagefile=True, include_stdin=True)
parser.add_argument("--lang", help="Language to do (optional)")
parser.add_argument("--convert-raw-self-links", action="store_true",
    help="Convert raw self-links to [[#English|LINK]] or {{l|en|LINK}} rather than detemplatize templated links")
parser.add_argument("--self-links-use-raw", action="store_true",
    help="Self-links use [[#English|LINK]] rather than {{l|en|LINK}}")
parser.add_argument("--partial-page", action="store_true",
    help="Input was generated with 'find_regex.py --lang LANG' and has no ==LANG== header.")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True)
