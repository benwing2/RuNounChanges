#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, getrmparam, tname, msg, errandmsg, site

# FIXME: Out of date script, not needed any more, might not still work.

def la_verb_1st_subtype(stem, arg2, arg3, arg4, types):
  depon = 'depon' in types or 'semidepon' in types or 'semi-depon' in types
  if 'impers' in types or '3only' in types:
    lemma = stem + (u"ātur" if 'depon' in types else "at")
  else:
    lemma = stem + ("or" if 'depon' in types else u"ō")
  if depon:
    perf_stem = None
    supine_stem = arg2
  else:
    perf_stem = arg2
    supine_stem = arg3
  if not perf_stem and not depon and 'noperf' not in types:
    perf_stem = stem + u"āv"
    arg2 = perf_stem
  if not supine_stem and ('nopass' not in types and 'noperf' not in types
      and 'nosup' not in types and 'no-pasv-perf' not in types and
      'nopasvperf' not in types and 'memini' not in types and
      'pass-3only' not in types and 'pass3only' not in types):
    supine_stem = stem + u"āt"
    if depon:
      arg2 = supine_stem
    else:
      arg3 = supine_stem
  types = [x for x in types if x != 'depon' and x != 'impers']
  if supine_stem == stem + u"āt" and (depon or perf_stem == stem + u"āv"):
    return "1+", lemma, None, None, types
  else:
    return "1", lemma, arg2, arg3, types

def la_verb_2nd_subtype(stem, arg2, arg3, arg4, types):
  depon = 'depon' in types or 'semidepon' in types or 'semi-depon' in types
  if 'impers' in types or '3only' in types:
    lemma = stem + (u"ētur" if 'depon' in types else "et")
  else:
    lemma = stem + ("eor" if 'depon' in types else u"eō")
  types = [x for x in types if x != 'depon' and x != 'impers']
  if ((depon and arg2 == stem + "it") or
      (not depon and arg2 == stem + "u" and arg3 == stem + "it")):
    return "2+", lemma, None, None, types
  else:
    return "2", lemma, arg2, arg3, types

def la_verb_3rd_subtype(stem, arg2, arg3, arg4, types):
  if 'impers' in types or '3only' in types:
    lemma = stem + ("itur" if 'depon' in types else "it")
  else:
    lemma = stem + ("or" if 'depon' in types else u"ō")
  if stem.endswith("i"):
    types = types + ["-I"]
  types = [x for x in types if x != 'depon' and x != 'impers']
  return "3", lemma, arg2, arg3, types

def la_verb_3rd_io_subtype(stem, arg2, arg3, arg4, types):
  if 'impers' in types or '3only' in types:
    lemma = stem + ("itur" if 'depon' in types else "it")
    types = types + ["I"]
  else:
    lemma = stem + ("ior" if 'depon' in types else u"iō")
  types = [x for x in types if x != 'depon' and x != 'impers']
  return "3", lemma, arg2, arg3, types

def la_verb_4th_subtype(stem, arg2, arg3, arg4, types):
  # For at least serviō and saeviō, the perfect is written
  # serv.īv and saev.īv, where the dot was a signal used in conjunction
  # with sync_perf=y or sync_perf=yn. We don't need it so remove it.
  arg2 = arg2 and arg2.replace(".", "") or ""
  arg3 = arg3 and arg3.replace(".", "") or ""
  depon = 'depon' in types or 'semidepon' in types or 'semi-depon' in types
  if 'impers' in types or '3only' in types:
    lemma = stem + (u"ītur" if 'depon' in types else "it")
  else:
    lemma = stem + ("ior" if 'depon' in types else u"iō")
  types = [x for x in types if x != 'depon' and x != 'impers']
  if ((depon and arg2 == stem + u"īt") or
      (not depon and arg2 == stem + u"īv" and arg3 == stem + u"īt")):
    return "4+", lemma, None, None, types
  else:
    return "4", lemma, arg2, arg3, types

irreg_verb_type_to_lemma = {
  'aio': u"āiō",
  'aiio': u"aiiō",
  'dico': u"dīcō",
  'duco': u"dūcō",
  'facio': u"faciō",
  'fio': u"fīō",
  'fero': u"ferō",
  'inquam': "inquam",
  'libet': "libet",
  'lubet': "lubet",
  'licet': "licet",
  'volo': u"volō",
  'malo': u"mālō",
  'nolo': u"nōlō",
  'possum': "possum",
  'piget': "piget",
  'coepi': u"coepī",
  'sum': "sum",
  'edo': u"edō",
  'do': u"dō",
  'eo': u"eō",
}

def la_verb_irreg_subtype(stem, arg2, arg3, arg4, types):
  lemma = arg2 + irreg_verb_type_to_lemma[stem]
  return "irreg", lemma, arg3, arg4, types

la_verb_conj_suffix_to_props = {
  '1st': la_verb_1st_subtype,
  '2nd': la_verb_2nd_subtype,
  '3rd': la_verb_3rd_subtype,
  '3rd-IO': la_verb_3rd_io_subtype,
  '4th': la_verb_4th_subtype,
  'irreg': la_verb_irreg_subtype,
}

def generate_old_verb_forms(template, errandpagemsg, expand_text, return_raw=False,
    include_linked=False, include_props=False):
  if template.startswith("{{la-conj|"):
    if include_props:
      generate_template = re.sub(r"^\{\{la-conj\|", "{{la-generate-verb-props|",
          template)
    else:
      generate_template = re.sub(r"^\{\{la-conj\|", "{{la-generate-verb-forms|",
          template)
  elif template.startswith("{{la-conj-3rd-IO|"):
    generate_template = re.sub(r"^\{\{la-conj-3rd-IO\|", "{{la-generate-verb-forms|conjtype=3rd-io|", template)
  else:
    generate_template = re.sub(r"^\{\{la-conj-(.*?)\|", r"{{la-generate-verb-forms|conjtype=\1|", template)
  if not generate_template.startswith("{{la-generate-verb-forms|"):
    errandpagemsg("Template %s not a recognized conjugation template" % template)
    return None
  result = expand_text(generate_template)
  if return_raw:
    return None if result is False else result
  if not result:
    errandpagemsg("WARNING: Error generating forms, skipping")
    return None
  args = blib.split_generate_args(result)
  if not include_linked:
    args = {k: v for k, v in args.iteritems() if not k.startswith("linked_")}
  return args

old_la_verb_conj_templates = {
  "la-conj-1st",
  "la-conj-2nd",
  "la-conj-3rd",
  "la-conj-3rd-IO",
  "la-conj-4th",
  "la-conj-irreg",
}

def compare_new_and_old_templates(origt, newt, pagetitle, pagemsg, errandpagemsg):
  global args
  def expand_text(tempcall):
    return blib.expand_text(tempcall, pagetitle, pagemsg, args.verbose)

  def generate_old_forms():
    return generate_old_verb_forms(origt, errandpagemsg, expand_text, return_raw=True)

  def generate_new_forms():
    new_generate_template = re.sub(r"^\{\{la-conj\|", "{{User:Benwing2/la-new-generate-verb-forms|", newt)
    new_result = expand_text(new_generate_template)
    if not new_result:
      return None
    return new_result

  return blib.compare_new_and_old_template_forms(origt, newt, generate_old_forms,
    generate_new_forms, pagemsg, errandpagemsg)

def convert_template_to_new(t, pagetitle, pagemsg, errandpagemsg):
  origt = str(t)
  tn = tname(t)
  m = re.search(r"^la-conj-(.*)$", tn)
  if not m:
    pagemsg("WARNING: Something wrong, can't parse verb conj template name: %s" % tn)
    return None
  conj_suffix = m.group(1)
  if conj_suffix not in la_verb_conj_suffix_to_props:
    pagemsg("WARNING: Unrecognized verb conj template name: %s" % tn)
    return None
  to_props = la_verb_conj_suffix_to_props[conj_suffix]
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
    pname = str(param.name)
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
  pagemsg("Replaced %s with %s" % (origt, str(t)))
  if compare_new_and_old_templates(origt, str(t), pagetitle, pagemsg, errandpagemsg):
    return t
  else:
    return None

def process_page(page, index, parsed):
  pagetitle = str(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
  def errandpagemsg(txt):
    errandmsg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  notes = []

  for t in parsed.filter_templates():
    tn = tname(t)
    if tn in old_la_verb_conj_templates:
      if convert_template_to_new(t, pagetitle, pagemsg, errandpagemsg):
        notes.append("converted {{%s}} to {{la-conj}}" % tn)
      else:
        return None, None

  return str(parsed), notes

parser = blib.create_argparser("Convert Latin verb conj templates to new form",
    include_pagefile=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_page,
  default_cats=["Latin verbs"], edit=True)
