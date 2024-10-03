#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse, unicodedata, json

import blib
from blib import getparam, rmparam, msg, errandmsg, site, tname, pname, rsub_repeatedly

def process_text_on_page(index, pagetitle, text):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
  def expand_text(tempcall):
    return blib.expand_text(tempcall, pagetitle, pagemsg, args.verbose)

  notes = []

  retval = blib.find_modifiable_lang_section(text, None if args.partial_page else "Polish", pagemsg,
    force_final_nls=True)
  if retval is None:
    return
  sections, j, secbody, sectail, has_non_lang = retval

  parsed = blib.parse_text(secbody)
  for t in parsed.filter_templates():
    tn = tname(t)
    if tn in ["pl-pronunciation", "pl-p"]:
      def getp(param):
        return getparam(t, param)
      origt = str(t)
      stopping_warning = []

      audios = blib.fetch_param_chain(t, "a") or blib.fetch_param_chain(t, "audio")
      if audios:
        audioparts = []
        for i, audio in enumerate(audios, start=1):
          param = "ac" + ("" if i == 1 else str(i))
          caption = getp(param)
          if not caption and i == 1:
            param = "ac" + str(i)
            caption = getp(param)
          origcaption = caption
          if caption and caption in ["Audio", "Audio %s" % i]:
            pagemsg("Ignoring caption '%s' in %s=: %s" % (caption, param, origt))
            caption = ""
          if caption:
            m = re.search(r"^(Audio [0-9]+|Audio) \((.*)\)$", caption)
            if not m:
              m = re.search("^(Audio [0-9]+|Audio),* (.*)$", caption)
            if m:
              audio_num_caption, text_caption = m.groups()
              if audio_num_caption in ["Audio", "Audio %s" % i]:
                pagemsg("Ignoring 'Audio #' portion of caption '%s' in %s=: %s" % (caption, param, origt))
                caption = text_caption
              else:
                pagemsg("WARNING: Mismatch in number of 'Audio #' portion of caption '%s' in %s=: %s" % (caption, param, origt))
                stopping_warning.append("mismatch in number of 'Audio #' portion of caption '%s' in %s=" % (caption, param))
          if caption:
            m = re.search("^''(.*)''$", caption)
            stripped_italics = False
            if m:
              caption = m.group(1)
              pagemsg("Stripping italics from caption %s in %s=: %s" % (caption, param, origt))
              stripped_italics = True
            if caption == pagetitle:
              audiomod = "<text:#>"
            elif caption == pagetitle + " się":
              audiomod = "<text:~>"
            elif caption == "colloquial":
              audiomod = "<a:colloquial>"
            elif stripped_italics:
              pagemsg("WARNING: Assuming italicized caption %s is text in %s=: %s" % (caption, param, origt))
              audiomod = "<text:%s>" % caption
            else:
              pagemsg("WARNING: Unable to parse caption '%s' in %s=: %s" % (caption, param, origt))
              audiomod = "<cap:%s>" % caption
              stopping_warning.append("unable to parse caption '%s' in %s=" % (caption, param))
          else:
            audiomod = ""
          audioparts.append("%s%s" % (audio, audiomod))
        new_audio = ";".join(audioparts)
      else:
        new_audio = None

      homophones = getp("hh")
      if homophones:
        homophones = homophones.replace(";", ",")
        if re.search(r"\.[^,]", homophones):
          pagemsg("WARNING: Saw likely syllable divider in hh=%s: %s" % (homophones, origt))
          stopping_warning.append("saw likely syllable divider in homophone(s)")
        homophones = homophones.split(",")
        homophone_quals = []
        for i in range(1, len(homophones) + 1):
          hhp = getp("hhp%s" % i) or (getp("hhp") if i == 1 else "")
          if hhp:
            homophones[i - 1] += "<qq:%s>" % hhp
        homophones = ",".join(homophones)

      hyphenations = blib.fetch_param_chain(t, "h")

      rhymes = blib.fetch_param_chain(t, "r")

      middle_polish = blib.fetch_param_chain(t, "mp")
      middle_polish = ["#" if mp == "+" else mp for mp in middle_polish]
      if middle_polish:
        middle_polish = ",".join(middle_polish)
        if middle_polish != "#":
          pagemsg("WARNING: Need to check Middle Polish respelling(s) %s" % middle_polish)
          stopping_warning.append("need to check Middle Polish respelling(s)")

      fixstress = getp("fixstress") or getp("fs")
      ipas = blib.fetch_param_chain(t, "ipa")
      respellings = blib.fetch_param_chain(t, "1")
      if ipas and respellings:
        pagemsg("WARNING: Both ipa= and 1=, can't handle: %s" % origt)
        continue
      if ipas:
        respellings = ["raw:%s" % ipa for ipa in ipas]
      respellings_defaulted = False
      if not respellings:
        respellings_defaulted = True
        respellings = [pagetitle]
      respelling_mods = []
      saw_respelling_mods = False
      def qualifier_to_mod(qualifier):
        if not qualifier:
          return ""
        else:
          qualifiers = re.split(", *", qualifier)
          return "<a:%s>" % ",".join(qualifiers)
      for i in range(1, len(respellings) + 1):
        qualifier = getp("q%s" % i) or (getp("q") if i == 1 else "")
        mod = qualifier_to_mod(qualifier)
        if mod:
          saw_respelling_mods = True
        respelling_mods.append(mod)
      if respellings_defaulted and respelling_mods[0]:
        respellings_defaulted = False
      new_default_respellings = ""
      if fixstress == "0":
        if not respellings_defaulted:
          pagemsg("WARNING: Saw respellings along with |fs=0, can't handle: %s" % origt)
          stopping_warning.append("saw respellings along with |fs=0, can't handle")
        else:
          respellings = [pagetitle]
          respellings_defaulted = False
        new_respellings = ["+"]
        respelling_mods = [""]
        new_default_respellings = "+"
      else:
        new_respellings = respellings
        new_respellings = ["#" if nr == pagetitle else nr for nr in new_respellings]
      new_respellings = ",".join(
        "%s%s" % (respelling, mod) for respelling, mod in zip(new_respellings, respelling_mods))
      if new_respellings == "#":
        new_respellings = ""

      for i, audio in enumerate(audios, start=1):
        param = "ac" + ("" if i == 1 else str(i))
        caption = getp(param)
        if not caption and i == 1:
          param = "ac" + str(i)
          caption = getp(param)
        origcaption = caption
        if caption and caption in ["Audio", "Audio %s" % i]:
          pagemsg("Ignoring caption '%s' in %s=: %s" % (caption, param, origt))
          caption = ""

      if not args.dont_compare_pronuns:
        ### Old code invoking [[Module:pl-IPA]] directly. New code makes only one invocation
        # per {{pl-p}} template, which should be faster.
        #pl_p_prons = [] 
        #must_continue = False
        #for respelling in respellings:
        #  pl_p_pron = expand_text("{{#invoke:pl-IPA|convert_to_IPA_bot|%s}}" % respelling)
        #  if not pl_p_pron:
        #    must_continue = True
        #    continue
        #  pl_p_prons.append("/" + pl_p_pron + "/")
        #if must_continue:
        #  continue
        if ipas:
          pl_p_args = ""
        else:
          pl_p_args = "".join("|plp%s=%s" % ("" if i == 0 else str(i + 1), respelling)
                              for i, respelling in enumerate(respellings))
        pl_pr_args = "|" + new_default_respellings if new_default_respellings else ""
        pl_pr_json = expand_text("{{#invoke:zlw-lch-IPA|get_lect_pron_info_bot%s%s}}" % (
          pl_pr_args, pl_p_args))
        if not pl_pr_json:
          continue
        pl_pr_obj = json.loads(pl_pr_json)
        if ipas:
          pl_p_prons = ipas
        else:
          pl_p_prons = pl_pr_obj["plp_prons"]
        if fixstress and fixstress != "0":
          if len(pl_p_prons) > 1:
            pagemsg("WARNING: Saw multiple respellings along with |fs=%s, can't handle: %s" % (fixstress, origt))
            stopping_warning.append("saw multiple respellings along with |fs=%s, can't handle" % fixstress)
          else:
            pl_p_pron_1 = pl_p_prons[0]
            if " " in pl_p_pron_1:
              pagemsg("WARNING: Saw space in {{pl-p}} output %s along with fs=1, can't handle: %s" % (
                pl_p_pron_1, origt))
              stopping_warning.append("saw space in {{pl-p}} output along with fs=1, can't handle")
            else:
              pl_p_pron_1_syls = re.split("[.ˈ]", pl_p_pron_1)
              pl_p_pron_1_parts = []
              for i, syl in enumerate(pl_p_pron_1_syls):
                if i == len(pl_p_pron_1_syls) - 3:
                  pl_p_pron_1_parts.append("ˈ")
                elif i > 0:
                  pl_p_pron_1_parts.append(".")
                pl_p_pron_1_parts.append(syl)
              pl_p_pron_1 = "".join(pl_p_pron_1_parts)
              pl_p_pron_2 = pl_p_prons[0]
              pl_p_prons = [pl_p_pron_1, pl_p_pron_2]

        pl_pr_prons = []
        for pron_obj in pl_pr_obj["pron_list"]:
          pl_pr_prons.append(pron_obj["pron_with_syldivs"])
        auto_hyphenations = pl_pr_obj["hyph_list"]
        auto_rhymes = []
        for rhyme_obj in pl_pr_obj["rhyme_list"]:
          auto_rhymes.append(rhyme_obj["rhyme"])

        pl_p_args = ("" if respellings_defaulted else "|" + "|".join(respellings)) + (
          "|fs=%s" % fixstress if fixstress else "")
        joined_pl_p_prons = ",".join(pl_p_prons)
        joined_pl_pr_prons = ",".join(pl_pr_prons)
        def remove_syldiv(txt):
          return txt.replace(".", "")
        def remove_syldiv_stress(txt):
          return re.sub("[.ˈ]", "", txt)
        def remove_stress(txt):
          return txt.replace("ˈ", "")
        def add_eng(txt):
          return re.sub("n([.ˈ]?[kɡ])", r"ŋ\1", txt)
        def add_monosyllabic_stress_to_words(txt1, txt2):
          if not re.search("[.ˈ]", txt1) and len(re.sub("[^aɛiɔuɘ]", "", txt2)) == 1 and txt2[0] == "ˈ":
            retval = "ˈ" + txt1
          else:
            retval = txt1
          return retval
        if len(pl_p_prons) == len(pl_pr_prons):
          monostress_pl_p_prons = []
          for pl_p_pron, pl_pr_pron in zip(pl_p_prons, pl_pr_prons):
            pl_p_pron = re.sub("^/(.*)/$", r"\1", pl_p_pron)
            pl_pr_pron = re.sub("^/(.*)/$", r"\1", pl_pr_pron)
            pl_p_pron_words = pl_p_pron.split(" ")
            pl_pr_pron_words = pl_pr_pron.split(" ")
            if len(pl_p_pron_words) == len(pl_pr_pron_words):
              monostress_words = []
              for i in range(len(pl_p_pron_words)):
                monostress_words.append(add_monosyllabic_stress_to_words(pl_p_pron_words[i], pl_pr_pron_words[i]))
              monostress_pl_p_prons.append("/" + " ".join(monostress_words) + "/")
            else:
              monostress_pl_p_prons.append("/" + pl_p_pron + "/")
          monostress_joined_pl_p_prons = ",".join(monostress_pl_p_prons)
        else:
          monostress_pl_p_prons = pl_p_prons
          monostress_joined_pl_p_prons = joined_pl_p_prons

        # adjust syldiv boundaries to make old more like new
        syladjusted_pl_p_prons = []
        for pl_p_pron in monostress_pl_p_prons:
          vowel = "aɛiɔuɘ"
          obstruent = "b|t͡s|t͡ɕ|t͡ʂ|d|d͡z|d͡ʑ|d͡ʐ|[fɡxkpsɕʂtvzʑʐ]"
          cons = obstruent + "|[lmnɲrw]"
          liquid = "lrj"
          C = "[%s]" % cons
          V = "[%s]" % vowel
          T = "(?:%s)" % obstruent
          R = "[%s]" % liquid
          pl_p_pron = re.sub("(" + V + ")(" + T + r")([.ˈ])(" + R + V + ")", r"\1\3\2\4", pl_p_pron)
          pl_p_pron = re.sub("(" + V + ")(" + T + r")([.ˈ])(" + R + V + ")", r"\1\3\2\4", pl_p_pron)
          pl_p_pron = re.sub("(" + V + ")(" + C + r")([.ˈ])(j" + V + ")", r"\1\3\2\4", pl_p_pron)
          pl_p_pron = re.sub("(" + V + ")(" + C + r")([.ˈ])(j" + V + ")", r"\1\3\2\4", pl_p_pron)
          syladjusted_pl_p_prons.append(pl_p_pron)
        syladjusted_joined_pl_p_prons = ",".join(syladjusted_pl_p_prons)

        long_voicing = {
          "t͡s": "d͡z",
          "t͡ɕ": "d͡ʑ",
          "t͡ʂ": "d͡ʐ",
        }
        short_voicing = {
          "p": "b",
          "f": "v",
          "x": "ɣ",
          "k": "ɡ",
          "s": "z",
          "ɕ": "ʑ",
          "ʂ": "ʐ",
          "t": "d",
        }
        long_unvoiced_obstruents = "|".join(list(long_voicing.keys()))
        short_unvoiced_obstruents = "|".join(list(short_voicing.keys()))
        long_voiced_obstruents = "|".join(list(long_voicing.values()))
        short_voiced_obstruents = "|".join(list(short_voicing.values()))
        voiced_non_obstruent = "[aɛiɔuɘlmnɲrwj]"
        voiced_obstruents = "%s|%s" % (long_voiced_obstruents, short_voiced_obstruents)
        voiced_sounds = "%s|%s|%s" % (long_voiced_obstruents, short_voiced_obstruents, voiced_non_obstruent)
        voicing_adjusted_pl_pr_prons = []
        for pl_pr_pron in pl_pr_prons:
          while True:
            changed = False
            while True:
              new_pl_pr_pron = re.sub(
                "^(.*)(%s)( ˈ?(?:%s).*)$" % (long_unvoiced_obstruents, voiced_sounds),
                lambda m: m.group(1) + long_voicing[m.group(2)] + m.group(3), pl_pr_pron)
              if new_pl_pr_pron == pl_pr_pron:
                break
              else:
                pl_pr_pron = new_pl_pr_pron
                changed = True
            while True:
              new_pl_pr_pron = re.sub(
                "^(.*)(%s)([ ˈ]*(?:%s).*)$" % (long_unvoiced_obstruents, voiced_obstruents),
                lambda m: m.group(1) + long_voicing[m.group(2)] + m.group(3), pl_pr_pron)
              if new_pl_pr_pron == pl_pr_pron:
                break
              else:
                pl_pr_pron = new_pl_pr_pron
                changed = True
            while True:
              new_pl_pr_pron = re.sub(
                "^(.*)(%s)( ˈ?(?:%s).*)$" % (short_unvoiced_obstruents, voiced_sounds),
                lambda m: m.group(1) + short_voicing[m.group(2)] + m.group(3), pl_pr_pron)
              if new_pl_pr_pron == pl_pr_pron:
                break
              else:
                pl_pr_pron = new_pl_pr_pron
                changed = True
            while True:
              new_pl_pr_pron = re.sub(
                "^(.*)(%s)([ ˈ]*(?:%s).*)$" % (short_unvoiced_obstruents, voiced_obstruents),
                lambda m: m.group(1) + short_voicing[m.group(2)] + m.group(3), pl_pr_pron)
              if new_pl_pr_pron == pl_pr_pron:
                break
              else:
                pl_pr_pron = new_pl_pr_pron
                changed = True
            if not changed:
              break
          voicing_adjusted_pl_pr_prons.append(pl_pr_pron)
        voicing_adjusted_joined_pl_pr_prons = ",".join(voicing_adjusted_pl_pr_prons)
        pagemsg("voicing_adjusted_joined_pl_pr_prons: %s" % voicing_adjusted_joined_pl_pr_prons)

        # account for clitic prepositions joined to following word
        clitic_adjusted_pl_pr_prons = []
        for pl_pr_pron in voicing_adjusted_pl_pr_prons:
          pl_pr_pron = re.sub("^/(.*)/$", r"\1", pl_pr_pron)
          pl_pr_pron = re.sub("(?:^|(?<= ))([^ .ˈ]+) ", r"\1.", pl_pr_pron)
          pl_pr_pron = pl_pr_pron.replace(".ˈ", "ˈ")
          # nonsyllabic clitics should not have a following syllable dividers
          pl_pr_pron = re.sub(r"(/| )([^aɛiɔuɘ])\.", r"\1\2", pl_pr_pron)
          clitic_adjusted_pl_pr_prons.append("/" + pl_pr_pron + "/")
        clitic_adjusted_joined_pl_pr_prons = ",".join(clitic_adjusted_pl_pr_prons)
        pagemsg("clitic_adjusted_joined_pl_pr_prons: %s" % clitic_adjusted_joined_pl_pr_prons)

        pron_diff = (
          "SAME" if joined_pl_p_prons == joined_pl_pr_prons else
          "SAME_MODULO_MONOSYLLABIC_STRESS" if monostress_joined_pl_p_prons == joined_pl_pr_prons else
          "SAME_MODULO_MONOSYLLABIC_STRESS_AND_SYL_ADJUST" if syladjusted_joined_pl_p_prons == joined_pl_pr_prons else
          "SAME_MODULO_MONOSYLLABIC_STRESS_SYL_ADJUST_AND_VOICING_ADJUST" if syladjusted_joined_pl_p_prons == voicing_adjusted_joined_pl_pr_prons else
          "SAME_MODULO_MONOSYLLABIC_STRESS_SYL_ADJUST_VOICING_ADJUST_AND_CLITIC_ADJUST" if syladjusted_joined_pl_p_prons == clitic_adjusted_joined_pl_pr_prons else
          "DIFFERENT_ONLY_IN_SYLDIV" if remove_syldiv(joined_pl_p_prons) == remove_syldiv(joined_pl_pr_prons) else
          "DIFFERENT_ONLY_IN_SYLDIV_MODULO_MONOSYLLABIC_STRESS" if remove_syldiv(monostress_joined_pl_p_prons) == remove_syldiv(joined_pl_pr_prons) else
          "DIFFERENT_ONLY_IN_SYLDIV_MODULO_MONOSYLLABIC_STRESS_AND_SYL_ADJUST" if remove_syldiv(syladjusted_joined_pl_p_prons) == remove_syldiv(joined_pl_pr_prons) else
          "DIFFERENT_ONLY_IN_SYLDIV_MODULO_MONOSYLLABIC_STRESS_SYL_ADJUST_AND_VOICING_ADJUST" if remove_syldiv(syladjusted_joined_pl_p_prons) == remove_syldiv(voicing_adjusted_joined_pl_pr_prons) else
          "DIFFERENT_ONLY_IN_SYLDIV_MODULO_MONOSYLLABIC_STRESS_SYL_ADJUST_VOICING_ADJUST_AND_CLITIC_ADJUST" if remove_syldiv(syladjusted_joined_pl_p_prons) == remove_syldiv(clitic_adjusted_joined_pl_pr_prons) else
          "DIFFERENT_ONLY_IN_STRESS" if remove_stress(joined_pl_p_prons) == remove_stress(joined_pl_pr_prons) else
          "DIFFERENT_ONLY_IN_STRESS_MODULO_SYL_ADJUST" if remove_stress(syladjusted_joined_pl_p_prons) == remove_stress(joined_pl_pr_prons) else
          "DIFFERENT_ONLY_IN_STRESS_MODULO_SYL_ADJUST_AND_VOICING_ADJUST" if remove_stress(syladjusted_joined_pl_p_prons) == remove_stress(voicing_adjusted_joined_pl_pr_prons) else
          "DIFFERENT_ONLY_IN_STRESS_MODULO_SYL_ADJUST_VOICING_ADJUST_AND_CLITIC_ADJUST" if remove_stress(syladjusted_joined_pl_p_prons) == remove_stress(clitic_adjusted_joined_pl_pr_prons) else
          "DIFFERENT_ONLY_IN_SYLDIV_AND_STRESS" if remove_syldiv_stress(joined_pl_p_prons) == remove_syldiv_stress(joined_pl_pr_prons) else
          "DIFFERENT_ONLY_IN_SYLDIV_AND_STRESS_MODULO_SYL_ADJUST" if remove_syldiv_stress(syladjusted_joined_pl_p_prons) == remove_syldiv_stress(joined_pl_pr_prons) else
          "DIFFERENT_ONLY_IN_SYLDIV_AND_STRESS_MODULO_SYL_ADJUST_AND_VOICING_ADJUST" if remove_syldiv_stress(syladjusted_joined_pl_p_prons) == remove_syldiv_stress(voicing_adjusted_joined_pl_pr_prons) else
          "DIFFERENT_ONLY_IN_SYLDIV_AND_STRESS_MODULO_SYL_ADJUST_VOICING_ADJUST_AND_CLITIC_ADJUST" if remove_syldiv_stress(syladjusted_joined_pl_p_prons) == remove_syldiv_stress(clitic_adjusted_joined_pl_pr_prons) else
          "DIFFERENT_ONLY_IN_ENG_ASSIM" if add_eng(joined_pl_p_prons) == add_eng(joined_pl_pr_prons) else
          "DIFFERENT_ONLY_IN_ENG_ASSIM_AND_SYLDIV" if remove_syldiv(add_eng(joined_pl_p_prons)) == remove_syldiv(add_eng(joined_pl_pr_prons)) else
          "DIFFERENT_ONLY_IN_ENG_ASSIM_AND_STRESS" if remove_stress(add_eng(joined_pl_p_prons)) == remove_stress(add_eng(joined_pl_pr_prons)) else
          "DIFFERENT_ONLY_IN_ENG_ASSIM, SYLDIV_AND_STRESS" if remove_syldiv_stress(add_eng(joined_pl_p_prons)) == remove_syldiv_stress(add_eng(joined_pl_pr_prons)) else
          "DIFFERENT_IN_PHONEMES"
        )
        pagemsg("{{pl-p%s}} = %s; {{pl-pr%s}} = %s: %s" % (
          pl_p_args, joined_pl_p_prons, pl_pr_args, joined_pl_pr_prons, pron_diff))

      must_continue = False
      for param in t.params:
        pn = pname(param)
        if not re.search("^([0-9]+|(a|ac|h|r|mp|q|audio|ipa|hhp)[0-9]*|hh|fs|fixstress)$", pn):
          pagemsg("WARNING: Unrecognized param %s=%s: %s" % (pn, str(param.value), str(t)))
          must_continue = True
          stopping_warning.append("unrecognized param %s=%s" % (pn, str(param.value)))
          break
      if must_continue:
        continue

      if saw_respelling_mods:
        stopping_warning.append("saw respelling qualifier(s), needs review")
      carry_over_respelling = not pron_diff.startswith("SAME") or saw_respelling_mods
      no_change = stopping_warning or carry_over_respelling
      if no_change:
        modt = list(blib.parse_text("{{pl-pr%s}}" % (
          "|" + new_respellings if new_respellings and carry_over_respelling else "")).
          filter_templates())[0]
      else:
        del t.params[:]
        blib.set_template_name(t, "pl-pr")
        if new_default_respellings:
          t.add("1", new_default_respellings)
        modt = t
      if new_audio:
        modt.add("a", new_audio)
      if homophones:
        modt.add("hh", homophones)

      if hyphenations:
        if carry_over_respelling:
          pagemsg("WARNING: Keeping hyphenation(s) %s because respelling(s) being carried over, must check manually: %s" % (
            ",".join(hyphenations), origt))
          stopping_warning.append("hyphenation(s) kept because respelling(s) carried over, must check manually")
        elif set(auto_hyphenations) == set(hyphenations):
          pagemsg("Ignoring hyphenation(s) %s same as auto-hyphenation(s): %s" % (",".join(hyphenations), origt))
          hyphenations = []
        else:
          pagemsg("WARNING: Keeping hyphenation(s) %s not same as auto-hyphenation(s) %s, must check manually: %s" % (
            ",".join(hyphenations), ",".join(auto_hyphenations) or "-", origt))
          stopping_warning.append("hyphenation(s) not same as auto-hyphenation(s) %s, must check manually" % (
                                  ",".join(auto_hyphenations) or "-"))
      if rhymes:
        if carry_over_respelling:
          pagemsg("WARNING: Keeping rhyme(s) %s because respelling(s) being carried over, must check manually: %s" % (
            ",".join(rhymes), origt))
          stopping_warning.append("rhyme(s) kept because respelling(s) carried over, must check manually")
        elif set(auto_rhymes) == set(rhymes):
          pagemsg("Ignoring rhyme(s) %s same as auto-rhyme(s): %s" % (",".join(rhymes), origt))
          rhymes = []
        else:
          pagemsg("WARNING: Keeping rhyme(s) %s not same as auto-rhyme(s) %s, must check manually: %s" % (
            ",".join(rhymes), ",".join(auto_rhymes), origt))
          stopping_warning.append("rhyme(s) not same as auto-rhyme(s) %s, must check manually" %
                                  ",".join(auto_rhymes))

      if hyphenations:
        hyphenations = ",".join(hyphenations)
        if args.dont_compare_pronuns:
          pagemsg("WARNING: Need to check hyphenation(s) %s" % hyphenations)
        modt.add("h", hyphenations)
      if rhymes:
        rhymes = ",".join(rhymes)
        if args.dont_compare_pronuns:
          pagemsg("WARNING: Need to check rhyme(s) %s" % rhymes)
        modt.add("r", rhymes)
      if middle_polish:
        modt.add("mp", middle_polish)

      if no_change:
        pagemsg("OLD: <begin> %s <end>" % origt)
        pagemsg("NEW: %s = %s; {{pl-pr%s}} = %s: %s%s: <begin> %s <end>" % (
          origt, joined_pl_p_prons, pl_pr_args, joined_pl_pr_prons, pron_diff,
          "; " + "; ".join(stopping_warning) if stopping_warning else "", str(modt)))
      else:
        pagemsg("Replace %s with %s" % (origt, str(t)))
        notes.append("replace {{pl-p}} with {{pl-pr}}, changing syntax as appropriate")

  secbody = str(parsed)

  # Strip extra newlines added to secbody
  sections[j] = secbody.rstrip("\n") + sectail
  return "".join(sections), notes

parser = blib.create_argparser("Convert {{pl-p}} to {{pl-pr}}", include_pagefile=True, include_stdin=True)
parser.add_argument("--partial-page", action="store_true", help="Input was generated with 'find_regex.py --lang LANG' and has no ==LANG== header.")
parser.add_argument("--dont-compare-pronuns", action="store_true", help="Disable comparing generated {{pl-p}} and {{pl-pr}} pronuns; for testing only.")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True)
