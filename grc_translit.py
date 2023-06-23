#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# Authors: Benwing; ??? for tr() functions, in Lua

import re
import unicodedata

from blib import remove_links, msg

# FIXME:
#
# 1. Check case of "ᾱῦ", whether the PERIS shouldn't be on first vowel.
#    Similarly with ACUTE (and GRAVE?).
# 2. Also check case of Latin Hāídēs. What should it be?

# Accented characters
GRAVE = "\u0300"      # grave accent = varia
ACUTE = "\u0301"      # acute accent = oxia, tonos
CIRC = "\u0302"       # circumflex accent
MAC = "\u0304"        # macron
BREVE = "\u0306"      # breve = vrachy
DIA = "\u0308"        # diaeresis = dialytika
CAR = "\u030C"        # caron = haček
SMBR = "\u0313"       # smooth breathing = comma above = psili
ROBR = "\u0314"       # rough breathing = reversed comma above = dasia
PERIS = "\u0342"      # perispomeni (circumflex accent)
KORO = "\u0343"       # koronis (is this used? looks like comma above/psili)
DIATON = "\u0344"     # dialytika tonos = diaeresis + acute, should not occur
IOBE = "\u0345"       # iota below = ypogegrammeni

GR_ACC = ("[" + GRAVE + ACUTE + MAC + BREVE + DIA + SMBR + ROBR +
        PERIS + KORO + DIATON + IOBE + "]")
GR_ACC_NO_IOBE = ("[" + GRAVE + ACUTE + MAC + BREVE + DIA + SMBR + ROBR +
        PERIS + KORO + DIATON + "]")
GR_ACC_NO_DIA = ("[" + GRAVE + ACUTE + MAC + BREVE + SMBR + ROBR +
        PERIS + KORO + DIATON + IOBE + "]")
GR_ACC_NO_MB = ("[" + GRAVE + ACUTE + DIA + SMBR + ROBR +
        PERIS + KORO + DIATON + IOBE + "]")
LA_ACC_NO_MB = ("[" + GRAVE + ACUTE + CIRC + DIA + CAR + "]")
ONE_MB = "[" + MAC + BREVE + "]"
MBS = ONE_MB + "+"
MBSOPT = ONE_MB + "*"
RS = "[" + ROBR + SMBR + "]"
RSOPT = RS + "?"

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

def nfc_form(txt):
    return unicodedata.normalize("NFC", str(txt))

def nfd_form(txt):
    return unicodedata.normalize("NFD", str(txt))

tt = {
    # Plain vowels
    "α":"a", "Α":"A",
    "ε":"e", "Ε":"E",
    "η":"e"+MAC, "Η":"E"+MAC,
    "ι":"i", "Ι":"I",
    "ο":"o", "Ο":"O",
    "ω":"o"+MAC, "Ω":"O"+MAC,
    "υ":"u", "Υ":"U",

    # Iotated vowels
    "ᾳ":"a"+MAC+"i", "ᾼ":"A"+MAC+"i",
    "ῃ":"e"+MAC+"i", "ῌ":"E"+MAC+"i",
    "ῳ":"o"+MAC+"i", "ῼ":"O"+MAC+"i",

    # Consonants
    "β":"b", "Β":"B",
    "γ":"g", "Γ":"G",
    "δ":"d", "Δ":"D",
    "ζ":"z", "Ζ":"Z",
    "θ":"th", "Θ":"Th",
    "κ":"k", "Κ":"K",
    "λ":"l", "Λ":"L",
    "μ":"m", "Μ":"M",
    "ν":"n", "Ν":"N",
    "ξ":"ks", "Ξ":"Ks",
    "π":"p", "Π":"P",
    "ρ":"r", "Ρ":"R",
    "σ":"s", "ς":"s", "Σ":"S",
    "τ":"t", "Τ":"T",
    "φ":"ph", "Φ":"Ph",
    "χ":"kh", "Χ":"Kh",
    "ψ":"ps", "Ψ":"Ps",

    # Archaic letters
    "ϝ":"w", "Ϝ":"W",
    "ϻ":"s"+ACUTE, "Ϻ":"S"+ACUTE,
    "ϙ":"q", "Ϙ":"Q",
    "ϡ":"s"+CAR, "Ϡ":"S"+CAR,
    "\u0377":"v", "\u0376":"V",

    GRAVE:GRAVE,
    ACUTE:ACUTE,
    MAC:MAC,
    BREVE:"",
    DIA:DIA,
    SMBR:"",
    ROBR:"h", # will be canonicalized before uppercase vowel
    PERIS:CIRC,
    KORO:"", # should not occur,
    DIATON:DIA + ACUTE, # should not occur
    IOBE:"i", #should not occur
}

greek_lowercase_vowels_raw = "αεηιοωυᾳῃῳ"
greek_lowercase_vowels = "[" + greek_lowercase_vowels_raw + "]"
greek_uppercase_vowels_raw = "ΑΕΗΙΟΩΥᾼῌῼ"
greek_uppercase_vowels = "[" + greek_uppercase_vowels_raw + "]"
greek_vowels = ("[" + greek_lowercase_vowels_raw + greek_uppercase_vowels_raw
        + "]")
# vowels that can be the first part of a diphthong
greek_diphthong_first_vowels = "[αεηοωΑΕΗΟΩ]"
iotate_vowel = {"α":"ᾳ", "Α":"ᾼ",
                "η":"ῃ", "Ε":"ῌ",
                "ω":"ῳ", "Ω":"ῼ",}

# Transliterates text, which should be a single word or phrase. It should
# include stress marks, which are then preserved in the transliteration.
def tr(text, lang=None, sc=None, msgfun=msg):
    text = remove_links(text)
    text = tr_canonicalize_greek(text)

    text = rsub(text, "γ([γκξχ])", r"n\1")
    text = rsub(text, "ρρ", "rrh")

    text = rsub(text, '.', tt)

    # compose accented characters, fix hA and similar
    text = tr_canonicalize_latin(text)

    return text

############################################################################
#                      Transliterate from Latin to Greek                   #
############################################################################

#########       Transliterate with Greek to guide       #########

multi_single_quote_subst = "\ufff1"

# This dict maps Greek characters to all the Latin characters that
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
# somewhere-else.
#
# Each string might have multiple characters, to handle things
# like θ=th.

tt_to_greek_matching = {
    # Plain vowels; allow uppercase Greek to match lowercase Latin to
    # handle vowels with rough breathing
    "α":"a", "Α":["A","a"],
    "ε":"e", "Ε":["E","e"],
    "η":"e"+MAC, "Η":["E"+MAC,"e"+MAC],
    "ι":"i", "Ι":["I","i"],
    "ο":"o", "Ο":["O","o"],
    "ω":"o"+MAC, "Ω":["O"+MAC,"o"+MAC],
    "υ":"u", "Υ":["U","u"],

    # Iotated vowels
    "ᾳ":"a"+MAC+"i", "ᾼ":["A"+MAC+"i","a"+MAC+"i"],
    "ῃ":"e"+MAC+"i", "ῌ":["E"+MAC+"i","e"+MAC+"i"],
    "ῳ":"o"+MAC+"i", "ῼ":["O"+MAC+"i","o"+MAC+"i"],

    # Consonants
    "β":["b","β"], "Β":["B","Β"], # second B is Greek
    # This will match n anywhere against γ and canonicalize to g, which
    # is probably OK because in post-processing we convert gk/gg to nk/ng.
    "γ":["g","n","ŋ","γ"], "Γ":["G","Γ"],
    "δ":["d","δ"], "Δ":["D","Δ"],
    # Handling of ζ/Ζ opposite zd/Zd is special-cased in
    # check_unmatching_rh_zd().
    "ζ":"z", "Ζ":"Z",
    "θ":["th","θ"], "Θ":["Th","Θ"],
    "κ":["k","κ"], "Κ":"K",
    "λ":"l", "Λ":"L",
    "μ":"m", "Μ":"M",
    "ν":"n", "Ν":"N",
    "ξ":["ks","x","ξ"], "Ξ":["Ks","X","Ξ"],
    "π":"p", "Π":"P",
    # Handling of ρρ opposite rrh is special-cased in check_unmatching_rh_zd().
    "ρ":"r", "Ρ":"R",
    "σ":"s", "ς":"s", "Σ":"S",
    "τ":"t", "Τ":"T",
    "φ":["ph","φ"], "Φ":["Ph","Φ"],
    "χ":["kh","χ","ch"], "Χ":["Kh","Χ"],
    "ψ":["ps","ψ"], "Ψ":["Ps","Ψ"],

    # Archaic letters
    "ϝ":"w", "Ϝ":"W",
    "ϻ":"s"+ACUTE, "Ϻ":"S"+ACUTE,
    "ϙ":"q", "Ϙ":"Q",
    "ϡ":"s"+CAR, "Ϡ":"S"+CAR,
    "\u0377":"v", "\u0376":"V",

    GRAVE:[GRAVE,""],
    ACUTE:[ACUTE,""],
    MAC:[MAC,""],
    BREVE:"",
    DIA:[DIA,""],
    SMBR:"",
    ROBR:["h","H",""], # will be canonicalized before uppercase vowel
    PERIS:[CIRC,MAC,""],
    #KORO:"", # should not occur,
    #DIATON:DIA + ACUTE, # should not occur
    #IOBE:"i", #should not occur

    # numerals
    "1":"1", "2":"2", "3":"3", "4":"4", "5":"5",
    "6":"6", "7":"7", "8":"8", "9":"9", "0":"0",
    # punctuation (leave on separate lines)
    "?":"?", # question mark
    ",":",", # comma
    ";":";", # semicolon
    ".":".", # period
    "!":"!", # exclamation point
    "-":"-", # hyphen/dash
    "'":"'", # single quote, for bold/italic
    " ":" ",
    "[":"",
    "]":"",
}

word_interrupting_chars = "-[]"

build_canonicalize_latin = {}
# x X y Y not on list -- canoned to ks Ks u U
for ch in "abcdefghijklmnopqrstuvwzABCDEFGHIJKLMNOPQRSTUVWZ":
    build_canonicalize_latin[ch] = "multiple"
build_canonicalize_latin[""] = "multiple"

# Make sure we don't canonicalize any canonical letter to any other one;
# e.g. could happen with ʾ, an alternative for ʿ.
for greek in tt_to_greek_matching:
    alts = tt_to_greek_matching[greek]
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

for greek in tt_to_greek_matching:
    alts = tt_to_greek_matching[greek]
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

# A list of Latin characters that are allowed to be unmatched in the
# Greek. The value is the corresponding Greek character to insert.
tt_to_greek_unmatching = {
    MAC:MAC,
    BREVE:BREVE,
}

# Pre-canonicalize Latin, and Greek if supplied. If Greek is supplied,
# it should be the corresponding Greek (after pre-pre-canonicalization),
# and is used to do extra canonicalizations.
def pre_canonicalize_latin(text, greek=None):
    # remove L2R, R2L markers
    text = rsub(text, "[\u200E\u200F]", "")
    # remove embedded comments
    text = rsub(text, "<!--.*?-->", "")
    # remove embedded IPAchar templates
    text = rsub(text, r"\{\{IPAchar\|(.*?)\}\}", r"\1")
    # lowercase and remove leading/trailing spaces
    text = text.strip()
    # canonicalize interior whitespace
    text = rsub(text, r"\s+", " ")
    # decompose
    text = nfd_form(text)
    text = rsub(text, "y", "u")
    # move accent on first part of diphthong to second part
    text = rsub(text, "([aeiuoAEIOU]" + MBSOPT + ")([" + CIRC + ACUTE + GRAVE +
            "])([ui])(?!" + MBSOPT + DIA + ")", r"\1\3\2")

    return text

def tr_canonicalize_latin(text):
    # Fix cases like hA to read Ha
    text = rsub(text, "h([AEIOU])",
            lambda m: "H" + m.group(1).lower())
    # Compose diacritics
    text = nfc_form(text)
    return text

def post_canonicalize_latin(text):
    # Move macron and breve to beginning after vowel.
    text = rsub(text, "([aeiouAEIOU])(" + LA_ACC_NO_MB + "*)(" +
            MBS + ")", r"\1\3\2")
    # Convert rr to rrh
    text = rsub(text, "rr($|[^h])", r"rrh\1")
    # Convert gk, gg to nk, ng
    text = rsub(text, "g([kg])", r"n\1")
    # recompose accented letters
    text = tr_canonicalize_latin(text)

    text = text.strip()
    return text

# Canonicalize a Latin transliteration and Greek text to standard form.
# Can be done on only Latin or only Greek (with the other one None), but
# is more reliable when both aare provided. This is less reliable than
# tr_matching() and is meant when that fails. Return value is a tuple of
# (CANONLATIN, CANONARABIC).
def canonicalize_latin_greek(latin, greek, msgfun=msg):
    if greek is not None:
        greek = pre_pre_canonicalize_greek(greek)
    if latin is not None:
        latin = pre_canonicalize_latin(latin, greek)
    if greek is not None:
        greek = pre_canonicalize_greek(greek)
        greek = post_canonicalize_greek(greek, msgfun=msgfun)
    if latin is not None:
        # Protect instances of two or more single quotes in a row so they don't
        # get converted to sequences of ʹ characters.
        def quote_subst(m):
            return m.group(0).replace("'", multi_single_quote_subst)
        latin = re.sub(r"''+", quote_subst, latin)
        latin = rsub(latin, ".", tt_canonicalize_latin)
        latin = latin.replace(multi_single_quote_subst, "'")
        latin = post_canonicalize_latin(latin)
    return (latin, greek)

def canonicalize_latin_foreign(latin, greek, msgfun=msg):
    return canonicalize_latin_greek(latin, greek, msgfun=msgfun)

def tr_canonicalize_greek(text):
    # Convert to decomposed form
    text = nfd_form(text)
    # Put rough/smooth breathing before vowel. (We do this with smooth
    # breathing as well to make it easier to add missing smooth breathing
    # in post_canonicalize_greek().)
    # Repeat in case of diphthong, where rough/smooth breathing follows 2nd
    # vowel.

    # Put rough/smooth breathing before diphthong; rough breathing comes first
    # in order with multiple accents, except macron or breve. Second vowel of
    # diphthong must be υ or ι and no following diaeresis. Only do it at
    # beginning of word.
    text = rsub(text, r"(^|[ \[\]|])(" + greek_diphthong_first_vowels + MBSOPT +
            "[υι])(" + RS + ")(?!" + GR_ACC_NO_DIA + "*" + DIA + ")",
            r"\1\3\2")
    # Put rough/smooth breathing before vowel; rough breathing comes first in
    # order with multiple accents, except macron or breve. Only do it at
    # beginning of word.
    text = rsub(text, r"(^|[ \[\]|])(" + greek_vowels + MBSOPT + ")(" +
            RS + ")", r"\1\3\2")
    # Recombine iotated vowels; iotated accent comes last in order.
    # We do this because iotated vowels have special Latin mappings that
    # aren't just sum-of-parts (i.e. with an extra macron in the case of αΑ).
    text = rsub(text, "([αΑηΗωΩ])(" + GR_ACC_NO_IOBE + "*)" + IOBE,
            lambda m:iotate_vowel[m.group(1)] + m.group(2))
    return text

# Early pre-canonicalization of Greek, doing stuff that's safe. We split
# this from pre-canonicalization proper so we can do Latin pre-canonicalization
# between the two steps.
def pre_pre_canonicalize_greek(text):
    # remove L2R, R2L markers
    text = rsub(text, "[\u200E\u200F]", "")
    # remove leading/trailing spaces
    text = text.strip()
    # canonicalize interior whitespace
    text = rsub(text, r"\s+", " ")

    # Do some compatibility transformations since we no longer do the
    # NFKC/NFKD transformations due to them changing Greek 1FBD (koronis) into
    # 0020 SPACE + 0313 COMBINING COMMA ABOVE.
    text = text.replace("\u00B5", "μ")

    text = tr_canonicalize_greek(text)

    return text

def pre_canonicalize_greek(text):
    return text

def post_canonicalize_greek(text, msgfun=msg):
    # Move macron and breve to beginning after vowel.
    text = rsub(text, "(" + greek_vowels + ")(" + GR_ACC_NO_MB + "*)(" +
            MBS + ")", r"\1\3\2")
    # Don't do this; the Greek should already have an iotated vowel.
    # In any case, complications arise with acute accents in the Latin and
    # Greek (should we have pā́i against παί?).
    ## Canonicalize Greek ᾱι to ᾳ. Same for uppercase. But not if ι is followed
    ## by diaeresis. IOBE goes at end of accents.
    #text = rsub(text, "([Αα])" + MAC + "(" + GR_ACC + "*)ι(?!" +
    #        GR_ACC_NO_DIA + "*" + DIA + ")", r"\1\2" + IOBE)
    # Don't do this; it's not always appropriate (e.g. with suffixes);
    # instead issue a warning.
    # If no rough breathing before beginning-of-word vowel, add a smooth
    # breathing sign.
    newtext = rsub(text, "(^|[ \[\]|])(" + greek_vowels + ")",
            r"\1" + SMBR + r"\2")
    if newtext != text:
        msgfun("WARNING: Text %s may be missing a smooth-breathing sign" %
                text)
    # Put rough/smooth breathing after diphthong; rough breathing comes first
    # in order with multiple accents, except macron or breve. Second vowel of
    # diphthong must be υ or ι and no following diaeresis. Only do it at
    # beginning of word.
    text = rsub(text, r"(^|[ \[\]|])(" + RS + ")(" +
            greek_diphthong_first_vowels + MBSOPT + "[υι])(?!" + GR_ACC_NO_DIA
            + "*" + DIA + ")", r"\1\3\2")
    # Put rough/smooth breathing after vowel; rough breathing comes first in
    # order with multiple accents, except macron or breve. Only do it at
    # beginning of word.
    text = rsub(text, r"(^|[ \[\]|])(" + RS + ")(" + greek_vowels +
            MBSOPT + ")", r"\1\3\2")
    # Eliminate breve over short vowel
    text = rsub(text, "([οεΟΕ])" + BREVE, r"\1")
    # Eliminate macron over long vowel
    text = rsub(text, "([ηωΗΩᾳᾼῃῌῳῼ])" + MAC, r"\1")
    # Finally, convert to composed form. Do at very end.
    text = nfc_form(text)
    return text

debug_tr_matching = False

# Vocalize Greek based on transliterated Latin, and canonicalize the
# transliteration based on the Greek.  This works by matching the Latin
# to the Greek and transferring Latin stress marks to the Greek as
# appropriate, so that ambiguities of Latin transliteration can be
# correctly handled. Returns a tuple of Greek, Latin. If unable to match,
# throw an error if ERR, else return None.
def tr_matching(greek, latin, err=False, msgfun=msg):
    origgreek = greek
    origlatin = latin
    def debprint(x):
        if debug_tr_matching:
            print(x)
    greek = pre_pre_canonicalize_greek(greek)
    latin = pre_canonicalize_latin(latin, greek)
    greek = pre_canonicalize_greek(greek)

    gr = [] # exploded Greek characters
    la = [] # exploded Latin characters
    res = [] # result Greek characters
    lres = [] # result Latin characters
    for cp in greek:
        gr.append(cp)
    for cp in latin:
        la.append(cp)
    gind = [0] # index of next Greek character
    glen = len(gr)
    lind = [0] # index of next Latin character
    llen = len(la)

    def is_bow(pos=None):
        if pos is None:
            pos = gind[0]
        return pos == 0 or gr[pos - 1] in [" ", "[", "|", "-"]

    # True if we are at the last character in a word.
    def is_eow(pos=None):
        if pos is None:
            pos = gind[0]
        return pos == glen - 1 or gr[pos + 1] in [" ", "]", "|", "-"]

    def get_matches(delete_blank_matches=False):
        ac = gr[gind[0]]
        debprint("get_matches: ac is %s" % ac)
        bow = is_bow()
        eow = is_eow()

        matches = tt_to_greek_matching.get(ac)
        debprint("get_matches: matches is %s" % matches)
        if matches == None:
            if True:
                error("Encountered non-Greek (?) character " + ac +
                    " at index " + str(gind[0]))
            else:
                matches = [ac]
        if type(matches) is not list:
            matches = [matches]
        if delete_blank_matches:
            # Don't delete blank matches if first match is blank, otherwise
            # we run into problems with ἆθλον vs. āthlon.
            if matches[0]:
                matches = [x for x in matches if x]
                debprint("get_matches: deleted blanks, matches is now %s" % matches)
        return matches

    # attempt to match the current Greek character against the current
    # Latin character(s). If no match, return False; else, increment the
    # Greek and Latin pointers over the matched characters, add the Greek
    # character to the result characters and return True.
    def match():
        # The reason for delete_blank_matches here is to deal with the case
        # of Greek βλάξ vs. Latin blā́ks. We want the Greek acute accent to
        # match nothing so it gets transfered to the Latin, but if we do
        # this naively we get a problem in these two words: the Greek contains
        # an acute accent, while the Latin contains a macron + acute, and
        # so the Greek acute accent matches against nothing in the Latin,
        # then the Latin macron matches against nothing in the Greek
        # through check_unmatching(), then we can't match Greek ξ against
        # Latin acute accent. Instead, disallow matching Greek stuff against
        # nothing if check_unmatching() would trigger. That way we don't
        # match Greek acute against nothing, but instead handle the macron
        # first, then the acute accents match against each other. We can't
        # fix this by simply doing check_unmatching() before match() because
        # then we wouldn't match Greek macron with Latin macron.
        delete_blank_matches = (
                lind[0] < llen and la[lind[0]] in tt_to_greek_unmatching)
        matches = get_matches(delete_blank_matches)

        ac = gr[gind[0]]

        # Check for link of the form [[foo|bar]] and skip over the part
        # up through the vertical bar, copying it
        if ac == '[':
            newpos = gind[0]
            while newpos < glen and gr[newpos] != ']':
                if gr[newpos] == '|':
                    newpos += 1
                    while gind[0] < newpos:
                        res.append(gr[gind[0]])
                        gind[0] += 1
                    return True
                newpos += 1

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
                debprint("cp: %s" % cp)
                if l < llen and la[l] == cp:
                    l = l + 1
                else:
                    matched = False
                    break
            if matched:
                res.append(ac)
                if preserve_latin:
                    for cp in m:
                        lres.append(cp)
                else:
                    subst = matches[0]
                    if type(subst) is list or type(subst) is tuple:
                        subst = subst[0]
                    for cp in subst:
                        lres.append(cp)
                lind[0] = l
                gind[0] = gind[0] + 1
                debprint("matched; lind is %s" % lind[0])
                return True
        return False

    def cant_match():
        if gind[0] < glen and lind[0] < llen:
            error("Unable to match Greek character %s at index %s, Latin character %s at index %s" %
                (gr[gind[0]], gind[0], la[lind[0]], lind[0]))
        elif gind[0] < glen:
            error("Unable to match trailing Greek character %s at index %s" %
                (gr[gind[0]], gind[0]))
        else:
            error("Unable to match trailing Latin character %s at index %s" %
                (la[lind[0]], lind[0]))

    # Check for an unmatched Latin short vowel or similar; if so, insert
    # corresponding Greek diacritic.
    def check_unmatching():
        if not (lind[0] < llen):
            return False
        debprint("Unmatched Latin: %s at %s" % (la[lind[0]], lind[0]))
        unmatched = tt_to_greek_unmatching.get(la[lind[0]])
        if unmatched != None:
            res.append(unmatched)
            lres.append(la[lind[0]])
            lind[0] = lind[0] + 1
            return True
        return False

    def check_unmatching_rh_zd():
        # Check for rh corresponding to ρ, which will occur especially
        # in a sequence ρρ. We can't handle this in tt_to_greek_matching[]
        # because canonical "r" is a subsequence of "rh".
        if not (lind[0] < llen and gind[0] > 0):
            return False
        if la[lind[0]] == "h" and gr[gind[0] - 1] == "ρ":
            lres.append("h")
            lind[0] += 1
            return True
        # Exact same thing here for zd/Zd corresponding to ζ/Ζ.
        if la[lind[0]] == "d" and gr[gind[0] - 1] in ["ζ", "Ζ"]:
            lres.append("d")
            lind[0] += 1
            return True
        return False

    # Here we go through the Greek letter for letter, matching
    # up the consonants we encounter with the corresponding Latin consonants
    # using the dict in tt_to_greek_matching and copying the Greek
    # consonants into a destination array. When we don't match, we check for
    # allowed unmatching Latin characters in tt_to_greek_unmatching, which
    # handles acute accents. If this doesn't match either, and we have
    # left-over Greek or Latin characters, we reject the whole match,
    # either returning False or signaling an error.

    while gind[0] < glen or lind[0] < llen:
        matched = False
        # The effect of the next clause is to handle cases where the
        # Greek has a right bracket or similar character and the Latin has
        # an acute accent that doesn't match and needs to go before
        # the right bracket. The is_bow() check is necessary for reasons
        # described in ar_translit.py, where this check comes from.
        #
        # FIXME: Is this still necessary here? Is there a better way?
        # E.g. splitting the Greek string on occurrences of left/right
        # brackets and handling the remaining occurrences piece-by-piece?
        if (not is_bow() and gind[0] < glen and
                gr[gind[0]] in word_interrupting_chars and
                check_unmatching()):
            debprint("Matched: Clause 1")
            matched = True
        elif gind[0] < glen and match():
            debprint("Matched: Clause match()")
            matched = True
        elif check_unmatching():
            debprint("Matched: Clause check_unmatching()")
            matched = True
        elif check_unmatching_rh_zd():
            debprint("Matched: Clause check_unmatching_rh_zd()")
            matched = True
        if not matched:
            if err:
                cant_match()
            else:
                return False

    greek = "".join(res)
    latin = "".join(lres)
    greek = post_canonicalize_greek(greek, msgfun=msgfun)
    latin = post_canonicalize_latin(latin)
    return greek, latin

def remove_diacritics(text):
    text = rsub(text, "[ᾸᾹᾰᾱῘῙῐῑῨῩῠῡ]",
            {"Ᾰ":"Α", "Ᾱ":"Α", "ᾰ":"α", "ᾱ":"α", "Ῐ":"Ι", "Ῑ":"Ι",
             "ῐ":"ι", "ῑ":"ι", "Ῠ":"Υ", "Ῡ":"Υ", "ῠ":"υ", "ῡ":"υ"})
    text = rsub(text, ONE_MB, "")
    text = nfc_form(text)
    return text

################################ Test code ##########################

num_failed = 0
num_succeeded = 0

def test(latin, greek, should_outcome, expectedgreek=None):
    global num_succeeded, num_failed
    if not expectedgreek:
        expectedgreek = greek
    try:
        result = tr_matching(greek, latin, True)
    except RuntimeError as e:
        print("%s" % e)
        result = False
    if result == False:
        print("tr_matching(%s, %s) = %s" % (greek, latin, result))
        outcome = "failed"
        canongreek = expectedgreek
    else:
        canongreek, canonlatin = result
        trlatin = tr(canongreek)
        print("tr_matching(%s, %s) = %s %s, " % (greek, latin, canongreek, canonlatin), end="")
        if trlatin == canonlatin:
            print("tr() MATCHED")
            outcome = "matched"
        else:
            print("tr() UNMATCHED (= %s)" % trlatin)
            outcome = "unmatched"
    if canongreek != expectedgreek:
        print("Canon Greek FAILED, expected %s got %s"% (
            expectedgreek, canongreek))
    canonlatin, _ = canonicalize_latin_greek(latin, None)
    print("canonicalize_latin(%s) = %s" %
            (latin, canonlatin))
    if outcome == should_outcome and canongreek == expectedgreek:
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
    test("Khristoû", "Χριστοῦ", "matched")
    test("Khrīstoû", "Χριστοῦ", "matched", "Χρῑστοῦ")
    test("Khristoû", "Χρῑστοῦ", "matched")
    test("Khrīstoû", "Χρῑστοῦ", "matched")
    test("hioû", "ἱοῦ", "matched")
    test("huioû", "υἱοῦ", "matched")
    test("huiou", "υἱοῦ", "matched")
    test("huiôu", "υἱοῦ", "matched")
    #test("pāi", "παι", "matched", "πᾳ")
    #test("pā́i", "παί", "matched", "πᾴ")
    #test("pāï", "παϊ", "matched", "πᾱϊ")
    #test("pā́ï", "πάϊ", "matched", "πᾱ́ϊ")
    # Should add smooth breathing
    test("ā̂u", "αῦ", "matched", "ᾱὖ") # FIXME!! Check this

    test("huiôu", "ὑϊοῦ", "matched")

    # Various real tests from the long-vowel warnings
    test("krīnō", "κρίνω", "matched", "κρῑ́νω")
    # Should add smooth breathing
    test("aŋkýlā", "αγκύλα", "matched", "ἀγκύλᾱ")
    test("baptīzō", "βαπτίζω", "matched", "βαπτῑ́ζω")
    test("stūlos", "στῦλος", "matched")
    test("hūlē", "ὕλη", "matched", "ῡ̔́λη")
    test("Hamilkās", "Ἀμίλκας", "failed")
    test("Dānīēl", "Δανιήλ", "matched", "Δᾱνῑήλ")
    test("hēmerā", "ἡμέρα", "matched", "ἡμέρᾱ")
    test("sbénnūmi", "σβέννυμι", "matched", "σβέννῡμι")
    test("Īberniā", "Ἱβερνία", "matched", "Ῑ̔βερνίᾱ")
    # FIXME: Produces Hāídēs. What should it produce?
    test("Hāidēs", "ᾍδης", "matched")
    test("blā́ks", "βλάξ", "matched", "βλᾱ́ξ")
    test("blā́x", "βλάξ", "matched", "βλᾱ́ξ")
    # FIXME: Think about this. We currently transliterate Greek breve with
    # nothing, so the translit of the Greek won't match the Latin.
    test("krūŏn", "κρύον", "unmatched", "κρῡ́ον")
    test("āthlon", "ἆθλον", "matched")
    test("rhādix", "ῥάδιξ", "matched", "ῥᾱ́διξ")
    test("Murrhā", "Μύῤῥα", "matched", "Μύῤῥᾱ")
    # Smooth breathing not at beginning of word; should not be moved
    test("tautologiā", "ταὐτολογία", "matched", "ταὐτολογίᾱ")
    # # Things that should fail
    test("stúlos", "στῦλος", "failed")
    test("stilos", "στῦλος", "failed")

    # Test handling of embedded links, including unmatched macron
    # directly before right bracket on Greek side
    test("pala bolu", "παλα [[βολα|βολυ]]", "matched")
    test("pala bolū", "παλα [[βολα|βολυ]]", "matched", "παλα [[βολα|βολῡ]]")
    test("bolu pala", "[[βολα|βολυ]] παλα", "matched")
    test("bolū pala", "[[βολα|βολυ]] παλα", "matched", "[[βολα|βολῡ]] παλα")
    test("bolupala", "[[βολα|βολυ]]παλα", "matched")
    test("pala bolu", "παλα [[βολυ]]", "matched")
    test("pala bolū", "παλα [[βολυ]]", "matched", "παλα [[βολῡ]]")
    test("bolu pala", "[[βολυ]] παλα", "matched")
    test("bolū pala", "[[βολυ]] παλα", "matched", "[[βολῡ]] παλα")
    test("bolūpala", "[[βολυ]]παλα", "matched", "[[βολῡ]]παλα")

    # # Single quotes in Greek
    test("bolu '''pala'''", "βολυ '''παλα'''", "matched")
    test("bolu '''palā'''", "βολυ '''παλα'''", "matched", "βολυ '''παλᾱ'''")

    # Final results
    print("RESULTS: %s SUCCEEDED, %s FAILED." % (num_succeeded, num_failed))

if __name__ == "__main__":
    run_tests()
