--[=[
	This module contains functions for creating inflection tables for Russian
	nouns.

	Author: Benwing, rewritten from early version by Wikitiki89

	Form of arguments: One of the following:
		1. LEMMA|DECL|PLSTEM (all arguments optional)
		2. ACCENT|LEMMA|DECL|PLSTEM (all arguments optional)
		3. multiple sets of arguments separated by the literal word "or"

	Arguments:
		ACCENT: Accent pattern (a b c d e f b' d' f' f''). Multiple values can
		   be specified, separated by commas. If omitted, defaults to a or b
		   depending on the position of stress on the lemma or
		   explicitly-specified declension.
		LEMMA: Lemma form (i.e. nom sg or nom pl), with appropriately-placed
		   stress; or the stem, if an explicit declension is specified
		   (in this case, the declension usually looks like an ending, and
		   the stem is the portion of the lemma minus the ending). In the
		   first argument set (i.e. first set of arguments separated
		   by "or"), defaults to page name; in later sets, defaults to lemma
		   of previous set. A plural form can be given, and causes argument
		   n= to default to n=p (plural only). Normally, an accent is
		   required if multisyllabic, and unaccented monosyllables with
		   automatically be stressed; prefix with * to override both behaviors.
		DECL: Declension field. Normally omitted to autodetect based on the
		   lemma form; see below.
		PLSTEM: special plural stem (defaults to stem of lemma)

	Additional named arguments:
		a: animacy (a/an/anim = animate, i/in/inan = inanimate, b/bi/both/ai = both
		   (listing animate first in the headword), ia = both (listing inanimate
		   first in the headword), otherwise inanimate)
		n: number restriction (p = plural only, s = singular only, b = both;
		   defaults to both unless the lemma is plural, in which case it
		   defaults to plural only)
		CASE_NUM or acc_NUM_ANIM or par/loc/voc: override (or multiple
		    values separated by commas) for case/number combination;
			forms auto-linked; can have raw links in it, can have an
			ending "note" (*, +, 1, 2, 3, etc.)
		pltail: Specify something (usually a * or similar) to attach to
		   the end of the last plural form when there's more than one. Used in
		   conjunction with notes= to indicate that alternative plural forms
		   are obsolete, poetic, etc.
		pltailall: Similar pltail= but attaches to all plural forms.
		   Typically used in conjunction with notes= to make a comment about
		   the plural as a whole (e.g. it's mostly hypothetical, rare and
		   awkward, etc.).
		sgtail, sgtailall: Same as pltail=, pltailall= but for the singular.
		obltail, obltailall: Same as pltail=, pltailall= but for oblique cases
		   (not the nominative or accusative).
		CASE_NUM_tail: Attach the argument to the end of the last form
		   (whether there's one or more than one) for the particular
		   case/number combination. Note that this doesn't work quite like
		   pltail= or sgtail= in that it doesn't skip adding the argument
		   when there's only one form.
		CASE_NUM_tailall: Attach the argument to the end of all forms
		   specified for the particular case/number combination. Similar to
		   pltailall= or sgtailall=.
		suffix: Add a suffix such as ся to all forms.
		prefix: Add a prefix to all forms.
		plhyp, plhypall, CASE_NUM_hyp, etc.: Same as pltail, pltailall,
		   CASE_NUM_tal, etc. but specify that the marked forms are
		   mostly hypothetical or rare/awkard. Generally you will want
		   plhypall=y to mark the plural as hypothetical.

	Per word named arguments:
		All of the above named arguments have per-word variants, e.g.
		a1, a2, ...; n1, n2, ...; CASE_NUM1, CASE_NUM2, ...;
		pltail1, pltail2, ...; etc. These apply to the individual words of a
		form.

	Case abbreviations:
		nom: nominative
		gen: genitive
		dat: dative
		acc: accusative
		ins: instrumental
		pre: prepositional
		par: partitive
		loc: locative
		voc: vocative

	Number abbreviations:
		sg: singular
		pl: plural

	Animacy abbreviations:
		an: animate
		in: inanimate

	Declension field:
		One of the following for regular nouns:
			(blank)
			GENDER
			-VARIANT
			GENDER-VARIANT
			$
			DECLTYPE
			DECLTYPE/DECLTYPE
			(also, can append various special-case markers to any of the above)
		Or one of the following for adjectival nouns:
			+
			+ь
			$
			+short, +mixed or +proper
			+DECLTYPE
		GENDER if present is m, f, n or 3f; for regular nouns, required if the
			lemma ends in -ь or is plural, ignored otherwise. 3f is the same
			as f but in the case of a plural lemma in -и, detects a
			third-declension feminine with singular in -ь rather than a
			first-declension feminine with singular in -а or -я.
		VARIANT is one way of requesting variant declensions (see also special
		    case (1) for variant nom pls, and special case (2) for variant
			gen pls). The currently allowed values are -ья (will select a
			mixed declension that has some normal declension in its singular
			and the -ья plural declension); -ин (for animate masculine nouns
			in -ин with plural in -е -- note that this is autodetected in the
			majority of cases where the ending in -янин or -анин); -ишко
			(used for inanimate neuter-form diminutive masculine nouns in
			-ишко [also сараю́шко] with nom pl -и and colloquial feminine-ending
			alternants in some singular cases); -ище (similar to -ишко but
			used for *animate* augmentative masculine neuter-form nouns in
			-ище). Variants -ишко and -ище must be given with with special
			case (1).
		$ is indeclinable words. It is principally useful in multiword
			expressions where some of the words are indeclinable.
		DECLTYPE is an explicit declension type. Normally you shouldn't use
			this, and should instead let the declension type be autodetected
			based on the ending, supplying the appropriate hint if needed
			(gender for regular nouns, +ь for adjectives). If provided, the
			declension type is usually the same as the ending, and if present,
			the lemma field should be just the stem, without the ending.

			Possibilities for regular nouns are (blank) or # for hard-consonant
			declension, а, я, о, е or ё, е́, й, ья, ье or ьё, ь-m, ь-f,
			ин, ёнок or онок or енок, ёночек or оночек or еночек, мя,
			-а or #-а, ь-я, й-я, о-и or о-ы, -ья or #-ья, $ (indeclinable).
			Old-style (pre-reform) declensions use ъ instead of (blank), ъ-а
			instead of -а, ъ-ья instead of -ья, and инъ, ёнокъ/онокъ/енокъ,
			ёночекъ/оночекъ/еночекъ instead of the same without terminating ъ.
			The declensions can also be written with an accent on them; this
			chooses the same declension (except for е vs. е́), but causes
			ACCENT to default to pattern b instead of a.

			For adjectival nouns, you should normally supply just + and let
			the ending determine the declension; supply +ь in the case of a
			possessive adjectival noun in -ий, which have an extra -ь- in
			most endings compared with normal adjectival nouns in -ий, but
			which can't be distinguished based on the nominative singular.
			You can also supply +short, +mixed or +proper, which constrains
			the declension appropriately but still autodetects the
			gender-specific and stress-specific variant. If you do supply
			a specific declension type, as with regular nouns you need to
			omit the ending from the lemma field and supply just the stem.
			Possibilities are +ый, +ое, +ая, +ій, +ее, +яя, +ой, +о́е, +а́я,
			+ьій, +ье, +ья, +-short or +#-short (masc), +о-short,
			+о-stressed-short or +о́-short,	+а-short, +а-stressed-short or
			+а́-short, and similar for -mixed and -proper (except there aren't
			any	stressed mixed declensions).
		DECLTYPE/DECLTYPE is used for nouns with one declension in the
			singular and a different one in the plural, for cases that
			PLVARIANT and special case (1) below don't cover.
		Special-case markers:
			(1) for Zaliznyak-style alternate nominative plural ending:
				-а or -я for masculine, -и or -ы for neuter
			(2) for Zaliznyak-style alternate genitive plural ending:
				-ъ/none for masculine, -ей for feminine, -ов(ъ) for neuter,
				-ей for plural variant -ья
			* for reducibles (nom sg or gen pl has an extra vowel before the
				final consonant as compared with the stem found in other cases)
			;ё for Zaliznyak-style alternation between last е in stem and ё

TODO:

1. Multi-word issues:
   -- FIXME: Make sure internal_notes handled correctly; we may run into issues
      with multiple internal notes from different words, if we're not careful
      to use different footnote symbols for each type of footnote (which we
      don't do currently). [NOT DONE, MAY NOT DO]
   -- Handling default lemma: With multiple words, we should probably split
      the page name on spaces and default each word in turn [NOT DONE, MAY
      NOT DO]
2a. FIXME: For -ишко diminutives and -ище augmentatives, should add an
   appropriate category of some sort (currently marked by colloqfem= in
   category).
2b. FIXME: Adding a note to dat_sg also adds it to loc_sg when it exists;
   seems wrong. See луг.
2c. FIXME: When you have both d' and f in feminines and you use sgtail=*,
   you get two *'s. See User:Benwing2/test-ru-noun-debug.
3. ADJECTIVE FIXMES:
3a. FIXME: Change calls to ru-adj11 to use the new proper name support in
   ru-adjective.
3b. FIXME: Test that omitting a manual form in ru-adjective leaves the form as
   a big dash.
3c. FIXME: какой-либо and какой-то display genitives with translit -go
   instead of -vo. To fix this properly requires implementing real
   manual translit for adjectives.
3d. FIXME: Implement real manual translit for adjectives.
5. [FIXME: Consider adding an indicator in the header line when the ё/e
   alternation occurs. This is a bit tricky to calculate: If special case
   ;ё is given, but also if ё occurs in the stem and the accent pattern is
   as follows -- for sg-only, b' d' f' f'', also b d f if the noun is masc
   or 3rd-decl fem (i.e. nom-sg ending is non-syllabic); for pl-only,
   e f f' f'', also b b' c if the gen pl is non-syllabic; for sg/pl,
   any but a or b, also b if either nom sg or gen pl is non-syllabic. But
   it gets more complicated due to overrides. An alternative is to check
   all forms to see if ё is present in some but not all; but this is
   tricky also because e.g. reducibles frequently have ё/null alternation,
   which doesn't count, and some endings have е or ё in them, which also
   doesn't count. If we were to do it this way, we'd have to (a) count
   the number of е's in the form(s) with ё and verify that there's at least
   one form without ё and with one more е than in the form(s) with ё
   (and it gets trickier if different forms with ё have different numbers of
   е in them, although that is probably rare); and (b) ignore the appropriate
   endings (the best way to do this would probably be to look at the actual
   suffixes that were generated in args.suffixes and chop off any matching
   ending in the actual form(s), but also chop off final -е/ё, as well as
   -ев(ъ)/-ёв(ъ)/-ей/-ёй in the gen pl, which is frequently overridden,
   unless perhaps the stem ends in the same way). It'd probably not
   possible to do this in a 100% foolproof way but can be "good enough" for
   nearly all circumstances.] [MIGHT BE TOO MUCH WORK]
6. HEADWORD FIXMES:
6a. FIXME: In ru-headword, create a category for words whose gender doesn't
   match the form. (This is easy to do for ru-noun+ but harder for ru-noun.
   We would need to do limited autodetection of the ending: for singulars,
   -а/я should be feminine, -е/о/ё should be neuter, -ь should be masculine
   or feminine, anything else should be masculine; for plurals, -и/ы should
   be masculine or feminine, -а/я should be neuter except that -ія can be
   feminine or neuter due to old-style adjectival pluralia tantum nouns,
   anything else can be any gender.)
6b. FIXME: Recognize indeclinable nouns and indicate as indeclinable. Probably
   should work by checking the case forms to see if they're the same.
9. FIXME: Change stress-pattern detection and overriding to happen inside of
   looping over the two parts of a slash decl. Requires that the loop over
   the two parts happen outside of the loop over stress patterns. Requires
   that the category code get split into two parts, one to handle combined
   singular/plural categories that goes outside the two loops, and one to
   handle everything else that goes inside the two loops.
10. FIXME: override_matches_suffix() had a free variable reference to ARGS
   in it, which should have triggered an error whenever there was a nom_sg or
   nom_pl override but didn't. Is there an error causing this never to be
   called? Check.
11a. FIXME: In a multiword lemma, using loc2=+ causes only the second word
    to get linked instead of the whole expression. Same for par2=+, voc2=+.
11b. FIXME: Using loc=+ with a multiword lemma should do the right thing, same
    as if locN=+ is specified for each individual word. Instead it generates
    the locative as a whole from the dative, which fails e.g. if some of the
    words are adjectival. Same for par=+, voc=+.
13. Multi-word issues:
   -- Setting n=pl when auto-detecting a plural lemma. How does that interact
      with multi-word stuff? (DONE)
   -- compute_heading() -- what to do with multiple words? I assume we should
      display info on the first noun (non-indeclinable, non-adjectival), and
	  on the first adjectival word otherwise, and finally on an indeclinable word (DONE)
   -- args.genders -- it should presumably come from the same word as is used
      in compute_heading(); but we should allow the overall gender to be
	  overridden, at least in ru-noun+ (DONE)
   -- Bug in args.suffix: Gets added to every word in attach_with() and then
      again at the end, after pltail and such. Needs to be added to the
	  last word only, before pltail. Need also suffixN for individual words.
	  (DONE, NEEDS TESTING)
   -- Should have ..N versions of pltail and variants. (DONE, NEEDS TESTING)
   -- Need to handle overrides of acc_sg, acc_pl (DONE)
   -- Overrides of nom_sg/nom_pl should also override acc_sg/acc_pl if it
      was originally empty and the animacy is inanimate; similarly for
	  gen_sg/gen_pl and animates; this needs to work both for per-word and
	  overall overrides. (DONE)
   -- do_generate_forms(_multi) need to run part of make_table(), enough to
      combine all per_word_info into single lists of forms and store back
	  into args[case]. (DONE, NEEDS TESTING)
   -- In generate_forms, should probably check if a=="i" and only return
      acc_sg_in as acc_sg=; or if a=="a" and only return acc_sg_an as acc_sg=;
      in old/new comparison code, do something similar, also when a=="b"
      check if acc_sg_in==acc_sg_an and make it acc_sg; when a=="b" and the
      _in and _an variants are different, might need to ignore them or check
      that acc_sg_in==nom_sg and acc_sg_an==gen_sg; similarly for _pl
	  (DONE, NEEDS TESTING)
   -- Need to test with multiple words! [DONE]
   -- Current handling of <adj> won't work properly with multiple words;
      will need to translate word-by-word in that case (should be solved by
	  manual-translit branch) [DONE]
14. In multiple-words branch, fix ru-decl-noun-multi so it recognizes
   things like *, (1), (2) and ; without the need for a separator. Consider
   using semicolon as a separator, since we already use it to separate ё
   from a previous declension. Maybe use $ or ~ for an indeclinable word; don't
   use semicolon. [IMPLEMENTED. NEED TO TEST.]
16. [Consider having ru-noun+ treat par= as a second genitive in
   the headword, as is done with край] [WON'T DO]
17. [FIXME: Consider removing slash patterns and instead handling them by
   allowing additional declension flags 'sg' and 'pl'. This simplifies the
   various special cases caused by slash declensions. It would also be
   possible to remove the special plural stem, which would get rid of more
   special cases. On the other hand, it makes it more complicated to support
   plural variant -ья with all singular types, and the category code that
   displays things like "Russian nouns with singular -X and plural -Y"
   also gets more complicated, and there's something convenient and intuitive
   about plural stems, and slash declensions are also convenient and at least
   somewhat intuitive. One possibility is to externally allow slash
   declensions and special plural stems and rewrite them internally to
   separate stems with 'sg' and 'pl' declension flags; but there are still
   the two coding issues mentioned above.]
18. [FIXME: Consider redoing slash patterns so they operate at the outer
   level, i.e. things like special cases apply separately in the singular
   and plural part of the slash pattern.]
19. In ru-noun, don't recognize -а with m as plural unless (1)
   or n=pl is also given, because there are masculine words with the
   feminine ending. Check using the test code whether this changes
   anything. Also check if there are other similar cases (neuter with
   -и isn't parallel because -и is always plural). [IMPLEMENTED. NEED TO TEST.]
19a. Internal notes weren't propagated properly from adjectives.
   [IMPLEMENTED. NEED TO TEST.]
19b. Add support for -ишко and -ище variants (p. 74 of Z),
   which conversationally and/or colloquially have feminine endings in
   certain cases. [IMPLEMENTED. NEED TO TEST. MAKE SURE THE INTERNAL NOTES
   APPEAR.]
19d. For masculine animate neuter-form nouns, the accusative singular
   ends in -а (-я soft) instead of -о. [IMPLEMENTED. NEED TO TEST.
   NOTE: Currently this variant only can be selected using new-style
   arguments where the gender can be given. Perhaps we should consider
   allowing gender to be specified with old-style explicit declensions.]
21. Put back gender hints for pl adjectival nouns; used by ru-noun+.
   [IMPLEMENTED. NEED TO TEST.]
23. Mixed and proper-noun adjectives have built-in notes. We need to
   handle those notes with an "internal_notes" section similar to what is used
   in the adjective module. [IMPLEMENTED. NEED TO TEST.]
24. Adjective detection code here needs to work the same as for the
   adjective module, in particular in the handling of short, stressed-short,
   mixed, proper, stressed-proper. [IMPLEMENTED. NEED TO TEST.]
25. Consider simplifying plural-variant code to only allow -ья as a
   plural variant [and maybe even change that to be something like (1')].
   [IMPLEMENTED REDUCTION OF PLURAL VARIANTS TO -ья; PLURAL-VARIANT CODE
   STILL COMPLEX, THOUGH. NEED TO TEST.]
26. Automatically superscript *, numbers and similar things at the
   beginning of a note. Also do this in adjective module. [IMPLEMENTED.
   NEED TO TEST.]
28. Make the check for multiple stress patterns (categorizing/tracking)
   smarter, to keep a list of them and check at the end, so we handle
   multiple stress patterns specified through different arg sets.
   [IMPLEMENTED; NEED TO TEST.]
29. More sophisticated handling of user-requested plural variant vs. special
  case (1) vs. plural-detected variant. [IMPLEMENTED. NEED TO TEST FURTHER.]
30. Solution to ambiguous plural involving gender spec "3f". [IMPLEMENTED;
   NEED TO TEST. Use запчасти, новости.]
33. With pluralia tantum adjectival nouns, we don't know the gender.
   By default we assume masculine (or feminine for old-style -ія nouns) and
   currently this goes into the category, but shouldn't. [IMPLEMENTED.]
39. [Eventually: Even with decl type explicitly given, the full stem with
    ending should be included.] [MAY NEVER IMPLEMENT]
40. [Get error "Unable to dereduce" with strange noun ва́йя, what should
  happen?] [WILL NOT FIX; USE AN OVERRIDE]
41. In творог, module generates partitive творогу́ when it should copy the
   dative творогу́,тво́рогу. (DONE)
42. [[груз 200]] doesn't work. Interprets 200 as a footnote symbol.
43. When converting е -> ё not after cons and with translit, we should
   convert e -> o to avoid double j. (DONE)
44. FIXME: In ро́вня/ровня́, similarly with неровня, marks genitive plural
   ровня́ as irregular even though it isn't. (NOT OUR ERROR; THE DECLENSIONS
   OF THESE NOUNS MARKED THE ENDING-STRESSED VARIANTS WITH (2).)
]=]--

local m_utilities = require("Module:utilities")
local m_table = require("Module:table")
local m_links = require("Module:links")
local com = require("Module:ru-common")
local nom = require("Module:ru-nominal")
local m_ru_adj = require("Module:ru-adjective")
local m_ru_translit = require("Module:ru-translit")
local strutils = require("Module:string utilities")
local scriptutils = require("Module:script utilities")
local m_table_tools = require("Module:table tools")
local m_debug = require("Module:debug")

local export = {}

local lang = require("Module:languages").getByCode("ru")
local Latn = require("Module:scripts").getByCode("Latn")

local u = mw.ustring.char
local rfind = mw.ustring.find
local rsubn = mw.ustring.gsub
local rmatch = mw.ustring.match
local rsplit = mw.text.split
local ulower = mw.ustring.lower
local usub = mw.ustring.sub
local ulen = mw.ustring.len

-- If enabled, compare this module with new version of module to make
-- sure all declensions are the same. Eventually consider removing this;
-- but useful as new code is created.
local test_new_ru_noun_module = false

local AC = u(0x0301) -- acute =  ́
local CFLEX = u(0x0302) -- circumflex =  ̂
local PSEUDOCONS = u(0xFFF2) -- pseudoconsonant placeholder, matching ru-common
local IRREGMARKER = "△"
local HYPMARKER = "⟐"

local paucal_marker = "*"
local paucal_internal_note = "* Used with the numbers 1.5, 2, 3, 4 and higher numbers after 20 ending in 2, 3, and 4."

-- text class to check lowercase arg against to see if Latin text embedded in it
local latin_text_class = "[a-zščžěáéíóúýàèìòùỳâêîôûŷạẹịọụỵȧėȯẏ]"

-- Forward functions

local generate_forms_1
local determine_decl
local handle_forms_and_overrides
local handle_overall_forms_and_overrides
local concat_word_forms
local make_table
local detect_adj_type
local detect_stress_pattern
local override_stress_pattern
local determine_stress_variant
local determine_stem_variant
local is_reducible
local is_dereducible
local add_bare_suffix
local attach_stressed
local do_stress_pattern
local canonicalize_override

-- version of rsubn() that discards all but the first return value
local function rsub(term, foo, bar)
	local retval = rsubn(term, foo, bar)
	return retval
end

-- version of rsubn() that returns a 2nd argument boolean indicating whether
-- a substitution was made.
local function rsubb(term, foo, bar)
	local retval, nsubs = rsubn(term, foo, bar)
	return retval, nsubs > 0
end

-- version of rfind() that lowercases its string first, for case-insensitive matching
local function rlfind(term, foo)
	return rfind(ulower(term), foo)
end

local function track(page)
	m_debug.track("ru-noun/" .. page)
	return true
end

-- version of m_table.insertIfNot() that makes sure 'false' doesn't get inserted by mistake, and uses deep comparison.
local function insert_if_not(foo, bar)
	assert(bar ~= false)
	m_table.insertIfNot(foo, bar, nil, "deep compare")
end

-- Fancy version of ine() (if-not-empty). Converts empty string to nil,
-- but also strips leading/trailing space and then single or double quotes,
-- to allow for embedded spaces.
local function ine(arg)
	if not arg then return nil end
	arg = rsub(arg, "^%s*(.-)%s*$", "%1")
	if arg == "" then return nil end
	local inside_quotes = rmatch(arg, '^"(.*)"$')
	if inside_quotes then
		return inside_quotes
	end
	inside_quotes = rmatch(arg, "^'(.*)'$")
	if inside_quotes then
		return inside_quotes
	end
	return arg
end

-- FIXME: Move to utils
-- Iterate over a chain of parameters, FIRST then PREF2, PREF3, ...,
-- inserting into LIST (newly created if omitted). Return LIST.
local function get_arg_chain(args, first, pref, list)
	if not list then
		list = {}
	end
	local val = args[first]
	local i = 2

	while val do
		table.insert(list, val)
		val = args[pref .. i]
		i = i + 1
	end
	return list
end

-- synthesize a frame so that exported functions meant to be called from
-- templates can be called from the debug console.
local function debug_frame(parargs, args)
	return {args = args, getParent = function() return {args = parargs} end}
end

local function rutr_pairs_equal(term1, term2)
	local ru1, tr1 = term1[1], term1[2]
	local ru2, tr2 = term2[1], term2[2]
	local ru1entry, ru1notes = m_table_tools.separate_notes(m_links.remove_links(ru1))
	local ru2entry, ru2notes = m_table_tools.separate_notes(m_links.remove_links(ru2))
	if ru1entry ~= ru2entry then
		return false
	end
	local tr1entry, tr1notes
	local tr2entry, tr2notes
	if tr1 then
		tr1entry, tr1notes = m_table_tools.separate_notes(tr1)
	end
	if tr2 then
		tr2entry, tr2notes = m_table_tools.separate_notes(tr2)
	end
	if tr1entry == tr2entry then
		return true
	elseif type(tr1entry) == type(tr2entry) then
		return false
	else
		tr1entry = tr1entry or com.translit_no_links(ru1entry)
		tr2entry = tr2entry or com.translit_no_links(ru2entry)
		return tr1entry == tr2entry
	end
end

local function contains_rutr_pair(list, pair)
	for _, item in ipairs(list) do
		if rutr_pairs_equal(item, pair) then
			return true
		end
	end
	return false
end

-- Clone parent's args while also assigning nil to empty strings.
local function clone_args(frame)
	local args = {}
	for pname, param in pairs(frame:getParent().args) do
		args[pname] = ine(param)
	end
	return args
end

-- Old-style declensions.
local declensions_old = {}
-- New-style declensions; computed automatically from the old-style ones,
-- for the most part.
local declensions = {}
-- Internal notes for old-style declensions.
local internal_notes_table_old = {}
-- Same for new-style declensions.
local internal_notes_table = {}
-- Category and type information corresponding to declensions: These may
-- contain the following fields: 'singular', 'plural', 'decl', 'hard', 'g',
-- 'suffix', 'gensg', 'irregpl', 'alt_nom_pl', 'cant_reduce', 'ignore_reduce',
-- 'stem_suffix'.
--
-- 'singular' is used to construct a category of the form
-- "Russian nouns SINGULAR". If omitted, a category is constructed of the
-- form "Russian nouns ending in -ENDING", where ENDING is the actual
-- nom sg ending shorn of its acute accents; or "Russian nouns ending
-- in suffix -ENDING", if 'suffix' is true. The value of SINGULAR can be
-- one of the following: a single string, a list of strings, or a function,
-- which is passed one argument (the value of ENDING that would be used to
-- auto-initialize the category), and should return a single string or list
-- of strings. Such a category is only constructed if 'gensg' is true.
--
-- 'plural' is analogous but used to construct a category of the form
-- "Russian nouns with PLURAL", and if omitted, a category is constructed
-- of the form "Russian nouns with plural -ENDING", based on the actual
-- nom pl ending shorn of its acute accents. Currently no plural category
-- is actually constructed.
--
-- In addition, a category may normally constructed from the combination of
-- 'singular' and 'plural', appropriately defaulted; e.g. if both are present,
-- the combined category will be "Russian nouns SINGULAR with PLURAL" and
-- if both are missing, the combined category will be
-- "Russian nouns ending in -SGENDING with plural -PLENDING" (or
-- "Russian nouns ending in suffix -SGENDING with plural -PLENDING" if
-- 'suffix' is true). Note that if either singular or plural or both
-- specifies a list, looping will occur over all combinations. Such a
-- category is constructed only if 'irregpl' or 'alt_nom_pl' or 'suffix'
-- is true or if the declension class is a slash class.
--
-- 'decl' is "1st", "2nd", "3rd" or "indeclinable"; 'hard' is "hard", "soft"
-- or "none"; 'g' is "m", "f", "n" or "none"; these are all traditional
-- declension categories.
--
-- If 'suffix' is true, the declension type includes a long suffix
-- added to the string that itself undergoes reducibility and such, and so
-- reducibility cannot occur in the stem minus the suffix. Categories will
-- be created for the suffix.
--
-- 'alt_nom_pl' indicates that the declension has an alternative nominative
-- plural (corresponding to Zaliznyak's special case 1; compare special case 2
-- for alternative genitive plural). 'irregpl' indicates that the entire
-- plural is irregular.
--
-- In addition to the above categories, additional more specific categories
-- are constructed based on the final letter of the stem, e.g.
-- "Russian velar-stem 1st-declension hard nouns". See calls to
-- com.get_stem_trailing_letter_type(). 'stem_suffix', if present, is added to
-- the end of the stem when get_stem_trailing_letter_type() is called.
-- This is the only place that 'stem_suffix' is used. This is for use with
-- the '-ья' and '-ье' declension types, so that the trailing letter is
-- 'ь' and not whatever precedes it.
--
-- 'enable_categories' is a special hack for testing, which disables all
-- category insertion if false. Delete this as soon as we've verified the
-- working of the category code and created all the necessary categories.
local enable_categories = true
-- Category/type info corresponding to old-style declensions; see above.
local declensions_old_cat = {}
-- Category/type info corresponding to new-style declensions. Computed
-- automatically from the old-style ones, for the most part. Same format
-- as the old-style ones.
local declensions_cat = {}
-- Table listing aliases of old-style declension classes.
local declensions_old_aliases = {}
-- Table listing aliases of new-style declension classes; computed
-- automatically from the old-style ones.
local declensions_aliases = {}
local stress_patterns = {}
-- Set of patterns with ending-stressed genitive plural.
local ending_stressed_gen_pl_patterns = {}
-- Set of patterns with ending-stressed prepositional singular.
local ending_stressed_pre_sg_patterns = {}
-- Set of patterns with ending-stressed dative singular.
local ending_stressed_dat_sg_patterns = {}
-- Set of patterns with all singular forms ending-stressed.
local ending_stressed_sg_patterns = {}
-- Set of patterns with all plural forms ending-stressed.
local ending_stressed_pl_patterns = {}

local declinable_cases_except_accusative = {
	"nom_sg", "gen_sg", "dat_sg", "ins_sg", "pre_sg",
	"nom_pl", "gen_pl", "dat_pl", "ins_pl", "pre_pl",
}

local accusative_cases_unsplit_animacy = {
	"acc_sg", "acc_pl",
}

local accusative_cases_split_animacy = {
	"acc_sg_an", "acc_sg_in", "acc_pl_an", "acc_pl_in",
}

local lemma_linked_cases = {
	"nom_sg_linked", "nom_pl_linked",
}

local overridable_only_cases = {
	"par", "loc", "voc", "par_pl", "loc_pl", "voc_pl", "count", "pauc",
}
local overridable_only_cases_set = m_table.listToSet(overridable_only_cases)

-- List of all cases that are declined normally.
local decl_cases = m_table.append(declinable_cases_except_accusative, accusative_cases_unsplit_animacy)

-- List of all cases that can be overridden (includes all cases except the "linked" lemma case variants). Also
-- currently the same as the cases returned by export.generate_forms().
local overridable_cases = m_table.append(decl_cases, accusative_cases_split_animacy, overridable_only_cases)

-- List of all cases that can be displayed (includes all cases except plain accusatives).
local displayable_cases = m_table.append(declinable_cases_except_accusative, lemma_linked_cases,
	accusative_cases_split_animacy, overridable_only_cases)

-- List of all cases, including those that are declined normally (nom/gen/dat/acc/ins/pre sg and pl), plus
-- animate/inanimate accusative variants (computed automatically as appropriate from the previous cases), plus
-- additional overridable cases (loc/par/voc and plural), plus the "linked" lemma case variants used in ru-noun+
-- headwords (nom_sg_linked, nom_pl_linked, whose values come from nom_sg and nom_pl but may have additional embedded
-- links if they were given in the lemma).
local all_cases = m_table.append(overridable_cases, lemma_linked_cases)

local function english_case_description(case)
	if case == "par" or case == "loc" or case == "voc" then
		-- For historical reasons, the singular of these cases doens't include "_sg" in their code.
		case = case .. "_sg"
	end
	local engcase = rsub(case, "^([a-z]*)", {
		nom="nominative", gen="genitive", dat="dative",
		acc="accusative", ins="instrumental", pre="prepositional",
		par="partitive", loc="locative", voc="vocative",
		count="count form", pauc="paucal",
	})
	engcase = rsub(engcase, "(_[a-z]*)", {
		_sg=" singular", _pl=" plural",
		_an="", _in="",
		--_an=" animate", _in=" inanimate"
	})
	return engcase
end

--------------------------------------------------------------------------
--                     Tracking and categorization                      --
--------------------------------------------------------------------------

-- FIXME! Move below the main code

-- FIXME!! Consider deleting most of this tracking code once we've enabled
-- all the categories. Note that some of the tracking categories aren't
-- completely redundant; e.g. we have tracking pages that combine decl and
-- stress classes, such as "а/a" or "о-и/d'", which are more or less
-- equivalent to stem/gender/stress categories, but we also have the same
-- prefixed by "reducible-stem/" for reducible stems.
local function tracking_code(stress, orig_decl, decl, args, n, islast)
	assert(orig_decl)
	assert(decl)
	local hint_types = com.get_stem_trailing_letter_type(args.stem)
	if orig_decl == decl then
		orig_decl = nil
	end

	if args.notes then
		track("notes")
	end
	
	local function all_pl_irreg()
		track("irreg")
		for _, case in ipairs(overridable_cases) do
			if rfind(case, "_pl") then
				track("irreg/" .. case)
			end
		end
	end

	local function track_prefix(prefix)
		local function dotrack(suf)
			track(prefix .. suf)
		end
		dotrack(stress)
		dotrack(decl)
		dotrack(decl .. "/" .. stress)
		if orig_decl then
			dotrack(orig_decl)
			dotrack(orig_decl .. "/" .. stress)
		end
		for _, hint_type in ipairs(hint_types) do
			dotrack(hint_type)
			dotrack(decl .. "/" .. hint_type)
			if orig_decl then
				dotrack(orig_decl .. "/" .. hint_type)
			end
		end
	end
	track_prefix("")
	if args.reducible then
		track("reducible-stem")
		track_prefix("reducible-stem/")
	end
	if rlfind(args.stem, "и́?н$") and (decl == "" or decl == "#") then
		track("irregular-in")
	end
	if args.pltail then
		track("pltail")
	end
	if args.sgtail then
		track("sgtail")
	end
	if args.pltailall then
		track("pltailall")
	end
	if args.sgtailall then
		track("sgtailall")
	end
	if args.pl ~= args.stem then
		track("irreg-pl-stem")
		track("irreg")
	end
	if args.alt_gen_pl then
		track("alt-gen-pl")
		track("irreg")
		track("irreg/gen_pl")
	end
	if args.want_sc1 then
		track("want-sc1")
		track("irreg")
		track("irreg/nom_pl")
	end
	if rfind(decl, "-и$") or rfind(decl, "-а$") or rfind(decl, "-я$") then
		track("irreg")
		track("irreg/nom_pl")
	end
	if rfind(decl, "-ья$") then
		track("variant-ья")
		all_pl_irreg()
	end
	if rfind(decl, "%(ишк%)$") then
		track("variant-ишко")
	end
	if rfind(decl, "%(ищ%)$") then
		track("variant-ище")
	end
	if args.jo_special then
		track("jo-special")
	end
	if args.manual then
		track("manual")
	end
	if args.explicit_gender then
		track("explicit-gender")
		track("explicit-gender/" .. args.explicit_gender)
	end
	for _, case in ipairs(overridable_cases) do
		if args[case .. n] and not args.manual then
			track("override")
			track("override/" .. case .. n)
			track("irreg")
			track("irreg/" .. case .. n)
			-- questionable use: track_prefix("irreg/" .. case .. "/")
			-- questionable use: track_prefix("irreg/" .. case .. n .. "/")
		end
		if islast and args[case] and not args.manual then
			track("override")
			track("override/" .. case)
			track("irreg")
			track("irreg/" .. case)
			-- questionable use: track_prefix("irreg/" .. case .. "/")
		end
		if args[case .. "_tail"] then
			track("casenum-tail")
			track("casenum-tail/" .. case)
		end
		if args[case .. "_tailall"] then
			track("casenum-tailall")
			track("casenum-tailall/" .. case)
		end
	end
end

local gender_to_full = {m="masculine", f="feminine", n="neuter"}
local gender_to_short = {m="masc", f="fem", n="neut"}

-- Insert the category CAT (a string) into list CATEGORIES. String will
-- have "Russian " prepended and ~ substituted for the plural part of speech.
local function insert_category(categories, cat, pos, atbeg)
	if enable_categories then
		local fullcat = "Russian " .. rsub(cat, "~", pos .. "s")
		if atbeg then
			table.insert(categories, 1, fullcat)
		else
			table.insert(categories, fullcat)
		end
	end
end

-- Insert categories into ARGS.CATEGORIES corresponding to the specified
-- stress and declension classes and to the form of the stem (e.g. velar,
-- sibilant, etc.). Also initialize values used to compute the declension
-- heading that describes similar information. N is the number of the
-- word being processed; ISLAST is true if this is the last word.
local function categorize_and_init_heading(stress, decl, args, n, islast)
	local function cat_to_list(cat)
		if not cat then
			return {}
		elseif type(cat) == "string" then
			return {cat}
		else
			assert(type(cat) == "table")
			return cat
		end
	end

	-- Insert category CAT into the list of categories in ARGS.
	-- CAT may be nil, a single string or a list of strings. We call
	-- insert_category() on each string. The strings will have "Russian "
	-- prepended and "~" replaced with the plural part of speech.
	local function insert_cat(cat)
		for _, c in ipairs(cat_to_list(cat)) do
			insert_category(args.categories, c, args.pos)
		end
	end

	-- "Resolve" the category spec CATSPEC into the sort of category spec
	-- accepted by insert_cat(), i.e. nil, a single string or a list of
	-- strings. CATSPEC may be any of these or a function, which takes one
	-- argument (SUFFIX) and returns another CATSPEC.
	local function resolve_cat(catspec, suffix)
		if type(catspec) == "function" then
			return resolve_cat(catspec(suffix), suffix)
		else
			return catspec
		end
	end

	-- Check whether an override for nom_sg or nom_pl still contains the
	-- normal suffix (which should already have accents removed) in at least
	-- one of its entries. If no override then of course we return true.
	local function override_matches_suffix(args, case, n, suffix)
		assert(suffix == com.remove_accents(suffix))
		-- NOTE: It might not be completely correct to pass in args.forms
		-- here when n == ""; this is different behavior from
		-- handle_overall_forms_and_overrides(). But args.forms is only used
		-- to retrieve the dat_sg for handling loc/par, and we're never
		-- called with loc or par as the value of CASE, so it doesn't matter.
		-- We add an assert to make sure of this.
		assert(case ~= "loc" and case ~= "par")
		local override = canonicalize_override(args, case, args.forms, n)
		if not override then
			return true
		end
		for _, x in ipairs(override) do
			local ru, tr = x[1], x[2]
			local entry, notes = m_table_tools.separate_notes(ru)
			entry = com.remove_accents(m_links.remove_links(entry))
			if rlfind(entry, suffix .. "$") then
				return true
			end
		end
		return false
	end

	if args.manual then
		return
	end

	local h = args.heading_info

	assert(decl)
	local decl_cats = args.old and declensions_old_cat or declensions_cat

	local sgdecl, pldecl
	local is_slash_decl = rfind(decl, "/")
	if is_slash_decl then
		local indiv_decls = rsplit(decl, "/")
		sgdecl, pldecl = indiv_decls[1], indiv_decls[2]
	else
		sgdecl, pldecl = decl, decl
	end
	local sgdc = decl_cats[sgdecl]
	local pldc = decl_cats[pldecl]
	assert(sgdc)
	assert(pldc)

	local sghint_types = com.get_stem_trailing_letter_type(
		args.stem .. (sgdc.stem_suffix or ""))

	-- insert English version of Zaliznyak stem type
	if sgdc.decl == "indeclinable" then
		insert_cat("indeclinable ~")
		insert_if_not(h.stemetc, "indecl")
	else
		local stem_type =
			sgdc.decl == "3rd" and "3rd-declension" or
			m_table.contains(sghint_types, "velar") and "velar-stem" or
			m_table.contains(sghint_types, "sibilant") and "sibilant-stem" or
			m_table.contains(sghint_types, "c") and "ц-stem" or
			m_table.contains(sghint_types, "i") and "i-stem" or
			m_table.contains(sghint_types, "vowel") and "vowel-stem" or
			m_table.contains(sghint_types, "soft-cons") and "vowel-stem" or
			m_table.contains(sghint_types, "palatal") and "vowel-stem" or
			sgdc.hard == "soft" and "soft-stem" or
			"hard-stem"
		local short_stem_type = stem_type == "3rd-declension" and "3rd-decl" or stem_type
		if sgdc.adj then
			-- Don't include gender for pluralia tantum because it's mostly
			-- indeterminate (certainly when specified using a plural lemma,
			-- which will be usually; technically it's partly or completely
			-- determinate in certain old-style adjectives that distinguish
			-- masculine from feminine/neuter, but this is too rare a case
			-- to worry about)
			local gendertext = args.thisn == "p" and "plural-only" or gender_to_full[sgdc.g]
			insert_if_not(h.adjectival, "yes")
			if args.thisn ~= "p" then
				insert_if_not(h.gender, gender_to_short[sgdc.g])
			end
			if sgdc.possadj then
				insert_cat(sgdc.decl .. " possessive " .. gendertext .. " accent-" .. stress .. " adjectival ~")
				insert_if_not(h.stemetc, sgdc.decl .. " poss")
				insert_if_not(h.stress, stress)
			elseif stem_type == "soft-stem" or stem_type == "vowel-stem" then
				insert_cat(stem_type .. " " .. gendertext .. " adjectival ~")
				insert_if_not(h.stemetc, short_stem_type)
			else
				insert_cat(stem_type .. " " .. gendertext .. " accent-" .. stress .. " adjectival ~")
				insert_if_not(h.stemetc, short_stem_type)
				insert_if_not(h.stress, stress)
			end
		else
			-- NOTE: There are 8 Zaliznyak-style stem types and 3 genders, but
			-- we don't create a category for masculine-form 3rd-declension
			-- nouns (there is such a noun, путь, but it mostly behaves
			-- like a feminine noun), so there are 23.
			insert_cat(stem_type .. " " .. gender_to_full[sgdc.g] .. "-form ~")
			-- NOTE: Here we are creating categories for the combination of
			-- stem, gender and accent. There are 10 accent patterns and 23
			-- combinations of stem and gender, which potentially makes for
			-- 10*23 = 230 such categories, which is a lot. Not all such
			-- categories should actually exist; there were maybe 75 former
			-- declension templates, each of which was essentially categorized
			-- by the same three variables, but some of which dealt with
			-- ancillary issues like irregular plurals; this amounts to 67
			-- actual stem/gender/accent categories, although there are more
			-- of them in Zaliznyak (FIXME, how many? See generate_cats.py).
			insert_cat(stem_type .. " " .. gender_to_full[sgdc.g] .. "-form accent-" .. stress .. " ~")
			insert_if_not(h.adjectival, "no")
			insert_if_not(h.gender, gender_to_short[sgdc.g])
			insert_if_not(h.stemetc, short_stem_type)
			insert_if_not(h.stress, stress)
		end
		insert_cat("~ with accent pattern " .. stress)
	end
	local sgsuffix = args.suffixes.nom_sg
	if sgsuffix then
		assert(#sgsuffix == 1) -- If this ever fails, then implement a loop
		sgsuffix = com.remove_accents(sgsuffix[1])
		-- If we are plural only or if nom_sg is overridden and has
		-- an unusual suffix, then don't create category for sg suffix
		if args.thisn == "p" or not override_matches_suffix(args, "nom_sg", n, sgsuffix) or islast and not override_matches_suffix(args, "nom_sg", "", sgsuffix) then
			sgsuffix = nil
		end
	end
	local plsuffix = args.suffixes.nom_pl
	if plsuffix then
		assert(#plsuffix == 1) -- If this ever fails, then implement a loop
		plsuffix = com.remove_accents(plsuffix[1])
		-- If we are a singulare tantum or if nom_pl is overridden and has
		-- an unusual suffix, then don't create category for pl suffix
		if args.thisn == "s" or not override_matches_suffix(args, "nom_pl", n, plsuffix) or islast and not override_matches_suffix(args, "nom_pl", "", plsuffix) then
			plsuffix = nil
		end
	end
	sgsuffix = sgsuffix and rsub(sgsuffix, "ъ$", "")
	plsuffix = plsuffix and rsub(plsuffix, "ъ$", "")
	local sgcat = sgsuffix and (resolve_cat(sgdc.singular, sgsuffix) or "ending in " .. (sgsuffix == "" and "a consonant" or (sgdc.suffix and "suffix " or "") .. "-" .. sgsuffix))
	local plcat = plsuffix and (resolve_cat(pldc.plural, suffix) or "plural -" .. plsuffix)
	if sgcat and sgdc.gensg then
		for _, cat in ipairs(cat_to_list(sgcat)) do
			insert_cat("~ " .. cat)
		end
	end
	if sgcat and plcat and (sgdc.suffix or sgdc.alt_nom_pl or sgdc.irregpl or
			is_slash_decl and plsuffix == "-ья") then
		for _, scat in ipairs(cat_to_list(sgcat)) do
			for _, pcat in ipairs(cat_to_list(plcat)) do
				insert_cat("~ " .. scat .. " with " .. pcat)
			end
		end
	end

	if args.pl ~= args.stem then
		insert_cat("~ with irregular plural stem")
	end
	if args.reducible and not sgdc.ignore_reduce then
		insert_cat("~ with reducible stem")
		insert_if_not(h.reducible, "yes")
	else
		insert_if_not(h.reducible, "no")
	end
	if args.alt_gen_pl then
		insert_cat("~ with alternate genitive plural")
	end
	if sgdc.adj then
		insert_cat("adjectival ~")
	end
end

local function compute_heading(args)
	local headings = {}
	local h = args.heading_info
	table.insert(headings, args.a == "a" and "anim" or args.a == "i" and
		"inan" or "bian")
	table.insert(headings, args.nonumber and "uncountable" or
		args.n == "s" and "sg-only" or args.n == "p" and "pl-only" or nil)
	if #h.gender > 0 then
		table.insert(headings, table.concat(h.gender, "/") .. "-form")
	end
	if #h.stemetc > 0 then
		table.insert(headings, table.concat(h.stemetc, "/"))
	end
	if #h.stress > 0 then
		local stresses = {}
		for _, stress in ipairs(h.stress) do
			table.insert(stresses, rsub(stress, "'", "&#39;"))
		end
		table.insert(headings, "accent-" .. table.concat(stresses, "/"))
	end

	local function handle_bool(boolvals, text, into)
		into = into or headings
		if m_table.contains(boolvals, "yes") and m_table.contains(boolvals, "no") then
			table.insert(into, "[" .. text .. "]")
		elseif m_table.contains(boolvals, "yes") then
			table.insert(into, text)
		end
	end
	handle_bool(h.adjectival, "adj")
	handle_bool(h.reducible, "reduc")

  	return headings
end

local function compute_overall_heading_categories_and_genders(args)
	local hinfo = args.per_word_heading_info
	local index = 0

	-- First try for non-adjectival, non-indeclinable
	for i=1,#hinfo do
		if not m_table.contains(hinfo[i].stemetc, "indecl") and not m_table.contains(hinfo[i].adjectival, "yes") then
			index = i
			break
		end
	end
	if index == 0 then
		-- Then just non-indeclinable
		for i=1,#hinfo do
			if not m_table.contains(hinfo[i].stemetc, "indecl") then
				index = i
				break
			end
		end
	end
	-- Finally, do anything
	if index == 0 then
		index = 1
	end

	-- Compute final heading
	local headings = args.per_word_headings[index]
	local categories = args.per_word_categories[index]
	if args.any_irreg then
		table.insert(headings, "irreg")
		insert_category(categories, "irregular ~", args.pos)
	end
	for _, case in ipairs(overridable_cases) do
		local is_pl = rfind(case, "_pl")
		if args.n == "s" and is_pl or args.n == "p" and not is_pl then
			-- Don't create singular categories when plural-only or vice-versa
		elseif overridable_only_cases_set[case] then
			if args.any_overridden[case] then
				insert_category(categories, "~ with " .. english_case_description(case), args.pos)
			end
		elseif args.any_irreg_case[case] then
			insert_category(categories, "~ with irregular " .. english_case_description(case), args.pos)
		end
	end
	local heading = args.manual and "" or "(<span style=\"font-size: smaller;\">[[Appendix:Russian nouns#Declension tables|" .. table.concat(headings, " ") .. "]]</span>)"
	args.heading = heading
	args.categories = categories

	args.genders = args.per_word_genders[index]
end

--------------------------------------------------------------------------
--                              Main code                               --
--------------------------------------------------------------------------

-- Used by do_generate_forms().
local function arg1_is_stress(arg1)
	if not arg1 then return false end
	for _, arg in ipairs(rsplit(arg1, ",")) do
		if not rfind(arg, "^[a-f]'?'?$") then
			return false
		end
	end
	return true
end

-- Used by do_generate_forms(), handling a word joiner argument
-- of the form 'join:JOINER'.
local function extract_word_joiner(spec)
	word_joiner = rmatch(spec, "^join:(.*)$")
	assert(word_joiner)
	return com.split_russian_tr(word_joiner, "dopair")
end

local function determine_headword_gender(args, sgdc, gender)
	-- If gender unspecified, use normal gender of declension, except when
	-- adjectival nouns that are pluralia tantum, where the gender is
	-- mostly indeterminate (FIXME, not completely with old-style declensions
	-- but we don't handle that currently).
	if not gender then
		if sgdc.adj and args.thisn == "p" then
			gender = nil
		else
			gender = sgdc.g
		end
	end

	-- Determine headword genders
	gender = gender and gender ~= "none" and gender .. "-" or ""
	local plsuffix = args.n == "p" and "-p" or ""
	local hgens
	if args.a == "a" then
		hgens = {gender .. "an" .. plsuffix}
	elseif args.a == "i" then
		hgens = {gender .. "in" .. plsuffix}
	elseif args.a == "ai" then
		hgens = {gender .. "an" .. plsuffix, gender .. "in" .. plsuffix}
	else
		hgens = {gender .. "in" .. plsuffix, gender .. "an" .. plsuffix}
	end

	-- Insert into list of genders
	for _, hgen in ipairs(hgens) do
		insert_if_not(args.genders, hgen)
	end
end

function export.do_generate_forms(args, old)
	old = old or args.old
	args.old = old
	args.pos = args.pos or "noun"

	-- This is a list with each element corresponding to a word and
	-- consisting of a two-element list, ARG_SETS and JOINER, where ARG_SETS
	-- is a list of ARG_SET objects, one per alternative stem, and JOINER
	-- is a string indicating how to join the word to the next one.
	local per_word_info = {}

	-- Gather arguments into a list of ARG_SET objects, containing (potentially)
	-- elements 1, 2, 3, 4, corresponding to accent pattern, stem, declension
	-- type, pl stem and coming from consecutive numbered parameters. Sets of
	-- declension parameters are separated by the word "or".
	local arg_sets = {}
	-- Find maximum-numbered arg, allowing for holes
	local max_arg = 0
	for k, v in pairs(args) do
		if type(k) == "number" and k > max_arg then
			max_arg = k
		end
	end
	-- Now gather the arguments.
	local offset = 0
	local arg_set = {}
	for i=1,(max_arg + 1) do
		local end_arg_set = false
		local end_word = false -- FIXME, is this correct?
		local word_joiner
		if i == max_arg + 1 then
			end_arg_set = true
			end_word = true
			word_joiner = {""}
		elseif args[i] == "_" then
			end_arg_set = true
			end_word = true
			word_joiner = {" "}
		elseif args[i] == "-" then
			end_arg_set = true
			end_word = true
			word_joiner = {"-"}
		elseif args[i] and rfind(args[i], "^join:") then
			end_arg_set = true
			end_word = true
			word_joiner = extract_word_joiner(args[i])
		elseif args[i] == "or" then
			end_arg_set = true
		end

		if end_arg_set then
			table.insert(arg_sets, arg_set)
			arg_set = {}
			offset = i
			if end_word then
				table.insert(per_word_info, {arg_sets, word_joiner})
				arg_sets = {}
			end
		else
			-- If the first argument isn't stress, that means all arguments
			-- have been shifted to the left one. We want to shift them
			-- back to the right one, so we change the offset so that we
			-- get the same effect of skipping a slot in the arg set.
			if i - offset == 1 and not arg1_is_stress(args[i]) then
				offset = offset - 1
			end
			if i - offset > 4 then
				error("Too many arguments for argument set: arg " .. i .. " = " .. (args[i] or "(blank)"))
			end
			arg_set[i - offset] = args[i]
		end
	end

	return generate_forms_1(args, per_word_info)
end

function export.do_generate_forms_multi(args, old)
	old = old or args.old
	args.old = old
	args.pos = args.pos or "noun"

	-- This is a list with each element corresponding to a word and
	-- consisting of a two-element list, ARG_SET and JOINER, where ARG_SET
	-- is a list of ARG_SET objects, one per alternative stem, and JOINER
	-- is a string indicating how to join the word to the next one.
	local per_word_info = {}

	-- Find maximum-numbered arg, allowing for holes (FIXME: Is this needed
	-- here? Will there be holes?)
	local max_arg = 0
	for k, v in pairs(args) do
		if type(k) == "number" and k > max_arg then
			max_arg = k
		end
	end

	-- Gather arguments into a list of ARG_SET objects, containing
	-- (potentially) elements 1, 2, 3, corresponding to accent pattern,
	-- lemma+declension spec, pl stem, exactly as with do_generate_forms()
	-- and {{ru-noun-table}} except that the values come from a single argument
	-- of the form ACCENTPATTERN:LEMMADECL:PL where all but LEMMADECL may (and
	-- probably will be) omitted and LEMMADECL may be of the following forms:
	--   LEMMA (for a noun with empty decl spec),
	--   LEMMADECL (for a noun with non-empty decl spec beginning with a
	--      *, left paren or semicolon),
	--   LEMMA^DECL (for a noun with non-empty decl spec),
	--   LEMMA$ (for an indeclinable word)
	--   LEMMA+ (for an adjective with auto-detected decl class)
	--   LEMMA+DECL (for an adjective with explicit decl class)
	-- Sets of parameters for the same word are separated by the word "or".
	local arg_sets = {}

	local continue_arg_sets = true
	for i=1,(max_arg + 1) do
		local end_word = false
		local word_joiner
		local process_arg = false
		if i == max_arg + 1 then
			end_word = true
			word_joiner = {""}
		elseif args[i] == "-" then
			end_word = true
			word_joiner = {"-"}
			continue_arg_sets = true
		elseif rfind(args[i], "^join:") then
			end_word = true
			word_joiner = extract_word_joiner(args[i])
			continue_arg_sets = true
		elseif args[i] == "or" then
			continue_arg_sets = true
		else
			if continue_arg_sets then
				continue_arg_sets = false
			else
				end_word = true
				word_joiner = {" "}
			end
			process_arg = true
		end

		if end_word then
			table.insert(per_word_info, {arg_sets, word_joiner})
			arg_sets = {}
		end
		if process_arg then
			local vals = rsplit(args[i], ":")
			if #vals > 3 then
				error("Can't specify more than 3 colon-separated params of param set: " .. args[i])
			end
			local arg_set = {}
			if arg1_is_stress(vals[1]) then
				arg_set[1] = vals[1]
				arg_set[2] = vals[2]
				arg_set[4] = vals[3]
			else
				arg_set[2] = vals[1]
				arg_set[4] = vals[2]
			end
			-- recognize indeclinable
			local indecl_stem = rmatch(arg_set[2], "^(.-)%$$")
			if indecl_stem then
				arg_set[2] = indecl_stem
				arg_set[3] = "$"
			else
				-- recognize adjective
				local adj_stem, adj_type = rmatch(arg_set[2], "^(.*)(%+.*)$")
				if adj_stem then
					arg_set[2] = adj_stem
					arg_set[3] = adj_type
				else
					-- recognize noun with ^
					local noun_stem, noun_type = rmatch(arg_set[2], "^(.*)%^(.*)$")
					if noun_stem then
						arg_set[2] = noun_stem
						arg_set[3] = noun_type
					else
						-- recognize noun without ^ but with decl spec
						noun_stem, noun_type = rmatch(arg_set[2], "^(..-)([;*(].*)$")
						if noun_stem then
							arg_set[2] = noun_stem
							arg_set[3] = noun_type
						else
							-- noun without ^ or decl spec; nothing to do
						end
					end
				end
			end
			table.insert(arg_sets, arg_set)
		end
	end

	return generate_forms_1(args, per_word_info)
end

-- Implementation of do_generate_forms() and do_generate_forms_multi(),
-- which have equivalent functionality but different calling sequence.
-- Implementation of do_generate_forms() and do_generate_forms_multi(),
-- which have equivalent functionality but different calling sequence,
-- as well as show_z() for template {{ru-decl-noun-z}}, which has a
-- subset of the functionality of the other two.
generate_forms_1 = function(args, per_word_info)
	local orig_args
	if test_new_ru_noun_module then
		orig_args = mw.clone(args)
	end

	local SUBPAGENAME = mw.title.getCurrentTitle().subpageText
	local old = args.old

	local function verify_animacy_value(val)
		if not val then return nil end
		if val == "a" or val == "an" or val == "anim" then
			return "a"
		elseif val == "i" or val == "in" or val == "inan" then
			return "i"
		elseif val == "b" or val == "bi" or val == "both" or val == "ai" then
			return "ai"
		elseif val == "ia" then
			return "ia"
		end
		error("Animacy value " .. val .. " should be empty or a/an/anim (animate), i/in/inan (inanimate), b/bi/both/ai (bianimate, listing animate first), or ia (bianimate, listing inanimate first)")
		return nil
	end

	local function verify_number_value(val, allow_none)
		if not val then return nil end
		local short = usub(val, 1, 1)
		if short == "s" or short == "p" or short == "b" or (allow_none and short == "n" or false) then
			return short
		end
		if allow_none then
			error("Number value " .. val .. " should be empty or start with 's' (singular), 'p' (plural), 'b' (both) or 'n' (none)")
		else
			error("Number value " .. val .. " should be empty or start with 's' (singular), 'p' (plural), or 'b' (both)")
		end
		return nil
	end

	-- Verify and canonicalize animacy, number, prefix, suffix
	assert(#per_word_info >= 1)
	for i=1,#per_word_info do
		args["a" .. i] = verify_animacy_value(args["a" .. i])
		args["n" .. i] = verify_number_value(args["n" .. i])
		args["prefix" .. i] = com.split_russian_tr(args["prefix" .. i] or "", "dopair")
		args["suffix" .. i] = com.split_russian_tr(args["suffix" .. i] or "", "dopair")
	end
	args.a = verify_animacy_value(args.a) or "i"
	-- args.ndef, if set, is the default value for args.n; if unset, it defaults
	-- to "both". It is set to "singular" in ru-proper noun+. We store the value
	-- of args.n in args.orign before defaulting to args.ndef because we may
	-- change it to plural-only later on if it was unspecified (this happens if
	-- an individual word's lemma is plural), and to determine whether it was
	-- unspecified, we need the original value before defaulting.
	args.n = verify_number_value(args.n, "allow none")
	-- treat n=none like n=sg but set a flag so "singular" isn't displayed
	if args.n == "n" then
		args.n = "s"
		args.nonumber = true
	end
	args.ndef = verify_number_value(args.ndef)
	args.orign = args.n
	args.n = args.n or args.ndef
	args.prefix = com.split_russian_tr(args.prefix or "", "dopair")
	args.suffix = com.split_russian_tr(args.suffix or "", "dopair")
	-- Attach overall prefix to first per-word prefix, similarly for suffix
	args.prefix1 = com.concat_paired_russian_tr(args.prefix, args.prefix1)
	args["suffix" .. #per_word_info] = com.concat_paired_russian_tr(
		args["suffix" .. #per_word_info], args.suffix)

	-- Initialize non-word-specific arguments.
	--
	-- The following is a list of WORD_INFO items, one per word, each of
	-- which is a two element list of WORD_FORMS (a table listing the forms for
	-- each case) and JOINER (a string, indicating how to join the word with
	-- the next one).
	args.per_word_info = {}
	-- List of HEADING_INFO items, one per word, containing the raw material
	-- used to generate the header. Initialized from 'args.heading_info',
	-- which is initialized in categorize_and_init_heading().
	args.per_word_heading_info = {}
	-- List of CATEGORIES items, one per word, containing the categories
	-- used to initialize the page categories. Initialized from
	-- 'args.categories', which is initialized in categorize_and_init_heading().
	args.per_word_categories = {}
	-- List of HEADINGS items, one per word, containing the actual words that
	-- go into the header if we were to use that word to construct the header.
	-- Comes from compute_heading(). We use this to generate the actual header
	-- string, which goes into 'args.heading' at the end (done in
	-- compute_overall_heading_categories_and_genders()).
	args.per_word_headings = {}
	-- List of GENDERS items, one per word, containing the headword genders
	-- for each word (where "headword gender" is in the format used in
	-- headwords and actually includes animacy and number as well, e.g.
	-- 'm-in' or 'f-an-p'). We end up selecting one such item and putting
	-- it into 'args.genders' at the end
	-- (in compute_overall_heading_categories_and_genders()).
	args.per_word_genders = {}
	args.any_overridden = {}
	args.any_non_nil = {}
	args.any_irreg = false
	args.any_irreg_case = {}
	local function insert_cat(cat)
		insert_category(args.categories, cat, args.pos)
	end
	args.internal_notes = {}
	local decl_sufs = old and declensions_old or declensions
	local decl_cats = old and declensions_old_cat or declensions_cat
	local intable = old and internal_notes_table_old or internal_notes_table

	-- Default lemma defaults to previous lemma, first one to page name.
	-- FIXME: With multiple words, we should probably split the page name
	-- on spaces and default each word in turn
	local default_lemma
	local all_stresses_seen

	-- Made into a function to avoid having to indent a lot of code.
	-- Process a single arg set of a single word. This inserts the forms
	-- for the word into args.forms and sets categories and tracking pages.
	local function do_arg_set(arg_set, n, islast)
		local stress_arg = arg_set[1]
		local decl = arg_set[3] or ""
		local pl, pltr
		if arg_set[4] then
			pl, pltr = com.split_russian_tr(arg_set[4])
		end

		-- Extract special markers from declension class.
		if decl == "manual" then
			decl = "$"
			args.manual = true
			if #per_word_info > 1 or #per_word_info[1][1] > 1 then
				error("Can't specify multiple words or argument sets when manual")
			end
			if pl then
				error("Can't specify optional stem parameters when manual")
			end
		end
		decl, args.jo_special = rsubb(decl, "([^/%a])ё$", "%1")
		if not args.jo_special then
			decl, args.jo_special = rsubb(decl, "([^/%a])ё([^/%a])", "%1%2")
		end
		decl, args.want_sc1 = rsubb(decl, "%(1%)", "")
		decl, args.alt_gen_pl = rsubb(decl, "%(2%)", "")
		decl, args.reducible = rsubb(decl, "%*", "")
		decl = rsub(decl, ";", "")

		-- Get the lemma.
		local lemma = args.manual and "-" or arg_set[2] or default_lemma
		if not lemma then
			error("Lemma in first argument set must be specified")
		end
		default_lemma = lemma
		local lemmatr
		lemma, lemmatr = com.split_russian_tr(lemma)

		-- If we're conjugating a suffix, insert a pseudoconsonant at the beginning
		-- of all forms, so they get conjugated as if ending in a consonant.
		-- We remove the pseudoconsonant later.
		local is_suffix = lemma ~= "-" and rfind(lemma, "^%-")
		args.any_suffix = args.any_suffix or is_suffix
		local asif_prefix = args["asif_prefix" .. n] or args.asif_prefix or is_suffix and PSEUDOCONS
		if asif_prefix then
			lemma = rsub(lemma, "^%-", "-" .. asif_prefix)
			if lemmatr then
				lemmatr = rsub(lemmatr, "^%-", "-" .. com.translit(asif_prefix))
			end
		end
		

		args.thisa = args["a" .. n] or args.a
		args.thisn = args["n" .. n] or args.n

		-- Check for explicit allow-unaccented indication.
		local allow_unaccented
		lemma, allow_unaccented = rsubb(lemma, "^%*", "")
		args.allow_unaccented = args.allow_unaccented or allow_unaccented
		if args.allow_unaccented then
			track("allow-unaccented")
		end

		args.orig_lemma = lemma
		lemma = m_links.remove_links(lemma)
		args.lemma_no_links = lemma
		args.lemmatr = lemmatr
		if args.lemma then
			-- Explicit lemma given.
			args.explicit_lemma, args.explicit_lemmatr = com.split_russian_tr(args.lemma)
		end

		-- Treat suffixes without an accent, and suffixes with an accent on the
		-- initial hyphen, as if they were preceded with a *, which overrides
		-- all the logic that normally (a) normalizes the accent, and (b)
		-- complains about multisyllabic words without an accent. Don't do this
		-- if lemma is just -, which is used specially in manual declension
		-- tables (e.g. сто, три).
		if lemma ~= "-" and (rfind(lemma, "^%-́") or (com.is_unstressed(lemma) and rfind(lemma, "^%-"))) then
			args.allow_unaccented = true
		end

		-- Convert lemma and decl arg into stem and canonicalized decl.
		-- This will autodetect the declension from the lemma if an explicit
		-- decl isn't given.
		local stem, tr, gender, was_accented, was_plural, was_autodetected
		if rfind(decl, "^%+") then
			stem, tr, decl, gender, was_accented, was_plural, was_autodetected =
				detect_adj_type(lemma, lemmatr, decl, old)
		else
			stem, tr, decl, gender, was_accented, was_plural, was_autodetected =
				determine_decl(lemma, lemmatr, decl, args)
		end
		if was_plural then
			args.n = args.orign or "p"
			args.thisn = args["n" .. n] or args.n
		elseif decl ~= "$" then
			args.thisn = args.thisn or "b"
		end

		args.explicit_gender = gender

		-- If allow-unaccented not given, maybe check for missing accents.
		if not args.allow_unaccented and not stress_arg and was_autodetected and com.needs_accents(lemma) then
			-- If user gave the full word and expects us to determine the
			-- declension and stress, the word should have an accent on the
			-- stem or ending. We have a separate check farther below for
			-- an accent on a multisyllabic stem, after stripping off any
			-- ending; but this way we get an error if the user e.g. writes
			-- "гора" without an accent rather than assuming it's stem
			-- stressed, as would otherwise happen.
			error("Lemma must have an accent in it: " .. lemma)
		end

		-- If stress not given, auto-determine; else validate/canonicalize
		-- stress arg, override in certain cases and convert to list.
		if not stress_arg then
			stress_arg = {detect_stress_pattern(stem, decl, decl_cats, args.reducible, was_plural, was_accented)}
		else
			stress_arg = rsplit(stress_arg, ",")
			for i=1,#stress_arg do
				local stress = stress_arg[i]
				stress = override_stress_pattern(decl, stress)
				if not stress_patterns[stress] then
					error("Unrecognized accent pattern " .. stress)
				end
				stress_arg[i] = stress
			end
		end

		-- parse slash decl to list
		local sub_decls
		if rfind(decl, "/") then
			track("mixed-decl")
			insert_cat("~ with mixed declension")
			local indiv_decls = rsplit(decl, "/")
			-- Should have been caught in canonicalize_decl()
			assert(#indiv_decls == 2)
			sub_decls = {{indiv_decls[1], "sg"}, {indiv_decls[2], "pl"}}
		else
			sub_decls = {{decl}}
		end

		-- Get singular declension and corresponding category.
		local sgdecl = sub_decls[1][1]
		local sgdc = decl_cats[sgdecl]
		assert(sgdc)

		-- Compute headword gender(s). We base it off the singular declension
		-- if we have a slash declension -- it's the best we can do.
		determine_headword_gender(args, sgdc, gender)

		local original_stem, original_tr = stem, tr
		local original_pl, original_pltr = pl, pltr

		-- Loop over accent patterns in case more than one given.
		for _, stress in ipairs(stress_arg) do
			args.suffixes = {}

			stem, tr = original_stem, original_tr
			local bare, baretr
			local stem_for_bare, tr_for_bare
			pl, pltr = original_pl, original_pltr

			insert_if_not(all_stresses_seen, stress)

			local stem_was_unstressed = com.is_unstressed(stem)

			-- If special case ;ё was given and stem is unstressed,
			-- add ё to the stem now; but don't let this interfere with
			-- restressing, to handle cases like железа́ with gen pl желёз
			-- but nom pl же́лезы.
			if stem_was_unstressed and args.jo_special then
				-- Beware, Cyrillic еЕ in first rsub, Latin eE in second
				local new_stem = rsub(stem, "([еЕ])([^еЕ]*)$",
					function(e, rest)
						return (e == "Е" and "Ё" or "ё") .. rest
					end
				)
				if stem == new_stem then
					error("No е in stem to replace with ё")
				end
				stem = new_stem
				if tr then
					local subbed
					-- e after j -> o, e not after j -> jo; don't just convert e -> jo
					-- and then map jjo -> jo because we want to preserve double j
					tr, subbed = rsubb(tr, "([jJ])([eE])([^eE]*)$",
						function(j, e, rest)
							return j .. (e == "E" and "O" or "o") .. AC .. rest
						end
					)
					if not subbed then
						tr = rsub(tr, "([eE])([^eE]*)$",
							function(e, rest)
								return (e == "E" and "Jo" or "jo") .. AC .. rest
							end
						)
					end
					tr = com.j_correction(tr)
				end
				-- This is used to handle железа́ with gen pl желёз and nom pl
				-- же́лезы. We have two stressed stems, one for the gen pl and
				-- one for the remaining pl cases, and the variable 'stem' can
				-- handle only one, so we put the second (gen pl) stem in
				-- stem_for_bare, which goes into the value of 'bare' (used
				-- only for gen pl here).
				stem_for_bare, tr_for_bare = stem, tr
			end

			-- Maybe add stress to the stem, depending on whether the
			-- stem was unstressed and the stress pattern. Stem pattern f
			-- and variants call for initial stress (голова́ -> го́ловы);
			-- stem pattern d and variants call for stem-final stress
			-- (сапожо́к -> сапо́жки). Stem patterns b and b' apparently
			-- call for stem-final stress as well but it's unlikely to
			-- make much of a difference (pattern b' only occurs in 3rd-decl
			-- feminines, which should already have stress in the stem,
			-- and the only place pattern b gets stem stress is in bare
			-- forms, i.e. nom sg and/or gen pl depending on the decl type,
			-- and nom sg stress should already be in the lemma while
			-- gen pl stress is handled by a different ending-stressing
			-- mechanism in attach_unstressed(); however, the user is
			-- free to leave a masc or 3rd-decl fem lemma completely
			-- unstressed with pattern b, and then the stem-final stress
			-- *will* make a difference).
			local function restress_stem(stem, tr, stress, stem_unstressed)
				-- If the user has indicated they purposely are leaving the
				-- word unstressed by putting a * at the beginning of the main
				-- stem, leave it unstressed. This might indicate lack of
				-- knowledge of the stress or a truly unaccented word
				-- (e.g. an unaccented suffix).
				if args.allow_unaccented then
					return stem, tr
				end
				if tr and com.is_unstressed(stem) ~= com.is_unstressed(tr) then
					error("Stem " .. stem .. " and translit " .. tr .. " must have same accent pattern")
				end
				-- it's safe to accent monosyllabic stems
				if com.is_monosyllabic(stem) then
					stem, tr = com.make_ending_stressed(stem, tr)
				-- For those patterns that are ending-stressed in the singular
				-- nominative (and hence are likely to be expressed without an
				-- accent on the stem) it's safe to put a particular accent on
				-- the stem depending on the stress type. Otherwise, give an
				-- error if no accent.
				elseif stem_unstressed then
					if rfind(stress, "^f") then
						stem, tr = com.make_beginning_stressed(stem, tr)
					elseif (rfind(stress, "^[bd]") or
						args.thisn == "p" and ending_stressed_pl_patterns[stress]) then
						stem, tr = com.make_ending_stressed(stem, tr)
					elseif com.needs_accents(stem) then
						error("Stem " .. stem .. " requires an accent")
					end
				end
				return stem, tr
			end

			stem, tr = restress_stem(stem, tr, stress, stem_was_unstressed)

			-- Leave pl unaccented if user wants this; see restress_stem().
			if pl and not args.allow_unaccented then
				if pltr and com.is_unstressed(pl) ~= com.is_unstressed(pltr) then
					error("Plural stem " .. pl .. " and translit " .. pltr .. " must have same accent pattern")
				end
				if com.is_monosyllabic(pl) then
					pl, pltr = com.make_ending_stressed(pl, pltr)
				end
				-- I think this is safe.
				if com.needs_accents(pl) then
					if ending_stressed_pl_patterns[stress] then
						pl, pltr = com.make_ending_stressed(pl, pltr)
					elseif not args.allow_unaccented then
						error("Plural stem " .. pl .. " requires an accent")
					end
				end
			end

			local resolved_bare, resolved_baretr
			-- Handle (de)reducibles
			-- FIXME! We are dereducing based on the singular declension.
			-- In a slash declension things can get weird and we don't
			-- handle that. We are also computing the bare value from the
			-- singular stem, and again things can get weird with a plural
			-- stem. Note that we don't compute a bare value unless we have
			-- to (either (de)reducible or stress pattern f/f'/f'' combined
			-- with ё special case); the remaining times we generate the bare
			-- value directly from the plural stem.
			if args.reducible and not sgdc.ignore_reduce then
				-- Zaliznyak treats all nouns in -ье and -ья as being
				-- reducible. We handle this automatically and don't require
				-- the user to specify this, but ignore it if so for
				-- compatibility.
				if is_reducible(sgdc) then
					-- If we derived the stem from a nom pl form, then
					-- it's already reduced, and we need to dereduce it to
					-- get a bare form; otherwise the stem comes from the
					-- nom sg and we need to reduce it to get the real stem.
					if was_plural then
						resolved_bare, resolved_baretr =
							export.dereduce_nom_sg_stem(stem, tr, sgdc,
								stress, old, "error")
					else
						resolved_bare, resolved_baretr = stem, tr
						stem, tr = export.reduce_nom_sg_stem(stem, tr,
							sgdecl, "error")
						-- Stem will be unstressed if stress was on elided
						-- vowel; restress stem the way we did above. (This is
						-- needed in at least one word, сапожо́к 3*d(2), with
						-- plural stem probably сапо́жк- and gen pl probably
						-- сапо́жек.)
						stem, tr = restress_stem(stem, tr, stress,
							com.is_unstressed(stem))
						if stress ~= "a" and stress ~= "b" and args.alt_gen_pl and not pl then
							-- Nouns like рожо́к, глазо́к of type 3*d(2) have
							-- gen pl's ро́жек, гла́зок; to handle this,
							-- dereduce the reduced stem and store in a
							-- special place.
							args.gen_pl_bare, args.gen_pl_baretr =
								export.dereduce_nom_sg_stem(stem, tr,
									sgdc, stress, old, "error")
						end
					end
				elseif is_dereducible(sgdc) then
					resolved_bare, resolved_baretr =
						export.dereduce_nom_sg_stem(stem, tr, sgdc,
							stress, old, "error")
				else
					error("Declension class " .. sgdecl .. " not (de)reducible")
				end
			elseif stem_for_bare and stem ~= stem_for_bare then
				resolved_bare, resolved_baretr =
					add_bare_suffix(stem_for_bare, tr_for_bare, old, sgdc, false)
			end

			-- Leave unaccented if user wants this; see restress_stem().
			-- FIXME, we no longer allow the user to specify the bare value
			-- so it's unclear if this is needed any more.
			if resolved_bare and not args.allow_unaccented then
				if resolved_baretr and com.is_unstressed(resolved_bare) ~= com.is_unstressed(resolved_baretr) then
					error("Resolved bare stem " .. resolved_bare .. " and translit " .. resolved_baretr .. " must have same accent pattern")
				end
				if com.is_monosyllabic(resolved_bare) then
					resolved_bare, resolved_baretr =
						com.make_ending_stressed(resolved_bare, resolved_baretr)
				else
					if com.needs_accents(resolved_bare) then
						error("Resolved bare stem " .. resolved_bare .. " requires an accent")
					end
				end
			end

			args.stem, args.stemtr = stem, tr
			args.bare, args.baretr = resolved_bare, resolved_baretr
			args.ustem, args.ustemtr = com.make_unstressed_once(stem, tr)
			if pl then
				args.pl, args.pltr = pl, pltr
			else
				args.pl, args.pltr = stem, tr
			end
			args.upl, args.upltr = com.make_unstressed_once(args.pl, args.pltr)
			-- Special hack for любо́вь and other reducible 3rd-fem nouns,
			-- which have the full stem in the ins sg
			args.ins_sg_stem = sgdecl == "ь-f" and args.reducible and resolved_bare
			args.ins_sg_tr = sgdecl == "ь-f" and args.reducible and resolved_baretr

			-- Loop over declension classes (we may have two of them, one for
			-- singular and one for plural, in the case of a mixed declension
			-- class of the form SGDECL/PLDECL).
			for _,decl_spec in ipairs(sub_decls) do
				local orig_decl = decl_spec[1]
				local number = decl_spec[2]
				local real_decl =
					determine_stress_variant(orig_decl, stress)
				real_decl = determine_stem_variant(real_decl,
					number == "pl" and args.pl or args.stem)
				-- sanity checking; errors should have been caught in
				-- canonicalize_decl()
				assert(decl_cats[real_decl], "real_decl " .. real_decl .. " nonexistent")
				assert(decl_sufs[real_decl], "real_decl " .. real_decl .. " nonexistent")
				tracking_code(stress, orig_decl, real_decl, args, n, islast)
				do_stress_pattern(stress, args, real_decl, number, n, islast)

				-- handle internal notes
				local internal_note = intable[real_decl]
				if internal_note then
					insert_if_not(args.internal_notes, internal_note)
				end
			end

			categorize_and_init_heading(stress, decl, args, n, islast)
		end
	end

	local n = 0
	for _, word_info in ipairs(per_word_info) do
		n = n + 1
		local islast = n == #per_word_info
		local arg_sets, joiner = word_info[1], word_info[2]
		args.forms = {}
		args.heading_info = {animacy={}, number={}, gender={}, stress={},
			stemetc={}, adjectival={}, reducible={}}
		args.categories = {}
		args.genders = {}
		args.this_any_non_nil = {}
		args.any_suffix = false

		if #arg_sets > 1 then
			track("multiple-arg-sets")
			insert_cat("~ with multiple argument sets")
			track("multiple-declensions")
			insert_cat("~ with multiple declensions")
		end

		default_lemma = SUBPAGENAME
		all_stresses_seen = {}

		-- Loop over all arg sets.
		for _, arg_set in ipairs(arg_sets) do
			do_arg_set(arg_set, n, islast)
		end

		if #all_stresses_seen > 1 then
			track("multiple-accent-patterns")
			insert_cat("~ with multiple accent patterns")
			track("multiple-declensions")
			insert_cat("~ with multiple declensions")
		end

		table.insert(args.per_word_heading_info, args.heading_info)
		table.insert(args.per_word_categories, args.categories)
		local headings = compute_heading(args)
		table.insert(args.per_word_headings, headings)
		table.insert(args.per_word_genders, args.genders)

		handle_forms_and_overrides(args, n, islast)

		if args.any_suffix then
			-- If we're conjugating a suffix, remove the pseudoconsonant or asif_prefix
			-- that we previously inserted at the beginning.
			local asif_prefix = args["asif_prefix" .. n] or args.asif_prefix or PSEUDOCONS
			local asif_prefix_tr = com.translit(asif_prefix)

			for _, case in ipairs(all_cases) do
				if args.forms[case] then
					local newforms = {}
					for _, form in ipairs(args.forms[case]) do
						local formru = form[1]
						local formtr = form[2]
						formru = rsub(formru, "^%-" .. asif_prefix, "-")
						if formtr then
							formtr = rsub(formtr, "^%-" .. asif_prefix_tr, "-")
						end
						if formru == "-" then
							-- if no ending, insert "(no suffix)".
							table.insert(newforms, {"(no suffix)"})
						else
							table.insert(newforms, {formru, formtr})
						end
					end
					args.forms[case] = newforms
				end
			end
		end

		table.insert(args.per_word_info, {args.forms, joiner})
	end

	handle_overall_forms_and_overrides(args)
	compute_overall_heading_categories_and_genders(args)

	for _, case in ipairs(all_cases) do
		if args[case] then
			for _, form in ipairs(args[case]) do
				local ru, tr = form[1], form[2]
				local ruentry, runotes = m_table_tools.separate_notes(ru)
				ruentry = m_links.remove_links(ruentry)
				if rfind(ulower(ruentry), latin_text_class) then
					--error("Found Latin text " .. ruentry .. " in case " .. case) 
					track("latin-text")
					track("latin-text/" .. case)
				end
			end
		end
	end

	-- Test code to compare existing module to new one.
	if test_new_ru_noun_module then
		local m_new_ru_noun = require("Module:User:Benwing2/ru-noun")
		local newargs = m_new_ru_noun.do_generate_forms(orig_args, old)
		local difdecl = false
		for _, case in ipairs(all_cases) do
			local arg = args[case]
			local newarg = newargs[case]
			local is_pl = rfind(case, "_pl")
			if args.thisn == "s" and is_pl or args.thisn == "p" and not is_pl then
				-- Don't need to check cases that won't be displayed.
			elseif not m_table.deepEquals(arg, newarg) then
				local monosyl_accent_diff = false
				-- Differences only in monosyllabic accents. Enable if we
				-- change the algorithm for these.
				--if arg and newarg and #arg == 1 and #newarg == 1 then
				--	local ru1, tr1 = arg[1][1], arg[1][2]
				--	local ru2, tr2 = newarg[1][1], newarg[1][2]
				--	if com.is_monosyllabic(ru1) and com.is_monosyllabic(ru2) then
				--		ru1, tr1 = com.remove_accents(ru1, tr1)
				--		ru2, tr2 = com.remove_accents(ru2, tr2)
				--		if ru1 == ru2 and tr1 == tr2 then
				--			monosyl_accent_diff = true
				--		end
				--	end
				--end
				if monosyl_accent_diff then
					track("monosyl-accent-diff")
					difdecl = true
				else
					-- Uncomment this to display the particular case and
					-- differing forms.
					--error(case .. " " .. (arg and com.concat_forms(arg) or "nil") .. " || " .. (newarg and com.concat_forms(newarg) or "nil"))
					track("different-decl")
					difdecl = true
				end
				break
			end
		end
		if not difdecl then track("same-decl") end
	end

	return args
end

-- Implementation of main entry point
local function do_show(frame, old)
	local args = clone_args(frame)
	local args = export.do_generate_forms(args, old)
	return make_table(args) .. m_utilities.format_categories(args.categories, lang)
end

-- The main entry point for modern declension tables.
function export.show(frame)
	return do_show(frame, false)
end

-- The main entry point for old declension tables.
function export.show_old(frame)
	return do_show(frame, true)
end

-- Implementation of new entry point, esp. for multiple words
local function do_show_multi(frame)
	local args = clone_args(frame)
	local args = export.do_generate_forms_multi(args)
	return make_table(args) .. m_utilities.format_categories(args.categories, lang)
end

-- The new entry point, esp. for multiple words (but works fine for
-- single words).
function export.show_multi(frame)
	return do_show_multi(frame)
end

local function get_form(forms, preserve_links, raw)
	local canon_forms = {}
	for _, form in ipairs(forms) do
		if raw then
			local ru, tr = form[1], form[2]
			ru = rsub(ru, "|", "<!>")
			if tr then
				tr = rsub(tr, "|", "<!>")
			end
			insert_if_not(canon_forms, {ru, tr})
		else
			local ru, tr = form[1], form[2]
			local ruentry, runotes = m_table_tools.separate_notes(ru)
			-- Skip hypothetical forms (but include in the raw versions)
			if not rfind(runotes, HYPMARKER) then
				local trentry, trnotes
				if tr then
					trentry, trnotes = m_table_tools.separate_notes(tr)
				end
				if not preserve_links then
					ruentry = m_links.remove_links(ruentry)
				end
				ruentry = rsub(ruentry, "|", "<!>")
				if trentry then
					trentry = rsub(trentry, "|", "<!>")
				end
				insert_if_not(canon_forms, {ruentry, trentry})
			end
		end
	end
	return com.concat_forms(canon_forms)
end

local function case_will_be_displayed(args, case)
	local ispl = rfind(case, "_pl")
	local caseok = true
	if args.n == "p" then
		caseok = ispl
	elseif args.n == "s" then
		caseok = not ispl
	end
	for _, override_case in ipairs(overridable_only_cases) do
		if case == override_case and not args.any_overridden[override_case] then
			caseok = false
			break
		end
	end
	if args.a == "a" or args.a == "i" then
		if rfind(case, "_[ai]n") then
			caseok = false
		end
	else -- bianimate
		-- don't include inanimate/animate variants if combined variant exists
		-- (typically because inanimate/animate variants are the same);
		-- FIXME: This could conceivably be different from how the display
		-- code works, which just checks that the inanimate/animate variants
		-- are the same when deciding whether to display them, in particular
		-- if there is an override. Here we are following the algorithm of
		-- handle_overall_forms_and_overrides().
		if (case == "acc_sg_in" or case == "acc_sg_an") and args.acc_sg or
		   (case == "acc_pl_in" or case == "acc_pl_an") and args.acc_pl then
		   	caseok = false
		end
	end
	if not args[case] then
		caseok = false
	end
	return caseok
end

local function concat_case_args(args, do_all, raw)
	local ins_text = {}
	for _, case in ipairs(do_all and all_cases or overridable_cases) do
		if case_will_be_displayed(args, case) then
			local forms = get_form(args[case], rfind(case, "_linked"), raw)
			if forms ~= "" then
				table.insert(ins_text, case .. (raw and "_raw" or "") .. "=" ..
					forms)
			end
		end
	end
	return table.concat(ins_text, "|")
end

-- The entry point for 'ru-noun-forms' to generate all noun forms.
-- This returns a single string, with | separating arguments and named
-- arguments of the form NAME=VALUE.
function export.generate_forms(frame)
	local args = clone_args(frame)
	args = export.do_generate_forms(args, false)
	return concat_case_args(args)
end

-- The entry point to generate multiple sets of noun forms. This is a hack
-- to speed up calling from a bot, where we often want to compare old and new
-- argument results to make sure they're the same. Each set of arguments is
-- jammed together into a single argument with individual values separated by
-- <!>; named arguments are of the form NAME<->VALUE. The return value for
-- each set of arguments is as in export.generate_forms(), and the return
-- values are concatenated with <!> separating them. NOTE: This will fail if
-- the exact sequences <!> or <-> happen to occur in values (which is unlikely,
-- esp. as we don't even use the characters <, ! or > for anything) and aren't
-- HTML-escaped.
function export.generate_multi_forms(frame)
	local retvals = {}
	for _, argset in ipairs(frame.args) do
		local args = {}
		local i = 0
		local argvals = rsplit(argset, "<!>")
		for _, argval in ipairs(argvals) do
			local split_arg = rsplit(argval, "<%->")
			if #split_arg == 1 then
				i = i + 1
				args[i] = ine(split_arg[1])
			else
				assert(#split_arg == 2)
				args[split_arg[1]] = ine(split_arg[2])
			end
		end
		args = export.do_generate_forms(args, false)
		table.insert(retvals, concat_case_args(args))
	end
	return table.concat(retvals, "<!>")
end

-- The entry point for 'ru-noun-form' to generate a particular noun form.
function export.generate_form(frame)
	local args = clone_args(frame)
	if not args.form then
		error("Must specify desired form using form=")
	end
	local form = args.form
	if not m_table.contains(all_cases, form) then
		error("Unrecognized form " .. form)
	end
	local args = export.do_generate_forms(args, false)
	if not args[form] then
		return ""
	else
		return get_form(args[form])
	end
end

-- The entry point for generating arguments of various sorts, including
-- the case forms, gender, number and animacy.
function export.generate_args(frame)
	local args = clone_args(frame)
	args = export.do_generate_forms(args, false)
	local retargs = {}
	table.insert(retargs, concat_case_args(args, "doall"))
	table.insert(retargs, concat_case_args(args, "doall", "raw"))
	table.insert(retargs, "g=" .. table.concat(args.genders, ","))
	-- The following is correct even with ndef because if ndef is 
	-- set we will set it in args.n.
	table.insert(retargs, "n=" .. (args.n or "b"))
	table.insert(retargs, "a=" .. (args.a or "i"))
	return table.concat(retargs, "|")
end

-- The entry point for compatibility with {{ru-decl-noun-z}}.
function export.show_z(frame)
	local args = clone_args(frame)

	local stem = args[1]
	local stress = args[2]
	local specific = args[4] or ""

	-- Parse gender/animacy spec
	local gender, anim = rmatch(args[3], "^([mfn])-([a-z]+)")
	if not gender then
		error("Unrecognized gender/anim spec " .. args[3])
	end
	if anim ~= "an" and anim ~= "in" then anim = "both" end
	args.a = anim

	-- Handle specific
	specific = rsub(specific, "ё", ";ё")

	-- Compute decl; special case for семьянин (perhaps not necessary)
	local decl = com.make_unstressed_once(stem) == "семьянин" and "#" .. specific or gender .. specific

	-- Handle overrides
	args.pre_sg = args.prp_sg
	args.pre_pl = args.prp_pl
	args.notes = args.note
	if args.par then
		args.par = "+"
	end
	if args.loc then
		if args.loc == "в" then
			args.loc = "в +"
		elseif args.loc == "на" then
			args.loc = "на +"
		else
			args.loc = "в +,на +"
		end
	end

	local arg_set = {}
	table.insert(arg_set, stress)
	table.insert(arg_set, stem)
	table.insert(arg_set, decl)

	local per_word_info = {{{arg_set}, ""}}

	return generate_forms_1(args, per_word_info)
end


--------------------------------------------------------------------------
--                   Autodetection and lemma munging                    --
--------------------------------------------------------------------------

-- Attempt to detect the type of the lemma based on its ending, separating
-- off the stem and the ending. GENDER must be present with -ь and plural
-- stems, and is otherwise ignored. Return up to three values: The stem
-- (lemma minus ending), the singular lemma ending, and if the lemma was
-- plural, the plural lemma ending. If the lemma was singular, the singular
-- lemma ending will contain any user-given accents; likewise, if the
-- lemma was plural, the plural ending will contain such accents.
-- VARIANT comes from the declension spec and controls certain declension
-- variants.
local function detect_lemma_type(lemma, tr, gender, args, variant)
	local base, ending = rmatch(lemma, "^(.*)([еЕ]́)$") -- accented
	if base then
		return base, com.strip_tr_ending(tr, ending), ulower(ending)
	end
	base, ending = rmatch(lemma, "^(.*[" .. com.sib_c .. "])([еЕ])$") -- unaccented
	if base then
		if variant == "-ище" and not rfind(lemma, "[щЩ][еЕ]$") then
			error("With declension variant -ище, lemma should end in -ще: " .. lemma)
		end
		return base, com.strip_tr_ending(tr, ending), variant == "-ище" and "(ищ)е-и" or "о"
	end
	if variant == "-ишко" then
		base, ending = rmatch(lemma, "^(.*[шШ][кК])([оО])$") -- unaccented
		if not base then
			error("With declension variant -ишко, lemma should end in -шко: " .. lemma)
		end
		return base, com.strip_tr_ending(tr, ending), "(ишк)о-и"
	end
	if variant == "-ин" then
		base, ending = rmatch(lemma, "^(.*)([иИ]́?[нН][ъЪ]?)$") -- maybe accented
		if not base then
			error("With declension variant -ин, lemma should end in -ин(ъ): " .. lemma)
		end
		return base, com.strip_tr_ending(tr, ending), ulower(ending)
	end
	-- Now autodetect -ин; only animate and in -анин/-янин
	base, ending = rmatch(lemma, "^(.*[аяАЯ]́?[нН])([иИ]́?[нН][ъЪ]?)$")
	-- Need to check the animacy to avoid nouns like маиганин, цианин,
	-- меланин, соланин, etc.
	if base and args.thisa == "a" then
		return base, com.strip_tr_ending(tr, ending), ulower(ending)
	end
	base, ending = rmatch(lemma, "^(.*)([ёЁ]́?[нН][оО][кК][ъЪ]?)$")
	if base then
		return base, com.strip_tr_ending(tr, ending), ulower(ending)
	end
	base, ending = rmatch(lemma, "^(.*[" .. com.sib_c .. "])([оО]́[нН][оО][кК][ъЪ]?)$")
	if base then
		return base, com.strip_tr_ending(tr, ending), ulower(ending)
	end
	base, ending = rmatch(lemma, "^(.*)([ёЁ]́?[нН][оО][чЧ][еЕ][кК][ъЪ]?)$")
	if base then
		return base, com.strip_tr_ending(tr, ending), ulower(ending)
	end
	base, ending = rmatch(lemma, "^(.*[" .. com.sib_c .. "])([оО]́[нН][оО][чЧ][еЕ][кК][ъЪ]?)$")
	if base then
		return base, com.strip_tr_ending(tr, ending), ulower(ending)
	end
	base, ending = rmatch(lemma, "^(.*)([мМ][яЯ]́?)$")
	if base then
		return base, com.strip_tr_ending(tr, ending), ulower(ending)
	end

	--recognize plural endings
	if gender == "n" then
		base, ending = rmatch(lemma, "^(.*)([ьЬ][яЯ]́?)$")
		if base then
			-- Don't do this; о/-ья is too rare
			-- error("Ambiguous plural lemma " .. lemma .. " in -ья, singular could be -о or -ье/-ьё; specify the singular")
			return base, com.strip_tr_ending(tr, ending), "ье", ending
		end
		base, ending = rmatch(lemma, "^(.*)([аяАЯ]́?)$")
		if base then
			return base, com.strip_tr_ending(tr, ending), rfind(ending, "[аА]") and "о" or "е", ending
		end
		base, ending = rmatch(lemma, "^(.*)([ыиЫИ]́?)$")
		if base then
			if rfind(ending, "[ыЫ]") or rfind(base, "[" .. com.sib .. com.velar .. "]$") then
				return base, com.strip_tr_ending(tr, ending), "о-и", ending
			else
				-- FIXME, should we return a slash declension?
				error("No neuter declension е-и available; use a slash declension")
			end
		end
	end
	if gender == "f" then
		base, ending = rmatch(lemma, "^(.*)([ьЬ][иИ]́?)$")
		if base then
			return base, com.strip_tr_ending(tr, ending), "ья", ending
		end
	end
	-- Recognize masculines with irregular plurals, but only if the user
	-- either explicitly specified that this noun is plural (n=p) or
	-- specifically requested the irregular plural. This is necessary
	-- because some masculine nouns have feminine endings, which look
	-- like irregular plurals.
	if gender == "m" then
		if args.thisn == "p" or variant == "-ья" then
			base, ending = rmatch(lemma, "^(.*)([ьЬ][яЯ]́?)$")
			if base then
				return base, com.strip_tr_ending(tr, ending), (args.old and "ъ-ья" or "-ья"), ending
			end
		end
		if args.thisn == "p" or args.want_sc1 then
			base, ending = rmatch(lemma, "^(.*)([аА]́?)$")
			if base then
				return base, com.strip_tr_ending(tr, ending), (args.old and "ъ-а" or "-а"), ending
			end
			base, ending = rmatch(lemma, "^(.*)([яЯ]́?)$")
			if base then
				if rfind(base, "[" .. com.vowel .. "]́?$") then
					return base, com.strip_tr_ending(tr, ending), "й-я", ending
				else
					return base, com.strip_tr_ending(tr, ending), "ь-я", ending
				end
			end
		end
	end
	if gender == "m" or gender == "f" then
		base, ending = rmatch(lemma, "^(.*[" .. com.sib .. com.velar .. "])([иИ]́?)$")
		if not base then
			base, ending = rmatch(lemma, "^(.*)([ыЫ]́?)$")
		end
		if base then
			return base, com.strip_tr_ending(tr, ending), gender == "m" and (args.old and "ъ" or "") or "а", ending
		end
		base, ending = rmatch(lemma, "^(.*[" .. com.vowel .. "й]́?)([иИ]́?)$")
		if base then
			return base, com.strip_tr_ending(tr, ending), gender == "m" and "й" or "я", ending
		end
		base, ending = rmatch(lemma, "^(.*)([иИ]́?)$")
		if base then
			return base, com.strip_tr_ending(tr, ending), gender == "m" and "ь-m" or "я", ending
		end
	end
	if gender == "3f" then
		base, ending = rmatch(lemma, "^(.*)([иИ]́?)$")
		if base then
			return base, com.strip_tr_ending(tr, ending), "ь-f", ending
		end
	end
	-- end of recognize-plurals code

	base, ending = rmatch(lemma, "^(.*)([ьЬ][яеёЯЕЁ]́?)$")
	if base then
		return base, com.strip_tr_ending(tr, ending), ulower(ending)
	end
	base, ending = rmatch(lemma, "^(.*)([йаяеоёъЙАЯЕОЁЪ]́?)$")
	if base then
		return base, com.strip_tr_ending(tr, ending), ulower(ending)
	end
	base, ending = rmatch(lemma, "^(.*)([ьЬ])$")
	if base then
		if gender == "m" or gender == "f" then
			return base, com.strip_tr_ending(tr, ending), "ь-" .. gender
		elseif gender == "3f" then
			return base, com.strip_tr_ending(tr, ending), "ь-f"
		else
			error("Need to specify gender m or f with lemma in -ь: ".. lemma)
		end
	end
	if rfind(lemma, "[ыиЫИ]́?$") then
		error("If this is a plural lemma, gender must be specified: " .. lemma)
	elseif rfind(lemma, "[уыэюиіѣѵУЫЭЮИІѢѴ]́?$") then
		error("Don't know how to decline lemma ending in this type of vowel: " .. lemma)
	end
	return lemma, tr, ""
end

local plural_variant_detection_map = {
	[""] = {["-ья"]="-ья"},
	["ъ"] = {["-ья"]="ъ-ья"},
}

local special_case_1_to_plural_variant = {
	[""] = "-а",
	["ъ"] = "ъ-а",
	["й"] = "й-я",
	["ь-m"] = "ь-я",
	["о"] = "о-и",
	-- these last two are here to avoid getting errors in that checks for
	-- compatibility with special case 1; the basic variants of these decls
	-- don't actually exist
	["(ишк)о"] = "(ишк)о-и",
	["(ищ)е"] = "(ищ)е-и",
}

local function map_decl(decl, fun)
	if rfind(decl, "/") then
		local split_decl = rsplit(decl, "/")
		if #split_decl ~= 2 then
			error("Mixed declensional class " .. decl
				.. "needs exactly two classes, singular and plural")
		end
		return fun(split_decl[1]) .. "/" .. fun(split_decl[2])
	else
		return fun(decl)
	end
end

-- Canonicalize decl class into non-accented and alias-resolved form;
-- but note that some canonical decl class names with an accent in them
-- (e.g. е́, not the same as е, whose accented version is ё; and various
-- adjective declensions).
local function canonicalize_decl(decl, old)
	local function do_canon(decl)
		-- remove accents, but not from е́ (for adj decls, accent matters
		-- as well but we handle that by mapping the accent to a stress pattern
		-- and then to the accented version in determine_stress_variant())
		if decl ~= "е́" then
			decl = com.remove_accents(decl)
		end

		local decl_aliases = old and declensions_old_aliases or declensions_aliases
		local decl_cats = old and declensions_old_cat or declensions_cat
		if decl_aliases[decl] then
			-- If we find an alias, map it.
			decl = decl_aliases[decl]
		elseif not decl_cats[decl] then
			error("Unrecognized declension class " .. decl)
		end
		return decl
	end
	return map_decl(decl, do_canon)
end

-- Attempt to determine the actual declension (including plural variants)
-- based on a combination of the declension the user specified, what can be
-- detected from the lemma, and special case (1), if given in the declension.
-- DECL is the value the user passed for the declension field, after
-- extraneous annotations (special cases (1) and (2), * for reducible,
-- ё for ё/ё alternation and a ; that may precede ё) have been stripped off.
-- What's left is one of the following:
--
-- 1. Blank, meaning to autodetect the declension from the lemma
-- 2. A hyphen followed by a declension variant (-ья, -ин, -ишко, -ище; see
--    long comment at top of file)
-- 3. A gender (m, f, n, 3f)
-- 4. A gender plus declension variant (e.g. f-ья)
-- 5. An actual declension, possibly including a plural variant (e.g. о-и) or
--    a slash declension (e.g. я/-ья, used for the noun дядя).
--
-- Return seven args: stem (lemma minus ending), translit, canonicalized
-- declension, explicitly specified gender if any (m, f, n or nil), whether
-- the specified declension or detected ending was accented, whether the
-- detected ending was pl, and whether the declension was autodetected
-- (corresponds to cases where a full word with ending attached is required
-- in the lemma field). "Canonicalized" means after autodetection, with
-- accents removed, with any aliases mapped to their canonical versions
-- and with any requested declension variants applied. The result is either a
-- declension that will have a categorization entry (in declensions_cat[] or
-- declensions_old_cat[]) or a slash declension where each part similarly has
-- a categorization entry.
--
-- Note that gender is never required when an explicit declension is given,
-- and in connection with stem autodetection is required only when the lemma
-- either ends in -ь or is plural.
determine_decl = function(lemma, tr, decl, args)
	-- Assume we're passed a value for DECL of types 1-4 above, and
	-- fetch gender and requested declension variant.
	local stem
	local want_ya_plural, orig_pl_ending, variant
	local was_autodetected
	local gender = rmatch(decl, "^(3?[mfn]?)$")
	if not gender then
		gender, variant = rmatch(decl, "^(3?[mfn]?)(%-[^%-]+)$")
		-- But be careful with explicit declensions like -а that look like
		-- variants without gender (FIXME, eventually we should maybe do
		-- something about the potential ambiguity).
		if gender == "" and not m_table.contains({"-ья", "-ин", "-ишко", "-ище"}, variant) then
			gender, variant = nil, nil
		end
	end
	-- If DECL is of type 1-4, handle declension variants and detect
	-- the actual declension from the lemma.
	if gender then
		-- Check for declension variants
		if variant then
			if variant == "-ья" then
				want_ya_plural = "-ья"
			else
				-- Sanity-check remaining declension variants, which need
				-- specific values of animacy, gender and special-case (1)
				local sc1_needed
				local animate_needed
				if variant == "-ишко" then
					animate_needed = false
					sc1_needed = true
				elseif variant == "-ище" then
					animate_needed = true
					sc1_needed = true
				elseif variant == "-ин" then
					animate_needed = true
					sc1_needed = false
				else
					-- WARNING: If adding another variant, you need to also
					-- add to the list farther above.
					error("Unrecognized declension variant " .. variant .. ", should be -ья, -ин, -ишко or -ище")
				end
				if sc1_needed and not args.want_sc1 then
					error("Declension variant " .. variant .. " must be used with special case (1)")
				elseif sc1_needed == false and args.want_sc1 then
					error("Declension variant " .. variant .. " must not be used with special case (1)")
				end
				if animate_needed and args.thisa ~= "a" then
					error("Declension variant " .. variant .. " must be specified as animate")
				elseif animate_needed == false and args.thisa == "a" then
					error("Declension variant " .. variant .. " must not be specified as animate")
				end
				if gender ~= "" and gender ~= "m" then
					error("Declension variant " .. variant .. " should be used with the masculine gender")
				end
			end
		end
		stem, tr, decl, orig_pl_ending = detect_lemma_type(lemma, tr, gender,
			args, variant)
		was_autodetected = true
	else
		stem, tr = lemma, tr
	end
	-- Now canonicalize gender
	if gender == "3f" then
		gender = "f"
	elseif gender == "" then
		gender = nil
	end

	-- The ending should be treated as accented if either the original singular
	-- or plural ending was accented, or if the stem is non-syllabic.
	local was_accented = com.is_stressed(decl) or
		orig_pl_ending and com.is_stressed(orig_pl_ending) or
		com.is_nonsyllabic(stem)
	local was_plural = not not orig_pl_ending
	decl = canonicalize_decl(decl, args.old)

	-- The rest of this code concerns plural variants. It's somewhat
	-- complicated because there are potentially four sources of plural
	-- variants (not to mention plural variants constructed using slash
	-- notation):
	--
	-- 1. A user-requested plural variant in declension types 2 or 4 above
	--    (currently only -ья)
	-- 2. An explicit plural variant encoded in an explicit declension of
	--    type 5 above
	-- 3. An autodetected plural variant (which will happen in some cases
	--    when autodetection is performed on a nominative plural)
	-- 4. A plural variant derived using special case (1).
	--
	-- Up to three actual plural variants might exist (e.g. if the user
	-- specifies a DECL value or 'm-ья(1)' and a STEM ending in -а,
	-- although not all three can ever be compatible because -ья and (1)
	-- are never compatible). We can't have all four because if there's
	-- an explicit plural variant, there won't be a user-requested or
	-- autodetected plural variant.
	--
	-- The goal below is to do two things: Check that all available plural
	-- variants are the same, and generate the actual declension.
	-- If we have a type-2 or type-3 variant, we already have the actual
	-- declension; else we need to use a table to map the basic declension
	-- to the one with the plural variant encoded in it.
	--
	-- NOTE: The code below was written with a more general plural-variant
	-- system. It probably can be simplified a lot now.

	-- 1: Handle explicit decl with slash variant
	if rfind(decl, "/") then
		if want_ya_plural then
			-- Don't think this can happen
			error("Plural variant " .. want_ya_plural .. " not compatible with slash declension " .. decl)
		end
		if args.want_sc1 then
			error("Special case (1) not compatible with slash declension" .. decl)
		end
		return stem, tr, decl, gender, was_accented, was_plural, was_autodetected
	end

	-- 2: Retrieve explicitly specified or autodetected decl and pl. variant
	local basic_decl, detected_or_explicit_plural = rmatch(decl, "^(.*)(%-[^mf]+)$")
	if basic_decl == "ь" then
		basic_decl = "ь-m"
	end
	basic_decl = basic_decl or decl

	-- 3: Any user-requested plural variant must agree with explicit or
	--    autodetected variant.
	if want_ya_plural and detected_or_explicit_plural and want_ya_plural ~= detected_or_explicit_plural then
		error("Plural variant " .. want_ya_plural .. " requested but plural variant " .. detected_or_explicit_plural .. " detected from plural stem")
	end

	-- 4: Handle special case (1). Derive the full declension, make sure its
	--    plural variant matches any other available plural variants, and
	--    return the declension.
	if args.want_sc1 then
		local sc1_decl = special_case_1_to_plural_variant[basic_decl] or
			error("Special case (1) not compatible with declension " .. basic_decl)
		local sc1_plural = rsub(sc1_decl, "^.*%-", "-")
		local other_plural = want_ya_plural or detected_or_explicit_plural
		if other_plural and sc1_plural ~= other_plural then
			error("Plural variant " .. other_plural .. " specified or detected, but special case (1) calls for plural variant " .. sc1_plural)
		end
		return stem, tr, sc1_decl, gender, was_accented, was_plural, was_autodetected
	end

	-- 5: Handle user-requested plural variant without explicit or detected
	--    one. (If an explicit or detected one exists, we've already checked
	--    that it agrees with the user-requested one, and so we already have
	--    our full declension.)
	if want_ya_plural and not detected_or_explicit_plural then
		local variant_decl
		if plural_variant_detection_map[decl] then
			variant_decl = plural_variant_detection_map[decl][want_ya_plural]
		end
		if variant_decl then
			return stem, tr, variant_decl, gender, was_accented, was_plural, was_autodetected
		else
			return stem, tr, decl .. (args.old and "/ъ-ья" or "/-ья"), gender, was_accented, was_plural, was_autodetected
		end
	end

	-- 6: Just return the full declension, which will include any available
	--    plural variant in it.
	return stem, tr, decl, gender, was_accented, was_plural, was_autodetected
end

-- Convert soft adjectival declensions into hard ones following certain
-- stem-final consonants. FIXME: We call this in two places, once
-- to handle auto-detection and once to handle explicit declensions; but
-- in the former case we end up calling it twice.
function determine_adj_stem_variant(decl, stem)
	local iend = rmatch(decl, "^%+[іи]([йея]?)$")
	-- Convert ій/ий to ый after velar or sibilant. This is important for
	-- velars; doesn't really matter one way or the other for sibilants as
	-- the sibilant rules will convert both sets of endings to the same
	-- thing (whereas there will be a difference with о vs. е for velars).
	if iend and rfind(stem, "[" .. com.velar .. com.sib .. "]$") then
		decl = "+ы" .. iend
	-- The following is necessary for -ц, unclear if makes sense for
	-- sibilants. (Would be necessary -- I think -- if we were
	-- inferring short adjective forms, but we're not.)
	elseif decl == "+ее" and rfind(stem, "[" .. com.sib_c .. "]$") then
		decl = "+ое"
	end
	return decl
end

-- Attempt to determine the actual adjective declension based on a
-- combination of the declension the user specified and what can be detected
-- from the stem. DECL is the value the user passed for the declension field,
-- after extraneous annotations have been removed (although none are probably
-- relevant here). What's left is one of the following, which always begins
-- with +:
--
-- 1. +, meaning to autodetect the declension from the stem
-- 2. +ь, same as + but selects +ьий instead of +ий if lemma ends in -ий
-- 3. +short, +mixed or +proper, with the declension partly specified but
--    the particular gender/number-specific short/mixed variant to be
--    autodetected
-- 4. A gender (+m, +f or +n), used only for detecting the singular of
--    plural-form lemmas (this is primarily used in conjunction with template
--    ru-noun+, to explicitly specify the gender; for the actual declension,
--    it doesn't much matter what singular gender we pick since we're a
--    plural only)
-- 5. A gender plus short/mixed/proper/ь (e.g. +f-mixed), again with the gender
--    used only for detecting the singular of plural-form short/mixed lemmas
-- 6. An actual declension, possibly including a slash declension
--    (WARNING: Unclear if slash declensions will work, especially those
--    that are adjective/noun combinations)
--
-- Returns the same seven args as for determine_decl(). The returned
-- declension will always begin with +.
detect_adj_type = function(lemma, tr, decl, old)
	local was_autodetected
	local base, ending
	local basedecl, g = rmatch(decl, "^(%+)([mfn])$")
	if not basedecl then
		g, basedecl = rmatch(decl, "^%+([mfn])%-([a-zь]+)$")
		if basedecl then
			basedecl = "+" .. basedecl
		end
	end
	decl = basedecl or decl
	if decl == "+" or decl == "+ь" then
		base, ending = rmatch(lemma, "^(.*)([ыиіьаяое]́?[йея])$")
		if ending == "ий" and decl == "+ь" then
			decl = "+ьий"
		elseif ending == "ій" and decl == "+ь" then
			decl = "+ьій"
		elseif ending then
			decl = "+" .. ending
		else
			base, ending = rmatch(lemma, "^(.-)([оаыъ]?́?)$")
			assert(base)
			local shortmixed = rfind(base, "^[" .. com.uppercase .. "].*[иы]́н$") and "stressed-proper" or -- accented
				rfind(base, "^[" .. com.uppercase .. "].*[иы]н$") and "proper" or --not accented
				rlfind(base, "[ёео]́?в$") and "short" or
				rlfind(base, "[ыи]́н$") and "stressed-short" or -- accented
				rlfind(base, "[ыи]н$") and "mixed" --not accented
			if not shortmixed then
				error("Cannot determine stem type of adjective: " .. lemma)
			end
			decl = "+" .. ending .. "-" .. shortmixed
		end
		was_autodetected = true
	elseif m_table.contains({"+short", "+mixed", "+proper"}, decl) then
		base, ending = rmatch(lemma, "^(.-)([оаыъ]?́?)$")
		assert(base)
		local shortmixed = usub(decl, 2)
		if rlfind(base, "[ыи]́н$") then -- accented
			if shortmixed == "short" then shortmixed = "stressed-short"
			elseif shortmixed == "proper" then shortmixed = "stressed-proper"
			end
		end
		decl = "+" .. ending .. "-" .. shortmixed
		was_autodetected = true
	else
		base = lemma
	end
	if ending and ending ~= "" then
		tr = com.strip_tr_ending(tr, ending)
	end

	-- Remove any accents from the declension, but not their presence.
	-- We will convert was_accented into stress pattern b, and convert that
	-- back to an accented version in determine_stress_variant(). This way
	-- we end up with the stressed version whether the user placed an accent
	-- in the ending or decl or specified stress pattern b.
	-- FIXME, might not work in the presence of slash declensions
	local was_accented = com.is_stressed(decl)
	decl = com.remove_accents(decl)

	decl = map_decl(decl, function(decl)
		return determine_adj_stem_variant(decl, base)
	end)
	local singdecl
	if decl == "+ые" then
		singdecl = (g == "m" or not g) and (was_accented and "+ой" or "+ый") or not old and g == "f" and "+ая" or not old and g == "n" and "+ое"
	elseif decl == "+ыя" and old then
		singdecl = (g == "f" or not g) and "+ая" or g == "n" and "+ое"
	elseif decl == "+ие" and not old then
		singdecl = (g == "m" or not g) and "+ий" or g == "f" and "+яя" or g == "n" and "+ее"
	elseif decl == "+іе" and old and (g == "m" or not g) then
		singdecl = "+ій"
	elseif decl == "+ія" and old then
		singdecl = (g == "f" or not g) and "+яя" or g == "n" and "+ее"
	elseif decl == "+ьи" then
		singdecl = (g == "m" or not g) and (old and "+ьій" or "+ьий") or g == "f" and "+ья" or g == "n" and "+ье"
	elseif rfind(decl, "^%+ы%-") then -- decl +ы-mixed or similar
		local beg = (g == "m" or not g) and (old and "ъ" or "") or g == "f" and "а" or g == "n" and "о"
		singdecl = beg and "+" .. beg .. usub(decl, 3)
	end
	if singdecl then
		was_plural = true
		decl = singdecl
	end
	return base, tr, canonicalize_decl(decl, old), g, was_accented, was_plural, was_autodetected
end

-- If stress pattern omitted, detect it based on whether ending is stressed
-- or the decl class or stem accent calls for inherent stress, defaulting to
-- pattern a. This is run after alias resolution and accent removal of DECL;
-- WAS_ACCENTED indicates whether the ending was originally stressed.
-- FIXME: This is run before splitting slash patterns but should be run after.
detect_stress_pattern = function(stem, decl, decl_cats, reducible,
		was_plural, was_accented)
	-- ёнок and ёночек always bear stress
	if rfind(decl, "ёнокъ?") or rfind(decl, "ёночекъ?") then
		return "b"
	-- stressed suffix и́н; missing in plural and true endings don't bear stress
	-- (except for exceptional господи́н)
	elseif rfind(decl, "инъ?") and was_accented then
		return "d"
	-- Adjectival -ой always bears the stress
	elseif rfind(decl, "%+ой") then
		return "b"
	-- Adjectival stressed-short, stressed-proper bears the stress
	elseif rfind(decl, "^%+.*%-stressed") then
		return "b"
	-- Pattern b if ending was accented by user
	elseif was_accented then
		return "b"
	-- Nonsyllabic stem means pattern b
	elseif com.is_nonsyllabic(stem) then
		return "b"
	-- Accent on reducible vowel in masc nom sg (not plural) means pattern b.
	-- Think about whether we want to enable this.
--	elseif reducible and not was_plural then
--		-- FIXME hack. Eliminate plural part of slash declension.
--		decl = rsub(decl, "/.*", "")
--		if decl_cats[decl] and decl_cats[decl].g == "m" then
--			if com.is_ending_stressed(stem) or com.is_monosyllabic(stem) then
--				return "b"
--			end
--		end
	end
	return "a"
end

-- In certain special cases, depending on the declension, we override the
-- user-specified stress pattern and convert it to something else.
-- NOTE: This function is run after alias resolution and accent removal.
-- FIXME: It's also run before splitting slash patterns but should be run after.
override_stress_pattern = function(decl, stress)
	-- ёнок and ёночек always bear stress; if user specified a,
	-- convert to b. Don't do this with slash patterns (see FIXME above).
	if stress == "a" and (rfind(decl, "^ёнокъ?$") or rfind(decl, "^ёночекъ?$")) then
		return "b"
	end
	return stress
end

-- Canonicalize an adjectival declension to either the stressed or unstressed
-- variant depending on the stress. Ultimately this is what ensures that
-- the user's stress mark on an adjectival ending is respected.
determine_stress_variant = function(decl, stress)
	if stress == "b" then
		if decl == "+ая" then
			return "+а́я"
		elseif decl == "+ое" then
			return "+о́е"
		else
			-- Convert +...-short to +...-stressed-short and same for -proper
			local b, e = rmatch(decl, "^%+(.*)%-(short)$")
			if not b then
				b, e = rmatch(decl, "^%+(.*)%-(proper)$")
			end
			if b and not rfind(b, "%-stressed") then
				return "+" .. b .. "-stressed-" .. e
			end
		end
	end
	return decl
end

-- Canonicalize a declension based on the final stem consonant, in
-- particular converting soft declensions to hard ones after velars and/or
-- sibilants. FIXME: We also do this canonicalization earlier on during
-- auto-detection (determine_adj_stem_variant() is called by
-- detect_adj_type(), and code in detect_lemma_type() does the equivalent
-- of the first clause below). Doing it here ensures that explicitly
-- specified declensions get handled as well, but it would be nice to not
-- do the same thing twice in the auto-detection case.
determine_stem_variant = function(decl, stem)
	if decl == "е" and rfind(stem, "[" .. com.sib_c .. "]$") then
		return "о"
	end
	return determine_adj_stem_variant(decl, stem)
end

is_reducible = function(decl_cat)
	if decl_cat.suffix or decl_cat.cant_reduce or decl_cat.adj then
		return false
	elseif decl_cat.decl == "3rd" and decl_cat.g == "f" or decl_cat.g == "m" then
		return true
	else
		return false
	end
end

-- Reduce nom sg to stem by eliminating the "epenthetic" vowel. Applies to
-- masculine 2nd-declension hard and soft, and 3rd-declension feminine in
-- -ь. STEM and DECL are after determine_decl(), before converting
-- outward-facing declensions to inward ones.
function export.reduce_nom_sg_stem(stem, tr, decl, can_err)
	local full_stem = stem .. (decl == "й" and decl or "")
	local full_tr = tr and tr .. (decl == "й" and "j" or "")
	local ret, rettr = com.reduce_stem(full_stem, full_tr)
	if not ret and can_err then
		error("Unable to reduce stem " .. stem)
	end
	return ret, rettr
end

is_dereducible = function(decl_cat)
	if decl_cat.suffix or decl_cat.cant_reduce or decl_cat.adj then
		return false
	elseif decl_cat.decl == "1st" or decl_cat.decl == "2nd" and decl_cat.g == "n" then
		return true
	else
		return false
	end
end

-- Add a possible suffix to the bare stem, according to the declension and
-- value of OLD. This may be -ь, -ъ, -й or nothing. We need to do this here
-- because we don't actually attach such a suffix in attach_unstressed() due
-- to situations where we don't want the suffix added, e.g. dereducible nouns
-- in -ня.
add_bare_suffix = function(bare, baretr, old, sgdc, dereduced)
	if old and sgdc.hard == "hard" then
		-- Final -ъ isn't transliterated
		return bare .. "ъ", baretr
	elseif sgdc.hard == "soft" or sgdc.hard == "palatal" then
		-- This next clause corresponds to a special case in Vitalik's module.
		-- It says that nouns in -ня (accent class a) have gen pl without
		-- trailing -ь. It appears to apply to most nouns in -ня (possibly
		-- all in -льня), but ку́хня (gen pl ку́хонь) and дерéвня (gen pl
		-- дереве́нь) is an exception. (Vitalik's module has an extra
		-- condition here 'stress == "a"' that would exclude дере́вня but I
		-- don't think this condition is in Zaliznyak, as he indicates
		-- дере́вня as having an exceptional genitive plural.)
		if dereduced and rfind(bare, "[нН]$") and sgdc.decl == "1st" then
			-- FIXME: What happens in this case old-style? I assume that
			-- -ъ is added, but this is a guess.
			-- Final -ъ isn't transliterated
			return bare .. (old and "ъ" or ""), baretr
		elseif rfind(bare, "[" .. com.vowel .. "]́?$") then
			return bare .. "й", baretr and (baretr .. "j")
		else
			return bare .. "ь", baretr and (baretr .. "ʹ")
		end
	else
		return bare, baretr
	end
end

-- Dereduce stem to the form found in the gen pl (and maybe nom sg) by
-- inserting an epenthetic vowel. Applies to 1st declension and 2nd
-- declension neuter, and to 2nd declension masculine when the stem was
-- specified as a plural form (in which case we're deriving the nom sg,
-- and also the gen pl in the alt-gen-pl scenario). STEM and DECL are
-- after determine_decl(), before converting outward-facing declensions
-- to inward ones. STRESS is the stess pattern.
function export.dereduce_nom_sg_stem(stem, tr, sgdc, stress, old, can_err)
	local epenthetic_stress = ending_stressed_gen_pl_patterns[stress]
	local ret, rettr = com.dereduce_stem(stem, tr, epenthetic_stress)
	if not ret then
		if can_err then
			error("Unable to dereduce stem " .. stem)
		else
			return nil, nil
		end
	end
	return add_bare_suffix(ret, rettr, old, sgdc, true)
end

--------------------------------------------------------------------------
--                      Second-declension masculine                     --
--------------------------------------------------------------------------

----------------- Masculine hard -------------------

-- Hard-masculine declension, ending in a hard consonant
-- (ending in -ъ, old-style).
declensions_old["ъ"] = {
	["nom_sg"] = "ъ",
	["gen_sg"] = "а́",
	["dat_sg"] = "у́",
	["acc_sg"] = nil,
	["ins_sg"] = "о́мъ",
	["pre_sg"] = "ѣ́",
	["nom_pl"] = "ы́",
	["gen_pl"] = function(stem, stress)
		return nom.sibilant_suffixes[ulower(usub(stem, -1))] and "е́й" or "о́въ"
	end,
	["alt_gen_pl"] = "ъ",
	["dat_pl"] = "а́мъ",
	["acc_pl"] = nil,
	["ins_pl"] = "а́ми",
	["pre_pl"] = "а́хъ",
}

declensions_old_cat["ъ"] = { decl="2nd", hard="hard", g="m" }

-- Normal mapping of old ъ would be "" (blank), but we set up "#" as an alias
-- so we have a way of referring to it without defaulting if need be and
-- distinct from auto-detection (e.g. in the second stem of a word, or to
-- override autodetection of -ёнок or -ин -- the latter is necessary in the
-- case of семьянин).
declensions_aliases["#"] = ""

----------------- Masculine hard, irregular plural -------------------

-- Hard-masculine declension, ending in a hard consonant
-- (ending in -ъ, old-style), with irreg nom pl -а.
declensions_old["ъ-а"] = mw.clone(declensions_old["ъ"])
declensions_old["ъ-а"]["nom_pl"] = "а́"

declensions_old_cat["ъ-а"] = { decl="2nd", hard="hard", g="m", alt_nom_pl=true }
declensions_aliases["#-a"] = "-a"

-- Hard-masculine declension, ending in a hard consonant
-- (ending in -ъ, old-style), with irreg soft pl -ья.
-- Differs from the normal declension throughout the plural.
declensions_old["ъ-ья"] = {
	["nom_sg"] = "ъ",
	["gen_sg"] = "а́",
	["dat_sg"] = "у́",
	["acc_sg"] = nil,
	["ins_sg"] = "о́мъ",
	["pre_sg"] = "ѣ́",
	["nom_pl"] = "ья́",
	["gen_pl"] = "ьёвъ",
	["alt_gen_pl"] = "е́й",
	["dat_pl"] = "ья́мъ",
	["acc_pl"] = nil,
	["ins_pl"] = "ья́ми",
	["pre_pl"] = "ья́хъ",
}

declensions_old_cat["ъ-ья"] = { decl="2nd", hard="hard", g="m", irregpl=true }
declensions_aliases["#-ья"] = "-ья"

----------------- Masculine hard, suffixed, irregular plural -------------------

declensions_old["инъ"] = {
	["nom_sg"] = "и́нъ",
	["gen_sg"] = "и́на",
	["dat_sg"] = "и́ну",
	["acc_sg"] = nil,
	["ins_sg"] = "и́номъ",
	["pre_sg"] = "и́нѣ",
	["nom_pl"] = "е́",
	["gen_pl"] = "ъ",
	["dat_pl"] = "а́мъ",
	["acc_pl"] = nil,
	["ins_pl"] = "а́ми",
	["pre_pl"] = "а́хъ",
}

declensions_old_cat["инъ"] = { decl="2nd", hard="hard", g="m", suffix=true }

declensions_old["ёнокъ"] = {
	["nom_sg"] = "ёнокъ",
	["gen_sg"] = "ёнка",
	["dat_sg"] = "ёнку",
	["acc_sg"] = nil,
	["ins_sg"] = "ёнкомъ",
	["pre_sg"] = "ёнкѣ",
	["nom_pl"] = "я́та",
	["gen_pl"] = "я́тъ",
	["dat_pl"] = "я́тамъ",
	["acc_pl"] = nil,
	["ins_pl"] = "я́тами",
	["pre_pl"] = "я́тахъ",
}
declensions_old_cat["ёнокъ"] = { decl="2nd", hard="hard", g="m", suffix=true }

declensions_old_aliases["онокъ"] = "ёнокъ"
declensions_old_aliases["енокъ"] = "ёнокъ"

declensions_old["ёночекъ"] = {
	["nom_sg"] = "ёночекъ",
	["gen_sg"] = "ёночка",
	["dat_sg"] = "ёночку",
	["acc_sg"] = nil,
	["ins_sg"] = "ёночкомъ",
	["pre_sg"] = "ёночкѣ",
	["nom_pl"] = "я́тки",
	["gen_pl"] = "я́токъ",
	["dat_pl"] = "я́ткамъ",
	["acc_pl"] = nil,
	["ins_pl"] = "я́тками",
	["pre_pl"] = "я́ткахъ",
}
declensions_old_cat["ёночекъ"] = { decl="2nd", hard="hard", g="m", suffix=true }

declensions_old_aliases["оночекъ"] = "ёночекъ"
declensions_old_aliases["еночекъ"] = "ёночекъ"

----------------- Masculine soft -------------------

-- Normal soft-masculine declension in -ь
declensions_old["ь-m"] = {
	["nom_sg"] = "ь",
	["gen_sg"] = "я́",
	["dat_sg"] = "ю́",
	["acc_sg"] = nil,
	["ins_sg"] = "ёмъ",
	["pre_sg"] = "ѣ́",
	["nom_pl"] = "и́",
	["gen_pl"] = "е́й",
	["alt_gen_pl"] = "ь",
	["dat_pl"] = "я́мъ",
	["acc_pl"] = nil,
	["ins_pl"] = "я́ми",
	["pre_pl"] = "я́хъ",
}

declensions_old_cat["ь-m"] = { decl="2nd", hard="soft", g="m" }

-- Soft-masculine declension in -ь with irreg nom pl -я
declensions_old["ь-я"] = mw.clone(declensions_old["ь-m"])
declensions_old["ь-я"]["nom_pl"] = "я́"

declensions_old_cat["ь-я"] = { decl="2nd", hard="soft", g="m", alt_nom_pl=true }

----------------- Masculine palatal -------------------

-- Masculine declension in palatal -й
declensions_old["й"] = {
	["nom_sg"] = "й",
	["gen_sg"] = "я́",
	["dat_sg"] = "ю́",
	["acc_sg"] = nil,
	["ins_sg"] = "ёмъ",
	["pre_sg"] = function(stem, stress)
		return rlfind(stem, "[іи]́?$") and not ending_stressed_pre_sg_patterns[stress] and "и" or "ѣ́"
	end,
	["nom_pl"] = "и́",
	["gen_pl"] = "ёвъ",
	["alt_gen_pl"] = "й",
	["dat_pl"] = "я́мъ",
	["acc_pl"] = nil,
	["ins_pl"] = "я́ми",
	["pre_pl"] = "я́хъ",
}

declensions_old_cat["й"] = { decl="2nd", hard="palatal", g="m" }

declensions_old["й-я"] = mw.clone(declensions_old["й"])
declensions_old["й-я"]["nom_pl"] = "я́"

declensions_old_cat["й-я"] = { decl="2nd", hard="palatal", g="m", alt_nom_pl=true }

--------------------------------------------------------------------------
--                       First-declension feminine                      --
--------------------------------------------------------------------------

----------------- Feminine hard -------------------

-- Hard-feminine declension in -а
declensions_old["а"] = {
	["nom_sg"] = "а́",
	["gen_sg"] = "ы́",
	["dat_sg"] = "ѣ́",
	["acc_sg"] = "у́",
	["ins_sg"] = {"о́й<insa>", "о́ю<insb>"}, -- see concat_word_forms_1()
	["pre_sg"] = "ѣ́",
	["nom_pl"] = "ы́",
	["gen_pl"] = function(stem, stress)
		return nom.sibilant_suffixes[ulower(usub(stem, -1))] and ending_stressed_gen_pl_patterns[stress] and "е́й" or "ъ"
	end,
	["alt_gen_pl"] = "е́й",
	["dat_pl"] = "а́мъ",
	["acc_pl"] = nil,
	["ins_pl"] = "а́ми",
	["pre_pl"] = "а́хъ",
}

declensions_old_cat["а"] = { decl="1st", hard="hard", g="f" }

----------------- Feminine soft -------------------

-- Soft-feminine declension in -я
declensions_old["я"] = {
	["nom_sg"] = "я́",
	["gen_sg"] = "и́",
	["dat_sg"] = function(stem, stress)
		return rlfind(stem, "[іи]́?$") and not ending_stressed_dat_sg_patterns[stress] and "и" or "ѣ́"
	end,
	["acc_sg"] = "ю́",
	["ins_sg"] = {"ёй<insa>", "ёю<insb>"}, -- see concat_word_forms_1()
	["pre_sg"] = function(stem, stress)
		return rlfind(stem, "[іи]́?$") and not ending_stressed_pre_sg_patterns[stress] and "и" or "ѣ́"
	end,
	["nom_pl"] = "и́",
	["gen_pl"] = function(stem, stress)
		return ending_stressed_gen_pl_patterns[stress] and not rlfind(stem, "[" .. com.vowel .. "]́?$") and "е́й" or "й"
	end,
	["alt_gen_pl"] = "е́й",
	["dat_pl"] = "я́мъ",
	["acc_pl"] = nil,
	["ins_pl"] = "я́ми",
	["pre_pl"] = "я́хъ",
}

declensions_old_cat["я"] = { decl="1st", hard="soft", g="f" }

-- Soft-feminine declension in -ья.
-- Almost like ь + -я endings except for genitive plural.
declensions_old["ья"] = {
	["nom_sg"] = "ья́",
	["gen_sg"] = "ьи́",
	["dat_sg"] = "ьѣ́",
	["acc_sg"] = "ью́",
	["ins_sg"] = {"ьёй<insa>", "ьёю<insb>"}, -- see concat_word_forms_1()
	["pre_sg"] = "ьѣ́",
	["nom_pl"] = "ьи́",
	["gen_pl"] = function(stem, stress)
		-- circumflex accent is a signal that forces stress, particularly
		-- in accent pattern d/d'.
		return (ending_stressed_gen_pl_patterns[stress] or stress == "d" or stress == "d'") and "е̂й" or "ий"
	end,
	["dat_pl"] = "ья́мъ",
	["acc_pl"] = nil,
	["ins_pl"] = "ья́ми",
	["pre_pl"] = "ья́хъ",
}

declensions_old_cat["ья"] = {
	decl="1st", hard="soft", g="f",
	stem_suffix="ь", gensg=true,
	ignore_reduce=true -- already has dereduced gen pl
}

--------------------------------------------------------------------------
--                       Second-declension neuter                       --
--------------------------------------------------------------------------

----------------- Neuter hard -------------------

-- Normal hard-neuter declension in -о
declensions_old["о"] = {
	["nom_sg"] = "о́",
	["gen_sg"] = "а́",
	["dat_sg"] = "у́",
	["acc_sg"] = function(stem, stress, args)
		return not (args.explicit_gender == "m" and args.thisa == "a") and "о́" or nil
	end,
	["ins_sg"] = "о́мъ",
	["pre_sg"] = "ѣ́",
	["nom_pl"] = "а́",
	["gen_pl"] = function(stem, stress)
		return nom.sibilant_suffixes[ulower(usub(stem, -1))] and ending_stressed_gen_pl_patterns[stress] and "е́й" or "ъ"
	end,
	["alt_gen_pl"] = "о́въ",
	["dat_pl"] = "а́мъ",
	["acc_pl"] = nil,
	["ins_pl"] = "а́ми",
	["pre_pl"] = "а́хъ",
}
declensions_old_cat["о"] = { decl="2nd", hard="hard", g="n" }

-- Hard-neuter declension in -о with irreg nom pl -и
declensions_old["о-и"] = mw.clone(declensions_old["о"])
declensions_old["о-и"]["nom_pl"] = "ы́"
declensions_old_cat["о-и"] = { decl="2nd", hard="hard", g="n", alt_nom_pl=true }

declensions_old_aliases["о-ы"] = "о-и"

-- Masculine-gender neuter-form declension in -(ишк)о with irreg nom pl -и,
-- with colloquial feminine endings in some of the singular cases
-- (§5 p. 74 of Zaliznyak)
declensions_old["(ишк)о-и"] = mw.clone(declensions_old["о-и"])
declensions_old["(ишк)о-и"]["gen_sg"] = {"а́", "ы́1"}
declensions_old["(ишк)о-и"]["dat_sg"] = {"у́", "ѣ́1"}
declensions_old["(ишк)о-и"]["ins_sg"] = {"о́мъ", "о́й1"}
declensions_old_cat["(ишк)о-и"] = { decl="2nd", hard="hard", g="n", colloqfem=true, alt_nom_pl=true }
internal_notes_table_old["(ишк)о-и"] = "<sup>1</sup> Colloquial."

-- Masculine-gender animate neuter-form declension in -(ищ)е with irreg
-- nom pl -и, with colloquial feminine endings in some of the singular cases
-- (§4 p. 74 of Zaliznyak)
declensions_old["(ищ)е-и"] = mw.clone(declensions_old["о-и"])
declensions_old["(ищ)е-и"]["acc_sg"] = {"а́", "у́1"}
declensions_old["(ищ)е-и"]["gen_sg"] = {"а́", "ы́2"}
declensions_old["(ищ)е-и"]["dat_sg"] = {"у́", "ѣ́2"}
declensions_old["(ищ)е-и"]["ins_sg"] = {"о́мъ", "о́й2"}
declensions_old_cat["(ищ)е-и"] = { decl="2nd", hard="hard", g="n", colloqfem=true, alt_nom_pl=true }
internal_notes_table_old["(ищ)е-и"] = "<sup>1</sup> Colloquial.<br /><sup>2</sup> Less common, more colloquial."

----------------- Neuter soft -------------------

-- Soft-neuter declension in -е (stressed -ё)
declensions_old["е"] = {
	["nom_sg"] = "ё",
	["gen_sg"] = "я́",
	["dat_sg"] = "ю́",
	["acc_sg"] = function(stem, stress, args)
		return not (args.explicit_gender == "m" and args.thisa == "a") and "ё" or nil
	end,
	["ins_sg"] = "ёмъ",
	["pre_sg"] = function(stem, stress)
		return rlfind(stem, "[іи]́?$") and not ending_stressed_pre_sg_patterns[stress] and "и" or "ѣ́"
	end,
	["nom_pl"] = "я́",
	["gen_pl"] = function(stem, stress)
		return ending_stressed_gen_pl_patterns[stress] and not rlfind(stem, "[" .. com.vowel .. "]́?$") and "е́й" or "й"
	end,
	["alt_gen_pl"] = "ёвъ",
	["dat_pl"] = "я́мъ",
	["acc_pl"] = nil,
	["ins_pl"] = "я́ми",
	["pre_pl"] = "я́хъ",
}

declensions_old_cat["е"] = {
	singular = function(suffix)
		if suffix == "ё" then
			return "ending in -ё"
		else
			return {}
		end
	end,
	decl="2nd", hard="soft", g="n", gensg=true
}

-- User-facing declension type "ё" = "е"
declensions_old_aliases["ё"] = "е"

-- Rare soft-neuter declension in stressed -е́ (e.g. муде́, бытие́)
declensions_old["е́"] = {
	["nom_sg"] = "е́",
	["gen_sg"] = "я́",
	["dat_sg"] = "ю́",
	["acc_sg"] = function(stem, stress, args)
		return not (args.explicit_gender == "m" and args.thisa == "a") and "е́" or nil
	end,
	["ins_sg"] = "е́мъ",
	["pre_sg"] = function(stem, stress)
		-- FIXME!!! Are we sure about this condition? This is what was
		-- found in the old template, but the related -е declension has
		-- -ие prep sg ending -(и)и only when *not* stressed.
		return rlfind(stem, "[іи]́?$") and "и́" or "ѣ́"
	end,
	["nom_pl"] = "я́",
	["gen_pl"] = function(stem, stress)
		return rlfind(stem, "[" .. com.vowel .. "]́?$") and "й" or "е́й"
	end,
	["alt_gen_pl"] = "ёвъ",
	["dat_pl"] = "я́мъ",
	["acc_pl"] = nil,
	["ins_pl"] = "я́ми",
	["pre_pl"] = "я́хъ",
}

declensions_old_cat["е́"] = {
	singular = "ending in stressed -е",
	decl="2nd", hard="soft", g="n", gensg=true
}

-- Soft-neuter declension in unstressed -ье (stressed -ьё).
declensions_old["ье"] = {
	["nom_sg"] = "ьё",
	["gen_sg"] = "ья́",
	["dat_sg"] = "ью́",
	["acc_sg"] = function(stem, stress, args)
		return not (args.explicit_gender == "m" and args.thisa == "a") and "ьё" or nil
	end,
	["ins_sg"] = "ьёмъ",
	["pre_sg"] = "ьѣ́",
	["nom_pl"] = "ья́",
	["gen_pl"] = function(stem, stress)
		return ending_stressed_gen_pl_patterns[stress] and "е́й" or "ий"
	end,
	["alt_gen_pl"] = "ьёвъ",
	["dat_pl"] = "ья́мъ",
	["acc_pl"] = nil,
	["ins_pl"] = "ья́ми",
	["pre_pl"] = "ья́хъ",
}

declensions_old_cat["ье"] = {
	decl="2nd", hard="soft", g="n",
	stem_suffix="ь", gensg=true,
	ignore_reduce=true -- already has dereduced gen pl
}

declensions_old_aliases["ьё"] = "ье"

--------------------------------------------------------------------------
--                           Third declension                           --
--------------------------------------------------------------------------

declensions_old["ь-f"] = {
	["nom_sg"] = "ь",
	["gen_sg"] = "и́",
	["dat_sg"] = "и́",
	["acc_sg"] = "ь",
	["ins_sg"] = "ью́",
	["pre_sg"] = "и́",
	["nom_pl"] = "и́",
	["gen_pl"] = "е́й",
	["dat_pl"] = "я́мъ",
	["acc_pl"] = nil,
	["ins_pl"] = "я́ми",
	["pre_pl"] = "я́хъ",
}

declensions_old_cat["ь-f"] = { decl="3rd", hard="soft", g="f" }

declensions_old["мя"] = {
	["nom_sg"] = "мя",
	["gen_sg"] = "мени",
	["dat_sg"] = "мени",
	["acc_sg"] = nil,
	["ins_sg"] = "менемъ",
	["pre_sg"] = "мени",
	["nom_pl"] = "мена́",
	["gen_pl"] = "мёнъ",
	["dat_pl"] = "мена́мъ",
	["acc_pl"] = nil,
	["ins_pl"] = "мена́ми",
	["pre_pl"] = "мена́хъ",
}

declensions_old_cat["мя"] = { decl="3rd", hard="soft", g="n", cant_reduce=true }

--------------------------------------------------------------------------
--                             Indeclinable                             --
--------------------------------------------------------------------------

-- Indeclinable declension; no endings.
declensions_old["$"] = {
	["nom_sg"] = "",
	["gen_sg"] = "",
	["dat_sg"] = "",
	["acc_sg"] = nil,
	["ins_sg"] = "",
	["pre_sg"] = "",
	["nom_pl"] = "",
	["gen_pl"] = "",
	["dat_pl"] = "",
	["acc_pl"] = nil,
	["ins_pl"] = "",
	["pre_pl"] = "",
}
declensions_old_cat["$"] = { decl="indeclinable", hard="none", g="none" }

--------------------------------------------------------------------------
--                              Adjectival                              --
--------------------------------------------------------------------------

-- This needs to be up here because it is called just below.
local function old_to_new(v)
	v = rsub(v, "ъ$", "")
	v = rsub(v, "^ъ", "")
	v = rsub(v, "(%A)ъ", "%1")
	v = rsub(v, "ъ(%A)", "%1")
	v = rsub(v, "і", "и")
	v = rsub(v, "ѣ", "е")
	return v
end

-- Meaning of entry is:
-- 1. The declension name in module ru-adjective
-- 2. The masculine declension name in this module
-- 3. The neuter declension name in this module
-- 4. The feminine declension name in this module
-- 5. The value of hard= for the declensions_cat entry
-- 6. The value of decl= for the declensions_cat entry
-- 7. The value of possadj= for the declensions_cat entry (true if possessive
--    or similar type of adjective)
local adj_decl_map = {
	{"ый", "ый", "ое", "ая", "hard", "long", false},
	{"ій", "ій", "ее", "яя", "soft", "long", false},
	{"ой", "ой", "о́е", "а́я", "hard", "long", false},
	{"ьій", "ьій", "ье", "ья", "palatal", "long", true},
	{"short", "ъ-short", "о-short", "а-short", "hard", "short", true},
	{"mixed", "ъ-mixed", "о-mixed", "а-mixed", "hard", "mixed", true},
	{"proper", "ъ-proper", "о-proper", "а-proper", "hard", "proper", true},
	{"stressed-short", "ъ-stressed-short", "о-stressed-short", "а-stressed-short", "hard", "short", true},
	{"stressed-proper", "ъ-stressed-proper", "о-stressed-proper", "а-stressed-proper", "hard", "proper", true},
}

local function get_adjectival_decl(adjtype, gender, old)
	local decl, intnotes = m_ru_adj.get_nominal_decl(adjtype, gender, old)
	-- hack fem ins_sg to insert <insa>, <insb>; see concat_word_forms_1()
	if gender == "f" and type(decl["ins_sg"]) == "table" and #decl["ins_sg"] == 2 then
		decl["ins_sg"][1] = decl["ins_sg"][1] .. "<insa>"
		decl["ins_sg"][2] = decl["ins_sg"][2] .. "<insb>"
	end
	return decl, intnotes
end

for _, declspec in ipairs(adj_decl_map) do
	local oadjdecl = declspec[1]
	local nadjdecl = old_to_new(oadjdecl)
	local odecl_by_gender =
		{m="+" .. declspec[2], n="+" .. declspec[3], f="+" .. declspec[4]}
	local hard = declspec[5]
	local decltype = declspec[6]
	local possadj = declspec[7]
	for _, g in ipairs({"m", "n", "f"}) do
		local odecl = odecl_by_gender[g]
		local ndecl = old_to_new(odecl)
		declensions_old[odecl], internal_notes_table_old[odecl] =
			get_adjectival_decl(oadjdecl, g, true)
		declensions[ndecl], internal_notes_table[ndecl] =
			get_adjectival_decl(nadjdecl, g, false)
		declensions_old_cat[odecl] = {
			decl=decltype, hard=hard, g=g, adj=true, possadj=possadj }
		declensions_cat[ndecl] = {
			decl=decltype, hard=hard, g=g, adj=true, possadj=possadj }
	end
end

-- Set up some aliases.
declensions_old_aliases["+о́-short"] = "+о-stressed-short"
declensions_old_aliases["+а́-short"] = "+а-stressed-short"
declensions_old_aliases["+о́-proper"] = "+о-stressed-proper"
declensions_old_aliases["+а́-proper"] = "+а-stressed-proper"
declensions_aliases["+#-short"] = "+-short"
declensions_aliases["+#-mixed"] = "+-mixed"
declensions_aliases["+#-proper"] = "+-proper"
declensions_aliases["+#-stressed-short"] = "+-stressed-short"
declensions_aliases["+#-stressed-proper"] = "+-stressed-proper"

--------------------------------------------------------------------------
--                         Populate new from old                        --
--------------------------------------------------------------------------

-- Function to convert an entry in an old declensions table to new.
local function old_decl_entry_to_new(v)
	if not v then
		return nil
	elseif type(v) == "table" then
		local new_entry = {}
		for _, i in ipairs(v) do
			table.insert(new_entry, old_decl_entry_to_new(i))
		end
		return new_entry
	elseif type(v) == "function" then
		return function(stem, suffix, args)
			return old_decl_entry_to_new(v(stem, suffix, args))
		end
	else
		return old_to_new(v)
	end
end

-- Function to convert an old declensions table to new.
local function old_decl_to_new(odecl)
	local ndecl = {}
	for k, v in pairs(odecl) do
		ndecl[k] = old_decl_entry_to_new(v)
	end
	return ndecl
end

-- Function to convert an entry in an old declensions_cat table to new.
local function old_decl_cat_entry_to_new(odecl_cat_entry)
	if not odecl_cat_entry then
		return nil
	elseif type(odecl_cat_entry) == "function" then
		return function(suffix)
			return old_decl_cat_entry_to_new(odecl_cat_entry(suffix))
		end
	elseif type(odecl_cat_entry) == "table" then
		local ndecl_cat_entry = {}
		for k, v in pairs(odecl_cat_entry) do
			ndecl_cat_entry[k] = old_decl_cat_entry_to_new(v)
		end
		return ndecl_cat_entry
	elseif type(odecl_cat_entry) == "boolean" then
		return odecl_cat_entry
	else
		assert(type(odecl_cat_entry) == "string")
		return old_to_new(odecl_cat_entry)
	end
end

-- Function to convert an old declensions_cat table to new.
local function old_decl_cat_to_new(odeclcat)
	local ndeclcat = {}
	for k, v in pairs(odeclcat) do
		ndeclcat[k] = old_decl_cat_entry_to_new(v)
	end
	return ndeclcat
end

-- populate declensions[] from declensions_old[]
for odecltype, odecl in pairs(declensions_old) do
	local ndecltype = old_to_new(odecltype)
	if not declensions[ndecltype] then
		declensions[ndecltype] = old_decl_to_new(odecl)
	end
end

-- populate declensions_cat[] from declensions_old_cat[]
for odecltype, odeclcat in pairs(declensions_old_cat) do
	local ndecltype = old_to_new(odecltype)
	if not declensions_cat[ndecltype] then
		declensions_cat[ndecltype] = old_decl_cat_to_new(odeclcat)
	end
end

-- populate declensions_aliases[] from declensions_old_aliases[]
for ofrom, oto in pairs(declensions_old_aliases) do
	local from = old_to_new(ofrom)
	if not declensions_aliases[from] then
		declensions_aliases[from] = old_to_new(oto)
	end
end

-- populate internal_notes_table[] from internal_notes_table_old[]
for odecl, note in pairs(internal_notes_table_old) do
	local ndecl = old_to_new(odecl)
	if not internal_notes_table[ndecl] then
		-- FIXME, should we be calling old_to_new() here?
		internal_notes_table[ndecl] = note
	end
end

--------------------------------------------------------------------------
--                        Inflection functions                          --
--------------------------------------------------------------------------

-- Attach the stressed stem (or plural stem, or barestem) out of ARGS
-- to the unstressed suffix SUF, modifying the suffix as necessary for the
-- last letter of the stem (e.g. if it is velar, sibilant or ц). CASE is
-- the case form being created and is used to select the plural stem if
-- needed. Returns two values, the combined form and the modified suffix.
local function attach_unstressed(args, case, suf, was_stressed)
	if suf == nil then
		return nil, nil
	elseif rfind(suf, CFLEX) then -- if suf has circumflex accent, it forces stressed
		return attach_stressed(args, case, suf)
	end
	local stem, tr
	if rfind(case, "_pl") then
		stem, tr = args.pl, args.pltr
	end
	if not stem and case == "ins_sg" then
		stem, tr = args.ins_sg_stem, args.ins_sg_tr
	end
	if not stem then
		stem, tr = args.stem, args.stemtr
	end
	if nom.nonsyllabic_suffixes[suf] then
		-- If gen_pl, use special args.gen_pl_bare if given, else regular
		-- args.bare if there isn't a plural stem. If nom_sg, always use
		-- regular args.bare.
		local barearg, bareargtr
		if case == "gen_pl" then
			barearg, bareargtr = args.gen_pl_bare, args.gen_pl_baretr
			if not barearg and args.pl == args.stem then
				barearg, bareargtr = args.bare, args.baretr
			end
		else
			barearg, bareargtr = args.bare, args.baretr
		end
		local barestem = barearg or stem
		local barestem, baretr
		if barearg then
			barestem, baretr = barearg, bareargtr
		else
			barestem, baretr = stem, tr
		end
		if was_stressed and case == "gen_pl" then
			if not barearg then
				local gen_pl_stem, gen_pl_tr = com.make_ending_stressed(stem, tr)
				barestem, baretr = gen_pl_stem, gen_pl_tr
			end
		end

		if rlfind(barestem, "[йьъ]$") then
			suf = ""
		else
			if suf == "ъ" then
				-- OK
			elseif suf == "й" or suf == "ь" then
				if barearg and case == "gen_pl" then
					-- explicit bare or reducible, don't add -ь
					suf = ""
				elseif rfind(barestem, "[" .. com.vowel .. "]́?$") then
					-- not reducible, do add -ь and correct to -й if necessary
					suf = "й"
				else
					suf = "ь"
				end
			end
		end
		return com.concat_russian_tr(barestem, baretr, suf, nil, "dopair"), suf
	end
	suf = com.make_unstressed(suf)
	local rules = nom.unstressed_rules[ulower(usub(stem, -1))]
	return nom.combine_stem_and_suffix(stem, tr, suf, rules, args.old)
end

-- Analogous to attach_unstressed() but for the unstressed stem and a
-- stressed suffix.
attach_stressed = function(args, case, suf)
	if suf == nil then
		return nil, nil
	end
 	-- circumflex forces stress even when the accent pattern calls for no stress
	suf = rsub(suf, "̂", "́")
	if not rfind(suf, "[ё́]") then -- if suf has no "ё" or accent marks
		return attach_unstressed(args, case, suf, "was stressed")
	end
	local stem, tr
	if rfind(case, "_pl") then
		stem, tr = args.upl, args.upltr
	end
	if not stem then
		stem, tr = args.ustem, args.ustemtr
	end
	local rules = nom.stressed_rules[ulower(usub(stem, -1))]
	return nom.combine_stem_and_suffix(stem, tr, suf, rules, args.old)
end

-- Attach the appropriate stressed or unstressed stem (or plural stem as
-- determined by CASE, or barestem) out of ARGS to the suffix SUF, which may
-- be a list of alternative suffixes (e.g. in the inst sg of feminine nouns).
-- Calls FUN (either attach_stressed() or attach_unstressed()) to do the work
-- for an individual suffix. Returns two values, a list of combined forms
-- and a list of the real suffixes used (which may be modified from the
-- passed-in suffixes, e.g. by removing stress marks or modifying vowels in
-- various ways after a stem-final velar, sibilant or ц).  Each combined form
-- is a two-element list {stem, tr} (or a one-element list if tr is nil).
-- IRREG is true if this is an irregular form. We are handling the Nth word;
-- ISLAST is true if this is the last one.
local function attach_with(args, case, suf, fun, irreg, n, islast)
	if type(suf) == "table" then
		local all_combineds = {}
		local all_realsufs = {}
		for _, x in ipairs(suf) do
			local combineds, realsufs =
				attach_with(args, case, x, fun, irreg, n, islast)
			for _, combined in ipairs(combineds) do
				table.insert(all_combineds, combined)
			end
			for _, realsuf in ipairs(realsufs) do
				table.insert(all_realsufs, realsuf)
			end
		end
		return all_combineds, all_realsufs
	else
		local combined, realsuf = fun(args, case, suf)
		local irregsuf = irreg and {IRREGMARKER} or {""}
		return {combined and com.concat_paired_russian_tr(
			com.concat_paired_russian_tr(args["prefix" .. n], combined),
			com.concat_paired_russian_tr(args["suffix" .. n], irregsuf)) or nil},
			{realsuf and realsuf .. args["suffix" .. n][1] or nil}
	end
end

-- Generate the form(s) and suffix(es) for CASE according to the declension
-- table DECL, using the attachment function FUN (one of attach_stressed()
-- or attach_unstressed()). IS_SLASH is true if this is a slash declension
-- (different declensions for singular and plural). We are handling the Nth
-- word; ISLAST is true if this is the last one.
local function gen_form(args, decl, case, stress, fun, is_slash, n, islast)
	local irreg = false
	if not args.suffixes[case] then
		args.suffixes[case] = {}
	end
	local decl_sufs = args.old and declensions_old or declensions
	decl_sufs = decl_sufs[decl]
	local suf = decl_sufs[case]
	local decl_cats = args.old and declensions_old_cat or declensions_cat
	local ispl = rfind(case, "_pl")
	if ispl and (decl_cats[decl].irregpl or args.pl and args.pl ~= args.stem or is_slash) then
		irreg = true
	end
	if case == "nom_pl" and decl_cats[decl].alt_nom_pl then
		irreg = true
	end
	if type(suf) == "function" then
		suf = suf(ispl and args.pl or args.stem, stress, args)
	end
	if case == "gen_pl" and args.alt_gen_pl then
		suf = decl_sufs.alt_gen_pl
		irreg = true
		if not suf then
			error("No alternate genitive plural available for this declension class")
		end
	end
	local combineds, realsufs = attach_with(args, case, suf, fun, irreg, n, islast)
	for _, realsuf in ipairs(realsufs) do
		args.any_non_nil[case] = true
		args.this_any_non_nil[case] = true
		insert_if_not(args.suffixes[case], realsuf)
	end
	return combineds
end

local attachers = {
	["+"] = attach_stressed,
	["-"] = attach_unstressed,
}


do_stress_pattern = function(stress, args, decl, number, n, islast)
	local f = {}
	for _, case in ipairs(decl_cases) do
		if not number or (number == "sg" and rfind(case, "_sg")) or
			(number == "pl" and rfind(case, "_pl")) then
			f[case] = gen_form(args, decl, case, stress,
				attachers[stress_patterns[stress][case]], not not number,
				n, islast)
			-- Turn empty form lists into nil to facilitate computation of
			-- animate/inanimate accusatives below
			if f[case] and #f[case] == 0 then
				f[case] = nil
			end
			-- Compute linked versions of potential lemma cases, for use
			-- in the ru-noun+ headword. We substitute the original lemma
			-- (before removing links) for forms that are the same as the
			-- lemma, if the original lemma has links.
			if f[case] and (case == "nom_sg" or case == "nom_pl") then
				local linked_forms = {}
				for _, form in ipairs(f[case]) do
					-- Return true if FORM is "close enough" to LEMMA that we can substitute the
					-- linked form of the lemma. Currently this means exactly the same except that
					-- we ignore acute and grave accent differences in monosyllables, and ignore
					-- notes that may have been appended (e.g. the triangle marking irregularity).
					local entry, notes = m_table_tools.separate_notes(form[1])
					local lemma = args.lemma_no_links
					local close_enough_to_lemma =
						entry == lemma or (com.is_monosyllabic(entry) and
							com.is_monosyllabic(lemma) and
							com.remove_accents(entry) == com.remove_accents(lemma))
					if close_enough_to_lemma and
							rfind(args.orig_lemma, "%[%[") then
						table.insert(linked_forms, {args.orig_lemma .. notes, args.lemmatr and args.lemmatr .. notes})
					else
						table.insert(linked_forms, form)
					end
				end
				f[case .. "_linked"] = linked_forms
			end
		end
	end
	-- Set acc an/in variants now as appropriate. We used to do this in
	-- handle_forms_and_overrides(), which simplified the handling of
	-- nom/gen/acc overrides but caused problems for words like мазло and
	-- трепло that had a mixture of nil and non-nil accusative forms.
	local an = args.thisa
	if not number or number == "sg" then
		f.acc_sg_an = f.acc_sg_an or f.acc_sg or an == "i" and f.nom_sg or f.gen_sg
		f.acc_sg_in = f.acc_sg_in or f.acc_sg or an == "a" and f.gen_sg or f.nom_sg
	end
	if not number or number == "pl" then
		f.acc_pl_an = f.acc_pl_an or f.acc_pl or an == "i" and f.nom_pl or f.gen_pl
		f.acc_pl_in = f.acc_pl_in or f.acc_pl or an == "a" and f.gen_pl or f.nom_pl
	end
	for case, forms in pairs(f) do
		if not args.forms[case] then
			args.forms[case] = {}
		end
		for _, form in ipairs(forms) do
			insert_if_not(args.forms[case], form)
		end
	end
end

stress_patterns["a"] = {
	nom_sg="-", gen_sg="-", dat_sg="-", acc_sg="-", ins_sg="-", pre_sg="-",
	nom_pl="-", gen_pl="-", dat_pl="-", acc_pl="-", ins_pl="-", pre_pl="-",
}

stress_patterns["b"] = {
	nom_sg="+", gen_sg="+", dat_sg="+", acc_sg="+", ins_sg="+", pre_sg="+",
	nom_pl="+", gen_pl="+", dat_pl="+", acc_pl="+", ins_pl="+", pre_pl="+",
}

stress_patterns["b'"] = {
	nom_sg="+", gen_sg="+", dat_sg="+", acc_sg="+", ins_sg="-", pre_sg="+",
	nom_pl="+", gen_pl="+", dat_pl="+", acc_pl="+", ins_pl="+", pre_pl="+",
}

stress_patterns["c"] = {
	nom_sg="-", gen_sg="-", dat_sg="-", acc_sg="-", ins_sg="-", pre_sg="-",
	nom_pl="+", gen_pl="+", dat_pl="+", acc_pl="+", ins_pl="+", pre_pl="+",
}

stress_patterns["d"] = {
	nom_sg="+", gen_sg="+", dat_sg="+", acc_sg="+", ins_sg="+", pre_sg="+",
	nom_pl="-", gen_pl="-", dat_pl="-", acc_pl="-", ins_pl="-", pre_pl="-",
}

stress_patterns["d'"] = {
	nom_sg="+", gen_sg="+", dat_sg="+", acc_sg="-", ins_sg="+", pre_sg="+",
	nom_pl="-", gen_pl="-", dat_pl="-", acc_pl="-", ins_pl="-", pre_pl="-",
}

stress_patterns["e"] = {
	nom_sg="-", gen_sg="-", dat_sg="-", acc_sg="-", ins_sg="-", pre_sg="-",
	nom_pl="-", gen_pl="+", dat_pl="+", acc_pl="+", ins_pl="+", pre_pl="+",
}

stress_patterns["f"] = {
	nom_sg="+", gen_sg="+", dat_sg="+", acc_sg="+", ins_sg="+", pre_sg="+",
	nom_pl="-", gen_pl="+", dat_pl="+", acc_pl="+", ins_pl="+", pre_pl="+",
}

stress_patterns["f'"] = {
	nom_sg="+", gen_sg="+", dat_sg="+", acc_sg="-", ins_sg="+", pre_sg="+",
	nom_pl="-", gen_pl="+", dat_pl="+", acc_pl="+", ins_pl="+", pre_pl="+",
}

stress_patterns["f''"] = {
	nom_sg="+", gen_sg="+", dat_sg="+", acc_sg="+", ins_sg="-", pre_sg="+",
	nom_pl="-", gen_pl="+", dat_pl="+", acc_pl="+", ins_pl="+", pre_pl="+",
}

ending_stressed_gen_pl_patterns = m_table.listToSet({"b", "b'", "c", "e", "f", "f'", "f''"})
ending_stressed_pre_sg_patterns = m_table.listToSet({"b", "b'", "d", "d'", "f", "f'", "f''"})
ending_stressed_dat_sg_patterns = ending_stressed_pre_sg_patterns
ending_stressed_sg_patterns = ending_stressed_pre_sg_patterns
ending_stressed_pl_patterns = m_table.listToSet({"b", "b'", "c"})

local numbers = {
	["s"] = "singular",
	["p"] = "plural",
}

local old_title_temp = [=[Pre-reform declension of <b lang="ru" class="Cyrl">{lemma}</b>]=]
local title_temp = [=[Declension of <b lang="ru" class="Cyrl">{lemma}</b>]=]

local extra_case_template, extra_case_template_with_plural
local internal_notes_template
local notes_template
local templates = {}

-- Convert a raw override into a canonicalized list of individual overrides.
-- If input is nil, so is output. Certain junk (e.g. <br/>) is removed,
-- and ~ and ~~ are substituted appropriately; ARGS and CASE are required for
-- this purpose. FORMS is the list of existing case forms and is currently
-- used only to retrieve the dat_sg for handling + in loc/par (this means
-- that any overrides of the dat_sg have to be handled before handling
-- overrides of loc/par). N is the suffix used to retrieve the override --
-- either a number for word-specific overrides, or an empty string for
-- overall overrides.
--
-- It will still be necessary to call m_table_tools.separate_notes() to separate
-- off any trailing "notes" (asterisks, superscript numbers, etc.), and
-- m_links.remove_links() to remove any links to get the raw override form.
canonicalize_override = function(args, case, forms, n)
	local val = args[case .. n]
	if not val then
		return nil
	end

	-- clean <br /> that's in many multi-form entries and messes up linking
	val = rsub(val, "<br%s*/>", "")
	-- substitute ~ and ~~ and split by commas
	local stem, tr
	if rfind(case, "_pl") then
		stem, tr = args.pl, args.pltr
	end
	if not stem then
		stem, tr = args.stem, args.stemtr
	end
	local ustem, utr = com.make_unstressed_once(stem, tr)
	local vals = rsplit(val, "%s*,%s*")
	local retvals = {}
	for _, val in ipairs(vals) do
		local valru, valtr = com.split_russian_tr(val)
		valru = rsub(valru, "~~", ustem)
		valru = rsub(valru, "~", com.is_stressed(val) and ustem or stem)
		if rfind(valru, "^%*") then
			valru = rsub(valru, "^%*", "") .. HYPMARKER
		end
		if valtr then
			tr = tr or com.translit_no_links(stem)
			utr = utr or com.translit_no_links(ustem)
			valtr = rsub(valtr, "~~", utr)
			valtr = rsub(valtr, "~", com.is_stressed(val) and utr or tr)
			if rfind(valtr, "^%*") then
				valtr = rsub(valtr, "^%*", "") .. HYPMARKER
			end
		end
		table.insert(retvals, {valru, valtr})
	end
	vals = retvals

	-- handle + in loc/par meaning "the expected form"; NOTE: This requires
	-- that dat_sg has already been processed!
	if case == "loc" or case == "par" then
		local new_vals = {}
		for _, rutr in ipairs(vals) do
			-- don't just handle + by itself in case the arg has в or на
			-- or whatever attached to it
			if rfind(rutr[1], "^%+") or rfind(rutr[1], "[%s%[|]%+") then
				for _, dat in ipairs(forms["dat_sg"]) do
					local ru, tr = rutr[1], rutr[2]
					local datru, dattr = dat[1], dat[2]
					local valru, valtr
					-- separate off any footnote symbols (which may have been
					-- introduced by a *tail or *tailall argument, which we need
					-- to process before this stage so overrides don't get
					-- automatically marked with footnote symbols); if par,
					-- try to preserve them, but with loc this can cause
					-- problems in case there are multiple dative forms
					-- (stress variants) and the last one is marked with a
					-- footnote symbol (occurs in грудь)
					local datru_entry, datru_notes = m_table_tools.separate_notes(datru)
					local dattr_entry, dattr_notes
					if dattr then
						dattr_entry, dattr_notes = m_table_tools.separate_notes(dattr)
					end
					if case == "par" then
						valru, valtr = datru_entry, dattr_entry
					else
						valru, valtr = com.make_ending_stressed(datru_entry, dattr_entry)
						datru_notes = ""
						dattr_notes = ""
					end
					-- wrap the word in brackets so it's linked; but not if it
					-- appears to already be linked
					ru = rsub(ru, "^%+", "[[" .. valru .. "]]")
					ru = rsub(ru, "([%[|])%+", "%1" .. valru)
					ru = rsub(ru, "(%s)%+", "%1[[" .. valru .. "]]")
					ru = ru .. datru_notes
					-- do the translit; but it shouldn't have brackets in it
					if tr or valtr then
						tr = tr or com.translit_no_links(rutr[1])
						valtr = valtr or com.translit_no_links(valru)
						tr = rsub(tr, "^%+", valtr)
						tr = rsub(tr, "(%s)%+", "%1" .. valtr)
						tr = tr .. dattr_notes
					end
					table.insert(new_vals, {ru, tr})
				end
			else
				table.insert(new_vals, rutr)
			end
		end
		vals = new_vals
	end

	-- auto-accent/check for necessary accents
	local newvals = {}
	for _, v in ipairs(vals) do
		local ru, tr = v[1], v[2]
		if not args.allow_unaccented then
			if tr and com.is_unstressed(ru) ~= com.is_unstressed(tr) then
				error("Override " .. ru .. " and translit " .. tr .. " must have same accent pattern")
			end
			-- it's safe to accent monosyllabic stems
			if com.is_monosyllabic(ru) then
				ru, tr = com.make_ending_stressed(ru, tr)
			elseif com.needs_accents(ru) then
				error("Override " .. ru .. " for case " .. case .. n .. " requires an accent")
			end
		end
		table.insert(newvals, {ru, tr})
	end
	vals = newvals

	return vals
end

local function process_overrides(args, f, n)
	local function process_override(case)
		if args[case .. n] then
			local overrides = canonicalize_override(args, case, f, n)
			if not f[case] then
				f[case] = {}
			end
			local new_overrides = {}
			for _, form in ipairs(overrides) do
				-- Don't consider overrides of loc/par/voc irregular since
				-- they're only specified through overrides; FIXME: Theoretically
				-- we could consider loc/par irregular if they don't follow the
				-- expected forms; but we'd have to figure out how to eliminate
				-- the preposition that may be specified
				if not overridable_only_cases_set[case] and
						not args.manual and
						not contains_rutr_pair(f[case], form) then
					local formru, formnotes = m_table_tools.separate_notes(form[1])
					if formru ~= "-" then
						-- don't mark an override of - as irregular, even if
						-- it has an attached footnote symbol
						form = com.concat_paired_russian_tr(form, {IRREGMARKER})
					end
				end
				if case == "pauc" then
					-- Internal note indicating that the form is for numbers 2, 3 and 4.
					form = com.concat_paired_russian_tr(form, {paucal_marker})
				end
				table.insert(new_overrides, form)
			end
			f[case] = new_overrides
			args.any_overridden[case] = true
		end
	end

	-- do dative singular first because it will be used by loc/par
	process_override("dat_sg")

	-- now do the rest
	for _, case in ipairs(overridable_cases) do
		if case ~= "dat_sg" then
			process_override(case)
		end
	end

	-- if the nominative is overridden, use it to set the linked version unless
	-- that is also specifically overridden
	if args["nom_sg" .. n] and not args["nom_sg_linked" .. n] then
		f.nom_sg_linked = f.nom_sg
	end
	if args["nom_pl" .. n] and not args["nom_pl_linked" .. n] then
		f.nom_pl_linked = f.nom_pl
	end

	-- convert empty lists to nil to facilitate computation of accusative
	-- case variants below.
	for _, case in ipairs(all_cases) do
		if f[case] then
			if type(f[case]) ~= "table" then
				error("Logic error, args[case] should be nil or table")
			end
			if #f[case] == 0 then
				f[case] = nil
			end
		end
	end
end

local function process_tail_args(args, f, n)
	local function append_note_all(case, value)
		value = com.split_russian_tr(value, "dopair")
		local function append1(case)
			if f[case] then
				for i=1,#f[case] do
					f[case][i] = com.concat_paired_russian_tr(f[case][i], value)
				end
			end
		end
		append1(case)
		if case == "acc_sg" then
			append1("acc_sg_in")
			append1("acc_sg_an")
		elseif case == "acc_pl" then
			append1("acc_pl_in")
			append1("acc_pl_an")
		end
	end

	local function append_note_last(case, value, gt_one)
		value = com.split_russian_tr(value, "dopair")
		local function append1(case)
			if f[case] then
				local lastarg = #f[case]
				if lastarg > (gt_one and 1 or 0) then
					f[case][lastarg] = com.concat_paired_russian_tr(f[case][lastarg], value)
				end
			end
		end
		append1(case)
		if case == "acc_sg" then
			append1("acc_sg_in")
			append1("acc_sg_an")
		elseif case == "acc_pl" then
			append1("acc_pl_in")
			append1("acc_pl_an")
		end
	end

	local function handle_tail_hyp(suf)
		local arg, val
		for _, case in ipairs(all_cases) do
			arg = args[case .. "_" .. suf .. n]
			if arg then
				append_note_last(case, suf == "hyp" and HYPMARKER or arg)
			end
			arg = args[case .. "_" .. suf .. "all" .. n]
			if arg then
				append_note_all(case, suf == "hyp" and HYPMARKER or arg)
			end
			if not rfind(case, "_pl") then
				arg = args["sg" .. suf .. "all" .. n]
				if arg then
					append_note_all(case, suf == "hyp" and HYPMARKER or arg)
				end
				arg = args["sg" .. suf .. n]
				if arg then
					append_note_last(case, suf == "hyp" and HYPMARKER or arg, ">1")
				end
			else
				arg = args["pl" .. suf .. "all" .. n]
				if arg then
					append_note_all(case, suf == "hyp" and HYPMARKER or arg)
				end
				arg = args["pl" .. suf .. n]
				if arg then
					append_note_last(case, suf == "hyp" and HYPMARKER or arg, ">1")
				end
			end
			if not rfind(case, "nom_") and not rfind(case, "acc_") then
				arg = args["obl" .. suf .. "all" .. n]
				if arg then
					append_note_all(case, suf == "hyp" and HYPMARKER or arg)
				end
				arg = args["obl" .. suf .. n]
				if arg then
					append_note_last(case, suf == "hyp" and HYPMARKER or arg, ">1")
				end
			end				
		end
	end

	handle_tail_hyp("tail")
	handle_tail_hyp("hyp")
end

handle_forms_and_overrides = function(args, n, islast)
	local f = args.forms

	process_tail_args(args, f, n)
	process_overrides(args, f, n)

	local an = args.thisa
	-- Maybe set the value of the animate/inanimate accusative variants based
	-- on nom/acc/gen overrides. Don't do this if there was a specific override
	-- of this form. Otherwise, always propagate an accusative singular
	-- override, and propagate the nom/gen sg if there wasn't a specific
	-- accusative suffix anywhere (occurs in the fem sg and sometimes the neut
	-- sg). This logic duplicates logic in handle_overall_forms_and_overrides();
	-- see long comment there. We need to duplicate the whole logic here to
	-- handle words like мать-одиночка, which has an override of acc_sg1.
	if not args["acc_sg_an" .. n] then
		if args["acc_sg" .. n] then
			f.acc_sg_an = f.acc_sg
		elseif not args.this_any_non_nil.acc_sg then
			f.acc_sg_an = f.acc_sg or an == "i" and f.nom_sg or f.gen_sg or f.acc_sg_an
		end
	end
	if not args["acc_sg_in" .. n] then
		if args["acc_sg" .. n] then
			f.acc_sg_in = f.acc_sg
		elseif not args.this_any_non_nil.acc_sg then
			f.acc_sg_in = f.acc_sg or an == "a" and f.gen_sg or f.nom_sg or f.acc_sg_in
		end
	end
	if not args["acc_pl_an" .. n] then
		if args["acc_pl" .. n] then
			f.acc_pl_an = f.acc_pl
		elseif not args.this_any_non_nil.acc_pl then
			f.acc_pl_an = f.acc_pl or an== "i" and f.nom_pl or f.gen_pl or f.acc_pl_an
		end
	end
	if not args["acc_pl_in" .. n] then
		if args["acc_pl" .. n] then
			f.acc_pl_in = f.acc_pl
		elseif not args.this_any_non_nil.acc_pl then
			f.acc_pl_in = f.acc_pl or an == "a" and f.gen_pl or f.nom_pl or f.acc_pl_in
		end
	end

	f.loc = f.loc or f.pre_sg
	f.par = f.par or f.gen_sg
	f.voc = f.voc or f.nom_sg
	-- Set these in case we have plural only, in which case the
	-- singular will also get set to these same values in case we are
	-- a plural-only word in a singular-only expression.
	f.loc_pl = f.loc_pl or f.pre_pl
	f.par_pl = f.par_pl or f.gen_pl
	f.voc_pl = f.voc_pl or f.nom_pl

	local nu = args.thisn
	-- If we have a singular-only, set the plural forms to the singular forms,
	-- and vice-versa. This is important so that things work in multi-word
	-- expressions that combine different number restrictions (e.g.
	-- singular-only with singular/plural or singular-only with plural-only,
	-- compare "St. Vincent and the Grenadines" [Сент-Винсент и Гренадины]).
	if nu == "s" then
		f.nom_pl_linked = f.nom_sg_linked
		f.nom_pl = f.nom_sg
		f.gen_pl = f.gen_sg
		f.dat_pl = f.dat_sg
		f.acc_pl = f.acc_sg
		f.acc_pl_an = f.acc_sg_an
		f.acc_pl_in = f.acc_sg_in
		f.ins_pl = f.ins_sg
		f.pre_pl = f.pre_sg
		f.nom_pl = f.nom_sg
		f.loc_pl = f.loc
		f.par_pl = f.par
		f.voc_pl = f.voc
	elseif nu == "p" then
		f.nom_sg_linked = f.nom_pl_linked
		f.nom_sg = f.nom_pl
		f.gen_sg = f.gen_pl
		f.dat_sg = f.dat_pl
		f.acc_sg = f.acc_pl
		f.acc_sg_an = f.acc_pl_an
		f.acc_sg_in = f.acc_pl_in
		f.ins_sg = f.ins_pl
		f.pre_sg = f.pre_pl
		f.nom_sg = f.nom_pl
		f.loc = f.loc_pl
		f.par = f.par_pl
		f.voc = f.voc_pl
	end
end

handle_overall_forms_and_overrides = function(args)
	local overall_forms = {}
	for _, case in ipairs(displayable_cases) do
		overall_forms[case] = concat_word_forms(args.per_word_info, case)
	end

	local acc_sg_overridden = args.acc_sg
	local acc_pl_overridden = args.acc_pl

	process_tail_args(args, overall_forms, "")
	process_overrides(args, overall_forms, "")

	if case_will_be_displayed(args, "pauc") then
		insert_if_not(args.internal_notes, paucal_internal_note)
	end

	-- if IRREGMARKER is anywhere in text, remove all instances and put
	-- at the end before any notes.
	local function clean_irreg_marker(case, text)
		if rfind(text, IRREGMARKER) then
			text = rsub(text, IRREGMARKER, "")
			local entry, notes = m_table_tools.separate_notes(text)
			if case_will_be_displayed(args, case) then
				insert_if_not(args.internal_notes, IRREGMARKER .. " Irregular.")
				args.any_irreg = true
				args.any_irreg_case[case] = true
			end
			return entry .. IRREGMARKER .. notes
		else
			return text
		end
	end

	-- set final args[case] and clean up IRREGMARKER.
	for _, case in ipairs(all_cases) do
		args[case] = overall_forms[case]
		if args[case] then
			local cleaned_forms = {}
			for _, form in ipairs(args[case]) do
				local ru, tr = form[1], form[2]
				ru = clean_irreg_marker(case, ru)
				if tr then
					tr = clean_irreg_marker(case, tr)
				end
				table.insert(cleaned_forms, {ru, tr})
			end
			args[case] = cleaned_forms
		end
	end

	-- Maybe set the value of the animate/inanimate accusative variants based
	-- on nom/acc/gen overrides. Don't do this if there was a specific override
	-- of this form. Otherwise, always propagate an accusative singular
	-- override, and propagate the nom/gen sg if there wasn't a specific
	-- accusative suffix anywhere (occurs in the fem sg and sometimes the neut
	-- sg). We need to do this somewhat complicated procedure to get overrides
	-- to work correctly, e.g. acc_sg overrides of feminine and neuter nouns
	-- (such as мать and полслова) and gen_sg/gen_pl overrides of masculine
	-- animate nouns. We also ran into an issue with words like мазло that are
	-- neuter-form but can be both masculine animate (in which case the
	-- acc sg inherits from the genitive) and neuter animate (in which case the
	-- acc sg has the fixed ending -о, same as nominative, despite the animacy).
	-- Remember also that the animate/inanimate accusative variants are the ones
	-- displayed, not the plain acc_sg/acc_pl ones.
	if not args.any_overridden.acc_sg_an then
		if acc_sg_overridden then
			args.acc_sg_an = args.acc_sg
		elseif not args.any_non_nil.acc_sg then
			args.acc_sg_an = args.acc_sg or args.a == "i" and args.nom_sg or args.gen_sg or args.acc_sg_an
		end
	end
	if not args.any_overridden.acc_sg_in then
		if acc_sg_overridden then
			args.acc_sg_in = args.acc_sg
		elseif not args.any_non_nil.acc_sg then
			args.acc_sg_in = args.acc_sg or args.a == "a" and args.gen_sg or args.nom_sg or args.acc_sg_in
		end
	end
	if not args.any_overridden.acc_pl_an then
		if acc_pl_overridden then
			args.acc_pl_an = args.acc_pl
		elseif not args.any_non_nil.acc_pl then
			args.acc_pl_an = args.acc_pl or args.a == "i" and args.nom_pl or args.gen_pl or args.acc_pl_an
		end
	end
	if not args.any_overridden.acc_pl_in then
		if acc_pl_overridden then
			args.acc_pl_in = args.acc_pl
		elseif not args.any_non_nil.acc_pl then
			args.acc_pl_in = args.acc_pl or args.a == "a" and args.gen_pl or args.nom_pl or args.acc_pl_in
		end
	end

	-- Try to set the values of acc_sg and acc_pl. The only time we can't is
	-- when the noun is bianimate and the anim/inan values are different.
	-- This is used primarily for generate_forms() and generate_multi_forms(),
	-- since we don't actually display these forms.
	if args.a == "a" then
		args.acc_sg = args.acc_sg or args.acc_sg_an
		args.acc_pl = args.acc_pl or args.acc_pl_an
	elseif args.a == "i" then
		args.acc_sg = args.acc_sg or args.acc_sg_in
		args.acc_pl = args.acc_pl or args.acc_pl_in
	else -- bianimate
		args.acc_sg = args.acc_sg or m_table.deepEquals(args.acc_sg_in, args.acc_sg_an) and args.acc_sg_in or nil
		args.acc_pl = args.acc_pl or m_table.deepEquals(args.acc_pl_in, args.acc_pl_an) and args.acc_pl_in or nil
	end
end

-- Subfunction of concat_word_forms(), used to implement recursively
-- generating all combinations of elements from WORD_FORMS (a list, one
-- element per word, of a list of the forms for a word, each of which is a
-- two-element list of {RUSSIAN, TR}) and TRAILING_FORMS (a list of forms, the
-- accumulated suffixes for trailing words so far in the recursion process,
-- again where each form is a two-element list {RUSSIAN, TR}). Each time we
-- recur we take the last FORMS item off of WORD_FORMS and to each form in
-- FORMS we add all elements in TRAILING_FORMS, passing the newly generated
-- list of items down the next recursion level with the shorter WORD_FORMS.
-- We end up returning a list of concatenated forms, where each list item
-- is a two-element list {RUSSIAN, TR}.
local function concat_word_forms_1(word_forms, trailing_forms)
	if #word_forms == 0 then
		local retforms = {}
		for _, form in ipairs(trailing_forms) do
			local ru, tr = form[1], form[2]
			-- Remove <insa> and <insb> markers; they've served their purpose.
			ru = rsub(ru, "<ins[ab]>", "")
			tr = tr and rsub(tr, "<ins[ab]>", "")
			table.insert(retforms, {ru, tr})
		end
		return retforms
	else
		local last_form_info = table.remove(word_forms)
		local last_forms, joiner = last_form_info[1], last_form_info[2]
		local new_trailing_forms = {}
		for _, form in ipairs(last_forms) do
			for _, trailing_form in ipairs(trailing_forms) do
				-- If form to prepend is empty, don't add the joiner; this
				-- is principally used in overall overrides, where we stuff
				-- the entire override into the last word
				local full_form = form[1] == "" and trailing_form or
					com.concat_paired_russian_tr(form,
						com.concat_paired_russian_tr(joiner, trailing_form),
						"movenotes")
				if rfind(full_form[1], "<insa>") and rfind(full_form[1], "<insb>") then
					-- REJECT! So we don't get mixtures of the two feminine
					-- instrumental singular endings.
				else
					table.insert(new_trailing_forms, full_form)
				end
			end
		end
		return concat_word_forms_1(word_forms, new_trailing_forms)
	end
end

-- Generate a list of overall forms by concatenating the per-word forms.
-- PER_WORD_INFO comes from args.per_word_info and is a list of
-- WORD_INFO items, one per word, each of which a two element list of
-- WORD_FORMS (a table listing the forms for each case) and JOINER (a string).
-- We loop over all possible combinations of elements from each word's list
-- of forms for the given case; this requires recursion.
concat_word_forms = function(per_word_info, case)
	local word_forms = {}
	-- Gather the appropriate word forms. We have to recreate this anew
	-- because it will be destructively modified by concat_word_forms_1().
	for _, word_info in ipairs(per_word_info) do
		table.insert(word_forms, {word_info[1][case], word_info[2]})
	end
	-- We need to start the recursion with the second parameter containing
	-- one blank element rather than no elements, otherwise no elements
	-- will be propagated to the next recursion level.
	return concat_word_forms_1(word_forms, {{""}})
end

local accel_forms = {
	nom_sg = "nom|s",
	nom_sg_linked = "nom|s",
	nom_pl = "nom|p",
	nom_pl_linked = "nom|p",
	gen_sg = "gen|s",
	gen_pl = "gen|p",
	dat_sg = "dat|s",
	dat_pl = "dat|p",
	acc_sg_an = "an|acc|s",
	acc_pl_an = "an|acc|p",
	acc_sg_in = "in|acc|s",
	acc_pl_in = "in|acc|p",
	ins_sg = "ins|s",
	ins_pl = "ins|p",
	pre_sg = "pre|s",
	pre_pl = "pre|p",
	loc = "loc|s",
	loc_pl = "loc|p",
	voc = "voc|s",
	voc_pl = "voc|p",
	par = "par|s",
	par_pl = "par|p",
	count = "count|form",
	pauc = "pau",
}

-- Make the table
make_table = function(args)
	local data = {}
	data.after_title = " " .. args.heading
	data.number = args.nonumber and "" or numbers[args.n]

	local lemma_forms = args[args.n == "p" and "nom_pl" or "nom_sg"]
	data.lemma = nom.show_form(args.explicit_lemma and {{args.explicit_lemma, args.explicit_lemmatr}} or
		args[args.n == "p" and "nom_pl_linked" or "nom_sg_linked"], "lemma", nil, nil)
	data.title = args.title or strutils.format(args.old and old_title_temp or title_temp, data)

	local sg_an_in_equal = m_table.deepEquals(args.acc_sg_an, args.acc_sg_in)
	local pl_an_in_equal = m_table.deepEquals(args.acc_pl_an, args.acc_pl_in)

	for _, case in ipairs(displayable_cases) do
		local accel_form = accel_forms[case]
		if not accel_form then
			error("Something wrong, can't find accelerator form for " .. case)
		end
		if (sg_an_in_equal and (case == "acc_sg_an" or case == "acc_sg_in") or
			pl_an_in_equal and (case == "acc_pl_an" or case == "acc_pl_in")) then
			accel_form = rsub(accel_form, "^[ai]n|", "")
		end
		if args.n == "p" then
			accel_form = rsub(accel_form, "|p$", "")
		end
		data[case] = nom.show_form(args[case], false, accel_form, lemma_forms, "remove monosyllabic accents only lemma")
	end

	local temp = nil

	if args.n == "s" then
		data.nom_x = data.nom_sg
		data.gen_x = data.gen_sg
		data.dat_x = data.dat_sg
		data.acc_x_an = data.acc_sg_an
		data.acc_x_in = data.acc_sg_in
		data.ins_x = data.ins_sg
		data.pre_x = data.pre_sg
		if sg_an_in_equal then
			temp = "one_number"
		else
			temp = "one_number_split_animacy"
		end
	elseif args.n == "p" then
		data.nom_x = data.nom_pl
		data.gen_x = data.gen_pl
		data.dat_x = data.dat_pl
		data.acc_x_an = data.acc_pl_an
		data.acc_x_in = data.acc_pl_in
		data.ins_x = data.ins_pl
		data.pre_x = data.pre_pl
		data.par = data.par_pl
		data.loc = data.loc_pl
		data.voc = data.voc_pl
		if pl_an_in_equal then
			temp = "one_number"
		else
			temp = "one_number_split_animacy"
		end
	else
		if pl_an_in_equal then
			temp = "both_numbers"
		elseif sg_an_in_equal then
			temp = "both_numbers_split_animacy_plural_only"
		else
			temp = "both_numbers_split_animacy"
		end
	end

	for _, extra_case in ipairs({
		{"par", "partitive"},
		{"loc", "locative"},
		{"voc", "vocative"},
	}) do
		local case, engcase = unpack(extra_case)
		local template
		if args.n ~= "s" and args.n ~= "p" and args.any_overridden[case .. "_pl"] then
			if not args.any_overridden[case] then
				data[case] = ""
			end
			template = extra_case_template_with_plural
		elseif args.n == "s" and args.any_overridden[case] or args.n == "p" and args.any_overridden[case .. "_pl"] then
			template = extra_case_template
		end
		if template then
			template = strutils.format(template, {case=case, engcase=engcase})
			data[case .. "_clause"] = strutils.format(template, data)
		else
			data[case .. "_clause"] = ""
		end
	end

	for _, extra_case in ipairs({
		{"count", "count form"},
		{"pauc", "paucal"},
	}) do
		local case, engcase = unpack(extra_case)
		local template
		if args.n ~= "p" and args.any_overridden[case] then
			template = extra_case_template
		end
		if template then
			template = strutils.format(template, {case=case, engcase=engcase})
			data[case .. "_clause"] = strutils.format(template, data)
		else
			data[case .. "_clause"] = ""
		end
	end

	local notes = get_arg_chain(args, "notes", "notes")
	local all_notes = {}
	for _, note in ipairs(args.internal_notes) do
		-- Superscript footnote marker at beginning of note, similarly to what's
		-- done at end of forms.
		local symbol, entry = m_table_tools.get_initial_notes(note)
		table.insert(all_notes, symbol .. entry)
	end
	for _, note in ipairs(notes) do
		-- Here too.
		local symbol, entry = m_table_tools.get_initial_notes(note)
		table.insert(all_notes, symbol .. entry)
	end
	data.notes = table.concat(all_notes, "<br />")
	data.notes_clause = data.notes ~= "" and strutils.format(notes_template, data) or ""

	return strutils.format(templates[temp], data)
end

local extra_case_template = [===[

! style="background:#eff7ff" | {engcase}
| {\op}{case}{\cl}
|
|-]===]

local extra_case_template_with_plural = [===[

! style="background:#eff7ff" | {engcase}
| {\op}{case}{\cl}
| {\op}{case}_pl{\cl}
|-]===]

notes_template = [===[
<div style="width:100%;text-align:left;background:#d9ebff">
<div style="display:inline-block;text-align:left;padding-left:1em;padding-right:1em">
{notes}
</div></div>
]===]

local function template_prelude(min_width)
	min_width = min_width or "70"
	return rsub([===[
<div>
<div class="NavFrame" style="display:inline-block; min-width:MINWIDTHem">
<div class="NavHead" style="background:#eff7ff;">{title}<span style="font-weight:normal;">{after_title}</span>&nbsp;</div>
<div class="NavContent">
{\op}| style="background:#F9F9F9; text-align:center; min-width:MINWIDTHem; width:100%;" class="inflection-table"
|-
]===], "MINWIDTH", min_width)
end

local function template_postlude()
	return [===[|-{par_clause}{loc_clause}{voc_clause}{count_clause}{pauc_clause}
|{\cl}{notes_clause}</div></div></div>]===]
end

templates["both_numbers"] = template_prelude("45") .. [===[
! style="width:10em;background:#d9ebff" |
! style="background:#d9ebff" | singular
! style="background:#d9ebff" | plural
|-
! style="background:#eff7ff" | nominative
| {nom_sg}
| {nom_pl}
|-
! style="background:#eff7ff" | genitive
| {gen_sg}
| {gen_pl}
|-
! style="background:#eff7ff" | dative
| {dat_sg}
| {dat_pl}
|-
! style="background:#eff7ff" | accusative
| {acc_sg_an}
| {acc_pl_an}
|-
! style="background:#eff7ff" | instrumental
| {ins_sg}
| {ins_pl}
|-
! style="background:#eff7ff" | prepositional
| {pre_sg}
| {pre_pl}
]===] .. template_postlude()

templates["both_numbers_split_animacy"] = template_prelude("50") .. [===[
! style="width:15em;background:#d9ebff" |
! style="background:#d9ebff" | singular
! style="background:#d9ebff" | plural
|-
! style="background:#eff7ff" | nominative
| {nom_sg}
| {nom_pl}
|-
! style="background:#eff7ff" | genitive
| {gen_sg}
| {gen_pl}
|-
! style="background:#eff7ff" | dative
| {dat_sg}
| {dat_pl}
|-
! style="background:#eff7ff" rowspan="2" | accusative <span style="padding-left:1em;display:inline-block;vertical-align:middle">animate<br/><br/>inanimate</span>
| {acc_sg_an}
| {acc_pl_an}
|-
| {acc_sg_in}
| {acc_pl_in}
|-
! style="background:#eff7ff" | instrumental
| {ins_sg}
| {ins_pl}
|-
! style="background:#eff7ff" | prepositional
| {pre_sg}
| {pre_pl}
]===] .. template_postlude()

templates["both_numbers_split_animacy_plural_only"] = template_prelude("50") .. [===[
! style="width:15em;background:#d9ebff" |
! style="background:#d9ebff" | singular
! style="background:#d9ebff" | plural
|-
! style="background:#eff7ff" | nominative
| {nom_sg}
| {nom_pl}
|-
! style="background:#eff7ff" | genitive
| {gen_sg}
| {gen_pl}
|-
! style="background:#eff7ff" | dative
| {dat_sg}
| {dat_pl}
|-
! style="background:#eff7ff" rowspan="2" | accusative <span style="padding-left:1em;display:inline-block;vertical-align:middle">animate<br/><br/>inanimate</span>
| rowspan="2" | {acc_sg_an}
| {acc_pl_an}
|-
| {acc_pl_in}
|-
! style="background:#eff7ff" | instrumental
| {ins_sg}
| {ins_pl}
|-
! style="background:#eff7ff" | prepositional
| {pre_sg}
| {pre_pl}
]===] .. template_postlude()

templates["one_number"] = template_prelude("30") .. [===[
! style="width:10em;background:#d9ebff" |
! style="background:#d9ebff" | {number}
|-
! style="background:#eff7ff" | nominative
| {nom_x}
|-
! style="background:#eff7ff" | genitive
| {gen_x}
|-
! style="background:#eff7ff" | dative
| {dat_x}
|-
! style="background:#eff7ff" | accusative
| {acc_x_an}
|-
! style="background:#eff7ff" | instrumental
| {ins_x}
|-
! style="background:#eff7ff" | prepositional
| {pre_x}
]===] .. template_postlude()

templates["one_number_split_animacy"] = template_prelude("35") .. [===[
! style="width:15em;background:#d9ebff" |
! style="background:#d9ebff" | {number}
|-
! style="background:#eff7ff" | nominative
| {nom_x}
|-
! style="background:#eff7ff" | genitive
| {gen_x}
|-
! style="background:#eff7ff" | dative
| {dat_x}
|-
! style="background:#eff7ff" rowspan="2" | accusative <span style="padding-left:1em;display:inline-block;vertical-align:middle">animate<br/><br/>inanimate</span>
| {acc_x_an}
|-
| {acc_x_in}
|-
! style="background:#eff7ff" | instrumental
| {ins_x}
|-
! style="background:#eff7ff" | prepositional
| {pre_x}
]===] .. template_postlude()

return export
