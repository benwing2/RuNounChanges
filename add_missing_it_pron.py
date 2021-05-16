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

vowel_respelling_to_spelling = {
  u"à": "a",
  u"é": "e",
  u"è": "e",
  u"ì": "i",
  u"ó": "o",
  u"ò": "o",
  u"ù": "u",
  u"À": "A",
  u"É": "E",
  u"È": "E",
  u"Ì": "I",
  u"Ó": "O",
  u"Ò": "O",
  u"Ù": "U",
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
  ipa = re.sub(r"[/\[\]]", "", ipa)
  ipa = ipa.replace(u"ɡ", "g")
  ipa = ipa.replace(u"ɾ", "r")
  ipa = ipa.replace(u"ä", "a")
  ipa = ipa.replace(u"ã", "a")
  ipa = ipa.replace(u"ẽ", "e")
  ipa = ipa.replace(u"ĩ", "i")
  ipa = ipa.replace(u"õ", "o")
  ipa = ipa.replace(u"ũ", "u")
  ipa = ipa.replace(u"\u0361", "") # get rid of tie bar in t͡ʃ, t͡ːs, etc.
  ipa = ipa.replace(u"\u032a", "") # get rid of dentalization marker in t̪ d̪ s̪ etc.
  ipa = ipa.replace(u"\u033a", "") # get rid of marker in r̺ etc.
  ipa = ipa.replace(u"\u031a", "") # get rid of marker in c̚ etc.
  ipa = ipa.replace(u"\u031e", "") # get rid of lowering marker in e̞ etc.
  ipa = ipa.replace(u"\u031f", "") # get rid of marker in ɡ̟ etc.
  ipa = ipa.replace(u"\u0320", "") # get rid of underline in n̠ etc.
  ipa = ipa.replace(u"ʲ", "")
  ipa = re.sub(u"([aeɛioɔu])ː", r"\1", ipa)
  ipa = ipa.replace(u"tʃː", u"ttʃ")
  ipa = ipa.replace(u"dʒː", u"ddʒ")
  ipa = ipa.replace(u"tsː", u"tts")
  ipa = ipa.replace(u"dzː", u"ddz")
  ipa = re.sub(u"(.)ː", r"\1\1", ipa)
  # Include negative lookahead of 032f (inverted underbreve as in e̯) so that pronuns like /fiˈde̯is.mo/
  # get the stress on the right vowel. Right afterwords we remove the inverted underbreves.
  ipa = sub_repeatedly(u"ˌ([^ ]*?)([aeɛioɔu])(?!\u032f)(.*ˈ)", lambda m: m.group(1) + vowel_ipa_to_spelling[m.group(2)] + m.group(3), ipa)
  # 0331 = LINEUNDER
  ipa = re.sub(u"ˌ(.*?)([aeɛioɔu])(?!\u032f)", lambda m: m.group(1) + vowel_ipa_to_spelling[m.group(2)] + u"\u0331", ipa)
  ipa = re.sub(u"ˈ(.*?)([aeɛioɔu])(?!\u032f)", lambda m: m.group(1) + vowel_ipa_to_spelling[m.group(2)], ipa)
  # 0323 = DOTUNDER
  ipa = re.sub(u"([ɛɔ])", lambda m: vowel_ipa_to_spelling[m.group(1)] + u"\u0323", ipa)
  ipa = ipa.replace(u"a̯", "a")
  ipa = ipa.replace(u"e̯", "e")
  ipa = ipa.replace(u"o̯", "o")
  ipa = ipa.replace(u"i̯", "j")
  ipa = ipa.replace(u"u̯", "w")
  ipa = sub_repeatedly(ur"([iu])\.?([aeiouàèéìòóù])", r"\1*\2", ipa)
  ipa = sub_repeatedly(ur"([aeiouàèéìòóù])\.?([iu])", r"\1*\2", ipa)
  ipa = ipa.replace(".", "").replace("*", ".")
  ipa = ipa.replace(u"dʒdʒ", u"ddʒ")
  ipa = ipa.replace("dzdz", u"ddz")
  ipa = ipa.replace(u"tʃtʃ", u"ttʃ")
  ipa = ipa.replace("tsts", u"tts")
  ipa = ipa.replace(u"ɱ", "n")
  ipa = re.sub(u"ŋ([kg])", r"n\1", ipa)
  ipa = ipa.replace("j", "i")
  ipa = re.sub(u"ɲ+", "gn", ipa)
  ipa = ipa.replace("kw", "qu").replace("w", "u")
  iap = ipa.replace("h", "[h]")
  ipa = re.sub(u"k([eièéì])", r"ch\1", ipa).replace("k", "c")
  ipa = re.sub(u"g([eièéì])", r"gh\1", ipa)
  ipa = re.sub(u"ddʒ([eièéì])", r"gg\1", ipa)
  ipa = re.sub(u"ddʒ([aàoòóuù])", r"ggi\1", ipa)
  ipa = re.sub(u"dʒ([eièéì])", r"g\1", ipa)
  ipa = re.sub(u"dʒ([aàoòóuù])", r"gi\1", ipa)
  ipa = ipa.replace(u"dʒ", u"[dʒ]")
  ipa = re.sub(u"ttʃ([eièéì])", r"cc\1", ipa)
  ipa = re.sub(u"ttʃ([aàoòóuù])", r"cci\1", ipa)
  ipa = re.sub(u"tʃ([eièéì])", r"c\1", ipa)
  ipa = re.sub(u"tʃ([aàoòóuù])", r"ci\1", ipa)
  ipa = ipa.replace(u"tʃ", u"[tʃ]")
  ipa = re.sub(u"ʃ+([eièéì])", r"sc\1", ipa)
  ipa = re.sub(u"ʃ+([aàoòóuù])", r"sci\1", ipa)
  ipa = re.sub(ur"ʃ+(?!\])", "sh", ipa) # don't change [tʃ] generated above
  ipa = re.sub(u"ʎ+([iì])", r"gl\1", ipa)
  ipa = re.sub(u"ʎ+([aàeèéoòóuù])", r"gli\1", ipa)
  ipa = sub_repeatedly(u"([aeiouàèéìòóù][\u0323\u0331]?)s([aeiouàèéìòóù])", r"\1[s]\2", ipa)
  ipa = sub_repeatedly(u"([aeiouàèéìòóù][\u0323\u0331]?)z([aeiouàèéìòóùbdglmnrv])", r"\1s\2", ipa)
  ipa = re.sub("z([bdglmnrv])", r"s\1", ipa)
  ipa = re.sub("(^|[^d])z", r"\1[z]", ipa)
  return ipa

def hack_respelling(pagetitle, respelling):
  pagetitle_words = pagetitle.split(" ")
  respelling_words = respelling.split(" ")
  warnings = []
  if len(pagetitle_words) != len(respelling_words):
    warnings.append("WARNING: Page title has %s words but respelling %s has %s words" % (
      len(pagetitle_words), respelling, len(respelling_words)))
  else:
    hacked_respelling_words = []
    for ptw, rw in zip(pagetitle_words, respelling_words):
      # Capitalize respelling as appropriate for pagetitle.
      if ptw[0].isupper():
        rw = rw.capitalize()
      # Add hyphens to respelling if pagetitle is a prefix or suffix.
      if ptw[0] == "-":
        rw = "-" + rw
      if ptw[-1] == "-":
        rw += "-"
      # Change 'c' in respelling to 'k' as appropriate for pagetitle; similarly, change 'cs' to 'x' as
      # appropriate and 'qu' to 'cu'.
      split_ptw = re.split(u"([cC]+[sh]|[Cc]*[xXkKqQ]+|[cC]+(?![eèéiì]))", ptw)
      split_rw = re.split(u"([cC]+[sh]|[Cc]*[xXkKqQ]+|[cC]+(?![eèéiì]))", rw)
      if len(split_ptw) != len(split_rw):
        warnings.append("WARNING: Different # of c/k/q's in pagetitle word %s vs. c/k/q's in respelling word %s" % (ptw, rw))
      else:
        parts = []
        for i in xrange(len(split_rw)):
          if i % 2 == 0:
            parts.append(split_rw[i])
          else:
            parts.append(split_ptw[i])
        rw = "".join(parts)
      # Change 'ce' in respelling to 'cie' as appropriate for pagetitle.
      split_ptw = re.split(u"([cC]i?(?=[eèé]))", ptw)
      split_rw = re.split(u"([cC]i?(?=[eèé]))", rw)
      if len(split_ptw) != len(split_rw):
        warnings.append("WARNING: Different # of c(i)e's in pagetitle word %s vs. c(i)e's in respelling word %s" % (ptw, rw))
      else:
        parts = []
        for i in xrange(len(split_rw)):
          if i % 2 == 0:
            parts.append(split_rw[i])
          else:
            parts.append(split_ptw[i])
        rw = "".join(parts)
      hacked_respelling_words.append(rw)
    respelling = " ".join(hacked_respelling_words)
  return respelling, warnings

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
        origt = unicode(t)
        def tmsg(txt):
          pagemsg("%s: %s" % (txt, unicode(t)))
        tn = tname(t)
        if tn == "it-IPA":
          saw_it_IPA = True
          break
        if tn == "IPA" and getparam(t, "1") == "it":
          saw_it_IPA = True
          pronuns = blib.fetch_param_chain(t, "2")
          this_phonemic_pronun = None
          this_phonemic_respelling = None
          this_phonetic_pronun = None
          this_phonetic_respelling = None
          respellings = []
          all_warnings = []
          hack_respelling_warnings = []
          main_warnings = []
          unable = [False]
          for pronun in pronuns:
            respelling = ipa_to_respelling(pronun)
            respelling, this_hack_respelling_warnings = hack_respelling(pagetitle, respelling)
            hack_respelling_warnings.extend(this_hack_respelling_warnings)
            def set_unable(msg):
              main_warnings.append(msg)
              unable[0] = True

            tmsg("For pronun %s, generated respelling %s" % (pronun, respelling))
            respelling_words = respelling.split(" ")
            for rw in respelling_words:
              if rw.endswith("-"): # prefix
                continue
              hacked_rw = re.sub(u".[\u0323\u0331]", "e", rw) # pretend vowels with secondary or no stress are 'e'
              if not re.search(u"[àèéìòóùÀÈÉÌÒÓÙ]", hacked_rw) and len(re.sub("[^aeiouAEIOU]", "", hacked_rw)) > 1:
                set_unable("WARNING: For respelling %s for pronun %s, word %s is missing stress" %
                  (respelling, pronun, rw))
            if not re.search(u"^[a-zA-ZàèéìòóùÀÈÉÌÒÓÙ. ʒʃ\[\]-]+$", respelling):
              set_unable("WARNING: Strange char in respelling %s for pronun %s" % (respelling, pronun))
            else:
              putative_pagetitle = re.sub(u"([àèéìòóùÀÈÉÌÒÓÙ])([^ ])",
                  lambda m: vowel_respelling_to_spelling[m.group(1)] + m.group(2),
                  respelling)
              pagetitle_words = pagetitle.split(" ")
              putative_pagetitle_words = putative_pagetitle.split(" ")
              if len(pagetitle_words) != len(putative_pagetitle_words):
                set_unable("WARNING: Page title has %s words but putative page title %s has %s words" % (
                  len(pagetitle_words), putative_pagetitle, len(putative_pagetitle_words)))
              else:
                hacked_putative_pagetitle_words = []
                for ptw, puptw in zip(pagetitle_words, putative_pagetitle_words):
                  split_ptw = re.split("([Zz]+)", ptw)
                  split_puptw = re.split("([Tt]?[Tt]s|[Dd]?[Dd]z)", puptw)
                  if len(split_ptw) != len(split_puptw):
                    set_unable("WARNING: Different # of z's in pagetitle word %s vs. (t)ts/(d)dz's in putative pagetitle word %s" % (
                      ptw, puptw))
                    hacked_putative_pagetitle_words.append(puptw)
                  else:
                    parts = []
                    for i in xrange(len(split_puptw)):
                      if i % 2 == 0:
                        parts.append(split_puptw[i])
                      else:
                        parts.append(split_ptw[i])
                    hacked_putative_pagetitle_words.append("".join(parts))
                putative_pagetitle = " ".join(hacked_putative_pagetitle_words)
                if putative_pagetitle != pagetitle:
                  # If respelling already seen, we already warned about it.
                  if respelling in respellings:
                    assert unable[0]
                  else:
                    set_unable("WARNING: Respelling %s doesn't match page title (putative page title %s, pronun %s)" %
                        (respelling, putative_pagetitle, pronun))

            def append_respelling(respelling):
              if respelling not in respellings:
                respellings.append(respelling)
            def append_warnings(warning):
              if warning:
                all_warnings.append(warning)
              for warning in hack_respelling_warnings:
                all_warnings.append(warning)
              del hack_respelling_warnings[:]
              for warning in main_warnings:
                all_warnings.append(warning)
              del main_warnings[:]

            append_respelling(respelling)
            if pronun.startswith("/"):
              if this_phonemic_pronun is not None:
                append_warnings("WARNING: Saw two phonemic pronuns %s (respelling %s) and %s (respelling %s) without intervening phonetic pronun" %
                    (this_phonemic_pronun, this_phonemic_respelling, pronun, respelling))
              this_phonemic_pronun = pronun
              this_phonemic_respelling = respelling
              this_phonetic_pronun = None
              this_phonetic_respelling = None
            elif pronun.startswith("["):
              if this_phonemic_pronun is None:
                if this_phonetic_pronun is not None:
                  unable[0] = True
                  append_warnings("WARNING: Saw two phonetic pronuns %s (respelling %s) and %s (respelling %s) without intervening phonemic pronun" %
                      (this_phonetic_pronun, this_phonetic_respelling, pronun, respelling))
                else:
                  append_warnings("WARNING: Saw phonetic pronun %s (respelling %s) without preceding phonemic pronun" %
                      (pronun, respelling))
                this_phonetic_pronun = pronun
                this_phonetic_respelling = respelling
              elif this_phonemic_respelling != respelling:
                unable[0] = True
                append_warnings("WARNING: Phonemic respelling %s (pronun %s) differs from phonetic respelling %s (pronun %s)" %
                    (this_phonemic_respelling, this_phonemic_pronun, respelling, pronun))
              else:
                if unable[0] and len(main_warnings) > 0:
                  # `unable` could be set from a previous pronunciation but no main warnings this time around
                  # because the previously generated warnings have already been appended to all_warnings.
                  mesg = main_warnings[0]
                  del main_warnings[0]
                  append_warnings(mesg)
                else:
                  append_warnings(None)
              this_phonemic_pronun = None
              this_phonemic_respelling = None
            else:
              unable[0] = True
              append_warnings("WARNING: Pronun %s (respelling %s) not marked as phonemic or phonetic" %
                  (pronun, respelling))
          if this_phonemic_pronun is not None:
            append_warnings("WARNING: Saw phonemic pronun %s (respelling %s) without corresponding phonetic pronun" %
                (this_phonemic_pronun, this_phonemic_respelling))
          if not unable[0]:
            for param in t.params:
              pn = pname(param)
              if not re.search("^[0-9]+$", pn) and pn != "nocount":
                unable[0] = True
                append_warnings("WARNING: Saw unrecognized param %s=%s" % (pn, unicode(param.value)))
          if unable[0]:
            num_other_warnings = len(all_warnings) - 1
            warnings_follow = (
              "; %s warnings follow" % num_other_warnings if num_other_warnings > 1 else
              "; 1 warning follows" if num_other_warnings == 1 else
              ""
            )
            tmsg("<respelling> %s <end> %s%s" % (" ".join(respellings), all_warnings[0], warnings_follow))
            for warning in all_warnings[1:]:
              tmsg(warning)
          else:
            rmparam(t, "nocount")
            del t.params[:]
            blib.set_param_chain(t, respellings, "1")
            blib.set_template_name(t, "it-IPA")
            notes.append("replace raw {{IPA|it}} with {{it-IPA|%s}}" % "|".join(respellings))
        if unicode(t) != origt:
          pagemsg("Replaced %s with %s" % (origt, unicode(t)))
      subsections[k] = unicode(parsed)

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
