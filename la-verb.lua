local m_utilities = require("Module:utilities")
local m_table = require("Module:table")
local m_links = require("Module:links")
local m_la_headword = require("Module:la-headword")
local m_la_utilities = require("Module:la-utilities")

-- TODO:
-- 1. (DONE) detect_decl_and_subtypes doesn't do anything with perf_stem or supine_stem.
-- 2. (DONE) Should error on bad subtypes.
-- 3. Make sure Google Books link still works.
-- 4. (DONE) Add 4++ that has alternative perfects -īvī/-iī.
-- 5. (DONE) If sup but no perf, allow passive perfect forms unless no-pasv-perf.
-- 6. (DONE) Remove no-actv-perf.
-- 7. (DONE) Support plural prefix/suffix and plural passive prefix/suffix
--
-- If enabled, compare this module with new version of module to make
-- sure all conjugations are the same.
local test_new_la_verb_module = false

local export = {}

local lang = require("Module:languages").getByCode("la")
local sc = require("Module:scripts").getByCode("Latn")

local title = mw.title.getCurrentTitle()
local NAMESPACE = title.nsText

-- Conjugations are the functions that do the actual
-- conjugating by creating the forms of a basic verb.
-- They are defined further down.
local conjugations = {}

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
local make_sigm
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

local split = mw.text.split
local find = mw.ustring.find
local len = mw.ustring.len
local match = mw.ustring.match
local sub = mw.ustring.sub
local gsub = mw.ustring.gsub
local toNFD = mw.ustring.toNFD

-- version of gsub() that discards all but the first return value
local function gsub1(term, foo, bar)
	local retval = gsub(term, foo, bar)
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

local function make_link(page, display, face, accel)
	return m_links.full_link({term = page, alt = display, lang = lang, sc = sc, accel = accel}, face)
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
		for _, t in ipairs({"pres", "impf", "futr", "perf", "plup", "futp", "sigf"}) do
			handle_tense(t, "indc")
		end
		for _, t in ipairs({"pres", "impf", "perf", "plup", "siga"}) do
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
	for _, n in ipairs({"ger_gen", "ger_dat", "ger_acc", "ger_abl", "sup_acc", "sup_abl"}) do
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

-- Construct a simple one- or two-part link, which will be put through full_link later.
local function make_raw_link(page, display)
	if page and display then
		return "[[" .. page .. "|" .. display .. "]]"
	elseif page then
		return "[[" .. page .. "]]"
	else
		return display
	end
end

local function split_prefix_and_base(lemma, main_verbs)
	for _, main in ipairs(main_verbs) do
		local prefix = match(lemma, "^(.*)" .. main .. "$")
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
		return match(lemma, ending)
	else
		return match(lemma, "^(.*)" .. ending .. "$")
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
	["aiō"] = "3rd-io",
	["aiiō"] = "3rd-io",
	["ajō"] = "3rd-io",
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
	local specs = split(args[1] or "", "%.")
	local subtypes = {}
	local conj_arg
	for i, spec in ipairs(specs) do
		if i == 1 then
			conj_arg = spec
		else
			local begins_with_hyphen = find(spec, "^%-")
			spec = spec:gsub("%-", "")
			if begins_with_hyphen then
				spec = "-" .. spec
			end
			subtypes[spec] = true
		end
	end

	local orig_lemma = args[2] or mw.title.getCurrentTitle().subpageText
	orig_lemma = gsub1(orig_lemma, "o$", "ō")
	local lemma = m_links.remove_links(orig_lemma)
	local base, conjtype, conj_subtype, detected_subtypes
	local base_conj_arg, auto_perf_supine = match(conj_arg, "^([124])(%+%+?)$")
	if base_conj_arg then
		if auto_perf_supine == "++" and base_conj_arg ~= "4" then
			error("Conjugation types 1++ and 2++ not allowed")
		end
		conj_arg = base_conj_arg
	end
	if sub(orig_lemma, 1, 1) == "-" then
		subtypes.suffix = true
	end
	local auto_perf, auto_supine, auto_sigm
	if subtypes.sigm or subtypes.sigmpasv or subtypes.suffix then
		auto_sigm = true
	end

	if conj_arg == "1" then
		conjtype = "1st"
		base, detected_subtypes = get_subtype_by_ending(lemma, "1", subtypes, {
			{"ō", {}},
			{"or", {"depon"}},
			{"at", {"impers"}},
			{"ātur", {"depon", "impers"}},
			{"ī", {"perfaspres"}},
		})
		if auto_perf_supine then
			if subtypes.perfaspres then
				auto_perf = base
			else
				auto_perf = base .. "āv"
				auto_supine = base .. "āt"
			end
		end
		if auto_sigm then
			auto_sigm = base .. "āss"
		end
		if subtypes.suffix then
			subtypes.p3inf = true
			subtypes.sigmpasv = true
		end
	elseif conj_arg == "2" then
		conjtype = "2nd"
		base, detected_subtypes = get_subtype_by_ending(lemma, "2", subtypes, {
			{"eō", {}},
			{"eor", {"depon"}},
			{"et", {"impers"}},
			{"ētur", {"depon", "impers"}},
			{"ī", {"perfaspres"}},
		})
		if auto_perf_supine then
			if subtypes.perfaspres then
				auto_perf = base
			else
				auto_perf = base .. "u"
				auto_supine = base .. "it"
			end
		end
		if auto_sigm then
			auto_sigm = "-/ēss"
		end
		if subtypes.suffix then
			subtypes.sigmpasv = true
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
				{"ī", {"perfaspres"}},
			})
			if subtypes.I then
				conjtype = "3rd-io"
			else
				conjtype = "3rd"
			end
		end
		if subtypes.perfaspres then
			auto_perf = base
		end
		if subtypes.suffix then
			auto_perf = "-"
			auto_supine = "-"
			auto_sigm = "-"
			subtypes.sigmpasv = true
		end
	elseif conj_arg == "4" then
		conjtype = "4th"
		base, detected_subtypes = get_subtype_by_ending(lemma, "4", subtypes, {
			{"iō", {}},
			{"ior", {"depon"}},
			{"it", {"impers"}},
			{"ītur", {"depon", "impers"}},
			{"ī", {"perfaspres"}},
		})
		if subtypes.perfaspres then
			auto_perf = base
		elseif auto_perf_supine == "++" then
			auto_perf = base .. "īv/" .. base .. "i"
			auto_supine = base .. "īt"
		elseif auto_perf_supine == "+" then
			auto_perf = base .. "īv"
			auto_supine = base .. "īt"
		end
		if auto_sigm then
			auto_sigm = base .. "īss"
		end
		if subtypes.suffix then
			subtypes.sigm = true
		end
	elseif conj_arg == "irreg" then
		conjtype = "irreg"
		local prefix
		prefix, base = split_prefix_and_base(lemma, {
			"aiō",
			"aiiō",
			"ajō",
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
		if subtypes.depon or subtypes.semidepon or subtypes.perfaspres then
			supine_stem = args[3] or auto_supine
			if supine_stem == "-" and not subtypes.suffix then
				supine_stem = nil
			end
			if not supine_stem then
				if subtypes.depon or subtypes.semidepon then
					subtypes.noperf = true
				end
				subtypes.nosup = true
			end
			if subtypes.sigm or subtypes.sigmpasv then
				local sigm_stem = args[5] or auto_sigm
				if sigm_stem == "-" and not subtypes.suffix then
					sigm_stem = nil
				end
				args[5] = sigm_stem
			end
			args[2] = supine_stem
			args[3] = nil
		else
			perf_stem = args[3] or auto_perf
			if perf_stem == "-" and not subtypes.suffix then
				perf_stem = nil
			end
			if not perf_stem then
				subtypes.noperf = true
			end
			supine_stem = args[4] or auto_supine
			if supine_stem == "-" and not subtypes.suffix then
				supine_stem = nil
			end
			if not supine_stem then
				subtypes.nosup = true
			end
			if subtypes.sigm or subtypes.sigmpasv then
				local sigm_stem = args[5] or auto_sigm
				if sigm_stem == "-" and not subtypes.suffix then
					sigm_stem = nil
				end
				args[5] = sigm_stem
			end
			args[2] = perf_stem
			args[3] = supine_stem
		end
		args[4] = nil
	end

	for subtype, _ in pairs(subtypes) do
		if not m_la_headword.allowed_subtypes[subtype] and
			not m_la_headword.allowed_subtypes[sub(subtype, 2)] and
			not (conjtype == "3rd" and subtype == "-I") and
			not (conjtype == "3rd-io" and subtype == "I") and
			not (subtype == "nound" or subtype == "sigm" or subtype == "sigmpasv" or subtype == "suffix") then
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

	if typeinfo.subtypes.suffix then data.categories = {} end

	-- Check if the links to the verb forms exist
	-- Has to happen after other categories are removed for suffixes
	checkexist(data)

	if domain == nil then
		return make_table(data) .. m_utilities.format_categories(data.categories, lang)
	else
		local verb = data['forms']['1s_pres_actv_indc'] ~= nil and ('[['.. gsub(toNFD(data['forms']['1s_pres_actv_indc']),'[^%w]+',"")..'|'..data['forms']['1s_pres_actv_indc'].. ']]') or 'verb'
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
					gsub1(gsub1(gsub1(v, "|", "<!>"), "=", "<->"), ",", "<.>")
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

	local active_prefix = data.prefix or ""
	local passive_prefix = data.passive_prefix or ""
	local plural_prefix = data.plural_prefix or ""
	local plural_passive_prefix = data.plural_passive_prefix or ""
	local active_prefix_no_links = m_links.remove_links(active_prefix)
	local passive_prefix_no_links = m_links.remove_links(passive_prefix)
	local plural_prefix_no_links = m_links.remove_links(plural_prefix)
	local plural_passive_prefix_no_links = m_links.remove_links(plural_passive_prefix)

	local active_suffix = data.suffix or ""
	local passive_suffix = data.passive_suffix or ""
	local plural_suffix = data.plural_suffix or ""
	local plural_passive_suffix = data.plural_passive_suffix or ""
	local active_suffix_no_links = m_links.remove_links(active_suffix)
	local passive_suffix_no_links = m_links.remove_links(passive_suffix)
	local plural_suffix_no_links = m_links.remove_links(plural_suffix)
	local plural_passive_suffix_no_links = m_links.remove_links(plural_passive_suffix)

	for slot in iter_slots(false, true) do
		if not slot:find("ger_") then
			local prefix, suffix, prefix_no_links, suffix_no_links
			if slot:find("pasv") and slot:find("[123]p") then
				prefix = plural_passive_prefix
				suffix = plural_passive_suffix
				prefix_no_links = plural_passive_prefix_no_links
				suffix_no_links = plural_passive_suffix_no_links
			elseif slot:find("pasv") and not slot:find("_inf") then
				prefix = passive_prefix
				suffix = passive_suffix
				prefix_no_links = passive_prefix_no_links
				suffix_no_links = passive_suffix_no_links
			elseif slot:find("[123]p") then
				prefix = plural_prefix
				suffix = plural_suffix
				prefix_no_links = plural_prefix_no_links
				suffix_no_links = plural_suffix_no_links
			else
				prefix = active_prefix
				suffix = active_suffix
				prefix_no_links = active_prefix_no_links
				suffix_no_links = active_suffix_no_links
			end
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
						table.insert(affixed_forms, prefix .. form .. suffix)
					elseif form:find("[%[%]]") then
						-- If not dealing with a linked slot, but there are links in the slot,
						-- include the original, potentially linked versions of the prefix and
						-- suffix (e.g. in perfect passive forms).
						table.insert(affixed_forms, prefix .. form .. suffix)
					else
						-- Otherwise, use the non-linking versions of the prefix and suffix
						-- so that the whole term (including prefix/suffix) gets linked.
						table.insert(affixed_forms, prefix_no_links .. form .. suffix_no_links)
					end
				end
				data.forms[slot] = affixed_forms
			end
		end
	end
end

local function notes_override(data, args)
	local notes = {args["note1"], args["note2"], args["note3"]}

	for n, note in pairs(notes) do
		if note == "-" then
			data.footnotes[n] = nil
		elseif note == "p3inf" then
			data.footnotes[n] = "The present passive infinitive in ''-ier'' is a rare poetic form which is attested."
		elseif note == "poetsyncperf" then
			data.footnotes[n] = "At least one rare poetic syncopated perfect form is attested."
		elseif note == "sigm" then
			data.footnotes[n] = "At least one use of the archaic \"sigmatic future\" and \"sigmatic aorist\" tenses is attested, which are used by [[Old Latin]] writers; most notably [[w:Plautus|Plautus]] and [[w:Terence|Terence]]. The sigmatic future is generally ascribed a future or future perfect meaning, while the sigmatic aorist expresses a possible desire (\"might want to\")."
		elseif note == "sigmpasv" then
			data.footnotes[n] = "At least one use of the archaic \"sigmatic future\" and \"sigmatic aorist\" tenses is attested, which are used by [[Old Latin]] writers; most notably [[w:Plautus|Plautus]] and [[w:Terence|Terence]]. The sigmatic future is generally ascribed a future or future perfect meaning, while the sigmatic aorist expresses a possible desire (\"might want to\"). It is also attested as having a rare sigmatic future passive indicative form (\"will have been\"), which is not attested in the plural for any verb."
		elseif note == "sigmdepon" then
			data.footnotes[n] = "At least one use of the archaic \"sigmatic future\" tense is attested, which is used by [[Old Latin]] writers; most notably [[w:Plautus|Plautus]] and [[w:Terence|Terence]]. The sigmatic future is generally ascribed a future or future perfect meaning, and, as the verb is deponent, takes the form of what would otherwise be the rare sigmatic future passive indicative tense (which is not attested in the plural for any verb)."
		elseif note then
			data.footnotes[n] = note
		end
	end

	if args["notes"] == "-" then
		data.footnotes = {}
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

function export.make_data(parent_args, from_headword, def1, def2)
	local params = {
		[1] = {required = true, default = def1 or "1+"},
		[2] = {required = true, default = def2 or "amō"},
		[3] = {},
		[4] = {},
		[5] = {},
		prefix = {},
		passive_prefix = {},
		plural_prefix = {},
		plural_passive_prefix = {},
		gen_prefix = {},
		dat_prefix = {},
		acc_prefix = {},
		abl_prefix = {},
		suffix = {},
		passive_suffix = {},
		plural_suffix = {},
		plural_passive_suffix = {},
		gen_suffix = {},
		dat_suffix = {},
		acc_suffix = {},
		abl_suffix = {},
		label = {},
		note1= {},
		note2= {},
		note3= {},
		notes= {},
		-- examined directly in export.show()
		search = {}
	}
	for slot in iter_slots(true, false) do
		params[slot] = {}
	end

	if from_headword then
		params.lemma = {list = true}
		params.id = {}
		params.cat = {list = true}
	end

	local args = require("Module:parameters").process(parent_args, params, nil, "la-verb", "make_data")
	local conj_type, conj_subtype, subtypes, orig_lemma, lemma =
		detect_decl_and_subtypes(args)

	if not conjugations[conj_type] then
		error("Unknown conjugation type '" .. conj_type .. "'")
	end

	local data = {
		forms = {},
		title = {},
		categories = args.cat and m_table.deepcopy(args.cat) or {},
		form_footnote_indices = {},
		footnotes = {},
		id = args.id,
		overriding_lemma = args.lemma,
	}  --note: the addition of red superscripted footnotes ('<sup class="roa-red-superscript">' ... </sup>) is only implemented for the three form printing loops in which it is used
	local typeinfo = {
		lemma = lemma,
		orig_lemma = orig_lemma,
		conj_type = conj_type,
		conj_subtype = conj_subtype,
		subtypes = subtypes,
	}

	if args.passive_prefix and not args.prefix then
		error("Can't specify passive_prefix= without prefix=")
	end
	if args.plural_prefix and not args.prefix then
		error("Can't specify plural_prefix= without prefix=")
	end
	if args.plural_passive_prefix and not args.prefix then
		error("Can't specify plural_passive_prefix= without prefix=")
	end

	if args.passive_suffix and not args.suffix then
		error("Can't specify passive_suffix= without suffix=")
	end
	if args.plural_suffix and not args.suffix then
		error("Can't specify plural_suffix= without suffix=")
	end
	if args.plural_passive_suffix and not args.suffix then
		error("Can't specify plural_passive_suffix= without suffix=")
	end

	local function normalize_prefix(prefix)
		if not prefix then
			return nil
		end
		local no_space_prefix = match(prefix, "(.*)_$")
		if no_space_prefix then
			return no_space_prefix
		elseif find(prefix, "%-$") then
			return prefix
		else
			return prefix .. " "
		end
	end

	local function normalize_suffix(suffix)
		if not suffix then
			return nil
		end
		local no_space_suffix = match(suffix, "^_(.*)$")
		if no_space_suffix then
			return no_space_suffix
		elseif find(suffix, "^%-") then
			return suffix
		else
			return " " .. suffix
		end
	end

	data.prefix = normalize_prefix(args.prefix)
	data.passive_prefix = normalize_prefix(args.passive_prefix) or data.prefix
	data.plural_prefix = normalize_prefix(args.plural_prefix) or data.prefix
	-- First fall back to the passive prefix (e.g. poenās dare, where the
	-- plural noun is used with both singular and plural verbs, but there's a
	-- separate passive form ''poenae datur''), then to the plural prefix,
	-- then to the base prefix.
	data.plural_passive_prefix = normalize_prefix(args.plural_passive_prefix) or
		normalize_prefix(args.passive_prefix) or data.plural_prefix
	data.gen_prefix = normalize_prefix(args.gen_prefix)
	data.dat_prefix = normalize_prefix(args.dat_prefix)
	data.acc_prefix = normalize_prefix(args.acc_prefix)
	data.abl_prefix = normalize_prefix(args.abl_prefix)

	data.suffix = normalize_suffix(args.suffix)
	data.passive_suffix = normalize_suffix(args.passive_suffix) or data.suffix
	data.plural_suffix = normalize_suffix(args.plural_suffix) or data.suffix
	-- Same as above for prefixes.
	data.plural_passive_suffix = normalize_suffix(args.plural_passive_suffix) or
		normalize_suffix(args.passive_suffix) or data.plural_suffix
	data.gen_suffix = normalize_suffix(args.gen_suffix)
	data.dat_suffix = normalize_suffix(args.dat_suffix)
	data.acc_suffix = normalize_suffix(args.acc_suffix)
	data.abl_suffix = normalize_suffix(args.abl_suffix)

	-- Generate the verb forms
	conjugations[conj_type](args, data, typeinfo)

	-- Post-process the forms
	postprocess(data, typeinfo)

	-- Override with user-set forms
	override(data, args)

	-- Set linked_* forms
	set_linked_forms(data, typeinfo)

	-- Prepend any prefixes, append any suffixes
	add_prefix_suffix(data)

	if args["label"] then
		m_table.insertIfNot(data.title, args["label"])
	end

	notes_override(data, args)

	-- Check if the verb is irregular
	if not conj_type == 'irreg' then checkirregular(args, data) end
	return data, typeinfo
end

local function form_contains(forms, form)
	if type(forms) == "string" then
		return forms == form
	else
		return m_table.contains(forms, form)
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
		m_table.insertIfNot(data.forms[key], stem .. s, pos)
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
		table.insert(ppplinks, make_link(pppform, nil, "term"))
	end
	local ppplink = table.concat(ppplinks, " or ")
	local sumlink = make_link("sum", nil, "term")

	text_for_slot = {
		perf_pasv_indc = "present active indicative",
		futp_pasv_indc = "future active indicative",
		plup_pasv_indc = "imperfect active indicative",
		perf_pasv_subj = "present active subjunctive",
		plup_pasv_subj = "imperfect active subjunctive"
	}
	local prefix_joiner = data.passive_prefix and data.passive_prefix:find(" $") and "+ " or ""
	local suffix_joiner = data.passive_suffix and data.passive_suffix:find("^ ") and " +" or ""
	for slot, text in pairs(text_for_slot) do
		data.forms[slot] =
			(data.passive_prefix or "") .. prefix_joiner .. ppplink .. " + " ..
			text .. " of " .. sumlink .. suffix_joiner .. (data.passive_suffix or "")
	end
	ppp = data.forms["1s_pres_actv_indc"]
	if type(ppp) ~= "table" then
		ppp = {ppp}
	end
	if ppp[1] == "faciō" then
		ppp = {"factum"}
		ppplinks = {}
		for _, pppform in ipairs(ppp) do
			table.insert(ppplinks, make_link(pppform, nil, "term"))
		end
		ppplink = table.concat(ppplinks, " or ")
		sumlink = make_link("sum", nil, "term")
		for slot, text in pairs(text_for_slot) do
			data.forms[slot] =
				data.forms[slot] .. " or " .. ppplink .. " + " .. text .. " of " .. sumlink
		end
	end
end

-- Make the gerund and gerundive/future passive participle. For the forms
-- labeled "gerund", we generate both gerund and gerundive variants if there's
-- a case-specific prefix or suffix for the case in question; otherwise we
-- generate only the gerund per se. BASE is the stem (ending in -nd).
-- UND_VARIANT, if true, means that a gerundive in -und should be generated
-- along with a gerundive in -end. NO_GERUND means to skip generating any
-- gerunds (and gerundive variants). NO_FUTR_PASV_PTC means to skip generating
-- the future passive participle.
local function make_gerund(data, typeinfo, base, und_variant, no_gerund, no_futr_pasv_ptc)
	local neut_endings = {
		nom = "um",
		gen = "ī",
		dat = "ō",
		acc = "um",
		abl = "ō",
	}

	local endings
	if typeinfo.subtypes.f then
		endings = {
			nom = "a",
			gen = "ae",
			dat = "ae",
			acc = "am",
			abl = "ā",
		}
	elseif typeinfo.subtypes.n then
		endings = neut_endings
	elseif typeinfo.subtypes.mp then
		endings = {
			nom = "ī",
			gen = "ōrum",
			dat = "īs",
			acc = "ōs",
			abl = "īs",
		}
	elseif typeinfo.subtypes.fp then
		endings = {
			nom = "ae",
			gen = "ārum",
			dat = "īs",
			acc = "ās",
			abl = "īs",
		}
	elseif typeinfo.subtypes.np then
		endings = {
			nom = "a",
			gen = "ōrum",
			dat = "īs",
			acc = "a",
			abl = "īs",
		}
	else
		endings = {
			nom = "us",
			gen = "ī",
			dat = "ō",
			acc = "um",
			abl = "ō",
		}
	end

	if find(base, "[uv]end$") or typeinfo.subtypes.nound then
		-- Per Lane's grammar section 899: "Verbs in -ere and -īre often have
		-- -undus, when not preceded by u or v, especially in formal style"
		-- There is also an optional exclusion if -undus is not attested
		und_variant = false
	end
	local und_base = und_variant and base:gsub("end$", "und")
	for case, ending in pairs(endings) do
		if case == "nom" then
			if not no_futr_pasv_ptc then
				if typeinfo.subtypes.passimpers then
					ending = "um"
				end
				add_form(data, "futr_pasv_ptc", "", base .. ending)
				if und_base then
					add_form(data, "futr_pasv_ptc", "", und_base .. ending)
				end
			end
		elseif (data[case .. "_prefix"] or data[case .. "_suffix"]) and not no_gerund then
			add_form(data, "ger_" .. case, "", (data[case .. "_prefix"] or "")
				.. base .. ending .. (data[case .. "_suffix"] or ""))
			if und_base then
				add_form(data, "ger_" .. case, "", (data[case .. "_prefix"] or "")
					.. und_base .. ending .. (data[case .. "_suffix"] or ""))
			end
		end
	end
	if not no_gerund then
		for case, ending in pairs(neut_endings) do
			add_form(data, "ger_" .. case, "",
				(data.prefix or  "") ..	base .. ending .. (data.suffix or  ""))
		end
	end
end

postprocess = function(data, typeinfo)
	-- Maybe clear out the supine-derived forms (except maybe for the
	-- future active participle). Do this first because some code below
	-- looks at the perfect participle to derive other forms.
	if typeinfo.subtypes.nosup then
		-- Some verbs have no supine forms or forms derived from the supine
		if typeinfo.subtypes.perfaspres == nil then
			m_table.insertIfNot(data.title, "no [[supine]] stem")
		end
		m_table.insertIfNot(data.categories, "Latin verbs with missing supine stem")
		m_table.insertIfNot(data.categories, "Latin defective verbs")

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
		if typeinfo.subtypes.perfaspres == nil then
			m_table.insertIfNot(data.title, "no [[supine]] stem except in the [[future]] [[active]] [[participle]]")
		end
		m_table.insertIfNot(data.categories, "Latin verbs with missing supine stem except in the future active participle")
		m_table.insertIfNot(data.categories, "Latin defective verbs")

		for key, _ in pairs(data.forms) do
			if cfind(key, "sup") or (
				key == "perf_actv_ptc" or key == "perf_pasv_ptc" or key == "perf_pasv_inf" or
				key == "futr_pasv_inf"
			) then
				data.forms[key] = nil
			end
		end
	end

	-- Add information for the passive perfective forms
	if data.forms["perf_pasv_ptc"] and not form_is_empty(data.forms["perf_pasv_ptc"]) then
		if typeinfo.subtypes.passimpers then
			-- this should always be a table because it's generated only in
			-- make_supine()
			local pppforms = data.forms["perf_pasv_ptc"]
			for _, ppp in ipairs(pppforms) do
				if not form_is_empty(ppp) then
					-- make_supine() already generated the neuter form of the PPP.
					local nns_ppp = make_raw_link(ppp)
					add_form(data, "3s_perf_pasv_indc", nns_ppp, " [[est]]")
					add_form(data, "3s_futp_pasv_indc", nns_ppp, " [[erit]]")
					add_form(data, "3s_plup_pasv_indc", nns_ppp, " [[erat]]")
					add_form(data, "3s_perf_pasv_subj", nns_ppp, " [[sit]]")
					add_form(data, "3s_plup_pasv_subj", nns_ppp, {" [[esset]]", " [[foret]]"})
				end
			end
		elseif typeinfo.subtypes.pass3only then
			local pppforms = data.forms["perf_pasv_ptc"]
			if type(pppforms) ~= "table" then
				pppforms = {pppforms}
			end
			for _, ppp in ipairs(pppforms) do
				if not form_is_empty(ppp) then
					local ppp_s, ppp_p
					if typeinfo.subtypes.mp then
						ppp_p = make_raw_link(gsub1(ppp, "ī$", "us"), ppp)
					elseif typeinfo.subtypes.fp then
						ppp_p = make_raw_link(gsub1(ppp, "ae$", "us"), ppp)
					elseif typeinfo.subtypes.np then
						ppp_p = make_raw_link(gsub1(ppp, "a$", "us"), ppp)
					elseif typeinfo.subtypes.f then
						local ppp_lemma = gsub1(ppp, "a$", "us")
						ppp_s = make_raw_link(ppp_lemma, ppp)
						ppp_p = make_raw_link(ppp_lemma, gsub1(ppp, "a$", "ae"))
					elseif typeinfo.subtypes.n then
						local ppp_lemma = gsub1(ppp, "um$", "us")
						ppp_s = make_raw_link(ppp_lemma, ppp)
						ppp_p = make_raw_link(ppp_lemma, gsub1(ppp, "um$", "a"))
					else
						ppp_s = make_raw_link(ppp)
						ppp_p = make_raw_link(ppp, gsub1(ppp, "us$", "ī"))
					end
					if not typeinfo.subtypes.mp and not typeinfo.subtypes.fp and not typeinfo.subtypes.np then
						add_form(data, "3s_perf_pasv_indc", ppp_s, " [[est]]")
						add_form(data, "3s_futp_pasv_indc", ppp_s, " [[erit]]")
						add_form(data, "3s_plup_pasv_indc", ppp_s, " [[erat]]")
						add_form(data, "3s_perf_pasv_subj", ppp_s, " [[sit]]")
						add_form(data, "3s_plup_pasv_subj", ppp_s, {" [[esset]]", " [[foret]]"})
					end
					add_form(data, "3p_perf_pasv_indc", ppp_p, " [[sunt]]")
					add_form(data, "3p_futp_pasv_indc", ppp_p, " [[erunt]]")
					add_form(data, "3p_plup_pasv_indc", ppp_p, " [[erant]]")
					add_form(data, "3p_perf_pasv_subj", ppp_p, " [[sint]]")
					add_form(data, "3p_plup_pasv_subj", ppp_p, {" [[essent]]", " [[forent]]"})
				end
			end
		else
			make_perfect_passive(data)
		end
	end

	if typeinfo.subtypes.perfaspres then
		-- Perfect forms as present tense
		m_table.insertIfNot(data.title, "no [[present tense|present]] stem")
		if typeinfo.subtypes.nosup then
			m_table.insertIfNot(data.title, "no [[supine]] stem")
		elseif typeinfo.subtypes.supfutractvonly then
			m_table.insertIfNot(data.title, "no [[supine]] stem except in the [[future]] [[active]] [[participle]]")
		end
		m_table.insertIfNot(data.title, "active only")
		m_table.insertIfNot(data.title, "[[perfect]] forms as present")
		m_table.insertIfNot(data.title, "pluperfect as imperfect")
		m_table.insertIfNot(data.title, "future perfect as future")
		m_table.insertIfNot(data.categories, "Latin defective verbs")
		m_table.insertIfNot(data.categories, "Latin active-only verbs")
		m_table.insertIfNot(data.categories, "Latin verbs with missing present stem")
        m_table.insertIfNot(data.categories, "Latin verbs with perfect forms having imperfective meanings")

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
	end

	-- Types of irregularity related primarily to the active.
	-- These could in theory be combined with those related to the passive and imperative,
	-- i.e. there's no reason there couldn't be an impersonal deponent verb with no imperatives.
	if typeinfo.subtypes.impers then
		-- Impersonal verbs have only third-person singular forms.
		m_table.insertIfNot(data.title, "[[impersonal]]")
		m_table.insertIfNot(data.categories, "Latin impersonal verbs")

		-- Remove all non-3sg forms
		for key, _ in pairs(data.forms) do
			if key:find("^[12][sp]") or key:find("^3p") then
				data.forms[key] = nil
			end
		end
	elseif typeinfo.subtypes["3only"] then
		m_table.insertIfNot(data.title, "[[third person]] only")
		m_table.insertIfNot(data.categories, "Latin third-person-only verbs")

		-- Remove all non-3sg forms
		for key, _ in pairs(data.forms) do
			if key:find("^[12][sp]") then
				data.forms[key] = nil
			end
		end
	end

	if typeinfo.subtypes.nopasvperf and not typeinfo.subtypes.nosup and
			not typeinfo.subtypes.supfutractvonly then
		-- Some verbs have no passive perfect forms (e.g. ārēscō, -ěre).
		-- Only do anything here if the verb has a supine; otherwise it
		-- necessarily has no passive perfect forms.
		m_table.insertIfNot(data.title, "no passive perfect forms")
		m_table.insertIfNot(data.categories, "Latin defective verbs")

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
		m_table.insertIfNot(data.title, "optionally [[semi-deponent]]")
		m_table.insertIfNot(data.categories, "Latin semi-deponent verbs")
		m_table.insertIfNot(data.categories, "Latin optionally semi-deponent verbs")

		-- Remove imperfective passive forms
		for key, _ in pairs(data.forms) do
			if cfind(key, "pres_pasv") or cfind(key, "impf_pasv") or cfind(key, "futr_pasv") then
				data.forms[key] = nil
			end
		end
	elseif typeinfo.subtypes.semidepon then
		-- Semi-deponent verbs use perfective passive forms with active meaning,
		-- and have no imperfective passive
		m_table.insertIfNot(data.title, "[[semi-deponent]]")
		m_table.insertIfNot(data.categories, "Latin semi-deponent verbs")

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
		m_table.insertIfNot(data.title, "[[deponent]]")
		m_table.insertIfNot(data.categories, "Latin deponent verbs")

		-- Remove active forms and future passive infinitive
		for key, _ in pairs(data.forms) do
			if cfind(key, "actv") and key ~= "pres_actv_ptc" and key ~= "futr_actv_ptc" and key ~= "futr_actv_inf" and cfind(key, "sigf") == nil or key == "futr_pasv_inf" then
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
	end

	if typeinfo.subtypes.noperf then
		-- Some verbs have no perfect stem (e.g. inalbēscō, -ěre)
		m_table.insertIfNot(data.title, "no [[perfect tense|perfect]] stem")
		m_table.insertIfNot(data.categories, "Latin defective verbs")
        if not typeinfo.subtypes.depon then
			m_table.insertIfNot(data.categories, "Latin verbs with missing perfect stem")
			end
		-- Remove all active perfect forms (passive perfect forms may
		-- still exist as they are formed with the supine stem)
		for key, _ in pairs(data.forms) do
			if cfind(key, "actv") and (cfind(key, "perf") or cfind(key, "plup") or cfind(key, "futp")) then
				data.forms[key] = nil
			end
		end
	end

	if typeinfo.subtypes.nopass then
		-- Remove all passive forms
		m_table.insertIfNot(data.title, "active only")
		m_table.insertIfNot(data.categories, "Latin active-only verbs")

		-- Remove all non-3sg and passive forms
		for key, _ in pairs(data.forms) do
			if cfind(key, "pasv") then
				data.forms[key] = nil
			end
		end
	elseif typeinfo.subtypes.pass3only then
		-- Some verbs have only third-person forms in the passive
		m_table.insertIfNot(data.title, "only third-person forms in passive")
		m_table.insertIfNot(data.categories, "Latin verbs with third-person passive")

		-- Remove all non-3rd-person passive forms and all passive imperatives
		for key, _ in pairs(data.forms) do
			if cfind(key, "pasv") and (key:find("^[12][sp]") or cfind(key, "impr")) then
				data.forms[key] = nil
			end
			-- For phrasal verbs with a plural complement, also need to erase the
			-- 3s forms.
			if typeinfo.subtypes.mp or typeinfo.subtypes.fp or typeinfo.subtypes.np then
				if cfind(key, "pasv") and key:find("^3s") then
					data.forms[key] = nil
				end
			end
		end
	elseif typeinfo.subtypes.passimpers then
		-- Some verbs are impersonal in the passive
		m_table.insertIfNot(data.title, "[[impersonal]] in passive")
		m_table.insertIfNot(data.categories, "Latin verbs with impersonal passive")

		-- Remove all non-3sg passive forms
		for key, _ in pairs(data.forms) do
			if cfind(key, "pasv") and (key:find("^[12][sp]") or key:find("^3p") or cfind(key, "impr")) or cfind(key, "futr_pasv_inf") then
				data.forms[key] = nil
			end
		end
	end

	-- Handle certain irregularities in the imperative
	if typeinfo.subtypes.noimp then
		-- Some verbs have no imperatives
		m_table.insertIfNot(data.title, "no [[imperative]]s")
		m_table.insertIfNot(data.categories, "Latin verbs with missing imperative")
		m_table.insertIfNot(data.categories, "Latin defective verbs")

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
		m_table.insertIfNot(data.title, "no [[future]]")
		m_table.insertIfNot(data.categories, "Latin verbs with missing future")
		m_table.insertIfNot(data.categories, "Latin defective verbs")

		-- Remove all future forms
		for key, _ in pairs(data.forms) do
			if cfind(key, "fut") then -- handles futr = future and futp = future perfect
				data.forms[key] = nil
			end
		end
	end

	-- Add the ancient future_passive_participle of certain verbs
	-- if typeinfo.pres_stem == "lāb" then
	-- 	data.forms["futr_pasv_ptc"] = "lābundus"
	-- elseif typeinfo.pres_stem == "collāb" then
	-- 	data.forms["futr_pasv_ptc"] = "collābundus"
	-- elseif typeinfo.pres_stem == "illāb" then
	-- 	data.forms["futr_pasv_ptc"] = "illābundus"
	-- elseif typeinfo.pres_stem == "relāb" then
	-- 	data.forms["futr_pasv_ptc"] = "relābundus"
	-- end

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
				table.insert(newvals, sub(fv, 1, -2) .. "ier")
			end
			data.forms[form] = newvals
			data.form_footnote_indices[form] = tostring(noteindex)
			data.footnotes[noteindex] = "The present passive infinitive in ''-ier'' is a rare poetic form which is attested."
	end

	--Add the syncopated perfect forms, omitting the separately handled fourth conjugation cases

	if typeinfo.subtypes.poetsyncperf then
		local sss = {
			--infinitive
			{'perf_actv_inf', 'sse'},
			--perfect actives
		    {'2s_perf_actv_indc', 'stī'},
		    {'3s_perf_actv_indc', 't'},
		    {'1p_perf_actv_indc', 'mus'},
			{'2p_perf_actv_indc', 'stis'},
			{'3p_perf_actv_indc', 'runt'},
			--pluperfect actives
		    {'1s_plup_actv_indc', 'ram'},
		    {'2s_plup_actv_indc', 'rās'},
		    {'3s_plup_actv_indc', 'rat'},
		    {'1p_plup_actv_indc', 'rāmus'},
			{'2p_plup_actv_indc', 'rātis'},
			{'3p_plup_actv_indc', 'rant'},
			--future perfect actives
		    {'1s_futp_actv_indc', 'rō'},
		    {'2s_futp_actv_indc', 'ris'},
		    {'3s_futp_actv_indc', 'rit'},
		    {'1p_futp_actv_indc', 'rimus'},
			{'2p_futp_actv_indc', 'ritis'},
			{'3p_futp_actv_indc', 'rint'},
			--perfect subjunctives
		    {'1s_perf_actv_subj', 'rim'},
			{'2s_perf_actv_subj', 'rīs'},
			{'3s_perf_actv_subj', 'rit'},
			{'1p_perf_actv_subj', 'rīmus'},
			{'2p_perf_actv_subj', 'rītis'},
			{'3p_perf_actv_subj', 'rint'},
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
				-- Can only syncopate 'vi', 've', 'vē', or any one of them spelled with a 'u' after a vowel
				if fv:find('v[ieē]' .. suff_sync .. '$') or fv:find('vē' .. suff_sync .. '$') or find(fv, '[aeiouyāēīōūȳăĕĭŏŭ]u[ieē]' .. suff_sync.. '$') or find(fv, '[aeiouyāēīōūȳăĕĭŏŭ]uē' .. suff_sync.. '$') then
					m_table.insertIfNot(newvals, sub(fv, 1, -len(suff_sync) - 3) .. suff_sync)
				end
			end
			data.forms[form] = newvals
			data.form_footnote_indices[form] = noteindex
		end
		for _, v in ipairs(sss) do
			add_sync_perf(v[1], v[2])
		end
		data.footnotes[noteindex] = "At least one rare poetic syncopated perfect form is attested." end

	-- Add category for sigmatic forms
	if typeinfo.subtypes.sigm or typeinfo.subtypes.sigmpasv then
		m_table.insertIfNot(data.categories, "Latin verbs with sigmatic forms")
	end
	-- Add subcategory for passive sigmatic forms
	if typeinfo.subtypes.sigmpasv or (typeinfo.subtypes.sigm and typeinfo.subtypes.depon) then
		m_table.insertIfNot(data.categories, "Latin verbs with passive sigmatic forms")
	end

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
	elseif typeinfo.subtypes.perfaspres then
		typeinfo.perf_stem = ine(args[1])
		typeinfo.supine_stem = ine(args[2])
	else
		typeinfo.pres_stem = ine(args[1])
		typeinfo.perf_stem = ine(args[2])
		typeinfo.supine_stem = ine(args[3])
	end
	if typeinfo.subtypes.sigm or typeinfo.subtypes.sigmpasv then
		typeinfo.sigm_stem = ine(args[5])
	end

	-- Prepare stems
	if not typeinfo.pres_stem then
		if NAMESPACE == "Template" or typeinfo.subtypes.perfaspres then
			typeinfo.pres_stem = "-"
		else
			error("Present stem has not been provided")
		end
	end

	if typeinfo.perf_stem then
		typeinfo.perf_stem = split(typeinfo.perf_stem, "/")
	else
		typeinfo.perf_stem = {}
	end

	if typeinfo.supine_stem then
		typeinfo.supine_stem = split(typeinfo.supine_stem, "/")
	else
		typeinfo.supine_stem = {}
	end

		if typeinfo.sigm_stem then
		typeinfo.sigm_stem = split(typeinfo.sigm_stem, "/")
	else
		typeinfo.sigm_stem = {}
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

    if typeinfo.subtypes.depon then
		m_table.insertIfNot(data.categories, "Latin first conjugation deponent verbs")
    elseif typeinfo.subtypes.noperf then
		m_table.insertIfNot(data.categories, "Latin first conjugation verbs with missing perfect stem")
    end

    if typeinfo.subtypes.nosup then
		m_table.insertIfNot(data.categories, "Latin first conjugation verbs with missing supine stem")
    elseif typeinfo.subtypes.supfutractvonly then
		m_table.insertIfNot(data.categories, "Latin first conjugation verbs with missing supine stem except in the future active participle‎ ")
    end

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

	make_pres_1st(data, typeinfo, typeinfo.pres_stem)
	make_perf_and_supine(data, typeinfo)
	make_sigm(data, typeinfo, typeinfo.sigm_stem)

	--Additional forms in specific cases
	if typeinfo.pres_stem == "dīlapid" then
		add_form(data, "3p_sigf_actv_indc", "", "dīlapidāssunt", 2 )
	elseif typeinfo.pres_stem == "invol" then
		add_form(data, "3s_sigf_actv_indc", "", "involāsit", 2 )
	elseif typeinfo.pres_stem == "viol" then
		local noteindex = #(data.footnotes) + 1
		add_form(data, "3p_futp_actv_indc", "", "violārint", 2 )
		add_form(data, "3p_perf_actv_subj", "", "violārint", 2 )
		add_form(data, "3s_sigf_actv_indc", "", "violāsit", 2 )
		data.form_footnote_indices["3p_futp_actv_indc"] = tostring(noteindex)
		data.form_footnote_indices["3p_perf_actv_subj"] = tostring(noteindex)
		data.footnotes[noteindex] = 'Archaic.'
	end
end

conjugations["2nd"] = function(args, data, typeinfo)
	get_regular_stems(args, typeinfo)

	table.insert(data.title, "[[Appendix:Latin second conjugation|second conjugation]]")
	table.insert(data.categories, "Latin second conjugation verbs")

    if typeinfo.subtypes.depon then
		m_table.insertIfNot(data.categories, "Latin second conjugation deponent verbs")
    elseif typeinfo.subtypes.noperf then
		m_table.insertIfNot(data.categories, "Latin second conjugation verbs with missing perfect stem")
    end

    if typeinfo.subtypes.nosup then
		m_table.insertIfNot(data.categories, "Latin second conjugation verbs with missing supine stem")
    elseif typeinfo.subtypes.supfutractvonly then
		m_table.insertIfNot(data.categories, "Latin second conjugation verbs with missing supine stem except in the future active participle‎ ")
    end

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

	make_pres_2nd(data, typeinfo, typeinfo.pres_stem)
	make_perf_and_supine(data, typeinfo)
	make_sigm(data, typeinfo, typeinfo.sigm_stem)

	--Additional forms in specific cases
	if typeinfo.pres_stem == "noc" then
		add_form(data, "3s_siga_actv_subj", "", "noxsīt", 2 )
	end
end

local function set_3rd_conj_categories(data, typeinfo)
	table.insert(data.categories, "Latin third conjugation verbs")

    if typeinfo.subtypes.depon then
		m_table.insertIfNot(data.categories, "Latin third conjugation deponent verbs")
    elseif typeinfo.subtypes.noperf then
		m_table.insertIfNot(data.categories, "Latin third conjugation verbs with missing perfect stem")
    end

    if typeinfo.subtypes.nosup then
		m_table.insertIfNot(data.categories, "Latin third conjugation verbs with missing supine stem")
    elseif typeinfo.subtypes.supfutractvonly then
		m_table.insertIfNot(data.categories, "Latin third conjugation verbs with missing supine stem except in the future active participle‎ ")
    end

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

	if typeinfo.pres_stem and match(typeinfo.pres_stem,"[āēīōū]sc$") then
		table.insert(data.categories, "Latin inchoative verbs")
	end

	make_pres_3rd(data, typeinfo, typeinfo.pres_stem)
	make_perf_and_supine(data, typeinfo)
	make_sigm(data, typeinfo, typeinfo.sigm_stem)

	--Additional forms in specific cases
	--FIXME: needs to be cleared up
	if match(typeinfo.pres_stem, "nōsc") then
		local noteindex = #(data.footnotes) + 1
		add_form(data, "2s_perf_actv_indc", "", sub(typeinfo.perf_stem[1],1,-2) .. "stī", 2 )
		add_form(data, "1p_perf_actv_indc", "", sub(typeinfo.perf_stem[1],1,-2) .. "mus", 2 )
		add_form(data, "2p_perf_actv_indc", "", sub(typeinfo.perf_stem[1],1,-2) .. "stis", 2 )
		add_form(data, "3p_perf_actv_indc", "", sub(typeinfo.perf_stem[1],1,-2) .. "runt", 3 )
		add_form(data, "1s_plup_actv_indc", "", sub(typeinfo.perf_stem[1],1,-2) .. "ram", 2 )
		add_form(data, "2s_plup_actv_indc", "", sub(typeinfo.perf_stem[1],1,-2) .. "rās", 2 )
		add_form(data, "3s_plup_actv_indc", "", sub(typeinfo.perf_stem[1],1,-2) .. "rat", 2 )
		add_form(data, "1p_plup_actv_indc", "", sub(typeinfo.perf_stem[1],1,-2) .. "rāmus", 2 )
		add_form(data, "2p_plup_actv_indc", "", sub(typeinfo.perf_stem[1],1,-2) .. "rātis", 2 )
		add_form(data, "3p_plup_actv_indc", "", sub(typeinfo.perf_stem[1],1,-2) .. "rant", 2 )
		add_form(data, "1s_futp_actv_indc", "", sub(typeinfo.perf_stem[1],1,-2) .. "rō", 2 )
		add_form(data, "2s_futp_actv_indc", "", sub(typeinfo.perf_stem[1],1,-2) .. "ris", 2 )
		add_form(data, "3s_futp_actv_indc", "", sub(typeinfo.perf_stem[1],1,-2) .. "rit", 2 )
		add_form(data, "1p_futp_actv_indc", "", sub(typeinfo.perf_stem[1],1,-2) .. "rimus", 2 )
		add_form(data, "2p_futp_actv_indc", "", sub(typeinfo.perf_stem[1],1,-2) .. "ritis", 2 )
		add_form(data, "3p_futp_actv_indc", "", sub(typeinfo.perf_stem[1],1,-2) .. "rint", 2 )
		add_form(data, "1s_perf_actv_subj", "", sub(typeinfo.perf_stem[1],1,-2) .. "rim", 2 )
		add_form(data, "2s_perf_actv_subj", "", sub(typeinfo.perf_stem[1],1,-2) .. "rīs", 2 )
		add_form(data, "3s_perf_actv_subj", "", sub(typeinfo.perf_stem[1],1,-2) .. "rit", 2 )
		add_form(data, "1p_perf_actv_subj", "", sub(typeinfo.perf_stem[1],1,-2) .. "rīmus", 2 )
		add_form(data, "2p_perf_actv_subj", "", sub(typeinfo.perf_stem[1],1,-2) .. "rītis", 2 )
		add_form(data, "3p_perf_actv_subj", "", sub(typeinfo.perf_stem[1],1,-2) .. "rint", 2 )
		add_form(data, "1s_plup_actv_subj", "", sub(typeinfo.perf_stem[1],1,-2) .. "ssem", 2 )
		add_form(data, "2s_plup_actv_subj", "", sub(typeinfo.perf_stem[1],1,-2) .. "ssēs", 2 )
		add_form(data, "3s_plup_actv_subj", "", sub(typeinfo.perf_stem[1],1,-2) .. "sset", 2 )
		add_form(data, "1p_plup_actv_subj", "", sub(typeinfo.perf_stem[1],1,-2) .. "ssēmus", 2 )
		add_form(data, "2p_plup_actv_subj", "", sub(typeinfo.perf_stem[1],1,-2) .. "ssētis", 2 )
		add_form(data, "3p_plup_actv_subj", "", sub(typeinfo.perf_stem[1],1,-2) .. "ssent", 2 )
		add_form(data, "perf_actv_inf", "", sub(typeinfo.perf_stem[1],1,-2) .. "sse", 2 )
		data.form_footnote_indices["2s_perf_actv_indc"] = tostring(noteindex)
		data.form_footnote_indices["1p_perf_actv_indc"] = tostring(noteindex)
		data.form_footnote_indices["2p_perf_actv_indc"] = tostring(noteindex)
		data.form_footnote_indices["3p_perf_actv_indc"] = tostring(noteindex)
		data.form_footnote_indices["1s_plup_actv_indc"] = tostring(noteindex)
		data.form_footnote_indices["2s_plup_actv_indc"] = tostring(noteindex)
		data.form_footnote_indices["3s_plup_actv_indc"] = tostring(noteindex)
		data.form_footnote_indices["1p_plup_actv_indc"] = tostring(noteindex)
		data.form_footnote_indices["2p_plup_actv_indc"] = tostring(noteindex)
		data.form_footnote_indices["3p_plup_actv_indc"] = tostring(noteindex)
		data.form_footnote_indices["1s_futp_actv_indc"] = tostring(noteindex)
		data.form_footnote_indices["2s_futp_actv_indc"] = tostring(noteindex)
		data.form_footnote_indices["3s_futp_actv_indc"] = tostring(noteindex)
		data.form_footnote_indices["1p_futp_actv_indc"] = tostring(noteindex)
		data.form_footnote_indices["2p_futp_actv_indc"] = tostring(noteindex)
		data.form_footnote_indices["3p_futp_actv_indc"] = tostring(noteindex)
		data.form_footnote_indices["1s_perf_actv_subj"] = tostring(noteindex)
		data.form_footnote_indices["2s_perf_actv_subj"] = tostring(noteindex)
		data.form_footnote_indices["3s_perf_actv_subj"] = tostring(noteindex)
		data.form_footnote_indices["1p_perf_actv_subj"] = tostring(noteindex)
		data.form_footnote_indices["2p_perf_actv_subj"] = tostring(noteindex)
		data.form_footnote_indices["3p_perf_actv_subj"] = tostring(noteindex)
		data.form_footnote_indices["1s_plup_actv_subj"] = tostring(noteindex)
		data.form_footnote_indices["2s_plup_actv_subj"] = tostring(noteindex)
		data.form_footnote_indices["3s_plup_actv_subj"] = tostring(noteindex)
		data.form_footnote_indices["1p_plup_actv_subj"] = tostring(noteindex)
		data.form_footnote_indices["2p_plup_actv_subj"] = tostring(noteindex)
		data.form_footnote_indices["3p_plup_actv_subj"] = tostring(noteindex)
		data.form_footnote_indices["perf_actv_inf"] = tostring(noteindex)
		data.footnotes[noteindex] = 'The verb \"nōscō\" and its compounds frequently drop the syllables \"vi\" and \"ve\" from their perfect, pluperfect and future perfect conjugations.'
	end
	if typeinfo.pres_stem == "ulcīsc" then
		local noteindex = #(data.footnotes) + 1
		add_form(data, "1s_sigf_actv_indc", "", "ullō", 2 )
		data.form_footnote_indices["1s_sigf_actv_indc"] = tostring(noteindex)
		data.footnotes[noteindex] = 'The form \"ullō\" may have resulted from a later, erroneous misreading of \"ulsō\".'
	end
end

conjugations["3rd-io"] = function(args, data, typeinfo)
	get_regular_stems(args, typeinfo)

	table.insert(data.title, "[[Appendix:Latin third conjugation|third conjugation]] ''iō''-variant")
	set_3rd_conj_categories(data, typeinfo)

	make_pres_3rd_io(data, typeinfo, typeinfo.pres_stem)
	make_perf_and_supine(data, typeinfo)
	make_sigm(data, typeinfo, typeinfo.sigm_stem)
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

    if typeinfo.subtypes.depon then
		m_table.insertIfNot(data.categories, "Latin fourth conjugation deponent verbs")
    elseif typeinfo.subtypes.noperf then
		m_table.insertIfNot(data.categories, "Latin fourth conjugation verbs with missing perfect stem")
    end

    if typeinfo.subtypes.nosup then
		m_table.insertIfNot(data.categories, "Latin fourth conjugation verbs with missing supine stem")
    elseif typeinfo.subtypes.supfutractvonly then
		m_table.insertIfNot(data.categories, "Latin fourth conjugation verbs with missing supine stem except in the future active participle‎ ")
    end

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

	make_pres_4th(data, typeinfo, typeinfo.pres_stem)
	make_perf_and_supine(data, typeinfo)
	make_sigm(data, typeinfo, typeinfo.sigm_stem)

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
						m_table.insertIfNot(data.forms[key], f)
					end
					m_table.insertIfNot(data.forms[key], ivi_ive(f))
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

	-- Signal to {{la-verb}} to display the verb as irregular and highly defective
	typeinfo.subtypes.irreg = true
	typeinfo.subtypes.highlydef = true

	local prefix = typeinfo.prefix or ""

	data.forms["1s_pres_actv_indc"] = prefix .. "aiō"
	data.forms["2s_pres_actv_indc"] = prefix .. "ais"
	data.forms["3s_pres_actv_indc"] = prefix .. "ait"
	data.forms["3p_pres_actv_indc"] = prefix .. "aiunt"

	data.forms["1s_impf_actv_indc"] = prefix .. "aiēbam"
	data.forms["2s_impf_actv_indc"] = prefix .. "aiēbās"
	data.forms["3s_impf_actv_indc"] = prefix .. "aiēbat"
	data.forms["1p_impf_actv_indc"] = prefix .. "aiēbāmus"
	data.forms["2p_impf_actv_indc"] = prefix .. "aiēbātis"
	data.forms["3p_impf_actv_indc"] = prefix .. "aiēbant"

	data.forms["2s_perf_actv_indc"] = prefix .. "aistī"
	data.forms["3s_perf_actv_indc"] = prefix .. "ait"

	data.forms["2s_pres_actv_subj"] = prefix .. "aiās"
	data.forms["3s_pres_actv_subj"] = prefix .. "aiat"
	data.forms["3p_pres_actv_subj"] = prefix .. "aiant"

	data.forms["2s_pres_actv_impr"] = prefix .. "ai"

	data.forms["pres_actv_inf"] = prefix .. "aiere"
	data.forms["pres_actv_ptc"] = prefix .. "aiēns"
end

irreg_conjugations["aiio"] = function(args, data, typeinfo)
	table.insert(data.title, "[[Appendix:Latin third conjugation|third conjugation]] iō-variant")
	table.insert(data.title, "[[Appendix:Latin irregular verbs|irregular]]")
	table.insert(data.title, "active only")
	table.insert(data.title, "highly [[defective verb|defective]]")
	table.insert(data.categories, "Latin third conjugation verbs")
	table.insert(data.categories, "Latin irregular verbs")
	table.insert(data.categories, "Latin active-only verbs")
	table.insert(data.categories, "Latin defective verbs")

	-- Signal to {{la-verb}} to display the verb as irregular and highly defective
	typeinfo.subtypes.irreg = true
	typeinfo.subtypes.highlydef = true

	local prefix = typeinfo.prefix or ""

	data.forms["1s_pres_actv_indc"] = prefix .. "aiiō"
	data.forms["2s_pres_actv_indc"] = prefix .. "ais"
	data.forms["3s_pres_actv_indc"] = prefix .. "ait"
	data.forms["3p_pres_actv_indc"] = prefix .. "aiunt"

	data.forms["1s_impf_actv_indc"] = prefix .. "aiiēbam"
	data.forms["2s_impf_actv_indc"] = prefix .. "aiiēbās"
	data.forms["3s_impf_actv_indc"] = prefix .. "aiiēbat"
	data.forms["1p_impf_actv_indc"] = prefix .. "aiiēbāmus"
	data.forms["2p_impf_actv_indc"] = prefix .. "aiiēbātis"
	data.forms["3p_impf_actv_indc"] = prefix .. "aiiēbant"

	data.forms["2s_perf_actv_indc"] = prefix .. "aistī"
	data.forms["3s_perf_actv_indc"] = prefix .. "ait"

	data.forms["2s_pres_actv_subj"] = prefix .. "aiiās"
	data.forms["3s_pres_actv_subj"] = prefix .. "aiiat"
	data.forms["3p_pres_actv_subj"] = prefix .. "aiiant"

	data.forms["2s_pres_actv_impr"] = prefix .. "ai"

	data.forms["pres_actv_inf"] = prefix .. "aiiere"
	data.forms["pres_actv_ptc"] = prefix .. "aiiēns"
end

irreg_conjugations["ajo"] = function(args, data, typeinfo)
	table.insert(data.title, "[[Appendix:Latin third conjugation|third conjugation]] iō-variant")
	table.insert(data.title, "[[Appendix:Latin irregular verbs|irregular]]")
	table.insert(data.title, "active only")
	table.insert(data.title, "highly [[defective verb|defective]]")
	table.insert(data.categories, "Latin third conjugation verbs")
	table.insert(data.categories, "Latin irregular verbs")
	table.insert(data.categories, "Latin active-only verbs")
	table.insert(data.categories, "Latin defective verbs")

	-- Signal to {{la-verb}} to display the verb as irregular and highly defective
	typeinfo.subtypes.irreg = true
	typeinfo.subtypes.highlydef = true

	local prefix = typeinfo.prefix or ""

	data.forms["1s_pres_actv_indc"] = prefix .. "ajō"
	data.forms["2s_pres_actv_indc"] = prefix .. "ais"
	data.forms["3s_pres_actv_indc"] = prefix .. "ait"
	data.forms["3p_pres_actv_indc"] = prefix .. "ajunt"

	data.forms["1s_impf_actv_indc"] = prefix .. "ajēbam"
	data.forms["2s_impf_actv_indc"] = prefix .. "ajēbās"
	data.forms["3s_impf_actv_indc"] = prefix .. "ajēbat"
	data.forms["1p_impf_actv_indc"] = prefix .. "ajēbāmus"
	data.forms["2p_impf_actv_indc"] = prefix .. "ajēbātis"
	data.forms["3p_impf_actv_indc"] = prefix .. "ajēbant"

	data.forms["2s_perf_actv_indc"] = prefix .. "aistī"
	data.forms["3s_perf_actv_indc"] = prefix .. "ait"

	data.forms["2s_pres_actv_subj"] = prefix .. "ajās"
	data.forms["3s_pres_actv_subj"] = prefix .. "ajat"
	data.forms["3p_pres_actv_subj"] = prefix .. "ajant"

	data.forms["2s_pres_actv_impr"] = prefix .. "ai"

	data.forms["pres_actv_inf"] = prefix .. "ajere"
	data.forms["pres_actv_ptc"] = prefix .. "ajēns"
end

irreg_conjugations["dico"] = function(args, data, typeinfo)
	table.insert(data.title, "[[Appendix:Latin third conjugation|third conjugation]]")
	table.insert(data.title, "[[Appendix:Latin irregular verbs|irregular]] short imperative")
	table.insert(data.categories, "Latin third conjugation verbs")
	table.insert(data.categories, "Latin irregular verbs")

	local prefix = typeinfo.prefix or ""

	make_pres_3rd(data, typeinfo, prefix .. "dīc")
	make_perf(data, prefix .. "dīx")
	make_supine(data, typeinfo, prefix .. "dict")
	make_sigm(data, typeinfo, prefix .. "dīx")

	--Archaic regular imperative
	local noteindex = #(data.footnotes) + 1
	add_form(data, "2s_pres_actv_impr", prefix, "dīc", 1)
	data.form_footnote_indices["2s_pres_actv_impr"] = tostring(noteindex)

	--Archaic future forms
	if prefix == "" then
		add_form(data, "1s_futr_actv_indc", "", "dīcēbō", 2 )
		add_form(data, "3s_futr_actv_indc", "", "dīcēbit", 2 )
		data.form_footnote_indices["1s_futr_actv_indc"] = tostring(noteindex)
		data.form_footnote_indices["3s_futr_actv_indc"] = tostring(noteindex)
	end
	data.footnotes[noteindex] = 'Archaic.'
end

irreg_conjugations["do"] = function(args, data, typeinfo)
	table.insert(data.title, "[[Appendix:Latin first conjugation|first conjugation]]")
	table.insert(data.title, "[[Appendix:Latin irregular verbs|irregular]] short ''a'' in most forms except " .. make_link(nil, "dās", "term") .. " and " .. make_link(nil, "dā", "term"))
	table.insert(data.categories, "Latin first conjugation verbs")
	table.insert(data.categories, "Latin irregular verbs")

	-- Signal to {{la-verb}} to display the verb as irregular
	typeinfo.subtypes.irreg = true

	local prefix = typeinfo.prefix or ""

	make_perf(data, prefix .. "ded")
	make_supine(data, typeinfo, prefix .. "dat")

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

	-- Gerund
	make_gerund(data, typeinfo, prefix .. "dand")
end

irreg_conjugations["duco"] = function(args, data, typeinfo)
	table.insert(data.title, "[[Appendix:Latin third conjugation|third conjugation]]")
	table.insert(data.title, "[[Appendix:Latin irregular verbs|irregular]] short imperative")
	table.insert(data.categories, "Latin third conjugation verbs")
	table.insert(data.categories, "Latin irregular verbs")

	local prefix = typeinfo.prefix or ""

	make_pres_3rd(data, typeinfo, prefix .. "dūc")
	make_perf(data, prefix .. "dūx")
	make_supine(data, typeinfo, prefix .. "duct")
	make_sigm(data, typeinfo, prefix .. "dūx")

	add_form(data, "2s_pres_actv_impr", prefix, "dūc", 1)
end

irreg_conjugations["edo"] = function(args, data, typeinfo)
	table.insert(data.title, "[[Appendix:Latin third conjugation|third conjugation]]")
	table.insert(data.title, "some [[Appendix:Latin irregular verbs|irregular]] alternative forms")
	table.insert(data.categories, "Latin third conjugation verbs")
	table.insert(data.categories, "Latin irregular verbs")

	-- Signal to {{la-verb}} to display the verb as irregular
	typeinfo.subtypes.irreg = true

	local prefix = typeinfo.prefix or ""

	make_pres_3rd(data, typeinfo, prefix .. "ed")
	make_perf(data, prefix .. "ēd")
	make_supine(data, typeinfo, prefix .. "ēs")

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
	make_supine(data, typeinfo, prefix .. "it")

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

	-- Gerund
	make_gerund(data, typeinfo, prefix .. "eund")
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
	table.insert(data.title, "[[Appendix:Latin irregular verbs|irregular]] and partially [[suppletive]] in the passive")
	table.insert(data.categories, "Latin third conjugation verbs")
	table.insert(data.categories, "Latin irregular verbs")
	table.insert(data.categories, "Latin suppletive verbs")

	local prefix = typeinfo.prefix or ""

	make_pres_3rd_io(data, typeinfo, prefix .. "fac", "nopass")
	-- We said no passive, but we do want the future passive participle.
	make_gerund(data, typeinfo, prefix .. "faciend", "und-variant", "no-gerund")

	make_perf(data, prefix .. "fēc")
	make_supine(data, typeinfo, prefix .. "fact")
	make_sigm(data, typeinfo, prefix .. "fax")

	if prefix == "" then
		-- Active imperative
		add_form(data, "2s_pres_actv_impr", "", "fac", 1)
		-- Sigmatic forms
		add_form(data, "1s_sigf_actv_indc", "", {"faxsō", "facsō", "faxiō"}, 2)
		add_form(data, "2s_sigf_actv_indc", "", {"faxsis", "facsis", "facxis", "facxsis"},  2)
		add_form(data, "3s_sigf_actv_indc", "", "faxsit", 2)
		add_form(data, "1p_sigf_actv_indc", "", "faxsimus", 2)
		add_form(data, "2p_sigf_actv_indc", "", "faxsitis", 2)
		add_form(data, "3p_sigf_actv_indc", "", "faxsint", 2)
		add_form(data, "1s_siga_actv_subj", "", {"faxsim", "faxēm"}, 2)
		add_form(data, "2s_siga_actv_subj", "", {"faxsīs", "faxseis", "faxeis", "faxēs"}, 2)
		add_form(data, "3s_siga_actv_subj", "", {"faxsīt", "faxeit", "faxēt"},  2)
		add_form(data, "1p_siga_actv_subj", "", {"faxsīmus", "faxeimus"}, 2)
		add_form(data, "2p_siga_actv_subj", "", {"faxsītis", "faxeitis"}, 2)
		add_form(data, "3p_siga_actv_subj", "", {"faxsint", "faxēnt"}, 2)
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

	make_supine(data, typeinfo, prefix .. "fact")

	-- Perfect/future infinitives
	data.forms["futr_actv_inf"] = data.forms["futr_pasv_inf"]

	-- Imperfective participles
	data.forms["pres_actv_ptc"] = nil
	data.forms["futr_actv_ptc"] = nil

	-- Gerund
	make_gerund(data, typeinfo, prefix .. "fiend", "und-variant")
end

irreg_conjugations["fero"] = function(args, data, typeinfo)
	table.insert(data.title, "[[Appendix:Latin third conjugation|third conjugation]]")
	table.insert(data.title, "[[Appendix:Latin irregular verbs|irregular]]")
	table.insert(data.title, "[[suppletive]]")
	table.insert(data.categories, "Latin third conjugation verbs")
	table.insert(data.categories, "Latin irregular verbs")
	table.insert(data.categories, "Latin suppletive verbs")

	-- Signal to {{la-verb}} to display the verb as irregular
	typeinfo.subtypes.irreg = true

	local prefix_pres = typeinfo.prefix or ""
	local prefix_perf = ine(args[3])
	local prefix_supine = ine(args[4])

	prefix_perf = prefix_perf or prefix_pres
	prefix_supine = prefix_supine or prefix_pres

	make_pres_3rd(data, typeinfo, prefix_pres .. "fer")
	if prefix_perf == "" then
		make_perf(data, {"tul", "tetul"})
		local noteindex = #(data.footnotes) + 1
		for slot in iter_slots(false, false) do
			if cfind(slot, "perf") or cfind(slot, "plup") or cfind(slot, "futp") then
				data.form_footnote_indices[slot] = tostring(noteindex)
				data.footnotes[noteindex] = 'Archaic.'
			end
		end
	else
		make_perf(data, prefix_perf .. "tul")
	end
	make_supine(data, typeinfo, prefix_supine .. "lāt")

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
end

irreg_conjugations["inquam"] = function(args, data, typeinfo)
	table.insert(data.title, "[[Appendix:Latin irregular verbs|irregular]]")
	table.insert(data.title, "highly [[defective verb|defective]]")
	table.insert(data.categories, "Latin irregular verbs")
	table.insert(data.categories, "Latin defective verbs")

	-- Signal to {{la-verb}} to display the verb as highly defective
	-- (it already displays as irregular because conj == "irreg" and
	-- subconj == "irreg")
	typeinfo.subtypes.highlydef = true

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
	table.insert(data.title, "[[suppletive]] in the second-person singular indicative present")
	table.insert(data.categories, "Latin irregular verbs")
	table.insert(data.categories, "Latin suppletive verbs")

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
	table.insert(data.title, "[[suppletive]] in the second-person singular indicative present")
	table.insert(data.categories, "Latin irregular verbs")
	table.insert(data.categories, "Latin suppletive verbs")

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
	table.insert(data.title, "[[suppletive]] in the second-person singular indicative present")
	table.insert(data.categories, "Latin irregular verbs")
	table.insert(data.categories, "Latin suppletive verbs")

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
	local ppplink = make_link(prefix .. "ausus", nil, "term")
	local sumlink = make_link("sum", nil, "term")
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
	make_gerund(data, typeinfo, prefix .. "pigend")
end

irreg_conjugations["coepi"] = function(args, data, typeinfo)
	table.insert(data.title, "[[Appendix:Latin third conjugation|third conjugation]]")
	table.insert(data.title, "no [[present tense|present]] stem")
	table.insert(data.categories, "Latin third conjugation verbs")
	table.insert(data.categories, "Latin verbs with missing present stem")
	table.insert(data.categories, "Latin defective verbs")

	local prefix = typeinfo.prefix or ""

	make_perf(data, prefix .. "coep")
	make_supine(data, typeinfo, prefix .. "coept")
	make_perfect_passive(data)
end

-- The vowel of the prefix is lengthened if it ends in -n and the next word begins with f- or s-.
local function lengthen_prefix(prefix)
	return prefix:gsub("([aeiou]n)$", {["an"] = "ān", ["en"] = "ēn", ["in"] = "īn", ["on"] = "ōn", ["un"] = "ūn"})
end

irreg_conjugations["sum"] = function(args, data, typeinfo)
	table.insert(data.title, "highly [[Appendix:Latin irregular verbs|irregular]]")
	table.insert(data.title, "[[suppletive]]")
	table.insert(data.categories, "Latin irregular verbs")
	table.insert(data.categories, "Latin suppletive verbs")

	local prefix = typeinfo.prefix or ""
	local prefix_e = ine(args[3]) or prefix
	local prefix_f = lengthen_prefix(ine(args[4]) or prefix)
	local prefix_s = lengthen_prefix(prefix)

	typeinfo.subtypes.nopass = true
	typeinfo.subtypes.supfutractvonly = true
	make_perf(data, prefix_f .. "fu")
	make_supine(data, typeinfo, prefix_f .. "fut")

	-- Active imperfective indicative
	data.forms["1s_pres_actv_indc"] = prefix_s .. "sum"
	data.forms["2s_pres_actv_indc"] = prefix_e .. "es"
	data.forms["3s_pres_actv_indc"] = prefix_e .. "est"
	data.forms["1p_pres_actv_indc"] = prefix_s .. "sumus"
	data.forms["2p_pres_actv_indc"] = prefix_e .. "estis"
	data.forms["3p_pres_actv_indc"] = prefix_s .. "sunt"

	data.forms["1s_impf_actv_indc"] = prefix_e .. "eram"
	data.forms["2s_impf_actv_indc"] = prefix_e .. "erās"
	data.forms["3s_impf_actv_indc"] = prefix_e .. "erat"
	data.forms["1p_impf_actv_indc"] = prefix_e .. "erāmus"
	data.forms["2p_impf_actv_indc"] = prefix_e .. "erātis"
	data.forms["3p_impf_actv_indc"] = prefix_e .. "erant"

	data.forms["1s_futr_actv_indc"] = prefix_e .. "erō"
	data.forms["2s_futr_actv_indc"] = {prefix_e .. "eris", prefix_e .. "ere"}
	data.forms["3s_futr_actv_indc"] = prefix_e .. "erit"
	data.forms["1p_futr_actv_indc"] = prefix_e .. "erimus"
	data.forms["2p_futr_actv_indc"] = prefix_e .. "eritis"
	data.forms["3p_futr_actv_indc"] = prefix_e .. "erunt"

	-- Active imperfective subjunctive
	data.forms["1s_pres_actv_subj"] = prefix_s .. "sim"
	data.forms["2s_pres_actv_subj"] = prefix_s .. "sīs"
	data.forms["3s_pres_actv_subj"] = prefix_s .. "sit"
	data.forms["1p_pres_actv_subj"] = prefix_s .. "sīmus"
	data.forms["2p_pres_actv_subj"] = prefix_s .. "sītis"
	data.forms["3p_pres_actv_subj"] = prefix_s .. "sint"
	if prefix_s == "ad" then
		local noteindex = #(data.footnotes) + 1
		add_form(data, "3p_pres_actv_subj", "", "adessint", 2 )
		data.form_footnote_indices["3p_pres_actv_subj"] = tostring(noteindex)
		data.footnotes[noteindex] = 'Archaic.'
	end

	data.forms["1s_impf_actv_subj"] = {prefix_e .. "essem", prefix_f .. "forem"}
	data.forms["2s_impf_actv_subj"] = {prefix_e .. "essēs", prefix_f .. "forēs"}
	data.forms["3s_impf_actv_subj"] = {prefix_e .. "esset", prefix_f .. "foret"}
	data.forms["1p_impf_actv_subj"] = {prefix_e .. "essēmus", prefix_f .. "forēmus"}
	data.forms["2p_impf_actv_subj"] = {prefix_e .. "essētis", prefix_f .. "forētis"}
	data.forms["3p_impf_actv_subj"] = {prefix_e .. "essent", prefix_f .. "forent"}

	-- Imperative
	data.forms["2s_pres_actv_impr"] = prefix_e .. "es"
	data.forms["2p_pres_actv_impr"] = prefix_e .. "este"

	data.forms["2s_futr_actv_impr"] = prefix_e .. "estō"
	data.forms["3s_futr_actv_impr"] = prefix_e .. "estō"
	data.forms["2p_futr_actv_impr"] = prefix_e .. "estōte"
	data.forms["3p_futr_actv_impr"] = prefix_s .. "suntō"

	-- Present infinitives
	data.forms["pres_actv_inf"] = prefix_e .. "esse"

	-- Future infinitives
	data.forms["futr_actv_inf"] = {"[[" .. prefix_f .. "futūrum]] [[esse]]", prefix_f .. "fore"}

	-- Imperfective participles
	if prefix == "ab" then
		data.forms["pres_actv_ptc"] = "absēns"
	elseif prefix == "prae" then
		data.forms["pres_actv_ptc"] = "praesēns"
	end

	-- Gerund
	data.forms["ger_gen"] = nil
	data.forms["ger_dat"] = nil
	data.forms["ger_acc"] = nil
	data.forms["ger_abl"] = nil

	-- Supine
	data.forms["sup_acc"] = nil
	data.forms["sup_abl"] = nil
end


-- Form-generating functions

make_pres_1st = function(data, typeinfo, pres_stem)
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

	-- Gerund
	make_gerund(data, typeinfo, pres_stem .. "and")
end

make_pres_2nd = function(data, typeinfo, pres_stem, nopass, noimpr)
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

	-- Gerund
	make_gerund(data, typeinfo, pres_stem .. "end", nil, nil, nopass)
end

make_pres_3rd = function(data, typeinfo, pres_stem)
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

	-- Gerund
	make_gerund(data, typeinfo, pres_stem .. "end", "und-variant")
end

make_pres_3rd_io = function(data, typeinfo, pres_stem, nopass)
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

	-- Gerund
	make_gerund(data, typeinfo, pres_stem .. "iend", "und-variant", nil, nopass)
end

make_pres_4th = function(data, typeinfo, pres_stem)
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

	-- Gerund
	make_gerund(data, typeinfo, pres_stem .. "iend", "und-variant")
end

make_perf_and_supine = function(data, typeinfo)
	if typeinfo.subtypes.optsemidepon then
		make_perf(data, typeinfo.perf_stem, "noinf")
		make_deponent_perf(data, typeinfo.supine_stem)
	else
		make_perf(data, typeinfo.perf_stem)
		make_supine(data, typeinfo, typeinfo.supine_stem)
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

		add_form(data, "perf_actv_inf", "", "[[" .. stem .. "um]] [[esse]]")
		add_form(data, "futr_actv_inf", "", "[[" .. stem .. "ūrum]] [[esse]]")
		add_form(data, "perf_actv_ptc", stem, "us")
		add_form(data, "futr_actv_ptc", stem, "ūrus")

		-- Supine
		add_form(data, "sup_acc", stem, "um")
		add_form(data, "sup_abl", stem, "ū")
	end
end

make_supine = function(data, typeinfo, supine_stem)
	if not supine_stem then
		return
	end
	if type(supine_stem) ~= "table" then
		supine_stem = {supine_stem}
	end

	-- Perfect/future infinitives
	for _, stem in ipairs(supine_stem) do
		local futr_actv_inf, perf_pasv_inf, futr_pasv_inf, futr_actv_ptc
		local perf_pasv_ptc_lemma, perf_actv_ptc, perf_actv_ptc_acc
		-- Perfect/future participles
		futr_actv_ptc = stem .. "ūrus"
		if typeinfo.subtypes.passimpers then
			perf_pasv_ptc_lemma = stem .. "um"
			perf_pasv_ptc = perf_pasv_ptc_lemma
			perf_pasv_ptc_acc = perf_pasv_ptc_lemma
		else
			perf_pasv_ptc_lemma = stem .. "us"
			if typeinfo.subtypes.mp then
				perf_pasv_ptc = stem .. "ī"
				perf_pasv_ptc_acc = stem .. "ōs"
			elseif typeinfo.subtypes.fp then
				perf_pasv_ptc = stem .. "ae"
				perf_pasv_ptc_acc = stem .. "ās"
			elseif typeinfo.subtypes.np then
				perf_pasv_ptc = stem .. "a"
				perf_pasv_ptc_acc = perf_pasv_ptc
			elseif typeinfo.subtypes.f then
				perf_pasv_ptc = stem .. "a"
				perf_pasv_ptc_acc = stem .. "am"
			elseif typeinfo.subtypes.n then
				perf_pasv_ptc = stem .. "um"
				perf_pasv_ptc_acc = perf_pasv_ptc
			else
				perf_pasv_ptc = perf_pasv_ptc_lemma
				perf_pasv_ptc_acc = stem .. "um"
			end
		end

		perf_pasv_inf = make_raw_link(perf_pasv_ptc_lemma,
			perf_pasv_ptc_acc ~= perf_pasv_ptc_lemma and perf_pasv_ptc_acc or nil) .. " [[esse]]"
		futr_pasv_inf = make_raw_link(stem .. "um") .. " [[īrī]]"

		-- Exceptions
		local mortu = {
			["conmortu"] = true,
			["commortu"] = true,
			["dēmortu"] = true,
			["ēmortu"] = true,
			["inmortu"] = true,
			["immortu"] = true,
			["inēmortu"] = true,
			["intermortu"] = true,
			["permortu"] = true,
			["praemortu"] = true,
			["superēmortu"] = true
		}
		local ort = {
			["ort"] = true,
			["abort"] = true,
			["adort"] = true,
			["coort"] = true,
			["exort"] = true,
			["hort"] = true,
			["obort"] = true
		}
		if mortu[stem] then
			futr_actv_ptc = stem:gsub("mortu$", "moritūrus")
		elseif ort[stem] then
			futr_actv_ptc = stem:gsub("ort$", "oritūrus")
		elseif stem == "mortu" then
			-- FIXME, are we sure about this?
			futr_actv_inf = {}
			futr_actv_ptc = "moritūrus"
		end

		if not futr_actv_inf then
			futr_actv_inf = make_raw_link(futr_actv_ptc, futr_actv_ptc:gsub("us$", "um")) .. " [[esse]]"
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

make_sigm = function(data, typeinfo, sigm_stem)
	if not (typeinfo.subtypes.sigm or typeinfo.subtypes.sigmpasv) then
		return
	end
	if type(sigm_stem) ~= "table" then
		sigm_stem = {sigm_stem}
	end
	local noteindex = #(data.footnotes) + 1

	for _, stem in ipairs(sigm_stem) do
		-- Deponent verbs use the passive form
		if typeinfo.subtypes.depon then
			add_form(data, "1s_sigf_actv_indc", stem, "or")
			add_form(data, "2s_sigf_actv_indc", stem, "eris")
			add_form(data, "3s_sigf_actv_indc", stem, "itur")
		else
			for _, stem in ipairs(sigm_stem) do
				-- Sigmatic future active indicative
				add_forms(data, "sigf_actv_indc", stem, "ō", "is", "it", "imus", "itis", "int")
				-- Sigmatic future passive indicative (option)
				if typeinfo.subtypes.sigmpasv then
					add_form(data, "1s_sigf_pasv_indc", stem, "or")
					add_form(data, "2s_sigf_pasv_indc", stem, "eris")
					add_form(data, "3s_sigf_pasv_indc", stem, "itur")
				end
				-- Sigmatic future active subjunctive
				add_forms(data, "siga_actv_subj", stem, "im", "īs", "īt", "īmus", "ītis", "int")
				-- Perfect infinitive
				if not no_inf then
					add_form(data, "sigm_actv_inf", stem, "ere")
				end
			end
		end
	end
	data.form_footnote_indices["sigm"] = noteindex
	if (typeinfo.subtypes.sigm or typeinfo.subtypes.sigmpasv) and not (typeinfo.subtypes.depon) then
		data.footnotes[noteindex] = 'At least one use of the archaic \"sigmatic future\" and \"sigmatic aorist\" tenses is attested, which are used by [[Old Latin]] writers; most notably [[w:Plautus|Plautus]] and [[w:Terence|Terence]]. The sigmatic future is generally ascribed a future or future perfect meaning, while the sigmatic aorist expresses a possible desire (\"might want to\").'
		if typeinfo.subtypes.sigmpasv then
			data.footnotes[noteindex] = data.footnotes[noteindex] .. ' It is also attested as having a rare sigmatic future passive indicative form (\"will have been\"), which is not attested in the plural for any verb.'
		end
	elseif typeinfo.subtypes.depon then
		data.footnotes[noteindex] = 'At least one use of the archaic \"sigmatic future\" tense is attested, which is used by [[Old Latin]] writers; most notably [[w:Plautus|Plautus]] and [[w:Terence|Terence]]. The sigmatic future is generally ascribed a future or future perfect meaning, and, as the verb is deponent, takes the form of what would otherwise be the rare sigmatic future passive indicative tense (which is not attested in the plural for any verb).'
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
		elseif subform:find("[%[%]]") then
			-- Don't put accelerators on forms already containing links such as
			-- the perfect passive infinitive and future active infinitive, or
			-- the participles wrongly get tagged as infinitives as well as
			-- participles.
			form[key] = make_link(subform)
		else
			form[key] = make_link(subform, nil, nil, accel)
		end
	end

	return table.concat(form, ",<br> ")
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
  ['futp'] = {'futp'},
  ['sigm'] = {'sigm'},
  ['sigf'] = {'sigm', 'fut'},
  ['siga'] = {'sigm', 'aor'},
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
		local slot_parts = split(slot, "_")
		local tags = {}
		for _, part in ipairs(slot_parts) do
			for _, tag in ipairs(parts_to_tags[part]) do
				table.insert(tags, tag)
			end
		end

		-- put the case first for verbal nouns
		local accel_slot
		if tags[1] == "sup" or tags[1] == "ger" then
			accel_slot = tags[2] .. "|" .. tags[1]
		else
			accel_slot = table.concat(tags, "|")
		end

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
		table.insert(lemma_links, make_link(nil, subform, "term"))
	end
	return table.concat(lemma_links, ", ")
end

-- Make the table
make_table = function(data)
	data.actual_lemma = export.get_lemma_forms(data)
	convert_forms_into_links(data)

	return require("Module:TemplateStyles")("Module:roa-verb/style.css") .. [=[
<div class="NavFrame">
<div class="NavHead"> &nbsp;&nbsp;&nbsp;Conjugation of ]=] .. get_displayable_lemma(data.actual_lemma) .. (#data.title > 0 and " (" .. table.concat(data.title, ", ") .. ")" or "") .. [=[</div>
<div class="NavContent">
{| class="roa-inflection-table" data-toggle-category="inflection"
]=] .. make_indc_rows(data) .. make_subj_rows(data) .. make_impr_rows(data) .. make_nonfin_rows(data) .. make_vn_rows(data) .. [=[

|}</div></div>]=].. make_footnotes(data)

end

local tenses = {
	["pres"] = "present",
	["impf"] = "imperfect",
	["futr"] = "future",
	["perf"] = "perfect",
	["plup"] = "pluperfect",
	["futp"] = "future&nbsp;perfect",
	["sigf"] = "sigmatic&nbsp;future",
	["siga"] = "sigmatic&nbsp;aorist"
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

		for _, t in ipairs({"pres", "impf", "futr", "perf", "plup", "futp", "sigf"}) do
			local row = {}
			local notempty = false

			if data.forms[t .. "_" .. v .. "_indc"] then
				row = '\n! colspan="6" class="roa-compound-row" |' .. data.forms[t .. "_" .. v .. "_indc"]
				nonempty = true
				notempty = true
			else
				for col, p in ipairs({"1s", "2s", "3s", "1p", "2p", "3p"}) do
					local slot = p .. "_" .. t .. "_" .. v .. "_indc"
					row[col] = "\n| " .. data.forms[slot] .. (
						data.form_footnote_indices[slot] == nil and "" or
						'<sup class="roa-red-superscript">' .. data.form_footnote_indices[slot].."</sup>"
					)

					-- show_form() already called so can just check for "&mdash;"
					if data.forms[slot] ~= "&mdash;" then
						nonempty = true
						notempty = true
					end
				end

				row = table.concat(row)
			end

			local fn
			if t == "sigf" and data.form_footnote_indices["sigm"] then
				fn = '<sup class="roa-red-superscript">' .. data.form_footnote_indices["sigm"].."</sup>"
			else
				fn = ""
			end

			if notempty then
				table.insert(group, '\n! class="roa-indicative-left-rail" | ' .. tenses[t] ..  fn .. row)
			end
		end

		if nonempty and #group > 0 then
			table.insert(indc, '\n|-\n! rowspan="' .. tostring(#group) .. '" class="roa-indicative-left-rail" | ' .. voices[v] .. "\n" .. table.concat(group, "\n|-"))
		end
	end

	return
[=[

|-
! colspan="2" rowspan="2" class="roa-indicative-left-rail" | indicative
! colspan="3" class="roa-indicative-left-rail" | ''singular''
! colspan="3" class="roa-indicative-left-rail" | ''plural''
|-
! class="roa-indicative-left-rail" style="width:12.5%;" | [[first person|first]]
! class="roa-indicative-left-rail" style="width:12.5%;" | [[second person|second]]
! class="roa-indicative-left-rail" style="width:12.5%;" | [[third person|third]]
! class="roa-indicative-left-rail" style="width:12.5%;" | [[first person|first]]
! class="roa-indicative-left-rail" style="width:12.5%;" | [[second person|second]]
! class="roa-indicative-left-rail" style="width:12.5%;" | [[third person|third]]
]=] .. table.concat(indc)

end

make_subj_rows = function(data)
	local subj = {}

	for _, v in ipairs({"actv", "pasv"}) do
		local group = {}
		local nonempty = false

		for _, t in ipairs({"pres", "impf", "perf", "plup", "siga"}) do
			local row = {}
			local notempty = false

			if data.forms[t .. "_" .. v .. "_subj"] then
				row = '\n! colspan="6" class="roa-compound-row" |' .. data.forms[t .. "_" .. v .. "_subj"]
				nonempty = true
				notempty = true
			else
				for col, p in ipairs({"1s", "2s", "3s", "1p", "2p", "3p"}) do
					local slot = p .. "_" .. t .. "_" .. v .. "_subj"
					row[col] = "\n| " .. data.forms[slot] .. (
						data.form_footnote_indices[slot] == nil and "" or
						'<sup class="roa-red-superscript">' .. data.form_footnote_indices[slot].."</sup>"
					)

					-- show_form() already called so can just check for "&mdash;"
					if data.forms[slot] ~= "&mdash;" then
						nonempty = true
						notempty = true
					end
				end

				row = table.concat(row)
			end

			local fn
			if t == "siga" and data.form_footnote_indices["sigm"] then
				fn = '<sup class="roa-red-superscript">' .. data.form_footnote_indices["sigm"].."</sup>"
			else
				fn = ""
			end

			if notempty then
				table.insert(group, '\n! class="roa-subjunctive-left-rail" | ' .. tenses[t] .. fn .. row)
			end
		end

		if nonempty and #group > 0 then
			table.insert(subj, '\n|-\n! rowspan=' .. tostring(#group) .. '" class="roa-subjunctive-left-rail" | ' .. voices[v] .. "\n" .. table.concat(group, "\n|-"))
		end
	end

	return
[=[

|-
! colspan="2" rowspan="2" class="roa-subjunctive-left-rail" | subjunctive
! colspan="3" class="roa-subjunctive-left-rail" | ''singular''
! colspan="3" class="roa-subjunctive-left-rail" | ''plural''
|-
! class="roa-subjunctive-left-rail" style="width:12.5%;" | [[first person|first]]
! class="roa-subjunctive-left-rail" style="width:12.5%;" | [[second person|second]]
! class="roa-subjunctive-left-rail" style="width:12.5%;" | [[third person|third]]
! class="roa-subjunctive-left-rail" style="width:12.5%;" | [[first person|first]]
! class="roa-subjunctive-left-rail" style="width:12.5%;" | [[second person|second]]
! class="roa-subjunctive-left-rail" style="width:12.5%;" | [[third person|third]]
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
				row = '\n! colspan="6" class="roa-compound-row" |' .. data.forms[t .. "_" .. v .. "_impr"]
				nonempty = true
			else
				for col, p in ipairs({"1s", "2s", "3s", "1p", "2p", "3p"}) do
					local slot = p .. "_" .. t .. "_" .. v .. "_impr"
					row[col] = "\n| " .. data.forms[slot] .. (
						data.form_footnote_indices[slot] == nil and "" or
						'<sup class="roa-red-superscript">' .. data.form_footnote_indices[slot].."</sup>"
					)

					-- show_form() already called so can just check for "&mdash;"
					if data.forms[slot] ~= "&mdash;" then
						nonempty = true
					end
				end

				row = table.concat(row)
			end

			table.insert(group, '\n! class="roa-imperative-left-rail" | ' .. tenses[t] .. row)
		end

		if nonempty and #group > 0 then
			has_impr = true
			table.insert(impr, '\n|-\n! rowspan="' .. tostring(#group) .. '" class="roa-imperative-left-rail" | ' .. voices[v] .. "\n" .. table.concat(group, "\n|-"))
		end
	end

	if not has_impr then
		return ""
	end
	return
[=[

|-
! colspan="2" rowspan="2" class="roa-imperative-left-rail" | imperative
! colspan="3" class="roa-imperative-left-rail" | ''singular''
! colspan="3" class="roa-imperative-left-rail" | ''plural''
|-
! class="roa-imperative-left-rail" style="width:12.5%;" | [[first person|first]]
! class="roa-imperative-left-rail" style="width:12.5%;" | [[second person|second]]
! class="roa-imperative-left-rail" style="width:12.5%;" | [[third person|third]]
! class="roa-imperative-left-rail" style="width:12.5%;" | [[first person|first]]
! class="roa-imperative-left-rail" style="width:12.5%;" | [[second person|second]]
! class="roa-imperative-left-rail" style="width:12.5%;" | [[third person|third]]
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
				'<sup class="roa-red-superscript">' .. data.form_footnote_indices[slot] .."</sup>"
			)

		end

		row = table.concat(row)
		table.insert(nonfin, '\n|-\n! class="roa-nonfinite-header" colspan="2" | ' .. nonfins[f] .. row)
	end

	return
[=[

|-
! colspan="2" rowspan="2" class="roa-nonfinite-header" | non-finite forms
! colspan="3" class="roa-nonfinite-header" | active
! colspan="3" class="roa-nonfinite-header" | passive
|-
! class="roa-nonfinite-header" style="width:12.5%;" | present
! class="roa-nonfinite-header" style="width:12.5%;" | perfect
! class="roa-nonfinite-header" style="width:12.5%;" | future
! class="roa-nonfinite-header" style="width:12.5%;" | present
! class="roa-nonfinite-header" style="width:12.5%;" | perfect
! class="roa-nonfinite-header" style="width:12.5%;" | future
]=] .. table.concat(nonfin)

end

make_vn_rows = function(data)
	local vn = {}
	local has_vn = false

	local row = {}

	for col, slot in ipairs({"ger_gen", "ger_dat", "ger_acc", "ger_abl", "sup_acc", "sup_abl"}) do
		-- show_form() already called so can just check for "&mdash;"
		if data.forms[slot] ~= "&mdash;" then
			has_vn = true
		end
		row[col] = "\n| " .. data.forms[slot] .. (
			data.form_footnote_indices[slot] == nil and "" or
			'<sup class="roa-red-superscript">' .. data.form_footnote_indices[slot] .. "</sup>"
		)
	end

	row = table.concat(row)

	if has_vn then
		table.insert(vn, "\n|-" .. row)
	end

	if not has_vn then
		return ""
	end
	return
[=[

|-
! colspan="2" rowspan="3" class="roa-nonfinite-header" | verbal nouns
! colspan="4" class="roa-nonfinite-header" | gerund
! colspan="2" class="roa-nonfinite-header" | supine
|-
! class="roa-nonfinite-header" style="width:12.5%;" | genitive
! class="roa-nonfinite-header" style="width:12.5%;" | dative
! class="roa-nonfinite-header" style="width:12.5%;" | accusative
! class="roa-nonfinite-header" style="width:12.5%;" | ablative
! class="roa-nonfinite-header" style="width:12.5%;" | accusative
! class="roa-nonfinite-header" style="width:12.5%;" | ablative]=] .. table.concat(vn)

end

make_footnotes = function(data)
	local tbl = {}
	local i = 0
	for k,v in pairs(data.footnotes) do
		i = i + 1
		tbl[i] = '<sup class="roa-red-superscript">'..tostring(k)..'</sup>'..v..'<br>' end
	return table.concat(tbl)
end

override = function(data, args)
	for slot in iter_slots(true, false) do
		if args[slot] then
			data.forms[slot] = split(args[slot], "/")
		end
	end
end

checkexist = function(data)
	if NAMESPACE ~= '' then return end
	local outerbreak = false
	for _, conjugation in pairs(data.forms) do
		if conjugation then
			if type(conjugation) == "string" then
				conjugation = {conjugation}
			end
			for _, conj in ipairs(conjugation) do
				if not cfind(conj, " ") then
					local title = (lang:makeEntryName(conj))
					local t = mw.title.new(title)
					if t and not t.exists then
						table.insert(data.categories, "Latin verbs with red links in their inflection tables")
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
	local apocopic = sub(args[1],1,-2)
	apocopic = gsub(apocopic,'[^aeiouyāēīōūȳ]+$','')
	if args[1] and args[2] and not find(args[2],'^'..apocopic) then
		table.insert(data.categories,'Latin stem-changing verbs')
	end
end







-- functions for creating external search hyperlinks

flatten_values = function(T)
	function noaccents(x)
		return gsub(toNFD(x),'[^%w]+',"")
	end
	function cleanup(x)
		return noaccents(gsub(gsub(gsub(x, '%[', ''), '%]', ''), ' ', '+'))
	end
		local tbl = {}
	for _, v in pairs(T) do
		if type(v) == "table" then
			local FT = flatten_values(v)
			for _, V in pairs(FT) do
				tbl[#tbl+1] = cleanup(V)
			end
		else
			if find(v, '<') == nil then
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
