local export = {}

--[=[

Authorship: Ben Wing <benwing2>

This module implements {{es-verb form of}}, which automatically generates the appropriate inflections of a non-lemma
verb form given the form and the conjugation spec for the verb (which is usually just the infinitive; see {{es-conj}}
and {{es-verb}}).
]=]

local m_links = require("Module:links")
local m_table = require("Module:table")
local m_form_of = require("Module:form of")
local accel_module = "Module:accel"
local es_verb_module = "Module:es-verb"

local lang = require("Module:languages").getByCode("es")

local rmatch = mw.ustring.match
local rfind = mw.ustring.find
local rsplit = mw.text.split
local usub = mw.ustring.sub

local function track(page)
	require("Module:debug/track")("es-inflections/" .. page)
	return true
end

local function generate_inflection_of(tag_sets, lemma, pretext, args)
	for _, tag_set in ipairs(tag_sets) do
		tag_set.tags = rsplit(tag_set.tag, "|")
		tag_set.tag = nil
	end
	local has_multiple_tag_sets = #tag_sets > 1

	-- If only one tag set, extract out the "combined with ..." text and move into posttext=, which goes after the lemma.
	local posttext
	if #tag_sets == 1 then
		local tags = tag_sets[1].tags
		local last_tag = tags[#tags]
		if last_tag:match("^combined with .*$") then
			-- NOTE: table.remove() side-effects the list by removing and returning the last item.
			posttext = " " .. table.remove(tags)
		end
	end

	local function hack_clitics(text)
		return text:gsub("%[%[(.-)%]%]", function(pronoun) return m_links.full_link({term = pronoun, lang = lang}, "term") end)
	end

	-- Hack to convert raw-linked pronouns e.g. in 'combined with [[te]]' to Spanish-linked pronouns.
	for _, tag_set in ipairs(tag_sets) do
		for i, tag in ipairs(tag_set.tags) do
			if tag:find("%[%[") then
				tag_set.tags[i] = hack_clitics(tag)
			end
		end
	end
	posttext = posttext and hack_clitics(posttext) or nil

	local lemma_obj = {
		lang = lang,
		term = lemma,
		gloss = args.t,
		pos = args.pos,
		lit = args.lit,
		id = args.id,
	}

	if has_multiple_tag_sets then
		tag_sets = require(accel_module).combine_tag_sets_into_multipart(tag_sets, lang, "verb")
	end
	return m_form_of.tagged_inflections {
		lang = lang, tag_sets = tag_sets, lemmas = {lemma_obj}, lemma_face = "term", pretext = pretext,
		posttext = posttext, POS = "verb",
	}
end

function export.verb_form_of(frame)
	local parargs = frame:getParent().args
	local params = {
		[1] = {required = true},
		["noautolinktext"] = {type = "boolean"},
		["noautolinkverb"] = {type = "boolean"},
		["pagename"] = {}, -- for testing/documentation pages
		["json"] = {type = "boolean"}, -- for bot use
		["slots"] = {}, -- restrict to only these slots
		["noslots"] = {}, -- restrict to all but these slots
		["t"] = {},
		["gloss"] = {alias_of = "t"},
		["lit"] = {},
		["pos"] = {},
		["id"] = {},
	}
	local m_es_verb = require(es_verb_module)
	local args = require("Module:parameters").process(parargs, params)
	local alternant_multiword_spec = m_es_verb.do_generate_forms(args, "es-verb form of")
	local non_lemma_form = alternant_multiword_spec.verb_form_of_form

	local lemmas = {}
	if not alternant_multiword_spec.forms.infinitive then
		error("Internal error: No infinitive?")
	end
	for _, formobj in ipairs(alternant_multiword_spec.forms.infinitive) do
		m_table.insertIfNot(lemmas, m_links.remove_links(formobj.form))
	end

	-- FIXME: Consider supporting multiple lemmas.
	local lemma = lemmas[1]

	local slot_restrictions = args.slots and m_table.listToSet(rsplit(args.slots, ",")) or nil
	local negated_slot_restrictions = args.noslots and m_table.listToSet(rsplit(args.noslots, ",")) or nil
	local tags = {}
	local slots_seen = {}

	local function loop_over_verb_slots(verb_slots)
		for _, slot_accel in ipairs(verb_slots) do
			local slot, accel = unpack(slot_accel)
			-- If used on the infinitive page, don't include the infinitive as a form.
			if slot ~= "infinitive" and slot ~= "infinitive_linked" then
				local forms = alternant_multiword_spec.forms[slot]
				if forms then
					for _, formobj in ipairs(forms) do
						local form = m_links.remove_links(formobj.form)
						-- Skip "combined forms" for reflexive verbs; otherwise e.g. ''ámate'' gets identified as a
						-- combined form of [[amarse]].
						if non_lemma_form == form and (not alternant_multiword_spec.refl or not slot:find("comb")) then
							if (not slot_restrictions or slot_restrictions[slot]) and (
								not negated_slot_restrictions or not negated_slot_restrictions[slot]
							) then
								m_table.insertIfNot(tags, {tag = accel})
							end
							if slot_restrictions or negated_slot_restrictions then
								slots_seen[slot] = true
							end
						end
					end
				end
			end
		end
	end

	local function check_slot_restrictions_against_slots_seen()
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
						prefix, slot, non_lemma_form, lemma, table.concat(get_slots_seen(), ",")))
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

	loop_over_verb_slots(alternant_multiword_spec.verb_slots_basic)
	loop_over_verb_slots(alternant_multiword_spec.verb_slots_combined)
	if next(slots_seen) then
		check_slot_restrictions_against_slots_seen()
	end
	if #tags > 0 then
		return generate_inflection_of(tags, lemma, nil, args)
	end

	-- If we don't find any matches, we try again, looking for non-reflexive forms of reflexive-only verbs.
	slots_seen = {}
	if alternant_multiword_spec.refl and not lemma:find(" ") then
		local refl_forms_to_tags = {}
		-- Only basic verb forms (not combined forms) have non-reflexive parts generated.
		for _, slot_accel in ipairs(alternant_multiword_spec.verb_slots_basic) do
			local slot, accel = unpack(slot_accel)
			local part_forms = alternant_multiword_spec.forms[slot .. "_non_reflexive"]
			local full_forms = alternant_multiword_spec.forms[slot]
			local variant_forms = alternant_multiword_spec.forms[slot .. "_variant"]
			-- Make sure same number of part and full forms, otherwise we can't match them up.
			if part_forms and full_forms and #part_forms == #full_forms and (
				not variant_forms or #part_forms == #variant_forms) then
				-- Find part form the same as the non-lemma form we're generating the inflection(s) of,
				-- and accumulate properties into refl_forms_to_tags.
				for i, part_form in ipairs(part_forms) do
					local form = part_form.form
					if non_lemma_form == form then
						if (not slot_restrictions or slot_restrictions[slot]) and (
							not negated_slot_restrictions or not negated_slot_restrictions[slot]
						) then
							local saw_existing = false
							for _, refl_form_to_tags in ipairs(refl_forms_to_tags) do
								if refl_form_to_tags.form == full_forms[i].form then
									table.insert(refl_form_to_tags.tags, {tag = accel})
									saw_existing = true
									break
								end
							end
							if not saw_existing then
								table.insert(refl_forms_to_tags, {
									form = full_forms[i].form,
									tags = {{tag = accel}},
									variant = variant_forms and variant_forms[i].form,
								})
							end
						end
						if slot_restrictions or negated_slot_restrictions then
							slots_seen[slot] = true
						end
					end
				end
			end
		end

		if next(slots_seen) then
			check_slot_restrictions_against_slots_seen()
		end
		if #refl_forms_to_tags > 0 then
			local parts = {}
			for _, refl_form_to_tags in ipairs(refl_forms_to_tags) do
				local only_used_in
				if refl_form_to_tags.variant then
					only_used_in =
						frame:preprocess(("{{only used in|es|%s|nocap=1}}, <span class='use-with-mention'>syntactic variant of {{m|es|%s}}</span>"):format(
							refl_form_to_tags.variant, refl_form_to_tags.form))
				else
					only_used_in =
						frame:preprocess(("{{only used in|es|%s|nocap=1}}"):format(refl_form_to_tags.form))
				end
				if refl_form_to_tags.form == lemma then
					table.insert(parts, only_used_in)
				else
					local infl = generate_inflection_of(refl_form_to_tags.tags, lemma, only_used_in .. ", ", args)
					table.insert(parts, infl)
				end
			end
			return table.concat(parts, "\n# ")
		end
	end

	error(("'%s' is not any of the forms of the verb '%s'"):format(non_lemma_form, table.concat(lemmas, "/")))
end

return export
