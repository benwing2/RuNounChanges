local export = {}

local lang = require("Module:languages").getByCode("is")
local m_links = require("Module:links")
local m_table = require("Module:table")
local m_string_utilities = require("Module:string utilities")

local u = mw.ustring.char
local rsplit = mw.text.split
local rfind = mw.ustring.find
local rmatch = mw.ustring.match
local rsubn = mw.ustring.gsub
local ulen = mw.ustring.len
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
local ALL_CAP_AU_SUB = u(0xFFF1) -- temporary substitution for 'AU'
local lc_vowel = "aeiouyáéíóúýöæ"
local uc_vowel = uupper(lc_vowel)
export.vowel = lc_vowel .. uc_vowel .. AU_SUB .. CAP_AU_SUB .. ALL_CAP_AU_SUB
export.vowel_c = "[" .. export.vowel .. "]"
export.vowel_or_hyphen = export.vowel .. "%-"
export.vowel_or_hyphen_c = "[" .. export.vowel_or_hyphen .. "]"
export.non_vowel_c = "[^" .. export.vowel .. "]"
export.cons_c = "[^" .. export.vowel .. "]"


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

-- Apply i-mutation to the last vowel of `stem`. If `newv` is given, use that vowel (for cases like [[sonur]] "son"
-- nom pl [[synir]] but [[hnot]] "nut; small ball of yarn" nom pl [[hnetur]]); otherwise use the appropriate default
-- vowel.
function export.apply_i_mutation(stem, newv)
	local modstem, subbed
	local function subfunc(origv, post)
		return (newv or i_mutation[origv]) .. post
	end
	modstem, subbed = rsubb(stem, "([Aa]u)(" .. export.cons_c .. "*)$", subfunc)
	if subbed then
		return modstem
	end
	modstem, subbed = rsubb(stem, "([Jj][aöóúu])(" .. export.cons_c .. "*)$", subfunc)
	if subbed then
		return modstem
	end
	modstem, subbed = rsubb(stem, "([aáeoöóúuAÁEOÖÓÚU])(" .. export.cons_c .. "*)$", subfunc)
	if subbed then
		return modstem
	end
	error(("Stem '%s' does not contain an i-mutable vowel as its last vowel"):format(stem))
end


-- Apply reverse i-mutation to the last vowel of `stem`. If `newv` is given, use that vowel; otherwise use the
-- appropriate default vowel.
function export.apply_reverse_i_mutation(stem, newv)
	local modstem, subbed
	local function subfunc(origv, post)
		return (newv or reverse_i_mutation[origv]) .. post
	end
	modstem, subbed = rsubb(stem, "([Ee]y)(" .. export.cons_c .. "*)$", subfunc)
	if subbed then
		return modstem
	end
	modstem, subbed = rsubb(stem, "([æeiýyÆEIÝY])(" .. export.cons_c .. "*)$", subfunc)
	if subbed then
		return modstem
	end
	error(("Stem '%s' does not contain a reversible i-mutated vowel as its last vowel"):format(stem))
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

local function apply_au_sub(stem)
	-- au doesn't mutate; easiest way to handle this is to temporarily convert au and variants to single characters
	stem = stem:gsub("au", AU_SUB)
	stem = stem:gsub("Au", CAP_AU_SUB)
	stem = stem:gsub("AU", ALL_CAP_AU_SUB)
	return stem
end

local function undo_au_sub(stem)
	stem = stem:gsub(AU_SUB, "au")
	stem = stem:gsub(CAP_AU_SUB, "Au")
	stem = stem:gsub(ALL_CAP_AU_SUB, "AU")
	return stem
end

-- Apply u-mutation to `stem`. `typ` is the type of u-mutation:
-- * "umut" (mutate the last vowel if possible, with a -> ö);
-- * "Umut" (mutate the last vowel if possible, with a -> u);
-- * "uumut" (mutate the last two vowels if possible, with a -> ö in the second-to-last and a -> ö in the last);
-- * "uUmut" (mutate the last two vowels if possible, with a -> ö in the second-to-last and a -> u in the last);
-- * "u_mut" (mutate the second-to-last vowel if possible, with a -> ö, leaving alone the last vowel).
function export.apply_u_mutation(stem, typ, error_if_unmatchable)
	local origstem = stem
	stem = apply_au_sub(stem)
	if typ == "uUmut" or typ == "uumut" or typ == "u_mut" then
		local first, v1, middle, v2, last = rmatch(stem, "^(.*)(" .. export.vowel_c .. ")(" .. export.cons_c .. "*)(" ..
			export.vowel_c .. ")(" .. export.cons_c .. "*)$")
		if first then
			v1 = lesser_u_mutation[v1] or v1
		elseif not stem:find("^%-") then
			if error_if_unmatchable then
				error(("Can't apply u-mutation of type '%s' because stem '%s' doesn't have two syllables"):
					format(typ, origstem))
			end
			return undo_au_sub(stem)
		else
			first, v2, last = rmatch(stem, "^(.*)(" .. export.vowel_c .. ")(" .. export.cons_c .. "*)$")
			if not first then
				if error_if_unmatchable then
					error(("Can't apply u-mutation of type '%s' because suffix stem '%s' doesn't have even one syllable"):
						format(typ, origstem))
				end
				return undo_au_sub(stem)
			end
			v1 = ""
			middle = ""
		end
		v2 = typ == "u_mut" and v2 or (typ == "uUmut" and greater_u_mutation or lesser_u_mutation)[v2] or v2
		local retval = undo_au_sub(first .. v1 .. middle .. v2 .. last)
		if retval == origstem and error_if_unmatchable then
			error(("Can't apply u-mutation of type '%s' to stem '%s'; result would be the same as the original"):
				format(typ, origstem))
		end
		return retval
	end
	if typ ~= "umut" and typ ~= "Umut" then
		error(("Internal error: For stem '%s', saw unrecognized u-mutation type '%s'"):format(origstem, typ))
	end
	local first, v, last = rmatch(stem, "^(.*)(" .. export.vowel_c .. ")(" .. export.cons_c .. "*)$")
	if not first then
		if error_if_unmatchable then
			error(("Can't apply u-mutation of type '%s' because stem '%s' doesn't have a vowel"):format(typ, origstem))
		end
		return undo_au_sub(stem)
	end
	v = (typ == "Umut" and greater_u_mutation or lesser_u_mutation)[v] or v
	local retval = undo_au_sub(first .. v .. last)
	if retval == origstem and error_if_unmatchable then
		error(("Can't apply u-mutation of type '%s' to stem '%s'; result would be the same as the original"):
			format(typ, origstem))
	end
	return retval
end


-- Apply reverse u-mutation to `stem`. `typ` is the type of u-mutation:
-- * "unumut" (unmutate the last vowel if possible, with ö -> a);
-- * "unUmut" (unmutate the last vowel if possible, with u -> a);
-- * "unuumut" (unmutate the last two vowels if possible, with ö -> a in the second-to-last and ö -> a in the last);
-- * "unuUmut" (unmutate the last two vowels if possible, with ö -> a in the second-to-last and u -> a in the last);
-- * "unu_mut" (unmutate the second-to-last vowel if possible, with ö -> a, leaving alone the last vowel).
function export.apply_reverse_u_mutation(stem, typ, error_if_unmatchable)
	local origstem = stem
	stem = apply_au_sub(stem)
	if typ == "unuumut" or typ == "unuUmut" or typ == "unu_mut" then
		local first, v1, middle, v2, last = rmatch(stem, "^(.*)(" .. export.vowel_c .. ")(" .. export.cons_c .. "*)(" ..
			export.vowel_c .. ")(" .. export.cons_c .. "*)$")
		if not first then
			if error_if_unmatchable then
				error(("Can't apply reverse u-mutation of type '%s' because stem '%s' doesn't have two syllables"):
					format(typ, origstem))
			end
			return undo_au_sub(stem)
		end
		v1 = lesser_reverse_u_mutation[v1] or v1
		v2 = typ == "unu_mut" and v2 or (typ == "unuUmut" and greater_reverse_u_mutation or lesser_reverse_u_mutation)[v2] or v2
		local retval = undo_au_sub(first .. v1 .. middle .. v2 .. last)
		if retval == origstem and error_if_unmatchable then
			error(("Can't apply reverse u-mutation of type '%s' to stem '%s'; result would be the same as the original"):
				format(typ, origstem))
		end
		return retval
	end
	if typ ~= "unumut" and typ ~= "unUmut" then
		error(("Internal error: For stem '%s', saw unrecognized reverse u-mutation type '%s'"):format(origstem, typ))
	end
	local first, v, last = rmatch(stem, "^(.*)(" .. export.vowel_c .. ")(" .. export.cons_c .. "*)$")
	if not first then
		if error_if_unmatchable then
			error(("Can't apply reverse u-mutation of type '%s' because stem '%s' doesn't have a vowel"):
				format(typ, origstem))
		end
		return undo_au_sub(stem)
	end
	v = (typ == "unUmut" and greater_reverse_u_mutation or lesser_reverse_u_mutation)[v] or v
	local retval = undo_au_sub(first .. v .. last)
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
	local butlast, v, last = rmatch(stem, "^(.*" .. export.cons_c .. ")([aiu])(" .. export.cons_c .. ")$")
	if not butlast then
		error(("Contraction cannot be applied to stem '%s' because it doesn't end in a/i/u preceded by a consonant and followed by a single consonant"
			):format(stem))
	end
	return butlast .. last
end


return export
