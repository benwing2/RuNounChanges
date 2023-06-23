#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# Authors: Benwing; Atitarev for tr() and tr_adj() functions, in Lua

import re
import unicodedata

from blib import remove_links, msg

# FIXME:
# 1. Converts grave-и to и with both acute and grave.
# 2. Doesn't convert grave to acute when no transliteration.

AC = "\u0301"
GR = "\u0300"
ACGR = "[" + AC + GR + "]"
ACGROPT = "[" + AC + GR + "]?"

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

tt = {
    "А":"A", "а":"a", "Б":"B", "б":"b", "В":"V", "в":"v", "Г":"G", "г":"g", "Д":"D", "д":"d", 
    "Е":"E", "е":"e", "Ж":"Ž", "ж":"ž", "З":"Z", "з":"z", "И":"I", "и":"i", "Й":"J", "й":"j", 
    "К":"K", "к":"k", "Л":"L", "л":"l", "М":"M", "м":"m", "Н":"N", "н":"n", "О":"O", "о":"o", 
    "П":"P", "п":"p", "Р":"R", "р":"r", "С":"S", "с":"s", "Т":"T", "т":"t", "У":"U", "у":"", 
    "Ф":"F", "ф":"f", "Х":"H", "х":"h", "Ц":"C", "ц":"c", "Ч":"Č", "ч":"č", "Ш":"Š", "ш":"š", 
    "Щ":"Št", "щ":"št", "Ъ":"Ǎ", "ъ":"ǎ", "Ю":"Ju", "ю":"ju", "Я":"Ja", "я":"ja",
    "ѝ":"ì",

    # Pre-reform
    "Ѫ":"Ǫ", "ѫ":"ǫ", "Ѣ":"Ě", "ѣ":"ě", "Ь":"ʹ", "ь":"ʹ",
}

bulgarian_vowels = "АОУЯЮИЕЪЬѢѪаоуяюиеъьѣѫAEIOUĚǪaeiouěǫʹ"

# Transliterates text, which should be a single word or phrase. It should
# include stress marks, which are then preserved in the transliteration.
def tr(text, lang=None, sc=None, msgfun=msg):
    text = remove_links(text)
    text = tr_canonicalize_bulgarian(text)

    # Remove word-final hard sign
    text = rsub(text, "[Ъъ]($|[- \]])", r"\1")

    # ьо becomes jo, Ьо becomes Jo
    text = rsub(text, "ь(?=[Оо])", r"j")
    text = rsub(text, "Ь(?=[Оо])", r"J")
    text = rsub(text, '.', tt)

    # compose accented characters
    text = tr_canonicalize_latin(text)

    return text

############################################################################
#                    Transliterate from Latin to Bulgarian                 #
############################################################################

debug_tables = False
debug_tr_matching = False

#########       Transliterate with Bulgarian to guide       #########

# list of items to pre-canonicalize to ʺ, which needs to be first in the list
double_quote_like = ["ʺ","”","″"]
# list of items to pre-canonicalize to ʹ, which needs to be first in the list
single_quote_like = ["ʹ","’","ʼ","´","′","ʲ","ь","ˈ","`","‘"]
# regexps to use for early canonicalization in pre_canonicalize_latin()
double_quote_like_re = "[" + "".join(double_quote_like) + "]"
single_quote_like_re = "[" + "".join(single_quote_like) + "]"
# list of items to match-canonicalize against a Bulgarian hard sign;
# the character Ǎ needs to be first in the list
hard_sign_matching = ["Ǎ", "Ă", "Ŭ", "A"]
# list of items to match-canonicalize against a Bulgarian soft sign;
# the character ʹ which needs to be first in the list
# Don't put 'j here because we might legitimately have ья or similar
soft_sign_matching = single_quote_like + ["'ʹ","'","y","j"]

bulgarian_to_latin_lookalikes_lc = {
        "а":"a", "е":"e", "о":"o", "х":"x", "ӓ":"ä", "ё":"ë", "с":"c",
        "і":"i",
        "а́":"á", "е́":"é", "о́":"ó", "і́":"í",
        "р":"p", "у":"y",
    }
bulgarian_to_latin_lookalikes_cap = {
        "А":"A", "Е":"E", "О":"O", "Х":"X", "Ӓ":"ä", "Ё":"Ë", "С":"C",
        "І":"I", "К":"K",
        "А́":"Á", "Е́":"É", "О́":"Ó", "І́":"Í",
    }
bulgarian_to_latin_lookalikes = dict(list(bulgarian_to_latin_lookalikes_lc.items()) +
        list(bulgarian_to_latin_lookalikes_cap.items()))
# When converting Latin to Bulgarian, only do lowercase so we don't do phrases
# like X, C++, витамин C, сульфат железа(II), etc.
latin_to_bulgarian_lookalikes = dict(
        [(y, x) for x, y in bulgarian_to_latin_lookalikes_lc.items()])
# Filter out multi-char sequences, which will work only on the right side of
# the correspondence (the accented Bulgarian chars; the other way will be
# handled by the non-accented equivalents, i.e. accented Bulgarian with accent
# as separate character will be converted to accented Latin with Latin as
# separate character, which is exactly what we want.
bulgarian_lookalikes_re = "[" + "".join(
        [x for x in bulgarian_to_latin_lookalikes.keys() if len(x) == 1]) + "]"
latin_lookalikes_re = "[" + "".join(
        [x for x in bulgarian_to_latin_lookalikes.values() if len(x) == 1]) + "]"

multi_single_quote_subst = "\ufff1"
capital_silent_hard_sign = "\ufff6"
small_silent_hard_sign = "\ufff7"

# List of characters we don't self-canonicalize at all, on top of
# whatever may be derived from the matching tables. Note that we also
# don't self-canonicalize the canonical entries in the matching tables.
dont_self_canonicalize = (
  "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
)
# Lists of characters that can be unmatched on either Latin or Bulgarian side.
# unmatch_either_before indicates characters handled before match(),
# unmatch_either_after indicates characters handled after match(). The
# difference concerns what happens when an unmatched character on the
# Bulgarian side that can be unmatched (e.g. a right bracket, single quote
# or soft sign) is against an unmatched character in the Latin side that's
# in one of the following two lists. The acute/grave accents need to go
# before the unmatched Bulgarian character, whereas the punctuation needs to
# go after.
unmatch_either_before = [AC, GR]
unmatch_either_after = ["!", "?", "."]

# This dict maps Bulgarian characters to all the Latin characters that
# might correspond to them. The entries can be a string (equivalent
# to a one-entry list) or a list of items. Each item can be a string
# (canonicalize to the first character in the entry during
# transliteration), a one-element list (don't canonicalize during
# transliteration), or a two-element list (canonicalize from the
# first element to the second element during transliteration), or a
# three-element list (like a two-element list, but the third is the
# Bulgarian to canonicalize to on the Bulgarian side, instead of the
# actually-matched Bulgarian). The ordering of items in the list is important
# insofar as which item is first, because the default behavior when
# canonicalizing a transliteration is to substitute any string in the
# list with the first item of the list (this can be suppressed by making an
# item a one-element list, or changed by making an item a two-element
# list, as mentioned above).
#
# If the item of a list, or the first element of such an item, is a
# one-element tuple containing a string, it makes no difference during
# match-canonicalization, but serves as a special signal during
# self-canonicalization. If the tuple-surrounded item is not the first
# item in the entry, it suppresses self-canonicalizing this character
# to the first item in the entry. Note that if a character occurs in
# multiple entries, normally no self-canonicalizing will occur of this
# character, but if some of them have self-canonicalizing suppressed but
# others don't it is possible to control what a character is
# self-canonicalized to. For example, single-quote ("'") occurs in various
# entries, but most occurrences are surrounded by one-element tuples;
# only the occurrences where the canonical character is "ʹ" aren't so
# surrounded. The effect is that single-quote will be self-canonicalized
# to "ʹ", even though it will be match-canonicalized to multiple
# possibilities depending on the corresponding Bulgarian character.
# (If the first item in an entry is a tuple, it overrides the behavior
# that normally suppresses all self-canonicalization of the character.
# For example, single-quote ("'") is surrounded in a tuple in the
# entry with the same single-quote on the Bulgarian side. That allows
# single-quote to remain as a single-quote when match-canonicalizing a
# single-quote on the Bulgarian side, but ensures that it will be
# stll self-canonicalized to "ʹ", as previously described.)
#
# Each string might have multiple characters, to handle things
# like ж=zh.

tt_to_bulgarian_matching_uppercase = {
    "А":"A",
    "Б":"B",
    "В":["V","B","W"],
    # most of these entries are here for the lowercase equivalent
    # second X is Greek
    'Г':['G',['V'],['X'],[("Χ",),"X"],['Kh'],['H']],
    "Д":"D",
    "Е":"E",
    "Ж":["Ž","Zh","ʐ","Z"], # no cap equiv: "ʐ"?
    "З":"Z",
    "И":["I","Yi","Y","'I","ʹI","Ji","И"],
    "Й":["J","Y","Ĭ","I","Ÿ"],
    # Second K is Cyrillic
    "К":["K","Ck","C","К"],
    "Л":"L",
    "М":"M",
    "Н":["N","H"],
    "О":"O",
    "П":"P",
    "Р":"R",
    "С":["S","C"],
    "Т":"T",
    "У":["U","Y","Ou","W"],
    "Ф":["F","Ph"],
    # final X is Greek
    "Х":["H", "X","Kh","Ch","Č","Χ"], # Ch might have been canoned to Č
    "Ц":["C","T͡s","Ts","Tz","Č"],
    'Ч':['Č',"Ch","Tsch","Tsč","Tch","Tč","T͡ɕ","Ć",["Š"],["Sh"]],
    "Ш":["Š","Sh"],
    # don't self-canon Ŝ to Щ because it might be occurring in a sequence Ŝč
    # or similar
    "Щ":["Št","Sht","St","St","Š(t)","Ŝt",("Ŝ",),"Š'","ʂ","Sh'",
        "Š","Sh"],# No cap equiv: "ʂ"?
    "Ъ":hard_sign_matching + [""],
    "Ю":["Ju","Yu","'U","ʹU","U","'Ju","ʹJu"],
    "Я":["Ja","Ya","'A","ʹA","A","'Ja","ʹJa"],
    # archaic, pre-1918 letters
    'Ѫ':'Ǫ',
    'Ѣ':['Ě',"E"],
    "Ь":soft_sign_matching + [""],
}

# Match Latin characters in the Bulgarian against same characters
for ch in "ABCDEFGHIJKLMNOPQRSTUVWXYZ":
    tt_to_bulgarian_matching_uppercase[ch] = ch

tt_to_bulgarian_matching_non_case = {
    # Bulgarian style quotes
    '«':['“','"'],
    '»':['”',('ʺ',),'"'],
    # punctuation (leave on separate lines)
    # these are now handled by check_unmatch_either(unmatch_either_before)
    #"?":["?",""], # question mark
    #".":[".",""], # period
    #"!":["!",""], # exclamation point
    "-":"-", # hyphen/dash
    "—":["—","-"], # long dash
    '"':[('"',)], # quotation mark
    # allow parens on the Bulgarian side to get copied over the the Latin
    # side if unmatching
    "(":["(",""],
    ")":[")",""],
    # allow single quote to match nothing so we can handle bolded text in
    # the Cyrillic without corresponding bold in the translit and add the
    # bold to the translit (occurs a lot in usexes)
    "'":[("'",),("ʹ",),""], # single quote, for bold/italic
    "’":[("’",),("ʹ",),("'",)], # Кот-д’Ивуар
    " ":" ",
    "[":"",
    "]":"",
    ",":[",", " ,", ""],
    "\u00A0":["\u00A0", " "],
    # these are now handled by check_unmatch_either(unmatch_either_after)
    #AC:[AC,""],
    #GR:[GR,""],
    # now handled by consume_against_eow_hard_sign()
    #capital_silent_hard_sign:[""],
    #small_silent_hard_sign:[""],
}

# Match numbers and some punctuation against itself
for ch in "1234567890;:/":
    tt_to_bulgarian_matching_non_case[ch] = ch

# Convert string, list of stuff of tuple of stuff into lowercase
def lower_entry(x):
    if isinstance(x, list):
        return [lower_entry(y) for y in x]
    if isinstance(x, tuple):
        return tuple(lower_entry(y) for y in x)
    return x.lower()
# Surround entries with a one-entry tuple so they don't trigger
# "multiple" in build_canonicalize_latin()
def make_tuple(x):
    if isinstance(x, list):
        if len(x) == 2:
            frm, to = x
            return [make_tuple(frm), to]
        assert len(x) == 1
        return [make_tuple(x[0])]
    if isinstance(x, tuple):
        return x
    return (x,)

tt_to_bulgarian_matching = {}
for k,v in tt_to_bulgarian_matching_uppercase.items():
    if isinstance(v, basestring):
        v = [v]
    # Surround lower->upper matching with a one-entry tuple so they
    # don't trigger "multiple" in build_canonicalize_latin()
    tt_to_bulgarian_matching[k] = v + [make_tuple(lower_entry(x)) for x in v]
    tt_to_bulgarian_matching[k.lower()] = [lower_entry(x) for x in v]
for k,v in tt_to_bulgarian_matching_non_case.items():
    tt_to_bulgarian_matching[k] = v

if debug_tables:
    for k,v in tt_to_bulgarian_matching.items():
        msg("t2rm %s = %s" % (k, v))

# FIXME FIXME FIXME!! We need a better way of handling accents in the interior
# of a multi-character Bulgarian matching sequence. For the moment we have to
# list all the possibilities with and without the accent, and include
# accented entries one character up.
tt_to_bulgarian_matching_2char = {
    # ja for ся is strange but occurs in ться vs. tʹja
    "ся":["sja","sa","ja"], # especially in the reflexive ending
    "нн":["nn","n"],
    "те":["te","ťe","țe"],
    "ие":["ije","ʹje","'je","je"],
    "ия":["ija","ia"],
    "ьо":["ʹo","ʹjo","'jo","jo"],
    "дж":["dž","j"],
    "кс":["ks","x"],
}

tt_to_bulgarian_matching_3char = {
    " — ":[" — ","—"," - ","-"],
}

tt_to_bulgarian_matching_4char = {
    "вств":["vstv","stv"],
}

tt_to_bulgarian_matching_all_char = dict(
        list(tt_to_bulgarian_matching.items()) +
        list(tt_to_bulgarian_matching_2char.items()) +
        list(tt_to_bulgarian_matching_3char.items()) +
        list(tt_to_bulgarian_matching_4char.items()))

build_canonicalize_latin = {}
for ch in dont_self_canonicalize:
    # "multiple" suppresses any self-canonicalization of this character
    build_canonicalize_latin[ch] = "multiple"
build_canonicalize_latin[""] = "multiple"

# Make sure we don't canonicalize any canonical letter to any other one;
# e.g. could happen with ʾ, an alternative for ʿ.
for bulgarian, alts in tt_to_bulgarian_matching_all_char.items():
    if not isinstance(alts, list):
        alts = [alts]
    canon = alts[0]
    if isinstance(canon, list):
        canon = canon[0]
    if isinstance(canon, tuple):
        continue
    # "multiple" suppresses any self-canonicalization of this character
    build_canonicalize_latin[canon] = "multiple"
    # For from->to canonicalization, suppress self-canonicalzation of
    # the 'to' character, because it's a possible canonical char
    for canon in alts[1:]:
        if isinstance(canon, list) and len(canon) == 2:
            build_canonicalize_latin[canon[1]] = "multiple"

# Now build a table along the way to constructing the self-canonicalizing
# table. We make from->to entries for all non-canonical chars; if we
# encounter an existing from->to entry with a different 'to', we set the
# value to "multiple", which suppresses any self-canonicalization of the
# character.
for bulgarian, alts in tt_to_bulgarian_matching_all_char.items():
    if not isinstance(alts, list):
        alts = [alts]
    canon = alts[0]
    if isinstance(canon, list):
        continue
    for alt in alts[1:]:
        frm = alt
        to = canon
        if isinstance(frm, list):
            if len(frm) == 1:
                continue
            assert len(frm) == 2 or len(frm) == 3
            to = frm[1]
            frm = frm[0]
        if isinstance(frm, tuple):
            continue
        if frm in build_canonicalize_latin and build_canonicalize_latin[frm] != to:
            if debug_tables:
                msg("Setting bcl of %s to multiple" % frm)
            build_canonicalize_latin[frm] = "multiple"
        else:
            if debug_tables:
                msg("Setting bcl of %s to %s" % (frm, to))
            build_canonicalize_latin[frm] = to

# Now build the actual self-canonicalizing table, derived from the
# previous table minus any entries with the value 'multiple'.
# NOTE: Multiple-character 'from' entries on this table have no effect
# since the self-canonicalizing algorithm goes character-by-character.
tt_canonicalize_latin = {}
for frm, to in build_canonicalize_latin.items():
    if to != "multiple":
        tt_canonicalize_latin[frm] = to

if debug_tables:
    for x,y in build_canonicalize_latin.items():
        msg("%s = %s" % (x, y))

# Pre-canonicalize Latin, and Bulgarian if supplied. If Bulgarian is supplied,
# it should be the corresponding Bulgarian (after pre-pre-canonicalization),
# and is used to do extra canonicalizations.
def pre_canonicalize_latin(text, bulgarian=None, msgfun=msg):
    debprint("pre_canonicalize_latin: Enter, text=%s" % text)
    # remove L2R, R2L markers
    text = rsub(text, "[\u200E\u200F]", "")
    # remove embedded comments
    text = rsub(text, "<!--.*?-->", "")
    # remove embedded IPAchar templates
    text = rsub(text, r"\{\{IPAchar\|(.*?)\}\}", r"\1")
    # canonicalize whitespace, including things like no-break space
    text = re.sub(r"\s+", " ", text, 0, re.U)
    # remove leading/trailing spaces
    text = text.strip()
    # decompose accented letters
    text = rsub(text, "[áéíóúýńÁÉÍÓÚÝŃàèìòùỳÀÈÌÒÙỲ]",
            {"á":"a"+AC, "é":"e"+AC, "í":"i"+AC,
             "ó":"o"+AC, "ú":""+AC, "ý":"y"+AC, "ń":"n"+AC,
             "Á":"A"+AC, "É":"E"+AC, "Í":"I"+AC,
             "Ó":"O"+AC, "Ú":"U"+AC, "Ý":"Y"+AC, "Ń":"N"+AC,
             "à":"a"+GR, "è":"e"+GR, "ì":"i"+GR,
             "ò":"o"+GR, "ù":""+GR, "ỳ":"y"+GR,
             "À":"A"+GR, "È":"E"+GR, "Ì":"I"+GR,
             "Ò":"O"+GR, "Ù":"U"+GR, "Ỳ":"Y"+GR,})

    ## "compose" digraphs
    ## This causes problems for words beginning with разх- and isn't necessary
    ## when both Latin and Cyrillic are available.
    #text = rsub(text, "[czskCZSK]h",
    #    {"ch":"č", "zh":"ž", "sh":"š", "kh":"x",
    #     "Ch":"Č", "Zh":"Ž", "Sh":"Š", "Kh":"X"})

    # canonicalize quote-like signs to make matching easier.
    text = rsub(text, double_quote_like_re, double_quote_like[0])
    text = rsub(text, single_quote_like_re, single_quote_like[0])

    # sub non-Latin similar chars to Latin
    text = rsub(text, bulgarian_lookalikes_re, bulgarian_to_latin_lookalikes)
    text = rsub(text, "[эε]",'ɛ') # Cyrillic э, Greek ε to Latin ɛ

    # remove some accents; don't include Ǎ, ǎ, Ě, ě which transliterate Bulgarian characters
    text = rsub(text, "[äïöüÿÄÏÖÜŸǐǒǔǏǑǓ]",
            {"ä":"a","ï":"i","ö":"o","ü":"",
             "ǐ":"i","ǒ":"o","ǔ":"",
             "Ä":"A","Ï":"I","ö":"O","Ü":"U",
             "Ǐ":"I","Ǒ":"O","Ǔ":"U",})

    # remove [[...]] from Latin
    if text.startswith("[[") and text.endswith("]]"):
        text = text[2:-2]

    # remove '''...''', ''...'' from Latin if not in Bulgarian
    if bulgarian:
        if (text.startswith("'''") and text.endswith("'''") and
                not bulgarian.startswith("'''") and not bulgarian.endswith("'''")):
            text = text[3:-3]
        elif (text.startswith("''") and text.endswith("''") and
                not bulgarian.startswith("''") and not bulgarian.endswith("''")):
            text = text[2:-2]
        # If no parens in Bulgarian and stray, unmatched praren at beginning or
        # end of Latin, remove it
        if "(" not in bulgarian and ")" not in bulgarian:
            if text.endswith(")") and "(" not in text:
                text = text[0:-1]
            if text.startswith("(") and ")" not in text:
                text = text[1:]

    # remove leading/trailing spaces again, cases like ''podnimát' ''
    text = text.strip()

    # canonicalize sequences of accents
    text = rsub(text, AC + "+", AC)
    text = rsub(text, GR + "+", GR)

    # Warn if multiple accents.
    latin_words = re.split(r"([\s+-/|\[\].])", text)
    for accent, english in [(AC, "acute"), (GR, "grave")]:
        for word in latin_words:
            if len(rsub(word, "[^" + accent + "]", "")) > 1:
                msgfun("WARNING: Latin %s has multiple %s accents"
                        % (text, english))
    # Change grave to acute in Latin if no acute accent also in word and only one
    # grave accent in word, but don't change the word ì (which is a special case in Bulgarian).
    new_latin_words = []
    for word in latin_words:
        if (re.search(GR, word) and not re.search(AC, word) and
                not re.search(r"\bi" + GR + r"($|\W)", word) and
                len(rsub(word, "[^" + GR + "]", "")) == 1):
            msgfun("Changing grave to acute in Latin word %s (Latin %s, Bulgarian %s)"
                    % (word, text, bulgarian))
            word = rsub(word, GR, AC)
        new_latin_words.append(word)
    text = "".join(new_latin_words)
    if re.search(GR, text):
        msgfun("WARNING: Latin %s has a grave accent" % text)

    debprint("pre_canonicalize_latin: Exit, text=%s" % text)
    return text

def tr_canonicalize_latin(text):
    # recompose accented letters
    text = rsub(text, "[aeiouyAEIOUY][" + AC + GR + "]",
        {"a"+AC:"á", "e"+AC:"é", "i"+AC:"í",
         "o"+AC:"ó", ""+AC:"ú", "y"+AC:"ý", "n"+AC:"ń",
         "A"+AC:"Á", "E"+AC:"É", "I"+AC:"Í",
         "O"+AC:"Ó", "U"+AC:"Ú", "Y"+AC:"Ý", "N"+AC:"Ń",
         "a"+GR:"à", "e"+GR:"è", "i"+GR:"ì",
         "o"+GR:"ò", ""+GR:"ù", "y"+GR:"ỳ",
         "A"+GR:"À", "E"+GR:"È", "I"+GR:"Ì",
         "O"+GR:"Ò", "U"+GR:"Ù", "Y"+GR:"Ỳ",})

    return text

def post_canonicalize_latin(text, msgfun=msg):
    # Handle Bulgarian jo.
    # FIXME, it may be correct to convert this to Jo, if the Bulgarian text has
    # Ь. But there don't seem to be any examples of that.
    text = rsub(text, "ʹo", "jo")

    # recompose accented letters
    text = tr_canonicalize_latin(text)

    text = text.strip()

    if re.search("[\u0400-\u052F\u2DE0-\u2DFF\uA640-\uA69F]", text):
        msgfun("WARNING: Latin text %s contains Cyrillic characters" % text)
    return text

# Canonicalize a Latin transliteration and Bulgarian text to standard form.
# Can be done on only Latin or only Bulgarian (with the other one None), but
# is more reliable when both are provided. This is less reliable than
# tr_matching() and is meant when that fails. Return value is a tuple of
# (CANONLATIN, CANONFOREIGN).
def canonicalize_latin_bulgarian(latin, bulgarian, msgfun=msg):
    if bulgarian is not None:
        bulgarian = pre_pre_canonicalize_bulgarian(bulgarian, msgfun)
    if latin is not None:
        latin = pre_canonicalize_latin(latin, bulgarian, msgfun)
    if bulgarian is not None:
        bulgarian = pre_canonicalize_bulgarian(bulgarian, msgfun)
        bulgarian = post_canonicalize_bulgarian(bulgarian, msgfun)
    if latin is not None:
        # Protect instances of two or more single quotes in a row so they don't
        # get converted to sequences of ʹ characters.
        def quote_subst(m):
            return m.group(0).replace("'", multi_single_quote_subst)
        latin = re.sub(r"''+", quote_subst, latin)
        latin = rsub(latin, ".", tt_canonicalize_latin)
        latin = latin.replace(multi_single_quote_subst, "'")
        latin = post_canonicalize_latin(latin, msgfun)
    return (latin, bulgarian)

def canonicalize_latin_foreign(latin, bulgarian, msgfun=msg):
    return canonicalize_latin_bulgarian(latin, bulgarian, msgfun)

def tr_canonicalize_bulgarian(text):
    # need to decompose grave-accented еЕиИ
    text = rsub(text, "ѝ", "и" + GR)
    text = rsub(text, "Ѝ", "И" + GR)
    text = rsub(text, "ѐ", "е" + GR)
    text = rsub(text, "Ѐ", "Е" + GR)
    return text

# Early pre-canonicalization of Bulgarian, doing stuff that's safe. We split
# this from pre-canonicalization proper so we can do Latin pre-canonicalization
# between the two steps.
def pre_pre_canonicalize_bulgarian(text, msgfun=msg):
    # remove L2R, R2L markers
    text = rsub(text, "[\u200E\u200F]", "")
    # canonicalize whitespace, including things like no-break space
    text = re.sub(r"\s+", " ", text, 0, re.U)
    # remove leading/trailing spaces
    text = text.strip()

    text = tr_canonicalize_bulgarian(text)

    # Convert word-final hard sign to special silent character; will be
    # undone later
    text = rsub(text, "Ъ($|[- \]])", capital_silent_hard_sign + r"\1")
    text = rsub(text, "ъ($|[- \]])", small_silent_hard_sign + r"\1")

    # sub non-Cyrillic similar chars to Cyrillic
    newtext = rsub(text, latin_lookalikes_re, latin_to_bulgarian_lookalikes)
    if newtext != text:
        if re.search("[A-Za-z]", newtext):
            msgfun("WARNING: Bulgarian %s has Latin chars in it after trying to correct them, not correcting"
                    % text)
        # Don't do things like расставить все точки над i
        elif re.search(r"\b[A-Za-z]\b", text, re.U):
            msgfun("WARNING: Bulgarian %s has one-char Latin word in it, not correcting"
                    % text)
        else:
            text = newtext

    # canonicalize sequences of accents
    text = rsub(text, AC + "+", AC)
    text = rsub(text, GR + "+", GR)

    # Warn if multiple accents.
    bulgarian_words = re.split(r"([\s+-/|\[\].])", text)
    for accent, english in [(AC, "acute"), (GR, "grave")]:
        for word in bulgarian_words:
            if len(rsub(word, "[^" + accent + "]", "")) > 1:
                msgfun("WARNING: Bulgarian %s has multiple %s accents"
                        % (text, english))
    # Change grave to acute in Bulgarian if no acute accent also in word and only one
    # grave accent in word, but don't change the word ѝ (which is a special case in Bulgarian).
    new_bulgarian_words = []
    for word in bulgarian_words:
        if (re.search(GR, word) and not re.search(AC, word) and
                not re.search(r"\bи" + GR + r"($|\W)", word) and
                len(rsub(word, "[^" + GR + "]", "")) == 1):
            msgfun("Changing grave to acute in Bulgarian word %s (Latin %s, Bulgarian %s)"
                    % (word, text, text))
            word = rsub(word, GR, AC)
        new_bulgarian_words.append(word)
    text = "".join(new_bulgarian_words)
    if re.search(GR, text):
        msgfun("WARNING: Bulgarian %s has a grave accent" % text)

    return text

def pre_canonicalize_bulgarian(text, msgfun=msg):
    return text

def post_canonicalize_bulgarian(text, msgfun=msg):
    # need to recompose grave-accented еЕиИ
    text = text.replace("и" + GR, "ѝ")
    text = text.replace("И" + GR, "Ѝ")
    text = text.replace("е" + GR, "ѐ")
    text = text.replace("Е" + GR, "Ѐ")
    text = text.replace(capital_silent_hard_sign, "Ъ")
    text = text.replace(small_silent_hard_sign, "ъ")
    return text

def debprint(x):
    if debug_tr_matching:
        print(x)

# Vocalize Bulgarian based on transliterated Latin, and canonicalize the
# transliteration based on the Bulgarian.  This works by matching the Latin
# to the Bulgarian and transferring Latin stress marks to the Bulgarian as
# appropriate, so that ambiguities of Latin transliteration can be
# correctly handled. Returns a tuple of Bulgarian, Latin. If unable to match,
# throw an error if ERR, else return None.
def tr_matching(bulgarian, latin, err=False, msgfun=msg):
    origbulgarian = bulgarian
    origlatin = latin
    bulgarian = pre_pre_canonicalize_bulgarian(bulgarian, msgfun)
    latin = pre_canonicalize_latin(latin, bulgarian, msgfun)
    bulgarian = pre_canonicalize_bulgarian(bulgarian, msgfun)

    ru = [] # exploded Bulgarian characters
    la = [] # exploded Latin characters
    res = [] # result Bulgarian characters
    lres = [] # result Latin characters
    for cp in bulgarian:
        ru.append(cp)
    for cp in latin:
        la.append(cp)
    rind = [0] # index of next Bulgarian character
    rlen = len(ru)
    lind = [0] # index of next Latin character
    llen = len(la)

    def is_bow(pos=None):
        if pos is None:
            pos = rind[0]
        return pos == 0 or ru[pos - 1] in [" ", "[", "|", "-"]

    # True if we are at the last character in a word.
    def is_eow(pos=None):
        if pos is None:
            pos = rind[0]
        return pos == rlen - 1 or ru[pos + 1] in [" ", "]", "|", "-"]

    def get_matches_nchar(numchar):
        assert numchar >= 2 and numchar <= 4
        assert rind[0] + numchar <= rlen
        ac = "".join(ru[rind[0]:rind[0]+numchar])
        debprint("get_matches_%schar: ac (%schar) is %s" % (
            numchar, numchar, ac))
        if numchar == 4:
            matches = tt_to_bulgarian_matching_4char.get(ac)
        elif numchar == 3:
            matches = tt_to_bulgarian_matching_3char.get(ac)
        elif numchar == 2:
            matches = tt_to_bulgarian_matching_2char.get(ac)
        debprint("get_matches_%schar: matches is %s" % (numchar, matches))
        if matches == None:
            matches = []
        elif type(matches) is not list:
            matches = [matches]
        return ac, matches

    def get_matches():
        assert rind[0] < rlen
        ac = ru[rind[0]]
        debprint("get_matches: ac is %s" % ac)
        matches = tt_to_bulgarian_matching.get(ac)
        if matches == None and ac in unmatch_either_after:
            matches = []
        debprint("get_matches: matches is %s" % matches)
        if matches == None:
            if True:
                error("Encountered non-Bulgarian (?) character " + ac +
                    " at index " + str(rind[0]))
            else:
                matches = [ac]
        if type(matches) is not list:
            matches = [matches]
        return ac, matches

    # Check for link of the form [[foo|bar]] and skip over the part
    # up through the vertical bar, copying it
    def skip_vertical_bar_link():
        if rind[0] < rlen and ru[rind[0]] == '[':
            newpos = rind[0]
            while newpos < rlen and ru[newpos] != ']':
                if ru[newpos] == '|':
                    newpos += 1
                    debprint("skip_vertical_bar_link: skip over [[...|, rind=%s -> %s" % (
                        rind[0], newpos))
                    while rind[0] < newpos:
                        res.append(ru[rind[0]])
                        rind[0] += 1
                    return True
                newpos += 1
        return False

    # attempt to match the current Bulgarian character (or multi-char sequence,
    # if NUMCHAR > 1) against the current Latin character(s). If no match,
    # return False; else, increment the Bulgarian and Latin pointers over
    # the matched characters, add the Bulgarian character(s) and the
    # corresponding match-canonical Latin character(s) to the result lists
    # and return True.
    def match(numchar):
        if rind[0] + numchar > rlen:
            return False

        if numchar > 1:
            ac, matches = get_matches_nchar(numchar)
        else:
            ac, matches = get_matches()

        debprint("match: lind=%s, la=%s" % (
            lind[0], lind[0] >= llen and "EOF" or la[lind[0]]))

        for m in matches:
            subst = matches[0]
            if type(subst) is list:
                subst = subst[0]
            if type(subst) is tuple:
                subst = subst[0]
            substbulgarian = ac
            preserve_latin = False
            # If an element of the match list is a one-element list, it means
            # "don't canonicalize". If a two-element list, it means
            # "canonicalize from m[0] to m[1]".
            if type(m) is list:
                if len(m) == 1:
                    preserve_latin = True
                    m = m[0]
                elif len(m) == 2:
                    m, subst = m
                else:
                    assert len(m) == 3
                    m, subst, substbulgarian = m
            assert isinstance(subst, basestring)
            assert isinstance(substbulgarian, basestring)
            # A one-element tuple is a signal for use in self-canonicalization,
            # not here.
            if type(m) is tuple:
                m = m[0]
            assert isinstance(m, basestring)
            l = lind[0]
            matched = True
            debprint("m: %s, subst: %s" % (m, subst))
            for cp in m:
                if l < llen and la[l] == cp:
                    debprint("cp: %s, l=%s, la=%s" % (cp, l, la[l]))
                    l = l + 1
                else:
                    debprint("cp: %s, unmatched")
                    matched = False
                    break
            if matched:
                for c in substbulgarian:
                    res.append(c)
                if preserve_latin:
                    for cp in m:
                        lres.append(cp)
                else:
                    for cp in subst:
                        lres.append(cp)
                lind[0] = l
                rind[0] = rind[0] + len(ac)
                debprint("matched; lind is %s" % lind[0])
                return True
        return False

    def cant_match():
        if rind[0] < rlen and lind[0] < llen:
            error("Unable to match Bulgarian character %s at index %s, Latin character %s at index %s" %
                (ru[rind[0]], rind[0], la[lind[0]], lind[0]))
        elif rind[0] < rlen:
            error("Unable to match trailing Bulgarian character %s at index %s" %
                (ru[rind[0]], rind[0]))
        else:
            error("Unable to match trailing Latin character %s at index %s" %
                (la[lind[0]], lind[0]))

    # Handle acute or grave accent or punctuation, which can be unmatching
    # on either side.
    def check_unmatch_either(unmatch_either):
        # Matching accents
        if (lind[0] < llen and rind[0] < rlen and
                la[lind[0]] in unmatch_either and
                la[lind[0]] == ru[rind[0]]):
            res.append(ru[rind[0]])
            lres.append(la[lind[0]])
            rind[0] += 1
            lind[0] += 1
            return True
        # Unmatched accent on Latin side
        if lind[0] < llen and la[lind[0]] in unmatch_either:
            res.append(la[lind[0]])
            lres.append(la[lind[0]])
            lind[0] += 1
            return True
        # Unmatched accent on Bulgarian side
        if rind[0] < rlen and ru[rind[0]] in unmatch_either:
            res.append(ru[rind[0]])
            lres.append(ru[rind[0]])
            rind[0] += 1
            return True
        return False

    # If the Bulgarian is an end-of-word hard sign, consume any hard or
    # soft signs or single/double-quote-like characters. We need a
    # special case here because we want the "canonical" Latin entry
    # to be empty, and putting an empty string as the canonical Latin
    # entry followed by other entries won't work; the empty string
    # will match and the other entries will never get checked.
    def consume_against_eow_hard_sign():
        if rind[0] < rlen and ru[rind[0]] in [capital_silent_hard_sign,
                small_silent_hard_sign]:
            # Consume any hard/soft-like signs
            if lind[0] < llen and la[lind[0]] in (["Ъ","ъ"] +
                    hard_sign_matching + soft_sign_matching):
                lind[0] += 1
            res.append(ru[rind[0]])
            rind[0] += 1
            return True
        return False

    # Here we go through the Bulgarian letter for letter, matching
    # up the consonants we encounter with the corresponding Latin consonants
    # using the dict in tt_to_bulgarian_matching and copying the Bulgarian
    # consonants into a destination array. When we don't match, we check for
    # allowed unmatching Latin characters in tt_to_bulgarian_unmatching, which
    # handles acute accents. If this doesn't match either, and we have
    # left-over Bulgarian or Latin characters, we reject the whole match,
    # either returning False or signaling an error.

    while rind[0] < rlen or lind[0] < llen:
        matched = False
        # Check for matching or unmatching acute/grave accent.
        # We do this first to deal with cases where the Bulgarian has a
        # right bracket, single quote or similar character that can be
        # unmatching, and the Latin has an unmatched accent, which needs
        # to be matched first.
        if check_unmatch_either(unmatch_either_before):
            matched = True
        elif consume_against_eow_hard_sign():
            debprint("Matched: consume_against_eow_hard_sign()")
            matched = True
        elif skip_vertical_bar_link():
            debprint("Matched: skip_vertical_bar_link()")
            matched = True
        elif match(4):
            debprint("Matched: Clause match(4)")
            matched = True
        elif match(3):
            debprint("Matched: Clause match(3)")
            matched = True
        elif match(2):
            debprint("Matched: Clause match(2)")
            matched = True
        elif match(1):
            debprint("Matched: Clause match(1)")
            matched = True
        # Check for matching or unmatching punctuation. We do this afterwards
        # to deal with cases where the Bulgarian has a right bracket,
        # single quote or similar character that can be unmatching, and the
        # Latin has an unmatched punctuation char, which needs to be matched
        # afterwards.
        elif check_unmatch_either(unmatch_either_after):
            matched = True
        if not matched:
            if err:
                cant_match()
            else:
                return False

    bulgarian = "".join(res)
    latin = "".join(lres)
    bulgarian = post_canonicalize_bulgarian(bulgarian, msgfun)
    latin = post_canonicalize_latin(latin, msgfun)
    return bulgarian, latin

def remove_diacritics(text):
    text = tr_canonicalize_bulgarian(text)
    text = text.replace(AC, "")
    text = text.replace(GR, "")
    return text

################################ Test code ##########################

num_failed = 0
num_succeeded = 0

def test(latin, bulgarian, should_outcome, expectedbulgarian=None):
    global num_succeeded, num_failed
    if not expectedbulgarian:
        expectedbulgarian = bulgarian
    try:
        result = tr_matching(bulgarian, latin, True)
    except RuntimeError as e:
        print("%s" % e)
        result = False
    if result == False:
        print("tr_matching(%s, %s) = %s" % (bulgarian, latin, result))
        outcome = "failed"
        canonbulgarian = expectedbulgarian
    else:
        canonbulgarian, canonlatin = result
        trlatin = tr(canonbulgarian)
        print("tr_matching(%s, %s) = %s %s, " % (bulgarian, latin, canonbulgarian, canonlatin), end="")
        if trlatin == canonlatin:
            print("tr() MATCHED")
            outcome = "matched"
        else:
            print("tr() UNMATCHED (= %s)" % trlatin)
            outcome = "unmatched"
    if canonbulgarian != expectedbulgarian:
        print("Canon Bulgarian FAILED, expected %s got %s"% (
            expectedbulgarian, canonbulgarian))
    canonlatin, _ = canonicalize_latin_bulgarian(latin, None)
    print("canonicalize_latin(%s) = %s" %
            (latin, canonlatin))
    if outcome == should_outcome and canonbulgarian == expectedbulgarian:
        print("TEST SUCCEEDED.")
        num_succeeded += 1
    else:
        print("TEST FAILED.")
        num_failed += 1

def run_tests():
    global num_succeeded, num_failed
    num_succeeded = 0
    num_failed = 0

    # Test inferring accents in both Cyrillic and Latin
    test("zontik", "зонтик", "matched")
    test("zóntik", "зо́нтик", "matched", "зо́нтик")
    test("zóntik", "зонтик", "matched", "зо́нтик")
    test("zontik", "зо́нтик", "matched")
    test("zontik", "зо́нтик", "matched")

    # Things that should fail
    test("zontak", "зонтик", "failed")
    test("zontika", "зонтик", "failed")

    # Test with Cyrillic e
    test("jebepʹje jebe", "ебепье ебе", "matched")
    test("jebepʹe jebe", "ебепье ебе", "matched")
    test("Jebe Jebe", "Ебе Ебе", "matched")
    test("ebe ebe", "ебе ебе", "matched")
    test("Ebe Ebe", "Ебе Ебе", "matched")
    test("yebe yebe", "ебе ебе", "matched")
    test("yebe yebe", "[[ебе]] [[ебе]]", "matched")
    test("Yebe Yebe", "Ебе Ебе", "matched")
    test("ébe ébe", "ебе ебе", "matched", "е́бе е́бе")
    test("Ébe Ébe", "Ебе Ебе", "matched", "Е́бе Е́бе")
    test("yéye yéye", "ее ее", "matched", "е́е е́е")
    test("yéye yéye", "е́е е́е", "matched")
    test("yeye yeye", "е́е е́е", "matched")

    # Test handling of embedded links, including unmatched acute accent
    # directly before right bracket on Bulgarian side
    test("pala volu", "пала [[вола|волу]]", "matched")
    test("pala volú", "пала [[вола|волу]]", "matched", "пала [[вола|волу́]]")
    test("volu pala", "[[вола|волу]] пала", "matched")
    test("volú pala", "[[вола|волу]] пала", "matched", "[[вола|волу́]] пала")
    test("volupala", "[[вола|волу]]пала", "matched")
    test("pala volu", "пала [[волу]]", "matched")
    test("pala volú", "пала [[волу]]", "matched", "пала [[волу́]]")
    test("volu pala", "[[волу]] пала", "matched")
    test("volú pala", "[[волу]] пала", "matched", "[[волу́]] пала")
    test("volúpala", "[[волу]]пала", "matched", "[[волу́]]пала")

    # Silent hard signs
    test("mir", "миръ", "matched")
    test("mir", "міръ", "matched")
    test("MIR", "МІРЪ", "matched")

    # Single quotes in Bulgarian
    test("volu '''pala'''", "волу '''пала'''", "matched")
    test("volu pala", "волу '''пала'''", "matched")
    test("volu '''palá'''", "волу '''пала'''", "matched", "волу '''пала́'''")
    test("volu palá", "волу '''пала'''", "matched", "волу '''пала́'''")
    # Here the single quote after l should become ʹ but not the others
    test("volu '''pal'dá'''", "волу '''пальда'''", "matched", "волу '''пальда́'''")
    test("bólʹše vsevó", "[[бо́льше]] [[всё|всего́]]", "unmatched")

    # Some real-world tests
    # FIXME!!
    # test("Gorbačóv", "Горбачев", "matched", "Горбачёв")
    test("Igor", "Игорь", "matched")
    test("rajón″", "районъ", "matched", "райо́нъ")
    test("karantin’", "карантинъ", "matched")
    test("blyad", "блядь", "matched")
    test("ródъ", "родъ", "matched", "ро́дъ")
    test("soból´", "соболь", "matched", "собо́ль")
    test("časóvn'a", "часовня", "matched", "часо́вня")
    test("ėkzistencializm", "экзистенциализм", "matched")
    test("ješčó", "ещё", "matched")
    test("pardoń", "пардон́", "matched")
    # The following Latin has Bulgarian ё
    test("lёgkoe", "лёгкое", "matched")
    test("prýšik", "прыщик", "matched", "пры́щик")
    test("''d'ejstvít'el'nost'''", "действительность", "matched",
            "действи́тельность")
    test("óstrov Rejun'jón", "остров Реюньон", "matched", "о́стров Реюньо́н")
    test("staromodny", "старомодный", "matched")
    # also should match when listed Bulgarian 2-char sequence fails to match
    # as such but can match char-by-char
    test("niy", "ный", "matched")
    test("trudít’sa", "трудиться", "matched", "труди́ться")
    test("vsestorónij", "всесторонний", "matched", "всесторо́нний")
    test("Válle-d’Aósta", "Валле-д'Аоста", "matched", "Ва́лле-д'Ао́ста")
    test("interesovátʹja", "интересоваться", "matched", "интересова́ться")
    test("rešímosť", "решимость", "matched", "реши́мость")
    test("smirénje", "смирение", "matched", "смире́ние")
    test("prékhodjaschij", "преходящий", "matched", "пре́ходящий")
    test("čústvo jazyká", "чувство языка", "matched", "чу́вство языка́")
    test("zanoš'ivost'", "заносчивость", "matched")
    test("brezgátь", "брезгать", "matched", "брезга́ть")
    test("adaptacia", "адаптация", "matched")
    test("apryiórniy", "априо́рный", "matched")
    # The following has Latin é in the Cyrillic
    test("prostrе́l", "прострéл", "matched", "простре́л")
    test("razdvaibat'", "раздваивать", "matched")
    # The following has Latin a in the Cyrillic
    test("Malán'ja", "Мaла́нья", "matched", "Мала́нья")
    test("''podnimát' ''", "поднимать", "matched", "поднима́ть")
    test("priv'áš'ivyj", "привязчивый", "matched", "привя́зчивый")
    test("zaméthyj", "заметный", "matched", "заме́тный")
    test("beznadyozhnyi", "безнадëжный", "unmatched", "безнадёжный")
    test("žénščinы", "женщины", "matched", "же́нщины")
    test("diakhronicheskyi", "диахронический", "matched")
    test("m'áχkij", "мягкий", "unmatched", "мя́гкий")
    test("vnimӓtelʹnyj","внима́тельный", "matched")
    test("brítanskij ángliskij", "британский английский", "matched",
            "бри́танский а́нглийский")
    test("gospódʹ", "Госпо́дь", "matched")
    test("ťomnij", "тёмный", "unmatched")
    test("bidonviľ", "бидонвиль", "matched")
    test("zádneje sidénʹje", "заднее сидение", "matched", "за́днее сиде́ние")
    test("s volkámi žitʹ - po-vólčʹi vytʹ", "с волками жить — по-волчьи выть",
            "matched", "с волка́ми жить — по-во́лчьи выть")
    test("Tajikskaja SSR", "Таджикская ССР", "matched")
    test("loxodroma", "локсодрома", "matched")
    test("prostophilya", "простофиля", "matched")
    test("polevój gospitál‘", "полевой госпиталь", "matched",
            "полево́й госпита́ль")
    test("vrémja—dén’gi", "время — деньги", "matched", "вре́мя — де́ньги")
    test("piniǎ", "пиния", "matched")
    test("losjón", "лосьон", "matched", "лосьо́н")
    test("εkzegéza", "экзегеза", "matched", "экзеге́за")
    test("brunɛ́jec", "бруне́ец", "unmatched")
    test("runglíjskij jazýk", "рунглийский язык", "matched", "рунгли́йский язы́к")
    test("skyy jazýk", "скый язык", "matched", "скый язы́к")
    test("skýy jazýk", "скый язык", "matched", "скы́й язы́к")
    test("ni púha ni perá", "ни пуха, ни пера", "matched",
            "ни пу́ха, ни пера́")
    test("predpolozytelyniy", "предположи́тельный", "matched")

    # Test adding !, ? or .
    test("fan", "фан!", "matched")
    test("fan!", "фан!", "matched")
    test("fan!", "фан", "matched", "фан!")
    test("fan", "фан?", "matched")
    test("fan?", "фан?", "matched")
    test("fan?", "фан", "matched", "фан?")
    test("fan", "фан.", "matched")
    test("fan.", "фан.", "matched")
    test("fan.", "фан", "matched", "фан.")

    # Check behavior of parens
    test("(fan)", "(фан)", "matched")
    test("fan", "(фан)", "matched")
    test("(fan", "фан", "matched")
    test("fan)", "фан", "matched")
    test("(fan)", "фан", "failed")

    # Final results
    print("RESULTS: %s SUCCEEDED, %s FAILED." % (num_succeeded, num_failed))

if __name__ == "__main__":
    run_tests()
