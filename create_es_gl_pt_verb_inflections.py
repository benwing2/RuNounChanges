#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse, json, unicodedata
from collections import defaultdict

import blib
from blib import getparam, rmparam, msg, errandmsg, site, tname, pname

lang_to_name = {
  "es": "Spanish",
  "gl": "Galician",
  "pt": "Portuguese",
}

norm_to_name = {
  "es": "Spanish",
  "gl": "Galician",
  "gl-reinteg": "Galician (reintegrationist)",
  "pt": "Portuguese",
}

norm_to_lang = {
  "es": "es",
  "gl": "gl",
  "gl-reinteg": "gl",
  "pt": "pt",
}

def escape_newlines(text):
  return text.replace("\n", r"\n")

def parse_inf_and_conj(arg1):
  m = re.search("^([^<>]+)(<[^<>]*>)$", arg1)
  if m:
    return m.groups()
  elif "<" not in arg1:
    return arg1, ""
  else:
    return None, None

def process_text_on_inflection_page(index, pagetitle, pagetext, norm, pos, lemma, infl, slot):
  normname = norm_to_name[norm]
  lang = norm_to_lang[norm]
  langname = lang_to_name[lang]

  if pos == "verb":
    headword_pos = "verb form"
    header_pos = "Verb"
    expected_header_poses = ["Verb"]
    expected_headword_templates = [("head", lang, "verb form")]
    new_headword_template = "{{head|%s|%s}}" % (lang, headword_pos)
    new_defn_template_name = "%s-verb form of" % norm
    new_defn_template = "{{%s|%s}}" % (new_defn_template_name, infl)
    if norm in ["gl", "gl-reinteg"]:
      expected_defn_templates = ["gl-verb form of", "gl-reinteg-verb form of"]
    else:
      expected_defn_templates = ["%s-verb form of" % norm]
  elif pos == "gerund":
    headword_pos = "gerund"
    header_pos = "Verb"
    expected_header_poses = ["Verb"]
    expected_headword_templates = [("head", lang, "gerund"), ("head", lang, "verb form")]
    new_headword_template = "{{head|%s|%s}}" % (lang, headword_pos)
    new_defn_template_name = "%s-verb form of" % norm
    new_defn_template = "{{%s|%s}}" % (new_defn_template_name, infl)
    if norm in ["gl", "gl-reinteg"]:
      expected_defn_templates = ["gl-verb form of", "gl-reinteg-verb form of", ("gerund of", lang)]
    else:
      expected_defn_templates = ["%s-verb form of" % norm, ("gerund of", lang)]
  elif pos == "participle":
    headword_pos = "participle"
    header_pos = "Participle"
    expected_header_poses = ["Participle", "Verb"]
    past_participle_template = "es-past participle" if norm == "es" else "%s-pp" % lang
    expected_headword_templates = [("head", lang, "verb form"), ("head", lang, "participle"), past_participle_template]
    new_headword_template = "{{%s}}" % past_participle_template
    new_defn_template_name = "past participle of"
    new_defn_template = "{{%s|%s|%s}}" % (new_defn_template_name, lang, lemma)
    expected_defn_templates = [("past participle of", lang), "%s-verb form of" % norm]
  else:
    assert False, "Unrecognized pos=%s" % pos

  notes = []

  def pagemsg(txt, fn=msg):
    fn("Page %s %s: %s %s %s of %s: %s" % (index, pagetitle, normname, headword_pos, slot, infl, txt))

  def match_template(t, specs):
    tn = tname(t)
    for spec in specs:
      if type(spec) is str:
        if tn == spec:
          return True
      else:
        assert type(spec) in [tuple, list]
        if tn == spec[0]:
          for argnum, argval in enumerate(spec[1:]):
            if getparam(t, str(argnum + 1)) != argval:
              break
          else: # no break
            return True
    return False

  newposbody = """%s

# %s

""" % (new_headword_template, new_defn_template)
  newpos = "===%s===\n" % header_pos + newposbody
  newposl4 = "====%s====\n" % header_pos + newposbody
  newsection = "==%s==\n\n" % langname + newpos
  infl_part = "with infl '%s'" % infl
  infl_inf, infl_conj = parse_inf_and_conj(infl)
  if infl_inf is None:
    pagemsg("WARNING: Can't parse out infinitive from conjugation '%s'" % infl)
    marked_up_infl = infl
  else:
    marked_up_infl = "[[%s]]%s" % (infl_inf, infl_conj)
  note_part = "with %s %s entry of %s" % (normname, headword_pos, marked_up_infl)

  if not pagetext:
    pagemsg("Creating new page %s" % infl_part)
    notes.append("create new page %s" % note_part)
    return newsection, notes

  # Pass None for pagemsg to suppress warning on lang section not found.
  retval = blib.find_modifiable_lang_section(pagetext, langname, None, force_final_nls=True)
  if retval is None:
    sections, sections_by_lang, section_langs = blib.split_text_into_sections(pagetext, pagemsg)
    normalized_langname = langname.lower()
    for j, seclangname in section_langs:
      normalized_seclangname = re.sub("[\u0300-\u036F]", "", unicodedata.normalize("NFD", seclangname)).lower()
      if normalized_seclangname > normalized_langname:
        sections[j - 1:j - 1] = [newsection]
        pagemsg("Inserting lang section %s before %s entry" % (infl_part, seclangname))
        notes.append("insert lang section %s before %s entry" % (note_part, seclangname))
        return "".join(sections), notes
    sections.append("\n\n" + newsection)
    pagemsg("Appending lang section %s at end of page" % infl_part)
    notes.append("append lang section %s at end of page" % note_part)
    return "".join(sections), notes

  sections, j, secbody, sectail, has_non_lang = retval
  subsections, subsections_by_header, subsection_levels = blib.split_text_into_subsections(
      secbody, pagemsg)

  # Look for possible matching headword/definition templates.
  matching_defn_templates = []
  for compare_against in expected_header_poses:
    if compare_against in subsections_by_header:
      for subsecind in subsections_by_header[compare_against]:
        subsectext = subsections[subsecind]
        parsed = blib.parse_text(subsectext)
        matching_headword_template = None
        for t in parsed.filter_templates():
          if match_template(t, expected_headword_templates):
            if matching_headword_template:
              pagemsg("WARNING: Saw two headword templates in same section index %s: %s and %s" % (
                subsecind, str(matching_headword_template), str(t)))
              return
            matching_headword_template = t
          if match_template(t, expected_defn_templates):
            if matching_headword_template is None:
              pagemsg("WARNING: Something strange, in section index %s, saw matching definition template %s but no matching headword template" % (
                subsecind, str(t)))
              return
            matching_defn_templates.append((t, matching_headword_template, subsecind))
  if matching_defn_templates:
    # First see if the existing definition is already present exactly.
    for matching_defn_template, matching_headword_template, subsecind in matching_defn_templates:
      if str(matching_defn_template) == new_defn_template:
        pagemsg("Already saw definition template %s" % new_defn_template)
        return
    add_after = None

    # Then see if we can find a place to add the definition, making sure we don't already have a
    # definition for the same form in a different fashion.
    for matching_defn_template, matching_headword_template, subsecind in matching_defn_templates:
      def saw_instead_of():
        pagemsg("Saw %s instead of %s" % (str(matching_defn_template), new_defn_template))
      tn = tname(matching_defn_template)
      if tn in ["past participle of", "gerund of"]:
        matching_lemma = getparam(matching_defn_template, "2")
        rawconj = ""
      else:
        arg1 = getparam(matching_defn_template, "1")
        matching_lemma, rawconj = parse_inf_and_conj(arg1)
        if matching_lemma is None:
          pagemsg("WARNING: Can't parse out infinitive from conjugation '%s'" % arg1)
          return
      both_template_names = {tn, new_defn_template_name}
      if len(both_template_names) == 2 and "past participle of" in both_template_names:
        if matching_lemma == lemma:
          # This must mean we saw {{*-verb form of}} instead of {{past participle of}}
          pagemsg("WARNING: For past participle, saw %s instead of %s" % (
            str(matching_defn_template), new_defn_template))
          return
        else:
          # note but allow
          saw_instead_of()
      elif len(both_template_names) == 2 and "gerund of" in both_template_names:
        if matching_lemma == lemma:
          # This must mean we saw {{gerund of}} instead of {{*-verb form of}}
          pagemsg("WARNING: For gerund, saw %s instead of %s" % (str(matching_defn_template), new_defn_template))
          return
        else:
          # note but allow
          saw_instead_of()
      elif both_template_names == {"gl-verb form of", "gl-reinteg-verb form of"}:
        add_after = subsecind
        # note but allow
        saw_instead_of()
      elif len(both_template_names) == 1:
        if matching_lemma == lemma:
          pagemsg("WARNING: Saw %s instead of %s, can't handle" % (str(matching_defn_template), new_defn_template))
          return
        else:
          add_after = subsecind
          saw_instead_of()
      else:
        # check more templates
        saw_instead_of()

    if add_after is not None:
      # Add another definition line. If there's already a defn line present, insert after any such defn
      # lines. Else, insert at beginning.
      if norm in ["gl", "gl-reinteg"] and pos in ["verb", "gerund"]:
        new_defn_template_beg = r"\{\{gl(?:-reinteg)?-verb form of\|"
      else:
        new_defn_template_beg = re.escape(re.sub(r"^(.*?\|).*", r"\1", new_defn_template))
      if re.search(r"^# %s" % new_defn_template_beg, subsections[subsecind], re.M):
        newsubsec = re.sub(r"(^(# %s.*\n)+)" % new_defn_template_beg,
            r"\1# %s\n" % new_defn_template, subsections[subsecind], 1, re.M)
      else:
        newsubsec = re.sub(r"^#", "# %s\n#" % new_defn_template, subsections[subsecind], 1, re.M)
      if newsubsec == subsections[subsecind]:
        pagemsg("WARNING: Couldn't insert new definition line %s in existing subsection %s" % (
          new_defn_template, subsecind))
        return
      subsections[subsecind] = newsubsec
      secbody = "".join(subsections)
      sections[j] = secbody.rstrip("\n") + sectail
      pagemsg("Inserting new definition into existing subsection %s" % infl_part)
      notes.append("insert new definition into existing subsection %s" % note_part)
      return "".join(sections), notes

  # Didn't find POS section for form. If form is a past participle, look for an adjective section and add before.
  if pos == "participle" and "Adjective" in subsections_by_header:
    adj_sections = subsections_by_header["Adjective"]
    if len(adj_sections) > 1:
      pagemsg("WARNING: Adding participle before adjective, saw %s Adjective sections, can't handle" %
              len(adj_sections))
      return
    adj_secind = adj_sections[0]
    if subsection_levels[adj_secind] not in [3, 4]:
      pagemsg("WARNING: Saw Adjective section %s at level %s != 3 or 4, can't handle" % (
        subsections[adj_secind - 1].strip(), subsection_levels[adj_secind]))
      return
    subsections[adj_secind - 1: adj_secind - 1] = [newposl4 if subsection_levels[adj_secind] == 4 else newpos]
    secbody = "".join(subsections)
    sections[j] = secbody.rstrip("\n") + sectail
    pagemsg("Inserting participle subsection %s before adjective subsection" % infl_part)
    notes.append("insert participle subsection %s before adjective subsection" % note_part)
    return "".join(sections), notes

  # Didn't find POS section for form.
  if "Etymology 1" in subsections_by_header:
    # find highest Etymology section
    highest_etym_section = 1
    for section_header in subsections_by_header:
      m = re.search("^Etymology ([0-9]+)$", section_header)
      if m:
        highest_etym_section = max(highest_etym_section, int(m.group(1)))
    subsections.append("===Etymology %s===\n" % (highest_etym_section + 1))
    subsections.append("\n" + newposl4)
    secbody = "".join(subsections)
    sections[j] = secbody.rstrip("\n") + sectail
    pagemsg("Appending etym subsection %s" % infl_part)
    notes.append("append etym subsection %s" % note_part)
    return "".join(sections), notes

  # One etymology section for language. Wrap existing text in Etymology 1 and add Etymology 2.
  if "Etymology" in subsections_by_header:
    # Found etymology section; if there is a preceding section such as Alternative forms, put the etymology section
    # above it.
    etymology_sections = subsections_by_header["Etymology"]
    if len(etymology_sections) > 1:
      pagemsg("WARNING: Saw %s Etymology sections, can't handle" % len(etymology_sections))
      return
    etymology_ind = etymology_sections[0]
    if subsection_levels[etymology_ind] != 3:
      pagemsg("WARNING: Saw Etymology section %s at level %s != 3, can't handle" % (
        subsections[etymology_ind - 1].strip(), subsection_levels[etymology_ind]))
      return
    if etymology_ind > 2:
      pagemsg("Found Etymology section at position %s, below other sections, moving up" % etymology_ind)
      notes.append("move Etymology subsection up to top of %s lang section" % normname)
      etymtext = subsections[etymology_ind]
      del subsections[etymology_ind - 1:etymology_ind + 1]
      subsections[1:1] = ["===Etymology 1===\n", etymtext]
    else:
      assert etymology_ind == 2
      subsections[1] = "===Etymology 1===\n"
  else:
    subsections[1:1] = ["===Etymology 1===\n", "\n"]

  # Increase indent level of existing headers (except maybe an Etymology section we converted to Etymology 1) by one.
  for k in range(3, len(subsections), 2):
    subsections[k] = "=" + subsections[k].strip() + "=\n"

  subsections.append("===Etymology 2===\n")
  subsections.append("\n" + newposl4)
  secbody = "".join(subsections)
  sections[j] = secbody.rstrip("\n") + sectail
  pagemsg("Wrapping existing lang section in Etymology 1, appending Etymology 2 subsection %s" %
          infl_part)
  notes.append("wrapping existing %s lang section in Etymology 1, append Etymology 2 subsection %s" %
               (normname, note_part))
  return "".join(sections), notes

def process_text_on_page(index, pagetitle, pagetext):
  norm = args.norm
  normname = norm_to_name[norm]
  def pagemsg(txt, fn=msg, overriding_index=None):
    fn("Page %s %s: %s" % (overriding_index or index, pagetitle, txt))
  def errandpagemsg(txt):
    pagemsg(txt, fn=errandmsg)
  def expand_text(tempcall):
    return blib.expand_text(tempcall, pagetitle, pagemsg, args.verbose)

  notes = []

  if " " in pagetitle:
    pagemsg("Space in pagetitle, not creating verb forms")
    return

  parsed = blib.parse_text(pagetext)
  conjs = []
  standard_gl_conj_forms = None
  for t in parsed.filter_templates():
    tn = tname(t)
    standard_conj_for_reinteg = norm == "gl-reinteg" and tn == "gl-conj"
    if tn == "%s-conj" % norm or standard_conj_for_reinteg:
      conj_normname = "Galician" if standard_conj_for_reinteg else normname
      arg1 = getparam(t, "1")
      inf = pagetitle
      if arg1 == "":
        newconj = inf
      elif re.search("^<[^<>]*>$", arg1):
        newconj = "%s%s" % (inf, arg1)
      else:
        newconj = arg1
      if newconj == arg1:
        pagemsg("%s conjugation already has infinitive in it: %s" % (conj_normname, arg1))
      else:
        pagemsg("Converting %s conjugation '%s' to '%s'" % (conj_normname, arg1, newconj))
        arg1 = newconj
      conjinf, rawconj = parse_inf_and_conj(arg1)
      if conjinf is None:
        pagemsg("WARNING: Can't parse out %s infinitive from conjugation '%s'" % (conj_normname, arg1))
        continue
      if conjinf.endswith("se"):
        pagemsg("Skipping reflexive conjugation '%s'" % arg1)
        continue
      if arg1 not in conjs:
        jsonconj = expand_text("{{%s-conj|%s|json=1%s}}" % (
          "gl" if standard_conj_for_reinteg else norm, arg1, "|nocomb=1" if norm == "es" else ""))
        if not jsonconj:
          continue
        json_expansion = json.loads(jsonconj)
        if norm == "es":
          if "forms" not in json_expansion:
            pagemsg("WARNING: Didn't see 'forms' in %s JSON expansion for conjugation '%s': %s" % (
              conj_normname, arg1, jsonconj))
            continue
          forms = json_expansion["forms"]
        else:
          forms = json_expansion
        if standard_conj_for_reinteg:
          standard_gl_conj_forms = forms
        else:
          new_tuple = (conjinf, arg1, forms, standard_gl_conj_forms)
          if new_tuple not in conjs:
            conjs.append(new_tuple)
          if tn == "gl-reinteg-conj":
            standard_gl_conj_forms = None
  if len(conjs) == 0:
    pagemsg("WARNING: %s infinitive page exists but has no conjugations" % normname)
    return
  elif len(conjs) > 1:
    pagemsg("WARNING: Multiple %s conjugations %s" % (normname, ", ".join(conj for conjinf, conj, forms, standard_forms in conjs)))
  for conjinf, conj, forms, standard_forms in conjs:
    seen_forms = set()
    forms_to_skip = set()
    if "short_pp_ms" in forms:
      for slot_form in ["short_pp_ms", "short_pp_fs", "short_pp_mp", "short_pp_fp"]:
        for formobj in forms[slot_form]:
          forms_to_skip.add(formobj["form"])
    def compute_slots_for_forms(forms):
      slots_for_forms = defaultdict(set)
      for slot, slot_forms in forms.items():
        for formobj in slot_forms:
          slots_for_forms[formobj["form"]].add(slot)
      return slots_for_forms
    slots_for_forms = compute_slots_for_forms(forms)
    slots_for_standard_forms = compute_slots_for_forms(standard_forms) if standard_forms else None
    for slot_index, (slot, slot_forms) in enumerate(sorted(list(forms.items()))):
      def get_combined_index():
        return "%s.%s" % (index, slot_index + 1)
      def indexed_pagemsg(txt):
        pagemsg(txt, overriding_index=get_combined_index())
      if slot in ["infinitive", "infinitive_linked"]:
        indexed_pagemsg("Skipping %s slot '%s'" % (normname, slot))
        continue
      if slot in ["pp_fs", "pp_mp", "pp_fp", "short_pp_fs", "short_pp_mp", "short_pp_fp"]:
        indexed_pagemsg("Skipping %s participle form slot '%s', code not yet written to handle it (FIXME)" % (normname, slot))
        # FIXME, deal with these
        continue
      if slot in ["short_pp_ms"]:
        indexed_pagemsg("Skipping %s short participle slot '%s', code not yet written to handle it (FIXME)" % (normname, slot))
        # FIXME, deal with this
        continue
      if slot in ["pp_ms"]:
        pos = "participle"
      elif slot in ["gerund"]:
        pos = "gerund"
      else:
        pos = "verb"
      for formobj in slot_forms:
        form = formobj["form"]
        if form in seen_forms:
          indexed_pagemsg("Skipping already-seen %s form %s for slot %s" % (normname, form, slot))
          continue
        seen_forms.add(form)
        if "[" in form:
          indexed_pagemsg("Skipping bracket-containing %s form %s for slot %s" % (normname, form, slot))
          continue
        should_skip = form in forms_to_skip
        if form == conjinf:
          indexed_pagemsg("Skipping %s form %s for slot %s that's identical to lemma" % (normname, form, slot))
          continue
        if "footnotes" in formobj and "[superseded]" in formobj["footnotes"]:
          indexed_pagemsg("Skipping %s form %s for slot %s that's superseded" % (normname, form, slot))
          continue
        if norm == "gl-reinteg" and slots_for_standard_forms:
          if slots_for_forms[form] == slots_for_standard_forms[form]:
            indexed_pagemsg("Skipping %s form %s for slot %s that's identical to the corresponding standard Galician form" % (
              normname, form, slot))
            continue
          else:
            gl_reinteg_slots = sorted(list(slots_for_forms[form]))
            gl_standard_slots = sorted(list(slots_for_standard_forms[form]))
            if gl_standard_slots:
              indexed_pagemsg("Not skipping %s form %s for slot %s; even though there's a corresponding standard Galician form, the standard Galician form fills slot%s %s while the reintegrated form fills slot%s %s" % (
                normname, form, slot, "s" if len(gl_standard_slots) > 1 else "", ",".join(gl_standard_slots),
                "s" if len(gl_reinteg_slots) > 1 else "", ",".join(gl_reinteg_slots)))
            else:
              indexed_pagemsg("Not skipping %s form %s for slot %s; even though there's a corresponding standard Galician verb, the form is not part of it" % (
                normname, form, slot))
        def process_page(page, index, parsed):
          retval = process_text_on_inflection_page(index, str(page.title()), blib.safe_page_text(page, errandpagemsg),
                                                   norm, pos, conjinf, conj, slot)
          if retval and should_skip:
            newtext, changelog = retval
            indexed_pagemsg("WARNING: Skipping %s form %s for slot %s that's the same as a short past participle form, handle manually; changelog msg=%s" % (
              normname, form, slot, blib.changelog_to_string(changelog)))
            return
          return retval
        blib.do_edit(pywikibot.Page(site, form), get_combined_index(), process_page, save=args.save,
                     verbose=args.verbose, diff=args.diff)

parser = blib.create_argparser("Create verb inflections for Spanish, Galician or Portuguese", include_pagefile=True,
                               include_stdin=True)
parser.add_argument("--norm", choices=list(norm_to_name.keys()), required=True, help="Code of norm to do.")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True,
    default_cats=["%s verbs" % lang_to_name[norm_to_lang[args.norm]]], skip_ignorable_pages=True)
