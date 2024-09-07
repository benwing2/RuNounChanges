local export = {}

--[=[

Authorship: Ben Wing <benwing2>

This module implements {{ar-verb form}}, which automatically generates the appropriate inflections of a non-lemma
verb form given the form and the conjugation spec for the verb (which is usually just the lemma and verb form; see
{{ar-conj}}/{{ar-verb}}).
]=]

local force_cat = false -- set to true for debugging

local m_links = require("Module:links")
local m_table = require("Module:table")
local m_form_of = require("Module:form of")
local m_string_utilities = require("Module:string utilities")
local accel_module = "Module:accel"
local headword_module = "Module:headword"
local ar_verb_module = "Module:ar-verb"
local ar_IPA_module = "Module:ar-IPA"
local IPA_module = "Module:IPA"
local template_parser_module = "Module:template parser"
local utilities_module = "Module:utilities"
local lang = require("Module:languages").getByCode("ar")

local rsplit = m_string_utilities.split

local function track(page)
	require("Module:debug/track")("ar-inflections/" .. page)
	return true
end

local function get_pronun(form, tr)
	local pronun = require(ar_IPA_module).toIPA({ Arabic = form, tr = tr}, "noerror")
	if pronun == "" then
		return nil
	else
		return require(IPA_module).format_IPA(lang, "/" .. pronun .. "/")
	end
end

local function find_conjugations(lemma, verb_form)
	local title = mw.title.new(lemma)
	if title then
		local content = title:getContent()
		if content then
			local arabic = require(utilities_module).get_section(content, "Arabic")
			if arabic then
				local conjs = {}
				local other_verb_forms = {}
				local saw_multiword_conj = 0
				for tempname, args, template_invoc, _ in require(template_parser_module).findTemplates(arabic) do
					if tempname == "ar-conj" then
						local arg1 = args[1]
						if arg1 then
							arg1 = arg1:match("^<(.*)>$") or arg1
							if arg1:find("<") or arg1:find("%(%(") then
								mw.log(('find_conjugations("%s", "%s"): Skipping multiword conjugation: %s'):format(
									lemma, verb_form, template_invoc))
								saw_multiword_conj = saw_multiword_conj + 1
							else
								local arg1_verb_form = arg1:gsub("[/.].*$", "")
								if arg1_verb_form == verb_form then
									table.insert(conjs, {
										conj = ("%s<%s>"):format(lemma, arg1),
										gloss = args.t,
									})
								else
									m_table.insertIfNot(other_verb_forms, arg1)
								end
							end
						end
					end
				end
				if conjs[1] then
					return conjs
				elseif other_verb_forms[1] then
					error(("For Arabic lemma '%s', found Arabic section but couldn't find conjugation for form %s (found conjugation(s) for form(s) %s%s"):format(
						lemma, verb_form, table.concat(other_verb_forms, ","), saw_multiword_conj > 0 and
						("; also skipped %s multiword conjugation(s)"):format(saw_multiword_conj) or ""))
				elseif saw_multiword_conj > 0 then
					error(("For Arabic lemma '%s', found Arabic section but couldn't find any verb conjugations when looking for form %s (but skipped %s multiword conjugation(s))"):format(
						lemma, verb_form, saw_multiword_conj))
				else
					error(("For Arabic lemma '%s', found Arabic section but couldn't find any verb conjugations when looking for form %s%s"):format(
						lemma, verb_form, saw_multiword_conj > 0 and (" (but skipped %s multiword conjugation(s))"):format(
							saw_multiword_conj)))
				end
			else
				error(("For Arabic lemma '%s', page exists but has no Arabic section when looking for form %s"):format(
					lemma, verb_form))
			end
		else
			error(("For Arabic lemma '%s', couldn't fetch contents for page when looking for form %s; page may not exist"):format(
			lemma, verb_form))
		end
	else
		error(("Bad Arabic lemma '%s' when looking for form %s; couldn't create title object"):format(lemma, verb_form))
	end
end


local function generate_inflection_of(forms_and_tags, vforms, pagename, is_template_example)
	-- There are two approaches for combining tag sets and lemmas: Either we combine the lemmas first or the tag sets
	-- first. Combining the lemmas first means we look for all instances of a given tag set and combine all the lemmas
	-- with that tag set, and then, for each given set of lemmas, find all tag sets with that set of lemmas and run
	-- the multipart combination algorithm on them. Combining the tag sets first means that first, for each given
	-- lemma, we find all tag sets for that lemma and run the multipart combination algorithm on them, then for each
	-- resulting multipart tag set, we group all instances, and then finally group by set of lemmas. It's not clear
	-- which one results in fewer overall lines, so we do it both ways and see which one results in fewer lines.

	for _, form_and_tags in ipairs(forms_and_tags) do
		local by_lemma_sets_by_stage = {}
		local stages = { "lemmas-first", "tag-sets-first" }
		for _, stage in ipairs(stages) do
			if stage == "lemmas-first" then
				-- Within a given form, we have a collection of lemma+tag-set objects. Group first by tag set.
				local group_by_tag_set = {}
				for _, lemma_tag_set in ipairs(form_and_tags.lemmas_tag_sets) do
					m_table.insertIfNot(group_by_tag_set, {
						tag_set = lemma_tag_set.tag_set,
						lemmas = {lemma_tag_set.lemma},
					}, {
						key = function(obj) return obj.tag_set end,
						combine = function(obj1, obj2)
							for _, lemma in ipairs(obj2.lemmas) do
								m_table.insertIfNot(obj1.lemmas, lemma)
							end
						end,
					})
				end
				-- Then group further by lemma set.
				local group_by_lemma_set = {}
				for _, by_tag_set in ipairs(group_by_tag_set) do
					m_table.insertIfNot(group_by_lemma_set, {
						tag_sets = {by_tag_set.tag_set},
						lemmas = by_tag_set.lemmas,
					}, {
						key = function(obj) return obj.lemmas end,
						combine = function(obj1, obj2)
							for _, tag_set in ipairs(obj2.tag_sets) do
								m_table.insertIfNot(obj1.tag_sets, tag_set)
							end
						end,
					})
				end
				-- Finally, run the multipart combination algorithm.
				for _, by_lemma_set in ipairs(group_by_lemma_set) do
					for i, tag_set in ipairs(by_lemma_set.tag_sets) do
						by_lemma_set.tag_sets[i] = {tags = rsplit(tag_set, "|", true)}
					end
					if by_lemma_set.tag_sets[2] then -- more than one
						by_lemma_set.tag_sets = require(accel_module).combine_tag_sets_into_multipart(
							by_lemma_set.tag_sets, lang, "verb")
					end
				end
				by_lemma_sets_by_stage[stage] = group_by_lemma_set
			else
				-- First group by lemma.
				local group_by_lemma = {}
				for _, lemma_tag_set in ipairs(form_and_tags.lemmas_tag_sets) do
					m_table.insertIfNot(group_by_lemma, {
						lemma = lemma_tag_set.lemma,
						tag_sets = {lemma_tag_set.tag_set},
					}, {
						key = function(obj) return obj.lemma end,
						combine = function(obj1, obj2)
							for _, tag_set in ipairs(obj2.tag_sets) do
								m_table.insertIfNot(obj1.tag_sets, tag_set)
							end
						end,
					})
				end
				-- Then run the multipart combination algorithm.
				for _, by_lemma in ipairs(group_by_lemma) do
					for i, tag_set in ipairs(by_lemma.tag_sets) do
						by_lemma.tag_sets[i] = {tags = rsplit(tag_set, "|", true)}
					end
					if by_lemma.tag_sets[2] then -- more than one
						by_lemma.tag_sets = require(accel_module).combine_tag_sets_into_multipart(
							by_lemma.tag_sets, lang, "verb")
					end
				end
				-- Finally group further by tag-set set.
				local group_by_tag_set_set = {}
				for _, by_lemma in ipairs(group_by_lemma) do
					m_table.insertIfNot(group_by_tag_set_set, {
						tag_sets = by_lemma.tag_sets,
						lemmas = {by_lemma.lemma},
					}, {
						key = function(obj) return obj.tag_sets end,
						combine = function(obj1, obj2)
							for _, lemma in ipairs(obj2.lemmas) do
								m_table.insertIfNot(obj1.lemmas, lemma)
							end
						end,
					})
				end
				by_lemma_sets_by_stage[stage] = group_by_tag_set_set
			end
		end

		local lines_by_stage = {}
		for _, stage in ipairs(stages) do
			local by_lemma_sets = by_lemma_sets_by_stage[stage]
			local num_lines = 0
			for _, by_lemma_set in ipairs(by_lemma_sets) do
				num_lines = num_lines + #by_lemma_set.tag_sets
			end
			lines_by_stage[stage] = num_lines
		end

		local by_lemma_sets
		if lines_by_stage["lemmas-first"] <= lines_by_stage["tag-sets-first"] then
			by_lemma_sets = by_lemma_sets_by_stage["lemmas-first"]
		else
			by_lemma_sets = by_lemma_sets_by_stage["tag-sets-first"]
		end
		form_and_tags.by_lemma_sets = by_lemma_sets
	end

	local function get_verb_forms_as_inflections()
		local formatted_vforms = {}
		-- FIXME: Duplicated in [[Module:ar-headword]]
		for _, vform in ipairs(vforms) do
			table.insert(formatted_vforms,
				{ label = "[[Appendix:Arabic verbs#Form " .. vform .. "|form " .. vform .. "]]" })
		end
		return formatted_vforms
	end

	local parts = {}
	local function ins(part)
		table.insert(parts, part)
	end
	local function add_lang_to_lemmas(lemmas)
		-- add lang; if the lang is already assigned, this isn't a big deal due to idempotency
		for _, lemma in ipairs(lemmas) do
			lemma.lang = lang
		end
	end

	if forms_and_tags[2] then -- more than one
		ins(require(headword_module).full_headword {
			lang = lang,
			pos_category = "verb forms",
			heads = is_template_example and {"كتبت"} or nil,
			inflections = get_verb_forms_as_inflections(),
			pagename = pagename,
			translits = {"-"},
			force_cat_output = force_cat,
		})
		ins("\n")
		for _, form_and_tags in ipairs(forms_and_tags) do
			ins("\n# ")
			ins(m_links.full_link {
				lang = lang,
				term = form_and_tags.form,
				tr = form_and_tags.translit,
			})
			local pronun = get_pronun(form_and_tags.form, form_and_tags.translit)
			if pronun then
				ins(" " .. pronun)
			end
			ins(":")
			local by_lemma_sets = form_and_tags.by_lemma_sets
			if by_lemma_sets[2] then -- more than one
				for _, by_lemma_set in ipairs(by_lemma_sets) do
					add_lang_to_lemmas(by_lemma_set.lemmas)
					ins("\n## ")
					ins(m_form_of.tagged_inflections {
						lang = lang, tag_sets = by_lemma_set.tag_sets, lemmas = by_lemma_set.lemmas,
						lemma_face = "term", POS = "verb", indent = "###",
					})
				end
			else
				local by_lemma_set = by_lemma_sets[1]
				add_lang_to_lemmas(by_lemma_set.lemmas)
				ins(" ")
				ins(m_form_of.tagged_inflections {
					lang = lang, tag_sets = by_lemma_set.tag_sets, lemmas = by_lemma_set.lemmas,
					lemma_face = "term", POS = "verb",
				})
			end
		end
	else
		local form_and_tags = forms_and_tags[1]
		ins(require(headword_module).full_headword {
			lang = lang,
			pos_category = "verb forms",
			heads = {form_and_tags.form},
			translits = {form_and_tags.translit},
			inflections = get_verb_forms_as_inflections(),
			pagename = pagename,
			force_cat_output = force_cat,
		})
		local pronun = get_pronun(form_and_tags.form, form_and_tags.translit)
		if pronun then
			ins(" " .. pronun)
		end
		ins("\n")
		local by_lemma_sets = form_and_tags.by_lemma_sets
		for _, by_lemma_set in ipairs(by_lemma_sets) do
			add_lang_to_lemmas(by_lemma_set.lemmas)
			ins("\n# ")
			ins(m_form_of.tagged_inflections {
				lang = lang, tag_sets = by_lemma_set.tag_sets, lemmas = by_lemma_set.lemmas,
				lemma_face = "term", POS = "verb",
			})
		end
	end

	return table.concat(parts)
end

function export.verb_form(frame)
	local parargs = frame:getParent().args
	local params = {
		[1] = {required = true, list = true},
		["noautolinktext"] = {type = "boolean"},
		["noautolinkverb"] = {type = "boolean"},
		["pagename"] = {}, -- for testing/documentation pages
		["json"] = {type = "boolean"}, -- for bot use
		["slots"] = {}, -- restrict to only these slots
		["noslots"] = {}, -- restrict to all but these slots
		["t"] = {list = true, separate_no_index = true},
		["gloss"] = {list = true, separate_no_index = true, alias_of = "t"},
		["lit"] = {list = true, separate_no_index = true},
		["pos"] = {list = true, separate_no_index = true},
		["id"] = {list = true, separate_no_index = true},
	}
	local m_verb_module = require(ar_verb_module)
	local args = require("Module:parameters").process(parargs, params)
	local argspecs = args[1]
	local forms_and_tags = {}
	local vforms = {}
	local is_template_example = mw.title.getCurrentTitle().nsText == "Template" and
		mw.title.getCurrentTitle().subpageText == "ar-verb form"
	if not argspecs[1] and is_template_example then -- template invocation
		argspecs = {"كتب<I/a~u.pass>"}
	end

	local function process_argspec(argspec, gloss)
		args[1] = argspec
		local alternant_multiword_spec = m_verb_module.do_generate_forms(args, "ar-verb form")

		local non_lemma_form = alternant_multiword_spec.verb_form_of_form

		for _, vform in ipairs(alternant_multiword_spec.verb_forms) do
			m_table.insertIfNot(vforms, vform)
		end

		local lemmas = {}
		local lemma_slot = nil
		for _, slot in ipairs(m_verb_module.potential_lemma_slots) do
			if alternant_multiword_spec.forms[slot] then
				lemma_slot = slot
				for _, formobj in ipairs(alternant_multiword_spec.forms[slot]) do
					local lemmaval = m_links.remove_links(mw.ustring.toNFC(formobj.form))
					local lemma_translit = formobj.translit
					-- In case there is redundant manual translit, remove it so the comparisons are guaranteed to work
					-- out correctly in insertIfNot() comparisons. Otherwise it's possible we are comparing an object
					-- without manual translit to an object with redundant manual translit, in which case we will
					-- wrongly not find them equivalent.
					if lemma_translit and lemma_translit == lang:transliterate(lemmaval) then
						lemma_translit = nil
					end
					-- Ignore any footnotes. FIXME: We could convert them to qualifiers instead.
					table.insert(lemmas, {
						-- use term and tr for compatibility with tagged_inflections()
						term = lemmaval,
						tr = lemma_translit,
						gloss = gloss or args.t[i] or args.t.default,
						lit = args.lit[i] or args.lit.default,
						pos = args.pos[i] or args.pos.default,
						id = args.id[i] or args.id.default,
					})
				end 
				break
			end
		end 

		if not lemmas[1] then
			error(("Can't identify any lemmas when invoking {{ar-conj|%s}}"):format(args[1]))
		end

		local slot_restrictions = args.slots and m_table.listToSet(rsplit(args.slots, ",")) or nil
		local negated_slot_restrictions = args.noslots and m_table.listToSet(rsplit(args.noslots, ",")) or nil
		if slot_restrictions and slot_restrictions.lemma then
			slot_restrictions.lemma = nil
			slot_restrictions[lemma_slot] = true
		end
		if negated_slot_restrictions and negated_slot_restrictions.lemma then
			negated_slot_restrictions.lemma = nil
			negated_slot_restrictions[lemma_slot] = true
		end
		local slots_seen = {}

		local normally_skipped_slots = m_table.listToSet { "ap", "vp", "vn" }
		normally_skipped_slots[lemma_slot] = true
		if slot_restrictions then
			for slot, _ in pairs(slot_restrictions) do
				normally_skipped_slots[slot] = nil
			end
		end

		local matched = false
		for _, slot_accel in ipairs(alternant_multiword_spec.verb_slots) do
			local slot, accel = unpack(slot_accel)
			-- Skip "unsettable" (ancillary/internal) slots.
			if not m_verb_module.unsettable_slots_set[slot] and not normally_skipped_slots[slot] then
				local forms = alternant_multiword_spec.forms[slot]
				if forms then
					for _, formobj in ipairs(forms) do
						local form = m_links.remove_links(mw.ustring.toNFC(formobj.form))
						if non_lemma_form == lang:makeEntryName(form) then
							if (not slot_restrictions or slot_restrictions[slot]) and (
								not negated_slot_restrictions or not negated_slot_restrictions[slot]
							) then
								local translit = formobj.translit
								-- In case there is redundant manual translit, remove it; see above with lemmas for why
								-- we do this.
								if translit and translit == lang:transliterate(form) then
									translit = nil
								end
								for _, lemma in ipairs(lemmas) do
									local form_and_tags = {
										form = form,
										translit = translit,
										lemmas_tag_sets = {{
											lemma = lemma,
											tag_set = accel,
										}},
									}
									m_table.insertIfNot(forms_and_tags, form_and_tags, {
										key = function(formobj)
											return {
												form = formobj.form,
												translit = formobj.translit,
											}
										end,
										combine = function(obj, newobj)
											for _, lemma_tag_set in ipairs(newobj.lemmas_tag_sets) do
												m_table.insertIfNot(obj.lemmas_tag_sets, lemma_tag_set)
											end
										end,
									})
								end
								matched = true
							end
							if slot_restrictions or negated_slot_restrictions then
								slots_seen[slot] = true
							end
						end
					end
				end
			end
		end

		local function concat_lemmas()
			local formvals = {}
			for _, lemma in ipairs(lemmas) do
				table.insert(formvals, lemma.term)
			end
			return table.concat(formvals, "/")
		end

		if next(slots_seen) then
			local function get_slots_seen()
				local slots_seen_list = {}
				for slot, _ in pairs(slots_seen) do
					table.insert(slots_seen_list, slot)
				end
				table.sort(slots_seen_list)
				return slots_seen_list
			end

			local function check_against_slots_seen(restrictions, prefix)			
				for slot, _ in pairs(restrictions) do
					if not slots_seen[slot] then
						error(("%sslot restriction for slot '%s' had no effect (typo?) because it is not any of the slots matching form '%s' for verb '%s': possible values %s"):format(
							prefix, slot, non_lemma_form, concat_lemmas(), table.concat(get_slots_seen(), ",")))
					end
				end
			end

			if slot_restrictions then
				check_against_slots_seen(slot_restrictions, "")
			end
			if negated_slot_restrictions then
				check_against_slots_seen(negated_slot_restrictions, "negated ")
			end
		end
		if not matched then
			error(("'%s' is not any of the forms of the verb '%s'"):format(non_lemma_form, concat_lemmas()))
		end
	end

	for i, argspec in ipairs(argspecs) do
		if argspec:find("^%+") then
			local lemma, verb_form = argspec:match("^%+(.+)<(.-)>$")
			local conjs = find_conjugations(lemma, verb_form)
			for _, conj in ipairs(conjs) do
				process_argspec(conj.conj, conj.gloss)
			end
		else
			process_argspec(argspec)
		end
	end

	return generate_inflection_of(forms_and_tags, vforms, args.pagename, is_template_example)
end

return export
