#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse
from collections import defaultdict

import blib
from blib import getparam, rmparam, msg, site, tname

def process_text_on_page(index, pagetitle, text, templates, paramspecs, countparams, counted_param_values_by_template):
  if not any(template in text for template in templates):
    return
  #if not re.search(r"\{\{\s*(%s)" % "|".join(templates), text):
  #  return

  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  if args.verbose and not args.stdin:
    pagemsg("Processing")
  notes = []

  parsed = blib.parse_text(text)

  paramset = paramspecs and set(paramspecs) or set()

  lines_output = 0
  def output_found(txt):
    nonlocal lines_output
    if args.find_regex_output:
      if lines_output == 0:
        pagemsg("-------- begin text --------")
      msg(txt)
    else:
      pagemsg(txt)
    lines_output += 1
  for t in parsed.filter_templates():
    if args.from_to:
      temptext = "<from> %s <to> %s <end>" % (str(t), str(t))
    else:
      temptext = str(t)
    tn = tname(t)
    if tn in templates:
      if not paramspecs and not countparams:
        output_found("Found %s template: %s" % (tn, temptext))
      else:
        seen_params = set()
        counted_param_values = counted_param_values_by_template[tn]
        for tparam in t.params:
          pname = str(tparam.name).strip()
          pvalue = str(tparam.value).strip()
          seen_params.add(pname)
          if pname in countparams or "*" in countparams:
            if pname not in counted_param_values:
              counted_param_values[pname] = defaultdict(int)
            if pvalue not in counted_param_values[pname]:
              output_found("Found new value %s=%s for %s template: %s" % (pname, pvalue, tn, temptext))
            counted_param_values[pname][pvalue] += 1
          if args.negate:
            if pname not in paramset:
              output_found("Found %s template with unrecognized param %s=%s: %s" % (tn, pname, pvalue, temptext))
          elif paramspecs:
            for spec in paramspecs:
              found = False
              if type(spec) is tuple:
                cond = spec[0]
                if (cond == 'eq' and pname == spec[1] and pvalue == spec[2] or
                    cond == 'neq' and pname == spec[1] and pvalue != spec[2]):
                  found = True
              elif pname == spec:
                found = True
              if found:
                output_found("Found %s template with %s=%s: %s" % (tn, pname, pvalue, temptext))
        # Also output occurrences of missing params when !PARAM given
        if paramspecs:
          for spec in paramspecs:
            if type(spec) is tuple and spec[0] == 'notpresent':
              if not getparam(t, spec[1]):
                output_found("Found %s template with param %s missing or blank: %s" % (tn, spec[1], temptext))
        # Also track occurrences of params in countparams not occurring
        if countparams:
          for countparam in countparams:
            if countparam != "*" and countparam not in seen_params:
              if countparam not in counted_param_values:
                counted_param_values[countparam] = defaultdict(int)
              if None not in counted_param_values[countparam]:
                output_found("Found new value %s=(unseen) for %s template: %s" % (countparam, tn, temptext))
              counted_param_values[countparam][None] += 1
  if lines_output > 0:
    if args.find_regex_output:
      msg("-------- end text --------")
    if args.verbose:
      pagemsg("Output %s lines" % lines_output)

parser = blib.create_argparser("Find templates with specified params",
    include_pagefile=True, include_stdin=True)
parser.add_argument("--templates",
    help="""Comma-separated list of templates to check params of.""")
parser.add_argument("--params",
    help="""Comma-separated list of params to check for.
Normally, will output a template if it has any of the specified parameters.
Can be of the form PARAM=VALUE to only find cases where the parameter has a
specific value, or PARAM!=VALUE to only find cases where the parameter doesn't
have a specific value. If omitted, output all templates.""")
parser.add_argument("--count",
    help="""Comma-separated list of params to count values of. If '*', count all params.""")
parser.add_argument("--negate",
    help="""Check if any params NOT in '--params' are present.""",
    action="store_true")
parser.add_argument("--from-to",
    help="""Output in from-to format for use with push_manual_changes.py.""",
    action="store_true")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

templates = re.split(",", args.templates)

def process_param(param):
  if "!=" in param:
    parts = param.split("!=")
    if len(parts) != 2:
      raise ValueError("Too many parts in PARAM!=VALUE spec: %s" % param)
    return ('neq', parts[0], parts[1])
  if "=" in param:
    parts = param.split("=")
    if len(parts) != 2:
      raise ValueError("Too many parts in PARAM=VALUE spec: %s" % param)
    return ('eq', parts[0], parts[1])
  if param.startswith("!"):
    return ('notpresent', param[1:])
  return param

if args.params:
  paramspecs = [process_param(param) for param in re.split(",", args.params)]
else:
  paramspecs = None

if args.negate:
  if not paramspecs:
    raise ValueError("When --negate is given, --params must be given")
  for paramspec in paramspecs:
    if type(paramspec) is tuple:
      raise ValueError("When --negate is given, PARAM=VALUE, PARAM!=VALUE, !PARAM specs not currently supported")

countparams = re.split(",", args.count) if args.count else []

counted_param_values_by_template = {template: {} for template in templates}
def do_process_text_on_page(index, pagetitle, text):
  process_text_on_page(index, pagetitle, text, templates, paramspecs, countparams, counted_param_values_by_template)
blib.do_pagefile_cats_refs(args, start, end, do_process_text_on_page, stdin=True,
    default_refs=["Template:%s" % template for template in templates])

for template in templates:
  counted_param_values = counted_param_values_by_template[template]
  if "*" in countparams:
    countparams = sorted(list(counted_param_values.keys()))
  for countparam in countparams:
    if countparam in counted_param_values:
      msg("For template %s, param %s, saw the following values:" %
        (template, countparam))
      for pname, count in sorted(
        counted_param_values[countparam].items(), key=lambda x:-x[1]
      ):
        msg("%s = %s" % ("(unseen)" if pname is None else pname, count))
    else:
      msg("For template %s, param %s never seen" % (template, countparam))
