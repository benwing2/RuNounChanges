#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys
from dataclasses import dataclass, field

import blib
from blib import getparam, rmparam, getrmparam, tname, pname, msg, errandmsg, site


@dataclass
class ArConjProperties:
  vform: str
  weakness: str = None
  rad1: str = None
  rad2: str = None
  rad3: str = None
  rad4: str = None
  past_vowel: str = None
  nonpast_vowel: str = None
  vns: list[str] = None
  vn_ids: list[str] = None
  passive: str = None
  variant: str = None
  noimp: bool = False
  intrans: bool = False

def extract_ar_verb_conj_properties(t, pagemsg):
  def getp(param):
    return getparam(t, param)
  vform = getp("1")
  if not vform:
    pagemsg("WARNING: No verb form specified: %s" % str(t))
    return None
  m = re.search("^(.+)-(.+)$", vform)
  if m:
    vform, weakness = m.groups()
  else:
    weakness = None
  props = ArConjProperties(vform, weakness)
  if vform == "I":
    props.past_vowel = getp("2") or None
    props.nonpast_vowel = getp("3") or None
    firstrad_ind = 4
  else:
    firstrad_ind = 2
  props.rad1 = getp(str(firstrad_ind)) or getp("I") or None
  props.rad2 = getp(str(firstrad_ind + 1)) or getp("II") or None
  props.rad3 = getp(str(firstrad_ind + 2)) or getp("III") or None
  if vform.endswith("q"):
    props.rad4 = getp(str(firstrad_ind + 3)) or getp("IV") or None
  vn = getp("vn")
  if vn:
    props.vns = re.split("[,،]", vn)
  else:
    props.vns = []
  props.vn_ids = [None] * len(props.vns)
  for i in range(0, len(props.vns)):
    props.vn_ids[i] = getp("vn-id%s" % (i + 1)) or None
  props.passive = getp("passive") or None
  props.variant = getp("variant") or None
  props.noimp = not not getp("noimp")
  props.intrans = not not getp("intrans")
  return props

def process_text_on_page(index, pagetitle, text):
  global args
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
  def errandpagemsg(txt):
    errandmsg("Page %s %s: %s" % (index, pagetitle, txt))
  def expand_text(tempcall):
    return blib.expand_text(tempcall, pagetitle, pagemsg, args.verbose)

  notes = []

  retval = blib.find_modifiable_lang_section(text, None if args.partial_page else "Arabic", pagemsg,
    force_final_nls=True)
  if retval is None:
    return
  sections, j, secbody, sectail, has_non_lang = retval

  subsections, subsections_by_header, subsection_headers, subsection_levels = blib.split_text_into_subsections(
      secbody, pagemsg)

  parsed_by_subsections = {}
  headts = None
  headts_formatted_subsection_header = None
  saw_headt = False

  def subsection_header_and_num(k):
    return subsections[k - 1].strip() if k > 0 else "FIRST SUBSECTION", k // 2
  def format_subsection_header_and_num(k):
    return "%s (#%s)" % subsection_header_and_num(k)

  for k in range(0, len(subsections), 2):
    parsed = blib.parse_text(subsections[k])
    parsed_by_subsections[k] = parsed
    this_headts = []
    this_conjts = []
    for t in parsed.filter_templates():
      tn = tname(t)
      origt = str(t)
      def getp(param):
        return getparam(t, param)
      if tn == "ar-verb":
        this_headts.append(t)
      elif tn == "ar-conj":
        this_conjts.append(t)
    if this_headts and this_conjts:
      pagemsg("WARNING: Saw both {{ar-verb}} and {{ar-conj}} templates in the same subsection %s" %
              format_subsection_header_and_num(k))
      continue
    if this_headts:
      if headts:
        pagemsg("WARNING: Saw successive {{ar-verb}} templates without corresponding {{ar-conj}} template(s) in subsection %s and %s" % (
          headts_formatted_subsection_header, format_subsection_header_and_num(k)))
      headts = this_headts
      headts_formatted_subsection_header = format_subsection_header_and_num(k)
    elif this_conjts:
      if not headts:
        pagemsg("WARNING: Saw {{ar-conj}} template(s) without corresponding {{ar-verb}} template(s) in subsection %s" % (
          format_subsection_header_and_num(k)))
        continue
      if len(headts) != len(this_conjts):
        pagemsg("WARNING: Saw %s {{ar-verb}} template(s) in subsection %s but %s corresponding {{ar-conj}} template(s) in subsection %s, can't handle" % (
          len(headts), headts_formatted_subsection_header, len(this_conjts), format_subsection_header_and_num(k)))
        heads = None
        continue
      for headt, conjt in zip(headts, this_conjts):
        headt_props = extract_ar_verb_conj_properties(headt, pagemsg)
        conjt_props = extract_ar_verb_conj_properties(conjt, pagemsg)
        if headt_props is None or conjt_props is None:
          continue
        if headt_props.passive is None:
          headt_props.passive = conjt_props.passive
        if not headt_props.vns:
          headt_props.vns = conjt_props.vns
          headt_props.vn_ids = conjt_props.vn_ids
        headt_props.intrans = headt_props.intrans or conjt_props.intrans
        headt_props.noimp = headt_props.noimp or conjt_props.noimp
        for radprop in ["rad1", "rad2", "rad3", "rad4"]:
          if getattr(conjt_props, radprop) is None:
            setattr(conjt_props, radprop, getattr(headt_props, radprop))
          elif getattr(headt_props, radprop) is None:
            setattr(headt_props, radprop, getattr(conjt_props, radprop))
        propvals = ["vform", "weakness", "rad1", "rad2", "rad3", "rad4", "past_vowel", "nonpast_vowel", "vns",
                    "vn_ids", "passive", "variant", "noimp", "intrans"]
        for propval in propvals:
          headval = getattr(headt_props, propval)
          conjval = getattr(conjt_props, propval)
          if headval != conjval:
            pagemsg("WARNING: Headword template %s differs from conjugation template %s in property %s (headword %s, conjugation %s)" % (
              str(headt), str(conjt), propval, headval, conjval))
            break
        else: # no break
          rad1 = conjt_props.rad1
          rad2 = conjt_props.rad2
          rad3 = conjt_props.rad3
          rad4 = conjt_props.rad4
          passive = None
          passive_uncertain = False
          past_vowels = (conjt_props.past_vowel or "-").split(",")
          nonpast_vowels = (conjt_props.nonpast_vowel or "-").split(",")
          if conjt_props.passive:
            passive = conjt_props.passive
            if passive.endswith("?"):
              passive_uncertain = True
              passive = passive[:-1]
            if passive == "impers":
              passive = "ipass"
            elif passive == "only":
              passive = "onlypass"
            elif passive == "only-impers":
              passive = "onlypass-impers"
            elif passive.lower() in ["y", "yes", "t", "true", "1", "on"]:
              passive = "pass"
            elif passive.lower() in ["n", "no", "f", "false", "0", "off"]:
              passive = "nopass"
            else:
              pagemsg("WARNING: Unparsable value for passive '%s': %s" % (conjt_props.passive, str(conjt)))
              continue
          ir1 = set()
          ir2 = set()
          ir3 = set()
          ir4 = set()
          if rad1 or rad2 or rad3 or rad4:
            must_continue = False
            for past_vowel in past_vowels:
              for nonpast_vowel in nonpast_vowels:
                tempcall = "{{#invoke:User:Benwing2/ar-verb|infer_radicals_json|headword=%s|vform=%s|passive=%s|past_vowel=%s|nonpast_vowel=%s|is_reduced=%s}}" % (
                  pagetitle, conjt_props.vform, passive or "", past_vowel, nonpast_vowel, "")
                ret = expand_text(tempcall)
                if not ret:
                  must_continue = True
                  break
                ret = json.loads(ret)
                ...
              if must_continue:
                break
            if must_continue:
              continue

          pagemsg("Would convert headword template %s and conjugation template %s to new format" % (
            str(headt), str(conjt)))
      headts = None

  secbody_parts = []
  for k in range(len(subsections)):
    if k % 2 == 0:
      secbody_parts.append(str(parsed_by_subsections[k]))
    else:
      secbody_parts.append(subsections[k])
  secbody = "".join(secbody_parts)
  sections[j] = secbody.rstrip("\n") + sectail
  text = "".join(sections)
  return text, notes

parser = blib.create_argparser("Convert Arabic verb headword and conj templates to new form",
    include_pagefile=True, include_stdin=True)
parser.add_argument("--partial-page", action="store_true", help="Input was generated with 'find_regex.py --lang Arabic' and has no ==Arabic== header.")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page,
  default_cats=["Arabic verbs"], edit=True, stdin=True)
