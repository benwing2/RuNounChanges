#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site, tname, pname

def process_text_on_page(index, pagetitle, text, templates, new_names, params_to_add, params_to_prepend,
    params_to_insert, params_to_remove, params_to_rename, filters, comment):
  if not any(template in text for template in templates):
    return
  if not re.search(r"\{\{\s*(%s)" % "|".join(templates), text):
    return

  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")
  notes = []

  if new_names:
    template_to_new_name_dict = dict(zip(templates, new_names))

  parsed = blib.parse_text(text)

  for t in parsed.filter_templates():
    origt = unicode(t)
    tn = tname(t)
    def getp(param):
      return getparam(t, param).strip()
    if tn in templates:
      must_continue = False
      for filt in filters:
        m = re.search("^(.*)!=(.*)$", filt)
        if m:
          if getp(m.group(1)) == m.group(2):
            pagemsg("Skipping %s because filter %s doesn't match" % (origt, filt))
            must_continue = True
            break
          continue
        m = re.search("^(.*)=(.*)$", filt)
        if m:
          if getp(m.group(1)) != m.group(2):
            pagemsg("Skipping %s because filter %s doesn't match" % (origt, filt))
            must_continue = True
            break
          continue
        m = re.search("^(.*)!~(.*)$", filt)
        if m:
          if re.search(m.group(2), getp(m.group(1))):
            pagemsg("Skipping %s because filter %s doesn't match" % (origt, filt))
            must_continue = True
            break
          continue
        m = re.search("^(.*)~(.*)$", filt)
        if m:
          if not re.search(m.group(2), getp(m.group(1))):
            pagemsg("Skipping %s because filter %s doesn't match" % (origt, filt))
            must_continue = True
            break
          continue
        m = re.search("^!(.*)$", filt)
        if m:
          if getp(m.group(1)):
            pagemsg("Skipping %s because filter %s doesn't match" % (origt, filt))
            must_continue = True
            break
          continue
        if not getp(filt):
          pagemsg("Skipping %s because filter %s doesn't match" % (origt, filt))
          must_continue = True
          break
        continue
      if must_continue:
        continue
      for old_param, new_param in params_to_rename:
        if t.has(old_param):
          t.add(new_param, getparam(t, old_param), before=old_param, preserve_spacing=False)
          rmparam(t, old_param)
          notes.append("rename %s= to %s= in {{%s}}" % (old_param, new_param, tn))
      for param in params_to_remove:
        if t.has(param):
          rmparam(t, param)
          notes.append("remove %s= from {{%s}}" % (param, tn))
      for param, value in params_to_add:
        if getparam(t, param) != value:
          t.add(param, value)
          notes.append("add %s=%s to {{%s}}" % (param, value, tn))
      for param, value in reversed(params_to_prepend):
        if getparam(t, param) != value:
          if t.has(param):
            t.add(param, value)
            notes.append("add %s=%s to {{%s}}" % (param, value, tn))
          else:
            first_pn = None
            for paramobj in t.params:
              first_pn = pname(paramobj)
              break
            t.add(param, value, before=first_pn)
            notes.append("prepend %s=%s to {{%s}}" % (param, value, tn))
      if params_to_insert:
        new_params = []
        params_to_insert = sorted(params_to_insert, key=lambda x: x[0])
        last_param_inserted = 0
        param_offset = 0
        max_existing_numeric_param = 0
        for param in t.params:
          pn = pname(param)
          if re.search("^[0-9]+$", pn):
            pnint = int(pn)
            max_existing_numeric_param = max(max_existing_numeric_param, pnint)
        def insert_remaining_numeric_params():
          local_last_param_inserted = last_param_inserted
          local_param_offset = param_offset
          # insert any new numeric params greater than those inserted so far
          for param_to_insert, values_to_insert in params_to_insert:
            if param_to_insert > local_last_param_inserted:
              # add blank params to avoid leading a gap between last param so far and new params
              for i in xrange(max(max_existing_numeric_param, local_last_param_inserted) + 1, param_to_insert):
                new_params.append((unicode(i + local_param_offset), ""))
              for i, value_to_insert in enumerate(values_to_insert):
                new_params.append((unicode(param_to_insert + local_param_offset + i), value_to_insert))
              notes.append("insert %s=%s into {{%s}}" % (param_to_insert, "|".join(values_to_insert), tn))
              local_last_param_inserted = param_to_insert
              # subtract one because we're not inserting a param after the numeric params just inserted
              local_param_offset += len(values_to_insert) - 1
        if max_existing_numeric_param == 0:
          insert_remaining_numeric_params()
        for param in t.params:
          pn = pname(param)
          pv = unicode(param.value)
          if re.search("^[0-9]+$", pn):
            pnint = int(pn)
            for param_to_insert, values_to_insert in params_to_insert:
              if param_to_insert > last_param_inserted and param_to_insert <= pnint:
                for i, value_to_insert in enumerate(values_to_insert):
                  new_params.append((unicode(param_to_insert + param_offset + i), value_to_insert))
                notes.append("insert %s=%s into {{%s}}" % (param_to_insert, "|".join(values_to_insert), tn))
                last_param_inserted = param_to_insert
                param_offset += len(values_to_insert)
            new_params.append((unicode(pnint + param_offset), pv))
            if pnint == max_existing_numeric_param:
              insert_remaining_numeric_params()
          else:
            new_params.append((pn, pv))
        del t.params[:]
        for pn, pv in new_params:
          t.add(pn, pv, preserve_spacing=False)

      if new_names:
        new_name = template_to_new_name_dict[tn]
        blib.set_template_name(t, new_name)
        notes.append("rename {{%s}} to {{%s}}" % (tn, new_name))

    if unicode(t) != origt:
      pagemsg("Replaced <%s> with <%s>" % (origt, unicode(t)))

  return unicode(parsed), comment or notes

pa = blib.create_argparser("Rewrite templates, possibly renaming params or the template itself, or removing params",
  include_pagefile=True, include_stdin=True)
pa.add_argument("-t", "--template", help="Name of template; separate with a comma for multiple templates", required=True)
pa.add_argument("-n", "--new-name", help="New name of template; separate with a comma for multiple templates")
pa.add_argument("-r", "--remove", help="Param to remove, can be specified multiple times",
    action="append")
pa.add_argument("--from", help="Old name of param, can be specified multiple times",
    metavar="FROM", dest="from_", action="append")
pa.add_argument("--to", help="New name of param, can be specified multiple times",
    action="append")
pa.add_argument("--prepend", help="PARAM=VALUE to add at the beginning, can be specified multiple times",
    action="append")
pa.add_argument("--add", help="PARAM=VALUE to add at the end, can be specified multiple times",
    action="append")
pa.add_argument("--insert", help="Insert numeric PARAM=VALUE|VALUE|..., moving greater numeric params to the right; can be specified multiple times, works from right to left",
    action="append")
pa.add_argument("--filter", help="Only take action on templates matching the filter, which should be either PARAM meaning the parameter must exist and be non-empty; !PARAM meaning the parameter must not exist or must be empty; PARAM=VALUE meaning the parameter must have the given value; PARAM!=VALUE meaning the parameter must not have the given value; PARAM~REGEXP meaning the parameter's value must match the given regular expression (unanchored); or PARAM!~REGEXP meaning the parameter's value must not match the given regular expression (unanchored). Can be specified multiple times and all must match. Note that all parameter values have whitespace stripped from both ends before comparison.",
    action="append")
pa.add_argument("-c", "--comment", help="Comment to use in place of auto-generated ones.")
args = pa.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

def handle_single_param(paramname, process=None):
  argval = getattr(args, paramname)
  if argval:
    rawval = argval.decode("utf-8")
    if process:
      return process(rawval)
    else:
      return rawval
  else:
    return None

def handle_list_param(paramname, process=None):
  argval = getattr(args, paramname)
  rawvals = [x.decode("utf-8") for x in argval] if argval else []
  if process:
    return [process(x) for x in rawvals]
  else:
    return rawvals

def handle_params_to_add(paramname, process_parts=None):
  argval = getattr(args, paramname)
  params_to_add = []
  addspecs = [x.decode("utf-8") for x in argval] if argval else []
  for spec in addspecs:
    specparts = spec.split("=")
    if len(specparts) != 2:
      raise ValueError("Value %s to --%s must have the form PARAM=VALUE" % (spec, paramname))
    if process_parts:
      parts_to_add = process_parts(*specparts)
    else:
      parts_to_add = specparts
    params_to_add.append(parts_to_add)
  return params_to_add

templates = handle_single_param("template", lambda val: val.split(","))
new_names = handle_single_param("new_name", lambda val: val.split(","))
if new_names and len(new_names) != len(templates):
  raise ValueError("Saw %s template(s) '%s' but %s new name(s) '%s'; both must agree in number" %
    (len(templates), ",".join(templates), len(new_names), ",".join(new_names)))

from_ = handle_list_param("from_")
to = handle_list_param("to")

params_to_add = handle_params_to_add("add")
params_to_prepend = handle_params_to_add("prepend")
def process_insert_parts(param, value):
  if not re.search("^[0-9]+$", param):
    raise ValueError("Parameter %s to --insert must be numeric" % param)
  return (int(param), value.split("|"))
params_to_insert = handle_params_to_add("insert", process_insert_parts)
params_to_remove = handle_list_param("remove")
filters = handle_list_param("filter")
comment = handle_single_param("comment")

if len(from_) != len(to):
  raise ValueError("Same number of --from and --to arguments must be specified")

params_to_rename = zip(from_, to)

def do_process_text_on_page(index, pagetitle, text):
  return process_text_on_page(index, pagetitle, text, templates, new_names, params_to_add, params_to_prepend,
    params_to_insert, params_to_remove, params_to_rename, filters, comment)

blib.do_pagefile_cats_refs(args, start, end, do_process_text_on_page, edit=True, stdin=True,
  default_refs=["Template:%s" % template for template in templates])
