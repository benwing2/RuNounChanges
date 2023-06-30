#!/usr/bin/env python3
# -*- coding: utf-8 -*-

# FIXME:
#
# 1. (NOT DONE, INSTEAD HANDLED IN ADDPRON.PY) Add pronunciation. For nouns
#    and verbs with unstressed -я in the ending (3rd plural verb, dat/ins/pre
#    plural noun), we need to add a dot-under. Otherwise we use the form
#    itself. With multiple etymologies, we need to do more. If there's a
#    combined pronunciation, we need to check if all the forms under all the
#    etymologies are the same. If so, do nothing, else, we need to delete the
#    combined pronunciation and add pronunciations individually to each
#    section. If there are already split pronunciations, we just add a
#    pronunciation to the individual section. It might make sense to do this
#    in addpron.py.
# 2. (DONE) Currently we check to see if the manual translit matches and
#    if not we don't see the inflection as already present. Probably instead
#    we should issue a warning when this happens.
# 2a. (DONE) We need to check if there are multiple forms with the
#    same Cyrillic but different translit, and combine the manual translits.
# 3. (DONE) When grouping participles with nouns/adjectives, don't do it if
#    participle is adverbial.
# 4. (DONE?) Need more special-casing of participles, e.g. head is 'participle',
#    name of POS is "Participle", defn uses 'ru-participle of'. Also for
#    adjectival participles, need to insert the declension, both in new
#    entries and in existing entries missing a declension.
# 5. (DONE) Need to group short adjectives with adverbs (cf. агресси́вно
#    "aggressively" and also "aggressive (short n s)"). When doing this,
#    may need to take into account manual translit (адеква́тно with
#    tr=adɛkvátno, both an adverb and short adjective).
# 6. (NOT DONE, INSTEAD HANDLED IN ADDPRON.PY) When wrapping a single-etymology
#    entry to create multiple etymologies, consider moving the pronunciation
#    to the top above the etymologies.
# 7. (DONE) When a given form value has multiple forms and they are the same
#    except for accents, we should combine them into a single entry with
#    multiple heads, cf. бе́дный with short plural бедны́,бе́дны. Cf. also
#    глубо́кий with short neuter singular глубоко́,глубо́ко, an existing entry
#    with both forms already there (and in addition an adverb глубоко́, put
#    into its own etymology section). Verify that we correctly note the
#    already-existing entry and do nothing. This means we may need to
#    deal with the heads being out of order. (We can use template_head_matches()
#    separately on each head to match, which will also allow us to handle
#    the case where for some reason there are three existing heads and we
#    want to match two; and will allow us to issue a warning when we want to
#    match two heads and can only match one. Example where such a warning
#    should be issued: красно.)
# 8. (DONE) When comparing params, we should allow the param to have a
#    missing accent relative to the expected value (cf.
#    {{inflection of|lang=ru|апатичный|...}} vs. expected value апати́чный).
# 9. (DONE) When comparing params, if we're checking the value of head= or
#    1= and it's missing, we should substitute the pagetitle (e.g. expected
#    short form бе́л, actual template {{head|ru|adjective form}}, similarly
#    with бла́г, which also has a noun form entry).
# 10. (DONE) When creating a POS form (as we usually are), check for a POS
#    entry with the same head and issue a warning if so (e.g. short adj
#    neuter sg бесконе́чно, with an ru-adj entry already present).
# 11. (DONE) Need to group short adjectives with predicatives
#    (head|ru|predicative).
# 12. (DONE) Need to group adjectives with participle forms
#    (head|ru|participle form), cf. используемы.
# 13. (DONE) Handle redirects, e.g. чёрен redirect to чёрный.
# 14. (DONE) Only process inflection templates under the right part of speech,
#    to avoid the issue with преданный, which has one adjectival inflection
#    as an adjective and a different one as a participle.
# 15. (DONE) Also combine dictionary forms with the same Russian but different
#    translit, so скучный works correctly.
# 16. (DONE) When doing future, skip periphrastic future.
# 17. (DONE) Always skip inflections that would go on the lemma page to handle
#     e.g. accusative inanimate masculine and plural, and accusative neuter.
# 18. (DONE) One-syllable noun forms end up accented, but the existing forms
#     might be unaccented. We probably want to (a) de-accent monosyllabic forms,
#     (b) when comparing forms in compare_param(), allow accented monosyllabic
#     to compare to unaccented monosyllabic. This may be important for
#     adjectives and verbs as well.
# 19. (DONE) Warn if existing head or inflection has multiple accents (взя́ло́).
# 20. (DONE) Remove blank params from existing form codes when comparing.
# 21. (DONE) Add support for genders.
# 22. (DONE) Compute and output total time.
# 23. (DONE) Add ability to specify lemmas to process (for short adjs, lemmas
#     will be missing accents and will have е in place of ё).
# 24. (DONE) It might be problematic to update the gender to have -p in it
#     because some of the existing definitions might be singular, particularly
#     in nouns where genitive singular and nominative plural are often the same.
#     This suggests that we should remove -p from the gender (alternatively
#     we'd have to parse all the definitions to see if any are singular).
#     Similar issues exist in adjectives (e.g. -ым dat pl and m/n ins sg);
#     gender issues also exist in adjectives, since e.g. many forms are
#     shared between masculine and neuter. This suggests we shouldn't specify
#     gender at all for adjectives except maybe short forms. (NOTE: Per
#     Anatoli's request we don't include gender for short adjectives either.)
# 25. (DONE) In compare_param(), allow for links in the param, which e.g. may
#     be [[выходить#Etymology 1|выходи́ть]].
# 26. (DONE) Anatoli wants adjective forms to not show gender in the headword,
#     and verb forms to have "gender" (actually aspect) shown in the definition
#     line instead of the headword.
# 27. (DONE) Remove gender from verb headwords.
# 28. (DONE) Don't include head=/1= if same as pagename.
# 29. (DONE) When checking heads against an existing headword template, make
#     sure there aren't extra heads in the existing template, e.g. if the
#     existing template says {{head|ru|noun|head=FOO|head2=BAR}} and the new
#     template has only FOO, don't treat this as a match. Occurs for example in
#     спалить, where the 2nd pl pres ind can be спали́те or спа́лите, which are
#     grouped together, but the 2nd pl imp can only be спали́те. (NOTE: Modified
#     below in #32.)
# 30. (DONE) Add --overwrite-lemmas to correct entries where the conjugation
#     or declension table was originally incorrect and later fixed.
# 31. (DONE) Add --lemmas-no-jo so that lemmas specified using --lemmafile
#     don't have to have е in place of ё, so that we can do only the pages
#     specified using --overwrite-lemmas.
# 32. (DONE) When checking to see if entry (headword and definition) already
#     present, allow extra heads, so e.g. when checking for 2nd pl fut ind
#     спали́те and we find a headword with both спали́те and спа́лите we won't
#     skip it. But when checking for headword without definition to insert a
#     new definition under it, make sure no left-over heads, otherwise we will
#     insert 2nd pl imperative спали́те under the entry with both спали́те and
#     спа́лите, which is incorrect. (спали́те is both fut ind and imper, but
#     спа́лите is only fut ind. Many verbs work this way. The two forms of the
#     fut ind are found under separate conjugation templates so we won't get
#     a single request with both of them.)
# 33. (DONE) For plurale tantum nouns, the e.g. genitive plural inflection
#     should just be "genitive".
# 34. (DONE) When there's an explicit translit, generate the auto translit and
#     see if it's the same; if so, don't include translit. (But we may need to
#     decompose the explicit translit when comparing.) This is because
#     currently, adjectival words end up with explicit translit even though
#     it isn't really needed.
# 35. (DONE) Should allow modifying an existing gender in a way that removes
#     the plurality.
# 36. (DONE) When finding noun gender, the gender derived from the declension
#     table isn't reliable; need to look at the headword.
# 37. (DONE) When finding noun gender, skip indeclinable headword nouns, to
#     avoid issues with proper names like Альцгеймер, which have two headwords,
#     a declined masculine one followed by an indeclinable feminine one, and a
#     masculine inflection table.
# 38. (DONE) When comparing two values, if they differ only in accents and one
#     has more accents than another, issue a warning. Cf. #2508 вице-президента,
#     which has existing {{ru-noun form|ви́це-президе́нта|...}} and
#     {{inflection of|...|ви́це-президе́нт|...}} but new вице-президе́нт(а)
#     without accent on вице-.
# 39. (DONE) Don't issue "No language sections" warning on redirect.
# 40. (DONE) Include purpose of call to template_head_matches() in warnings
#     so we know whether to ignore them.
# 41. (DONE) What to do about кеды, нарты, омеги? They have noun forms for two
#     different nouns (e.g. оме́га and оме́г). This leads to problems with the
#     genders, among other things, as we attempt to insert definitions for
#     noun forms for one noun under the entries for the forms of another noun.
#     We should probably instead ensure that we only insert a new definition
#     under an existing section if there are already forms for the same lemma.
# 42. (DONE) BUG: When handling form черви of червь, which is both animate and
#     inanimate, the code modifies the animacy to be m-in-p twice instead of
#     leaving alone m-an-p, m-in-p. Also, tries to modify value from old
#     value to same thing rather than leaving it alone.
# 43. BUG: Issues warning on being unable to change first existing
#     gender when it is able to change or stay compatible with second existing
#     gender.
# 44. (DONE) Implement ignore_headword_gender to handle редактор, where there
#     are multiple headwords with different genders, and the gender derivable
#     from the declension template is accurate.
# 45. (DONE) BUG: Creates entry as {{ru-noun form|f-in}} instead of
#     {{ru-noun form||f-in}} when param 1 empty (e.g. in genitive plural аб).
# 46. (DONE) If no defn's or defn's wrongly use * instead of #, can't
#     substitute; check for this and issue warning
# 47. (DONE) When adding plural to gender, check that there aren't existing
#     {{inflection of|...}} that are singular.
# 48. (DONE) Issue a warning when there are footnotes attached to a particular
#     form, including the footnote if possible.
# 49. (DONE) Do a bot run to correct cases of 'prep' to be 'pre'. Also
#     reverse things like s|gen to be gen|s.
# 50. (DONE) BUG: лебёдка gives acc_sg_an and acc_sg_in both лебёдку, when
#     should instead give acc_sg лебёдку.
# 51. (DONE) Support locative, partitive, vocative cases for nouns.
# 52. Export the raw versions of adjective forms in [[Module:ru-adjective]]
#     and use them to issue warnings about footnote symbols. (This will apply
#     especially to short adjectives. We've already created them; do another
#     run to get the warnings.)
# 53. (DONE) When creating noun forms, put after any adjective forms with same
#     form and lemma, and when creating adjective forms, put before any nouns
#     forms with same form and lemma.
# 54. (DONE) Warn when we create new etymology that maybe should be placed
#     in same etymology section because of existing noun or noun form where
#     one is plurale tantum and the other is related regular plural.
# 55. (DONE) Implement skip_lemma_pages, skip_form_pages.
# 56. (DONE) Plural forms in -ата/-ята are neuter in the plural even though the
#     singular is masculine.
# 57. (DONE) BUG: Gender cleared after first inflset in loop in create_forms(),
#     but there might be multiple inflsets.
# 58. (DONE) Figure out what to do with #445 обеспе́чение,обеспече́ние where
#     there are two lemmas with different stresses. Probably we should try
#     to split the forms and issue a warning if we can't. If there are two
#     lemmas that differ only in stress, then what we can do is extract the
#     stem (remove [аяеоь] possibly with accent), and assign the each form
#     to one of the stems based on matching the prefix, and if we can't
#     assign this way, assign to both, and if one stem ends up with no form,
#     take the other one's. Alternatively, we could just issue a warning,
#     clean these up manually and add them to the skip lists.
# 59. (DONE) Be smarter about how we insert defns into existing sections. First
#     do a pass where we check just for already-present defns and headwords,
#     then do a pass where we check for sections to insert into where we don't
#     have to modify the gender, then do a pass where we check for sections
#     to insert into where we do modify the gender. This will be important
#     when adding accusatives where inanimate and animate variants exist
#     as separate entries.
# 59a. (DONE) See #59; we actually need four passes, not three, splitting
#     the first pass where we check for already-present defns and headwords
#     in two, first where we're not allowed to add a gender and second where
#     we are.
# 60. (DONE) When splitting forms based on stress variants, handle reduced/
#     dereduced stems.
# 61. (DONE) Fix bug where head2 has translit tr= instead of tr2=.
# 62. (DONE) Handle manual translit when splitting stress variants. Probably
#     can just pretend it's not there.
# 63. (DONE) Allow manually-specified split forms when splitting stress
#     variants.
# 64. (DONE) When stress variants are present, ensure that newly created
#     subsections for different variants end up in the same etymology section.
# 65. (DONE) When both singular and plural inflections are present, there
#     should be two genders, e.g. f-in and f-in-p. However, if there's an
#     existing f-in and only plural inflections, it should be converted to
#     f-in-p. To do this, treat e.g. existing f-in as f-in-s if a singular
#     inflection is present, else as f-in with unspecified plurality. Treat
#     new inflection f-in as f-in-s always, and ensure that the gender is
#     e.g. f-in-p whenever we're dealing with a new plural inflection. Then
#     we can apply the same algorithm used to harmonize m and f, or in and an.
#     But we should modify the "Unable to" warnings to specify the gender
#     class (gender, animacy, plurality) that couldn't be harmonized, so we
#     can check specially for harmonization problems involving true gender
#     and animacy.
# 66. (DONE) Remove в, во, на, в/на from beginning of locatives, and issue
#     warning and don't create locative entries if there's still a space in the
#     locative and no space in the dictionary form (to handle cases where
#     there's something like 'в фобу́/на фобу́').
# 67. (DONE) Implement allow_in_same_etym_section, for pairs where one is a
#     plurale tantum and the other the corresponding singular and so we want
#     the subsections for each to go next to each other rather than in separate
#     etym sections.
# 68. (DONE) Implement allow_defn_in_same_subsection, for closely related
#     lemmas that share some of their forms where we allow definition lines for
#     forms of the two to sit under the same headword.
# 69. (DONE) If there are multiple entries for the same lemma that differ in
#     animacy, we should add the animacy to plurals and to singular masculines.
# 70. (DONE) Warn when lemma or inflections have multiple stresses.
# 71. BUG: Remove accent from monosyllabic transliterations (e.g. forms of
#     бог|tr=box).
# 72. (DONE) Sometimes past passive participles have been borrowed from
#     perfective to imperfective verbs (e.g. делать has сделанный as past
#     passive participle). To deal with this, if the verb is imperfective,
#     and it has one or more perfective verbs listed (that aren't the same
#     verb, as with biaspectual verbs), check for each of the imperfective
#     verb's past passive participles to see whether any of the corresponding
#     perfective verbs have the same word listed as a past passive participle,
#     and if so, ignore the participle on the imperfective verb.
# 73. (DONE) Don't create entries for words beginning with hyphens (e.g. verb
#     forms of the suffix -бавить).
# 74. (DONE) Wrap various places in try_repeatedly() to avoid crashing out
#     with maxlag errors.
# 75. (DONE) Support --lemmas-to-not-overwrite and write "not overwriting"
#     msgs to stderr as well.
# 76. (DONE) Remove accents from single-syllable manual translit, to handle бог
#     (translit box).
# 77. (ALREADY DONE) In "Found plurale tantum lemma" warning, output only if
#     not already found in allow_in_same_etym_section.
# 78. (DONE) When overwriting the page using --overwrite-page, preserve
#     {{also|...}} notes at the top.
# 79. Inserts "inanimate accusative plural" into трёпла of lemma трепло́ even
#     though it's always inanimate, due presumably to hypothetical animate
#     plural elsewhere on the page. Also doesn't note in change message that
#     it's inserting inanimate acc pl rather than just acc pl. Similarly with
#     со́пли pl. of сопля́.
# 80. Inserts "inanimate acc pl" instead of just "acc pl" into кисы́ form of
#     киса́; ки́сы pl of ки́са is animate. Similarly for попа́ gen. of поп "pope"
#     vs по́па gen. of поп "pop (music, art)".
# 81. Inserts "animate acc pl" instead of just "acc pl" into посла́ form of
#     посо́л "ambassador", which is only animate; посо́л with genitive
#     посо́ла "salting" is inanimate.
# 82. (DONE) Don't warn on known singular/plurale tantum cases either in
#     allow_in_same_etym_section or not_in_same_etym_section.
# 83. (DONE) Properly handle participles with multiple translits.
# 84. (DONE) Properly handle ===Alternative forms=== before etymology
#     when moving from one to multiple etymologies.
# 85. (DONE) Handle newlines in template names.
# 86. (DONE EXCEPT один, два AND COMPOUNDS) Support generating inflections for
#     cardinal/collective numerals.
# 87. (DONE) Support один, два, оба and compounds.
# 88. (DONE) Gather warnings and output again if 'would save' or 'saving'.
# 89. (DONE) Handle 'infl of'.
# 90. (DONE) Warn on misplaced semicolon in tag set.
# 91. (DONE) Handle 'head|ru|noun form' by converting to 'ru-noun form'.
# 92. Remove monosyllabic accent from existing lemma in 'inflection of'.
# 93. (DONE) Combine tag sets into multipart tag sets using [[Module:accel]]
#     algorithm.
# 94. (DONE) Canonicalize tags to our preferred variants when combining.
# 95. (DONE) Change saving code to use blib.do_edit() so --diff works.
# 96. (DONE) Use blib.split_trailing_separator_and_categories().
# 97. Standardize using include_pagefile=True.
# 98. Warn if both acc|p and {an,in}|acc|p occur in the same tag set or ideally
#     in the same set of defn lines; same with acc|s and {an,in}|acc|s
# 99. Use {{participle of|ru}} instead of {{ru-participle of}}.

import pywikibot, re, sys, argparse, time
import traceback
import unicodedata

import blib
from blib import getparam, rmparam, tname, pname, msg, errmsg, site
from collections import OrderedDict

import rulib
import infltags

verbose = True

# We prefer the following tag variants (instead of e.g. 'pasv' for passive
# or 'ptcp' for participle).
preferred_tag_variants = {
  "nom", "gen", "dat", "acc", "ins", "pre", "par", "loc", "voc",
  "m", "f", "n",
  "s", "p",
  "in", "an",
  "1", "2", "3",
  "pres", "past", "fut",
  "ind", "imp",
  "act", "pass",
  "short", "adv", "part"
}

tag_to_dimension_table, tag_to_canonical_form_table = (
  infltags.fetch_tag_tables(preferred_tag_variants)
)

AC = "\u0301" # acute accent
GR = "\u0300" # grave accent

# List of nouns where there are multiple headword genders and the gender
# in the declension is acceptable
ignore_headword_gender = [
    "редактор",
]

skip_lemma_pages = [
    "роженица", # 3 stress variants
    "лицо, ищущее убежище", # can't properly handle comma in title
    "витамин B2", # can't handle < in form titles
    "ложное срабатывание", # will be deleted
]

# Skip non-lemma forms if specified here. Format is (FORM, LEMMA) for the
# form and corresponding lemma.
skip_form_pages = [
    ("добытый", "добыть"), # has two variants which need to be split
    ("бабки", "бабка"), # etymologically split, wrongly adds an-acc-pl
    ("посла", "посол"), # wrongly adds an-acc-sg
    ("попа", "поп"), # wrongly adds an-acc-sg
    ("кисы", "киса"), # wrongly adds in-acc-pl
    ("трёпла", "трепло"), # wrongly adds in-acc-pl
    ("чухи", "чуха"), # wrongly adds in-acc-pl
]

# Used to manually assign forms to lemmas when there are stress variants.
# Each entry is (FORMREGEX, LEMMA) where FORMREGEX is a regex with accents
# that should match the form, and LEMMA is the corresponding lemma with
# accents.
manual_split_form_list = [
    ("^аппара́тн.*обеспе́чен", "аппара́тное обеспе́чение"),
    ("^аппара́тн.*обеспече́н", "аппара́тное обеспече́ние"),
    ("^бондар", "бонда́рь"),
    ("^грабар", "граба́рь"),
    ("^договор", "до́говор"),
    ("^йо́ркширск.*терье́р", "йо́ркширский терье́р"),
    ("^йоркши́рск.*терье́р", "йоркши́рский терье́р"),
    ("^кожух", "кожу́х"),
    ("^козы́рн.*ка́рт", "козы́рная ка́рта"),
    ("^козырн.*ка́рт", "козырна́я ка́рта"),
    ("^колок", "коло́к"),
    ("^ко́мплекс.*чис", "ко́мплексное число́"),
    ("^компле́кс.*чис", "компле́ксное число́"),
    ("^лемех", "леме́х"),
    ("^морск.*у́ш", "морско́е у́шко"),
    ("^морск.*уш", "морско́е ушко́"),
    ("^не́топыр", "не́топырь"),
    ("^нетопыр", "нетопы́рь"),
    ("^обух", "обу́х"),
    ("^пехтер", "пехте́рь"),
    # split algorithm doesn't currently handle adjectives correctly
    ("^Пика́ссо прямоуго́льчат", "Пика́ссо прямоуго́льчатый"),
    ("^Пикассо́ прямоуго́льчат", "Пикассо́ прямоуго́льчатый"),
    # combined entry with при́вод type c(1) and приво́д type a.
    ("^привод", "при́вод"),
    ("^програ́ммн.*обеспе́чен", "програ́ммное обеспе́чение"),
    ("^програ́ммн.*обеспече́н", "програ́ммное обеспече́ние"),
    ("^пу́рпур", "пу́рпурный"),
    ("^пурпу́р", "пурпу́рный"),
    ("^пяден", "пя́день"),
    # FIXME, following three don't work because of the three-way split
    ("^рожени́ц", "рожени́ца"),
    ("^роже́ниц", "роже́ница"),
    ("^ро́жениц", "ро́женица"),
    ("^рыбар", "рыба́рь"),
    ("^сажен", "са́жень"),
    ("^творог", "творо́г"),
    ("^тео́ри.*ха́оса", "тео́рия ха́оса"),
    ("^тео́ри.*хао́са", "тео́рия хао́са"),
    ("^украи́нск", "украи́нский"),
    ("^укра́инск", "укра́инский"),
    # verbs; need to split every one since we don't yet have automatic
    # handling of them
    ("^гази́р", "гази́ровать"),
    ("^газир", "газирова́ть"),
    ("^вкли́н.*с[ья]$", "вкли́ниться"),
    ("^вклин.*с[ья]$", "вклини́ться"),
    ("^вкли́н", "вкли́нить"),
    ("^вклин", "вклини́ть"),
    ("^закли́н", "закли́нить"),
    ("^заклин", "заклини́ть"),
    ("^запы́ха", "запы́хаться"),
    ("^запыха́", "запыха́ться"),
    ("^зареше[тч]", "зарешети́ть"),
    ("^зареше́[тч]", "зареше́тить"),
    ("^заржа́ве", "заржа́веть"),
    ("^заржаве́", "заржаве́ть"),
    ("^и́скр", "и́скриться"),
    ("^искр", "искри́ться"),
    ("^норми́р", "норми́ровать"),
    ("^нормир", "нормирова́ть"),
    ("^обрам", "обрами́ть"),
    ("^обра́м", "обра́мить"),
    ("^опорожн", "опорожни́ть"),
    ("^опоро́жн", "опоро́жнить"),
    ("^преуме́ньш", "преуме́ньшить"),
    ("^преуменьш", "преуменьши́ть"),
    ("^прину́[жд]", "прину́дить"),
    ("^прину[жд]", "принуди́ть"),
    ("^пузы́р", "пузы́риться"),
    ("^пузыр", "пузыри́ться"),
    ("^ржа́ве", "ржа́веть"),
    ("^ржаве́", "ржаве́ть"),
    ("^са́дн", "са́днить"),
    ("^садн", "садни́ть"),
    ("^сгру́[жд]", "сгру́диться"),
    ("^сгру[жд]", "сгруди́ться"),
    ("^уме́ньш.*с[ья]$", "уме́ньшиться"),
    ("^уменьш.*с[ья]$", "уменьши́ться"),
    ("^уме́ньш", "уме́ньшить"),
    ("^уменьш", "уменьши́ть"),
    ("^предвосхи́", "предвосхи́тить"),
    ("^предвосхи", "предвосхити́ть"),
    ("^ю́ркн", "ю́ркнуть"),
    ("^юркн", "юркну́ть"),
]

# These represent pairs of lemmas, typically where the first one is a plurale
# tantum and the second one the corresponding singular. When creating forms
# of one of these words and checking for existing noun form subsections to
# insert next to, if the headword forms match and a definition is found that
# matches the other lemma of the pair, we treat the whole subsection as a match
# and insert the new subsection after it, rather than creating a new
# etymology section. We do similarly for noun lemmas, so that if we're creating
# a form of the second one and we find a lemma matching the first one that's
# plural, insert the subsection after the lemma rather than creating a new
# etymology section.
allow_in_same_etym_section = [
    ("авиалинии", "авиалиния"),
    ("агулы", "агул"),
    ("азы", "аз"),
    # the following is complicated because there are two амур etymologies,
    # one of which is shared with амуры.
    ("амуры", "амур"),
    ("антресоли", "антресоль"),
    ("бакенбарды", "бакенбарда"),
    ("бега", "бег"),
    ("боеприпасы", "боеприпас"),
    ("бразды", "бразда"),
    ("брусья", "брус"),
    ("брюхоногие", "брюхоногий"),
    ("бубны", "бубна"),
    ("внучата", "внук"),
    ("внутренности", "внутренность"),
    ("вожжи", "вожжа"),
    ("войска", "войско"),
    ("волосы", "волос"),
    ("выборы", "выбор"),
    ("выходные", "выходной"),
    ("гонки", "гонка"),
    ("горелки", "горелка"), # at least partly related
    ("деньги", "деньга"),
    ("домашние", "домашний"),
    ("доспехи", "доспех"),
    ("жабры", "жабра"),
    ("заморозки", "зоморозок"),
    ("запчасти", "запчасть"),
    ("кавычки", "кавычка"),
    ("кадры", "кадр"),
    ("капли", "капля"),
    ("карты", "карта"),
    ("коньки", "конёк"),
    ("коронавирусы", "коронавирус"),
    ("кости", "кость"),
    ("кракозябры", "кракозябра"),
    ("курсы", "курс"),
    ("ладоши", "ладоша"),
    ("леса", "лес"),
    ("литавры", "литавра"),
    ("люди", "человек"),
    ("лыжи", "лыжа"),
    ("мозги", "мозг"),
    ("морепродукты", "морепродукт"),
    ("мостки", "мосток"),
    ("мурашки", "мурашка"),
    ("нарты", "нарта"),
    ("наручники", "наручник"),
    ("наушники", "наушник"),
    ("небеса", "небо"),
    ("нечистоты", "нечистота"),
    ("новости", "новость"),
    ("ноты", "нота"),
    ("окрестности", "окрестность"),
    ("окружающие", "окружающее"),
    ("осадки", "осадок"),
    ("опилки", "опилка"),
    ("отбросы", "отброс"),
    ("отговоры", "отговор"),
    ("падонки", "падонак"),
    ("пики", "пика"),
    ("подтяжки", "подтяжка"),
    ("позывные", "позывной"),
    ("покои", "покой"),
    ("полдни", "полдень"),
    ("почести", "почесть"),
    ("правнучата", "правнук"),
    ("права", "право"),
    ("припасы", "припас"),
    ("реалии", "реалия"),
    ("ребята", "ребёнок"),
    ("роды", "род"),
    ("секундочку", "секундочка"),
    ("сиги", "сиг"),
    ("сласти", "сласть"),
    ("слухи", "слух"),
    ("слюнки", "слюнка"),
    ("слюни", "слюна"),
    ("сопли", "сопля"),
    ("соты", "сота"),
    # FIXME! This should be split into стих "verse" (goes with стихи),
    # стих "mood" (does not go)
    ("стихи", "стих"),
    ("тапочки", "тапочка"),
    ("трефы", "трефа"),
    ("усы", "ус"),
    ("французы", "француз"),
    ("цимбалы", "цимбал"),
    ("часы", "час"),
    ("червы", "черва"),
    ("шашки", "шашка"),
    ("шлёпанцы", "шлёпанец"),
    ("энергоресурсы", "энергоресурс"),
    ("японцы", "японец"),
    ("яства", "яство"),
]

# These represent pairs of lemmas, typically where the first one is a plurale
# tantum and the second one is an unrelated singular with overlapping forms.
# This is the opposite of allow_in_same_etym_section and is used to avoid
# warnings about these pairs.
not_in_same_etym_section = [
    ("асы", "ас"),
    ("бабки", "бабка"),
    ("бачки", "бачок"),
    ("вьетнамки", "вьетнамка"),
    ("городки", "городок"),
    ("денежки", "денежка"),
    ("духи", "дух"),
    ("дыбы", "дыба"),
    ("кеды", "кед"),
    ("клещи", "клещ"),
    ("козлы", "козёл"),
    ("ладушки", "ладушка"),
    ("латы", "лат"),
    ("нары", "нар"),
    ("нарды", "нард"),
    ("отходы", "отход"),
    ("очки", "очко"),
    ("плавки", "плавка"),
    ("плечики", "плечико"),
    ("сланцы", "сланец"),
    ("трусы", "трус"),
    ("цыпочки", "цыпочка"),
    ("чари", "чара"),
    ("черви", "червь"),
]

# List of lemmas where we allow stress mismatches to go into the same etym
# section.
allow_stress_mismatch_list = [
    "щавель"
]

# These represent pairs of lemmas where we allow definition lines from the
# two to go under the same headword; this only happens for closely related
# alternative forms (often, where one has an epenthetic vowel in the
# nominative singular and the other doesn't; by convention, we list the one
# with the epenthetic vowel first).
allow_defn_in_same_subsection = [
    ("басня", "баснь"),
    ("бобёр", "бобр"),
    ("ветер", "ветр"),
    ("водоросель", "водоросль"),
    ("воспитание", "воспитанье"),
    ("вылезти", "вылезть"),
    ("деревцо", "деревце"),
    ("дыхание", "дыханье"),
    ("дитя", "ребёнок"), # special-case with same plural
    ("жалование", "жалованье"),
    ("жарение", "жаренье"),
    ("купание", "купанье"),
    ("либеральничание", "либеральничанье"),
    # three-way equivalence of мать, мати, матерь; need to list all pairs
    ("мать", "мати"),
    ("матерь", "мати"),
    ("мать", "матерь"),
    ("мнение", "мненье"),
    ("нуль", "ноль"),
    ("обличие", "обличье"),
    ("ожидание", "ожиданье"),
    ("огонь", "огнь"),
    ("остыть", "остынуть"),
    ("пение", "пенье"),
    ("плавание", "плаванье"),
    ("подножие", "подножье"),
    ("пол-литра", "поллитра"),
    ("простыть", "простынуть"),
    ("прощение", "прощенье"),
    ("рождение", "рожденье"),
    ("свёкор", "свёкр"),
    ("свёкла", "свекла"),
    ("служение", "служенье"),
    ("собрание", "собранье"),
    ("соление", "соленье"),
    ("сражение", "сраженье"),
    ("судия", "судья"),
    ("уединение", "уединенье"),
    ("уголь", "угль"),
    ("умиление", "умиленье"),
    ("учение", "ученье"),
    ("хотение", "хотенье"),
    ("чёрт", "чорт"),
    # -стигнуть vs. -стичь
    ("достигнуть", "достичь"),
    ("застигнуть", "застичь"),
    ("настигнуть", "настичь"),
    ("постигнуть", "постичь"),
    # Type 4a1a vs. type 1a: мерить
    ("измерить", "измерять"),
    ("измериться", "измеряться"),
    ("мерить", "мерять"),
    ("обмерить", "обмерять"),
    ("отмерить", "отмерять"),
    ("примерить", "примерять"),
    ("примериться", "примеряться"),
    ("размерить", "размерять"),
    ("смерить", "смерять"),
    # Type 4a1a vs. type 1a: мучить
    ("замучить", "замучать"),
    ("замучиться", "замучаться"),
    ("измучить", "измучать"),
    ("измучиться", "измучаться"),
    ("мучить", "мучать"),
    ("мучиться", "мучаться"),
]

def check_re_sub(warnfun, action, refrom, reto, text, numsub=1, flags=0):
  newtext = re.sub(refrom, reto, text, numsub, flags)
  if newtext == text:
    warnfun("When %s, no substitution occurred" % action)
  return newtext

def issue_warning(warning, pagemsg, warnings):
  warnings.append(warning)
  pagemsg("WARNING: %s" % warning)

# Make sure there is one trailing newline
def ensure_one_trailing_nl(text):
  return re.sub(r"\n*$", r"\n\n", text)

# Make sure there are two trailing newlines
def ensure_two_trailing_nl(text):
  return re.sub(r"\n*$", r"\n\n", text)

# Given a list of strings, construct a regexp that matches any of them.
def construct_alternant_re(items):
  return "(?:%s)" % "|".join(re.escape(item) for item in items)

# Compare two values but first normalize them to composed form.
# This is important when comparing translits because translit taken directly
# from wikicode will be composed, whereas translit generated by expanding
# the {{xlit|ru|...}} template will be decomposed.
def compare_normalized(x, y):
  return unicodedata.normalize("NFC", x) == unicodedata.normalize("NFC", y)

# Return a tuple (RU, TR) with TR set to a blank string if it's redundant.
# If TR is already blank on entry, it is just returned.
def check_for_redundant_translit(ru, tr, pagemsg, warnfun, expand_text):
  if not tr:
    return ru, tr
  autotr = expand_text("{{xlit|ru|%s}}" % ru)
  if not autotr:
    warnfun("Error generating translit for %s" % ru)
    return ru, tr
  if compare_normalized(autotr, tr):
    pagemsg("Removing redundant translit %s from Russian %s" % (tr, ru))
    return ru, ""
  pagemsg("Keeping non-redundant translit %s != auto %s for Russian %s" % (
    tr, autotr, ru))
  return ru, tr

# Return True if LEMMA (in the form RUSSIAN or RUSSIAN/TRANSLIT) matches the
# specified Cyrillic term RU, with possible manual transliteration TR
# (may be empty). Issue a warning if Cyrillic matches but not translit.
# FIXME: If either the lemma specifies manual translit or TR is given,
# we should consider transliterating the other one in case of redundant
# manual translit.
def lemma_matches(lemma, ru, tr, warnfun, expand_text):
  if "//" in lemma:
    lemru, lemtr = re.split("//", lemma, 1)
  else:
    lemru, lemtr = lemma, ""
  if ru == lemru:
    # If one of the two has manual translit but the other doesn't, generate
    # translit for the one without it in case of redundant manual translit
    if tr and not lemtr:
      lemtr = expand_text("{{xlit|ru|%s}}" % lemru)
      if not lemtr:
        warnfun("Error generating translit for %s" % lemru)
        return False
    elif lemtr and not tr:
      tr = expand_text("{{xlit|ru|%s}}" % ru)
      if not tr:
        warnfun("Error generating translit for %s" % ru)
        return False
    trmatches = not tr and not lemtr or compare_normalized(tr, lemtr)
    if not trmatches:
      warnfun("Value %s matches lemma %s of ru-(proper )noun+, but translit %s doesn't match %s" % (
        ru, lemru, tr, lemtr))
    else:
      return True
  return False

pages_already_erased = set()

# Create or insert a section describing a given inflection of a given lemma.
# INFLECTIONS is the list of tuples of (INFL, INFLTR), i.e. accented
# inflectional form (e.g. the plural, feminine, verbal noun, participle,
# etc.) and associated manual transliteration (or None); LEMMA is the
# accented lemma (e.g. the singular, masculine or dictionary form of a
# verb); and LEMMATR is the associated manual transliterations (if any).
# POS is the part of speech of the word (capitalized, e.g. "Noun"). Only
# save the changed page if SAVE is true. INDEX is the numeric index of
# the lemma page, for ID purposes and to aid restarting. INFLTYPE is e.g.
# "adj form nom_m", and is used in messages; both POS and INFLTYPE are
# used in special-case code that is appropriate to only certain inflectional
# types. LEMMATYPE is e.g. "infinitive" or "masculine singular" and is
# used in messages.
#
# HEADTEMP is the headword template for the inflected-word entry (e.g.
# "head|ru|verb form" or "ru-noun form"; we special-case "head|" headword
# templates). HEADTEMP_PARAM is a parameter or parameters to add to the
# created HEADTEMP template, and should be either empty or of the form
# "|foo=bar" (or e.g. "|foo=bar|baz=bat" for more than one parameter).
#
# DEFTEMP is the definitional template that points to the base form (e.g.
# "inflection of" or "participle of"). DEFTEMP can be a list of such
# templates (e.g. ["inflection of", "infl of"]), which will all be
# recognized; the first list item will be used when generating new entries.
# DEFTEMP_PARAM is a parameter or parameters to add to the created DEFTEMP
# template, similar to HEADTEMP_PARAM; or it should be a list of inflection
# codes (e.g. ['2', 's', 'pres', 'ind']). DEFTEMP_NEEDS_LANG indicates
# whether the definition template specified by DEFTEMP needs to have a
# 'lang'/'1' parameter with value 'ru'. DEFTEMP_ALLOWS_MULTIPLE_TAG_SETS
# indicates whether multiple tag sets can be inserted into the definitional
# template (True for {{infl of}} and {{participle of}}).
#
# GENDER should be a list of genders to use in adding or updating gender
# (assumed to be parameter g= in HEADTEMP if it's a "head|" headword template,
# else parameter 2=, and g2=, g3= for additional genders). If no genders
# are relevant, supply an empty list. (NOTE: This is special-cased for verbs,
# and inserts the "gender" [actually the aspect, perfective/imperfective]
# into the definition line.)
#
# If ENTRYTEXT is given, this is the text to use for the entry, starting
# directly after the "==Etymology==" line, which is assumed to be necessary.
# If not given, this text is synthesized from the other parameters.
#
# IS_LEMMA_TEMPLATE is a function that is passed one argument, a template,
# and should indicate if it's a lemma template (e.g. 'ru-adj' for adjectives).
# This is used to issue warnings in case of non-lemma forms where there's
# a corresponding lemma (NOTE, this situation could be legitimate for nouns).
#
# LEMMAS_TO_OVERWRITE is a list of lemma pages the forms of which to overwrite
# the inflection codes of when an existing definition template (e.g.
# "inflection of") is found with matching lemma. Entries are without accents.
#
# LEMMAS_TO_NOT_OVERWRITE is a list of lemma pages, which should in general
# be the entire set of lemmas. Any non-lemma form that would overwrite the
# Russian section will not do so if the form is one of these pages.
# Entries are without accents.
#
# ALLOW_STRESS_MISMATCH_IN_DEFN is used when dealing with stress variants to
# allow for stress mismatch when inserting a new subsection next to an
# existing one, instead of creating a new etymology section.
#
# PAST_F_END_STRESSED is used for determining the short-form type when
# generating the declension of an adjectival participle (specifically, if
# the past_f is end-stressed, participles in -тый have short-form type c,
# and participles in -анный/-янный/-енный have short-form type c as a
# dated alternant).
def create_inflection_entry(program_args, save, index, inflections, lemma,
    lemmatr, pos, infltype, lemmatype, headtemp, headtemp_param, deftemp,
    deftemp_param, gender, deftemp_allows_multiple_tag_sets=True,
    deftemp_needs_lang=True, entrytext=None, is_lemma_template=None,
    lemmas_to_overwrite=[], lemmas_to_not_overwrite=[],
    allow_stress_mismatch_in_defn=False, past_f_end_stressed=False):

  warnings = []

  # Remove any links that may esp. appear in the lemma, since the
  # accented version of the lemma as it appears in the lemma's headword
  # template often has links in it when the form is multiword.
  lemma = blib.remove_links(lemma)
  inflections = [(blib.remove_links(infl), infltr) for infl, infltr in inflections]

  joined_infls = ",".join(infl for infl, infltr in inflections)
  # Make this a function because it's needed in pagemsg(), but we may change
  # INFLTR down below (code is below because it needs pagemsg() to run).
  def joined_infls_with_tr():
    return ",".join("%s (%s)" % (infl, infltr) if infltr else "%s" % infl for infl, infltr in inflections)

  # Fetch pagename, create pagemsg() fn to output msg with page name included
  pagenames = set(rulib.remove_accents(infl) for infl, infltr in inflections)
  # If multiple inflections, they should have the same pagename minus accents
  assert len(pagenames) == 1
  pagename = list(pagenames)[0]

  def format_pagemsg_text(text, simple=False):
    if simple:
      return text
    else:
      return "%s: %s %s, %s %s%s" % (text, infltype, joined_infls_with_tr(),
          lemmatype, lemma, " (%s)" % lemmatr if lemmatr else "")
  def pagemsg(text, simple=False, fun=msg):
    fun("Page %s %s: %s" % (index, pagename, format_pagemsg_text(text, simple)))
  def pagemsg_if(doit, text, simple=False):
    if doit:
      pagemsg(text, simple=simple)
  def errpagemsg(txt):
    pagemsg(txt)
    pagemsg(txt, fun=errmsg)
  def expand_text(tempcall):
    return blib.expand_text(tempcall, pagename, pagemsg, verbose)
  def warn(warning, simple=False, err=False):
    text = format_pagemsg_text(warning, simple)
    issue_warning(text, errpagemsg if err else pagemsg, warnings)
  def warn_if(doit, warning, simple=False, err=False):
    if doit:
      warn(warning, simple=simple, err=err)

  for (skip_form, skip_lemma) in skip_form_pages:
    if skip_form == pagename and skip_lemma == rulib.remove_accents(lemma):
      warn("Skipping form because in skip_form_pages for lemma %s" % skip_lemma)
      return warnings

  # Remove any redundant manual translit
  lemma, lemmatr = check_for_redundant_translit(lemma, lemmatr, pagemsg, warn, expand_text)
  inflections = [check_for_redundant_translit(infl, infltr, pagemsg, warn, expand_text) for infl, infltr in inflections]

  is_participle = "_part" in infltype
  is_adverbial_participle = "adv_part" in infltype
  is_adjectival_participle = is_participle and not is_adverbial_participle
  is_adj_form = "adjective form" in infltype
  is_noun_form = "noun form" in infltype
  is_verb_form = "verb form" in infltype
  is_short_adj_form = "adjective form short" in infltype
  is_noun_or_adj = "noun" in infltype or "adjective" in infltype
  is_noun_adj_plural = is_noun_or_adj and ("_p" in infltype or "_mp" in infltype)
  generic_infltype = ("participle" if is_participle else
      re.sub(" form.*", " form", infltype) if " form" in infltype else infltype)

  if type(deftemp) is not list:
    deftemp = [deftemp]
  headtemp_is_head = headtemp.startswith("head|")
  first_gender_param = "g" if headtemp_is_head else "2"

  for infl, infltr in inflections:
    if infl == "-":
      pagemsg("Not creating %s entry - for %s %s%s" % (
        infltype, lemmatype, lemma, " (%s)" % lemmatr if lemmatr else ""))
      return warnings

  # Prepare to create page
  pagemsg("Creating entry")
  page = pywikibot.Page(site, pagename)

  # Warn on multi-stressed words
  if rulib.is_multi_stressed(lemma):
    warn("Lemma %s has multiple accents" % lemma)
  for infl, infltr in inflections:
    if rulib.is_multi_stressed(infl):
      warn("Inflection %s has multiple accents" % infl)

  # Check whether parameter PARAM of template T matches VALUE.
  def compare_param(t, param, value, valuetr, param_is_head,
      issue_warnings=True, allow_stress_mismatch=False):
    value = rulib.remove_monosyllabic_accents(value)
    valuetr = rulib.remove_tr_monosyllabic_accents(valuetr)
    paramval = rulib.remove_monosyllabic_accents(blib.remove_links(getparam(t, param)))
    if rulib.is_multi_stressed(paramval):
      warn_if(issue_warnings, "Param %s=%s has multiple accents: %s" % (
        param, paramval, str(t)))
    if rulib.is_multi_stressed(value):
      warn_if(issue_warnings, "Value %s to compare to param %s=%s has multiple accents" % (
        value, param, paramval))
    # If checking the lemma param, substitute page name if missing.
    if not paramval and param_is_head and param in ["1", "2", "head"]:
      paramval = pagename
    # Allow cases where the parameter says e.g. апатичный (missing an accent)
    # and the value compared to is e.g. апати́чный (with an accent).
    if rulib.is_unaccented(paramval) and rulib.remove_accents(value) == paramval:
      matches = True
    # Allow cases that differ only in grave accents (typically if one of the
    # values has a grave accent and the other doesn't).
    elif re.sub(GR, "", paramval) == re.sub(GR, "", value):
      matches = True
    elif allow_stress_mismatch:
      matches = rulib.remove_accents(paramval) == rulib.remove_accents(value)
    else:
      matches = paramval == value
    if rulib.remove_accents(value) == rulib.remove_accents(paramval):
      valueaccents = rulib.number_of_accents(value)
      paramvalaccents = rulib.number_of_accents(paramval)
      if valueaccents != paramvalaccents:
        warn_if(issue_warnings, "Value %s (%s accents) matches param %s=%s (%s accents) except for accents, and different numbers of accents: %s" % (
          value, valueaccents, param, paramval, paramvalaccents,
          str(t)))
    # Now, if there's a match, check the translit
    if matches:
      if param_is_head and param in ["1", "2", "head"]:
        trparam = "tr"
      elif param.startswith("head"):
        trparam = re.sub("^head", "tr", param)
      else:
        assert not valuetr, "Translit cannot be specified with a non-head parameter"
        return True
      trparamval = rulib.remove_tr_monosyllabic_accents(getparam(t, trparam))
      if not valuetr and not trparamval:
        return True
      if (allow_stress_mismatch and valuetr and trparamval and
          rulib.remove_tr_accents(valuetr) ==
          rulib.remove_tr_accents(trparamval)):
        return True
      if valuetr == trparamval:
        return True
      warn_if(issue_warnings, "Value %s matches param %s=%s, but translit %s doesn't match param %s=%s: %s" % (
        value, param, paramval, valuetr, trparam, trparamval, str(t)))
      return False
    return False

  # True if the heads in the template match all the inflections in INFLECTIONS,
  # a list of (FORM, FORMTR) tuples. Warn if some but not all match, and
  # warn if all match but some heads are left over. Knows how to deal with
  # ru-noun+ and ru-proper noun+.
  def template_head_matches(t, inflections, purpose, fail_when_left_over_heads=False, issue_warnings=True):
    some_match = False
    all_match = True
    left_over_heads = False

    if tname(t) in ["ru-noun+", "ru-proper noun+"]:
      lemmaarg = rulib.fetch_noun_lemma(t, expand_text)
      if lemmaarg is None:
        warn_if(issue_warnings, "Error generating noun forms when %s" % purpose)
        return False
      else:
        lemmas = set(re.split(",", lemmaarg))
        # Check to see whether all inflections match, and remove head params
        # that have matched so we can check if any are left over
        for infl, infltr in inflections:
          for lem in lemmas:
            if lemma_matches(lem, infl, infltr,
                lambda x:warn_if(issue_warnings, x),
                expand_text):
              some_match = True
              lemmas.remove(lem)
              break
          else:
            all_match = False
        left_over_heads = lemmas
    else:
      # Get list of head params
      headparams = set()
      headparams.add("head" if tname(t) == "head" else "1")
      i = 1
      while True:
        i += 1
        param = "head" + str(i)
        if not getparam(t, param):
          break
        headparams.add(param)

      # Check to see whether all inflections match, and remove head params
      # that have matched so we can check if any are left over
      for infl, infltr in inflections:
        for param in headparams:
          if compare_param(t, param, infl, infltr, param_is_head=True,
              issue_warnings=issue_warnings):
            some_match = True
            headparams.remove(param)
            break
        else:
          all_match = False
      left_over_heads = headparams

    if some_match and not all_match:
      warn_if(issue_warnings, "Some but not all inflections %s match template when %s: %s" %
          (joined_infls_with_tr(), purpose, str(t)))
    elif all_match and left_over_heads:
      if fail_when_left_over_heads:
        warn_if(issue_warnings, "All inflections %s match template, but extra heads in template when %s, treating as a non-match: %s" %
            (joined_infls_with_tr(), purpose, str(t)))
        return False
      else:
        warn_if(issue_warnings, "All inflections %s match template, but extra heads in template when %s: %s" %
            (joined_infls_with_tr(), purpose, str(t)))
    return all_match

  # Prepare parts of new entry to insert
  if entrytext:
    entrytextl4 = re.sub("^==(.*?)==$", r"===\1===", entrytext, 0, re.M)
    newsection = "==Russian==\n\n===Etymology===\n" + entrytext
  else:
    # Synthesize new entry. Some of the parts here besides 'entrytext',
    # 'entrytextl4' and 'newsection' are used down below when creating
    # verb parts and participles; these parts don't exist when 'entrytext'
    # was passed in, but that isn't a problem because it isn't passed in
    # when creating verb parts or participles.

    # 1. Get the head=/1= and head2=,head3= etc. headword params.
    headparams = []
    headno = 0
    no_param1 = False
    if len(inflections) == 1 and inflections[0][0] == pagename and not inflections[0][1]:
      # Don't add head=/1= params if there's only one inflection that's the
      # same as the pagename and there's no translit. But if we add gender
      # below, we may need to add a blank param 1 before it.
      no_param1 = True
      pass
    else:
      for infl, infltr in inflections:
        headno += 1
        if headno == 1:
          headparams.append("|%s%s%s" % ("head=" if headtemp_is_head else "",
            infl, "|tr=%s" % infltr if infltr else ""))
        else:
          headparams.append("|head%s=%s%s" % (headno, infl,
            "|tr%s=%s" % (headno, infltr) if infltr else ""))

    # 2. Get the g=/2= and g2=,g3= etc. headword params.
    genderparams = []
    genderno = 0
    for g in gender:
      genderno += 1
      if genderno == 1:
        genderparams.append("|g=%s" % g if headtemp_is_head else
            "||%s" % g if no_param1 else "|%s" % g)
      else:
        genderparams.append("|g%s=%s" % (genderno, g))

    # 3. Synthesize headword template.
    new_headword_template = "{{%s%s%s%s}}" % (headtemp, "".join(headparams),
        "".join(genderparams), headtemp_param)

    # 4. Synthesize definition template.
    new_defn_template = "{{%s%s|%s%s%s}}" % (
      deftemp[0], "|ru" if deftemp_needs_lang else "",
      lemma, "|tr=%s" % lemmatr if lemmatr else "",
      deftemp_param if isinstance(deftemp_param, str) else "||" + "|".join(deftemp_param))

    # 5. Synthesize declension template if needed.
    if is_adjectival_participle:
      new_decl_template_parts = []
      part_short_decls = []
      for infl, infltr in inflections:
        part_short_decl = (
          ("a(2),dated-c(2)" if past_f_end_stressed else "a(2)") if re.search("(е|а́|а|я́|я)нный$", infl) else
          "b(2)" if infl.endswith("ённый") else
          "c" if infl.endswith("тый") and past_f_end_stressed else
          "a" if re.search("[мт]ый$", infl) else "-")
        part_short_decls.append(part_short_decl)

      # Combine inflection and its translit the way that it's expected in
      # {{ru-decl-adj}}. In particular, we need to have cases like
      # infl=аннекси́рующий, infltr=annɛksírujuščij, anneksírujuščij, which
      # needs to be converted to аннекси́рующий//annɛksírujuščij,аннекси́рующий.
      def combine_adj_infl_and_tr(infl, infltr):
        decls = []
        for onetr in re.split(", *", infltr or ""):
          ru, tr = check_for_redundant_translit(infl, onetr, pagemsg, warn, expand_text)
          if tr:
            decls += ["%s//%s" % (ru, tr)]
          else:
            decls += [ru]
        return ",".join(decls)

      # If all inflection variants have the same short declension class,
      # we can combine into a single ru-decl-adj call; else we need to
      # generate more than one. FIXME: In the latter case, we should maybe
      # generate two POS sections.
      if len(set(part_short_decls)) == 1:
        if len(part_short_decls) > 1:
          pagemsg("Combining multiple inflections %s into single ru-decl-adj" %
              joined_infls_with_tr())
        param1 = ",".join(combine_adj_infl_and_tr(infl, infltr)
          for infl, infltr in inflections)
        new_decl_template_parts.append("{{ru-decl-adj|%s|%s}}\n" % (param1, part_short_decls[0]))
      else:
        if len(part_short_decls) > 1:
          warn("Unable to combine multiple inflections %s into single ru-decl-adj because of differing short decls %s" %
              joined_infls_with_tr(), " ".join(part_short_decls))
        for part_short_decl, (infl, infltr) in zip(part_short_decl, inflections):
          new_decl_template_parts.append("{{ru-decl-adj|%s|%s}}\n" % (
            combine_adj_infl_and_tr(infl, infltr), part_short_decl))
      new_decl_template = "".join(new_decl_template_parts)
      newdecl = "\n====Declension====\n" + new_decl_template
      newdecll4 = "\n=====Declension=====\n" + new_decl_template
    else:
      newdecl = ""
      newdecll4 = ""

    # 6. Synthesize part of speech body and section text as a whole.
    newposbody = """%s

# %s
""" % (new_headword_template, new_defn_template)
    newpos = "===%s===\n" % pos + newposbody + newdecl
    newposl4 = "====%s====\n" % pos + newposbody + newdecll4
    entrytext = "\n" + newpos
    entrytextl4 = "\n" + newposl4
    newsection = "==Russian==\n" + entrytext

  def print_warnings():
    if program_args.save:
      for warning in warnings:
        pagemsg("WARNING: Saving and issued the following warnings: %s" % warning, simple=True)
    else:
      for warning in warnings:
        pagemsg("WARNING: Would save and issued the following warnings: %s" % warning, simple=True)

  def do_add_infl(page, index, parsed):
    comment = None
    notes = []

    existing_text = blib.safe_page_text(page, pagemsg)
    if not blib.safe_page_exists(page, pagemsg):
      # Page doesn't exist. Create it.
      pagemsg("Creating page")
      comment = "Create page for Russian %s %s of %s, pos=%s" % (
          infltype, joined_infls, lemma, pos)
      #if verbose:
      #  pagemsg("New text is [[%s]]" % newsection)
      print_warnings()
      return newsection, comment

    # Page does exist
    pagetext = existing_text

    # Split off interwiki links at end
    m = re.match(r"^(.*?\n)(\n*(\[\[[a-z0-9_\-]+:[^\]]+\]\]\n*)*)$",
        pagetext, re.S)
    if m:
      pagebody = m.group(1)
      pagetail = m.group(2)
    else:
      pagebody = pagetext
      pagetail = ""

    # Split into sections
    splitsections = re.split("(^==[^=\n]+==\n)", pagebody, 0, re.M)
    # Extract off pagehead and recombine section headers with following text
    pagehead = splitsections[0]
    sections = []
    for i in range(1, len(splitsections)):
      if (i % 2) == 1:
        sections.append("")
      sections[-1] += splitsections[i]

    found_plurale_tantum_lemma = False

    # Go through each section in turn, looking for existing Russian section
    for i in range(len(sections)):
      m = re.match("^==([^=\n]+)==$", sections[i], re.M)
      if not m:
        pagemsg("Can't find language name in text: [[%s]]" % (sections[i]))
      elif m.group(1) == "Russian":
        secbody, sectail = blib.split_trailing_separator_and_categories(sections[i])
        # Note that this changes the number of sections, which is seemingly
        # a problem because the for-loop above calculates the end point
        # at the beginning of the loop, but is not actually a problem
        # because we always break after processing the Russian section.
        sections[i:i+1] = [secbody, sectail]

        if program_args.overwrite_page:
          if pagename in pages_already_erased:
            warn("Not overwriting page, already overwritten previously")
          elif "==Etymology 1==" in sections[i] and not program_args.overwrite_etymologies:
            warn("Found ==Etymology 1== in page text, not overwriting, skipping form",
                err=True)
            return
          elif "{{audio|" in sections[i]:
            warn("{{audio|...}} in page text, not overwriting, skipping form", err=True)
            return
          elif pagename in lemmas_to_not_overwrite:
            warn("Page in --lemmas-to-not-overwrite, not overwriting, skipping form", err=True)
            return
          else:
            parsed = blib.parse_text(sections[i])
            found_lemma = []
            for t in parsed.filter_templates():
              tnam = tname(t)
              if tnam in ["ru-noun", "ru-noun+", "ru-proper noun",
                  "ru-proper noun+", "ru-noun-alt-ё", "ru-proper noun-alt-ё",
                  "ru-adj", "ru-adj-alt-ё", "ru-verb", "ru-verb-alt-ё",
                  "ru-adv", "ru-phrase"] or (tnam == "head" and
                      getparam(t, "1") == "ru" and getparam(t, "2") in
                      ["circumfix", "conjunction", "determiner", "interfix",
                        "interjection", "letter", "numeral", "cardinal number",
                        "particle", "predicative", "prefix", "preposition",
                        "prepositional phrase", "pronoun"]):
                found_lemma.append(getparam(t, "2") if tnam == "head" else
                    tnam)
            if found_lemma:
              warn("Page appears to have a lemma on it, not overwriting, skipping form: lemmas = %s"
              % ",".join(found_lemma), err=True)
              return
            notes.append("overwrite section")
            warn("Overwriting entire Russian section")
            # Preserve {{also|...}}
            sections[i] = re.sub(r"^((\s*\{\{also\|.*?\}\}\s*)?).*$", r"\1",
                sections[i], 0, re.S)
            pages_already_erased.add(pagename)

        # Convert {{head|ru|noun form}} into {{ru-noun form}}, which we may
        # process later. Currently we do this always; we need to do it at least
        # for nouns and adjectives, since adjectives look for occurrences of
        # {{ru-noun form}}.
        parsed = blib.parse_text(sections[i])
        for t in parsed.filter_templates():
          if tname(t) == "head" and getparam(t, "1") == "ru" and getparam(t, "2") == "noun form":
            origt = str(t)
            head = getparam(t, "head") or pagename
            t.add("1", head) # 1= is already set
            rmparam(t, "head")
            g = getparam(t, "g")
            if g:
              t.add("2", g) # 2= is already set
            else:
              rmparam(t, "2")
            rmparam(t, "g")
            blib.set_template_name(t, "ru-noun form")
            pagemsg("Replaced %s with %s" % (origt, str(t)))
            notes.append("convert {{head|ru|noun form}} to {{ru-noun form}}")
        sections[i] = str(parsed)

        # Canonicalize tags in {{inflection of}} to those in
        # preferred_tag_variants.
        parsed = blib.parse_text(sections[i])
        for t in parsed.filter_templates():
          if tname(t) not in deftemp:
            continue
          origt = str(t)
          lang_in_1 = deftemp_needs_lang and not t.has("lang")
          lang_param = lang_in_1 and "1" or "lang"
          if (not deftemp_needs_lang or
              compare_param(t, lang_param, "ru", None, param_is_head=False)):
            for param in t.params:
              pnam = pname(param)
              pvalue = str(param.value)
              if (pnam not in ["1", "2"] and not (lang_in_1 and pnam == "3")
                  and re.search("^[0-9]+$", pnam)):
                if pvalue in tag_to_canonical_form_table:
                   param.value = tag_to_canonical_form_table[pvalue]
            newt = str(t)
            if origt != newt:
              pagemsg("Replaced %s with %s" % (origt, newt))
              notes.append("canonicalize tags in {{%s}}" % tname(t))
        sections[i] = str(parsed)

        # When creating non-lemma forms, warn about matching lemma template
        if is_lemma_template:
          parsed = blib.parse_text(sections[i])
          for t in parsed.filter_templates():
            if is_lemma_template(t):
              if template_head_matches(t, inflections, "checking for lemma"):
                warn("Creating non-lemma form and found matching lemma template: %s" % str(t))
              if is_noun_form:
                tnam = tname(t)
                if tnam in ["ru-noun", "ru-proper noun"] and any([re.search(r"\bp\b", x) for x in blib.fetch_param_chain(t, "2", "g")]):
                  found_plurale_tantum_lemma = True
                elif tnam in ["ru-noun+", "ru-proper noun+"]:
                  args = rulib.fetch_noun_args(t, expand_text)
                  if args is None:
                    warn("Error expanding template when checking for plurale tantum nouns: %s" %
                        str(t))
                  elif args["n"] == "p":
                    found_plurale_tantum_lemma = True

        if found_plurale_tantum_lemma and is_noun_form and is_noun_adj_plural:
          pllemmas = set(rulib.remove_accents(infl) for infl, infltr in inflections)
          sglemma = rulib.remove_accents(lemma)
          for pllemma in pllemmas:
            is_known_about = False
            for lemma1, lemma2 in allow_in_same_etym_section:
              if lemma1 == pllemma and lemma2 == sglemma:
                pagemsg("Found plurale tantum lemma and creating plural noun form, found the pair in allow_in_same_etym_section")
                is_known_about = True
                break
            if not is_known_about:
              for lemma1, lemma2 in not_in_same_etym_section:
                if lemma1 == pllemma and lemma2 == sglemma:
                  pagemsg("Found plurale tantum lemma and creating plural noun form, found the pair in not_in_same_etym_section")
                  is_known_about = True
                  break
            if not is_known_about:
              warn("Found plurale tantum lemma and creating plural noun form, might need to add lemmas to allow_in_same_etym_section or not_in_same_etym_section")

        subsections = re.split("(^===+[^=\n]+===+\n)", sections[i], 0, re.M)

        # We will loop through the subsections up to 4 times, seeing if we
        # can find a match or a way of inserting a new definition. If so, we
        # break the loop.
        #
        # Pass 0 = check for existing headword and definition, without adding
        #          a new gender to the headword; break if so
        # Pass 1 = same, but this time allow a new gender to be added;
        #          break if existing headword and definition found
        # Pass 2 = if no existing definition, check for ability to insert
        #          new defn into existing subsection without adding a new
        #          gender; break if so
        # Pass 3 = if got this far, check for ability to insert new defn
        #          into existing subsection adding a new gender
        #
        # If we got through all four passes without breaking, we will
        # proceed below to insert a new subsection, and possibly a whole
        # new etymology section or Russian-language section.
        #
        # We do this to handle certain situations where there are multiple
        # subsections. For example, моль has three separate etymologically
        # unrelated meanings, with different declensions and genders. моль
        # meaning "clothes moth" is feminine animate, while моль meaning
        # "minor (music)" or "mole (chemistry)" is masculine inanimate.
        # моли is gen/dat/pre sg and nom pl or моль "clothes moth", and
        # nom/acc pl of the other two meanings. After the gen sg and nom pl
        # were created by the bot, it was hand-edited and split into two
        # etymology sections, one feminine animate with definitions for
        # gen sg and nom pl and the second masculine inanimate with a
        # definition for nom pl. When processing the nom pl of the masculine
        # inanimate meanings, if we don't have separate passes with and
        # without allowing for adding gender, we'll match the first etymology
        # section and add masculine inanimate gender to it, when there's
        # already a suitable entry in the second etymology section. Similarly,
        # when processing the acc pl of the masculine inanimate meanings,
        # without separate passes we would insert the defn into the first
        # etymology section and modify the gender, when it should go into
        # the second. In other circumstances, without separate passes to
        # first check for existing definitions we might add a definition for
        # a form into an earlier subsection when there's already such a
        # definition in a later subsection.

        for process_section_pass in range(4):
          need_outer_break = False

          # Go through each subsection in turn, looking for subsection
          # matching the POS with an appropriate headword template whose
          # head matches the inflected form
          for j in range(2, len(subsections), 2):
            if re.match("^===+%s===+\n" % pos, subsections[j - 1]):
              # Found a POS match
              parsed = blib.parse_text(subsections[j])

              # For nouns and adjectives, check the existing gender of the
              # given headword template and attempt to make sure it matches
              # the given gender or can be compatibly modified to the new
              # gender. Return False if genders incompatible and FIX_INCOMPAT
              # is False, else modify existing gender if needed, and return
              # True. (E.g. existing "m" matches new "an" and will be
              # modified to "m-an"; # existing "m-an" matches new "m" and
              # will be left alone.)
              def check_fix_noun_adj_gender(headword_template, gender,
                  singular_in_existing_defn_templates, fix_incompat):
                def gender_compatible(existing, new):
                  # Compare existing and new m/f/n gender
                  m = re.search(r"\b([mfn])\b", existing)
                  existing_mf = m and m.group(1)
                  m = re.search(r"\b([mfn])\b", new)
                  new_mf = m and m.group(1)
                  if existing_mf and new_mf and existing_mf != new_mf:
                    warn("Can't modify mf gender from %s to %s" % (
                        existing_mf, new_mf))
                    return False, "true gender"
                  new_mf = new_mf or existing_mf

                  # Compare existing and new animacy
                  m = re.search(r"\b(an|in)\b", existing)
                  existing_an = m and m.group(1)
                  m = re.search(r"\b(an|in)\b", new)
                  new_an = m and m.group(1)
                  if existing_an and new_an and existing_an != new_an:
                    warn("Can't modify animacy from %s to %s" % (
                        existing_an, new_an))
                    return False, "animacy"
                  new_an = new_an or existing_an

                  # Compare existing and new plurality
                  m = re.search(r"\b([p])\b", existing)
                  existing_p = m and m.group(1)
                  if not existing_p and singular_in_existing_defn_templates:
                    existing_p = "s"
                  m = re.search(r"\b([p])\b", new)
                  new_p = m and m.group(1)
                  if not new_p:
                    new_p = "s"
                  if existing_p and new_p and existing_p != new_p:
                    warn("Can't modify plurality from %s to %s" % (
                        existing_p, new_p))
                    return False, "plurality"
                  new_p = new_p or existing_p

                  # Construct result
                  return '-'.join([x for x in [new_mf, new_an, new_p] if x and x != "s"]), None

                if len(gender) == 0:
                  return True # "nochange"

                existing_genders = blib.fetch_param_chain(headword_template,
                    first_gender_param, "g")

                if not fix_incompat:
                  # If we're not allowed to fix an incompatible gender by
                  # adding a new gender, first make sure we can harmonize
                  # all the genders before modifying anything.
                  for g in gender:
                    if g in existing_genders:
                      continue
                    found_compat = False
                    if existing_genders:
                      # Try to modify an existing gender to match the new gender
                      for paramno, existing in enumerate(existing_genders):
                        new_gender, harmonization_problem = gender_compatible(existing, g)
                        if new_gender:
                          found_compat = True
                    # FIXME: If there are no existing genders, we return False
                    # here. Should we instead allow this?
                    if not found_compat:
                      return False

                for g in gender:
                  if g in existing_genders:
                    continue
                  found_compat = False
                  changed = False
                  if existing_genders:
                    # Try to modify an existing gender to match the new gender
                    harmonization_problems = []
                    for paramno, existing in enumerate(existing_genders):
                      new_gender, harmonization_problem = gender_compatible(existing, g)
                      if new_gender:
                        found_compat = True
                        if existing != new_gender:
                          newparam = first_gender_param if paramno == 0 else (
                              "g%s" % (paramno + 1))
                          pagemsg("Modifying gender param %s from %s to %s" %
                              (newparam, existing, new_gender))
                          notes.append("modify gender from %s to %s" %
                              (existing, new_gender))
                          headword_template.add(newparam, new_gender)
                          changed = True
                        break
                      assert harmonization_problem
                      if harmonization_problem not in harmonization_problems:
                        harmonization_problems.append(harmonization_problem)
                    else:
                      warn("Unable to modify %s in existing genders %s to match new gender %s" % (
                        ",".join(harmonization_problems),
                        ",".join(existing_genders), g))
                  if not found_compat:
                    assert fix_incompat
                    newparam = blib.append_param_to_chain(headword_template, g,
                        first_gender_param, "g")
                    pagemsg("Adding new gender param %s=%s" %
                        (newparam, g))
                    notes.append("add gender %s" % g)
                    changed = True
                  if changed:
                    subsections[j] = str(parsed)
                    sections[i] = ''.join(subsections)
                return True # changed and "changed" or "nochange"

              # For verbs, the only gender is 'pf' or 'impf' (CURRENTLY UNUSED)
              #def check_fix_verb_gender(headword_template, gender):
              #  existing_genders = blib.fetch_param_chain(headword_template,
              #      first_gender_param, "g")
              #  for g in gender:
              #    if g not in existing_genders:
              #      newparam = blib.append_param_to_chain(headword_template, g,
              #        first_gender_param, "g")
              #      pagemsg("Added verb gender %s=%s" % (newparam, g))
              #      subsections[j] = str(parsed)
              #      sections[i] = ''.join(subsections)
              #      notes.append("update gender %s" % g)

              # Update the gender in HEADWORD_TEMPLATE according to GENDER
              # (which might be empty, meaning no updating) using
              # check_fix_*_gender(). Also update any other parameters in
              # HEADWORD_TEMPLATE according to PARAMS. (NOTE: We don't
              # currently have any such params, but we preserve this code
              # in any we will in the future.) Return False and issue a
              # warning if we're unable to update (meaning a parameter we
              # wanted to set already existed in HEADWORD_TEMPLATE with a
              # different value); else return True. If changes were made,
              # an appropriate note will be added to 'notes' and the
              # section and subsection text updated. The argument
              # SINGULAR_IN_EXISTING_DEFN_TEMPLATES indicates whether there's
              # an existing definition template (e.g. {{inflection of|...}})
              # with the inflection code "s" (singular); if so, when
              # harmonizing the gender we remove plural gender.
              # FIX_INCOMPAT_GENDER says whether we add a new gender to
              # the headword template when gender harmonization fails.
              def check_fix_infl_params(headword_template, params, gender,
                  singular_in_existing_defn_templates, fix_incompat_gender):
                if gender:
                  if is_noun_or_adj:
                    if not check_fix_noun_adj_gender(headword_template, gender,
                        singular_in_existing_defn_templates,
                        fix_incompat_gender):
                      return False
                if is_verb_form:
                  # If verb form, remove any existing gender, since it
                  # instead goes into the definition line
                  if blib.remove_param_chain(headword_template,
                      first_gender_param, "g"):
                    subsections[j] = str(parsed)
                    sections[i] = ''.join(subsections)
                    notes.append("remove gender")

                # REMAINING CODE IN FUNCTION NOT CURRENTLY USED
                # First check that we can update params before changing anything
                #for param, value in params:
                #  existing = getparam(headword_template, param)
                #  assert(value)
                #  if existing == value:
                #    pass
                #  elif existing:
                #    warn("Can't modify %s from %s to %s" % (
                #        param, existing, value))
                #    return False
                ## Now update params
                #changed = False
                #for param, value in params:
                #  existing = getparam(headword_template, param)
                #  assert(value)
                #  if existing:
                #    assert(existing == value)
                #  else:
                #    headword_template.add(param, value)
                #    changed = True
                #    notes.append("update %s=%s" % (param, value))
                #if changed:
                #  subsections[j] = str(parsed)
                #  sections[i] = ''.join(subsections)
                return True

              # Split a list of tags into individual tag sets,
              # where the individual tag sets are separated by a ; tag.
              def split_inflection_tag_sets(tags):
                tag_sets = []
                cur_tag_set = []
                for tag in tags:
                  if tag == ";":
                    tag_sets.append(cur_tag_set)
                    cur_tag_set = []
                  else:
                    if ";" in tag:
                      warn("Found semicolon in tag '%s' in tags %s" % (
                        tag, "|".join(tags)))
                    cur_tag_set.append(tag)
                tag_sets.append(cur_tag_set)
                return tag_sets

              # Join tag sets back into a list of tags.
              def join_inflection_tag_sets(tag_sets):
                tags = []
                for tag_set in tag_sets:
                  if tags:
                    tags.append(";")
                  tags.extend(tag_set)
                return tags

              # Split a tag set possibly containing multipart tags
              # into one or more tag sets not containing such tags.
              def split_multipart_tag_set(ts):
                for i, tag in enumerate(ts):
                  if "//" in tag:
                    single_tags = tag.split("//")
                    pre_tags = ts[0:i]
                    post_tags = ts[i+1:]
                    tag_sets = []
                    for single_tag in single_tags:
                      tag_sets.extend(split_multipart_tag_set(
                        pre_tags + [single_tag] + post_tags))
                    return tag_sets
                return [ts]

              # Check for a given tag (including in part of a multipart tag)
              # in the tags of any definitional template (with the correct
              # language) in the subsection.
              # FIXME, should this check the lemma?
              def check_for_given_inflection_tag(parsed, tag):
                for t in parsed.filter_templates():
                  if tname(t) not in deftemp:
                    continue
                  lang_in_1 = deftemp_needs_lang and not t.has("lang")
                  lang_param = lang_in_1 and "1" or "lang"
                  if (not deftemp_needs_lang or
                        compare_param(t, lang_param, "ru", None,
                          param_is_head=False, issue_warnings=issue_warnings)):
                    for param in t.params:
                      pnam = pname(param)
                      pvalue = str(param.value)
                      if (pnam not in ["1", "2"] and not (lang_in_1 and pnam == "3")
                          and re.search("^[0-9]+$", pnam)):
                        # Individual components may be separated by //
                        # (first-level) or : (second-level).
                        split_values = re.split("//|:", pvalue)
                        if tag in split_values:
                          return True
                return False

              # Replace the form-code parameters of tag set TAG_SET_NO
              # in "infl of" (or "participle of") with those
              # in INFLS, putting the non-form-code parameters in the
              # right places. If TAG_SET_NO is -1, add to the end.
              # if TAG_SET_NO == "all", replace all tag sets.
              def check_fix_defn_params(t, tag_set_no, infls):
                # Following code mostly copied from fix_verb_form.py
                origt = str(t)
                # Fetch lemma and alt params, and non-numbered params.
                lang = getparam(t, "lang")
                lang_in_1 = deftemp_needs_lang and not lang
                if lang_in_1:
                  lang = getparam(t, "1")
                lemmaparam = getparam(t, "2" if lang_in_1 else "1")
                altparam = getparam(t, "3" if lang_in_1 else "2")
                tr = getparam(t, "tr")
                tags = []
                non_numbered_params = []
                for param in t.params:
                  pnam = pname(param)
                  pvalue = str(param.value)
                  if (pnam not in ["1", "2"] and not (lang_in_1 and pnam == "3")
                      and re.search("^[0-9]+$", pnam) and pvalue):
                    tags.append(pvalue)
                  if not re.search(r"^[0-9]+$", pnam) and pnam not in ["lang", "tr"]:
                    non_numbered_params.append((pnam, param.value))

                tag_sets = split_inflection_tag_sets(tags)
                if tag_set_no == -1:
                  tag_sets.append(infls)
                elif tag_set_no == "all":
                  tag_sets = [infls]
                else:
                  tag_sets[tag_set_no] = infls
                tags = join_inflection_tag_sets(tag_sets)

                if deftemp_allows_multiple_tag_sets:
                  # Now combine adjacent tags into multipart tags.
                  tags, this_notes = infltags.combine_adjacent_tags_into_multipart(
                    tname(t), lang, lemmaparam,
                    tags, tag_to_dimension_table, pagemsg, warn,
                    tag_to_canonical_form_table=tag_to_canonical_form_table
                  )
                  notes.extend(this_notes)

                # Erase all params.
                del t.params[:]
                # Put back lang, lemma param, alt param, tr, then the
                # replacements for the higher numbered params, then the
                # non-numbered params. Use new-style params (lang in 1)
                # even if params were old-style (lang in lang=).
                if lang:
                  t.add("1", lang)
                t.add("2" if lang else "1", lemmaparam)
                t.add("3" if lang else "2", altparam)
                if tr:
                  t.add("tr", tr)
                for paramno, param in enumerate(tags):
                  t.add(str(paramno+(4 if lang else 3)), param)
                for name, value in non_numbered_params:
                  t.add(name, value)
                newt = str(t)
                if origt != newt:
                  pagemsg("Replaced %s with %s" % (origt, newt))
                  if tag_set_no != -1:
                    # FIXME, unnecessary long-term dependency here,
                    # where we happen to know that the places where
                    # tag_set_no is called with a non-negative
                    # number or "all" are used for updating aspect
                    # codes.
                    notes.append("update form codes (pfv/impfv)")
                  subsections[j] = str(parsed)
                  sections[i] = ''.join(subsections)

              # True if the tag sets in template T (an "inflection of"
              # template) exactly match the inflections given in INFLS (in
              # any order), or if the former are a superset of the latter.
              # Return value is a tuple (MATCH, TAG_SET_NO) where TAG_SET_NO
              # is the index of the tag set in template T that matches (0 if
              # there's only one tag set in T, but there may be multiple tag
              # sets separated by a semicolon; or "all") and MATCH is
              # * True if any tag set in T either exactly matches the
              #   inflections in INFLS (where "exactly match" takes into
              #   account tag sets with multipart tags, which are effectively
              #   multiple tag sets jammed together) or is a superset of the
              #   inflections in INFLS (in which case a warning is issued);
              # * "update" if an exact match isn't found and the current
              #   lemma is in lemmas_to_overwrite, or if an exact match or
              #   superset isn't found but an exact match would be found
              #   if "pfv" or "impfv" were added to a tag set;
              # * else False.
              def compare_inflections(t, infls, issue_warnings=True):
                lang_in_1 = deftemp_needs_lang and not t.has("lang")
                inflset = set(infls)
                tags = []
                for param in t.params:
                  name = pname(param)
                  value = str(param.value)
                  if (name not in ["1", "2"] and not (lang_in_1 and name == "3")
                      and re.search("^[0-9]+$", name) and value):
                    tags.append(value)
                tag_sets = split_inflection_tag_sets(tags)
                split_tag_sets = [split_multipart_tag_set(tag_set) for tag_set in tag_sets]
                # See if there's an exact match.
                for tag_set_no, split_tag_set_group in enumerate(split_tag_sets):
                  for indiv_tag_set in split_tag_set_group:
                    if set(indiv_tag_set) == inflset:
                      return True, tag_set_no

                # Return "update" if lemma in lemmas_to_overwrite.
                if rulib.remove_accents(lemma) in lemmas_to_overwrite:
                  return "update", "all"

                # See if there's a superset match.
                for tag_set_no, split_tag_set_group in enumerate(split_tag_sets):
                  for indiv_tag_set in split_tag_set_group:
                    if set(indiv_tag_set) > inflset:
                      warn_if(issue_warnings, "Found actual inflection %s in template %s whose codes are a superset of intended codes %s, accepting" % (
                        "|".join(indiv_tag_set), str(t), "|".join(infls)))
                      return True, tag_set_no
                # See if there's a subset match.
                for tag_set_no, split_tag_set_group in enumerate(split_tag_sets):
                  for indiv_tag_set in split_tag_set_group:
                    indiv_set = set(indiv_tag_set)
                    if indiv_set < inflset:
                      # Check to see if we match except for a missing
                      # perfective or imperfective aspect, which we will update.
                      if (indiv_set | {"pfv"}) == inflset or (indiv_set | {"impfv"}) == inflset:
                        if len(split_tag_set_group) == 1:
                          pagemsg_if(issue_warnings, "Need to update actual inflection %s in template %s with intended codes %s" % (
                            "|".join(indiv_tag_set), str(t), "|".join(infls)))
                          return "update", tag_set_no
                        else:
                          warn_if(issue_warnings, "Found actual inflection %s in template %s whose codes are a subset of intended codes %s and could update aspect except that multipart tags are present" % (
                            "|".join(indiv_tag_set), str(t), "|".join(infls)))
                return False, 0

              # Find the inflection headword template(s) (e.g. 'ru-noun form' or
              # 'head|ru|verb form').
              def template_name(t):
                if headtemp_is_head:
                  return "|".join([tname(t), getparam(t, "1"), getparam(t, "2")])
                else:
                  return tname(t)

              # When checking to see if entry (headword and definition) already
              # present, allow extra heads, so e.g. when checking for 2nd pl
              # fut ind спали́те and we find a headword with both спали́те and
              # спа́лите we won't skip it. But when checking for headword without
              # definition to insert a new definition under it, make sure no
              # left-over heads, otherwise we will insert 2nd pl imperative
              # спали́те under the entry with both спали́те and спа́лите, which is
              # incorrect. (спали́те is both fut ind and imper, but спа́лите is
              # only fut ind. Many verbs work this way. The two forms of the
              # fut ind are found under separate conjugation templates so we
              # won't get a single request with both of them.)
              #
              # Set ISSUE_WARNINGS appropriately so we only issue warnings
              # on the first pass, rather than duplicating up to four times
              # on each pass.
              issue_warnings = process_section_pass == 0
              infl_headword_templates_for_already_present_entry = [
                  t for t in parsed.filter_templates()
                  if template_name(t) == headtemp and
                  template_head_matches(t, inflections,
                    "checking for already-present entry",
                    issue_warnings=issue_warnings)]
              infl_headword_templates_for_inserting_in_same_section = [
                  t for t in parsed.filter_templates()
                  if template_name(t) == headtemp and
                  template_head_matches(t, inflections,
                    "checking for inserting defn in same section",
                    fail_when_left_over_heads=True,
                    issue_warnings=issue_warnings)]

              def check_for_closely_related_lemma(otherlemma, lemma,
                  issue_warnings=True):
                otherlemma = rulib.remove_accents(otherlemma)
                lemma = rulib.remove_accents(lemma)
                for lemma1, lemma2 in allow_defn_in_same_subsection:
                  if (lemma1 == otherlemma and lemma2 == lemma or
                      lemma2 == otherlemma and lemma1 == lemma):
                    pagemsg_if(issue_warnings, "Allowing lemma %s to share headword with lemma %s because in allow_defn_in_same_subsection" %
                        (lemma, otherlemma))
                    return True
                return False

              # Find the definitional (typically "inflection of") template(s).
              # We store a tuple of (TEMPLATE, NEEDS_UPDATE) where NEEDS_UDPATE
              # is true if we need to overwrite the form codes (this happens
              # when we want to add the verb aspect 'pfv' or 'impfv' to the
              # form codes).
              defn_templates_for_already_present_entry = []
              defn_templates_for_inserting_in_same_section = []
              defn_templates_for_inserting_in_same_template = []
              for t in parsed.filter_templates():
                if tname(t) not in deftemp:
                  continue
                lang_in_1 = deftemp_needs_lang and not t.has("lang")
                lang_param = lang_in_1 and "1" or "lang"
                lemma_param = lang_in_1 and "2" or "1"
                if (compare_param(t, lemma_param, lemma, lemmatr,
                      param_is_head=True, issue_warnings=issue_warnings) and
                    (not deftemp_needs_lang or
                      compare_param(t, lang_param, "ru", None,
                        param_is_head=False, issue_warnings=issue_warnings))):
                  defn_templates_for_inserting_in_same_section.append(t)
                  defn_templates_for_inserting_in_same_template.append(t)
                  if isinstance(deftemp_param, str):
                    defn_templates_for_already_present_entry.append((t, False, 0))
                  else:
                    result, tag_set_no = compare_inflections(t, deftemp_param,
                        issue_warnings=issue_warnings)
                    if result == "update":
                      defn_templates_for_already_present_entry.append((t, True, tag_set_no))
                    elif result:
                      defn_templates_for_already_present_entry.append((t, False, 0))
                # Also see if the definition template matches a closely-related
                # lemma where we allow the two to share the same headword
                # (e.g. огонь and alternative form огнь)
                elif (check_for_closely_related_lemma(getparam(t, lemma_param), lemma,
                      issue_warnings=issue_warnings) and
                    (not deftemp_needs_lang or
                      compare_param(t, lang_param, "ru", None,
                        param_is_head=False, issue_warnings=issue_warnings))):
                  defn_templates_for_inserting_in_same_section.append(t)

              # Check for singular in any existing definition templates
              # (with the correct language) in the subsection.
              # FIXME, should this check the lemma?
              singular_in_existing_defn_templates = (
                check_for_given_inflection_tag(parsed, "s"))

              # Make sure there's exactly one headword template.
              if (len(infl_headword_templates_for_already_present_entry) > 1
                  or len(infl_headword_templates_for_inserting_in_same_section) > 1):
                warn("Found multiple inflection headword templates for %s; taking no action"
                    % (infltype))
                need_outer_break = True
                break

              # Insert participle declension if not present and term is an
              # adjectival participle. If declension already present, check
              # whether it matches; if not, issue warning and/or correct it.
              # Return true if inserted declension.
              def insert_part_decl_if_needed():
                if not is_adjectival_participle:
                  return False

                # Check if Declension subsection exists at a higher
                # indent level.
                m = re.match("^(==+)", subsections[j - 1])
                indentlevel = len(m.group(1))

                check_subsection = j + 1
                while check_subsection < len(subsections):
                  if (check_subsection % 2) == 0:
                    check_subsection += 1
                    continue
                  m = re.match("^(==+)", subsections[check_subsection])
                  newindent = len(m.group(1))
                  if newindent <= indentlevel:
                    break
                  if "==Declension==" in subsections[check_subsection]:
                    # Found Declension subsection; check ru-decl-adj templates
                    # in it to see if they match what we would insert
                    decl_templates = []
                    subsecparsed = blib.parse_text(subsections[check_subsection + 1])
                    for t in subsecparsed.filter_templates():
                      if tname(t) == "ru-decl-adj":
                        decl_templates.append(t)
                    # If different numbers of existing vs. wanted decl
                    # templates, exit with a warning
                    if len(decl_templates) != len(new_decl_template_parts):
                      warn("Found %s existing participial decl templates %s but want %s new decl templates %s" %
                          (len(decl_templates),
                          " ".join(str(t) for t in decl_templates),
                          len(new_decl_template_parts),
                          " ".join(new_decl_template_parts)))
                      return False
                    # Same number of existing vs. wanted decl templates;
                    # see if they match, and if not, whether we can update
                    # the short decl to make them match (we can convert from
                    # a(2) to a(2),dated-c(2) and from empty to -)
                    for k in range(len(decl_templates)):
                      declt = decl_templates[k]
                      newdeclt = blib.parse_text(new_decl_template_parts[k]).filter_templates()[0]
                      if str(declt) != str(newdeclt):
                        if getparam(declt, "1") == getparam(newdeclt, "1"):
                          shortdecl = getparam(declt, "2")
                          newshortdecl = getparam(newdeclt, "2")
                          if (shortdecl == "a(2)" and newshortdecl == "a(2),dated-c(2)" or
                              shortdecl == "" and newshortdecl == "-"):
                            pagemsg("Updated participle short decl from %s to %s" %
                                (shortdecl, newshortdecl))
                            notes.append("update participle short decl from %s to %s" %
                                (shortdecl, newshortdecl))
                            declt.add("2", newshortdecl)
                            subsections[check_subsection + 1] = str(subsecparsed)
                            sections[i] = "".join(subsections)
                            continue
                        warn("Existing decl %s and wanted decl %s differ and can't fix" %
                          (str(declt), str(newdeclt)))

                    return False
                  check_subsection += 1

                if not subsections[j].endswith("\n"):
                  subsections[j] = ensure_one_trailing_nl(subsections[j])

                pagemsg("Inserting declension in existing entry: %s %s, %s %s" %
                  (infltype, joined_infls, lemmatype, lemma))
                if indentlevel == 3:
                  subsections[j] += newdecl + "\n"
                else:
                  assert(indentlevel == 4)
                  subsections[j] += newdecll4 + "\n"
                sections[i] = "".join(subsections)
                return True

              # We found both templates and their heads matched; inflection
              # entry is already present.
              if (infl_headword_templates_for_already_present_entry and
                  defn_templates_for_already_present_entry and
                  process_section_pass in [0, 1]):
                if process_section_pass == 0:
                  pagemsg("Exists and has Russian section and found %s already in it"
                      % (infltype))
                # Maybe fix up auxiliary parameters (e.g. gender) in the
                # headword template.
                if check_fix_infl_params(infl_headword_templates_for_already_present_entry[0],
                    [], gender, singular_in_existing_defn_templates,
                    process_section_pass == 1):
                  # Maybe override the current form code parameters in the
                  # definition template(s) with the supplied ones (i.e. those
                  # derived from the declension/conjugation template on the
                  # lemma page).
                  for t, needs_update, tag_set_no in defn_templates_for_already_present_entry:
                    if needs_update:
                      check_fix_defn_params(t, tag_set_no, deftemp_param)
                  inserted = insert_part_decl_if_needed()
                  if inserted:
                    comment = "Insert declension in existing entry: %s %s, %s %s" % (
                      infltype, joined_infls, lemmatype, lemma)
                  else:
                    # "Do nothing", but set a comment, in case we made a
                    # template change like changing gender (NOTE: in addition
                    # to the comment, there are notes, which will reflect
                    # any minor changes like changing gender, so if we've
                    # taken a more major action like inserting a declension
                    # above, we don't need to put "Updating params" in the
                    # comment.)
                    comment = "Update params of existing entry: %s %s, %s %s" % (
                        infltype, joined_infls, lemmatype, lemma)
                  need_outer_break = True
                  break

              # At this point, didn't find either headword or definitional
              # template, or both. If we found headword template and another
              # definition template for the same lemma, insert new definition
              # in same section.
              elif (infl_headword_templates_for_inserting_in_same_section and
                  defn_templates_for_inserting_in_same_section and
                  process_section_pass in [2, 3]):
                # Make sure we can set the gender appropriately (and other
                # inflection parameters, if any were to exist). If not, we will
                # end up checking for more entries and maybe adding an entirely
                # new entry.
                if check_fix_infl_params(infl_headword_templates_for_inserting_in_same_section[0],
                    [], gender, singular_in_existing_defn_templates,
                    process_section_pass == 3):
                  # If multiple tag sets can be inserted into a single
                  # definitional template, try to do that.
                  if (deftemp_allows_multiple_tag_sets and
                      len(defn_templates_for_inserting_in_same_template) > 0 and
                      # FIXME, when is deftemp_param a string?
                      not isinstance(deftemp_param, str)):
                    defn_template_to_modify = defn_templates_for_inserting_in_same_template[-1]
                    check_fix_defn_params(defn_template_to_modify, -1, deftemp_param)
                    pagemsg("Insert new tag set into existing {{%s}}" % (
                        tname(defn_template_to_modify)))
                    # FIXME, this might not occur in these circumstances
                    inserted = insert_part_decl_if_needed()
                    comment = "%s new tag set into existing {{%s}}: %s %s, %s %s" % (
                        "Insert declension in existing entry and insert" if inserted else "Insert",
                        tname(defn_template_to_modify), infltype, joined_infls, lemmatype, lemma)
                  else:
                    # If there's already a defn line present, insert after
                    # any such defn lines. Else, insert at beginning.
                    if re.search(r"^# \{\{%s\|" % construct_alternant_re(deftemp), subsections[j], re.M):
                      if not subsections[j].endswith("\n"):
                        subsections[j] += "\n"
                      subsections[j] = check_re_sub(warn, "inserting definition into existing section",
                          r"(^(# \{\{%s\|.*\n)+)" % construct_alternant_re(deftemp),
                          r"\1# %s\n" % new_defn_template, subsections[j],
                          1, re.M)
                    else:
                      subsections[j] = check_re_sub(warn, "inserting definition into existing section",
                          r"^#", "# %s\n#" % new_defn_template,
                          subsections[j], 1, re.M)
                    sections[i] = ''.join(subsections)
                    pagemsg("Insert new defn with {{%s}} at beginning after any existing such defns" % (
                        deftemp[0]))
                    inserted = insert_part_decl_if_needed()
                    comment = "%s new defn with {{%s}} at beginning after any existing such defns: %s %s, %s %s" % (
                        "Insert declension in existing entry and insert" if inserted else "Insert",
                        deftemp[0], infltype, joined_infls, lemmatype, lemma)
                  need_outer_break = True
                  break

          if need_outer_break:
            break

        # else of for loop over passes 0-3, i.e. no break out of loop
        else:
          # At this point we couldn't find an existing subsection with
          # matching POS and appropriate headword template whose head matches
          # the inflected form.

          def insert_new_text_before_section(insert_at, secbefore_desc,
              matching):
            pagemsg("Found section to insert %s before: [[%s]]" % (
                generic_infltype, subsections[insert_at + 1]))

            # Determine indent level
            m = re.match("^(==+)", subsections[insert_at])
            indentlevel = len(m.group(1))

            secmsg = "%s section for same %s" % (secbefore_desc, matching)
            pagemsg("Inserting before %s" % secmsg)
            comment = "Insert entry for %s %s of %s before %s" % (
              infltype, joined_infls, lemma, secmsg)
            if insert_at > 0:
              subsections[insert_at - 1] = ensure_two_trailing_nl(
                  subsections[insert_at - 1])
            if indentlevel == 3:
              subsections[insert_at:insert_at] = [newpos + "\n"]
            else:
              assert(indentlevel == 4)
              subsections[insert_at:insert_at] = [newposl4 + "\n"]
            sections[i] = ''.join(subsections)
            return comment

          def insert_new_text_after_section(insert_at, secafter_desc,
              matching):
            pagemsg("Found section to insert %s after: [[%s]]" % (
                generic_infltype, subsections[insert_at - 1]))

            # Determine indent level and skip past sections at higher indent
            m = re.match("^(==+)", subsections[insert_at - 2])
            indentlevel = len(m.group(1))
            while insert_at < len(subsections):
              if (insert_at % 2) == 0:
                insert_at += 1
                continue
              m = re.match("^(==+)", subsections[insert_at])
              newindent = len(m.group(1))
              if newindent <= indentlevel:
                break
              pagemsg("Skipped past higher-indented subsection: [[%s]]" %
                  subsections[insert_at])
              insert_at += 1

            secmsg = "%s section for same %s" % (secafter_desc, matching)
            pagemsg("Inserting after %s" % secmsg)
            comment = "Insert entry for %s %s of %s after %s" % (
              infltype, joined_infls, lemma, secmsg)
            subsections[insert_at - 1] = ensure_two_trailing_nl(
                subsections[insert_at - 1])
            if indentlevel == 3:
              subsections[insert_at:insert_at] = [newpos + "\n"]
            else:
              assert(indentlevel == 4)
              subsections[insert_at:insert_at] = [newposl4 + "\n"]
            sections[i] = ''.join(subsections)
            return comment

          # If adjectival participle, try to find an existing noun or
          # adjective with the same headword to insert before. Insert before
          # the first such one.
          if is_adjectival_participle:
            insert_at = None
            for j in range(2, len(subsections), 2):
              if re.match("^===+(Noun|Adjective)===+", subsections[j - 1]):
                parsed = blib.parse_text(subsections[j])
                for t in parsed.filter_templates():
                  if (tname(t) in ["ru-adj", "ru-noun", "ru-proper noun", "ru-noun+", "ru-proper noun+"] and
                      template_head_matches(t, inflections, "checking for existing noun/adjective with headword matching adjectival participle") and insert_at is None):
                    insert_at = j - 1

            if insert_at is not None:
              comment = insert_new_text_before_section(insert_at,
                  "noun/adjective", "headword")
              break

          # If adverbial participle, try to find an existing adverb or
          # preposition with the same headword to insert before. Insert before
          # the first such one.
          if is_adverbial_participle:
            insert_at = None
            for j in range(2, len(subsections), 2):
              if re.match("^===+(Adverb|Preposition)===+", subsections[j - 1]):
                parsed = blib.parse_text(subsections[j])
                for t in parsed.filter_templates():
                  if ((tname(t) in ["ru-adv"] or tname(t) == "head" and getparam(t, "1") == "ru" and getparam(t, "2") == "preposition") and
                      template_head_matches(t, inflections, "checking for existing adverb/preposition with headword matching adverbial participle") and insert_at is None):
                    insert_at = j - 1

            if insert_at is not None:
              comment = insert_new_text_before_section(insert_at,
                  "adverb/preposition", "headword")
              break

          # If adjective form, try to find an existing participle form with
          # the same headword to insert after. If short adjective form, also
          # try to find an existing adverb or predicative with the same
          # headword to insert after. In all cases, insert after the last such
          # one.
          if is_adj_form:
            insert_at = None
            for j in range(2, len(subsections), 2):
              if re.match("^===+Participle===+", subsections[j - 1]):
                parsed = blib.parse_text(subsections[j])
                for t in parsed.filter_templates():
                  if (tname(t) == "head" and getparam(t, "1") == "ru" and
                      getparam(t, "2") == "participle form" and
                      template_head_matches(t, inflections, "checking for existing participle with headword matching adjective")):
                    insert_at = j + 1
              if is_short_adj_form:
                if re.match("^===+Adverb===+", subsections[j - 1]):
                  parsed = blib.parse_text(subsections[j])
                  for t in parsed.filter_templates():
                    if (tname(t) in ["ru-adv"] and
                        template_head_matches(t, inflections, "checking for existing adverb with headword matching short adjective")):
                      insert_at = j + 1
                elif re.match("^===+Predicative===+", subsections[j - 1]):
                  parsed = blib.parse_text(subsections[j])
                  for t in parsed.filter_templates():
                    if (tname(t) == "head" and getparam(t, "1") == "ru" and
                        getparam(t, "2") == "predicative" and
                        template_head_matches(t, inflections, "checking for existing predicative with headword matching short adjective")):
                      insert_at = j + 1
            if insert_at:
              comment = insert_new_text_after_section(insert_at,
                  "adverb/predicative/participle form" if is_short_adj_form
                  else "participle form", "headword")
              break

          # Check whether lemma LEMMA of form to add and already-existing
          # form of OTHERLEMMA are pairs in allow_in_same_etym_section.
          # If FIRST_ONLY, require that OTHERLEMMA is the first one
          # (the plurale tantum); we use this when creating a form that
          # will be in the same etym section as a plurale tantum lemma,
          # so we don't by accident end up inserting in the same etym section
          # as a normal singular lemma.
          def check_for_matching_sg_pl_pair(otherlemma, lemma,
              first_only=False):
            otherlemma = rulib.remove_accents(otherlemma)
            lemma = rulib.remove_accents(lemma)
            for lemma1, lemma2 in allow_in_same_etym_section:
              if (lemma1 == otherlemma and lemma2 == lemma or
                  not first_only and lemma2 == otherlemma and lemma1 == lemma):
                pagemsg("Allowing new subsection for lemma %s in same etym section as lemma %s because in allow_in_same_etym_section list" %
                    (lemma, otherlemma))
                return True
            return False

          def matching_defn_templates(parsed, allow_stress_mismatch=False,
              check_for_sg_pl_pairs=False):
            retval = []
            for t in parsed.filter_templates():
              if tname(t) not in deftemp:
                continue
              lang_in_1 = deftemp_needs_lang and not t.has("lang")
              lang_param = lang_in_1 and "1" or "lang"
              lemma_param = lang_in_1 and "2" or "1"
              if (
                (compare_param(t, lemma_param, lemma, lemmatr,
                  param_is_head=True, allow_stress_mismatch=allow_stress_mismatch) or
                  check_for_sg_pl_pairs and check_for_matching_sg_pl_pair(
                    getparam(t, lemma_param), lemma)) and
                (not deftemp_needs_lang or
                  compare_param(t, lang_param, "ru", None, param_is_head=False))
              ):
                retval.append(t)
            return retval

          # If adjective form, try to find noun form with same headword
          # (inflection) and definition (lemma) to insert before (this happens
          # with nouns that are substantivized adjectives). Insert before
          # first such one.
          if is_adj_form:
            insert_at = None
            for j in range(2, len(subsections), 2):
              if re.match("^===+Noun===+", subsections[j - 1]):
                parsed = blib.parse_text(subsections[j])
                defn_templates = matching_defn_templates(parsed)
                for t in parsed.filter_templates():
                  if (tname(t) in ["ru-noun form"] and
                      template_head_matches(t, inflections, "checking for existing noun form with headword and defn matching adj form") and
                      defn_templates and
                      insert_at is None):
                    insert_at = j - 1

            if insert_at is not None:
              comment = insert_new_text_before_section(insert_at, "noun form",
                  "headword and definition")
              break

          # If noun form, try to find adjective form with same headword
          # (inflection) and definition (lemma) to insert after (this happens
          # with nouns that are substantivized adjectives). Insert after
          # last such one.
          if is_noun_form:
            insert_at = None
            for j in range(2, len(subsections), 2):
              if re.match("^===+Adjective===+", subsections[j - 1]):
                parsed = blib.parse_text(subsections[j])
                defn_templates = matching_defn_templates(parsed)
                for t in parsed.filter_templates():
                  if (tname(t) == "head" and getparam(t, "1") == "ru" and
                      getparam(t, "2") == "adjective form" and
                      template_head_matches(t, inflections, "checking for existing adj form with headword and defn matching noun form") and
                      defn_templates):
                    insert_at = j + 1

            if insert_at:
              comment = insert_new_text_after_section(insert_at, "adj form",
                  "headword and definition")
              break

          # Try to find plurale tantum noun lemma for paired lemma in
          # allow_in_same_etym_section list (e.g. creating gen_sg/nom_pl
          # бакенбарды of бакенбарда, on same page as plurale tantum
          # бакенбарды). Insert after the last such one.
          if is_noun_form:
            insert_at = None
            for j in range(2, len(subsections), 2):
              if re.match("^===+Noun===+", subsections[j - 1]):
                parsed = blib.parse_text(subsections[j])
                for t in parsed.filter_templates():
                  if tname(t) in ["ru-noun+", "ru-proper noun+"]:
                    otherlemmaarg = rulib.fetch_noun_lemma(t, expand_text)
                    if otherlemmaarg is None:
                      warn("Error generating noun forms when %s" % purpose)
                    else:
                      otherlemmas = set(re.split(",", otherlemmaarg))
                      for otherlemma in otherlemmas:
                        if check_for_matching_sg_pl_pair(otherlemma, lemma,
                            first_only=True):
                          insert_at = j + 1
                  elif tname(t) in ["ru-noun", "ru-proper noun"]:
                    otherlemmas = blib.fetch_param_chain(t, "1", "head")
                    for otherlemma in otherlemmas:
                      if check_for_matching_sg_pl_pair(otherlemma, lemma,
                          first_only=True):
                        insert_at = j + 1

            if insert_at:
              comment = insert_new_text_after_section(insert_at,
                  "plurale tantum noun", "lemma pair in allow_in_same_etym_section")
              break

          # Now try to find an existing section corresponding to the same
          # lemma. This happens e.g. with verb forms, such as смо́трите
          # 2nd plural pres ind vs. смотри́те 2nd plural imperative, or
          # with nouns of e.g. accent patterns c and d, in the gen sg vs.
          # nom pl of masculine nouns.
          #
          # Insert after the last such section.

          insert_at = None
          for j in range(2, len(subsections), 2):
            if re.match("^===+%s===+\n" % pos, subsections[j - 1]):
              parsed = blib.parse_text(subsections[j])
              defn_templates = matching_defn_templates(parsed,
                  allow_stress_mismatch=allow_stress_mismatch_in_defn,
                  check_for_sg_pl_pairs=is_noun_form)
              if defn_templates:
                insert_at = j + 1

          if insert_at:
            comment = insert_new_text_after_section(insert_at, generic_infltype,
                "definition")
            break

          # Check for another plural noun form if we're a plural noun form
          if is_noun_form and is_noun_adj_plural:
            found_plural_noun_form = False
            for j in range(2, len(subsections), 2):
              if re.match("^===+Noun===+", subsections[j - 1]):
                parsed = blib.parse_text(subsections[j])
                # Check for singular in any existing definition templates
                # (with the correct language) in the subsection.
                # FIXME, should this check the lemma?
                plural_in_existing_defn_templates = (
                  check_for_given_inflection_tag(parsed, "p"))
                # Now check for matching ru-noun form, where either there was
                # a plural in a defn template or there's a plural gender
                # (the latter is necessary because plurale tantum forms don't
                # have "p" in the defn template)
                for t in parsed.filter_templates():
                  if (tname(t) in ["ru-noun form"] and
                      template_head_matches(t, inflections, "checking for plural noun form") and (
                        plural_in_existing_defn_templates or
                        any([re.search(r"\bp\b", y) for y in blib.fetch_param_chain(t, "2", "g")]))):
                    found_plural_noun_form = True
            if found_plural_noun_form or found_plurale_tantum_lemma:
              warn("Creating new etymology for plural noun form and found existing plural noun form or noun lemma")

          pagemsg("Exists and has Russian section, appending to end of section")
          # [FIXME! Conceivably instead of inserting at end we should insert
          # next to any existing ===Noun=== (or corresponding POS, whatever
          # it is), in particular after the last one. However, this makes less
          # sense when we create separate etymologies, as we do. Conceivably
          # this would mean inserting after the last etymology section
          # containing an entry of the same part of speech.
          #
          # (Perhaps for now we should just skip creating entries if we find
          # an existing Russian entry?)] -- comment out of date
          if not sections[i]: # Erased section
            pagemsg("Blank section, creating it")
            comment = "Create Russian section for %s %s of %s, pos=%s" % (
              infltype, joined_infls, lemma, pos)
            sections[i] = newsection
          elif "\n===Etymology 1===\n" in sections[i]:
            j = 2
            while ("\n===Etymology %s===\n" % j) in sections[i]:
              j += 1
            pagemsg("Found multiple etymologies, adding new section \"Etymology %s\"" % (j))
            comment = "Append entry (Etymology %s) for %s %s of %s, pos=%s in existing Russian section" % (
              j, infltype, joined_infls, lemma, pos)
            sections[i] = ensure_two_trailing_nl(sections[i])

            sections[i] += "===Etymology %s===\n" % j + entrytextl4
          else:
            pagemsg("Wrapping existing text in \"Etymology 1\" and adding \"Etymology 2\"")
            comment = "Wrap existing Russian section in Etymology 1, append entry (Etymology 2) for %s %s of %s, pos=%s" % (
                infltype, joined_infls, lemma, pos)

            for j in range(2, len(subsections), 2):
              if re.match("^===+Etymology===+\n", subsections[j - 1]):
                pagemsg("Found Etymology section at position %s-%s" % (
                    j - 1, j))
                # Found etymology section; if there is a preceding section
                # such as Alternative forms, put the etymology section above
                # it.
                if j > 2:
                  pagemsg("Found Etymology section at position %s-%s, below other sections, moving up" % (
                    j - 1, j))
                  etymtext = subsections[j - 1:j + 1]
                  del subsections[j - 1:j + 1]
                  subsections[1:1] = etymtext
                  sections[i] = "".join(subsections)
                break

            # Wrap existing text in "Etymology 1" and increase the indent level
            # by one of all headers
            sections[i] = re.sub("^\n*==Russian==\n+", "", sections[i])
            wikilink_re = r"^(\{\{wikipedia\|.*?\}\})\n*"
            mmm = re.match(wikilink_re, sections[i])
            wikilink = (mmm.group(1) + "\n") if mmm else ""
            if mmm:
              sections[i] = re.sub(wikilink_re, "", sections[i])
            sections[i] = re.sub("^===Etymology===\n", "", sections[i])
            sections[i] = ("==Russian==\n" + wikilink + "\n===Etymology 1===\n" +
                ("\n" if sections[i].startswith("==") else "") +
                ensure_two_trailing_nl(re.sub("^==(.*?)==$", r"===\1===",
                  sections[i], 0, re.M)) +
                "===Etymology 2===\n" + entrytextl4)
        break
      elif m.group(1) > "Russian":
        pagemsg("Exists; inserting before %s section" % (m.group(1)))
        comment = "Create Russian section and entry for %s %s of %s, pos=%s; insert before %s section" % (
            infltype, joined_infls, lemma, pos, m.group(1))
        sections[i:i] = [newsection, "\n----\n\n"]
        break

    else: # else of for loop over sections, i.e. no break out of loop
      pagemsg("Exists; adding section to end")
      comment = "Create Russian section and entry for %s %s of %s, pos=%s; append at end" % (
          infltype, joined_infls, lemma, pos)

      if sections:
        sections[-1] = ensure_two_trailing_nl(sections[-1])
        sections += ["----\n\n", newsection]
      else:
        if not program_args.overwrite_page:
          notes.append("formerly empty")
        if pagehead.lower().startswith("#redirect"):
          warn("Page is redirect, overwriting")
          notes.append("overwrite redirect")
          pagehead = re.sub(r"#redirect *\[\[(.*?)\]\] *(<!--.*?--> *)*\n*",
              r"{{also|\1}}\n", pagehead, 0, re.I)
        elif not program_args.overwrite_page:
          warn("No language sections in current page")
        sections += [newsection]

    # End of loop over sections in existing page; rejoin sections
    newtext = pagehead + ''.join(sections) + pagetail

    if page.text != newtext:
      assert comment or notes

    # Eliminate newlines at the end of the text, because that is done
    # automatically when saving, and doing this avoids some unnecessary saves
    newtext = re.sub(r"\n*$", "", newtext)
    # Eliminate sequences of 3 or more newlines, which may come from
    # ensure_two_trailing_nl(). Add comment if none, in case of existing page
    # with extra newlines.
    newnewtext = re.sub(r"\n\n\n+", r"\n\n", newtext)
    if newnewtext != newtext and not comment and not notes:
      notes = ["eliminate sequences of 3 or more newlines"]
    newtext = newnewtext

    if page.text == newtext:
      pagemsg("No change in text")
    #elif verbose:
    #  pagemsg("Replacing <%s> with <%s>" % (page.text, newtext),
    #      simple = True)
    #  print_warnings()
    else:
      pagemsg("Text has changed")
      print_warnings()

    notestext = '; '.join(blib.group_notes(notes))
    if notestext:
      if comment:
        comment += " (%s)" % notestext
      else:
        comment = notestext

    return newtext, comment

  blib.do_edit(page, index, do_add_infl, save=program_args.save,
      verbose=program_args.verbose, diff=program_args.diff)

  return warnings

# Parse a noun/verb/adv form spec (from the user), one or more forms separated
# by commas, possibly including aliases. INFL_DICT is a dictionary
# mapping possible form codes to a tuple specifying the corresponding set of
# inflection codes in {{inflection of|...}}, or a list of multiple such tuples
# (for cases where a single form code refers to multiple inflections, such
# as with adjectives, where the form code gen_m specifies not only the genitive
# masculine singular but also the genitive neuter singular and the animate
# accusative masculine singular. ALIASES is a dictionary mapping aliases to
# form codes. Returns a list of tuples (FORM, INFLSETS), where FORM is a form
# code and INFLSETS is the corresponding value entry in INFL_DICT (a tuple of
# inflection codes, or a list of such tuples).
def parse_form_spec(formspec, infl_dict, aliases):
  forms = []
  for form in re.split(",", formspec):
    if form in aliases:
      for f in aliases[form]:
        if f not in forms:
          forms.append(f)
    elif form in infl_dict:
      if form not in forms:
        forms.append(form)
    else:
      raise ValueError("Invalid value '%s'" % form)

  infls = []
  for form in forms:
    infls.append((form, infl_dict[form]))
  return infls

def adj_form_inflection_list(old, special, has_nom_mp):
  return [
    # used with all variants
    ["nom_m", ("nom", "m", "s")],
    ["nom_f", ("nom", "f", "s")],
    ["nom_n", ("nom", "n", "s")],
    # not used with special; applies to all genders normally but only
    # feminine and neuter with old=1
    ["nom_p", [("nom", "f", "p"), ("nom", "n", "p")] if old and has_nom_mp
      else ("nom", "p")],
    # only used with old=1 or special; applies to the masculine and neuter if
    # special, but only masculine if old=1
    ["nom_mp", [("nom", "m", "p"), ("nom", "n", "p")] if special
      else ("nom", "m", "p")],
    # only used with special
    ["nom_fp", [("nom", "f", "p")]],
    # the remaining singulars and non-gendered plurals used with all variants
    # except special == "oba"
    ["gen_m", [("gen", "m", "s"), ("gen", "n", "s")]],
    ["gen_f", ("gen", "f", "s")],
    ["gen_p", [("gen", "p")]],
    ["dat_m", [("dat", "m", "s"), ("dat", "n", "s")]],
    ["dat_f", ("dat", "f", "s")],
    ["dat_p", ("dat", "p")],
    ["acc_m_an", ("an", "acc", "m", "s")],
    ["acc_m_in", ("in", "acc", "m", "s")],
    ["acc_f", ("acc", "f", "s")],
    ["acc_n", ("acc", "n", "s")],
    # the following two not used with special in ("dva", "oba"); applies to
    # all genders normally but only feminine and neuter with old=1
    ["acc_p_an", [("an", "acc", "f", "p"), ("an", "acc", "n", "p")]
      if old and has_nom_mp
      else ("an", "acc", "p")],
    ["acc_p_in", [("in", "acc", "f", "p"), ("in", "acc", "n", "p")]
      if old and has_nom_mp
      else ("in", "acc", "p")],
    # the following two only used with old=1 or special in ("dva", "oba");
    # applies to the masculine and neuter if special, but only masculine if
    # old=1
    ["acc_mp_an", [("an", "acc", "m", "p"), ("an", "acc", "n", "p")] if special
      else ("an", "acc", "m", "p")],
    ["acc_mp_in", [("in", "acc", "m", "p"), ("in", "acc", "n", "p")] if special
      else ("in", "acc", "m", "p")],
    # the following two only used with special in ("dva", "oba")
    ["acc_fp_an", ("an", "acc", "f", "p")],
    ["acc_fp_in", ("in", "acc", "f", "p")],
    # the next 6 are used with all variants except special == "oba"
    ["ins_m", [("ins", "m", "s"), ("ins", "n", "s")]],
    ["ins_f", ("ins", "f", "s")],
    ["ins_p", ("ins", "p")],
    ["pre_m", [("pre", "m", "s"), ("pre", "n", "s")]],
    ["pre_f", ("pre", "f", "s")],
    ["pre_p", ("pre", "p")],
    # the following two gendered plurals are only used with special == "cdva"
    ["acc_mp", [("acc", "m", "p"), ("acc", "n", "p")]],
    ["acc_fp", ("acc", "f", "p")],
    # the remaining gendered plurals are only used with special == "oba"
    ["gen_mp", [("gen", "m", "p"), ("gen", "n", "p")]],
    ["gen_fp", ("gen", "f", "p")],
    ["dat_mp", [("dat", "m", "p"), ("dat", "n", "p")]],
    ["dat_fp", ("dat", "f", "p")],
    ["ins_mp", [("ins", "m", "p"), ("ins", "n", "p")]],
    ["ins_fp", ("ins", "f", "p")],
    ["pre_mp", [("pre", "m", "p"), ("pre", "n", "p")]],
    ["pre_fp", ("pre", "f", "p")],
    # short forms
    ["short_m", ("short", "m", "s")],
    ["short_f", ("short", "f", "s")],
    ["short_n", ("short", "n", "s")],
    ["short_p", ("short", "p")]
  ]

def adj_form_inflection_dict(infltemp, args):
  return dict(adj_form_inflection_list(
    getparam(infltemp, "old").strip(),
    getparam(infltemp, "special").strip(),
    "nom_mp" in args))

adj_form_aliases = {
    "all":[x for x, y in adj_form_inflection_list(False, "", False)],
    "long": [
      "nom_m", "nom_f", "nom_n", "nom_p", "nom_mp", "nom_fp",
      "gen_m", "gen_f", "gen_p", "gen_mp", "gen_fp",
      "dat_m", "dat_f", "dat_p", "dat_mp", "dat_fp",
      "acc_m_an", "acc_m_in", "acc_f", "acc_n", "acc_p_an", "acc_p_in",
      "acc_mp_an", "acc_mp_in", "acc_fp_an", "acc_fp_in", "acc_mp", "acc_fp",
      "ins_m", "ins_f", "ins_p", "ins_mp", "ins_fp",
      "pre_m", "pre_f", "pre_p", "pre_mp", "pre_fp",
    ],
    "short":["short_m", "short_n", "short_f", "short_p"]
}

noun_form_inflection_list = [
  ["nom_sg", ("nom", "s")],
  ["gen_sg", ("gen", "s")],
  ["dat_sg", ("dat", "s")],
  ["acc_sg", ("acc", "s")],
  ["acc_sg_an", ("an", "acc", "s")],
  ["acc_sg_in", ("in", "acc", "s")],
  ["ins_sg", ("ins", "s")],
  ["pre_sg", ("pre", "s")],
  ["loc", ("loc", "s")],
  ["par", ("par", "s")],
  ["voc", ("voc", "s")],
  ["nom_pl", ("nom", "p")],
  ["gen_pl", ("gen", "p")],
  ["dat_pl", ("dat", "p")],
  ["acc_pl", ("acc", "p")],
  ["acc_pl_an", ("an", "acc", "p")],
  ["acc_pl_in", ("in", "acc", "p")],
  ["ins_pl", ("ins", "p")],
  ["pre_pl", ("pre", "p")],
]

def noun_form_inflection_dict(infltemp, args):
  return dict(noun_form_inflection_list)

noun_form_aliases = {
    "all":[x for x, y in noun_form_inflection_list],
    "sg":["nom_sg", "gen_sg", "dat_sg", "acc_sg", "acc_sg_an", "acc_sg_in",
      "ins_sg", "pre_sg"],
    "pl":["nom_pl", "gen_pl", "dat_pl", "acc_pl", "acc_pl_an", "acc_pl_in",
      "ins_pl", "pre_pl"],
}

verb_form_inflection_list = [
  # present tense
  ["pres_1sg", ("1", "s", "pres", "ind")],
  ["pres_2sg", ("2", "s", "pres", "ind")],
  ["pres_3sg", ("3", "s", "pres", "ind")],
  ["pres_1pl", ("1", "p", "pres", "ind")],
  ["pres_2pl", ("2", "p", "pres", "ind")],
  ["pres_3pl", ("3", "p", "pres", "ind")],
  # future tense
  ["futr_1sg", ("1", "s", "fut", "ind")],
  ["futr_2sg", ("2", "s", "fut", "ind")],
  ["futr_3sg", ("3", "s", "fut", "ind")],
  ["futr_1pl", ("1", "p", "fut", "ind")],
  ["futr_2pl", ("2", "p", "fut", "ind")],
  ["futr_3pl", ("3", "p", "fut", "ind")],
  # imperative
  ["impr_sg", ("2", "s", "imp")],
  ["impr_pl", ("2", "p", "imp")],
  # past
  ["past_m", ("m", "s", "past", "ind")],
  ["past_f", ("f", "s", "past", "ind")],
  ["past_n", ("n", "s", "past", "ind")],
  ["past_pl", ("p", "past", "ind")],
  ["past_m_short", ("short", "m", "s", "past", "ind")],
  ["past_f_short", ("short", "f", "s", "past", "ind")],
  ["past_n_short", ("short", "n", "s", "past", "ind")],
  ["past_pl_short", ("short", "p", "past", "ind")],
  # active participles
  ["pres_actv_part", ("pres", "act", "part")],
  ["past_actv_part", ("past", "act", "part")],
  # passive participles
  ["pres_pasv_part", ("pres", "pass", "part")],
  ["past_pasv_part", ("past", "pass", "part")],
  # adverbial participles
  ["pres_adv_part", ("pres", "adv", "part")],
  ["past_adv_part", ("past", "adv", "part")],
  ["past_adv_part_short", ("short", "past", "adv", "part")],
  # infinitive
  ["infinitive", ("infinitive")]
]
def verb_form_inflection_dict(infltemp, args):
  return dict(verb_form_inflection_list)

verb_form_aliases = {
    "all":[x for x, y in verb_form_inflection_list],
    "pres":["pres_1sg", "pres_2sg", "pres_3sg", "pres_1pl", "pres_2pl", "pres_3pl"],
    "futr":["futr_1sg", "futr_2sg", "futr_3sg", "futr_1pl", "futr_2pl", "futr_3pl"],
    "impr":["impr_sg", "impr_pl"],
    "past":["past_m", "past_f", "past_n", "past_pl", "past_m_short", "past_f_short", "past_n_short", "past_pl_short"],
    "part":["pres_actv_part", "past_actv_part", "pres_pasv_part", "past_pasv_part", "pres_adv_part", "past_adv_part", "past_adv_part_short"]
}

def split_ru_tr(form):
  if "//" in form:
    rutr = re.split("//", form)
    assert len(rutr) == 2
    ru, tr = rutr
    return (ru, tr)
  else:
    return (form, None)

def get_noun_gender_from_args(args):
  gender = re.split(",", args["g"])
  #gender = [re.sub("-p$", "", x) for x in gender]
  return gender

# Find the noun gender from the headword. Return None if no headword present,
# else a list of genders, which may be empty if headword doesn't specify
# genders.
def get_headword_noun_gender(section, pagemsg, expand_text):
  parsed = blib.parse_text(section)
  genders_seen = None
  for t in parsed.filter_templates():
    tnam = tname(t)
    new_genders = None
    # Skip indeclinable nouns, to avoid issues with proper names like
    # Альцгеймер, which have two headwords, a declined masculine one
    # followed by an indeclinable feminine one, and a masculine inflection
    # table.
    if tnam in ["ru-noun", "ru-proper noun"] and getparam(t, "3") != "-":
      new_genders = blib.fetch_param_chain(t, "2", "g")
    elif tnam in ["ru-noun+", "ru-proper noun+"]:
      new_genders = blib.fetch_param_chain(t, "g", "g")
      if not new_genders:
        args = rulib.fetch_noun_args(t, expand_text)
        if args is None:
          pagemsg("WARNING: Error generating args for headword template: %s" %
              str(t))
        else:
          new_genders = get_noun_gender_from_args(args)
    if new_genders:
      #new_genders = [re.sub("-p$", "", x) for x in new_genders]
      if genders_seen and new_genders != genders_seen:
        pagemsg("WARNING: Multiple conflicting gender specs in headwords, found both %s and %s" % (
          ",".join(genders_seen),
          ",".join(new_genders)))
      genders_seen = new_genders
  return genders_seen

# Find inflection templates and genders, skipping those under SKIP_POSES
# and issuing warnings for bad headers and bad level indentation, according
# to EXPECTED_HEADER and EXPECTED_POSES (see comment to create_forms()).
# Return a list of tuples of (TEMPLATE, GENDER). GENDER may come from the
# headword rather than the inflection (specifically, for nouns).
def find_inflection_templates(text, expected_header, expected_poses, skip_poses,
    is_inflection_template, find_gender, pagemsg, expand_text):
  templates = []

  sections = re.split("(^==[^=\n]+==\n)", text, 0, re.M)
  latest_genders = None
  for i in range(2, len(sections), 2):
    if sections[i-1] == "==Russian==\n":
      subsections = re.split("(^===+[^=\n]+===+\n)", sections[i], 0, re.M)
      headers_at_level = {}
      last_levelno = 2
      for j in range(2, len(subsections), 2):
        m = re.search("^(=+)([^=\n]+)", subsections[j-1])
        levelno = len(m.group(1))
        header = m.group(2)
        headers_at_level[levelno] = header
        if levelno - last_levelno > 1:
          pagemsg("WARNING: Misformatted header level (jump by %s - %s = %s, in section %s)" % (
            levelno, last_levelno, levelno - last_levelno, subsections[j-1].replace("\n", "")))
        last_levelno = levelno
        genders = find_gender(subsections[j], pagemsg, expand_text) if find_gender else None
        if genders is not None:
          latest_genders = genders
        parsed = blib.parse_text(subsections[j])
        for t in parsed.filter_templates():
          if is_inflection_template(t) and not getparam(t, "old").strip():
            if header != expected_header:
              pagemsg("WARNING: Expected inflection template under %s header but instead found under %s header" % (
                expected_header, header))
            pos_header = headers_at_level.get(levelno-1, None)
            if pos_header and pos_header not in expected_poses:
              pagemsg("WARNING: Inflection template under unexpected part of speech %s" %
                  pos_header)
            if pos_header not in skip_poses:
              templates.append((t, latest_genders))
            else:
              pagemsg("Skipping inflection template because under part of speech %s: %s" % (
                pos_header, str(t)))
  return templates

# Split forms where there are stress variants with corresponding stress-variant
# forms, e.g. #445 обеспе́чение,обеспече́ние with genitive singular
# обеспе́чения,обеспече́ния etc. where обеспе́чения should be assigned to
# обеспе́чение and обеспече́ния to обеспече́ние. Also handle cases like
# пе́тля,петля́ with one nominative plural пе́тли that matches one of the stress
# variants but should be assigned to both, and cases like до́говор,догово́р with
# genitive plural до́говоров,догово́ров,договоро́в where до́говоров goes with
# до́говор, догово́ров goes with догово́р, and до́говоров goes with both. Also
# don't get tripped up by instrumental singular of feminines, where there
# are four forms, two for each stress variant. We use the following algorithm:
# If there are two lemmas that differ only in stress, then extract the stem
# (remove [аяеоь] possibly with accent), and assign each form to one of the
# stems based on matching the prefix, and if we can't assign this way, assign
# to both, and if one stem ends up with no form, take the other one's.
# Return a list of tuples of (DICFORMS, ARGS), where ARGS is a table of
# form strings (multiple forms separated by commas), and DICFORMS is a list
# of (RUSSIAN, TRANSLIT) tuples.
def split_forms_with_stress_variants(args, forms_desired, dicforms, pagemsg,
    expand_text):
  if len(dicforms) == 1:
    return [(dicforms, args)]
  dicforms_printed = ",".join(["%s (%s)" % (dicru, dictr) if dictr else dicru for dicru, dictr in dicforms])
  pagemsg("WARNING: Multiple (%s) dictionary forms: %s" % (
    len(dicforms), dicforms_printed))
  if len(dicforms) > 2:
    pagemsg("WARNING: More than two (%s) dictionary forms, not sure how to split: %s" % (
      len(dicforms), dicforms_printed))
    return [(dicforms, args)]
  dicform1, dicform1tr = dicforms[0]
  dicform2, dicform2tr = dicforms[1]
  # We can just more or less ignore the translit and it works.
  #if dicform1tr:
  #  pagemsg("WARNING: Dictionary form 1 of 2 %s has translit %s, can't handle" % (dicform1, dicform1tr))
  #  return [(dicforms, args)]
  #if dicform2tr:
  #  pagemsg("WARNING: Dictionary form 2 of 2 %s has translit %s, can't handle" % (dicform2, dicform2tr))
  #  return [(dicforms, args)]
  if rulib.remove_accents(dicform1) != rulib.remove_accents(dicform2):
    pagemsg("WARNING: Two dictionary forms %s and %s aren't stress variants, not splitting" %
        (dicform1, dicform2))
    return [(dicforms, args)]
  dicform1_stem = re.sub("[аяеоьыий]́?$", "", dicform1)
  dicform2_stem = re.sub("[аяеоьыий]́?$", "", dicform2)
  # Also compute reduced/unreduced stem
  # The stem for reduce_stem() should preserve -й
  dicform1_stem_for_reduce = re.sub("[аяеоьыи]́?$", "", dicform1)
  dicform2_stem_for_reduce = re.sub("[аяеоьыи]́?$", "", dicform2)
  dicform1_epenthetic_vowel = dicform1.endswith(AC)
  dicform2_epenthetic_vowel = dicform2.endswith(AC)
  if re.search("[аяеоыи]́?$", dicform1):
    dicform1_reduced_stem = expand_text("{{#invoke:ru-common|dereduce_stem|%s||%s}}" %
        (dicform1_stem_for_reduce, "y" if dicform1_epenthetic_vowel else ""))
    dicform2_reduced_stem = expand_text("{{#invoke:ru-common|dereduce_stem|%s||%s}}" %
        (dicform2_stem_for_reduce, "y" if dicform2_epenthetic_vowel else ""))
  else:
    dicform1_reduced_stem = expand_text("{{#invoke:ru-common|reduce_stem|%s}}" %
        dicform1_stem_for_reduce)
    dicform2_reduced_stem = expand_text("{{#invoke:ru-common|reduce_stem|%s}}" %
        dicform2_stem_for_reduce)

  args1 = args.copy()
  args2 = args.copy()

  def doform(formname):
    if formname not in args:
      return
    forms1 = []
    forms2 = []
    # Remove links in case we're dealing with a _raw form
    argval = blib.remove_links(args[formname])
    formvals = re.split(",", argval)
    for formval in formvals:
      formlemma = None
      for formregex, lemma in manual_split_form_list:
        if re.search(formregex, formval):
          pagemsg("Found matching manually specified form regex %s, lemma %s" %
              (formregex, lemma))
          formlemma = lemma
          break
      if formlemma:
        if formlemma == dicform1:
          forms1.append(formval)
          continue
        elif formlemma == dicform2:
          forms2.append(formval)
          continue
        else:
          pagemsg("WARNING: Lemma %s doesn't match either lemma %s or %s" % (
            formlemma, dicform1, dicform2))
      if formval.startswith(dicform1_stem):
        forms1.append(formval)
      elif formval.startswith(dicform2_stem):
        forms2.append(formval)
      elif dicform1_reduced_stem and formval.startswith(dicform1_reduced_stem):
        forms1.append(formval)
      elif dicform2_reduced_stem and formval.startswith(dicform2_reduced_stem):
        forms2.append(formval)
      else:
        forms1.append(formval)
        forms2.append(formval)
    if not forms1:
      forms1 = forms2
    elif not forms2:
      forms2 = forms1
    args1[formname] = ",".join(forms1)
    args2[formname] = ",".join(forms2)
    pagemsg("For form %s=%s, split into %s for %s and %s for %s" % (
      formname, argval, args1[formname], dicform1, args2[formname],
      dicform2))

  for formname, inflsets in forms_desired:
    doform(formname)
    doform(formname + "_raw")
  return [([(dicform1, dicform1tr)], args1), ([(dicform2, dicform2tr)], args2)]

# Create required forms for all nouns/verbs/adjectives.
#
# LEMMAS_TO_PROCESS is a list of lemma pages to process. Entries are assumed
# to be without accents; if LEMMAS_NO_JO, they have е in place of ё. If empty,
# process all lemmas of the appropriate part of speech.
#
# LEMMAS_TO_OVERWRITE is a list of lemma pages the forms of which to overwrite
# the inflection codes of when an existing definition template (e.g.
# "inflection of") is found with matching lemma. Entries are without accents.
#
# LEMMAS_TO_NOT_OVERWRITE is a list of lemma pages, which should in general
# be the entire set of lemmas. Any non-lemma form that would overwrite the
# Russian section will not do so if the form is one of these pages.
# Entries are without accents.
#
# SAVE is as in create_inflection_entry(). STARTFROM and UPTO, if not None,
# delimit the range of pages to process (inclusive on both ends).
#
# FORMSPEC specifies the form(s) to do, a comma-separated list of form codes,
# possibly including aliases (e.g. 'all'). GENERATE_INFLECTION_DICT is a
# function of two arguments (the inflection template and a dictionary of forms)
# that returns a dictionary mapping possible form codes to a tuple of the
# corresponding inflection codes in {{inflection of|...}}, or a list of such
# tuples; see 'parse_form_spec'. FORM_ALIASES is a dictionary mapping aliases
# to form codes.
#
# POS specifies the part of speech (lowercase, singular, e.g. "verb").
# HEADTEMP specifies the headword template name (e.g. "head|ru|verb form" or
# "ru-noun form"). DICFORM_CODES specifies the form code for the dictionary
# form (e.g. "infinitive", "nom_m") or a list of such codes to try (e.g.
# ["nom_sg", "nom_pl"]).
#
# NOTE: There is special-case code that depends on the part of speech.
#
# EXPECTED_HEADER specifies the header that the inflection template (e.g.
# 'ru-decl-adj' for adjectives, 'ru-conj' for verbs) should be under
# (Declension or Conjugation); a warning will be issued if it's wrong.
# EXPECTED_POSES is a list of the parts of speech that the inflection template
# should be under (e.g. ["Noun", "Proper noun"]); a warning will be issued if
# an unexpected part of speech is found. A warning is also issued if the
# level indentation is wrong. SKIP_POSES is a list of parts of speech to skip
# the inflections of (e.g. ["Participle", "Pronoun"] for adjectives).
# IS_INFLECTION_TEMPLATE is a function that is passed one argument, a template,
# and should indicate if it's an inflection template. GENERATE_FORMS
# is a function that's passed two arguments, an inflection template and
# an 'expand_text' function, and should return an expansion of the template
# into a string identifying the set of forms, of the form
# 'FORMCODE1=VALUE1|FORMCODE2=VALUE2|...'.
#
# IS_LEMMA_TEMPLATE is a function that is passed one argument, a template,
# and should indicate if it's a lemma template (e.g. 'ru-adj' for adjectives).
# This is used to issue warnings in case of non-lemma forms where there's
# a corresponding lemma (NOTE, this situation could be legitimate for nouns).
#
# GET_GENDER, if supplied, should be a function of three arguments (a template,
# the form code and the arguments resulting from calling CREATE_FORM_GENERATOR
# and parsing the result into a dictionary). It should return a list of gender
# codes to be inserted into the headword template. (NOTE: This is special-cased
# for verbs.)
#
# SKIP_INFLECTIONS, if supplied, should be a function of three arguments, the
# form name, Russian and translit (which may be missing), and should return
# true if the particular form value in question is to be skipped. This is
# used e.g. to skip periphrastic future forms.
#
# PPPP_SET is a set of perfective past passive participles extracted in a
# separate run, which will not be considered as imperfective participles even
# if found in an imperfective conjugation.
def create_forms(lemmas_to_process, lemmas_no_jo, lemmas_to_overwrite,
    lemmas_to_not_overwrite, program_args, save, startFrom, upTo, formspec,
    generate_inflection_dict, form_aliases, pos, headtemp, dicform_codes,
    expected_header, expected_poses, skip_poses, is_inflection_template,
    generate_forms, is_lemma_template, get_gender=None,
    skip_inflections=None, pppp_set=None):

  if type(dicform_codes) is not list:
    dicform_codes = [dicform_codes]

  # If lemmas_to_process, we want to process the lemmas in the order they're
  # in this list, but the lemmas in the list have е in place of ё, so we need
  # to do some work to get the corresponding pages with ё in them.
  if lemmas_to_process and lemmas_no_jo:
    lemmas_to_process_set = set(lemmas_to_process)
    unaccented_lemmas = {}
    for index, page in blib.cat_articles("Russian %ss" % pos):
      pagetitle = str(page.title())
      unaccented_title = rulib.make_unstressed_ru(pagetitle)
      if unaccented_title in lemmas_to_process_set:
        if unaccented_title in unaccented_lemmas:
          unaccented_lemmas[unaccented_title].append(pagetitle)
        else:
          unaccented_lemmas[unaccented_title] = [pagetitle]
    pagetitles_to_process = []
    for lemma in lemmas_to_process:
      if lemma in unaccented_lemmas:
        pagetitles_to_process.extend(unaccented_lemmas[lemma])
      else:
        msg("WARNING: Can't find pages to match lemma %s" % lemma)
    pages_to_process = ((index, pywikibot.Page(site, page)) for index, page in
        blib.iter_items(pagetitles_to_process, startFrom, upTo))
  elif lemmas_to_process:
    pages_to_process = ((index, pywikibot.Page(site, page)) for index, page in
        blib.iter_items(lemmas_to_process, startFrom, upTo))
  else:
    pages_to_process = blib.cat_articles("Russian %ss" % pos, startFrom, upTo)

  for index, page in pages_to_process:
    pagetitle = str(page.title())
    def pagemsg(txt):
      msg("Page %s %s: %s" % (index, pagetitle, txt))
    def errpagemsg(txt):
      pagemsg(txt)
      errmsg("Page %s %s: %s" % (index, pagetitle, txt))
    def expand_text(tempcall):
      return blib.expand_text(tempcall, pagetitle, pagemsg, verbose)
    if pagetitle.startswith("-"):
      pagemsg("Skipping suffix entry")
      continue
    if pagetitle in skip_lemma_pages:
      pagemsg("WARNING: Skipping lemma because in skip_lemma_pages")
      continue

    # Find the inflection templates. Rather than just look for all inflection
    # templates, we may skip those under certain parts of speech, e.g.
    # participles for adjective forms. This is to avoid the issue with
    # преданный, which has one adjectival inflection as an adjective
    # and a different one as a participle.
    inflection_templates = find_inflection_templates(page.text, expected_header,
        expected_poses, skip_poses, is_inflection_template,
        get_headword_noun_gender if pos == "noun" and pagetitle not in ignore_headword_gender else None, pagemsg,
        expand_text)
    if len(inflection_templates) > 1 and pos == "adjective":
      pagemsg("WARNING: Multiple inflection templates for %s" % pagetitle)
    # Check for multiple animacies in nouns; if so, make sure m acc sg and
    # all acc pl reflect the animacy
    multiple_noun_animacies = False
    if pos == "noun":
      saw_animate = False
      saw_inanimate = False
      for t, headword_gender in inflection_templates:
        if headword_gender:
          for g in headword_gender:
            if re.search(r"\ban\b", g):
              saw_animate = True
            if re.search(r"\bin\b", g):
              saw_inanimate = True
      if saw_animate and saw_inanimate:
        multiple_noun_animacies = True
        pagemsg("Found multiple animacies for noun")

    for infltemp, headword_gender in inflection_templates:
      result = generate_forms(infltemp, expand_text)
      if not result:
        pagemsg("WARNING: Error generating %s forms, skipping" % pos)
        continue
      args = blib.split_generate_args(result)
      for dicform_code in dicform_codes:
        if dicform_code in args:
          break
      else:
        pagemsg("WARNING: No dictionary form available among putative codes %s, skipping" %
            ",".join(dicform_codes))
        continue
      if dicform_code != dicform_codes[0]:
        pagemsg("create_forms: Using non-default dictionary form code %s" % dicform_code)
      dicforms = re.split(",", args[dicform_code])
      if len(dicforms) > 1:
        pagemsg("create_forms: Found multiple dictionary forms: %s" % args[dicform_code])
      forms_desired = parse_form_spec(formspec, generate_inflection_dict(infltemp, args),
        form_aliases)
      # Fetch dictionary forms, remove accents on monosyllables
      dicforms = [split_ru_tr(dicform) for dicform in dicforms]
      dicforms = [(rulib.remove_monosyllabic_accents(dicru),
        rulib.remove_tr_monosyllabic_accents(dictr)) for dicru, dictr in dicforms]
      # Group dictionary forms by Russian, to group multiple translits
      dicforms = rulib.group_translits(dicforms, pagemsg, verbose)
      dicforms_args_sets = split_forms_with_stress_variants(args, forms_desired,
          dicforms, pagemsg, expand_text)
      # If multiple stress variants, allow stress mismatch when comparing
      # definitions to see if we can insert a subsection next to an existing
      # one rather than create a new etymology section, so the stress variants
      # end up in the same etymology section
      allow_stress_mismatch = len(dicforms_args_sets) > 1 or pagetitle in allow_stress_mismatch_list
      for split_dicforms, split_args in dicforms_args_sets:
        for dicformru, dicformtr in split_dicforms:
          for formname, inflsets in forms_desired:
            # Skip the dictionary form; also skip forms that don't have
            # listed inflections (e.g. singulars with plural-only nouns,
            # animate/inanimate variants when a noun isn't bianimate):
            if formname != dicform_code and formname in split_args and split_args[formname]:
              # Warn if footnote symbol found; may need to manually add a note
              if formname + "_raw" in split_args:
                raw_form = re.sub("△", "", blib.remove_links(split_args[formname + "_raw"]))
                if split_args[formname] != raw_form:
                  pagemsg("WARNING: Raw form %s=%s contains footnote symbol (notes=%s)" % (
                    formname, split_args[formname + "_raw"],
                    infltemp.has("notes") and "<%s>" % getparam(infltemp, "notes") or "NO NOTES"))

              # Group inflections by unaccented Russian, so we process
              # multiple accent variants together
              formvals_by_pagename = OrderedDict()
              formvals = re.split(",", split_args[formname])
              if len(formvals) > 1:
                pagemsg("create_forms: Found multiple form values for %s=%s, dictionary form %s%s" %
                    (formname, split_args[formname], dicformru, dicformtr and " (%s)" % dicformtr or ""))
              for formval in formvals:
                formvalru, formvaltr = split_ru_tr(formval)
                formval_no_accents = rulib.remove_accents(formvalru)
                if skip_inflections and skip_inflections(formname, formvalru, formvaltr):
                  pagemsg("create_forms: Skipping %s=%s%s" % (formname, formvalru,
                    formvaltr and " (%s)" % formvaltr or ""))
                elif formval_no_accents in formvals_by_pagename:
                  formvals_by_pagename[formval_no_accents].append((formvalru, formvaltr))
                else:
                  formvals_by_pagename[formval_no_accents] = [(formvalru, formvaltr)]
              # Process groups of inflections
              formvals_by_pagename_items = list(formvals_by_pagename.items())
              if len(formvals_by_pagename_items) > 1:
                pagemsg("create_forms: For form %s, found multiple page names %s" % (
                  formname, ",".join("%s" % formval_no_accents for formval_no_accents, inflections in formvals_by_pagename_items)))
              for formval_no_accents, inflections in formvals_by_pagename_items:
                inflections = [(rulib.remove_monosyllabic_accents(infl),
                  rulib.remove_tr_monosyllabic_accents(infltr)) for infl, infltr in inflections]
                inflections_printed = ",".join("%s%s" %
                    (infl, " (%s)" % infltr if infltr else "")
                    for infl, infltr in inflections)

                if formval_no_accents == rulib.remove_accents(dicformru):
                  pagemsg("create_forms: Skipping form %s=%s because would go on lemma page" % (formname, inflections_printed))
                else:
                  if len(inflections) > 1:
                    pagemsg("create_forms: For pagename %s, found multiple inflections %s" % (
                      formval_no_accents, inflections_printed))
                  # Group inflections by Russian, to group multiple translits
                  inflections = rulib.group_translits(inflections, pagemsg, verbose)

                  if type(inflsets) is not list:
                    inflsets = [inflsets]
                  form_gender = headword_gender or (get_gender(infltemp, formname, split_args) if get_gender else [])
                  # This isn't agreed upon; probably masculine is better
                  #if pos == "noun":
                  #  # Nouns with plural in -ята, -ата are neuter in the plural
                  #  # in the corresponding forms, even though the singular is
                  #  # masc. This is tricky with words like ребёнок and мальчонок
                  #  # that have two plurals, one in -и and one in -ата/ята.
                  #  if ("nom_pl" in split_args and
                  #      re.search(r"[яа]́?та(,|$)", split_args["nom_pl"]) and
                  #      re.search(r"[яа]т(|а|ам|ами|ах)$", formval_no_accents)):
                  #    form_gender = [re.sub(r"\bm\b", "n", g) for g in form_gender]

                  if formname == "past_pasv_part" and form_gender == ["impf"]:
                    filtered_inflections = []
                    for infl, infltr in inflections:
                      if pppp_set and infl in pppp_set:
                        pagemsg("create_forms: Skipping imperfective past passive participle %s%s because in perfective past passive participle list"
                            % (infl, " (%s)" % infltr if infltr else ""))
                      else:
                        filtered_inflections.append((infl, infltr))
                    if not filtered_inflections:
                      continue
                    inflections = filtered_inflections

                  for inflset in inflsets:
                    inflset_gender = form_gender
                    # Add perfective or imperfective to verb inflection codes
                    # depending on gender, then clear gender so we don't set
                    # it on the headword.
                    if pos == "verb":
                      assert inflset_gender == ["pf"] or inflset_gender == ["impf"]
                      if inflset_gender == ["pf"]:
                        inflset = inflset + ("pfv",)
                      else:
                        inflset = inflset + ("impfv",)
                      inflset_gender = []
                    # If we're dealing with plural noun inflection, make sure
                    # gender contains plural.
                    if pos == "noun" and "_pl" in formname:
                      new_inflset_gender = []
                      for g in inflset_gender:
                        if not re.search(r"\bp\b", g):
                          if not g:
                            g = "p"
                          else:
                            g += "-p"
                        if g not in new_inflset_gender:
                          new_inflset_gender.append(g)
                      inflset_gender = new_inflset_gender
                    # For nouns with multiple animacies where we're dealing
                    # with an accusative that varies depending on animacy,
                    # make sure the animacy is in the inflection codes.
                    # The accusative plural always varies depending on animacy;
                    # the accusative singular varies for masculine-type nouns
                    # and for neuter-type nouns that are actually masculine.
                    # We check for this by seeing if one of the genders is
                    # masculine and the accusative singular is the same as
                    # the nom sg or gen sg (which will filter out feminine-type
                    # nouns that have masculine gender, such as дядя).
                    if (pos == "noun" and multiple_noun_animacies and
                        "an" not in inflset and "in" not in inflset and
                        (formname == "acc_pl" or formname == "acc_sg" and
                          [re.search(r"\bm\b", g) for g in inflset_gender] and
                          (split_args["acc_sg"] == split_args.get("nom_sg", None) or
                            split_args["acc_sg"] == split_args.get("gen_sg", None)))):
                      found_animate = any(re.search(r"\ban\b", g) for g in inflset_gender)
                      found_inanimate = any(re.search(r"\bin\b", g) for g in inflset_gender)
                      if found_animate and found_inanimate:
                        pagemsg("WARNING: Something wrong, lemma is bianimate (gender=%s) and animacy codes not inflset %s" % (
                          ",".join(inflset_gender), "|".join(inflset)))
                      elif found_animate:
                        newinflset = ("an",) + inflset
                        pagemsg("Multiple noun animacies, adding animate form code, modifying inflset from %s to %s" %
                            ("|".join(inflset), "|".join(newinflset)))
                        inflset = newinflset
                      elif found_inanimate:
                        newinflset = ("in",) + inflset
                        pagemsg("Multiple noun animacies, adding inanimate form code, modifying inflset from %s to %s" %
                            ("|".join(inflset), "|".join(newinflset)))
                        inflset = newinflset
                    # For plurale tantum nouns, don't include "plural" in
                    # inflection codes.
                    if pos == "noun" and dicform_code == "nom_pl":
                      inflset = tuple(x for x in inflset if x != "p")
                    # For numerals, don't include "singular" or "plural"
                    # in inflection codes when the numerals don't vary
                    # according to number.
                    if pos == "numeral" and numeral_is_tantum(infltemp, dicform_code):
                      inflset = tuple(x for x in inflset if x not in ["s", "p"])
                    # Frob the locative of nouns, removing в, на, в/на, на/в,
                    # and variants with во.
                    if pos == "noun" and formname == "loc":
                      def frob_locative(ru, tr):
                        newru = re.sub("^(во?|на|во?/на|на/во?) ", "", ru)
                        if ru != newru:
                          pagemsg("Modifying locative from %s to %s" %
                              (ru, newru))
                          ru = newru
                        if tr:
                          tr = re.sub("^(v|na|v/na|na/v) ", "", tr)
                        return ru, tr
                      inflections = [frob_locative(ru, tr) for ru, tr in
                          inflections]
                      # If space in locative and not in lemma, then presumably
                      # there's some other prefix we weren't able to remove,
                      # so skip creating locative
                      skip_locative = False
                      for ru, tr in inflections:
                        if " " in ru and " " not in dicformru:
                          pagemsg("WARNING: Space in locative %s but not in lemma %s, skipping" %
                              (ru, dicformru))
                          skip_locative = True
                          break
                      if skip_locative:
                        continue
                    past_f_end_stressed = False
                    if pos == "verb" and "part" in inflset:
                      inflset = tuple(x for x in inflset if x != "part")
                      header_pos = "Participle"
                      deftemp = "participle of"
                      deftemp_needs_lang = True
                      deftemp_allows_multiple_tag_sets = True
                      if "pres" in inflset:
                        headtemp_tense = "present"
                      else:
                        if "past" not in inflset:
                          pagemsg("WARNING: Something wrong, neither 'pres' nor 'past' in participle inflset: %s"
                            % (",".join(inflset)))
                        headtemp_tense = "past"
                      if "act" in inflset:
                        headtemp_voice = "active"
                      elif "adv" in inflset:
                        headtemp_voice = "adverbial"
                      else:
                        if "pass" not in inflset:
                          pagemsg("WARNING: Something wrong, none of 'act', 'pass' or 'adv' in participle inflset: %s"
                            % (",".join(inflset)))
                        headtemp_voice = "passive"
                      headtemp_pos = "%s %s participle" % (headtemp_tense, headtemp_voice)
                      our_headtemp = "head|ru|%s" % headtemp_pos
                      if "past_f" in split_args:
                        saw_end_stressed_past_f = False
                        saw_non_end_stressed_past_f = False
                        formvals = re.split(",", split_args["past_f"])
                        for formval in formvals:
                          formvalru, formvaltr = split_ru_tr(formval)
                          if formvalru.endswith(AC):
                            saw_end_stressed_past_f = True
                          else:
                            saw_non_end_stressed_past_f = True
                        if saw_non_end_stressed_past_f and saw_end_stressed_past_f:
                          pagemsg("WARNING: Saw both ending-stressed and non-ending-stressed past_f when determining short participle type: %s" %
                              split_args["past_f"])
                        past_f_end_stressed = saw_end_stressed_past_f
                    else:
                      header_pos = pos.capitalize()
                      deftemp = ["infl of", "inflection of"]
                      deftemp_needs_lang = True
                      deftemp_allows_multiple_tag_sets = True
                      our_headtemp = headtemp
                    create_inflection_entry(program_args, save, index,
                      inflections, dicformru, dicformtr, header_pos,
                      "%s form %s" % (pos, formname), "dictionary form",
                      our_headtemp, "", deftemp, inflset,
                      inflset_gender, is_lemma_template=is_lemma_template,
                      lemmas_to_overwrite=lemmas_to_overwrite,
                      lemmas_to_not_overwrite=lemmas_to_not_overwrite,
                      allow_stress_mismatch_in_defn=allow_stress_mismatch,
                      deftemp_needs_lang=deftemp_needs_lang,
                      deftemp_allows_multiple_tag_sets=deftemp_allows_multiple_tag_sets,
                      past_f_end_stressed=past_f_end_stressed)

def skip_future_periphrastic(formname, ru, tr):
  return re.search(r"^(бу́ду|бу́дешь|бу́дет|бу́дем|бу́дете|бу́дут) ", ru)

def get_verb_gender(t, formname, args):
  gender = re.sub("-.*", "", getparam(t, "1"))
  assert gender in ["pf", "impf"]
  return [gender]

def create_verb_forms(save, startFrom, upTo, formspec, lemmas_to_process,
    lemmas_no_jo, lemmas_to_overwrite, lemmas_to_not_overwrite, program_args,
    pppp_set):
  create_forms(lemmas_to_process, lemmas_no_jo, lemmas_to_overwrite,
      lemmas_to_not_overwrite, program_args, save, startFrom, upTo, formspec,
      verb_form_inflection_dict,
      # NOTE: 'head|ru|verb form' will be overridden with participles
      verb_form_aliases, "verb", "head|ru|verb form",
      "infinitive", "Conjugation", ["Verb", "Idiom"], [],
      lambda t:tname(t) == "ru-conj",
      lambda t, expand_text: expand_text(re.sub(r"^\{\{ru-conj", "{{ru-generate-verb-forms", str(t))),
      lambda t:tname(t) == "ru-verb",
      get_gender=get_verb_gender,
      skip_inflections=skip_future_periphrastic,
      pppp_set=pppp_set)

def get_adj_gender(t, formname, args):
  if "short" in formname:
    m = re.search("_([mfnp])", formname)
    assert m
    return [m.group(1)]
  else:
    return []

def generate_adj_forms(t, expand_text):
  if tname(t) == "ru-decl-adj":
    return expand_text(re.sub(r"^\{\{ru-decl-adj", "{{ru-generate-adj-forms", str(t)))
  else:
    assert tname(t) == "ru-decl-adj-irreg"
    return expand_text(re.sub(r"^\{\{ru-decl-adj-irreg\s*\|", r"{{ru-generate-adj-forms|-|manual|",
      str(t)))

def create_adj_forms(save, startFrom, upTo, formspec, lemmas_to_process,
    lemmas_no_jo, lemmas_to_overwrite, lemmas_to_not_overwrite, program_args):
  create_forms(lemmas_to_process, lemmas_no_jo, lemmas_to_overwrite,
      lemmas_to_not_overwrite, program_args, save, startFrom, upTo, formspec,
      adj_form_inflection_dict, adj_form_aliases,
      "adjective", "head|ru|adjective form", "nom_m",
      # Proper noun can occur because names are formatted using {{ru-decl-adj}}
      # with decl type 'proper'.
      "Declension", ["Adjective", "Participle", "Pronoun", "Proper noun"],
      ["Participle", "Pronoun", "Proper noun"],
      lambda t:tname(t) in ["ru-decl-adj", "ru-decl-adj-irreg"],
      generate_adj_forms,
      lambda t:tname(t) == "ru-adj",
      #get_gender=get_adj_gender
      )

def create_numeral_adj_forms(save, startFrom, upTo, formspec, lemmas_to_process,
      lemmas_no_jo, lemmas_to_overwrite, lemmas_to_not_overwrite, program_args):
  create_forms(lemmas_to_process, lemmas_no_jo, lemmas_to_overwrite,
      lemmas_to_not_overwrite, program_args, save, startFrom, upTo, formspec,
      adj_form_inflection_dict, adj_form_aliases,
      "numeral", "head|ru|numeral form", ["nom_m", "nom_mp"],
      "Declension", ["Numeral"], [],
      lambda t:tname(t) in ["ru-decl-adj", "ru-decl-adj-irreg"],
      generate_adj_forms,
      lambda t:tname(t) == "head" and getparam(t, "1") == "ru" and getparam(t, "2") == "numeral"
      #get_gender=get_adj_gender
      )

def create_pronoun_adj_forms(save, startFrom, upTo, formspec, lemmas_to_process,
      lemmas_no_jo, lemmas_to_overwrite, lemmas_to_not_overwrite, program_args):
  create_forms(lemmas_to_process, lemmas_no_jo, lemmas_to_overwrite,
      lemmas_to_not_overwrite, program_args, save, startFrom, upTo, formspec,
      adj_form_inflection_dict, adj_form_aliases,
      "pronoun", "head|ru|pronoun form", ["nom_m", "nom_mp"],
      "Declension", ["Pronoun"], [],
      lambda t:tname(t) in ["ru-decl-adj", "ru-decl-adj-irreg"],
      generate_adj_forms,
      lambda t:tname(t) == "head" and getparam(t, "1") == "ru" and getparam(t, "2") == "pronoun"
      #get_gender=get_adj_gender
      )

# WARNING: This isn't used unless the noun is in ignore_headword_gender;
# see get_headword_noun_gender().
def get_noun_gender(t, formname, args):
  return get_noun_gender_from_args(args)

def create_noun_forms(save, startFrom, upTo, formspec, lemmas_to_process,
      lemmas_no_jo, lemmas_to_overwrite, lemmas_to_not_overwrite, program_args):
  create_forms(lemmas_to_process, lemmas_no_jo, lemmas_to_overwrite,
      lemmas_to_not_overwrite, program_args, save, startFrom, upTo, formspec,
      noun_form_inflection_dict, noun_form_aliases, "noun", "ru-noun form",
      ["nom_sg", "nom_pl"], "Declension", ["Noun", "Proper noun"], [],
      lambda t:tname(t) == "ru-noun-table",
      lambda t, expand_text: expand_text(re.sub(r"^\{\{ru-noun-table", "{{ru-generate-noun-args", str(t))),
      lambda t:tname(t) in ["ru-noun", "ru-proper noun", "ru-noun+", "ru-proper noun+"],
      get_gender=get_noun_gender)

def numeral_is_tantum(t, dicform_code):
  # If true, we should remove "singular" or "plural" from the inflection.
  # This applies to numerals that don't vary by number, so that it's not
  # obvious whether to classify them as singular or plural. It doesn't
  # apply to один, оба, тысяча, миллион, etc. which have both singular
  # and plural forms.
  if tname(t) in ["ru-decl-adj", "ru-adj-table"]:
    return dicform_code == "nom_mp" and not getparam(t, "special").strip() == "oba"
  if tname(t) == "ru-noun-table":
    return dicform_code == "nom_pl" or getparam(t, "n")[0:1] in ["s", "p"]
  return tname(t) in ["ru-decl-noun-unc", "ru-decl-noun-pl"]

def generate_numeral_noun_forms(t, expand_text):
  if tname(t) == "ru-noun-table":
    temp_to_expand = str(t)
  elif tname(t) == "ru-decl-noun":
    temp_to_expand = "{{ru-noun-table|a|%s|manual|a=%s|nom_sg=%s|nom_pl=%s|gen_sg=%s|gen_pl=%s|dat_sg=%s|dat_pl=%s|acc_sg=%s|acc_pl=%s|ins_sg=%s|ins_pl=%s|pre_sg=%s|pre_pl=%s|loc=%s|voc=%s|notes=%s}}" % (
      getparam(t, "1"),
      getparam(t, "a") or "bi",
      getparam(t, "1"),
      getparam(t, "2"),
      getparam(t, "3"),
      getparam(t, "4"),
      getparam(t, "5"),
      getparam(t, "6"),
      getparam(t, "7"),
      getparam(t, "8"),
      getparam(t, "9"),
      getparam(t, "10"),
      # Get rid of preposition 'о' in the prepositional case if it exists
      re.sub("^о ", "", getparam(t, "11")),
      re.sub("^о ", "", getparam(t, "12")),
      getparam(t, "13"),
      getparam(t, "14"),
      getparam(t, "notes")
    )
  else:
    assert tname(t) in ["ru-decl-noun-unc", "ru-decl-noun-pl"]
    temp_to_expand = "{{ru-noun-table|a|%s|manual|a=%s|n=sg|nom_sg=%s|gen_sg=%s|dat_sg=%s|acc_sg=%s|ins_sg=%s|pre_sg=%s|loc=%s|voc=%s}}" % (
      getparam(t, "1"),
      getparam(t, "a") or "bi",
      getparam(t, "1"),
      getparam(t, "2"),
      getparam(t, "3"),
      getparam(t, "4"),
      getparam(t, "5"),
      # Get rid of preposition 'о' in the prepositional case if it exists
      re.sub("^о ", "", getparam(t, "6")),
      getparam(t, "7"),
      getparam(t, "8")
    )
  return expand_text(re.sub(r"^\{\{ru-noun-table", "{{ru-generate-noun-args",
    temp_to_expand))

def create_numeral_noun_forms(save, startFrom, upTo, formspec, lemmas_to_process,
      lemmas_no_jo, lemmas_to_overwrite, lemmas_to_not_overwrite, program_args):
  create_forms(lemmas_to_process, lemmas_no_jo, lemmas_to_overwrite,
      lemmas_to_not_overwrite, program_args, save, startFrom, upTo, formspec,
      noun_form_inflection_dict, noun_form_aliases, "numeral", "head|ru|numeral form",
      ["nom_sg", "nom_pl"], "Declension", ["Numeral"], [],
      lambda t:tname(t) in ["ru-noun-table", "ru-decl-noun", "ru-decl-noun-unc", "ru-decl-noun-pl"],
      generate_numeral_noun_forms,
      lambda t:tname(t) == "head" and getparam(t, "1") == "ru" and getparam(t, "2") == "numeral")


pa = blib.create_argparser("Create Russian inflection entries")
pa.add_argument("--adj-form",
    help="""Do specified adjective-form inflections, a comma-separated list.
Each element is compatible with the override specifications used in
'ru-decl-adj': nom_m, nom_n, nom_f, nom_p, nom_mp, gen_m, gen_f, gen_p,
dat_m, dat_f, dat_p, acc_f, acc_n, ins_m, ins_f, ins_p, pre_m, pre_f, pre_p,
short_m, short_n, short_f, short_p. Also possible is 'all' (all forms),
'long' (all long forms), 'short' (all short forms). The nominative masculine
singular form will not be created even if specified, because it is the
same as the dictionary/lemma form. Also, non-existent forms for particular
adjectives will not be created.""")
pa.add_argument("--noun-form",
    help="""Do specified noun-form inflections, a comma-separated list.
Each element is compatible with the override specifications used in
'ru-noun-table': nom_sg, gen_sg, dat_sg, acc_sg, ins_sg, pre_sg, nom_pl,
gen_pl, dat_pl, acc_pl, ins_pl, pre_pl, acc_sg_an, acc_sg_in, acc_pl_an,
acc_pl_in. Also possible is 'all' (all forms), 'sg' (all singular forms),
'pl' (all plural forms). The nominative singular form will not be created
even if specified, because it is the same as the dictionary/lemma form,
nor will accusative singulars that have the same form as the nominative
singular (or accusative plurals that have the same form as the nominative
plural, for pluralia tantum). Also, non-existent forms for particular nouns
will not be created. Note that the animate/inanimate accusative variants
are only for bianimate nouns.""")
pa.add_argument("--verb-form",
    help="""Do specified verb-form inflections, a comma-separated list.
Each element is compatible with the specifications used in module ru-verb:
pres_1sg, pres_2sg, pres_3sg, pres_1pl, pres_2pl, pres_3pl;
futr_1sg, futr_2sg, futr_3sg, futr_1pl, futr_2pl, futr_3pl;
impr_sg, impr_pl;
past_m, past_f, past_n, past_pl;
past_m_short, past_f_short, past_n_short, past_pl_short;
pres_actv_part, past_actv_part, pres_pasv_part, past_pasv_part,
pres_adv_part, past_adv_part, past_adv_part_short;
infinitive (ignored). Also possible is 'all' (all forms), 'pres' (all present
forms), 'futr' (all future forms), 'impr' (all imperative forms), 'past'
(all past forms). The infinitive form will not be created even if specified,
because it is the same as the dictionary/lemma form. Also, non-existent forms
for particular verbs will not be created.""")
pa.add_argument("--lemmafile",
    help="""List of lemmas to process, without accents. May have е in place
of ё; see '--lemmas-no-jo'.""")
pa.add_argument("--lemmas",
    help="""Comma-separated list of lemmas to process. May have е in place
of ё; see '--lemmas-no-jo'.""")
pa.add_argument("--lemmas-no-jo",
    help="""If specified, lemmas specified using --lemmafile have е in place of ё.""",
    action="store_true")
pa.add_argument("--perfective-past-passive-participles", "--pppp",
    help="""File containing list of extracted perfective past passive
participles, which won't be considered imperfective participles even if found
in an imperfective conjugation. Entries are with accents.""")
pa.add_argument("--overwrite-lemmas",
    help="""File containing list of lemmas where the current inflections are
considered to have errors in them (e.g. due to the conjugation template having
incorrect aspect) and thus should be overwritten. Entries are without
accents.""")
pa.add_argument("--lemmas-to-not-overwrite",
    help="""File containing list of lemma pages, which should in general
be the entire set of lemmas. Any non-lemma form that would overwrite the
Russian section (--overwrite-page) will not do so if the form is one of
these pages. Entries are without accents.""")
pa.add_argument("--overwrite-page", action="store_true",
    help="""If specified, overwrite the entire existing page of inflections.
Won't do this if it finds "Etymology N", unless --overwrite-etymologies is
given. WARNING: Be careful!""")
pa.add_argument("--overwrite-etymologies", action="store_true",
    help="""If specified and --overwrite-page, overwrite the entire existing
page of inflections even if "Etymology N". WARNING: Be careful!""")
pa.add_argument("--numeral", action="store_true",
    help="""If specified, create numeral forms instead of noun/adj forms.""")
pa.add_argument("--pronoun", action="store_true",
    help="""If specified, create pronoun forms instead of noun/adj forms.""")

params = pa.parse_args()
startFrom, upTo = blib.parse_start_end(params.start, params.end)

if params.lemmafile:
  lemmas_to_process = list(blib.yield_items_from_file(params.lemmafile))
elif params.lemmas:
  lemmas_to_process = blib.split_arg(params.lemmas)
else:
  lemmas_to_process = []
if params.overwrite_lemmas:
  lemmas_to_overwrite = list(blib.yield_items_from_file(params.overwrite_lemmas))
else:
  lemmas_to_overwrite = []
if params.lemmas_to_not_overwrite:
  lemmas_to_not_overwrite = list(blib.yield_items_from_file(params.lemmas_to_not_overwrite))
else:
  lemmas_to_not_overwrite = []
if params.perfective_past_passive_participles:
  pppp_set = set(blib.yield_items_from_file(params.perfective_past_passive_participles))
else:
  pppp_set = None
if params.adj_form:
  function_to_call = (create_pronoun_adj_forms if params.pronoun
      else create_numeral_adj_forms if params.numeral
      else create_adj_forms)
  function_to_call(params.save, startFrom, upTo, params.adj_form, lemmas_to_process, params.lemmas_no_jo, lemmas_to_overwrite, lemmas_to_not_overwrite, params)
if params.noun_form:
  function_to_call = create_numeral_noun_forms if params.numeral else create_noun_forms
  function_to_call(params.save, startFrom, upTo, params.noun_form, lemmas_to_process, params.lemmas_no_jo, lemmas_to_overwrite, lemmas_to_not_overwrite, params)
if params.verb_form:
  create_verb_forms(params.save, startFrom, upTo, params.verb_form, lemmas_to_process, params.lemmas_no_jo, lemmas_to_overwrite, lemmas_to_not_overwrite, params, pppp_set)

blib.elapsed_time()
