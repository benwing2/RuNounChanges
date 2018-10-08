--[=[
	This module contains functions for generating new Russian entries.

	Author: Benwing

	Arguments:
		1: part of speech
		2: lemma; this should include primary (acute) and other pronunciation-related
		accents (secondary=grave, tertiary=circumflex, dot-above or dot-below if
		needed), and can have manual translit following the lemma separated by //
		(e.g. лате́нтный//latɛ́ntnyj).
		3: definition; multiple lines should be semicolon-separated; put a backslash
		before the semicolon to include a literal semicolon; a given line can be
		prefixed by one or more of the following:
		+ = attributive
		(f) = figurative
		(h) = historical
		(c) = colloquial
		(lc) = low colloquial
		(d) = dated
		(l) = literary
		(p) = poetic
		(tr) = transitive
		(in) = intransitive
		(io) = imperfective only
		(po) = perfective only
		(im) = impersonal
		(an) = animate
		(inan) = inanimate
		(LABEL) = an arbitrary label
		ux: = usage example
		altof: = alternative form of
		dim: = diminutive of
		end: = endearing form of
		aug: = augmentative of
		pej: = pejorative of
		
	If verb:
		4: verb aspect and transitivity
		5: paired aspectual verb
		6,...: conjugation; note that if only one argument is given and it specifies classes
		1 through 6, the appropriate remaining arguments will automatically be generated
		based on the lemma

	If noun:
		4,5,...: declension
		a=, n=: animacy and number; copied directly

	If adjective:
		4: declension

	Other arguments:
		pron=: Pronunciation
		e=: Etymology
		syn=: Synonyms; separate multiple lines with a semicolon, multiple entries on a line
		with comma; prefix with (SENSE) to add a sense label
		ant=: Antonyms; as with synonyms
		der=: Derived terms; as with synonyms but sense labels aren't supported
		rel=: Related terms; as with synonyms but sense labels aren't supported
		alt=: Alternative forms; as with synonyms but sense labels aren't supported
]=]--

local m_utilities = require("Module:utilities")
local ut = require("Module:utils")
local m_links = require("Module:links")
local com = require("Module:ru-common")
local nom = require("Module:ru-nominal")
local strutils = require("Module:string utilities")
local m_table_tools = require("Module:table tools")
local m_debug = require("Module:debug")

local export = {}

local lang = require("Module:languages").getByCode("ru")

local TEMPSUB = "\uFFF0"

----------------------------- Utility functions ------------------------

local u = mw.ustring.char
local rfind = mw.ustring.find
local rsubn = mw.ustring.gsub
local rmatch = mw.ustring.match
local rsplit = mw.text.split
local ulower = mw.ustring.lower
local usub = mw.ustring.sub

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

-- Insert a single form (consisting of {RUSSIAN, TR}) or a list of such
-- forms into an existing list of such forms, adding NOTESYM (a string or nil)
-- to the new forms if not nil. Return whether an insertion was performed.
local function insert_forms_into_existing_forms(existing, newforms, notesym)
	if type(newforms) ~= "table" then
		newforms = {newforms}
	end
	local inserted = false
	for _, item in ipairs(newforms) do
		if not ut.contains(existing, item) then
			if notesym then
				item = nom.concat_paired_russian_tr(item, {notesym})
			end
	        table.insert(existing, item)
			inserted = true
	    end
	end
	return inserted
end

local function track(page)
	m_debug.track("ru-adjective/" .. page)
	return true
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

-- Clone parent's args while also assigning nil to empty strings.
local function clone_args(frame)
	local args = {}
	for pname, param in pairs(frame:getParent().args) do
		args[pname] = ine(param)
	end
	return args
end

-- Iterate over a chain of parameters, FIRST then PREF2, PREF3, ...,
-- inserting into LIST (newly created if omitted). Return LIST.
local function process_arg_chain(args, first, pref, list)
    if not list then
        list = {}
    end
    local val = args[first]
    local i = 2

    while val do
        table.insert(list, val)
        val = args[(pref or first) .. i]
        i = i + 1
    end
    return list
end

-------------------- Global declension/case/etc. variables -------------------

-- 'enable_categories' is a special hack for testing, which disables all
-- category insertion if false. Delete this as soon as we've verified the
-- working of the category code and created all the necessary categories.
local enable_categories = false
local declensions = {}
local declensions_old = {}
local internal_notes_table = {}
local internal_notes_table_old = {}
local internal_notes_genders = {}
local internal_notes_genders_old = {}
local short_declensions = {}
local short_declensions_old = {}
-- Formerly used for the ой-rare type, which has been removed; but keep
-- the code around in case we need it later.
local short_internal_notes_table = {}
local short_internal_notes_table_old = {}
local short_stress_patterns = {}

local long_cases = {
	"nom_m", "nom_n", "nom_f", "nom_p",
	"gen_m", "gen_f", "gen_p",
	"dat_m", "dat_f", "dat_p",
	"acc_f", "acc_n",
	"ins_m", "ins_f", "ins_p",
	"pre_m", "pre_f", "pre_p",
	-- extra old long cases
	"nom_mp",
	-- extra dva cases
	"nom_fp",
	-- extra oba cases
	"gen_mp", "gen_fp",
	"dat_mp", "dat_fp",
	"ins_mp", "ins_fp",
	"pre_mp", "pre_fp",
}

-- Short cases and corresponding numbered arguments
local short_cases = {
	"short_m", "short_n", "short_f", "short_p"
}

-- Create master list of all possible cases (actually case/number/gender pairs)
local all_cases = mw.clone(long_cases)
for _, case in ipairs(short_cases) do
	ut.insert_if_not(all_cases, case)
end

-- If enabled, compare this module with new version of module to make
-- sure all declensions are the same.
local test_new_ru_adjective_module = false

-- Forward references to functions
local tracking_code
local categorize
local detect_stem_and_accent_type
local construct_bare_and_short_stem
local decline
local canonicalize_override
local handle_forms_and_overrides
local decline_short
local make_table

--------------------------------------------------------------------------
--                               Main code                              --
--------------------------------------------------------------------------

local function check_stress(word)
	-- Allow unstressed prefix (e.g. разо-) and unstressed suffix (e.g. -овать)
	if rfind(word, "^%-") or rfind(word, "%-$") then
		return
	end
	if com.needs_accents(word, split_dash=true) then
		error("Word " .. word .. " missing an accent")
	end
end

local function do_split(text, sep)
	text = rsub(text, "\\" .. sep, TEMPSUB)
	local vals = rsplit(text, sep)
	local retvals = {}
	for _, val in ipairs(vals) do
		table.insert(retvals, rsub(val, TEMPSUB, sep))
	end
	return retvals
end

local function handle_etym(arg, data)
	if arg == "?" then
		error("Etymology consists of bare question mark")
	end
	if arg == "-" then
		return "===Etymology===\n{{rfe|lang=ru}}\n\n"
	elseif arg == "--"
		return ""
	end
	local adjformtext = ""
	local adjpos
	if rfind(arg, "^part[fnp]:") then
		adjpos = "part"
		adjg, etym = rmatch(arg, "^part([fnp])(.*)$", arg)
	elseif rfind(arg, "^adj[fnp]:") then
		adjpos = "adj"
		adjg, etym = rmatch(arg, "^adj([fnp])(.*)$", arg)
	elseif rfind(arg, "^partadj[fnp]:") then
		adjpos = "partadj"
		adjg, etym = rmatch(arg, "^partadj([fnp])(.*)$", arg)
	end


	[fill in]

	local etymtext
	if rfind(arg, "^acr:") then
		local _, fullexpr, meaning = do_split(arg, ":")
		etymtext = "{{ru-etym acronym of|" .. fullexpr .. "||" .. meaning .. "}}."
	elseif rfind(arg, "^back:") then
		local _, sourceterm = do_split(arg, ":")
		etymtext = "{{back-form|lang=ru|" .. sourceterm .. "}}"
	elseif rfind(arg, "^raw:") then
		etymtext = rsub(arg, "^raw:", "")
	elseif rfind(arg, ":") and not rfind(arg, "%+") then
		local prefix
		if rfind(arg, "^%?") then
			prefix = "Perhaps borrowed from "
			arg = rsub(arg, "^%?", "")
		elseif rfind(arg, "^<<") then
			prefix = "Ultimately borrowed from "
			arg = rsub(arg, "^<<", "")
		else
			prefix = "Borrowed from "
		end
		
		local lang, etym = rmatch(arg, "^([a-zA-Z.-]+):(.*)$")
		if not lang then
			error("Bad etymology form: " .. arg)
		end
		etymtext = prefix .. "{{bor|ru|" .. lang .. "|" .. etym .. "}}."
	else
		local prefix = ""
		local suffix = ""
		if rfind(arg, "^%?") then
			prefix = "Perhaps from "
			suffix = "."
			arg = rsub(arg, "^%?", "")
		elseif rfind(arg, "^<<") then
			prefix = "Ultimately from "
			suffix = "."
			arg = rsub(arg, "^<<", "")
		end
		if arg == "r" then
			if not data.isrefl then
				error("Etymology 'r' only allowed with reflexive verbs")
			end
			etymtext = rsub(data.verb, "^(.-)(с[яь])$", "{{affix|ru|%1|-%2}}")
		else
			local lang, etym = rmatch(arg, "^([a-zA-Z.-]+):(.*)$")
			local langtext
			if lang then
				langtext = "|lang1=" .. lang
				arg = etym
			else
				langtext = ""
			end
			etymtext = prefix .. "{{affix|ru|" .. table.concat(do_split(arg, "%+"), "|") .. langtext .. suffix
		end
	end
	return "===Etymology===\n" .. etymtext .. "\n\n"
end

local known_labels = {
	or="or",
	also={"also", "_"},
	f="figurative",
	d="dated",
	p="poetic",
	h="historical",
	n="nonstandard",
	lc={"low", "_", "colloquial"},
	v="vernacular",
	c="colloquial",
	l="literary",
	tr="transitive',
	in="intransitive",
	io="imperfective only",
	po="perfective only",
	im="impersonal",
	pej="pejorative",
	vul="vulgar",
	reg="regional",
	dia="dialectal",
	joc="jocular",
	an="animate",
	inan="inanimate",
}

local handle_defn(arg, pos)
	local lines = {}
	for _, defn in ipairs(do_split(arg, ";")) do
		if defn == "-" then
			table.insert(lines, "# {{rfdef|lang=ru}}\n")
		elseif rfind(defn, "^ux:") then
			table.insert(lines, "#: {{uxi|ru|" .. rsub(defn, "^ux:", "") .. "}}\n")
		else
			local labels = {}
			local prefix = ""
			while true do
				if rfind(defn, "^%+") then
					table.insert(labels, "attributive")
					defn = rsub(defn, "^+", "")
				elseif rfind(defn, "^#") then
					table.insert(labels, "figurative")
					defn = rsub(defn, "^#", "")
				elseif rfind(defn, "^!") then
					table.insert(labels, "colloquial")
					defn = rsub(defn, "^!", "")
				else
					local shortlab, newdefn = rmatch(defn, "^%((.@)%)([^ ].*)$")
					if shortlab then
						local longlab = known_labels[shortlab]
						if longlab then
							if type(longlab) == "table" then
								for _, lab in ipairs(longlab) do
									table.insert(labels, lab)
								end
							else
								table.insert(labels, longlab)
							end
						else
							table.insert(labels, shortlab)
						end
						defn = newdefn
					else
						defn = rsub(rsub(defn, "\\(", "("), "\\)", ")")
						break
				end
			end
			if #labels > 0 then
				prefix = "{{lb|ru|" .. table.concat(labels, " |") .. "}} "
			end
			local defnline = ""
			if rfind(defn, "^altof:") then
				defnline = "{{alternative form of|lang=ru" .. rsub(defn, "^altof:", "") .. "}}"
			elseif rfind(defn, "^dim:") then
				defnline = generate_dimaugpej(defn, "diminutive of", pos)
			elseif rfind(defn, "^end:") then
				defnline = generate_dimaugpej(defn, "endearing form of", pos)
			elseif rfind(defn, "^enddim:") then
				defnline = generate_dimaugpej(defn, "endearing diminutive of", pos)
			elseif rfind(defn, "^aug:") then
				defnline = generate_dimaugpej(defn, "augmentative of", pos)
			elseif rfind(defn, "^pej:") then
				defnline = generate_dimaugpej(defn, "pejorative of", pos)
			elseif rfind(defn, "^gn:") then
				local gnparts = rsplit(defn, ":")
				if #gnparts ~= 2 then
					error("Wrong number of given-name parts for " .. defn)
				end
				defnline = "{{given name|lang=ru|" .. gnparts[2] .. "}}"
			else
				defnline = defn
			end
			defnline = rsub(defnline, "%(%((.@)%)%)", "%1")
			defnline = rsub(defnline, "g%((.@)%)", "{{glossary|%1}}")
			table.insert(defnlines, "# " .. prefix .. defnline .. "\n")
		end
	end
	return table.concat(defnlines, "")
end

local function handle_synant(args, satype)
	local lines = {}
	for _, arg in ipairs(args) do
		for _, synantgroup in ipairs(do_split(arg, ";")) do
			local sensetext = ""
			local tag, words = rmatch(synantgroup, "^%*?%((.-)%)(.*)$")
			if tag then
				sensetext = "{{sense|" .. tag .. "}} "
			else
				words = rmatch(synantgroup, "^%*(.*)$")
				if words then
					sensetext = "{{sense|FIXME}} "
				else
					sensetext = ""
					words = synantgroup
				end
			end
			local links = {}
			for _, synant in ipairs(do_split(words, ",")) do
				-- FIXME, won't work easily due to difficulty in inserting literal
				-- braces into templates
				if rfind(synant, "^%{") then
					table.insert(links, synant)
				else
					check_stress(synant)
					table.insert(links, "{{l|ru|" .. synant .. "}}")
				end
			end
			table.insert(lines, "* " .. sensetext .. table.concat(links, ", ") .. "\n")
		end
	end
	return "====" .. (satype == "syn" and "Synonyms" or "Antonyms") .. "====\n" ..
		table.concat(lines, "") .. "\n"
end

local function handle_pron(args)
	local lines = {}
	
	for _, arg in ipairs(args) do
		for _, pron in ipairs(do_split(arg, ",")) do
			check_stress(pron)
			table.insert(lines, "* {{ru-IPA|" .. pron .. "}}\n")
		end
		return table.concat(lines, "")
	end
end

local function handle_alt(args)
	local lines = {}
	for _, arg in ipairs(args) do
		for _, altform in ipairs(do_split(",", vals)) do
			if rfind(altform, "^%{") then
				table.insert(lines, "* " .. altform .. "\n")
			else
				check_stress(altform)
				table.insert(lines, "* {{l|ru|" .. altform .. "}}\n")
			end
		end
	end
	return "====Alternative forms====\n" .. table.concat(lines, "") .. "\n"
end

local function handle_alt(args)
	local lines = {}
	for _, arg in ipairs(args) do
		for _, altform in ipairs(do_split(",", vals)) do
			if rfind(altform, "^%{") then
				table.insert(lines, "* " .. altform .. "\n")
			else
				check_stress(altform)
				table.insert(lines, "* {{l|ru|" .. altform .. "}}\n")
			end
		end
	end
	return "====Alternative forms====\n" .. table.concat(lines, "") .. "\n"
end

local function handle_usage(arg)
	if arg then
		return "====Usage notes====\n" .. arg .. "\n\n"
	else
		return ""
	end
end

local function handle_wiki(args)
	local lines = {}
	for _, arg in ipairs(args) do
		for _, val in ipairs(do_split(arg, ",")) do
			if val ~= "-" then
				table.insert(lines, "{{wikipedia|lang=ru|" .. val .. "}}\n")
			else
				table.insert(lines, "{{wikipedia|lang=ru}}\n")
			end
		end
	end
	return table.concat(lines, "")
end

local function handle_enwiki(arg)
	local lines = {}
	for _, arg in ipairs(args) do
		for _, val in ipairs(do_split(arg, ",")) do
			table.insert(lines, "{{wikipedia|" .. val .. "}}\n")
		end
	end
	return table.concat(lines, "")
end			

local function handle_derrelsee(arg, drstype, data)
	local lines = {}
	for _, arg in ipairs(args) do
		if arg == "-" then
			continue
		end
		for _, derrelgroup in ipairs(do_split(arg, ",")) do
			local links = {}
			for _, derrel in ipairs(do_split(derrelgroup, ":")) do
				-- Handle #ref, which we replace with the corresponding reflexive
				-- verb pair for non-reflexive verbs and vice-versa
				local gender_arg = data.headword_aspect == "both" and "|g=impf|g2=pf" or
					"|g=" .. data.headword_aspect
				if rfind(derrel, "#ref") then
					if data.translit then
						-- FIXME
						error("Unable yet to handle translit with #ref")
					end
					-- * at the beginning of an aspect-paired verb forces
					-- imperfective; used with aspect "both"
					local corverb_impf_override = false
					for _, corverb in ipairs(data.corverbs) do
						if rfind(corverb, "^%*") then
							corverb_impf_override = true
							break
						end
					end
					local refverb
					local correfverbs = {}
					if data.isrefl then
						refverb = rsub(data.verb, "с[ья]$", "") .. gender_arg
						for _, corverb in ipairs(data.corverbs) do
							local corverb_base = rsub(rsub(corverb, "%^*", ""), "с[ья]$", "")
							local corverb_aspect = (data.headword_aspect == "pf" or rfind(corverb, "^%*")) and
								"impf" or "pf"
							table.insert(correfverbs, corverb_base .. "|g=" .. corverb_aspect)
						end
					else
						refverb = rfind(data.verb, "и́?$") and data.verb .. "сь" or
							com.try_to_stress(data.verb) .. "ся" .. gender_arg
						for _, corverb in ipairs(data.corverbs) do
							local impf_override = rfind(corverb, "^%*")
							corverb = rsub(corverb, "^%*", "")
							local corverb_base = rfind(corverb, "и́?$") and corverb .. "сь" or
								com.try_to_stress(data.verb) .. "ся"
							local corverb_aspect = (data.headword_aspect == "pf" or impf_override) and
								"impf" or "pf"
							table.insert(correfverbs, corverb_base .. "|g=" .. corverb_aspect)
						end
					end
					if data.headword_aspect == "pf" or corverb_impf_override then
						table.insert(correfverbs, refverb)
					else
						table.insert(correfverbs, 0, refverb)
					end
					derrel = rsub(derrel, "#ref", table.concat(correfverbs, "/"))
				end

				if rfind(derrel, "/") then
					local impfpfverbs = do_split(derrel, "/")
					for index, impfpfverb in ipairs(impfpfverbs) do
						check_stress(impfpfverb)
						local aspect = index == 1 and "impf" or "pf"
						if rfind(impfpfverb, "|") then
							table.insert(links, "{{l|ru|" .. impfpfverb .. "}}")
						else
							table.insert(links, "{{l|ru|" .. impfpfverb .. "|g=" .. aspect .. "}}")
						end
					end
				else
					check_stress(derrel)
					table.insert(links, "{{l|ru|" .. derrel .. "}})
				end
			end
		end
		table.insert(lines, "* " .. table.concat(links, ", ") .. "\n")
	end
	local header = drstype == "der" and "Derived terms" or drstype == "rel" and "Related terms" or "See also"
	return "====" .. header .. "====\n" .. table.concat(lines, "") .. "\n"
end

local function generate_verb_args(conj_args, verbbase, trverbbase)
	if #conj_args == 1 then
		local conj = conj_args[1]
		local origverbbase = verbbase
		local origtrverbbase = trverbbase
		local check_and_chop(regex, trregex)
			if not rfind(verbbase, regex) then
				error("Type " .. conj .. " verb " .. verbbase .. " doesn't end as expected, should match regex " .. regex)
			end
			verbbase = rsub(verbbase, regex, "")
			if trverbbase then
				if not trregex then
					error("For type " .. conj .. "verbs, manual translit not allowed")
				elseif not rfind(trverbbase, trregex) then
					error("Type " .. conj .. " verb " .. verbbase .. " doesn't end as expected, should match regex " .. trregex)
				end
				trverbbase = rsub(trverbbase, trregex, "")
			end
		end
			
		if rfind(conj, "^6[°o]?a") then
			check_and_chop("[ая]ть$")
			args = {verbbase}
		elseif rfind(conj, "^6[°o]?b") then
			if com.is_monosyllabic(verbbase) then
				check_and_chop("[ая]́?ть$")
			else
				check_and_chop("[ая]́ть$")
			end
			args = {verbbase}
		elseif rfind(conj, "^6[°o]?c") then
			if com.is_monosyllabic(verbbase) then
				check_and_chop("[ая]́?ть$")
			else
				check_and_chop("[ая]́ть$")
			end
			args = {com.make_ending_stressed(verbbase)}
		elseif rfind(conj, "^5a") then
			check_and_chop("[еая]ть$")
			args = {verbbase, com.try_to_stress(rsub(origverbbase, "ть$", ""))}
		elseif rfind(conj, "^5b") then
			if com.is_monosyllabic(verbbase) then
				check_and_chop("[еая]́?ть$")
			else
				check_and_chop("[еая]́ть$")
			end
			args = {verbbase, rsub(origverbbase, "ть$", "")}
		elseif rfind(conj, "^5c") then
			if com.is_monosyllabic(verbbase) then
				check_and_chop("[еая]́?ть$")
			else
				check_and_chop("[еая]́ть$")
			end
			args = {com.make_ending_stressed(verbbase), com.try_to_stress(rsub(origverbbase, "ть$", ""))}
		elseif rfind(conj, "^4a") then
			check_and_chop("ить$", "itʹ$")
			args = {verbbase .. (trverbbase and "//" .. trverbbase or "")}
		elseif rfind(conj, "^4b") then
			check_and_chop("ить$", "itʹ$")
			if com.is_monosyllabic(verbbase) then
				check_and_chop("и́?ть$", "i" .. AC .. "?tʹ$")
			else
				check_and_chop("и́ть$", "i" .. AC .. "tʹ$")
			end
			args = {verbbase .. (trverbbase and "//" .. trverbbase or "")}
		elseif rfind(conj, "^4c") then
			check_and_chop("ить$", "itʹ$")
			if com.is_monosyllabic(verbbase) then
				check_and_chop("и́?ть$", "i" .. AC .. "?tʹ$")
			else
				check_and_chop("и́ть$", "i" .. AC .. "tʹ$")
			end
			verbbase, trverbbase = com.make_ending_stressed(verbbase, trverbbase)
			args = {verbbase .. (trverbbase and "//" .. trverbbase or "")}
		elseif rfind(conj, "^3[°o]?a") then
			check_and_chop("нуть$")
			args = {verbbase}
		elseif rfind(conj, "^3b") then
			if com.is_monosyllabic(verbbase) then
				check_and_chop("ну́?ть$")
			else
				check_and_chop("ну́ть$")
			end
			args = {verbbase .. "н"}
		elseif rfind(conj, "^3c") then
			if com.is_monosyllabic(verbbase) then
				check_and_chop("ну́?ть$")
			else
				check_and_chop("ну́ть$")
			end
			args = {com.make_ending_stressed(verbbase) .. "н"}
		elseif rfind(conj, "^2[ab]") then
			-- check and chop only for checking, then restore original
			check_and_chop("ва́?ть$", "va" .. AC .. "?tʹ$")
			verbbase, trverbbase = origverbbase, origtrverbbase
			check_and_chop("ть$", "tʹ$")
			args = {verbbase .. (trverbbase and "//" .. trverbbase or "")}
		elseif rfind(conj, "^1a") then
			check_and_chop("ть$", "tʹ$")
			args = {verbbase .. (trverbbase and "//" .. trverbbase or "")}
		else
			error("Unrecognized conjugation type and no arguments: " .. conj)
		end
		table.insert(args, 1, conj)
		return args
	end
	return conj_args
end			

local function do_verb(args)
	subs = {}
	local data = {}
	data.verb = args[2]
	data.defn = args[3]
	data.aspect = args[4]
	data.corverbs = args[5]
	data.conj = {}
	for i = 6, 20 do
		table.insert(data.conj, args[i])
	end
	data.translit = nil
	if rfind(data.verb, "//") then
		local bases = rsplit(data.verb, "//")
		if #bases ~= 2 then
			error("Verb with manual translit should have only one //: " .. data.verb)
		data.verb, data.translit = bases[1], bases[2]
	end
	subs.pron = "* {{ru-IPA|" .. verb .. "}}\n"
	data.verb = rsub(com.decompose(data.verb), "[" .. GR .. CFLEX .. DOTABOVE .. DOTBELOW .. "]", "")
	if data.translit then
		data.translit = rsub(com.decompose(data.translit), "[" .. GR .. CFLEX .. DOTABOVE .. DOTBELOW .. "]", "")
	end
	subs.verb = data.verb
	if not rfind(data.verb, "ть$") and not rfind(data.verb, "ться$") and not rfind(data.verb, "ти́$") and
		not rfind(data.verb, "ти́сь$") and not rfind(data.verb, "чь$") and not rfind(data.verb, "чься$") then
		error("Lemma " .. data.verb .. " doesn't look like a verb infinitive")
	end
	check_stress(data.verb)
	subs.tr = data.translit and "|tr=" .. data.translit or ""
	data.isrefl = rfind(data.verb, "с[яь]$")
	subs.headword_aspect = rsub(data.aspect, "%-.*", "")
	if not ut.contains({"pf", "impf", "both"}, subs.headword_aspect) then
		error("Headword aspect " .. subs.headword_aspect .. " should be pf, impf or both")
	end
	if data.corverbs == "-" then
		data.corverbs = {}
	else
		data.corverbs = do_split(corverbs, ",")
	end
	subs.corverb = ""
	for corverbno, corverb in ipairs(data.corverbs) do
		check_stress(corverb)
		subs.corverb = subs.corverb + "|" + ((subs.headword_aspect == "pf" or rfind(corverb, "^%*")) and "impf" or "pf") +
			(corverbno == 1 and "" or corverbno) + "="
			rsub(corverb, "^%*", ""
	data.verbbase = rsub(verb, "с[яь]$", "")
	data.trverbbase = data.translit and (rfind(data.translit, "sja$") and rsub(data.translit, "sja$", "") or
		rsub(data.translit, "sʹ$", ""))
	subs.passive = args.e == "r" and "# {{passive of|lang=ru|" .. data.verbbase ..
		(data.trverbbase and "|tr=" .. data.trverbbase or "") .. "}}\n" or ""

	data.reflsuf = data.isrefl and "-refl" or ""
	local function order_aspect(aspect)
		return rsub(aspect, "-impers-refl", "-refl-impers")
	end
	data.conjargs = generate_verb_args(data.conj, data.verbbase, data.trverbbase)
	data.conjstr = table.concat(data.conjargs, "|")
	if rfind(data.aspect, "^both") then
		local pfaspect = rsub(data.aspect, "^both", "pf")
		local impfaspect = rsub(aspect, "^both", "impf")
		local subsub = {
			impfaspect = order_aspect(impfaspect .. data.reflsuf),
			pfaspect = order_aspect(pfaspect .. data.reflsuf),
			conj = data.conjstr,
		}
		sub.conj = strutils.format([===[
''imperfective''
{\op}{\op}ru-conj|{pfaspect}{conj}{\cl}{\cl}
''perfective''
{\op}{\op}ru-conj|{impfaspect}{conj}{\cl}{\cl}]===], subsub)
	else
		sub.conj = "{{ru-conj|" .. order_aspect(data.aspect .. data.reflsuf) .. "|" .. data.conjstr .. "}}"
	end

	sub.etym = handle_etym(args.e, data)
	sub.alt = handle_alt(process_arg_chain(args, "alt"))
	sub.usage = handle_usage(args.usage)
	sub.syn = handle_synant(process_arg_chain(args, "syn"), "syn")
	sub.ant = handle_synant(process_arg_chain(args, "ant"), "ant")
	sub.der = handle_derrelsee(process_arg_chain(args, "der"), "der", data)
	sub.rel = handle_derrelsee(process_arg_chain(args, "rel"), "rel", data)
	sub.see = handle_derrelsee(process_arg_chain(args, "see"), "see", data)
	local prons = process_arg_chain(args, "pron")
	if #prons == 0 then
		prons = {data.verb}
	end
	sub.pron = handle_pron(prons)
	sub.defn = handle_defn(args.def, "verb")
	sub.note = handle_note(process_arg_chain(args, "note"))
	sub.wiki = handle_wiki(process_arg_chain(args, "wiki"))
	sub.enwiki = handle_enwiki(process_arg_chain(args, "enwiki"))
	
	return strutils.format([===[
==Russian==

{alt}{etym}===Pronunciation===
{pron}
===Verb===
{\op}{\op}ru-verb|{verb}{tr}|{headword_aspect}{corverb}{\cl}{\cl}

{defn}{passive}
====Conjugation====
{conj}

{syn}{ant}{der}{rel}{see}
]===], subs)

local function do_non_verb(args, pos)
	subs = {}
	local data = {}
	data.term = args[2]
	data.defn = args[3]
	data.decl = {}
	for i = 4, 20 do
		table.insert(data.decl, args[i])
	end
	data.translit = nil
	if rfind(data.term, "//") then
		local bases = rsplit(data.term, "//")
		if #bases ~= 2 then
			error("Term with manual translit should have only one //: " .. data.term)
		data.term, data.translit = bases[1], bases[2]
	end
	-- The original term may have translit, links and/or secondary/tertiary accents.
	-- For pronunciation purposes, we remove the translit and links but keep the
	-- secondary/tertiary accents. For declension purposes, we remove the
	-- secondary/tertiary accents but keep the translit and links. For headword
	-- purposes (other than ru-noun+), we remove everything (but still leave
	-- primary accents).
	local pronterm = m_links.remove_links(data.term)
	data.term = rsub(com.decompose(data.term), "[" .. GR .. CFLEX .. DOTABOVE .. DOTBELOW .. "]", "")
	if data.translit then
		data.translit = rsub(com.decompose(data.translit), "[" .. GR .. CFLEX .. DOTABOVE .. DOTBELOW .. "]", "")
	end
	data.declterm = data.translit and data.term .. "//" .. data.translit or data.term
	data.term = m_links.remove_links(data.term)
	local adj_endings = {
		"ый",
		"ыйся",
		"ий",
		"ийся",
		"о́й",
		"ойся",
		"[оеё]́?в",
		"и́?н",
	}
	if pos == "adj" then
		local saw_ending = false
		for _, ending in ipairs(adj_endings) do
			if rfind(data.term, ending .. "$") then
				saw_ending = true
				break
			end
		end
		if not saw_ending then
			error("Invalid adjective term, unrecognized ending: " .. data.term)
		end
	end
	data.trtext = data.translit and "|tr=" .. data.translit or ""
	check_stress(data.term)
		
	subs.verb = data.verb


	data.term = rsub(com.decompose(data.verb), "[" .. GR .. CFLEX .. DOTABOVE .. DOTBELOW .. "]", "")
	subs.verb = data.verb
	if not rfind(data.verb, "ть$") and not rfind(data.verb, "ться$") and not rfind(data.verb, "ти́$") and
		not rfind(data.verb, "ти́сь$") and not rfind(data.verb, "чь$") and not rfind(data.verb, "чься$") then
		error("Lemma " .. data.verb .. " doesn't look like a verb infinitive")
	end
	check_stress(data.verb)
	subs.tr = data.translit and "|tr=" .. data.translit or ""
	data.isrefl = rfind(data.verb, "с[яь]$")
	subs.headword_aspect = rsub(data.aspect, "%-.*", "")
	if not ut.contains({"pf", "impf", "both"}, subs.headword_aspect) then
		error("Headword aspect " .. subs.headword_aspect .. " should be pf, impf or both")
	end
	if data.corverbs == "-" then
		data.corverbs = {}
	else
		data.corverbs = do_split(corverbs, ",")
	end
	subs.corverb = ""
	for corverbno, corverb in ipairs(data.corverbs) do
		check_stress(corverb)
		subs.corverb = subs.corverb + "|" + ((subs.headword_aspect == "pf" or rfind(corverb, "^%*")) and "impf" or "pf") +
			(corverbno == 1 and "" or corverbno) + "="
			rsub(corverb, "^%*", ""
	data.verbbase = rsub(verb, "с[яь]$", "")
	data.trverbbase = data.translit and (rfind(data.translit, "sja$") and rsub(data.translit, "sja$", "") or
		rsub(data.translit, "sʹ$", ""))
	subs.passive = args.e == "r" and "# {{passive of|lang=ru|" .. data.verbbase ..
		(data.trverbbase and "|tr=" .. data.trverbbase or "") .. "}}\n" or ""

	data.reflsuf = data.isrefl and "-refl" or ""
	local function order_aspect(aspect)
		return rsub(aspect, "-impers-refl", "-refl-impers")
	end
	data.conjargs = generate_verb_args(data.conj, data.verbbase, data.trverbbase)
	data.conjstr = table.concat(data.conjargs, "|")
	if rfind(data.aspect, "^both") then
		local pfaspect = rsub(data.aspect, "^both", "pf")
		local impfaspect = rsub(aspect, "^both", "impf")
		local subsub = {
			impfaspect = order_aspect(impfaspect .. data.reflsuf),
			pfaspect = order_aspect(pfaspect .. data.reflsuf),
			conj = data.conjstr,
		}
		sub.conj = strutils.format([===[
''imperfective''
{\op}{\op}ru-conj|{pfaspect}{conj}{\cl}{\cl}
''perfective''
{\op}{\op}ru-conj|{impfaspect}{conj}{\cl}{\cl}]===], subsub)
	else
		sub.conj = "{{ru-conj|" .. order_aspect(data.aspect .. data.reflsuf) .. "|" .. data.conjstr .. "}}"
	end

	sub.alt = handle_alt(process_arg_chain(args, "alt"))
	sub.usage = handle_usage(args.usage)
	sub.syn = handle_synant(process_arg_chain(args, "syn"), "syn")
	sub.ant = handle_synant(process_arg_chain(args, "ant"), "ant")
	sub.der = handle_derrelsee(process_arg_chain(args, "der"), "der", data)
	sub.rel = handle_derrelsee(process_arg_chain(args, "rel"), "rel", data)
	sub.see = handle_derrelsee(process_arg_chain(args, "see"), "see", data)
	local prons = process_arg_chain(args, "pron")
	if #prons == 0 then
		sub.pron = handle_pron(prons)
	end
	sub.defn = handle_defn(args.def, "verb")
	sub.note = handle_note(process_arg_chain(args, "note"))
	sub.wiki = handle_wiki(process_arg_chain(args, "wiki"))
	sub.enwiki = handle_enwiki(process_arg_chain(args, "enwiki"))
	
	return strutils.format([===[
==Russian==

{alt}{etym}===Pronunciation===
{pron}
===Verb===
{\op}{\op}ru-verb|{verb}{tr}|{headword_aspect}{corverb}{\cl}{\cl}

{defn}{passive}
====Conjugation====
{conj}

{syn}{ant}{der}{rel}{see}
]===], subs)	

-- The main entry point.
function export.new(frame)
	local args = clone_args(frame)
	if pos == "verb" then
		return do_verb(args)
	elseif pos == "noun" then
		return do_noun(args)
	elseif pos == "adj" then
		return do_adj(args)
	else
		return do_misc_pos(args, pos)
	end
end

return export

-- For Vim, so we get 4-space tabs
-- vim: set ts=4 sw=4 noet:
