#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, errandmsg, site, tname, pname

import lalib

parts_to_tags = {
  # parts for verbs
  '1s': ['1', 's'],
  '2s': ['2', 's'],
  '3s': ['3', 's'],
  '1p': ['1', 'p'],
  '2p': ['2', 'p'],
  '3p': ['3', 'p'],
  'actv': ['act'],
  'pasv': ['pass'],
  'pres': ['pres'],
  'impf': ['impf'],
  'futr': ['fut'],
  'perf': ['perf'],
  'plup': ['plup'],
  'futp': ['fut', 'perf'],
  'indc': ['ind'],
  'subj': ['sub'],
  'impr': ['imp'],
  'inf': ['inf'],
  'ptc': ['part'],
  'ger': ['ger'],
  'sup': ['sup'],
  'nom': ['nom'],
  'gen': ['gen'],
  'dat': ['dat'],
  'acc': ['acc'],
  'abl': ['abl'],
  # additional parts for adjectives
  'voc': ['voc'],
  'sg': ['s'],
  'pl': ['p'],
  'm': ['m'],
  'f': ['f'],
  'n': ['n'],
}

tags_to_canonical = {
  'first-person': '1',
  'second-person': '2',
  'third-person': '3',
  'sg': 's',
  'singular': 's',
  'pl': 'p',
  'plural': 'p',
  'actv': 'act',
  'active': 'act',
  'pasv': 'pass',
  'passive': 'pass',
  'imperf': 'impf',
  'imperfect': 'impf',
  'futr': 'fut',
  'future': 'fut',
  'perfect': 'perf',
  'pluperf': 'plup',
  'pluperfect': 'plup',
  'indc': 'ind',
  'indic': 'ind',
  'indicative': 'ind',
  'subj': 'sub',
  'subjunctive': 'sub',
  'impr': 'imp',
  'impv': 'imp',
  'imperative': 'imp',
  'infinitive': 'inf',
  'ptcp': 'part',
  'participle': 'part',
  'gerund': 'ger',
  'supine': 'sup',
  'nominative': 'nom',
  'genitive': 'gen',
  'dative': 'dat',
  'accusative': 'acc',
  'ablative': 'abl',
  'vocative': 'voc',
  'masculine': 'm',
  'feminine': 'f',
  'neuter': 'n',
}

semicolon_tags = [';', ';<!--\n-->']

def split_tags_into_tag_sets(tags):
  tag_set_group = []
  cur_tag_set = []
  for tag in tags:
    if tag in semicolon_tags:
      if cur_tag_set:
        tag_set_group.append(cur_tag_set)
      cur_tag_set = []
    else:
      cur_tag_set.append(tag)
  if cur_tag_set:
    tag_set_group.append(cur_tag_set)
  return tag_set_group

def combine_tag_set_group(group):
  result = []
  for tag_set in group:
    if result:
      result.append(";")
    result.extend(tag_set)
  return result

def canonicalize_tag_set(tag_set):
  new_tag_set = []
  for tag in tag_set:
    new_tag_set.append(tags_to_canonical.get(tag, tag))
  return new_tag_set

def delete_participle(index, lemma, formind, formval, pos, save, verbose):
  notes = []

  def pagemsg(txt):
    msg("Page %s %s: form %s %s: %s" % (index, lemma, formind, formval, txt))
  def errandpagemsg(txt):
    errandmsg("Page %s %s: form %s %s: %s" % (index, lemma, formind, formval, txt))
  def expand_text(tempcall):
    return blib.expand_text(tempcall, lalib.remove_macrons(formval), pagemsg, verbose)

  if "[" in formval:
    pagemsg("Skipping form value %s with link in it" % formval)
    return

  page = pywikibot.Page(site, lalib.remove_macrons(formval))
  if not page.exists():
    pagemsg("Skipping form value %s, page doesn't exist" % formval)
    return

  if pos == "presactpart":
    expected_head_template = "la-present participle"
    expected_decl_template = "la-decl-3rd-part"
  elif pos == "futactpart":
    expected_head_template = "la-future participle"
    expected_decl_template = "la-decl-1&2"
  elif pos == "perfpasspart":
    expected_head_template = "la-perfect participle"
    expected_decl_template = "la-decl-1&2"
  elif pos == "futpasspart":
    expected_head_template = "la-gerundive"
    expected_decl_template = "la-decl-1&2"
  else:
    raise ValueError("Unrecognized part of speech %s" % pos)

  text = unicode(page.text)
  origtext = text

  retval = lalib.find_latin_section(text, pagemsg)
  if retval is None:
    return

  sections, j, secbody, sectail, has_non_latin = retval

  subsections = re.split("(^==+[^=\n]+==+\n)", secbody, 0, re.M)
  saw_lemma_in_etym = False
  saw_wrong_lemma_in_etym = False
  saw_head = False
  infl_template = None
  saw_bad_template = False
  for k in xrange(2, len(subsections), 2):
    parsed = blib.parse_text(subsections[k])
    for t in parsed.filter_templates():
      tn = tname(t)
      if tn == "m" and "==Etymology==" in subsections[k - 1]:
        actual_lemma = getparam(t, "2")
        if lalib.remove_macrons(lemma) == lalib.remove_macrons(actual_lemma):
          saw_lemma_in_etym = True
        else:
          pagemsg("WARNING: Saw wrong lemma %s != %s in Etymology section: %s" % (
            actual_lemma, lemma, unicode(t)))
          saw_wrong_lemma_in_etym = True
      elif tn == expected_head_template:
        saw_head = True
      elif tn == expected_decl_template:
        if not saw_head:
          pagemsg("WARNING: Saw inflection template without (or before) head template, skipping: %s" %
            unicode(t))
        elif infl_template:
          pagemsg("WARNING: Saw two possible inflection templates: first %s, second %s" % (
            infl_template, unicode(t)))
        else:
          infl_template = unicode(t)
      elif tn in ["rfdef"]:
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
    return

  args = lalib.generate_adj_forms(infl_template, errandpagemsg, expand_text)
  if args is None:
    return
  single_forms_to_delete = []
  for key, form in args.iteritems():
    single_forms_to_delete.extend(form.split(","))
  for formformind, formformval in blib.iter_items(single_forms_to_delete):
    delete_form(index, formval, formformind, formformval, "partform", True,
        save, verbose)

  #### Now, we can maybe delete the whole section or page

  if subsections[0].strip():
    pagemsg("WARNING: Whole Latin section deletable except that there's text above all subsections: <%s>" % subsections[0].strip())
    return
  if "[[Category:" in sectail:
    pagemsg("WARNING: Whole Latin section deletable except that there's a category at the end: <%s>" % sectail.strip())
    return
  if not has_non_latin:
    # Can delete the whole page, but check for non-blank section 0
    cleaned_sec0 = re.sub("^\{\{also\|.*?\}\}\n", "", sections[0])
    if cleaned_sec0.strip():
      pagemsg("WARNING: Whole page deletable except that there's text above all sections: <%s>" % cleaned_sec0.strip())
      return
    pagetitle = unicode(page.title())
    pagemsg("Page %s should be deleted" % pagetitle)
    pages_to_delete.append(pagetitle)
    return
  del sections[j]
  del sections[j-1]
  notes.append("removed Latin section for bad participle")
  if j > len(sections):
    # We deleted the last section, remove the separator at the end of the
    # previous section.
    sections[-1] = re.sub(r"\n+--+\n*\Z", "", sections[-1])
  text = "".join(sections)

  if text != origtext:
    if verbose:
      pagemsg("Replacing <%s> with <%s>" % (origtext, text))
    assert notes
    comment = "; ".join(blib.group_notes(notes))
    if save:
      pagemsg("Saving with comment = %s" % comment)
      page.text = text
      page.save(comment=comment)
    else:
      pagemsg("Would save with comment = %s" % comment)


def delete_form(index, lemma, formind, formval, pos, tag_sets_to_delete, save, verbose):
  notes = []

  def pagemsg(txt):
    msg("Page %s %s: form %s %s: %s" % (index, lemma, formind, formval, txt))
  def errandpagemsg(txt):
    errandmsg("Page %s %s: form %s %s: %s" % (index, lemma, formind, formval, txt))

  if "[" in formval:
    pagemsg("Skipping form value %s with link in it" % formval)
    return

  page = pywikibot.Page(site, lalib.remove_macrons(formval))
  if not page.exists():
    pagemsg("Skipping form value %s, page doesn't exist" % formval)
    return

  if pos == "verbform":
    expected_head_template = "la-verb-form"
    expected_header_pos = "Verb"
  elif pos == "partform":
    expected_head_template = "la-part-form"
    expected_header_pos = "Participle"
  else:
    raise ValueError("Unrecognized part of speech %s" % pos)

  text = unicode(page.text)
  origtext = text

  retval = lalib.find_latin_section(text, pagemsg)
  if retval is None:
    return

  sections, j, secbody, sectail, has_non_latin = retval

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
      if tn == expected_head_template:
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
          return
        actual_lemma = getparam(t, str(lemma_param))
        # Allow mismatch in macrons, which often happens, e.g. because
        # a macron was added to the lemma page but not to the inflections
        if lalib.remove_macrons(actual_lemma) == lalib.remove_macrons(lemma):
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
            tag_sets = split_tags_into_tag_sets(tags)
            for tag_set in tag_sets:
              if tag_sets_to_delete is True or frozenset(canonicalize_tag_set(tag_set)) in tag_sets_to_delete:
                saw_infl = True
              else:
                pagemsg("Found {{inflection of}} for correct lemma but wrong tag set %s: %s" % (
                  "|".join(tag_set), unicode(t)))
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
        if tn not in [expected_head_template, "inflection of"]:
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
          if lalib.remove_macrons(actual_lemma) == lalib.remove_macrons(lemma):
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
            tag_sets = split_tags_into_tag_sets(tags)
            filtered_tag_sets = []
            for tag_set in tag_sets:
              if tag_sets_to_delete is not True and frozenset(canonicalize_tag_set(tag_set)) not in tag_sets_to_delete:
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
            for tag in combine_tag_set_group(filtered_tag_sets):
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

  if len(subsections) == 1:
    # Whole section deletable
    if subsections[0].strip():
      pagemsg("WARNING: Whole Latin section deletable except that there's text above all subsections: <%s>" % subsections[0].strip())
      return
    if "[[Category:" in sectail:
      pagemsg("WARNING: Whole Latin section deletable except that there's a category at the end: <%s>" % sectail.strip())
      return
    if not has_non_latin:
      # Can delete the whole page, but check for non-blank section 0
      cleaned_sec0 = re.sub("^\{\{also\|.*?\}\}\n", "", sections[0])
      if cleaned_sec0.strip():
        pagemsg("WARNING: Whole page deletable except that there's text above all sections: <%s>" % cleaned_sec0.strip())
        return
      pagetitle = unicode(page.title())
      pagemsg("Page %s should be deleted" % pagetitle)
      pages_to_delete.append(pagetitle)
      return
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
      return
    if "==Pronunciation" in sections[j]:
      pagemsg("WARNING: %s but found Pronunciation subsection, don't know how to handle" %
          deletable_subsec_text)
      return

    notes.append("%s for bad Latin forms, leaving some subsections remaining" %
      deletable_subsec_note_text)
    text = "".join(sections)

  if text != origtext:
    if verbose:
      pagemsg("Replacing <%s> with <%s>" % (origtext, text))
    assert notes
    comment = "; ".join(blib.group_notes(notes))
    if save:
      pagemsg("Saving with comment = %s" % comment)
      page.text = text
      page.save(comment=comment)
    else:
      pagemsg("Would save with comment = %s" % comment)

def form_key_to_tag_set(key):
  parts = key.split("_")
  tags = []
  for part in parts:
    tags.extend(parts_to_tags[part])
  return frozenset(tags)

def process_page(index, lemma, conj, forms, pages_to_delete, save, verbose):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, lemma, txt))
  def errandpagemsg(txt):
    errandmsg("Page %s %s: %s" % (index, lemma, txt))
  def expand_text(tempcall):
    return blib.expand_text(tempcall, lalib.remove_macrons(lemma), pagemsg, verbose)

  pagemsg("Processing")

  args = lalib.generate_verb_forms(conj, errandpagemsg, expand_text)
  if args is None:
    return

  forms_to_delete = []
  tag_sets_to_delete = []

  for form in forms.split(","):
    if form in args:
      tag_sets_to_delete.append(form_key_to_tag_set(form))
      forms_to_delete.append((form, args[form]))
    if form == "all":
      for key, val in args.iteritems():
        tag_sets_to_delete.append(form_key_to_tag_set(key))
        forms_to_delete.append((key, val))
    if form in ["pasv", "pass"]:
      for key, val in args.iteritems():
        if key != "perf_pasv_ptc" and "pasv" in key:
          tag_sets_to_delete.append(form_key_to_tag_set(key))
          forms_to_delete.append((key, val))
    if form == "passnofpp":
      for key, val in args.iteritems():
        if key != "perf_pasv_ptc" and key != "futr_pasv_ptc" and "pasv" in key:
          tag_sets_to_delete.append(form_key_to_tag_set(key))
          forms_to_delete.append((key, val))
    if form == "perf":
      for key, val in args.iteritems():
        if key not in ["perf_actv_ptc", "perf_pasv_ptc"] and re.search("(perf|plup|futp)", key):
          tag_sets_to_delete.append(form_key_to_tag_set(key))
          forms_to_delete.append((key, val))
    if form in ["perf-pasv", "perf-pass"]:
      for key, val in args.iteritems():
        if "perf" in key and "pasv" in key:
          tag_sets_to_delete.append(form_key_to_tag_set(key))
          forms_to_delete.append((key, val))
    if form == "sup":
      for key, val in args.iteritems():
        if "sup" in key or key in ["perf_actv_ptc", "perf_pasv_ptc", "futr_actv_ptc"]:
          tag_sets_to_delete.append(form_key_to_tag_set(key))
          forms_to_delete.append((key, val))
    if form == "ger":
      for key, val in args.iteritems():
        if "ger" in key:
          tag_sets_to_delete.append(form_key_to_tag_set(key))
          forms_to_delete.append((key, val))

  single_forms_to_delete = []

  for key, form in forms_to_delete:
    for single_form in form.split(","):
      single_forms_to_delete.append((key, single_form))
  for formind, (key, formval) in blib.iter_items(single_forms_to_delete,
      get_name=lambda x: x[1]):
    partpos = None
    if key == "pres_actv_ptc":
      partpos = "presactpart"
    elif key in ["perf_actv_ptc", "perf_pasv_ptc"]:
      partpos = "perfpasspart"
    elif key == "futr_actv_ptc":
      partpos = "futactpart"
    elif key == "futr_pasv_ptc":
      partpos = "futpasspart"

    if partpos:
      delete_participle(index, lemma, formind, formval, partpos, save, verbose)
    else:
      delete_form(index, lemma, formind, formval, "verbform", tag_sets_to_delete, save, verbose)

parser = blib.create_argparser(u"Delete bad Latin forms")
parser.add_argument('--conjfile', help="File containing lemmas and conj templates.")
parser.add_argument('--form-conjfile', help="File containing lemmas, forms to delete and conj templates.")
parser.add_argument('--forms', help="Forms to delete.")
parser.add_argument('--output-pages-to-delete', help="File to write pages to delete.")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

pages_to_delete = []
if args.form_conjfile:
  lines = [x.strip() for x in codecs.open(args.form_conjfile, "r", "utf-8")]
  for index, line in blib.iter_items(lines, start, end):
    if "!!!" in line:
      lemma, forms, conj = re.split("!!!", line)
    else:
      lemma, forms, conj = re.split(" ", line, 2)
    process_page(index, lemma, conj, forms, pages_to_delete,
      args.save, args.verbose)
else:
  if not args.conjfile or not args.forms:
    raise ValueError("If --form-conjfile not given, --conjfile and --forms must be given")
  lines = [x.strip() for x in codecs.open(args.conjfile, "r", "utf-8")]
  for index, line in blib.iter_items(lines, start, end):
    if "!!!" in line:
      lemma, conj = re.split("!!!", line)
    else:
      lemma, conj = re.split(" ", line, 1)
    process_page(index, lemma, conj, args.forms, pages_to_delete,
      args.save, args.verbose)
msg("The following pages need to be deleted:")
for page in pages_to_delete:
  msg(page)
if args.output_pages_to_delete:
  with codecs.open(args.output_pages_to_delete, "w", "utf-8") as fp:
    for page in pages_to_delete:
      print >> fp, page
