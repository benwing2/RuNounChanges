#!/usr/bin/env python
#coding: utf-8

import re, sys

AC = u"\u0301"
vowels = u"аеиоуіяєїю"
vowels_c = "[" + vowels + "]"
non_vowels_c = "[^" + vowels + "]"

def remove_accents(word):
  return word.replace(AC, "")

def is_unstressed(word):
  return AC not in word

def is_stressed(word):
  return AC in word

def is_multi_stressed(word):
  num_stresses = sum(1 if x == AC else 0 for x in word)
  return num_stresses > 1

def is_monosyllabic(word):
  return len(re.sub(non_vowels_c, "", word)) <= 1

def add_monosyllabic_stress(word):
  if is_monosyllabic(word) and not is_stressed(word):
    return re.sub("(" + vowels_c + ")", r"\1" + AC, word)
  else:
    return word

def needs_accent(word):
  return not is_monosyllabic(word) and is_unstressed(word)

def is_end_stressed(word, possible_endings=[]):
  for ending in possible_endings:
    if not re.search(vowels_c, ending):
      continue
    ending = remove_accents(ending)
    if not word.endswith(ending) and remove_accents(word).endswith(ending):
      return True
  return not not re.search(AC + non_vowels_c + "*$", word)

def is_mixed_stressed(word, possible_endings=[]):
  return is_multi_stressed(word) and is_end_stressed(word, possible_endings)
