#!/usr/bin/env python3
# -*- coding: utf-8 -*-

# Convert la-noun old form (specifying nominative, genitive, gender and
# declension) to new form (same as la-ndecl).

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

noun_decl_to_decl_type = {
  "first": "1",
  "second": "2",
  "third": "3",
  "fourth": "4",
  "fifth": "5",
  "irregular": "irreg",
}

def new_generate_noun_forms(template, errandpagemsg, expand_text, return_raw=False,
    include_props=False):
  assert template.startswith("{{la-ndecl|")
  if include_props:
    generate_template = re.sub(r"^\{\{la-ndecl\|", "{{User:Benwing2/la-new-generate-noun-props|",
        template)
  else:
    generate_template = re.sub(r"^\{\{la-ndecl\|", "{{User:Benwing2/la-new-generate-noun-forms|",
        template)
  result = expand_text(generate_template)
  if return_raw:
    return None if result is False else result
  if not result:
    errandpagemsg("WARNING: Error generating forms, skipping")
    return None
  return blib.split_generate_args(result)

def compare_headword_decl_forms(id_slot, headword_forms, decl_slots, noun_props,
    headword_and_decl_text, pagemsg, adjust_for_missing_gen_forms=False,
    adjust_for_e_ae_gen=False, remove_headword_links=False):
  decl_forms = ""
  for slot in decl_slots:
    if slot in noun_props:
      decl_forms = noun_props[slot]
      break
  decl_forms = safe_split(decl_forms, ",")
  if remove_headword_links:
    headword_forms = [blib.remove_links(x) for x in headword_forms]
  corrected_headword_forms = [lengthen_ns_nf(x) for x in headword_forms]
  corrected_decl_forms = [lengthen_ns_nf(x) for x in decl_forms]
  if adjust_for_e_ae_gen:
    corrected_headword_forms = [re.sub(u"ē$", "ae", x) for x in headword_forms]
  if adjust_for_missing_gen_forms:
    # Nouns in -ius and -ium are commonly missing the shortened genitive
    # variants. Don't get tripped up by that.
    ii_decl_forms = [x for x in corrected_decl_forms if x.endswith(u"iī")]
    for ii_decl_form in ii_decl_forms:
      i_decl_form = re.sub(u"iī$", u"ī", ii_decl_form)
      if i_decl_form in corrected_decl_forms and i_decl_form not in corrected_headword_forms:
        corrected_headword_forms.append(i_decl_form)
  if set(corrected_headword_forms) != set(corrected_decl_forms):
    macronless_headword_forms = set(lalib.remove_macrons(x) for x in corrected_headword_forms)
    macronless_decl_forms = set(lalib.remove_macrons(x) for x in corrected_decl_forms)
    if macronless_headword_forms == macronless_decl_forms:
      pagemsg("WARNING: Headword %s=%s different from decl %s=%s in macrons only, skipping: %s" % (
        id_slot, ",".join(headword_forms), id_slot, ",".join(decl_forms),
        headword_and_decl_text
      ))
    else:
      pagemsg("WARNING: Headword %s=%s different from decl %s=%s in more than just macrons, skipping: %s" % (
        id_slot, ",".join(headword_forms), id_slot, ",".join(decl_forms),
        headword_and_decl_text
      ))
    return False
  return True

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
    la_noun_template = None
    la_ndecl_template = None
    must_continue = False
    for t in parsed.filter_templates():
      tn = tname(t)
      if tn == "la-ndecl":
        if la_ndecl_template:
          pagemsg("WARNING: Saw multiple noun declension templates in subsection, %s and %s, skipping" % (
            str(la_ndecl_template), str(t)))
          must_continue = True
          break
        la_ndecl_template = t
        saw_a_template = True
      if tn in ["la-noun", "la-proper noun", "la-location"] or (
        tn == "head" and getparam(t, "1") == "la" and getparam(t, "2") in ["noun", "proper noun"]
      ):
        if la_noun_template:
          pagemsg("WARNING: Saw multiple noun headword templates in subsection, %s and %s, skipping" % (
            str(la_noun_template), str(t)))
          must_continue = True
          break
        la_noun_template = t
        saw_a_template = True
    if must_continue:
      continue
    if not la_noun_template and not la_ndecl_template:
      continue
    new_style_headword_template = (
      la_noun_template and
      tname(la_noun_template) in ["la-noun", "la-proper noun"] and
      not getparam(la_noun_template, "head2") and
      not getparam(la_noun_template, "2") and
      not getparam(la_noun_template, "3") and
      not getparam(la_noun_template, "4") and
      not getparam(la_noun_template, "decl")
    )
    if la_noun_template and not la_ndecl_template:
      if (tname(la_noun_template) in ["la-noun", "la-proper noun"] and
          getparam(la_noun_template, "indecl")):
        if new_style_headword_template:
          pagemsg("Found new-style indeclinable noun headword template, skipping: %s" %
            str(la_noun_template))
          continue
        if (getparam(la_noun_template, "head2") or
            getparam(la_noun_template, "decl") or
            getparam(la_noun_template, "2") and
            getparam(la_noun_template, "2") != getparam(la_noun_template, "1") or
            not getparam(la_noun_template, "3")):
          pagemsg("WARNING: Found old-style indeclinable noun headword template and don't know how to convert: %s" %
              str(la_noun_template))
          continue
        gender = getparam(la_noun_template, "3")
        orig_la_noun_template = str(la_noun_template)
        la_noun_template.add("g", gender[0], before="3")
        rmparam(la_noun_template, "3")
        rmparam(la_noun_template, "2")
        pagemsg("Replaced %s with %s" % (orig_la_noun_template, str(la_noun_template)))
        notes.append("convert indeclinable {{la-noun}}/{{la-proper noun}} template to new style")
        subsections[k] = str(parsed)
        continue
      else:
        pagemsg("WARNING: Saw noun headword template but no declension template: %s" % str(la_noun_template))
        continue
    if la_ndecl_template and not la_noun_template:
      pagemsg("WARNING: Saw noun declension template but no headword template: %s" % str(la_ndecl_template))
      continue

    orig_la_noun_template = str(la_noun_template)
    if new_style_headword_template:
      pagemsg("Found new-style noun headword template, skipping: %s" %
        orig_la_noun_template)
      continue

    def render_headword_and_decl():
      return "headword template <from> %s <to> %s <end>, declension template <from> %s <to> %s <end>" % (
        orig_la_noun_template, orig_la_noun_template,
        str(la_ndecl_template), str(la_ndecl_template)
      )

    if tname(la_noun_template) == "head":
      explicit_head_param_head = blib.fetch_param_chain(la_noun_template, ["head", "head1"], "head")
      lemma = explicit_head_param_head or [pagetitle]
    elif tname(la_noun_template) == "la-location":
      explicit_head_param_head = [getparam(la_noun_template, "1")]
    else:
      explicit_head_param_head = blib.fetch_param_chain(la_noun_template, ["1", "head", "head1"], "head")
    lemma = explicit_head_param_head or [pagetitle]
    if "[[" in lemma[0]:
      if len(lemma) > 1:
        pagemsg("WARNING: Multiple lemmas %s and lemmas with links in them, can't handle, skipping: %s" % (
          ",".join(lemma), render_headword_and_decl()
        ))
        continue
      ndecl_lemma = getparam(la_ndecl_template, "1")
      if "[[" not in ndecl_lemma:
        must_continue = False
        for m in re.finditer(r"(\[\[.*?\]\])", lemma[0]):
          link = m.group(1)
          plainlink = blib.remove_links(link)
          if plainlink not in ndecl_lemma:
            pagemsg("WARNING: Can't interpolate link %s into declension template, skipping: %s" % (
              link, render_headword_and_decl()))
            must_continue = True
            break
          ndecl_lemma = ndecl_lemma.replace(plainlink, link, 1)
        if must_continue:
          continue
        new_ndecl_template = blib.parse_text(str(la_ndecl_template)).filter_templates()[0]
        new_ndecl_template.add("1", ndecl_lemma)
        pagemsg("Adding links to decl template %s to produce %s" % (
          str(la_ndecl_template), str(new_ndecl_template)))
        la_ndecl_template = new_ndecl_template

    noun_props = new_generate_noun_forms(str(la_ndecl_template), errandpagemsg, expand_text, include_props=True)
    if noun_props is None:
      continue
    decl_gender = noun_props.get("g", None)

    if tname(la_noun_template) == "head":
      noun_gender = blib.fetch_param_chain(la_noun_template, ["g", "g1"], "g")
      if not noun_gender and not decl_gender:
        pagemsg("WARNING: No gender in {{head|la|...}} and no declension gender, can't proceed, skipping: %s" % render_headword_and_decl())
        continue
    elif tname(la_noun_template) == "la-location":
      noun_gender = [getparam(la_noun_template, "4")]
    else:
      noun_gender = blib.fetch_param_chain(la_noun_template, ["3", "g", "g1"], "g")
      if not noun_gender:
        pagemsg("WARNING: No gender in old-style headword, skipping: %s" % render_headword_and_decl())
        continue

    def do_compare_headword_decl_forms(id_slot, headword_forms, decl_slots,
        adjust_for_missing_gen_forms=False, remove_headword_links=False):
      return compare_headword_decl_forms(id_slot, headword_forms, decl_slots,
        noun_props, render_headword_and_decl(), pagemsg,
        adjust_for_missing_gen_forms=adjust_for_missing_gen_forms,
        remove_headword_links=remove_headword_links)

    def check_headword_vs_decl_decls(regularized_noun_decl):
      must_continue = False
      decl_lemma = getparam(la_ndecl_template, "1") 
      if "((" in decl_lemma:
        pagemsg("WARNING: (( in decl_lemma, can't handle, skipping: %s" %
            render_headword_and_decl())
        must_continue = True
        return
      segments = re.split(r"([^<> -]+<[^<>]*>)", decl_lemma)
      decl_decls = []
      for i in range(1, len(segments) - 1, 2):
        m = re.search("^([^<> -]+)<([^<>]*)>$", segments[i])
        stem_spec, decl_and_subtype_spec = m.groups()
        decl_and_subtypes = decl_and_subtype_spec.split(".")
        decl_decl = decl_and_subtypes[0]
        decl_decls.append(decl_decl)
      if set(regularized_noun_decl) != set(decl_decls):
        if set(regularized_noun_decl) <= set(decl_decls):
          pagemsg("headword decl %s subset of declension decl %s, allowing: %s" % (
            ",".join(regularized_noun_decl), ",".join(decl_decls),
            render_headword_and_decl()))
        else:
          pagemsg("WARNING: headword decl %s not same as or subset of declension decl %s, skipping: %s" % (
            ",".join(regularized_noun_decl), ",".join(decl_decls),
            render_headword_and_decl()))
          must_continue = True
      return must_continue

    def check_headword_vs_decl_gender():
      must_continue = False
      if len(noun_gender) == 1 and noun_gender[0] == decl_gender:
        need_explicit_gender = False
      else:
        need_explicit_gender = True
        if len(noun_gender) > 1:
          pagemsg("WARNING: Saw multiple headword genders %s, please verify: %s" % (
            ",".join(noun_gender), render_headword_and_decl()))
        elif (noun_gender and noun_gender[0].startswith("n") != (decl_gender == "n")):
          pagemsg("WARNING: Headword gender %s is neuter and decl gender %s isn't, or vice-versa, need to correct, skipping: %s" % (
          noun_gender[0], decl_gender, render_headword_and_decl()))
          must_continue = True
      return need_explicit_gender, must_continue

    def erase_and_copy_params_and_add_gender(need_explicit_gender, noun_gender):
      # Erase all params
      del la_noun_template.params[:]
      # Copy params from decl template
      for param in la_ndecl_template.params:
        pname = str(param.name)
        la_noun_template.add(pname, param.value, showkey=param.showkey, preserve_spacing=False)
      # Add explicit gender if needed
      if need_explicit_gender:
        explicit_genders = []
        for ng in noun_gender:
          ng = ng[0]
          if ng not in explicit_genders:
            explicit_genders.append(ng)
        blib.set_param_chain(la_noun_template, explicit_genders, "g", "g")

    if tname(la_noun_template) == "head":
      if explicit_head_param_head and not do_compare_headword_decl_forms("lemma", explicit_head_param_head, ["linked_nom_sg", "linked_nom_pl"]):
        continue
      need_explicit_gender, must_continue = check_headword_vs_decl_gender()
      if must_continue:
        continue

      # Check for extraneous {{head|la|...}} parameters
      must_continue = False
      is_proper_noun = getparam(la_ndecl_template, "2") == "proper noun"
      for param in la_noun_template.params:
        pname = str(param.name)
        if pname.strip() in ["1", "2"] or re.search("^(head|g)[0-9]*$", pname.strip()):
          continue
        pagemsg("WARNING: Saw extraneous param %s in {{head}} template, skipping: %s" % (
          pname, render_headword_and_decl()))
        must_continue = True
        break
      if must_continue:
        continue
      # Copy params from decl template
      blib.set_template_name(la_noun_template,
        "la-proper noun" if is_proper_noun else "la-noun")
      erase_and_copy_params_and_add_gender(need_explicit_gender, noun_gender)
      pagemsg("Replaced %s with %s" % (orig_la_noun_template, str(la_noun_template)))
      notes.append("convert {{head|la|...}} to new-style {{la-noun}}/{{la-proper noun}} template")

    elif tname(la_noun_template) == "la-location":
      noun_decl = [getparam(la_noun_template, "6")]
      if not noun_decl:
        pagemsg("WARNING: No noun decl in {{la-location}}, skipping: %s" % render_headword_and_decl())
        continue
      genitive = [getparam(la_noun_template, "2")]
      if not do_compare_headword_decl_forms("lemma", lemma, ["linked_nom_sg", "linked_nom_pl"]):
        continue
      if not do_compare_headword_decl_forms("genitive", genitive, ["gen_sg", "gen_pl"],
          adjust_for_missing_gen_forms=True, remove_headword_links=True):
        continue
      regularized_noun_decl = []
      must_continue = False
      for nd in noun_decl:
        if nd not in noun_decl_to_decl_type:
          pagemsg("WARNING: Unrecognized noun decl=%s, skipping: %s" % (
            nd, render_headword_and_decl()))
          must_continue = True
          break
        regularized_noun_decl.append(noun_decl_to_decl_type[nd])
      if must_continue:
        continue
      must_continue = check_headword_vs_decl_decls(regularized_noun_decl)
      if must_continue:
        continue
      need_explicit_gender, must_continue = check_headword_vs_decl_gender()
      if must_continue:
        continue

      # Check for extraneous {{la-location}} parameters
      must_continue = False
      for param in la_noun_template.params:
        pname = str(param.name)
        if pname.strip() in ["1", "2", "3", "4", "5", "6"]:
          continue
        pagemsg("WARNING: Saw extraneous param %s in {{la-location}} template, skipping: %s" % (
          pname, render_headword_and_decl()))
        must_continue = True
        break
      if must_continue:
        continue
      blib.set_template_name(la_noun_template, "la-proper noun")
      erase_and_copy_params_and_add_gender(need_explicit_gender, noun_gender)
      pagemsg("Replaced %s with %s" % (orig_la_noun_template, str(la_noun_template)))
      notes.append("convert {{la-location}} to new-style {{la-proper noun}} template")

    else:
      # old-style {{la-noun}} or {{la-proper noun}}
      noun_decl = blib.fetch_param_chain(la_noun_template, ["4", "decl", "decl1"], "decl")
      if not noun_decl:
        pagemsg("WARNING: No noun decl in old-style headword, skipping: %s" % render_headword_and_decl())
        continue
      genitive = blib.fetch_param_chain(la_noun_template, ["2", "gen", "gen1"], "gen")
      if not do_compare_headword_decl_forms("lemma", lemma, ["linked_nom_sg", "linked_nom_pl"]):
        continue
      if not do_compare_headword_decl_forms("genitive", genitive, ["gen_sg", "gen_pl"],
          adjust_for_missing_gen_forms=True, remove_headword_links=True):
        continue
      regularized_noun_decl = []
      must_continue = False
      for nd in noun_decl:
        if nd not in noun_decl_to_decl_type:
          pagemsg("WARNING: Unrecognized noun decl=%s, skipping: %s" % (
            nd, render_headword_and_decl()))
          must_continue = True
          break
        regularized_noun_decl.append(noun_decl_to_decl_type[nd])
      if must_continue:
        continue

      must_continue = check_headword_vs_decl_decls(regularized_noun_decl)
      if must_continue:
        continue
      need_explicit_gender, must_continue = check_headword_vs_decl_gender()
      if must_continue:
        continue

      # Fetch remaining params from headword template
      headword_params = []
      for param in la_noun_template.params:
        pname = str(param.name)
        if pname.strip() in ["1", "2", "3", "4"] or re.search("^(head|gen|g|decl)[0-9]*$", pname.strip()):
          continue
        headword_params.append((pname, param.value, param.showkey))
      erase_and_copy_params_and_add_gender(need_explicit_gender, noun_gender)
      # Copy remaining params from headword template
      for name, value, showkey in headword_params:
        la_noun_template.add(name, value, showkey=showkey, preserve_spacing=False)
      pagemsg("Replaced %s with %s" % (orig_la_noun_template, str(la_noun_template)))
      notes.append("convert {{la-noun}}/{{la-proper noun}} params to new style")

    subsections[k] = str(parsed)

  if not saw_a_template:
    pagemsg("WARNING: Saw no noun headword or declension templates")

  secbody = "".join(subsections)
  sections[j] = secbody + sectail
  return "".join(sections), notes

if __name__ == "__main__":
  parser = blib.create_argparser("Convert Latin noun headword templates to new form",
      include_pagefile=True)
  args = parser.parse_args()
  start, end = blib.parse_start_end(args.start, args.end)

  blib.do_pagefile_cats_refs(args, start, end, process_page,
    default_cats=["Latin nouns", "Latin proper nouns"], edit=True)
