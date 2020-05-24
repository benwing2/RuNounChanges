#!/usr/bin/env python
#coding: utf-8

#    rewrite_template.py is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site, tname

def process_page(index, page, template, new_name, params_to_add, params_to_remove,
    params_to_rename, filters, comment):
  pagetitle = unicode(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")
  notes = []

  parsed = blib.parse(page)

  for t in parsed.filter_templates():
    origt = unicode(t)
    tn = tname(t)
    if tn == template:
      for filt in filters:
        m = re.search("^(.*)=(.*)$", filt)
        if m:
          if getparam(t, m.group(1)) != m.group(2):
            pagemsg("Skipping %s because filter %s doesn't match" %
              origt, filt)
          continue
        else:
          m = re.search("^(.*)~(.*)$", filt)
          if m:
            if not re.search(m.group(2), getparam(t, m.group(1))):
              pagemsg("Skipping %s because filter %s doesn't match" %
                origt, filt)
            continue
          else:
            raise ValueError("Unrecognized filter %s" % filt)
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
      if new_name:
        blib.set_template_name(t, new_name)
        notes.append("rename {{%s}} to {{%s}}" % (template, new_name))

    if unicode(t) != origt:
      pagemsg("Replaced <%s> with <%s>" % (origt, unicode(t)))

  return unicode(parsed), comment or notes

pa = blib.create_argparser("Rewrite templates, possibly renaming params or the template itself, or removing params",
  include_pagefile=True)
pa.add_argument("-t", "--template", help="Name of template", required=True)
pa.add_argument("-n", "--new-name", help="New name of template")
pa.add_argument("-r", "--remove", help="Param to remove, can be specified multiple times",
    action="append")
pa.add_argument("--from", help="Old name of param, can be specified multiple times",
    metavar="FROM", dest="from_", action="append")
pa.add_argument("--to", help="New name of param, can be specified multiple times",
    action="append")
pa.add_argument("--add", help="PARAM=VALUE to add, can be specified multiple times",
    action="append")
pa.add_argument("--filter", help="Only take action on templates matching the filter, which should be either PARAM=VALUE meaning the parameter must have the given value, or PARAM~REGEXP meaning the parameter must match the given regular expression (unanchored). Can be specified multiple times and all must match.",
    action="append")
pa.add_argument("-c", "--comment", help="Comment to use in place of auto-generated ones.")
args = pa.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

template = args.template.decode("utf-8")
new_name = args.new_name and args.new_name.decode("utf-8")
from_ = [x.decode("utf-8") for x in args.from_] if args.from_ else []
to = [x.decode("utf-8") for x in args.to] if args.to else []
addspecs = [x.decode("utf-8") for x in args.add] if args.add else []
params_to_add = []
for spec in addspecs:
  specparts = spec.split("=")
  if len(specparts) != 2:
    raise ValueError("Value %s to --add must have the form PARAM=VALUE" % spec)
  params_to_add.append(specparts)
params_to_remove = [x.decode("utf-8") for x in args.remove] if args.remove else []
filters = [x.decode("utf-8") for x in args.filter] if args.filter else []
comment = args.comment and args.comment.decode("utf-8")

if len(from_) != len(to):
  raise ValueError("Same number of --from and --to arguments must be specified")

params_to_rename = zip(from_, to)

def do_process_page(page, index, parsed):
  return process_page(index, page, template, new_name, params_to_add, params_to_remove,
    params_to_rename, filters, comment)

blib.do_pagefile_cats_refs(args, start, end, do_process_page, edit=True,
  default_refs=["Template:%s" % template])
