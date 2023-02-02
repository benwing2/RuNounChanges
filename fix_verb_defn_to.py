#!/usr/bin/env python
# -*- coding: utf-8 -*-

# Add 'to' to Russian verb defns when missing.

import blib, re, codecs
import pywikibot

import blib
from blib import getparam, rmparam, msg, site

def process_text_on_page(pageindex, pagetitle, text):
  global args
  def pagemsg(txt):
    msg("Page %s %s: %s" % (pageindex, pagetitle, txt))

  notes = []

  retval = blib.find_modifiable_lang_section(text, None if args.partial_page else args.langname, pagemsg,
    force_final_nls=True)
  if retval is None:
    return
  sections, j, secbody, sectail, has_non_lang = retval

  subsections = re.split("(^==+[^=\n]+==+\n)", secbody, 0, re.M)

  for k in xrange(2, len(subsections), 2):
    if not subsections[k].startswith("{{%s-verb|" % args.langcode):
      continue
    m = re.search("^===*([^=]*)=*==\n$", subsections[k - 1])
    subsectitle = m.group(1)
    if subsectitle in ["Etymology", "Pronunciation"]:
      continue

    def add_to_to_defn(m):
      defn = m.group(1)
      # First split into "sections" where a section is either a sequence
      # {{...}}, ''...'', (...), [[...]], [...], or an individual char.
      # Allow one level of nested {{...}} inside of {{...}}.
      secs = re.split(r"(''.*?''|\{\{(?:\{\{.*?\}\}|.)*?\}\}|\(.*?\)|\[\[.*?\]\]|\[.*?\]|.)", defn)
      # Remove blank sections.
      secs = [sec for sec in secs if sec]
      # Now regroup into "segments" where a segment is either a multi-char
      # section as defined above, or a run of consecutive single-char
      # sections, except that a single-char section consisting of a comma
      # or semicolon or colon is a divider between groups of segments.
      grouped_segments = []
      grouped_segments_sep = []
      segments = []
      segment = []
      for sec in secs:
        if sec in [",", ";", ":"]:
          if segment:
            segments.append("".join(segment))
            segment = []
          if segments:
            grouped_segments.append(segments)
            grouped_segments_sep.append(sec)
            segments = []
        elif (sec.startswith("''") or sec.startswith("{{") or
            (sec.startswith("(") and sec.endswith(")")) or
            sec.startswith("[[") or
            (sec.startswith("[") and sec.endswith("]"))):
          if segment:
            segments.append("".join(segment))
            segment = []
          segments.append(sec)
        else:
          segment.append(sec)
      if segment:
        segments.append("".join(segment))
        segment = []
      if segments:
        grouped_segments.append(segments)
        grouped_segments_sep.append("")
        segments = []

      # Now go through segment groups (where each segment group, as
      # defined above, is a run of segments with a comma separating
      # segment groups), and insert a "to " in the segment group if
      # it's not already present.
      for grouped_segment in grouped_segments:
        i = 0
        # First skip past any segments consisting of blanks, ''...''
        # sequences, {{...}} sequences, (...) sequences and [...]
        # sequences (but not [[...]] sequences).
        while i < len(grouped_segment):
          if re.search("^ *$", grouped_segment[i]):
            i += 1
            continue
          if re.search("^''.*''$", grouped_segment[i]):
            i += 1
            continue
          if re.search(r"^\{\{.*\}\}$", grouped_segment[i]):
            i += 1
            continue
          if re.search(r"^\(.*\)$", grouped_segment[i]):
            i += 1
            continue
          if re.search(r"^\[[^\[].*\]$", grouped_segment[i]):
            i += 1
            continue
          break
        # If the first word of the next segment is "to" or "etc" or "e.g."
        # or ends in "-ing" preceded by a vowel (excluding "fling", "sing",
        # "take wing", etc.), don't insert "to ", otherwise do.
        if i < len(grouped_segment) and (
            not re.search(r"^ *(to|etc|e\.\g.|when|then|especially|usually|or|and)\b", grouped_segment[i]) and
            not re.search(r"^\[\[[^ ]*?[a-z]*[aeiouy][a-z]*ing\]\]$", grouped_segment[i]) and
            not re.search(r"^ *[a-z]*[aeiouy][a-z]*ing\b", grouped_segment[i])):
          grouped_segment[i] = re.sub("^( *)", r"\1to ", grouped_segment[i])

      # Rejoin segments and segment groups.
      newdefn = "".join(
        "".join(grouped_segment) + sep for grouped_segment, sep in
        zip(grouped_segments, grouped_segments_sep))

      if newdefn != defn:
        pagemsg("Replace defn <%s> with <%s>" % (defn, newdefn))
        notes.append("add missing 'to' in %s verb defn" % args.langname)
        defn = newdefn

      return "# " + defn + "\n"

    subsections[k] = re.sub("^# (.*)\n", add_to_to_defn, subsections[k], 0, re.M)

  secbody = "".join(subsections)
  # Strip extra newlines added to secbody
  sections[j] = secbody.rstrip("\n") + sectail
  return "".join(sections), notes

parser = blib.create_argparser("Add 'to' to verb defns when missing", include_pagefile=True, include_stdin=True)
parser.add_argument("--partial-page", action="store_true", help="Input was generated with 'find_regex.py --lang LANG' and has no ==LANG== header.")
parser.add_argument("--langcode", required=True, help="Language code of language to do")
parser.add_argument("--langname", required=True, help="Language name of language to do")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True, default_cats=["%s verbs" % args.langname])
