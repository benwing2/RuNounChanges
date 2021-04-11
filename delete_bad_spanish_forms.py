#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, errandmsg, site, tname, pname

def delete_form_1(page, index, lemma, formind, formval):
  notes = []

  def pagemsg(txt):
    msg("Page %s %s: form %s %s: %s" % (index, lemma, formind, formval, txt))
  def errandpagemsg(txt):
    errandmsg("Page %s %s: form %s %s: %s" % (index, lemma, formind, formval, txt))

  text = unicode(page.text)
  origtext = text

  retval = blib.find_modifiable_lang_section(text, "Spanish", pagemsg)
  if retval is None:
    return None, None

  sections, j, secbody, sectail, has_non_spanish = retval

  # FIXME!

  #if "==Etymology 1==" in secbody:
  #  etym_sections = re.split("(^===Etymology [0-9]+===\n)", secbody, 0, re.M)
  #  for k in xrange(2, len(etym_sections), 2):
  #    etym_sections[k] = fix_up_section(etym_sections[k], warn_on_multiple_heads=True)
  #  secbody = "".join(etym_sections)

  subsections_to_delete = []
  subsections_to_remove_inflections_from = []

  subsections = re.split("(^==+[^=\n]+==+\n)", secbody, 0, re.M)
  for k in xrange(2, len(subsections), 2):
    parsed = blib.parse_text(subsections[k])
    saw_head = False
    saw_infl = False
    saw_other_infl = False
    remove_deletable_tag_sets_from_subsection = False
    saw_bad_template = False
    for t in parsed.filter_templates():
      tn = tname(t)
      if tn == "head" and getparam(t, "1") == "es" and getparam(t, "2") == "verb form":
        saw_head = True
      elif tn == "inflection of":
        lang = getparam(t, "1")
        if lang != "es":
          errandpagemsg("WARNING: In Spanish section, found {{inflection of}} for different language %s: %s" % (
            lang, unicode(t)))
          return None, None
        actual_lemma = getparam(t, "2")
        if actual_lemma == lemma:
          saw_infl = True
        else:
          pagemsg("Found {{inflection of}} for different lemma %s: %s" % (
            actual_lemma, unicode(t)))
          saw_other_infl = True
      elif tn == "es-verb form of":
        actual_lemma = getparam(t, "1")
        if actual_lemma == lemma:
          saw_infl = True
        else:
          pagemsg("Found {{es-verb form of}} for different lemma %s: %s" % (
            actual_lemma, unicode(t)))
          saw_other_infl = True
    if saw_head and saw_infl:
      if saw_other_infl:
        pagemsg("Found subsection #%s to delete but has inflection-of or es-verb-form-of template for different lemma or nondeletable tag set, will remove only deletable tag sets" % (k // 2))
        remove_deletable_tag_sets_from_subsection = True
      for t in parsed.filter_templates():
        tn = tname(t)
        if tn not in ["es-verb form of", "inflection of"] and not (
            tn == "head" and getparam(t, "1") == "es" and getparam(t, "2") == "verb form"
          ):
          pagemsg("WARNING: Saw unrecognized template in otherwise deletable subsection #%s: %s" % (
            k // 2, unicode(t)))
          saw_bad_template = True
          break
      else:
        # No break
        if "===Verb===" in subsections[k - 1]:
          if remove_deletable_tag_sets_from_subsection:
            subsections_to_remove_inflections_from.append(k)
          else:
            subsections_to_delete.append(k)
        else:
          pagemsg("WARNING: Wrong header in otherwise deletable subsection #%s: %s" % (
            k // 2, subsections[k - 1].strip()))

  if not subsections_to_delete and not subsections_to_remove_inflections_from:
    pagemsg("Found Spanish section but no deletable or excisable subsections")
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
          lang = getparam(t, "1")
          assert lang == "es"
          actual_lemma = getparam(t, "2")
          if actual_lemma == lemma:
            return ""
        if tn == "es-verb form of":
          actual_lemma = getparam(t, "1")
          if actual_lemma == lemma:
            return ""
      return unicode(parsed)

    newnewsubsec = re.sub(r"^# \{\{inflection of\|[^{}\n]*\}\}\n", remove_inflections, newsubsec, 0, re.M)
    if newnewsubsec != newsubsec:
      notes.append("removed {{inflection of}} inflection(s) for bad Spanish form(s)")
      subsections[k] = newnewsubsec

    newnewsubsec = re.sub(r"^# \{\{es-verb form of\|[^{}\n]*\}\}\n", remove_inflections, newsubsec, 0, re.M)
    if newnewsubsec != newsubsec:
      notes.append("removed {{es-verb form of}} inflection(s) for bad Spanish form(s)")
      subsections[k] = newnewsubsec

  for k in reversed(subsections_to_delete):
    # Do in reverse order so indices don't change
    del subsections[k]
    del subsections[k - 1]

  if len(subsections) == 1 or len(subsections) == 3 and re.search("^==+References==+$", subsections[1].strip()):
    # Whole section deletable
    if subsections[0].strip():
      pagemsg("WARNING: Whole Spanish section deletable except that there's text above all subsections: <%s>" % subsections[0].strip())
      return None, None
    if "[[Category:" in sectail:
      pagemsg("WARNING: Whole Spanish section deletable except that there's a category at the end: <%s>" % sectail.strip())
      return None, None
    if not has_non_spanish:
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
    notes.append("excised %s subsection%s for bad Spanish forms, leaving no Spanish section" %
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

    notes.append("%s for bad Spanish forms, leaving some subsections remaining" %
      deletable_subsec_note_text)
    text = "".join(sections)

  return text, notes

def delete_form(index, lemma, formind, formval, save, verbose, diff):
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
    return delete_form_1(page, index, lemma, formind, formval)
  blib.do_edit(page, index, do_delete_form_1, save=save, verbose=verbose,
      diff=diff)

def process_page(index, lemma, forms, pages_to_delete, save, verbose, diff):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, lemma, txt))
  def errandpagemsg(txt):
    errandmsg("Page %s %s: %s" % (index, lemma, txt))
  def expand_text(tempcall):
    return blib.expand_text(tempcall, lemma, pagemsg, verbose)

  pagemsg("Processing")

  for formind, form in blib.iter_items(forms):
    delete_form(index, lemma, formind, form, save, verbose, diff)

parser = blib.create_argparser(u"Delete bad Spanish forms")
parser.add_argument('--formfile', help="File containing lemmas and forms to delete.", required=True)
parser.add_argument('--output-pages-to-delete', help="File to write pages to delete.")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

pages_to_delete = []
lines = [x.strip() for x in codecs.open(args.formfile, "r", "utf-8")]
for index, line in blib.iter_items(lines, start, end):
  if line.startswith("#"):
    continue
  lemma, forms = re.split(": *", line)
  forms = re.split(", *", forms)
  process_page(index, lemma, forms, pages_to_delete, args.save, args.verbose, args.diff)

msg("The following pages need to be deleted:")
for page in pages_to_delete:
  msg(page)
if args.output_pages_to_delete:
  with codecs.open(args.output_pages_to_delete, "w", "utf-8") as fp:
    for page in pages_to_delete:
      print >> fp, page
