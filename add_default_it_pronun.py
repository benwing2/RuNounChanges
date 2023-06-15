#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse, json

import blib
from blib import getparam, rmparam, tname, pname, msg, errandmsg, site
import unicodedata

AC = u"\u0301"
GR = u"\u0300"
CFLEX = u"\0302"
vowel = u"AEIOUaeiouɛɔy"
vowel_c = "[" + vowel + "]"
vocalic_c = "[^" + vowel + "jw]"
not_vowel_c = "[^" + vowel + "]"
stress_c = "[" + AC + GR + "]"

def process_text_on_page(index, pagetitle, text):
  global args
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
  def errandpagemsg(txt):
    errandmsg("Page %s %s: %s" % (index, pagetitle, txt))
  def expand_text(tempcall):
    return blib.expand_text(tempcall, pagetitle, pagemsg, args.verbose)

  notes = []

  if "it-IPA" not in text:
    return

  if ":" in pagetitle:
    pagemsg("Skipping non-mainspace title")
    return

  pagemsg("Processing")

  parsed = blib.parse_text(text)

  headt = None
  saw_decl = False

  for t in parsed.filter_templates():
    origt = unicode(t)
    tn = tname(t)

    if tn == "it-IPA":
      pagemsg("Saw %s" % unicode(t))
      if getparam(t, "voiced2"):
        pagemsg("WARNING: Can't yet handle voiced2=%s" % getparam(t, "voiced2"))
        continue
      specified_pronuns = blib.fetch_param_chain(t, "1", "")
      pronuns = specified_pronuns or [pagetitle]
      frobbed_pronuns = []
      must_continue = False
      for ipa in pronuns:
        ipa = unicodedata.normalize("NFD", ipa)
        if AC not in ipa and GR not in ipa:
          vowel_count = len([x for x in ipa if x in vowel])
          if vowel_count == 1:
            pagemsg("WARNING: Single-vowel word")
          if vowel_count > 1:
            new_ipa = re.sub("(" + vowel_c + ")(" + not_vowel_c + "*[iyu]?" + vowel_c + not_vowel_c + "*)$",
                lambda m: m.group(1) + (AC if m.group(1) in u"eoɛɔ" else GR) + m.group(2), ipa)
            if new_ipa == ipa:
              pagemsg("WARNING: Unable to add stress: %s" % ipa)
            else:
              notes.append(unicodedata.normalize("NFC", "add stressed form %s to defaulted {{it-IPA}} pronun" %
                new_ipa))
              ipa = new_ipa
        if "z" in ipa:
          frobbed_ipa = re.sub("i(" + vowel_c + ")", r"j\1", ipa)
          frobbed_ipa = re.sub("u(" + vowel_c + ")", r"w\1", frobbed_ipa)
          split_frobbed_ipa = re.split("(z+)", frobbed_ipa)
          split_z = re.split("(z+)", ipa)
          voiced = getparam(t, "voiced")
          if voiced not in ["y", "yes", "1", ""]:
            pagemsg("WARNING: Unrecognized voiced=%s" % voiced)
            must_continue = True
            break
          for i in range(1, len(split_z), 2):
            if split_z[i - 1].endswith("d"):
              continue # already converted appropriately
            default_voiced = False
            if voiced in ["y", "yes"] or i == 1 and voiced == "1":
              default_voiced = True
            elif i == 1 and split_frobbed_ipa[0] == "":
              if re.search("^[ij]" + stress_c + "?" + vowel_c, split_frobbed_ipa[2]):
                default_voiced = False
              elif re.search("^" + vowel_c + stress_c + "?" + vowel_c, split_frobbed_ipa[2]):
                default_voiced = True
            else:
              if (split_frobbed_ipa[i] == "z" and
                  re.search(vowel_c + stress_c + "?$", split_frobbed_ipa[i - 1]) and
                  re.search("^" + vowel_c, split_frobbed_ipa[i + 1])):
                default_voiced = True
              if re.search("i" + CFLEX, split_frobbed_ipa[i + 1]):
                default_voiced = False
            if default_voiced:
              z_to_voiced = {"z": "dz", "zz": "ddz"}
              split_z[i] = z_to_voiced.get(split_z[i], split_z[i])
            else:
              z_to_voiceless = {"z": "ts", "zz": "tts"}
              split_z[i] = z_to_voiceless.get(split_z[i], split_z[i])
          new_ipa = "".join(split_z)
          if new_ipa != ipa:
            notes.append(unicodedata.normalize("NFC",
              "convert z to ts or dz in %s -> %s in {{it-IPA}}" % (ipa, new_ipa)))
            ipa = new_ipa
        new_ipa = ipa.replace(u"ʦ", "ts")
        new_ipa = new_ipa.replace(u"ʣ", "dz")
        if new_ipa != ipa:
          notes.append(u"normalize ʦ/ʣ to ts/dz in {{it-IPA}} pronun")
          ipa = new_ipa
        ipa = unicodedata.normalize("NFC", ipa)
        # module special-cases -izzare
        new_ipa = re.sub(u"iddz[àá]re", "izzare", ipa)
        if new_ipa != ipa:
          notes.append(u"normalize -iddzàre to -izzare in {{it-IPA}}")
          ipa = new_ipa
        new_ipa = ipa.replace(u"á", u"à").replace(u"í", u"ì").replace(u"ú", u"ù")
        if new_ipa != ipa:
          notes.append(unicodedata.normalize("NFC", u"normalize stress in %s in {{it-IPA}}" % ipa))
          ipa = new_ipa
        frobbed_pronuns.append(ipa)
      if must_continue:
        continue
      if frobbed_pronuns == [pagetitle]:
        frobbed_pronuns = []
        if specified_pronuns:
          notes.append("remove explicitly specified pronun in {{it-IPA}} because same as page title")
      blib.set_param_chain(t, frobbed_pronuns, "1", "")
      if t.has("voiced"):
        rmparam(t, "voiced")
        notes.append("remove voiced= in {{it-IPA}}")

    if origt != unicode(t):
      pagemsg("Replaced %s with %s" % (origt, unicode(t)))

  return unicode(parsed), notes

parser = blib.create_argparser("Add missing stress and z resolution to {{it-IPA}}",
  include_pagefile=True, include_stdin=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True,
    default_refs=["Template:it-IPA"])
