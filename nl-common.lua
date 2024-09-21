local export = {}

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
            return "<" .. (tag or "span") .. " lang=\"nl\">[[" .. form .. (form ~= PAGENAME and "#Dutch|" .. form or "") .. "]]</" .. (tag or "span") .. ">"
        else
            return "&mdash;"
        end
    end
end

function export.add_e(stem, weak_final, lengthen)
	-- Vowel lengthening
	if lengthen then
		return stem:gsub("i(.)$", "e%1") .. "e"
	-- Final weak syllable, no consonant doubling
	elseif weak_final then
		if stem:find("ie$") then
			return stem:gsub("ie$", "ië")
		else
			return stem .. "e"
		end
	else
		-- Ends in ee, ie, oe
		if stem:find("[eio]e$") then
			return stem .. "ë"
		-- Ends in e
		elseif stem:find("e$") then
			return stem
		-- Ends in double vowel + single consonant, remove one of the vowels
		elseif stem:find("([aeou])%1[bcdfgklmnpqrstvxz]$") then
			-- Add a diaeresis if the removal would create a digraph
			if stem:find("[io]ee.$") then
				return stem:gsub("..(.)$", "ë%1e")
			else
				return stem:gsub(".(.)$", "%1e")
			end
		-- Ends in single vowel + single consonant, double the consonant
		elseif stem:find("[AaEeIiOoUu][bcdfgklmnpqrstvz]$") and not stem:find("[IiïOoö]e.$") and (not stem:find("[AaäEeëOoöUuü]i.$") or stem:find("qui.$")) and not stem:find("[AaäEeëOoö]u.$") then
			return stem:gsub("(.)$", "%1%1e")
		else
			return stem .. "e"
		end
	end
end

return export
