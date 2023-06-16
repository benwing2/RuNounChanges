#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import re

import blib, pywikibot
from blib import msg, getparam, addparam

def fix_tool_place_noun(save, verbose, startFrom, upTo):
  for template in ["ar-tool noun", "ar-noun of place", "ar-instance noun"]:

    # Fix the template refs. If cap= is present, remove it; else, add lc=.
    def fix_one_page_tool_place_noun(page, index, text):
      pagetitle = page.title()
      for t in text.filter_templates():
        if t.name == template:
          if getparam(t, "cap"):
            msg("Page %s %s: Template %s: Remove cap=" %
                (index, pagetitle, template))
            t.remove("cap")
          else:
            msg("Page %s %s: Template %s: Add lc=1" %
                (index, pagetitle, template))
            addparam(t, "lc", "1")
      changelog = "%s: If cap= is present, remove it, else add lc=" % template
      msg("Page %s %s: Change log = %s" % (index, pagetitle, changelog))
      return text, changelog

    for index, page in blib.references("Template:" + template, startFrom, upTo):
      blib.do_edit(page, index, fix_one_page_tool_place_noun, save=save,
          verbose=verbose)

pa = blib.create_argparser("Fix lc vs. cap in tool/place noun etym templates")
params = pa.parse_args()
startFrom, upTo = blib.parse_start_end(params.start, params.end)

fix_tool_place_noun(params.save, params.verbose, startFrom, upTo)
