local export = {}

local romut_module = "Module:romance utilities"

local u = mw.ustring.char
local rsplit = mw.text.split
local rfind = mw.ustring.find
local rmatch = mw.ustring.match
local rsubn = mw.ustring.gsub


local TEMPC1 = u(0xFFF1)
local TEMPC2 = u(0xFFF2)
local TEMPV1 = u(0xFFF3)
local DIV = u(0xFFF4)
local vowel = "aeiouáéíóúý" .. TEMPV1
local V = "[" .. vowel .. "]"
local AV = "[áéíóúý]" -- accented vowel
local W = "[iyuw]" -- glide
local C = "[^" .. vowel .. ".]"

export.vowel = vowel
export.V = V
export.AV = AV
export.W = W 
export.C = C 

local remove_accent = {
	["á"] = "a", ["é"] = "e", ["í"] = "i", ["ó"] = "o", ["ú"] = "u", ["ý"] = "y"
}
local add_accent = {
	["a"] = "á", ["e"] = "é", ["i"] = "í", ["o"] = "ó", ["u"] = "ú", ["y"] = "ý"
}

export.remove_accent = remove_accent
export.add_accent = add_accent


local prepositions = {
	"al? ",
	"del? ",
	"como ",
	"con ",
	"en ",
	"para ",
	"por ",
}


-- version of rsubn() that discards all but the first return value
local function rsub(term, foo, bar)
	local retval = rsubn(term, foo, bar)
	return retval
end

export.rsub = rsub

-- apply rsub() repeatedly until no change
local function rsub_repeatedly(term, foo, bar)
	while true do
		local new_term = rsub(term, foo, bar)
		if new_term == term then
			return term
		end
		term = new_term
	end
end

export.rsub_repeatedly = rsub_repeatedly


-- Applies alternation of the final consonant of a stem, converting the form
-- used before a back vowel into the form used before a front vowel.
function export.back_to_front(stem)
    return (stem:gsub("qu$", "qü"):gsub("c$", "qu"):gsub("ç$", "c"):gsub("gu$", "gü"):gsub("g$", "gu"):gsub("j$", "g"))
end

-- Applies alternation of the final consonant of a stem, converting the form
-- used before a front vowel into the form used before a back vowel.
function export.front_to_back(stem)
    return (stem:gsub("c$", "ç"):gsub("qu$", "c"):gsub("qü$", "qu"):gsub("g$", "j"):gsub("gu$", "g"):gsub("gü$", "gu"))
end

-----------------------------------------------------------------------------------------
--                                  Inflection functions                               --
-----------------------------------------------------------------------------------------

-- Given a term `term`, if the term is multiword (either through spaces or hyphens), handle inflection of the term by
-- calling handle_multiword() in [[Module:romance utilities]]. `special` indicates which parts of the multiword term to
-- inflect, and `inflect` is a function of one argument to inflect the individual parts of the term. As an optimization,
-- if the term is not multiword and `special` is not given, do nothing.
local function call_handle_multiword(term, special, inflect, allow_multiple)
	if not special and not term:find("[ %-]") then
		return nil
	end
	local retval = require(romut_module).handle_multiword(term, special, inflect, prepositions)
	if retval and #retval > 0 then
		if allow_multiple then
			return retval
		end
		if #retval ~= 1 then
			error("Internal error: Should have only one return value from inflection function: " .. table.concat(retval, ","))
		end
		return retval[1]
	end
	return nil
end

function export.make_feminine(base, special)
	local retval = call_handle_multiword(base, special, export.make_feminine)
	if retval then
		return retval
	end

	-- special cases
	-- -able, -ible, -uble
	if base:find("ble$") or
		-- stressed -al/-ar in a multisyllabic word (not [[gal]], [[anòmal]], or [[car]], [[clar]], [[rar]], [[var]],
		-- [[isòbar]], [[èuscar]], [[búlgar]], [[tàrtar]]/[[tàtar]], [[càtar]], [[àvar]])
		(rfind(base, V .. "[^ ]*a[lr]$") and not rfind(base, AV .. "[^ ]*a[lr]$")) or
		-- -ant in a multisyllabic word (not [[mant]], [[tant]], also [[quant]] but that needs manual handling)
		-- -ent in a multisyllabic word (not [[lent]]; some other words in -lent have feminine in -a but not all)
		rfind(base, V .. "[^ ]*[ae]nt$") or
		-- Words in -aç, -iç, -oç (not [[descalç]], [[dolç]], [[agredolç]]; [[balbuç]] has -a and needs manual handling)
		rfind(base, V .. "ç$") or
		-- Words in -il including when non-stressed ([[hàbil]], [[dèbil]], [[mòbil]], [[fàcil]], [[símil]], [[tàmil]],
		-- etc.); but not words in -òfil, -èfil, etc.
		base:find("[^f]il$") then
		return base
	end

	-- final vowel -> -a
	if base:find("a$") then return base end
	if base:find("o$") then return (base:gsub("o$", "a")) end
	if base:find("e$") then return export.front_to_back(base:gsub("e$", "")) .. "a" end

	-- -u -> -va
	if base:find(UV .. "u$") then return (base:gsub("u$", "v") .. "a") end

	-- accented vowel -> -na
	if rfind(base, AV .. "$") then return export.remove_accents(base) .. "na" end

	-- accented vowel + -s -> -sa
	if rfind(base, AV .. "s$") then return export.remove_accents(base) .. "a" end

	-- vowel + consonant(s) + i -> accent the first vowel, add -a
	local prev, first_vowel, cons = rmatch(base, "^(.*)([aeo])i(" .. C .. "+)i$")
	if first_vowel then
		-- At least [[malaisi]]
		return prev .. accent_vowel[first_vowel] .. "i" .. cons .. "ia"
	end
	local prev, first_vowel, cons = rmatch(base, "^(.*)(" .. UV .. ")(" .. C .. "+)i$")
	if first_vowel then
		return prev .. accent_vowel[first_vowel] .. cons .. "ia"
	end

	-- multisyllabic -at/-it/-ut (also -ït/-üt) with stress on the final vowel -> -ada/-ida/-uda
	local mod_base = rsub(base, "([gq])u(" .. UV .. ")", "%1w%2") -- hack so we don't treat the u in qu/gu as a vowel
	if (rfind(mod_base, V .. "[^ ]*[aiu]t$") and not rfind(mod_base, AV .. "[^ ]*[aiu]t$") and
		not rfind(mod_base, "[aeo][iu]t$")) or rfind(mod_base, "[ïü]t$") then
		return rsub(base, "t$", "da")
	end

	return base .. "a"
end

local function make_try(word)
	return function(from, to)
		local stem = rmatch(word, "^(.*)" .. from .. "$")
		if stem then
			return stem .. to
		end
		return nil
	end
end


function export.iotate(word)
	return
		try("s[tť]", "šť") or
		try("z[dď]", "žď") or
		try("[tť]", "c") or
		try("[dď]", "z") or
		try("n", "ň") or
		try("s", "š") or
		try("z", "ž") or
		try("r", "ř") or
		try("ch", "š") or
		try("[kc]", "č") or
		try("[hg]", "ž") or
		word
end


function export.make_plural(base, gender, special)
	local retval = call_handle_multiword(base, special,
		function(term) return export.make_plural(term, gender) end, "allow multiple")
	if retval then
		return retval
	end

	-- a -> es
	if base:find("a$") then return {export.back_to_front(base:gsub("a$", "")) .. "es"} end

	-- ends in an accented vowel + consonant
	if rfind(form, AV .. C .. "$") then
		return rsub(form, "(.)(.)$", function(vowel, consonant)
			return export.remove_accent[vowel] .. consonant .. "es"
		end)
	end

	local try = make_try(word)
	return
		try("áu", "aos") or
		try("éu", "eos") or
		try("u", "os") or

	if base:find("áu$") then return {export.back_to_front(base:gsub("a$", "")) .. "es"} end
	-- accented vowel -> -ns
	if rfind(base, AV .. "$") then
		return {export.remove_accents(base) .. "ns"}
	end

	if gender == "m" then
		if rfind(base, AV .. "s$") then
			return {export.remove_accents(base) .. "os"}
		end

		if rfind(base, "[sçxz]$") then
			return {base .. "os"}
		end

		if base:find("sc$") or base:find("[sx]t$") then
			return {base .. "s", base .. "os"}
		end
	end

	if gender == "f" then
		if base:find("s$") then return {base} end

		if base:find("sc$") or base:find("[sx]t$") then
			return {base .. "s", base .. "es"}
		end
	end

	if base:find("eig$") then
		return {base .. "s", rsub(base, "ig$", "jos")}
	end

	return {base .. "s"}
end

return export
