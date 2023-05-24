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
      if re.search("^#+[^*:#]", line):
        # First, replace templated English links in definitions with raw ones.
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
            notes.append("replace templated link to English term(s) in defns with raw link(s)" + (
              ", keeping self-links templated" if saw_self_link else ""))
          return m1
        # Replace only one-part templated links (no vertical bars outside of raw links) but allow two-part raw links
        # inside of a one-part templated link.
        line = re.sub(r"\{\{l\|en\|((?:[^{}|\[\]]|\[\[[^{}\[\]]*\]\])*?)\}\}", replace_templated, line)

        # Now replace two-part templated English links with raw ones.
        def replace_two_part_templated(m):
          linktext, displaytext = m.groups()
          if linktext == pagetitle:
            # Don't change if link is to same page.
            return m.group(0)
          if displaytext.startswith(linktext):
            # Can use a shortcut in this case, e.g. {{l|en|olive tree|olive trees}} -> [[olive tree]]s.
            notes.append("replace two-part templated link to English term in defns with one-part raw link with extension text")
            return "[[%s]]%s" % (linktext, displaytext[len(linktext):])
          else:
            notes.append("replace two-part templated link to English term in defns with two-part raw link")
            return "[[%s|%s]]" % (linktext, displaytext)
        line = re.sub(r"\{\{l\|en\|([^{}|\[\]=]*)\|([^{}|\[\]=]*)\}\}", replace_two_part_templated, line)

        # Now, replace raw English self-links with templated ones.
        template_split_re = r"(\{\{(?:[^{}]|\{\{[^{}]*\}\})*\}\})"
        # Split templates and only change non-template text
        split_templates = re.split(template_split_re, line)
        for l in xrange(0, len(split_templates), 2):
          def replace_raw_self_link(m):
            notes.append("replace raw self link to English term with templated one")
            return get_templated_self_link(pagetitle)
          split_templates[l] = re.sub(r"\[\[(?:#English\|)?%s\]\]" % re.escape(pagetitle), replace_raw_self_link, split_templates[l])
          def replace_raw_two_part_link(m):
            link = m.group(1)
            if link == pagetitle:
              notes.append("replace two-part raw self link to English term with templated one")
              return get_templated_self_link(pagetitle)
            notes.append("replace two-part link to English term with raw link")
            return "[[%s]]" % link
          split_templates[l] = re.sub(r"\[\[([^|\[\]]+)(?:#English)?\|\1\]\]", replace_raw_two_part_link, split_templates[l])
        line = "".join(split_templates)

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
parser.add_argument("--self-links-use-raw", action="store_true",
    help="Self-links use [[#English|LINK]] rather than {{l|en|LINK}}")
parser.add_argument("--partial-page", action="store_true",
    help="Input was generated with 'find_regex.py --lang LANG' and has no ==LANG== header.")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True)
