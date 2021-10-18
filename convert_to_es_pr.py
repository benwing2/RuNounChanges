#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, errandmsg, site, tname, pname

def process_text_on_page(index, pagetitle, text):
  global args
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
  def verify_template_is_full_line(tn, line):
    templates = list(blib.parse_text(line).filter_templates())
    if len(templates) == 0:
      pagemsg("WARNING: No templates on {{%s}} line?, skipping: %s" % (tn, line))
      return None
    t = templates[0]
    if tname(t) != tn:
      pagemsg("WARNING: Putative {{%s}} line doesn't have {{%s...}} as the first template, skipping: %s" %
          (tn, tn, line))
      return None
    if unicode(t) != line:
      pagemsg("WARNING: {{%s}} line has text other than {{%s...}}, skipping: %s" % (tn, tn, line))
      return None
    return t

  notes = []

  retval = blib.find_modifiable_lang_section(text, None if args.partial_page else "Spanish", pagemsg,
    force_final_nls=True)
  if retval is None:
    return
  sections, j, secbody, sectail, has_non_lang = retval

  subsections = re.split("(^==+[^=\n]+==+\n)", secbody, 0, re.M)

  for k in xrange(1, len(subsections), 2):
    if re.search(r"==\s*Pronunciation\s*==", subsections[k]):
      extra_notes = []
      parsed = blib.parse_text(subsections[k + 1])
      num_es_IPA = 0
      saw_es_pr = False
      for t in parsed.filter_templates():
        tn = tname(t)
        if tn in ["es-pr", "es-pronunciation"]:
          saw_es_pr = True
          break
        if tn == "es-IPA":
          num_es_IPA += 1
      if saw_es_pr:
        pagemsg("Already saw {{es-pr}}, skipping: %s" % unicode(t))
        continue
      if num_es_IPA == 0:
        pagemsg("WARNING: Didn't see {{es-IPA}} in Pronunciation section, skipping")
        continue
      if num_es_IPA > 1:
        pagemsg("WARNING: Saw multiple {{es-IPA}} in Pronunciation section, skipping")
        continue
      lines = subsections[k + 1].strip().split("\n")
      # Remove blank lines.
      lines = [line for line in lines if line]
      hyph_lines = []
      homophone_lines = []
      rhyme_lines = []
      must_continue = False
      audioarg = ""
      arg = ""
      for line in lines:
        origline = line
        # In case of "* {{es-IPA|...}}", chop off the "* ".
        line = re.sub(r"^\*\s*(\{\{es-IPA)", r"\1", line)
        if line.startswith("{{es-IPA"):
          if arg:
            pagemsg("WARNING: Something wrong, already saw {{es-IPA}}?: %s" % origline)
            must_continue = True
            break
          ipat = verify_template_is_full_line("es-IPA", line)
          if ipat is None:
            must_continue = True
            break
          arg = getparam(ipat, "1") or "+"
          for param in ipat.params:
            pn = pname(param)
            pv = unicode(param.value)
            if pn == "1":
              continue
            if pn in ["pre", "post", "bullets", "ref", "style"]:
              arg += "<%s:%s>" % (pn, pv)
            else:
              pagemsg("WARNING: Unrecognized param %s=%s in {{es-IPA}}, skipping: %s" % (
                pn, pv, origline))
              must_continue = True
              break
          if must_continue:
            break
          continue
        if not line.startswith("* ") and not line.startswith("*{"):
          pagemsg("WARNING: Pronunciation section line doesn't start with '* ', skipping: %s"
              % origline)
          must_continue = True
          break
        if line.startswith("* "):
          line = line[2:]
        else:
          line = line[1:]
        if line.startswith("{{hyph"):
          hyph_lines.append("* " + line)
        elif line.startswith("{{homophone"):
          homophone_lines.append("* " + line)
        elif line.startswith("{{audio"):
          audiot = verify_template_is_full_line("audio", line)
          if audiot is None:
            must_continue = True
            break
          if getparam(audiot, "1") != "es":
            pagemsg("WARNING: Wrong language in {{audio}}, skipping: %s" % origline)
            must_continue = True
            break
          audiofile = getparam(audiot, "2")
          audiogloss = getparam(audiot, "3")
          for param in audiot.params:
            pn = pname(param)
            pv = unicode(param.value)
            if pn not in ["1", "2", "3"]:
              pagemsg("WARNING: Unrecognized param %s=%s in {{audio}}, skipping: %s" % (
                pn, pv, origline))
              must_continue = True
              break
          if must_continue:
            break
          if audiogloss in ["Audio", "audio"]:
            audiogloss = ""
          if audiogloss:
            audiogloss = ";%s" % audiogloss
          audioarg += "<audio:%s%s>" % (audiofile, audiogloss)
          pagemsg("Replacing %s with argument %s" % (unicode(audiot), arg))
          extra_notes.append("incorporate %s into {{es-pr}}" % unicode(audiot))
        elif line.startswith("{{rhyme"):
          rhyme_lines.append(line)
        else:
          pagemsg("WARNING: Unrecognized Pronunciation section line, skipping: %s" % origline)
          must_continue = True
          break
      if must_continue:
        continue
      if rhyme_lines:
        # FIXME, verify specified rhymes are subset of actual rhymes
        pass
      if not arg:
        pagemsg("WARNING: Something wrong, didn't see {{es-IPA}}?")
        continue
      arg += audioarg
      if arg == "+":
        es_pr = "{{es-pr}}"
      else:
        es_pr = "{{es-pr|%s}}" % arg
      pagemsg("Replaced %s with %s" % (unicode(ipat), es_pr))
      all_lines = "\n".join([es_pr] + hyph_lines + homophone_lines)
      newsubsec = "%s\n\n" % all_lines
      if subsections[k + 1] != newsubsec:
        this_notes = ["convert {{es-IPA}} to {{es-pr}}"] + extra_notes
        notes.extend(this_notes)
      subsections[k + 1] = newsubsec

  secbody = "".join(subsections)
  # Strip extra newlines added to secbody
  sections[j] = secbody.rstrip("\n") + sectail
  return "".join(sections), notes

parser = blib.create_argparser("Convert {{es-IPA}} to {{es-pr}}", include_pagefile=True, include_stdin=True)
parser.add_argument("--partial-page", action="store_true", help="Input was generated with 'find_regex.py --lang LANG' and has no ==LANG== header.")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True)
