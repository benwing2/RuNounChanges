local export = {}

local rfind = mw.ustring.find
local rsubn = mw.ustring.gsub
local rmatch = mw.ustring.match
local rsplit = mw.text.split

-- version of rsubn() that discards all but the first return value
local function rsub(term, foo, bar)
	local retval = rsubn(term, foo, bar)
	return retval
end


export.allowed_special_indicators = {
	["first"] = true,
	["first-second"] = true,
	["first-last"] = true,
	["second"] = true,
	["last"] = true,
	["each"] = true,
	["+"] = true, -- requests the default behavior with preposition handling
}

-- Check for special indicators (values such as "+first" or "+first-last" that are used in a `pl`, `f`, etc. argument
-- and indicate how to inflect a multiword term). If `form` is such an indicator, the return value is `form` minus
-- the initial + sign; otherwise, if form begins with a + sign, an error is thrown; otherwise the return value is nil.
function export.get_special_indicator(form)
	if form:find("^%+") then
		form = form:gsub("^%+", "")
		if not export.allowed_special_indicators[form] then
			local indicators = {}
			for indic, _ in pairs(export.allowed_special_indicators) do
				table.insert(indicators, "+" .. indic)
			end
			table.sort(indicators)
			error("Special inflection indicator beginning with '+' can only be " ..
				require("Module:table").serialCommaJoin(indicators, {dontTag = true}) .. ": +" .. form)
		end
		return form
	end
	return nil
end


local function add_endings(bases, endings)
	local retval = {}
	if type(bases) ~= "table" then
		bases = {bases}
	end
	if type(endings) ~= "table" then
		endings = {endings}
	end
	for _, base in ipairs(bases) do
		for _, ending in ipairs(endings) do
			table.insert(retval, base .. ending)
		end
	end
	return retval
end


-- Inflect a possibly multiword or hyphenated term `form` using the function `inflect`, which is a function of one
-- argument that is called on a single word to inflect and should return either the inflected word or a list of
-- inflected words. `special` indicates how to inflect the multiword term and should be e.g. "first" to inflect only the
-- first word, "first-last" to inflect the first and last words, "each" to inflect each word, etc. See
-- `allowed_special_indicators` above for the possibilities. If `special` is '+', or is omitted and the term is
-- multiword (i.e. containing a space character), the function checks for multiword or hyphenated terms containing the
-- prepositions in `prepositions`, e.g. Italian [[senso di marcia]] or [[succo d'arancia]] or Portuguese
-- [[tartaruga-do-mar]]. If such a term is found, only the first word is inflected. Otherwise, the default is
-- "first-last". `prepositions` is a list of regular expressions matching prepositions. The regular expressions will
-- automatically have the separator character (space or hyphen) added to the left side but not the right side, so they
-- should contain a space character (which will automatically be converted to the appropriate separator) on the right
-- side unless the preposition is joined on the right side with an apostrophe. Examples of preposition regular
-- expressions for Italian are "di ", "sull'" and "d?all[oae] " (which matches "dallo ", "dalle ", "alla ", etc.).
--
-- The return value is always either a list of inflected multiword or hyphenated terms, or nil if `special` is omitted
-- and `form` is not multiword. (If `special` is specified and `form` is not multiword or hyphenated, an error results.)
function export.handle_multiword(form, special, inflect, prepositions, sep)
	sep = sep or form:find(" ") and " " or "%-"
	local raw_sep = sep == " " and " " or "-"
	-- Used to add regex version of separator in the replacement portion of rsub() or :gsub()
	local sep_replacement = sep == " " and " " or "%%-"
	-- Given a Lua pattern (aka "regex"), replace space with the appropriate separator.
	local function hack_re(re)
		if sep == " " then
			return re
		else
			return rsub(re, " ", sep_replacement)
		end
	end

	if special == "first" then
		local first, rest = rmatch(form, hack_re("^(.-)( .*)$"))
		if not first then
			error("Special indicator 'first' can only be used with a multiword term: " .. form)
		end
		return add_endings(inflect(first), rest)
	elseif special == "second" then
		local first, second, rest = rmatch(form, hack_re("^([^ ]+ )([^ ]+)( .*)$"))
		if not first then
			error("Special indicator 'second' can only be used with a term with three or more words: " .. form)
		end
		return add_endings(add_endings({first}, inflect(second)), rest)
	elseif special == "first-second" then
		local first, space, second, rest = rmatch(form, hack_re("^([^ ]+)( )([^ ]+)( .*)$"))
		if not first then
			error("Special indicator 'first-second' can only be used with a term with three or more words: " .. form)
		end
		return add_endings(add_endings(add_endings(inflect(first), space), inflect(second)), rest)
	elseif special == "each" then
		local terms = rsplit(form, sep)
		if #terms < 2 then
			error("Special indicator 'each' can only be used with a multiword term: " .. form)
		end
		for i, term in ipairs(terms) do
			terms[i] = inflect(term)
			if i > 1 then
				terms[i] = add_endings(raw_sep, terms[i])
			end
		end
		local result = ""
		for _, term in ipairs(terms) do
			result = add_endings(result, term)
		end
		return result
	elseif special == "first-last" then
		local first, middle, last = rmatch(form, hack_re("^(.-)( .* )(.-)$"))
		if not first then
			first, middle, last = rmatch(form, hack_re("^(.-)( )(.*)$"))
		end
		if not first then
			error("Special indicator 'first-last' can only be used with a multiword term: " .. form)
		end
		return add_endings(add_endings(inflect(first), middle), inflect(last))
	elseif special == "last" then
		local rest, last = rmatch(form, hack_re("^(.* )(.-)$"))
		if not rest then
			error("Special indicator 'last' can only be used with a multiword term: " .. form)
		end
		return add_endings(rest, inflect(last))
	elseif special and special ~= "+" then
		error("Unrecognized special=" .. special)
	end

	-- Only do default behavior if special indicator '+' explicitly given or separator is space; otherwise we will
	-- break existing behavior with hyphenated words.
	if (special == "+" or sep == " ") and form:find(sep) then
		-- check for prepositions in the middle of the word; do it this way so we can handle
		-- more than one word before the preposition (and usually inflect each word)
		for _, prep in ipairs(prepositions) do
			local first, space_prep_rest = rmatch(form, hack_re("^(.-)( " .. prep .. ".*)$"))
			if first then
				return add_endings(inflect(first), space_prep_rest)
			end
		end

		-- multiword or hyphenated expressions default to first-last; we need to pass in the separator to avoid
		-- problems with multiword terms containing hyphens in the individual words
		return export.handle_multiword(form, "first-last", inflect, prepositions, sep)
	end

	return nil
end


-- Auto-add links to a word that should not have spaces but may have hyphens and/or apostrophes. We split off final
-- punctuation, then split on hyphens if `splithyph` is given, and also split on apostrophes. We only split on hyphens
-- and apostrophes if they are in the middle of the word, not at the beginning of end (hyphens at the beginning or end
-- indicate suffixes or prefixes, respectively, and apostrophes at the beginning or end are also possible, as in
-- Italian [['ndrangheta]] or [[po']]). The apostrophe is included in the link to its left (so we auto-split French
-- [[l'eau]] as [[l']][[eau]]). `no_split_apostrophe_words`, if given, is a set of words that contain apostrophes but
-- which should not be split on the apostrophes, such as French [[c'est]] and [[quelqu'un]]. `include_hyphen_prefixes`,
-- if given, is a set of prefixes (not including the final hyphen) where we should include the final hyphen in the
-- prefix. Hence, e.g. if "anti" is in the set, a Portuguese word like [[anti-herói]] "anti-hero" will be split
-- [[anti-]][[herói]] (whereas a word like [[código-fonte]] "source code" will be split as [[código]]-[[fonte]]).
local function add_single_word_links(space_word, splithyph, no_split_apostrophe_words, include_hyphen_prefixes)
	local space_word_no_punct, punct = rmatch(space_word, "^(.*)([,;:?!])$")
	space_word_no_punct = space_word_no_punct or space_word
	punct = punct or ""
	local words
	-- don't split prefixes and suffixes
	if not splithyph or space_word_no_punct:find("^%-") or space_word_no_punct:find("%-$") then
		words = {space_word_no_punct}
	else
		words = rsplit(space_word_no_punct, "%-")
	end
	local linked_words = {}
	for j, word in ipairs(words) do
		if j < #words and include_hyphen_prefixes and include_hyphen_prefixes[word] then
			word = "[[" .. word .. "-]]"
		else
			-- Don't split on apostrophes if the word is in `no_split_apostrophe_words` or begins or ends with an apostrophe
			-- (e.g. [['ndrangheta]] or [[po']]). Handle multiple apostrophes correctly, e.g. [[l'altr'ieri]].
			if (not no_split_apostrophe_words or not no_split_apostrophe_words[word]) and word:find("'")
				and not word:find("^'") and not word:find("'$") then
				local apostrophe_parts = rsplit(word, "'")
				for i, apostrophe_part in ipairs(apostrophe_parts) do
					if i == #apostrophe_parts then
						apostrophe_parts[i] = "[[" .. apostrophe_part .. "]]"
					else
						apostrophe_parts[i] = "[[" .. apostrophe_part .. "']]"
					end
				end
				word = table.concat(apostrophe_parts)
			else
				word = "[[" .. word .. "]]"
			end
			if j < #words then
				word = word .. "-"
			end
		end
		table.insert(linked_words, word)
	end
	return table.concat(linked_words) .. punct
end

-- Auto-add links to a lemma. Links are not added to single-word lemmas. We split on spaces, and also on hyphens if
-- `splithyph` is given or the word has no spaces. In addition, we split on apostrophes, including the apostrophe in
-- the link to its left (so we auto-split "de l'eau" "[[de]] [[l']][[eau]]"). We don't always split on hyphens because
-- of cases like "boire du petit-lait" where "petit-lait" should be linked as a whole, but provide the option to do it
-- for cases like "croyez-le ou non". If there's no space, however, then it makes sense to split on hyphens by default
-- (e.g. for "avant-avant-hier"). Cases where only some of the hyphens should be split can always be handled by
-- explicitly specifying the head (e.g. "Nord-Pas-de-Calais" given as head=[[Nord]]-[[Pas-de-Calais]]).
--
-- `no_split_apostrophe_words` and `include_hyphen_prefixes` allow for special-case handling of particular words and
-- are as described in the comment above add_single_word_links().
function export.add_lemma_links(lemma, splithyph, no_split_apostrophe_words, include_hyphen_prefixes)
	if not rfind(lemma, " ") then
		splithyph = true
	end
	local words = rsplit(lemma, " ")
	local linked_words = {}
	for _, word in ipairs(words) do
		table.insert(linked_words, add_single_word_links(word, splithyph, no_split_apostrophe_words,
			include_hyphen_prefixes))
	end
	local retval = table.concat(linked_words, " ")
	-- If we ended up with a single link consisting of the entire lemma,
	-- remove the link.
	local unlinked_retval = rmatch(retval, "^%[%[([^%[%]]*)%]%]$")
	return unlinked_retval or retval
end


return export
