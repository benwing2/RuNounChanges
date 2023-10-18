local export = {}

local rsubn = mw.ustring.gsub
local rfind = mw.ustring.find
local rmatch = mw.ustring.match

local unaccented_vowel = "aeiouüAEIOUÜ"
local accented_vowel = "áéíóúýÁÉÍÓÚÝ"
local vowel = unaccented_vowel .. accented_vowel
local V = "[" .. vowel .. "]"
export.V = V
local AV = "[" .. accented_vowel .. "]"
export.AV = AV
local NAV = "[^" .. accented_vowel .. "]"
export.NAV = NAV
local C = "[^" .. vowel .. ".]"
export.C = C
local remove_accent = {
	["á"]="a", ["é"]="e", ["í"]="i", ["ó"]="o", ["ú"]="u", ["ý"]="y",
	["Á"]="A", ["É"]="E", ["Í"]="I", ["Ó"]="O", ["Ú"]="U", ["Ý"]="Y",
}
export.remove_accent = remove_accent
local add_accent = {
	["a"]="á", ["e"]="é", ["i"]="í", ["o"]="ó", ["u"]="ú", ["y"]="ý",
	["A"]="Á", ["E"]="É", ["I"]="Í", ["O"]="Ó", ["U"]="Ú", ["Y"]="Ý",
}
export.add_accent = add_accent

-- version of rsubn() that discards all but the first return value
local function rsub(term, foo, bar)
	local retval = rsubn(term, foo, bar)
	return retval
end

export.rsub = rsub

-- version of rsubn() that returns a 2nd argument boolean indicating whether
-- a substitution was made.
local function rsubb(term, foo, bar)
	local retval, nsubs = rsubn(term, foo, bar)
	return retval, nsubs > 0
end

export.rsubb = rsubb

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

function export.remove_final_accent(stem)
	return rsub(stem, "(" .. AV .. ")(" .. C .. "*)$", function(v, c) return (remove_accent[v] or v) .. c end)
end

function export.add_final_accent(stem)
	return rsub(stem, "(" .. NAV .. ")(" .. C .. "*)$", function(v, c) return (add_accent[v] or v) .. c end)
end

-- FIXME: Next two copied from [[Module:es-common]]. Move to a utilities module.

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


function export.strip_redundant_links(form)
	-- Strip redundant brackets surrounding entire form.
	return rmatch(form, "^%[%[([^%[%]]*)%]%]$") or form
end

return export
