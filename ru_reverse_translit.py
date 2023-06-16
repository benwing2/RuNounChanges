#!/usr/bin/env python3
# -*- coding: utf-8 -*-

# This is used to reverse-convert transliterated Latin back to Russian,
# so we can generate phon= for ru-IPA calls from the transliteration.

import re, sys, codecs
import rulib

latin_to_russian_tab_1_char = {
  u"A":u"А", u"B":u"Б", u"V":u"В", u"G":u"Г", u"D":u"Д",
  u"Ž":u"Ж", u"Z":u"З", u"I":u"И", u"J":u"Й",
  u"K":u"К", u"L":u"Л", u"M":u"М", u"N":u"Н", u"O":u"О",
  u"P":u"П", u"R":u"Р", u"S":u"С", u"T":u"Т", u"U":u"У", u"F":u"Ф",
  u"X":u"Х", u"C":u"Ц", u"Č":u"Ч", u"Š":u"Ш",
  u"ʺ":u"Ъ", u"Y":u"Ы", u"ʹ":u"Ь", u"E":u"Э", u"Ɛ":u"Э",
  u"a":u"а", u"b":u"б", u"v":u"в", u"g":u"г", u"d":u"д",
  u"ž":u"ж", u"z":u"з", u"i":u"и", u"j":u"й",
  u"k":u"к", u"l":u"л", u"m":u"м", u"n":u"н", u"o":u"о",
  u"p":u"п", u"r":u"р", u"s":u"с", u"t":u"т", u"u":u"у", u"f":u"ф",
  u"x":u"х", u"c":u"ц", u"č":u"ч", u"š":u"ш",
  u"ʺ":u"ъ", u"y":u"ы", u"ʹ":u"ь", u"e":u"э", u"ɛ":u"э",
  # Russian style quotes
  u"“":u"«", u"”":u"»",
  # archaic, pre-1918 letters
  # can't do the following
  # u"I":u"І", u"i":u"і", u"F":u"Ѳ", u"f":u"ѳ", u"I":u"Ѵ", u"i":u"ѵ",
  u"Ě":u"Ѣ", u"ě":u"ѣ",
}

latin_to_russian_tab_2_char = {
  u"Je":u"Е", u"Ju":u"Ю", u"Ja":u"Я",
  # These are special-cased because of decomposition: u"Jó":u"Ё", u"jó":u"ё",
  u"je":u"е", u"ju":u"ю", u"ja":u"я",
  u"Jě":u"Ѣ", u"jě":u"ѣ",
  u"šč":u"щ", u"Šč":u"Щ",
}

# FIXME! Doesn't work with ɣ, which gets included in this character set
non_consonants = "[" + rulib.vowel + rulib.tr_vowel + ur"ЪЬъьʹʺ\W]"
consonants = "[^" + rulib.vowel + rulib.tr_vowel + ur"ЪЬъьʹʺ\W]"

AC = u"\u0301"
GR = u"\u0300"

def uniprint(x):
  print x.encode('utf-8')
def uniout(x):
  print x.encode('utf-8'),

def rsub(text, fr, to):
  if type(to) is dict:
    def rsub_replace(m):
      try:
        g = m.group(1)
      except IndexError:
        g = m.group(0)
      if g in to:
        return to[g]
      else:
        return g
    return re.sub(fr, rsub_replace, text, 0, re.U)
  else:
    return re.sub(fr, to, text, 0, re.U)

def error(text):
    raise RuntimeError(text)

# Reverse transliterate. Corresponding Cyrillic can be passed in and will be
# used to attempt to reverse transliterate -vo to -го.
def reverse_translit(text, cyrillic=None):
  text = rulib.decompose_acute_grave(text)
  # Not necessary, hard sign should already be present:
  # Need to add hard sign between consonant and j
  # text = rsub(text, "(" + consonants + ")j", ur"\1ʺj")
  text = rsub(text, u"jo" + AC, u"ё")
  text = rsub(text, u"Jo" + AC, u"Ё")
  text = rsub(text, u"[JjŠš].", latin_to_russian_tab_2_char)
  # Reverse-transliterating е and э:
  #   je -> Cyrillic е (handled by latin_to_russian_tab_2_char)
  #   ɛ -> Cyrillic э (handled by latin_to_russian_tab_1_char)
  #   -e at beginning of word -> Cyrillic е
  #   e after consonant + one or more of '() -> Cyrillic е
  #   other e -> Cyrillic э (handled by latin_to_russian_tab_1_char)
  text = rsub(text, r"(^|\s)-e", ur"\1-е")
  text = rsub(text, "(" + consonants + r"['\(\)]*)e", ur"\1е")
  text = rsub(text, u".", latin_to_russian_tab_1_char)
  # If Cyrillic passed in, try to convert -во in output back to -го when
  # appropriate
  if cyrillic:
    textwords = re.split(r"([\s,-]+)", text)
    cyrwords = re.split(r"([\s,-]+)", cyrillic)
    if len(textwords) == len(cyrwords):
      for i in range(len(textwords)):
        if re.search(u"го́?$", cyrwords[i]) and re.search(u"во́?$", textwords[i]):
          textwords[i] = re.sub(u"в(о́?)$", ur"г\1", textwords[i])
      return "".join(textwords)

  return text

################################ Test code ##########################

num_failed = 0
num_succeeded = 0

def test(latin, russian):
  global num_succeeded, num_failed
  try:
    result = reverse_translit(latin)
  except RuntimeError as e:
    uniprint(u"%s" % e)
    result = False
  if result == False or result != russian:
    uniprint("reverse_translit(%s) = %s, FAILED (expected %s)" %
        (latin, result, russian))
    num_failed += 1
  else:
    uniprint("reverse_translit(%s) = %s, SUCCEEDED" %
        (latin, result))
    num_succeeded += 1

def run_tests():
  global num_succeeded, num_failed
  num_succeeded = 0
  num_failed = 0

  test("zontik", u"зонтик")
  test(u"zóntik", u"зо́нтик")

  # Test with Cyrillic e
  test(u"jebepʹje jebe", u"ебепье ебе")
  test("jebe jebe", u"ебе ебе")
  test("Jebe Jebe", u"Ебе Ебе")
  test("ebe ebe", u"эбе эбе")
  test("Ebe Ebe", u"Эбе Эбе")
  test(u"ébe ébe", u"э́бе э́бе")
  test(u"Ébe Ébe", u"Э́бе Э́бе")
  test(u"jéje jéje", u"е́е е́е")
  test(u"je" + AC + "je je" + AC + "je", u"е́е е́е")
  test(u"-ec", u"-ец")
  test(u"-éc", u"-е́ц")
  test(u"foo -ec", u"фоо -ец")
  test(u"foo -éc", u"фоо -е́ц")
  test(u"b'''ez", u"б'''ез")
  test(u"amerikán(ec)", u"америка́н(ец)")

  # Test with jo
  test(u"ketjó", u"кетё")
  test(u"kétjo", u"ке́тйо")

  test(u"Igor", u"Игор")
  test(u"rajónʺ", u"раёнъ")
  test(u"bljad", u"бляд")
  test(u"sobólʹ", u"собо́ль")
  test(u"časóvnja", u"часо́вня")
  test(u"ekzistencializm", u"экзистенциализм")
  test(u"ješčó", u"ещо́")
  test(u"prýšik", u"пры́шик")
  test(u"óstrov Rejunʹjón", u"о́стров Реюньён")
  test(u"staromodnyj", u"старомодный")
  test(u"brunɛ́jec", u"брунэ́ец")

  # Final results
  uniprint("RESULTS: %s SUCCEEDED, %s FAILED." % (num_succeeded, num_failed))

if __name__ == "__main__":
    run_tests()
