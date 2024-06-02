#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import re

import blib, pywikibot
from blib import msg, getparam, addparam
from collections import defaultdict

site = pywikibot.Site()

max_truncate_len = 80

# Truncate a string so its length is <= max_truncate_len including a ... added at the end.
def truncate(text, truncate_len=max_truncate_len):
  text = text.replace("\n", r"\n") # escape newlines
  if len(text) <= truncate_len:
    return text
  return text[0:truncate_len - 3] + "..."

# Truncate a string so its UTF-8 length is <= max_truncate_len including a ... added at the end.
def truncate_bytes(text, truncate_len=max_truncate_len):
  text = text.replace("\n", r"\n") # escape newlines
  textbytes = text.encode("utf-8")
  if len(textbytes) <= truncate_len:
    return text
  return textbytes[0:truncate_len - 3].decode("utf-8", "ignore") + "..."

def read_direcfile(direcfile, start, end):
  comment = None
  template_changes = []
  for lineno, line in blib.iter_items_from_file(direcfile, start, end):
    def linemsg(txt):
      msg("Line %s: %s" % (lineno, txt))
    repl_on_right = False
    m = re.match(r"^Page [^ ]+ (.*?): .*?: (\{\{.*?\}\}) <- \{\{.*?\}\} \((\{\{.*?\}\})\)$",
        line)
    if not m:
      m = re.match(r"^\* (?:Page [^ ]+ )?\[\[(.*?)\]\]: .*?: <nowiki>(\{\{.*?\}\}) <- \{\{.*?\}\} \((\{\{.*?\}\})\)</nowiki>.*$",
          line)
    if not m:
      m = re.match(r"^(?:Page [^ ]+ )(.*?): .* /// (.*?) /// (.*?)$", line)
      repl_on_right = True
    if m:
      if m.group(2) != m.group(3):
        # If the current template is the same as the current template of the
        # previous entry, ignore the previous entry; otherwise we won't be
        # able to locate the current template the second time around. This
        # happens e.g. in the output of find_russian_need_vowels.py when
        # processing a template such as cardinalbox or compound that has
        # more than one foreign-language parameter in it.
        if len(template_changes) > 0 and template_changes[-1][2] == m.group(3):
          linemsg("Ignoring change for pagename %s, %s -> %s" % template_changes[-1])
          template_changes.pop()
        if repl_on_right:
          pagename, curr, repl = m.groups()
          template_changes.append((pagename, [(repl, curr)], None))
        else:
          pagename, repl, curr = m.groups()
          template_changes.append((pagename, [(repl, curr)], None))
      else:
        linemsg("WARNING: Ignoring line with from=to: %s" % line)
    else:
      mpage = re.search(r"^(?:Page [^ ]+ )(.*?): (.*)$", line)
      if not mpage:
        linemsg("WARNING: Unable to parse line: [%s]" % line)
        continue
      pagename, directives = mpage.groups()
      m = re.search("<comment> (.*?) <endcom>", directives)
      if m:
        comment = m.group(1)
      this_template_changes = []
      for m in re.finditer("<from> (.*?) <to> (.*?) <end>", directives):
        curr, repl = m.groups()
        if curr != repl:
          this_template_changes.append((repl, curr))
        else:
          linemsg("WARNING: Ignoring line with from=to: %s" % line)
      if this_template_changes:
        template_changes.append((pagename, this_template_changes, comment))
  return template_changes

def template_changes_to_dict(template_changes):
  retval = defaultdict(list)
  for pagename, repl_curr_changes, comment in template_changes:
    retval[pagename].append((repl_curr_changes, comment))
  return retval

def read_split_direcfile(direcfile, start, end):
  comment = None
  template_changes = []
  for lineno, line in blib.iter_items_from_file(direcfile, start, end):
    def linemsg(txt):
      msg("Line %s: %s" % (lineno, txt))
    m = re.match(r"^Page [^ ]+ (.*?): .*?<begin> (.*?) <end>.*$", line)
    if not m:
      linemsg("WARNING: Unable to parse line: [%s]" % line)
      continue
    pagename, from_to = m.groups()
    template_changes.append((pagename, from_to))
  return template_changes

def split_template_changes_to_dict(template_changes):
  retval = defaultdict(list)
  for pagename, from_to in template_changes:
    retval[pagename].append(from_to)
  return retval

def push_one_set_of_manual_changes(pagetitle, index, text, repl_curr_changes, comment):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
  #template = blib.parse_text(template_text).filter_templates()[0]
  #orig_template = str(template)
  #if getparam(template, "sc") == "polytonic":
  #  template.remove("sc")
  #to_template = str(template)
  #param_value = getparam(template, removed_param)
  #template.remove(removed_param)
  #from_template = str(template)
  text = str(text)
  changelogs = []
  for repl_template, curr_template in repl_curr_changes:
    repl_template = undo_slash_newline(repl_template)
    curr_template = undo_slash_newline(curr_template)
    found_repl_template = repl_template in text
    newtext = text.replace(curr_template, repl_template)
    if newtext == text:
      if not found_repl_template:
        pagemsg("WARNING: Unable to locate current template: %s (would replace with %s)" % (curr_template, repl_template))
      else:
        pagemsg("Replacement template already found, taking no action")
    else:
      if found_repl_template:
        pagemsg("WARNING: Made change, but replacement template %s already present!" % repl_template)
      repl_curr_diff = len(repl_template) - len(curr_template)
      newtext_text_diff = len(newtext) - len(text)
      if newtext_text_diff == repl_curr_diff:
        pass
      elif repl_curr_diff == 0:
        if newtext_text_diff != 0:
          pagemsg("WARNING: Something wrong, no change in text length during replacement but expected change: Expected length change=%s, actual=%s, curr=%s, repl=%s"
              % (repl_curr_diff, newtext_text_diff, curr, repl))
      else:
        ratio = float(newtext_text_diff) / repl_curr_diff
        if ratio == int(ratio):
          pagemsg("WARNING: Replaced %s occurrences of curr=%s with repl=%s"
              % (int(ratio), curr_template, repl_template))
        else:
          pagemsg("WARNING: Something wrong, length mismatch during replacement: Expected length change=%s, actual=%s, ratio=%.2f, curr=%s, repl=%s"
              % (repl_curr_diff, newtext_text_diff, ratio, curr_template,
                repl_template))
      changelog = "replace <%s> with <%s>" % (truncate(curr_template), truncate(repl_template))
      pagemsg("Change log = %s" % changelog)
      if args.include_what_changed:
        changelogs.append(changelog)
    text = newtext

  if comment:
    changelogs = [comment]
  return text, changelogs

def undo_slash_newline(txt):
  if not args.undo_slash_newline:
    return txt
  return blib.undo_escape_newline(txt)

def combine_notes_with_comment(notes):
  if notes:
    if args.comment:
      # Wiktionary comments can be at most 500 bytes when encoded in UTF-8. If longer, they get truncated, which we
      # don't want, because we want the comment at the end to display in full, so we need to do the truncation
      # ourselves before adding the comment.
      grouped_notes = "; ".join(blib.group_notes(notes))
      comment_suffix = " (%s)" % args.comment
      comment_suffix_len = len(comment_suffix.encode("utf-8"))
      grouped_notes = truncate_bytes(grouped_notes, 500 - comment_suffix_len)
      return grouped_notes + comment_suffix
    else:
      return notes
  else:
    return args.comment or "push manual changes"

def process_text_on_page_pushing_manual_changes(index, pagetitle, text):
  global args
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  if pagetitle not in direcfile_changes_dict:
    return
  notes = []
  for repl_curr_changes, comment in direcfile_changes_dict[pagetitle]:
    text, this_changelogs = push_one_set_of_manual_changes(pagetitle, index, text, repl_curr_changes, comment)
    notes.extend(this_changelogs)

  return text, combine_notes_with_comment(notes)

def process_text_on_page_pushing_split_manual_changes(index, pagetitle, text):
  global args
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  if pagetitle not in direcfile_changes_dict:
    return
  if pagetitle not in origfile_changes_dict:
    pagemsg("WARNING: Can't find page in original file")
    return
  from_changes = origfile_changes_dict[pagetitle]
  to_changes = direcfile_changes_dict[pagetitle]
  if len(from_changes) != len(to_changes):
    pagemsg("WARNING: Saw %s change%s in original but %s change%s in replacement, can't match" % (
      len(from_changes), "" if len(from_changes) == 1 else "s", len(to_changes), "" if len(to_changes) == 1 else "s"))
    return
  if from_changes == to_changes:
    pagemsg("from-changes identical to to-changes, skipping")
    return
  # FIXME: Support per-change comments in replacement file
  text, notes = push_one_set_of_manual_changes(pagetitle, index, text, zip(to_changes, from_changes), None)

  return text, combine_notes_with_comment(notes)

params = blib.create_argparser("Push manual changes to Wiktionary",
  include_pagefile=True, include_stdin=True)
params.add_argument("--direcfile", help="File containing templates to change, as output by various scripts with --from-to",
    required=True)
params.add_argument("--origfile", help="File containing original templates, in the split-file format")
params.add_argument("--undo-slash-newline", action="store_true", help=r"Undo replacement of newlines with \n")
params.add_argument("--comment", help="Comment of change log message (included in addition to any comments embedded in the manual changes)")
params.add_argument("--include-what-changed", action="store_true", help="If no comment embedded in manual changes, include what changed in the changelog")

args = params.parse_args()
start, end = blib.parse_start_end(args.start, args.end)
if args.origfile:
  direcfile_changes = read_split_direcfile(args.direcfile, start, end)
  direcfile_changes_dict = split_template_changes_to_dict(direcfile_changes)
  origfile_changes = read_split_direcfile(args.origfile, None, None)
  origfile_changes_dict = split_template_changes_to_dict(origfile_changes)
  blib.do_pagefile_cats_refs(args, None, None, process_text_on_page_pushing_split_manual_changes, edit=True, stdin=True,
                             default_pages=list(direcfile_changes_dict.keys()))
else:
  direcfile_changes = read_direcfile(args.direcfile, start, end)
  direcfile_changes_dict = template_changes_to_dict(direcfile_changes)
  blib.do_pagefile_cats_refs(args, None, None, process_text_on_page_pushing_manual_changes, edit=True, stdin=True,
                             default_pages=list(direcfile_changes_dict.keys()))
