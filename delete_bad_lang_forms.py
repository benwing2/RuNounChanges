#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, msg, errandmsg, site, tname, pname

inflection_of_templates = ["inflection of", "past participle of", "present participle of", "feminine singular of"]

form_poses = ["noun form", "verb form", "adjective form", "past participle", "past participle form",
  "present participle", "present participle form"]

lang_to_langname = {
  "es": "Spanish",
  "it": "Italian",
}

lang_headword_templates = {
  "es": [],
  "it": ["it-pp"],
}

lang_inflection_of_templates = {
  "es": ["es-verb form of"],
  "it": [],
}

def delete_form_1(page, index, lemma, formind, formval, lang):
  notes = []

  def pagemsg(txt):
    msg("Page %s %s: form %s %s: %s" % (index, lemma, formind, formval, txt))
  def errandpagemsg(txt):
    errandmsg("Page %s %s: form %s %s: %s" % (index, lemma, formind, formval, txt))

  text = str(page.text)
  origtext = text

  retval = blib.find_modifiable_lang_section(text, lang_to_langname[lang], pagemsg)
  if retval is None:
    return

  sections, j, secbody, sectail, has_non_lang = retval

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
      if tn in lang_headword_templates[lang] or (
        tn == "head" and getparam(t, "1") == lang and getparam(t, "2") in form_poses
      ):
        saw_head = True
      elif tn in inflection_of_templates:
        langcode = getparam(t, "1")
        if langcode != lang:
          errandpagemsg("WARNING: In %s section, found {{%s}} for different language %s: %s" % (
            lang_to_langname[lang], tn, langcode, str(t)))
          return
        actual_lemma = getparam(t, "2")
        if actual_lemma == lemma:
          saw_infl = True
        else:
          pagemsg("Found {{%s}} for different lemma %s: %s" % (tn, actual_lemma, str(t)))
          saw_other_infl = True
      elif tn in lang_inflection_of_templates[lang]:
        actual_lemma = getparam(t, "1")
        if actual_lemma == lemma:
          saw_infl = True
        else:
          pagemsg("Found {{%s}} for different lemma %s: %s" % (tn, actual_lemma, str(t)))
          saw_other_infl = True
    if saw_head and saw_infl:
      if saw_other_infl:
        pagemsg("Found subsection #%s to delete but has inflection template for different lemma or nondeletable tag set, will remove only deletable tag sets" % (k // 2))
        remove_deletable_tag_sets_from_subsection = True
      for t in parsed.filter_templates():
        tn = tname(t)
        if tn not in lang_headword_templates[lang] + lang_inflection_of_templates[lang] + inflection_of_templates and not (
            tn == "head" and getparam(t, "1") == lang and getparam(t, "2") in form_poses
          ):
          pagemsg("WARNING: Saw unrecognized template in otherwise deletable subsection #%s: %s" % (
            k // 2, str(t)))
          saw_bad_template = True
          break
      else:
        # No break
        if re.search("===(Noun|Verb|Adjective)===", subsections[k - 1]):
          indent_header = subsections[k - 1].strip()
          indent = len(re.sub("^(=+).*", r"\1", indent_header))
          has_non_deletable_subsubsection = False
          extra_subsubsections_to_delete = []
          l = k
          while l + 1 < len(subsections):
            nextindent = len(re.sub("^(=+).*", r"\1", subsections[l + 1].strip()))
            if nextindent <= indent:
              break
            # Italian verb forms often have Synonyms sections for alternative forms, and random Related terms sections
            if re.search("==(Synonyms|Related terms)==", subsections[l + 1]):
              extra_subsubsections_to_delete.append(l + 2)
              l += 2
            else:
              has_non_deletable_subsubsection = True
              pagemsg("WARNING: Subsection #%s (header %s, indent %s) has subsubsection with header %s (indent %s), not deleting" % (
                l // 2, indent_header, indent, subsections[l + 1].strip(), nextindent))
              break
          if not has_non_deletable_subsubsection:
            if remove_deletable_tag_sets_from_subsection:
              subsections_to_remove_inflections_from.append(k)
            else:
              subsections_to_delete.append(k)
              subsections_to_delete.extend(extra_subsubsections_to_delete)
        else:
          pagemsg("WARNING: Wrong header in otherwise deletable subsection #%s: %s" % (
            k // 2, subsections[k - 1].strip()))

  if not subsections_to_delete and not subsections_to_remove_inflections_from:
    pagemsg("Found %s section but no deletable or excisable subsections" % lang_to_langname[lang])
    return

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
        if tn in inflection_of_templates:
          langcode = getparam(t, "1")
          assert langcode == lang
          actual_lemma = getparam(t, "2")
          if actual_lemma == lemma:
            return ""
        if tn in lang_inflection_of_templates[lang]:
          actual_lemma = getparam(t, "1")
          if actual_lemma == lemma:
            return ""
      return str(parsed)

    for tn in lang_inflection_of_templates[lang] + inflection_of_templates:
      newnewsubsec = re.sub(r"^# \{\{%s\|[^{}\n]*\}\}\n" % re.escape(tn), remove_inflections, newsubsec, 0, re.M)
      if newnewsubsec != newsubsec:
        newsubsec = newnewsubsec
        notes.append("removed {{%s}} inflection(s) for bad %s form(s) of [[%s]]" % (tn, lang_to_langname[lang], lemma))
        subsections[k] = newsubsec

  for k in reversed(subsections_to_delete):
    # Do in reverse order so indices don't change
    del subsections[k]
    del subsections[k - 1]

  whole_section_deletable = False
  if len(subsections) == 1:
    whole_section_deletable = True
  else:
    for k in range(3, len(subsections), 2):
      if not re.search("^==+(References|Anagrams)==+$", subsections[k].strip()):
        break
    else:
      # no break
      whole_section_deletable = True
  if whole_section_deletable:
    # Whole section deletable
    if subsections[0].strip():
      pagemsg("WARNING: Whole %s section deletable except that there's text above all subsections: <%s>" % (
        lang_to_langname[lang], subsections[0].strip()))
      return
    if "[[Category:" in sectail:
      pagemsg("WARNING: Whole %s section deletable except that there's a category at the end: <%s>" % (
        lang_to_langname[lang], sectail.strip()))
      return
    if not has_non_lang:
      # Can delete the whole page, but check for non-blank section 0
      cleaned_sec0 = re.sub("^\{\{also\|.*?\}\}\n", "", sections[0])
      if cleaned_sec0.strip():
        pagemsg("WARNING: Whole page deletable except that there's text above all sections: <%s>" % cleaned_sec0.strip())
        return
      pagetitle = str(page.title())
      pagemsg("Page %s should be deleted" % pagetitle)
      pages_to_delete.append(pagetitle)
      return
    del sections[j]
    del sections[j-1]
    notes.append("excised %s subsection%s for bad %s form(s) of [[%s]], leaving no %s section" % (
      (len(subsections_to_delete), "" if len(subsections_to_delete) == 1 else "s", lang_to_langname[lang],
        lemma, lang_to_langname[lang])))
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
      return
    if "==Pronunciation" in sections[j]:
      pagemsg("WARNING: %s but found Pronunciation subsection, don't know how to handle" %
          deletable_subsec_text)
      return

    notes.append("%s for bad %s form(s) of %s, leaving some subsections remaining" % (
      deletable_subsec_note_text, lang_to_langname[lang], lemma))
    text = "".join(sections)

  return text, notes

def delete_form(index, lemma, formind, formval, lang, save, verbose, diff):
  def pagemsg(txt):
    msg("Page %s %s: form %s %s: %s" % (index, lemma, formind, formval, txt))

  if "[" in formval:
    pagemsg("Skipping form value %s with link in it" % formval)
    return

  page = pywikibot.Page(site, formval)
  if not page.exists():
    pagemsg("Skipping form value %s, page doesn't exist" % formval)
    return

  def do_delete_form_1(page, index, parsed):
    return delete_form_1(page, index, lemma, formind, formval, lang)
  blib.do_edit(page, index, do_delete_form_1, save=save, verbose=verbose,
      diff=diff)

def process_page(index, lemma, forms, lang, pages_to_delete, save, verbose, diff):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, lemma, txt))
  def errandpagemsg(txt):
    errandmsg("Page %s %s: %s" % (index, lemma, txt))
  def expand_text(tempcall):
    return blib.expand_text(tempcall, lemma, pagemsg, verbose)

  pagemsg("Processing")

  for formind, form in blib.iter_items(forms):
    delete_form(index, lemma, formind, form, lang, save, verbose, diff)

parser = blib.create_argparser("Delete bad forms for inflected languages")
parser.add_argument('--formfile', help="File containing lemmas and forms to delete.", required=True)
parser.add_argument('--lang', help="Language ('es' or 'it').", choices=["es", "it"], required=True)
parser.add_argument('--output-pages-to-delete', help="File to write pages to delete.")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

pages_to_delete = []
for index, line in blib.iter_items_from_file(args.formfile, start, end):
  lemma, forms = re.split(": *", line)
  forms = re.split(", *", forms)
  process_page(index, lemma, forms, args.lang, pages_to_delete, args.save, args.verbose, args.diff)

msg("The following pages need to be deleted:")
for page in pages_to_delete:
  msg(page)
if args.output_pages_to_delete:
  with open(args.output_pages_to_delete, "w", encoding="utf-8") as fp:
    for page in pages_to_delete:
      print(page, file=fp)
