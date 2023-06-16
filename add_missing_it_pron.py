#!/usr/bin/env python3
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
        for i in range(len(split_rw)):
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
        for i in range(len(split_rw)):
          if i % 2 == 0:
            parts.append(split_rw[i])
          else:
            parts.append(split_ptw[i])
        rw = "".join(parts)

      # Change 'tts/ddz' in respelling to 'ts/dz' as appropriate for pagetitle.
      split_ptw = re.split("([Zz]+)", ptw)
      split_rw = re.split("([Tt]?[Tt]s|[Dd]?[Dd]z)", rw)
      if len(split_ptw) != len(split_rw):
        warnings.append("WARNING: Different # of z's in pagetitle word %s vs. ts/dz's in respelling word %s" % (ptw, rw))
      else:
        parts = []
        for i in range(len(split_rw)):
          if i % 2 == 0:
            parts.append(split_rw[i])
          elif split_rw[i] == "tts" and split_ptw[i] == "z":
            parts.append("ts")
          elif split_rw[i] == "ddz" and split_ptw[i] == "z":
            parts.append("dz")
          else:
            parts.append(split_rw[i])
        rw = "".join(parts)

      hacked_respelling_words.append(rw)
    respelling = " ".join(hacked_respelling_words)
  return respelling, warnings

def process_text_on_page(index, pagetitle, text):
  global args
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  notes = []

  retval = blib.find_modifiable_lang_section(text, None if args.partial_page else "Italian", pagemsg,
    force_final_nls=True)
  if retval is None:
    return
  sections, j, secbody, sectail, has_non_lang = retval

  subsections = re.split("(^==+[^=\n]+==+\n)", secbody, 0, re.M)

  need_ref_section = False

  for k in range(2, len(subsections), 2):
    if "==Pronunciation==" in subsections[k - 1]:
      parsed = blib.parse_text(subsections[k])

      all_pronun_templates = []
      for t in parsed.filter_templates():
        tn = tname(t)
        if tn == "it-pr" or tn == "IPA" and getparam(t, "1") == "it":
          all_pronun_templates.append(t)

      saw_it_pr = False
      pronun_based_respellings = []
      for t in parsed.filter_templates():
        origt = str(t)
        def tmsg(txt):
          other_templates = []
          for t in all_pronun_templates:
            thist = str(t)
            if thist != origt:
              other_templates.append(thist)
          pagemsg("%s: %s%s" % (
            txt, origt,
            ", other templates %s" % ", ".join(other_templates) if len(other_templates) > 0 else ""
          ))
        tn = tname(t)
        if tn == "it-pr":
          saw_it_pr = True
          respellings = blib.fetch_param_chain(t, "1")
          # FIXME, need to split on comma
          pronun_based_respellings.extend(respellings)
          break
        if tn == "IPA" and getparam(t, "1") == "it":
          saw_it_pr = True
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
                    for i in range(len(split_puptw)):
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
                append_warnings("WARNING: Saw unrecognized param %s=%s" % (pn, str(param.value)))
          manual_assist = ""
          if unable[0]:
            if pagetitle in ipa_directives:
              respellings = ipa_directives[pagetitle]
              unable[0] = False
              manual_assist = " (manually assisted)"
              tmsg("%sUsing manually-specified IPA-based respelling%s %s; original warnings follow: %s" % (
                "[MULTIPLE PRONUN TEMPLATES] " if len(all_pronun_templates) > 1 else "",
                "s" if len(respellings) > 1 else "", ",".join(respellings), " ||| ".join(all_warnings)))
            else:
              tmsg("%s<respelling> %s <end> %s" % (
                "[MULTIPLE PRONUN TEMPLATES] " if len(all_pronun_templates) > 1 else "",
                " ".join(respellings), " ||| ".join(all_warnings)))
          if not unable[0]:
            del t.params[:]
            nextparam = 0
            for param in respellings:
              if "=" in param:
                paramname, paramval = param.split("=", 1)
              else:
                nextparam += 1
                paramname = str(nextparam)
                paramval = param
              if re.search("^n[0-9]*$", paramname):
                need_ref_section = True
              t.add(paramname, paramval)
            blib.set_template_name(t, "it-pr")
            notes.append("replace raw {{IPA|it}} with {{it-pr|%s}}%s" % ("|".join(respellings), manual_assist))
          pronun_based_respellings.extend(respellings)
        if str(t) != origt:
          pagemsg("Replaced %s with %s" % (origt, str(t)))
      subsections[k] = str(parsed)

      rhymes_template = None
      for t in parsed.filter_templates():
        tn = tname(t)
        if tn in ["rhyme", "rhymes"] and getparam(t, "1") == "it":
          if rhymes_template:
            pagemsg("WARNING: Saw two {{rhymes|it}} templates: %s and %s" % (str(rhymes_template), str(t)))
          rhymes_template = t
      if rhymes_template:
        rhyme_based_respellings = []
        all_warnings = []
        def append_respelling(respelling):
          if respelling not in rhyme_based_respellings:
            rhyme_based_respellings.append(respelling)
        def append_warnings(warning):
          all_warnings.append(warning)
        rhymes = blib.fetch_param_chain(rhymes_template, "2")
        unable = False
        for rhy in rhymes:
          spellings = rhyme_to_spelling(rhy)
          matched = False
          bad_rhyme_msgs = []
          for ending, ending_respelling in spellings:
            if pagetitle.endswith(ending):
              prevpart = pagetitle[:-len(ending)]
              respelling = prevpart + ending_respelling
              saw_oso_ese = False
              if ending_respelling == u"óso":
                saw_oso_ese = True
                append_respelling(respelling)
                append_respelling("#" + prevpart + u"ó[s]o")
              elif ending_respelling == u"ése":
                saw_oso_ese = True
                append_respelling(respelling)
                append_respelling("#" + prevpart + u"é[s]e")
              else:
                if respelling.endswith(u"zióne"):
                  new_respelling = re.sub(u"zióne$", u"tsióne", respelling)
                  pagemsg("Replaced respelling '%s' with '%s'" % (respelling, new_respelling))
                  respelling = new_respelling
                  prevpart = respelling[:-len(ending)] + ending_respelling
                append_respelling(respelling)
              if (re.search(u"[aeiouàèéìòóù]s([aeiouàèéìòóù]|$)", prevpart.lower()) or
                  not saw_oso_ese and re.search(u"[aeiouàèéìòóù][sz][aeiouàèéìòóù]", ending_respelling.lower())):
                append_warnings("WARNING: Unable to add pronunciation due to /s/ or /z/ between vowels: %s" % rhy)
                unable = True
                break
              if "z" in prevpart:
                append_warnings("WARNING: Unable to add pronunciation due to z in part before rhyme: %s" % rhy)
                unable = True
                break
              hacked_prevpart = re.sub("([gq])u", r"\1w", prevpart)
              hacked_prevpart = hacked_prevpart.replace("gli", "gl")
              hacked_prevpart = re.sub("([cg])i", r"\1", hacked_prevpart)
              if re.search("[^aeiou][iu]([aeiou]|$)", hacked_prevpart.lower()):
                append_warnings("WARNING: Unable to add pronunciation due to hiatus in part before rhyme %s" % rhy)
                unable = True
                break
              if re.search(u"[aeiouàèéìòóù]i([^aeiouàèéìòóù]|$)", respelling.lower()):
                append_warnings("WARNING: Unable to add pronunciation due to falling diphthong in -i: %s" % rhy)
                unable = True
                break
              matched = True
              break
            else:
              bad_rhyme_msgs.append("WARNING: Unable to match rhyme %s, spelling %s, respelling %s" % (
                rhy, ending, ending_respelling))
          if not matched and not unable and bad_rhyme_msgs:
            for bad_rhyme_msg in bad_rhyme_msgs:
              pagemsg(bad_rhyme_msg)
        if rhyme_based_respellings:
          if not saw_it_pr:
            manual_assist = ""
            if pagetitle in rhyme_directives:
              rhyme_based_respellings = rhyme_directives[pagetitle]
              manual_assist = " (manually assisted)"
              pagemsg("Using manually-specified rhyme-based respelling%s %s; original warnings follow: %s: %s" % (
                "s" if len(rhyme_based_respellings) > 1 else "", ",".join(rhyme_based_respellings),
                " ||| ".join(all_warnings), str(rhymes_template)))
              subsections[k] = "* {{it-pr|%s}}\n" % ",".join(rhyme_based_respellings) + subsections[k]
              notes.append("add Italian rhyme-based respelling%s %s%s" % (
                "s" if len(rhyme_based_respellings) > 1 else "", ",".join(rhyme_based_respellings), manual_assist))
            else:
              different_headers = []
              for pos in ["Noun", "Verb", "Adjective", "Adverb", "Participle"]:
                if "==%s==" % pos in secbody:
                  different_headers.append(pos)
              if len(different_headers) > 1:
                all_warnings[0:0] = ["WARNING: Multiple headers %s seen" % ",".join(different_headers)]
              if "Etymology 1" in secbody:
                all_warnings[0:0] = ["WARNING: Multiple etymologies seen"]

              pagemsg("<respelling> all: %s <end>%s: <from> %s <to> %s <end>" % (" ".join(rhyme_based_respellings),
                " " + " ||| ".join(all_warnings) if all_warnings else "",
                str(rhymes_template), str(rhymes_template)))
          else:
            for respelling in rhyme_based_respellings:
              if (not re.search("^qual[0-9]*=", respelling) and pronun_based_respellings and
                  respelling not in pronun_based_respellings):
                pagemsg("WARNING: Rhyme-based respelling%s %s doesn't match it-pr respelling(s) %s%s" % (
                  " (with problems)" if len(all_warnings) > 0 else "", respelling,
                  ",".join(pronun_based_respellings),
                  ": %s" % " ||| ".join(all_warnings) if len(all_warnings) > 0 else ""))

  if need_ref_section:
    for k in range(len(subsections) - 1, 2, -2):
      if re.search(r"^===\s*References\s*===$", subsections[k - 1].strip()):
        if not re.search(r"<references\s*/?\s*>", subsections[k]):
          subsections[k] = subsections[k].rstrip("\n") + "\n<references />\n\n"
          notes.append("add <references /> to existing ===References=== section for pronunciation refs")
        break
    else: # no break
      for k in range(len(subsections) - 1, 2, -2):
        if not re.search(r"==\s*(Anagrams|Further reading)\s*==", subsections[k - 1]):
          subsections[k + 1:k + 1] = ["===References===\n", "<references />\n\n"]
          notes.append("add new ===References=== section for pronunciation refs")
          break
      else: # no break
        pagemsg("WARNING: Something wrong, couldn't find location to insert ===References=== section")

  secbody = "".join(subsections)
  # Strip extra newlines added to secbody
  sections[j] = secbody.rstrip("\n") + sectail
  return "".join(sections), notes

parser = blib.create_argparser("Add Italian pronunciations based on rhymes",
  include_pagefile=True, include_stdin=True)
parser.add_argument("--partial-page", action="store_true", help="Input was generated with 'find_regex.py --lang Italian' and has no ==Italian== header.")
parser.add_argument("--ipa-direcfile", help="File containing IPA respelling directives, modified from lines output with <respelling> ... <end> in them.")
parser.add_argument("--rhyme-direcfile", help="File containing rhyme respelling directives, modified from lines output with <rhyme-respelling> ... <end> in them.")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

ipa_directives = {}

if args.ipa_direcfile:
  for lineno, line in blib.yield_items_from_file(args.ipa_direcfile, include_original_lineno=True):
    m = re.search("^Page [0-9]+ (.*?): <respelling> *(.*?) *<end>", line)
    if not m:
      msg("Line %s: WARNING: Unrecognized line: %s" % (lineno, line))
    else:
      page, respellings = m.groups()
      respellings = [respelling.replace("_", " ") for respelling in respellings.split(" ")]
      ipa_directives[page] = respellings

rhyme_directives = {}

if args.rhyme_direcfile:
  for lineno, line in blib.yield_items_from_file(args.rhyme_direcfile, include_original_lineno=True):
    m = re.search("^Page [0-9]+ (.*?): <rhyme-respelling> *(.*?) *<end>", line)
    if not m:
      msg("Line %s: WARNING: Unrecognized line: %s" % (lineno, line))
    else:
      page, respellings = m.groups()
      respellings = [respelling.replace("_", " ") for respelling in respellings.split(" ")]
      rhyme_directives[page] = respellings

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True,
  default_refs=["Template:it-pr"])
