#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse, json, unicodedata

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

  if pos in ["verb", "gerund"]:
    headword_pos = "verb form" if pos == "verb" else "gerund"
    header_pos = "Verb"
    expected_header_poses = ["Verb"]
    if pos == "verb":
      expected_headword_templates = [("head", lang, "verb form")]
    else:
      expected_headword_templates = [("head", lang, "gerund"), ("head", lang, "verb form")]
    new_headword_template = "{{head|%s|%s}}" % (lang, headword_pos)
    new_defn_template_name = "%s-verb form of" % norm
    new_defn_template = "{{%s|%s}}" % (new_defn_template_name, infl)
    if norm in ["gl", "gl-reinteg"]:
      expected_defn_templates = ["gl-verb form of", "gl-reinteg-verb form of"]
    else:
      expected_defn_templates = ["%s-verb form of" % norm]
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
    fn("Page %s %s: %s %s %s of [[%s]]: %s" % (index, pagetitle, normname, headword_pos, slot, lemma, txt))

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
  entrytext = "\n" + newpos
  entrytextl4 = "\n" + newposl4
  newsection = "==%s==\n" % langname + entrytext
  infl_part = "with infl '%s'" % infl
  note_part = "with %s %s entry of %s" % (normname, headword_pos, infl)

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
  subsections, subsections_by_header, subsection_levels = blib.split_text_into_subsections(secbody, pagemsg)
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
              pagemsg("WARNING: Saw two %s headword templates in same section index %s: %s and %s" % (
                normname, subsecind, str(matching_headword_template), str(t)))
              return
            matching_headword_template = t
          if match_template(t, expected_defn_templates):
            if matching_headword_template is None:
              pagemsg("WARNING: Something strange, in %s section index %s, saw matching definition template %s but no matching headword template" % (
                normname, subsecind, str(t)))
              return
            matching_defn_templates.append((t, matching_headword_template, subsecind))
  if matching_defn_templates:
    for matching_defn_template, matching_headword_template, subsecind in matching_defn_templates:
      if str(matching_defn_template) == new_defn_template:
        pagemsg("Already saw %s definition template %s" % (normname, new_defn_template))
        return
      else:
        add_after = False
        tn = tname(matching_defn_template)
        if tn == "past participle of":
          matching_lemma = getparam(matching_defn_template, "2")
          rawconj = ""
        else:
          arg1 = getparam(matching_defn_template, "1")
          matching_lemma, rawconj = parse_inf_and_conj(arg1)
          if matching_lemma is None:
            pagemsg("WARNING: Can't parse out %s infinitive from conjugation '%s'" % (normname, arg1))
            return
        both_template_names = {tn, new_defn_template_name}
        if len(both_template_names) == 2 and "past participle of" in both_template_names:
          if matching_lemma == lemma:
            # This must mean we saw {{*-verb form of}} instead of {{past participle of}}
            pagemsg("WARNING: For %s past participle, saw %s instead of {{past participle of}}" % (
              normname, str(matching_defn_template)))
            return
          else:
            # note but allow
            pagemsg("For %s, saw %s instead of %s" % (
              normname, str(matching_defn_template), new_defn_template))
        elif both_template_names == {"gl-verb form of", "gl-reinteg-verb form of"}:
          add_after = True
          # note but allow
          pagemsg("For %s, saw %s instead of %s" % (
            normname, str(matching_defn_template), new_defn_template))
        elif len(both_template_names) == 1:
          if matching_lemma == lemma:
            pagemsg("WARNING: Saw different %s conjugation '%s' of same lemma, can't handle" % (
              normname, arg1))
            return
          else:
            add_after = True
            pagemsg("For %s, saw %s instead of %s" % (
              normname, str(matching_defn_template), new_defn_template))
        else:
          # check more templates
          pagemsg("For %s, saw %s instead of %s" % (
            normname, str(matching_defn_template), new_defn_template))

        if add_after:
          # Add another definition line. If there's already a defn line present, insert after any such defn lines.
          # Else, insert at beginning.
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
            pagemsg("WARNING: Couldn't insert new %s definition line %s in existing subsection %s" % (
              normname, new_defn_template, subsecind))
            return
          subsections[subsecind] = newsubsec
          secbody = "".join(subsections)
          sections[j] = secbody.rstrip("\n") + sectail
          pagemsg("Inserting new definition into existing subsection %s" % infl_part)
          notes.append("insert new definition into existing subsection %s" % note_part)
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
        subsections.append(entrytextl4)
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
      return None
    etymology_ind = etymology_sections[0]
    if subsection_levels[etymology_ind] != 3:
      pagemsg("WARNING: Saw Etymology section %s at level %s != 3, can't handle" % (
        subsections[etymology_ind - 1].strip(), subsection_levels[etymology_ind]))
      return None
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
  subsections.append(entrytextl4)
  secbody = "".join(subsections)
  sections[j] = secbody.rstrip("\n") + sectail
  pagemsg("Wrapping existing %s lang section in Etymology 1, appending Etymology 2 subsection %s" %
          (normname, infl_part))
  notes.append("wrapping existing %s lang section in Etymology 1, append Etymology 2 subsection %s" %
               (normname, note_part))
  return "".join(sections), notes

def process_text_on_page(index, pagetitle, pagetext):
  norm = args.norm
  normname = norm_to_name[norm]
  def pagemsg(txt, fn=msg):
    fn("Page %s %s: %s" % (index, pagetitle, txt))
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
  for t in parsed.filter_templates():
    tn = tname(t)
    if tn == "%s-conj" % norm:
      arg1 = getparam(t, "1")
      inf = pagetitle
      if arg1 == "":
        newconj = inf
      elif re.search("^<[^<>]*>$", arg1):
        newconj = "%s%s" % (inf, arg1)
      else:
        newconj = arg1
      if newconj == arg1:
        pagemsg("%s conjugation already has infinitive in it: %s" % (normname, arg1))
      else:
        pagemsg("Converting %s conjugation '%s' to '%s'" % (normname, arg1, newconj))
        arg1 = newconj
      conjinf, rawconj = parse_inf_and_conj(arg1)
      if conjinf is None:
        pagemsg("WARNING: Can't parse out %s infinitive from conjugation '%s'" % (normname, arg1))
        continue
      if conjinf.endswith("se"):
        pagemsg("Skipping reflexive conjugation '%s'" % arg1)
        continue
      if arg1 not in conjs:
        jsonconj = expand_text("{{%s-conj|%s|json=1%s}}" % (norm, arg1, "|nocomb=1" if norm == "es" else ""))
        if not jsonconj:
          continue
        json_expansion = json.loads(jsonconj)
        if norm == "es":
          if "forms" not in json_expansion:
            pagemsg("WARNING: Didn't see 'forms' in %s JSON expansion for conjugation '%s': %s" % (
              normname, arg1, jsonconj))
            continue
          forms = json_expansion["forms"]
        else:
          forms = json_expansion
        new_tuple = (conjinf, arg1, forms)
        if new_tuple not in conjs:
          conjs.append(new_tuple)
  if len(conjs) == 0:
    pagemsg("WARNING: %s infinitive page exists but has no conjugations" % normname)
    return
  elif len(conjs) > 1:
    pagemsg("WARNING: Multiple %s conjugations %s" % (normname, ", ".join(conj for conjinf, conj, forms in conjs)))
  for conjinf, conj, forms in conjs:
    seen_forms = set()
    for slot_index, (slot, slot_forms) in enumerate(sorted(list(forms.items()))):
      if slot in ["infinitive", "infinitive_linked"]:
        continue
      if slot in ["pp_fs", "pp_mp", "pp_fp"]:
        # FIXME, deal with these
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
          pagemsg("Skipping already-seen %s form %s for slot %s" % (normname, form, slot))
          continue
        seen_forms.add(form)
        if "[" in form:
          pagemsg("Skipping bracket-containing %s form %s for slot %s" % (normname, form, slot))
          continue
        if form == conjinf:
          pagemsg("Skipping %s form %s for slot %s that's identical to lemma" % (normname, form, slot))
          continue
        def process_page(page, index, parsed):
          return process_text_on_inflection_page(index, str(page.title()), blib.safe_page_text(page, errandpagemsg),
                                                 norm, pos, conjinf, conj, slot)
        blib.do_edit(pywikibot.Page(site, form), "%s.%s" % (index, slot_index + 1), process_page, save=args.save,
                     verbose=args.verbose, diff=args.diff)

parser = blib.create_argparser("Create verb inflections for Spanish, Galician or Portuguese", include_pagefile=True,
                               include_stdin=True)
parser.add_argument("--norm", choices=list(norm_to_name.keys()), required=True, help="Code of norm to do.")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True,
    default_cats=["%s verbs" % lang_to_name[norm_to_lang[args.norm]]], skip_ignorable_pages=True)
