local export = {}

--[=[

Authorship: Ben Wing <benwing2>

This module implements {{ar-verb form}}, which automatically generates the appropriate inflections of a non-lemma
verb form given the form and the conjugation spec for the verb (which is usually just the lemma and verb form; see
{{ar-conj}}/{{ar-verb}}).
]=]

local force_cat = false -- set to true for debugging

local m_links = require("Module:links")
local m_table = require("Module:User:Benwing2/table")
local m_form_of = require("Module:form of")
local m_string_utilities = require("Module:string utilities")
local accel_module = "Module:accel"
local headword_module = "Module:headword"
local ar_verb_module = "Module:User:Benwing2/ar-verb"
local lang = require("Module:languages").getByCode("ar")

local rsplit = m_string_utilities.split

local function track(page)
	require("Module:debug/track")("ar-inflections/" .. page)
	return true
end

local function generate_inflection_of(alternant_multiword_spec, forms_and_tags, lemmas, args)
	for _, form_and_tags in ipairs(forms_and_tags) do
		for i, tag_set in ipairs(form_and_tags.tag_sets) do
			form_and_tags.tag_sets[i] = {tags = rsplit(tag_set, "|")}
		end
	end

	local lemma_objs = {}
	for i, lemma in ipairs(lemmas) do
		local lemma_obj = {
			lang = lang,
			term = lemma.form,
			tr = lemma.translit,
		}
		if i == #lemmas then
			lemma_obj.gloss = args.t
			lemma_obj.pos = args.pos
			lemma_obj.lit = args.lit
			lemma_obj.id = args.id
		end
		table.insert(lemma_objs, lemma_obj)
	end

	local function get_verb_forms_as_inflections()
		local vforms = {}
		for _, vform in ipairs(alternant_multiword_spec.verb_forms) do
			table.insert(vforms, { label = "[[Appendix:Arabic verbs#Form " .. vform .. "|form " .. vform .. "]]" })
		end
		return vforms
	end

	local parts = {}
	local function ins(part)
		table.insert(parts, part)
	end

	if forms_and_tags[2] then
		ins(require(headword_module).full_headword {
			lang = lang,
			pos_category = "verb forms",
			inflections = get_verb_forms_as_inflections(),
			pagename = args.pagename,
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
			ins(": ")
			local tag_sets = form_and_tags.tag_sets
			if tag_sets[2] then
				tag_sets = require(accel_module).combine_tag_sets_into_multipart(tag_sets, lang, "verb")
			end
			ins(m_form_of.tagged_inflections {
				lang = lang, tag_sets = tag_sets, lemmas = lemma_objs, lemma_face = "term", POS = "verb",
			})
		end
	else
		local form_and_tags = forms_and_tags[1]
		ins(require(headword_module).full_headword {
			lang = lang,
			pos_category = "verb forms",
			heads = {form_and_tags.form},
			translits = {form_and_tags.translit},
			inflections = get_verb_forms_as_inflections(),
			pagename = args.pagename,
			force_cat_output = force_cat,
		})
		ins("\n\n# ")
		local tag_sets = form_and_tags.tag_sets
		if tag_sets[2] then
			tag_sets = require(accel_module).combine_tag_sets_into_multipart(tag_sets, lang, "verb")
		end
		ins(m_form_of.tagged_inflections {
			lang = lang, tag_sets = tag_sets, lemmas = lemma_objs, lemma_face = "term", POS = "verb",
		})
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
	local alternant_multiword_spec = m_verb_module.do_generate_forms(args, "ar-verb form of")

	local non_lemma_form = alternant_multiword_spec.verb_form_of_form

    local lemmas = {}
    for _, slot in ipairs(m_verb_module.potential_lemma_slots) do
        if alternant_multiword_spec.forms[slot] then
            for _, formobj in ipairs(alternant_multiword_spec.forms[slot]) do
                table.insert(lemmas, formobj)
            end 
            break
        end
    end 

	if not lemmas[1] then
		error(("Can't identify any lemmas when invoking {{ar-conj|%s}}"):format(args[1]))
	end

	local slot_restrictions = args.slots and m_table.listToSet(rsplit(args.slots, ",")) or nil
	local negated_slot_restrictions = args.noslots and m_table.listToSet(rsplit(args.noslots, ",")) or nil
	local forms_and_tags = {}
	local slots_seen = {}

	for _, slot_accel in ipairs(alternant_multiword_spec.verb_slots) do
		local slot, accel = unpack(slot_accel)
		-- Skip "unsettable" (ancillary/internal) slots.
		if not m_verb_module.unsettable_slots_set[slot] then
			local forms = alternant_multiword_spec.forms[slot]
			if forms then
				for _, formobj in ipairs(forms) do
					local form = m_links.remove_links(mw.ustring.toNFC(formobj.form))
					if non_lemma_form == lang:makeEntryName(form) then
						if (not slot_restrictions or slot_restrictions[slot]) and (
							not negated_slot_restrictions or not negated_slot_restrictions[slot]
						) then
							local translit = formobj.translit
							-- In case there is redundant manual translit, remove it so the comparisons are
							-- guaranteed to work out correctly below in insertIfNot(). Otherwise it's possible
							-- we are comparing an object without manual translit to an object with redundant
							-- manual translit, in which case we will wrongly not find them equivalent.
							if translit and translit == lang:transliterate(form) then
								translit = nil
							end
							local form_and_tags = {
								form = form,
								translit = translit,
								tag_sets = {accel},
							}
							m_table.insertIfNot(forms_and_tags, form_and_tags, {
								key = function(formobj)
									return formobj.translit and {form = formobj.form, translit = formobj.translit}
										or formobj.form
								end,
								combine = function(pos, obj, newobj)
									for _, tag_set in ipairs(newobj.tag_sets) do
										m_table.insertIfNot(obj.tag_sets, tag_set)
									end
								end,
							})
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
			table.insert(formvals, lemma.form)
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
	if forms_and_tags[1] then
		return generate_inflection_of(alternant_multiword_spec, forms_and_tags, lemmas, args)
	end

	error(("'%s' is not any of the forms of the verb '%s'"):format(non_lemma_form, concat_lemmas()))
end

return export
