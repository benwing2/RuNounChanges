#!/usr/bin/env python3
# -*- coding: utf-8 -*-

##* {{RQ:Addison Freeholder|50|June 11 1715}}
##*:The enemies of our happy establishment seem at present to copy out the piety of this seditious prophet , and to have recourse to his laudable method of '''club-law''', when they find all other means of enforcing the absurdity of their opinions to be ineffectual.
#
#→
#
##* {{RQ:Addison Freeholder|issue=50|date=11 June 1716|passage=The enemies of our happy establishment seem at present to copy out the piety of this seditious prophet , and to have recourse to his laudable method of '''club-law''', when they find all other means of enforcing the absurdity of their opinions to be ineffectual.}}

##* {{RQ:Thackeray VF|37}}
##*: His jaw was '''underhung''', and when he laughed, two white buckteeth protruded themselves and glistened savagely in the midst of the grin.
#
#→
#
##* {{RQ:Thackeray Vanity Fair|chapter=37|passage=His jaw was '''underhung''', and when he laughed, two white buckteeth protruded themselves and glistened savagely in the midst of the grin.}}

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, set_template_name, msg, errmsg, site

def process_text_on_page(index, pagename, text):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagename, txt))
  def errandpagemsg(txt):
    errandmsg("Page %s %s: %s" % (index, pagename, txt))

  pagemsg("Processing")

  notes = []

  curtext = text + "\n"

  def replace_addison_freeholder(m):
    issue, date, text = m.groups()
    text = re.sub(r"\s*<br */?>\s*", " / ", text)
    notes.append("reformat {{RQ:Addison Freeholder}}")
    return "{{RQ:Addison Freeholder|issue=%s|date=%s|passage=%s}}\n" % (issue, date, text)

  curtext = re.sub(r"\{\{RQ:Addison Freeholder\|([^|{}]*?)\|([^|{}]*?)\}\}\n#+\*: *(.*?)\n",
      replace_addison_freeholder, curtext)

  def replace_thackeray_vf(m):
    chapter, text = m.groups()
    text = re.sub(r"\s*<br */?>\s*", " / ", text)
    notes.append("reformat {{RQ:Thackeray VF}} into {{RQ:Thackeray Vanity Fair}}")
    return "{{RQ:Thackeray Vanity Fair|chapter=%s|passage=%s}}\n" % (chapter, text)

  curtext = re.sub(r"\{\{RQ:Thackeray VF\|([^|{}]*?)\}\}\n#+\*: *(.*?)\n",
      replace_thackeray_vf, curtext)

  return curtext.rstrip("\n"), notes

parser = blib.create_argparser("Reformat {{RQ:Addison Freeholder}} and {{RQ:Thackeray VF}}", include_pagefile=True,
    include_stdin=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page,
    default_refs=["Template:RQ:Addison Freeholder", "Template:RQ:Thackeray VF"], edit=True, stdin=True)
