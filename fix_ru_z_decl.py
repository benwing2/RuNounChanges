#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site

import rulib as ru

def process_page(index, page, save, verbose):
  pagetitle = unicode(page.title())
  subpagetitle = re.sub(".*:", "", pagetitle)
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  parsed = blib.parse(page)

  for t in parsed.filter_templates():
    if unicode(t.name) == "ru-decl-noun-z":
      # {{ru-decl-noun-z|звезда́|f-in|d|ё}}
      # {{ru-decl-noun-z|ёж|m-inan|b}}
      zlemma = getparam(t, "1")
      zgender_anim = getparam(t, "2")
      zstress = getparam(t, "3")
      zspecial = getparam(t, "4")
      m = re.search(r"^([mfn])-(an|in|inan)$", zgender_anim)
      if not m:
        pagemsg("Unable to recognize z-decl gender/anim spec, skipping: %s" %
            zgender_anim)
        return
      zgender, zanim = m.groups()
      zspecial = zgender + re.sub(u"ё", u";ё", zspecial)
      # FIXME, properly we should check whether the gender is actually
      # needed and leave it off if not
      decl_template.add("3", zspecial)
      if zanim == "an":
        decl_template.add("a", "an")
      elif zanim == "inan":
        # FIXME, properly we should convert to either ai or ia depending
        # on the order of genders in the headword; this will have to
        # be a task for the script that converts z-decl to regular decl
        decl_template.add("a", "bi")
      # FIXME, save/convert overrides; but don't seem to be any in the
      # few words with zdecl (звезда, ёж)
      params_to_preserve = []
      for param in decl_z_template.params:
        name = unicode(param.name)
        if name not in ["1", "2", "3", "4"]:
          pagemsg("WARNING: Found named or extraneous numbered params in z-decl for word #%s, can't handle yet, skipping: %s, lemma=%s, infl=%s" %
              (wordind, unicode(decl_z_template), lemma, infl))
          return None
      decl_templates = [decl_template]

      FIXME

  comment = "Replace ru-decl-noun-z with ru-noun-table"
  if save:
    pagemsg("Saving with comment = %s" % comment)
    page.text = unicode(parsed)
    page.save(comment=comment)
  else:
    pagemsg("Would save with comment = %s" % comment)

parser = blib.create_argparser("Convert ru-decl-noun-z into ru-noun-table")
args = parser.parse_args()
start, end = blib.get_args(args.start, args.end)

for index, page in blib.references("Template:ru-decl-noun-z", start, end):
  process_page(index, page, args.save, args.verbose)
