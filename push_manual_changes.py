#!/usr/bin/env python
# -*- coding: utf-8 -*-

import re, codecs

import blib, pywikibot
from blib import msg, getparam, addparam
from collections import defaultdict

site = pywikibot.Site()

max_truncate_len = 80

def truncate(text):
  if len(text) < max_truncate_len:
    return text
  return text[0:max_truncate_len] + "..."

def read_direcfile(direcfile, start, end):
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
          template_changes.append((pagename, repl, curr))
        else:
          template_changes.append(m.groups())
      else:
        linemsg("WARNING: Ignoring line with from=to: %s" % line)
    else:
      mpage = re.search(r"^(?:Page [^ ]+ )(.*?): (.*)$", line)
      if not mpage:
        linemsg("WARNING: Unable to parse line: [%s]" % line)
        continue
      pagename, directives = mpage.groups()
      for m in re.finditer("<from> (.*?) <to> (.*?) <end>", directives):
        curr, repl = m.groups()
        if curr != repl:
          template_changes.append((pagename, repl, curr))
        else:
          linemsg("WARNING: Ignoring line with from=to: %s" % line)
  return template_changes

def template_changes_to_dict(template_changes):
  retval = defaultdict(list)
  for pagename, repl_template, curr_template in template_changes:
    retval[pagename].append((repl_template, curr_template))
  return retval

def push_one_manual_change(pagetitle, index, text, curr_template, repl_template):
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
  found_repl_template = repl_template in text
  newtext = text.replace(curr_template, repl_template)
  changelog = ""
  if newtext == text:
    if not found_repl_template:
      pagemsg("WARNING: Unable to locate current template: %s"
          % curr_template)
    else:
      pagemsg("Replacement template already found, taking no action")
  else:
    if found_repl_template:
      pagemsg("WARNING: Made change, but replacement template %s already present!" %
          repl_template)
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
    changelog = "replace <%s> with <%s> (%s)" % (truncate(curr_template),
        truncate(repl_template), comment)
    pagemsg("Change log = %s" % changelog)
  return newtext, changelog

def push_manual_changes(save, verbose, diff, template_changes, start, end):
  for index, (pagename, repl_template, curr_template) in blib.iter_items(template_changes, get_name = lambda x: x[0]):
    page = pywikibot.Page(site, pagename)
    if not page.exists():
      msg("Page %s %s: WARNING, something wrong, does not exist" % (
        index, pagename))
    else:
      def do_push_one_manual_change(page, index, text):
        return push_one_manual_change(str(page.title()), index, text, curr_template, repl_template)
      blib.do_edit(page, index, do_push_one_manual_change, save=save,
          verbose=verbose, diff=diff)

def process_text_on_page_pushing_manual_changes(index, pagetitle, text):
  global args
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  if pagetitle not in direcfile_changes_dict:
    return
  notes = []
  for repl_template, curr_template in direcfile_changes_dict[pagetitle]:
    text, this_changelog = push_one_manual_change(pagetitle, index, text, curr_template, repl_template)
    notes.append(this_changelog)

  return text, notes

params = blib.create_argparser("Push manual changes to Wiktionary",
  include_pagefile=True, include_stdin=True)
params.add_argument("--direcfile", help="File containing templates to change, as output by parse_log_file.py",
    required=True)
params.add_argument("--comment", default="manually",
    help="Comment in change log message used to indicate source of changes (default 'manually')")

args = params.parse_args()
start, end = blib.parse_start_end(args.start, args.end)
comment = args.comment.decode("utf-8")
direcfile_changes = read_direcfile(args.direcfile, start, end)

if args.stdin:
  direcfile_changes_dict = template_changes_to_dict(direcfile_changes)
  blib.do_pagefile_cats_refs(args, start, end, process_text_on_page_pushing_manual_changes, edit=True, stdin=True)
else:
  push_manual_changes(args.save, args.verbose, args.diff, direcfile_changes, start, end)
