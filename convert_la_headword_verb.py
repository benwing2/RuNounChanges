#!/usr/bin/env python3
# -*- coding: utf-8 -*-

# Convert la-verb old form (specifying all principal parts) to new form
# (same as la-conj).

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, errandmsg, site, tname

import lalib

def safe_split(text, delim):
  if not text:
    return []
  return text.split(delim)

def lengthen_ns_nf(text):
  text = re.sub("an([sf])", ur"ān\1", text)
  text = re.sub("en([sf])", ur"ēn\1", text)
  text = re.sub("in([sf])", ur"īn\1", text)
  text = re.sub("on([sf])", ur"ōn\1", text)
  text = re.sub("un([sf])", ur"ūn\1", text)
  text = re.sub("yn([sf])", ur"ȳn\1", text)
  text = re.sub("An([sf])", ur"Ān\1", text)
  text = re.sub("En([sf])", ur"Ēn\1", text)
  text = re.sub("In([sf])", ur"Īn\1", text)
  text = re.sub("On([sf])", ur"Ōn\1", text)
  text = re.sub("Un([sf])", ur"Ūn\1", text)
  text = re.sub("Yn([sf])", ur"Ȳn\1", text)
  return text

def new_generate_verb_forms(template, errandpagemsg, expand_text, return_raw=False,
    include_props=False):
  assert template.startswith("{{la-conj|")
  if include_props:
    generate_template = re.sub(r"^\{\{la-conj\|", "{{User:Benwing2/la-new-generate-verb-props|",
        template)
  else:
    generate_template = re.sub(r"^\{\{la-conj\|", "{{User:Benwing2/la-new-generate-verb-forms|",
        template)
  result = expand_text(generate_template)
  if return_raw:
    return None if result is False else result
  if not result:
    errandpagemsg("WARNING: Error generating forms, skipping")
    return None
  return blib.split_generate_args(result)

def process_page(page, index, parsed):
  global args
  pagetitle = str(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
  def errandpagemsg(txt):
    errandmsg("Page %s %s: %s" % (index, pagetitle, txt))
  def expand_text(tempcall):
    return blib.expand_text(tempcall, pagetitle, pagemsg, args.verbose)

  pagemsg("Processing")

  text = str(page.text)
  origtext = text

  notes = []

  retval = lalib.find_latin_section(text, pagemsg)
  if retval is None:
    return None, None

  sections, j, secbody, sectail, has_non_latin = retval

  subsections = re.split("(^===[^=]*===\n)", secbody, 0, re.M)

  saw_a_template = False

  for k in range(2, len(subsections), 2):
    parsed = blib.parse_text(subsections[k])
    la_verb_template = None
    la_conj_template = None
    must_continue = False
    for t in parsed.filter_templates():
      tn = tname(t)
      if tn == "la-conj":
        if la_conj_template:
          pagemsg("WARNING: Saw multiple verb conjugation templates in subsection, %s and %s, skipping" % (
            str(la_conj_template), str(t)))
          must_continue = True
          break
        la_conj_template = t
        saw_a_template = True
      if tn == "la-verb":
        if la_verb_template:
          pagemsg("WARNING: Saw multiple verb headword templates in subsection, %s and %s, skipping" % (
            str(la_verb_template), str(t)))
          must_continue = True
          break
        la_verb_template = t
        saw_a_template = True
    if must_continue:
      continue
    if not la_verb_template and not la_conj_template:
      continue
    if la_verb_template and not la_conj_template:
      pagemsg("WARNING: Saw verb headword template but no conjugation template: %s" % str(la_verb_template))
      continue
    if la_conj_template and not la_verb_template:
      pagemsg("WARNING: Saw verb conjugation template but no headword template: %s" % str(la_conj_template))
      continue

    orig_la_verb_template = str(la_verb_template)
    if re.search(r"^(irreg|[0-9]\+*)(\..*)?$", getparam(la_verb_template, "1")):
      pagemsg("Found new-style verb headword template, skipping: %s" %
        orig_la_verb_template)
      continue

    def render_headword_and_conj():
      return "headword template <from> %s <to> %s <end>, conjugation template <from> %s <to> %s <end>" % (
        orig_la_verb_template, orig_la_verb_template,
        str(la_conj_template), str(la_conj_template)
      )

    verb_props = new_generate_verb_forms(str(la_conj_template), errandpagemsg, expand_text, include_props=True)
    if verb_props is None:
      continue
    subtypes = [x.replace("-", "") for x in safe_split(verb_props["subtypes"], ".")]
    conj_type = verb_props["conj_type"]
    conj_subtype = verb_props.get("conj_subtype", None)

    def compare_headword_conj_forms(id_slot, headword_forms, conj_slots,
        adjust_for_missing_perf_forms=False, remove_conj_links=False):
      conj_forms = ""
      for slot in conj_slots:
        if slot in verb_props:
          conj_forms = verb_props[slot]
          break
      conj_forms = safe_split(conj_forms, ",")
      if remove_conj_links:
        conj_forms = [blib.remove_links(x) for x in conj_forms]
      corrected_headword_forms = [lengthen_ns_nf(x) for x in headword_forms]
      corrected_conj_forms = [lengthen_ns_nf(x) for x in conj_forms]
      if adjust_for_missing_perf_forms:
        # There are several instances of 4++ verbs where only the -īvī variant,
        # not the -iī variant, is listed in the headword. Don't get tripped up
        # by that.
        ivi_conj_forms = [x for x in corrected_conj_forms if x.endswith(u"īvī")]
        for ivi_conj_form in ivi_conj_forms:
          ii_conj_form = re.sub(u"īvī$", u"iī", ivi_conj_form)
          if ii_conj_form in corrected_conj_forms and ii_conj_form not in corrected_headword_forms:
            corrected_headword_forms.append(ii_conj_form)
      if set(corrected_headword_forms) != set(corrected_conj_forms):
        macronless_headword_forms = set(lalib.remove_macrons(x) for x in corrected_headword_forms)
        macronless_conj_forms = set(lalib.remove_macrons(x) for x in corrected_conj_forms)
        if macronless_headword_forms == macronless_conj_forms:
          pagemsg("WARNING: Headword %s=%s different from conj %s=%s in macrons only, skipping: %s" % (
            id_slot, ",".join(headword_forms), id_slot, ",".join(conj_forms),
            render_headword_and_conj()
          ))
        else:
          pagemsg("WARNING: Headword %s=%s different from conj %s=%s in more than just macrons, skipping: %s" % (
            id_slot, ",".join(headword_forms), id_slot, ",".join(conj_forms),
            render_headword_and_conj()
          ))
        return False
      return True

    verb_conj = getparam(la_verb_template, "conj") or getparam(la_verb_template, "c")
    pattern = getparam(la_verb_template, "pattern")
    lemma = blib.fetch_param_chain(la_verb_template, ["1", "head", "head1"], "head")
    inf = blib.fetch_param_chain(la_verb_template, ["2", "inf", "inf1"], "inf")
    perf = blib.fetch_param_chain(la_verb_template, ["3", "perf", "perf1"], "perf")
    sup = blib.fetch_param_chain(la_verb_template, ["4", "sup", "sup1"], "sup")
    # Hack to handle cases like abeō where the headword normally lists perfect
    # abiī but the conj lists abiī, abīvī.
    if verb_conj == "irreg" and len(lemma) > 0 and lemma[0].endswith(u"eō"):
      ivi = re.sub(u"eō$", u"īvī", lemma[0])
      if ivi not in perf:
        perf.append(ivi)
    if not compare_headword_conj_forms("lemma", lemma, ["1s_pres_actv_indc", "3s_pres_actv_indc", "1s_perf_actv_indc", "3s_perf_actv_indc"]):
      continue
    if "depon" in subtypes or "semidepon" in subtypes:
      if sup:
        pagemsg("WARNING: Saw supine in conjunction with deponent verb, skipping: %s" %
          render_headword_and_conj())
        continue
      sup = [re.sub("[sm]( (sum|est))?$", "m", x) for x in perf]
    else:
      if not compare_headword_conj_forms("perfect", perf, ["1s_perf_actv_indc", "3s_perf_actv_indc"],
          adjust_for_missing_perf_forms=True,
          # Remove links from perfect to handle cases like adsoleō where the
          # perfect is adsoluī,[[adsolitus]] [[sum]] and the headword says
          # adsoluī,adsolitus sum.
          remove_conj_links=True):
        continue
    if len(sup) > 0 and sup[0].endswith(u"ūrus"):
      if not compare_headword_conj_forms("future participle", sup, ["futr_actv_ptc"]):
        continue
      if "supfutractvonly" not in subtypes:
        if len(lemma) > 0 and lemma[0].endswith("sum"):
          pass
        else:
          pagemsg("WARNING: Expected supfutractvonly in subtypes=%s, skipping: %s" % (
            ".".join(sorted(subtypes)), render_headword_and_conj()
          ))
          continue
    else:
      if not compare_headword_conj_forms("supine", sup, ["sup_acc"]):
        continue
    if not verb_conj:
      pagemsg("WARNING: No conj in headword template: %s" % render_headword_and_conj())
    else:
      conj_type_to_verb_conj = {
        "1st": "1",
        "2nd": "2",
        "3rd": "3",
        "3rd-io": "io",
        "4th": "4",
        "irreg": "irreg",
      }
      if conj_type not in conj_type_to_verb_conj:
        pagemsg("WARNING: Something wrong, saw unrecognized conj_type=%s: %s" %
            (conj_type, render_headword_and_conj()))
        continue
      conj_type = conj_type_to_verb_conj[conj_type]
      if conj_subtype:
        if conj_subtype not in conj_type_to_verb_conj:
          pagemsg("WARNING: Something wrong, saw unrecognized conj_subtype=%s" %
              (conj_subtype, render_headword_and_conj()))
          continue
        conj_subtype = conj_type_to_verb_conj[conj_subtype]
      if verb_conj != conj_type and verb_conj != conj_subtype:
        pagemsg("WARNING: Conjugation template has conj=%s, subconj=%s but headword template has conj=%s, skipping: %s" % (
          conj_type, conj_subtype, verb_conj, render_headword_and_conj()
        ))
        continue
    pattern = pattern.replace("opt-semi-depon", "optsemidepon")
    pattern = pattern.replace("semi-depon", "semidepon")
    pattern = pattern.replace("pass-3only", "pass3only")
    pattern = pattern.replace("pass-impers", "passimpers")
    pattern = pattern.replace("no-actv-perf", "noactvperf")
    pattern = pattern.replace("no-pasv-perf", "nopasvperf")
    pattern = pattern.replace("perf-as-pres", "perfaspres")
    pattern = pattern.replace("short-imp", "shortimp")
    pattern = pattern.replace("sup-futr-actv-only", "supfutractvonly")
    pattern = safe_split(pattern, "-")
    pattern = [x for x in pattern if x not in ["noperf", "nosup", "irreg", "def", "facio", "shortimp", "depon"]]
    subtypes = [x for x in subtypes if x not in ["I", "noperf", "nosup", "irreg", "depon"]]
    if len(lemma) > 0 and lemma[0].endswith("sum"):
      # This is added automatically by [[sum]]
      subtypes = [x for x in subtypes if x != "supfutractvonly"]
    if set(pattern) != set(subtypes):
      if set(subtypes) >= set(pattern) and (
        set(subtypes) - set(pattern) <= {"nopass", "p3inf", "poetsyncperf", "optsyncperf", "alwayssyncperf"}
      ):
        pagemsg("Subtypes=%s of conjugation template have extra, ignorable subtypes %s compared with pattern=%s of headword template: %s" % (
          ".".join(sorted(subtypes)),
          ".".join(sorted(list(set(subtypes) - set(pattern)))),
          ".".join(sorted(pattern)), render_headword_and_conj()
        ))
      else:
        pagemsg("WARNING: Conjugation template has subtypes=%s but headword template has pattern=%s, skipping: %s" % (
          ".".join(sorted(subtypes)), ".".join(sorted(pattern)),
          render_headword_and_conj()
        ))
        continue

    # Fetch remaining params from headword template
    headword_params = []
    for param in la_verb_template.params:
      pname = str(param.name)
      if pname.strip() in ["1", "2", "3", "4", "44", "conj", "c", "pattern"] or re.search("^(head|inf|perf|sup)[0-9]*$", pname.strip()):
        continue
      headword_params.append((pname, param.value, param.showkey))
    # Erase all params
    del la_verb_template.params[:]
    # Copy params from conj template
    for param in la_conj_template.params:
      pname = str(param.name)
      la_verb_template.add(pname, param.value, showkey=param.showkey, preserve_spacing=False)
    # Copy remaining params from headword template
    for name, value, showkey in headword_params:
      la_verb_template.add(name, value, showkey=showkey, preserve_spacing=False)
    pagemsg("Replaced %s with %s" % (orig_la_verb_template, str(la_verb_template)))
    notes.append("convert {{la-verb}} params to new style")
    subsections[k] = str(parsed)

  if not saw_a_template:
    pagemsg("WARNING: Saw no verb headword or conjugation templates")

  secbody = "".join(subsections)
  sections[j] = secbody + sectail
  return "".join(sections), notes

parser = blib.create_argparser("Convert Latin verb headword templates to new form",
    include_pagefile=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_page,
  default_cats=["Latin verbs"], edit=True)
