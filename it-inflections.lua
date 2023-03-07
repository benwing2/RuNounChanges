local export = {}

--[=[

Authorship: Ben Wing <benwing2>

This module implements {{it-verb form of}}, which automatically generates the appropriate inflections of a non-lemma
verb form given the form and the conjugation spec for the verb (which is usually just the infinitive; see {{it-conj}}
and {{it-verb}}).
]=]

local m_table = require("Module:table")
local m_form_of = require("Module:form of")
local m_links = require("Module:links")
local m_it_verb = require("Module:User:Benwing2/it-verb")

local lang = require("Module:languages").getByCode("it")

local rmatch = mw.ustring.match
local rfind = mw.ustring.find
local rsplit = mw.text.split
local usub = mw.ustring.sub

local function track(page)
	require("Module:debug/track")("it-inflections/" .. page)
	return true
end

local function extract_link_targets(text)
    text = text:gsub("%[%[([^|%]]-)|[^|%]]-%]%]", "%1")
    text = text:gsub("%[%[", "")
    text = text:gsub("%]%]", "")

    return text
end

local function generate_inflection_of(tags, lemma)
	local has_multiple_tag_sets = #tags > 1

	tags = table.concat(tags, "|;|")
	tags = rsplit(tags, "|")

	local terminfo = {
		lang = lang,
		term = lemma,
	}

	if has_multiple_tag_sets then
		tags = require("Module:accel").combine_tag_sets_into_multipart(tags)
	end
	local categories = m_form_of.fetch_lang_categories(lang, tags, terminfo, "verb")
	local cat_text = #categories > 0 and require("Module:utilities").format_categories(categories, lang) or ""
	return m_form_of.tagged_inflections({
		tags = tags, terminfo = terminfo, terminfo_face = "term",
	}) .. cat_text
end

function export.verb_form_of(frame)
	local parent_args = frame:getParent().args
	local params = {
		[1] = {required = true, default = def or "mettere<a\\é,mìsi,mésso>"},
		["noheadword"] = {type = "boolean"}, -- FIXME: ignored for now
		["pagename"] = {}, -- for testing
	}

	local args = require("Module:parameters").process(parent_args, params)
	local alternant_multiword_spec = m_it_verb.do_generate_forms(args, "it-inflections")
	local non_lemma_form = alternant_multiword_spec.verb_form_of_form

	local lemmas = {}
	if not alternant_multiword_spec.forms.inf then
		error("Internal error: No infinitive?")
	end
	for _, formobj in ipairs(alternant_multiword_spec.forms.inf) do
		m_table.insertIfNot(lemmas, extract_link_targets(formobj.form))
	end

	-- FIXME: Consider supporting multiple lemmas.
	local lemma = lemmas[1]

	local tags = {}
	local accented_forms = {}
	local function loop_over_verb_slots(verb_slots)
		for _, slot_accel in ipairs(verb_slots) do
			local slot, accel = unpack(slot_accel)
			local forms = alternant_multiword_spec.forms[slot]
			if forms then
				for _, formobj in ipairs(forms) do
					local form_with_accents = m_links.remove_links(formobj.form)
					local form_without_accents = m_it_verb.convert_to_unaccented(formobj.form)
					if non_lemma_form == form_without_accents then
						m_table.insertIfNot(tags, accel)
						m_table.insertIfNot(accented_forms, form_without_accents)
					end
				end
			end
		end
	end
	loop_over_verb_slots(m_it_verb.all_verb_slots)

	local prelude
	if args.noheadword then
		prelude = ""
	else
		local prelude_parts = {}
		local explicit_head = args_pagename and "|head=" .. args_pagename or ""
		add(("{{head|it|verb form%s}}\n\n"):format(explicit_head))
	end

	if #tags > 0 then
		return generate_inflection_of(tags, lemma)
	end

	-- If we don't find any matches, we try again, looking for non-reflexive forms of reflexive-only verbs.
	if not alternant_multiword_spec.props.is_non_reflexive and not lemma:find(" ") then
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
					if part_form.form == non_lemma_form then
						local saw_existing = false
						for _, refl_form_to_tags in ipairs(refl_forms_to_tags) do
							if refl_form_to_tags.form == full_forms[i].form then
								table.insert(refl_form_to_tags.tags, accel)
								saw_existing = true
								break
							end
						end
						if not saw_existing then
							table.insert(refl_forms_to_tags, {
								form = full_forms[i].form,
								tags = {accel},
								variant = variant_forms and variant_forms[i].form,
							})
						end
					end
				end
			end
		end

		if #refl_forms_to_tags > 0 then
			local parts = {}
			for _, refl_form_to_tags in ipairs(refl_forms_to_tags) do
				local only_used_in
				local tags = refl_forms_to_tags.tags
				if refl_form_to_tags.variant then
					only_used_in =
						frame:preprocess(("{{only used in|it|%s|nocap=1}}, <span class='use-with-mention'>syntactic variant of {{m|it|%s}}</span>"):format(
							refl_form_to_tags.variant, refl_form_to_tags.form))
				else
					only_used_in =
						frame:preprocess(("{{only used in|it|%s|nocap=1}}"):format(refl_form_to_tags.form))
				end
				if refl_form_to_tags.form == lemma then
					table.insert(parts, only_used_in)
				else
					local inflection_of = generate_inflection_of(refl_form_to_tags.tags, lemma)
					table.insert(parts, ("%s, %s"):format(only_used_in, inflection_of))
				end
			end
			return table.concat(parts, "\n# ")
		end
	end

	error(("'%s' is not any of the forms of the verb '%s'"):format(non_lemma_form, table.concat(lemmas, "/")))
end

return export
