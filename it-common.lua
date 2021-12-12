local export = {}

local u = mw.ustring.char
local rfind = mw.ustring.find
local rsubn = mw.ustring.gsub
local rmatch = mw.ustring.match
local rsplit = mw.text.split
local ulower = mw.ustring.lower
local uupper = mw.ustring.upper
local usub = mw.ustring.sub
local ulen = mw.ustring.len
local unfd = mw.ustring.toNFD
local unfc = mw.ustring.toNFC

export.GR = u(0x0300)
export.TEMP_QU = u(0xFFF1)
export.TEMP_GU = u(0xFFF2)
export.TEMP_U_IN_AU = u(0xFFF3)
export.V = "[aeiou]"
export.NV = "[^aeiou]"
export.AV = "[àèéìòóù]"

export.explicit_slots = { "imperf", "fut", "sub", "impsub", "imp" }

-- version of rsubn() that discards all but the first return value
local function rsub(term, foo, bar)
	local retval = rsubn(term, foo, bar)
	return retval
end

function export.remove_accents(form)
	return rsub(form, export.AV, function(v) return usub(unfd(v), 1, 1) end)
end

-- Add the `stem` to the `ending` for the given `slot` and apply any phonetic modifications.
function export.combine_stem_ending(base, slot, stem, ending)
	-- Add h after c/g in -are forms to preserve the sound.
	if base.conj_vowel == "à" and stem:find("[cg]$") and rfind(ending, "^[eèéiì]") then
		stem = stem .. "h"
	end

	-- Two unstressed i's coming together compress to one.
	if ending:find("^i") then
		stem = stem:gsub("i$", "")
	end

	-- Remove accents from stem if ending is accented.
	if rfind(ending, com.AV) then
		stem = com.remove_accents(stem)
	end

	return stem .. ending
end

function export.analyze_verb(lemma)
	local is_pronominal = false
	local is_reflexive = false
	-- The particles that can go after a verb are:
	-- * la, le
	-- * ne
	-- * ci, vi (sometimes in the form ce, ve)
	-- * si (sometimes in the form se)
	-- Observed combinations:
	--   * ce + la: [[avercela]] "to be angry (at someone)", [[farcela]] "to make it, to succeed",
	--              [[mettercela tutta]] "to put everything (into something)"
	--   * se + la: [[sbrigarsela]] "to deal with", [[bersela]] "to naively believe in",
	--              [[sentirsela]] "to have the courage to face (a difficult situation)",
	--              [[spassarsela]] "to live it up", [[svignarsela]] "to scurry away",
	--              [[squagliarsela]] "to vamoose, to clear off", [[cercarsela]] "to be looking for (trouble etc.)",
	--              [[contarsela]] "to have a distortedly positive self-image; to chat at length",
	--              [[dormirsela]] "to be fast asleep", [[filarsela]] "to slip away, to scram",
	--              [[giostrarsela]] "to get away with; to turn a situation to one's advantage",
	--              [[cavarsela]] "to get away with; to get out of (trouble); to make the best of; to manage (to do); to be good at",
	--              [[meritarsela]] "to get one's comeuppance", [[passarsela]] "to fare (well, badly)",
	--              [[rifarsela]] "to take revenge", [[sbirbarsela]] "to slide by (in life)",
	--              [[farsela]]/[[intendersela]] "to have a secret affair or relationship with",
	--              [[farsela addosso]] "to shit oneself", [[prendersela]] "to take offense at; to blame",
	--              [[prendersela comoda]] "to take one's time", [[sbrigarsela]] "to finish up; to get out of (a difficult situation)",
	--              [[tirarsela]] "to lord it over", [[godersela]] "to enjoy", [[vedersela]] "to see (something) through",
	--              [[vedersela brutta]] "to have a hard time with; to be in a bad situation",
	--              [[aversela]] "to pick on (someone)", [[battersela]] "to run away, to sneak away",
	--              [[darsela a gambe]] "to run away", [[fumarsela]] "to sneak away",
	--              [[giocarsela]] "to behave (a certain way); to strategize; to play"
	--   * se + ne: [[andarsene]] "to take leave", [[approfittarsene]] "to take advantage of",
	--              [[fottersene]]/[[strafottersene]] "to not give a fuck",
	--              [[fregarsene]]/[[strafregarsene]] "to not give a damn",
	--              [[guardarsene]] "to beware; to think twice", [[impiparsene]] "to not give a damn",
	--              [[morirsene]] "to fade away; to die a lingering death", [[ridersene]] "to laugh at; to not give a damn",
	--              [[ritornarsene]] "to return to", [[sbattersene]]/[[strabattersene]] "to not give a damn",
	--              [[infischiarsene]] "to not give a damn", [[stropicciarsene]] "to not give a damn",
	--              [[sbarazzarsene]] "to get rid of, to bump off", [[andarsene in acqua]] "to be diluted; to decay",
	--              [[nutrirsene]] "to feed oneself", [[curarsene]] "to take care of",
	--              [[intendersene]] "to be an expert (in)", [[tornarsene]] "to return, to go back",
	--              [[starsene]] "to stay", [[farsene]] "to matter; to (not) consider; to use",
	--              [[farsene una ragione]] "to resign; to give up; to come to terms with; to settle (a dispute)",
	--              [[riuscirsene]] "to repeat (something annoying)", [[venirsene]] "to arrive slowly; to leave"
	--   * ci + si: [[trovarcisi]] "to find oneself in a happy situation",
	--              [[vedercisi]] "to imagine oneself (in a situation)", [[sentircisi]] "to feel at ease"
	--   * vi + si: [[recarvisi]] "to go there"
	--
	local ret = {}
	local linked_suf, finite_pref, finite_pref_ho
	local clitic_to_finite = {ce = "ce", ve = "ve", se = "me"}
	local verb, clitic, clitic2 = rmatch(lemma, "^(.-)([cvs]e)(l[ae])$")
	if verb then
		linked_suf = "[[" .. clitic .. "]][[" .. clitic2 .. "]]"
		finite_pref = "[[" .. clitic_to_finite[clitic] .. "]] [[" .. clitic2 .. "]] "
		finite_pref_ho = "[[" .. clitic_to_finite[clitic] .. "]] [[l']]"
		is_pronominal = true
		is_reflexive = clitic == "se"
	end
	if not verb then
		verb, clitic = rmatch(lemma, "^(.-)([cvs]e)ne$")
		if verb then
			linked_suf = "[[" .. clitic .. "]][[ne]]"
			finite_pref = "[[" .. clitic_to_finite[clitic] .. "]] [[ne]] "
			finite_pref_ho = "[[" .. clitic_to_finite[clitic] .. "]] [[n']]"
			is_pronominal = true
			is_reflexive = clitic == "se"
		end
	end
	if not verb then
		verb, clitic = rmatch(lemma, "^(.-)([cv]i)si$")
		if verb then
			linked_suf = "[[" .. clitic .. "]][[si]]"
			finite_pref = "[[mi]] [[" .. clitic .. "]] "
			if clitic == "vi" then
				finite_pref_ho = "[[mi]] [[v']]"
			else
				finite_pref_ho = "[[mi]] [[ci]] "
			end
			is_pronominal = true
			is_reflexive = true
		end
	end
	if not verb then
		verb, clitic = rmatch(lemma, "^(.-)([cv]i)$")
		if verb then
			linked_suf = "[[" .. clitic .. "]]"
			finite_pref = "[[" .. clitic .. "]] "
			if clitic == "vi" then
				finite_pref_ho = "[[v']]"
			else
				finite_pref_ho = "[[ci]] "
			end
			is_pronominal = true
		end
	end
	if not verb then
		verb = rmatch(lemma, "^(.-)si$")
		if verb then
			linked_suf = "[[si]]"
			finite_pref = "[[mi]] "
			finite_pref_ho = "[[m']]"
			-- not pronominal
			is_reflexive = true
		end
	end
	if not verb then
		verb = rmatch(lemma, "^(.-)ne$")
		if verb then
			linked_suf = "[[ne]]"
			finite_pref = "[[ne]] "
			finite_pref_ho = "[[n']]"
			is_pronominal = true
		end
	end
	if not verb then
		verb, clitic = rmatch(lemma, "^(.-)(l[ae])$")
		if verb then
			linked_suf = "[[" .. clitic .. "]]"
			finite_pref = "[[" .. clitic .. "]] "
			finite_pref_ho = "[[l']]"
			is_pronominal = true
		end
	end
	if not verb then
		verb = lemma
		linked_suf = ""
		finite_pref = ""
		finite_pref_ho = ""
		-- not pronominal
	end

	ret.raw_verb = verb
	ret.linked_suf = linked_suf
	ret.finite_pref = finite_pref
	ret.finite_pref_ho = finite_pref_ho
	ret.is_pronominal = is_pronominal
	ret.is_reflexive = is_reflexive
	return ret
end

function export.add_default_verb_forms(iut, base, from_headword)
	local ret = base.verb
	local raw_verb = ret.raw_verb

	if rfind(raw_verb, "r$") then
		if rfind(raw_verb, "[ou]r$") or base.rre then
			ret.verb = raw_verb .. "re"
		else
			ret.verb = raw_verb .. "e"
		end
	else
		ret.verb = raw_verb
	end

	local stems, conj_vowel
	if base.explicit_stem then
		stems = iut.map_forms(base.explicit_stem, function(form)
			local stem, ending = rmatch(form, "^(.*)([aei])$")
			if not stem then
				error("Unrecognized stem '" .. form .. "', should end in -a, -e or -i")
			end
			if conj_vowel and conj_vowel ~= ending then
				error("Can't currently specify explicit stems with two different conjugation vowels (" .. conj_vowel
					.. " and " .. ending .. ")")
			end
			conj_vowel = ending
			return stem
		end
	else
		stems, conj_vowel = rmatch(raw_verb, "^(.-)([aeiour])re?$")
		if not stems then
			error("Unrecognized verb '" .. raw_verb .. "', doesn't end in -are, -ere, -ire, -rre, -ar, -er, -ir, -or or -ur")
		end
		stems = iut.convert_to_general_list_form(stems)
		if not rfind(conj_vowel, "^[aei]$") then
			base.rre = true
		end
		if base.rre then
			if not from_headword then
				error("With syncopated verb '" .. raw_verb .. "', must use stem: to specify an explicit stem")
			else
				conj_vowel = "e"
			end
		end
	end

	ret.stem = stems
	base.conj_vowel = conj_vowel == "a" and "à" or conj_vowel == "e" and "é" or "ì"

	if base.rre then
		-- Can't generate defaults for verbs in -rre
		return
	end

	local unaccented_stems = iut.map_forms(stems, function(stem) return export.remove_accents(stem) end)
	ret.unaccented_stem = unaccented_stems
	ret.pres = iut.map_forms(stems, function(stem)
		if base.third then
			return conj_vowel == "a" and stem .. "a" or stem .. "e"
		else
			return stem .. "o"
		end
	end)
	ret.pres3s = iut.map_forms(stems, function(stem) return conj_vowel == "a" and stem .. "a" or stem .. "e" end)
	if conj_vowel == "i" then
		ret.isc_pres = iut.map_forms(unaccented_stems, function(stem) return stem .. "ìsco" end)
		ret.isc_pres3s = iut.map_forms(unaccented_stems, function(stem) return stem .. "ìsci" end)
	end
	ret.past = iut.flatmap_forms(unaccented_stems, function(stem)
		if conj_vowel == "a" then
			return {stem .. (base.third and "ò" or "ài")}
		elseif conj_vowel == "e" then
			return {stem .. (base.third and "é" or "éi"), stem .. (base.third and "ètte" or "ètti")}
		else
			return {stem .. (base.third and "ì" or "ìi")}
		end
	end)
	ret.pp = iut.map_forms(unaccented_stems, function(stem)
		if conj_vowel == "a" then
			return stem .. "àto"
		elseif conj_vowel == "e" then
			return rfind(stem, "[cg]$") and stem .. "iùto" or stem .. "ùto"
		else
			return stem .. "ìto"
		end
	end)
end

-- Add links around words. If multiword_only, do it only in multiword forms.
function export.add_links(form, multiword_only)
	if form == "" or form == " " then
		return form
	end
	if not form:find("%[%[") then
		if rfind(form, "[%s%p]") then --optimization to avoid loading [[Module:headword]] on single-word forms
			local m_headword = require("Module:headword")
			if m_headword.head_is_multiword(form) then
				form = m_headword.add_multiword_links(form)
			end
		end
		if not multiword_only and not form:find("%[%[") then
			form = "[[" .. form .. "]]"
		end
	end
	return form
end

function export.strip_spaces(text)
	return text:gsub("^%s*(.-)%s*", "%1")
end

local function check_not_null(base, form)
	if form == nil then
		error("Default forms cannot be derived from '" .. base.lemma .. "'")
	end
end

-- Given an unaccented stem, pull out the last two vowels as well as the in-between stuff, and return
-- before, v1, between, v2, after as 5 return values. You must undo the TEMP_QU, TEMP_GU and TEMP_U_IN_AU
-- substitutions made in before/between/after if you want to use them. `unaccented` is the full verb and
-- `unaccented_desc` a description of where the verb came from; used only in error messages.
local function analyze_stem_for_last_two_vowels(unaccented_stem, unaccented, unaccented_desc)
	unaccented_stem = rsub(unaccented_stem, "qu", export.TEMP_QU)
	unaccented_stem = rsub(unaccented_stem, "gu(" .. export.V .. ")", export.TEMP_GU .. "%1")
	unaccented_stem = rsub(unaccented_stem, "au(" .. export.NV .. "*" .. export.V .. export.NV .. "*)$", "a" .. export.TEMP_U_IN_AU .. "%1")
	local before, v1, between, v2, after = rmatch(unaccented_stem, "^(.*)(" .. export.V .. ")(" .. export.NV .. "*)(" .. export.V .. ")(" .. export.NV .. "*)$")
	if not before then
		before, v1 = "", ""
		between, v2, after = rmatch(unaccented_stem, "^(.*)(" .. export.V .. ")(" .. export.NV .. "*)$")
	end
	if not between then
		error("No vowel in " .. unaccented_desc .. " '" .. unaccented .. "' to match")
	end
	return before, v1, between, v2, after
end

-- Apply a single-vowel spec in `form`, e.g. é+, to `unaccented_stem`. `unaccented` is the full verb and
-- `unaccented_desc` a description of where the verb came from; used only in error messages.
local function apply_vowel_spec(unaccented_stem, unaccented, unaccented_desc, form)
	local before, v1, between, v2, after = analyze_stem_for_last_two_vowels(unaccented_stem, unaccented, unaccented_desc)
	if v1 == v2 then
		local form_vowel, first_second = rmatch(form, "^(.)([+-])$")
		if not form_vowel then
			error("Last two stem vowels of " .. unaccented_desc .. " '" .. unaccented ..
				"' are the same; you must specify + (second vowel) or - (first vowel) after the vowel spec '" ..
				form .. "'")
		end
		local raw_form_vowel = usub(unfd(form_vowel), 1, 1)
		if raw_form_vowel ~= v1 then
			error("Vowel spec '" .. form .. "' doesn't match vowel of " .. unaccented_desc .. " '" .. unaccented .. "'")
		end
		if first_second == "-" then
			form = before .. form_vowel .. between .. v2 .. after
		else
			form = before .. v1 .. between .. form_vowel .. after
		end
	else
		if rfind(form, "[+-]$") then
			error("Last two stem vowels of " .. unaccented_desc .. " '" .. unaccented ..
				"' are different; specify just an accented vowel, without a following + or -: '" .. form .. "'")
		end
		local raw_form_vowel = usub(unfd(form), 1, 1)
		if raw_form_vowel == v1 then
			form = before .. form .. between .. v2 .. after
		elseif raw_form_vowel == v2 then
			form = before .. v1 .. between .. form .. after
		elseif before == "" then
			error("Vowel spec '" .. form .. "' doesn't match vowel of " .. unaccented_desc .. " '" .. unaccented .. "'")
		else
			error("Vowel spec '" .. form .. "' doesn't match either of the last two vowels of " .. unaccented_desc ..
				" '" .. unaccented .. "'")
		end
	end
	form = rsub(form, export.TEMP_QU, "qu")
	form = rsub(form, export.TEMP_GU, "gu")
	form = rsub(form, export.TEMP_U_IN_AU, "u")
	return form
end

function export.do_ending_stressed_inf(iut, base)
	if rfind(base.verb.verb, "rre$") then
		error("Use \\ not / with -rre verbs")
	end
	-- Add acute accent to -ere, grave accent to -are/-ire.
	local accented = rsub(base.verb.verb, "ere$", "ére")
	accented = unfc(rsub(accented, "([ai])re$", "%1" .. export.GR .. "re"))
	-- If there is a clitic suffix like -la or -sene, truncate final -e.
	if base.verb.linked_suf ~= "" then
		accented = rsub(accented, "e$", "")
	end
	local linked = "[[" .. base.verb.verb .. "|" .. accented .. "]]" .. base.verb.linked_suf
	iut.insert_form(base.forms, "lemma_linked", {form = linked})
end

function export.do_root_stressed_inf(iut, base, specs)
	for _, spec in ipairs(specs) do
		if spec.form == "-" then
			error("Spec '-' not allowed as root-stressed infinitive spec")
		end
		local this_specs
		if spec.form == "+" then
			-- do_root_stressed_inf is used for verbs in -ere and -rre. If the root-stressed vowel isn't explicitly
			-- given and the verb ends in -arre, -irre or -urre, derive it from the infinitive since there's only
			-- one possibility.. If the verb ends in -erre or -orre, this won't work because we have both
			-- scérre (= [[scegliere]]) and disvèrre (= [[disvellere]]), as well as pórre and tòrre (= [[togliere]]).
			local rre_vowel = rmatch(base.verb.verb, "([aiu])rre$")
			if rre_vowel then
				local before, v1, between, v2, after = analyze_stem_for_last_two_vowels(
					rsub(base.verb.verb, "re$", ""), base.verb.verb, "root-stressed infinitive")
				local vowel_spec = unfc(rre_vowel .. export.GR)
				if v1 == v2 then
					vowel_spec = vowel_spec .. "+"
				end
				this_specs = {{form = vowel_spec}}
			else
				-- Combine current footnotes into present-tense footnotes.
				this_specs = iut.convert_to_general_list_form(base.pres, spec.footnotes)
				for _, this_spec in ipairs(this_specs) do
					if not rfind(this_spec.form, "^" .. export.AV .. "[+-]?$") then
						error("When defaulting root-stressed infinitive vowel to present, present spec must be a single-vowel spec, but saw '"
							.. this_spec.form .. "'")
					end
				end
			end
		else
			this_specs = {spec}
		end
		local verb_stem, verb_suffix = rmatch(base.verb.verb, "^(.-)([er]re)$")
		if not verb_stem then
			error("Verb '" .. base.verb.verb .. "' must end in -ere or -rre to use \\ notation")
		end
		-- If there is a clitic suffix like -la or -sene, truncate final -(r)e.
		if base.verb.linked_suf ~= "" then
			verb_suffix = verb_suffix == "ere" and "er" or "r"
		end
		for _, this_spec in ipairs(this_specs) do
			if not rfind(this_spec.form, "^" .. export.AV .. "[+-]?$") then
				error("Explicit root-stressed infinitive spec '" .. this_spec.form .. "' should be a single-vowel spec")
			end

			local expanded = apply_vowel_spec(verb_stem, base.verb.verb, "root-stressed infinitive", this_spec.form)
			iut.insert_form(base, "root_stressed_stem", {form = expanded, footnotes = this_spec.footnotes})
			local linked = "[[" .. base.verb.verb .. "|" .. expanded .. verb_suffix .. "]]" .. base.verb.linked_suf
			iut.insert_form(base.forms, "lemma_linked", {form = linked, footnotes = this_spec.footnotes})
		end
	end
end

function export.pres_special_case(base, form)
	if form == "+" then
		check_not_null(base, base.verb.pres)
		return base.verb.pres
	elseif form == "+isc" then
		check_not_null(base, base.verb.isc_pres)
		return base.verb.isc_pres
	elseif form == "-" then
		return form
	elseif rfind(form, "^" .. export.AV .. "[+-]?$") then
		check_not_null(base, base.verb.pres)
		local pres, final_vowel = rmatch(base.verb.pres, "^(.*)([oae])$")
		if not pres then
			error("Internal error: Default present '" .. base.verb.pres .. "' doesn't end in -o, -a or -e")
		end
		return apply_vowel_spec(pres, base.verb.pres, "default present", form) .. final_vowel
	elseif not base.third and not rfind(form, "[oò]$") then
		error("Present first-person singular form '" .. form .. "' should end in -o")
	elseif base.third and not rfind(form, "[aàeè]") then
		error("Present third-person singular form '" .. form .. "' should end in -a or -e")
	else
		return form
	end
end

function export.pres3s_special_case(base, form)
	if form == "+" then
		check_not_null(base, base.verb.pres3s)
		return base.verb.pres3s
	elseif form == "+isc" then
		check_not_null(base, base.verb.isc_pres3s)
		return base.verb.isc_pres3s
	elseif form == "-" then
		return form
	elseif rfind(form, "^" .. export.AV .. "[+-]?$") then
		check_not_null(base, base.verb.pres3s)
		local pres3s, final_vowel = rmatch(base.verb.pres3s, "^(.*)([ae])$")
		if not pres3s then
			error("Internal error: Default third-person singular present '" .. base.verb.pres3s
				.. "' doesn't end in -a or -e")
		end
		return apply_vowel_spec(pres3s, base.verb.pres3s, "default third-person singular present", form) .. final_vowel
	elseif not rfind(form, "[aàeè]") then
		error("Present third-person singular form '" .. form .. "' should end in -a or -e")
	else
		return form
	end
end

function export.past_special_case(base, form)
	if form == "+" then
		check_not_null(base, base.verb.past)
		return base.verb.past
	elseif form ~= "-" and not base.third and not rfind(form, "i$") then
		error("Past historic form '" .. form .. "' should end in -i")
	else
		return form
	end
end

function export.pp_special_case(base, form)
	if form == "+" then
		check_not_null(base, base.verb.pp)
		return base.verb.pp
	elseif form ~= "-" and not rfind(form, "o$") then
		error("Past participle form '" .. form .. "' should end in -o")
	else
		return form
	end
end
