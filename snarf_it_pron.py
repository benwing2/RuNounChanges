#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse
import unicodedata

import blib
from blib import getparam, rmparam, tname, pname, msg, site

GR = u"\u0300"
unaccented_vowel = u"aeiouöüy"
unaccented_vowel_not_a = u"eiouöüy"
unaccented_vowel_c = "[" + unaccented_vowel + "]"
# For whatever reason, there's a single character for ǜ but not for ö̀
accented_vowel = u"àèéìòóùǜỳ" + GR # GR for ö̀
accented_vowel_not_a = u"èéìòóùǜỳ" + GR # GR for ö̀
accented_vowel_c = "[" + accented_vowel + "]"
vowel_c = "[" + unaccented_vowel + accented_vowel + "]"
vowel_not_a_c = "[" + unaccented_vowel_not_a + accented_vowel_not_a + "]"
non_vowel_c = "[^" + unaccented_vowel + accented_vowel + "]"

recognized_suffixes = [
  # -(m)ente, -(m)ento
  ("ment([eo])", ur"mént\1"), # must precede -ente/o below
  ("ent([eo])", ur"ènt\1"), # must follow -mente/o above
  # verbs
  ("izzare", u"iddzàre"), # must precede -are below
  ("izzarsi", u"iddzàrsi"), # must precede -arsi below
  ("([ai])re", r"\1" + GR + "re"), # must follow -izzare above
  ("([ai])rsi", r"\1" + GR + "rsi"), # must follow -izzarsi above
  # nouns
  ("izzatore", u"iddzatóre"), # must precede -tore below
  ("([st])ore", ur"\1óre"), # must follow -izzatore above
  ("izzatrice", u"iddzatrìce"), # must precede -trice below
  ("trice", u"trìce"), # must follow -izzatrice above
  ("izzazione", u"iddzatsióne"), # must precede -zione below
  ("zione", u"tsióne"), # must precede -one below and follow -izzazione above
  ("one", u"óne"), # must follow -zione above
  ("acchio", u"àcchio"),
  ("acci([ao])", ur"àcci\1"),
  ("([aiu])ggine", r"\1" + GR + "ggine"),
  ("aggio", u"àggio"),
  ("([ai])gli([ao])", r"\1" + GR + r"gli\2"),
  ("ai([ao])", ur"ài\1"),
  ("([ae])nza", r"\1" + GR + "ntsa"),
  ("ario", u"àrio"),
  ("([st])orio", ur"\1òrio"),
  ("astr([ao])", ur"àstr\1"),
  ("ell([ao])", ur"èll\1"),
  ("etta", u"étta"),
  # do not include -etto, both ètto and étto are common
  ("ezza", u"éttsa"),
  ("ficio", u"fìcio"),
  ("ier([ao])", ur"ièr\1"),
  ("ifero", u"ìfero"),
  ("ismo", u"ìsmo"),
  ("ista", u"ìsta"),
  ("izi([ao])", ur"ìtsi\1"),
  ("logia", u"logìa"),
  # do not include -otto, both òtto and ótto are common
  ("tudine", u"tùdine"),
  ("ura", u"ùra"),
  ("([^aeo])uro", ur"\1ùro"),
  # adjectives
  ("izzante", u"iddzànte"), # must precede -ante below
  ("ante", u"ànte"), # must follow -izzante above
  ("izzando", u"iddzàndo"), # must precede -ando below
  ("([ae])ndo", r"\1" + GR + "ndo"), # must follow -izzando above
  ("([ai])bile", r"\1" + GR + "bile"),
  ("ale", u"àle"),
  ("([aeiou])nico", r"\1" + GR + "nico"),
  ("([ai])stic([ao])", r"\1" + GR + r"stic\2"),
  # exceptions to the following: àbato, àcato, acròbata, àgata, apòstata, àstato, cìato, fégato, omeòpata,
  # sàb(b)ato, others?
  ("at([ao])", ur"àt\1"),
  ("([ae])tic([ao])", r"\1" + GR + r"tic\2"),
  ("ense", u"ènse"),
  ("esc([ao])", ur"ésc\1"),
  ("evole", u"évole"),
  # FIXME: Systematic exceptions to the following in 3rd plural present tense verb forms
  ("ian([ao])", ur"iàn\1"),
  ("iv([ao])", ur"ìv\1"),
  ("oide", u"òide"),
  ("oso", u"óso"),
]

unstressed_words = {
  "il", "lo", "la", "i", "gli", "le", # definite articles
  "un", # indefinite articles
  "mi", "ti", "si", "ci", "vi", "li", # object pronouns
  "me", "te", "se", "ce", "ve", "ne", # conjunctive object pronouns
  "e", "ed", "o", "od", # conjunctions
  "chi", "che", "non", # misc particles
  "di", "del", "dei", # prepositions
  "a", "ad", "al", "ai",
  "da", "dal", "dai",
  "in", "nel", "nei",
  "con", "col", "coi",
  "su", "sul", "sui",
  "per", "pei",
  "tra", "fra",
}

def apply_default_pronun(pronun):
  this_msgs = []
  def append_msg(txt):
    if txt not in this_msgs:
      this_msgs.append(txt)
  respelled_words = []
  traditional_respelled_words = []
  for word in pronun.split(" "):
    if word in unstressed_words:
      append_msg("UNSTRESSED_WORD")
      respelled_words.append(word)
      traditional_respelled_words.append(word)
      continue
    hacked_word = word.lower()
    if re.search(accented_vowel_c, hacked_word):
      subbed_word = word
      append_msg("SELF_ACCENTED")
    elif word.startswith("-"):
      subbed_word = word
      append_msg("SUFFIX")
    elif word.endswith("-"):
      subbed_word = word
      append_msg("PREFIX")
    else:
      m = re.search("^([^AEIOUaeiou]*)([AIUaiu])([^A-Z0-9aeiou]*[aeiou]?)$", word)
      if m:
        first, vowel, rest = m.groups()
        subbed_word = unicodedata.normalize("NFC", first + vowel + GR + rest)
        append_msg("AUTOACCENTED")
      else:
        for suf, repl in recognized_suffixes:
          subbed_word = unicodedata.normalize("NFC", re.sub(suf + "$", repl, word))
          if subbed_word != word:
            append_msg("AUTOSUBBED")
            break
        else: # no break
          append_msg("NEED_ACCENT")
          subbed_word = word
    if re.search(vowel_c + ".*ese$", hacked_word):
      append_msg("AUTO_ESE")
      respelled_words.append(re.sub("ese$", u"ése", word))
      traditional_respelled_words.append(re.sub("ese$", u"é[s]e", word))
    elif re.search(vowel_c + ".*oso$", hacked_word):
      append_msg("AUTO_OSO")
      respelled_words.append(re.sub("oso$", u"óso", word))
      traditional_respelled_words.append(re.sub("oso$", u"ó[s]o", word))
    else:
      respelled_words.append(subbed_word)
      traditional_respelled_words.append(subbed_word)
    hacked_subbed = subbed_word.lower()
    if re.search("%ss%s" % (vowel_c, vowel_c), hacked_subbed):
      append_msg("S_BETWEEN_VOWELS")
    if re.search(r"(^|[^d\[])z", hacked_subbed):
      append_msg("Z")
    if re.search(u"%si(%s|$)" % (vowel_c, non_vowel_c), hacked_subbed):
      append_msg("FALLING_IN_I")
    if re.search(u"%su(%s|$)" % (vowel_not_a_c, non_vowel_c), hacked_subbed): # not au, àu
      append_msg("FALLING_IN_U")
    hacked_subbed = re.sub("([gq])u", r"\1w", hacked_subbed)
    hacked_subbed = hacked_subbed.replace("gli", "gl")
    hacked_subbed = re.sub("([cg])i", r"\1", hacked_subbed)
    hacked_subbed = hacked_subbed.replace("qu", "Q")
    if re.search(u"%s[iu]%s" % (non_vowel_c, vowel_c), hacked_subbed):
      append_msg("HIATUS")
  respelled_term = "_".join(respelled_words)
  traditional_respelled_term = "_".join(traditional_respelled_words)
  respellings = [respelled_term]
  if respelled_term != traditional_respelled_term:
    respellings.append("#" + traditional_respelled_term)
  return respellings, this_msgs

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

  has_etym_sections = "==Etymology 1==" in secbody
  saw_pronun_section_at_top = False
  split_pronun_sections = False
  saw_pronun_section_this_etym_section = False
  saw_existing_pron = False
  saw_existing_pron_this_etym_section = False

  etymsection = "top" if has_etym_sections else "all"
  etymsections_to_first_subsection = {}
  if etymsection == "top":
    after_etym_1 = False
    for k in range(2, len(subsections), 2):
      if "==Etymology 1==" in subsections[k - 1]:
        after_etym_1 = True
      if "==Pronunciation==" in subsections[k - 1]:
        if after_etym_1:
          split_pronun_sections = True
        else:
          saw_pronun_section_at_top = True
      m = re.search("==Etymology ([0-9]*)==", subsections[k - 1])
      if m:
        etymsections_to_first_subsection[int(m.group(1))] = k

  msgs = []

  def append_msg(txt):
    if txt not in msgs:
      msgs.append(txt)

  def apply_default_pronun_to_pagetitle():
    respellings, this_msgs = apply_default_pronun(pagetitle)
    for msg in this_msgs:
      append_msg(msg)
    return respellings

  for k in range(2, len(subsections), 2):
    msgs = []
    def check_missing_pronun(etymsection):
      if split_pronun_sections and not saw_existing_pron_this_etym_section:
        pagemsg("WARNING: Missing pronunciations in etym section %s" % etymsection)
        append_msg("MISSING_PRONUN")
        append_msg("NEW_DEFAULTED")
        respellings = apply_default_pronun_to_pagetitle()
        pagemsg("<respelling> %s: %s <end> %s" % (etymsection, " ".join(respellings), " ".join(msgs)))

      #pagemsg("<respelling> %s: %s <end> %s" % ("top" if has_etym_sections else "all",
      #  " ".join(x.replace(" ", "_") for x in respellings), " ".join(msgs)))

    m = re.search("==Etymology ([0-9]*)==", subsections[k - 1])
    if m:
      if etymsection != "top":
        check_missing_pronun(etymsection)
      etymsection = m.group(1)
      saw_pronun_section_this_etym_section = False
      saw_existing_pron_this_etym_section = False
    if "==Pronunciation " in subsections[k - 1]:
      pagemsg("WARNING: Saw Pronunciation N section header: %s" % subsections[k - 1].strip())
    if "==Pronunciation==" in subsections[k - 1]:
      if saw_pronun_section_this_etym_section:
        pagemsg("WARNING: Saw two Pronunciation sections under etym section %s" % etymsection)
      if saw_pronun_section_at_top and etymsection != "top":
        pagemsg("WARNING: Saw Pronunciation sections both at top and in etym section %s" % etymsection)
      saw_pronun_section_this_etym_section = True
      parsed = blib.parse_text(subsections[k])

      respellings = []
      prev_it_IPA_t = None
      prev_it_pr_t = None
      must_continue = False
      for t in parsed.filter_templates():
        tn = tname(t)
        if tn == "it-IPA":
          saw_existing_pron = True
          saw_existing_pron_this_etym_section = True
          if prev_it_IPA_t:
            pronun_lines = re.findall(r"^.*\{\{it-IPA.*$", subsections[k], re.M)
            pagemsg("WARNING: Saw multiple {{it-IPA}} templates in a single Pronunciation section: %s" %
              " ||| ".join(pronun_lines))
            must_continue = True
            break
          prev_it_IPA_t = t
          this_respellings = []
          saw_pronun = False
          last_numbered_param = 0
          for param in t.params:
            pn = pname(param)
            pv = str(param.value).strip().replace(" ", "_")
            if re.search("^[0-9]+$", pn):
              last_numbered_param += 1
              saw_pronun = True
              if pv == "+":
                append_msg("EXISTING_DEFAULTED")
                this_respellings.extend(apply_default_pronun_to_pagetitle())
              else:
                append_msg("EXISTING")
                this_respellings.append(pv)
            elif re.search("^ref[0-9]*$", pn) and int(pn[3:] or "1") == last_numbered_param:
              m = re.search(r"^\{\{R:it:(DiPI|Olivetti|Treccani|Trec)(\|[^{}]*)?\}\}$", pv)
              if m:
                refname, refparams = m.groups()
                refname = "Treccani" if refname == "Trec" else refname
                this_respellings.append("n:%s%s" % (refname, refparams or ""))
              else:
                this_respellings.append("%s=%s" % (pn, pv))
            else:
              this_respellings.append("%s=%s" % (pn, pv))
          if not saw_pronun:
            append_msg("EXISTING_DEFAULTED")
            this_respellings.extend(apply_default_pronun_to_pagetitle())
          respellings.extend(this_respellings)
        if tn == "it-pr":
          saw_existing_pron = True
          saw_existing_pron_this_etym_section = True
          if prev_it_pr_t:
            pronun_lines = re.findall(r"^.*\{\{it-pr.*$", subsections[k], re.M)
            pagemsg("WARNING: Saw multiple {{it-pr}} templates in a single Pronunciation section: %s" %
              " ||| ".join(pronun_lines))
            must_continue = True
            break
          prev_it_pr_t = t
          this_respellings = []
          saw_pronun = False
          for param in t.params:
            pn = pname(param)
            pv = str(param.value).strip().replace(" ", "_")
            if re.search("^[0-9]+$", pn):
              saw_pronun = True
              #if pv == "+":
              #  append_msg("EXISTING_DEFAULTED")
              #  this_respellings.extend(apply_default_pronun_to_pagetitle())
              #else:
              def fix_ref(m):
                refname, refparams = m.groups()
                refname = "Treccani" if refname == "Trec" else refname
                return "<r:%s%s>" % (refname, refparams or "")
              pv = re.sub(r"<ref:\{\{R:it:(DiPI|Olivetti|Treccani|Trec|DOP)(\|[^{}]*)?\}\}>", fix_ref, pv)
              append_msg("EXISTING")
              this_respellings.append(pv)
            else:
              this_respellings.append("%s=%s" % (pn, pv))
          if not saw_pronun:
            append_msg("EXISTING_DEFAULTED")
            #this_respellings.extend(apply_default_pronun_to_pagetitle())
            this_respellings.append("+")
          respellings.extend(this_respellings)
      if must_continue:
        continue

      if args.include_defns and etymsection not in ["top", "all"]:
        first_etym_subsec = etymsections_to_first_subsection.get(int(etymsection), None)
        next_etym_subsec = etymsections_to_first_subsection.get(1 + int(etymsection), None)
        if first_etym_subsec is None:
          pagemsg("WARNING: Internal error: Unknown first etym section for =Etymology %s=" % etymsection)
        else:
          if next_etym_subsec is None:
            next_etym_subsec = len(subsections)
          defns = blib.find_defns("".join(subsections[first_etym_subsec:next_etym_subsec]), "it")
          append_msg("defns: %s" % ";".join(defns))

      if respellings:
        pagemsg("<respelling> %s: %s <end> %s" % (etymsection, " ".join(respellings), " ".join(msgs)))

  check_missing_pronun(etymsection)
  if not saw_existing_pron:
    if args.include_defns and has_etym_sections:
      for etymsec in sorted(list(etymsections_to_first_subsection.keys())):
        msgs = []
        first_etym_subsec = etymsections_to_first_subsection[etymsec]
        next_etym_subsec = etymsections_to_first_subsection.get(1 + etymsec, None)
        if next_etym_subsec is None:
          next_etym_subsec = len(subsections)
        append_msg("NEW_DEFAULTED")
        defns = blib.find_defns("".join(subsections[first_etym_subsec:next_etym_subsec]), "it")
        append_msg("defns: %s" % ";".join(defns))
        respellings = apply_default_pronun_to_pagetitle()
        pagemsg("<respelling> %s: %s <end> %s" % (etymsec, " ".join(respellings), " ".join(msgs)))
    else:
      msgs = []
      append_msg("NEW_DEFAULTED")
      respellings = apply_default_pronun_to_pagetitle()
      pagemsg("<respelling> %s: %s <end> %s" % ("top" if has_etym_sections else "all", " ".join(respellings), " ".join(msgs)))

if __name__ == "__main__":
  parser = blib.create_argparser("Snarf Italian pronunciations for fixing", include_pagefile=True, include_stdin=True)
  parser.add_argument("--partial-page", action="store_true", help="Input was generated with 'find_regex.py --lang LANG' and has no ==LANG== header.")
  parser.add_argument("--include-defns", action="store_true", help="Include defns of snarfed terms (helps with multi-etym sections).")
  args = parser.parse_args()
  start, end = blib.parse_start_end(args.start, args.end)

  blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True)
