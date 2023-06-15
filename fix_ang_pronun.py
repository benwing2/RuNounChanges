#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site, tname

def get_head_param(t, pagetitle):
  tn = tname(t)
  if tn in [
    "ang-adj", "ang-adj-comp", "ang-adj-sup",
    "ang-adv", "ang-adv-comp", "ang-adv-sup",
    "ang-verb"
  ]:
    retval = blib.fetch_param_chain(t, "1", "head")
  elif tn in [
    "ang-noun", "ang-noun-form", "ang-verb-form", "ang-adj-form",
    "ang-con", "ang-prep", "ang-prefix", "ang-proper noun", "ang-suffix"
  ]:
    retval = blib.fetch_param_chain(t, "head", "head")
  elif tn == "head" and getparam(t, "1") == "ang":
    retval = blib.fetch_param_chain(t, "head", "head")
  else:
    return None
  return retval or [pagetitle]

def process_section(index, pagetitle, sectext):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  parsed = blib.parse_text(sectext)
  head = None
  for t in parsed.filter_templates():
    newhead = get_head_param(t, pagetitle)
    if newhead is not None:
      newhead = [blib.remove_links(x) for x in newhead]
      if head and head != newhead:
        pagemsg("WARNING: Saw multiple heads %s and %s" % (",".join(head), ",".join(newhead)))
      head = newhead
  if not head:
    pagemsg("WARNING: Couldn't find head")
  saw_pronun = False
  for t in parsed.filter_templates():
    tn = tname(t)
    if tn == "IPA":
      if getparam(t, "1") != "ang":
        pagemsg("WARNING: Wrong-language IPA template: %s" % unicode(t))
        continue
      pagemsg("<from> %s <to> {{ang-IPA|%s}} <end>" % (
        unicode(t), "|".join(head) or "<<%s>>" % pagetitle))
      saw_pronun = True
    elif tn == "ang-IPA":
      pagemsg("Saw existing pronunciation: %s" % unicode(t))
      saw_pronun = True
  if not saw_pronun:
    pagemsg("WARNING: Didn't see pronunciation for headword %s <new> {{ang-IPA|%s}} <end>" % (
      ",".join(head), "|".join(head)))

def process_text_on_page(index, pagetitle, text):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  #retval = blib.find_modifiable_lang_section(text, "Old English", pagemsg)
  #if retval is None:
  #  pagemsg("WARNING: Couldn't find Old English section")
  #  return
  #sections, j, secbody, sectail, has_non_lang = retval
  secbody = text
  if "Etymology 1" in secbody:
    etym_sections = re.split("(^===Etymology [0-9]+===\n)", secbody, 0, re.M)
    if "=Pronunciation=" in etym_sections[0]:
      process_section(index, pagetitle, secbody)
    else:
      for k in range(2, len(etym_sections), 2):
        process_section(index, pagetitle, etym_sections[k])
  else:
    process_section(index, pagetitle, secbody)

def process_section_for_modification(index, pagetitle, sectext, indent_level, new_pronuns):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  parsed = blib.parse_text(sectext)
  heads = []
  for t in parsed.filter_templates():
    newheads = get_head_param(t, pagetitle)
    if newheads:
      newheads = [blib.remove_links(x) for x in newheads]
      for head in newheads:
        if head not in heads:
          heads.append(head)
  if not heads:
    pagemsg("WARNING: Couldn't find head")
    return sectext
  saw_pronun = False
  for t in parsed.filter_templates():
    tn = tname(t)
    if tn == "IPA":
      if getparam(t, "1") != "ang":
        pagemsg("WARNING: Wrong-language IPA template: %s" % unicode(t))
        continue
      saw_pronun = True
    elif tn == "ang-IPA":
      pagemsg("Saw existing pronunciation: %s" % unicode(t))
      saw_pronun = True
  if saw_pronun:
    return sectext
  subsecs = re.split("(^%s[^=]*?%s\n)" % ("=" * indent_level, "=" * indent_level), sectext, 0, re.M)
  for k in range(1, len(subsecs), 2):
    if "=Pronunciation=" in subsecs[k]:
      pagemsg("WARNING: Already saw pronunciation section without pronunciation in it")
      return sectext
  k = 1
  while k < len(subsecs) and re.search("=(Alternative forms|Etymology)=", subsecs[k]):
    k += 2
  if k >= len(subsecs):
    pagemsg("WARNING: No place to insert pronunciation")
    return sectext
  new_pronun_map = dict(new_pronuns)
  if len(heads) > 1:
    pronuns = []
    for head in heads:
      if head not in new_pronun_map:
        pagemsg("WARNING: No pronun found for head %s" % head)
        return sectext
      pronuns.append("* " + new_pronun_map[head].replace("}}", "|ann=1}}"))
    newsec = "%sPronunciation%s\n%s\n\n" % ("=" * indent_level, "=" * indent_level, "\n".join(pronuns))
  else:
    if heads[0] not in new_pronun_map:
      pagemsg("WARNING: No pronun found for head %s" % heads[0])
      return sectext
    newsec = "%sPronunciation%s\n* %s\n\n" % ("=" * indent_level, "=" * indent_level, new_pronun_map[heads[0]])
  subsecs[k:k] = [newsec]
  return "".join(subsecs)

def process_page_for_modification(index, pagetitle, text, new_pronuns):
  if pagetitle not in new_pronuns:
    return
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  retval = blib.find_modifiable_lang_section(text, "Old English", pagemsg)
  if retval is None:
    pagemsg("WARNING: Couldn't find Old English section")
    return
  sections, j, secbody, sectail, has_non_lang = retval
  heads = None
  if "Etymology 1" in secbody:
    etym_sections = re.split("(^===Etymology [0-9]+===\n)", secbody, 0, re.M)
    for k in range(2, len(etym_sections), 2):
      parsed = blib.parse_text(etym_sections[k])
      secheads = []
      for t in parsed.filter_templates():
        this_heads = get_head_param(t, pagetitle)
        if this_heads:
          this_heads = [blib.remove_links(x) for x in this_heads]
          for head in this_heads:
            if head not in secheads:
              secheads.append(head)
      if heads is None:
        heads = secheads
      elif set(heads) != set(secheads):
        pagemsg("Saw head(s) %s in one etym section and %s in another, splitting pronuns per etym section" % (
          ",".join(heads), ",".join(secheads)))
        for k in range(2, len(etym_sections), 2):
          etym_sections[k] = process_section_for_modification(index, pagetitle, etym_sections[k], 4,
              new_pronuns[pagetitle])
        sections[j] = "".join(etym_sections) + sectail
        return "".join(sections), "add pronunciation(s) to Old English lemma(s)"
    pagemsg("All etym sections have same head(s) %s, creating a single pronun section" % ",".join(heads))
  secbody = process_section_for_modification(index, pagetitle, secbody, 3, new_pronuns[pagetitle])
  sections[j] = secbody + sectail
  return "".join(sections), "add pronunciation(s) to Old English lemma(s)"

parser = blib.create_argparser("Find Old English heads and pronuns or fix them",
    include_pagefile=True, include_stdin=True)
parser.add_argument('--new-pronuns', help="File containing new pronuns.")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

if not args.new_pronuns:
  blib.do_pagefile_cats_refs(args, start, end, process_text_on_page,
      default_cats=["Old English lemmas"], stdin=True)
else:
  new_pronuns = {}
  bad_pagename = None
  for lineno, line in blib.iter_items_from_file(args.new_pronuns):
    m = re.search("^Page [0-9]+ (.*?): WARNING: Didn't see pronunciation for headword (.*?) <new> (.*?) <end>$", line)
    if not m:
      msg("Line %s: WARNING: Unparsable line: %s" % (lineno, line))
      continue
    pagename, headword, new_pronun = m.groups()
    if pagename == bad_pagename:
      continue
    if pagename not in new_pronuns:
      new_pronuns[pagename] = [(headword, new_pronun)]
    else:
      broken = False
      for this_headword, this_new_pronun in new_pronuns[pagename]:
        if this_headword == headword and this_new_pronun != new_pronun:
          msg("Line %s: WARNING: Saw multiple pronuns for headword %s: %s and %s" % (
            lineno, headword, this_new_pronun, new_pronun))
          broken = True
          break
      if broken:
        del new_pronuns[pagename]
        bad_pagename = pagename
      else:
        new_pronuns[pagename].append((headword, new_pronun))

  def do_process_page_for_modification(index, pagetitle, text):
    return process_page_for_modification(index, pagetitle, text, new_pronuns)

  blib.do_pagefile_cats_refs(args, start, end, do_process_page_for_modification,
      default_cats=["Old English lemmas"], stdin=True, edit=True)
