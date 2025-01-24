#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, msg, site, tname, pname
from rename import rename_page

templates_to_rename = set()
template_couldnt_be_renamed = set()
template_to_new_name_dict = {}

def process_text_on_page(
    index, pagetitle, text, templates, new_names, params_to_add, params_to_prepend, params_to_insert, params_to_remove,
    params_to_rename, from_to_regex, filters, recognized_params, comment, comment_tag
):
  if not any(template in text for template in templates):
    return
  if not re.search(r"\{\{\s*(%s)" % "|".join(re.escape(t) for t in templates), text):
    return

  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")
  notes = []

  def append_note(note):
    notes.append(note)

  parsed = blib.parse_text(text)

  def substitute_in_value(value, is_regex=False):
    repl_pagetitle = pagetitle
    if is_regex:
      repl_pagetitle = re.escape(repl_pagetitle)
    value = value.replace("{{PAGENAME}}", repl_pagetitle)
    return value

  for t in parsed.filter_templates():
    origt = str(t)
    tn = tname(t)
    def getp(param):
      return getparam(t, param).strip()
    if tn in templates:
      must_continue = False
      for filt in filters:
        m = re.search("^(.*?)!=(.*)$", filt)
        if m:
          if getp(m.group(1)) == substitute_in_value(m.group(2)):
            pagemsg("Skipping %s because filter %s doesn't match" % (origt, filt))
            must_continue = True
            break
          continue
        m = re.search("^(.*?)=(.*)$", filt)
        if m:
          if getp(m.group(1)) != substitute_in_value(m.group(2)):
            pagemsg("Skipping %s because filter %s doesn't match" % (origt, filt))
            must_continue = True
            break
          continue
        m = re.search("^(.*)!~(.*)$", filt)
        if m:
          if re.search(substitute_in_value(m.group(2), is_regex=True), getp(m.group(1))):
            pagemsg("Skipping %s because filter %s doesn't match" % (origt, filt))
            must_continue = True
            break
          continue
        m = re.search("^(.*)~(.*)$", filt)
        if m:
          if not re.search(substitute_in_value(m.group(2), is_regex=True), getp(m.group(1))):
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

      must_continue = False
      if recognized_params:
        for param in t.params:
          pn = pname(param)
          recognized = None
          for recognized_param in recognized_params:
            if recognized_param == "-":
              recognized = False
              break
            elif re.search("^" + recognized_param + "$", pn):
              recognized = True
              break
            # else try next recognized param
          else: # no break
            recognized = False
          if not recognized:
            pagemsg("Skipping %s because of unrecognized param %s=%s" % (origt, pn, str(param.value)))
            must_continue = True
            break
      if must_continue:
        continue

      if tn in templates_to_rename:
        new_name = template_to_new_name_dict[tn]
        template_page = pywikibot.Page(site, "Template:%s" % tn)
        rename_comment = comment
        if not rename_comment:
          rename_comment = "rename template preparatory to renaming all uses"
        rename_comment = blib.changelog_to_string(rename_comment, comment_tag)
        templates_to_rename.remove(tn)
        if not rename_page(args, index, template_page, "Template:%s" % new_name, rename_comment, None, None):
          ignore_error = False
          if ignore_rename_errors is True:
            ignore_error = True # ignore all rename errors
          elif ignore_rename_errors and tn in ignore_rename_errors:
            ignore_error = True # ignore rename error for this template
          else:
            template_couldnt_be_renamed.add(tn)
          if ignore_error:
            pagemsg("WARNING: Ignoring rename error for Template:%s -> Template:%s" % (tn, new_name))

      if tn in template_couldnt_be_renamed:
        pagemsg("Skipping %s because template couldn't be renamed" % tn)
        continue

      if from_to_regex:
        for param in t.params:
          pn = pname(param)
          for old_param, new_param in params_to_rename:
            newpn = re.sub("^" + old_param + "$", new_param, pn)
            if newpn != pn:
              param.name = newpn
              append_note("rename %s= to %s= in {{%s}}" % (pn, newpn, tn))
              break
      else:
        for old_param, new_param in params_to_rename:
          can_overwrite = False
          if new_param.startswith("!"):
            can_overwrite = True
            new_param = new_param[1:]
          if t.has(old_param):
            will_overwrite = True
            if t.has(new_param):
              if can_overwrite:
                pagemsg("When renaming %s=%s to %s=, already has %s=%s, overwriting" % (
                  old_param, getp(old_param), new_param, new_param, getp(new_param)))
              else:
                pagemsg("WARNING: When renaming %s=%s to %s=, already has %s=%s" % (
                  old_param, getp(old_param), new_param, new_param, getp(new_param)))
                will_overwrite = False
            if will_overwrite:
              t.add(new_param, getparam(t, old_param), before=old_param, preserve_spacing=False)
              rmparam(t, old_param)
              append_note("rename %s= to %s= in {{%s}}" % (old_param, new_param, tn))
      for param in params_to_remove:
        if t.has(param):
          rmparam(t, param)
          append_note("remove %s= from {{%s}}" % (param, tn))
      for param, value in params_to_add:
        value = substitute_in_value(value)
        if getparam(t, param) != value:
          t.add(param, value)
          append_note("add %s=%s to {{%s}}" % (param, value, tn))
      for param, value in reversed(params_to_prepend):
        value = substitute_in_value(value)
        if getparam(t, param) != value:
          if t.has(param):
            t.add(param, value)
            append_note("add %s=%s to {{%s}}" % (param, value, tn))
          else:
            first_pn = None
            for paramobj in t.params:
              first_pn = pname(paramobj)
              break
            t.add(param, value, before=first_pn)
            append_note("prepend %s=%s to {{%s}}" % (param, value, tn))
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
              for i in range(max(max_existing_numeric_param, local_last_param_inserted) + 1, param_to_insert):
                new_params.append((str(i + local_param_offset), ""))
              values_to_insert = [substitute_in_value(v) for v in values_to_insert]
              for i, value_to_insert in enumerate(values_to_insert):
                new_params.append((str(param_to_insert + local_param_offset + i), value_to_insert))
              append_note("insert %s=%s into {{%s}}" % (param_to_insert, "|".join(values_to_insert), tn))
              local_last_param_inserted = param_to_insert
              # subtract one because we're not inserting a param after the numeric params just inserted
              local_param_offset += len(values_to_insert) - 1
        if max_existing_numeric_param == 0:
          insert_remaining_numeric_params()
        for param in t.params:
          pn = pname(param)
          pv = str(param.value)
          if re.search("^[0-9]+$", pn):
            pnint = int(pn)
            for param_to_insert, values_to_insert in params_to_insert:
              values_to_insert = [substitute_in_value(v) for v in values_to_insert]
              if param_to_insert > last_param_inserted and param_to_insert <= pnint:
                for i, value_to_insert in enumerate(values_to_insert):
                  new_params.append((str(param_to_insert + param_offset + i), value_to_insert))
                append_note("insert %s=%s into {{%s}}" % (param_to_insert, "|".join(values_to_insert), tn))
                last_param_inserted = param_to_insert
                param_offset += len(values_to_insert)
            new_params.append((str(pnint + param_offset), pv))
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
        append_note("rename {{%s}} to {{%s}}" % (tn, new_name))

    if str(t) != origt:
      pagemsg("Replaced <%s> with <%s>" % (origt, str(t)))

  if not comment:
    comment = notes
  comment = blib.changelog_to_string(comment, comment_tag)
  return str(parsed), comment

pa = blib.create_argparser("Rewrite templates, possibly renaming params or the template itself, or removing params",
  include_pagefile=True, include_stdin=True)
pa.add_argument("-t", "--template", help="Name of template; separate with a comma for multiple templates.")
pa.add_argument("-n", "--new-name", help="New name of template; separate with a comma for multiple templates.")
pa.add_argument("--direcfile", help="File containing templates to rewrite.")
pa.add_argument("--rename-templates", help="Rename the templates whose references are being changed.",
                action="store_true")
pa.add_argument("--ignore-rename-errors", help="Comma-separated list of templates to ignore rename errors for, or 'all' for all templates.")
pa.add_argument("-r", "--remove", help="Param to remove, can be specified multiple times",
    action="append")
pa.add_argument("--from", help="Old name of param, can be specified multiple times",
    metavar="FROM", dest="from_", action="append")
pa.add_argument("--to", help="New name of param, can be specified multiple times; if param preceded by an !, can overwrite existing param",
    action="append")
pa.add_argument("--from-to-regex", help="Interpret values in --from and --to as regexes.", action="store_true")
pa.add_argument("--prepend", help="PARAM=VALUE to add at the beginning, can be specified multiple times; VALUE can have {{PAGENAME}} in it to substitute the page title",
    action="append")
pa.add_argument("--add", help="PARAM=VALUE to add at the end, can be specified multiple times; VALUE can have {{PAGENAME}} in it to substitute the page title",
    action="append")
pa.add_argument("--insert", help="Insert numeric PARAM=VALUE|VALUE|..., moving greater numeric params to the right; can be specified multiple times, works from right to left; VALUE can have {{PAGENAME}} in it to substitute the page title",
    action="append")
pa.add_argument("--filter", help="Only take action on templates matching the filter, which should be either PARAM meaning the parameter must exist and be non-empty; !PARAM meaning the parameter must not exist or must be empty; PARAM=VALUE meaning the parameter must have the given value; PARAM!=VALUE meaning the parameter must not have the given value; PARAM~REGEXP meaning the parameter's value must match the given regular expression (unanchored); or PARAM!~REGEXP meaning the parameter's value must not match the given regular expression (unanchored). Can be specified multiple times and all must match. Note that all parameter values have whitespace stripped from both ends before comparison. VALUE and REGEXP can have {{PAGENAME}} in them to substitute the page title; when substituting into a regular expression, the page title is properly escaped.",
    action="append")
pa.add_argument("--recognized-params", help="Comma-separated list of regexps matching recognized params. Use - to indicate no recognized params. If the template contains any unrecognized params, a warning will be displayed and no action taken. Regexps are auto-anchored on both ends.")
pa.add_argument("-c", "--comment", help="Comment to use in place of auto-generated ones.")
pa.add_argument("--comment-tag", help="Comment tag to use along with auto-generated ones.")
args = pa.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

def handle_single_param(paramname, process=None):
  argval = getattr(args, paramname)
  if argval:
    if process:
      return process(argval)
    else:
      return argval
  else:
    return None

def handle_list_param(paramname, split_on_comma=False):
  argval = getattr(args, paramname)
  rawvals = list(argval) if argval else []
  if split_on_comma:
    return [splitval for arg in rawvals for splitval in blib.split_arg(arg)]
  else:
    return rawvals

def handle_params_to_add(paramname, process_parts=None):
  argval = getattr(args, paramname)
  params_to_add = []
  addspecs = list(argval) if argval else []
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

if args.direcfile:
  templates = []
  new_names = []
  for index, line in blib.iter_items_from_file(args.direcfile):
    if " ||| " not in line:
      msg("Line %s: WARNING: Saw bad line in --direcfile: %s" % (index, line))
      continue
    frompage, topage = line.split(" ||| ")
    frompage = re.sub("^Template:", "", frompage)
    topage = re.sub("^Template:", "", topage)
    templates.append(frompage)
    new_names.append(topage)
else:
  templates = handle_single_param("template", blib.split_arg)
  new_names = handle_single_param("new_name", blib.split_arg)
  if new_names and len(new_names) != len(templates):
    if len(new_names) == 1:
      new_names = new_names * len(templates)
    else:
      raise ValueError("Saw %s template(s) '%s' but %s new name(s) '%s'; both must agree in number or there must be only one new name" %
        (len(templates), ",".join(templates), len(new_names), ",".join(new_names)))
if not templates:
  raise ValueError("No templates specified to process")
if new_names:
  template_to_new_name_dict = dict(zip(templates, new_names))
recognized_params = handle_single_param("recognized_params", blib.split_arg)

ignore_rename_errors = handle_single_param("ignore_rename_errors", blib.split_arg)
if ignore_rename_errors == ["all"]:
  ignore_rename_errors = True

from_ = handle_list_param("from_", split_on_comma=True)
to = handle_list_param("to", split_on_comma=True)

params_to_add = handle_params_to_add("add")
params_to_prepend = handle_params_to_add("prepend")
def process_insert_parts(param, value):
  if not re.search("^[0-9]+$", param):
    raise ValueError("Parameter %s to --insert must be numeric" % param)
  return (int(param), value.split("|"))
params_to_insert = handle_params_to_add("insert", process_insert_parts)
params_to_remove = handle_list_param("remove", split_on_comma=True)
filters = handle_list_param("filter")
comment = handle_single_param("comment")

if len(from_) != len(to):
  raise ValueError("Same number of --from and --to arguments must be specified")

params_to_rename = list(zip(from_, to))

def do_process_text_on_page(index, pagetitle, text):
  return process_text_on_page(index, pagetitle, text, templates, new_names, params_to_add, params_to_prepend,
    params_to_insert, params_to_remove, params_to_rename, args.from_to_regex, filters, recognized_params, comment,
    args.comment_tag)

if args.rename_templates:
  templates_to_rename = set(templates)
blib.do_pagefile_cats_refs(args, start, end, do_process_text_on_page, edit=True, stdin=True,
  default_refs=["Template:%s" % template for template in templates])

for index, (template, new_name) in blib.iter_items(zip(templates, new_names), get_name=lambda x: x[0]):
  if template in templates_to_rename:
    template_page = pywikibot.Page(site, "Template:%s" % template)
    rename_comment = comment
    if not rename_comment:
      rename_comment = "rename template preparatory to renaming all uses"
    rename_comment = blib.changelog_to_string(rename_comment, args.comment_tag)
    rename_page(args, index, template_page, "Template:%s" % new_name, rename_comment, None, None)
