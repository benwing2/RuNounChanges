#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, errandmsg, site, tname, pname

demacron_mapper = {
  u'ā': 'a',
  u'ē': 'e',
  u'ī': 'i',
  u'ō': 'o',
  u'ū': 'u',
  u'ȳ': 'y',
  u'Ā': 'A',
  u'Ē': 'E',
  u'Ī': 'I',
  u'Ō': 'O',
  u'Ū': 'U',
  u'Ȳ': 'Y',
  u'ă': 'a',
  u'ĕ': 'e',
  u'ĭ': 'i',
  u'ŏ': 'o',
  u'ŭ': 'u',
  # no composed breve-y
  u'Ă': 'A',
  u'Ĕ': 'E',
  u'Ĭ': 'I',
  u'Ŏ': 'O',
  u'Ŭ': 'U',
  # combining breve
  u'\u0306': '',
  u'ë': 'e',
  u'Ë': 'E',
}

parts_to_tags = {
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
}

def remove_macrons(text):
  return re.sub(u'([āēīōūȳĀĒĪŌŪȲăĕĭŏŭĂĔĬŎŬ\u0306ëË])', lambda m: demacron_mapper[m.group(1)], text)

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

def canonicalize_tag_set(tag_set):
  new_tag_set = []
  for tag in tag_set:
    new_tag_set.append(tags_to_canonical.get(tag, tag))
  return new_tag_set

def process_page(index, lemma, conj, forms, pages_to_delete, save, verbose):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, lemma, txt))
  def errandpagemsg(txt):
    errandmsg("Page %s %s: %s" % (index, lemma, txt))
  def expand_text(tempcall):
    return blib.expand_text(tempcall, lemma, pagemsg, verbose)

  pagemsg("Processing")

  if conj.startswith("{{la-conj-3rd-IO|"):
    generate_template = re.sub(r"^\{\{la-conj-3rd-IO\|", "{{la-generate-verb-forms|conjtype=3rd-io|", conj)
  else:
    generate_template = re.sub(r"^\{\{la-conj-(.*?)\|", r"{{la-generate-verb-forms|conjtype=\1|", conj)
  if not generate_template.startswith("{{la-generate-verb-forms|"):
    errandpagemsg("Template %s not a recognized conjugation template" % conj)
    return
  result = expand_text(generate_template)
  if not result:
    errandpagemsg("WARNING: Error generating forms, skipping")
    return
  args = blib.split_generate_args(result)

  def delete_form(formind, formval, tag_sets_to_delete):
    notes = []

    def pagemsg(txt):
      msg("Page %s %s: form %s %s: %s" % (index, lemma, formind, formval, txt))

    def errandpagemsg(txt):
      errandmsg("Page %s %s: form %s %s: %s" % (index, lemma, formind, formval, txt))

    if "[" in formval:
      pagemsg("Skipping form value %s with link in it" % formval)
      return
    page = pywikibot.Page(site, remove_macrons(formval))
    if not page.exists():
      pagemsg("Skipping form value %s, page doesn't exist" % formval)
      return

    text = unicode(page.text)
    origtext = text
    sections = re.split("(^==[^=]*==\n)", text, 0, re.M)

    has_non_latin = False

    latin_j = -1
    for j in xrange(2, len(sections), 2):
      if sections[j-1] != "==Latin==\n":
        has_non_latin = True
      else:
        if latin_j >= 0:
          pagemsg("WARNING: Found two Latin sections, skipping")
          return
        latin_j = j
    if latin_j < 0:
      pagemsg("Can't find Latin section, skipping")
      return
    j = latin_j

    # Extract off trailing separator
    mm = re.match(r"^(.*?\n)(\n*--+\n*)$", sections[j], re.S)
    if mm:
      # Note that this changes the number of sections, which is seemingly
      # a problem because the for-loop above calculates the end point
      # at the beginning of the loop, but is not actually a problem
      # because we always break after processing the Russian section.
      secbody, sectail = mm.group(1), mm.group(2)
    else:
      secbody = sections[j]
      sectail = ""

    # Split off categories at end
    mm = re.match(r"^(.*?\n)(\n*(\[\[Category:[^\]]+\]\]\n*)*)$",
        secbody, re.S)
    if mm:
      # See comment above.
      secbody, secbodytail = mm.group(1), mm.group(2)
      sectail = secbodytail + sectail

    subsections_to_delete = []

    subsections = re.split("(^==+[^=\n]+==+\n)", secbody, 0, re.M)
    for k in xrange(2, len(subsections), 2):
      parsed = blib.parse_text(subsections[k])
      saw_head = False
      saw_infl = False
      saw_other_infl = False
      saw_bad_template = False
      for t in parsed.filter_templates():
        tn = tname(t)
        if tn == "la-verb-form":
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
          if remove_macrons(actual_lemma) == remove_macrons(lemma):
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
                if frozenset(canonicalize_tag_set(tag_set)) in tag_sets_to_delete:
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
          pagemsg("WARNING: Found subsection #%s to delete but has inflection-of template for different lemma" % (k // 2))
          continue
        for t in parsed.filter_templates():
          tn = tname(t)
          if tn not in ["la-verb-form", "inflection of"]:
            pagemsg("WARNING: Saw unrecognized template in otherwise deletable subsection #%s: %s" % (
              k // 2, unicode(t)))
            saw_bad_template = True
            break
        else:
          # No break
          if "===Verb===" in subsections[k - 1]:
            subsections_to_delete.append(k)
          else:
            pagemsg("WARNING: Wrong header in otherwise deletable subsection #%s: %s" % (
              k // 2, subsections[k - 1].strip()))
    if not subsections_to_delete:
      pagemsg("Found Latin section but no deletable subsections")
      return

    #### Now, we can delete a subsection or the whole section or page

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
      if "==Etymology" in sections[j]:
        pagemsg("WARNING: Subsection(s) %s deletable but found Etymology subsection, don't know how to handle" %
            ",".join(k//2 for k in subsections_to_delete))
        return
      if "==Pronunciation" in sections[j]:
        pagemsg("WARNING: Subsection(s) %s deletable but found Pronunciation subsection, don't know how to handle" %
            ",".join(k//2 for k in subsections_to_delete))
        return
      notes.append("excised %s subsection%s for bad Latin forms, leaving some subsections remaining" %
        (len(subsections_to_delete), "" if len(subsections_to_delete) == 1 else "s"))
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

  forms_to_delete = []
  tag_sets_to_delete = []

  for form in forms.split(","):
    if form in args:
      tag_sets_to_delete.append(form_key_to_tag_set(form))
      forms_to_delete.append(args[form])
    if form in ["pasv", "pass"]:
      for key, val in args.iteritems():
        if "pasv" in key:
          tag_sets_to_delete.append(form_key_to_tag_set(key))
          forms_to_delete.append(val)
    if form == "perf":
      for key, val in args.iteritems():
        if re.search("(perf|plup|futp)", key):
          tag_sets_to_delete.append(form_key_to_tag_set(key))
          forms_to_delete.append(val)
    if form in ["perf-pasv", "perf-pass"]:
      for key, val in args.iteritems():
        if "perf" in key and "pasv" in key:
          tag_sets_to_delete.append(form_key_to_tag_set(key))
          forms_to_delete.append(val)

  single_forms_to_delete = []

  for form in forms_to_delete:
    single_forms_to_delete.extend(form.split(","))
  for formind, formval in blib.iter_items(single_forms_to_delete):
    delete_form(formind, formval, tag_sets_to_delete)

parser = blib.create_argparser(u"Delete bad Latin forms")
parser.add_argument('--conjfile', required=True, help="File containing lemmas and conj templates.")
parser.add_argument('--forms', required=True, help="Forms to delete.")
parser.add_argument('--output-pages-to-delete', help="File to write pages to delete.")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

lines = [x.strip() for x in codecs.open(args.conjfile, "r", "utf-8")]
pages_to_delete = []
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
