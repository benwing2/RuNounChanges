#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# Authors: Benwing, ZxxZxxZ, Atitarev

import re, unicodedata
import arabiclib
from arabiclib import *
from blib import remove_links, msg

# FIXME!! To do:
#
# 1. Modify Module:ar-translit to convert – (long dash) into regular -;
#  also need extra clause in has_diacritics_subs (2nd one)
# 2. alif madda should match against 'a with short a

# STATUS:
#
# OK to run. We actually did a run saving the results, using a page file,
# like this:
#
# python canon_arabic.py --cattype pages --page-file canon_arabic.4+14.saved-pages.out --save >! canon_arabic.15.saved-pages.save.out
#
# But it was interrupted partway through.
#
# Wrote parse_log_file.py to create a modified log file suitable for editing
# to allow manual changes to be saved rapidly (using a not-yet-written script,
# presumably modeled on undo_greek_removal.py).

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
    return re.sub(fr, rsub_replace, text)
  else:
    return re.sub(fr, to, text)

def error(text):
  raise RuntimeError(text)

def nfkc_form(txt):
  return unicodedata.normalize("NFKC", str(txt))

def nfc_form(txt):
  return unicodedata.normalize("NFC", str(txt))

zwnj = "\u200c" # zero-width non-joiner
zwj  = "\u200d" # zero-width joiner
#lrm = "\u200e" # left-to-right mark
#rlm = "\u200f" # right-to-left mark

tt = {
  # consonants
  "ب":"b", "ت":"t", "ث":"ṯ", "ج":"j", "ح":"ḥ", "خ":"ḵ",
  "د":"d", "ذ":"ḏ", "ر":"r", "ز":"z", "س":"s", "ش":"š",
  "ص":"ṣ", "ض":"ḍ", "ط":"ṭ", "ظ":"ẓ", "ع":"ʿ", "غ":"ḡ",
  "ف":"f", "ق":"q", "ك":"k", "ل":"l", "م":"m", "ن":"n",
  "ه":"h",
  # tāʾ marbūṭa (special) - always after a fatḥa (a), silent at the end of
  # an utterance, "t" in ʾiḍāfa or with pronounced tanwīn. We catch
  # most instances of tāʾ marbūṭa before we get to this stage.
  "\u0629":"t", # tāʾ marbūṭa = ة
  # control characters
  zwnj:"-", # ZWNJ (zero-width non-joiner)
  zwj:"-", # ZWJ (zero-width joiner)
  # rare letters
  "پ":"p", "چ":"č", "ڤ":"v", "گ":"g", "ڨ":"g", "ڧ":"q",
  # semivowels or long vowels, alif, hamza, special letters
  "ا":"ā", # ʾalif = \u0627
  # hamzated letters
  "أ":"ʾ", "إ":"ʾ", "ؤ":"ʾ", "ئ":"ʾ", "ء":"ʾ",
  "و":"w", #"ū" after ḍamma (u) and not before diacritic = \u0648
  "ي":"y", #"ī" after kasra (i) and not before diacritic = \u064A
  "ى":"ā", # ʾalif maqṣūra = \u0649
  "آ":"ʾā", # ʾalif madda = \u0622
  "ٱ":"", # hamzatu l-waṣl = \u0671
  "\u0670":"ā", # ʾalif xanjariyya = dagger ʾalif (Koranic diacritic)
  # short vowels, šádda and sukūn
  "\u064B":"an", # fatḥatān
  "\u064C":"un", # ḍammatān
  "\u064D":"in", # kasratān
  "\u064E":"a", # fatḥa
  "\u064F":"u", # ḍamma
  "\u0650":"i", # kasra
  # \u0651 = šadda - doubled consonant
  "\u0652":"", #sukūn - no vowel
  # ligatures
  "ﻻ":"lā",
  "ﷲ":"llāh",
  # taṭwīl
  "ـ":"", # taṭwīl, no sound
  # numerals
  "١":"1", "٢":"2", "٣":"3", "٤":"4", "٥":"5",
  "٦":"6", "٧":"7", "٨":"8", "٩":"9", "٠":"0",
  # punctuation (leave on separate lines)
  "؟":"?", # question mark
  "،":",", # comma
  "؛":";", # semicolon
  "–":"-", # long dash
}

sun_letters = "تثدذرزسشصضطظلن"
# For use in implementing sun-letter assimilation of ال (al-)
ttsun1 = {}
ttsun2 = {}
for ch in sun_letters:
  ttsun1[ch] = tt[ch]
  ttsun2["l-" + ch] = tt[ch] + "-" + ch
# For use in implementing elision of al-
sun_letters_tr = ''.join(ttsun1.values())

consonants_needing_vowels = "بتثجحخدذرزسشصضطظعغفقكلمنهپچڤگڨڧأإؤئءةﷲ"
# consonants on the right side; includes alif madda
rconsonants = consonants_needing_vowels + "ويآ"
# consonants on the left side; does not include alif madda
lconsonants = consonants_needing_vowels + "وي"
punctuation = ("؟،؛" # Arabic semicolon, comma, question mark
         + "ـ" # taṭwīl
         + ".!'" # period, exclamation point, single quote for bold/italic
         )
numbers = "١٢٣٤٥٦٧٨٩٠"

before_diacritic_checking_subs = [
  ########### transformations prior to checking for diacritics ##############
  # remove the first part of [[foo|bar]] links
  [r"\[\[[^]]*\|", ""],
  # remove brackets in [[foo]] links
  [r"[\[\]]", ""],
  # convert llh for allāh into ll+shadda+dagger-alif+h
  ["لله", "للّٰه"],
  # shadda+short-vowel (including tanwīn vowels, i.e. -an -in -un) gets
  # replaced with short-vowel+shadda during NFC normalisation, which
  # MediaWiki does for all Unicode strings; however, it makes the
  # transliteration process inconvenient, so undo it.
  ["([\u064B\u064C\u064D\u064E\u064F\u0650\u0670])\u0651", "\u0651\\1"],
  # ignore alif jamīla (otiose alif in 3pl verb forms)
  #   #1: handle ḍamma + wāw + alif (final -ū)
  ["\u064F\u0648\u0627", "\u064F\u0648"],
  #   #2: handle wāw + sukūn + alif (final -w in -aw in defective verbs)
  #   this must go before the generation of w, which removes the waw here.
  ["\u0648\u0652\u0627", "\u0648\u0652"],
  # ignore final alif or alif maqṣūra following fatḥatān (e.g. in accusative
  # singular or words like عَصًا "stick" or هُذًى "guidance"; this is called
  # tanwīn nasb)
  ["\u064B[\u0627\u0649]", "\u064B"],
  # same but with the fatḥatān placed over the alif or alif maqṣūra
  # instead of over the previous letter (considered a misspelling but
  # common)
  ["[\u0627\u0649]\u064B", "\u064B"],
  # tāʾ marbūṭa should always be preceded by fatḥa, alif, alif madda or
  # dagger alif; infer fatḥa if not
  ["([^\u064E\u0627\u0622\u0670])\u0629", "\\1\u064E\u0629"],
  # similarly for alif between consonants, possibly marked with shadda
  # (does not apply to initial alif, which is silent when not marked with
  # hamza, or final alif, which might be pronounced as -an)
  ["([" + lconsonants + "]\u0651?)\u0627([" + rconsonants + "])",
    "\\1\u064E\u0627\\2"],
  # infer fatḥa in case of non-fatḥa + alif/alif-maqṣūra + dagger alif
  ["([^\u064E])([\u0627\u0649]\u0670)", "\\1\u064E\\2"],
  # infer kasra in case of hamza-under-alif not + kasra
  ["\u0625([^\u0650])", "\u0625\u0650\\1"],
  # ignore dagger alif placed over regular alif or alif maqṣūra
  ["([\u0627\u0649])\u0670", "\\1"],

  # al + consonant + shadda (only recognize word-initially if regular alif): remove shadda
  ["(^|\\s)(\u0627\u064E?\u0644[" + lconsonants + "])\u0651", "\\1\\2"],
  ["(\u0671\u064E?\u0644[" + lconsonants + "])\u0651", "\\1"],
  # handle l- hamzatu l-waṣl or word-initial al-
  ["(^|\\s)\u0627\u064E?\u0644", "\\1al-"],
  ["\u0671\u064E?\u0644", "l-"],
  # implement assimilation of sun letters
  ["l-[" + sun_letters + "]", ttsun2]
]

# Transliterate the word(s) in TEXT. LANG (the language) and SC (the script)
# are ignored. OMIT_I3RAAB means leave out final short vowels (ʾiʿrāb).
# GRAY_I3RAAB means render transliterate short vowels (ʾiʿrāb) in gray.
# FORCE_TRANSLATE causes even non-vocalized text to be transliterated
# (normally the function checks for non-vocalized text and returns nil,
# since such text is ambiguous in transliteration).
def tr(text, lang=None, sc=None, omit_i3raab=False, gray_i3raab=False,
    force_translate=False, msgfun=msg):
  for sub in before_diacritic_checking_subs:
    text = rsub(text, sub[0], sub[1])

  if not force_translate and not has_diacritics(text):
    return None

  ############# transformations after checking for diacritics ##############
  # Replace plain alif with hamzatu l-waṣl when followed by fatḥa/ḍamma/kasra.
  # Must go after handling of initial al-, which distinguishes alif-fatḥa
  # from alif w/hamzatu l-waṣl. Must go before generation of ū and ī, which
  # eliminate the ḍamma/kasra.
  text = rsub(text, "\u0627([\u064E\u064F\u0650])", "\u0671\\1")
  # ḍamma + waw not followed by a diacritic is ū, otherwise w
  text = rsub(text, "\u064F\u0648([^\u064B\u064C\u064D\u064E\u064F\u0650\u0651\u0652\u0670])", "ū\\1")
  text = rsub(text, "\u064F\u0648$", "ū")
  # kasra + yaa not followed by a diacritic (or ū from prev step) is ī, otherwise y
  text = rsub(text, "\u0650\u064A([^\u064B\u064C\u064D\u064E\u064F\u0650\u0651\u0652\u0670ū])", "ī\\1")
  text = rsub(text, "\u0650\u064A$", "ī")
  # convert shadda to double letter.
  text = rsub(text, "(.)\u0651", "\\1\\1")
  if not omit_i3raab and gray_i3raab: # show ʾiʿrāb grayed in transliteration
    # decide whether to gray out the t in ة. If word begins with al-, yes.
    # Otherwise, no if word ends in a/i/u, yes if ends in an/in/un.
    text = rsub(text, "((?:^|\\s)a?l-[^\\s]+)\u0629([\u064B\u064C\u064D\u064E\u064F\u0650])",
      "\\1<span style=\"color: #888888\">t</span>\\2")
    text = rsub(text, "\u0629([\u064E\u064F\u0650])", "t\\1")
    text = rsub(text, "\u0629([\u064B\u064C\u064D])",
      "<span style=\"color: #888888\">t</span>\\1")
    text = rsub(text, ".", {
      "\u064B":"<span style=\"color: #888888\">an</span>",
      "\u064D":"<span style=\"color: #888888\">in</span>",
      "\u064C":"<span style=\"color: #888888\">un</span>"
    })
    text = rsub(text, "([\u064E\u064F\u0650])\\s", {
      "\u064E":"<span style=\"color: #888888\">a</span> ",
      "\u0650":"<span style=\"color: #888888\">i</span> ",
      "\u064F":"<span style=\"color: #888888\">u</span> "
    })
    text = rsub(text, "[\u064E\u064F\u0650]$", {
      "\u064E":"<span style=\"color: #888888\">a</span>",
      "\u0650":"<span style=\"color: #888888\">i</span>",
      "\u064F":"<span style=\"color: #888888\">u</span>"
    })
    text = rsub(text, "</span><span style=\"color: #888888\">", "")
  elif omit_i3raab: # omit ʾiʿrāb in transliteration
    text = rsub(text, "[\u064B\u064C\u064D]", "")
    text = rsub(text, "[\u064E\u064F\u0650]\\s", " ")
    text = rsub(text, "[\u064E\u064F\u0650]$", "")
  # tāʾ marbūṭa should not be rendered by -t if word-final even when
  # ʾiʿrāb (desinential inflection) is shown; instead, use (t) before
  # whitespace, nothing when final; but render final -اة and -آة as -āh,
  # consistent with Wehr's dictionary
  text = rsub(text, "([\u0627\u0622])\u0629$", "\\1h")
  # Ignore final tāʾ marbūṭa (it appears as "a" due to the preceding
  # short vowel). Need to do this after graying or omitting word-final
  # ʾiʿrāb.
  text = rsub(text, "\u0629$", "")
  if not omit_i3raab: # show ʾiʿrāb in transliteration
    text = rsub(text, "\u0629\\s", "(t) ")
  else:
    # When omitting ʾiʿrāb, show all non-absolutely-final instances of
    # tāʾ marbūṭa as (t), with trailing ʾiʿrāb omitted.
    text = rsub(text, "\u0629", "(t)")
  # tatwīl should be rendered as - at beginning or end of word. It will
  # be rendered as nothing in the middle of a word (FIXME, do we want
  # this?)
  text = rsub(text, "^ـ", "-")
  text = rsub(text, "\\sـ", " -")
  text = rsub(text, "ـ$", "-")
  text = rsub(text, "ـ\\s", "- ")
  # Now convert remaining Arabic chars according to table.
  text = rsub(text, ".", tt)
  text = rsub(text, "aā", "ā")
  # Implement elision of al- after a final vowel. We do this
  # conservatively, only handling elision of the definite article rather
  # than elision in other cases of hamzat al-waṣl (e.g. form-I imperatives
  # or form-VII and above verbal nouns) partly because elision in
  # these cases isn't so common in MSA and partly to avoid excessive
  # elision in case of words written with initial bare alif instead of
  # properly with hamzated alif. Possibly we should reconsider.
  # At the very least we currently don't handle elision of الَّذِي (allaḏi)
  # correctly because we special-case it to appear without the hyphen;
  # perhaps we should reconsider that.
  text = rsub(text, "([aiuāīū](?:</span>)?) a([" + sun_letters_tr + "]-)",
    "\\1 \\2")
  # Special-case the transliteration of allāh, without the hyphen
  text = rsub(text, "(^|\\s)(a?)l-lāh", "\\1\\2llāh")

  return text

has_diacritics_subs = [
  # FIXME! What about lam-alif ligature?
  # remove punctuation and shadda
  # must go before removing final consonants
  ["[" + punctuation + "\u0651]", ""],
  # Convert dash/hyphen to space so we can handle cases like وَيْد–جَيْلْز
  # "wayd-jaylz" (Wade-Giles).
  ["[-–]", " "],
  # Remove consonants at end of word or utterance, so that we're OK with
  # words lacking iʿrāb (must go before removing other consonants).
  # If you want to catch places without iʿrāb, comment out the next two lines.
  ["[" + lconsonants + "]$", ""],
  ["[" + lconsonants + "]\\s", " "],
  # remove consonants (or alif) when followed by diacritics
  # must go after removing shadda
  # do not remove the diacritics yet because we need them to handle
  # long-vowel sequences of diacritic + pseudo-consonant
  ["[" + lconsonants + "\u0627]([\u064B\u064C\u064D\u064E\u064F\u0650\u0652\u0670])", "\\1"],
  # the following two must go after removing consonants w/diacritics because
  # we only want to treat vocalic wāw/yā' in them (we want to have removed
  # wāw/yā' followed by a diacritic)
  # remove ḍamma + wāw
  ["\u064F\u0648", ""],
  # remove kasra + yā'
  ["\u0650\u064A", ""],
  # remove fatḥa/fatḥatān + alif/alif-maqṣūra
  ["[\u064B\u064E][\u0627\u0649]", ""],
  # remove diacritics
  ["[\u064B\u064C\u064D\u064E\u064F\u0650\u0652\u0670]", ""],
  # remove numbers, hamzatu l-waṣl, alif madda
  ["[" + numbers + "ٱ" + "آ" + "]", ""],
  # remove non-Arabic characters
  ["[^\u0600-\u06FF\u0750-\u077F\u08A1-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF]", ""]
]

def has_diacritics(text):
  for sub in has_diacritics_subs:
    text = rsub(text, sub[0], sub[1])
  return len(text) == 0


############################################################################
#           Transliterate from Latin to Arabic           #
############################################################################

#########     Transliterate with unvocalized Arabic to guide     #########

silent_alif_subst = "\ufff1"
silent_alif_maqsuura_subst = "\ufff2"
multi_single_quote_subst = "\ufff3"
assimilating_l_subst = "\ufff4"
double_l_subst = "\ufff5"
dagger_alif_subst = "\ufff6"

hamza_match = ["ʾ","ʼ","'","´",("`",),"ʔ","’",("‘",),"ˀ",
    ("ʕ",),("ʿ",),"2"]
hamza_match_or_empty = hamza_match + [""]
hamza_match_chars = [x[0] if isinstance(x, list) or isinstance(x, tuple) else x
    for x in hamza_match]

# Special-case matching at beginning of word. Plain alif normally corresponds
# to nothing, and hamza seats might correspond to nothing (omitted hamza
# at beginning of word). We can't allow e.g. أ to have "" as one of its
# possibilities mid-word because that will screw up a word like سألة "saʾala",
# which won't match at all because the أ will match nothing directly after
# the Latin "s", and then the ʾ will never be matched.
tt_to_arabic_matching_bow = { #beginning of word
  # put empty string in list so this entry will be recognized -- a plain
  # empty string is considered logically false
  "ا":[""],
  "أ":hamza_match_or_empty,
  "إ":hamza_match_or_empty,
  "آ":["ʾaā","’aā","'aā","`aā","aā"], #ʾalif madda = \u0622
}

# Special-case matching at end of word. Some ʾiʿrāb endings may appear in
# the Arabic but not the transliteration; allow for that.
tt_to_arabic_matching_eow = { # end of word
  UN:["un",""], # ḍammatān
  IN:["in",""], # kasratān
  A:["a",""], # fatḥa (in plurals)
  U:["u",""], # ḍamma (in diptotes)
  I:["i",""], # kasra (in duals)
}

# This dict maps Arabic characters to all the Latin characters that
# might correspond to them. The entries can be a string (equivalent
# to a one-entry list) or a list of strings or one-element lists
# containing strings (the latter is equivalent to a string but
# suppresses canonicalization during transliteration; see below). The
# ordering of elements in the list is important insofar as which
# element is first, because the default behavior when canonicalizing
# a transliteration is to substitute any string in the list with the
# first element of the list (this can be suppressed by making an
# element a one-entry list containing a string, as mentioned above).
#
# If the element of a list is a one-element tuple, we canonicalize
# during match-canonicalization but we do not trigger the check for
# multiple possible canonicalizations during self-canonicalization;
# instead we indicate that this character occurs somewhere else and
# should be canonicalized at self-canonicalization according to that
# somewhere-else. (For example, ` occurs as a match for both ʿ and ʾ;
# in the latter's list, it is a one-element tuple, meaning during
# self-canonicalization it will get canonicalized into ʿ and not left
# alone, as it otherwise would due to occurring as a match for multiple
# characters.)
#
# Each string might have multiple characters, to handle things
# like خ=kh and ث=th.

tt_to_arabic_matching = {
  # consonants
  "ب":["b",["p"]], "ت":"t",
  "ث":["ṯ","ŧ","θ","th"],
  # FIXME! We should canonicalize ʒ to ž
  "ج":["j","ǧ","ğ","ǰ","dj","dǧ","dğ","dǰ","dž","dʒ",["ʒ"],
    ["ž"],["g"]],
  # Allow what would normally be capital H, but we lowercase all text
  # before processing; always put the plain letters last so previous longer
  # sequences match (which may be letter + combining char).
  # I feel a bit uncomfortable allowing kh to match against ح like this,
  # but generally I trust the Arabic more.
  "ح":["ḥ","ħ","ẖ","ḩ","7",("kh",),"h"],
  # I feel a bit uncomfortable allowing ḥ to match against خ like this,
  # but generally I trust the Arabic more.
  "خ":["ḵ","kh","ḫ","ḳ","ẖ","χ",("ḥ",),"x"],
  "د":"d",
  "ذ":["ḏ","đ","ð","dh","ḍ","ẕ","d"],
  "ر":"r",
  "ز":"z",
  # I feel a bit uncomfortable allowing emphatic variants of s to match
  # against س like this, but generally I trust the Arabic more.
  "س":["s",("ṣ",),("sʿ",),("sˤ",),("sˁ",),("sʕ",),("ʂ",),("ṡ",)],
  "ش":["š","sh","ʃ"],
  # allow non-emphatic to match so we can handle uppercase S, D, T, Z;
  # we lowercase the text before processing to handle proper names and such;
  # always put the plain letters last so previous longer sequences match
  # (which may be letter + combining char)
  "ص":["ṣ","sʿ","sˤ","sˁ","sʕ","ʂ","ṡ","s"],
  "ض":["ḍ","dʿ","dˤ","dˁ","dʕ","ẓ","ɖ","ḋ","d"],
  "ط":["ṭ","tʿ","tˤ","tˁ","tʕ","ṫ","ţ","ŧ","ʈ","t̤","t"],
  "ظ":["ẓ","ðʿ","ðˤ","ðˁ","ðʕ","ð̣","đʿ","đˤ","đˁ","đʕ","đ̣",
    "ż","ʐ","dh","z"],
  "ع":["ʿ","ʕ","`","‘","ʻ","3","ˤ","ˁ",("'",),("ʾ",),"῾",("’",)],
  "غ":["ḡ","ġ","ğ","gh",["g"],("`",)],
  "ف":["f",["v"]],
  # I feel a bit uncomfortable allowing k to match against q like this,
  # but generally I trust the Arabic more
  "ق":["q","ḳ",["g"],"k"],
  "ك":["k",["g"]],
  "ل":"l",
  "م":"m",
  "ن":"n",
  "ه":"h",
  # We have special handling for the following in the canonicalized Latin,
  # so that we have -a but -āh and -at-.
  "ة":["h",["t"],["(t)"],""],
  # control characters
  # The following are unnecessary because we handle them specially in
  # check_against_hyphen() and other_arabic_chars.
  #zwnj:["-"],#,""], # ZWNJ (zero-width non-joiner)
  #zwj:["-"],#,""], # ZWJ (zero-width joiner)
  # rare letters
  "پ":"p",
  "چ":["č","ch"],
  "ڤ":"v",
  "گ":"g",
  "ڨ":"g",
  "ڧ":"q",
  # semivowels or long vowels, alif, hamza, special letters
  "ا":"ā", # ʾalif = \u0627
  # put empty string in list so not considered logically false, which can
  # mess with the logic
  silent_alif_subst:[""],
  silent_alif_maqsuura_subst:[""],
  # hamzated letters
  "أ":hamza_match,
  "إ":hamza_match,
  "ؤ":hamza_match,
  "ئ":hamza_match,
  "ء":hamza_match,
  "و":[["w"],["ū"],["ō"], "v"],
  # Adding j here creates problems with e.g. an-nijir vs. النيجر
  "ي":[["y"],["ī"],["ē"]], #"j",
  "ى":"ā", # ʾalif maqṣūra = \u0649
  "آ":["ʾaā","’aā","'aā","`aā"], # ʾalif madda = \u0622
  # put empty string in list so not considered logically false, which can
  # mess with the logic
  "ٱ":[""], # hamzatu l-waṣl = \u0671
  "\u0670":"aā", # ʾalif xanjariyya = dagger ʾalif (Koranic diacritic)
  # short vowels, šadda and sukūn
  "\u064B":"an", # fatḥatān
  "\u064C":"un", # ḍammatān
  "\u064D":"in", # kasratān
  "\u064E":"a", # fatḥa
  "\u064F":[["u"],["o"]], # ḍamma
  "\u0650":[["i"],["e"]], # kasra
  "\u0651":"\u0651", # šadda - handled specially when matching Latin šadda
  double_l_subst:"\u0651", # handled specially when matching šadda in Latin
  "\u0652":"", #sukūn - no vowel
  # ligatures
  "ﻻ":"lā",
  "ﷲ":"llāh",
  # put empty string in list so not considered logically false, which can
  # mess with the logic
  "ـ":[""], # taṭwīl, no sound
  # numerals
  "١":"1", "٢":"2", "٣":"3", "٤":"4", "٥":"5",
  "٦":"6", "٧":"7", "٨":"8", "٩":"9", "٠":"0",
  # punctuation (leave on separate lines)
  "؟":"?", # question mark
  "،":",", # comma
  "؛":";", # semicolon
  ".":".", # period
  "!":"!", # exclamation point
  "'":[("'",)], # single quote, for bold/italic
  " ":" ",
  "[":"",
  "]":"",
  # The following are unnecessary because we handle them specially in
  # check_against_hyphen() and other_arabic_chars.
  #"-":"-",
  #"–":"-",
}

# exclude consonants like h ʿ ʕ ʕ that can occur second in a two-charcter
# sequence, because of cases like "múdhhil" vs. "مذهل"
latin_consonants_no_double_after_cons = "bcdfgjklmnpqrstvwxyzʾʔḍḥḳḷṃṇṛṣṭṿẉỵẓḃċḋḟġḣṁṅṗṙṡṫẇẋẏżčǧȟǰňřšžḇḏẖḵḻṉṟṯẕḡs̄z̄çḑģḩķļņŗşţz̧ćǵḱĺḿńṕŕśẃźďľťƀđǥħłŧƶğḫʃɖʈt̤ð"
latin_consonants_no_double_after_cons_re = "[%s]" % (
    latin_consonants_no_double_after_cons)

# Characters that aren't in tt_to_arabic_matching but which are valid
# Arabic characters in some circumstances (in particular, opposite a hyphen,
# where they are matched in check_against_hyphen()). We need to tell
# get_matches() about this so it doesn't throw an "Encountered non-Arabic"
# error, but instead just returns an empty list of matches so match() will
# properly fail.
other_arabic_chars = [zwj, zwnj, "-", "–"]

word_interrupting_chars = "ـ[]"

build_canonicalize_latin = {}
for ch in "abcdefghijklmnopqrstuvwyz3": # x not in this list! canoned to ḵ
  build_canonicalize_latin[ch] = "multiple"
build_canonicalize_latin[""] = "multiple"

# Make sure we don't canonicalize any canonical letter to any other one;
# e.g. could happen with ʾ, an alternative for ʿ.
for arabic in tt_to_arabic_matching:
  alts = tt_to_arabic_matching[arabic]
  if isinstance(alts, str):
    build_canonicalize_latin[alts] = "multiple"
  else:
    canon = alts[0]
    if isinstance(canon, tuple):
      pass
    if isinstance(canon, list):
      build_canonicalize_latin[canon[0]] = "multiple"
    else:
      build_canonicalize_latin[canon] = "multiple"

for arabic in tt_to_arabic_matching:
  alts = tt_to_arabic_matching[arabic]
  if isinstance(alts, str):
    continue
  canon = alts[0]
  if isinstance(canon, list):
    continue
  for alt in alts[1:]:
    if isinstance(alt, list) or isinstance(alt, tuple):
      continue
    if alt in build_canonicalize_latin and build_canonicalize_latin[alt] != canon:
      build_canonicalize_latin[alt] = "multiple"
    else:
      build_canonicalize_latin[alt] = canon
tt_canonicalize_latin = {}
for alt in build_canonicalize_latin:
  canon = build_canonicalize_latin[alt]
  if canon != "multiple":
    tt_canonicalize_latin[alt] = canon

# A list of Latin characters that are allowed to have particular unmatched
# Arabic characters following. This is used to allow short Latin vowels
# to correspond to long Arabic vowels. The value is the list of possible
# unmatching Arabic characters.
tt_skip_unmatching = {
  "a":["ا"],
  "u":["و"],
  "o":["و"],
  "i":["ي"],
  "e":["ي"],
}

# A list of Latin characters that are allowed to be unmatched in the
# Arabic. The value is the corresponding Arabic character to insert.
tt_to_arabic_unmatching = {
  "a":"\u064E",
  "u":"\u064F",
  "o":"\u064F",
  "i":"\u0650",
  "e":"\u0650",
  # Rather than inserting DAGGER_ALIF directly, insert a special character
  # and convert it later, absorbing a previous fatḥa. We don't simply
  # absorb fatḥa before DAGGER_ALIF in post-canonicalization because
  # Wikitiki89 says the sequence fatḥa + DAGGER_ALIF is Koranic, and will
  # revert attempts to remove the fatḥa.
  "ā":dagger_alif_subst,
  "\u0651":"\u0651",
  "-":"",
}

# Pre-canonicalize Latin, and Arabic if supplied. If Arabic is supplied,
# it should be the corresponding Arabic (after pre-pre-canonicalization),
# and is used to do extra canonicalizations.
def pre_canonicalize_latin(text, arabic=None, msgfun=msg):
  # Map to canonical composed form, eliminate presentation variants etc.
  text = nfkc_form(text)
  # remove L2R, R2L markers
  text = rsub(text, "[\u200E\u200F]", "")
  # remove embedded comments
  text = rsub(text, "<!--.*?-->", "")
  # remove embedded IPAchar templates
  text = rsub(text, r"\{\{IPAchar\|(.*?)\}\}", r"\1")
  # lowercase and remove leading/trailing spaces
  text = text.lower().strip()
  # canonicalize interior whitespace
  text = rsub(text, r"\s+", " ")
  # eliminate ' after space or - and before non-vowel, indicating elided /a/
  text = rsub(text, r"([ -])'([^'aeiouəāēīōū])", r"\1\2")
  # eliminate accents
  text = rsub(text, ".",
    {"á":"a", "é":"e", "í":"i", "ó":"o", "ú":"u",
     "à":"a", "è":"e", "ì":"i", "ò":"o", "ù":"u",
     "ă":"a", "ĕ":"e", "ĭ":"i", "ŏ":"o", "ŭ":"u",
     "ā́":"ā", "ḗ":"ē", "ī́":"ī", "ṓ":"ō", "ū́":"ū",
     "ä":"a", "ë":"e", "ï":"i", "ö":"o", "ü":"u"})
  # some accented macron letters have the accent as a separate Unicode char
  text = rsub(text, ".́",
    {"ā́":"ā", "ḗ":"ē", "ī́":"ī", "ṓ":"ō", "ū́":"ū"})
  # canonicalize weird vowels
  text = text.replace("ɪ", "i")
  text = text.replace("ɑ", "a")
  text = text.replace("æ", "a")
  text = text.replace("а", "a") # Cyrillic a
  # eliminate doubled vowels = long vowels
  text = rsub(text, "([aeiou])\\1", {"a":"ā", "e":"ē", "i":"ī", "o":"ō", "u":"ū"})
  # eliminate vowels followed by colon = long vowels
  text = rsub(text, "([aeiou])[:ː]", {"a":"ā", "e":"ē", "i":"ī", "o":"ō", "u":"ū"})
  # convert circumflexed vowels to long vowels
  text = rsub(text, ".",
    {"â":"ā", "ê":"ē", "î":"ī", "ô":"ō", "û":"ū"})
  # eliminate - or ' separating t-h, t'h, etc. in transliteration style
  # that uses th to indicate ث
  text = rsub(text, "([dtgkcs])[-']h", "\\1h")
  # substitute geminated digraphs, possibly with a hyphen in the middle
  text = rsub(text, "dh(-?)dh", r"ḏ\1ḏ")
  text = rsub(text, "sh(-?)sh", r"š\1š")
  text = rsub(text, "th(-?)th", r"ṯ\1ṯ")
  text = rsub(text, "kh(-?)kh", r"ḵ\1ḵ")
  text = rsub(text, "gh(-?)gh", r"ḡ\1ḡ")
  # misc substitutions
  text = rsub(text, "ẗ$", "")
  # cases like fi 'l-ḡad(i) -> eventually fi l-ḡad
  text = rsub(text, r"\([aiu]\)($|[ |\[\]])", r"\1")
  text = rsub(text, r"\(tun\)$", "")
  text = rsub(text, r"\(un\)$", "")
  #### vowel/diphthong canonicalizations
  text = rsub(text, "([aeiouəāēīōū])u", r"\1w")
  text = rsub(text, "([aeiouəāēīōū])i", r"\1y")
  # Convert -iy- not followed by a vowel or y to long -ī-
  text = rsub(text, "iy($|[^aeiouəyāēīōū])", r"ī\1")
  # Same for -uw- -> -ū-
  text = rsub(text, "uw($|[^aeiouəwāēīōū])", r"ū\1")
  # Insert y between i and a
  text = rsub(text, "([iī])([aā])", r"\1y\2")
  # Insert w between u and a
  text = rsub(text, "([uū])([aā])", r"\1w\2")
  text = rsub(text, "īy", "iyy")
  text = rsub(text, "ūw", "uww")
  # Reduce cases of three characters in a row (e.g. from īyy -> iyyy -> iyy);
  # but not ''', which stands for boldface, or ..., which is legitimate
  text = rsub(text, r"([^'.])\1\1", r"\1\1")
  # Remove double consonant following another consonant, but only at
  # word boundaries, since that's the only time when these cases seem to
  # legitimately occur
  text = re.sub(r"([^aeiouəāēīōū\W])(%s)\2\b" % (
    latin_consonants_no_double_after_cons_re), r"\1\2", text, 0, re.U)
  # Remove double consonant preceding another consonant but special-case
  # a known example that shouldn't be touched.
  if text != "dunḡḡwān":
    text = re.sub(r"([^aeiouəāēīōū\W])\1(%s)" % (
      latin_consonants_no_double_after_cons_re), r"\1\2", text, 0, re.U)
  if arabic:
    # Remove links from Arabic to simplify the following code
    arabic = remove_links(arabic)
    # If Arabic ends with -un, remove it from the Latin (it will be
    # removed from Arabic in pre-canonicalization). But not if the
    # Arabic has a space in it (may be legitimate, in Koranic quotes or
    # whatever).
    if arabic.endswith("\u064C") and " " not in arabic:
      newtext = rsub(text, "un$", "")
      if newtext != text:
        msgfun("Removing final -un from Latin %s" % text)
        text = newtext
      # Now remove -un from the Arabic.
      arabic = rsub(arabic, "\u064C$", "")
    # If Arabic ends with tāʾ marbūṭa, canonicalize some Latin endings
    # right now. Only do this at the end of the text, not at the end
    # of each word, since an Arabic word in the middle might be in the
    # construct state.
    if arabic.endswith("اة"):
      text = rsub(text, r"ā(\(t\)|t)$", "āh")
    elif arabic.endswith("ة"):
      text = rsub(text, r"[ae](\(t\)|t)$", "a")
    # Do certain end-of-word changes on each word, comparing corresponding
    # Latin and Arabic words ...
    arabicwords = re.split(" +", arabic)
    latinwords = re.split(" +", text)
    # ... but only if the number of words in both is the same.
    if len(arabicwords) == len(latinwords):
      for i in range(len(latinwords)):
        aword = arabicwords[i]
        lword = latinwords[i]
        # If Arabic word ends with long alif or alif maqṣūra, not
        # preceded by fatḥatān, convert short -a to long -ā.
        if (re.search("[اى]$", aword) and not
            re.search("\u064B[اى]$", aword)):
          lword = rsub(lword, r"a$", "ā")
        # If Arabic word ends in -yy, convert Latin -i/-ī to -iyy
        # If the Arabic actually ends in -ayy or similar, this should
        # have no effect because in any vowel+i combination, we
        # changed i->y
        if re.search("يّ$", aword):
          lword = rsub(lword, "[iī]$", "iyy")
        # If Arabic word ends in -y preceded by sukūn, assume
        # correct and convert final Latin -i/ī to -y.
        if re.search("\u0652ي$", aword):
          lword = rsub(lword, "[iī]$", "y")
        # Otherwise, if Arabic word ends in -y, convert Latin -i to -ī
        # WARNING: Many of these should legitimately be converted
        # to -iyy or perhaps (sukūn+)-y both in Arabic and Latin, but
        # it's impossible for us to know this.
        elif re.search("ي$", aword):
          lword = rsub(lword, "i$", "ī")
        # Except same logic, but for u/w vs. i/y
        if re.search("وّ$", aword):
          lword = rsub(lword, "[uū]$", "uww")
        if re.search("\u0652و$", aword):
          lword = rsub(lword, "[uū]$", "w")
        elif re.search("و$", aword):
          lword = rsub(lword, "u$", "ū")
        # Echo a final exclamation point in the Latin
        if re.search("!$", aword) and not re.search("!$", lword):
          lword += "!"
        # Same for a final question mark
        if re.search("؟$", aword) and not re.search("\?$", lword):
          lword += "?"
        latinwords[i] = lword
      text = " ".join(latinwords)
  #text = rsub(text, "[-]", "") # eliminate stray hyphens (e.g. in al-)
  # add short vowel before long vowel since corresponding Arabic has it
  text = rsub(text, ".",
    {"ā":"aā", "ē":"eē", "ī":"iī", "ō":"oō", "ū":"uū"})
  return text

def post_canonicalize_latin(text):
  text = rsub(text, "aā", "ā")
  text = rsub(text, "eē", "ē")
  text = rsub(text, "iī", "ī")
  text = rsub(text, "oō", "ō")
  text = rsub(text, "uū", "ū")
  # Convert shadda back to double letter
  text = rsub(text, "(.)\u0651", "\\1\\1")
  # Implement elision of al- after a word-final vowel. See comments above
  # in tr().
  text = rsub(text, "([aiuāīū](?:</span>)?) a([" + sun_letters_tr + "]-)",
    "\\1 \\2")
  text = text.lower().strip()
  return text

# Canonicalize a Latin transliteration and Arabic text to standard form.
# Can be done on only Latin or only Arabic (with the other one None), but
# is more reliable when both aare provided. This is less reliable than
# tr_matching() and is meant when that fails. Return value is a tuple of
# (CANONLATIN, CANONARABIC).
def canonicalize_latin_arabic(latin, arabic, msgfun=msg):
  if arabic is not None:
    arabic = pre_pre_canonicalize_arabic(arabic, msgfun=msgfun)
  if latin is not None:
    latin = pre_canonicalize_latin(latin, arabic, msgfun=msgfun)
  if arabic is not None:
    arabic = pre_canonicalize_arabic(arabic, safe=True, msgfun=msgfun)
    arabic = post_canonicalize_arabic(arabic, safe=True)
  if latin is not None:
    # Protect instances of two or more single quotes in a row so they don't
    # get converted to sequences of hamza half-rings.
    def quote_subst(m):
      return m.group(0).replace("'", multi_single_quote_subst)
    latin = re.sub(r"''+", quote_subst, latin)
    latin = rsub(latin, ".", tt_canonicalize_latin)
    latin_chars = "[a-zA-Zāēīōūčḍḏḡḥḵṣšṭṯẓžʿʾ]"
    # Convert 3 to ʿ if next to a letter or letter symbol. This tries
    # to avoid converting 3 in numbers.
    latin = rsub(latin, "(%s)3" % latin_chars, "\\1ʿ")
    latin = rsub(latin, "3(%s)" % latin_chars, "ʿ\\1")
    latin = latin.replace(multi_single_quote_subst, "'")
    latin = post_canonicalize_latin(latin)
  return (latin, arabic)

# Special-casing for punctuation-space and diacritic-only text; don't
# pre-canonicalize.
def dont_pre_canonicalize_arabic(text):
  if "\u2008" in text:
    return True
  rdtext = remove_diacritics(text)
  if len(rdtext) == 0:
    return True
  if rdtext == "ـ":
    return True
  return False

# Early pre-canonicalization of Arabic, doing stuff that's safe. We split
# this from pre-canonicalization proper so we can do Latin pre-canonicalization
# between the two steps.
def pre_pre_canonicalize_arabic(text, msgfun=msg):
  if dont_pre_canonicalize_arabic(text):
    msgfun("Not pre-canonicalizing %s due to U+2008 or overly short" %
        text)
    return text
  # Map to canonical composed form, eliminate presentation variants.
  # But don't do it if word ligatures are present or length-1 words with
  # presentation variants, because we want to leave those alone.
  if (not re.search("[\uFDF0-\uFDFF]", text)
      and not re.search("(^|[\\W])[\uFB50-\uFDCF\uFE70-\uFEFF]($|[\\W])",
        text, re.U)):
    text = nfkc_form(text)
  # remove L2R, R2L markers
  text = rsub(text, "[\u200E\u200F]", "")
  # remove leading/trailing spaces;
  text = text.strip()
  # canonicalize interior whitespace
  text = rsub(text, r"\s+", " ")
  # replace Farsi, etc. characters with corresponding Arabic characters
  text = text.replace("ی", "ي") # FARSI YEH
  text = text.replace("ک", "ك") # ARABIC LETTER KEHEH (06A9)
  # convert llh for allāh into ll+shadda+dagger-alif+h
  text = rsub(text, "لله", "للّٰه")
  # print("text enter: %s" % text)
  # shadda+short-vowel (including tanwīn vowels, i.e. -an -in -un) gets
  # replaced with short-vowel+shadda during NFC normalisation, which
  # MediaWiki does for all Unicode strings; however, it makes the
  # transliteration process inconvenient, so undo it.
  text = rsub(text,
    "([\u064B\u064C\u064D\u064E\u064F\u0650\u0670])\u0651", "\u0651\\1")
  # tāʾ marbūṭa should always be preceded by fatḥa, alif, alif madda or
  # dagger alif; infer fatḥa if not. This fatḥa will force a match to an "a"
  # in the Latin, so we can safely have tāʾ marbūṭa itself match "h", "t"
  # or "", making it work correctly with alif + tāʾ marbūṭa where
  # e.g. اة = ā and still correctly allow e.g. رة = ra but disallow رة = r.
  text = rsub(text, "([^\u064E\u0627\u0622\u0670])\u0629",
    "\\1\u064E\u0629")
  # some Arabic text has a shadda after the initial consonant; remove it
  newtext = rsub(text, r"(^|[ |\[\]])(.)" + SH, r"\1\2")
  if text != newtext:
    if " " in newtext:
      # Shadda after initial consonant can legitimately occur in
      # Koranic text, standing for assimilation of the final consonant
      # of the preceding word
      msgfun("Not removing shadda after initial consonant in %s because of space in text"
          %  text)
    else:
      msgfun("Removing shadda after initial consonant in %s" % text)
      text = newtext
  # similarly for sukūn + consonant + shadda.
  newtext = rsub(text, SK + "(.)" + SH, SK + r"\1")
  if text != newtext:
    msgfun("Removing shadda after sukūn + consonant in %s" % text)
    text = newtext
  # fatḥa mistakenly placed after consonant + alif should go before.
  newtext = rsub(text, "([" + lconsonants + "])" + A + "?" + ALIF + A,
      r"\1" + AA)
  if text != newtext:
    msgfun("uFixing fatḥa after consonant + alif in %s" % text)
    text = newtext
  return text

# Pre-canonicalize the Arabic. If SAFE, only do "safe" operations appropriate
# to canonicalizing Arabic on its own, not before a tr_matching() operation.
def pre_canonicalize_arabic(text, safe=False, msgfun=msg):
  if dont_pre_canonicalize_arabic(text):
    return text
  # Remove final -un i3rab
  if text.endswith("\u064C"):
    if " " in text:
      # Don't remove final -un from text with spaces because it might
      # be a Koranic quote or similar where we want the -un
      msgfun("Not removing final -un from Arabic %s because it has a space in it" % text)
    else:
      msgfun("Removing final -un from Arabic %s" % text)
      text = rsub(text, "\u064C$", "")
  if not safe:
    # Final alif or alif maqṣūra following fatḥatān is silent (e.g. in
    # accusative singular or words like عَصًا "stick" or هُذًى "guidance";
    # this is called tanwin nasb). So substitute special silent versions
    # of these vowels. Will convert back during post-canonicalization.
    text = rsub(text, "\u064B\u0627", "\u064B" + silent_alif_subst)
    text = rsub(text, "\u064B\u0649", "\u064B" +
        silent_alif_maqsuura_subst)
    # same but with the fatḥatan placed over the alif or alif maqṣūra
    # instead of over the previous letter (considered a misspelling but
    # common)
    text = rsub(text, "\u0627\u064B", silent_alif_subst + "\u064B")
    text = rsub(text, "\u0649\u064B", silent_alif_maqsuura_subst +
        "\u064B")
    # word-initial al + consonant + shadda: remove shadda
    text = rsub(text, "(^|\\s|\[\[|\|)(\u0627\u064E?\u0644[" +
        lconsonants + "])\u0651", "\\1\\2")
    # same for hamzat al-waṣl + l + consonant + shadda, anywhere
    text = rsub(text,
        "(\u0671\u064E?\u0644[" + lconsonants + "])\u0651", "\\1")
    # word-initial al + l + dagger-alif + h (allāh): convert second l
    # to double_l_subst; will match shadda in Latin allāh during
    # tr_matching(), will be converted back during post-canonicalization
    text = rsub(text, "(^|\\s|\[\[|\|)(\u0627\u064E?\u0644)\u0644(\u0670?ه)",
      "\\1\\2" + double_l_subst + "\\3")
    # same for hamzat al-waṣl + l + l + dagger-alif + h occurring anywhere.
    text = rsub(text, "(\u0671\u064E?\u0644)\u0644(\u0670?ه)",
      "\\1" + double_l_subst + "\\2")
    # word-initial al + sun letter: convert l to assimilating_l_subst; will
    # convert back during post-canonicalization; during tr_matching(),
    # assimilating_l_subst will match the appropriate character, or "l"
    text = rsub(text, "(^|\\s|\[\[|\|)(\u0627\u064E?)\u0644([" +
        sun_letters + "])", "\\1\\2" + assimilating_l_subst + "\\3")
    # same for hamzat al-waṣl + l + sun letter occurring anywhere.
    text = rsub(text, "(\u0671\u064E?)\u0644([" + sun_letters + "])",
      "\\1" + assimilating_l_subst + "\\2")
  return text

def post_canonicalize_arabic(text, safe=False):
  if dont_pre_canonicalize_arabic(text):
    return text
  if not safe:
    text = rsub(text, silent_alif_subst, "ا")
    text = rsub(text, silent_alif_maqsuura_subst, "ى")
    text = rsub(text, assimilating_l_subst, "ل")
    text = rsub(text, double_l_subst, "ل")
    text = rsub(text, A + "?" + dagger_alif_subst, DAGGER_ALIF)

    # add sukūn between adjacent consonants, but not in the first part of
    # a link of the sort [[foo|bar]], which we don't vocalize
    splitparts = []
    index = 0
    for part in re.split(r'(\[\[[^]]*\|)', text):
      if (index % 2) == 0:
        # do this twice because a sequence of three consonants won't be
        # matched by the initial one, since the replacement does
        # non-overlapping subs
        part = rsub(part,
            "([" + lconsonants + "])([" + rconsonants + "])",
            "\\1\u0652\\2")
        part = rsub(part,
            "([" + lconsonants + "])([" + rconsonants + "])",
            "\\1\u0652\\2")
      splitparts.append(part)
      index += 1
    text = ''.join(splitparts)

  # remove sukūn after ḍamma + wāw
  text = rsub(text, "\u064F\u0648\u0652", "\u064F\u0648")
  # remove sukūn after kasra + yā'
  text = rsub(text, "\u0650\u064A\u0652", "\u0650\u064A")
  # initial al + consonant + sukūn + sun letter: convert to shadda
  text = rsub(text, "(^|\\s|\[\[|\|)(\u0627\u064E?\u0644)\u0652([" + sun_letters + "])",
     "\\1\\2\\3\u0651")
  # same for hamzat al-waṣl + l + consonant + sukūn + sun letters anywhere
  text = rsub(text, "(\u0671\u064E?\u0644)\u0652([" + sun_letters + "])",
     "\\1\\2\u0651")
  # Undo shadda+short-vowel reversal in pre_pre_canonicalize_arabic.
  # Not strictly necessary as MediaWiki will automatically do this
  # reversal but ensures that e.g. we don't keep trying to revocalize and
  # save a page with a shadda in it. Don't undo shadda+dagger-alif because
  # that sequence may not get reversed to begin with.
  text = rsub(text,
    "\u0651([\u064B\u064C\u064D\u064E\u064F\u0650])", "\\1\u0651")
  return text

debug_tr_matching = False

# Vocalize Arabic based on transliterated Latin, and canonicalize the
# transliteration based on the Arabic.  This works by matching the Latin
# to the unvocalized Arabic and inserting the appropriate diacritics in
# the right places, so that ambiguities of Latin transliteration can be
# correctly handled. Returns a tuple of Arabic, Latin. If unable to match,
# throw an error if ERR, else return None.
def tr_matching(arabic, latin, err=False, msgfun=msg):
  origarabic = arabic
  origlatin = latin
  def debprint(x):
    if debug_tr_matching:
      print(x)
  arabic = pre_pre_canonicalize_arabic(arabic, msgfun=msgfun)
  latin = pre_canonicalize_latin(latin, arabic, msgfun=msgfun)
  arabic = pre_canonicalize_arabic(arabic, msgfun=msgfun)
  # convert double consonant after non-cons to consonant + shadda,
  # but not multiple quotes or multiple periods
  latin = re.sub(r"(^|[aeiouəāēīōū\W])([^'.])\2", "\\1\\2\u0651",
      latin, 0, re.U)

  ar = [] # exploded Arabic characters
  la = [] # exploded Latin characters
  res = [] # result Arabic characters
  lres = [] # result Latin characters
  for cp in arabic:
    ar.append(cp)
  for cp in latin:
    la.append(cp)
  debprint("Arabic characters: %s" % ar)
  debprint("Latin characters: %s" % la)
  aind = [0] # index of next Arabic character
  alen = len(ar)
  lind = [0] # index of next Latin character
  llen = len(la)

  # Find occurrences of al- in Arabic text and note characte pos's after.
  # We treat these as beginning-of-word positions so we correctly handle
  # varieties of alif in this position, treating them the same as at the
  # beginning of a word. We don't need to match assimilating_l_subst
  # here because the only things that we care about after Arabic al-
  # are alif variations, which don't occur with assimilating_l_subst.
  after_al_pos = []
  for m in re.finditer(r"((^|\s|\[\[|\|)" + ALIF + "|" + ALIF_WASLA + ")" +
      A + "?" + L + SK + "?", arabic):
    after_al_pos.append(m.end(0))

  def is_bow(pos=None):
    if pos is None:
      pos = aind[0]
    return (pos == 0 or ar[pos - 1] in [" ", "[", "|"] or
        pos in after_al_pos)

  # True if we are at the last character in a word.
  def is_eow(pos=None):
    if pos is None:
      pos = aind[0]
    return pos == alen - 1 or ar[pos + 1] in [" ", "]", "|"]

  def get_matches():
    ac = ar[aind[0]]
    debprint("get_matches: ac is %s" % ac)
    bow = is_bow()
    eow = is_eow()

    # Special-case handling of the lām that gets assimilated to a sun
    # letter in transliteration. We build up the list of possible
    # matches on the fly according to the following character, which
    # should be a sun letter. We put "l" as a secondary match so that
    # something like al-nūr will get recognized and converted to an-nūr.
    if ac == assimilating_l_subst:
      assert aind[0] < alen - 1
      sunlet = ar[aind[0] + 1]
      assert sunlet in sun_letters
      matches = [ttsun1[sunlet], "l"]
    else:
      matches = (
        bow and tt_to_arabic_matching_bow.get(ac) or
        eow and tt_to_arabic_matching_eow.get(ac) or
        tt_to_arabic_matching.get(ac))
    debprint("get_matches: matches is %s" % matches)
    if matches == None:
      if ac in other_arabic_chars:
        return []
      if True:
        error("Encountered non-Arabic (?) character " + ac +
          " at index " + str(aind[0]))
      else:
        matches = [ac]
    if type(matches) is not list:
      matches = [matches]
    return matches

  # attempt to match the current Arabic character against the current
  # Latin character(s). If no match, return False; else, increment the
  # Arabic and Latin pointers over the matched characters, add the Arabic
  # character to the result characters and return True.
  def match():
    matches = get_matches()

    ac = ar[aind[0]]

    # Check for link of the form [[foo|bar]] and skip over the part
    # up through the vertical bar, copying it
    if ac == '[':
      newpos = aind[0]
      while newpos < alen and ar[newpos] != ']':
        if ar[newpos] == '|':
          newpos += 1
          while aind[0] < newpos:
            res.append(ar[aind[0]])
            aind[0] += 1
          return True
        newpos += 1

    debprint("match: lind=%s, la=%s" % (
      lind[0], lind[0] >= llen and "EOF" or la[lind[0]]))

    for m in matches:
      preserve_latin = False
      # If an element of the match list is a list, it means
      # "don't canonicalize".
      if type(m) is list:
        preserve_latin = True
        m = m[0]
      # A one-element tuple is a signal for use in self-canonicalization,
      # not here.
      elif type(m) is tuple:
        m = m[0]
      l = lind[0]
      matched = True
      debprint("m: %s" % m)
      for cp in m:
        if l < llen and la[l] == cp:
          debprint("cp: %s, l=%s, la=%s" % (cp, l, la[l]))
          l = l + 1
        else:
          debprint("cp: %s, unmatched")
          matched = False
          break
      if matched:
        res.append(ac)
        if preserve_latin:
          for cp in m:
            lres.append(cp)
        elif ac == "ة":
          if not is_eow():
            lres.append("t")
          elif aind[0] > 0 and (ar[aind[0] - 1] == "ا" or
              ar[aind[0] - 1] == "آ"):
            lres.append("h")
          # else do nothing
        else:
          subst = matches[0]
          if type(subst) is list or type(subst) is tuple:
            subst = subst[0]
          for cp in subst:
            lres.append(cp)
        lind[0] = l
        aind[0] = aind[0] + 1
        debprint("matched; lind is %s" % lind[0])
        return True
    return False

  def cant_match():
    if aind[0] < alen and lind[0] < llen:
      error("Unable to match Arabic character %s at index %s, Latin character %s at index %s" %
        (ar[aind[0]], aind[0], la[lind[0]], lind[0]))
    elif aind[0] < alen:
      error("Unable to match trailing Arabic character %s at index %s" %
        (ar[aind[0]], aind[0]))
    else:
      error("Unable to match trailing Latin character %s at index %s" %
        (la[lind[0]], lind[0]))

  # Check for an unmatched Latin short vowel or similar; if so, insert
  # corresponding Arabic diacritic.
  def check_unmatching():
    if not (lind[0] < llen):
      return False
    debprint("Unmatched Latin: %s at %s" % (la[lind[0]], lind[0]))
    unmatched = tt_to_arabic_unmatching.get(la[lind[0]])
    if unmatched != None:
      res.append(unmatched)
      lres.append(la[lind[0]])
      lind[0] = lind[0] + 1
      return True
    return False

  # Check for an Arabic long vowel that is unmatched but following a Latin
  # short vowel.
  def check_skip_unmatching():
    if not (lind[0] > 0 and aind[0] < alen):
      return False
    skip_char_pos = lind[0] - 1
    # Skip back over a hyphen, so we match wa-l-jabal against والجبل
    if la[skip_char_pos] == "-" and skip_char_pos > 0:
      skip_char_pos -= 1
    skip_chars = tt_skip_unmatching.get(la[skip_char_pos])
    if skip_chars != None and ar[aind[0]] in skip_chars:
      debprint("Skip-unmatching matched %s at %s following %s at %s" % (
        ar[aind[0]], aind[0], la[skip_char_pos], skip_char_pos))
      res.append(ar[aind[0]])
      aind[0] = aind[0] + 1
      return True
    return False

  # Check for Latin hyphen and match it against -, zwj, zwnj, Arabic space
  # or nothing. See the caller for some of the reasons we special-case
  # this.
  def check_against_hyphen():
    if lind[0] < llen and la[lind[0]] == "-":
      if aind[0] >= alen:
        lres.append("-")
      elif ar[aind[0]] in ["-", "–", zwj, zwnj]:
        lres.append("-")
        res.append(ar[aind[0]])
        aind[0] += 1
      elif ar[aind[0]] == " ":
        # When matching against space, convert hyphen to space.
        lres.append(" ")
        res.append(" ")
        aind[0] += 1
      else:
        lres.append("-")
      lind[0] += 1
      return True
    return False

  # Check for plain alif matching hamza and canonicalize.
  def check_bow_alif():
    if not (is_bow() and aind[0] < alen and ar[aind[0]] == "ا"):
      return False
    # Check for hamza + vowel.
    if not (lind[0] < llen - 1 and la[lind[0]] in hamza_match_chars and
        la[lind[0] + 1] in "aeiouəāēīōū"):
      return False
    # long vowels should have been pre-canonicalized to have the
    # corresponding short vowel before them.
    assert la[lind[0] + 1] not in "āēīōū"
    if la[lind[0] + 1] in "ei":
      canonalif = "إ"
    else:
      canonalif = "أ"
    msgfun("Canonicalized alif to %s in %s (%s)" % (
      canonalif, origarabic, origlatin))
    res.append(canonalif)
    aind[0] += 1
    lres.append("ʾ")
    lind[0] += 1
    return True

  # Check for inferring tanwīn
  def check_eow_tanwin():
    tanwin_mapping = {"a":AN, "i":IN, "u":UN}
    # Infer tanwīn at EOW
    if (aind[0] > 0 and is_eow(aind[0] - 1) and lind[0] < llen - 1 and
        la[lind[0]] in "aiu" and la[lind[0] + 1] == "n"):
      res.append(tanwin_mapping[la[lind[0]]])
      lres.append(la[lind[0]])
      lres.append(la[lind[0] + 1])
      lind[0] += 2
      return True
    # Infer fatḥatān before EOW alif/alif maqṣūra
    if (aind[0] < alen and is_eow() and
        ar[aind[0]] in "اى" and lind[0] < llen - 1 and
        la[lind[0]] == "a" and la[lind[0] + 1] == "n"):
      res.append(AN)
      res.append(ar[aind[0]])
      lres.append("a")
      lres.append("n")
      aind[0] += 1
      lind[0] += 2
      return True
    return False

  # Here we go through the unvocalized Arabic letter for letter, matching
  # up the consonants we encounter with the corresponding Latin consonants
  # using the dict in tt_to_arabic_matching and copying the Arabic
  # consonants into a destination array. When we don't match, we check for
  # allowed unmatching Latin characters in tt_to_arabic_unmatching, which
  # handles short vowels and shadda. If this doesn't match either, and we
  # have left-over Arabic or Latin characters, we reject the whole match,
  # either returning False or signaling an error.

  while aind[0] < alen or lind[0] < llen:
    matched = False
    # The first clause ensures that shadda always gets processed first;
    # necessary in the case of the qiṭṭun example below, which otherwise
    # would be rendered as qiṭunn.
    if lind[0] < llen and la[lind[0]] == "\u0651":
      debprint("Matched: Clause shadda")
      lind[0] += 1
      lres.append("\u0651")
      if aind[0] < alen and (
          ar[aind[0]] == "\u0651" or ar[aind[0]] == double_l_subst):
        res.append(ar[aind[0]])
        aind[0] += 1
      else:
        res.append("\u0651")
      matched = True
    # We need a special clause for hyphen for various reasons. One of them
    # is that otherwise we have problems with al-ʾimārāt against الإمارات,
    # where the إ is in BOW position against hyphen and is allowed to
    # match against nothing and does so, and then the hyphen matches
    # against nothing and the ʾ can't match. Another is so that we can
    # canonicalize it to space if matching against a space but keep it
    # a hyphen otherwise.
    elif check_against_hyphen():
      debprint("Matched: Clause check_against_hyphen()")
      matched = True
    # The effect of the next clause is to handle cases where the
    # Arabic has a right bracket or similar character and the Latin has
    # a short vowel or shadda that doesn't match and needs to go before
    # the right bracket. The is_bow() check is necessary because
    # left-bracket is part of word_interrupting_chars and when the
    # left bracket is word-initial opposite a short vowel, the bracket
    # needs to be handled first. Similarly for word-initial tatwil, etc.
    #
    # Note that we can't easily generalize the word_interrupting_chars
    # check. We used to do so, calling get_matches() and looking where
    # the match has only an empty string, but this messed up on words
    # like زنىً (zinan) where the silent_alif_maqsuura_subst has only
    # an empty string matching but we do want to consume it first
    # before checking for short vowels. Even earlier we had an even
    # more general check, calling get_matches() and checking that any
    # of the matches are an empty string. This had the side-effect of
    # fixing the qiṭṭun problem but made it impossible to vocalize the
    # ghurfatun al-kuuba example, among others.
    elif (not is_bow() and aind[0] < alen and
        ar[aind[0]] in word_interrupting_chars and
        check_unmatching()):
      debprint("Matched: Clause 1")
      matched = True
    elif check_bow_alif():
      debprint("Matched: Clause check_bow_alif()")
      matched = True
    elif aind[0] < alen and match():
      debprint("Matched: Clause match()")
      matched = True
    elif check_eow_tanwin():
      debprint("Matched: Clause check_eow_tanwin()")
      matched = True
    elif check_unmatching():
      debprint("Matched: Clause check_unmatching()")
      matched = True
    elif check_skip_unmatching():
      debprint("Matched: Clause check_skip_unmatching()")
      matched = True
    if not matched:
      if err:
        cant_match()
      else:
        return False

  arabic = "".join(res)
  latin = "".join(lres)
  arabic = post_canonicalize_arabic(arabic)
  latin = post_canonicalize_latin(latin)
  return arabic, latin

def remove_diacritics(word):
  return arabiclib.remove_diacritics(word)

def foreign_diff_msgs(rdforeign, rdcanonforeign):
  msgs = []
  if "ی" in rdarabic:
    msgs.append("Farsi Yeh")
  if "ک" in rdarabic:
    msgs.append("Keheh")
  if re.search("[\uFB50-\uFDCF]", rdarabic):
    msgs.append("Arabic Pres-A")
  if re.search("[\uFDF0-\uFDFF]", rdarabic):
    msgs.append("Arabic word ligatures")
  if re.search("[\uFE70-\uFEFF]", rdarabic):
    msgs.append("Arabic Pres-B")
  return msgs

######### Transliterate directly, without unvocalized Arabic to guide #########
#########             (NEEDS WORK)            #########

tt_to_arabic_direct = {
  # consonants
  "b":"ب", "t":"ت", "ṯ":"ث", "θ":"ث", # "th":"ث",
  "j":"ج",
  "ḥ":"ح", "ħ":"ح", "ḵ":"خ", "x":"خ", # "kh":"خ",
  "d":"د", "ḏ":"ذ", "ð":"ذ", "đ":"ذ", # "dh":"ذ",
  "r":"ر", "z":"ز", "s":"س", "š":"ش", # "sh":"ش",
  "ṣ":"ص", "ḍ":"ض", "ṭ":"ط", "ẓ":"ظ",
  "ʿ":"ع", "ʕ":"ع",
  "`":"ع",
  "3":"ع",
  "ḡ":"غ", "ġ":"غ", "ğ":"غ",  # "gh":"غ",
  "f":"ف", "q":"ق", "k":"ك", "l":"ل", "m":"م", "n":"ن",
  "h":"ه",
  # "a":"ة", "ah":"ة"
  # tāʾ marbūṭa (special) - always after a fátḥa (a), silent at the end of
  # an utterance, "t" in ʾiḍāfa or with pronounced tanwīn
  # \u0629 = tāʾ marbūṭa = ة
  # control characters
  # zwj:"", # ZWJ (zero-width joiner)
  # rare letters
  "p":"پ", "č":"چ", "v":"ڤ", "g":"گ",
  # semivowels or long vowels, alif, hamza, special letters
  "ā":"\u064Eا", # ʾalif = \u0627
  # "aa":"\u064Eا", "a:":"\u064Eا"
  # hamzated letters
  "ʾ":"ء",
  "’":"ء",
  "'":"ء",
  "w":"و",
  "y":"ي",
  "ū":"\u064Fو", # "uu":"\u064Fو", "u:":"\u064Fو"
  "ī":"\u0650ي", # "ii":"\u0650ي", "i:":"\u0650ي"
  # "ā":"ى", # ʾalif maqṣūra = \u0649
  # "an":"\u064B" = fatḥatān
  # "un":"\u064C" = ḍammatān
  # "in":"\u064D" = kasratān
  "a":"\u064E", # fatḥa
  "u":"\u064F", # ḍamma
  "i":"\u0650", # kasra
  # \u0651 = šadda - doubled consonant
  # "\u0652":"", #sukūn - no vowel
  # ligatures
  # "ﻻ":"lā",
  # "ﷲ":"llāh",
  # taṭwīl
  # numerals
  "1":"١", "2":"٢",# "3":"٣",
  "4":"٤", "5":"٥",
  "6":"٦", "7":"٧", "8":"٨", "9":"٩", "0":"٠",
  # punctuation (leave on separate lines)
  "?":"؟", # question mark
  ",":"،", # comma
  ";":"؛" # semicolon
}

# Transliterate any words or phrases from Latin into Arabic script.
# POS, if not None, is e.g. "noun" or "verb", controlling how to handle
# final -a.
#
# FIXME: NEEDS WORK. Works but ignores POS. Doesn't yet generate the correct
# seat for hamza (need to reuse code in Module:ar-verb to do this). Always
# transliterates final -a as fatḥa, never as tāʾ marbūṭa (should make use of
# POS for this). Doesn't (and can't) know about cases where sh, th, etc.
# stand for single letters rather than combinations.
def tr_latin_direct(text, pos, msgfun=msg):
  text = pre_canonicalize_latin(text, msgfun=msg)
  text = rsub(text, "ah$", "\u064Eة")
  text = rsub(text, "āh$", "\u064Eاة")
  text = rsub(text, ".", tt_to_arabic_direct)
  # convert double consonant to consonant + shadda
  text = rsub(text, "([" + lconsonants + "])\\1", "\\1\u0651")
  text = post_canonicalize_arabic(text)

  return text

################################ Test code ##########################

num_failed = 0
num_succeeded = 0

def test(latin, arabic, should_outcome):
  global num_succeeded, num_failed
  try:
    result = tr_matching(arabic, latin, True)
  except RuntimeError as e:
    print("%s" % e)
    result = False
  if result == False:
    print("tr_matching(%s, %s) = %s" % (arabic, latin, result))
    outcome = "failed"
  else:
    canonarabic, canonlatin = result
    trlatin = tr(canonarabic)
    print("tr_matching(%s, %s) = %s %s, " % (arabic, latin, canonarabic, canonlatin), end="")
    if trlatin == canonlatin:
      print("tr() MATCHED")
      outcome = "matched"
    else:
      print("tr() UNMATCHED (= %s)" % trlatin)
      outcome = "unmatched"
  canonlatin, _ = canonicalize_latin_arabic(latin, None)
  print("canonicalize_latin(%s) = %s" %
      (latin, canonlatin))
  if outcome == should_outcome:
    print("TEST SUCCEEDED.")
    num_succeeded += 1
  else:
    print("TEST FAILED.")
    num_failed += 1

def run_tests():
  global num_succeeded, num_failed
  num_succeeded = 0
  num_failed = 0
  test("katab", "كتب", "matched")
  test("kattab", "كتب", "matched")
  test("kátab", "كتب", "matched")
  test("katab", "كتبٌ", "matched")
  test("kat", "كتب", "failed") # should fail
  test("katabaq", "كتب", "failed") # should fail
  test("dakhala", "دخل", "matched")
  test("al-dakhala", "الدخل", "matched")
  test("ad-dakhala", "الدخل", "matched")
  test("al-la:zim", "اللازم", "matched")
  test("al-bait", "البيت", "matched")
  test("wa-dakhala", "ودخل", "unmatched")
  # The Arabic of the following consists of wāw + fatḥa + ZWJ + dāl + ḵāʾ + lām.
  test("wa-dakhala", "وَ‍دخل", "matched")
  # The Arabic of the following two consists of wāw + ZWJ + dāl + ḵāʾ + lām.
  test("wa-dakhala", "و‍دخل", "matched")
  test("wa-dakhala", "و-دخل", "matched")
  test("wadakhala", "و‍دخل", "failed") # should fail, ZWJ must match hyphen
  test("wadakhala", "ودخل", "matched")
  # Six different ways of spelling a long ū.
  test("duuba", "دوبة", "matched")
  test("dúuba", "دوبة", "matched")
  test("duwba", "دوبة", "matched")
  test("du:ba", "دوبة", "matched")
  test("dūba", "دوبة", "matched")
  test("dū́ba", "دوبة", "matched")
  # w definitely as a consonant, should be preserved
  test("duwaba", "دوبة", "matched")

  # Similar but for ī and y
  test("diiba", "ديبة", "matched")
  test("díiba", "ديبة", "matched")
  test("diyba", "ديبة", "matched")
  test("di:ba", "ديبة", "matched")
  test("dība", "ديبة", "matched")
  test("dī́ba", "ديبة", "matched")
  test("diyaba", "ديبة", "matched")

  # Test o's and e's
  test("dōba", "دوبة", "unmatched")
  test("dōba", "دُوبة", "unmatched")
  test("telefōn", "تلفون", "unmatched")

  # Test handling of tāʾ marbūṭa
  # test of "duuba" already done above.
  test("duubah", "دوبة", "matched") # should be reduced to -a
  test("duubaa", "دوباة", "matched") # should become -āh
  test("duubaah", "دوباة", "matched") # should become -āh
  test("mir'aah", "مرآة", "matched") # should become -āh

  # Test the definite article and its rendering in Arabic
  test("al-duuba", "اَلدّوبة", "matched")
  test("al-duuba", "الدّوبة", "matched")
  test("al-duuba", "الدوبة", "matched")
  test("ad-duuba", "اَلدّوبة", "matched")
  test("ad-duuba", "الدّوبة", "matched")
  test("ad-duuba", "الدوبة", "matched")
  test("al-kuuba", "اَلْكوبة", "matched")
  test("al-kuuba", "الكوبة", "matched")
  test("baitu l-kuuba", "بيت الكوبة", "matched")
  test("baitu al-kuuba", "بيت الكوبة", "matched")
  test("baitu d-duuba", "بيت الدوبة", "matched")
  test("baitu ad-duuba", "بيت الدوبة", "matched")
  test("baitu l-duuba", "بيت الدوبة", "matched")
  test("baitu al-duuba", "بيت الدوبة", "matched")
  test("bait al-duuba", "بيت الدوبة", "matched")
  test("bait al-Duuba", "بيت الدوبة", "matched")
  test("bait al-kuuba", "بيت الكوبة", "matched")
  test("baitu l-kuuba", "بيت ٱلكوبة", "matched")

  test("ʼáwʻada", "أوعد", "matched")
  test("'áwʻada", "أوعد", "matched")
  # The following should be self-canonicalized differently.
  test("`áwʻada", "أوعد", "matched")

  # Test handling of tāʾ marbūṭa when non-final
  test("ghurfatu l-kuuba", "غرفة الكوبة", "matched")
  test("ghurfatun al-kuuba", "غرفةٌ الكوبة", "matched")
  test("al-ghurfatu l-kuuba", "الغرفة الكوبة", "matched")
  test("ghurfat al-kuuba", "غرفة الكوبة", "unmatched")
  test("ghurfa l-kuuba", "غرفة الكوبة", "unmatched")
  test("ghurfa(t) al-kuuba", "غرفة الكوبة", "matched")
  test("ghurfatu l-kuuba", "غرفة ٱلكوبة", "matched")
  test("ghurfa l-kuuba", "غرفة ٱلكوبة", "unmatched")
  test("ghurfa", "غرفةٌ", "matched")

  # Test handling of tāʾ marbūṭa when final
  test("ghurfat", "غرفةٌ", "matched")
  test("ghurfa(t)", "غرفةٌ", "matched")
  test("ghurfa(tun)", "غرفةٌ", "matched")
  test("ghurfat(un)", "غرفةٌ", "matched")

  # Test handling of embedded links
  test("’ālati l-fam", "[[آلة]] [[فم|الفم]]", "matched")
  test("arqām hindiyya", "[[أرقام]] [[هندية]]", "matched")
  test("arqām hindiyya", "[[رقم|أرقام]] [[هندية]]", "matched")
  test("arqām hindiyya", "[[رقم|أرقام]] [[هندي|هندية]]", "matched")
  test("ʾufuq al-ħadaŧ", "[[أفق]] [[حادثة|الحدث]]", "matched")

  # Test transliteration that omits initial hamza (should be inferrable)
  test("aṣdiqaa'", "أَصدقاء", "matched")
  test("aṣdiqā́'", "أَصدقاء", "matched")
  # Test random hamzas
  test("'aṣdiqā́'", "أَصدقاء", "matched")
  # Test capital letters for emphatics
  test("aSdiqaa'", "أَصدقاء", "matched")
  # Test final otiose alif maqṣūra after fatḥatān
  test("hudan", "هُدًى", "matched")
  # Test opposite with fatḥatān after alif otiose alif maqṣūra
  test("zinan", "زنىً", "matched")

  # Check that final short vowel is canonicalized to a long vowel in the
  # presence of a corresponding Latin long vowel.
  test("'animi", "أنمي", "matched")
  # Also check for 'l indicating assimilation.
  test("fi 'l-marra", "في المرة", "matched")

  # Test cases where short Latin vowel corresponds to Long Arabic vowel
  test("diba", "ديبة", "unmatched")
  test("tamariid", "تماريد", "unmatched")
  test("tamuriid", "تماريد", "failed")

  # Single quotes in Arabic
  test("man '''huwa'''", "من '''هو'''", "matched")

  # Alif madda
  test("'aabaa'", "آباء", "matched")
  test("mir'aah", "مرآة", "matched")

  # Test case where close bracket occurs at end of word and an unmatched
  # vowel or shadda needs to be before it.
  test("fuuliyy", "[[فولي]]", "matched")
  test("fuula", "[[فول]]", "matched")
  test("wa-'uxt", "[[و]][[أخت]]", "unmatched")
  # Here we test when an open bracket occurs in the middle of a word and
  # an unmatched vowel or shadda needs to be before it.
  test("wa-'uxt", "و[[أخت]]", "unmatched")

  # Test hamza against non-hamza
  test("'uxt", "اخت", "matched")
  test("uxt", "أخت", "matched")
  test("'ixt", "اخت", "matched")
  test("ixt", "أخت", "matched") # FIXME: Should be "failed" or should correct hamza

  # Test alif after al-
  test("al-intifaaḍa", "[[الانتفاضة]]", "matched")
  test("al-'uxt", "الاخت", "matched")

  # Test adding ! or ؟
  test("fan", "فن!", "matched")
  test("fan!", "فن!", "matched")
  test("fan", "فن؟", "matched")
  test("fan?", "فن؟", "matched")

  # Test inferring fatḥatān
  test("hudan", "هُدى", "matched")
  test("qafan", "قفا", "matched")
  test("qafan qafan", "قفا قفا", "matched")

  # Case where shadda and -un are opposite each other; need to handle
  # shadda first.
  test("qiṭṭ", "قِطٌ", "matched")

  # 3 consonants in a row
  test("Kūlūmbīyā", "كولومبيا", "matched")
  test("fustra", "فسترة", "matched")

  # Allāh
  test("allāh", "الله", "matched")

  # Test dagger alif, alif maqṣūra
  test("raḥmān", "رَحْمٰن", "matched")
  test("fusḥā", "فسحى", "matched")
  test("fusḥā", "فُسْحَى", "matched")
  test("'āxir", "آخر", "matched")

  # Real-world tests
  test("’ijrā’iy", "إجْرائِيّ", "matched")
  test("wuḍūʕ", "وضوء", "matched")
  test("al-luḡa al-ʾingilīziyya", "اَلْلُّغَة الْإنْجِلِيزِيّة", "unmatched")
  test("šamsíyya", "شّمسيّة", "matched")
  test("Sirbiyā wa-l-Jabal al-Aswad", "صربيا والجبل الأسود", "unmatched")
  test("al-’imaraat", "الإمارات", "unmatched")
  # FIXME: Should we canonicalize to al-?
  test("al'aan(a)", "الآن", "unmatched")
  test("yūnānīyya", "يونانية", "matched")
  test("hindiy-'uruubiy", "هندي-أوروبي", "unmatched")
  test("moldōva", "مولدوفا", "unmatched")
  test("darà", "درى", "matched")
  test("waraa2", "وراء", "matched")
  test("takhaddaa", "تحدى", "matched")
  test("qaránful", "ﻗﺮﻧﻔﻞ", "matched")
  # Can't easily handle this one because ال matches against -r- in the
  # middle of a word.
  # test("al-sāʿa wa-'r-rubʿ", "الساعة والربع", "matched")
  test("taḥṭīṭ", "تخطيط", "matched")
  test("hāḏihi", "هذه", "matched")
  test("ħaláːt", "حَالاَتٌ", "unmatched")
  test("raqṣ šarkiyy", "رقص شرقي", "matched")
  test("ibn ʾaḵ", "[[اِبْنُ]] [[أَخٍ]]", "matched")
  test("al-wuṣṭā", "الوسطى", "matched")
  test("fáħmu-l-xášab", "فحم الخشب", "matched")
  test("gaṡor", "قَصُر", "unmatched")
  # Getting this to work makes it hard to get e.g. nijir vs. نيجر to work.
  # test("sijāq", "سِيَاق", "matched")
  test("winipiigh", "وينيبيغ", "unmatched")
  test("ʿaḏrāʿ", "عذراء", "matched")
  test("ʂaʈħ", "سطْح", "matched")
  test("dʒa'", "جاء", "unmatched")
  #will split when done through canon_arabic.py, but not here
  #test("ʿíndak/ʿíndak", "عندك", "matched") # should split
  test("fi 'l-ḡad(i)", "في الغد", "matched")
  test("ḩaythu", "حَيثُ", "matched")
  test("’iʐhār", "إظهار", "matched")
  test("taħli:l riya:dˤiy", "تَحْلِيلْ رِيَاضِي", "matched")
  test("al-'ingilizíyya al-'amrikíyya", "الإنجليزية الأمريكية", "unmatched")
  test("ḵаwḵa", "خوخة", "matched") # this has a Cyrillic character in it
  test("’eħsās", "احساس", "unmatched")
  # Up through page 848 "sense"
  test("wayd-jaylz", "ويد–جيلز", "matched")
  test("finjáːn šæːy", "فِنْجَان شَاي", "matched")
  test("múdhhil", "مذهل", "matched")
  test("ixtiār", "اختيار", "matched")
  test("miṯll", "مثل", "matched")
  test("li-wajhi llāh", "لِوَجْهِ اللهِ", "unmatched")

  # FIXME's: assimilating_l_subst only matches against canonical sun
  # letters, not against non-canonical ones like θ. We can fix that
  # by adding all the non-canonical ones to ttsun1[], or maybe just
  # matching anything that's not a vowel.
  #test("tišrīnu θ-θāni", "تِشرينُ الثّانِي", "matched")

  # Final results
  print("RESULTS: %s SUCCEEDED, %s FAILED." % (num_succeeded, num_failed))

if __name__ == "__main__":
  run_tests()
