#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse
from collections import defaultdict

import blib
from blib import getparam, rmparam, msg, site, tname

def process_page(page, index, templates, paramspecs, negate, from_to,
    countparams, counted_param_values_by_template):
  pagetitle = unicode(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")
  notes = []

  parsed = blib.parse(page)

  paramset = paramspecs and set(paramspecs) or set()

  for t in parsed.filter_templates():
    if from_to:
      temptext = "<from> %s <to> %s <end>" % (unicode(t), unicode(t))
    else:
      temptext = unicode(t)
    tn = tname(t)
    if tn in templates:
      if not paramspecs and not countparams:
        pagemsg("Found %s template: %s" % (tn, temptext))
      else:
        seen_params = set()
        counted_param_values = counted_param_values_by_template[tn]
        for tparam in t.params:
          pname = unicode(tparam.name).strip()
          pvalue = unicode(tparam.value).strip()
          seen_params.add(pname)
          if pname in countparams or "*" in countparams:
            if pname not in counted_param_values:
              counted_param_values[pname] = defaultdict(int)
            if pvalue not in counted_param_values[pname]:
              pagemsg("Found new value %s=%s for %s template: %s" %
                  (pname, pvalue, tn, temptext))
            counted_param_values[pname][pvalue] += 1
          if negate:
            if pname not in paramset:
              pagemsg("Found %s template with unrecognized param %s=%s: %s" %
                  (tn, pname, pvalue, temptext))
          elif paramspecs:
            for spec in paramspecs:
              found = False
              if type(spec) is tuple:
                cond, name, value = spec
                if (cond == 'eq' and pname == name and pvalue == value or
                    cond == 'neq' and pname == name and pvalue != value):
                  found = True
              elif pname == spec:
                found = True
              if found:
                pagemsg("Found %s template with %s=%s: %s" %
                    (tn, pname, pvalue, temptext))
        # Also track occurrences of params in countparams not occurring
        if countparams:
          for countparam in countparams:
            if countparam != "*" and countparam not in seen_params:
              if countparam not in counted_param_values:
                counted_param_values[countparam] = defaultdict(int)
              if None not in counted_param_values[countparam]:
                pagemsg("Found new value %s=(unseen) for %s template: %s" %
                    (countparam, tn, temptext))
              counted_param_values[countparam][None] += 1

parser = blib.create_argparser("Find templates with specified params",
    include_pagefile=True)
parser.add_argument("--templates",
    help=u"""Comma-separated list of templates to check params of.""")
parser.add_argument("--params",
    help=u"""Comma-separated list of params to check for.
Normally, will output a template if it has any of the specified parameters.
Can be of the form PARAM=VALUE to only find cases where the parameter has a
specific value, or PARAM!=VALUE to only find cases where the parameter doesn't
have a specific value. If omitted, output all templates.""")
parser.add_argument("--count",
    help=u"""Comma-separated list of params to count values of. If '*', count all params.""")
parser.add_argument("--negate",
    help=u"""Check if any params NOT in '--params' are present.""",
    action="store_true")
parser.add_argument("--from-to",
    help=u"""Output in from-to format for use with push_manual_changes.py.""",
    action="store_true")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

templates = re.split(",", args.templates.decode('utf-8'))

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
  return param

if args.params:
  paramspecs = [process_param(param) for param in re.split(",", args.params.decode('utf-8'))]
else:
  paramspecs = None

if args.negate:
  if not paramspecs:
    raise ValueError("When --negate is given, --params must be given")
  for paramspec in paramspecs:
    if type(paramspec) is tuple:
      raise ValueError("When --negate is given, PARAM=VALUE and PARAM!=VALUE specs not currently supported")

countparams = re.split(",", args.count) if args.count else []

counted_param_values_by_template = {template: {} for template in templates}
def do_process_page(page, index):
  process_page(page, index, templates, paramspecs, args.negate, args.from_to,
      countparams, counted_param_values_by_template)
blib.do_pagefile_cats_refs(args, start, end, do_process_page,
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
        counted_param_values[countparam].iteritems(), key=lambda x:-x[1]
      ):
        msg("%s = %s" % ("(unseen)" if pname is None else pname, count))
    else:
      msg("For template %s, param %s never seen" % (template, countparam))
