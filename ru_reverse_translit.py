#!/usr/bin/env python3
# -*- coding: utf-8 -*-

# This is used to reverse-convert transliterated Latin back to Russian,
# so we can generate phon= for ru-IPA calls from the transliteration.

import re, sys
import rulib

latin_to_russian_tab_1_char = {
  "A":"А", "B":"Б", "V":"В", "G":"Г", "D":"Д",
  "Ž":"Ж", "Z":"З", "I":"И", "J":"Й",
  "K":"К", "L":"Л", "M":"М", "N":"Н", "O":"О",
  "P":"П", "R":"Р", "S":"С", "T":"Т", "U":"У", "F":"Ф",
  "X":"Х", "C":"Ц", "Č":"Ч", "Š":"Ш",
  "ʺ":"Ъ", "Y":"Ы", "ʹ":"Ь", "E":"Э", "Ɛ":"Э",
  "a":"а", "b":"б", "v":"в", "g":"г", "d":"д",
  "ž":"ж", "z":"з", "i":"и", "j":"й",
  "k":"к", "l":"л", "m":"м", "n":"н", "o":"о",
  "p":"п", "r":"р", "s":"с", "t":"т", "u":"у", "f":"ф",
  "x":"х", "c":"ц", "č":"ч", "š":"ш",
  "ʺ":"ъ", "y":"ы", "ʹ":"ь", "e":"э", "ɛ":"э",
  # Russian style quotes
  "“":"«", "”":"»",
  # archaic, pre-1918 letters
  # can't do the following
  # "I":"І", "i":"і", "F":"Ѳ", "f":"ѳ", "I":"Ѵ", "i":"ѵ",
  "Ě":"Ѣ", "ě":"ѣ",
}

latin_to_russian_tab_2_char = {
  "Je":"Е", "Ju":"Ю", "Ja":"Я",
  # These are special-cased because of decomposition: "Jó":"Ё", "jó":"ё",
  "je":"е", "ju":"ю", "ja":"я",
  "Jě":"Ѣ", "jě":"ѣ",
  "šč":"щ", "Šč":"Щ",
}

# FIXME! Doesn't work with ɣ, which gets included in this character set
non_consonants = "[" + rulib.vowel + rulib.tr_vowel + r"ЪЬъьʹʺ\W]"
consonants = "[^" + rulib.vowel + rulib.tr_vowel + r"ЪЬъьʹʺ\W]"

AC = "\u0301"
GR = "\u0300"

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
  # text = rsub(text, "(" + consonants + ")j", r"\1ʺj")
  text = rsub(text, "jo" + AC, "ё")
  text = rsub(text, "Jo" + AC, "Ё")
  text = rsub(text, "[JjŠš].", latin_to_russian_tab_2_char)
  # Reverse-transliterating е and э:
  #   je -> Cyrillic е (handled by latin_to_russian_tab_2_char)
  #   ɛ -> Cyrillic э (handled by latin_to_russian_tab_1_char)
  #   -e at beginning of word -> Cyrillic е
  #   e after consonant + one or more of '() -> Cyrillic е
  #   other e -> Cyrillic э (handled by latin_to_russian_tab_1_char)
  text = rsub(text, r"(^|\s)-e", r"\1-е")
  text = rsub(text, "(" + consonants + r"['\(\)]*)e", r"\1е")
  text = rsub(text, ".", latin_to_russian_tab_1_char)
  # If Cyrillic passed in, try to convert -во in output back to -го when
  # appropriate
  if cyrillic:
    textwords = re.split(r"([\s,-]+)", text)
    cyrwords = re.split(r"([\s,-]+)", cyrillic)
    if len(textwords) == len(cyrwords):
      for i in range(len(textwords)):
        if re.search("го́?$", cyrwords[i]) and re.search("во́?$", textwords[i]):
          textwords[i] = re.sub("в(о́?)$", r"г\1", textwords[i])
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
    print("%s" % e)
    result = False
  if result == False or result != russian:
    print("reverse_translit(%s) = %s, FAILED (expected %s)" %
        (latin, result, russian))
    num_failed += 1
  else:
    print("reverse_translit(%s) = %s, SUCCEEDED" %
        (latin, result))
    num_succeeded += 1

def run_tests():
  global num_succeeded, num_failed
  num_succeeded = 0
  num_failed = 0

  test("zontik", "зонтик")
  test("zóntik", "зо́нтик")

  # Test with Cyrillic e
  test("jebepʹje jebe", "ебепье ебе")
  test("jebe jebe", "ебе ебе")
  test("Jebe Jebe", "Ебе Ебе")
  test("ebe ebe", "эбе эбе")
  test("Ebe Ebe", "Эбе Эбе")
  test("ébe ébe", "э́бе э́бе")
  test("Ébe Ébe", "Э́бе Э́бе")
  test("jéje jéje", "е́е е́е")
  test("je" + AC + "je je" + AC + "je", "е́е е́е")
  test("-ec", "-ец")
  test("-éc", "-е́ц")
  test("foo -ec", "фоо -ец")
  test("foo -éc", "фоо -е́ц")
  test("b'''ez", "б'''ез")
  test("amerikán(ec)", "америка́н(ец)")

  # Test with jo
  test("ketjó", "кетё")
  test("kétjo", "ке́тйо")

  test("Igor", "Игор")
  test("rajónʺ", "раёнъ")
  test("bljad", "бляд")
  test("sobólʹ", "собо́ль")
  test("časóvnja", "часо́вня")
  test("ekzistencializm", "экзистенциализм")
  test("ješčó", "ещо́")
  test("prýšik", "пры́шик")
  test("óstrov Rejunʹjón", "о́стров Реюньён")
  test("staromodnyj", "старомодный")
  test("brunɛ́jec", "брунэ́ец")

  # Final results
  print("RESULTS: %s SUCCEEDED, %s FAILED." % (num_succeeded, num_failed))

if __name__ == "__main__":
    run_tests()
