#!/usr/bin/python
# -*- coding: utf-8 -*-

import re
from collections import OrderedDict

AC = u"\u0301" # acute =  ́
GR = u"\u0300" # grave =  ̀
CFLEX = u"\u0302" # circumflex =  ̂
DOTABOVE = u"\u0307" # dot above =  ̇
DOTBELOW = u"\u0323" # dot below =  ̣
DI = u"\u0308" # diaeresis =  ̈
DUBGR = u"\u030F" # double grave =  ̏
accents = AC + GR + CFLEX + DOTABOVE + DOTBELOW + DI + DUBGR

composed_grave_vowel = u"ѐЀѝЍ"
vowel_no_jo = u"аеиоуяэыюіѣѵАЕИОУЯЭЫЮІѢѴ" + composed_grave_vowel #omit ёЁ
vowel = vowel_no_jo + u"ёЁ"
cons_except_sib_c = u"бдфгйклмнпрствхзьъБДФГЙКЛМНПРСТВХЗЬЪ"
sib = u"шщчжШЩЧЖ"
sib_c = sib + u"цЦ"
cons = cons_except_sib_c + sib_c
velar = u"кгхКГХ"
uppercase = u"АЕИОУЯЭЫЁЮІѢѴБДФГЙКЛМНПРСТВХЗЬЪШЩЧЖЦ"

# Does a phrase of connected text need accents? We need to split by word
# and check each one.
def needs_accents(text, split_dash=False):
  # A word needs accents if it is unstressed and contains more than one vowel;
  # but if split_dash, allow cases like динь-динь with multiple monosyllabic
  # words separated by a hyphen. We don't just split on hyphens at top level
  # otherwise a word like Али-Баба́ will "need accents".
  def word_needs_accents(word):
    if not is_unaccented(word):
      return False
    for sw in re.split(r"-", word) if split_dash else [word]:
      if not is_monosyllabic(sw):
        return True
    return False
  words = re.split(r"\s", text)
  for word in words:
    if word_needs_accents(word):
      return True
  return False

def is_stressed(word):
  # A word that has ё in it is inherently stressed.
  # diaeresis occurs in сѣ̈дла plural of сѣдло́
  return re.search(u"[́̈ёЁ]", word)

def is_unstressed(word):
  return not is_stressed(word)

def is_unaccented(word):
  return not re.search("[" + accents + u"ёЁѐЀѝЍ]", word)

def is_ending_stressed(word):
  return (re.search(u"[ёЁ][^" + vowel + "]*$", word) or
    re.search("[" + vowel + u"][́̈][^" + vowel + "]*$", word))

# True if any word in text has two or more stresses
def is_multi_stressed(text):
  text = re.sub(u"[ёЁ]", u"е́", text)
  words = re.split(r"[\s-]", text)
  for word in words:
    if re.search("[" + vowel + u"][́̈].*[" + vowel + u"][́̈]", word):
      return True
  return False

def is_beginning_stressed(word):
  return (re.search("^[^" + vowel + u"]*[ёЁ]", word) or
    re.search("^[^" + vowel + "]*[" + vowel + u"]́", word))

def is_nonsyllabic(word):
  return not re.search("[" + vowel + "]", word)

# Includes non-syllabic stems such as льд-
def is_monosyllabic(word):
  return not re.search("[" + vowel + "].*[" + vowel + "]", word)

def ends_with_vowel(word):
  return re.search("[" + vowel + "][" + AC + GR + DI + "]?$", word)

grave_deaccenter = {
    GR:"", # grave accent
    u"ѐ":u"е", # composed Cyrillic chars w/grave accent
    u"Ѐ":u"Е",
    u"ѝ":u"и",
    u"Ѝ":u"И",
}

deaccenter = grave_deaccenter.copy()
deaccenter[AC] = "" # acute accent
deaccenter[DI] = "" # diaeresis

def remove_accents(word):
  # remove acute, grave and diaeresis (but not affecting composed ёЁ)
    return re.sub(u"([̀́̈ѐЀѝЍ])", lambda m: deaccenter[m.group(1)], word)

def remove_monosyllabic_accents(word):
  # note: This doesn't affect ё or Ё, provided that the word is
  # precomposed (which it normally is, as this is done automatically by
  # MediaWiki upon saving)
  if is_monosyllabic(word):
    return remove_accents(word)
  else:
    return word

destresser = deaccenter.copy()
destresser[u"ё"] = u"е"
destresser[u"Ё"] = u"Е"

def make_unstressed(word):
  return re.sub(u"([̀́̈ёЁѐЀѝЍ])", lambda m: destresser[m.group(1)], word)

def remove_jo(word):
  return re.sub(u"([ёЁ])", lambda m: destresser[m.group(1)], word)

def make_unstressed_once(word):
  # leave graves alone
  return re.sub(u"([́̈ёЁ])([^́̈ёЁ]*)$", lambda m: destresser[m.group(1)] + m.group(2), word, 1)

def make_unstressed_once_at_beginning(word):
  # leave graves alone
  return re.sub(u"^([^́̈ёЁ]*)([́̈ёЁ])", lambda m: m.group(1) + destresser[m.group(2)], word, 1)

def correct_grave_acute_clash(word):
  word = re.sub(u"([̀ѐЀѝЍ])́", lambda m: grave_deaccenter[m.group(1)] + AC, word)
  return re.sub(AC + GR, AC, word)

def make_ending_stressed(word):
  # If already ending stressed, just return word so we don't mess up ё
  if is_ending_stressed(word):
    return word
  word = make_unstressed_once(word)
  word = re.sub("([" + vowel_no_jo + "])([^" + vowel + "]*)$", ur"\1́\2", word)
  return correct_grave_acute_clash(word)

def make_beginning_stressed(word):
  # If already beginning stressed, just return word so we don't mess up ё
  if is_beginning_stressed(word):
    return word
  word = make_unstressed_once_at_beginning(word)
  word = re.sub("^([^" + vowel + "]*)([" + vowel_no_jo + "])", ur"\1\2́", word)
  return correct_grave_acute_clash(word)

def try_to_stress(word):
  if is_unaccented(word) and is_monosyllabic(word):
    return make_ending_stressed(word)
  else:
    return word

def add_soft_sign(stem):
  if re.search("[" + vowel + "]$", stem):
    return stem + u"й"
  else:
    return stem + u"ь"

def add_hard_neuter(stem):
  if re.search("[" + sib_c + "]$", stem):
    return stem + u"е"
  else:
    return stem + u"о"

def split_generate_args(tempresult):
  args = {}
  for arg in re.split(r"\|", tempresult):
    name, value = re.split("=", arg)
    args[name] = re.sub("<!>", "|", value)
  return args

# Given an ru-noun+ or ru-proper noun+ template, fetch the arguments
# associated with it. May return None if an error occurred in template
# expansion.
def fetch_noun_args(t, expand_text, forms_only=False):
  generate_template = ("ru-generate-noun-forms" if forms_only else
      "ru-generate-noun-args")
  if unicode(t.name) == "ru-noun+":
    generate_template = re.sub(r"^\{\{ru-noun\+",
        "{{%s" % generate_template, unicode(t))
  else:
    generate_template = re.sub(r"^\{\{ru-proper noun\+",
        "{{%s|ndef=sg" % generate_template, unicode(t))
  generate_result = expand_text(generate_template)
  if not generate_result:
    return None
  return split_generate_args(generate_result)

# Given an ru-noun+ or ru-proper noun+ template, fetch the lemma, which
# is of the form of one or more terms separted by commas, where each
# term is either a Cyrillic word or words, or a combination CYRILLIC/LATIN
# with manual transliteration. May return None if an error occurred
# in template expansion.
def fetch_noun_lemma(t, expand_text):
  # FIXME, probably not necessary to specify forms_only=True
  args = fetch_noun_args(t, expand_text, forms_only=True)
  if args is None:
    return None
  return args["nom_sg"] if "nom_sg" in args else args["nom_pl"]

# Given a list of form values, each of which is a tuple (RUSSIAN, TRANSLIT)
# where the TRANSLIT may be None or the empty string (in both cases treated
# as missing), group by RUSSIAN to handle cases where multiple translits are
# possible, generate any missing translits and join by commas. Return the list
# of form values, in the same order except with multiple translits combined.
def group_translits(formvals, pagemsg, expand_text):
  # Group formvals by Russian, to group multiple translits
  formvals_by_russian = OrderedDict()
  for formvalru, formvaltr in formvals:
    if formvalru in formvals_by_russian:
      formvals_by_russian[formvalru].append(formvaltr)
    else:
      formvals_by_russian[formvalru] = [formvaltr]
  formvals = []
  # If there is more than one translit, then generate the
  # translit for any missing translit and join by commas
  for russian, translits in formvals_by_russian.iteritems():
    if len(translits) == 1:
      formvals.append((russian, translits[0]))
    else:
      manual_translits = []
      for translit in translits:
        if translit:
          manual_translits.append(translit)
        else:
          translit = expand_text("{{xlit|ru|%s}}" % russian)
          if not translit:
            pagemsg("WARNING: Error generating translit for %s" % russian)
          else:
            manual_translits.append(translit)
      joined_manual_translits = ", ".join(manual_translits)
      pagemsg("NOTE: For Russian %s, found multiple manual translits %s" %
          (russian, joined_manual_translits))
      formvals.append((russian, joined_manual_translits))
  return formvals
