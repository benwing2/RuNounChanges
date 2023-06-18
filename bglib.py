#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import re
import unicodedata
import blib
from collections import OrderedDict

AC = u"\u0301" # acute =  ́
GR = u"\u0300" # grave =  ̀

# non-primary accents (i.e. excluding acute) that indicate pronunciation
# (not counting diaeresis, which indicates a completely different vowel,
# and caron, which is used in translit as ě to indicate the yat vowel)
non_primary_pron_accents = GR
# accents that indicate pronunciation (not counting diaresis, which indicates
# a completely different vowel)
pron_accents = AC + non_primary_pron_accents
# all accents
accents = pron_accents
# accents indicating stress (primary or otherwise)
stress_accents = AC + GR

# regex for any optional accent(s)
opt_accent = "[" + accents + "]*"

composed_grave_vowel = u"ѐЀѝЍ"
vowel = u"аеиоуяюъѣАЕИОУЯЮЪѢ" + composed_grave_vowel

def decompose_acute_grave(text):
  # Decompose sequences of character + acute or grave, but compose all other
  # accented sequences, e.g. Latin č and ě, Cyrillic ё and й.
  # (1) Decompose entirely.
  decomposed = unicodedata.normalize("NFD", str(text))
  # (2) Split into text sections separated by acutes and graves.
  split = re.split("([%s%s])" % (AC, GR), decomposed)
  # (3) Recompose each section.
  recomposed = [unicodedata.normalize("NFC", part) for part in split]
  # (4) Paste sections together.
  return "".join(recomposed)

def decompose(text):
  return decompose_acute_grave(text)

def recompose(text):
  return unicodedata.normalize("NFC", text)

def assert_decomposed(text):
  assert not re.search(u"[áéíóúýàèìòùỳäëïöüÿÁÉÍÓÚÝÀÈÌÒÙỲÄËÏÖÜŸ]", text)

def xlit_text(text, pagemsg, verbose=False):
  def expand_text(tempcall):
    # The page name doesn't matter when we call {{xlit}}.
    return blib.expand_text(tempcall, "foo bar", pagemsg, verbose)
  return expand_text("{{xlit|ru|%s}}" % text)

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

def is_unaccented(word):
  return not re.search("[" + stress_accents + u"ѐЀѝЍ]", word)

def number_of_accents(text):
  return len(re.sub("[^" + accents + u"ѐЀѝЍ]", "", text))

def is_beginning_stressed(word):
  return re.search("^[^" + vowel + "]*[" + vowel + u"]́", word)

def is_nonsyllabic(word):
  return not re.search("[" + vowel + "]", word)

# Includes non-syllabic stems such as зл-
def is_monosyllabic(word):
  word = re.sub(u"ъ$", "", word)
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

def remove_accents(word):
  # remove pronunciation accents
  return re.sub("([" + pron_accents + u"ѐЀѝЍ])",
    lambda m: deaccenter[m.group(1)], word)

def remove_monosyllabic_accents(word):
  # note: This doesn't affect diaeresis (composed or uncomposed) because
  # it indicates a change in vowel quality, which still applies to
  # monosyllabic words.
  if is_monosyllabic(word) and not word.startswith("-"):
    return remove_accents(word)
  return word

def remove_non_primary_accents(word):
  # remove all pronunciation accents except acute
  return re.sub("([" + non_primary_pron_accents + u"ѐЀѝЍ])",
    lambda m: deaccenter[m.group(1)], word)

def find_defns(text):
  return blib.find_defns(text, "bg")
