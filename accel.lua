local export = {}

local rsplit = mw.text.split
local split_term_regex = "%*~!"

-- FIXME: Intentionally global, but think whether this is correct. Currently no messages are logged in any code.
-- This potentially could be made non-global by moving inside of generate_JSON() and passed into export.generate(),
-- so it can in turn be passed to language-specific accelerator code.
messages = require("Module:array")() -- intentionally global

 
function export.default_entry(params)
	local function make_head(pos, default_gender)
		local gender = params.gender or default_gender
		local genderspec = ""
		if gender then
			local genders = rsplit(gender, ",")
			for i, g in ipairs(genders) do
				if i == 1 then
					genders[i] = "|g=" .. g
				else
					genders[i] = "|g" .. i .. "=" .. g
				end
			end
			genderspec = table.concat(genders)
		end
		local parts = {}
		table.insert(parts, "{{head|" .. params.lang .. "|" .. pos)
		for i, target in ipairs(params.targets) do
			local paramnum = i == 1 and "" or tostring(i)
			if target.term ~= params.target_pagename then
				table.insert(parts, ("|head%s=%s"):format(paramnum, target.term))
			end
			if target.translit then
				table.insert(parts, ("|tr%s=%s"):format(paramnum, target.translit))
			end
		end
		table.insert(parts, genderspec .. "}}")
		return table.concat(parts)
	end

	local function make_def(tempname, extra_params)
		local parts = {}
		table.insert(parts, "{{" .. tempname .. "|" .. params.lang)
		for i, origin in ipairs(params.origins) do
			local termparam, trparam
			if i == 1 then
				termparam = ""
				trparam = "tr="
			else
				termparam = "term" .. i .. "="
				trparam = "tr" .. i .. "="
			end
			table.insert(parts, ("|%s%s"):format(termparam, origin.term))
			if origin.translit then
				table.insert(parts, ("|%s%s"):format(trparam, origin.translit))
			end
		end
		table.insert(parts, (extra_params or "") .. "}}")
		return table.concat(parts)
	end

	local function no_rule_error(params)
		-- FIXME, verify the 2 below (number of stack frames to pop off); may be wrong now that we moved this function
		-- underneath default_entry().
		return error(('No rule for "%s" in language "%s".')
			:format(params.form, params.lang), 2)
	end

	local entry = {
		etymology = nil,
		pronunc = nil,
		pos_header = mw.getContentLanguage():ucfirst(params.pos),
		head = make_head(params.pos .. " form"),
		def = make_def("inflection of", "||" .. params.form),
		inflection = nil,
		declension = nil,
		conjugation = nil,
		mutation = nil,
		altforms = nil,
		-- also pass in functions
		make_head = make_head,
		make_def = make_def,
		no_rule_error = no_rule_error,
	}
	
	-- Exceptions for some forms
	local templates = {
		["p"] = "plural of",
		["f"] = "feminine of",
		["f|s"] = "feminine singular of",
		["m|p"] = "masculine plural of",
		["f|p"] = "feminine plural of",
		["pejorative"] = "pejorative of",
	}
	
	if params.form == "comparative" or params.form == "superlative" or params.form == "equative" then
		entry.head = make_head(params.form .. " " .. params.pos)
		entry.def = make_def(params.form .. " of", params.pos ~= "adjective" and "|POS=" .. params.pos or "")
	elseif params.form == "diminutive" or params.form == "augmentative" then
		entry.head = make_head(params.pos)
		entry.def = make_def(params.form .. " of", params.pos ~= "noun" and "|POS=" .. params.pos or "")
	elseif params.form == "f" and params.pos == "noun" then
		entry.head = make_head(params.pos, "f")
		entry.def = make_def("female equivalent of")
	elseif (params.form == "abstract noun" or params.form == "verbal noun") and params.pos == "noun" then
		entry.head = make_head(params.pos)
		entry.def = make_def(params.form .. " of")
	elseif templates[params.form] then
		entry.def = make_def(templates[params.form])
	end
	
	return entry
end

-- Given a list of tags, split into tag sets (separated by semicolons in
-- the initial list of tags).
local function split_tags_into_tag_sets(tags)
	local tag_set_group = {}
	local cur_tag_set = {}
	for _, tag in ipairs(tags) do
		if tag == ";" then
			if #cur_tag_set > 0 then
				table.insert(tag_set_group, cur_tag_set)
			end
			cur_tag_set = {}
		else
			table.insert(cur_tag_set, tag)
		end
	end
	if #cur_tag_set > 0 then
		table.insert(tag_set_group, cur_tag_set)
	end
	return tag_set_group
end

-- Canonicalize multipart shortcuts (e.g. "123" -> "1//2//3") and
-- list shortcuts (e.g. "1s" -> {"1", "s"}); leave others alone.
local function canonicalize_multipart_and_list_shortcuts(tags)
	local result = {}
	for _, tag in ipairs(tags) do
		local expansion = require("Module:form of").lookup_shortcut(tag)
		if type(expansion) == "string" and not expansion:find("//", nil, true) then
			expansion = tag
		end
		if type(expansion) == "table" then
			for _, t in ipairs(expansion) do
				table.insert(result, t)
			end
		else
			table.insert(result, expansion)
		end
	end
	return result
end

-- Split a multipart tag into component tags, normalize each component, and
-- return the resulting list. If MAP_TO_CANONICAL_SHORTCUT is given,
-- attempt to map each normalized component tag to its "canonical shortcut",
-- i.e. the first shortcut listed among its shortcuts.
--
-- If given a two-level multipart tag such as "1:sg//3:pl", the resulting
-- return value will be {"first:singular", "third:plural"}, or {"1:s", "3:p"}
-- if MAP_TO_CANONICAL_SHORTCUT is given.
local function split_and_normalize_tag(tag, map_to_canonical_shortcut)
	local m_form_of = require("Module:form of")
	local normalized = m_form_of.normalize_tags({tag}, true)
	assert(#normalized == 1, "Something is wrong, encountered list tag " .. tag .. ", which should have been canonicalized earlier")
	tag = normalized[1]
	if tag:find("://") then
		-- HTML URL???
		return {tag}
	else
		local tags = rsplit(tag, "//")
		if map_to_canonical_shortcut then
			for i=1,#tags do
				if tags[i]:find(":") then
					local split_tags = rsplit(tags[i], ":")
					for j=1,#split_tags do
						local tagobj = m_form_of.lookup_tag(split_tags[j])
						split_tags[j] = tagobj and tagobj.shortcuts and tagobj.shortcuts[1] or split_tags[j]
					end
					tags[i] = table.concat(split_tags, ":")
				else
					local tagobj = m_form_of.lookup_tag(tags[i])
					tags[i] = tagobj and tagobj.shortcuts and tagobj.shortcuts[1] or tags[i]
				end
			end
		end
		return tags
	end
end

-- Given a normalized tag, return its tag type, or "unknown" if a tag type
-- cannot be located (either the tag isn't recognized or for some reason
-- it doesn't specify a tag type).
local function get_normalized_tag_type(tag)
	local tagobj = require("Module:form of").lookup_tag(tag)
	return tagobj and tagobj.tag_type or "unknown"
end

-- Combine multiple semicolon-separated tag sets into multipart tags if
-- possible. We combine tag sets that differ in only one tag in a given
-- dimension, and repeat this until no changes in case we can reduce along
-- multiple dimensions, e.g.
--
-- {{inflection of|la|canus||dat|m|p|;|dat|f|p|;|dat|n|p|;|abl|m|p|;|abl|f|p|;|abl|n|p}}
--
-- {{inflection of|la|canus||dat//abl|m//f//n|p}}
function export.combine_tag_sets_into_multipart(tags)
	-- First, as an optimization, make sure there are multiple tag sets.
	-- Otherwise, do nothing.
	local found_semicolon = false
	for _, tag in ipairs(tags) do
		if tag == ";" then
			found_semicolon = true
			break
		end
	end
	if not found_semicolon then
		return tags
	end

	local m_table = require("Module:table")

	-- Repeat until no changes can be made.
	while true do
		-- First, canonicalize 1s etc. into 1|s
		local canonicalized_tags = canonicalize_multipart_and_list_shortcuts(tags)
		local old_canonicalized_tags = canonicalized_tags

		-- Then split into tag sets.
		local tag_set_group = split_tags_into_tag_sets(canonicalized_tags)

		-- Try combining in two different styles ("adjacent-first" =
		-- do two passes, where the first pass only combines adjacent
		-- tag sets, while the second pass combines nonadjacent tag sets;
		-- "all-first" = do one pass combining nonadjacent tag sets).
		-- Sometimes one is better, sometimes the other.
		--
		-- An example where adjacent-first is better:
		--
		-- {{inflection of|la|medius||m|acc|s|;|n|nom|s|;|n|acc|s|;|n|voc|s}}
		--
		-- all-first results in
		--
		-- {{inflection of|la|medius||m//n|acc|s|;|n|nom//voc|s}}
		--
		-- which isn't ideal.
		--
		-- If we do adjacent-first, we get
		--
		-- {{inflection of|la|medius||m|acc|s|;|n|nom//acc//voc|s}}
		--
		-- which is much better.
		--
		-- The opposite happens in
		--
		-- {{inflection of|grc|βουλόμενος||n|nom|s|;|m|acc|s|;|n|acc|s|;|n|voc|s}}
		--
		-- where all-first results in
		--
		-- {{inflection of|grc|βουλόμενος||n|nom//acc//voc|s|;|m|acc|s}}
		--
		-- which is better than the result from adjacent-first, which is
		--
		-- {{inflection of|grc|βουλόμενος||n|nom//voc|s|;|m//n|acc|s}}
		--
		-- To handle this conundrum, we try both, and look to see which one
		-- results in fewer "combinations" (where a tag with // in it counts
		-- as a combination). If both are different but have the same # of
		-- combinations, we prefer adjacent-first, we seems generally a better
		-- approach.

		local tag_set_group_by_style = {}

		for _, combine_style in ipairs({"adjacent-first", "all-first"}) do
			-- Now, we do two passes. The first pass only combines adjacent
			-- tag sets, while the second pass combines nonadjacent tag sets.
			-- Copy tag_set_group, since we destructively modify the list.
			local tag_sets = m_table.shallowClone(tag_set_group)
			local combine_passes
			if combine_style == "adjacent-first" then
				combine_passes = {"adjacent", "all"}
			else
				combine_passes = {"all"}
			end
			for _, combine_pass in ipairs(combine_passes) do
				local tag_ind = 1
				while tag_ind <= #tag_sets do
					local from, to
					if combine_pass == "adjacent" then
						if tag_ind == 1 then
							from = 1
							to = 0
						else
							from = tag_ind - 1
							to = tag_ind - 1
						end
					else
						from = 1
						to = tag_ind - 1
					end
					local inner_broken = false
					for prev_tag_ind=from,to do
						local cur_tag_set = tag_sets[prev_tag_ind]
						local tag_set = tag_sets[tag_ind]
						if #cur_tag_set == #tag_set then
							local mismatch_ind = nil
							local innermost_broken = false
							for i=1,#tag_set do
								local tag1 = split_and_normalize_tag(cur_tag_set[i])
								local tag2 = split_and_normalize_tag(tag_set[i])
								if not m_table.deepEquals(m_table.listToSet(tag1),
									m_table.listToSet(tag2)) then
									if mismatch_ind then
										innermost_broken = true
										break
									end
									local combined_dims = {}
									for _, tag in ipairs(tag1) do
										combined_dims[get_normalized_tag_type(tag)] = true
									end
									for _, tag in ipairs(tag2) do
										combined_dims[get_normalized_tag_type(tag)] = true
									end
									if m_table.size(combined_dims) == 1 and not combined_dims["unknown"] then
										mismatch_ind = i
									else
										innermost_broken = true
										break
									end
								end
							end
							if not innermost_broken then
								-- No break, we either match perfectly or are combinable
								if not mismatch_ind then
									-- Two identical tag sets
									table.remove(tag_sets, tag_ind)
									inner_broken = true
									break
								else
									-- Combine tag sets at mismatch_ind, using the canonical shortcuts.
									tag1 = cur_tag_set[mismatch_ind]
									tag2 = tag_set[mismatch_ind]
									tag1 = split_and_normalize_tag(tag1, true)
									tag2 = split_and_normalize_tag(tag2, true)
									local combined_tag = table.concat(m_table.append(tag1, tag2), "//")
									local new_tag_set = {}
									for i=1,#cur_tag_set do
										if i == mismatch_ind then
											table.insert(new_tag_set, combined_tag)
										else
											local cur_canon_tag = split_and_normalize_tag(cur_tag_set[i])
											local canon_tag = split_and_normalize_tag(tag_set[i])
											assert(m_table.deepEquals(m_table.listToSet(cur_canon_tag),
												m_table.listToSet(canon_tag)))
											table.insert(new_tag_set, cur_tag_set[i])
										end
									end
									tag_sets[prev_tag_ind] = new_tag_set
									table.remove(tag_sets, tag_ind)
									inner_broken = true
									break
								end
							end
						end
					end
					if not inner_broken then
						-- No break from inner for-loop. Break from that loop indicates
						-- that we found that the current tag set can be combined with
						-- a preceding tag set, did the combination and deleted the
						-- current tag set. The next iteration then processes the same
						-- numbered tag set again (which is actually the following tag
						-- set, because we deleted the tag set before it). No break
						-- indicates that we couldn't combine the current tag set with
						-- any preceding tag set, and need to advance to the next one.
						tag_ind = tag_ind + 1
					end
				end
			end
			tag_set_group_by_style[combine_style] = tag_sets
		end

		local tag_set_group
		
		if not m_table.deepEqualsList(tag_set_group_by_style["adjacent-first"], tag_set_group_by_style["all-first"]) then
			local function num_combinations(group)
				local num_combos = 0
				for _, tag_set in ipairs(group) do
					for _, tag in ipairs(tag_set) do
						if tag:find("//") then
							num_combos = num_combos + 1
						end
					end
				end
				return num_combos
			end

			local num_adjacent_first_combos = num_combinations(tag_set_group_by_style["adjacent-first"])
			local num_all_first_combos = num_combinations(tag_set_group_by_style["all-first"])
			if num_adjacent_first_combos < num_all_first_combos then
				tag_set_group = tag_set_group_by_style["adjacent-first"]
			elseif num_all_first_combos < num_adjacent_first_combos then
				tag_set_group = tag_set_group_by_style["all-first"]
			else
				tag_set_group = tag_set_group_by_style["adjacent-first"]
			end
		else
			-- Both are the same, pick either one
			tag_set_group = tag_set_group_by_style["adjacent-first"]
		end

		canonicalized_tags = {}
		for _, tag_set in ipairs(tag_set_group) do
			if #canonicalized_tags > 0 then
				table.insert(canonicalized_tags, ";")
			end
			for _, tag in ipairs(tag_set) do
				table.insert(canonicalized_tags, tag)
			end
		end
		if m_table.deepEqualsList(canonicalized_tags, old_canonicalized_tags) then
			break
		end
		-- FIXME, we should consider reversing the transformation 1s -> 1|s,
		-- but it's complicated to figure out when the transformation occurred;
		-- not really important as both are equivalent
		tags = canonicalized_tags
	end

	return tags
end

-- Test function, callable externally.
function export.test_combine_tag_sets_into_multipart(frame)
	local combined_tags = export.combine_tag_sets_into_multipart(frame.args)
	return table.concat(combined_tags, "|")
end

local function find_mergeable(entry, candidates)
	local function can_merge(candidate)
		for _, key in ipairs({"pronunc", "pos_header", "head", "inflection", "declension", "conjugation", "altforms"}) do
			if entry[key] ~= candidate[key] then
				return false
			end
		end
		
		return true
	end
	
	for _, candidate in ipairs(candidates) do
		if can_merge(candidate) then
			return candidate
		end
	end
	
	return nil
end

-- Merge multiple entries into one if they differ only in the definition, with all other
-- properties the same. The combined entry has multiple definition lines. We then do
-- further frobbing of {{inflection of}} lines:
--
-- 1. Convert lang= param to param 1 (there shouldn't be any remaining cases of accelerator
--    modules generating {{inflection of}} templates with lang=, but we do this just in case).
-- 2. Combine adjacent {{inflection of}} lines that differ only in the tags, e.g.:
--
--    # {{inflection of|la|bonus||nom|m|s}}
--    # {{inflection of|la|bonus||nom|n|s}}
--    # {{inflection of|la|bonus||acc|n|s}}
--    # {{inflection of|la|bonus||voc|n|s}}
--
--    becomes
--
--    # {{inflection of|la|bonus||nom|m|s|;|nom|n|s|;|acc|n|s|;|voc|n|s}}
--
-- 3. Further group {{inflection of}} lines with multiple tag sets (as may be generated b y
--    the previous step) using multipart tags, e.g. for the Latin entry ''bonum'',
--
--    # {{inflection of|la|bonus||nom|m|s|;|nom|n|s|;|acc|n|s|;|voc|n|s}}
--
--    becomes
--
--    # {{inflection of|la|bonus||nom|m|s|;|nom//acc//voc|n|s}}
--
--    This grouping can group across multiple dimensions, e.g. for the Latin entry ''bonīs'',
--
--    # {{inflection of|la|bonus||dat|m|p|;|dat|f|p|;|dat|n|p|;|abl|m|p|;|abl|f|p|;|abl|n|p}}
--
--    becomes
--
--    # {{inflection of|la|bonus||dat//abl|m//f//n|p}}
--
--    Another complex real-world example, for the Old English weak adjective form ''dēorenan'':
--
--    # {{inflection of|ang|dēoren||wk|acc|m|sg|;|wk|acc|f|sg|;|wk|gen|m|sg|;|wk|gen|f|sg|;|wk|gen|n|sg|;|wk|dat|m|sg|;|wk|dat|f|sg|;|wk|dat|n|sg|;|wk|ins|m|sg|;|wk|ins|f|sg|;|wk|ins|n|sg|;|wk|nom|m|pl|;|wk|nom|f|pl|;|wk|nom|n|pl|;|wk|acc|m|pl|;|wk|acc|f|pl|;|wk|acc|n|pl}}
--
--    becomes
--
--    # {{inflection of|ang|dēoren||wk|acc|m//f|sg|;|wk|gen//dat//ins|m//f//n|sg|;|wk|nom//acc|m//f//n|pl}}
--
--    Here, 17 separate tag sets are combined down into 3.
local function merge_entries(entries)
	local entries_new = {}

	-- First rewrite {{inflection of|...|lang=LANG}} to {{inflection of|LANG|...}}
	for _, entry in ipairs(entries) do
		local params = entry.def:match("^{{inflection of|([^{}]+)}}$")
		if params then
			params = rsplit(params, "|", true)
			local new_params = {}
			for _, param in ipairs(params) do
				local lang = param:match("^lang=(.*)$")
				if lang then
					table.insert(new_params, 1, lang)
				else
					table.insert(new_params, param)
				end
			end
			entry.def = "{{inflection of|" .. table.concat(new_params, "|") .. "}}"
		end
	end

	-- Merge entries that match in all of the following properties:
	-- "pronunc", "pos_header", "head", "inflection", "declension", "conjugation", "altforms"
	-- This will merge any two mergeable entries even if non-consecutive.
	-- The definitions of the merged entries do not have to match, but any matching
	-- definitions will be deduped.
	for _, entry in ipairs(entries) do
		-- See if this entry can be merged with any previous entry.
		local merge_entry = find_mergeable(entry, entries_new)

		if merge_entry then
			local duplicate_def = false
			-- If we can merge, check whether the definition of the new entry is
			-- the same as any previous definitions.
			for _, def in ipairs(merge_entry.defs) do
				if def == entry.def then
					duplicate_def = true
					break
				end
			end

			if not duplicate_def then
				table.insert(merge_entry.defs, entry.def)
			end
		else
			entry.defs = {entry.def}
			table.insert(entries_new, entry)
		end
	end

	-- Combine the definitions for each entries, merging all {{inflection of}} calls
	-- into one such call with multiple tag sets.
	for _, entry in ipairs(entries_new) do
		local existing_defs = {}
		for _, new_def in ipairs(entry.defs) do
			local did_merge = false
			local new_params = new_def:match("^{{inflection of|([^{}]+)}}$")
			if new_params then
				-- The new definition is {{inflection of}}. See if there is an
				-- {{inflection of}} among the definitions seen so far.
				for i, existing_def in ipairs(existing_defs) do
					local existing_params = existing_def:match("^{{inflection of|([^{}]+)}}$")
					if existing_params then
						-- Merge the existing and new {{inflection of}} calls.
						-- Find the last unnamed parameter of the first template.
						existing_params = rsplit(existing_params, "|", true)
						local last_numbered_index
						
						for j, param in ipairs(existing_params) do
							if not param:find("=", nil, true) then
								last_numbered_index = j
							end
						end
						
						-- Add grammar tags of the second template
						new_params = rsplit(new_params, "|")
						local tags = {}
						local n = 0
						
						for k, param in ipairs(new_params) do
							if not param:find("=", nil, true) then
								n = n + 1
								
								-- Skip the first three unnamed parameters,
								-- which don't indicate grammar tags
								if n >= 4 then
									-- Now append the tags
									table.insert(tags, param)
								end
							end
						end
						
						-- Add the new parameters after the existing ones
						existing_params[last_numbered_index] = existing_params[last_numbered_index] .. "|;|" .. table.concat(tags, "|")
						existing_defs[i] = "{{inflection of|" .. table.concat(existing_params, "|") .. "}}"
						did_merge = true
						break
					end
				end
			end

			if not did_merge then
				table.insert(existing_defs, new_def)
			end
		end

		entry.def = table.concat(existing_defs, "\n# ")
	end
	
	-- Now combine tag sets inside a multiple-tag-set {{inflection of}} call
	for i, entry in ipairs(entries_new) do
		local infl_of_params = entry.def:match("^{{inflection of|([^{}]+)}}$")
			
		if infl_of_params then
			infl_of_params = rsplit(infl_of_params, "|", true)

			-- Find the last unnamed parameter
			local last_numbered_index
			
			for j, param in ipairs(infl_of_params) do
				if not param:find("=", nil, true) then
					last_numbered_index = j
				end
			end

			-- Split the params in three:
			-- (1) Params before the inflection tags, and any named params mixed in with the tags
			-- (2) The tags themselves
			-- (3) Named params after the tags
			local pre_tag_params = {}
			local tags = {}
			local post_tag_params = {}
			local n = 0
			
			for j, param in ipairs(infl_of_params) do
				if not param:find("=", nil, true) then
					n = n + 1
					
					-- Skip the first three unnamed parameters, which don't indicate grammar tags
					if n >= 4 then
						table.insert(tags, param)
					else
						table.insert(pre_tag_params, param)
					end
				elseif n >= last_numbered_index then
					table.insert(post_tag_params, param)
				else
					table.insert(pre_tag_params, param)
				end
				if not param:find("=", nil, true) then
					last_numbered_index = j
				end
			end

			-- Now combine tag sets.
			tags = export.combine_tag_sets_into_multipart(tags)

			-- Put the template back together.
			local combined_params = {}
			for _, param in ipairs(pre_tag_params) do
				table.insert(combined_params, param)
			end
			for _, param in ipairs(tags) do
				table.insert(combined_params, param)
			end
			for _, param in ipairs(post_tag_params) do
				table.insert(combined_params, param)
			end
			entry.def = "{{inflection of|" .. table.concat(combined_params, "|") .. "}}"
		end
	end

	return entries_new
end

local function entries_to_text(entries, lang)
	lang = require("Module:languages").getByCode(lang, "lang")
	for i, entry in ipairs(entries) do
		if entry.override then
			entry = "\n" ..(entry.override or "")
		else
			entry =
				"\n\n" ..
				(entry.etymology and "===Etymology===\n" .. entry.etymology .. "\n\n" or "") ..
				(entry.pronunc and "===Pronunciation===\n" .. entry.pronunc .. "\n\n" or "") ..
				"===" .. entry.pos_header .. "===\n" ..
				entry.head .. "\n\n" ..
				"# " .. entry.def ..
				(entry.inflection and "\n\n====Inflection====\n" .. entry.inflection or "") ..
				(entry.declension and "\n\n====Declension====\n" .. entry.declension or "") ..
				(entry.conjugation and "\n\n====Conjugation====\n" .. entry.conjugation or "") ..
				(entry.mutation and "\n\n===Mutation===\n" .. entry.mutation or "") ..
				(entry.altforms and "\n\n====Alternative forms====\n" .. entry.altforms or "")
		end
		entries[i] = entry
	end
	return "==" .. lang:getCanonicalName() .. "==" .. table.concat(entries)
end


local function split_term_and_translit(encoded_term, encoded_translit)
	local terms = rsplit(encoded_term, split_term_regex)
	local translits = encoded_translit and rsplit(encoded_translit, split_term_regex) or {}
	if #translits > #terms then
		error(("Saw %s translits, which is > the %s terms seen: encoded_term=%s, encoded_translit=%s"):
			format(#translits, #terms, encoded_term, encoded_translit))
	end
	local result = {}
	for i, term in ipairs(terms) do
		local translit = translits[i]
		if translit == "" then
			translit = nil
		end
		table.insert(result, {term = term, translit = translit})
	end
	return result
end


function export.generate(frame)
	local fparams = {
		lang            = {required = true},
		origin_pagename = {required = true},
		target_pagename = {required = true},
		num             = {required = true, type = "number"},
		
		pos                    = {list = true, allow_holes = true},
		form                   = {list = true, allow_holes = true},
		gender                 = {list = true, allow_holes = true},
		transliteration        = {list = true, allow_holes = true},
		origin                 = {list = true, allow_holes = true},
		origin_transliteration = {list = true, allow_holes = true},
		-- I'm pretty sure this is actually required and must have args.num entries in it.
		target                 = {list = true, allow_holes = true},
	}
	
	local args = require("Module:parameters").process(frame.args, fparams)
	
	local entries = {}
	
	-- Generate each entry
	for i = 1, args.num do
		local params = {
			lang = args.lang,
			origin_pagename = args.origin_pagename,
			target_pagename = args.target_pagename,
			
			pos = args.pos[i] or error("The argument \"pos\" is missing for entry " .. i),
			form = args.form[i] or error("The argument \"form\" is missing for entry " .. i),
			gender = args.gender[i],
			transliteration = args.transliteration[i],
			origin = args.origin[i] or error("The argument \"origin\" is missing for entry " .. i),
			origin_transliteration = args.origin_transliteration[i],
			target = args.target[i],
		}
		
		params.form = params.form:gsub("&#124;", "|")
		params.targets = split_term_and_translit(params.target, params.transliteration)
		params.origins = split_term_and_translit(params.origin, params.origin_transliteration)
		
		-- Make a default entry
		local entry = export.default_entry(params)
		
		-- Try to use a language-specific module, if one exists
		local success, lang_module = pcall(require, "Module:accel/" .. args.lang)
		
		if success then
			lang_module.generate(params, entry)
		end
		
		-- Add it to the list
		table.insert(entries, entry)
	end
	
	-- Merge entries if possible
	entries = merge_entries(entries)
	entries = entries_to_text(entries, args.lang)
	
	return entries
end


function export.generate_JSON(frame)
	local success, entries = pcall(export.generate, frame)
	
	-- If success is false, entries is an error message.
	local ret = { [success and "entries" or "error"] = entries, messages = messages }
	
	return require("Module:JSON").toJSON(ret)
end


return export
