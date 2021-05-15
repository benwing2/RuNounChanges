#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, tname, pname, msg, site

vowel_ipa_to_spelling = {
  "a": u"à",
  "e": u"é",
  u"ɛ": u"è",
  "i": u"ì",
  "o": u"ó",
  u"ɔ": u"ò",
  "u": u"ù",
}

def rhyme_to_spelling(rhy):
  rhy = re.sub(u"^(.*?)([aɛeiɔou])", lambda m: m.group(1) + vowel_ipa_to_spelling[m.group(2)], rhy)
  rhy = re.sub("([iu])([aeiou])", r"\1.\2", rhy)
  rhy = rhy.replace("j", "i").replace(u"ɡ", "g").replace(u"ɲɲ", "gn")
  rhy = rhy.replace("kw", "qu").replace("w", "u")
  rhy = re.sub("k([ei])", r"ch\1", rhy).replace("k", "c")
  rhy = re.sub("g([ei])", r"gh\1", rhy)
  rhy = re.sub(u"ddʒ([ei])", r"gg\1", rhy).replace(u"ddʒ", "ggi")
  rhy = re.sub(u"dʒ([ei])", r"g\1", rhy).replace(u"dʒ", "gi")
  rhy = re.sub(u"ttʃ([ei])", r"cc\1", rhy).replace(u"ttʃ", "cci")
  rhy = re.sub(u"tʃ([ei])", r"c\1", rhy).replace(u"tʃ", "ci")
  rhy = re.sub(u"ʃ+([ei])", r"sc\1", rhy)
  rhy = re.sub(u"ʃ+", "sci", rhy)
  rhy = re.sub(u"ʎʎi?", "gli", rhy)
  rhy = re.sub("([^d])z", r"\1s", rhy)
  vowel_respelling_to_spelling = {
    u"à": "a",
    u"é": "e",
    u"è": "e",
    u"ì": "i",
    u"ó": "o",
    u"ò": "o",
    u"ù": "u",
  }
  spelling = re.sub(u"([àéèìóòù])(.)", lambda m: vowel_respelling_to_spelling[m.group(1)] + m.group(2), rhy)
  spelling = spelling.replace(".", "")
  spelling = re.sub("([^t])ts", r"\1z", spelling)
  spelling = re.sub("([^d])dz", r"\1z", spelling)
  if "tts" in rhy:
    ret = [(spelling.replace("tts", "z"), rhy.replace("tts", "ts")), (spelling.replace("tts", "zz"), rhy)]
  elif "ddz" in rhy:
    ret = [(spelling.replace("ddz", "z"), rhy.replace("ddz", "dz")), (spelling.replace("ddz", "zz"), rhy)]
  else:
    ret = [(spelling, rhy)]
  ret_with_cap = []
  for spelling, respelling in ret:
    ret_with_cap.append((spelling, respelling))
    ret_with_cap.append((spelling.capitalize(), respelling.capitalize()))
    if re.search(u"[àéèìóòù]", spelling):
      # final stressed vowel; also add possibilities without the accent in case word is a monosyllable
      spelling = re.sub(u"([àéèìóòù])", lambda m: vowel_respelling_to_spelling[m.group(1)], spelling)
      ret_with_cap.append((spelling, respelling))
      ret_with_cap.append((spelling.capitalize(), respelling.capitalize()))
  return ret_with_cap

def sub_repeatedly(fro, to, text):
  newtext = re.sub(fro, to, text)
  while newtext != text:
    text = newtext
    newtext = re.sub(fro, to, text)
  return text

def ipa_to_respelling(ipa):
  ipa = ipa.replace("/", "")
  ipa = ipa.replace(u"\u0361", "") # get rid of tie bar in t͡ʃ, t͡ːs, etc.
  ipa = re.sub(u"([aeɛioɔu])ː", r"\1", ipa)
  ipa = ipa.replace(u"tʃː", u"ttʃ")
  ipa = ipa.replace(u"dʒː", u"ddʒ")
  ipa = re.sub(u"(.)ː", r"\1\1", ipa)
  ipa = re.sub(u"ˈ(.*?)([aeɛioɔu])", lambda m: m.group(1) + vowel_ipa_to_spelling[m.group(2)], ipa)
  ipa = sub_repeatedly(r"([iu])\.?([aeiouàèéìòóù])", r"\1*\2", ipa)
  ipa = sub_repeatedly(r"([aeiouàèéìòóù])\.?([iu])", r"\1*\2", ipa)
  ipa = ipa.replace(u"a̯", "a")
  ipa = ipa.replace(u"ɾ", "r")
  ipa = ipa.replace(".", "").replace("*", ".")
  ipa = ipa.replace("j", "i").replace(u"ɡ", "g")
  ipa = re.sub(u"ɲ+", "gn")
  ipa = ipa.replace("kw", "qu").replace("w", "u")
  ipa = re.sub(u"k([eièéì])", r"ch\1", ipa).replace("k", "c")
  ipa = re.sub(u"g([eièéì])", r"gh\1", ipa)
  ipa = re.sub(u"ddʒ([eièéì])", r"gg\1", ipa).replace(u"ddʒ", "ggi")
  ipa = re.sub(u"dʒ([eièéì])", r"g\1", ipa).replace(u"dʒ", "gi")
  ipa = re.sub(u"ttʃ([eièéì])", r"cc\1", ipa).replace(u"ttʃ", "cci")
  ipa = re.sub(u"tʃ([eièéì])", r"c\1", ipa).replace(u"tʃ", "ci")
  ipa = re.sub(u"ʃ+([eièéì])", r"sc\1", ipa)
  ipa = re.sub(u"ʃ+", "sci", ipa)
  ipa = re.sub(u"ʎ+([iì])", r"gl\1", ipa)
  ipa = re.sub(u"ʎ+", "gli")
  ipa = sub_repeatedly("([aeiouàèéìòóù])s([aeiouàèéìòóù])", r"\1hs\2", ipa)
  ipa = sub_repeatedly("([aeiouàèéìòóù])z([aeiouàèéìòóùbdglmnrv])", r"\1s\2", ipa)
  ipa = re.sub("z([bdglmnrv])", r"s\1", ipa)
  ipa = re.sub("(^|[^d])z", r"\1[z]", ipa)
  return ipa

def process_text_on_page(index, pagetitle, text):
  global args
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  notes = []

  if not args.partial_page:
    retval = blib.find_modifiable_lang_section(text, "Italian", pagemsg)
    if retval is None:
      return
    sections, j, secbody, sectail, has_non_lang = retval
  else:
    sections = [text]
    j = 0
    secbody = text
    sectail = ""

  subsections = re.split("(^==+[^=\n]+==+\n)", secbody, 0, re.M)

  for k in xrange(2, len(subsections), 2):
    if "==Pronunciation==" in subsections[k - 1]:
      parsed = blib.parse_text(subsections[k])
      saw_it_IPA = False
      for t in parsed.filter_templates():
        tn = tname(t)
        if tn == "it-IPA":
          saw_it_IPA = True
          break
      if not saw_it_IPA:
        rhymes_template = None
        for t in parsed.filter_templates():
          tn = tname(t)
          if tn in ["rhyme", "rhymes"] and getparam(t, "1") == "it":
            if rhymes_template:
              pagemsg("WARNING: Saw two {{rhymes|it}} templates: %s and %s" % (unicode(rhymes_template), unicode(t)))
            rhymes_template = t
        if rhymes_template:
          pronuns = []
          rhymes = blib.fetch_param_chain(rhymes_template, "2")
          unable = False
          for rhy in rhymes:
            spellings = rhyme_to_spelling(rhy)
            matched = False
            bad_rhyme_msgs = []
            for spelling, respelling in spellings:
              if pagetitle.endswith(spelling):
                prevpart = pagetitle[:-len(spelling)]
                if "z" in prevpart:
                  pagemsg("WARNING: Unable to add pronunciation due to z in part before rhyme %s" % rhy)
                  unable = True
                  break
                else:
                  hacked_prevpart = re.sub("([gq])u", r"\1w", prevpart)
                  hacked_prevpart = hacked_prevpart.replace("gli", "gl")
                  hacked_prevpart = re.sub("([cg])i", r"\1", hacked_prevpart)
                  if re.search("[^aeiouAEIOU][iu]([aeiou]|$)", hacked_prevpart):
                    pagemsg("WARNING: Unable to add pronunciation due to hiatus in part before rhyme %s" % rhy)
                    unable = True
                    break
                  else:
                    pronuns.append(prevpart + respelling)
                    matched = True
                    break
              else:
                bad_rhyme_msgs.append("WARNING: Unable to match rhyme %s, spelling %s, respelling %s" % (
                  rhy, spelling, respelling))
            if not matched and not unable and bad_rhyme_msgs:
              for bad_rhyme_msg in bad_rhyme_msgs:
                pagemsg(bad_rhyme_msg)
          if pronuns and not unable:
            subsections[k] = "* {{it-IPA|%s}}\n" % "|".join(pronuns) + subsections[k]
            notes.append("add Italian pronunciation respelling%s %s" % (
              "s" if len(pronuns) > 1 else "", ",".join(pronuns)))

  secbody = "".join(subsections)
  sections[j] = secbody + sectail
  return "".join(sections), notes

parser = blib.create_argparser("Add Italian pronunciations based on rhymes",
  include_pagefile=True, include_stdin=True)
parser.add_argument("--partial-page", action="store_true")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True,
  default_refs=["Template:it-IPA"])
