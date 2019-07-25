local m_utilities = require("Module:utilities")
local m_table = require("Module:table")
-- FIXME, port remaining functions to [[Module:table]] and use it instead
local ut = require("Module:utils")
local m_links = require("Module:links")
local make_link = m_links.full_link
local m_la_headword = require("Module:User:Benwing2/la-headword")
local m_la_utilities = require("Module:la-utilities")
local m_para = require("Module:parameters")

-- TODO:
-- 1. (DONE) detect_decl_and_subtypes doesn't do anything with perf_stem or supine_stem.
-- 2. (DONE) Should error on bad subtypes.
-- 3. Make sure Google Books link still works.
-- 4. (DONE) Add 4++ that has alternative perfects -īvī/-iī.
--
-- If enabled, compare this module with new version of module to make
-- sure all conjugations are the same.
local test_new_la_verb_module = false

local export = {}

local lang = require("Module:languages").getByCode("la")

local title = mw.title.getCurrentTitle()
local NAMESPACE = title.nsText
local PAGENAME = title.text

-- Conjugations are the functions that do the actual
-- conjugating by creating the forms of a basic verb.
-- They are defined further down.
local conjugations = {}

-- Check if this verb is reconstructed
-- i.e. the pagename is Reconstruction:Latin/...
local reconstructed = NAMESPACE == "Reconstruction" and PAGENAME:find("^Latin/")

-- Forward functions

local postprocess
local make_pres_1st
local make_pres_2nd
local make_pres_3rd
local make_pres_3rd_io
local make_pres_4th
local make_perf_and_supine
local make_perf
local make_deponent_perf
local make_supine
local make_table
local make_indc_rows
local make_subj_rows
local make_impr_rows
local make_nonfin_rows
local make_vn_rows
local make_footnotes
local override
local checkexist
local checkirregular
local flatten_values
local link_google_books

local rsplit = mw.text.split
local rfind = mw.ustring.find
local rmatch = mw.ustring.match
local rsubn = mw.ustring.gsub

-- version of rsubn() that discards all but the first return value
local function rsub(term, foo, bar)
	local retval = rsubn(term, foo, bar)
	return retval
end

local function cfind(str, text)
	-- Constant version of :find()
	return str:find(text, nil, true)
end

local function form_is_empty(form)
	return not form or form == "" or form == "-" or form == "—" or form == "&mdash;" or (
		type(form) == "table" and (form[1] == "" or form[1] == "-" or form[1] == "—" or form[1] == "&mdash;")
	)
end

local function initialize_slots()
	local generic_slots = {}
	local non_generic_slots = {}
	local function handle_slot(slot, generic)
		if generic then
			table.insert(generic_slots, slot)
		else
			table.insert(non_generic_slots, slot)
		end
	end
	for _, v in ipairs({"actv", "pasv"}) do
		local function handle_tense(t, mood)
			local non_pers_slot = t .. "_" .. v .. "_" .. mood
			handle_slot(non_pers_slot, true)
			for _, p in ipairs({"1s", "2s", "3s", "1p", "2p", "3p"}) do
				handle_slot(p .. "_" .. non_pers_slot, false)
			end
		end
		for _, t in ipairs({"pres", "impf", "futr", "perf", "plup", "futp"}) do
			handle_tense(t, "indc")
		end
		for _, t in ipairs({"pres", "impf", "perf", "plup"}) do
			handle_tense(t, "subj")
		end
		for _, t in ipairs({"pres", "futr"}) do
			handle_tense(t, "impr")
		end
	end
	for _, f in ipairs({"inf", "ptc"}) do
		for _, t in ipairs({"pres_actv", "perf_actv", "futr_actv", "pres_pasv", "perf_pasv", "futr_pasv"}) do
			handle_slot(t .. "_" .. f, false)
		end
	end
	for _, n in ipairs({"ger_nom", "ger_gen", "ger_dat", "ger_acc", "sup_acc", "sup_abl"}) do
		handle_slot(n, false)
	end
	return non_generic_slots, generic_slots
end

local non_generic_slots, generic_slots = initialize_slots()

local potential_lemma_slots = {
	"1s_pres_actv_indc", -- regular
	"3s_pres_actv_indc", -- impersonal
	"1s_perf_actv_indc", -- coepī
	"3s_perf_actv_indc", -- doesn't occur?
}

-- Iterate over all the "slots" associated with a verb declension, where a slot
-- is e.g. 1s_pres_actv_indc (a non-generic slot), pres_actv_indc (a generic slot),
-- or linked_1s_pres_actv_indc (a linked slot). Only include the generic and/or linked
-- slots if called for.
local function iter_slots(include_generic, include_linked)
	-- stage == 1: non-generic slots
	-- stage == 2: generic slots
	-- stage == 3: linked slots
	local stage = 1
	local slotnum = 0
	local max_slotnum = #non_generic_slots
	local function iter()
		slotnum = slotnum + 1
		if slotnum > max_slotnum then
			slotnum = 1
			stage = stage + 1
			if stage == 2 then
				if include_generic then
					max_slotnum = #generic_slots
				else
					stage = stage + 1
				end
			end
			if stage == 3 then
				if include_linked then
					max_slotnum = #potential_lemma_slots
				else
					stage = stage + 1
				end
			end
			if stage > 3 then
				return nil
			end
		end
		if stage == 1 then
			return non_generic_slots[slotnum]
		elseif stage == 2 then
			return generic_slots[slotnum]
		else
			return "linked_" .. potential_lemma_slots[slotnum]
		end
	end
	return iter
end

local function ine(val)
	if val == "" then
		return nil
	else
		return val
	end
end

local function track(page)
	require("Module:debug").track("la-verb/" .. page)
	return true
end

-- For a given form, we allow either strings (a single form) or lists of forms,
-- and treat strings equivalent to one-element lists.
local function forms_equal(form1, form2)
	if type(form1) ~= "table" then
		form1 = {form1}
	end
	if type(form2) ~= "table" then
		form2 = {form2}
	end
	return m_table.deepEquals(form1, form2)
end

local function concat_vals(val)
	if type(val) == "table" then
		return table.concat(val, ",")
	else
		return val
	end
end

local function split_prefix_and_base(lemma, main_verbs)
	for _, main in ipairs(main_verbs) do
		local prefix = rmatch(lemma, "^(.*)" .. main .. "$")
		if prefix then
			return prefix, main
		end
	end
	error("Argument " .. lemma .. " doesn't end in any of " .. table.concat(main_verbs, ","))
end

-- Given an ending (or possibly a full regex matching the entire lemma, if
-- a regex group is present), return the base minus the ending, or nil if
-- the ending doesn't match.
local function extract_base(lemma, ending)
	if ending:find("%(") then
		return rmatch(lemma, ending)
	else
		return rmatch(lemma, "^(.*)" .. ending .. "$")
	end
end

-- Given ENDINGS_AND_SUBTYPES (a list of pairs of endings with associated
-- subtypes, where each pair consists of a single ending spec and a list of
-- subtypes), check each ending in turn against LEMMA. If it matches, return
-- the pair BASE, SUBTYPES where BASE is the remainder of LEMMA minus the
-- ending, and SUBTYPES is the subtypes associated with the ending. If no
-- endings match, throw an error if DECLTYPE is non-nil, mentioning the
-- DECLTYPE (the user-specified declension); but if DECLTYPE is nil, just
-- return the pair nil, nil.
--
-- The ending spec in ENDINGS_AND_SUBTYPES is one of the following:
--
-- 1. A simple string, e.g. "ātur", specifying an ending.
-- 2. A regex that should match the entire lemma (it should be anchored at
--    the beginning with ^ and at the end with $), and contains a single
--    capturing group to match the base.
local function get_subtype_by_ending(lemma, conjtype, specified_subtypes,
		endings_and_subtypes)
	for _, ending_and_subtypes in ipairs(endings_and_subtypes) do
		local ending = ending_and_subtypes[1]
		local subtypes = ending_and_subtypes[2]
		not_this_subtype = false
		for _, subtype in ipairs(subtypes) do
			-- A subtype is directly canceled by specifying -SUBTYPE.
			if specified_subtypes["-" .. subtype] then
				not_this_subtype = true
				break
			end
		end
		if not not_this_subtype then
			local base = extract_base(lemma, ending)
			if base then
				return base, subtypes
			end
		end
	end
	if conjtype then
		error("Unrecognized ending for conjugation-" .. conjtype .. " verb: " .. lemma)
	end
	return nil, nil
end

local irreg_verbs_to_conj_type = {
	["āiō"] = "3rd-io",
	["aiiō"] = "3rd-io",
	["dīcō"] = "3rd",
	["dūcō"] = "3rd",
	["faciō"] = "3rd-io",
	["fīō"] = "3rd",
	["ferō"] = "3rd",
	["inquam"] = "irreg",
	["libet"] = "2nd",
	["lubet"] = "2nd",
	["licet"] = "2nd",
	["volō"] = "irreg",
	["mālō"] = "irreg",
	["nōlō"] = "irreg",
	["possum"] = "irreg",
	["piget"] = "2nd",
	["coepī"] = "irreg",
	["sum"] = "irreg",
	["edō"] = "3rd",
	["dō"] = "1st",
	["eō"] = "irreg",
}

local function detect_decl_and_subtypes(args)
	local specs = rsplit(args[1] or "", "%.")
	local subtypes = {}
	local conj_arg
	for i, spec in ipairs(specs) do
		if i == 1 then
			conj_arg = spec
		else
			local begins_with_hyphen = rfind(spec, "^%-")
			spec = spec:gsub("%-", "")
			if begins_with_hyphen then
				spec = "-" .. spec
			end
			subtypes[spec] = true
		end
	end

	local orig_lemma = args[2] or mw.title.getCurrentTitle().subpageText
	orig_lemma = rsub(orig_lemma, "o$", "ō")
	local lemma = m_links.remove_links(orig_lemma)
	local base, conjtype, conj_subtype, detected_subtypes
	local base_conj_arg, auto_perf_supine = rmatch(conj_arg, "^([124])(%+%+?)$")
	if base_conj_arg then
		if auto_perf_supine == "++" and base_conj_arg ~= "4" then
			error("Conjugation types 1++ and 2++ not allowed")
		end
		conj_arg = base_conj_arg
	end
	local auto_perf, auto_supine

	if conj_arg == "1" then
		conjtype = "1st"
		base, detected_subtypes = get_subtype_by_ending(lemma, "1", subtypes, {
			{"ō", {}},
			{"or", {"depon"}},
			{"at", {"impers"}},
			{"ātur", {"depon", "impers"}},
		})
		if auto_perf_supine then
			auto_perf = base .. "āv"
			auto_supine = base .. "āt"
		end
	elseif conj_arg == "2" then
		conjtype = "2nd"
		base, detected_subtypes = get_subtype_by_ending(lemma, "2", subtypes, {
			{"eō", {}},
			{"eor", {"depon"}},
			{"et", {"impers"}},
			{"ētur", {"depon", "impers"}},
		})
		if auto_perf_supine then
			auto_perf = base .. "u"
			auto_supine = base .. "it"
		end
	elseif conj_arg == "3" then
		base, detected_subtypes = get_subtype_by_ending(lemma, nil, subtypes, {
			{"iō", {"I"}},
			{"ior", {"depon", "I"}},
		})
		if base then
			conjtype = "3rd-io"
		else
			base, detected_subtypes = get_subtype_by_ending(lemma, "3", subtypes, {
				{"ō", {}},
				{"or", {"depon"}},
				{"it", {"impers"}},
				{"itur", {"depon", "impers"}},
			})
			if subtypes.I then
				conjtype = "3rd-io"
			else
				conjtype = "3rd"
			end
		end
	elseif conj_arg == "4" then
		conjtype = "4th"
		base, detected_subtypes = get_subtype_by_ending(lemma, "4", subtypes, {
			{"iō", {}},
			{"ior", {"depon"}},
			{"it", {"impers"}},
			{"ītur", {"depon", "impers"}},
		})
		if auto_perf_supine == "++" then
			auto_perf = base .. "īv/" .. base .. "i"
			auto_supine = base .. "īt"
		elseif auto_perf_supine == "+" then
			auto_perf = base .. "īv"
			auto_supine = base .. "īt"
		end
	elseif conj_arg == "irreg" then
		conjtype = "irreg"
		local prefix
		prefix, base = split_prefix_and_base(lemma, {
			"āiō",
			"aiiō",
			"dīcō",
			"dūcō",
			"faciō",
			"fīō",
			"ferō",
			"inquam",
			"libet",
			"lubet",
			"licet",
			"volō",
			"mālō",
			"nōlō",
			"possum",
			"piget",
			"coepī",
			-- list sum after possum
			"sum",
			-- FIXME: Will praedō cause problems?
			"edō",
			-- list dō after edō
			"dō",
			"eō",
		})
		conj_subtype = irreg_verbs_to_conj_type[base]
		args[1] = m_la_utilities.strip_macrons(base)
		args[2] = prefix
		-- args[3] and args[4] are used by ferō and sum and stay where they are
		detected_subtypes = {}
	else
		error("Unrecognized conjugation '" .. conj_arg .. "'")
	end

	for _, detected_subtype in ipairs(detected_subtypes) do
		if detected_subtype == "impers" and subtypes["3only"] then
			-- 3only overrides impers
		else
			subtypes[detected_subtype] = true
		end
	end

	if conjtype ~= "irreg" then
		args[1] = base
		local perf_stem, supine_stem
		if subtypes.depon or subtypes.semidepon then
			supine_stem = args[3] or auto_supine
			if supine_stem == "-" then
				supine_stem = nil
			end
			if not supine_stem then
				subtypes.noperf = true
				subtypes.nosup = true
			end
			args[2] = supine_stem
			args[3] = nil
		else
			perf_stem = args[3] or auto_perf
			if perf_stem == "-" then
				perf_stem = nil
			end
			if not perf_stem then
				subtypes.noperf = true
			end
			supine_stem = args[4] or auto_supine
			if supine_stem == "-" then
				supine_stem = nil
			end
			if not supine_stem then
				subtypes.nosup = true
			end
			args[2] = perf_stem
			args[3] = supine_stem
		end
		args[4] = nil
	end

	for subtype, _ in pairs(subtypes) do
		if not m_la_headword.allowed_subtypes[subtype] and
			not (conjtype == "3rd" and subtype == "-I") and
			not (conjtype == "3rd-io" and subtype == "I") then
			error("Unrecognized verb subtype " .. subtype)
		end
	end

	return conjtype, conj_subtype, subtypes, orig_lemma, lemma
end

-- The main new entry point.
function export.show(frame)
	local parent_args = frame:getParent().args
	local data, typeinfo = export.make_data(parent_args)
	local domain = frame:getParent().args['search']
	-- Test code to compare existing module to new one.
	if test_new_la_verb_module then
		local m_new_la_verb = require("Module:User:Benwing2/la-verb")
		local miscdata = {
			title = data.title,
			categories = data.categories,
		}
		local new_parent_args = frame:getParent().args
		local newdata, newtypeinfo = m_new_la_verb.make_data(new_parent_args)
		local newmiscdata = {
			title = newdata.title,
			categories = newdata.categories,
		}
		local all_verb_props = {"forms", "form_footnote_indices", "footnotes", "miscdata"}
		local difconj = false
		for _, prop in ipairs(all_verb_props) do
			local table = prop == "miscdata" and miscdata or data[prop]
			local newtable = prop == "miscdata" and newmiscdata or newdata[prop]
			for key, val in pairs(table) do
				local newval = newtable[key]
				if not forms_equal(val, newval) then
					-- Uncomment this to display the particular key and
					-- differing forms.
					--error(key .. " " .. (val and concat_vals(val) or "nil") .. " || " .. (newval and concat_vals(newval) or "nil"))
					difconj = true
					break
				end
			end
			if difconj then
				break
			end
			-- Do the comparison the other way as well in case of extra keys
			-- in the new table.
			for key, newval in pairs(newtable) do
				local val = table[key]
				if not forms_equal(val, newval) then
					-- Uncomment this to display the particular key and
					-- differing forms.
					--error(key .. " " .. (val and concat_vals(val) or "nil") .. " || " .. (newval and concat_vals(newval) or "nil"))
					difconj = true
					break
				end
			end
			if difconj then
				break
			end
		end
		track(difconj and "different-conj" or "same-conj")
	end

	if domain == nil then
		return make_table(data) .. m_utilities.format_categories(data.categories, lang)
	else
		local verb = data['forms']['1s_pres_actv_indc'] ~= nil and ('[['..mw.ustring.gsub(mw.ustring.toNFD(data['forms']['1s_pres_actv_indc']),'[^%w]+',"")..'|'..data['forms']['1s_pres_actv_indc'].. ']]') or 'verb'
		return link_google_books(verb, flatten_values(data['forms']), domain) end
end

local function concat_forms(data, typeinfo, include_props)
	local ins_text = {}
	for key, val in pairs(data.forms) do
		local ins_form = {}
		if type(val) ~= "table" then
			val = {val}
		end
		for _, v in ipairs(val) do
			if not form_is_empty(v) then
				table.insert(ins_form,
					rsub(rsub(rsub(v, "|", "<!>"), "=", "<->"), ",", "<.>")
				)
			end
		end
		if #ins_form > 0 then
			table.insert(ins_text, key .. "=" .. table.concat(ins_form, ","))
		end
	end
	if include_props then
		table.insert(ins_text, "conj_type=" .. typeinfo.conj_type)
		if typeinfo.conj_subtype then
			table.insert(ins_text, "conj_subtype=" .. typeinfo.conj_subtype)
		end
		local subtypes = {}
		for subtype, _ in pairs(typeinfo.subtypes) do
			table.insert(subtypes, subtype)
		end
		table.insert(ins_text, "subtypes=" .. table.concat(subtypes, "."))
	end
	return table.concat(ins_text, "|")
end

-- The entry point for 'la-generate-verb-forms' and 'la-generate-verb-props'
-- to generate all verb forms/props.
function export.generate_forms(frame)
	local include_props = frame.args["include_props"]
	local parent_args = frame:getParent().args
	local data, typeinfo = export.make_data(parent_args)
	return concat_forms(data, typeinfo, include_props)
end

-- Add prefixes and suffixes to non-generic slots. The generic slots (e.g.
-- perf_pasv_indc, whose text indicates to use the past passive participle +
-- the present active indicative of [[sum]]), handle prefixes and suffixes
-- themselves in make_perfect_passive().
local function add_prefix_suffix(data, typeinfo)
	if not data.prefix and not data.suffix then
		return
	end
	local prefix_no_links = m_links.remove_links(data.prefix or "")
	local suffix_no_links = m_links.remove_links(data.suffix or "")
	for slot in iter_slots(false, true) do
		local forms = data.forms[slot]
		if not form_is_empty(forms) then
			local affixed_forms = {}
			if type(forms) ~= "table" then
				forms = {forms}
			end
			for _, form in ipairs(forms) do
				if form_is_empty(form) then
					table.insert(affixed_forms, form)
				elseif slot:find("^linked") then
					-- If we're dealing with a linked slot, include the original links
					-- in the prefix/suffix and also add a link around the form itself
					-- if links aren't already present. (Note, above we early-exited
					-- if there was no prefix and no suffix.)
					if not form:find("[%[%]]") then
						form = "[[" .. form .. "]]"
					end
					table.insert(affixed_forms, (data.prefix or "") .. form .. (data.suffix or ""))
				else
					-- If not dealing with a linked slot, use the non-linking versions
					-- of the prefix and suffix.
					table.insert(affixed_forms, prefix_no_links .. form .. suffix_no_links)
				end
			end
			data.forms[slot] = affixed_forms
		end
	end
end

local function set_linked_forms(data, typeinfo)
	-- Generate linked variants of slots that may be the lemma.
	-- If the form is the same as the lemma (with links removed),
	-- substitute the original lemma (with links included).
	for _, slot in ipairs(potential_lemma_slots) do
		local forms = data.forms[slot]
		local linked_forms = {}
		if forms then
			if type(forms) ~= "table" then
				forms = {forms}
			end
			for _, form in ipairs(forms) do
				if form == typeinfo.lemma then
					table.insert(linked_forms, typeinfo.orig_lemma)
				else
					table.insert(linked_forms, form)
				end
			end
		end
		data.forms["linked_" .. slot] = linked_forms
	end
end

function export.make_data(parent_args, from_headword)
	local params = {
		[1] = {required = true, default = "1+"},
		[2] = {required = true, default = "amō"},
		[3] = {},
		[4] = {},
		prefix = {},
		suffix = {},
		-- examined directly in export.show()
		search = {},
	}
	for slot in iter_slots(true, false) do
		params[slot] = {}
	end

	if from_headword then
		params.lemma = {list = true}
		params.id = {}
	end

	local args = m_para.process(parent_args, params)
	local conj_type, conj_subtype, subtypes, orig_lemma, lemma =
		detect_decl_and_subtypes(args)

	if not conjugations[conj_type] then
		error("Unknown conjugation type '" .. conj_type .. "'")
	end

	local data = {
		forms = {},
		title = {},
		categories = {},
		form_footnote_indices = {},
		footnotes = {},
		id = args.id,
		overriding_lemma = args.lemma,
	}  --note: the addition of red superscripted footnotes ('<sup style="color: red">' ... </sup>) is only implemented for the three form printing loops in which it is used
	local typeinfo = {
		lemma = lemma,
		orig_lemma = orig_lemma,
		conj_type = conj_type,
		conj_subtype = conj_subtype,
		subtypes = subtypes,
	}

	if args.prefix then
		local no_space_prefix = rmatch(args.prefix, "(.*)_$")
		if no_space_prefix then
			data.prefix = no_space_prefix
		elseif rfind(args.prefix, "%-$") then
			data.prefix = args.prefix
		else
			data.prefix = args.prefix .. " "
		end
	end

	if args.suffix then
		local no_space_suffix = rmatch(args.suffix, "^_(.*)$")
		if no_space_suffix then
			data.suffix = no_space_suffix
		elseif rfind(args.suffix, "^%-") then
			data.suffix = args.suffix
		else
			data.suffix = " " .. args.suffix
		end
	end

	-- Generate the verb forms
	conjugations[conj_type](args, data, typeinfo)

	-- Override with user-set forms
	override(data, args)

	-- Post-process the forms
	postprocess(data, typeinfo)

	-- Set linked_* forms
	set_linked_forms(data, typeinfo)

	-- Prepend any prefixes, append any suffixes
	add_prefix_suffix(data)

	-- Check if the links to the verb forms exist
	checkexist(data)

	-- Check if the verb is irregular
	if not conj_type == 'irreg' then checkirregular(args, data) end
	return data, typeinfo
end

local function form_contains(forms, form)
	if type(forms) == "string" then
		return forms == form
	else
		return ut.contains(forms, form)
	end
end

-- Add a value to a given form key, e.g. "1s_pres_actv_indc". If the
-- value is already present in the key, it won't be added again.
--
-- The value is formed by concatenating STEM and SUF. SUF can be a list,
-- in which case STEM will be concatenated in turn to each value in the
-- list and all the resulting forms added to the key.
--
-- POS is the position to insert the form(s) at; default is at the end.
-- To insert at the beginning specify 1 for POS.
local function add_form(data, key, stem, suf, pos)
	if not suf then
		return
	end
	if type(suf) ~= "table" then
		suf = {suf}
	end
	for _, s in ipairs(suf) do
		if not data.forms[key] then
			data.forms[key] = {}
		elseif type(data.forms[key]) == "string" then
			data.forms[key] = {data.forms[key]}
		end
		ut.insert_if_not(data.forms[key], stem .. s, pos)
	end
end

-- Add a value to all persons/numbers of a given tense/voice/mood, e.g.
-- "pres_actv_indc" (specified by KEYTYPE). If a value is already present
-- in a key, it won't be added again.
--
-- The value for a given person/number combination is formed by concatenating
-- STEM and the appropriate suffix for that person/number, e.g. SUF1S. The
-- suffix can be a list, in which case STEM will be concatenated in turn to
-- each value in the list and all the resulting forms added to the key. To
-- not add a value for a specific person/number, specify nil or {} for the
-- suffix for the person/number.
local function add_forms(data, keytype, stem, suf1s, suf2s, suf3s, suf1p, suf2p, suf3p)
	add_form(data, "1s_" .. keytype, stem, suf1s)
	add_form(data, "2s_" .. keytype, stem, suf2s)
	add_form(data, "3s_" .. keytype, stem, suf3s)
	add_form(data, "1p_" .. keytype, stem, suf1p)
	add_form(data, "2p_" .. keytype, stem, suf2p)
	add_form(data, "3p_" .. keytype, stem, suf3p)
end

-- Add a value to the 2nd person (singular and plural) of a given
-- tense/voice/mood. This works like add_forms().
local function add_2_forms(data, keytype, stem, suf2s, suf2p)
	add_form(data, "2s_" .. keytype, stem, suf2s)
	add_form(data, "2p_" .. keytype, stem, suf2p)
end

-- Add a value to the 2nd and 3rd persons (singular and plural) of a given
-- tense/voice/mood. This works like add_forms().
local function add_23_forms(data, keytype, stem, suf2s, suf3s, suf2p, suf3p)
	add_form(data, "2s_" .. keytype, stem, suf2s)
	add_form(data, "3s_" .. keytype, stem, suf3s)
	add_form(data, "2p_" .. keytype, stem, suf2p)
	add_form(data, "3p_" .. keytype, stem, suf3p)
end

-- Clear out all forms from a given key (e.g. "1s_pres_actv_indc").
local function clear_form(data, key)
	data.forms[key] = nil
end

-- Clear out all forms from all persons/numbers a given tense/voice/mood
-- (e.g. "pres_actv_indc").
local function clear_forms(data, keytype)
	clear_form(data, "1s_" .. keytype)
	clear_form(data, "2s_" .. keytype)
	clear_form(data, "3s_" .. keytype)
	clear_form(data, "1p_" .. keytype)
	clear_form(data, "2p_" .. keytype)
	clear_form(data, "3p_" .. keytype)
end

local function make_perfect_passive(data)
	local ppp = data.forms["perf_pasv_ptc"]
	if type(ppp) ~= "table" then
		ppp = {ppp}
	end
	local ppplinks = {}
	for _, pppform in ipairs(ppp) do
		table.insert(ppplinks, make_link({lang = lang, term = pppform}, "term"))
	end
	local ppplink = table.concat(ppplinks, " or ")
	local sumlink = make_link({lang = lang, term = "sum"}, "term")

	text_for_slot = {
		perf_pasv_indc = "present active indicative",
		futp_pasv_indc = "future active indicative",
		plup_pasv_indc = "imperfect active indicative",
		perf_pasv_subj = "present active subjunctive",
		plup_pasv_subj = "imperfect active subjunctive"
	}
	local prefix_joiner = data.prefix and data.prefix:find(" $") and "+ " or ""
	local suffix_joiner = data.suffix and data.suffix:find("^ ") and " +" or ""
	for slot, text in pairs(text_for_slot) do
		data.forms[slot] =
			(data.prefix or "") .. prefix_joiner .. ppplink .. " + " ..
			text .. " of " .. sumlink .. suffix_joiner .. (data.suffix or "")
	end
end

postprocess = function(data, typeinfo)
	-- Add information for the passive perfective forms
	if data.forms["perf_pasv_ptc"] and not form_is_empty(data.forms["perf_pasv_ptc"]) then
		if typeinfo.subtypes.passimpers then
			-- These may already be set by make_supine().
			clear_form(data, "perf_pasv_inf")
			clear_form(data, "perf_pasv_ptc")
			for _, supine_stem in ipairs(typeinfo.supine_stem) do
				local nns_ppp = "[[" .. (typeinfo.prefix or "") .. supine_stem .. "um]]"
				add_form(data, "3s_perf_pasv_indc", nns_ppp, " [[est]]")
				add_form(data, "3s_futp_pasv_indc", nns_ppp, " [[erit]]")
				add_form(data, "3s_plup_pasv_indc", nns_ppp, " [[erat]]")
				add_form(data, "3s_perf_pasv_subj", nns_ppp, " [[sit]]")
				add_form(data, "3s_plup_pasv_subj", nns_ppp, " [[esset]], [[foret]]")
				add_form(data, "perf_pasv_inf", nns_ppp, " [[esse]]")
				add_form(data, "perf_pasv_ptc", nns_ppp, "")
			end
		elseif typeinfo.subtypes.pass3only then
			for _, supine_stem in ipairs(typeinfo.supine_stem) do
				local nns_ppp_s = "[[" .. supine_stem .. "us]]"
				local nns_ppp_p = "[[" .. supine_stem .. "ī]]"
				add_form(data, "3s_perf_pasv_indc", nns_ppp_s, " [[est]]")
				add_form(data, "3p_perf_pasv_indc", nns_ppp_p, " [[sunt]]")
				add_form(data, "3s_futp_pasv_indc", nns_ppp_s, " [[erit]]")
				add_form(data, "3p_futp_pasv_indc", nns_ppp_p, " [[erunt]]")
				add_form(data, "3s_plup_pasv_indc", nns_ppp_s, " [[erat]]")
				add_form(data, "3p_plup_pasv_indc", nns_ppp_p, " [[erant]]")
				add_form(data, "3s_perf_pasv_subj", nns_ppp_s, " [[sit]]")
				add_form(data, "3p_perf_pasv_subj", nns_ppp_p, " [[sint]]")
				add_form(data, "3s_plup_pasv_subj", nns_ppp_s, " [[esset]], [[foret]]")
				add_form(data, "3p_plup_pasv_subj", nns_ppp_p, " [[essent]], [[forent]]")
			end
		else
			make_perfect_passive(data)
		end
	end

	if typeinfo.subtypes.perfaspres then
		-- Perfect forms as present tense
		ut.insert_if_not(data.title, "active only")
		ut.insert_if_not(data.title, "[[perfect]] forms as present")
		ut.insert_if_not(data.title, "pluperfect as imperfect")
		ut.insert_if_not(data.title, "future perfect as future")
		ut.insert_if_not(data.categories, "Latin defective verbs")
		ut.insert_if_not(data.categories, "Latin active-only verbs")
        ut.insert_if_not(data.categories, "Latin verbs with perfect forms having imperfective meanings")

		-- Change perfect passive participle to perfect active participle
		data.forms["perf_actv_ptc"] = data.forms["perf_pasv_ptc"]

		-- Change perfect active infinitive to present active infinitive
		data.forms["pres_actv_inf"] = data.forms["perf_actv_inf"]

		-- Remove passive forms
		-- Remove present active, imperfect active and future active forms
		for key, _ in pairs(data.forms) do
			if key ~= "futr_actv_inf" and key ~= "futr_actv_ptc" and (
				cfind(key, "pasv") or cfind(key, "pres") and key ~= "pres_actv_inf" or
				cfind(key, "impf") or cfind(key, "futr")
			) then
				data.forms[key] = nil
			end
		end

		-- Change perfect forms to non-perfect forms
		for key, form in pairs(data.forms) do
			if cfind(key, "perf") and key ~= "perf_actv_ptc" then
				data.forms[key:gsub("perf", "pres")] = form
				data.forms[key] = nil
			elseif cfind(key, "plup") then
				data.forms[key:gsub("plup", "impf")] = form
				data.forms[key] = nil
			elseif cfind(key, "futp") then
				data.forms[key:gsub("futp", "futr")] = form
				data.forms[key] = nil
			elseif cfind(key, "ger") then
				data.forms[key] = nil
			end
		end

		data.forms["pres_actv_ptc"] = nil
	elseif typeinfo.subtypes.memini then
		-- Perfect forms as present tense
		ut.insert_if_not(data.title, "active only")
		ut.insert_if_not(data.title, "[[perfect]] forms as present")
		ut.insert_if_not(data.title, "pluperfect as imperfect")
		ut.insert_if_not(data.title, "future perfect as future")
		ut.insert_if_not(data.categories, "Latin defective verbs")
		ut.insert_if_not(data.categories, "Latin verbs with perfect forms having imperfective meanings")

		-- Remove passive forms
		-- Remove present active, imperfect active and future active forms
		-- Except for future active imperatives
		for key, _ in pairs(data.forms) do
			if cfind(key, "pasv") or cfind(key, "pres") or cfind(key, "impf") or cfind(key, "futr") or cfind(key, "ptc") or cfind(key, "ger") then
				data.forms[key] = nil
			end
		end

		-- Change perfect forms to non-perfect forms
		for key, form in pairs(data.forms) do
			if cfind(key, "perf") and key ~= "perf_actv_ptc" then
				data.forms[key:gsub("perf", "pres")] = form
				data.forms[key] = nil
			elseif cfind(key, "plup") then
				data.forms[key:gsub("plup", "impf")] = form
				data.forms[key] = nil
			elseif cfind(key, "futp") then
				data.forms[key:gsub("futp", "futr")] = form
				data.forms[key] = nil
			end
		end

		-- Add imperative forms
		data.forms["2s_futr_actv_impr"] = "mementō"
		data.forms["2p_futr_actv_impr"] = "mementōte"
	end

	-- Types of irregularity related primarily to the active.
	-- These could in theory be combined with those related to the passive and imperative,
	-- i.e. there's no reason there couldn't be an impersonal deponent verb with no imperatives.
	if typeinfo.subtypes.impers then
		-- Impersonal verbs have only third-person singular forms.
		ut.insert_if_not(data.title, "[[impersonal]]")
		ut.insert_if_not(data.categories, "Latin impersonal verbs")

		-- Remove all non-3sg forms
		for key, _ in pairs(data.forms) do
			if key:find("^[12][sp]") or key:find("^3p") then
				data.forms[key] = nil
			end
		end
	elseif typeinfo.subtypes["3only"] then
		ut.insert_if_not(data.title, "[[third person]] only")
		ut.insert_if_not(data.categories, "Latin third-person-only verbs")

		-- Remove all non-3sg forms
		for key, _ in pairs(data.forms) do
			if key:find("^[12][sp]") then
				data.forms[key] = nil
			end
		end
	end

	if typeinfo.subtypes.noactvperf then
		-- Some verbs have no active perfect forms (e.g. interstinguō, -ěre)
		ut.insert_if_not(data.title, "no active perfect forms")
		ut.insert_if_not(data.categories, "Latin defective verbs")

		-- Remove all active perfect forms
		for key, _ in pairs(data.forms) do
			if cfind(key, "actv") and (cfind(key, "perf") or cfind(key, "plup") or cfind(key, "futp")) then
				data.forms[key] = nil
			end
		end
	elseif typeinfo.subtypes.nopasvperf then
		-- Some verbs have no passive perfect forms (e.g. ārēscō, -ěre)
		ut.insert_if_not(data.title, "no passive perfect forms")
		ut.insert_if_not(data.categories, "Latin defective verbs")

		-- Remove all passive perfect forms
		for key, _ in pairs(data.forms) do
			if cfind(key, "pasv") and (cfind(key, "perf") or cfind(key, "plup") or cfind(key, "futp")) then
				data.forms[key] = nil
			end
		end
	end

	-- Handle certain irregularities in the passive
	if typeinfo.subtypes.optsemidepon then
		-- Optional semi-deponent verbs use perfective passive forms with active
		-- meaning, but also have perfect active forms with the same meaning,
		-- and have no imperfective passive. We already generated the perfective
		-- forms but need to clear out the imperfective passive.
		ut.insert_if_not(data.title, "optionally [[semi-deponent]]")
		ut.insert_if_not(data.categories, "Latin semi-deponent verbs")
		ut.insert_if_not(data.categories, "Latin optionally semi-deponent verbs")

		-- Remove imperfective passive forms
		for key, _ in pairs(data.forms) do
			if cfind(key, "pres_pasv") or cfind(key, "impf_pasv") or cfind(key, "futr_pasv") then
				data.forms[key] = nil
			end
		end
	elseif typeinfo.subtypes.semidepon then
		-- Semi-deponent verbs use perfective passive forms with active meaning,
		-- and have no imperfective passive
		ut.insert_if_not(data.title, "[[semi-deponent]]")
		ut.insert_if_not(data.categories, "Latin semi-deponent verbs")

		-- Remove perfective active and imperfective passive forms
		for key, _ in pairs(data.forms) do
			if cfind(key, "perf_actv") or cfind(key, "plup_actv") or cfind(key, "futp_actv") or cfind(key, "pres_pasv") or cfind(key, "impf_pasv") or cfind(key, "futr_pasv") then
				data.forms[key] = nil
			end
		end

		-- Change perfective passive to active
		for key, form in pairs(data.forms) do
			if cfind(key, "perf_pasv") or cfind(key, "plup_pasv") or cfind(key, "futp_pasv") then
				data.forms[key:gsub("pasv", "actv")] = form
				data.forms[key] = nil
			end
		end
	elseif typeinfo.subtypes.depon then
		-- Deponent verbs use passive forms with active meaning
		ut.insert_if_not(data.title, "[[deponent]]")
		ut.insert_if_not(data.categories, "Latin deponent verbs")

		-- Remove active forms and future passive infinitive
		for key, _ in pairs(data.forms) do
			if cfind(key, "actv") and key ~= "pres_actv_ptc" and key ~= "futr_actv_ptc" and key ~= "futr_actv_inf" or key == "futr_pasv_inf" then
				data.forms[key] = nil
			end
		end

		-- Change passive to active
		for key, form in pairs(data.forms) do
			if cfind(key, "pasv") and key ~= "pres_pasv_ptc" and key ~= "futr_pasv_ptc" and key ~= "futr_pasv_inf" then
				data.forms[key:gsub("pasv", "actv")] = form
				data.forms[key] = nil
			end
		end

		-- Generate correct form of infinitive for nominative gerund
		data.forms["ger_nom"] = data.forms["pres_actv_inf"]
	end

	if typeinfo.subtypes.noperf then
		-- Some verbs have no perfect forms (e.g. inalbēscō, -ěre)
		ut.insert_if_not(data.title, "no [[perfect tense|perfect]]")
		ut.insert_if_not(data.categories, "Latin verbs with missing perfect")
		ut.insert_if_not(data.categories, "Latin defective verbs")

		-- Remove all perfect forms
		for key, _ in pairs(data.forms) do
			if cfind(key, "perf") or cfind(key, "plup") or cfind(key, "futp") then
				data.forms[key] = nil
			end
		end
	end

	if typeinfo.subtypes.nopass then
		-- Remove all passive forms
		ut.insert_if_not(data.title, "active only")
		ut.insert_if_not(data.categories, "Latin active-only verbs")

		-- Remove all non-3sg and passive forms
		for key, _ in pairs(data.forms) do
			if cfind(key, "pasv") then
				data.forms[key] = nil
			end
		end
	elseif typeinfo.subtypes.pass3only then
		-- Some verbs have only third-person forms in the passive
		ut.insert_if_not(data.title, "only third-person forms in passive")
		ut.insert_if_not(data.categories, "Latin verbs with third-person passive")

		-- Remove all non-3rd-person passive forms and all passive imperatives
		for key, _ in pairs(data.forms) do
			if cfind(key, "pasv") and (key:find("^[12][sp]") or cfind(key, "impr")) then
				data.forms[key] = nil
			end
		end
	elseif typeinfo.subtypes.passimpers then
		-- Some verbs are impersonal in the passive
		ut.insert_if_not(data.title, "[[impersonal]] in passive")
		ut.insert_if_not(data.categories, "Latin verbs with impersonal passive")

		-- Remove all non-3sg passive forms
		for key, _ in pairs(data.forms) do
			if cfind(key, "pasv") and (key:find("^[12][sp]") or key:find("^3p") or cfind(key, "impr")) or cfind(key, "futr_pasv_inf") then
				data.forms[key] = nil
			end
		end
	end

	if typeinfo.subtypes.nosup then
		-- Some verbs have no supine forms or forms derived from the supine
		ut.insert_if_not(data.title, "no [[supine]] stem")
		ut.insert_if_not(data.categories, "Latin verbs with missing supine stem")
		ut.insert_if_not(data.categories, "Latin defective verbs")

		for key, _ in pairs(data.forms) do
			if cfind(key, "sup") or (
				key == "perf_actv_ptc" or key == "perf_pasv_ptc" or key == "perf_pasv_inf" or
				key == "futr_actv_ptc" or key == "futr_actv_inf" or key == "futr_pasv_inf" or
				(typeinfo.subtypes.depon or typeinfo.subtypes.semidepon or
				 typeinfo.subtypes.optsemidepon) and key == "perf_actv_inf"
			) then
				data.forms[key] = nil
			end
		end
	elseif typeinfo.subtypes.supfutractvonly then
		-- Some verbs have no supine forms or forms derived from the supine,
		-- except for the future active infinitive/participle
		ut.insert_if_not(data.title, "no [[supine]] stem except in the [[future]] [[active]] [[participle]]")
		ut.insert_if_not(data.categories, "Latin verbs with missing supine stem except in the future active participle")
		ut.insert_if_not(data.categories, "Latin defective verbs")

		for key, _ in pairs(data.forms) do
			if cfind(key, "sup") or (
				key == "perf_actv_ptc" or key == "perf_pasv_ptc" or key == "perf_pasv_inf" or
				key == "futr_pasv_inf"
			) then
				data.forms[key] = nil
			end
		end
	end

	-- Handle certain irregularities in the imperative
	if typeinfo.subtypes.noimp then
		-- Some verbs have no imperatives
		ut.insert_if_not(data.title, "no [[imperative]]s")
		ut.insert_if_not(data.categories, "Latin verbs with missing imperative")
		ut.insert_if_not(data.categories, "Latin defective verbs")

		-- Remove all imperative forms
		for key, _ in pairs(data.forms) do
			if cfind(key, "impr") then
				data.forms[key] = nil
			end
		end
	end

	-- Handle certain irregularities in the future
	if typeinfo.subtypes.nofut then
		-- Some verbs (e.g. soleō) have no future
		ut.insert_if_not(data.title, "no [[future]]")
		ut.insert_if_not(data.categories, "Latin verbs with missing future")
		ut.insert_if_not(data.categories, "Latin defective verbs")

		-- Remove all future forms
		for key, _ in pairs(data.forms) do
			if cfind(key, "fut") then -- handles futr = future and futp = future perfect
				data.forms[key] = nil
			end
		end
	end

	-- Add the ancient future_passive_participle of certain verbs
	if typeinfo.pres_stem == "lāb" then
		data.forms["futr_pasv_ptc"] = "lābundus"
	elseif typeinfo.pres_stem == "collāb" then
		data.forms["futr_pasv_ptc"] = "collābundus"
	elseif typeinfo.pres_stem == "illāb" then
		data.forms["futr_pasv_ptc"] = "illābundus"
	elseif typeinfo.pres_stem == "relāb" then
		data.forms["futr_pasv_ptc"] = "relābundus"
	end

	-- Add the poetic present passive infinitive forms of certain verbs
	if typeinfo.subtypes.p3inf then
			local is_depon = typeinfo.subtypes.depon
			local form = "pres_" .. (is_depon and "actv" or "pasv") .. "_inf"
			local noteindex = #(data.footnotes) + 1
			local formval = data.forms[form]
			if type(formval) ~= "table" then
				formval = {formval}
			end
			local newvals = mw.clone(formval)
			for _, fv in ipairs(formval) do
				table.insert(newvals, mw.ustring.sub(fv, 1, -2) .. "ier")
			end
			data.forms[form] = newvals
			data.form_footnote_indices[form] = tostring(noteindex)
			if is_depon then
				data.form_footnote_indices["ger_nom"] = tostring(noteindex)
				data.forms['ger_nom'] = data.forms[form]
			end
			data.footnotes[noteindex] = 'The present passive infinitive in -ier is a rare poetic form which is attested for this verb.'
	end

	--Add the syncopated perfect forms, omitting the separately handled fourth conjugation cases

	if typeinfo.subtypes.poetsyncperf then
		local sss = {
			--infinitive
			{'perf_actv_inf', 'sse'},
			--unambiguous perfect actives
		    {'2s_perf_actv_indc', 'stī'},
			{'2p_perf_actv_indc', 'stis'},
			--pluperfect subjunctives
		    {'1s_plup_actv_subj', 'ssem'},
			{'2s_plup_actv_subj', 'ssēs'},
			{'3s_plup_actv_subj', 'sset'},
			{'1p_plup_actv_subj', 'ssēmus'},
			{'2p_plup_actv_subj', 'ssētis'},
			{'3p_plup_actv_subj', 'ssent'}
		}
		local noteindex = #(data.footnotes)+1
		function add_sync_perf(form, suff_sync)
			local formval = data.forms[form]
			if type(formval) ~= "table" then
				formval = {formval}
			end
			local newvals = mw.clone(formval)
			for _, fv in ipairs(formval) do
				-- Can only syncopate 'vi', or 'vi' spelled as 'ui' after a vowel
				if fv:find('vi' .. suff_sync .. '$') or mw.ustring.find(fv, '[aeiouyāēīōūȳăĕĭŏŭ]ui' .. suff_sync.. '$') then
					ut.insert_if_not(newvals, mw.ustring.sub(fv, 1, -mw.ustring.len(suff_sync) - 3) .. suff_sync)
				end
			end
			data.forms[form] = newvals
			data.form_footnote_indices[form] = noteindex
		end
		for _, v in ipairs(sss) do
			add_sync_perf(v[1], v[2])
		end
		data.footnotes[noteindex] = "At least one rare poetic syncopated perfect form is attested." end

end

--[=[
	Conjugation functions
]=]--

local function get_regular_stems(args, typeinfo)
	-- Get the parameters
	if typeinfo.subtypes.depon or typeinfo.subtypes.semidepon then
		-- Deponent and semi-deponent verbs don't have the perfective principal part.
		-- But optionally semi-deponent verbs do.
		typeinfo.pres_stem = ine(args[1])
		typeinfo.perf_stem = nil
		typeinfo.supine_stem = ine(args[2])
	else
		typeinfo.pres_stem = ine(args[1])
		typeinfo.perf_stem = ine(args[2])
		typeinfo.supine_stem = ine(args[3])
	end

	if (typeinfo.subtypes.perfaspres or typeinfo.subtypes.memini
	) and not typeinfo.pres_stem then
		typeinfo.pres_stem = "whatever"
	end

	-- Prepare stems
	if not typeinfo.pres_stem then
		if NAMESPACE == "Template" then
			typeinfo.pres_stem = "-"
		else
			error("Present stem has not been provided")
		end
	end

	if typeinfo.perf_stem then
		typeinfo.perf_stem = mw.text.split(typeinfo.perf_stem, "/")
	else
		typeinfo.perf_stem = {}
	end

	if typeinfo.supine_stem then
		typeinfo.supine_stem = mw.text.split(typeinfo.supine_stem, "/")
	else
		typeinfo.supine_stem = {}
	end
end

local function has_perf_in_s_or_x(pres_stem, perf_stem)
	if pres_stem == perf_stem then
		return false
	end

	return perf_stem and perf_stem:find("[sx]$") ~= nil
end

conjugations["1st"] = function(args, data, typeinfo)
	get_regular_stems(args, typeinfo)

	table.insert(data.title, "[[Appendix:Latin first conjugation|first conjugation]]")
	table.insert(data.categories, "Latin first conjugation verbs")

	for _, perf_stem in ipairs(typeinfo.perf_stem) do
		if perf_stem == typeinfo.pres_stem .. "āv" then
			table.insert(data.categories, "Latin first conjugation verbs with perfect in -av-")
		elseif perf_stem == typeinfo.pres_stem .. "u" then
			table.insert(data.categories, "Latin first conjugation verbs with perfect in -u-")
		elseif perf_stem == typeinfo.pres_stem then
			table.insert(data.categories, "Latin first conjugation verbs with suffixless perfect")
		else
			table.insert(data.categories, "Latin first conjugation verbs with irregular perfect")
		end
	end

	make_pres_1st(data, typeinfo.pres_stem)
	make_perf_and_supine(data, typeinfo)
end

conjugations["2nd"] = function(args, data, typeinfo)
	get_regular_stems(args, typeinfo)

	table.insert(data.title, "[[Appendix:Latin second conjugation|second conjugation]]")
	table.insert(data.categories, "Latin second conjugation verbs")

	for _, perf_stem in ipairs(typeinfo.perf_stem) do
		local pres_stem = typeinfo.pres_stem
		pres_stem = pres_stem:gsub("qu", "1")
		perf_stem = perf_stem:gsub("qu", "1")
		if perf_stem == pres_stem .. "ēv" then
			table.insert(data.categories, "Latin second conjugation verbs with perfect in -ev-")
		elseif perf_stem == pres_stem .. "u" then
			table.insert(data.categories, "Latin second conjugation verbs with perfect in -u-")
		elseif perf_stem == pres_stem then
			table.insert(data.categories, "Latin second conjugation verbs with suffixless perfect")
		elseif has_perf_in_s_or_x(pres_stem, perf_stem) then
			table.insert(data.categories, "Latin second conjugation verbs with perfect in -s- or -x-")
		else
			table.insert(data.categories, "Latin second conjugation verbs with irregular perfect")
		end
	end

	make_pres_2nd(data, typeinfo.pres_stem)
	make_perf_and_supine(data, typeinfo)
end

local function set_3rd_conj_categories(data, typeinfo)
	table.insert(data.categories, "Latin third conjugation verbs")

	for _, perf_stem in ipairs(typeinfo.perf_stem) do
		local pres_stem = typeinfo.pres_stem
		pres_stem = pres_stem:gsub("qu", "1")
		perf_stem = perf_stem:gsub("qu", "1")
		if perf_stem == pres_stem .. "āv" then
			table.insert(data.categories, "Latin third conjugation verbs with perfect in -av-")
		elseif perf_stem == pres_stem .. "ēv" then
			table.insert(data.categories, "Latin third conjugation verbs with perfect in -ev-")
		elseif perf_stem == pres_stem .. "īv" then
			table.insert(data.categories, "Latin third conjugation verbs with perfect in -iv-")
		elseif perf_stem == pres_stem .. "i" then
			table.insert(data.categories, "Latin third conjugation verbs with perfect in -i-")
		elseif perf_stem == pres_stem .. "u" then
			table.insert(data.categories, "Latin third conjugation verbs with perfect in -u-")
		elseif perf_stem == pres_stem then
			table.insert(data.categories, "Latin third conjugation verbs with suffixless perfect")
		elseif has_perf_in_s_or_x(pres_stem, perf_stem) then
			table.insert(data.categories, "Latin third conjugation verbs with perfect in -s- or -x-")
		else
			table.insert(data.categories, "Latin third conjugation verbs with irregular perfect")
		end
	end
end

conjugations["3rd"] = function(args, data, typeinfo)
	get_regular_stems(args, typeinfo)

	table.insert(data.title, "[[Appendix:Latin third conjugation|third conjugation]]")
	set_3rd_conj_categories(data, typeinfo)

	if typeinfo.pres_stem and mw.ustring.match(typeinfo.pres_stem,"[āēīōū]sc$") then
		table.insert(data.categories, "Latin inchoative verbs")
	end

	make_pres_3rd(data, typeinfo.pres_stem)
	make_perf_and_supine(data, typeinfo)
end

conjugations["3rd-io"] = function(args, data, typeinfo)
	get_regular_stems(args, typeinfo)

	table.insert(data.title, "[[Appendix:Latin third conjugation|third conjugation]] ''iō''-variant")
	set_3rd_conj_categories(data, typeinfo)

	make_pres_3rd_io(data, typeinfo.pres_stem)
	make_perf_and_supine(data, typeinfo)
end

local function ivi_ive(form)
	form = form:gsub("īvī", "iī")
	form = form:gsub("īvi", "ī")
	form = form:gsub("īve", "ī")
	form = form:gsub("īvē", "ē")
	return form
end

conjugations["4th"] = function(args, data, typeinfo)
	get_regular_stems(args, typeinfo)

	table.insert(data.title, "[[Appendix:Latin fourth conjugation|fourth conjugation]]")
	table.insert(data.categories, "Latin fourth conjugation verbs")


	for _, perf_stem in ipairs(typeinfo.perf_stem) do
		local pres_stem = typeinfo.pres_stem
		pres_stem = pres_stem:gsub("qu", "1")
		perf_stem = perf_stem:gsub("qu", "1")
		if perf_stem == pres_stem .. "īv" then
			table.insert(data.categories, "Latin fourth conjugation verbs with perfect in -iv-")
		elseif perf_stem == pres_stem .. "i" then
			table.insert(data.categories, "Latin fourth conjugation verbs with perfect in -i-")
		elseif perf_stem == pres_stem .. "u" then
			table.insert(data.categories, "Latin fourth conjugation verbs with perfect in -u-")
		elseif perf_stem == pres_stem then
			table.insert(data.categories, "Latin fourth conjugation verbs with suffixless perfect")
		elseif has_perf_in_s_or_x(pres_stem, perf_stem) then
			table.insert(data.categories, "Latin fourth conjugation verbs with perfect in -s- or -x-")
		else
			table.insert(data.categories, "Latin fourth conjugation verbs with irregular perfect")
		end
	end

	make_pres_4th(data, typeinfo.pres_stem)
	make_perf_and_supine(data, typeinfo)

	if form_contains(data.forms["1s_pres_actv_indc"], "serviō") or form_contains(data.forms["1s_pres_actv_indc"], "saeviō") then
		add_forms(data, "impf_actv_indc", typeinfo.pres_stem,
			{"iēbam", "ībam"},
			{"iēbās", "ībās"},
			{"iēbat", "ībat"},
			{"iēbāmus", "ībāmus"},
			{"iēbātis", "ībātis"},
			{"iēbant", "ībant"}
		)

		add_forms(data, "futr_actv_indc", typeinfo.pres_stem,
			{"iam", "ībō"},
			{"iēs", "ībis"},
			{"iet", "ībit"},
			{"iēmus", "ībimus"},
			{"iētis", "ībitis"},
			{"ient", "ībunt"}
		)
	end

	if typeinfo.subtypes.alwayssyncperf or typeinfo.subtypes.optsyncperf then
		for key, form in pairs(data.forms) do
			if cfind(key, "perf") or cfind(key, "plup") or cfind(key, "futp") then
				local forms = data.forms[key]
				if type(forms) ~= "table" then
					forms = {forms}
				end
				data.forms[key] = {}
				for _, f in ipairs(forms) do
					if typeinfo.subtypes.optsyncperf then
						ut.insert_if_not(data.forms[key], f)
					end
					ut.insert_if_not(data.forms[key], ivi_ive(f))
				end
			end
		end
	end
end

-- Irregular conjugations
local irreg_conjugations = {}

conjugations["irreg"] = function(args, data, typeinfo)
	local verb = ine(args[1])
	local prefix = ine(args[2])

	if not verb then
		if NAMESPACE == "Template" then
			verb = "sum"
		else
			error("The verb to be conjugated has not been specified.")
		end
	end

	if not irreg_conjugations[verb] then
		error("The verb '" .. verb .. "' is not recognised as an irregular verb.")
	end

	typeinfo.verb = verb
	typeinfo.prefix = prefix

	-- Generate the verb forms
	irreg_conjugations[verb](args, data, typeinfo)
end

irreg_conjugations["aio"] = function(args, data, typeinfo)
	table.insert(data.title, "[[Appendix:Latin third conjugation|third conjugation]] iō-variant")
	table.insert(data.title, "[[Appendix:Latin irregular verbs|irregular]]")
	table.insert(data.title, "active only")
	table.insert(data.title, "highly [[defective verb|defective]]")
	table.insert(data.categories, "Latin third conjugation verbs")
	table.insert(data.categories, "Latin irregular verbs")
	table.insert(data.categories, "Latin active-only verbs")
	table.insert(data.categories, "Latin defective verbs")

	local prefix = typeinfo.prefix or ""

	data.forms["1s_pres_actv_indc"] = {prefix .. "āiō", prefix .. "aiiō"}
	data.forms["2s_pres_actv_indc"] = {prefix .. "āis", prefix .. "ais"}
	data.forms["3s_pres_actv_indc"] = prefix .. "ait"
	data.forms["3p_pres_actv_indc"] = {prefix .. "āiunt", prefix .. "aiiunt"}

	data.forms["1s_impf_actv_indc"] = {prefix .. "aiēbam", prefix .. "āībam"}
	data.forms["2s_impf_actv_indc"] = {prefix .. "aiēbās", prefix .. "āībās"}
	data.forms["3s_impf_actv_indc"] = {prefix .. "aiēbat", prefix .. "āībat"}
	data.forms["1p_impf_actv_indc"] = {prefix .. "aiēbāmus", prefix .. "āībāmus"}
	data.forms["2p_impf_actv_indc"] = {prefix .. "aiēbātis", prefix .. "āībātis"}
	data.forms["3p_impf_actv_indc"] = {prefix .. "aiēbant", prefix .. "āībant"}

	data.forms["2s_perf_actv_indc"] = prefix .. "aistī"
	data.forms["3s_perf_actv_indc"] = prefix .. "ait"

	data.forms["2s_pres_actv_subj"] = prefix .. "āiās"
	data.forms["3s_pres_actv_subj"] = prefix .. "āiat"
	data.forms["3p_pres_actv_subj"] = prefix .. "āiant"

	data.forms["2s_pres_actv_impr"] = prefix .. "aï"

	data.forms["pres_actv_inf"] = prefix .. "āiere"
	data.forms["pres_actv_ptc"] = prefix .. "aiēns"
end

irreg_conjugations["dico"] = function(args, data, typeinfo)
	table.insert(data.title, "[[Appendix:Latin third conjugation|third conjugation]]")
	table.insert(data.title, "[[Appendix:Latin irregular verbs|irregular]] short imperative")
	table.insert(data.categories, "Latin third conjugation verbs")
	table.insert(data.categories, "Latin irregular verbs")

	local prefix = typeinfo.prefix or ""

	make_pres_3rd(data, prefix .. "dīc")
	make_perf(data, prefix .. "dīx")
	make_supine(data, prefix .. "dict")

	add_form(data, "2s_pres_actv_impr", prefix, "dīc", 1)
end

irreg_conjugations["do"] = function(args, data, typeinfo)
	table.insert(data.title, "[[Appendix:Latin first conjugation|first conjugation]]")
	table.insert(data.title, "[[Appendix:Latin irregular verbs|irregular]] short ''a'' in most forms except " .. make_link({lang = lang, alt = "dās"}, "term") .. " and " .. make_link({lang = lang, alt = "dā"}, "term"))
	table.insert(data.categories, "Latin first conjugation verbs")
	table.insert(data.categories, "Latin irregular verbs")

	local prefix = typeinfo.prefix or ""

	make_perf(data, prefix .. "ded")
	make_supine(data, prefix .. "dat")

	-- Active imperfective indicative
	add_forms(data, "pres_actv_indc", prefix, "dō", "dās", "dat", "damus", "datis", "dant")
	add_forms(data, "impf_actv_indc", prefix, "dabam", "dabās", "dabat", "dabāmus", "dabātis", "dabant")
	add_forms(data, "futr_actv_indc", prefix, "dabō", "dabis", "dabit", "dabimus", "dabitis", "dabunt")

	-- Passive imperfective indicative
	add_forms(data, "pres_pasv_indc", prefix, "dor", {"daris", "dare"}, "datur", "damur", "daminī", "dantur")
	add_forms(data, "impf_pasv_indc", prefix, "dabar", {"dabāris", "dabāre"}, "dabātur", "dabāmur", "dabāminī", "dabantur")
	add_forms(data, "futr_pasv_indc", prefix, "dabor", {"daberis", "dabere"}, "dabitur", "dabimur", "dabiminī", "dabuntur")

	-- Active imperfective subjunctive
	add_forms(data, "pres_actv_subj", prefix, "dem", "dēs", "det", "dēmus", "dētis", "dent")
	add_forms(data, "impf_actv_subj", prefix, "darem", "darēs", "daret", "darēmus", "darētis", "darent")

	-- Passive imperfective subjunctive
	add_forms(data, "pres_pasv_subj", prefix, "der", {"dēris", "dēre"}, "dētur", "dēmur", "dēminī", "dentur")
	add_forms(data, "impf_pasv_subj", prefix, "darer", {"darēris", "darēre"}, "darētur", "darēmur", "darēminī", "darentur")

	-- Imperative
	add_2_forms(data, "pres_actv_impr", prefix, "dā", "date")
	add_23_forms(data, "futr_actv_impr", prefix, "datō", "datō", "datōte", "dantō")

	add_2_forms(data, "pres_pasv_impr", prefix, "dare", "daminī")
	-- no 2p form
	add_23_forms(data, "futr_pasv_impr", prefix, "dator", "dator", {}, "dantor")

	-- Present infinitives
	data.forms["pres_actv_inf"] = prefix .. "dare"
	data.forms["pres_pasv_inf"] = prefix .. "darī"

	-- Imperfective participles
	data.forms["pres_actv_ptc"] = prefix .. "dāns"
	data.forms["futr_pasv_ptc"] = prefix .. "dandus"

	-- Gerund
	data.forms["ger_nom"] = data.forms["pres_actv_inf"]
	data.forms["ger_gen"] = prefix .. "dandī"
	data.forms["ger_dat"] = prefix .. "dandō"
	data.forms["ger_acc"] = prefix .. "dandum"
end

irreg_conjugations["duco"] = function(args, data, typeinfo)
	table.insert(data.title, "[[Appendix:Latin third conjugation|third conjugation]]")
	table.insert(data.title, "[[Appendix:Latin irregular verbs|irregular]] short imperative")
	table.insert(data.categories, "Latin third conjugation verbs")
	table.insert(data.categories, "Latin irregular verbs")

	local prefix = typeinfo.prefix or ""

	make_pres_3rd(data, prefix .. "dūc")
	make_perf(data, prefix .. "dūx")
	make_supine(data, prefix .. "duct")

	add_form(data, "2s_pres_actv_impr", prefix, "dūc", 1)
end

irreg_conjugations["edo"] = function(args, data, typeinfo)
	table.insert(data.title, "[[Appendix:Latin third conjugation|third conjugation]]")
	table.insert(data.title, "some [[Appendix:Latin irregular verbs|irregular]] alternative forms")
	table.insert(data.categories, "Latin third conjugation verbs")
	table.insert(data.categories, "Latin irregular verbs")

	local prefix = typeinfo.prefix or ""

	make_pres_3rd(data, prefix .. "ed")
	make_perf(data, prefix .. "ēd")
	make_supine(data, prefix .. "ēs")

	-- Active imperfective indicative
	add_forms(data, "pres_actv_indc", prefix, {}, "ēs", "ēst", {}, "ēstis", {})

	-- Passive imperfective indicative
	add_form(data, "3s_pres_pasv_indc", prefix, "ēstur")

	-- Active imperfective subjunctive
	add_forms(data, "pres_actv_subj", prefix, "edim", "edīs", "edit", "edīmus", "edītis", "edint")
	add_forms(data, "impf_actv_subj", prefix, "ēssem", "ēssēs", "ēsset", "ēssēmus", "ēssētis", "ēssent")

	-- Active imperative
	add_2_forms(data, "pres_actv_impr", prefix, "ēs", "ēste")
	add_23_forms(data, "futr_actv_impr", prefix, "ēstō", "ēstō", "ēstōte", {})

	-- Present infinitives
	add_form(data, "pres_actv_inf", prefix, "ēsse")
end

irreg_conjugations["eo"] = function(args, data, typeinfo)
	table.insert(data.title, "[[Appendix:Latin irregular verbs|irregular]]")
	table.insert(data.categories, "Latin irregular verbs")

	local prefix = typeinfo.prefix or ""

	make_perf(data, prefix .. "i")
	make_supine(data, prefix .. "it")
	typeinfo.supine_stem = {"it"}

	-- Active imperfective indicative
	add_forms(data, "pres_actv_indc", prefix, "eō", "īs", "it", "īmus", "ītis",
		prefix == "prōd" and {"eunt", "īnunt"} or "eunt")
	add_forms(data, "impf_actv_indc", prefix, "ībam", "ībās", "ībat", "ībāmus", "ībātis", "ībant")
	add_forms(data, "futr_actv_indc", prefix, "ībō", "ībis", "ībit", "ībimus", "ībitis", "ībunt")

	-- Active perfective indicative
	add_form(data, "1s_perf_actv_indc", prefix, "īvī")
	data.forms["2s_perf_actv_indc"] = {prefix .. "īstī", prefix .. "īvistī"}
	add_form(data, "3s_perf_actv_indc", prefix, "īvit")
	data.forms["2p_perf_actv_indc"] = prefix .. "īstis"

	-- Passive imperfective indicative
	add_forms(data, "pres_pasv_indc", prefix, "eor", { "īris", "īre"}, "ītur", "īmur", "īminī", "euntur")
	add_forms(data, "impf_pasv_indc", prefix, "ībar", {"ībāris", "ībāre"}, "ībātur", "ībāmur", "ībāminī", "ībantur")
	add_forms(data, "futr_pasv_indc",  prefix, "ībor", {"īberis", "ībere"}, "ībitur", "ībimur", "ībiminī", "ībuntur")

	-- Active imperfective subjunctive
	add_forms(data, "pres_actv_subj", prefix, "eam", "eās", "eat", "eāmus", "eātis", "eant")
	add_forms(data, "impf_actv_subj", prefix, "īrem", "īrēs", "īret", "īrēmus", "īrētis", "īrent")

	-- Active perfective subjunctive
	data.forms["1s_plup_actv_subj"] = prefix .. "īssem"
	data.forms["2s_plup_actv_subj"] = prefix .. "īssēs"
	data.forms["3s_plup_actv_subj"] = prefix .. "īsset"
	data.forms["1p_plup_actv_subj"] = prefix .. "īssēmus"
	data.forms["2p_plup_actv_subj"] = prefix .. "īssētis"
	data.forms["3p_plup_actv_subj"] = prefix .. "īssent"

	-- Passive imperfective subjunctive
	add_forms(data, "pres_pasv_subj", prefix, "ear", {"eāris", "eāre"}, "eātur", "eāmur", "eāminī", "eantur")
	add_forms(data, "impf_pasv_subj", prefix, "īrer", {"īrēris", "īrēre"}, "īrētur", "īrēmur", "īrēminī", "īrentur")

	-- Imperative
	add_2_forms(data, "pres_actv_impr", prefix, "ī", "īte")
	add_23_forms(data, "futr_actv_impr", prefix, "ītō", "ītō", "ītōte", "euntō")

	add_2_forms(data, "pres_pasv_impr", prefix, "īre", "īminī")
	add_23_forms(data, "futr_pasv_impr", prefix, "ītor", "ītor", {}, "euntor")

	-- Present infinitives
	data.forms["pres_actv_inf"] = prefix .. "īre"
	data.forms["pres_pasv_inf"] = prefix .. "īrī"

	-- Perfect/future infinitives
	data.forms["perf_actv_inf"] = prefix .. "īsse"

	-- Imperfective participles
	data.forms["pres_actv_ptc"] = prefix .. "iēns"
	data.forms["futr_pasv_ptc"] = prefix .. "eundus"

	-- Gerund
	data.forms["ger_nom"] = data.forms["pres_actv_inf"]
	data.forms["ger_gen"] = prefix .. "eundī"
	data.forms["ger_dat"] = prefix .. "eundō"
	data.forms["ger_acc"] = prefix .. "eundum"
end

local function fio(data, prefix, voice)
	-- Active/passive imperfective indicative
	add_forms(data, "pres_" .. voice .. "_indc", prefix,
		"fīō", "fīs", "fit", "fīmus", "fītis", "fīunt")
	add_forms(data, "impf_" .. voice .. "_indc", prefix .. "fīēb",
		"am", "ās", "at", "āmus", "ātis", "ant")
	add_forms(data, "futr_" .. voice .. "_indc", prefix .. "fī",
		"am", "ēs", "et", "ēmus", "ētis", "ent")

	-- Active/passive imperfective subjunctive
	add_forms(data, "pres_" .. voice .. "_subj", prefix .. "fī",
		"am", "ās", "at", "āmus", "ātis", "ant")
	add_forms(data, "impf_" .. voice .. "_subj", prefix .. "fier",
		"em", "ēs", "et", "ēmus", "ētis", "ent")

	-- Active/passive imperative
	add_2_forms(data, "pres_" .. voice .. "_impr", prefix .. "fī", "", "te")
	add_23_forms(data, "futr_" .. voice .. "_impr", prefix .. "fī", "tō", "tō", "tōte", "untō")

	-- Active/passive present infinitive
	add_form(data, "pres_" .. voice .. "_inf", prefix, "fierī")
end

irreg_conjugations["facio"] = function(args, data, typeinfo)
	table.insert(data.title, "[[Appendix:Latin third conjugation|third conjugation]] ''iō''-variant")
	table.insert(data.title, "[[Appendix:Latin irregular verbs|irregular]] and [[suppletive]] in the passive")
	table.insert(data.categories, "Latin third conjugation verbs")
	table.insert(data.categories, "Latin irregular verbs")
	table.insert(data.categories, "Latin suppletive verbs")

	local prefix = typeinfo.prefix or ""

	make_pres_3rd_io(data, prefix .. "fac", "nopass")
	-- We said no passive, but we do want the future passive participle.
	data.forms["futr_pasv_ptc"] = prefix .. "faciendus"

	make_perf(data, prefix .. "fēc")
	make_supine(data, prefix .. "fact")

	-- Active imperative
	if prefix == "" then
		add_form(data, "2s_pres_actv_impr", prefix, "fac", 1)
	end

	fio(data, prefix, "pasv")
end

irreg_conjugations["fio"] = function(args, data, typeinfo)
	table.insert(data.title, "[[Appendix:Latin third conjugation|third conjugation]] ''iō''-variant")
	table.insert(data.title, "[[Appendix:Latin irregular verbs|irregular]] long ''ī''")
	if not typeinfo.subtypes.nosup then
		table.insert(data.title, "[[suppletive]] in the supine stem")
	end
	table.insert(data.categories, "Latin third conjugation verbs")
	table.insert(data.categories, "Latin irregular verbs")
	table.insert(data.categories, "Latin suppletive verbs")

	local prefix = typeinfo.prefix or ""

	typeinfo.subtypes.semidepon = true

	fio(data, prefix, "actv")

	make_supine(data, prefix .. "fact")

	-- Perfect/future infinitives
	data.forms["futr_actv_inf"] = data.forms["futr_pasv_inf"]

	-- Imperfective participles
	data.forms["pres_actv_ptc"] = nil
	data.forms["futr_actv_ptc"] = nil

	-- Gerund
	data.forms["ger_nom"] = data.forms["pres_actv_inf"]
	data.forms["ger_gen"] = prefix .. "fiendī"
	data.forms["ger_dat"] = prefix .. "fiendō"
	data.forms["ger_acc"] = prefix .. "fiendum"
end

irreg_conjugations["fero"] = function(args, data, typeinfo)
	table.insert(data.title, "[[Appendix:Latin third conjugation|third conjugation]]")
	table.insert(data.title, "[[Appendix:Latin irregular verbs|irregular]]")
	table.insert(data.title, "[[suppletive]]")
	table.insert(data.categories, "Latin third conjugation verbs")
	table.insert(data.categories, "Latin irregular verbs")
	table.insert(data.categories, "Latin suppletive verbs")

	local prefix_pres = typeinfo.prefix or ""
	local prefix_perf = ine(args[3])
	local prefix_supine = ine(args[4])

	prefix_perf = prefix_perf or prefix_pres
	prefix_supine = prefix_supine or prefix_pres

	make_pres_3rd(data, prefix_pres .. "fer")
	make_perf(data, prefix_perf .. "tul")
	make_supine(data, prefix_supine .. "lāt")

	-- Active imperfective indicative
	data.forms["2s_pres_actv_indc"] = prefix_pres .. "fers"
	data.forms["3s_pres_actv_indc"] = prefix_pres .. "fert"
	data.forms["2p_pres_actv_indc"] = prefix_pres .. "fertis"

	-- Passive imperfective indicative
	data.forms["3s_pres_pasv_indc"] = prefix_pres .. "fertur"

	-- Active imperfective subjunctive
	data.forms["1s_impf_actv_subj"] = prefix_pres .. "ferrem"
	data.forms["2s_impf_actv_subj"] = prefix_pres .. "ferrēs"
	data.forms["3s_impf_actv_subj"] = prefix_pres .. "ferret"
	data.forms["1p_impf_actv_subj"] = prefix_pres .. "ferrēmus"
	data.forms["2p_impf_actv_subj"] = prefix_pres .. "ferrētis"
	data.forms["3p_impf_actv_subj"] = prefix_pres .. "ferrent"

	-- Passive present indicative
	data.forms["2s_pres_pasv_indc"] = {prefix_pres .. "ferris", prefix_pres .. "ferre"}

	-- Passive imperfective subjunctive
	data.forms["1s_impf_pasv_subj"] = prefix_pres .. "ferrer"
	data.forms["2s_impf_pasv_subj"] = {prefix_pres .. "ferrēris", prefix_pres .. "ferrēre"}
	data.forms["3s_impf_pasv_subj"] = prefix_pres .. "ferrētur"
	data.forms["1p_impf_pasv_subj"] = prefix_pres .. "ferrēmur"
	data.forms["2p_impf_pasv_subj"] = prefix_pres .. "ferrēminī"
	data.forms["3p_impf_pasv_subj"] = prefix_pres .. "ferrentur"

	-- Imperative
	data.forms["2s_pres_actv_impr"] = prefix_pres .. "fer"
	data.forms["2p_pres_actv_impr"] = prefix_pres .. "ferte"

	data.forms["2s_futr_actv_impr"] = prefix_pres .. "fertō"
	data.forms["3s_futr_actv_impr"] = prefix_pres .. "fertō"
	data.forms["2p_futr_actv_impr"] = prefix_pres .. "fertōte"

	data.forms["2s_pres_pasv_impr"] = prefix_pres .. "ferre"

	data.forms["2s_futr_pasv_impr"] = prefix_pres .. "fertor"
	data.forms["3s_futr_pasv_impr"] = prefix_pres .. "fertor"

	-- Present infinitives
	data.forms["pres_actv_inf"] = prefix_pres .. "ferre"
	data.forms["pres_pasv_inf"] = prefix_pres .. "ferrī"

	-- Gerund
	data.forms["ger_nom"] = data.forms["pres_actv_inf"]
end

irreg_conjugations["inquam"] = function(args, data, typeinfo)
	table.insert(data.title, "[[Appendix:Latin irregular verbs|irregular]]")
	table.insert(data.title, "highly [[defective verb|defective]]")
	table.insert(data.categories, "Latin irregular verbs")
	table.insert(data.categories, "Latin defective verbs")

	-- not used
	-- local prefix = typeinfo.prefix or ""

	data.forms["1s_pres_actv_indc"] = "inquam"
	data.forms["2s_pres_actv_indc"] = "inquis"
	data.forms["3s_pres_actv_indc"] = "inquit"
	data.forms["1p_pres_actv_indc"] = "inquimus"
	data.forms["2p_pres_actv_indc"] = "inquitis"
	data.forms["3p_pres_actv_indc"] = "inquiunt"

	data.forms["2s_futr_actv_indc"] = "inquiēs"
	data.forms["3s_futr_actv_indc"] = "inquiet"

	data.forms["3s_impf_actv_indc"] = "inquiēbat"

	data.forms["1s_perf_actv_indc"] = "inquiī"
	data.forms["2s_perf_actv_indc"] = "inquistī"
	data.forms["3s_perf_actv_indc"] = "inquit"

	data.forms["3s_pres_actv_subj"] = "inquiat"

	data.forms["2s_pres_actv_impr"] = "inque"
	data.forms["2s_futr_actv_impr"] = "inquitō"
	data.forms["3s_futr_actv_impr"] = "inquitō"

	data.forms["pres_actv_ptc"] = "inquiēns"
end

local function libet_lubet(data, typeinfo, stem)
	table.insert(data.title, "[[Appendix:Latin second conjugation|second conjugation]]")
	table.insert(data.title, "mostly [[impersonal]]")
	table.insert(data.categories, "Latin second conjugation verbs")
	table.insert(data.categories, "Latin impersonal verbs")

	typeinfo.subtypes.nopass = true
	local prefix = typeinfo.prefix or ""

	stem = prefix .. stem

	-- Active imperfective indicative
	data.forms["3s_pres_actv_indc"] = stem .. "et"

	data.forms["3s_impf_actv_indc"] = stem .. "ēbat"

	data.forms["3s_futr_actv_indc"] = stem .. "ēbit"

	-- Active perfective indicative
	data.forms["3s_perf_actv_indc"] = {stem .. "uit", "[[" .. stem .. "itum]] [[est]]"}

	data.forms["3s_plup_actv_indc"] = {stem .. "uerat", "[[" .. stem .. "itum]] [[erat]]"}

	data.forms["3s_futp_actv_indc"] = {stem .. "uerit", "[[" .. stem .. "itum]] [[erit]]"}

	-- Active imperfective subjunctive
	data.forms["3s_pres_actv_subj"] = stem .. "eat"

	data.forms["3s_impf_actv_subj"] = stem .. "ēret"

	-- Active perfective subjunctive
	data.forms["3s_perf_actv_subj"] = {stem .. "uerit", "[[" .. stem .. "itum]] [[sit]]"}

	data.forms["3s_plup_actv_subj"] = {stem .. "uisset", "[[" .. stem .. "itum]] [[esset]]"}
	data.forms["3p_plup_actv_subj"] = stem .. "uissent"

	-- Present infinitives
	data.forms["pres_actv_inf"] = stem .. "ēre"

	-- Perfect infinitive
	data.forms["perf_actv_inf"] = {stem .. "uisse", "[[" .. stem .. "itum]] [[esse]]"}

	-- Imperfective participles
	data.forms["pres_actv_ptc"] = stem .. "ēns"
	data.forms["perf_actv_ptc"] = stem .. "itum"
end

irreg_conjugations["libet"] = function(args, data, typeinfo)
	libet_lubet(data, typeinfo, "lib")
end

irreg_conjugations["lubet"] = function(args, data, typeinfo)
	libet_lubet(data, typeinfo, "lub")
end

irreg_conjugations["licet"] = function(args, data, typeinfo)
	table.insert(data.title, "[[Appendix:Latin second conjugation|second conjugation]]")
	table.insert(data.title, "mostly [[impersonal]]")
	table.insert(data.categories, "Latin second conjugation verbs")
	table.insert(data.categories, "Latin impersonal verbs")

	typeinfo.subtypes.nopass = true

	-- Active imperfective indicative
	data.forms["3s_pres_actv_indc"] = "licet"
	data.forms["3p_pres_actv_indc"] = "licent"

	data.forms["3s_impf_actv_indc"] = "licēbat"
	data.forms["3p_impf_actv_indc"] = "licēbant"

	data.forms["3s_futr_actv_indc"] = "licēbit"

	-- Active perfective indicative
	data.forms["3s_perf_actv_indc"] = {"licuit", "[[licitum]] [[est]]"}

	data.forms["3s_plup_actv_indc"] = {"licuerat", "[[licitum]] [[erat]]"}

	data.forms["3s_futp_actv_indc"] = {"licuerit", "[[licitum]] [[erit]]"}

	-- Active imperfective subjunctive
	data.forms["3s_pres_actv_subj"] = "liceat"
	data.forms["3p_pres_actv_subj"] = "liceant"

	data.forms["3s_impf_actv_subj"] = "licēret"

	-- Perfective subjunctive
	data.forms["3s_perf_actv_subj"] = {"licuerit", "[[licitum]] [[sit]]"}

	data.forms["3s_plup_actv_subj"] = {"licuisset", "[[licitum]] [[esset]]"}

	-- Imperative
	data.forms["2s_futr_actv_impr"] = "licētō"
	data.forms["3s_futr_actv_impr"] = "licētō"

	-- Infinitives
	data.forms["pres_actv_inf"] = "licēre"
	data.forms["perf_actv_inf"] = {"licuisse", "[[licitum]] [[esse]]"}
	data.forms["futr_actv_inf"] = "[[licitūrum]] [[esse]]"

	-- Participles
	data.forms["pres_actv_ptc"] = "licēns"
	data.forms["perf_actv_ptc"] = "licitus"
	data.forms["futr_actv_ptc"] = "licitūrus"
end

-- Handle most forms of volō, mālō, nōlō.
local function volo_malo_nolo(data, indc_stem, subj_stem)
	-- Present active indicative needs to be done individually as each
	-- verb is different.
	add_forms(data, "impf_actv_indc", indc_stem .. "ēb", "am", "ās", "at", "āmus", "ātis", "ant")
	add_forms(data, "futr_actv_indc", indc_stem, "am", "ēs", "et", "ēmus", "ētis", "ent")

	-- Active imperfective subjunctive
	add_forms(data, "pres_actv_subj", subj_stem, "im", "īs", "it", "īmus", "ītis", "int")
	add_forms(data, "impf_actv_subj", subj_stem .. "l", "em", "ēs", "et", "ēmus", "ētis", "ent")

	-- Present infinitives
	data.forms["pres_actv_inf"] = subj_stem .. "le"

	-- Imperfective participles
	data.forms["pres_actv_ptc"] = indc_stem .. "ēns"
end

irreg_conjugations["volo"] = function(args, data, typeinfo)
	table.insert(data.title, "[[Appendix:Latin irregular verbs|irregular]]")
	table.insert(data.categories, "Latin irregular verbs")

	local prefix = typeinfo.prefix or ""

	typeinfo.subtypes.nopass = true
	typeinfo.subtypes.noimp = true
	make_perf(data, prefix .. "volu")

	-- Active imperfective indicative
	add_forms(data, "pres_actv_indc", prefix,
		"volō", "vīs", prefix ~= "" and "vult" or {"vult", "volt"},
		"volumus", prefix ~= "" and "vultis" or {"vultis", "voltis"}, "volunt")
	volo_malo_nolo(data, prefix .. "vol", prefix .. "vel")
end

irreg_conjugations["malo"] = function(args, data, typeinfo)
	table.insert(data.title, "[[Appendix:Latin irregular verbs|irregular]]")
	table.insert(data.categories, "Latin irregular verbs")

	typeinfo.subtypes.nopass = true
	typeinfo.subtypes.noimp = true
	make_perf(data, "mālu")

	-- Active imperfective indicative
	add_forms(data, "pres_actv_indc", "",
		"mālō", "māvīs", "māvult", "mālumus", "māvultis", "mālunt")
	volo_malo_nolo(data, "māl", "māl")
end

irreg_conjugations["nolo"] = function(args, data, typeinfo)
	table.insert(data.title, "[[Appendix:Latin irregular verbs|irregular]]")
	table.insert(data.categories, "Latin irregular verbs")

	typeinfo.subtypes.nopass = true
	make_perf(data, "nōlu")

	-- Active imperfective indicative
	add_forms(data, "pres_actv_indc", "",
		"nōlō", "nōn vīs", "nōn vult", "nōlumus", "nōn vultis", "nōlunt")
	add_forms(data, "impf_actv_indc", "nōlēb", "am", "ās", "at", "āmus", "ātis", "ant")
	volo_malo_nolo(data, "nōl", "nōl")

	-- Imperative
	add_2_forms(data, "pres_actv_impr", "nōlī", "", "te")
	add_23_forms(data, "futr_actv_impr", "nōl", "itō", "itō", "itōte", "untō")
end

irreg_conjugations["possum"] = function(args, data, typeinfo)
	table.insert(data.title, "highly [[Appendix:Latin irregular verbs|irregular]]")
	table.insert(data.title, "[[suppletive]]")
	table.insert(data.categories, "Latin irregular verbs")
	table.insert(data.categories, "Latin suppletive verbs")

	typeinfo.subtypes.nopass = true
	make_perf(data, "potu")

	-- Active imperfective indicative
	add_forms(data, "pres_actv_indc", "", "possum", "potes", "potest",
		"possumus", "potestis", "possunt")
	add_forms(data, "impf_actv_indc", "poter", "am", "ās", "at", "āmus", "ātis", "ant")
	add_forms(data, "futr_actv_indc", "poter", "ō", {"is", "e"}, "it", "imus", "itis", "unt")

	-- Active imperfective subjunctive
	add_forms(data, "pres_actv_subj", "poss", "im", "īs", "it", "īmus", "ītis", "int")
	add_forms(data, "impf_actv_subj", "poss", "em", "ēs", "et", "ēmus", "ētis", "ent")

	-- Present infinitives
	data.forms["pres_actv_inf"] = "posse"

	-- Imperfective participles
	data.forms["pres_actv_ptc"] = "potēns"
end

irreg_conjugations["piget"] = function(args, data, typeinfo)
	table.insert(data.title, "[[Appendix:Latin second conjugation|second conjugation]]")
	table.insert(data.title, "[[impersonal]]")
	table.insert(data.title, "[[semi-deponent]]")
	table.insert(data.categories, "Latin second conjugation verbs")
	table.insert(data.categories, "Latin impersonal verbs")
	table.insert(data.categories, "Latin semi-deponent verbs")
	table.insert(data.categories, "Latin defective verbs")

	local prefix = typeinfo.prefix or ""

	--[[
	-- not used
	local ppplink = make_link({lang = lang, term = prefix .. "ausus"}, "term")
	local sumlink = make_link({lang = lang, term = "sum"}, "term")
	--]]

	data.forms["3s_pres_actv_indc"] = prefix .. "piget"

	data.forms["3s_impf_actv_indc"] = prefix .. "pigēbat"

	data.forms["3s_futr_actv_indc"] = prefix .. "pigēbit"

	data.forms["3s_perf_actv_indc"] = {prefix .. "piguit", "[[" .. prefix .. "pigitum]] [[est]]"}

	data.forms["3s_plup_actv_indc"] = {prefix .. "piguerat", "[[" .. prefix .. "pigitum]] [[erat]]"}

	data.forms["3s_futp_actv_indc"] = {prefix .. "piguerit", "[[" .. prefix .. "pigitum]] [[erit]]"}

	data.forms["3s_pres_actv_subj"] = prefix .. "pigeat"

	data.forms["3s_impf_actv_subj"] = prefix .. "pigēret"

	data.forms["3s_perf_actv_subj"] = {prefix .. "piguerit", "[[" .. prefix .. "pigitum]] [[sit]]"}

	data.forms["3s_plup_actv_subj"] = {prefix .. "piguisset", "[[" .. prefix .. "pigitum]] [[esset]]"}

	data.forms["pres_actv_inf"] = prefix .. "pigēre"
	data.forms["perf_actv_inf"] = "[[" .. prefix .. "pigitum]] [[esse]]"
	data.forms["pres_actv_ptc"] = prefix .. "pigēns"
	data.forms["perf_actv_ptc"] = prefix .. "pigitum"

	-- Gerund
	data.forms["ger_nom"] = data.forms["pres_actv_inf"]
	data.forms["ger_gen"] = prefix .. "pigendī"
	data.forms["ger_dat"] = prefix .. "pigendō"
	data.forms["ger_acc"] = prefix .. "pigendum"

end

irreg_conjugations["coepi"] = function(args, data, typeinfo)
	table.insert(data.title, "[[Appendix:Latin third conjugation|third conjugation]]")
	table.insert(data.categories, "Latin third conjugation verbs")
	table.insert(data.categories, "Latin defective verbs")

	local prefix = typeinfo.prefix or ""

	make_perf(data, prefix .. "coep")
	make_supine(data, prefix .. "coept")
	make_perfect_passive(data)

	data.forms["futr_pasv_ptc"] = prefix .. "coepiendus"
end

irreg_conjugations["sum"] = function(args, data, typeinfo)
	table.insert(data.title, "highly [[Appendix:Latin irregular verbs|irregular]]")
	table.insert(data.title, "[[suppletive]]")
	table.insert(data.categories, "Latin irregular verbs")
	table.insert(data.categories, "Latin suppletive verbs")

	local prefix = typeinfo.prefix or ""
	local prefix_d = ine(args[3])
	prefix_d = prefix_d or prefix
	local prefix_f = ine(args[4]); if prefix == "ab" then prefix_f = "ā" end
	prefix_f = prefix_f or prefix
	-- The vowel of the prefix is lengthened if it ends in -n and the next word begins with f- or s-.
	local prefix_long = prefix:gsub("([aeiou]n)$", {["an"] = "ān", ["en"] = "ēn", ["in"] = "īn", ["on"] = "ōn", ["un"] = "ūn"})
	prefix_f = prefix_f:gsub("([aeiou]n)$", {["an"] = "ān", ["en"] = "ēn", ["in"] = "īn", ["on"] = "ōn", ["un"] = "ūn"})

	typeinfo.subtypes.nopass = true
	make_perf(data, prefix_f .. "fu")
	make_supine(data, prefix_f .. "fut")

	-- Active imperfective indicative
	data.forms["1s_pres_actv_indc"] = prefix_long .. "sum"
	data.forms["2s_pres_actv_indc"] = prefix_d .. "es"
	data.forms["3s_pres_actv_indc"] = prefix_d .. "est"
	data.forms["1p_pres_actv_indc"] = prefix_long .. "sumus"
	data.forms["2p_pres_actv_indc"] = prefix_d .. "estis"
	data.forms["3p_pres_actv_indc"] = prefix_long .. "sunt"

	data.forms["1s_impf_actv_indc"] = prefix_d .. "eram"
	data.forms["2s_impf_actv_indc"] = prefix_d .. "erās"
	data.forms["3s_impf_actv_indc"] = prefix_d .. "erat"
	data.forms["1p_impf_actv_indc"] = prefix_d .. "erāmus"
	data.forms["2p_impf_actv_indc"] = prefix_d .. "erātis"
	data.forms["3p_impf_actv_indc"] = prefix_d .. "erant"

	data.forms["1s_futr_actv_indc"] = prefix_d .. "erō"
	data.forms["2s_futr_actv_indc"] = {prefix_d .. "eris", prefix_d .. "ere"}
	data.forms["3s_futr_actv_indc"] = prefix_d .. "erit"
	data.forms["1p_futr_actv_indc"] = prefix_d .. "erimus"
	data.forms["2p_futr_actv_indc"] = prefix_d .. "eritis"
	data.forms["3p_futr_actv_indc"] = prefix_d .. "erunt"

	-- Active imperfective subjunctive
	data.forms["1s_pres_actv_subj"] = prefix_long .. "sim"
	data.forms["2s_pres_actv_subj"] = prefix_long .. "sīs"
	data.forms["3s_pres_actv_subj"] = prefix_long .. "sit"
	data.forms["1p_pres_actv_subj"] = prefix_long .. "sīmus"
	data.forms["2p_pres_actv_subj"] = prefix_long .. "sītis"
	data.forms["3p_pres_actv_subj"] = prefix_long .. "sint"

	data.forms["1s_impf_actv_subj"] = {prefix_d .. "essem", prefix_f .. "forem"}
	data.forms["2s_impf_actv_subj"] = {prefix_d .. "essēs", prefix_f .. "forēs"}
	data.forms["3s_impf_actv_subj"] = {prefix_d .. "esset", prefix_f .. "foret"}
	data.forms["1p_impf_actv_subj"] = {prefix_d .. "essēmus", prefix_f .. "forēmus"}
	data.forms["2p_impf_actv_subj"] = {prefix_d .. "essētis", prefix_f .. "forētis"}
	data.forms["3p_impf_actv_subj"] = {prefix_d .. "essent", prefix_f .. "forent"}

	-- Imperative
	data.forms["2s_pres_actv_impr"] = prefix_d .. "es"
	data.forms["2p_pres_actv_impr"] = prefix_d .. "este"

	data.forms["2s_futr_actv_impr"] = prefix_d .. "estō"
	data.forms["3s_futr_actv_impr"] = prefix_d .. "estō"
	data.forms["2p_futr_actv_impr"] = prefix_d .. "estōte"
	data.forms["3p_futr_actv_impr"] = prefix_long .. "suntō"

	-- Present infinitives
	data.forms["pres_actv_inf"] = prefix_d .. "esse"

	-- Future infinitives
	data.forms["futr_actv_inf"] = {"[[" .. prefix_f .. "futūrus]] [[esse]]", prefix_f .. "fore"}

	-- Imperfective participles
	if prefix == "ab" then
		data.forms["pres_actv_ptc"] = "absēns"
	elseif prefix == "prae" then
		data.forms["pres_actv_ptc"] = "praesēns"
	end

	-- Gerund
	data.forms["ger_nom"] = nil
	data.forms["ger_gen"] = nil
	data.forms["ger_dat"] = nil
	data.forms["ger_acc"] = nil

	-- Supine
	data.forms["sup_acc"] = nil
	data.forms["sup_abl"] = nil
end


-- Form-generating functions

make_pres_1st = function(data, pres_stem)
	if not pres_stem then
		return
	end

	-- Active imperfective indicative
	add_forms(data, "pres_actv_indc", pres_stem, "ō", "ās", "at", "āmus", "ātis", "ant")
	add_forms(data, "impf_actv_indc", pres_stem, "ābam", "ābās", "ābat", "ābāmus", "ābātis", "ābant")
	add_forms(data, "futr_actv_indc", pres_stem, "ābō", "ābis", "ābit", "ābimus", "ābitis", "ābunt")

	-- Passive imperfective indicative
	add_forms(data, "pres_pasv_indc", pres_stem, "or", {"āris", "āre"}, "ātur", "āmur", "āminī", "antur")
	add_forms(data, "impf_pasv_indc", pres_stem, "ābar", {"ābāris", "ābāre"}, "ābātur", "ābāmur", "ābāminī", "ābantur")
	add_forms(data, "futr_pasv_indc", pres_stem, "ābor", {"āberis", "ābere"}, "ābitur", "ābimur", "ābiminī", "ābuntur")

	-- Active imperfective subjunctive
	add_forms(data, "pres_actv_subj", pres_stem, "em", "ēs", "et", "ēmus", "ētis", "ent")
	add_forms(data, "impf_actv_subj", pres_stem, "ārem", "ārēs", "āret", "ārēmus", "ārētis", "ārent")

	-- Passive imperfective subjunctive
	add_forms(data, "pres_pasv_subj", pres_stem, "er", {"ēris", "ēre"}, "ētur", "ēmur", "ēminī", "entur")
	add_forms(data, "impf_pasv_subj", pres_stem, "ārer", {"ārēris", "ārēre"}, "ārētur", "ārēmur", "ārēminī", "ārentur")

	-- Imperative
	add_2_forms(data, "pres_actv_impr", pres_stem, "ā", "āte")
	add_23_forms(data, "futr_actv_impr", pres_stem, "ātō", "ātō", "ātōte", "antō")

	add_2_forms(data, "pres_pasv_impr", pres_stem, "āre", "āminī")
	add_23_forms(data, "futr_pasv_impr", pres_stem, "ātor", "ātor", {}, "antor")

	-- Present infinitives
	data.forms["pres_actv_inf"] = pres_stem .. "āre"
	data.forms["pres_pasv_inf"] = pres_stem .. "ārī"

	-- Imperfective participles
	data.forms["pres_actv_ptc"] = pres_stem .. "āns"
	data.forms["futr_pasv_ptc"] = pres_stem .. "andus"

	-- Gerund
	data.forms["ger_nom"] = data.forms["pres_actv_inf"]
	data.forms["ger_gen"] = pres_stem .. "andī"
	data.forms["ger_dat"] = pres_stem .. "andō"
	data.forms["ger_acc"] = pres_stem .. "andum"
end

make_pres_2nd = function(data, pres_stem, nopass, noimpr)
	-- Active imperfective indicative
	add_forms(data, "pres_actv_indc", pres_stem, "eō", "ēs", "et", "ēmus", "ētis", "ent")
	add_forms(data, "impf_actv_indc", pres_stem, "ēbam", "ēbās", "ēbat", "ēbāmus", "ēbātis", "ēbant")
	add_forms(data, "futr_actv_indc", pres_stem, "ēbō", "ēbis", "ēbit", "ēbimus", "ēbitis", "ēbunt")

	-- Active imperfective subjunctive
	add_forms(data, "pres_actv_subj", pres_stem, "eam", "eās", "eat", "eāmus", "eātis", "eant")
	add_forms(data, "impf_actv_subj", pres_stem, "ērem", "ērēs", "ēret", "ērēmus", "ērētis", "ērent")

	-- Active imperative
	if not noimpr then
		add_2_forms(data, "pres_actv_impr", pres_stem, "ē", "ēte")
		add_23_forms(data, "futr_actv_impr", pres_stem, "ētō", "ētō", "ētōte", "entō")
	end

	if not nopass then
		-- Passive imperfective indicative
		add_forms(data, "pres_pasv_indc", pres_stem, "eor", {"ēris", "ēre"}, "ētur", "ēmur", "ēminī", "entur")
		add_forms(data, "impf_pasv_indc", pres_stem, "ēbar", {"ēbāris", "ēbāre"}, "ēbātur", "ēbāmur", "ēbāminī", "ēbantur")
		add_forms(data, "futr_pasv_indc", pres_stem, "ēbor", {"ēberis", "ēbere"}, "ēbitur", "ēbimur", "ēbiminī", "ēbuntur")

		-- Passive imperfective subjunctive
		add_forms(data, "pres_pasv_subj", pres_stem, "ear", {"eāris", "eāre"}, "eātur", "eāmur", "eāminī", "eantur")
		add_forms(data, "impf_pasv_subj", pres_stem, "ērer", {"ērēris", "ērēre"}, "ērētur", "ērēmur", "ērēminī", "ērentur")

		-- Passive imperative
		if not noimpr then
			add_2_forms(data, "pres_pasv_impr", pres_stem, "ēre", "ēminī")
			add_23_forms(data, "futr_pasv_impr", pres_stem, "ētor", "ētor", {}, "entor")
		end
	end

	-- Present infinitives
	data.forms["pres_actv_inf"] = pres_stem .. "ēre"
	if not nopass then
		data.forms["pres_pasv_inf"] = pres_stem .. "ērī"
	end

	-- Imperfective participles
	data.forms["pres_actv_ptc"] = pres_stem .. "ēns"
	if not nopass then
		data.forms["futr_pasv_ptc"] = pres_stem .. "endus"
	end

	-- Gerund
	data.forms["ger_nom"] = data.forms["pres_actv_inf"]
	data.forms["ger_gen"] = pres_stem .. "endī"
	data.forms["ger_dat"] = pres_stem .. "endō"
	data.forms["ger_acc"] = pres_stem .. "endum"
end

make_pres_3rd = function(data, pres_stem)
	-- Active imperfective indicative
	add_forms(data, "pres_actv_indc", pres_stem, "ō", "is", "it", "imus", "itis", "unt")
	add_forms(data, "impf_actv_indc", pres_stem, "ēbam", "ēbās", "ēbat", "ēbāmus", "ēbātis", "ēbant")
	add_forms(data, "futr_actv_indc", pres_stem, "am", "ēs", "et", "ēmus", "ētis", "ent")

	-- Passive imperfective indicative
	add_forms(data, "pres_pasv_indc", pres_stem, "or", {"eris", "ere"}, "itur", "imur", "iminī", "untur")
	add_forms(data, "impf_pasv_indc", pres_stem, "ēbar", {"ēbāris", "ēbāre"}, "ēbātur", "ēbāmur", "ēbāminī", "ēbantur")
	add_forms(data, "futr_pasv_indc", pres_stem, "ar", {"ēris", "ēre"}, "ētur", "ēmur", "ēminī", "entur")

	-- Active imperfective subjunctive
	add_forms(data, "pres_actv_subj", pres_stem, "am", "ās", "at", "āmus", "ātis", "ant")
	add_forms(data, "impf_actv_subj", pres_stem, "erem", "erēs", "eret", "erēmus", "erētis", "erent")

	-- Passive imperfective subjunctive
	add_forms(data, "pres_pasv_subj", pres_stem, "ar", {"āris", "āre"}, "ātur", "āmur", "āminī", "antur")
	add_forms(data, "impf_pasv_subj", pres_stem, "erer", {"erēris", "erēre"}, "erētur", "erēmur", "erēminī", "erentur")

	-- Imperative
	add_2_forms(data, "pres_actv_impr", pres_stem, "e", "ite")
	add_23_forms(data, "futr_actv_impr", pres_stem, "itō", "itō", "itōte", "untō")

	add_2_forms(data, "pres_pasv_impr", pres_stem, "ere", "iminī")
	add_23_forms(data, "futr_pasv_impr", pres_stem, "itor", "itor", {}, "untor")

	-- Present infinitives
	data.forms["pres_actv_inf"] = pres_stem .. "ere"
	data.forms["pres_pasv_inf"] = pres_stem .. "ī"

	-- Imperfective participles
	data.forms["pres_actv_ptc"] = pres_stem .. "ēns"
	data.forms["futr_pasv_ptc"] = pres_stem .. "endus"

	-- Gerund
	data.forms["ger_nom"] = data.forms["pres_actv_inf"]
	data.forms["ger_gen"] = pres_stem .. "endī"
	data.forms["ger_dat"] = pres_stem .. "endō"
	data.forms["ger_acc"] = pres_stem .. "endum"
end

make_pres_3rd_io = function(data, pres_stem, nopass)
	-- Active imperfective indicative
	add_forms(data, "pres_actv_indc", pres_stem, "iō", "is", "it", "imus", "itis", "iunt")
	add_forms(data, "impf_actv_indc", pres_stem, "iēbam", "iēbās", "iēbat", "iēbāmus", "iēbātis", "iēbant")
	add_forms(data, "futr_actv_indc", pres_stem, "iam", "iēs", "iet", "iēmus", "iētis", "ient")

	-- Active imperfective subjunctive
	add_forms(data, "pres_actv_subj", pres_stem, "iam", "iās", "iat", "iāmus", "iātis", "iant")
	add_forms(data, "impf_actv_subj", pres_stem, "erem", "erēs", "eret", "erēmus", "erētis", "erent")

	-- Active imperative
	add_2_forms(data, "pres_actv_impr", pres_stem, "e", "ite")
	add_23_forms(data, "futr_actv_impr", pres_stem, "itō", "itō", "itōte", "iuntō")

	-- Passive imperfective indicative
	if not nopass then
		add_forms(data, "pres_pasv_indc", pres_stem, "ior", {"eris", "ere"}, "itur", "imur", "iminī", "iuntur")
		add_forms(data, "impf_pasv_indc", pres_stem, "iēbar", {"iēbāris", "iēbāre"}, "iēbātur", "iēbāmur", "iēbāminī", "iēbantur")
		add_forms(data, "futr_pasv_indc", pres_stem, "iar", {"iēris", "iēre"}, "iētur", "iēmur", "iēminī", "ientur")

		-- Passive imperfective subjunctive
		add_forms(data, "pres_pasv_subj", pres_stem, "iar", {"iāris", "iāre"}, "iātur", "iāmur", "iāminī", "iantur")
		add_forms(data, "impf_pasv_subj", pres_stem, "erer", {"erēris", "erēre"}, "erētur", "erēmur", "erēminī", "erentur")

		-- Passive imperative
		add_2_forms(data, "pres_pasv_impr", pres_stem, "ere", "iminī")
		add_23_forms(data, "futr_pasv_impr", pres_stem, "itor", "itor", {}, "iuntor")
	end

	-- Present infinitives
	data.forms["pres_actv_inf"] = pres_stem .. "ere"
	if not nopass then
		data.forms["pres_pasv_inf"] = pres_stem .. "ī"
	end

	-- Imperfective participles
	data.forms["pres_actv_ptc"] = pres_stem .. "iēns"
	if not nopass then
		data.forms["futr_pasv_ptc"] = pres_stem .. "iendus"
	end

	-- Gerund
	data.forms["ger_nom"] = data.forms["pres_actv_inf"]
	data.forms["ger_gen"] = pres_stem .. "iendī"
	data.forms["ger_dat"] = pres_stem .. "iendō"
	data.forms["ger_acc"] = pres_stem .. "iendum"
end

make_pres_4th = function(data, pres_stem)
	-- Active imperfective indicative
	add_forms(data, "pres_actv_indc", pres_stem, "iō", "īs", "it", "īmus", "ītis", "iunt")
	add_forms(data, "impf_actv_indc", pres_stem, "iēbam", "iēbās", "iēbat", "iēbāmus", "iēbātis", "iēbant")
	add_forms(data, "futr_actv_indc", pres_stem, "iam", "iēs", "iet", "iēmus", "iētis", "ient")

	-- Passive imperfective indicative
	add_forms(data, "pres_pasv_indc", pres_stem, "ior", {"īris", "īre"}, "ītur", "īmur", "īminī", "iuntur")
	add_forms(data, "impf_pasv_indc", pres_stem, "iēbar", {"iēbāris", "iēbāre"}, "iēbātur", "iēbāmur", "iēbāminī", "iēbantur")
	add_forms(data, "futr_pasv_indc", pres_stem, "iar", {"iēris", "iēre"}, "iētur", "iēmur", "iēminī", "ientur")

	-- Active imperfective subjunctive
	add_forms(data, "pres_actv_subj", pres_stem, "iam", "iās", "iat", "iāmus", "iātis", "iant")
	add_forms(data, "impf_actv_subj", pres_stem, "īrem", "īrēs", "īret", "īrēmus", "īrētis", "īrent")

	-- Passive imperfective subjunctive
	add_forms(data, "pres_pasv_subj", pres_stem, "iar", {"iāris", "iāre"}, "iātur", "iāmur", "iāminī", "iantur")
	add_forms(data, "impf_pasv_subj", pres_stem, "īrer", {"īrēris", "īrēre"}, "īrētur", "īrēmur", "īrēminī", "īrentur")

	-- Imperative
	add_2_forms(data, "pres_actv_impr", pres_stem, "ī", "īte")
	add_23_forms(data, "futr_actv_impr", pres_stem, "ītō", "ītō", "ītōte", "iuntō")

	add_2_forms(data, "pres_pasv_impr", pres_stem, "īre", "īminī")
	add_23_forms(data, "futr_pasv_impr", pres_stem, "ītor", "ītor", {}, "iuntor")

	-- Present infinitives
	data.forms["pres_actv_inf"] = pres_stem .. "īre"
	data.forms["pres_pasv_inf"] = pres_stem .. "īrī"

	-- Imperfective participles
	data.forms["pres_actv_ptc"] = pres_stem .. "iēns"
	data.forms["futr_pasv_ptc"] = pres_stem .. "iendus"

	-- Gerund
	data.forms["ger_nom"] = data.forms["pres_actv_inf"]
	data.forms["ger_gen"] = pres_stem .. "iendī"
	data.forms["ger_dat"] = pres_stem .. "iendō"
	data.forms["ger_acc"] = pres_stem .. "iendum"
end

make_perf_and_supine = function(data, typeinfo)
	if typeinfo.subtypes.optsemidepon then
		make_perf(data, typeinfo.perf_stem, "noinf")
		make_deponent_perf(data, typeinfo.supine_stem)
	else
		make_perf(data, typeinfo.perf_stem)
		make_supine(data, typeinfo.supine_stem)
	end
end

make_perf = function(data, perf_stem, no_inf)
	if not perf_stem then
		return
	end
	if type(perf_stem) ~= "table" then
		perf_stem = {perf_stem}
	end

	for _, stem in ipairs(perf_stem) do
		-- Perfective indicative
		add_forms(data, "perf_actv_indc", stem, "ī", "istī", "it", "imus", "istis", {"ērunt", "ēre"})
		add_forms(data, "plup_actv_indc", stem, "eram", "erās", "erat", "erāmus", "erātis", "erant")
		add_forms(data, "futp_actv_indc", stem, "erō", "eris", "erit", "erimus", "eritis", "erint")
		-- Perfective subjunctive
		add_forms(data, "perf_actv_subj", stem, "erim", "erīs", "erit", "erīmus", "erītis", "erint")
		add_forms(data, "plup_actv_subj", stem, "issem", "issēs", "isset", "issēmus", "issētis", "issent")

		-- Perfect infinitive
		if not no_inf then
			add_form(data, "perf_actv_inf", stem, "isse")
		end
	end
end

make_deponent_perf = function(data, supine_stem)
	if not supine_stem then
		return
	end
	if type(supine_stem) ~= "table" then
		supine_stem = {supine_stem}
	end

	-- Perfect/future infinitives
	for _, stem in ipairs(supine_stem) do
		local stems = "[[" .. stem .. "us]] "
		local stemp = "[[" .. stem .. "ī]] "

		add_forms(data, "perf_actv_indc", stems, "[[sum]]", "[[es]]", "[[est]]", {}, {}, {})
		add_forms(data, "perf_actv_indc", stemp, {}, {}, {}, "[[sumus]]", "[[estis]]", "[[sunt]]")

		add_forms(data, "plup_actv_indc", stems, "[[eram]]", "[[erās]]", "[[erat]]", {}, {}, {})
		add_forms(data, "plup_actv_indc", stemp, {}, {}, {}, "[[erāmus]]", "[[erātis]]", "[[erant]]")

		add_forms(data, "futp_actv_indc", stems, "[[erō]]", "[[eris]]", "[[erit]]", {}, {}, {})
		add_forms(data, "futp_actv_indc", stemp, {}, {}, {}, "[[erimus]]", "[[eritis]]", "[[erint]]")

		add_forms(data, "perf_actv_subj", stems, "[[sim]]", "[[sīs]]", "[[sit]]", {}, {}, {})
		add_forms(data, "perf_actv_subj", stemp, {}, {}, {}, "[[sīmus]]", "[[sītis]]", "[[sint]]")

		add_forms(data, "plup_actv_subj", stems, "[[essem]]", "[[essēs]]", "[[esset]]", {}, {}, {})
		add_forms(data, "plup_actv_subj", stemp, {}, {}, {}, "[[essēmus]]", "[[essētis]]", "[[essent]]")

		add_form(data, "perf_actv_inf", stems, "[[esse]]")
		add_form(data, "futr_actv_inf", "", "[[" .. stem .. "ūrus]] [[esse]]")
		add_form(data, "perf_actv_ptc", stem, "us")
		add_form(data, "futr_actv_ptc", stem, "ūrus")

		-- Supine
		add_form(data, "sup_acc", stem, "um")
		add_form(data, "sup_abl", stem, "ū")
	end
end

make_supine = function(data, supine_stem)
	if not supine_stem then
		return
	end
	if type(supine_stem) ~= "table" then
		supine_stem = {supine_stem}
	end

	-- Perfect/future infinitives
	for _, stem in ipairs(supine_stem) do
		local futr_actv_inf, perf_pasv_inf, futr_pasv_inf, futr_actv_ptc, perf_pasv_ptc
		if reconstructed then
			futr_actv_inf = "[[" .. NAMESPACE .. ":Latin/" .. stem .. "ūrus|" .. stem .. "ūrus]] [[esse]]"
			perf_pasv_inf = "[[" .. NAMESPACE .. ":Latin/" .. stem .. "us|" .. stem .. "us]] [[esse]]"
			futr_pasv_inf = "[[" .. NAMESPACE .. ":Latin/" .. stem .. "um|" .. stem .. "um]] [[īrī]]"
		else
			futr_actv_inf = "[[" .. stem .. "ūrus]] [[esse]]"
			perf_pasv_inf = "[[" .. stem .. "us]] [[esse]]"
			futr_pasv_inf = "[[" .. stem .. "um]] [[īrī]]"
		end

		-- Perfect/future participles
		futr_actv_ptc = stem .. "ūrus"
		perf_pasv_ptc = stem .. "us"

		-- Exceptions
		local mortu = {
			["conmortu"]=true,
			["commortu"]=true,
			["dēmortu"]=true,
			["ēmortu"]=true,
			["inmortu"]=true,
			["immortu"]=true,
			["inēmortu"]=true,
			["intermortu"]=true,
			["permortu"]=true,
			["praemortu"]=true,
			["superēmortu"]=true
		}
		local ort = {
			["ort"]=true,
			["abort"]=true,
			["adort"]=true,
			["coort"]=true,
			["exort"]=true,
			["hort"]=true,
			["obort"]=true
		}
		if mortu[stem] then
			futr_actv_inf = "[["..stem:gsub("mortu$","moritūrus").."]] [[esse]]"
			futr_actv_ptc = stem:gsub("mortu$","moritūrus")
		elseif ort[stem] then
			futr_actv_inf = "[["..stem:gsub("ort$","oritūrus").."]] [[esse]]"
			futr_actv_ptc = stem:gsub("ort$","oritūrus")
		elseif stem == "mortu" then
			futr_actv_inf = {}
			futr_actv_ptc = "moritūrus"
		end

		add_form(data, "futr_actv_inf", "", futr_actv_inf)
		add_form(data, "perf_pasv_inf", "", perf_pasv_inf)
		add_form(data, "futr_pasv_inf", "", futr_pasv_inf)
		add_form(data, "futr_actv_ptc", "", futr_actv_ptc)
		add_form(data, "perf_pasv_ptc", "", perf_pasv_ptc)

		-- Supine itself
		add_form(data, "sup_acc", stem, "um")
		add_form(data, "sup_abl", stem, "ū")
	end
end

-- Functions for generating the inflection table

-- Convert FORM (one or more forms) to a string of links. If the form is empty
-- (see form_is_empty), the return value will be "&mdash;".
local function show_form(form, accel)
	if not form then
		return "&mdash;"
	end

	if type(form) ~= "table" then
		form = {form}
	end

	for key, subform in ipairs(form) do
		if form_is_empty(subform) then
			form[key] = "&mdash;"
		elseif reconstructed and not subform:find(NAMESPACE .. ":Latin/") then
			form[key] = make_link({lang = lang, term = NAMESPACE .. ":Latin/" .. subform, alt = subform})
		elseif subform:find("[%[%]]") then
			-- Don't put accelerators on forms already containing links such as
			-- the perfect passive infinitive and future active infinitive, or
			-- the participles wrongly get tagged as infinitives as well as
			-- participles.
			form[key] = make_link({lang = lang, term = subform})
		else
			form[key] = make_link({lang = lang, term = subform, accel = accel})
		end
	end

	return table.concat(form, ", ")
end

parts_to_tags = {
  ['1s'] = {'1', 's'},
  ['2s'] = {'2', 's'},
  ['3s'] = {'3', 's'},
  ['1p'] = {'1', 'p'},
  ['2p'] = {'2', 'p'},
  ['3p'] = {'3', 'p'},
  ['actv'] = {'act'},
  ['pasv'] = {'pass'},
  ['pres'] = {'pres'},
  ['impf'] = {'impf'},
  ['futr'] = {'fut'},
  ['perf'] = {'perf'},
  ['plup'] = {'plup'},
  ['futp'] = {'fut', 'perf'},
  ['indc'] = {'ind'},
  ['subj'] = {'sub'},
  ['impr'] = {'imp'},
  ['inf'] = {'inf'},
  ['ptc'] = {'part'},
  ['ger'] = {'ger'},
  ['sup'] = {'sup'},
  ['nom'] = {'nom'},
  ['gen'] = {'gen'},
  ['dat'] = {'dat'},
  ['acc'] = {'acc'},
  ['abl'] = {'abl'},
}

-- Call show_form() the forms in each non-generic slot (where a
-- generic slot is something like pres_actv_indc that covers a whole
-- row of slots), converting the forms to a string consisting of
-- comma-separated links with accelerators in them.
local function convert_forms_into_links(data)
	local accel_lemma = data.actual_lemma[1]
	for slot in iter_slots(false, false) do
		local slot_parts = rsplit(slot, "_")
		local tags = {}
		for _, part in ipairs(slot_parts) do
			for _, tag in ipairs(parts_to_tags[part]) do
				table.insert(tags, tag)
			end
		end
		local accel_slot = table.concat(tags, "|")
		local accel = {form = accel_slot, lemma = accel_lemma}
		data.forms[slot] = show_form(data.forms[slot], accel)
	end
end

function export.get_valid_forms(raw_forms)
	local valid_forms = {}
	if raw_forms then
		if type(raw_forms) ~= "table" then
			raw_forms = {raw_forms}
		end
		for _, subform in ipairs(raw_forms) do
			if not form_is_empty(subform) then
				table.insert(valid_forms, subform)
			end
		end
	end
	return valid_forms
end

function export.get_lemma_forms(data, do_linked)
	local linked_prefix = do_linked and "linked_" or ""
	for _, slot in ipairs(potential_lemma_slots) do
		local lemma_forms = export.get_valid_forms(data.forms[linked_prefix .. slot])
		if #lemma_forms > 0 then
			return lemma_forms
		end
	end

	return nil
end

local function get_displayable_lemma(lemma_forms)
	if not lemma_forms then
		return "&mdash;"
	end
	local lemma_links = {}
	for _, subform in ipairs(lemma_forms) do
		table.insert(lemma_links, make_link({lang = lang, alt = subform}, "term"))
	end
	return table.concat(lemma_links, ", ")
end

-- Make the table
make_table = function(data)
	local pagename = PAGENAME
	if reconstructed then
		pagename = pagename:gsub("Latin/","")
	end
	data.actual_lemma = export.get_lemma_forms(data)
	convert_forms_into_links(data)

	return [=[
{| style="width: 100%; background: #EEE; border: 1px solid #AAA; font-size: 95%; text-align: center;" class="inflection-table vsSwitcher vsToggleCategory-inflection"
|-
! colspan="8" class="vsToggleElement" style="background: #CCC; text-align: left;" | &nbsp;&nbsp;&nbsp;Conjugation of ]=] .. get_displayable_lemma(data.actual_lemma) .. (#data.title > 0 and " (" .. table.concat(data.title, ", ") .. ")" or "") .. [=[

]=] .. make_indc_rows(data) .. make_subj_rows(data) .. make_impr_rows(data) .. make_nonfin_rows(data) .. make_vn_rows(data) .. [=[

|}]=].. make_footnotes(data)

end

local tenses = {
	["pres"] = "present",
	["impf"] = "imperfect",
	["futr"] = "future",
	["perf"] = "perfect",
	["plup"] = "pluperfect",
	["futp"] = "future&nbsp;perfect",
}

local voices = {
	["actv"] = "active",
	["pasv"] = "passive",
}

--[[
local moods = {
	["indc"] = "indicative",
	["subj"] = "subjunctive",
	["impr"] = "imperative",
}
--]]

local nonfins = {
	["inf"] = "infinitives",
	["ptc"] = "participles",
}

--[[
local verbalnouns = {
	["ger"] = "gerund",
	["sup"] = "supine",
}
--]]

--[[
local cases = {
	["nom"] = "nominative",
	["gen"] = "genitive",
	["dat"] = "dative",
	["acc"] = "accusative",
	["abl"] = "ablative",
}
--]]

make_indc_rows = function(data)
	local indc = {}

	for _, v in ipairs({"actv", "pasv"}) do
		local group = {}
		local nonempty = false

		for _, t in ipairs({"pres", "impf", "futr", "perf", "plup", "futp"}) do
			local row = {}
			local notempty = false

			if data.forms[t .. "_" .. v .. "_indc"] then
				row = "\n! colspan=\"6\" style=\"background: #CCC\" |" .. data.forms[t .. "_" .. v .. "_indc"]
				nonempty = true
				notempty = true
			else
				for col, p in ipairs({"1s", "2s", "3s", "1p", "2p", "3p"}) do
					local slot = p .. "_" .. t .. "_" .. v .. "_indc"
					row[col] = "\n| " .. data.forms[slot] .. (
						data.form_footnote_indices[slot] == nil and "" or
						'<sup style="color: red">' .. data.form_footnote_indices[slot].."</sup>"
					)

					-- show_form() already called so can just check for "&mdash;"
					if data.forms[slot] ~= "&mdash;" then
						nonempty = true
						notempty = true
					end
				end

				row = table.concat(row)
			end

			if notempty then
				table.insert(group, "\n! style=\"background:#c0cfe4\" | " .. tenses[t] .. row)
			end
		end

		if nonempty and #group > 0 then
			table.insert(indc, "\n|- class=\"vsHide\"\n! rowspan=\"" .. tostring(#group) .. "\" style=\"background:#c0cfe4\" | " .. voices[v] .. "\n" .. table.concat(group, "\n|- class=\"vsHide\""))
		end
	end

	return
[=[

|- class="vsHide"
! colspan="2" rowspan="2" style="background:#c0cfe4" | indicative
! colspan="3" style="background:#c0cfe4" | ''singular''
! colspan="3" style="background:#c0cfe4" | ''plural''
|- class="vsHide"
! style="background:#c0cfe4;width:12.5%" | [[first person|first]]
! style="background:#c0cfe4;width:12.5%" | [[second person|second]]
! style="background:#c0cfe4;width:12.5%" | [[third person|third]]
! style="background:#c0cfe4;width:12.5%" | [[first person|first]]
! style="background:#c0cfe4;width:12.5%" | [[second person|second]]
! style="background:#c0cfe4;width:12.5%" | [[third person|third]]
]=] .. table.concat(indc)

end

make_subj_rows = function(data)
	local subj = {}

	for _, v in ipairs({"actv", "pasv"}) do
		local group = {}
		local nonempty = false

		for _, t in ipairs({"pres", "impf", "perf", "plup"}) do
			local row = {}
			local notempty = false

			if data.forms[t .. "_" .. v .. "_subj"] then
				row = "\n! colspan=\"6\" style=\"background: #CCC\" |" .. data.forms[t .. "_" .. v .. "_subj"]
				nonempty = true
				notempty = true
			else
				for col, p in ipairs({"1s", "2s", "3s", "1p", "2p", "3p"}) do
					local slot = p .. "_" .. t .. "_" .. v .. "_subj"
					row[col] = "\n| " .. data.forms[slot] .. (
						data.form_footnote_indices[slot] == nil and "" or
						'<sup style="color: red">' .. data.form_footnote_indices[slot].."</sup>"
					)

					-- show_form() already called so can just check for "&mdash;"
					if data.forms[slot] ~= "&mdash;" then
						nonempty = true
						notempty = true
					end
				end

				row = table.concat(row)
			end

			if notempty then
				table.insert(group, "\n! style=\"background:#c0e4c0\" | " .. tenses[t] .. row)
			end
		end

		if nonempty and #group > 0 then
			table.insert(subj, "\n|- class=\"vsHide\"\n! rowspan=\"" .. tostring(#group) .. "\" style=\"background:#c0e4c0\" | " .. voices[v] .. "\n" .. table.concat(group, "\n|- class=\"vsHide\""))
		end
	end

	return
[=[

|- class="vsHide"
! colspan="2" rowspan="2" style="background:#c0e4c0" | subjunctive
! colspan="3" style="background:#c0e4c0" | ''singular''
! colspan="3" style="background:#c0e4c0" | ''plural''
|- class="vsHide"
! style="background:#c0e4c0;width:12.5%" | [[first person|first]]
! style="background:#c0e4c0;width:12.5%" | [[second person|second]]
! style="background:#c0e4c0;width:12.5%" | [[third person|third]]
! style="background:#c0e4c0;width:12.5%" | [[first person|first]]
! style="background:#c0e4c0;width:12.5%" | [[second person|second]]
! style="background:#c0e4c0;width:12.5%" | [[third person|third]]
]=] .. table.concat(subj)

end

make_impr_rows = function(data)
	local impr = {}
	local has_impr = false

	for _, v in ipairs({"actv", "pasv"}) do
		local group = {}
		local nonempty = false

		for _, t in ipairs({"pres", "futr"}) do
			local row = {}

			if data.forms[t .. "_" .. v .. "_impr"] then
				row = "\n! colspan=\"6\" style=\"background: #CCC\" |" .. data.forms[t .. "_" .. v .. "_impr"]
				nonempty = true
			else
				for col, p in ipairs({"1s", "2s", "3s", "1p", "2p", "3p"}) do
					local slot = p .. "_" .. t .. "_" .. v .. "_impr"
					row[col] = "\n| " .. data.forms[slot]

					-- show_form() already called so can just check for "&mdash;"
					if data.forms[slot] ~= "&mdash;" then
						nonempty = true
					end
				end

				row = table.concat(row)
			end

			table.insert(group, "\n! style=\"background:#e4d4c0\" | " .. tenses[t] .. row)
		end

		if nonempty and #group > 0 then
			has_impr = true
			table.insert(impr, "\n|- class=\"vsHide\"\n! rowspan=\"" .. tostring(#group) .. "\" style=\"background:#e4d4c0\" | " .. voices[v] .. "\n" .. table.concat(group, "\n|- class=\"vsHide\""))
		end
	end

	if not has_impr then
		return ""
	end
	return
[=[

|- class="vsHide"
! colspan="2" rowspan="2" style="background:#e4d4c0" | imperative
! colspan="3" style="background:#e4d4c0" | ''singular''
! colspan="3" style="background:#e4d4c0" | ''plural''
|- class="vsHide"
! style="background:#e4d4c0;width:12.5%" | [[first person|first]]
! style="background:#e4d4c0;width:12.5%" | [[second person|second]]
! style="background:#e4d4c0;width:12.5%" | [[third person|third]]
! style="background:#e4d4c0;width:12.5%" | [[first person|first]]
! style="background:#e4d4c0;width:12.5%" | [[second person|second]]
! style="background:#e4d4c0;width:12.5%" | [[third person|third]]
]=] .. table.concat(impr)
end

make_nonfin_rows = function(data)
	local nonfin = {}

	for _, f in ipairs({"inf", "ptc"}) do
		local row = {}

		for col, t in ipairs({"pres_actv", "perf_actv", "futr_actv", "pres_pasv", "perf_pasv", "futr_pasv"}) do
			local slot = t .. "_" .. f
			--row[col] = "\n| " .. data.forms[slot]
			row[col] = "\n| " .. data.forms[slot] .. (
				data.form_footnote_indices[slot] == nil and "" or
				'<sup style="color: red">' .. data.form_footnote_indices[slot] .."</sup>"
			)

		end

		row = table.concat(row)
		table.insert(nonfin, "\n|- class=\"vsHide\"\n! style=\"background:#e2e4c0\" colspan=\"2\" | " .. nonfins[f] .. row)
	end

	return
[=[

|- class="vsHide"
! colspan="2" rowspan="2" style="background:#e2e4c0" | non-finite forms
! colspan="3" style="background:#e2e4c0" | active
! colspan="3" style="background:#e2e4c0" | passive
|- class="vsHide"
! style="background:#e2e4c0;width:12.5%" | present
! style="background:#e2e4c0;width:12.5%" | perfect
! style="background:#e2e4c0;width:12.5%" | future
! style="background:#e2e4c0;width:12.5%" | present
! style="background:#e2e4c0;width:12.5%" | perfect
! style="background:#e2e4c0;width:12.5%" | future
]=] .. table.concat(nonfin)

end

make_vn_rows = function(data)
	local vn = {}
	local has_vn = false

	local row = {}

	for col, slot in ipairs({"ger_nom", "ger_gen", "ger_dat", "ger_acc", "sup_acc", "sup_abl"}) do
		-- show_form() already called so can just check for "&mdash;"
		if data.forms[slot] ~= "&mdash;" then
			has_vn = true
		end
		row[col] = "\n| " .. data.forms[slot] .. (
			data.form_footnote_indices[slot] == nil and "" or
			'<sup style="color: red">' .. data.form_footnote_indices[slot] .. "</sup>"
		)
	end

	row = table.concat(row)

	if has_vn then
		table.insert(vn, "\n|- class=\"vsHide\"" .. row)
	end

	if not has_vn then
		return ""
	end
	return
[=[

|- class="vsHide"
! colspan="2" rowspan="3" style="background:#e0e0b0" | verbal nouns
! colspan="4" style="background:#e0e0b0" | gerund
! colspan="2" style="background:#e0e0b0" | supine
|- class="vsHide"
! style="background:#e0e0b0;width:12.5%" | nominative
! style="background:#e0e0b0;width:12.5%" | genitive
! style="background:#e0e0b0;width:12.5%" | dative/ablative
! style="background:#e0e0b0;width:12.5%" | accusative
! style="background:#e0e0b0;width:12.5%" | accusative
! style="background:#e0e0b0;width:12.5%" | ablative]=] .. table.concat(vn)

end

make_footnotes = function(data)
	local tbl = {}
	local i = 0
	for k,v in pairs(data.footnotes) do
		i = i + 1
		tbl[i] = '<sup style="color: red">'..tostring(k)..'</sup>'..v..'<br>' end
	return table.concat(tbl)
end

override = function(data, args)
	for slot in iter_slots(true, false) do
		if args[slot] then
			data.forms[slot] = mw.text.split(args[slot], "/")
		end
	end
end

checkexist = function(data)
	if NAMESPACE ~= '' then return end
	local outerbreak = false
	for _, conjugation in pairs(data.forms) do
		if conjugation then
			if type(conjugation) == 'string' then
				conjugation = {conjugation}
			end
			for _, conj in ipairs(conjugation) do
				if not cfind(conj, " ") then
					local title = lang:makeEntryName(conj)
					local t = mw.title.new(title)
					if t and not t.exists then
						table.insert(data.categories, 'Latin verbs with red links in their conjugation tables')
						outerbreak = true
						break
					end
				end
			end
		end
		if outerbreak then
			break
		end
	end
end

checkirregular = function(args,data)
	local apocopic = mw.ustring.sub(args[1],1,-2)
	apocopic = mw.ustring.gsub(apocopic,'[^aeiouyāēīōūȳ]+$','')
	if args[1] and args[2] and not mw.ustring.find(args[2],'^'..apocopic) then
		table.insert(data.categories,'Latin stem-changing verbs')
	end
end







-- functions for creating external search hyperlinks

flatten_values = function(T)
	function noaccents(x)
		return mw.ustring.gsub(mw.ustring.toNFD(x),'[^%w]+',"")
	end
	function cleanup(x)
		return noaccents(string.gsub(string.gsub(string.gsub(x, '%[', ''), '%]', ''), ' ', '+'))
	end
		local tbl = {}
	for _, v in pairs(T) do
		if type(v) == "table" then
			local FT = flatten_values(v)
			for _, V in pairs(FT) do
				tbl[#tbl+1] = cleanup(V)
			end
		else
			if string.find(v, '<') == nil then
				tbl[#tbl+1] = cleanup(v)
			end
		end
	end
	return tbl
end

link_google_books = function(verb, forms, domain)
	function partition_XS_into_N(XS, N)
		local count = 0
		local mensae = {}
		for _, v in pairs(XS) do
			if count % N == 0 then mensae[#mensae+1] = {} end
			count = count + 1
			mensae[#mensae][#(mensae[#mensae])+1] = v end
		return mensae end
	function forms_N_to_link(fs, N, args, site)
		return '[https://www.google.com/search?'..args..'&q='..site..'+%22'.. table.concat(fs, "%22+OR+%22") ..'%22 '..N..']' end
	function make_links_txt(fs, N, site)
		local args = site == "Books" and "tbm=bks&lr=lang_la" or ""
		local links = {}
		for k,v in pairs(partition_XS_into_N(fs, N)) do
			links[#links+1] = forms_N_to_link(v,k,args,site=="Books" and "" or site) end
		return table.concat(links, ' - ') end
	return "Google "..domain.." forms of "..verb.." : "..make_links_txt(forms, 30, domain)
end

return export

-- For Vim, so we get 4-space tabs
-- vim: set ts=4 sw=4 noet:
