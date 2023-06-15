#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, errandmsg, site, tname, pname

import lalib

pages_to_delete = []

def delete_term(index, term, expected_head_templates, save, verbose):
  notes = []

  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, term, txt))
  page = pywikibot.Page(site, term)
  if not page.exists():
    pagemsg("Skipping form value %s, page doesn't exist" % term)
    return

  text = unicode(page.text)

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
  for k in range(2, len(subsections), 2):
    parsed = blib.parse_text(subsections[k])
    for t in parsed.filter_templates():
      tn = tname(t)
      if tn in expected_head_templates:
        saw_head = True
      elif tn in ["inflection of", "rfdef", "la-IPA"]:
        pass
      else:
        pagemsg("WARNING: Saw unrecognized template in subsection #%s %s: %s" % (
          k // 2, subsections[k - 1].strip(), unicode(t)))
        saw_bad_template = True

  delete = False
  if saw_head:
    if saw_bad_template:
      pagemsg("WARNING: Would delete but saw unrecognized template, not deleting")
    else:
      delete = True

  if not delete:
    return

  if "==Etymology" in sections[j]:
    pagemsg("WARNING: Found Etymology subsection, don't know how to handle")
    return
  if "==Pronunciation " in sections[j]:
    pagemsg("WARNING: Found Pronunciation N subsection, don't know how to handle")
    return

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
  notes.append("removed Latin section for bad term")
  if j > len(sections):
    # We deleted the last section, remove the separator at the end of the
    # previous section.
    sections[-1] = re.sub(r"\n+--+\n*\Z", "", sections[-1])
  text = "".join(sections)

  return text, notes

parser = blib.create_argparser(u"Delete bad Latin terms", include_pagefile=True)
parser.add_argument('--headtemp', required=True, help="Name(s) of expected headword template(s).")
parser.add_argument('--output-pages-to-delete', help="File to write pages to delete.")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

headtemp = blib.split_utf8_arg(args.headtemp)

def process_page(page, index, parsed):
  return delete_term(index, page, headtemp)

blib.do_pagefile_cats_refs(args, start, end, process_page, edit=True)

msg("The following pages need to be deleted:")
for page in pages_to_delete:
  msg(page)
if args.output_pages_to_delete:
  with codecs.open(args.output_pages_to_delete, "w", "utf-8") as fp:
    for page in pages_to_delete:
      print >> fp, page
