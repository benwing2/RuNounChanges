local export = {}

local add_suffix -- Defined below.
local find = string.find
local is_regular_plural -- Defined below.
local match = string.match
local remove_possessive -- Defined below.
local reverse = string.reverse
local sub = string.sub
local toNFD = mw.ustring.toNFD
local ugsub = mw.ustring.gsub
local ulower = mw.ustring.lower
local umatch = mw.ustring.match
local usub = mw.ustring.sub
local uupper = mw.ustring.upper

local vowels = "aæᴀᴁɐɑɒ@eᴇǝⱻəɛɘɜɞɤiıɪɨᵻoøœᴏɶɔᴐɵuᴜʉᵾɯꟺʊʋʌyʏ"
local hyphens = "%-‐‑‒–—"

--[==[
Loaders for objects, which load data (or some other object) into some variable, which can then be accessed as "foo or get_foo()", where the function get_foo sets the object to "foo" and then returns it. This ensures they are only loaded when needed, and avoids the need to check for the existence of the object each time, since once "foo" has been set, "get_foo" will not be called again.]==]
	local diacritics
	local function get_diacritics()
		diacritics, get_diacritics = mw.loadData("Module:headword/data").page.comb_chars.diacritics_all .. "+", nil
		return diacritics
	end

-- Normalize a string, so that case and diacritics are ignored. By default, "gu"
-- and "qu" are normalized to "g" and "q", because they behave like consonants
-- under certain conditions (e.g. final "y" does not usually have the plural
-- "ies" after a vowel, but it's regular for "quy" to become "quies". The flag
-- `not_gu` prevents this happening to "gu", and is needed because terms ending
-- "-guy" are almost always compounds of "guy" (→ "guys").
local function normalize(str, followed_by, not_gu)
	if not followed_by then
		followed_by = ""
	end
	str = ugsub(toNFD(str) .. followed_by, "([" .. (not_gu and "" or "Gg") .. "Qq])u([".. vowels .. "])", "%1%2")
	return ulower(ugsub(sub(str, 1, #str - #followed_by), diacritics or get_diacritics(), ""))
end

local function epenthetic_e_default(stem)
	return sub(stem, -1) ~= "e"
end

local function epenthetic_e_for_s(stem, term)
	-- If the stem is different, it must be from "y" → "i".
	if stem ~= term then
		return true
	end
	local final
	if match(stem, "^[^\128-\255]*$") then
		final = sub(stem, -1)
	else
		stem = ugsub(toNFD(stem), diacritics or get_diacritics(), "")
		final = usub(stem, -1)
	end
	-- Epenthetic "e" is added after a sibilant or sibilant-affricate. The vast
	-- majority of these are spelled "s", "x", "z", "ch" and "sh", but "dg"
	-- (→ "dge") and "ß" (→ "ss") can be found in obsolete spellings, "shh" in
	-- onomatopoeia, and "zh", "dj", "jj" (and more) in loanwords.
	return (
		final == "g" and sub(stem, -2, -2) == "d" or
		final == "h" and match(stem, "[csz]h+$") or
		final == "j" and umatch(stem, "[^" .. vowels .. "]j$") or
		final == "s" or
		final == "u" and umatch(stem, "%f[%w']u$") or
		final == "x" or
		final == "z" or
		final == "ß"
	)
end

function export.remove_possessive(stem)
	return match(stem, "^(.*)'s$") or match(stem, "^(.*s)'$") or stem
end
remove_possessive = export.remove_possessive

local suffixes = {}

suffixes["'s"] = {
	truncated = function(stem)
		return sub(stem, -1) == "s" and "'" or "'s"
	end,
}

suffixes["s.plural"] = {
	final_y_is_i = true,
	epenthetic_e = epenthetic_e_for_s,
	modifies_possessive = true,
}

suffixes["s.verb"] = {
	final_y_is_i = true,
	final_consonant_is_doubled = true,
	epenthetic_e = epenthetic_e_for_s
}

suffixes["ing"] = {
	final_consonant_is_doubled = true,
	remove_silent_e = true,
}

suffixes["d"] = {
	final_y_is_i = true,
	final_consonant_is_doubled = true,
	epenthetic_e = epenthetic_e_default,
}

suffixes["dst"] = suffixes["d"]
suffixes["st.verb"] = suffixes["d"]
suffixes["th"] = suffixes["d"]

suffixes["n"] = {
	final_y_is_i = true,
	final_y_is_i_after_vowel = true,
	final_guy_is_gui = true,
	final_consonant_is_doubled = true,
	-- No epenthetic "e" after an "e", or an "i", "r" or "w" preceded by a vowel.
	epenthetic_e = function(stem)
		return not (
			sub(stem, -1) == "e" or
			umatch(normalize(stem), "[" .. vowels .. "][irw]$")
		)
	end,
}

suffixes["r"] = {
	final_y_is_i = true,
	final_ey_is_i = true,
	final_guy_is_gui = true,
	final_consonant_is_doubled = true,
	epenthetic_e = epenthetic_e_default
}

suffixes["st.superlative"] = suffixes["r"]

-- Returns the stem used for suffixes that sometimes convert final "y" into "i",
-- such as "-es" ("-ies"), e.g. "penny" → "penni" ("pennies"). If
-- `final_ey_is_i` is true, final "ey" may also be converted, e.g. "plaguey" →
-- "plagui"; this is needed for "-er" ("-ier") and "-est" ("-iest"). If `not_gu`
-- is true, then normalize() will be called with the `not_gu` flag (see there
-- for more info); this is true in most cases.
local function convert_final_y_to_i(str, not_gu, final_ey_is_i, final_y_is_i_after_vowel)
	local final3 = usub(str, -3)
	-- Special case: treat "eey" as "ee" + "y" (e.g. "treey" → "treeiest").
	-- "oey" and "uey" are usually vowel + "ey", but examples of "oe" + "y" and
	-- "ue" = "y" do also exist: compare "go" → "goey" → "goier" with "doe" →
	-- "doey" → "doeier"; "flu" → "fluey" → "fluiest" and "flue" → "fluey" →
	-- "flueiest" form a theoretically possible minimal pair.
	if final3 == "eey" then
		return sub(str, 1, -2) .. "i"
	end
	local final2 = usub(str, -2)
	-- If `final_ey_is_i` is true, treat final "-ey" can also be reduced.
	if final_ey_is_i and final2 == "ey" then
		-- Remove "ey" to get the base stem.
		local base_stem = sub(str, 1, -3)
		-- Special case: allow final "-ey" ("potato-ey" → "potato-iest").
		if umatch(final3, "[" .. hyphens .. "]ey") then
			return base_stem .. "i"
		end
		-- Final "ey" becomes "i" iff the term is polysyllabic (e.g. not
		-- "grey"). "ey" is common if the base stem ends in a vowel ("echo →
		-- "echoey"), so the presence of a vowel anywhere in the base stem is
		-- sufficient to deem it polysyllabic. ("echoey" → "echo" → "echoiest",
		-- "beigey" → "beig" → "beigiest", but "grey" → "gr" → "greyest"). The
		-- first "y" in "-yey" can be treated as a vowel as long as it's
		-- preceded by something ("clayey" → "clay" → "clayiest", "cryey" →
		-- "cry" → "cryiest", but "*yey" → "*y" → "*yeyest"), so it needs to be
		-- treated as a special case.
		local normalized = normalize(base_stem, "ey")
		if sub(normalized, -1) == "y" then
			if umatch(normalized, "[%w@][yY]$") then
				return base_stem .. "i"
			end
		elseif umatch(normalized, "[" .. vowels .. "%d]%w*$") then
			return base_stem .. "i"
		end
	-- Special cases:
	-- Final "quy" ("soliloquy" → "soliloquies").
	-- Final "guy" iff `not_gu` is false ("roguy" → "roguiest").
	-- Final "y" after a vowel iff `final_y_is_i_after_vowel` is true ("slay" →
	-- "slain").
	-- Final "-y" ("bro-y" → "bro-iest"), accounting for hyphen variation.
	elseif umatch(final2, "[" .. hyphens .. "]y") then
		-- Replace final "y" with "i".
		return sub(str, 1, -2) .. "i"
	-- Otherwise, final "y" becomes "i" iff it's not preceded by a vowel
	-- ("shy" → "shiest", "horsy" → "horsies", but "day" → "days", "coy" →
	-- "coyest").
	else
		-- Remove "y" to get the base stem.
		local base_stem = sub(str, 1, -2)
		if umatch(normalize(base_stem, "y", not_gu), "[^%s%p" .. (final_y_is_i_after_vowel and "" or vowels) .. "]$") then
			return base_stem .. "i"
		end
	end
	return str
end

local function double_final_consonant(str, final)
	local initial = umatch(normalize(sub(str, 1, -2), final), "^.*%f[^%z%s" .. hyphens .. "…]([%l%p]*)[" .. vowels .. "]$")
	return initial and (
		initial == "" or
		initial == "y" or
		match(initial, "^.[\128-\191]*$") and umatch(initial, "[^" .. vowels .. "]") or
		umatch(initial, "^[^" .. vowels .. "]*%f[^%l]$")
	) and (str .. final) or str
end

local function remove_silent_e(str)
	local final2 = sub(str, -2)
	if final2 == "ie" then
		-- Replace "ie" with "y", unless it follows another "y" (e.g.
		-- "spulyie" → "spulyieing").
		return ugsub(str, "([^yY%s%p])ie$", "%1y")
	end
	local base_stem = sub(str, 1, -2)
	-- Silent "e" occurs after "u" or a consonant (cluster) preceded by a vowel.
	return (
		final2 == "ue" or
		umatch(normalize(base_stem, "e"), "[" .. vowels .. "][^" .. vowels .. "]+$")
	) and base_stem or str
end

function export.add_suffix(term, suffix, pos)
	local data, possessive = suffixes[suffix]
	-- If modifies_possessive is set, check for and remove any possessive
	-- suffix, which will be re-added again at the end.
	if data.modifies_possessive then
		local new = remove_possessive(term)
		if new ~= term then
			term, possessive = new, true
		end
	end
	suffix = match(suffix, "^([^.]*)")
	local final, stem = sub(term, -1)
	-- Proper nouns don't have a final "y" changed to "i" (e.g. "the Gettys",
	-- "the public Ivys").
	if data.final_y_is_i and final == "y" and pos ~= "proper noun" then
		stem = convert_final_y_to_i(term, not data.final_guy_is_gui, data.final_ey_is_i, data.final_y_is_i_after_vowel)
	elseif data.remove_silent_e and final == "e" then
		stem = remove_silent_e(term)
	else
		stem = term
	end
	local epenthetic_e = data.epenthetic_e
	if epenthetic_e and epenthetic_e(stem, term) then
		suffix = "e" .. suffix
	end
	if (
		data.final_consonant_is_doubled and
		match(final, "^[bcdfgjklmnpqrstvz]$") and -- Only double regular consonants.
		umatch(suffix, "^[" .. vowels .. "]")
	) then
		stem = double_final_consonant(term, final)
	end
	local truncated = data.truncated
	if truncated then
		suffix = truncated(stem)
	end
	local output = stem .. suffix
	-- Re-add the possessive suffix, if applicable.
	if possessive then
		output = add_suffix(output, "'s", pos)
	end
	return output
end
add_suffix = export.add_suffix

--[==[
Pluralize a word in a smart fashion, according to normal English rules.
# If the word ends in a consonant or "qu" + "-y", replace "-y" with "-ies".
# If the word ends in "s", "x", "z", "ch", "sh" or "zh", add "-es".
# Otherwise, add "-s".

This handles links correctly:
# If a piped link, change the second part appropriately.
# If a non-piped link and rule #1 above applies, convert to a piped link with the second part containing the plural.
# If a non-piped link and rules #2 or #3 above apply, add the plural outside the link.
]==]
function export.pluralize(str)
	-- Treat as a link if a "[[" is present and the string ends with "]]".
	if not (find(str, "[[", 1, true) and sub(str, -2) == "]]") then
		return add_suffix(str, "s.plural")
	end
	-- Find the last "[[" (in case there is more than one) by reversing
	-- the string.
	local str_rev = reverse(str)
	local open = find(str_rev, "[[", 3, true)
	-- If the last "[[" is followed by a "]]" which isn't at the end,
	-- then the final "]]" is just plaintext (e.g. "[[foo]]bar]]").
	local bad_close = find(str_rev, "]]", 3, true)
	-- Note: the bad "]]" will have a lower index than the last "[[" in
	-- the reversed string.
	if bad_close and bad_close < open then
		return add_suffix(str, "s.plural")
	end
	open = #str - open + 2
	-- Get the target and display text by searching from just after "[[".
	local target, display = match(str, "([^|]*)|?(.*)%]%]$", open)
	display = add_suffix(display ~= "" and display or target, "s.plural")
	-- If the link target is a substring of the display text, then
	-- use a trail (e.g. "[[foo]]" → "[[foo]]s", since "foo" is a substring
	-- of "foos").
	local index, trail = find(display, target, 1, true)
	if index == 1 then
		return sub(str, 1, open - 1) .. target .. "]]" .. sub(display, trail + 1)
	end
	-- Otherwise, return a piped link.
	return sub(str, 1, open - 1) .. target .. "|" .. display .. "]]"
end

--[==[
Returns true if `plural` is an expected, regular plural of `term`.
The optional parameter `pos` can be used to specify the part of speech,
which is necessary because proper nouns do not change a {"-y"} suffix to {"-ies"}
(e.g. {"Abby"} → {"Abbys"}). By default, `pos` is set to {"noun"}. In addition to
{"proper noun"}, it can also take the special value {"noun+"}, which means that
the function will first attempt the check with the {"noun"} setting, and will
then attempt it with the {"proper noun"} setting iff the term begins with a
capital letter.
]==]
function export.is_regular_plural(plural, term, pos)
	local init_plural, init_term, try_as_proper_noun = plural, term
	if pos == "noun+" then
		pos, try_as_proper_noun = "noun", true
	end
	-- Ignore any final punctuation that occurs in both forms, which is common
	-- in abbreviations (e.g. "abbr." → "abbrs.").
	local final_punc = umatch(term, "%p*$")
	local final_punc_len = #final_punc
	if sub(plural, -final_punc_len) == final_punc then
		term = sub(term, 1, -final_punc_len - 1)
		plural = sub(plural, 1, -final_punc_len - 1)
	end
	if plural == add_suffix(term, "s.plural", pos) then
		return true
	end
	local final = sub(term, -1)
	if (
		-- Doubled final consonants in "s" and "z".
		final == "s" and plural == term .. "ses" or -- e.g. "busses"
		final == "z" and plural == term .. "zes" or -- e.g. "quizzes"
		-- convert_final_y_to_i() without the `not_gu` flag set, to catch
		-- "-guy" → "-guies", but not "day" → "daies".
		final == "y" and plural == convert_final_y_to_i(term) .. "es" or
		-- Capitalized terms like "$DEITY" → "$DEITIES (should we treat this as regular?)
		final == "Y" and ulower(plural) == convert_final_y_to_i(ulower(term)) .. "es"
	) then
		return true
	elseif try_as_proper_noun then
		local init = umatch(init_term, "^[^%w%s]*(%w)")
		return init and uupper(init) == init and ulower(init) ~= init and
			is_regular_plural(init_plural, init_term, "proper noun") or
			false
	end
	return false
end
is_regular_plural = export.is_regular_plural

do
	local function do_singularize(str)
		local sing = match(str, "^(.-)ies$")
		if sing then
			return sing .. "y"
		end
		-- Handle cases like "[[parish]]es"
		return match(str, "^(.-[cs]h%]*)es$") or -- not -zhes
		-- Handle cases like "[[box]]es"
			match(str, "^(.-x%]*)es$") or -- not -ses or -zes
		-- Handle regular plurals
			match(str, "^(.-)s$") or
		-- Otherwise, return input
			str
	end
	
	local function collapse_link(link, linktext)
		if link == linktext then
			return "[[" .. link .. "]]"
		end
		return "[[" .. link .. "|" .. linktext .. "]]"
	end
	
	--[==[
	Singularize a word in a smart fashion, according to normal English rules. Works analogously to {pluralize()}.

	'''NOTE''': This doesn't always work as well as {pluralize()}. Beware. It will mishandle cases like "passes" -> "passe", "eyries" -> "eyry".
	# If word ends in -ies, replace -ies with -y.
	# If the word ends in -xes, -shes, -ches, remove -es. [Does not affect -ses, cf. "houses", "impasses".]
	# Otherwise, remove -s.

	This handles links correctly:
	# If a piped link, change the second part appropriately. Collapse the link to a simple link if both parts end up the same.
	# If a non-piped link, singularize the link.
	# A link like "[[parish]]es" will be handled correctly because the code that checks for -shes etc. allows ] characters between the
	  'sh' etc. and final -es.
	]==]
	function export.singularize(str)
		if type(str) == "table" then
			-- allow calling from a template
			str = str.args[1]
		end
		-- Check for a link. This pattern matches both piped and unpiped links.
		-- If the link is not piped, the second capture (linktext) will be empty.
		local beginning, link, linktext = match(str, "^(.*)%[%[([^|%]]+)%|?(.-)%]%]$")
		if not link then
			return do_singularize(str)
		elseif linktext ~= "" then
			return beginning .. collapse_link(link, do_singularize(linktext))
		end
		return beginning .. "[[" .. do_singularize(link) .. "]]"
	end
end

--[==[
Return the appropriate indefinite article to prefix to `str`. Correctly handles links and capitalized text.
Does not correctly handle words like [[union]], [[uniform]] and [[university]] that take "a" despite beginning with
a 'u'. The returned article will have its first letter capitalized if `ucfirst` is specified, otherwise lowercase.
]==]
function export.get_indefinite_article(str, ucfirst)
	str = str or ""
	-- If there's a link at the beginning, examine the first letter of the
	-- link text. This pattern matches both piped and unpiped links.
	-- If the link is not piped, the second capture (linktext) will be empty.
	local link, linktext = match(str, "^%[%[([^|%]]+)%|?(.-)%]%]")
	if match(link and (linktext ~= "" and linktext or link) or str, "^()[AEIOUaeiou]") then
		return ucfirst and "An" or "an"
	end
	return ucfirst and "A" or "a"
end
get_indefinite_article = export.get_indefinite_article

--[==[
Prefix `text` with the appropriate indefinite article to prefix to `text`. Correctly handles links and capitalized
text. Does not correctly handle words like [[union]], [[uniform]] and [[university]] that take "a" despite beginning
with a 'u'. The returned article will have its first letter capitalized if `ucfirst` is specified, otherwise lowercase.
]==]
function export.add_indefinite_article(text, ucfirst)
	return get_indefinite_article(text, ucfirst) .. " " .. text
end

export.vowels = vowels
export.vowel = "[" .. vowels .. "]"

return export
