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
            return "<" .. (tag or "span") .. " lang=\"ca\">[[" .. form .. (form ~= PAGENAME and "#Catalan|" .. form or "") .. "]]</" .. (tag or "span") .. ">"
        else
            return "&mdash;"
        end
    end
end

-- Remove accents from any of the vowels in a word.
-- If an accented í follows another vowel, a diaeresis is added following
-- normal Catalan spelling rules.
function export.remove_accents(word)
    word = mw.ustring.gsub(
    	word,
    	"(.?.?)([àèéíòóú])",
    	function (preceding, vowel)
    		if vowel == "í" then
    			if preceding:find("^[gq]u$") then
    				return preceding .. "i"
    			elseif preceding:find("[aeiou]$") then
    				return preceding .. "ï"
    			end
    		end
    		
    		-- Decompose the accented vowel to an unaccented vowel (a, e, i, o, u)
    		-- plus an acute or grave; return the unaccented vowel.
    		return preceding .. mw.ustring.toNFD(vowel):sub(1, 1)
    	end)
    
    return word
end

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

return export
