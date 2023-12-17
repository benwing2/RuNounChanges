local export = {}

local unaccented_vowel = "aeiouïü"
local accented_vowel = "àèéíòóú"
local vowel = unaccented_vowel .. accented_vowel

local rfind = mw.ustring.find
local rmatch = mw.ustring.match
local rsubn = mw.ustring.gsub
local usub = mw.ustring.sub

-- version of rsubn() that discards all but the first return value
function export.rsub(term, foo, bar)
	local retval = rsubn(term, foo, bar)
	return retval
end

local rsub = export.rsub

export.V = "[" .. vowel .. "]"
export.UV = "[" .. unaccented_vowel .. "]"
export.AV = "[" .. accented_vowel .. "]"
export.C = "[^" .. vowel .. "]"

local V = export.V
local UV = export.UV
local AV = export.AV
local C = export.C

-- Used when forming the feminine of adjectives in -i. Those with the stressed vowel 'e' or 'o' always seem to have è, ò.
local accent_vowel = {
	["a"] = "à",
	["e"] = "è",
	["i"] = "í",
	["o"] = "ò",
	["u"] = "ú",
}

local prepositions = {
	-- a + optional article (including salat)
	"al?s? ",
	-- de + optional article (including salat)
	"del?s? ",
	"d'",
	-- ca + optional article (including salat and [[en]])
	"can? ",
	"cal?s? ",
	-- per + optional article
	"per ",
	"pels? ",
	-- others
	"en ",
	"amb ",
	"cap ",
	"com ",
	"entre ",
	"sense ",
	"sobre ",
}

-- Make a link out of a form, or show a dash if empty.
function export.link_form(form, tag)
	if not PAGENAME then
		PAGENAME = mw.title.getCurrentTitle().text
	end

	if type(form) == "table" then
		for n, subform in pairs(form) do
			form[n] = export.link_form(subform, tag)
		end
		return table.concat(form, ", ")
	else
		if form ~= "" then
			return "<" .. (tag or "span") .. " lang=\"ca\">[[" .. form .. (form ~= PAGENAME and "#Catalan|" .. form or "") .. "]]</" .. (tag or "span") .. ">"
		else
			return "&mdash;"
		end
	end
end

-- Remove accents from any of the vowels in a word.
-- If an accented í follows another vowel, a diaeresis is added following
-- normal Catalan spelling rules.
function export.remove_accents(word, final_syllable_only)
	word = rsub(
		word,
		"(.?.?)([àèéíòóú])(" .. (final_syllable_only and export.C .. "*" or ".*") .. ")$",
		function (preceding, vowel, after)
			if vowel == "í" then
				if preceding:find("^[gq]u$") then
					return preceding .. "i"
				elseif preceding:find("[aeiou]$") then
					return preceding .. "ï"
				end
			end

			-- Decompose the accented vowel to an unaccented vowel (a, e, i, o, u)
			-- plus an acute or grave; return the unaccented vowel.
			return preceding .. mw.ustring.toNFD(vowel):sub(1, 1) .. after
		end)

	return word
end

-- Apply alternation of the final consonant of a stem, converting the form used before a back vowel into the form used
-- before a front vowel.
function export.back_to_front(stem)
	return (stem
		:gsub("qu$", "qü") -- adequar -> adeqües
		:gsub("c$", "qu") -- marcar -> marques
		:gsub("ç$", "c") -- abraçar -> abraces
		:gsub("gu$", "gü") -- enaiguar -> enaigües
		:gsub("g$", "gu") -- pegar -> pegues
		:gsub("j$", "g") -- arranjar -> arranges
	)
end

-- Apply alternation of the final consonant of a stem, converting the form used before a front vowel into the form used
-- before a back vowel.
function export.front_to_back(stem)
	return (stem
		:gsub("c$", "ç") -- torcer -> torço
		:gsub("qu$", "c")
		:gsub("qü$", "qu")
		:gsub("g$", "j") -- fugir -> fujo
		:gsub("gu$", "g")
		:gsub("gü$", "gu")
	)
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

function export.make_plural(base, gender, special)
	local retval = call_handle_multiword(base, special,
		function(term) return export.make_plural(term, gender) end, "allow multiple")
	if retval then
		return retval
	end

	-- a -> es
	if base:find("a$") then return {export.back_to_front(base:gsub("a$", "")) .. "es"} end

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
