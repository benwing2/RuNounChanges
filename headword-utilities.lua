local export = {}

local table_module = "Module:table"
local pattern_utilities_module = "Module:pattern utilities"

local rfind = mw.ustring.find
local rmatch = mw.ustring.match
local rsplit = mw.text.split
local rsubn = mw.ustring.gsub

-- version of rsubn() that discards all but the first return value
local function rsub(term, foo, bar)
	local retval = rsubn(term, foo, bar)
	return retval
end 


--[=[
Auto-add links to a word that should not have spaces but may have hyphens and/or apostrophes. We split off final
punctuation, then split on hyphens if `data.split_hyphen` is given, and also split on apostrophes if
`data.split_apostrophe` is given. We only split on hyphens if they are in the middle of the word, not at the beginning
or end (hyphens at the beginning or end indicate suffixes or prefixes, respectively). `include_hyphen_prefixes`, if
given, is a set of prefixes (not including the final hyphen) where we should include the final hyphen in the prefix.
Hence, e.g. if "anti" is in the set, a Portuguese word like [[anti-herói]] "anti-hero" will be split [[anti-]][[herói]]
(whereas a word like [[código-fonte]] "source code" will be split as [[código]]-[[fonte]]).

If `data.split_apostrophe` is specified, we split on apostrophes unless `data.no_split_apostrophe_words` is given and
the word is in the specified set, such as French [[c'est]] and [[quelqu'un]]. If `data.split_apostrophe` is true, the
default algorithm applies, which splits on all apostrophes except those at the beginning and end of a word (as in
Italian [['ndrangheta]] or [[po']]), and includes the apostrophe in the link to its left (so we auto-split French
[[l'eau]] as [[l']][[eau]] and [[l'altr'ieri]] as [[l']][altr']][[ieri]]). If `data.split_apostrophe` is specified
but not `true`, it should be a function of one argument that does custom apostrophe-splitting. The argument is the word
to split, and the return value should be the split and linked word.
]=]
local function add_single_word_links(space_word, data)
	local space_word_no_punct, punct = rmatch(space_word, "^(.*)([,;:?!])$")
	space_word_no_punct = space_word_no_punct or space_word
	punct = punct or ""
	local words
	-- don't split prefixes and suffixes
	if not data.split_hyphen or space_word_no_punct:find("^%-") or space_word_no_punct:find("%-$") then
		words = {space_word_no_punct}
	else
		words = rsplit(space_word_no_punct, "%-")
	end
	local linked_words = {}
	for j, word in ipairs(words) do
		if j < #words and data.include_hyphen_prefixes and data.include_hyphen_prefixes[word] then
			word = "[[" .. word .. "-]]"
		else
			-- Don't split on apostrophes if the word is in `no_split_apostrophe_words`.
			if (not data.no_split_apostrophe_words or not data.no_split_apostrophe_words[word]) and
				data.split_apostrophe and word:find("'") then
				if data.split_apostrophe == true then
					-- Default apostrophe-splitting algorithm. Don't split apostrophes at the beginning or end of a
					-- word (e.g. [['ndrangheta]] or [[po']]). Handle multiple apostrophes correctly, e.g.
					-- [[l'altr'ieri]] -> [[l']][altr']][[ieri]].
					local begapo, inner_word, endapo = word:match("^('*)(.-)('*)$")
					local apostrophe_parts = rsplit(word, "'")
					local linked_apostrophe_parts = {}
					local apostrophes_at_beginning = ""
					local i = 1
					-- Apostrophes at beginning get attached to the first word after (which will always exist but may
					-- be blank if the word consists only of apostrophes).
					while i < #apostrophe_parts do -- <, not <=, in case the word consists only of apostrophes
						local apostrophe_part = apostrophe_parts[i]
						i = i + 1
						if apostrophe_part == "" then
							apostrophes_at_beginning = apostrophes_at_beginning .. "'"
						else
							break
						end
					end
					apostrophe_parts[i] = apostrophes_at_beginning .. apostrophe_parts[i]
					-- Now, do the remaining parts. A blank part indicates more than one apostrophe in a row; we join
					-- all of them to the preceding word.
					while i <= #apostrophe_parts do
						local apostrophe_part = apostrophe_parts[i]
						if apostrophe_part == "" then
							linked_apostrophe_parts[#linked_apostrophe_parts] =
								linked_apostrophe_parts[#linked_apostrophe_parts] .. "'"
						elseif i == #apostrophe_parts then
							table.insert(linked_apostrophe_parts, apostrophe_part)
						else
							table.insert(linked_apostrophe_parts, apostrophe_part .. "'")
						end
						i = i + 1
					end
					for i, tolink in ipairs(linked_apostrophe_parts) do
						linked_apostrophe_parts[i] = "[[" .. tolink .. "]]"
					end
					word = table.concat(linked_apostrophe_parts)
				else -- custom apostrophe splitter/linker
					word = data.split_apostrophe(word)
				end
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

-- Auto-add links to a multiword term. Links are not added to single-word terms. We split on spaces, and also on hyphens
-- if `split_hyphen` is given or the word has no spaces. In addition, we split on apostrophes, including the apostrophe
-- in the link to its left (so we auto-split "de l'eau" "[[de]] [[l']][[eau]]"). We don't always split on hyphens
-- because of cases like "boire du petit-lait" where "petit-lait" should be linked as a whole, but provide the option to
-- do it for cases like "croyez-le ou non". If there's no space, however, then it makes sense to split on hyphens by
-- default (e.g. for "avant-avant-hier"). Cases where only some of the hyphens should be split can always be handled by
-- explicitly specifying the head (e.g. "Nord-Pas-de-Calais" given as head=[[Nord]]-[[Pas-de-Calais]]).
--
-- `no_split_apostrophe_words` and `include_hyphen_prefixes` allow for special-case handling of particular words and
-- are as described in the comment above add_single_word_links().
function export.add_links_to_multiword_term(term, data)
	if rfind(term, "[%[%]]") then
		return term
	end
	if not rfind(term, " ") then
		data = require(table_module).shallowcopy(data)
		data.split_hyphen = true
	end
	local words = rsplit(term, " ")
	local linked_words = {}
	for _, word in ipairs(words) do
		table.insert(linked_words, add_single_word_links(word, data))
	end
	local retval = table.concat(linked_words, " ")
	-- If we ended up with a single link consisting of the entire term,
	-- remove the link.
	local unlinked_retval = rmatch(retval, "^%[%[([^%[%]]*)%]%]$")
	return unlinked_retval or retval
end


-- Badly named older entry point. FIXME: Obsolete me!
function export.add_lemma_links(lemma, split_hyphen)
	return export.add_links_to_multiword_term(lemma, {split_hyphen = split_hyphen})
end


-- Ensure that brackets display literally in error messages. Replacing with equivalent HTML escapes doesn't work
-- because they are displayed literally; but inserting a Unicode word-joiner symbol works.
local function escape_wikicode(term)
	return require(put_module).escape_wikicode(term)
end


-- Given a `linked_term` that is the output of add_links_to_multiword_term(), apply modifications as given in
-- `modifier_spec` to change the link destination of subterms (normally single-word non-lemma forms; sometimes
-- collections of adjacent words). This is usually used to link non-lemma forms to their corresponding lemma, but can
-- also be used to replace a span of adjacent separately-linked words to a single multiword lemma. The format of
-- `modifier_spec` is one or more semicolon-separated subterm specs, where each such spec is of the form
-- SUBTERM:DEST, where SUBTERM is one or more words in the `linked_term` but without brackets in them, and DEST is the
-- corresponding link destination to link the subterm to. Any occurrence of ~ in DEST is replaced with SUBTERM.
-- Alternatively, a single modifier spec can be of the form BEGIN[FROM:TO], which is equivalent to writing
-- BEGINFROM:BEGINTO (see example below).
--
-- For example, given the source phrase [[il bue che dice cornuto all'asino]] "the pot calling the kettle black"
-- (literally "the ox that calls the donkey horned/cuckolded"), the result of calling add_links_to_multiword_term()
-- is [[il]] [[bue]] [[che]] [[dice]] [[cornuto]] [[all']][[asino]]. With a modifier_spec of 'dice:dire', the result
-- is [[il]] [[bue]] [[che]] [[dire|dice]] [[cornuto]] [[all']][[asino]]. Here, based on the modifier spec, the
-- non-lemma form [[dice]] is replaced with the two-part link [[dire|dice]].
-- 
-- Another example: given the source phrase [[chi semina vento raccoglie tempesta]] "sow the wind, reap the whirlwind"
-- (literally (he) who sows wind gathers [the] tempest"). The result of calling add_links_to_multiword_term() is
-- [[chi]] [[semina]] [[vento]] [[raccoglie]] [[tempesta]], and with a modifier_spec of 'semina:~re; raccoglie:~re',
-- the result is [[chi]] [[seminare|semina]] [[vento]] [[raccogliere|raccoglie]] [[tempesta]]. Here we use the ~
-- notation to stand for the non-lemma form in the destination link.
--
-- A more complex example is [[se non hai altri moccoli puoi andare a letto al buio]], which becomes
-- [[se]] [[non]] [[hai]] [[altri]] [[moccoli]] [[puoi]] [[andare]] [[a]] [[letto]] [[al]] [[buio]] after calling
-- add_links_to_multiword_term(). With the following modifier_spec:
-- 'hai:avere; altr[i:o]; moccol[i:o]; puoi: potere; andare a letto:~; al buio:~', the result of applying the spec is
-- [[se]] [[non]] [[avere|hai]] [[altro|altri]] [[moccolo|moccoli]] [[potere|puoi]] [[andare a letto]] [[al buio]].
-- Here, we rely on the alternative notation mentioned above for e.g. 'altr[i:o]', which is equivalent to 'altri:altro',
-- and link multiword subterms using e.g. 'andare a letto:~'. (The code knows how to handle multiword subexpressions
-- properly, and if the link text and destination are the same, only a single-part link is formed.)
function export.apply_link_modifiers(linked_term, modifier_spec)
	local split_modspecs = rsplit(modifier_spec, "%s*;%s*")
	for j, modspec in ipairs(split_modspecs) do
		local subterm, dest, otherlang
		local begin_from, begin_to, rest, end_from, end_to = modspec:match("^%[(.-):(.*)%]([^:]*)%[(.-):(.*)%]$")
		if begin_from then
			subterm = begin_from .. rest .. end_from
			dest = begin_to .. rest .. end_to
		end
		if not subterm then
			rest, end_from, end_to = modspec:match("^([^:]*)%[(.-):(.*)%]$")
			if rest then
				subterm = rest .. end_from
				dest = rest .. end_to
			end
		end
		if not subterm then
			begin_from, begin_to, rest = modspec:match("^%[(.-):(.*)%]([^:]*)$")
			if begin_from then
				subterm = begin_from .. rest
				dest = begin_to .. rest
			end
		end
		if not subterm then
			subterm, dest = modspec:match("^(.-)%s*:%s*(.*)$")
			if subterm and subterm ~= "^" and subterm ~= "$" then
				local langdest
				-- Parse off an initial language code (e.g. 'en:Higgs', 'la:minūtia' or 'grc:σκατός'). Also handle
				-- Wikipedia prefixes ('w:Abatemarco' or 'w:it:Colle Val d'Elsa').
				otherlang, langdest = dest:match("^([A-Za-z0-9._-]+):([^ ].*)$")
				if otherlang == "w" then
					local foreign_wikipedia, foreign_term = langdest:match("^([A-Za-z0-9._-]+):([^ ].*)$")
					if foreign_wikipedia then
						otherlang = otherlang .. ":" .. foreign_wikipedia
						langdest = foreign_term
					end
					dest = ("%s:%s"):format(otherlang, langdest)
					otherlang = nil
				elseif otherlang then
					otherlang = require("Module:languages").getByCode(otherlang, true, "allow etym")
					dest = langdest
				end
			end
		end
		if not subterm then
			error(("Single modifier spec %s should be of the form SUBTERM:DEST where SUBTERM is one or more words in a multiword "
					.. "term and DEST is the destination to link the subterm to (possibly prefixed by a language code); or of "
					.. "the form BEGIN[FROM:TO], which is equivalent to BEGINFROM:BEGINTO; or similarly [FROM:TO]END, which is "
					.. "equivalent to FROMEND:TOEND"):
				format(modspec))
		end
		if subterm == "^" then
			linked_term = dest:gsub("_", " ") .. linked_term
		elseif subterm == "$" then
			linked_term = linked_term .. dest:gsub("_", " ")
		else
			if subterm:find("%[") then
				error(("Subterm '%s' in modifier spec '%s' cannot have brackets in it"):format(
					escape_wikicode(subterm), escape_wikicode(modspec)))
			end
			local patut = require(pattern_utilities_module)
			local escaped_subterm = patut.pattern_escape(subterm)
			local subterm_re = "%[%[" .. escaped_subterm:gsub("(%%?[ '%-])", "%%]*%1%%[*") .. "%]%]"
			local expanded_dest
			if dest:find("~") then
				expanded_dest = dest:gsub("~", patut.replacement_escape(subterm))
			else
				expanded_dest = dest
			end
			if otherlang then
				expanded_dest = expanded_dest .. "#" .. otherlang:getCanonicalName()
			end

			local subterm_replacement
			if expanded_dest:find("%[") then
				-- Use the destination directly if it has brackets in it (e.g. to put brackets around parts of a word).
				subterm_replacement = expanded_dest
			elseif expanded_dest == subterm then
				subterm_replacement = "[[" .. subterm .. "]]"
			else
				subterm_replacement = "[[" .. expanded_dest .. "|" .. subterm .. "]]"
			end

			local replaced_linked_term = rsub(linked_term, subterm_re, patut.replacement_escape(subterm_replacement))
			if replaced_linked_term == linked_term then
				error(("Subterm '%s' could not be located in %slinked expression %s, or replacement same as subterm"):format(
					subterm, j > 1 and "intermediate " or "", escape_wikicode(linked_term)))
			else
				linked_term = replaced_linked_term
			end
		end
	end

	return linked_term
end


return export
