#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import re

import blib, pywikibot
from blib import msg, getparam, addparam

site = pywikibot.Site()

def undo_greek_removal(save, verbose, direcfile, start, end):
  template_removals = []
  for lineno, line in blib.iter_items_from_file(direcfile, start, end):
    m = re.match(r"\* \[\[(.*?)]]: Removed (.*?)=.*?: <nowiki>(.*?)</nowiki>$",
        line)
    if not m:
      msg("Line %s: WARNING: Unable to parse line: [%s]" % (lineno, line))
    else:
      template_removals.append(m.groups())

  for index, (pagename, removed_param, template_text) in blib.iter_items(
      template_removals, get_name = lambda x: x[0]):

    def undo_one_page_greek_removal(page, index, text):
      def pagemsg(txt):
        msg("Page %s %s: %s" % (index, str(page.title()), txt))
      template = blib.parse_text(template_text).filter_templates()[0]
      orig_template = str(template)
      if getparam(template, "sc") == "polytonic":
        template.remove("sc")
      to_template = str(template)
      param_value = getparam(template, removed_param)
      template.remove(removed_param)
      from_template = str(template)
      text = str(text)
      found_orig_template = orig_template in text
      newtext = text.replace(from_template, to_template)
      changelog = ""
      if newtext == text:
        if not found_orig_template:
          pagemsg("WARNING: Unable to locate 'from' template when undoing Greek param removal: %s"
              % from_template)
        else:
          pagemsg("Original template found, taking no action")
      else:
        if found_orig_template:
          pagemsg("WARNING: Undid removal, but original template %s already present!" %
              orig_template)
        if len(newtext) - len(text) != len(to_template) - len(from_template):
          pagemsg("WARNING: Length mismatch when undoing Greek param removal, may have matched multiple templates: from=%s, to=%s" % (
            from_template, to_template))
        changelog = "Undid removal of %s=%s in %s" % (removed_param,
            param_value, to_template)
        pagemsg("Change log = %s" % changelog)
      return newtext, changelog

    page = pywikibot.Page(site, pagename)
    if not page.exists():
      msg("Page %s %s: WARNING, something wrong, does not exist" % (
        index, pagename))
    else:
      blib.do_edit(page, index, undo_one_page_greek_removal, save=save,
          verbose=verbose)

params = blib.create_argparser("Undo Greek transliteration removal")
params.add_argument("--file",
    help="File containing templates and removal directives to undo", required=True)

args = params.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

undo_greek_removal(args.save, args.verbose, args.file, start, end)
