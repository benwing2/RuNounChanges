#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, getrmparam, tname, msg, errandmsg, site

import lalib

def compare_new_and_old_templates(origt, newt, pagetitle, pagemsg, errandpagemsg):
  global args
  def expand_text(tempcall):
    return blib.expand_text(tempcall, pagetitle, pagemsg, args.verbose)

  def generate_old_forms():
    return lalib.generate_verb_forms(origt, errandpagemsg, expand_text, return_raw=True)

  def generate_new_forms():
    new_generate_template = re.sub(r"^\{\{la-conj\|", "{{User:Benwing2/la-new-generate-verb-forms|", newt)
    new_result = expand_text(new_generate_template)
    if not new_result:
      return None
    return new_result

  return blib.compare_new_and_old_template_forms(origt, newt, generate_old_forms,
    generate_new_forms, pagemsg, errandpagemsg)

def convert_template_to_new(t, pagetitle, pagemsg, errandpagemsg):
  origt = unicode(t)
  tn = tname(t)
  m = re.search(r"^la-conj-(.*)$", tn)
  if not m:
    pagemsg("WARNING: Something wrong, can't parse verb conj template name: %s" % tn)
    return None
  conj_suffix = m.group(1)
  if conj_suffix not in lalib.la_verb_conj_suffix_to_props:
    pagemsg("WARNING: Unrecognized verb conj template name: %s" % tn)
    return None
  to_props = lalib.la_verb_conj_suffix_to_props[conj_suffix]
  stem = getparam(t, "1").strip()
  arg2 = getparam(t, "2").strip()
  arg3 = getparam(t, "3").strip()
  arg4 = getparam(t, "4").strip()
  types = getparam(t, "type").strip()
  if not types:
    types = []
    depon = False
  else:
    types = re.split("(opt-semi-depon|semi-depon|pass-3only|pass-impers|no-actv-perf|no-pasv-perf|perf-as-pres|short-imp|sup-futr-actv-only|[a-z0-9]+)", types)
    types = [x for i, x in enumerate(types) if i % 2 == 1]
    depon = "depon" in types or "semidepon" in types or "semi-depon" in types
  conj, lemma, arg3, arg4, types = to_props(stem, arg2, arg3, arg4, types)
  if conj != "irreg":
    if "noperf" in types and not depon:
      if arg3:
        pagemsg("WARNING: Perfect %s specified along with noperf: %s" % (
          arg3, origt))
        arg3 = ""
    if "nosup" in types:
      if depon:
        if arg3:
          pagemsg("WARNING: Supine %s specified along with nosup: %s" % (
            arg3, origt))
          arg3 = ""
      else:
        if arg4:
          pagemsg("WARNING: Supine %s specified along with nosup: %s" % (
            arg4, origt))
          arg4 = ""
    if not conj.endswith("+"):
      if depon:
        if not arg3:
          types = [x for x in types if x != "noperf" and x != "nosup"]
      else:
        if not arg3:
          types = [x for x in types if x != "noperf"]
        if not arg4:
          types = [x for x in types if x != "nosup"]
  p3inf = getrmparam(t, "p3inf")
  if p3inf == "1":
    types = types + ["p3inf"]
  elif p3inf:
    pagemsg("WARNING: Unrecognized value for p3inf=%s" % p3inf)
  sync_perf = getrmparam(t, "sync_perf")
  if sync_perf == "poet":
    types = types + ["poet-sync-perf"]
  elif sync_perf == "y":
    types = types + ["always-sync-perf"]
  elif sync_perf == "yn":
    types = types + ["opt-sync-perf"]
  elif sync_perf:
    pagemsg("WARNING: Unrecognized value for sync_perf=%s" % sync_perf)
  # Fetch all params
  named_params = []
  for param in t.params:
    pname = unicode(param.name)
    if pname.strip() in ["1", "2", "3", "4", "type"]:
      continue
    named_params.append((pname, param.value, param.showkey))
  # Erase all params
  del t.params[:]
  # Put back params
  conj = ".".join([conj] + types)
  t.add("1", conj)
  t.add("2", lemma)
  if not arg3 and arg4:
    t.add("3", "")
    t.add("4", arg4)
  elif arg3 and not arg4:
    t.add("3", arg3)
  elif arg3 and arg4:
    t.add("3", arg3)
    t.add("4", arg4)
  for name, value, showkey in named_params:
    t.add(name, value, showkey=showkey, preserve_spacing=False)
  blib.set_template_name(t, "la-conj")
  pagemsg("Replaced %s with %s" % (origt, unicode(t)))
  if compare_new_and_old_templates(origt, unicode(t), pagetitle, pagemsg, errandpagemsg):
    return t
  else:
    return None

def process_page(page, index, parsed):
  pagetitle = unicode(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
  def errandpagemsg(txt):
    errandmsg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  notes = []

  for t in parsed.filter_templates():
    tn = tname(t)
    if tn in lalib.la_verb_conj_templates:
      if convert_template_to_new(t, pagetitle, pagemsg, errandpagemsg):
        notes.append("converted {{%s}} to {{la-conj}}" % tn)
      else:
        return None, None

  return unicode(parsed), notes

parser = blib.create_argparser("Convert Latin verb conj templates to new form")
parser.add_argument("--pagefile", help="List of pages to process.")
parser.add_argument("--cats", help="List of categories to process.")
parser.add_argument("--refs", help="List of references to process.")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

if args.pagefile:
  pages = [x.rstrip('\n') for x in codecs.open(args.pagefile, "r", "utf-8")]
  for i, page in blib.iter_items(pages, start, end):
    blib.do_edit(pywikibot.Page(site, page), i, process_page, save=args.save,
        verbose=args.verbose, diff=args.diff)
else:
  if not args.cats and not args.refs:
    cats = ["Latin verbs"]
    refs = []
  else:
    cats = args.cats and [x.decode("utf-8") for x in args.cats.split(",")] or []
    refs = args.refs and [x.decode("utf-8") for x in args.refs.split(",")] or []

  for cat in cats:
    for i, page in blib.cat_articles(cat, start, end):
      blib.do_edit(page, i, process_page, save=args.save, verbose=args.verbose)
  for ref in refs:
    for i, page in blib.references(ref, start, end):
      blib.do_edit(page, i, process_page, save=args.save, verbose=args.verbose)
