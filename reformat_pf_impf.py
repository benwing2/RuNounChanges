#!/usr/bin/env python
# -*- coding: utf-8 -*-

# Reformat corresponding (im)perfective specs using {{pf}} or {{impf}}

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, errmsg, site

def process_page(index, page, save, verbose):
  pagetitle = unicode(page.title())
  subpagetitle = re.sub("^.*:", "", pagetitle)
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
  def errpagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
    errmsg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  if ":" in pagetitle:
    pagemsg("WARNING: Colon in page title, skipping page")
    return

  text = unicode(page.text)
  notes = []

  foundrussian = False
  sections = re.split("(^==[^=]*==\n)", text, 0, re.M)

  for j in xrange(2, len(sections), 2):
    if sections[j-1] == "==Russian==\n":
      if foundrussian:
        pagemsg("WARNING: Found multiple Russian sections, skipping page")
        return
      foundrussian = True

      # Try to convert multi-line usex using #:
      def generate_new_format_corverb(m):
        pfimpf = m.group(1)
        verbtext = m.group(2)
        verbs = re.split(" *(?:,|or) *", verbtext)
        newverbs = []
        for index, verb in enumerate(verbs):
          qual = ""
          if "only" in verb:
            verb = re.sub(" *only *", "", verb)
            qual = "only"
          if "also" in verb:
            verb = re.sub(" *also *", "", verb)
            qual = "also"
          if "{{i|low colloquial}} " in verb:
            verb = re.sub(r" *\{\{i\|low colloquial\}\} *", "", verb)
            qual = "low colloquial"
          if qual:
            qual = "|q%s=%s" % (index + 1, qual)
          m = re.search(r"^\[\[(.*)\]\]$", verb)
          if m:
            newverbs.append(m.group(1) + qual)
            continue
          m = re.search(r"^\{\{[ml]\|ru\|(.*)\}\}$", verb)
          if m:
            newverbs.append(m.group(1) + qual)
            continue
          pagemsg("WARNING: Unable to parse verb spec %s, treating as raw" % verb)
          newverbs.append(verb + qual)
        return "\n#: {{%s|ru|%s}}\n" % (pfimpf, "|".join(newverbs))
      sections[j] = re.sub(ur", *\{\{g\|(pf|impf)\}\} *[-–—:] * (.*)\n",
          generate_new_format_corverb, sections[j])
      # Repeatedly move {{pf}}/{{impf}} after usexes
      while True:
        replacement = re.sub(ur"\n(#: \{\{(?:pf|impf)\|.*?\}\}.*\n)(#\*?: \{\{ux.*?\}\}.*\n)",
            r"\n\2\1", sections[j])
        if replacement == sections[j]:
          break
        sections[j] = replacement
      if "{{g|pf}}" in sections[j] or "{{g|impf}}" in sections[j]:
        errpagemsg("WARNING: Found unconverted {{g|pf}} or {{g|impf}}")
      if " pf" in sections[j] or " impf" in sections[j]:
        errpagemsg("WARNING: Found unconverted pf or impf following a space")

  new_text = "".join(sections)

  if new_text != text:
    if verbose:
      pagemsg("Replacing <<%s>> with <<%s>>" % (text, new_text))
    notes = ["Reformatting Russian perfective/imperfective correspondences to use {{pf}}/{{impf}}"]
    comment = "; ".join(blib.group_notes(notes))
    if save:
      pagemsg("Saving with comment = %s" % comment)
      page.text = new_text
      page.save(comment=comment)
    else:
      pagemsg("Would save with comment = %s" % comment)

parser = blib.create_argparser("Reformat corresponding (im)perfective specs using {{pf}} or {{impf}}")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

for cat in ["Russian verbs"]:
  msg("Processing category %s" % cat)
  for i, page in blib.cat_articles(cat, start, end):
    process_page(i, page, args.save, args.verbose) 
