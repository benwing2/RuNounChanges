#!/usr/bin/env python
# -*- coding: utf-8 -*-

import re, codecs

import blib, pywikibot
from blib import msg, getparam, addparam

site = pywikibot.Site()

max_truncate_len = 80

def truncate(text):
  if len(text) < max_truncate_len:
    return text
  return text[0:max_truncate_len] + "..."

def push_manual_changes(save, verbose, diff, direcfile, comment, start, end):
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

  for index, (pagename, repl_template, curr_template) in blib.iter_items(template_changes, get_name = lambda x: x[0]):
    def push_one_manual_change(page, index, text):
      def pagemsg(txt):
        msg("Page %s %s: %s" % (index, unicode(page.title()), txt))
      #template = blib.parse_text(template_text).filter_templates()[0]
      #orig_template = unicode(template)
      #if getparam(template, "sc") == "polytonic":
      #  template.remove("sc")
      #to_template = unicode(template)
      #param_value = getparam(template, removed_param)
      #template.remove(removed_param)
      #from_template = unicode(template)
      text = unicode(text)
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

    page = pywikibot.Page(site, pagename)
    if not page.exists():
      msg("Page %s %s: WARNING, something wrong, does not exist" % (
        index, pagename))
    else:
      blib.do_edit(page, index, push_one_manual_change, save=save,
          verbose=verbose, diff=diff)

params = blib.create_argparser("Push manual changes to Wiktionary")
params.add_argument("--file", help="File containing templates to change, as output by parse_log_file.py",
    required=True)
params.add_argument("--comment", default="manually",
    help="Comment in change log message used to indicate source of changes (default 'manually')")

args = params.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

push_manual_changes(args.save, args.verbose, args.diff, args.file, args.comment.decode("utf-8"), start, end)
