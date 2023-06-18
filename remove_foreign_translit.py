#!/usr/bin/env python3
# -*- coding: utf-8 -*-

# This program removes redundant translit from links and similar templates,
# and also removes redundant sc= values from those same links.

import re, unicodedata

import blib, pywikibot
from blib import msg, getparam, addparam, rmparam

show_template=True

# Map from language codes to list of [LONGLANG, IGNORE_MANUAL_TR], where
# LONGLANG is the canonical name of the language and IGNORE_MANUAL_TR is
# True if manual transliteration is ignored in this language and should
# always be removed.
languages = {
  "cu": ["Old Church Slavonic", False],
  "orv": ["Old East Slavic", False],
  "ru": ["Russian", False],
  "uk": ["Ukrainian", False],
  "be": ["Belarusian", False],
  "bg": ["Bulgarian", False],
  "mk": ["Macedonian", False],
  "sh": ["Serbo-Croatian", False]
}

# Attempt to canonicalize foreign parameter PARAM (which may be a list
# [FROMPARAM, TOPARAM], where FROMPARAM may be "page title") and Latin
# parameter PARAMTR. Return False if PARAM has no value, else list of
# changelog actions.
def canon_param(pagetitle, index, template, tlang, param, paramtr,
    pagemsg, expand_text, include_tempname_in_changelog=False):
  if isinstance(param, list):
    fromparam, toparam = param
  else:
    fromparam, toparam = (param, param)
  foreign = (pagetitle if fromparam == "page title" else
    getparam(template, fromparam))
  latin = getparam(template, paramtr)
  if not foreign or not latin:
    return False
  autotr = expand_text("{{xlit|%s|%s}}" % (tlang, foreign))
  tname = str(template.name)
  if autotr == latin or languages[tlang][1]:
    oldtempl = "%s" % str(template)
    rmparam(template, paramtr)
    pagemsg("Removing redundant translit for %s.%s (%s)" % (
        tname, foreign, latin))
    if include_tempname_in_changelog:
      paramtrname = "%s.%s.%s" % (tname, tlang, paramtr)
    else:
      paramtrname = paramtr
    pagemsg("Replaced %s with %s" % (oldtempl, str(template)))
    return ["remove redundant %s=%s" % (paramtrname, latin)]
  else:
    pagemsg("Not removing non-redundant translit for %s.%s (%s); autotr=%s" % (
      tname, foreign, latin, autotr))
  return False

def combine_adjacent(values):
  combined = []
  for val in values:
    if combined:
      last_val, num = combined[-1]
      if val == last_val:
        combined[-1] = (val, num + 1)
        continue
    combined.append((val, 1))
  return ["%s(x%s)" % (val, num) if num > 1 else val for val, num in combined]

def sort_group_changelogs(actions):
  grouped_actions = {}
  begins = ["split ", "match-canon ", "cross-canon ", "self-canon ",
      "remove redundant ", "remove ", ""]
  for begin in begins:
    grouped_actions[begin] = []
  actiontype = None
  action = ""
  for action in actions:
    for begin in begins:
      if action.startswith(begin):
        actiontag = action.replace(begin, "", 1)
        grouped_actions[begin].append(actiontag)
        break

  grouped_action_strs = (
    [begin + ', '.join(combine_adjacent(grouped_actions[begin]))
        for begin in begins
        if len(grouped_actions[begin]) > 0])
  all_grouped_actions = '; '.join([x for x in grouped_action_strs if x])
  return all_grouped_actions

# Canonicalize foreign and Latin in link-like templates on pages from STARTFROM
# to (but not including) UPTO, either page names or 0-based integers. Save
# changes if SAVE is true. Show exact changes if VERBOSE is true. CATTYPE
# should be 'vocab', 'borrowed', 'translation', 'links', 'pagetext', 'pages',
# an arbitrary category or a list of such items, indicating which pages to
# examine. If CATTYPE is 'pagetext', PAGES_TO_DO should be a list of
# (PAGETITLE, PAGETEXT). If CATTYPE is 'pages', PAGES_TO_DO should be a list
# of page titles, specifying the pages to do. LANG is a list of language codes
# to process templates of. LONGLANG is a canonical language name, as in
# blib.process_links(); this is only used when CATTYPE is 'vocab' or
# 'borrowed'.
def canon_links(save, verbose, cattype, lang, longlang,
    startFrom, upTo, pages_to_do=[]):
  def process_param(pagetitle, index, pagetext, template, tlang, param, paramtr):
    def pagemsg(txt):
      msg("Page %s %s: %s" % (index, pagetitle, txt))

    def expand_text(tempcall):
      return blib.expand_text(tempcall, pagetitle, pagemsg, verbose)

    result = canon_param(pagetitle, index, template, tlang, param, paramtr,
        pagemsg, expand_text, include_tempname_in_changelog=True)
    scvalue = getparam(template, "sc")
    if scvalue:
      if isinstance(param, list):
        fromparam, toparam = param
      else:
        fromparam, toparam = (param, param)
      foreign = (pagetitle if fromparam == "page title" else
        getparam(template, fromparam))
      predicted_script = expand_text("{{#invoke:scripts/templates|findBestScript|%s|%s}}"
          % (foreign, tlang))
      if scvalue == predicted_script:
        tname = str(template.name)
        if show_template and result == False:
          pagemsg("%s.%s.%s: Processing %s" % (
            tname, tlang, "sc", str(template)))
        pagemsg("%s.%s.%s: Removing sc=%s" % (
          tname, tlang, "sc", scvalue))
        oldtempl = "%s" % str(template)
        template.remove("sc")
        pagemsg("Replaced %s with %s" % (oldtempl, str(template)))
        newresult = ["remove %s.%s.sc=%s" % (tname, tlang, scvalue)]
        if result != False:
          result = result + newresult
        else:
          result = newresult
    return result

  return blib.process_links(save, verbose, lang, longlang, cattype,
      startFrom, upTo, process_param, sort_group_changelogs,
      pages_to_do=pages_to_do)

pa = blib.create_argparser("Remove redundant foreign translit and script")
pa.add_argument("--lang",
    help="""Language to use when --cattype is 'vocab' or 'borrowed'.""")
pa.add_argument("--cattype", default="borrowed",
    help="""Categories to examine ('vocab', 'borrowed', 'translation',
'links', 'pagetext', 'pages', an arbitrary category or comma-separated list)""")
pa.add_argument("--page-file",
    help="""File containing "pages" to process when --cattype pagetext,
or list of pages when --cattype pages""")

params = pa.parse_args()
start, end = blib.parse_start_end(params.start, params.end)
pages_to_do = []
if params.page_file:
  for lineno, line in blib.iter_items_from_file(params.page_file, start, end):
    # FIXME: We don't yet support a cattype list containing 'pages'
    if params.cattype == "pages":
      pages_to_do.append(line)
    else:
      m = re.match(r"^Page [0-9]+ (.*?): [^:]*: Processing (.*?)$", line)
      if not m:
        msg("Line %s: WARNING: Unable to parse line: [%s]" % (lineno, line))
      else:
        pages_to_do.append(m.groups())
longlang = None
if params.lang:
  if params.lang not in languages:
    raise ValueError("Unrecognized language '%s'" % params.lang)
  longlang, this_ignore_manual_tr = languages[params.lang]

canon_links(params.save, params.verbose, params.cattype, languages.keys(),
    longlang, startFrom, upTo, pages_to_do=pages_to_do)
