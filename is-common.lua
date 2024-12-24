local export = {}

local lang = require("Module:languages").getByCode("is")
local m_links = require("Module:links")
local m_table = require("Module:table")
local m_string_utilities = require("Module:string utilities")
local pages_module = "Module:pages"
local template_parser_module = "Module:template parser"

local u = mw.ustring.char
local rsplit = mw.text.split
local rfind = mw.ustring.find
local rmatch = mw.ustring.match
local rsubn = mw.ustring.gsub
local ulen = mw.ustring.len
local usub = mw.ustring.sub
local uupper = mw.ustring.upper

-- Capitalize the first letter.
local function ucap(str)
	local first, rest = rmatch(str, "^(.)(.*)$")
	if first then
		return uupper(first) .. rest
	else
		return str
	end
end

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

local AU_SUB = u(0xFFF0) -- temporary substitution for 'au'
local CAP_AU_SUB = u(0xFFF1) -- temporary substitution for 'Au'
local ALL_CAP_AU_SUB = u(0xFFF2) -- temporary substitution for 'AU'
local UR_SUB = u(0xFFF3) -- temporary substitution for final 'ur'; should be treated as consonant
local lc_vowel = "aeiouyáéíóúýöæ"
local uc_vowel = uupper(lc_vowel)
export.vowel = lc_vowel .. uc_vowel .. AU_SUB .. CAP_AU_SUB .. ALL_CAP_AU_SUB
export.vowel_c = "[" .. export.vowel .. "]"
export.vowel_or_hyphen = export.vowel .. "%-"
export.vowel_or_hyphen_c = "[" .. export.vowel_or_hyphen .. "]"
export.non_vowel_c = "[^" .. export.vowel .. "]"
export.cons_c = "[^" .. export.vowel .. "]"

local V = export.vowel_c
local C = export.cons_c


local function apply_au_ur_sub(stem, ur_only)
	if not ur_only then
		-- au doesn't u-mutate; easiest way to handle this is to temporarily convert au and variants to single
		-- characters
		stem = stem:gsub("au", AU_SUB)
		stem = stem:gsub("Au", CAP_AU_SUB)
		stem = stem:gsub("AU", ALL_CAP_AU_SUB)
	end
	-- There must be at least one vowel to treat -ur as a suffix; lemmas like [[bur]] don't count.
	stem = rsub(stem, "^(.*" ..export.vowel_or_hyphen_c .. ".*)ur$", "%1" .. UR_SUB)
	return stem
end

local function undo_au_ur_sub(stem)
	stem = stem:gsub(UR_SUB, "ur")
	stem = stem:gsub(AU_SUB, "au")
	stem = stem:gsub(CAP_AU_SUB, "Au")
	stem = stem:gsub(ALL_CAP_AU_SUB, "AU")
	return stem
end


local lc_i_mutation = {
	["a"] = "e", -- [[dagur]] "dat" -> dat sg [[degi]]; [[faðir]] "father" -> nom pl [[feður]]; [[maður]] "man" -> nom
				 -- pl [[menn]]; [[taka]] "to take" -> 1sg pres ind [[tek]]; [[langur]] "long" -> [[lengd]] "length"
	["á"] = "æ", -- [[háttur]] "way, manner" -> nom pl [[hættir]]; [[hár]] "high" -> comp [[hærri]]
	["e"] = "i", -- this may mostly occur in reverse
	["o"] = "e", -- [[hnot]] "nut; small ball of yarn" -> nom pl [[hnetur]]; [[koma]] "to come" -> 1sg pres ind [[kem]]
	-- ["o"] = "y", -- [[sonur]] "son" -> nom pl [[synir]]; needs explicit vowel
	["ö"] = "e", -- [[mölur]] "clothes moth" -> nom pl [[melir]]; [[köttur]] "cat" -> nom pl [[kettir]]; [[slökkva]]
				 -- "to extinguish" -> 1sg pres ind [[slekk]]; [[dökkur]] "dark" -> comp [[dekkri]]
	["ó"] = "æ", -- [[bók]] "book" -> nom pl [[bækur]]; [[stór]] "big" -> comp [[stærri]]; [[dómur]] "judgement" ->
				 -- [[dæmdur]] "judged"
	["u"] = "y", -- [[fullur]] "full" -> comp [[fyllri]]; [[þungur]] "heavy/weighty" -> [[þyngd]] "weight"
	["ú"] = "ý", -- [[mús]] "mouse" -> nom pl [[mýs]]; [[brú]] "bridge" -> nom pl [[brýr]]; [[búa]] "to reside" ->
				 -- 1sg pres ind [[bý]]; [[hús]] "house" -> [[hýsa]] "to house"
	["ja"] = "i", -- un-u-mutated version of jö
	["jö"] = "i", -- [[fjörður]] "fjord" -> dat sg [[firði]], nom pl [[firðir]]
	-- ["jö"] = "é", -- [[stjölur]] "?" -> dat sg [[stéli]], nom pl [[stélir]]; needs explicit vowel
	["jó"] = "ý", -- [[bjóða]] "to offer" -> 1sg pres ind [[býð]]; [[ljós]] "light" -> [[lýsa]] "to illuminate"
	["ju"] = "y", -- [[við]] [[bjuggum]] "we lived" -> subjunctive [[við]] [[byggjum]]
	["jú"] = "ý", -- [[ljúga]] "to lie" -> 1sg pres ind [[lýg]]
	["au"] = "ey", -- [[ausa]] "to dip, to scoop" -> 1sg pres ind [[eys]]; [[aumur]] "wretched" -> [[eymd]]
				   -- "wretchedness"
}

local i_mutation = {}
for k, v in pairs(lc_i_mutation) do
	i_mutation[k] = v
	i_mutation[ucap(k)] = ucap(v)
end

local lc_reverse_i_mutation = {
	["æ"] = "á", -- [[hættur]] nom pl "bedtime, quitting time" dat pl [[háttum]]; [[ær]] "ewe" acc/dat sg [[á]]
	["e"] = "a", -- [[ketill]] "kettle" dat sg [[katli]]; [[Egill]] (male given name) dat sg [[Agli]];
				 -- [[telja]] "to count" past ind [[taldi]]
	["i"] = "e", -- [[sitja]] "to sit" past part [[setinn]]
	["ý"] = "ú", -- [[kýr]] "cow" acc/dat sg [[kú]]
	["y"] = "u", -- FIXME: examples?
	["ey"] = "au", -- FIXME: examples?
}

local reverse_i_mutation = {}
for k, v in pairs(lc_reverse_i_mutation) do
	reverse_i_mutation[k] = v
	reverse_i_mutation[ucap(k)] = ucap(v)
end

-- Apply i-mutation to the last vowel of `stem`, excluding suffixal -ur. If `newv` is given, use that vowel (for cases
-- like [[sonur]] "son" nom pl [[synir]] but [[hnot]] "nut; small ball of yarn" nom pl [[hnetur]]); otherwise use the
-- appropriate default vowel.
function export.apply_i_mutation(stem, newv)
	local modstem, subbed
	local function subfunc(origv, post)
		return (newv or i_mutation[origv]) .. post
	end
	stem = apply_au_ur_sub(stem, "ur only")
	modstem, subbed = rsubb(stem, "([Aa]u)(" .. C .. "*)$", subfunc)
	if subbed then
		return undo_au_ur_sub(modstem)
	end
	modstem, subbed = rsubb(stem, "([Jj][aöóúu])(" .. C .. "*)$", subfunc)
	if subbed then
		return undo_au_ur_sub(modstem)
	end
	modstem, subbed = rsubb(stem, "([aáeoöóúuAÁEOÖÓÚU])(" .. C .. "*)$", subfunc)
	if subbed then
		return undo_au_ur_sub(modstem)
	end
	error(("Stem '%s' does not contain an i-mutable vowel as its last vowel"):format(undo_au_ur_sub(stem)))
end


-- Apply reverse i-mutation to the last vowel of `stem`, excluding suffixal -ur. If `newv` is given, use that vowel;
-- otherwise use the appropriate default vowel.
function export.apply_reverse_i_mutation(stem, newv)
	local modstem, subbed
	local function subfunc(origv, post)
		return (newv or reverse_i_mutation[origv]) .. post
	end
	stem = apply_au_ur_sub(stem, "ur only")
	modstem, subbed = rsubb(stem, "([Ee]y)(" .. C .. "*)$", subfunc)
	if subbed then
		return undo_au_ur_sub(modstem)
	end
	modstem, subbed = rsubb(stem, "([æeiýyÆEIÝY])(" .. C .. "*)$", subfunc)
	if subbed then
		return undo_au_ur_sub(modstem)
	end
	error(("Stem '%s' does not contain a reversible i-mutated vowel as its last vowel"):format(undo_au_ur_sub(stem)))
end


local lesser_u_mutation = {
	["a"] = "ö",
	["A"] = "Ö",
}

local lesser_reverse_u_mutation = {
	["ö"] = "a",
	["Ö"] = "A",
}

local greater_u_mutation = {
	["a"] = "u",
	["A"] = "U", -- FIXME, may not occur
}

local greater_reverse_u_mutation = {
	["u"] = "a",
	["U"] = "A", -- FIXME, may not occur
}

-- Apply u-mutation to `stem`, excluding suffixal -ur. `typ` is the type of u-mutation:
-- * "umut" (mutate the last vowel if possible, with a -> ö);
-- * "Umut" (mutate the last vowel if possible, with a -> u);
-- * "uumut" (mutate the last two vowels if possible, with a -> ö in the second-to-last and a -> ö in the last);
-- * "uUmut" (mutate the last two vowels if possible, with a -> ö in the second-to-last and a -> u in the last);
-- * "uUUmut" (mutate the last three vowels if possible, with a -> ö in the third-to-last and a -> u in the last and
--			   second-to-last; needed in superlatives of past-participle-derived adjectives like [[saltaður]] "salty"
--			   with superlative [[saltaðastur]] whose nominative feminine singular is [[söltuðust]]);
-- * "u_mut" (mutate the second-to-last vowel if possible, with a -> ö, leaving alone the last vowel).
function export.apply_u_mutation(stem, typ, error_if_unmatchable)
	local origstem = stem
	stem = apply_au_ur_sub(stem)
	if typ == "uUUmut" then
		local first, v1, mid1, v2, mid2, v3, last = rmatch(stem, "^(.*)(" .. V .. ")(" .. C .. "*)(" .. V .. ")(" ..
			C .. "*)(" .. V .. ")(" .. C .. "*)$")
		if first then
			v1 = lesser_u_mutation[v1] or v1
		elseif not stem:find("^%-") then
			if error_if_unmatchable then
				error(("Can't apply u-mutation of type '%s' because stem '%s' doesn't have three syllables"):
					format(typ, origstem))
			end
			return undo_au_ur_sub(stem)
		else
			first, v2, mid2, v3, last = rmatch(stem, "^(.*)(" .. V .. ")(" .. C .. "*)(" ..  V .. ")(" .. C .. "*)$")
			if not first then
				if error_if_unmatchable then
					error(("Can't apply u-mutation of type '%s' because suffix stem '%s' doesn't have two syllables"):
						format(typ, origstem))
				end
				return undo_au_ur_sub(stem)
			end
			v1 = ""
			mid1 = ""
		end
		v2 = greater_u_mutation[v2] or v2
		v3 = greater_u_mutation[v3] or v3
		local retval = undo_au_ur_sub(first .. v1 .. mid1 .. v2 .. mid2 .. v3 .. last)
		if retval == origstem and error_if_unmatchable then
			error(("Can't apply u-mutation of type '%s' to stem '%s'; result would be the same as the original"):
				format(typ, origstem))
		end
		return retval
	end
	if typ == "uUmut" or typ == "uumut" or typ == "u_mut" then
		local first, v1, middle, v2, last = rmatch(stem, "^(.*)(" .. V .. ")(" .. C .. "*)(" .. V .. ")(" .. C .. "*)$")
		if first then
			v1 = lesser_u_mutation[v1] or v1
		elseif not stem:find("^%-") then
			if error_if_unmatchable then
				error(("Can't apply u-mutation of type '%s' because stem '%s' doesn't have two syllables"):
					format(typ, origstem))
			end
			return undo_au_ur_sub(stem)
		else
			first, v2, last = rmatch(stem, "^(.*)(" .. V .. ")(" .. C .. "*)$")
			if not first then
				if error_if_unmatchable then
					error(("Can't apply u-mutation of type '%s' because suffix stem '%s' doesn't have even one syllable"):
						format(typ, origstem))
				end
				return undo_au_ur_sub(stem)
			end
			v1 = ""
			middle = ""
		end
		v2 = typ == "u_mut" and v2 or (typ == "uUmut" and greater_u_mutation or lesser_u_mutation)[v2] or v2
		local retval = undo_au_ur_sub(first .. v1 .. middle .. v2 .. last)
		if retval == origstem and error_if_unmatchable then
			error(("Can't apply u-mutation of type '%s' to stem '%s'; result would be the same as the original"):
				format(typ, origstem))
		end
		return retval
	end
	if typ ~= "umut" and typ ~= "Umut" then
		error(("Internal error: For stem '%s', saw unrecognized u-mutation type '%s'"):format(origstem, typ))
	end
	local first, v, last = rmatch(stem, "^(.*)(" .. V .. ")(" .. C .. "*)$")
	if not first then
		if error_if_unmatchable then
			error(("Can't apply u-mutation of type '%s' because stem '%s' doesn't have a vowel"):format(typ, origstem))
		end
		return undo_au_ur_sub(stem)
	end
	v = (typ == "Umut" and greater_u_mutation or lesser_u_mutation)[v] or v
	local retval = undo_au_ur_sub(first .. v .. last)
	if retval == origstem and error_if_unmatchable then
		error(("Can't apply u-mutation of type '%s' to stem '%s'; result would be the same as the original"):
			format(typ, origstem))
	end
	return retval
end


-- Apply reverse u-mutation to `stem`, excluding suffixal -ur. `typ` is the type of u-mutation:
-- * "unumut" (unmutate the last vowel if possible, with ö -> a);
-- * "unUmut" (unmutate the last vowel if possible, with u -> a);
-- * "unuumut" (unmutate the last two vowels if possible, with ö -> a in the second-to-last and ö -> a in the last);
-- * "unuUmut" (unmutate the last two vowels if possible, with ö -> a in the second-to-last and u -> a in the last);
-- * "unu_mut" (unmutate the second-to-last vowel if possible, with ö -> a, leaving alone the last vowel).
-- NOTE: "unuUUmut" isn't implemented at this point because AFAIK it's not needed anywhere.
function export.apply_reverse_u_mutation(stem, typ, error_if_unmatchable)
	local origstem = stem
	stem = apply_au_ur_sub(stem)
	if typ == "unuumut" or typ == "unuUmut" or typ == "unu_mut" then
		local first, v1, middle, v2, last =
			rmatch(stem, "^(.*)(" .. V .. ")(" .. C .. "*)(" ..  V .. ")(" .. C .. "*)$")
		if not first then
			if error_if_unmatchable then
				error(("Can't apply reverse u-mutation of type '%s' because stem '%s' doesn't have two syllables"):
					format(typ, origstem))
			end
			return undo_au_ur_sub(stem)
		end
		v1 = lesser_reverse_u_mutation[v1] or v1
		v2 = typ == "unu_mut" and v2 or (typ == "unuUmut" and greater_reverse_u_mutation or lesser_reverse_u_mutation)[v2] or v2
		local retval = undo_au_ur_sub(first .. v1 .. middle .. v2 .. last)
		if retval == origstem and error_if_unmatchable then
			error(("Can't apply reverse u-mutation of type '%s' to stem '%s'; result would be the same as the original"):
				format(typ, origstem))
		end
		return retval
	end
	if typ ~= "unumut" and typ ~= "unUmut" then
		error(("Internal error: For stem '%s', saw unrecognized reverse u-mutation type '%s'"):format(origstem, typ))
	end
	local first, v, last = rmatch(stem, "^(.*)(" .. V .. ")(" .. C .. "*)$")
	if not first then
		if error_if_unmatchable then
			error(("Can't apply reverse u-mutation of type '%s' because stem '%s' doesn't have a vowel"):
				format(typ, origstem))
		end
		return undo_au_ur_sub(stem)
	end
	v = (typ == "unUmut" and greater_reverse_u_mutation or lesser_reverse_u_mutation)[v] or v
	local retval = undo_au_ur_sub(first .. v .. last)
	if retval == origstem and error_if_unmatchable then
		error(("Can't apply reverse u-mutation of type '%s' to stem '%s'; result would be the same as the original"):
			format(typ, origstem))
	end
	return retval
end


-- Apply contraction to `stem`. Throw an error if the stem can't be contracted.
function export.apply_contraction(stem)
	-- Contraction only applies when the last vowel is a/i/u and followed by a single consonant. There are restrictions
	-- on what the consonant can be but I'm not sure exactly what they are; r/l/n/ð are all possible (cf. [[hamar]],
	-- [[megin]], [[höfuð]], [[þumall]], where in the last case the final -l is the nominative singular ending).
	local butlast, v, last = rmatch(stem, "^(.*" .. C .. ")([aiu])(" .. C .. ")$")
	if not butlast then
		error(("Contraction cannot be applied to stem '%s' because it doesn't end in a/i/u preceded by a consonant and followed by a single consonant"
			):format(stem))
	end
	return butlast .. last
end


-- Add a dental ending (d/t/ð) to `stem`.
function export.add_dental_ending(stem)
	if stem:find("[lmn]$") then
		-- [[talinn]] "counted" -> tald-; [[framinn]] "performed" -> framd-; [[hruninn]] "fallen down/in" -> hrund-
		return stem .. "d"
	elseif stem:find("ð$") then
		-- I dunno if this ever happens.
		return usub(stem, 1, -2) .. "dd"
	elseif rfind(stem, "[pkt]$") then
		-- [[glapinn]] "confused" -> glapt-; [[lukinn]] "(en)closed" -> lukt-; no examples with -t-
		return stem .. "t"
	else
		-- [[vafinn]] "wrapped" -> vafð-; [[varinn]] "defended" -> varð-; [[tugginn]] "chewed" -> tuggð- (or tuggn-);
		-- [[spúinn]] "vomited" -> spúð-
		return stem .. "ð"
	end
end


-- Parse off and return a final -ur or -r nominative ending. Return the portion before the ending as well as the ending
-- itself. If the lemma ends in -aur, only the -r is stripped off. This is used by ## and by the `@l` scraping
-- indicator (so that e.g. `@r` when applied to a compound of [[réttur]] "law; court; course (of a meal)" won't get
-- confused by the final -r).
function export.parse_off_final_nom_ending(lemma)
	local lemma_minus_r, final_nom_ending
	if lemma:find("[^Aa]ur$") then
		lemma_minus_r, final_nom_ending = lemma:match("^(.*)(ur)$")
	elseif lemma:find("r$") then
		lemma_minus_r, final_nom_ending = lemma:match("^(.*)(r)$")
	else
		lemma_minus_r, final_nom_ending = lemma, ""
	end
	return lemma_minus_r, final_nom_ending
end


-- Replace # and ## with `val`, substituting `lemma` as necessary (possibly without final -r or -ur).
function export.replace_hashvals(val, lemma)
	if not val then
		return val
	end
	if val:find("##") then
		local lemma_minus_r, final_nom_ending = export.parse_off_final_nom_ending(lemma)
		val = val:gsub("##", m_string_utilities.replacement_escape(lemma_minus_r))
	end
	val = val:gsub("#", m_string_utilities.replacement_escape(lemma))
	return val
end
	

-- Find the inflection spec by scraping the contents of the Icelandic section of `lemma`, looking for `infltemp` calls
-- (where template is e.g. "is-ndecl", "is-adecl" or "is-conj") If `inflid` is given, it must match the value of the
-- |id= param specified to the inflection template; otherwise, any inflection template call will work. If anything goes
-- wrong in the process, a string is returned describing the error message; otherwise a table of inflections is
-- returned, each containing a field `infl` with the inflection spec. The inflection spec comes from the |deriv=,
-- |deriv2=, etc. params in the inflection template if specified and `is_deriv` is given; otherwise from 1=, 2=, etc.
-- If `allow_empty_infl` is given, a missing inflection spec in 1= is allowed and converted to an empty string;
-- otherwise, an error is signaled.
function export.find_inflection(lemma, infltemp, allow_empty_infl, is_deriv, inflid)
	local title = mw.title.new(lemma)
	if title then
		local content = title:getContent()
		if content then
			local icelandic = require(pages_module).get_section(content, "Icelandic")
			if icelandic then
				local infl_sets_by_id = {}
				local infl_sets_without_id = {}
				local ordered_seen_ids = {}
				for template in require(template_parser_module).find_templates(icelandic) do
					if template:get_name() == infltemp then
						local args = template:get_arguments()
						local infls = {}
						if is_deriv and args.deriv then
							local i = 1
							while true do
								local deriv_param = "deriv" .. (i == 1 and "" or tostring(i))
								if args[deriv_param] then
									table.insert(infls, {infl = args[deriv_param]})
									i = i + 1
								else
									break
								end
							end
						elseif not args[1] and not allow_empty_infl then
							return ("For Icelandic base lemma '[[%s]]', saw no inflection spec in 1="):format(lemma)
						else
							local i = 1
							while true do
								if args[i] or (i == 1 and allow_empty_infl) then
									table.insert(infls, {infl = args[i] or ""})
									i = i + 1
								else
									break
								end
							end
						end
						local infl_set = {infls = infls, pos = args.pos}
						if args.id then
							if infl_sets_by_id[args.id] then
								return ("For Icelandic base lemma '[[%s]]', saw id='%s' twice"):format(args.id)
							end
							infl_sets_by_id[args.id] = infl_set
							m_table.insertIfNot(ordered_seen_ids, args.id)
						else
							table.insert(infl_sets_without_id, infl_set)
						end
					end
				end
				local function concat_ordered_seen_ids()
					local quoted_seen_ids = {}
					for _, seen_id in ipairs(ordered_seen_ids) do
						table.insert(quoted_seen_ids, "'" .. seen_id .. "'")
					end
					return m_table.serialCommaJoin(quoted_seen_ids, {dontTag = true})
				end
				if ordered_seen_ids[1] and infl_sets_without_id[1] then
					return ("For Icelandic base lemma '[[%s]]', saw %s [[Template:%s]]%s with id=%s " ..
						"as well as %s [[Template:%s]]%s without ID; this is not allowed; with multiple " ..
						"[[Template:%s]] calls, all must have id= params"):format(lemma, #ordered_seen_ids,
						infltemp, ordered_seen_ids[2] and "'s" or "",concat_ordered_seen_ids(), #infl_sets_without_id,
						infltemp, infl_sets_without_id[2] and "'s" or "", infltemp)
				elseif not ordered_seen_ids[1] and not infl_sets_without_id[1] then
					return ("For Icelandic base lemma '[[%s]]', found Icelandic section but couldn't find " ..
							"any calls to [[Template:%s]]"):format(lemma, infltemp)
				elseif #infl_sets_without_id > 1 then
					return ("For Icelandic base lemma '[[%s]]', found %s [[Template:%s]]'s without " ..
						"ID's; this is not allowed; with multiple [[Template:%s]] calls, all must have id= params"):
						format(lemma, #infl_sets_without_id, infltemp, infltemp)
				elseif inflid then
					if infl_sets_by_id[inflid] then
						return infl_sets_by_id[inflid]
					elseif ordered_seen_ids[1] then
							return ("For Icelandic base lemma '[[%s]]', found Icelandic section but couldn't find " ..
								"any inflections matching ID '%s'; instead found ID's %s; you may have misspelled " ..
								"the ID"):format(lemma, inflid, concat_ordered_seen_ids())
					else
						return ("For Icelandic base lemma '[[%s]]', found Icelandic section with a single " ..
							"[[Template:%s]] without ID, but ID requirement '%s' specified; consider " ..
							"removing the ID requirement"):format(lemma, infltemp, inflid)
					end
				elseif infl_sets_without_id[1] then
					-- only one {{is-ninfl}}, and it doesn't have an id=; return it
					return infl_sets_without_id[1]
				elseif ordered_seen_ids[2] then
					return ("For Icelandic base lemma '[[%s]]', saw %s [[Template:%s]]'s with id=%s " ..
						"but with a request to return the inflection without ID; consider adding an ID " ..
						"restriction to the scrape request, e.g. '@@:%s' for self-scraping or '@%s:%s' for " ..
						"scraping from another page"):format(lemma, #ordered_seen_ids, infltemp,
						concat_ordered_seen_ids(), ordered_seen_ids[1], usub(lemma, 1, 1), ordered_seen_ids[1])
				else
					return ("For Icelandic base lemma '[[%s]]', found Icelandic section with a single " ..
						"[[Template:%s]] with id=%s, but the scrape request didn't specify an ID; " ..
						"consider removing the id= param from the [[Template:%s]] call unless you " ..
						"expect to add more such calls to the page in the future (in which case add the ID " ..
						"to the scrape request, e.g. '@@:%s' for self-scraping or '@%s:%s' for scraping from " ..
						"another page"):format(lemma, infltemp, concat_ordered_seen_ids(), infltemp,
						ordered_seen_ids[1], usub(lemma, 1, 1), ordered_seen_ids[1])
				end
			else
				return ("For Icelandic base lemma '[[%s]]', page exists but has no Icelandic section"):format(lemma)
			end
		else
			return ("For Icelandic base lemma '[[%s]]', couldn't fetch contents for page; page may not exist"):
				format(lemma)
		end
	else
		return ("Bad Icelandic base lemma '[[%s]]'; couldn't create title object"):format(lemma)
	end
end


-- Find and return the prefix, base lemma and inflection spec for a scraped lemma given `lemma` (the lemma with an `@l`
-- or similar indicator spec), the scraping spec (e.g. "l", i.e. the portion after the @ sign), and optionally an
-- `inflid` restriction. The base lemma is the lemma whose inflection was scraped, and `prefix` is the portion of the
-- lemma before the base lemma (which must be a suffix of the lemma). For example, if `lemma` is [[ljósabekkur]]
-- "sunbed, tanning bed" and `scrape_spec` is "@b", the base lemma will be [[bekkur]] "bench" and the prefix will be
-- "ljósa". The inflection spec returned will be either an object containing a field `infl` containing the scraped
-- inflection spec, or a string indicating an error to display.
function export.find_scraped_infl(data)
	local lemma, scrape_spec, scrape_is_suffix, scrape_is_uppercase, infltemp, allow_empty_infl, inflid =
		data.lemma, data.scrape_spec, data.scrape_is_suffix, data.scrape_is_uppercase, data.infltemp,
		data.allow_empty_infl, data.inflid
	local prefix, base_lemma
	if scrape_spec == "@" then -- @@ specified
		base_lemma = lemma
		prefix = ""
	else
		local lemma_minus_ending, final_ending = data.parse_off_ending(lemma)
		local escaped_scrape_spec = m_string_utilities.pattern_escape(scrape_spec)
		prefix, base_lemma = rmatch(lemma_minus_ending, "^(.*)(" .. escaped_scrape_spec .. ".-)$")
		if not prefix then
			error(("Can't determine base lemma to scrape given lemma '%s' and scraping spec '@%s'; scraping spec not " ..
				"found in lemma"):format(lemma, scrape_spec))
		end
		base_lemma = base_lemma .. final_ending
	end
	if scrape_is_uppercase then
		local base_first, base_rest = rmatch(base_lemma, "^(.)(.*)$")
		if not base_first then
			error(("Internal error: Something wrong, couldn't match a single character in %s"):format(dump(base_lemma)))
		end
		base_lemma = uupper(base_first) .. base_rest
	end
	if scrape_is_suffix then
		base_lemma = "-" .. base_lemma
	end
	local infl = export.find_inflection(base_lemma, infltemp, allow_empty_infl, "is deriv", inflid)
	local errmsg = nil
	if type(infl) == "table" then
		infl = infl.infls
		if infl[2] then
			errmsg = ("For Icelandic base lemma '[[%s]]', saw %s inflection specs; currently, can only handle one"):
				format(base_lemma, #infl)
		else
			infl = infl[1]
			local argspec = infl.infl
			if argspec:find("<") then
				errmsg = ("For Icelandic base lemma '[[%s]]', saw explicit angle bracket spec in inflection, likely " ..
					"indicating a multiword inflection; can't handle yet: %s"):format(lemma, argspec)
			elseif argspec:find("%(%(") then
				errmsg = ("For Icelandic base lemma '[[%s]]', saw alternant specs; can't handle yet: %s"):
					format(lemma, argspec)
			end
		end
		if errmsg then
			infl = errmsg
		end
	end
	return prefix, base_lemma, infl
end


return export
