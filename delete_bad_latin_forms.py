#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, errandmsg, site, tname, pname

import lalib
from lalib import remove_macrons

def delete_participle_1(page, index, lemma, formind, formval, pos, preserve_diaeresis, save, verbose, diff):
  notes = []

  def pagemsg(txt):
    msg("Page %s %s: form %s %s: %s" % (index, lemma, formind, formval, txt))
  def errandpagemsg(txt):
    errandmsg("Page %s %s: form %s %s: %s" % (index, lemma, formind, formval, txt))
  def expand_text(tempcall):
    return blib.expand_text(tempcall, remove_macrons(formval, preserve_diaeresis), pagemsg, verbose)

  expected_head_template = "la-part"

  text = unicode(page.text)
  origtext = text

  retval = lalib.find_latin_section(text, pagemsg)
  if retval is None:
    return None, None

  sections, j, secbody, sectail, has_non_latin = retval

  subsections = re.split("(^==+[^=\n]+==+\n)", secbody, 0, re.M)
  saw_lemma_in_etym = False
  saw_wrong_lemma_in_etym = False
  saw_head = False
  infl_template = None
  saw_bad_template = False
  for k in range(2, len(subsections), 2):
    parsed = blib.parse_text(subsections[k])
    for t in parsed.filter_templates():
      tn = tname(t)
      if tn == "m" and "==Etymology==" in subsections[k - 1]:
        actual_lemma = getparam(t, "2")
        if remove_macrons(lemma, preserve_diaeresis) == remove_macrons(actual_lemma, preserve_diaeresis):
          saw_lemma_in_etym = True
        else:
          pagemsg("WARNING: Saw wrong lemma %s != %s in Etymology section: %s" % (
            actual_lemma, lemma, unicode(t)))
          saw_wrong_lemma_in_etym = True
      elif tn == expected_head_template:
        saw_head = True
      elif tn == "la-adecl":
        if not saw_head:
          pagemsg("WARNING: Saw inflection template without (or before) head template, skipping: %s" %
            unicode(t))
        elif infl_template:
          pagemsg("WARNING: Saw two possible inflection templates: first %s, second %s" % (
            infl_template, unicode(t)))
        else:
          infl_template = unicode(t)
      elif tn in ["rfdef", "R:L&S", "R:Elementary Lewis", "R:du Cange", "R:Gaffiot",
          "R:NLW", "alternative form of", "la-IPA"]:
        pass
      else:
        pagemsg("WARNING: Saw unrecognized template in subsection #%s %s: %s" % (
          k // 2, subsections[k - 1].strip(), unicode(t)))
        saw_bad_template = True

  delete = False
  if saw_head and infl_template:
    if not saw_lemma_in_etym:
      pagemsg("WARNING: Would delete but didn't see reference to correct lemma %s in Etymology section, not deleting" %
          lemma)
    elif saw_wrong_lemma_in_etym:
      pagemsg("WARNING: Would delete but saw reference to wrong lemma in Etymology section, not deleting")
    elif saw_bad_template:
      pagemsg("WARNING: Would delete but saw unrecognized template, not deleting")
    else:
      delete = True

  if not delete:
    return None, None

  args = lalib.generate_adj_forms(infl_template, errandpagemsg, expand_text)
  if args is None:
    return None, None
  single_forms_to_delete = []
  for key, form in args.iteritems():
    single_forms_to_delete.extend(form.split(","))
  for formformind, formformval in blib.iter_items(single_forms_to_delete):
    delete_form(index, formval, formformind, formformval, "partform", True,
        preserve_diaeresis, save, verbose, diff)

  #### Now, we can maybe delete the whole section or page

  if subsections[0].strip():
    pagemsg("WARNING: Whole Latin section deletable except that there's text above all subsections: <%s>" % subsections[0].strip())
    return None, None
  if "[[Category:" in sectail:
    pagemsg("WARNING: Whole Latin section deletable except that there's a category at the end: <%s>" % sectail.strip())
    return None, None
  if not has_non_latin:
    # Can delete the whole page, but check for non-blank section 0
    cleaned_sec0 = re.sub("^\{\{also\|.*?\}\}\n", "", sections[0])
    if cleaned_sec0.strip():
      pagemsg("WARNING: Whole page deletable except that there's text above all sections: <%s>" % cleaned_sec0.strip())
      return None, None
    pagetitle = unicode(page.title())
    pagemsg("Page %s should be deleted" % pagetitle)
    pages_to_delete.append(pagetitle)
    return None, None
  del sections[j]
  del sections[j-1]
  notes.append("removed Latin section for bad participle")
  if j > len(sections):
    # We deleted the last section, remove the separator at the end of the
    # previous section.
    sections[-1] = re.sub(r"\n+--+\n*\Z", "", sections[-1])
  text = "".join(sections)

  return text, notes

def delete_participle(index, lemma, formind, formval, pos, preserve_diaeresis, save, verbose, diff):
  def pagemsg(txt):
    msg("Page %s %s: form %s %s: %s" % (index, lemma, formind, formval, txt))

  if "[" in formval:
    pagemsg("Skipping form value %s with link in it" % formval)
    return

  page = pywikibot.Page(site, remove_macrons(formval, preserve_diaeresis))
  if not page.exists():
    pagemsg("Skipping form value %s, page doesn't exist" % formval)
    return

  def do_delete_participle_1(page, index, parsed):
    return delete_participle_1(page, index, lemma, formind, formval, pos,
        preserve_diaeresis, save, verbose, diff)
  blib.do_edit(page, index, do_delete_participle_1, save=save, verbose=verbose,
      diff=diff)

def delete_form_1(page, index, lemma, formind, formval, pos, tag_sets_to_delete,
    preserve_diaeresis):
  notes = []

  tag_sets_to_delete = True if tag_sets_to_delete is True else (
    sorted(tag_sets_to_delete)
  )
  frozenset_tag_sets_to_delete = True if tag_sets_to_delete is True else set(
    frozenset(tag_set) for tag_set in tag_sets_to_delete
  )

  def pagemsg(txt):
    msg("Page %s %s: form %s %s: %s" % (index, lemma, formind, formval, txt))
  def errandpagemsg(txt):
    errandmsg("Page %s %s: form %s %s: %s" % (index, lemma, formind, formval, txt))

  if pos == "verbform":
    expected_head_template = "la-verb-form"
    expected_header_pos = "Verb"
    expected_head_pos = "verb form"
  elif pos == "nounform":
    expected_head_template = "la-noun-form"
    expected_header_pos = "Noun"
    expected_head_pos = "noun form"
  elif pos == "adjform":
    expected_head_template = "la-adj-form"
    expected_header_pos = "Adjective"
    expected_head_pos = "adjective form"
  elif pos == "partform":
    expected_head_template = "la-part-form"
    expected_header_pos = "Participle"
    expected_head_pos = "participle form"
  elif pos == "numform":
    expected_head_template = "la-num-form"
    expected_header_pos = "Numeral"
    expected_head_pos = "numeral form"
  else:
    raise ValueError("Unrecognized part of speech %s" % pos)

  text = unicode(page.text)
  origtext = text

  retval = lalib.find_latin_section(text, pagemsg)
  if retval is None:
    return None, None

  sections, j, secbody, sectail, has_non_latin = retval

  # FIXME!

  #if "==Etymology 1==" in secbody:
  #  etym_sections = re.split("(^===Etymology [0-9]+===\n)", secbody, 0, re.M)
  #  for k in range(2, len(etym_sections), 2):
  #    etym_sections[k] = fix_up_section(etym_sections[k], warn_on_multiple_heads=True)
  #  secbody = "".join(etym_sections)

  subsections_to_delete = []
  subsections_to_remove_inflections_from = []

  subsections = re.split("(^==+[^=\n]+==+\n)", secbody, 0, re.M)
  for k in range(2, len(subsections), 2):
    parsed = blib.parse_text(subsections[k])
    saw_head = False
    saw_infl = False
    saw_other_infl = False
    remove_deletable_tag_sets_from_subsection = False
    saw_bad_template = False
    for t in parsed.filter_templates():
      tn = tname(t)
      if tn == expected_head_template:
        saw_head = True
      elif tn == "head" and getparam(t, "1") == "la" and getparam(t, "2") == expected_head_pos:
        saw_head = True
      elif tn == "inflection of":
        lang = getparam(t, "lang")
        if lang:
          lemma_param = 1
        else:
          lang = getparam(t, "1")
          lemma_param = 2
        if lang != "la":
          errandpagemsg("WARNING: In Latin section, found {{inflection of}} for different language %s: %s" % (
            lang, unicode(t)))
          return None, None
        actual_lemma = getparam(t, str(lemma_param))
        # Allow mismatch in macrons, which often happens, e.g. because
        # a macron was added to the lemma page but not to the inflections
        if remove_macrons(actual_lemma, preserve_diaeresis) == remove_macrons(lemma, preserve_diaeresis):
          # fetch tags
          tags = []
          for param in t.params:
            pname = unicode(param.name).strip()
            pval = unicode(param.value).strip()
            if re.search("^[0-9]+$", pname):
              if int(pname) >= lemma_param + 2:
                if pval:
                  tags.append(pval)
          for tag in tags:
            if "//" in tag:
              pagemsg("WARNING: Don't know how to handle multipart tags yet: %s" % unicode(t))
              saw_other_infl = True
              break
          else:
            # no break
            tag_sets = lalib.split_tags_into_tag_sets(tags)
            for tag_set in tag_sets:
              if tag_sets_to_delete is True or frozenset(lalib.canonicalize_tag_set(tag_set)) in frozenset_tag_sets_to_delete:
                saw_infl = True
              else:
                pagemsg("Found {{inflection of}} for correct lemma but wrong tag set %s, expected one of %s: %s" % (
                  "|".join(tag_set), ",".join("|".join(x) for x in tag_sets_to_delete), unicode(t)))
                saw_other_infl = True
        else:
          pagemsg("Found {{inflection of}} for different lemma %s: %s" % (
            actual_lemma, unicode(t)))
          saw_other_infl = True
    if saw_head and saw_infl:
      if saw_other_infl:
        pagemsg("Found subsection #%s to delete but has inflection-of template for different lemma or nondeletable tag set, will remove only deletable tag sets" % (k // 2))
        remove_deletable_tag_sets_from_subsection = True
      for t in parsed.filter_templates():
        tn = tname(t)
        if tn not in [expected_head_template, "inflection of"] and not (
            tn == "head" and getparam(t, "1") == "la" and getparam(t, "2") == expected_head_pos
          ):
          pagemsg("WARNING: Saw unrecognized template in otherwise deletable subsection #%s: %s" % (
            k // 2, unicode(t)))
          saw_bad_template = True
          break
      else:
        # No break
        if "===%s===" % expected_header_pos in subsections[k - 1]:
          if remove_deletable_tag_sets_from_subsection:
            subsections_to_remove_inflections_from.append(k)
          else:
            subsections_to_delete.append(k)
        else:
          pagemsg("WARNING: Wrong header in otherwise deletable subsection #%s: %s" % (
            k // 2, subsections[k - 1].strip()))

  if not subsections_to_delete and not subsections_to_remove_inflections_from:
    pagemsg("Found Latin section but no deletable or excisable subsections")
    return None, None

  #### Now, we can delete an inflection, a subsection or the whole section or page

  for k in subsections_to_remove_inflections_from:
    newsubsec = subsections[k]
    if not newsubsec.endswith("\n"):
      # This applies to the last subsection on the page
      newsubsec += "\n"

    def remove_inflections(m):
      parsed = blib.parse_text(m.group(0))
      for t in parsed.filter_templates():
        tn = tname(t)
        if tn == "inflection of":
          lang = getparam(t, "lang")
          if lang:
            lemma_param = 1
          else:
            lang = getparam(t, "1")
            lemma_param = 2
          assert lang == "la"
          actual_lemma = getparam(t, str(lemma_param))
          # Allow mismatch in macrons, which often happens, e.g. because
          # a macron was added to the lemma page but not to the inflections
          if remove_macrons(actual_lemma, preserve_diaeresis) == remove_macrons(lemma, preserve_diaeresis):
            tr = getparam(t, "tr")
            alt = getparam(t, "alt") or getparam(t, str(lemma_param + 1))
            # fetch tags
            tags = []
            params = []
            for param in t.params:
              pname = unicode(param.name).strip()
              pval = unicode(param.value).strip()
              if re.search("^[0-9]+$", pname):
                if int(pname) >= lemma_param + 2:
                  if pval:
                    tags.append(pval)
              elif pname not in ["lang", "tr", "alt"]:
                params.append((pname, pval, param.showkey))
            tag_sets = lalib.split_tags_into_tag_sets(tags)
            filtered_tag_sets = []
            for tag_set in tag_sets:
              if tag_sets_to_delete is not True and frozenset(lalib.canonicalize_tag_set(tag_set)) not in frozenset_tag_sets_to_delete:
                filtered_tag_sets.append(tag_set)
            if not filtered_tag_sets:
              return ""

            # Erase all params.
            del t.params[:]
            # Put back new params.
            t.add("1", lang)
            t.add("2", actual_lemma)
            if tr:
              t.add("tr", tr)
            t.add("3", alt)
            next_tag_param = 4
            for tag in lalib.combine_tag_set_group(filtered_tag_sets):
              t.add(str(next_tag_param), tag)
              next_tag_param += 1
      return unicode(parsed)

    newnewsubsec = re.sub(r"^# \{\{inflection of\|[^{}\n]*\}\}\n", remove_inflections, newsubsec, 0, re.M)
    if newnewsubsec != newsubsec:
      notes.append("removed inflection(s) for bad Latin form(s)")
      subsections[k] = newnewsubsec

  for k in reversed(subsections_to_delete):
    # Do in reverse order so indices don't change
    del subsections[k]
    del subsections[k - 1]

  if len(subsections) == 1 or len(subsections) == 3 and re.search("^==+References==+$", subsections[1].strip()):
    # Whole section deletable
    if subsections[0].strip():
      pagemsg("WARNING: Whole Latin section deletable except that there's text above all subsections: <%s>" % subsections[0].strip())
      return None, None
    if "[[Category:" in sectail:
      pagemsg("WARNING: Whole Latin section deletable except that there's a category at the end: <%s>" % sectail.strip())
      return None, None
    if not has_non_latin:
      # Can delete the whole page, but check for non-blank section 0
      cleaned_sec0 = re.sub("^\{\{also\|.*?\}\}\n", "", sections[0])
      if cleaned_sec0.strip():
        pagemsg("WARNING: Whole page deletable except that there's text above all sections: <%s>" % cleaned_sec0.strip())
        return None, None
      pagetitle = unicode(page.title())
      pagemsg("Page %s should be deleted" % pagetitle)
      pages_to_delete.append(pagetitle)
      return None, None
    del sections[j]
    del sections[j-1]
    notes.append("excised %s subsection%s for bad Latin forms, leaving no Latin section" %
      (len(subsections_to_delete), "" if len(subsections_to_delete) == 1 else "s"))
    if j > len(sections):
      # We deleted the last section, remove the separator at the end of the
      # previous section.
      sections[-1] = re.sub(r"\n+--+\n*\Z", "", sections[-1])
    text = "".join(sections)

  else:
    # Some but not all subsections remain
    secbody = "".join(subsections)
    sections[j] = secbody + sectail
    if subsections_to_delete and subsections_to_remove_inflections_from:
      deletable_subsec_text = "Subsection(s) %s deletable and subsection(s) %s excisable" % (
        ",".join(str(k//2) for k in subsections_to_delete),
        ",".join(str(k//2) for k in subsections_to_remove_inflections_from)
      )
      deletable_subsec_note_text = "deleted %s subsection%s and partly excised %s subsection%s" % (
        len(subsections_to_delete),
        "" if len(subsections_to_delete) == 1 else "s",
        len(subsections_to_remove_inflections_from),
        "" if len(subsections_to_remove_inflections_from) == 1 else "s"
      )
    elif subsections_to_delete:
      deletable_subsec_text = "Subsection(s) %s deletable" % (
        ",".join(str(k//2) for k in subsections_to_delete)
      )
      deletable_subsec_note_text = "deleted %s subsection%s" % (
        len(subsections_to_delete),
        "" if len(subsections_to_delete) == 1 else "s"
      )
    else:
      deletable_subsec_text = "Subsection(s) %s excisable" % (
        ",".join(str(k//2) for k in subsections_to_remove_inflections_from)
      )
      deletable_subsec_note_text = "partly excised %s subsection%s" % (
        len(subsections_to_remove_inflections_from),
        "" if len(subsections_to_remove_inflections_from) == 1 else "s"
      )

    if "==Etymology" in sections[j]:
      pagemsg("WARNING: %s but found Etymology subsection, don't know how to handle" %
          deletable_subsec_text)
      return None, None
    if "==Pronunciation" in sections[j]:
      pagemsg("WARNING: %s but found Pronunciation subsection, don't know how to handle" %
          deletable_subsec_text)
      return None, None

    notes.append("%s for bad Latin forms, leaving some subsections remaining" %
      deletable_subsec_note_text)
    text = "".join(sections)

  return text, notes

def delete_form(index, lemma, formind, formval, pos, tag_sets_to_delete,
    preserve_diaeresis, save, verbose, diff):
  def pagemsg(txt):
    msg("Page %s %s: form %s %s: %s" % (index, lemma, formind, formval, txt))

  if "[" in formval:
    pagemsg("Skipping form value %s with link in it" % formval)
    return

  page = pywikibot.Page(site, remove_macrons(formval, preserve_diaeresis))
  if not page.exists():
    pagemsg("Skipping form value %s, page doesn't exist" % formval)
    return

  def do_delete_form_1(page, index, parsed):
    return delete_form_1(page, index, lemma, formind, formval, pos,
        tag_sets_to_delete, preserve_diaeresis)
  blib.do_edit(page, index, do_delete_form_1, save=save, verbose=verbose,
      diff=diff)

def process_page(index, lemma, pos, infl, slots, pages_to_delete, preserve_diaeresis, save, verbose, diff):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, lemma, txt))
  def errandpagemsg(txt):
    errandmsg("Page %s %s: %s" % (index, lemma, txt))
  def expand_text(tempcall):
    return blib.expand_text(tempcall, remove_macrons(lemma, preserve_diaeresis), pagemsg, verbose)

  pagemsg("Processing")

  args = lalib.generate_infl_forms(pos, infl, errandpagemsg, expand_text,
      add_sync_verb_forms=True)
  if args is None:
    return

  forms_to_delete = []
  tag_sets_to_delete = []
  lemma_no_macrons = remove_macrons(lemma)

  def add_bad_forms(bad_slot_fun):
    for slot, formspec in args.iteritems():
      if bad_slot_fun(slot):
        tag_sets_to_delete.append(lalib.slot_to_tag_set(slot))
        forms_to_delete.append((slot, formspec))

  for slot in slots.split(","):
    if slot.startswith("@"):
      if ":" in slot:
        real_form, real_slot = slot[1:].split(":")
        tag_sets_to_delete.append(lalib.slot_to_tag_set(real_slot))
        forms_to_delete.append((real_slot, real_form))
      else:
        forms_to_delete.append((None, slot[1:]))
    elif slot in args:
      tag_sets_to_delete.append(lalib.slot_to_tag_set(slot))
      forms_to_delete.append((slot, args[slot]))
    elif slot == "allbutlemma":
      for sl, formspec in args.iteritems():
        forms = formspec.split(",")
        forms = [form for form in forms if lemma_no_macrons != remove_macrons(form)]
        if forms:
          tag_sets_to_delete.append(lalib.slot_to_tag_set(sl))
          forms_to_delete.append((sl, ",".join(forms)))
    else:
      add_bad_forms(lambda sl: lalib.slot_matches_spec(sl, slot))

  single_forms_to_delete = []

  for slot, formspec in forms_to_delete:
    for single_form in formspec.split(","):
      single_forms_to_delete.append((slot, single_form))
  for formind, (slot, formval) in blib.iter_items(single_forms_to_delete,
      get_name=lambda x: x[1]):
    partpos = None
    if slot == "pres_actv_ptc":
      partpos = "presactpart"
    elif slot in ["perf_actv_ptc", "perf_pasv_ptc"]:
      partpos = "perfpasspart"
    elif slot == "futr_actv_ptc":
      partpos = "futactpart"
    elif slot == "futr_pasv_ptc":
      partpos = "futpasspart"

    if partpos:
      delete_participle(index, lemma, formind, formval, partpos,
        preserve_diaeresis, save, verbose, diff)
    else:
      if pos == "noun":
        posform = "nounform"
      elif pos == "verb":
        posform = "verbform"
      elif pos == "adj":
        posform = "adjform"
      elif pos == "nounadj":
        # Noun that uses an adjective declension
        posform = "nounform"
      elif pos == "numadj":
        posform = "numform"
      elif pos == "part":
        posform = "partform"
      else:
        raise ValueError("Invalid part of speech %s" % pos)
      delete_form(index, lemma, formind, formval, posform,
        True if slot is None else tag_sets_to_delete,
        preserve_diaeresis, save, verbose, diff)

parser = blib.create_argparser(u"Delete bad Latin forms")
parser.add_argument('--inflfile', help="File containing lemmas and inflection templates.")
parser.add_argument('--slot-inflfile', help="File containing lemmas, slots to delete and infl templates.")
parser.add_argument('--pos-slot-inflfile', help="File containing POSes, lemmas, slots to delete and infl templates.")
parser.add_argument('--slots', help="Slots to delete.")
parser.add_argument('--pos', help="Part of speech of words to delete",
    choices=['noun', 'verb', 'adj'])
parser.add_argument('--output-pages-to-delete', help="File to write pages to delete.")
parser.add_argument('--preserve-diaeresis', action="store_true",
    help="Don't remove diaeresis when removing macrons to compute page name.")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

pages_to_delete = []
if args.pos_slot_inflfile:
  for index, line in blib.iter_items_from_file(args.pos_slot_inflfile, start, end):
    if "!!!" in line:
      pos, lemma, slots, infl = re.split("!!!", line)
    else:
      pos, lemma, slots, infl = re.split(" ", line, 3)
    process_page(index, lemma, pos, infl, slots, pages_to_delete,
      args.preserve_diaeresis, args.save, args.verbose, args.diff)
elif args.slot_inflfile:
  if not args.pos:
    raise ValueError("If --slot-inflfile given, --pos must be given")
  for index, line in blib.iter_items_from_file(args.slot_inflfile, start, end):
    if "!!!" in line:
      lemma, slots, infl = re.split("!!!", line)
    else:
      lemma, slots, infl = re.split(" ", line, 2)
    process_page(index, lemma, args.pos, infl, slots, pages_to_delete,
      args.preserve_diaeresis, args.save, args.verbose, args.diff)
else:
  if not args.inflfile or not args.slots or not args.pos:
    raise ValueError("If --slot-inflfile not given, --inflfile, --pos and --slots must be given")
  for index, line in blib.iter_items_from_file(args.inflfile, start, end):
    if "!!!" in line:
      lemma, infl = re.split("!!!", line)
    else:
      lemma, infl = re.split(" ", line, 1)
    process_page(index, lemma, args.pos, infl, args.slots, pages_to_delete,
      args.preserve_diaeresis, args.save, args.verbose, args.diff)
msg("The following pages need to be deleted:")
for page in pages_to_delete:
  msg(page)
if args.output_pages_to_delete:
  with codecs.open(args.output_pages_to_delete, "w", "utf-8") as fp:
    for page in pages_to_delete:
      print >> fp, page
