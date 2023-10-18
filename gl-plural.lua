-- Gets the plural of Galician nouns and adjectives.
 
local accented_letters = {'á', 'é', 'í', 'ó', 'ú', 'â', 'ê', 'ô'}
local remove_accent = {['á']='a', ['é']='e', ['í']='i', ['ó']='o', ['ú']='u', ['â']='a', ['ê']='e', ['ô']='o'}
local vowels = {'a', 'e', 'i', 'o', 'u', 'ã', 'á', 'é', 'í', 'ó', 'ê', 'ô', 'ú'}
local export = {}
 
function export.show(frame)
    local args = frame:getParent().args
    return export.get_plural(args[1])
end
 
-- Returns a singular’s plural if it can be safely guessed, and an empty string
-- otherwise.
function export.get_plural(lemma)
 
	if (has_space_or_hyphen(lemma)) then return nil end
 
	local suf3 = suffix(lemma, 3);
	local pre3 = prefix(lemma, 3);
 
	if (suf3 == "bel") then
		return pre3 .. "beis"
	end
 
	local suf2 = suffix(lemma, 2);
	local pre2 = prefix(lemma, 2);
	local suf1 = suffix(lemma, 1);
	local pre1 = prefix(lemma, 1);
 
	if (suf1 == "l") then
		if (has_multiple_vowels(lemma) and not is_accented(pre2)) then
			if (suf2 == "il") then
				return pre2 .. "is"
			else
				return pre1 .. "is"
			end
		else
			return lemma .. "es"
		end
	end
 
	if (suf1 == "m") then return pre1 .. "ns" end
	
	if (suf1 == "z") then return pre1 .. "ces" end
 
	if (suf1 == "r") then return lemma .. "es" end
	
	if (suf3 == "ção" or suf3 == "são") then
		return pre2 .. "ões"
	end
	
	if (suf2 == "ão") then return nil end
 
	if (suf1 == "x") then return lemma end
 
	if (is_vowel(suf1) or suf1 == "n") then return lemma .. "s" end
 
	if (suf1 == "s") then
		local penult = mw.ustring.sub(suf2, 1, 1)
		if (not is_vowel(penult)) then return lemma end
 
		local antepenult = mw.ustring.sub(suf3, 1, 1)
		if (is_vowel(antepenult)) then return lemma .. "es" end
 
 
		if (is_accented(penult)) then
			return pre2 .. remove_accent[penult] .. "ses"
		else
			return lemma
		end
	end
 
	return nil
end
 
 
function suffix(word, length)
	return mw.ustring.sub(word, mw.ustring.len(word) - length + 1)
end
 
 
function prefix(word, suf_length)
	return mw.ustring.sub(word, 1, mw.ustring.len(word) - suf_length)
end
 
-- returns whether it has ´ or ^
function is_accented(word)
	return word_has_letter(word, accented_letters)
end
 
function is_vowel(letter)
	return word_has_letter(letter, vowels)
end
 
function has_space_or_hyphen(word)
	return mw.ustring.find(word, " ") or mw.ustring.find(word, "-")
end
 
function word_has_letter(word, array)
	for c = 1, table.getn(array) do
		if (mw.ustring.find(word, array[c])) then
			return true
		end
	end
	return false
end
 
function has_multiple_vowels(word)
	local vowels = 0;
	for c = 1, mw.ustring.len(word) do
		if (is_vowel(mw.ustring.sub(word, c, c))) then
			vowels = vowels + 1
			if (vowels >= 2) then return true end
		end
	end
	return false
end
 
return export
