#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site, tname

def process_page(page, index, template, paramspecs, negate):
  pagetitle = unicode(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")
  notes = []

  parsed = blib.parse(page)

  paramset = paramspecs and set(paramspecs) or set()

  for t in parsed.filter_templates():
    tn = tname(t)
    if tn == template:
      if not paramspecs:
        pagemsg("Found %s template: %s" % (template, unicode(t)))
      else:
        for tparam in t.params:
          pname = unicode(tparam.name).strip()
          pvalue = unicode(tparam.value).strip()
          if negate:
            if pname not in paramset:
              pagemsg("Found %s template with unrecognized param %s=%s: %s" %
                  (template, pname, pvalue, unicode(t)))
          else:
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
                    (template, pname, pvalue, unicode(t)))

parser = blib.create_argparser("Find templates with specified params")
parser.add_argument("--templates",
    help=u"""Comma-separated list of templates to check params of.""")
parser.add_argument("--params",
    help=u"""Comma-separated list of params to check for.
Normally, will output a template if it has any of the specified parameters.
Can be of the form PARAM=VALUE to only find cases where the parameter has a
specific value, or PARAM!=VALUE to only find cases where the parameter doesn't
have a specific value. If omitted, output all templates.""")
parser.add_argument("--negate",
    help=u"""Check if any params NOT in '--params' are present.""",
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

for template in templates:
  msg("Processing references to Template:%s" % template)
  for i, page in blib.references("Template:%s" % template, start, end):
    process_page(page, i, template, paramspecs, args.negate)
