local export = {}

--[=[

Authorship: Ben Wing <benwing2>

This module implements {{pt-verb form of}}, which automatically generates the appropriate inflections of a non-lemma
verb form given the form and the conjugation spec for the verb (which is usually just the infinitive; see {{pt-conj}}
and {{pt-verb}}).
]=]

local m_links = require("Module:links")
local m_table = require("Module:table")
local m_form_of = require("Module:form of")
local m_pt_verb = require("Module:pt-verb")
local accel_module = "Module:accel"

local lang = require("Module:languages").getByCode("pt")

local rmatch = mw.ustring.match
local rfind = mw.ustring.find
local rsplit = mw.text.split
local usub = mw.ustring.sub

local function track(page)
	require("Module:debug/track")("pt-inflections/" .. page)
	return true
end

local function generate_inflection_of(tag_sets, lemma, pretext, args)
	for _, tag_set in ipairs(tag_sets) do
		tag_set.tags = rsplit(tag_set.tag, "|")
		tag_set.tag = nil
	end
	local has_multiple_tag_sets = #tag_sets > 1

	-- If only one tag, extract out the "combined with ..." text and move into posttext=, which goes after the lemma.
	-- FIXME: No support for clitic combinations currently for Portuguese, although maybe we should add it.
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

	-- Hack to convert raw-linked pronouns e.g. in 'combined with [[te]]' to Portuguese-linked pronouns.
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

local function extract_labels(formobj)
	local labels = {}
	local form = formobj.form
	local footnotes = formobj.footnotes
	if not not form:find(m_pt_verb.VAR_BR) or footnotes and m_table.contains(footnotes, "[Brazil]") or
		footnotes and m_table.contains(footnotes, "[Brazil only]") then
		table.insert(labels, "Brazilian Portuguese verb form")
	end
	if not not form:find(m_pt_verb.VAR_PT) or footnotes and m_table.contains(footnotes, "[Portugal]") or
		footnotes and m_table.contains(footnotes, "[Portugal only]") then
		table.insert(labels, "European Portuguese verb form")
	end
	if not not form:find(m_pt_verb.VAR_SUPERSEDED) or footnotes and m_table.contains(footnotes, "[superseded]") then
		table.insert(labels, "superseded")
	end
	return labels
end

function export.verb_form_of(frame)
	local parargs = frame:getParent().args
	local alternant_multiword_spec = m_pt_verb.do_generate_forms(parargs, false, "from verb form of")
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

	local slot_restrictions = alternant_multiword_spec.args.slots and
		m_table.listToSet(rsplit(alternant_multiword_spec.args.slots, ",")) or nil
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
						local labels = extract_labels(formobj)
						local form =
							m_pt_verb.remove_variant_codes(m_links.remove_links(mw.ustring.toNFC(formobj.form)))
						if non_lemma_form == form then
							if (not slot_restrictions or slot_restrictions[slot]) then
								m_table.insertIfNot(tags, {tag = accel, labels = labels})
							end
							if slot_restrictions then
								slots_seen[slot] = true
							end
						end
					end
				end
			end
		end
	end

	local function check_slot_restrictions_against_slots_seen()
		if slot_restrictions then
			for slot, _ in pairs(slot_restrictions) do
				if not slots_seen[slot] then
					local slots_seen_list = {}
					for slot, _ in pairs(slots_seen) do
						table.insert(slots_seen_list, slot)
					end
					table.sort(slots_seen_list)
					error(("'%s' is not any of the slots matching form '%s' for verb '%s': %s"):format(
						slot, non_lemma_form, lemma, table.concat(slots_seen_list, ",")))
				end
			end
		end
	end

	loop_over_verb_slots(alternant_multiword_spec.verb_slots_basic)
	if next(slots_seen) then
		check_slot_restrictions_against_slots_seen()
	end
	if #tags > 0 then
		return generate_inflection_of(tags, lemma, nil, alternant_multiword_spec.args)
	end

	-- If we don't find any matches, we try again, looking for non-reflexive forms of reflexive-only verbs.
	slots_seen = {}
	if alternant_multiword_spec.refl and not lemma:find(" ") then
		local refl_forms_to_tags = {}
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
					local labels = extract_labels(part_form)
					local form = m_pt_verb.remove_variant_codes(m_links.remove_links(mw.ustring.toNFC(part_form.form)))
					if non_lemma_form == form then
						if (not slot_restrictions or slot_restrictions[slot]) then
							local saw_existing = false
							for _, refl_form_to_tags in ipairs(refl_forms_to_tags) do
								if refl_form_to_tags.form == m_pt_verb.remove_variant_codes(full_forms[i].form) then
									table.insert(refl_form_to_tags.tags, {tag = accel, labels = labels})
									saw_existing = true
									break
								end
							end
							if not saw_existing then
								table.insert(refl_forms_to_tags, {
									form = m_pt_verb.remove_variant_codes(full_forms[i].form),
									tags = {{tag = accel, labels = labels}},
									variant = variant_forms and m_pt_verb.remove_variant_codes(variant_forms[i].form),
								})
							end
						end
						if slot_restrictions then
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
						frame:preprocess(("{{only used in|pt|%s|nocap=1}}, <span class='use-with-mention'>syntactic variant of {{m|pt|%s}}</span>"):format(
							refl_form_to_tags.variant, refl_form_to_tags.form))
				else
					only_used_in =
						frame:preprocess(("{{only used in|pt|%s|nocap=1}}"):format(refl_form_to_tags.form))
				end
				if refl_form_to_tags.form == lemma then
					table.insert(parts, only_used_in)
				else
					local infl = generate_inflection_of(refl_form_to_tags.tags, lemma, only_used_in .. ", ",
						alternant_multiword_spec.args)
					table.insert(parts, infl)
				end
			end
			return table.concat(parts, "\n# ")
		end
	end

	error(("'%s' is not any of the forms of the verb '%s'"):format(non_lemma_form, table.concat(lemmas, "/")))
end

return export
