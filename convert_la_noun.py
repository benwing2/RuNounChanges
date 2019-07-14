#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, getrmparam, tname, msg, errandmsg, site, bool_param_is_true

import lalib

def compare_new_and_old_templates(origt, newt, pagetitle, pagemsg, errandpagemsg):
  global args
  def expand_text(tempcall):
    return blib.expand_text(tempcall, pagetitle, pagemsg, args.verbose)

  if origt.startswith("{{la-decl-multi|"):
    old_generate_template = re.sub(r"^\{\{la-decl-multi\|", "{{la-generate-multi-forms|", origt)
    old_result = expand_text(old_generate_template)
    if not old_result:
      old_forms = None
    else:
      old_forms = blib.split_generate_args(old_result)
  else:
    old_forms = lalib.generate_noun_forms(origt, errandpagemsg, expand_text)
  if old_forms is None:
    errandpagemsg("WARNING: Error generating old forms, can't compare")
    return False
  new_generate_template = re.sub(r"^\{\{la-ndecl\|", "{{User:Benwing2/la-new-generate-noun-forms|", newt)
  new_result = expand_text(new_generate_template)
  if not new_result:
    errandpagemsg("WARNING: Error generating new forms, can't compare")
    return False
  new_forms = blib.split_generate_args(new_result)
  for form in set(old_forms.keys() + new_forms.keys()):
    if form not in new_forms:
      pagemsg("WARNING: form %s=%s in old forms but missing in new forms" % (
        form, old_forms[form]))
      return False
    if form not in old_forms:
      pagemsg("WARNING: form %s=%s in new forms but missing in old forms" % (
        form, new_forms[form]))
      return False
    if new_forms[form] != old_forms[form]:
      pagemsg("WARNING: form %s=%s in old forms but =%s in new forms" % (
        form, old_forms[form], new_forms[form]))
      return False
  pagemsg("%s and %s have same forms" % (origt, newt))
  return True

def compute_lemma_and_subtypes(decl, stem1, stem2, num, stem_suffix, pl_suffix,
    to_auto, pagemsg, origt):
  if type(to_auto) is not tuple:
    to_auto = to_auto(stem1, stem2, num)
  num_originally_pl = False
  if num == "pl" and pl_suffix:
    num_originally_pl = True
    lemma = stem1 + pl_suffix
    num = None
  else:
    lemma = stem1 + stem_suffix
  subtypes = []
  for subtype in to_auto:
    if subtype.startswith('-'):
      pagemsg("WARNING: Inferred canceling subtype %s, need to verify: %s" % (subtype, origt))
    subtypes.append(subtype)
  if re.search(u"^[A-ZĀĒĪŌŪȲĂĔĬŎŬ]", lemma):
    # Proper nouns in -polis that use {{la-decl-3rd-polis}} won't specify
    # num=sg because the declension template itself specifies num=sg when
    # invoking the module. Meanwhile the module itself specifies num=sg for
    # indeclinable nouns and certain irregular nouns. In all these cases,
    # we should not add .both.
    auto_sg = (
      decl == "3" and lemma.endswith("polis") and "-polis" not in subtypes or
      decl == "indecl" or
      decl == "irreg" and lemma in ["Deus", u"Iēsus", u"Jēsus", u"Callistō", u"Themistō"]
    )
    if not num and not num_originally_pl and not auto_sg:
      num = "both"
    elif num == "sg":
      num = None
  if num:
    subtypes.append(num)
  if stem2:
    if (decl == "3" and lalib.infer_3rd_decl_stem(lemma) == stem2 or
        decl == "2" and lemma == stem2):
      stem2 = ""
  return lemma, stem2, subtypes

def convert_la_decl_multi_to_new(t, pagetitle, pagemsg, errandpagemsg):
  global args
  def expand_text(tempcall):
    return blib.expand_text(tempcall, pagetitle, pagemsg, args.verbose)
  origt = unicode(t)
  segments = re.split(r"([^<> ]+<[^<>]*>)", getparam(t, "1"))
  g = getrmparam(t, "g")
  if not g:
    errandpagemsg("WARNING: No gender, can't handle adjectives yet")
    return None
  else:
    gender_map = {"m": "M", "f": "F", "n": "N"}
    if g not in gender_map:
      errandpagemsg("WARNING: Unrecognized gender g=%s" % g)
      return None
    g = gender_map[g]
  lig = getparam(t, "lig")
  um = getrmparam(t, "um")
  if um:
    um = um.split(",")
  else:
    um = []
  num = getrmparam(t, "num")
  for i in xrange(1, len(segments) - 1, 2):
    m = re.search("^([^<> ]+)<([^<>]*)>$", segments[i])
    stem_spec, decl_and_subtype_spec = m.groups()
    stems = stem_spec.split("/")
    if len(stems) == 1:
      stem1 = stems[0]
      stem2 = ""
    elif len(stems) == 2:
      stem1, stem2 = stems
    else:
      errandpagemsg("WARNING: Too many stems: %s" % origt)
      return None
    decl_and_subtypes = decl_and_subtype_spec.split(".")
    if len(decl_and_subtypes) == 1:
      decl = decl_and_subtypes[0]
      specified_subtypes = ()
    elif len(decl_and_subtypes) == 2:
      decl, specified_subtypes = decl_and_subtypes
      specified_subtypes = tuple(specified_subtypes.split("-"))
    else:
      errandpagemsg("WARNING: Too many subtypes: %s" % origt)
      return None
    if g == "N" and "N" not in specified_subtypes:
      specified_subtypes = ("N",) + specified_subtypes
    lookup_key = (decl, specified_subtypes)
    if lookup_key not in lalib.decl_and_subtype_to_props:
      errandpagemsg("WARNING: Lookup key %s not found: %s" % (
        lookup_key, origt))
      return None
    auto_num, stem_suffix, pl_suffix, to_auto = lalib.decl_and_subtype_to_props[lookup_key]
    lemma, stem2, subtypes = compute_lemma_and_subtypes(decl, stem1, stem2, num, stem_suffix, pl_suffix, to_auto, pagemsg, origt)
    base_and_detected_subtypes = expand_text("{{#invoke:User:Benwing2/la-noun|detect_subtype|%s|%s|%s|%s}}" % (lemma, stem2, decl, ".".join(subtypes)))
    base, detected_subtypes = base_and_detected_subtypes.split("|")
    detected_subtypes = detected_subtypes.split(".")
    if (g == "N" and ("M" in detected_subtypes or "F" in detected_subtypes or "N" not in detected_subtypes and "N" not in subtypes) or
        (g == "M" or g == "F") and ("N" in detected_subtypes)):
      errandpagemsg("WARNING: Incompatible gender specification: g=%s, subtypes=%s, detected_subtypes=%s: %s" % (
        g, ".".join(subtypes), ".".join(detected_subtypes), origt))
      return None
    if (g == "M" or g == "F") and g not in detected_subtypes:
      # Add the gender explicitly, and remove any -N specification, which
      # becomes redundant.
      subtypes = [g] + [x for x in subtypes if x != "-N"]
    loc = getrmparam(t, "loc")
    if bool_param_is_true(loc):
      subtypes.append("loc")
    if bool_param_is_true(lig):
      subtypes.append("lig")
    if str((i + 1) / 2) in um:
      subtypes.append("genplum")
    if stem2:
      lemma += "/" + stem2
    lemma += "<%s>" % ".".join([decl] + subtypes)
    segments[i] = lemma
  blib.set_template_name(t, "la-ndecl")
  t.add("1", "".join(segments))
  pagemsg("Replaced %s with %s" % (origt, unicode(t)))
  if compare_new_and_old_templates(origt, unicode(t), pagetitle, pagemsg, errandpagemsg):
    return t
  else:
    return None

def convert_template_to_new(t, pagetitle, pagemsg, errandpagemsg):
  origt = unicode(t)
  tn = tname(t)
  m = re.search(r"^la-decl-(.*)$", tn)
  if not m:
    pagemsg("WARNING: Something wrong, can't parse noun decl template name: %s" % tn)
    return None
  decl_suffix = m.group(1)
  if decl_suffix not in lalib.la_noun_decl_suffix_to_decltype:
    pagemsg("WARNING: Unrecognized noun decl template name: %s" % tn)
    return None
  retval = lalib.la_noun_decl_suffix_to_decltype[decl_suffix]
  if retval is None:
    pagemsg("WARNING: Unable to convert template: %s" % unicode(t))
    return None
  declspec, stem_suffix, pl_suffix, to_auto = retval
  if type(declspec) is tuple:
    declspec = declspec[0]
  stem1 = getparam(t, "1").strip()
  stem2 = getparam(t, "2").strip()
  num = getrmparam(t, "num")
  lemma, stem2, subtypes = compute_lemma_and_subtypes(declspec, stem1, stem2, num, stem_suffix, pl_suffix, to_auto, pagemsg, origt)
  loc = getrmparam(t, "loc")
  if bool_param_is_true(loc):
    subtypes.append("loc")
  lig = getrmparam(t, "lig")
  if bool_param_is_true(lig):
    subtypes.append("lig")
  um = getrmparam(t, "um")
  genplum = getrmparam(t, "genplum")
  if bool_param_is_true(um) or bool_param_is_true(genplum):
    subtypes.append("genplum")
  sufn = getrmparam(t, "n")
  if bool_param_is_true(sufn):
    subtypes.append("sufn")
  blib.set_template_name(t, "la-ndecl")
  # Fetch all params
  named_params = []
  for param in t.params:
    pname = unicode(param.name)
    if pname.strip() in ["1", "2", "noun"]:
      continue
    named_params.append((pname, param.value, param.showkey))
  # Erase all params
  del t.params[:]
  # Put back params
  if stem2:
    lemma += "/" + stem2
  lemma += "<%s>" % ".".join([declspec] + subtypes)
  t.add("1", lemma)
  for name, value, showkey in named_params:
    t.add(name, value, showkey=showkey, preserve_spacing=False)
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
    if tn == "la-decl-multi":
      if convert_la_decl_multi_to_new(t, pagetitle, pagemsg, errandpagemsg):
        notes.append("converted {{%s}} to {{la-ndecl}}" % tn)
      else:
        return None, None
    elif tn in lalib.la_noun_decl_templates:
      if convert_template_to_new(t, pagetitle, pagemsg, errandpagemsg):
        notes.append("converted {{%s}} to {{la-ndecl}}" % tn)
      else:
        return None, None

  return unicode(parsed), notes

parser = blib.create_argparser("Convert Latin noun decl templates to new form")
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
    cats = ["Latin nouns", "Latin proper nouns"]
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
