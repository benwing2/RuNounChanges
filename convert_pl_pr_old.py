#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse, unicodedata, json

import blib
from blib import getparam, rmparam, msg, errandmsg, site, tname, pname, rsub_repeatedly

langs = ["pl", "csb", "szl", "zlw-slv"]
pl_lects = [
    # Middle Polish
    "mpl",
    # Greater Poland
    "koc", "bor", "kra", "CD", "kuj", "NGP", "WGP", "CGP", "EGP", "SGP",
    # Masovia
    "lub", "ost", "war", "mas", "kur", "MB", "MD", "pdl", "suw", "low",
    # Lesser Poland
    "lec", "sie", "PM", "kie", "krk", "ekr", "las", "pdg", "bie", "WL", "EL", "prz",
    # Goral
    "sad", "zyw", "ora", "pod", "spi", "zag", "kli", "BG", "kys", "pie", "och", "lip",
    # Borderlands
    "sbl", "nbl",
    # New Mixed Dialects
    "nmd",
    # lect aliases
    "mp", "łow",
]


def process_text_on_page(index, pagetitle, text):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
  def expand_text(tempcall):
    return blib.expand_text(tempcall, pagetitle, pagemsg, args.verbose)

  notes = []

  parsed = blib.parse_text(text)
  templates_to_check = ["%s-pr/old" % lang for lang in langs]
  for t in parsed.filter_templates():
    tn = tname(t)
    if tn in templates_to_check:
      origt = str(t)
      def getp(param):
        return getparam(t, param)
      def getp_rm(param):
        val = getp(param)
        rmparam(t, param)
        return val
      respellings = blib.fetch_param_chain(t, "1")
      new_respellings = []
      for i, respelling in enumerate(respellings, start=1):
        ind = "" if i == 1 else str(i)
        qual = getp_rm("qual%s" % ind) or getp_rm("q%s" % ind)
        if qual:
          respelling += "<q:%s>" % qual
        ref = getp_rm("ref%s" % ind)
        if ref:
          respelling += "<ref:%s>" % ref
        if respelling:
          new_respellings.append(respelling)
      if new_respellings:
        blib.set_param_chain(t, [",".join(new_respellings)], "1")
      else:
        blib.remove_param_chain(t, "1")

      if tn == "pl-pr/old":
        for lect in pl_lects:
          respellings = blib.fetch_param_chain(t, lect)
          new_respellings = []
          for i, respelling in enumerate(respellings, start=1):
            ind = "" if i == 1 else str(i)
            qual = getp_rm("%s_qual%s" % (lect, ind)) or getp_rm("%s_q%s" % (lect, ind))
            if qual:
              respelling += "<q:%s>" % qual
            ref = getp_rm("%s_ref%s" % (lect, ind))
            if ref:
              respelling += "<ref:%s>" % ref
            if respelling:
              new_respellings.append(respelling)
          if new_respellings:
            blib.set_param_chain(t, [",".join(new_respellings)], lect)
          else:
            blib.remove_param_chain(t, lect)
      audios = getp("audios") or getp("a")
      if audios:
        audios = audios.split(";")
        new_audios = []
        for audio in audios:
          m = re.search("^(.*?)<([^<>]+)>$", audio)
          if m:
            before, caption = m.groups()
            new_audio = before
            if caption in ["#", "~"]:
              new_audio += "<text:%s>" % caption
            else:
              pagemsg("WARNING: Not sure how to handle old-style caption %s, needs review: %s" % (audio, origt))
              new_audio += "<cap:%s>" % caption
          else:
            new_audio = audio
          new_audios.append(new_audio)
        new_audio = ";".join(new_audios)
        if t.has("audios"):
          t.add("a", new_audio, before="audios")
          rmparam(t, "audios")
        else:
          t.add("a", new_audio)

      homophones = getp("homophones") or getp("hh")
      if homophones:
        if "<" in homophones:
          pagemsg("WARNING: Can't yet handle captions in homophones %s, skipping: %s" % (homophones, origt))
        else:
          homophones = homophones.replace(";", ",")
          if t.has("homophones"):
            t.add("hh", homophones, before="homophones")
            rmparam(t, "homophones")
          else:
            t.add("hh", homophones)
      newt = str(t)
      blib.set_template_name(t, tn[:-4]) # chop off /old
      if newt != origt:
        pagemsg("Replace %s with %s" % (origt, str(t)))
        notes.append("rename {{%s}} to {{%s}} and update arguments to new syntax" % (tn, tname(t)))
      else:
        notes.append("rename {{%s}} to {{%s}}, syntax already new" % (tn, tname(t)))

  return str(parsed), notes

parser = blib.create_argparser("Convert {{pl-pr/old}} to {{pl-pr}} and similarly for other Lechitic langs", include_pagefile=True, include_stdin=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True)
