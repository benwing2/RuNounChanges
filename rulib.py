#!/usr/bin/env python
# -*- coding: utf-8 -*-

import re

AC = u"\u0301"
GR = u"\u0300"
vowels_no_jo = u"аеиоуяэыюіѣѵАЕИОУЯЭЫЮІѢѴ"
vowels = vowels_no_jo + u"ёЁ"
velar_cons = u"кгхКГХ"
sib_cons = u"шщчжШЩЧЖ"
velar_sib = velar_cons + sib_cons
sib_c = sib_cons + u"цЦ"

def is_stressed(word):
  return re.search(ur"[ё" + AC + GR + "]", word)

def is_unstressed(word):
  return not is_stressed(word)

def is_one_syllable(word):
  return len(re.sub("[^" + vowels + "]", "", word)) == 1

# assumes word is unstressed
def make_ending_stressed(word):
  word = re.sub("([" + vowels_no_jo + "])([^" + vowels_no_jo + "]*)$",
      r"\1" + AC + r"\2", word)
  return word

def try_to_stress(word):
  if is_unstressed(word) and is_one_syllable(word):
    return make_ending_stressed(word)
  else:
    return word

# Just remove the rightmost stress, in case we have ё plus a later stress
def make_unstressed(word):
  word = word.replace(u"ё́", u"ё") # in case of accent on top of ё
  return re.sub(u"([ё́])([^ё́]*)$", lambda m: (m.group(1) == u"ё" and u"е" or "") + m.group(2), word)

def make_unstressed_all(word):
  word = word.replace(u"ё", u"е")
  word = word.replace(AC, "")
  word = word.replace(GR, "")
  return word

def add_soft_sign(stem):
  if re.search("[" + vowels + "]$", stem):
    return stem + u"й"
  else:
    return stem + u"ь"

def add_hard_neuter(stem):
  if re.search("[" + sib_c + "]$", stem):
    return stem + u"е"
  else:
    return stem + u"о"

def do_assert(cond, msg=None):
  if msg:
    assert cond, msg
  else:
    assert cond
  return True

def remove_links(text):
  # eliminate [[FOO| in [[FOO|BAR]], and then remaining [[ and ]]
  text = re.sub(r"\[\[[^|\[\]]*\|", "", text)
  text = re.sub(r"\[\[|\]\]", "", text)
  return text

