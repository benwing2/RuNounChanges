-- Author: Benwing, based on early version by CodeCat.

--[[
FIXME: Nouns/adjectives to create to exemplify complex declensions:
-- riḍan (رِضًا or رِضًى)
--]]

local m_utilities = require("Module:utilities")
local m_links = require("Module:links")
local ar_utilities = require("Module:ar-utilities")
local m_table = require("Module:table")

local lang = require("Module:languages").getByCode("ar")
local u = require("Module:string/char")
local rfind = mw.ustring.find
local rsubn = mw.ustring.gsub
local rmatch = mw.ustring.match
local rsplit = mw.text.split

-- This is used in place of a transliteration when no manual
-- translit is specified and we're unable to automatically generate
-- one (typically because some vowel diacritics are missing).
local BOGUS_CHAR = u(0xFFFD)

-- hamza variants
local HAMZA            = u(0x0621) -- hamza on the line (stand-alone hamza) = ء
local HAMZA_ON_ALIF    = u(0x0623)
local HAMZA_ON_W       = u(0x0624)
local HAMZA_UNDER_ALIF = u(0x0625)
local HAMZA_ON_Y       = u(0x0626)
local HAMZA_ANY = "[" .. HAMZA .. HAMZA_ON_ALIF .. HAMZA_UNDER_ALIF .. HAMZA_ON_W .. HAMZA_ON_Y .. "]"
local HAMZA_PH = u(0xFFF0) -- hamza placeholder

-- various letters
local ALIF   = u(0x0627) -- ʔalif = ا
local AMAQ   = u(0x0649) -- ʔalif maqṣūra = ى
local AMAD   = u(0x0622) -- ʔalif madda = آ
local TAM    = u(0x0629) -- tāʔ marbūṭa = ة
local T      = u(0x062A) -- tāʔ = ت
local HYPHEN = u(0x0640)
local N      = u(0x0646) -- nūn = ن
local W      = u(0x0648) -- wāw = و
local Y      = u(0x064A) -- yā = ي

-- diacritics
local A  = u(0x064E) -- fatḥa
local AN = u(0x064B) -- fatḥatān (fatḥa tanwīn)
local U  = u(0x064F) -- ḍamma
local UN = u(0x064C) -- ḍammatān (ḍamma tanwīn)
local I  = u(0x0650) -- kasra
local IN = u(0x064D) -- kasratān (kasra tanwīn)
local SK = u(0x0652) -- sukūn = no vowel
local SH = u(0x0651) -- šadda = gemination of consonants
local DAGGER_ALIF = u(0x0670)
local DIACRITIC_ANY_BUT_SH_insides = A .. I .. U .. AN .. IN .. UN .. SK .. DAGGER_ALIF
local DIACRITIC_ANY_BUT_SH = "[" .. DIACRITIC_ANY_BUT_SH_insides .. "]"
local DIACRITIC_ANY_insides = DIACRITIC_ANY_BUT_SH .. SH
local DIACRITIC_ANY = "[" .. DIACRITIC_ANY_insides .. "]"
local TATWEEL = u(0x0640)

-- common combinations
local NA    = N .. A
local NI    = N .. I
local AH    = A .. TAM
local AT    = A .. T
local AA    = A .. ALIF
local AAMAQ = A .. AMAQ
local AAH   = AA .. TAM
local AAT   = AA .. T
local II    = I .. Y
local IIN   = II .. N
local IINA  = II .. NA
local IY	= II
local UU    = U .. W
local UUN   = UU .. N
local UUNA  = UU .. NA
local AY    = A .. Y
local AW    = A .. W
local AYSK  = AY .. SK
local AWSK  = AW .. SK
local AAN   = AA .. N
local AANI  = AA .. NI
local AYN   = AYSK .. N
local AYNI  = AYSK .. NI
local AWN   = AWSK .. N
local AWNA  = AWSK .. NA
local AYNA  = AYSK .. NA
local AYAAT = AY .. AAT
local UNU = "[" .. UN .. U .. "]"

-- optional diacritics/letters
local AOPT = A .. "?"
local AOPTA = A .. "?" .. ALIF
local IOPT = I .. "?"
local INOPT = IN .. "?"
local UOPT = U .. "?"
local UNOPT = UN .. "?"
local UNUOPT = UNU .. "?"
local SKOPT = SK .. "?"

-- lists of consonants
-- exclude tāʔ marbūṭa because we don't want it treated as a consonant
-- in patterns like أَفْعَل
local consonants_needing_vowels_no_tam = "بتثجحخدذرزسشصضطظعغفقكلمنهپچڤگڨڧأإؤئء"
-- consonants on the right side; includes alif madda
local rconsonants_no_tam = consonants_needing_vowels_no_tam .. "ويآ"
-- consonants on the left side; does not include alif madda
local lconsonants_no_tam = consonants_needing_vowels_no_tam .. "وي"
-- consonant character class
local C = "[" .. lconsonants_no_tam .. "]"
-- capturing consonant character class
local CCAP = "(" .. C .. ")"

local LRM = u(0x200E) --left-to-right mark

-- First syllable or so of elative/color-defect adjective
local ELCD_START = "^" .. HAMZA_ON_ALIF .. AOPT .. CCAP

local export = {}

--------------------
-- Utility functions
--------------------

-- version of rsubn() that discards all but the first return value
local function rsub(term, foo, bar)
	local retval = rsubn(term, foo, bar)
	return retval
end

-- version of rsub() that asserts that a match occurred
local function assert_rsub(term, foo, bar)
	local retval, numsub = rsubn(term, foo, bar)
	assert(numsub > 0)
	return retval
end

local function make_link(arabic)
	--return m_links.full_link(nil, arabic, lang, nil, "term", nil, {tr = "-"}, false)
	return m_links.full_link({lang = lang, alt = arabic}, "term")
end

local function track(page)
	require("Module:debug/track")("ar-nominals/" .. page)
	return true
end

local function copy_stem_and_replace(stem, ar, tr)
	stem = m_table.shallowcopy(stem)
	stem.form = ar
	stem.translit = tr
	return stem
end

local function check_value(value, possible_values, propname)
	if type(possible_values) ~= "table" then
		possible_values = {possible_values}
	end
	if not m_table.contains(possible_values, value) then
		local quoted_values = {}
		for i, possible_value in ipairs(possible_values) do
			quoted_values = '"' .. possible_value .. '"'
		error(('Internal error: Property "%s" should be %s but saw "%s"'):format(propname,
			m_table.serialCommaJoin(quoted_values, {conj = "or", dontTag = true}), value))
	end
end

local function check_num(base, values)
	check_value(base.num, values, "number")
end

local function prefix_with_tatweel_if(ending)
	if rfind(ending, "^" .. DIACRITIC_ANY) then
		return TATWEEL .. ending
	else
		return ending
	end
end

local function bad_ar_ending(ar, endings, slot_prefix, interr)
	if type(endings) ~= "table" then
		endings = {endings}
	end
	local prefixed_endings = {}
	for i, ending in ipairs(endings) do
		prefixed_endings[i] = prefix_with_tatweel_if(ending)
	end

	error(("%sArabic-script argument %s for slot prefix \"%s\" doesn't end with expected ending %s"):format(
		interr and "Internal error: " or "", ar, slot_prefix,
		m_table.serialCommaJoin(prefixed_endings, {conj = "or", dontTag = true})))
end

local function bad_tr_ending(tr, endings, slot_prefix, interr)
	if type(endings) ~= "table" then
		endings = {endings}
	end
	local prefixed_endings = {}
	for i, ending in ipairs(endings) do
		prefixed_endings[i] = "-" .. ending
	end

	error(("%sTranslit %s for slot prefix \"%s\" doesn't end with expected ending -%s"):format(
		interr and "Internal error: " or "", tr, slot_prefix,
		m_table.serialCommaJoin(prefixed_endings, {conj = "or", dontTag = true})))
end

local function check_ar_ending(ar, ending, slot_prefix, interr)
	if not rfind(ar, ending .. "$") then
		bad_ar_ending(ar, ending, slot_prefix, interr)
	end
end

local function check_tr_ending(tr, ending, slot_prefix, interr)
	if not rfind(tr, ending .. "$") then
		bad_tr_ending(ar, ending, slot_prefix, interr)
	end
end

local function check_ar_tr_ending(ar, tr, ending, slot_prefix, interr)
	check_ar_ending(ar, ending, slot_prefix, interr)
	check_tr_ending(tr, transliterate(ending), slot_prefix, interr)
end

local function check_ending(stem, ending, slot_prefix, interr)
	local ar, tr = stem.form, stem.translit
	check_ar_tr_ending(ar, tr, ending, slot_prefix, interr)
end

local function strip_ar_ending(ar, ending, slot_prefix, interr)
	local strippedar = rsub(ar, ending .. "$", "")
	if strippedar == ar then
		bad_ar_ending(ar, ending, slot_prefix, interr)
	end
	return strippedar
end

local function strip_tr_ending(tr, ending, slot_prefix, interr)
	local strippedtr = rsub(tr, ending .. "$", "")
	if strippedtr == tr then
		bad_tr_ending(tr, ending, slot_prefix, interr)
	end
	return strippedtr
end

local function strip_ar_tr_ending(ar, tr, ending, slot_prefix, interr)
	local endingtr
	if type(ending) == "table" then
		ending, endingtr = unpack(ending)
	else
		endingtr = transliterate(ending)
	end

	ar = strip_ar_ending(ar, ending, slot_prefix, interr)
	tr = strip_tr_ending(tr, endingtr, slot_prefix, interr)
	return ar, tr
end

local function strip_ending(stem, ending, slot_prefix, interr)
	local ar, tr = stem.form, stem.translit
	ar, tr = strip_ar_tr_ending(ar, tr, ending, slot_prefix, interr)
	return copy_stem_and_replace(stem, ar, tr)
end

-------------------------------------
-- Functions for building declensions
-------------------------------------

-- Functions that do the actual inflecting of a given declension type. Each function is passed three arguments: `base`,
-- `props` (properties of the noun or adjective form being declined; see below) and `stem` (a form object containing the
-- stem onto which case and state endings should be added). The transliteration is always present in `stem.translit`.
-- The Arabic in `stem.form` will always be in the normalized form output by detect_declension(), i.e. it will be
-- nominative indefinite and without ʔiʕrāb except for final-weak stems. Alif madda will be regularized into hamza +
-- fatḥa + alif to ease operations; this will be undone later in postprocessing. The function should generally call
-- add_declensions() to add the actual declensions to the appropriate slots. It should also call insert_cats() to add
-- any categories and annotations.
--
-- `props` contains the following fields:
-- * `slot`: The slot prefix to add the per-declined-form suffixes to in order to form the actual slot.
-- * `number`: The number of the noun or adjective being declined ("sg", "du", "pl", "coll", "sgl" or "pauc").
-- * `gender`: The gender of the adjective being declined ("m" or "f").
local declensions = {}

-- Table of additional properties of a declension type. Currently there are two: `cats` (a string or list of strings
-- specifying the category or categories to insert the lemma into, or a function of three arguments `base`, `slot` and
-- `stem`, as above, to generate the same) and `ann` (a string specifying the English annotation to add to the
-- declension table, or a function of three arguments `base`, `slot` and `stem`, as above, to generate the same. The
-- category strings should not have the word "Arabic", which will automatically be prefixed, and should use all-caps
-- placeholders to represent values that will be appropriately substituted, specifically:
-- * NUMBER is replaced with the English equivalent of the form's number (e.g. "singular", "dual", "plural", "paucal");
-- * BROKNUM is replaced with the word "broken" followed by the English equivalent of the form's number;
-- * POS is replaced with the part of speech, generally "noun" or "adjective";
-- * PLPOS is replaced with the plural form of the part of speech.
-- The annotation strings can contain the same placeholders.
local declprops = {}

-- Create and return the 'data' structure that will hold all of the
-- generated declensional forms, as well as other ancillary information
-- such as the possible numbers, genders and cases the the actual numbers
-- and states to store (in 'data.numbers' and 'data.states' respectively).
local function init_data()
	-- FORMS contains a table of forms for each inflectional category,
	-- e.g. "nom_sg_ind" for nouns or "nom_m_sg_ind" for adjectives. The value
	-- of an entry is an array of alternatives (e.g. different plurals), where
	-- each alternative is either a string of the form "ARABIC" or
	-- "ARABIC/TRANSLIT", or an array of such strings (this is used for
	-- alternative spellings involving different hamza seats,
	-- e.g. مُبْتَدَؤُون or مُبْتَدَأُون). Alternative hamza spellings are separated
	-- in display by an "inner separator" (/), while alternatives on
	-- the level of different plurals are separated by an "outer separator" (;).
	return {forms = {}, title = nil, categories = {},
		allgenders = {"m", "f"},
		allstates = {"ind", "def", "con"},
		allnumbers = {"sg", "du", "pl"},
		states = {}, -- initialized later
		numbers = {}, -- initialized later
		engnumbers = {sg="singular", du="dual", pl="plural",
			coll="collective", sing="singulative", pauc="paucal"},
		engnumberscap = {sg="Singular", du="Dual", pl="Plural",
			coll="Collective", sing="Singulative", pauc="Paucal (3-10)"},
		allcases = {"nom", "acc", "gen", "inf"},
		allcases_with_lemma = {"nom", "acc", "gen", "inf", "lemma"},
		-- index into endings array indicating correct ending for given
		-- combination of state and case
		statecases = {
			ind = {nom = 1, acc = 2, gen = 3, inf = 10, lemma = 13},
			def = {nom = 4, acc = 5, gen = 6, inf = 11, lemma = 14},
			-- used for a definite adjective modifying a construct-state noun
			defcon = {nom = 4, acc = 5, gen = 6, inf = 11, lemma = 14},
			con = {nom = 7, acc = 8, gen = 9, inf = 12, lemma = 15},
		},
	}
end

-- Initialize and return ARGS, ORIGARGS and DATA (see init_data()).
-- ARGS is a table of user-supplied arguments, massaged from the original
-- arguments by converting empty-string arguments to nil and appending
-- translit arguments to their base arguments with a separating slash.
-- ORIGARGS is the original table of arguments.
local function init(origargs)
	-- Massage arguments by converting empty arguments to nil, and
	--  "" or '' arguments to empty.
	local args = {}
	for k, v in pairs(origargs) do
		args[k] = ine(v)
	end

	-- Further massage arguments by appending translit arguments to the
	-- corresponding base arguments, with a slash separator, as is expected
	-- in the rest of the code.
	--
	-- FIXME: We should consider separating translit and base arguments by the
	-- separators ; , | (used in overrides; see handle_lemma_and_overrides())
	-- and matching up individual parts, to allow separate translit arguments
	-- to be specified for overrides. But maybe not; the point of allowing
	-- separate translit arguments is for compatibility with headword
	-- templates such as "ar-noun" and "ar-adj", and those templates don't
	-- handle override arguments.

	local function dotr(arg, argtr)
		if not args[arg] then
			error("Argument '" .. argtr .."' specified but not corresponding base argument '" .. arg .. "'")
		end
		args[arg] = args[arg] .. "/" .. args[argtr]
	end

	-- By convention, corresponding to arg 1 is tr; corresponding to
	-- head2, head3, ... is tr2, tr3, ...; corresponding to
	-- modhead2, modhead3, ... is modtr2, modtr3, ...; corresponding to
	-- modNhead2, modNhead3, ... is modNtr2, modNtr3, ..; corresponding to
	-- all other arguments FOO, FOO2, ... is FOOtr, FOO2tr, ...
	for k, v in pairs(args) do
		if k == "tr" then
			dotr(1, "tr")
		elseif rfind(k, "tr[0-9]+$") then
			dotr(assert_rsub(k, "tr([0-9]+)$", "head%1"), k)
		elseif rfind(k, "tr$") then
			dotr(assert_rsub(k, "tr$", ""), k)
		end
	end

	-- Construct data.
	local data = init_data()

	return args, origargs, data
end

-- Parse the user-specified state spec and other related arguments. The
-- user can specify, using idafaN=, how modifiers are related to previous
-- words. The user can also manually specify which states are to appear;
-- whether to omit the definite article in the definite state; and
-- how/whether to restrict modifiers to a particular state, case or number.
-- Normally the modN_* parameters and basestate= do not need to be set
-- directly; instead, use idafaN=. It may be necessary to explicitly
-- specify state= in the presence of proper nouns or definite-only
-- adjectival expressions. NOTE: At the time this function is called,
-- data.numbers has not yet been initialized.
local function parse_state_etc_spec(data, args)
	local function check(arg, dataval, allvalues)
		if args[arg] then
			if not m_table.contains(allvalues, args[arg]) then
				error("For " .. arg .. "=, value '" .. args[arg] .. "' should be one of " ..
					table.concat(allvalues, ", "))
			end
			data[dataval] = args[arg]
		end
	end

	local function check_boolean(arg, dataval)
		check(arg, dataval, {"yes", "no"})
		if data[dataval] == "yes" then
			data[dataval] = true
		elseif data[dataval] == "no" then
			data[dataval] = false
		end
	end

	-- Set default value; may be overridden e.g. by arg["state"] or
	-- by idafaN=.
	data.states = data.allstates

	-- List of pairs of idafaN/modN parameters
	local idafa_mod_list = {{"idafa", "mod"}}
	for i=2,max_mods do
		table.insert(idafa_mod_list, {"idafa" .. i, "mod" .. i})
	end

	-- True if the value of an |idafa= param is a valid adjectival modifier
	-- value.
	local function valid_adjectival_idafaval(idafaval)
		return idafaval == "adj" or idafaval == "adj-base" or
			idafaval == "adj-mod" or rfind(idafaval, "^adj%-mod[0-9]+$")
	end

	-- Extract the referent (base or modifier) of an adjectival |idafa= param.
	-- Assumes the value is valid.
	local function adjectival_idafaval_referent(idafaval)
		if idafaval == "adj" then
			return "base"
		end
		return assert_rsub(idafaval, "^adj%-", "")
	end

	-- Convert a base/mod spec to an index: 0=base, 1=mod, 2=mod2, etc.
	local function basemod_to_index(basemod)
		if basemod == "base" then return 0 end
		if basemod == "mod" then return 1 end
		return tonumber(assert_rsub(basemod, "^mod", ""))
	end

	-- Recognize idafa spec and handle it.
	-- We do the following:
	-- (1) Check that if idafaN= is given, then modN= is also given.
	-- (2) Check that adjectival modifiers aren't followed by idafa modifiers.
	-- (3) Check that adjectival modifiers are modifying the base or an
	--     ʔidāfa modifier, not another adjectival modifier.
	-- (4) Support idafa values "adj-base", "adj-mod", "adj-mod2", "adj"
	--     (="adj-base") etc. and check that we're referring to an earlier
	--     word.
	-- (5) For ʔidāfa modifiers, set basestate=con, set modN_case=gen,
	--     set modN_idafa=true, and set modN_number to the number specified
	--     in the parameter value (e.g. 'sg' or 'def-pl'); and if the
	--     parameter value specifies a state (e.g. 'def' or 'ind-du'),
	--     set modN_state= to this value, and if this is the last ʔidāfa
	--     modifier, also set state= to this value; if this is not the last
	--     ʔidāfa modifier, set modN_state=con and disallow a state to be
	--     specified in the parameter value.
	-- (6) For adjectival modifiers of the base, do nothing.
	-- (7) For adjectival modifiers of ʔidāfa modifiers, set modN_case=gen;
	--     set modN_idafa=false; and set modN_number=, modN_numgen= and
	--     modN_state= to match the values of the idafa modifier.

	-- error checking and find last ʔidāfa modifier
	local last_is_idafa = true
	local last_idafa_mod = "base"
	for _, idafa_mod in ipairs(idafa_mod_list) do
		local idafaparam = idafa_mod[1]
		local mod = idafa_mod[2]
		local idafaval = args[idafaparam]

		if idafaval then
			local paramval = idafaparam .. "=" .. idafaval
			if not args[mod] then
				error("'" .. idafaparam .. "' parameter without corresponding '"
					.. mod .. "' parameter")
			end
			if not valid_adjectival_idafaval(idafaval) then
				-- We're a construct (ʔidāfa) modifier
				if not last_is_idafa then
					error("ʔidāfa modifier " .. paramval .. " follows adjectival modifier")
				end
				last_idafa_mod = mod
			else
				last_is_idafa = false
				local adjref = adjectival_idafaval_referent(idafaval)
				if adjref ~= "base" then
					if basemod_to_index(adjref) >= basemod_to_index(mod) then
						error(paramval .. " can only refer to an earlier element")
					end
					local idafaref = assert_rsub(adjref, "^mod", "idafa")
					if not args[idafaref] then
						error(paramval .. " cannot refer to a missing modifier")
					elseif valid_adjectival_idafaval(args[idafaref]) then
						error(paramval .. " cannot refer to an adjectival modifier")
					end
				end
			end
		end
	end

	-- Now go through and set all the modN_ data values appropriately.
	for _, idafa_mod in ipairs(idafa_mod_list) do
		local idafaparam = idafa_mod[1]
		local mod = idafa_mod[2]
		local idafaval = args[idafaparam]

		if idafaval then
			local paramval = idafaparam .. "=" .. idafaval
			local bad_idafa = true
			if idafaval == "yes" then
				idafaval = "sg"
			end
			if idafaval == "ind-def" or m_table.contains(data.allstates, idafaval) then
				idafaval = idafaval .. "-sg"
			end
			if not idafaval then
				bad_idafa = false
			elseif valid_adjectival_idafaval(idafaval) then
				local adjref = adjectival_idafaval_referent(idafaval)
				if adjref ~= "base" then
					data[mod .. "_case"] = "gen"
					data[mod .. "_state"] = data[adjref .. "_state"]
					-- if agreement is with ind-def, make it def
					if data[mod .. "_state"] == "ind-def" then
						data[mod .. "_state"] = "def"
					end
					data[mod .. "_number"] = data[adjref .. "_number"]
					data[mod .. "_numgen"] = data[adjref .. "_numgen"]
					data[mod .. "_idafa"] = false
				end
				bad_idafa = false
			elseif m_table.contains(data.allnumbers, idafaval) then
				data.basestate = "con"
				data[mod .. "_case"] = "gen"
				data[mod .. "_number"] = idafaval
				data[mod .. "_idafa"] = true
				if mod ~= last_idafa_mod then
					data[mod .. "_state"] = "con"
				end
				bad_idafa = false
			elseif rfind(idafaval, "%-") then
				local state_num = rsplit(idafaval, "%-")
				-- Support ind-def as a possible value. We set modstate to
				-- ind-def, which will signal definite agreement with adjectival
				-- modifiers; then later on we change the value to ind.
				if #state_num == 3 and state_num[1] == "ind" and state_num[2] == "def" then
					state_num[1] = "ind-def"
					state_num[2] = state_num[3]
					table.remove(state_num)
				end
				if #state_num == 2 then
					local state = state_num[1]
					local num = state_num[2]
					if (state == "ind-def" or m_table.contains(data.allstates, state))
							and m_table.contains(data.allnumbers, num) then
						if mod == last_idafa_mod then
							if state == "ind-def" then
								data.states = {"def"}
							else
								data.states = {state}
							end
						else
							error(paramval .. " cannot specify a state because it is not the last ʔidāfa modifier")
						end
						data.basestate = "con"
						data[mod .. "_case"] = "gen"
						data[mod .. "_state"] = state
						data[mod .. "_number"] = num
						data[mod .. "_idafa"] = true
						bad_idafa = false
					end
				end
			end
			if bad_idafa then
				error(paramval .. " should be one of yes, def, sg, def-sg, adj, adj-base, adj-mod, adj-mod2 or similar")
			end
		end
	end

	if args["state"] == "ind-def" then
		data.states = {"def"}
		data.basestate = "ind"
	elseif args["state"] then
		data.states = rsplit(args["state"], ",")
		for _, state in ipairs(data.states) do
			if not m_table.contains(data.allstates, state) then
				error("For state=, value '" .. state .. "' should be one of " ..
					table.concat(data.allstates, ", "))
			end
		end
	end

	-- Now process explicit settings, so that they can override the
	-- settings based on idafaN=.
	check("basestate", "basestate", data.allstates)
	check_boolean("noirreg", "noirreg")
	check_boolean("omitarticle", "omitarticle")
	data.prefix = args.prefix

	for _, mod in ipairs(mod_list) do
		check(mod .. "state", mod .. "_state", data.allstates)
		check(mod .. "case", mod .. "_case", data.allcases)
		check(mod .. "number", mod .. "_number", data.allnumgens)
		check(mod .. "numgen", mod .. "_numgen", data.allnumgens)
		check_boolean(mod .. "idafa", mod .. "_idafa")
		check_boolean(mod .. "omitarticle", mod .. "_omitarticle")
		data[mod .. "_prefix"] = args[mod .. "prefix"]
	end

	-- Make sure modN_numgen is initialized, to modN_number if necessary.
	-- This simplifies logic in certain places, e.g. call_declensions().
	-- Also convert ind-def to ind.
	for _, mod in ipairs(mod_list) do
		data[mod .. "_numgen"] = data[mod .. "_numgen"] or data[mod .. "_number"]
		if data[mod .. "_state"] == "ind-def" then
			data[mod.. "_state"] = "ind"
		end
	end
end

-- Parse the user-specified number spec. The user can manually specify which
-- numbers are to appear. Return true if |number= was specified.
local function parse_number_spec(data, args)
	if args["number"] then
		data.numbers = rsplit(args["number"], ",")
		for _, num in ipairs(data.numbers) do
			if not m_table.contains(data.allnumbers, num) then
				error("For number=, value '" .. num .. "' should be one of " ..
					table.concat(data.allnumbers, ", "))
			end
		end
		return true
	else
		data.numbers = data.allnumbers
		return false
	end
end

-- Determine which numbers will appear using the logic for nouns.
-- See comment just below.
local function determine_noun_numbers(data, args, pls)
	-- Can manually specify which numbers are to appear, and exactly those
	-- numbers will appear. Otherwise, if any plurals given, duals and plurals
	-- appear; else, only singular (on the assumption that the word is a proper
	-- noun or abstract noun that exists only in the singular); however,
	-- singular won't appear if "-" given for singular, and similarly for dual.
	if not parse_number_spec(data, args) then
		data.numbers = {}
		local sgarg1 = args[1]
		local duarg1 = args["d"]
		if sgarg1 ~= "-" then
			table.insert(data.numbers, "sg")
		end
		if #pls["base"] > 0 then
			-- Dual appears if either: explicit dual stem (not -) is given, or
			-- default dual is used and explicit singular stem (not -) is given.
			if (duarg1 and duarg1 ~= "-") or (not duarg1 and sgarg1 ~= "-") then
				table.insert(data.numbers, "du")
			end
			table.insert(data.numbers, "pl")
		elseif duarg1 and duarg1 ~= "-" then
			-- If explicit dual but no plural given, include it. Useful for
			-- dual tantum words.
			table.insert(data.numbers, "du")
		end
	end
end

-- For stem STEM, convert to stem-and-type format and insert stem and type
-- into RESULTS, checking to make sure it's not already there. SGS is the
-- list of singular items to base derived forms off of (masculine or feminine
-- as appropriate), an array of length-two arrays of {COMBINED_STEM, TYPE} as
-- returned by stem_and_type(); ISFEM is true if this is feminine gender;
-- NUM is "sg", "du" or "pl". POS is the part of speech, generally "noun" or
-- "adjective".
local function insert_stems(stem, results, sgs, isfem, num, pos)
	if stem == "-" then
		return
	end
	for _, sg in ipairs(sgs) do
		local combined_stem, ty = export.stem_and_type(stem,
			sg[1], sg[2], isfem, num, pos)
		m_table.insertIfNot(results, {combined_stem, ty})
	end
end

-- Handle manually specified overrides of individual forms. Separate
-- outer-level alternants with ; or , or the Arabic equivalents; separate
-- inner-level alternants with | (we can't use / because it's already in
-- use separating Arabic from translit).
--
-- Also determine lemma and allow it to be overridden.
-- Also allow POS (part of speech) to be overridden.
local function handle_lemma_and_overrides(data, args)
	local function handle_override(arg)
		if args[arg] then
			local ovval = {}
			local alts1 = rsplit(args[arg], "[;,؛،]")
			for _, alt1 in ipairs(alts1) do
				local alts2 = rsplit(alt1, "|")
				table.insert(ovval, alts2)
			end
			data.forms[arg] = ovval
		end
	end

	local function do_overrides(mod)
		for _, numgen in ipairs(data.allnumgens) do
			for _, state in ipairs(data.allstates) do
				for _, case in ipairs(data.allcases) do
					local arg = mod .. case .. "_" .. numgen .. "_" .. state
					handle_override(arg)
					if args[arg] and not data.noirreg then
						insert_cats(base, props, "PLPOS with irregular NUMBER", "NUMBER of irregular POS")
					end
				end
			end
		end
	end

	do_overrides("")
	for _, mod in ipairs(mod_list) do
		do_overrides(mod .. "_")
	end

	local function get_lemma(mod)
		for _, numgen in ipairs(data.numgens()) do
			for _, state in ipairs(data.states) do
				local arg = mod .. "lemma_" .. numgen .. "_" .. state
				if data.forms[arg] and #data.forms[arg] > 0 then
					return data.forms[arg]
				end
			end
		end
		return nil
	end

	data.forms["lemma"] = get_lemma("")
	for _, mod in ipairs(mod_list) do
		data.forms[mod .. "_lemma"] = get_lemma(mod .. "_")
	end
	handle_override("lemma")
	for _, mod in ipairs(mod_list) do
		handle_override(mod .. "_lemma")
	end
end

-- Return the part of speech based on the part of speech contained in
-- data.pos and MOD (either "", "mod_", "mod2_", etc., same as in
-- do_gender_number_1()). If we're a modifier, don't use data.pos but
-- instead choose based on whether modifier is adjectival or nominal
-- (ʔiḍāfa).
local function get_pos(data, mod)
	local ismod = mod ~= ""
	if not ismod then
		return data.pos
	elseif data[mod .. "idafa"] then
		return "noun"
	else
		return "adjective"
	end
end

-- Find the stems associated with a particular gender/number combination.
-- ARGS is the set of all arguments. ARGPREFS is an array of argument prefixes
-- (e.g. "f" for the actual arguments "f", "f2", ..., for the feminine
-- singular; we allow more than one to handle "cpl"). SGS is a
-- "stem-type list" (see do_gender_number()), and is the list of stems to
-- base derived forms off of (masculine or feminine as appropriate), an array
-- of length-two arrays of {COMBINED_STEM, TYPE} as returned by
-- stem_and_type(). DEFAULT, ISFEM and NUM are as in do_gender_number().
-- MOD is either "", "mod_", "mod2_", etc. depending if we're working on a
-- base or modifier argument (in the latter case, basically if the argument
-- begins with "mod").
local function do_gender_number_1(data, args, argprefs, sgs, default, isfem, num, mod)
	local results = {}
	local function handle_stem(stem)
		insert_stems(stem, results, sgs, isfem, num, get_pos(data, mod))
	end

	-- If no arguments specified, use the default instead.
	need_default = true
	for _, argpref in ipairs(argprefs) do
		if args[argpref] then
			need_default = false
			break
		end
	end
	if need_default then
		if not default then
			return results
		end
		handle_stem(default)
		return results
	end

	-- For explicitly specified arguments, make sure there's at least one
	-- stem to generate off of; otherwise specifying e.g. 'sing=- pauc=فُلَان'
	-- won't override paucal.
	if #sgs == 0 then
		sgs = {{"", ""}}
	end
	for _, argpref in ipairs(argprefs) do
		if args[argpref] then
			handle_stem(args[argpref])
		end
		local i = 2
		while args[argpref .. i] do
			handle_stem(args[argpref .. i])
			i = i + 1
		end
	end
	return results
end

-- For a given gender/number combination, parse and return the full set
-- of stems for both base and modifier. The return value is a
-- "stem specification", i.e. table with a "base" key for the base, a
-- "mod" key for the first modifier (see below), a "mod2" key for the
-- second modifier, etc. listing all stems for both the base and modifier(s).
-- The value of each key is a "stem-type list", i.e. an array of stem-type
-- pairs, where each element is a size-two array of {COMBINED_STEM, STEM_TYPE}.
-- COMBINED_STEM is a stem with attached transliteration in the form
-- STEM/TRANSLIT (where the transliteration is either manually specified in
-- the stem argument, e.g. 'pl=لُورْدَات/lordāt', or auto-transliterated from
-- the Arabic, with BOGUS_CHAR substituting for the transliteration if
-- auto-translit fails). STEM_TYPE is the declension of the stem, either
-- manually specified, e.g. 'بَبَّغَاء:di' for manually-specified diptote, or
-- auto-detected (see stem_and_type() and detect_type()).
--
-- DATA and ARGS are as in init(). ARGPREFS is an array of the prefixes for
-- the argument(s) specifying the stem (and optional translit and declension
-- type). For a given ARGPREF, we check ARGPREF, ARGPREF2, ARGPREF3, ... in
-- turn for the base, and modARGPREF, modARGPREF2, modARGPREF3, ... in turn
-- for the first modifier, and mod2ARGPREF, mod2ARGPREF2, mod2ARGPREF3, ...
-- for the second modifier, etc. SGS is a stem specification (see above),
-- giving the stems that are used to base derived forms off of (e.g. if a stem
-- type "smp" appears in place of a stem, the sound masculine plural of the
-- stems in SGS will be derived). DEFAULT is a single stem (i.e. a string) that
-- is used when no stems were explicitly given by the user (typically either
-- "f", "m", "d" or "p"), or nil for no default. ISFEM is true if we're
-- accumulating stems for a feminine number/gender category, and NUM is the
-- number (expected to be "sg", "du" or "pl") of the number/gender category
-- we're accumulating stems for.
--
-- About bases and modifiers: Note that e.g. in the noun phrase يَوْم الاِثْنَيْن
-- the head noun يَوْم is the base and the noun الاِثْنَيْن is the modifier.
-- In a noun phrase like البَحْر الأَبْيَض المُتَوَسِّط, there are two modifiers.
-- Note that modifiers come in two varieties, adjectival modifiers and
-- construct (ʔidāfa) modifiers. The first above noun phrase is an example
-- of a noun phrase with a construct modifier, where the base is fixed in
-- the construct state and the modifier is fixed in number and case
-- (which is always genitive) and possibly in state. The second above noun
-- phrase is an example of a noun phrase with two adjectival modifiers.
-- A construct modifier is generally a noun, whereas an adjectival modifier
-- is an adjective that usually agrees in state, number and case with the
-- base noun. (Note that in the case of multiple modifiers, it is possible
-- for e.g. the second modifier to be an adjectival modifier that agrees
-- with the first, construct, modifier, in which case its case will be fixed
-- to genitive, its number will be fixed to the same number as the first
-- modifier and its state will vary or not depending on whether the first
-- modifier's state varies. It is not possible in general to distinguish
-- adjectival and construct modifiers by looking at the values of
-- modN_state, modN_case or modN_number, since e.g. a third modifier could
-- have all of them specified and be either kind. Thus we have modN_idafa,
-- which is true for a construct modifier, false otherwise.)
local function do_gender_number(data, args, argprefs, sgs, default, isfem, num)
	local results = do_gender_number_1(data, args, argprefs, sgs["base"],
		default, isfem, num, "")
	basemodtable = {base=results}
	for _, mod in ipairs(mod_list) do
		local modn_argprefs = {}
		for _, argpref in ipairs(argprefs) do
			table.insert(modn_argprefs, mod .. argpref)
		end
		local modn_results = do_gender_number_1(data, args, modn_argprefs,
			sgs[mod] or {}, default, isfem, num, mod .. "_")
		basemodtable[mod] = modn_results
	end
	return basemodtable
end

-- Generate declensions for the given combined stem and type, for MOD
-- (either "" if we're working on the base or "mod_", "mod2_", etc. if we're
-- working on a modifier) and NUMGEN (number or number-gender combination,
-- of the sort that forms part of the keys in DATA.FORMS).
local function call_declension(combined_stem, ty, data, mod, numgen)
	if ty == "-" then
		return
	end

	if not declensions[ty] then
		error("Unknown declension type '" .. ty .. "'")
	end
	
	local ar, tr = split_arabic_tr(combined_stem)
	declensions[ty](ar, tr, data, mod, numgen)
end

-- Generate declensions for the stems of a given number/gender combination
-- and for either the base or the modifier. STEMTYPES is a stem-type list
-- (see do_gender_number()), listing all the stems and corresponding
-- declension types. MOD is either "", "mod_", "mod2_", etc. depending on
-- whether we're working on the base or a modifier. NUMGEN is the number or
-- number-gender combination we're working on, of the sort that forms part
-- of the keys in DATA.FORMS, e.g. "sg" or "m_sg".
local function call_declensions(stemtypes, data, mod, numgen)
	local mod_with_modnumgen = mod ~= "" and data[mod .. "numgen"]
	-- If modN_numgen= is given, do nothing if NUMGEN isn't the same
	if mod_with_modnumgen and data[mod .. "numgen"] ~= numgen then
		return
	end
	-- always call declension() if mod_with_modnumgen since it may affect
	-- other numbers (cf. يَوْم الاِثْنَيْن)
	if mod_with_modnumgen or m_table.contains(data.numbers, rsub(numgen, "^.*_", "")) then
		for _, stemtype in ipairs(stemtypes) do
			call_declension(stemtype[1], stemtype[2], data, mod, numgen)
		end
	end
end

-- Generate the entire set of declensions for a noun or adjective.
-- Also handle any manually-specified part of speech and any manual
-- declension overrides. The value of INFLECTIONS is an array of stem
-- specifications, one per number, where each element is a size-two
-- array of a stem specification (containing the set of stems and
-- corresponding declension types for the base and any modifiers;
-- see do_gender_number()) and a NUMGEN string, i.e. a string identifying
-- the number or number/gender in question (e.g. "sg", "du", "pl",
-- "m_sg", "f_pl", etc.).
local function do_declensions_and_overrides(data, args, declensions)
	-- do this before generating declensions so POS change is reflected in
	-- categories
	if args["pos"] then
		data.pos = args["pos"]
	end

	for _, declension in ipairs(declensions) do
		call_declensions(declension[1]["base"] or {}, data, "", declension[2])
		for _, mod in ipairs(mod_list) do
			call_declensions(declension[1][mod] or {}, data,
				mod .. "_", declension[2])
		end
	end

	handle_lemma_and_overrides(data, args)
end

-- Helper function for get_heads(). Parses the stems for either the
-- base or the modifier (see do_gender_number()). ARG1 is the argument
-- for the first stem and ARGN is the prefix of the arguments for the
-- remaining stems. For example, for the singular base, ARG1=1 and
-- ARGN="head"; for the first singular modifier, ARG1="mod" and
-- ARGN="modhead"; for the plural base, ARG1=ARGN="pl". The arguments
-- other than the first are numbered 2, 3, ..., which is appended to
-- ARGN. MOD is either "", "mod_", "mod2_", etc. depending if we're
-- working on a base or modifier argument. The returned value is an
-- array of stems, where each element is a size-two array of
-- {COMBINED_STEM, STEM_TYPE}. See do_gender_number().
local function get_heads_1(data, args, arg1, argn, mod)
	if not args[arg1] then
		return {}
	end
	local heads
	if args[arg1] == "-" then
		heads = {{"", "-"}}
	else
		heads = {}
		insert_stems(args[arg1], heads, {{args[arg1], ""}}, false, "sg",
			get_pos(data, mod))
	end
	local i = 2
	while args[argn .. i] do
		local arg = args[argn .. i]
		insert_stems(arg, heads, {{arg, ""}}, false, "sg",
			get_pos(data, mod))
		i = i + 1
	end
	return heads
end

-- Very similar to do_gender_number(), and returns the same type of
-- structure, but works specifically for the stems of the head (the
-- most basic gender/number combiation, e.g. singular for nouns,
-- masculine singular for adjectives and gendered nouns, collective
-- for collective nouns, etc.), including both base and modifier.
-- See do_gender_number(). Note that the actual return value is
-- two items, the first of which is the same type of structure
-- returned by do_gender_number() and the second of which is a boolean
-- indicating whether we were called from within a template documentation
-- page (in which case no user-specified arguments exist and we
-- substitute sample ones). The reason for this boolean is to indicate
-- whether sample arguments need to be substituted for other numbers
-- as well.
local function get_heads(data, args, headtype)
	if not args[1] and mw.title.getCurrentTitle().nsText == "Template" then
		return {base={{"{{{1}}}", "tri"}}}, true
	end

	if not args[1] then error("Parameter 1 (" .. headtype .. " stem) may not be empty.") end
	local base = get_heads_1(data, args, 1, "head", "")
	basemodtable = {base=base}
	for _, mod in ipairs(mod_list) do
		local modn = get_heads_1(data, args, mod, mod .. "head", mod .. "_")
		basemodtable[mod] = modn
	end
	return basemodtable, false
end

-- The main entry point for noun tables.
function export.show_noun(frame)
	local args, origargs, data = init(frame:getParent().args)
	data.pos = "noun"
	data.numgens = function() return data.numbers end
	data.allnumgens = data.allnumbers

	local sgs, is_template = get_heads(data, args, "singular")
	local pls = is_template and {base={{"{{{pl}}}", "tri"}}} or
		do_gender_number(data, args, {"pl", "cpl"}, sgs, nil, false, "pl")
	-- always do dual so cases like يَوْم الاِثْنَيْن work -- a singular with
	-- a dual modifier, where data.number refers only the singular
	-- but we need to go ahead and compute the dual so it parses the
	-- "modd" modifier dual argument. When the modifier dual argument
	-- is parsed, it will store the resulting dual declension for اِثْنَيْن
	-- in the modifier slot for all numbers, including specifically
	-- the singular.
	local dus = do_gender_number(data, args, {"d"}, sgs, "d", false, "du")

	parse_state_etc_spec(data, args)

	determine_noun_numbers(data, args, pls)

	do_declensions_and_overrides(data, args,
		{{sgs, "sg"}, {dus, "du"}, {pls, "pl"}})

	-- Make the table
	return make_noun_table(data)
end

local function any_feminine(data, stem_spec)
	for basemod, stemtypelist in pairs(stem_spec) do
		-- Only check modifiers if modN_numgen= not given. If not given, the
		-- modifier needs to be declined for all numgens; else only for the
		-- given numgen, which should be explicitly specified.
		if not (basemod ~= "base" and data[basemod .. "_numgen"]) then
			for _, stemtype in ipairs(stemtypelist) do
				if rfind(stemtype[1], TAM .. UNUOPT .. "/") then
					return true
				end
			end
		end
	end
	return false
end

local function all_feminine(data, stem_spec)
	for basemod, stemtypelist in pairs(stem_spec) do
		-- Only check modifiers if modN_numgen= not given. If not given, the
		-- modifier needs to be declined for all numgens; else only for the
		-- given numgen, which should be explicitly specified.
		if not (basemod ~= "base" and data[basemod .. "_numgen"]) then
			for _, stemtype in ipairs(stemtypelist) do
				if not rfind(stemtype[1], TAM .. UNUOPT .. "/") then
					return false
				end
			end
		end
	end
	return true
end

-- The main entry point for collective noun tables.
function export.show_coll_noun(frame)
	local args, origargs, data = init(frame:getParent().args)
	data.pos = "noun"
	data.allnumbers = {"coll", "sing", "du", "pauc", "pl"}
	data.engnumberscap["pl"] = "Plural of variety"
	data.numgens = function() return data.numbers end
	data.allnumgens = data.allnumbers

	local colls, is_template = get_heads(data, args, "collective")
	local pls = is_template and {base={{"{{{pl}}}", "tri"}}} or
		do_gender_number(data, args, {"pl", "cpl"}, colls, nil, false, "pl")

	parse_state_etc_spec(data, args)

	-- If collective noun is already feminine in form, don't try to
	-- form a feminine singulative
	local collfem = any_feminine(data, colls)

	local sings = do_gender_number(data, args, {"sing"}, colls,
		not already_feminine and "f" or nil, true, "sg")
	local singfem = all_feminine(data, sings)
	local dus = do_gender_number(data, args, {"d"}, sings, "d", singfem, "du")
	local paucs = do_gender_number(data, args, {"pauc"}, sings, "paucp",
		singfem, "pl")

	-- Can manually specify which numbers are to appear, and exactly those
	-- numbers will appear. Otherwise, if any plurals given, plurals appear,
	-- and if singulative given, dual and paucal appear.
	if not parse_number_spec(data, args) then
		data.numbers = {}
		if args[1] ~= "-" then
			table.insert(data.numbers, "coll")
		end
		if #sings["base"] > 0 then
			table.insert(data.numbers, "sing")
		end
		if #dus["base"] > 0 then
			table.insert(data.numbers, "du")
		end
		if #paucs["base"] > 0 then
			table.insert(data.numbers, "pauc")
		end
		if #pls["base"] > 0 then
			table.insert(data.numbers, "pl")
		end
	end

	-- Generate the collective, singulative, dual, paucal and plural forms
	do_declensions_and_overrides(data, args,
		{{colls, "coll"}, {sings, "sing"}, {dus, "du"}, {paucs, "pauc"}, {pls, "pl"}})

	-- Make the table
	return make_noun_table(data)
end

-- The main entry point for singulative noun tables.
function export.show_sing_noun(frame)
	local args, origargs, data = init(frame:getParent().args)
	data.pos = "noun"
	data.allnumbers = {"sing", "coll", "du", "pauc", "pl"}
	data.engnumberscap["pl"] = "Plural of variety"
	data.numgens = function() return data.numbers end
	data.allnumgens = data.allnumbers

	parse_state_etc_spec(data, args)

	local sings, is_template = get_heads(data, args, "singulative")

	-- If all singulative nouns feminine in form, form a masculine collective
	local singfem = all_feminine(data, sings)

	local colls = do_gender_number(data, args, {"coll"}, sings,
		singfem and "m" or nil, false, "sg")
	local dus = do_gender_number(data, args, {"d"}, sings, "d", singfem, "du")
	local paucs = do_gender_number(data, args, {"pauc"}, sings, "paucp",
		singfem, "pl")
	local pls = is_template and {base={{"{{{pl}}}", "tri"}}} or
		do_gender_number(data, args, {"pl", "cpl"}, colls, nil, false, "pl")

	-- Can manually specify which numbers are to appear, and exactly those
	-- numbers will appear. Otherwise, if any plurals given, plurals appear;
	-- if singulative given or derivable, it and dual and paucal will appear.
	if not parse_number_spec(data, args) then
		data.numbers = {}
		if args[1] ~= "-" then
			table.insert(data.numbers, "sing")
		end
		if #colls["base"] > 0 then
			table.insert(data.numbers, "coll")
		end
		if #dus["base"] > 0 then
			table.insert(data.numbers, "du")
		end
		if #paucs["base"] > 0 then
			table.insert(data.numbers, "pauc")
		end
		if #pls["base"] > 0 then
			table.insert(data.numbers, "pl")
		end
	end

	-- Generate the singulative, collective, dual, paucal and plural forms
	do_declensions_and_overrides(data, args,
		{{sings, "sing"}, {colls, "coll"}, {dus, "du"}, {paucs, "pauc"}, {pls, "pl"}})

	-- Make the table
	return make_noun_table(data)
end

-- The implementation of the main entry point for adjective and
-- gendered noun tables.
local function show_gendered(frame, isadj, pos)
	local args, origargs, data = init(frame:getParent().args)
	data.pos = pos
	data.numgens = function()
		local numgens = {}
		for _, gender in ipairs(data.allgenders) do
			for _, number in ipairs(data.numbers) do
				table.insert(numgens, gender .. "_" .. number)
			end
		end
		return numgens
	end
	data.allnumgens = {}
	for _, gender in ipairs(data.allgenders) do
		for _, number in ipairs(data.allnumbers) do
			table.insert(data.allnumgens, gender .. "_" .. number)
		end
	end

	parse_state_etc_spec(data, args)

	local msgs = get_heads(data, args, 'masculine singular')
	-- Always do all of these so cases like يَوْم الاِثْنَيْن work.
	-- See comment in show_noun().
	local fsgs = do_gender_number(data, args, {"f"}, msgs, "f", true, "sg")
	local mdus = do_gender_number(data, args, {"d"}, msgs, "d", false, "du")
	local fdus = do_gender_number(data, args, {"fd"}, fsgs, "d", true, "du")
	local mpls = do_gender_number(data, args, {"pl", "cpl"}, msgs,
		isadj and "p" or nil, false, "pl")
	local fpls = do_gender_number(data, args, {"fpl", "cpl"}, fsgs, "fp",
		true, "pl")

	if isadj then
		parse_number_spec(data, args)
	else
		determine_noun_numbers(data, args, mpls)
	end

	-- Generate the singular, dual and plural forms
	do_declensions_and_overrides(data, args,
		{{msgs, "m_sg"}, {fsgs, "f_sg"}, {mdus, "m_du"}, {fdus, "f_du"},
		 {mpls, "m_pl"}, {fpls, "f_pl"}})

	-- Make the table
	if isadj then
		return make_adj_table(data)
	else
		return make_gendered_noun_table(data)
	end
end

-- The main entry point for gendered noun tables.
function export.show_gendered_noun(frame)
	return show_gendered(frame, false, "noun")
end

-- The main entry point for numeral tables. Same as using show_gendered_noun()
-- with pos=numeral.
function export.show_numeral(frame)
	return show_gendered(frame, false, "numeral")
end

-- The main entry point for adjective tables.
function export.show_adj(frame)
	return show_gendered(frame, true, "adjective")
end

-- Inflection functions

local function do_translit(term)
	return (lang:transliterate(term)) or track("cant-translit") and BOGUS_CHAR
end

local function split_arabic_tr(term)
	if term == "" then
		return "", ""
	elseif not rfind(term, "/") then
		return term, do_translit(term)
	else
		splitvals = rsplit(term, "/")
		if #splitvals ~= 2 then
			error("Must have at most one slash in a combined Arabic/translit expr: '" .. term .. "'")
		end
		return splitvals[1], splitvals[2]
	end
end

local function reorder_shadda(word)
	-- shadda+short-vowel (including tanwīn vowels, i.e. -an -in -un) gets
	-- replaced with short-vowel+shadda during NFC normalisation, which
	-- MediaWiki does for all Unicode strings; however, it makes the
	-- detection process inconvenient, so undo it.
	word = rsub(word, "(" .. DIACRITIC_ANY_BUT_SH .. ")" .. SH, SH .. "%1")
	return word
end

-- Combine PREFIX, AR/TR, and ENDING in that order. PREFIX and ENDING
-- can be of the form ARABIC/TRANSLIT. The Arabic and translit parts are
-- separated out and grouped together, resulting in a string of the
-- form ARABIC/TRANSLIT (TRANSLIT will always be present, computed
-- automatically if not present in the source). The return value is actually a
-- list of ARABIC/TRANSLIT strings because hamza resolution is applied to
-- ARABIC, which may produce multiple outcomes (all of which will have the
-- same TRANSLIT).
local function combine_with_ending(prefix, ar, tr, ending)
	local prefixar, prefixtr = split_arabic_tr(prefix)
	local endingar, endingtr = split_arabic_tr(ending)
	-- When calling hamza_seat(), leave out prefixes, which we expect to be
	-- clitics like وَ. (In case the prefix is a separate word, it won't matter
	-- whether we include it in the text passed to hamza_seat().)
	allar = hamza_seat(ar .. endingar)
	-- Convert ...īān to ...iyān in case of stems ending in -ī or -ū
	-- (e.g. kubrī "bridge").
	if rfind(endingtr, "^[aeiouāēīōū]") then
		if rfind(tr, "ī$") then
			tr = rsub(tr, "ī$", "iy")
		elseif rfind(tr, "ū$") then
			tr = rsub(tr, "ū$", "uw")
		end
	end
	tr = prefixtr .. tr .. endingtr
	allartr = {}
	for _, arval in ipairs(allar) do
		table.insert(allartr, prefixar .. arval .. "/" .. tr)
	end
	return allartr
end

local function basic_combine_stem_ending(stem, ending)
	return stem .. ending
end

local function basic_combine_stem_ending_tr(stem, ending)
	return stem .. ending
end

-- Concatenate `prefixes`, `stems` and `endings` (any of which may be an abbreviate form list, i.e. strings, form
-- objects or lists of strings or form objects) and store into `slot`. If a user-supplied override exists for the slot,
-- nothing will happen unless `allow_overrides` is provided.
local function add3(base, slot, prefixes, stems, endings, allow_overrides)
	if skip_slot(base, slot, allow_overrides) then
		return
	end

	-- Optimization since the prefixes are almost always single strings.
	if type(prefixes) == "string" then
		local function do_combine_stem_ending(stem, ending)
			return prefixes .. stem .. ending
		end
		local function do_combine_stem_ending_tr(stem, ending)
			return transliterate(prefixes) .. stem .. ending
		end
		iut.add_forms(base.forms, slot, stems, endings, do_combine_stem_ending, transliterate,
			do_combine_stem_ending_tr, base.form_footnotes)
	else
		iut.add_multiple_forms(base.forms, slot, {prefixes, stems, endings}, basic_combine_stem_ending, transliterate,
			basic_combine_stem_ending_tr, base.form_footnotes)
	end
end

-- Combine PREFIX, STEM/TR and ENDING in that order and insert into the
-- list of items in DATA[KEY], initializing it if empty and making sure
-- not to insert duplicates. ENDING can be a list of endings, will be
-- distributed over the remaining parts. PREFIX and/or ENDING can be
-- of the form ARABIC/TRANSLIT (the stem is already split into Arabic STEM
-- and Latin TR). Note that what's inserted into DATA[KEY] is actually a
-- list of ARABIC/TRANSLIT strings; if more than one is present in the list,
-- they represent hamza variants, i.e. different ways of writing a hamza
-- sound, such as مُبْتَدَؤُون vs. مُبْتَدَأُون (see init_data()).
local function add_declension(data, key, prefix, stem, tr, ending)
	if data.forms[key] == nil then
		data.forms[key] = {}
	end
	if type(ending) ~= "table" then
		ending = {ending}
	end
	for _, endingval in ipairs(ending) do
		m_table.insertIfNot(data.forms[key],
			combine_with_ending(prefix, stem, tr, endingval))
	end
end

-- Add declensions for all cases and states of the noun or adjective form whose prefix is `slot` (e.g. "" for the
-- base form, "pl_" for the plural of nouns, etc.). The declensions are formed by adding endings to `stem` (a form
-- object, with Arabic, transliteration and optional footnotes). `endings` is a list of 13 endings to add, in the
-- following order:
-- * 1, 2, 3: ind_nom, ind_acc, ind_gen;
-- * 4, 5, 6: def_nom, def_acc, def_gen;
-- * 7, 8, 9: con_nom, con_acc, con_gen;
-- * 10, 11, 12: inf_nom, inf_acc, inf_gen ("informal" endings i.e. without ʔiʕrāb);
-- * 13: lemma (the form used in the lemma, whose specific shape will vary depending on the term's state and case as
--              specified in `base.state` and `base.case`).
-- Each of the elements of `endings` can be either nil (don't add any form corresponding to this state/case
-- combination) or an abbreviated form list (see [[Module:inflection utilities]]; i.e. a string, list of strings,
-- form object, or list of form objects).
local function add_declensions(base, props, stem, endings)
	assert(#endings == 13)
	-- Return a list of combined of ar/tr forms, with the ending tacked on.
	-- There may be more than one form because of alternative hamza seats that
	-- may be supplied, e.g. مُبْتَدَؤُون or مُبْتَدَأُون (mubtadaʔūn "(grammatical) subjects").
	local defstem, deftr
	if stem == "?" or data[mod .. "omitarticle"] then
		defstem = stem
		deftr = tr
	else
		-- apply sun-letter assimilation and hamzat al-wasl elision
		defstem = rsub("الْ" .. stem, "^الْ([سشصتثطدذضزژظنرل])", "ال%1ّ")
		defstem = rsub(defstem, "^الْ([اٱ])([ًٌٍَُِ])", "ال%2%1")
		deftr = rsub("al-" .. tr, "^al%-([sšṣtṯṭdḏḍzžẓnrḷ])", "a%1-%1")
	end
	
	-- For a given MOD spec, is the previous word (base or modifier) a noun?
	-- We assume the base is always a noun in this case, and otherwise
	-- look at the value of modN_idafa.
	local function prev_mod_is_noun(mod)
		if mod == "mod_" then
			return true
		end
		if mod == "mod2_" then
			return data["mod_idafa"]
		end
		modnum = assert_rsub(mod, "^mod([0-9]+)_$", "%1")
		modnum = modnum - 1
		return data["mod" .. modnum .. "_idafa"]
	end

	local numgens = ismod and data[mod .. "numgen"] and data.numgens() or {numgen}
	-- "defcon" means definite adjective modifying construct state noun. We
	-- add a ... before the adjective (and after the construct-state noun) to
	-- indicate that a nominal modifier would go between noun and adjective.
	local stems = {ind = stem, def = defstem, con = stem,
	  defcon = "... " .. defstem}
	local trs = {ind = tr, def = deftr, con = tr, defcon = "... " .. deftr}
	for _, ng in ipairs(numgens) do
		for _, state in ipairs(data.allstates) do
			for _, case in ipairs(data.allcases_with_lemma) do
				-- We are generating the declensions for STATE, but sometimes
				-- we want to use the inflected form of a different state, e.g.
				-- if modN_state= or basestate= is set to some particular state.
				-- If we're dealing with an adjectival modifier, then in
				-- place of "con" we use "defcon" if immediately after a noun
				-- (see comment above), else "def".
				local thestate = ismod and data[mod .. "state"] or
					ismod and not data[mod .. "idafa"] and state == "con" and
				  		(prev_mod_is_noun(mod) and "defcon" or "def") or
					not ismod and data.basestate or
					state
				local is_lemmainf = case == "lemma" or case == "inf"
				-- Don't substitute value of modcase for lemma/informal "cases"
				local thecase = is_lemmainf and case or
					ismod and data[mod .. "case"] or case
				add_declension(data, mod .. case .. "_" .. ng .. "_" .. state,
					data[mod .. "prefix"] or "",
					stems[thestate], trs[thestate],
					endings[data.statecases[thestate][thecase]])
			end
		end
	end
end	

-- Insert into a category and a type variable (e.g. m_sg_type) for the
-- declension type of a particular declension (e.g. masculine singular for
-- adjectives). MOD and NUMGEN are as in call_declension(). CATVALUE is the
-- category and ENGVALUE is the English description of the declension type.
-- In these values, POS is replaced with either "noun" or "adjective",
-- NUMBER is replaced with the English equivalent of the number in NUMGEN
-- (e.g. "singular", "dual" or "plural") while BROKNUM is the same but uses
-- "broken plural" in place of "plural" and "broken paucal" in place of
-- "paucal".
local function insert_cats(base, props, catvalue, annvalue)
	local singpl = base.alternant_multiword_spec.engnumbers[props.number]
	assert(singpl ~= nil)
	local broksingpl = rsub(singpl, "plural", "broken plural")
	broksingpl = rsub(broksingpl, "paucal", "broken paucal")
	if rfind(broksingpl, "broken plural") and (rfind(catvalue, "BROKNUM") or
			rfind(annvalue, "BROKNUM")) then
		table.insert(base.categories, "Arabic " .. data.pos .. "s with broken plural")
	end
	if rfind(catvalue, "irregular") or rfind(annvalue, "irregular") then
		table.insert(base.categories, "Arabic irregular " .. data.pos .. "s")
	end
	catvalue = rsub(catvalue, "POS", data.pos)
	catvalue = rsub(catvalue, "NUMBER", singpl)
	catvalue = rsub(catvalue, "BROKNUM", broksingpl)
	annvalue = rsub(annvalue, "POS", data.pos)
	annvalue = rsub(annvalue, "NUMBER", singpl)
	annvalue = rsub(annvalue, "BROKNUM", broksingpl)
	if mod == "" and catvalue ~= "" then
		m_table.insertIfNot(base.categories, catvalue)
	end
	if annvalue ~= "" then
		local key = mod .. numgen .. "_type"
		if data.forms[key] == nil then
			data.forms[key] = {}
		end
		m_table.insertIfNot(data.forms[key], annvalue)
	end
	if m_table.contains(data.states, "def") and not m_table.contains(data.states, "ind") then
		m_table.insertIfNot(base.categories, "Arabic definite " .. data.pos .. "s")
	end
end

-- Return true if we're handling modifier declensions and the modifier's
-- case is limited to an oblique case (gen or acc; typically genitive,
-- in an ʔidāfa construction). This is used when returning lemma
-- declensions -- the modifier part of the lemma should agree in case
-- with modifier's case if it's restricted in case.
local function mod_oblique(mod, data)
	return mod ~= "" and data[mod .. "case"] and (
		data[mod .. "case"] == "acc" or data[mod .. "case"] == "gen")
end

-- Similar to mod_oblique but specifically when the modifier case is
-- limited to the accusative (which is rare or nonexistent in practice).
local function mod_acc(mod, data)
	return mod ~= "" and data[mod .. "case"] and data[mod .. "case"] == "acc"
end

-- Handle triptote and diptote declensions. `typ` is "triptote", "diptote" or "long construct".
local function triptote_diptote(base, props, stem, typ)
	check_value(typ, {"triptote", "diptote", "long construct"}, "triptote_diptote() type")
	local ar, tr = stem.form, stem.translit
	-- Remove any case ending
	if rfind(ar, "[" .. UN .. U .. "]$") then
		error(("Internal error: Stem \"%s\" for slot prefix \"%s\" should not have ʔiʕrāb on it at this point"):format(
			ar, props.slot))
	end

	-- special-case for صلوة pronounced ṣalāh; check translit
	local is_aah = rfind(ar, TAM .. "$") and rfind(tr, "āh$")

	if rfind(ar, TAM .. "$") then
		if rfind(tr, "h$") then
			tr = rsub(tr, "h$", "t")
		elseif not rfind(tr, "t$") then
			tr = tr .. "t"
		end
	end

	stem = copy_stem_and_replace(stem, ar, tr)

	local is_dip = typ == "diptote"
	local lc = typ == "long construct"
	add_declensions(base, props, stem,
		{is_dip and U or UN,
		 is_dip and A or AN .. ((rfind(ar, "[" .. HAMZA_ON_ALIF .. TAM .. "]$")
			or rfind(ar, ALIF .. HAMZA .. "$")
			) and "" or ALIF),
		 is_dip and A or IN,
		 U, A, I,
		 lc and UU or U,
		 lc and AA or A,
		 lc and II or I,
		 -- omit informal declensions
		 -- omit lemma declension
		})

	-- add category and informal and lemma declensions
	local singpl_tote = "BROKNUM " .. typ
	local cat_prefix = "PLPOS with " .. typ .. " BROKNUM"
	-- Since we're checking translit for -āh we probably don't need to check Arabic too.
	if is_aah or rfind(ar, ALIF .. TAM .. "$") then
		add_declensions(base, props, stem,
			{nil, nil, nil,
			 nil, nil, nil,
			 nil, nil, nil,
			 "", "", "", -- informal forms use -āt
			-- omit lemma declension because we do it just below
			})
		if base.state ~= "con" then
			-- This is safe because we already copied the stem.
			stem.translit = stem.translit:gsub("t$", "h")
		end
		add_declensions(base, props, stem, {
			nil, nil, nil,
			nil, nil, nil,
			nil, nil, nil,
			nil, nil, nil,
			"" -- lemma uses -āh not in construct state
		})
		insert_cats(base, props, cat_prefix .. " in -āh", singpl_tote .. " in " .. make_link(HYPHEN .. AAH))
	elseif rfind(stem, TAM .. "$") then
		add_declensions(base, props, stem,
			{nil, nil, nil,
			 nil, nil, nil,
			 nil, nil, nil,
			 nil, nil, "",
			 base.state == "con" and "" or nil -- lemma uses -a not in construct state, otherwise -at
			})
		-- This is safe because we already copied the stem.
		stem.translit = stem.translit:gsub("t$", "")
		add_declensions(base, props, stem,
			{nil, nil, nil,
			 nil, nil, nil,
			 nil, nil, nil,
			 "", "", nil,
			 base.state ~= "con" and "" or nil -- lemma uses -a not in construct state, otherwise -at
			})
		insert_cats(base, props, cat_prefix .. " in -a", singpl_tote .. " in " .. make_link(HYPHEN .. AH))
	elseif lc then
		add_declensions(base, props, stem,
			{nil, nil, nil,
			 nil, nil, nil,
			 nil, nil, nil,
			 "", "", UU,
			 base.state == "con" and UU or "",
			})
		insert_cats(base, props, cat_prefix, singpl_tote)
	else
		-- Also special-case the nisba ending, which has an informal pronunciation.
		if rfind(stem, IY .. SH .. "$") then
			add_declensions(base, props, stem,
				{nil, nil, nil,
				 nil, nil, nil,
				 nil, nil, nil,
				 nil, nil, nil,
				 "",
				})
			-- This is safe because we already copied the stem.
			stem.form = stem.form:gsub(SH .. "$", "")
			stem.translit = stem.translit:gsub("iyy$", "ī")
			-- add informal and lemma declensions separately
			add_declensions(base, props, stem,
				{nil, nil, nil,
				 nil, nil, nil,
				 nil, nil, nil,
				 "", "", "",
				})
		else
			add_declensions(base, props, stem,
				{nil, nil, nil,
				 nil, nil, nil,
				 nil, nil, nil,
				 "", "", "",
				 "",
				})
		end
		insert_cats(base, props, "PLPOS with basic " .. typ .. " BROKNUM", "basic " .. singpl_tote)
	end
end

-- Regular triptote
declensions["tri"] = function(base, props, stem)
	triptote_diptote(base, props, stem, "triptote")
end

-- Regular diptote
declensions["di"] = function(base, props, stem)
	triptote_diptote(base, props, stem, "diptote")
end

local function invariable(base, props, stem)
	add_declensions(base, props, stem,
		{"", "", "",
		 "", "", "",
		 "", "", "",
		 "", "", "",
		 "",
		})
	
	insert_cats(base, props, "PLPOS with invariable BROKNUM", "BROKNUM invariable")
end

-- Invariable in -ā (non-loanword type)
declensions["inv"] = function(base, props, stem)
	invariable(base, props, stem)
end

-- Invariable in -ā (loanword type, behaving in the dual as if ending in -a, I think!)
declensions["lwinv"] = function(base, props, stem)
	invariable(base, props, stem)
end

-- Elative and color/defect adjective: usually same as diptote,
-- might be invariable
local function elative_color_defect(base, props, stem)
	if rfind(stem.form, "[" .. ALIF .. AMAQ .. "]$") then
		invariable(base, props, stem)
	else
		triptote_diptote(base, props, stem, "diptote")
	end
end

-- Elative: usually same as diptote, might be invariable
declensions["el"] = function(base, props, stem)
	elative_color_defect(base, props, stem)
end

-- Color/defect adjective: Same as elative
declensions["cd"] = function(base, props, stem)
	elative_color_defect(base, props, stem)
end

-- Triptote with lengthened ending in the construct state
declensions["lc"] = function(base, props, stem)
	triptote_diptote(base, props, stem, "long construct")
end

local function in_final_weak(base, props, stem, tri)
	stem = strip_ending(stem, IN, props.slot, "internal")

	local acc_ind_ending = tri and IY .. AN .. ALIF or IY .. A
	add_declensions(base, props, stem,
		{IN, acc_ind_ending, IN,
		 II, IY .. A, II,
		 II, IY .. A, II,
		 II, II, II,
		 -- FIXME: It's not clear that the indefinite accusative lemma form should end in -iya(n); but this situation
		 -- rarely if ever occurs so it may not matter.
		 base.state == "ind" and (base.case == "acc" and acc_ind_ending or IN) or "II",
		})
	local tote = tri and "triptote" or "diptote"
	insert_cats(base, props, "PLPOS with " .. tote .. " BROKNUM in -in",
		"BROKNUM " .. tote .. " in " .. make_link(HYPHEN .. IN))
end

-- Final-weak in -in, force "triptote" variant
declensions["triin"] = function(base, props, stem)
	in_final_weak(base, props, stem, "triptote")
end

-- Final-weak in -in, force "diptote" variant
declensions["diin"] = function(base, props, stem)
	in_final_weak(base, props, stem, false)
end

-- Final-weak in -an (comes in two variants, depending on spelling with tall alif or alif maqṣūra)
declensions["an"] = function(base, props, stem)
	local tall_alif
	local an_alif = AN .. ALIF
	local an_amaq = AN .. AMAQ
	if rfind(stem.form, an_alif .. "$") then
		tall_alif = true
		stem = strip_ending(stem, {an_alif, "an"}, props.slot, "internal")
	elseif rfind(stem.form, an_amaq .. "$") then
		tall_alif = false
		stem = strip_ending(stem, {an_amaq, "an"}, props.slot, "internal")
	else
		bad_ar_ending(stem.form, {an_amaq, an_alif}, props.slot, "internal")
	end

	if tall_alif then
		add_declensions(base, props, stem,
			{AN .. ALIF, AN .. ALIF, AN .. ALIF,
			 AA, AA, AA,
			 AA, AA, AA,
			 AA, AA, AA,
			 base.state == "ind" and AN .. ALIF or AA
			})
	else
		add_declensions(base, props, stem,
			{AN .. AMAQ, AN .. AMAQ, AN .. AMAQ,
			 AAMAQ, AAMAQ, AAMAQ,
			 AAMAQ, AAMAQ, AAMAQ,
			 AAMAQ, AAMAQ, AAMAQ,
			 base.state == "ind" and AN .. AMAQ or AAMAQ
			})
	end
	-- FIXME: Should we distinguish between tall alif and alif maqṣūra?
	insert_cats(base, props, "PLPOS with BROKNUM in -an",
		"BROKNUM in " .. make_link(HYPHEN .. AN .. (tall_alif and ALIF or AMAQ)))
end


-- Dual
declensions["d"] = function(base, props, stem)
	check_num(base, "du")
	stem = strip_ending(stem, AAN, props.slot, "internal")

	add_declensions(base, props, stem,
		{AANI, AYNI, AYNI,
		 AANI, AYNI, AYNI,
		 AA, AYSK, AYSK,
		 AYN, AYN, AYSK,
		 base.case == "nom" and (base.state == "con" and AA or AAN) or (base.state == "con" and AYSK or AYN),
		})
	insert_cats(base, props, nil, "dual in " .. make_link(HYPHEN .. AANI))
end

-- Sound masculine plural
declensions["smp"] = function(base, props, stem)
	check_num(base, {"pl", "pauc"})
	stem = strip_ending(stem, UUN, props.slot, "internal")
	add_declensions(base, props, stem,
		{UUNA, IINA, IINA,
		 UUNA, IINA, IINA,
		 UU,   II,   II,
		 IIN,  IIN,  II,
		 base.case == "nom" and (base.state == "con" and UU or UUN) or (base.state == "con" and II or IIN),
		})
	-- use NUMBER because conceivably this might be used with the paucal instead of plural
	insert_cats(base, props, "PLPOS with sound masculine NUMBER", "sound masculine NUMBER")
end

-- Sound feminine plural
declensions["sfp"] = function(base, props, stem)
	check_num(base, {"pl", "pauc"})
	check_ending(stem, AAT, props.slot, "internal")
	add_declensions(base, props, stem,
		{UN, IN, IN,
		 U,  I,  I,
		 U,  I,  I,
		 "", "", "",
		 "",
		})
	-- use NUMBER because this might be used with the paucal instead of plural
	insert_cats(base, props, "PLPOS with sound feminine NUMBER", "sound feminine NUMBER")
end

-- Plural of final-weak in -an
declensions["awnp"] = function(base, props, stem)
	check_num(base, {"pl", "pauc"})
	stem = strip_ending(stem, AWN, props.slot, "internal")
	add_declensions(base, props, stem,
		{AWNA, AYNA, AYNA,
		 AWNA, AYNA, AYNA,
		 AWSK, AYSK, AYSK,
		 AYN, AYN, AYSK,
		 base.case == "nom" and (base.state == "con" and AWSK or AWN) or (base.state == "con" and AYSK or AYN),
		})
	-- use NUMBER because conceivably this might be used with the paucal instead of plural
	insert_cats(base, props, "PLPOS with sound NUMBER in -awna", "sound NUMBER in " .. make_link(HYPHEN .. AWNA))
end

-- Unknown
declensions["?"] = function(base, props, stem)
	stem = copy_stem_and_replace(stem, "?", "?")
	add_declensions(base, props, stem,
		{"", "", "",
		 "", "", "",
		 "", "", "",
		 "", "", "",
		 "",
		})
	
	insert_cats(base, props, "PLPOS with unknown NUMBER", "NUMBER unknown")
end

--[==[
Detect declension of noun or adjective lemma or non-lemma forms. On input, the following should be specified in `data`:
* `form`: The form value itself (a string). Required. It may or may not have ʔiʕrāb except for final-weak indefinite
          forms ending in -in -or -an, where it is required. When the ʔiʕrāb is not required, it should preferably be
		  omitted, but in some cases will be taken into account (e.g. to distinguish triptotes from diptotes).
* `case`: The case ("nom", "acc" or "gen"). Required.
* `iscon`: Whether this is in the construct state (true or false, never {nil}). Required. If `iscons` is {false}, the
           code will determine whether the state is definite or indefinite, unless `nodef` is set.
* `nodef`: If true, the user specified `-def` to force a term with initial ال to not be interpreted as definite.
           Normally this shouldn't be necessary; initial ال should appear unpointed while all following consonants
		   should have diacritics on them.
* `num`: The number ("sg", "du", "pl", "coll" = collective, "sgl" = singulative, "pauc" = paucal). Required.
* `decl`: The declension, if specified by the user. This can be a "partially specified" declension such as "in" (which
          will be converted to a fully specified declension "triin" or "diin").
* `gender`: The gender, if specified by the user ("m" or "f"). If the user specified that the term can be either
            masculine or feminine, leave this as {nil}.
* `pos`: The part of speech, if known.

The return value is a structure with the following fields:
* `normalized_form`: The normalized form (indefinite nominative, no ʔiʕrāb except for final-weak forms in -in or -an).
* `inferred_case`: Same as `case` on input.
* `inferred_state`: The inferred state ("ind", "def" or "con").
* `inferred_num`: Same as `num` on input.
* `inferred_decl`: The inferred declension. Will always be a fully specified declension.
* `inferred_gender`: The inferred gender ("m" or "f", based on the passed-in gender or inferred from the ending and/or
                     declension). In some cases, this will be nil (the gender was not passed in and could not be
					 inferred, e.g. terms ending in -āʔ). The caller may throw an error in this circumstance.
* `inferred_pos`: Same as `pos` on input.
                     
The form should be in the indefinite nominative
unless there is a state or case restriction. We allow triptotes, diptotes and sound duals and plurals to either come
with ʔiʕrāb or not (preferably not). We detect some cases where vowels are missing, when it seems fairly unambiguous
to do so. On input, `data` is an object containing the form and known information about the form (e.g. a specified
declension, which might need to be refined into something more specific; a gender or number; etc.).
--
--
-- ISFEM is true if we are dealing with a feminine stem (not
-- currently used and needs to be rethought). NUM is "sg", "du", or "pl",
-- depending on the number of the stem.
--
-- POS is the part of speech, generally "noun" or "adjective". Used to
-- distinguish nouns and adjectives of the فَعْلَان type. There are nouns of
-- this type and they generally are triptotes, e.g. قَطْرَان "tar"
-- and شَيْطَان "devil". An additional complication is that the user can set
-- the POS to something else, like "numeral". We don't use this POS for
-- modifiers, where we determine whether they are noun-like or adjective-like
-- according to whether mod_idafa= is true.
--
-- Some unexpectedly diptote nouns/adjectives:
--
-- jiʕrān in ʔabū jiʕrān "dung beetle"
-- distributive numbers: ṯunāʔ "two at a time", ṯulāṯ/maṯlaṯ "three at a time",
--   rubāʕ "four at a time" (not a regular diptote pattern, cf. triptote
--   junāḥ "misdemeanor, sin", nujār "origin, root", nuḥām "flamingo")
-- jahannam (f.) "hell"
-- many names: jilliq/jillaq "Damascus", judda/jidda "Jedda", jibrīl (and
--   variants) "Gabriel", makka "Mecca", etc.
-- jibriyāʔ "pride"
-- kibriyāʔ "glory, pride"
-- babbaḡāʔ "parrot"
-- ʕayāyāʔ "incapable, tired"
-- suwaidāʔ "black bile, melancholy"
-- Note also: ʔajhar "day-blind" (color-defect) and ʔajhar "louder" (elative)
]==]
function export.detect_declension(data)
	local form, decl, num, gender, case, state, pos =
		data.form, data.decl, data.num, data.gender, data.case, data.state, data.pos
	local function dotrack(word)
		track(word)
		track(word .. "/" .. pos)
		return true
	end
	local origform = form
	-- Not strictly necessary because the caller (form_and_type) already reorders, but won't hurt, and may be necessary
	-- if this function is called from an external caller.
	form = reorder_shadda(form)
	-- So that we don't get tripped up by alif madda, we replace alif madda with the sequence hamza placeholder + fatḥa
	-- + alif before the regexps below. We undo this later; this is necessary because we may replace a form with a
	-- different case form, which may produce an alif madda that didn't previously exist (e.g. when the dual oblique
	-- -ayn(i) is replaced with nominative -ān).
	form = rsub(form, AMAD, HAMZA_PH .. AA)
	local retform, retdecl, retcase, retnum, retstate, retgender

	if not data.nodef then
		local bareform = form:match("^ال(.*)$")
		if bareform then
			if case and case ~= "def" then
				error(("Stem '%s' is definite but case incompatibly specified as '%s'; if form is not actually definite, use indicator '-def'"
				):format(origform, case))
			end
			case = "def"
			form = bareform
		end
	end

	-- Normalize a form that may be in any case and state to the nominative indefinite form (minus ʔiʕrāb except after
	-- final-weak forms). Note that we know for sure by this point the case and state of the form. `data` contains the
	-- following:
	-- (1) Several fields specifying Lua patterns matching particular endings. Each field is a Lua pattern or list of
	--     patterns (which are tried in turn) to match the appropriate ending. The remainder (which is matched using
	--     `(.-)`) becomes the form.
	-- * `nom_ind`: Pattern or patterns to match the nominative indefinite ending.
	-- * `nom_def`: Pattern or patterns to match the nominative definite ending.
	-- * `nom_con`: Pattern or patterns to match the nominative construct ending.
	-- * `nom_ind_def`: Pattern or patterns to match both the nominative indefinite and definite endings. Equivalent to
	--                  setting `nom_ind` and `nom_def` to the same value.
	-- * `nom_def_con`: Pattern or patterns to match both the nominative definite and construct endings. Equivalent to
	--                  setting `nom_def` and `nom_con` to the same value.
	-- * `acc_ind`: Pattern or patterns to match the accusative indefinite ending.
	-- * `acc_def`: Pattern or patterns to match the accusative definite ending.
	-- * `acc_con`: Pattern or patterns to match the accusative construct ending.
	-- * `acc_ind_def`: Pattern or patterns to match both the accusative indefinite and definite endings. Equivalent to
	--                  setting `acc_ind` and `acc_def` to the same value.
	-- * `acc_def_con`: Pattern or patterns to match both the accusative definite and construct endings. Equivalent to
	--                  setting `acc_def` and `acc_con` to the same value.
	-- * `gen_ind`: Pattern or patterns to match the genitive indefinite ending.
	-- * `gen_def`: Pattern or patterns to match the genitive definite ending.
	-- * `gen_con`: Pattern or patterns to match the genitive construct ending.
	-- * `gen_ind_def`: Pattern or patterns to match both the genitive indefinite and definite endings. Equivalent to
	--                  setting `gen_ind` and `gen_def` to the same value.
	-- * `gen_def_con`: Pattern or patterns to match both the genitive definite and construct endings. Equivalent to
	--                  setting `gen_def` and `gen_con` to the same value.
	-- * `obl_ind`: Pattern or patterns to match the oblique (accusative and genitive) indefinite ending.
	-- * `obl_def`: Pattern or patterns to match the oblique (accusative and genitive) definite ending.
	-- * `obl_con`: Pattern or patterns to match the oblique (accusative and genitive) construct ending.
	-- * `obl_ind_def`: Pattern or patterns to match both the oblique (accusative and genitive) indefinite and definite
	--                  endings. Equivalent to setting `obl_ind` and `obl_def` to the same value.
	-- * `obl_def_con`: Pattern or patterns to match both the oblique (accusative and genitive) definite and construct
	--                  endings. Equivalent to setting `obl_def` and `obl_con` to the same value.
	-- (2) Other fields:
	-- * `normalized_ending`: Ending to add to the stem extracted from the above patterns to get the normalized
	--                        nominative indefinite form. Required.
	-- * `reject_if`: If specified, a function that should return true if this match should be rejected. It is passed
	--                three arguments: (1) the normalized form that would be returned, (2) the determined case, (3) the
	--                determined state. It can be used for example to avoid treating plurals like ʕuyūn "eyes" and
	--                qurūn "horns" as sound masculine plurals if the declension wasn't explicitly specified as sound.
	local function normalize_to_nom_ind(data)
		local this_retform, this_retcase, this_retstate
		local try_cases, try_states
		if case == "nom" then
			try_cases = {"nom"}
		elseif case == "acc" or case == "gen" then
			try_cases = {case, "obl"}
		else
			error(("Internal error: Unrecognized case '%s'"):format(case))
		end
		if state == "ind" then
			try_states = {"ind", "ind_def"}
		elseif state == "def" then
			try_states = {"def", "ind_def", "def_con"}
		elseif state == "con" then
			try_states = {"con", "def_con"}
		else
			error(("Internal error: Unrecognized state '%s'"):format(state))
		end

		for _, try_case in ipairs(try_cases) do
			for _, try_state in ipairs(try_states) do
				local field = ("%s_%s"):format(try_case, try_state)
				local patterns = data[field]
				if patterns then
					if type(patterns) == "string" then
						patterns = {patterns}
					end
					for _, pattern in ipairs(patterns) do




		while true do
			this_retform = rmatch(form, "^(.-)" .. data.nom_ind .. "$")
			if this_retform then
				this_retcase = "nom"
				this_retstate = {"ind", "def"}
				break
			end
			if data
			this_retform = rmatch(form, "^(.-)" .. data.obl_ind .. "$")
			if this_retform then
				this_retcase = {"acc", "gen"}
				this_retstate = {"ind", "def"}
				break
			end
			this_retform = rmatch(form, "^(.-)" .. data.nom_con .. "$")
			if this_retform then
				this_retcase = "nom"
				this_retstate = "con"
				break
			end
			this_retform = rmatch(form, "^(.-)" .. data.obl_con .. "$")
			if this_retform then
				this_retcase = {"acc", "gen"}
				this_retstate = "con"
				break
			end
			return false
		end

		this_retform = this_retform .. data.normalized_ending
		if data.reject_if and data.reject_if(this_retform, this_retcase, this_retstate) then
			return false
		end
		retform = this_retform
		retcase = this_retcase
		retstate = this_retstate
		return true
	end

	while true do
		if num == "du" then
			if normalize_nom_obl {
				nom_ind = AOPTA .. NI .. "?",
				obl_ind = AY .. SKOPT .. NI .. "?",
				nom_con = AOPTA,
				obl_con = AY .. SKOPT,
				normalized_ending = AAN,
			} then
				retdecl = "d"
				break
			else
				error("Malformed form for dual, should end in -ān(i), -ayn(i), -ā or -ay: '" .. origform .. "'")
			end
		end
		if num == "pl" then
			if not decl or decl == "awnp" then
				if normalize_to_nom_ind {
					nom_ind_def = AW .. SKOPT .. N .. AOPT,
					obl_ind_def = AY .. SKOPT .. N .. AOPT,
					nom_con = AW .. SKOPT,
					obl_con = AY .. SKOPT,
					normalized_ending = AWN,
				} then
					retdecl = "awnp"
					retgender = "m"
					break
				elseif decl == "awnp" then
					error("Malformed form for -awn plural, should end in -awn(a), -ayn(a), -aw or -ay: '" ..
						origform .. "'")
				end
			end
			if not decl or decl == "sp" or decl == "sfp" then
				local at = AOPTA .. T
				if normalize_to_nom_ind {
					nom_ind = at .. UNOPT,
					obl_ind = at .. INOPT,
					nom_def_con = at .. UOPT,
					obl_def_con = at .. IOPT,
					normalized_ending = AAT,
					reject_if = function(form)
						-- Avoid getting tripped up by plurals like ʔawqāt "times", ʔaḥwāt "fishes", ʔabyāt "verses",
						-- ʔazyāt "oils", ʔaṣwāt "voices", ʔamwāt "dead (pl.)".
						return not decl and rfind(form, "^" .. HAMZA_ON_ALIF .. A .. C .. SK .. C .. AAT .. "$")
					end,
				} then
					retdecl = "sfp"
					retgender = "f"
					break
				elseif decl == "sfp" then
					error("Malformed form for strong feminine plural, should end in -āt(u/i)(n): '" .. origform .. "'")
				end
			end
			if not decl or decl == "sp" or decl == "smp" then
				if normalize_to_nom_ind {
					nom_ind_def = UUN .. AOPT,
					obl_ind_def = IIN .. AOPT,
					nom_con = UU,
					obl_con = II,
					normalized_ending = UUN,
					reject_if = function(form)
						-- Avoid getting tripped up by plurals like ʕuyūn "eyes", qurūn "horns". Note, we check for U
						-- between first two consonants so we correctly ignore cases like sinūn "hours" (from sana),
						-- riʔūn "lungs" (from riʔa) and banūn "sons" (from ibn).
						return not decl and rfind(form, "^" .. C .. U .. C .. UUN .. AOPT .. "$")
					end,
				} then
					retdecl = "sfp"
					retgender = "f"
					break
				elseif decl == "sfp" then
					error("Malformed form for strong feminine plural, should end in -āt(u/i)(n): '" .. origform .. "'")
				end
			end
		end
		if rfind(form, IN .. "$") then -- -in words
			if num == "pl" and rfind(form, "^" .. C .. AOPT .. C .. AOPTA .. C .. IN .. "$") then -- layālin
				return "diin"
			else -- other -in words
				return "triin"
			end
	end

			return detect_in_type(form, num == "pl")
		elseif rfind(form, AN .. "[" .. ALIF .. AMAQ .. "]$") then
			return "an"
		elseif rfind(form, AN .. "$") then
			error("Malformed form, fatḥatan should be over second-to-last letter: " .. origform)
		elseif num == "pl" and rfind(form, ALIF .. T .. UNOPT .. "$") and
			-- Avoid getting tripped up by plurals like ʔawqāt "times",
			-- ʔaḥwāt "fishes", ʔabyāt "verses", ʔazyāt "oils", ʔaṣwāt "voices",
			-- ʔamwāt "dead (pl.)".
			not rfind(form, HAMZA_ON_ALIF .. A .. C .. SK .. C .. AAT .. UNOPT .. "$") then
			return "sfp"
		elseif num == "pl" and rfind(form, W .. N .. AOPT .. "$") and
			-- Avoid getting tripped up by plurals like ʕuyūn "eyes",
			-- qurūn "horns" (note we check for U between first two consonants
			-- so we correctly ignore cases like sinūn "hours" (from sana),
			-- riʔūn "lungs" (from riʔa) and banūn "sons" (from ibn).
			not rfind(form, "^" .. C .. U .. C .. UUN .. AOPT .. "$") then
			return "smp"
		elseif rfind(form, UN .. "$") then -- explicitly specified triptotes (we catch sound feminine plurals above)
			return "tri"
		elseif rfind(form, U .. "$") then -- explicitly specified diptotes
			return "di"
		elseif -- num == "pl" and
			( -- various diptote plural patterns; these are diptote even in the singular (e.g. yanāyir "January", falāfil "falafel", tuʔabāʔ "yawn, fatigue"
			  -- currently we sometimes end up with such plural patterns in the "singular" in a singular
			  -- ʔidāfa construction with plural modifier. (FIXME: These should be fixed to the correct number.)
			rfind(form, "^" .. C .. AOPT .. C .. AOPTA .. C .. IOPT .. Y .. "?" .. C .. "$") and dotrack("fawaakih") or -- fawākih, daqāʔiq, makātib, mafātīḥ
			rfind(form, "^" .. C .. AOPT .. C .. AOPTA .. C .. SH .. "$")
				and not rfind(form, "^" .. T) and dotrack("mawaadd") or -- mawādd, maqāmm, ḍawāll; exclude t- so we don't catch form-VI verbal nouns like taḍādd (HACK!!!)
			rfind(form, "^" .. C .. U .. C .. AOPT .. C .. AOPTA .. HAMZA .. "$") and dotrack("wuzaraa") or -- wuzarāʔ "ministers", juhalāʔ "ignorant (pl.)"
			rfind(form, ELCD_START .. SKOPT .. C .. IOPT .. C .. AOPTA .. HAMZA .. "$") and dotrack("asdiqaa") or -- ʔaṣdiqāʔ
			rfind(form, ELCD_START .. IOPT .. C .. SH .. AOPTA .. HAMZA .. "$") and dotrack("aqillaa") -- ʔaqillāʔ, ʔajillāʔ "important (pl.)", ʔaḥibbāʔ "lovers"
			) then
			return "di"
		elseif num == "sg" and ( -- diptote singular patterns (nouns/adjectives)
			rfind(form, "^" .. C .. A .. C .. SK .. C .. AOPTA .. HAMZA .. "$") and dotrack("qamraa") or -- qamrāʔ "moon-white, moonlight"; baydāʔ "desert"; ṣaḥrāʔ "desert-like, desert"; tayhāʔ "trackless, desolate region"; not pl. to avoid catching e.g. ʔabnāʔ "sons", ʔaḥmāʔ "fathers-in-law", ʔamlāʔ "steppes, deserts" (pl. of malan), ʔanbāʔ "reports" (pl. of nabaʔ)
			rfind(form, ELCD_START .. SK .. C .. A .. C .. "$") and dotrack("abyad") or -- ʔabyaḍ "white", ʔakbar "greater"; FIXME nouns like ʔaʕzab "bachelor", ʔaḥmad "Ahmed" but not ʔarnab "rabbit", ʔanjar "anchor", ʔabjad "abjad", ʔarbaʕ "four", ʔandar "threshing floor" (cf. diptote ʔandar "rarer")
			rfind(form, ELCD_START .. A .. C .. SH .. "$") and dotrack("alaff") or -- ʔalaff "plump", ʔaḥabb "more desirable"
			-- do the following on the origform so we can check specifically for alif madda
			rfind(origform, "^" .. AMAD .. C .. A .. C .. "$") and dotrack("aalam") -- ʔālam "more painful", ʔāḵar "other"
			) then
			return "di"
		elseif num == "sg" and pos == "adjective" and ( -- diptote singular patterns (adjectives)
			rfind(form, "^" .. C .. A .. C .. SK .. C .. AOPTA .. N .. "$") and dotrack("kaslaan") or -- kaslān "lazy", ʕaṭšān "thirsty", jawʕān "hungry", ḡaḍbān "angry", tayhān "wandering, perplexed"; but not nouns like qaṭrān "tar", šayṭān "devil", mawtān "plague", maydān "square"
			-- rfind(form, "^" .. C .. A .. C .. SH .. AOPTA .. N .. "$") and dotrack("laffaa") -- excluded because of too many false positives e.g. ḵawwān "disloyal", not to mention nouns like jannān "gardener"; only diptote example I can find is ʕayyān "incapable, weary" (diptote per Lane but not Wehr)
			rfind(form, "^" .. C .. A .. C .. SH .. AOPTA .. HAMZA .. "$") and dotrack("laffaa") -- laffāʔ "plump (fem.)"; but not nouns like jarrāʔ "runner", ḥaddāʔ "camel driver", lawwāʔ "wryneck"
			) then
			return "di"
		elseif rfind(form, AMAQ .. "$") then -- kaslā, ḏikrā (spelled with alif maqṣūra)
			return "inv"
		elseif rfind(form, "[" .. ALIF .. SK .. "]" .. Y .. AOPTA .. "$") then -- dunyā, hadāyā (spelled with tall alif after yāʔ)
			return "inv"
		elseif rfind(form, ALIF .. "$") then -- kāmērā, lībiyā (spelled with tall alif; we catch dunyā and hadāyā above)
			return "lwinv"
		elseif rfind(form, II .. "$") then -- cases like كُوبْرِي kubrī "bridge" and صَوَانِي ṣawānī pl. of ṣīniyya; modern words that would probably end with -in
			dotrack("ii")
			return "inv"
		elseif rfind(form, UU .. "$") then -- FIXME: Does this occur? Check the tracking
			dotrack("uu")
			return "inv"
		else
			return "tri"
		end
end

-- Replace hamza (of any sort) at the end of a word, possibly followed by
-- a nominative case ending or -in or -an, with HAMZA_PH, and replace alif
-- madda at the end of a word with HAMZA_PH plus fatḥa + alif. To undo these
-- changes, use hamza_seat().
local function canon_hamza(word)
	word = rsub(word, AMAD .. "$", HAMZA_PH .. AA)
	word = rsub(word, HAMZA_ANY .. "([" .. UN .. U .. IN .. "]?)$", HAMZA_PH .. "%1")
	word = rsub(word, HAMZA_ANY .. "(" .. AN .. "[" .. ALIF .. AMAQ .. "])$", HAMZA_PH .. "%1")
	return word
end

-- Supply the appropriate hamza seat(s) for a placeholder hamza.
local function hamza_seat(word)
	if rfind(word, HAMZA_PH) then -- optimization to avoid many regexp substs
		return ar_utilities.process_hamza(word)
	end
	return {word}
end

--[[
-- Supply the appropriate hamza seat for a placeholder hamza in a combined
-- Arabic/translation expression.
local function split_and_hamza_seat(word)
	if rfind(word, HAMZA_PH) then -- optimization to avoid many regexp substs
		local ar, tr = split_arabic_tr(word)
		-- FIXME: Do something with all values returned
		ar = ar_utilities.process_hamza(ar)[1]
		return ar .. "/" .. tr
	end
	return word
end
--]]

-- Return stem and type of an argument given the singular stem and whether
-- this is a plural argument. WORD may be of the form ARABIC, ARABIC/TR,
-- ARABIC:TYPE, ARABIC/TR:TYPE, or TYPE, for Arabic stem ARABIC with
-- transliteration TR and of type (i.e. declension) TYPE. If the type
-- is omitted, it is auto-detected using detect_type(). If the transliteration
-- is omitted, it is auto-transliterated from the Arabic. If only the type
-- is present, it is a sound plural type ("sf", "sm" or "awn"),
-- in which case the stem and translit are generated from the singular by
-- regular rules. SG may be of the form ARABIC/TR or ARABIC. ISFEM is true
-- if WORD is a feminine stem. NUM is either "sg", "du" or "pl" according to
-- the number of the stem. The return value will be in the ARABIC/TR format.
--
-- POS is the part of speech, generally "noun" or "adjective". Used to
-- distinguish nouns and adjectives of the فَعْلَان type. There are nouns of
-- this type and they generally are triptotes, e.g. قَطْرَان "tar"
-- and شَيْطَان "devil". An additional complication is that the user can set
-- the POS to something else, like "numeral". We don't use this POS for
-- modifiers, where we determine whether they are noun-like or adjective-like
-- according to whether mod_idafa= is true.
function export.stem_and_type(word, sg, sgtype, isfem, num, pos)
	local rettype = nil
	if rfind(word, ":") then
		local split = rsplit(word, ":")
		if #split > 2 then
			error("More than one colon found in argument: '" .. word .. "'")
		end
		word, rettype = split[1], split[2]
	end

	local ar, tr = split_arabic_tr(word)
	-- Need to reorder shaddas here so that shadda at the end of a stem
	-- followed by ʔiʕrāb or a plural ending or whatever can get processed
	-- correctly. This processing happens in various places so make sure
	-- we return the reordered Arabic in all circumstances.
	ar = reorder_shadda(ar)
	local artr = ar .. "/" .. tr

	-- Now return split-out ARABIC/TR and TYPE, with shaddas reordered in
	-- the Arabic.
	if rettype then
		return artr, rettype
	end

	-- Likewise, do shadda reordering for the singular.
	local sgar, sgtr = split_arabic_tr(sg)
	sgar = reorder_shadda(sgar)

	-- Apply a substitution to the singular Arabic and translit. If a
	-- substitution could be made, return the combined ARABIC/TR with
	-- substitutions made; else, return nil. The Arabic has ARFROM
	-- replaced with ARTO, while the translit has TRFROM replaced with
	-- TRTO, and if that doesn't match, replace TRFROM2 with TRTO2.
	local function sub(arfrom, arto, trfrom, trto, trfrom2, trto2, trfrom3, trto3)
		if rfind(sgar, arfrom) then
			local arret = rsub(sgar, arfrom, arto)
			local trret = sgtr
			if rfind(sgtr, trfrom) then
				trret = rsub(sgtr, trfrom, trto)
			elseif trfrom2 and rfind(sgtr, trfrom2) then
				trret = rsub(sgtr, trfrom2, trto2)
			elseif trfrom3 and rfind(sgtr, trfrom3) then
				trret = rsub(sgtr, trfrom3, trto3)
			elseif not rfind(sgtr, BOGUS_CHAR) then
				error("Transliteration '" .. sgtr .."' does not have same ending as Arabic '" .. sgar .. "'")
			end
			return arret .. "/" .. trret
		else
			return nil
		end
	end

	if (num ~= "sg" or not isfem) and (word == "elf" or word == "cdf" or word == "intf" or word == "rf" or word == "f") then
		error("Inference of form for declension type '" .. word .. "' only allowed in singular feminine")
	end
	
	if num ~= "du" and word == "d" then
		error("Inference of form for declension type '" .. word .. "' only allowed in dual")
	end
	
	if num ~= "pl" and (word == "sfp" or word == "smp" or word == "awnp" or word == "cdp" or word == "sp" or word == "fp" or word == "p") then
		error("Inference of form for declension type '" .. word .. "' only allowed in plural")
	end

	local function is_intensive_adj(ar)
		return rfind(ar, "^" .. C .. A .. C .. SK .. C .. AOPTA .. N .. UOPT .. "$") or
			rfind(ar, "^" .. C .. A .. C .. SK .. AMAD .. N .. UOPT .. "$") or
			rfind(ar, "^" .. C .. A .. C .. SH .. AOPTA .. N .. UOPT .. "$")
	end
		
	local function is_feminine_cd_adj(ar)
		return pos == "adjective" and
			(rfind(ar, "^" .. C .. A .. C .. SK .. C .. AOPTA .. HAMZA .. UOPT .. "$") or -- ʔḥamrāʔ/ʕamyāʔ/bayḍāʔ
			rfind(ar, "^" .. C .. A .. C .. SH .. AOPTA .. HAMZA .. UOPT .. "$") -- laffāʔ
			)
	end

	local function is_elcd_adj(ar)
		return rfind(ar, ELCD_START .. SK .. C .. A .. C .. UOPT .. "$") or -- ʔabyaḍ "white", ʔakbar "greater"
			rfind(ar, ELCD_START .. A .. C .. SH .. UOPT .. "$") or -- ʔalaff "plump", ʔaqall "fewer"
			rfind(ar, ELCD_START .. SK .. C .. AAMAQ .. "$") or -- ʔaʕmā "blind", ʔadnā "lower"
			rfind(ar, "^" .. AMAD .. C .. A .. C .. UOPT .. "$") -- ʔālam "more painful", ʔāḵar "other"
	end

	if word == "?" or
			(rfind(word, "^[a-z][a-z]*$") and sgtype == "?") then
		--if 'word' is a type, actual value inferred from sg; if sgtype is ?,
		--propagate it to all derived types
		return "", "?"
	end

	if word == "intf" then
		if not is_intensive_adj(sgar) then
			error("Singular stem not in CACCān form: " .. sgar)
		end
		local ret = (
			sub(AMAD .. N .. UOPT .. "$", AMAD, "nu?$", "") or -- ends in -ʔān
			sub(AOPTA .. N .. UOPT .. "$", AMAQ, "nu?$", "") -- ends in -ān
		)
		return ret, "inv"
	end

	if word == "elf" then
		local ret = (
			sub(ELCD_START .. SK .. "[" .. Y .. W .. "]" .. A .. CCAP .. UOPT .. "$",
				"%1" .. UU .. "%2" .. AMAQ, "ʔa(.)[yw]a(.)u?", "%1ū%2ā") or -- ʔajyad
			sub(ELCD_START .. SK .. CCAP .. A .. CCAP .. UOPT .. "$",
				"%1" .. U .. "%2" .. SK .. "%3" .. AMAQ, "ʔa(.)(.)a(.)u?", "%1u%2%3ā") or -- ʔakbar
			sub(ELCD_START .. A .. CCAP .. SH .. UOPT .. "$",
				"%1" .. U .. "%2" .. SH .. AMAQ, "ʔa(.)a(.)%2u?", "%1u%2%2ā") or -- ʔaqall
			sub(ELCD_START .. SK .. CCAP .. AAMAQ .. "$",
				"%1" .. U .. "%2" .. SK .. Y .. ALIF, "ʔa(.)(.)ā", "%1u%2yā") or -- ʔadnā
			sub("^" .. AMAD .. CCAP .. A .. CCAP .. UOPT .. "$",
				HAMZA_ON_ALIF .. U .. "%1" .. SK .. "%2" .. AMAQ, "ʔā(.)a(.)u?", "ʔu%1%2ā") -- ʔālam "more painful", ʔāḵar "other"
		)
		if not ret then
			error("Singular stem not an elative adjective: " .. sgar)
		end
		return ret, "inv"
	end

	if word == "cdf" then
		local ret = (
			sub(ELCD_START .. SK .. CCAP .. A .. CCAP .. UOPT .. "$",
				"%1" .. A .. "%2" .. SK .. "%3" .. AA .. HAMZA, "ʔa(.)(.)a(.)u?", "%1a%2%3āʔ") or -- ʔaḥmar
			sub(ELCD_START .. A .. CCAP .. SH .. UOPT .. "$",
				"%1" .. A .. "%2" .. SH .. AA .. HAMZA, "ʔa(.)a(.)%2u?", "%1a%2%2āʔ") or -- ʔalaff
			sub(ELCD_START .. SK .. CCAP .. AAMAQ .. "$",
				"%1" .. A .. "%2" .. SK .. Y .. AA .. HAMZA, "ʔa(.)(.)ā", "%1a%2yāʔ") -- ʔaʕmā
		)
		if not ret then
			error("Singular stem not a color/defect adjective: " .. sgar)
		end
		return ret, "cd" -- so plural will be correct
	end

	-- Regular feminine -- add ة, possibly with stem modifications
	if word == "rf" then
		sgar = canon_hamza(sgar)
	
		if rfind(sgar, TAM .. UNUOPT .. "$") then
			--Don't do this or we have problems when forming singulative from
			--collective with a construct modifier that's feminine
			--error("Singular stem is already feminine: " .. sgar)
			return sgar .. "/" .. sgtr, "tri"
		end

		local ret = (
			sub(AN .. "[" .. ALIF .. AMAQ .. "]$", AAH, "an$", "āh") or -- ends in -an
			sub(IN .. "$", IY .. AH, "in$", "iya") or -- ends in -in
			sub(AOPT .. "[" .. ALIF .. AMAQ .. "]$", AAH, "ā$", "āh") or -- ends in alif or alif maqṣūra
			-- We separate the ʔiʕrāb and no-ʔiʕrāb cases even though we can
			-- do a single Arabic regexp to cover both because we want to
			-- remove u(n) from the translit only when ʔiʕrāb is present to
			-- lessen the risk of removing -un in the actual stem. We also
			-- allow for cases where the ʔiʕrāb is present in Arabic but not
			-- in translit.
			sub(UNU .. "$", AH, "un?$", "a", "$", "a") or -- anything else + -u(n)
			sub("$", AH, "$", "a") -- anything else
		)
		return ret, "tri"
	end

	if word == "f" then
		if sgtype == "cd" then
			return export.stem_and_type("cdf", sg, sgtype, true, "sg", pos)
		elseif sgtype == "el" then
			return export.stem_and_type("elf", sg, sgtype, true, "sg", pos)
		elseif sgtype =="di" and is_intensive_adj(sgar) then
			return export.stem_and_type("intf", sg, sgtype, true, "sg", pos)
		elseif sgtype == "di" and is_elcd_adj(sgar) then
			-- If form is elative or color-defect, we don't know which of
			-- the two it is, and each has a special feminine which isn't
			-- the regular "just add ة", so shunt to unknown. This will
			-- ensure that ?'s appear in place of the declension -- also
			-- for dual and plural.
			return export.stem_and_type("?", sg, sgtype, true, "sg", pos)
		else
			return export.stem_and_type("rf", sg, sgtype, true, "sg", pos)
		end
	end

	if word == "rm" then
		sgar = canon_hamza(sgar)
	
		--Don't do this or we have problems when forming collective from
		--singulative with a construct modifier that's not feminine,
		--e.g. شَجَرَة التُفَّاح
		--if not rfind(sgar, TAM .. UNUOPT .. "$") then
		--	error("Singular stem is not feminine: " .. sgar)
		--end

		local ret = (
			sub(AAH .. UNUOPT .. "$", AN .. AMAQ, "ātun?$", "an", "ā[ht]$", "an") or -- in -āh
			sub(IY .. AH .. UNUOPT .. "$", IN, "iyatun?$", "in", "iya$", "in") or -- ends in -iya
			sub(AOPT .. TAM .. UNUOPT .. "$", "", "atun?$", "", "a$", "") or --ends in -a
			sub("$", "", "$", "") -- do nothing
		)
		return ret, "tri"
	end

	if word == "m" then
		-- FIXME: handle cd (color-defect)
		-- FIXME: handle el (elative)
		-- FIXME: handle int (intensive)
		return export.stem_and_type("rm", sg, sgtype, false, "sg", pos)
	end

	-- The plural used for feminine adjectives. If the singular type is
	-- color/defect or it looks like a feminine color/defect adjective,
	-- use color/defect plural. Otherwise shunt to sound feminine plural.
	if word == "fp" then
		if sgtype == "cd" or is_feminine_cd_adj(sgar) then
			return export.stem_and_type("cdp", sg, sgtype, true, "pl", pos)
		else
			return export.stem_and_type("sfp", sg, sgtype, true, "pl", pos)
		end
	end

	if word == "sp" then
		if sgtype == "cd" then
			return export.stem_and_type("cdp", sg, sgtype, isfem, "pl", pos)
		elseif isfem then
			return export.stem_and_type("sfp", sg, sgtype, true, "pl", pos)
		elseif sgtype == "an" then
			return export.stem_and_type("awnp", sg, sgtype, false, "pl", pos)
		else
			return export.stem_and_type("smp", sg, sgtype, false, "pl", pos)
		end
	end

	-- Conservative plural, as used for masculine plural adjectives.
	-- If singular type is color-defect, shunt to color-defect plural; else
	-- shunt to unknown, so ? appears in place of the declensions.
	if word == "p" then
		if sgtype == "cd" then
			return export.stem_and_type("cdp", sg, sgtype, isfem, "pl", pos)
		else
			return export.stem_and_type("?", sg, sgtype, isfem, "pl", pos)
		end
	end

	-- Special plural used for paucal plurals of singulatives. If ends in -ة
	-- (most common), use strong feminine plural; if ends with -iyy (next
	-- most common), use strong masculine plural; ends default to "p"
	-- (conservative plural).
	if word == "paucp" then
		if rfind(sgar, TAM .. UNUOPT .. "$") then
			return export.stem_and_type("sfp", sg, sgtype, true, "pl", pos)
		elseif rfind(sgar, IY .. SH .. UNUOPT .. "$") then
			return export.stem_and_type("smp", sg, sgtype, false, "pl", pos)
		else
			return export.stem_and_type("p", sg, sgtype, isfem, "pl", pos)
		end
	end

	if word == "d" then
		sgar = canon_hamza(sgar)
		local ret = (
			sub(AN .. "[" .. ALIF .. AMAQ .. "]$", AY .. AAN, "an$", "ayān") or -- ends in -an
			sub(IN .. "$", IY .. AAN, "in$", "iyān") or -- ends in -in
			sgtype == "lwinv" and sub(AOPTA .. "$", AT .. AAN, "[āa]$", "atān") or -- lwinv, ends in alif; allow translit with short -a
			sub(AOPT .. "[" .. ALIF .. AMAQ .. "]$", AY .. AAN, "ā$", "ayān") or -- ends in alif or alif maqṣūra
			-- We separate the ʔiʕrāb and no-ʔiʕrāb cases even though we can
			-- do a single Arabic regexp to cover both because we want to
			-- remove u(n) from the translit only when ʔiʕrāb is present to
			-- lessen the risk of removing -un in the actual stem. We also
			-- allow for cases where the ʔiʕrāb is present in Arabic but not
			-- in translit.
			--
			-- NOTE: Collapsing the "h$" and "$" cases into "h?$" doesn't work
			-- in the case of words ending in -āh, which end up having the
			-- translit end in -tāntān.
			sub(TAM .. UNU .. "$", T .. AAN, "[ht]un?$", "tān", "h$", "tān", "$", "tān") or -- ends in tāʔ marbuṭa + -u(n)
			sub(TAM .. "$", T .. AAN, "h$", "tān", "$", "tān") or -- ends in tāʔ marbuṭa
			-- Same here as above
			sub(UNU .. "$", AAN, "un?$", "ān", "$", "ān") or -- anything else + -u(n)
			sub("$", AAN, "$", "ān") -- anything else
		)
		return ret, "d"
	end

	-- Strong feminine plural in -āt, possibly with stem modifications
	if word == "sfp" then
		sgar = canon_hamza(sgar)
		sgar = rsub(sgar, AMAD .. "(" .. TAM .. UNUOPT .. ")$", HAMZA_PH .. AA .. "%1")
		sgar = rsub(sgar, HAMZA_ANY .. "(" .. AOPT .. TAM .. UNUOPT .. ")$", HAMZA_PH .. "%1")
		local ret = (
			sub(AOPTA .. TAM .. UNUOPT .. "$", AYAAT, "ā[ht]$", "ayāt", "ātun?$", "ayāt") or -- ends in -āh
			sub(AOPT .. TAM .. UNUOPT .. "$", AAT, "a$", "āt", "atun?$", "āt") or -- ends in -a
			sub(AN .. "[" .. ALIF .. AMAQ .. "]$", AYAAT, "an$", "ayāt") or -- ends in -an
			sub(IN .. "$", IY .. AAT, "in$", "iyāt") or -- ends in -in
			sgtype == "inv" and (
				sub(AOPT .. "[" .. ALIF .. AMAQ .. "]$", AYAAT, "ā$", "ayāt") -- ends in alif or alif maqṣūra
			) or
			sgtype == "lwinv" and (
				sub(AOPTA .. "$", AAT, "[āa]$", "āt") -- loanword ending in tall alif; allow translit with short -a
			) or
			-- We separate the ʔiʕrāb and no-ʔiʕrāb cases even though we can
			-- do a single Arabic regexp to cover both because we want to
			-- remove u(n) from the translit only when ʔiʕrāb is present to
			-- lessen the risk of removing -un in the actual stem. We also
			-- allow for cases where the ʔiʕrāb is present in Arabic but not
			-- in translit.
			sub(UNU .. "$", AAT, "un?$", "āt", "$", "āt") or -- anything else + -u(n)
			sub("$", AAT, "$", "āt") -- anything else
		)
		return ret, "sfp"
	end

	if word == "smp" then
		sgar = canon_hamza(sgar)
		local ret = (
			sub(IN .. "$", UUN, "in$", "ūn") or -- ends in -in
			-- See comments above for why we have two cases, one for UNU and
			-- one for non-UNU
			sub(UNU .. "$", UUN, "un?$", "ūn", "$", "ūn") or -- anything else + -u(n)
			sub("$", UUN, "$", "ūn") -- anything else
		)
		return ret, "smp"
	end

	-- Color/defect plural; singular must be masculine or feminine
	-- color/defect adjective
	if word == "cdp" then
		local ret = (
			sub(ELCD_START .. SK .. W .. A .. CCAP .. UOPT .. "$",
				"%1" .. UU .. "%2", "ʔa(.)wa(.)u?", "%1ū%2") or -- ʔaswad
			sub(ELCD_START .. SK .. Y .. A .. CCAP .. UOPT .. "$",
				"%1" .. II .. "%2", "ʔa(.)ya(.)u?", "%1ī%2") or -- ʔabyaḍ
			sub(ELCD_START .. SK .. CCAP .. A .. CCAP .. UOPT .. "$",
				"%1" .. U .. "%2" .. SK .. "%3", "ʔa(.)(.)a(.)u?", "%1u%2%3") or -- ʔaḥmar
			sub(ELCD_START .. A .. CCAP .. SH .. UOPT .. "$",
				"%1" .. U .. "%2" .. SH, "ʔa(.)a(.)%2u?", "%1u%2%2") or -- ʔalaff
			sub(ELCD_START .. SK .. CCAP .. AAMAQ .. "$",
				"%1" .. U .. "%2" .. Y, "ʔa(.)(.)ā", "%1u%2y") or -- ʔaʕmā
			sub("^" .. CCAP .. A .. W .. SKOPT .. CCAP .. AA .. HAMZA .. UOPT .. "$", "%1" .. UU .. "%2", "(.)aw(.)āʔu?", "%1ū%2") or -- sawdāʔ
			sub("^" .. CCAP .. A .. Y .. SKOPT .. CCAP .. AA .. HAMZA .. UOPT .. "$", "%1" .. II .. "%2", "(.)ay(.)āʔu?", "%1ī%2") or -- bayḍāʔ
			sub("^" .. CCAP .. A .. CCAP .. SK .. CCAP .. AA .. HAMZA .. UOPT .. "$", "%1" .. U .. "%2" .. SK .. "%3", "(.)a(.)(.)āʔu?", "%1u%2%3") or -- ʔḥamrāʔ/ʕamyāʔ
			sub("^" .. CCAP .. A .. CCAP .. SH .. AA .. HAMZA .. UOPT .. "$", "%1" .. U .. "%2" .. SH, "(.)a(.)%2āʔu?", "%1u%2%2") -- laffāʔ
		)
		if not ret then
			error("For 'cdp', singular must be masculine or feminine color/defect adjective: " .. sgar)
		end
		return ret, "tri"
	end

	if word == "awnp" then
		local ret = (
			sub(AN .. "[" .. ALIF .. AMAQ .. "]$", AWSK .. N, "an$", "awn") -- ends in -an
		)
		if not ret then
			error("For 'awnp', singular must end in -an: " .. sgar)
		end
		return ret, "awnp"
	end

	return artr, export.detect_type(ar, isfem, num, pos)
end

local function parse_indicator_spec(angle_bracket_spec)
	-- Store the original angle bracket spec so we can reconstruct the overall conj spec with the lemma(s) in them.
	local base = {
		angle_bracket_spec = angle_bracket_spec,
		user_stem_overrides = {},
		user_slot_overrides = {},
		slot_explicitly_missing = {},
		slot_uncertain = {},
		slot_override_uses_default = {},
		addnote_specs = {},
	}
	local function parse_err(msg)
		error(msg .. ": " .. angle_bracket_spec)
	end
	local function fetch_footnotes(separated_group)
		local footnotes
		for j = 2, #separated_group - 1, 2 do
			if separated_group[j + 1] ~= "" then
				parse_err("Extraneous text after bracketed footnotes: '" .. table.concat(separated_group) .. "'")
			end
			if not footnotes then
				footnotes = {}
			end
			table.insert(footnotes, separated_group[j])
		end
		return footnotes
	end

	local inside = angle_bracket_spec:match("^<(.*)>$")
	assert(inside)
	local segments = iut.parse_multi_delimiter_balanced_segment_run(inside, {{"[", "]"}, {"<", ">"}})
	local dot_separated_groups = iut.split_alternating_runs_and_strip_spaces(segments, "%.")

	-- The first dot-separated element must specify the verb form, e.g. IV or IIq. If the form is I, it needs to include
	-- the the past and non-past vowels, e.g.  I/a~u for kataba ~ yaktubu. More than one vowel can be given,
	-- comma-separated, and more than one past~non-past pair can be given, slash-separated, e.g. I/a,u~u/i~a for form I
	-- كمل, which can be conjugated as kamala/kamula ~ yakmulu or kamila ~ yakmalu. An individual vowel spec must be one
	-- of a, i or u and in general (a) at least one past~non-past pair most be given, and (b) both past and non-past
	-- vowels must be given even though sometimes the vowel can be determined from the unvocalized form. An exception is
	-- passive-only verbs, where the vowels can't in general be determined (except indirectly in some cases by looking
	-- at an associated non-passive verb); in that case, the vowel~vowel spec can left out.
	local slash_separated_groups = iut.split_alternating_runs_and_strip_spaces(dot_separated_groups[1], "/")
	local form_spec = slash_separated_groups[1]
	base.form_footnotes = fetch_footnotes(form_spec)
	if form_spec[1] == "" then
		parse_err("Missing verb form")
	end
	if not allowed_vforms_with_weakness_set[form_spec[1]] then
		parse_err(("Unrecognized verb form '%s', should be one of %s"):format(
			form_spec[1], m_table.serialCommaJoin(allowed_vforms, {conj = "or", dontTag = true})))
	end
	if form_spec[1]:find("%-") then
		base.verb_form, base.explicit_weakness = form_spec[1]:match("^(.-)%-(.*)$")
	else
		base.verb_form = form_spec[1]
	end

	if #slash_separated_groups > 1 then
		if base.verb_form ~= "I" then
			parse_err(("Past~non-past vowels can only be specified when verb form is I, but saw form '%s'"):format(
				base.verb_form))
		end
		for i = 2, #slash_separated_groups do
			local slash_separated_group = slash_separated_groups[i]
			local tilde_separated_groups = iut.split_alternating_runs_and_strip_spaces(slash_separated_group, "~")
			if #tilde_separated_groups ~= 2 then
				parse_err(("Expected two tilde-separated vowel specs: %s"):format(table.concat(slash_separated_group)))
			end
			local function parse_conj_vowels(tilde_separated_group, vtype)
				local conj_vowel_objects = {}
				local comma_separated_groups = iut.split_alternating_runs_and_strip_spaces(tilde_separated_group, ",")
				for _, comma_separated_group in ipairs(comma_separated_groups) do
					local conj_vowel = comma_separated_group[1]
					if conj_vowel ~= "a" and conj_vowel ~= "i" and conj_vowel ~= "u" then
						parse_err(("Expected %s conjugation vowel '%s' to be one of a, i or u in %s"):format(
							vtype, conj_vowel, table.concat(slash_separated_group)))
					end
					conj_vowel = dia[conj_vowel]
					local conj_vowel_footnotes = fetch_footnotes(comma_separated_group)
					-- Try to use strings when possible as it makes q() significantly more efficient.
					if conj_vowel_footnotes then
						table.insert(conj_vowel_objects, {form = conj_vowel, footnotes = conj_vowel_footnotes})
					else
						table.insert(conj_vowel_objects, conj_vowel)
					end
				end
				return conj_vowel_objects
			end
			local conj_vowel_spec = {
				past = parse_conj_vowels(tilde_separated_groups[1], "past"),
				nonpast = parse_conj_vowels(tilde_separated_groups[2], "non-past"),
			}
			table.insert(base.conj_vowels, conj_vowel_spec)
		end
	end

	for i = 2, #dot_separated_groups do
		local dot_separated_group = dot_separated_groups[i]
		local first_element = dot_separated_group[1]
		if first_element == "addnote" then
			local spec_and_footnotes = fetch_footnotes(dot_separated_group)
			if #spec_and_footnotes < 2 then
				parse_err("Spec with 'addnote' should be of the form 'addnote[SLOTSPEC][FOOTNOTE][FOOTNOTE][...]'")
			end
			local slot_spec = table.remove(spec_and_footnotes, 1)
			local slot_spec_inside = rmatch(slot_spec, "^%[(.*)%]$")
			if not slot_spec_inside then
				parse_err("Internal error: slot_spec " .. slot_spec .. " should be surrounded with brackets")
			end
			local slot_specs = rsplit(slot_spec_inside, ",")
			-- FIXME: Here, [[Module:it-verb]] called strip_spaces(). Generally we don't do this. Should we?
			table.insert(base.addnote_specs, {slot_specs = slot_specs, footnotes = spec_and_footnotes})
		elseif first_element:find("^var:") then
			if #dot_separated_group > 1 then
				parse_err(("Can't attach footnotes to 'var:' spec '%s'"):format(first_element))
			end
			base.variant = first_element:match("^var:(.*)$")
		elseif first_element:find("^I+V?:") then
			local root_cons, root_cons_value = first_element:match("^(I+V?):(.*)$")
			local root_index
			if root_cons == "I" then
				root_index = 1
			elseif root_cons == "II" then
				root_index = 2
			elseif root_cons == "III" then
				root_index = 3
			elseif root_cons == "IV" then
				root_index = 4
				if not base.verb_form:find("q$") then
					parse_err(("Can't specify root consonant IV for non-quadriliteral verb form '%s': %s"):format(
						base.verb_form, first_element))
				end
			end
			local cons, translit = root_cons_value:match("^(.*)//(.*)$")
			if not cons then
				cons = root_cons_value
			end
			local root_footnotes = fetch_footnotes(dot_separated_group)
			if not translit and not root_footnotes then
				base.root_consonants[root_index] = cons
			else
				base.root_consonants[root_index] = {form = cons, translit = translit, footnotes = root_footnotes}
			end
		elseif first_element:find("^[a-z][a-z0-9_]*:") then
			local slot_or_stem, remainder = first_element:match("^(.-):(.*)$")
			dot_separated_group[1] = remainder
			local comma_separated_groups = iut.split_alternating_runs_and_strip_spaces(dot_separated_group, "[,،]")
			if overridable_stems[slot_or_stem] then
				if base.user_stem_overrides[slot_or_stem] then
					parse_err("Overridable stem '" .. slot_or_stem .. "' specified twice")
				end
				base.user_stem_overrides[slot_or_stem] = overridable_stems[slot_or_stem](comma_separated_groups,
					{prefix = slot_or_stem, base = base, parse_err = parse_err, fetch_footnotes = fetch_footnotes})
			else -- assume a form override; we validate further later when the possible slots are available
				if base.user_slot_overrides[slot_or_stem] then
					parse_err("Form override '" .. slot_or_stem .. "' specified twice")
				end
				base.user_slot_overrides[slot_or_stem] = allow_multiple_values_for_override(comma_separated_groups,
					{prefix = slot_or_stem, base = base, parse_err = parse_err, fetch_footnotes = fetch_footnotes},
					"is form override")
			end
		elseif indicator_flags[first_element] then
			if #dot_separated_group > 1 then
				parse_err("No footnotes allowed with '" .. first_element .. "' spec")
			end
			if base[first_element] then
				parse_err("Spec '" .. first_element .. "' specified twice")
			end
			base[first_element] = true
		else
			local passive, uncertain = first_element:match("^(.*)(%?)$")
			passive = passive or first_element
			uncertain = not not uncertain
			if passive_types[passive] then
				if #dot_separated_group > 1 then
					parse_err("No footnotes allowed with '" .. passive .. "' spec")
				end
				if base.passive then
					parse_err("Value for passive type specified twice")
				end
				base.passive = passive
				base.passive_uncertain = uncertain
			else
				parse_err("Unrecognized spec '" .. first_element .. "'")
			end
		end
	end

	return base
end

-- local outersep = " <small style=\"color: #888\">or</small> "
-- need LRM here so multiple Arabic plurals end up agreeing in order with
-- the transliteration
local outersep = LRM .. "; "
local innersep = LRM .. "/"

-- Subfunction of show_form(), used to implement recursively generating
-- all combinations of elements from FORM and from each of the items in
-- LIST_OF_MODS, both of which are either arrays of strings or arrays of
-- arrays of strings, where the strings are in the form ARABIC/TRANSLIT,
-- as described in show_form(). TRAILING_ARTRMODS is an array of ARTRMOD
-- items, each of which is a two-element array of ARMOD (Arabic) and TRMOD
-- (transliteration), accumulating all of the suffixes generated so far
-- in the recursion process. Each time we recur we take the last MOD item
-- off of LIST_OF_MODS, separate each element in MOD into its Arabic and
-- Latin parts and to each Arabic/Latin pair we add all elements in
-- TRAILING_ARTRMODS, passing the newly generated list of ARTRMOD items
-- down the next recursion level with the shorter LIST_OF_MODS. We end up
-- returning a string to insert into the Wiki-markup table.
local function show_form_1(form, list_of_mods, trailing_artrmods, use_parens)
	if #list_of_mods == 0 then
		local arabicvals = {}
		local latinvals = {}
		local parenvals = {}
		
		-- Accumulate separately the Arabic and transliteration into
		-- ARABICVALS and LATINVALS, then concatenate each down below.
		-- However, if USE_PARENS, we put each transliteration directly
		-- after the corresponding Arabic, in parens, and put the results
		-- in PARENVALS, which get concatenated below. (This is used in the
		-- title of the declension table.)
		for _, artrmod in ipairs(trailing_artrmods) do
			assert(#artrmod == 2)
			local armod = artrmod[1]
			local trmod = artrmod[2]
			for _, subform in ipairs(form) do
				local ar_span, tr_span
				local ar_subspan, tr_subspan
				local ar_subspans = {}
				local tr_subspans = {}
				if type(subform) ~= "table" then
					subform = {subform}
				end
				for _, subsubform in ipairs(subform) do
					local arabic, translit = split_arabic_tr(subsubform)
					if arabic == "-" then
						ar_subspan = "&mdash;"
						tr_subspan = "&mdash;"
					else
						tr_subspan = (rfind(translit, BOGUS_CHAR) or rfind(trmod, BOGUS_CHAR)) and "?" or
							require("Module:script utilities").tag_translit(translit .. trmod, lang, "default", 'style="color: #888;"')
						-- implement elision of al- after vowel
						tr_subspan = rsub(tr_subspan, "([aeiouāēīōū][ %-])a([sšṣtṯṭdḏḍzžẓnrḷl]%-)", "%1%2")
						tr_subspan = rsub(tr_subspan, "([aeiouāēīōū][ %-])a(llāh)", "%1%2")

						ar_subspan = m_links.full_link({lang = lang, term = arabic .. armod, tr = "-"})
					end

					m_table.insertIfNot(ar_subspans, ar_subspan)
					m_table.insertIfNot(tr_subspans, tr_subspan)
				end

				ar_span = table.concat(ar_subspans, innersep)
				tr_span = table.concat(tr_subspans, innersep)

				if use_parens then
					table.insert(parenvals, ar_span .. " (" .. tr_span .. ")")
				else
					table.insert(arabicvals, ar_span)
					table.insert(latinvals, tr_span)
				end
			end
		end

		if use_parens then
			return table.concat(parenvals, outersep)
		else
			local arabic_span = table.concat(arabicvals, outersep)
			local latin_span = table.concat(latinvals, outersep)
			return arabic_span .. "<br />" .. latin_span
		end
	else
		local last_mods = table.remove(list_of_mods)
		local artrmods = {}
		for _, mod in ipairs(last_mods) do
			if type(mod) ~= "table" then
				mod = {mod}
			end
			for _, submod in ipairs(mod) do
				local armod, trmod = split_arabic_tr(submod)
				-- If the value is -, we need to create a blank entry
				-- rather than skipping it; if we have no entries at any
				-- level, then there will be no overall entries at all
				-- because the inside of the loop at the next level will
				-- never be executed.
				if armod == "-" then
					armod = ""
					trmod = ""
				end
				if armod ~= "" then armod = ' ' .. armod end
				if trmod ~= "" then trmod = ' ' .. trmod end
				for _, trailing_artrmod in ipairs(trailing_artrmods) do
					local trailing_armod = trailing_artrmod[1]
					local trailing_trmod = trailing_artrmod[2]
					armod = armod .. trailing_armod
					trmod = trmod .. trailing_trmod
					artrmod = {armod, trmod}
					table.insert(artrmods, artrmod)
				end
			end
		end
		return show_form_1(form, list_of_mods, artrmods, use_parens)
	end
end

-- Generate a string to substitute into a particular form in a Wiki-markup
-- table. FORM is the set of inflected forms corresponding to the base,
-- either an array of strings (referring e.g. to different possible plurals)
-- or an array of arrays of strings (the first level referring e.g. to
-- different possible plurals and the inner level referring typically to
-- hamza-spelling variants). LIST_OF_MODS is an array of MODS elements, one
-- per modifier. Each MODS element is the set of inflected forms corresponding
-- to the modifier and is of the same form as FORM, i.e. an array of strings
-- or an array of arrays of strings. Each string is typically of the form
-- "ARABIC/TRANSLIT", i.e. an Arabic string and a Latin string separated
-- by a slash. We loop over all possible combinations of elements from
-- each array; this requires recursion.
local function show_form(form, list_of_mods, use_parens)
	if not form then
		return "&mdash;"
	elseif type(form) ~= "table" then
		error("a non-table value was given in the list of inflected forms.")
	end
	if #form == 0 then
		return "&mdash;"
	end

	-- We need to start the recursion with the third parameter containing
	-- one blank element rather than no elements, otherwise no elements
	-- will be propagated to the next recursion level.
	return show_form_1(form, list_of_mods, {{"", ""}}, use_parens)
end

-- Create a Wiki-markup table using the values in DATA and the template in
-- WIKICODE.
local function make_table(data, wikicode)
	-- Function used as replace arg of call to rsub(). Replace the
	-- specified param with its (HTML) value. The param references appear
	-- as {{{PARAM}}} in the wikicode.
	local function repl(param)
		if param == "pos" then
			return data.pos
		elseif param == "info" then
			return data.title and " (" .. data.title .. ")" or ""
		elseif rfind(param, "type$") then
			return table.concat(data.forms[param] or {"&mdash;"}, outersep)
		else
			local list_of_mods = {}
			for _, mod in ipairs(mod_list) do
				local mods = data.forms[mod .. "_" .. param]
				if not mods or #mods == 0 then
					-- We need one blank element rather than no element,
					-- otherwise no elements will be propagated from one
					-- recursion level to the next.
					mods = {""}
				end
				table.insert(list_of_mods, mods)
			end
			return show_form(data.forms[param], list_of_mods, param == "lemma")
		end
	end
	
	-- For states not in the list of those to be displayed, clear out the
	-- corresponding declensions so they appear as a dash.
	for _, state in ipairs(data.allstates) do
		if not m_table.contains(data.states, state) then
			for _, numgen in ipairs(data.numgens()) do
				for _, case in ipairs(data.allcases) do
					data.forms[case .. "_" .. numgen .. "_" .. state] = {}
				end
			end
		end
	end

	return rsub(wikicode, "{{{([a-z_]+)}}}", repl) .. m_utilities.format_categories(data.categories, lang)
end

-- Generate part of the noun table for a given number spec NUM (e.g. sg)
local function generate_noun_num(num)
	return [=[! style="background: #CDCDCD;" | Indefinite
! style="background: #CDCDCD;" | Definite
! style="background: #CDCDCD;" | Construct
|-
! style="background: #EFEFEF;" | Informal
| {{{inf_]=] .. num .. [=[_ind}}}
| {{{inf_]=] .. num .. [=[_def}}}
| {{{inf_]=] .. num .. [=[_con}}}
|-
! style="background: #EFEFEF;" | Nominative
| {{{nom_]=] .. num .. [=[_ind}}}
| {{{nom_]=] .. num .. [=[_def}}}
| {{{nom_]=] .. num .. [=[_con}}}
|-
! style="background: #EFEFEF;" | Accusative
| {{{acc_]=] .. num .. [=[_ind}}}
| {{{acc_]=] .. num .. [=[_def}}}
| {{{acc_]=] .. num .. [=[_con}}}
|-
! style="background: #EFEFEF;" | Genitive
| {{{gen_]=] .. num .. [=[_ind}}}
| {{{gen_]=] .. num .. [=[_def}}}
| {{{gen_]=] .. num .. [=[_con}}}
]=]
end

-- Make the noun table
local function make_noun_table(data)
	local wikicode = [=[<div class="NavFrame">
<div class="NavHead">Declension of {{{pos}}} {{{lemma}}}</div>
<div class="NavContent">
{| class="inflection-table" style="border-width: 1px; border-collapse: collapse; background:#F9F9F9; text-align:center; width:100%;"
]=]

	for _, num in ipairs(data.numbers) do
		if num == "du" then
			wikicode = wikicode .. [=[|-
! style="background: #CDCDCD;" | Dual
]=] .. generate_noun_num("du")
		else
			wikicode = wikicode .. [=[|-
! style="background: #CDCDCD;" rowspan=2 | ]=] .. data.engnumberscap[num] .. "\n" .. [=[
! style="background: #CDCDCD;" colspan=3 | {{{]=] .. num .. [=[_type}}}
|-
]=] .. generate_noun_num(num)
		end
	end
	wikicode = wikicode .. [=[|}
</div>
</div>]=]

	return make_table(data, wikicode)
end

-- Generate part of the gendered-noun table for a given numgen spec
-- NUM (e.g. m_sg)
local function generate_gendered_noun_num(num)
	return [=[|-
! style="background: #CDCDCD;" | Indefinite
! style="background: #CDCDCD;" | Definite
! style="background: #CDCDCD;" | Construct
! style="background: #CDCDCD;" | Indefinite
! style="background: #CDCDCD;" | Definite
! style="background: #CDCDCD;" | Construct
|-
! style="background: #EFEFEF;" | Informal
| {{{inf_m_]=] .. num .. [=[_ind}}}
| {{{inf_m_]=] .. num .. [=[_def}}}
| {{{inf_m_]=] .. num .. [=[_con}}}
| {{{inf_f_]=] .. num .. [=[_ind}}}
| {{{inf_f_]=] .. num .. [=[_def}}}
| {{{inf_f_]=] .. num .. [=[_con}}}
|-
! style="background: #EFEFEF;" | Nominative
| {{{nom_m_]=] .. num .. [=[_ind}}}
| {{{nom_m_]=] .. num .. [=[_def}}}
| {{{nom_m_]=] .. num .. [=[_con}}}
| {{{nom_f_]=] .. num .. [=[_ind}}}
| {{{nom_f_]=] .. num .. [=[_def}}}
| {{{nom_f_]=] .. num .. [=[_con}}}
|-
! style="background: #EFEFEF;" | Accusative
| {{{acc_m_]=] .. num .. [=[_ind}}}
| {{{acc_m_]=] .. num .. [=[_def}}}
| {{{acc_m_]=] .. num .. [=[_con}}}
| {{{acc_f_]=] .. num .. [=[_ind}}}
| {{{acc_f_]=] .. num .. [=[_def}}}
| {{{acc_f_]=] .. num .. [=[_con}}}
|-
! style="background: #EFEFEF;" | Genitive
| {{{gen_m_]=] .. num .. [=[_ind}}}
| {{{gen_m_]=] .. num .. [=[_def}}}
| {{{gen_m_]=] .. num .. [=[_con}}}
| {{{gen_f_]=] .. num .. [=[_ind}}}
| {{{gen_f_]=] .. num .. [=[_def}}}
| {{{gen_f_]=] .. num .. [=[_con}}}
]=]
end

-- Make the gendered noun table
local function make_gendered_noun_table(data)
	local wikicode = [=[<div class="NavFrame">
<div class="NavHead">Declension of {{{pos}}} {{{lemma}}}</div>
<div class="NavContent">
{| class="inflection-table" style="border-width: 1px; border-collapse: collapse; background:#F9F9F9; text-align:center; width:100%;"
]=]

	for _, num in ipairs(data.numbers) do
		if num == "du" then
			wikicode = wikicode .. [=[|-
! style="background: #CDCDCD;" rowspan=2 | Dual
! style="background: #CDCDCD;" colspan=3 | Masculine
! style="background: #CDCDCD;" colspan=3 | Feminine
]=] .. generate_gendered_noun_num("du")
		else
			wikicode = wikicode .. [=[|-
! style="background: #CDCDCD;" rowspan=3 | ]=] .. data.engnumberscap[num] .. "\n" .. [=[
! style="background: #CDCDCD;" colspan=3 | Masculine
! style="background: #CDCDCD;" colspan=3 | Feminine
|-
! style="background: #CDCDCD;" colspan=3 | {{{m_]=] .. num .. [=[_type}}}
! style="background: #CDCDCD;" colspan=3 | {{{f_]=] .. num .. [=[_type}}}
]=] .. generate_gendered_noun_num(num)
		end
	end
	wikicode = wikicode .. [=[|}
</div>
</div>]=]

	return make_table(data, wikicode)
end

-- Generate part of the adjective table for a given numgen spec NUM (e.g. m_sg)
local function generate_adj_num(num)
	return [=[|-
! style="background: #CDCDCD;" | Indefinite
! style="background: #CDCDCD;" | Definite
! style="background: #CDCDCD;" | Indefinite
! style="background: #CDCDCD;" | Definite
|-
! style="background: #EFEFEF;" | Informal
| {{{inf_m_]=] .. num .. [=[_ind}}}
| {{{inf_m_]=] .. num .. [=[_def}}}
| {{{inf_f_]=] .. num .. [=[_ind}}}
| {{{inf_f_]=] .. num .. [=[_def}}}
|-
! style="background: #EFEFEF;" | Nominative
| {{{nom_m_]=] .. num .. [=[_ind}}}
| {{{nom_m_]=] .. num .. [=[_def}}}
| {{{nom_f_]=] .. num .. [=[_ind}}}
| {{{nom_f_]=] .. num .. [=[_def}}}
|-
! style="background: #EFEFEF;" | Accusative
| {{{acc_m_]=] .. num .. [=[_ind}}}
| {{{acc_m_]=] .. num .. [=[_def}}}
| {{{acc_f_]=] .. num .. [=[_ind}}}
| {{{acc_f_]=] .. num .. [=[_def}}}
|-
! style="background: #EFEFEF;" | Genitive
| {{{gen_m_]=] .. num .. [=[_ind}}}
| {{{gen_m_]=] .. num .. [=[_def}}}
| {{{gen_f_]=] .. num .. [=[_ind}}}
| {{{gen_f_]=] .. num .. [=[_def}}}
]=]
end

-- Make the adjective table
local function make_adj_table(data)
	local wikicode = [=[<div class="NavFrame">
<div class="NavHead">Declension of {{{pos}}} {{{lemma}}}</div>
<div class="NavContent">
{| class="inflection-table" style="border-width: 1px; border-collapse: collapse; background:#F9F9F9; text-align:center; width:100%;"
]=]

	if m_table.contains(data.numbers, "sg") then
		wikicode = wikicode .. [=[|-
! style="background: #CDCDCD;" rowspan=3 | Singular
! style="background: #CDCDCD;" colspan=2 | Masculine
! style="background: #CDCDCD;" colspan=2 | Feminine
|-
! style="background: #CDCDCD;" colspan=2 | {{{m_sg_type}}}
! style="background: #CDCDCD;" colspan=2 | {{{f_sg_type}}}
]=] .. generate_adj_num("sg")
	end
	if m_table.contains(data.numbers, "du") then
		wikicode = wikicode .. [=[|-
! style="background: #CDCDCD;" rowspan=2 | Dual
! style="background: #CDCDCD;" colspan=2 | Masculine
! style="background: #CDCDCD;" colspan=2 | Feminine
]=] .. generate_adj_num("du")
	end
	if m_table.contains(data.numbers, "pl") then
		wikicode = wikicode .. [=[|-
! style="background: #CDCDCD;" rowspan=3 | Plural
! style="background: #CDCDCD;" colspan=2 | Masculine
! style="background: #CDCDCD;" colspan=2 | Feminine
|-
! style="background: #CDCDCD;" colspan=2 | {{{m_pl_type}}}
! style="background: #CDCDCD;" colspan=2 | {{{f_pl_type}}}
]=] .. generate_adj_num("pl")
	end
	wikicode = wikicode .. [=[|}
</div>
</div>]=]

	return make_table(data, wikicode)
end

return export

-- For Vim, so we get 4-space tabs
-- vim: set ts=4 sw=4 noet:
