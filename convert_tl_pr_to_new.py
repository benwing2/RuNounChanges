#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse, unicodedata

import blib
from blib import getparam, rmparam, msg, errandmsg, site, tname, pname, rsub_repeatedly

recogized_poses = {
  "noun": "n",
  "verb": "v",
  "adjective": "a",
  "adverb": "adv",
  "preposition": "prep",
  "interjection": "int",
}

def process_text_on_page(index, pagetitle, text):
  global args
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
  def expand_text(tempcall):
    return blib.expand_text(tempcall, pagetitle, pagemsg, args.verbose)

  notes = []
  parsed = blib.parse_text(text)
  for t in parsed.filter_templates():
    tn = tname(t)
    if tn == "tl-pr":
      origt = str(t)
      def getp(param):
        return getparam(t, param).strip()
      def get_chain(first, pref=None, firstdefault="", holes="close"):
        ret = blib.fetch_param_chain(t, first, pref=pref, firstdefault=firstdefault, holes=holes)
        return [x.strip() if x is not None else x for x in ret]
      if getp("new"):
        continue
      specs = []
      hyphs = None
      try:
        if getp("2"):
          # 1=, 2=, ... are hyphenation
          raw_hyphs = get_chain("1", holes="allow")
          hyph_syls = []
          hyphs = []
          must_continue = False
          for syl in raw_hyphs:
            if not syl:
              if not hyph_syls:
                pagemsg("WARNING: Saw blank hyphenation argument initially or after another blank argument: %s" %
                        str(t))
                must_continue = True
                break
              else:
                hyphs.append(".".join(hyph_syls))
                hyph_syls = []
            else:
              hyph_syls.append(syl)
          if must_continue:
            continue
          if hyph_syls:
            hyphs.append(".".join(hyph_syls))
          else:
            pagemsg("WARNING: Saw blank hyphenation argument finally: %s" % str(t))
            continue
          prons = get_chain("IPA")
        else:
          prons = get_chain(["1", "IPA"], "IPA", holes="allow")
        audios = get_chain("audio", holes="allow")
        audioqs = get_chain("audioq", holes="allow")
        hmps = get_chain("hmp")
        hmpqs = get_chain("hmpq")
        a_s = get_chain("a", holes="allow")
        qs = get_chain("q", holes="allow")
      except blib.ParameterError as e:
        pagemsg("WARNING: %s" % e)
        continue
      for i, pron in enumerate(prons):
        pron = pron or "+"
        m = re.search(r"^(/.*/), *(\[.*\])$", pron)
        if m:
          pron = "%s %s" % m.groups()
        if i < len(qs) and qs[i]:
          filtered_qs = []
          filtered_poses = []
          thisqs = re.split(r"\s*,\s*", qs[i])
          for thisq in thisqs:
            if thisq in recogized_poses:
              filtered_poses.append("<%s^>" % recogized_poses[thisq])
            else:
              filtered_qs.append(thisq)
          if filtered_qs:
            pron += "<qq:%s>" % ", ".join(filtered_qs)
          pron += "".join(filtered_poses)
        if i < len(a_s) and a_s[i]:
          pron += "<a:%s>" % a_s[i]
        if i < len(audios) and audios[i]:
          audioq_mod = "<q:%s>" % audioqs[i] if i < len(audioqs) and audioqs[i] else ""
          pron += "<audio:%s%s>" % (audios[i], audioq_mod)
        specs.append(pron)
      if specs == ["+"]:
        specs = []
      hmp_specs = []
      for i, hmp in enumerate(hmps):
        hmpq_mod = "<q:%s>" % hmpqs[i] if i < len(hmpqs) and hmpqs[i] else ""
        hmp_specs.append("%s%s" % (hmp, hmpq_mod))
      hmp_spec = ",".join(hmp_specs)
      if hyphs:
        hyphcap = getp("hyphcap")
        hyph_spec = ",".join(hyphs) + ("<cap:%s>" % hyphcap if hyphcap else "")
      else:
        hyph_spec = None
      del t.params[:]
      for i, spec in enumerate(specs):
        t.add(str(i + 1), spec)
      if hyph_spec:
        t.add("syll", hyph_spec)
      if hmp_spec:
        t.add("hmp", hmp_spec)
      t.add("new", "1")
      newt = str(t)
      if newt != origt:
        pagemsg("Replaced %s with %s" % (origt, newt))
        notes.append("convert {{tl-pr}} to new format")

  return str(parsed), notes

parser = blib.create_argparser("Convert {{tl-pr}} to new format", include_pagefile=True, include_stdin=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True)
