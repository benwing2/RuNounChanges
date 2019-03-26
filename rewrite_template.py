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

def rewrite_pages(template, new_name, params_to_remove, params_to_rename,
    startFrom, upTo, save, verbose):
  def process_page(page, index, parsed):
    pagetitle = unicode(page.title())
    def pagemsg(txt):
      msg("Page %s %s: %s" % (index, pagetitle, txt))

    pagemsg("Processing")
    notes = []

    for t in parsed.filter_templates():
      origt = unicode(t)
      tn = tname(t)
      if tn == template:
        for old_param, new_param in params_to_rename:
          if t.has(old_param):
            t.add(new_param, getparam(t, old_param), before=old_param)
            rmparam(t, old_param)
            notes.append("rename %s= to %s= in {{%s}}" % (old_param, new_param, tn))
        for param in params_to_remove:
          if t.has(param):
            rmparam(t, param)
            notes.append("remove %s= from {{%s}}" % (param, tn))
        if new_name:
          blib.set_template_name(t, new_name)
          notes.append("rename {{%s}} to {{%s}}" % (template, new_name))

      if unicode(t) != origt:
        pagemsg("Replaced <%s> with <%s>" % (origt, unicode(t)))

    return unicode(parsed), notes

  for index, page in blib.references("Template:%s" % template, startFrom, upTo):
    blib.do_edit(page, index, process_page, save=args.save, verbose=args.verbose)

pa = blib.init_argparser("Rewrite templates, possibly renaming params or the template itself, or removing params")
pa.add_argument("-t", "--template", help="Name of template", required=True)
pa.add_argument("-n", "--new-name", help="New name of template")
pa.add_argument("-r", "--remove", help="Param to remove, can be specified multiple times",
    action="append")
pa.add_argument("--from", help="Old name of param, can be specified multiple times",
    metavar="FROM", dest="from_", action="append")
pa.add_argument("--to", help="New name of param, can be specified multiple times",
    action="append")
args = pa.parse_args()
startFrom, upTo = blib.parse_start_end(args.start, args.end)

template = args.template.decode("utf-8")
new_name = args.new_name and args.new_name.decode("utf-8")
from_ = [x.decode("utf-8") for x in args.from_] if args.from_ else []
to = [x.decode("utf-8") for x in args.to] if args.to else []
params_to_remove = [x.decode("utf-8") for x in args.remove] if args.remove else []

if len(from_) != len(to):
  raise ValueError("Same number of --from and --to arguments must be specified")

params_to_rename = zip(from_, to)

rewrite_pages(template, new_name, params_to_remove, params_to_rename, 
    startFrom, upTo, args.save, args.verbose)
