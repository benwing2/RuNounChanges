local m_utilities = require("Module:utilities")
local m_table = require("Module:table")
-- FIXME, port remaining functions to [[Module:table]] and use it instead
local ut = require("Module:utils")
local make_link = require("Module:links").full_link

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

local function if_not_empty(val)
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

-- The main entry point.
function export.show(frame)
	local data, domain = export.make_data(frame), frame:getParent().args['search']
	-- Test code to compare existing module to new one.
	if test_new_la_verb_module then
		local m_new_la_verb = require("Module:User:Benwing2/la-verb")
		local miscdata = {
			title = data.title,
			categories = data.categories,
		}
		local newdata = m_new_la_verb.make_data(frame)
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


-- The entry point for 'la-generate-verb-forms' to generate all verb forms.
function export.generate_forms(frame)
	local data = export.make_data(frame)
	local ins_text = {}
	for key, val in pairs(data.forms) do
		local ins_form = {}
		if type(val) ~= "table" then
			val = {val}
		end
		for _, v in ipairs(val) do
			-- skip forms with HTML or links in them
			if v ~= "-" and v ~= "—" and v ~= "&mdash;" and not v:find("[<>=|%[%]]") then
				table.insert(ins_form, v)
			end
		end
		if #ins_form > 0 then
			table.insert(ins_text, key .. "=" .. table.concat(ins_form, ","))
		end
	end
	return table.concat(ins_text, "|")
end


function export.make_data(frame)
	local args = frame:getParent().args
	local conj_type = frame.args[1] or if_not_empty(args["conjtype"]) or error("Conjugation type has not been specified. Please pass parameter 1 to the module invocation")
	local subtype = frame.args["type"] or args["type"]; if subtype == nil then subtype = '' end
	local sync_perf = args["sync_perf"]; if sync_perf == nil then sync_perf = '' end
	local p3inf = args["p3inf"]; if p3inf == nil then p3inf = '' end
	
	if not conjugations[conj_type] then
		error("Unknown conjugation type '" .. conj_type .. "'")
	end
	
	local data = {forms = {}, title = {}, categories = {}, form_footnote_indices = {}, footnotes = {}}  --note: the addition of red superscripted footnotes ('<sup style="color: red">' ... </sup>) is only implemented for the three form printing loops in which it is used
	local typeinfo = {conj_type = conj_type, subtype = subtype, sync_perf = sync_perf, p3inf = p3inf}
	
	-- Generate the verb forms
	conjugations[conj_type](args, data, typeinfo)
	
	-- Override with user-set forms
	override(data, args)
	
	-- Post-process the forms
	postprocess(data, typeinfo)
	
	-- Check if the links to the verb forms exist
	checkexist(data)
	
	-- Check if the verb is irregular
	if not conj_type == 'irreg' then checkirregular(args, data) end
	return data
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
	
	data.forms["perf_pasv_indc"] = ppplink .. " + present active indicative of " .. sumlink
	data.forms["futp_pasv_indc"] = ppplink .. " + future active indicative of " .. sumlink
	data.forms["plup_pasv_indc"] = ppplink .. " + imperfect active indicative of " .. sumlink
	data.forms["perf_pasv_subj"] = ppplink .. " + present active subjunctive of " .. sumlink
	data.forms["plup_pasv_subj"] = ppplink .. " + imperfect active subjunctive of " .. sumlink
end

postprocess = function(data, typeinfo)
	-- Add information for the passive perfective forms
	if data.forms["perf_pasv_ptc"] and not form_contains(data.forms["perf_pasv_ptc"], "&mdash;") then
		if typeinfo.subtype == "pass-impers" then
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
		elseif typeinfo.subtype == "pass-3only" then
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
	
	-- Types of irregularity related primarily to the active.
	-- These could in theory be combined with those related to the passive and imperative,
	-- i.e. there's no reason there couldn't be an impersonal deponent verb with no imperatives.
	if typeinfo.subtype == "impers" then
		-- Impersonal verbs have only third-person singular forms.
		table.insert(data.title, "[[impersonal]]")
		table.insert(data.categories, "Latin impersonal verbs")
		
		-- Remove all non-3sg forms
		for key, _ in pairs(data.forms) do
			if key:find("^[12][sp]") or key:find("^3p") then
				data.forms[key] = nil
			end
		end
	elseif typeinfo.subtype == "impers-nopass" then
		-- Impersonal verbs have only third-person singular forms.
		table.insert(data.title, "[[impersonal]]")
		table.insert(data.title, "active only")
		table.insert(data.categories, "Latin impersonal verbs")
		table.insert(data.categories, "Latin active-only verbs")
		
		-- Remove all non-3sg and passive forms
		for key, _ in pairs(data.forms) do
			if key:find("^[12][sp]") or key:find("^3p") or key:find("pasv") then
				data.forms[key] = nil
			end
		end
	elseif typeinfo.subtype == "impers-depon" then
		-- Impersonal verbs have only third-person singular forms.
		table.insert(data.title, "[[impersonal]]")
		table.insert(data.title, "[[deponent]]")
		table.insert(data.categories, "Latin impersonal verbs")
		table.insert(data.categories, "Latin deponent verbs")
		
		-- Remove all non-3sg and active forms and future passive infinitive
		for key, _ in pairs(data.forms) do
			if key:find("^[12][sp]") or key:find("^3p") or key:find("actv") and key ~= "pres_actv_ptc" and key ~= "futr_actv_ptc" or key == "futr_pasv_inf" then
				data.forms[key] = nil
			end
		end
		
		-- Change passive to active
		for key, form in pairs(data.forms) do
			if key:find("pasv") and key ~= "pres_pasv_ptc" and key ~= "futr_pasv_ptc" then
				data.forms[key:gsub("pasv", "actv")] = form
				data.forms[key] = nil
			end
		end
	elseif typeinfo.subtype == "3only" then
		table.insert(data.title, "[[impersonal]]")
		table.insert(data.categories, "Latin impersonal verbs")
		
		-- Remove all non-3sg forms
		for key, _ in pairs(data.forms) do
			if key:find("^[12][sp]") then
				data.forms[key] = nil
			end
		end
	elseif typeinfo.subtype == "3only-nopass" then
		table.insert(data.title, "[[impersonal]]")
		table.insert(data.title, "active only")
		table.insert(data.categories, "Latin impersonal verbs")
		table.insert(data.categories, "Latin active-only verbs")
		
		-- Remove all non-3sg and passive forms
		for key, _ in pairs(data.forms) do
			if key:find("^[12][sp]") or key:find("pasv") then
				data.forms[key] = nil
			end
		end
	elseif typeinfo.subtype == "3only-depon" then
		table.insert(data.title, "[[impersonal]]")
		table.insert(data.title, "[[deponent]]")
		table.insert(data.categories, "Latin impersonal verbs")
		table.insert(data.categories, "Latin deponent verbs")
		
		-- Remove all non-3sg and active forms and future passive infinitive
		for key, _ in pairs(data.forms) do
			if key:find("^[12][sp]") or key:find("actv") and key ~= "pres_actv_ptc" and key ~= "futr_actv_ptc" or key == "futr_pasv_inf" then
				data.forms[key] = nil
			end
		end
		
		-- Change passive to active
		for key, form in pairs(data.forms) do
			if key:find("pasv") and key ~= "pres_pasv_ptc" and key ~= "futr_pasv_ptc" then
				data.forms[key:gsub("pasv", "actv")] = form
				data.forms[key] = nil
			end
		end
	end
	
	-- Handle certain irregularities in the passive
	if typeinfo.subtype == "depon" then
		-- Deponent verbs use passive forms with active meaning
		table.insert(data.title, "[[deponent]]")
		table.insert(data.categories, "Latin deponent verbs")
		
		-- Remove active forms and future passive infinitive
		for key, _ in pairs(data.forms) do
			if key:find("actv") and key ~= "pres_actv_ptc" and key ~= "futr_actv_ptc" and key ~= "futr_actv_inf" or key == "futr_pasv_inf" then
				data.forms[key] = nil
			end
		end
		
		-- Change passive to active
		for key, form in pairs(data.forms) do
			if key:find("pasv") and key ~= "pres_pasv_ptc" and key ~= "futr_pasv_ptc" and key ~= "futr_pasv_inf" then
				data.forms[key:gsub("pasv", "actv")] = form
				data.forms[key] = nil
			end
		end
	
		-- Generate correct form of infinitive for nominative gerund
		data.forms["ger_nom"] = data.forms["pres_actv_inf"]
		
	elseif typeinfo.subtype == "semi-depon" then
		-- Semi-deponent verbs use perfective passive forms with active meaning,
		-- and have no imperfective passive
		table.insert(data.title, "[[semi-deponent]]")
		table.insert(data.categories, "Latin semi-deponent verbs")
		
		-- Remove perfective active and imperfective passive forms
		for key, _ in pairs(data.forms) do
			if key:find("perf_actv") or key:find("plup_actv") or key:find("futp_actv") or key:find("pres_pasv") or key:find("impf_pasv") or key:find("futr_pasv") then
				data.forms[key] = nil
			end
		end
		
		-- Change perfective passive to active
		for key, form in pairs(data.forms) do
			if key:find("perf_pasv") or key:find("plup_pasv") or key:find("futp_pasv") then
				data.forms[key:gsub("pasv", "actv")] = form
				data.forms[key] = nil
			end
		end
	elseif typeinfo.subtype == "depon-noperf" then --(e.g. calvor, -ī)
		table.insert(data.title, "[[deponent]]")
		table.insert(data.categories, "Latin deponent verbs")
		table.insert(data.title, "[[defective verb|defective]]")
		table.insert(data.categories, "Latin defective verbs")
		
		-- Remove active forms and future passive infinitive
		for key, _ in pairs(data.forms) do
			if key:find("actv") and key ~= "pres_actv_ptc" and key ~= "futr_actv_ptc" and key ~= "futr_actv_inf" or key == "futr_pasv_inf" then
				data.forms[key] = nil
			end
		end
		
		-- Change passive to active
		for key, form in pairs(data.forms) do
			if key:find("pasv") and key ~= "pres_pasv_ptc" and key ~= "futr_pasv_ptc" and key ~= "futr_pasv_inf" then
				data.forms[key:gsub("pasv", "actv")] = form
				data.forms[key] = nil
			end
		end
		
		-- Remove all perfect forms
		for key, _ in pairs(data.forms) do
			if key:find("perf") or key:find("plup") or key:find("futp") then
				data.forms[key] = nil
			end
		end
	elseif typeinfo.subtype == "noperf" then
		-- Some verbs have no perfect forms (e.g. inalbēscō, -ěre)
		table.insert(data.title, "[[defective verb|defective]]")
		table.insert(data.categories, "Latin defective verbs")

		-- Remove all perfect forms
		for key, _ in pairs(data.forms) do
			if key:find("perf") or key:find("plup") or key:find("futp") then
				data.forms[key] = nil
			end
		end
	elseif typeinfo.subtype == "no-actv-perf" then
		-- Some verbs have no active perfect forms (e.g. interstinguō, -ěre)
		table.insert(data.title, "no active perfect forms")
		table.insert(data.categories, "Latin defective verbs")
		
		-- Remove all active perfect forms
		for key, _ in pairs(data.forms) do
			if key:find("actv") and (key:find("perf") or key:find("plup") or key:find("futp")) then
				data.forms[key] = nil
			end
		end
	elseif typeinfo.subtype == "no-pasv-perf" then
		-- Some verbs have no passive perfect forms (e.g. ārēscō, -ěre)
		table.insert(data.title, "no passive perfect forms")
		table.insert(data.categories, "Latin defective verbs")
		
		-- Remove all passive perfect forms
		for key, _ in pairs(data.forms) do
			if key:find("pasv") and (key:find("perf") or key:find("plup") or key:find("futp")) then
				data.forms[key] = nil
			end
		end
	elseif typeinfo.subtype == "nopass-noperf" then
		-- Some verbs have no passive and no perfect forms (e.g. albēscō, -ěre)
		table.insert(data.title, "[[defective verb|defective]]")
		table.insert(data.title, "active only")
		table.insert(data.categories, "Latin defective verbs")
		table.insert(data.categories, "Latin active-only verbs")
		
		-- Remove all passive and all perfect forms
		for key, _ in pairs(data.forms) do
			if key:find("pasv") or key:find("perf") or key:find("plup") or key:find("futp") then
				data.forms[key] = nil
			end
		end
	elseif typeinfo.subtype == "nopass" or typeinfo.subtype == "nopass-noimp" then
		-- Some verbs have no passive forms (usually intransitive)
		table.insert(data.title, "active only")
		table.insert(data.categories, "Latin active-only verbs")
		
		-- Remove all passive forms
		for key, _ in pairs(data.forms) do
			if key:find("pasv") then
				data.forms[key] = nil
			end
		end
	elseif typeinfo.subtype == "pass-3only" then
		-- Some verbs have only third-person forms in the passive
		table.insert(data.title, "only third-person forms in passive")
		table.insert(data.categories, "Latin verbs with third-person passive")
		
		-- Remove all non-3rd-person passive forms and all passive imperatives
		for key, _ in pairs(data.forms) do
			if key:find("pasv") and (key:find("^[12][sp]") or key:find("impr")) then
				data.forms[key] = nil
			end
		end
	elseif typeinfo.subtype == "pass-impers" then
		-- Some verbs are impersonal in the passive
		table.insert(data.title, "[[impersonal]] in passive")
		table.insert(data.categories, "Latin verbs with impersonal passive")
		
		-- Remove all non-3sg passive forms
		for key, _ in pairs(data.forms) do
			if key:find("pasv") and (key:find("^[12][sp]") or key:find("^3p") or key:find("impr")) or key:find("futr_pasv_inf") then
				data.forms[key] = nil
			end
		end
		
	elseif typeinfo.subtype == "perf-as-pres" then
		-- Perfect forms as present tense
		table.insert(data.title, "active only")
		table.insert(data.title, "[[perfect]] forms as present")
		table.insert(data.title, "pluperfect as imperfect")
		table.insert(data.title, "future perfect as future")
		table.insert(data.categories, "Latin defective verbs")
		table.insert(data.categories, "Latin active-only verbs")
        table.insert(data.categories, "Latin verbs with perfect forms having imperfective meanings")
		
		-- Change perfect passive participle to perfect active participle
		data.forms["perf_actv_ptc"] = data.forms["perf_pasv_ptc"]
		
		-- Change perfect active infinitive to present active infinitive
		data.forms["pres_actv_inf"] = data.forms["perf_actv_inf"]
		
		-- Remove passive forms
		-- Remove present active, imperfect active and future active forms
		for key, _ in pairs(data.forms) do
			if key ~= "futr_actv_inf" and key ~= "futr_actv_ptc" and (key:find("pasv") or key:find("pres") and key ~= "pres_actv_inf" or key:find("impf") or key:find("futr")) then
				data.forms[key] = nil
			end
		end

		-- Change perfect forms to non-perfect forms
		for key, form in pairs(data.forms) do
			if key:find("perf") and key ~= "perf_actv_ptc" then
				data.forms[key:gsub("perf", "pres")] = form
				data.forms[key] = nil
			elseif key:find("plup") then
				data.forms[key:gsub("plup", "impf")] = form
				data.forms[key] = nil
			elseif key:find("futp") then
				data.forms[key:gsub("futp", "futr")] = form
				data.forms[key] = nil
			elseif key:find("ger") then
				data.forms[key] = nil
			end
		end
		
		data.forms["pres_actv_ptc"] = nil
	elseif typeinfo.subtype == "memini" then
		-- Perfect forms as present tense
		table.insert(data.title, "active only")
		table.insert(data.title, "[[perfect]] forms as present")
		table.insert(data.title, "pluperfect as imperfect")
		table.insert(data.title, "future perfect as future")
		table.insert(data.categories, "Latin defective verbs")
		table.insert(data.categories, "Latin verbs with perfect forms having imperfective meanings")

		-- Remove passive forms
		-- Remove present active, imperfect active and future active forms
		-- Except for future active imperatives
		for key, _ in pairs(data.forms) do
			if key:find("pasv") or key:find("pres") or key:find("impf") or key:find("futr") or key:find("ptc") or key:find("ger") then
				data.forms[key] = nil
			end
		end

		-- Change perfect forms to non-perfect forms
		for key, form in pairs(data.forms) do
			if key:find("perf") and key ~= "perf_actv_ptc" then
				data.forms[key:gsub("perf", "pres")] = form
				data.forms[key] = nil
			elseif key:find("plup") then
				data.forms[key:gsub("plup", "impf")] = form
				data.forms[key] = nil
			elseif key:find("futp") then
				data.forms[key:gsub("futp", "futr")] = form
				data.forms[key] = nil
			end
		end
		
		-- Add imperative forms
		data.forms["2s_futr_actv_impr"] = "mementō"
		data.forms["2p_futr_actv_impr"] = "mementōte"
	end

	-- Handle certain irregularities in the imperative
	if typeinfo.subtype == "noimp" or typeinfo.subtype == "nopass-noimp" then
		-- Some verbs have no imperatives
		table.insert(data.title, "no [[imperative]]s")
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
	if typeinfo.p3inf == '1' then
			local form, noteindex = "pres_"..(typeinfo.subtype=='depon' and "actv" or "pasv").."_inf", #(data.footnotes)+1
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
			if typeinfo.subtype == 'depon' then
				data.form_footnote_indices["ger_nom"] = tostring(noteindex)
				data.forms['ger_nom'] = data.forms[form]
			end
			data.footnotes[noteindex] = 'The present passive infinitive in -ier is a rare poetic form which is attested for this verb.'
	end
	
	--Add the syncopated perfect forms, omitting the separately handled fourth conjugation cases
	
	if typeinfo.sync_perf == 'poet' then
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
	if typeinfo.subtype:find("depon") then
		-- Deponent and semi-deponent verbs don't have the perfective principal part
		typeinfo.pres_stem = if_not_empty(args[1])
		typeinfo.perf_stem = nil
		typeinfo.supine_stem = if_not_empty(args[2])
	else
		typeinfo.pres_stem = if_not_empty(args[1])
		typeinfo.perf_stem = if_not_empty(args[2])
		typeinfo.supine_stem = if_not_empty(args[3])
	end
	
	if (typeinfo.subtype == "perf-as-pres" or typeinfo.subtype == "memini") and not typeinfo.pres_stem then typeinfo.pres_stem = "whatever" end
	
	-- Prepare stems
	if not typeinfo.pres_stem then
		if NAMESPACE == "Template" then
			typeinfo.pres_stem = "-"
		else
			error("Present stem has not been provided")
		end
	end
	
	if not typeinfo.perf_stem and not typeinfo.subtype:find("depon") and not typeinfo.subtype:find("noperf") then
		if typeinfo.conj_type == "1st" then
			typeinfo.perf_stem = typeinfo.pres_stem .. "āv"
		elseif NAMESPACE == "Template" then
			typeinfo.perf_stem = "-"
		else
			error("Perfect stem has not been provided")
		end
	end

	if typeinfo.perf_stem then
		typeinfo.perf_stem = mw.text.split(typeinfo.perf_stem, "/")
	else
		typeinfo.perf_stem = {}
	end

	if not typeinfo.supine_stem and not typeinfo.subtype:find("nopass") and not typeinfo.subtype:find("noperf") and typeinfo.subtype ~= "no-pasv-perf" and typeinfo.subtype ~= "memini" and typeinfo.subtype ~= "pass-3only" then
		if typeinfo.conj_type == "1st" then
			typeinfo.supine_stem = typeinfo.pres_stem .. "āt"
		elseif NAMESPACE == "Template" then
			typeinfo.supine_stem = "-"
		else
			error("Supine stem has not been provided")
		end
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
	make_perf(data, typeinfo.perf_stem)
	make_supine(data, typeinfo.supine_stem)
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
	make_perf(data, typeinfo.perf_stem)
	make_supine(data, typeinfo.supine_stem)
end

conjugations["3rd"] = function(args, data, typeinfo)
	get_regular_stems(args, typeinfo)
	
	table.insert(data.title, "[[Appendix:Latin third conjugation|third conjugation]]")
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
	
	if typeinfo.pres_stem and mw.ustring.match(typeinfo.pres_stem,"[āēīōū]sc$") then
		table.insert(data.categories, "Latin inchoative verbs")
	end
	
	make_pres_3rd(data, typeinfo.pres_stem)
	make_perf(data, typeinfo.perf_stem)
	make_supine(data, typeinfo.supine_stem)
end

conjugations["3rd-io"] = function(args, data, typeinfo)
	get_regular_stems(args, typeinfo)
	
	table.insert(data.title, "[[Appendix:Latin third conjugation|third conjugation]] ''iō''-variant")
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
	
	make_pres_3rd_io(data, typeinfo.pres_stem)
	make_perf(data, typeinfo.perf_stem)
	make_supine(data, typeinfo.supine_stem)
end

local function ivi_ive(form)
	form = form:gsub("%.īvī", "iī")
	form = form:gsub("%.īvi", "ī")
	form = form:gsub("%.īve", "ī")
	form = form:gsub("%.īvē", "ē")
	return form
end

conjugations["4th"] = function(args, data, typeinfo)
	get_regular_stems(args, typeinfo)
	
	table.insert(data.title, "[[Appendix:Latin fourth conjugation|fourth conjugation]]")
	table.insert(data.categories, "Latin fourth conjugation verbs")
	
	
	for _, perf_stem in ipairs(typeinfo.perf_stem) do
		local pres_stem = typeinfo.pres_stem
		pres_stem = pres_stem:gsub("qu", "1")
		perf_stem = perf_stem:gsub("qu", "1"):gsub("%.", "")
		if perf_stem == pres_stem .. "īv" then
			table.insert(data.categories, "Latin fourth conjugation verbs with perfect in -iv-")
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
	make_perf(data, typeinfo.perf_stem)
	make_supine(data, typeinfo.supine_stem)
	
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
	
	if typeinfo.sync_perf == "y" or typeinfo.sync_perf == "yn" then
		for key, form in pairs(data.forms) do
			if key:find("perf") or key:find("plup") or key:find("futp") then
				local forms = data.forms[key]
				if type(forms) ~= "table" then
					forms = {forms}
				end
				data.forms[key] = {}
				for _, f in ipairs(forms) do
					if typeinfo.sync_perf == "yn" then
						-- fuckme, need to assign to local to discard second value
						local fsub = f:gsub("%.", "")
						ut.insert_if_not(data.forms[key], fsub)
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
	local verb = if_not_empty(args[1])
	local prefix = if_not_empty(args[2])
	
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
	table.insert(data.title, "[[suppletive]] in the supine stem")
	table.insert(data.categories, "Latin third conjugation verbs")
	table.insert(data.categories, "Latin irregular verbs")
	table.insert(data.categories, "Latin suppletive verbs")
	
	local prefix = typeinfo.prefix or ""
	
	typeinfo.subtype = "semi-depon"

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
	local prefix_perf = if_not_empty(args[3])
	local prefix_supine = if_not_empty(args[4])
	
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
	
	typeinfo.subtype = "nopass"
	local prefix = typeinfo.prefix or ""
	
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
	
	typeinfo.subtype = "nopass"
	
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
	
	typeinfo.subtype = "nopass-noimp"
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
	
	typeinfo.subtype = "nopass-noimp"
	make_perf(data, "mālu")
	
	-- Active imperfective indicative
	add_forms(data, "pres_actv_indc", "",
		"mālō", "māvīs", "māvult", "mālumus", "māvultis", "mālunt")
	volo_malo_nolo(data, "māl", "māl")
end

irreg_conjugations["nolo"] = function(args, data, typeinfo)
	table.insert(data.title, "[[Appendix:Latin irregular verbs|irregular]]")
	table.insert(data.categories, "Latin irregular verbs")
	
	typeinfo.subtype = "nopass"
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
	
	typeinfo.subtype = "nopass"
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

irreg_conjugations["soleo"] = function(args, data, typeinfo)
	table.insert(data.title, "[[Appendix:Latin second conjugation|second conjugation]]")
	table.insert(data.title, "[[semi-deponent]]")
	table.insert(data.title, "no [[future]]")
	table.insert(data.categories, "Latin second conjugation verbs")
	table.insert(data.categories, "Latin semi-deponent verbs")
	table.insert(data.categories, "Latin defective verbs")
	
	local prefix = typeinfo.prefix or ""
	
	make_pres_2nd(data, prefix .. "sol", "nopass", "noimpr")
	make_perf(data, prefix .. "solu", "noinf")
	make_deponent_perf(data, prefix .. "solit")
	-- There isn't any future, so clear out the future forms.
	clear_forms(data, "futr_actv_indc")
	clear_forms(data, "futp_actv_indc")
	clear_form(data, "futr_actv_inf")
	clear_form(data, "futr_actv_ptc")
end

irreg_conjugations["audeo"] = function(args, data, typeinfo)
	table.insert(data.title, "[[Appendix:Latin second conjugation|second conjugation]]")
	table.insert(data.title, "[[semi-deponent]]")
	table.insert(data.categories, "Latin second conjugation verbs")
	table.insert(data.categories, "Latin semi-deponent verbs")
	table.insert(data.categories, "Latin defective verbs")
	
	local prefix = typeinfo.prefix or ""
	
	make_pres_2nd(data, prefix .. "aud", "nopass", "noimpr")
	make_perf(data, prefix .. "aus", "noinf")
	make_deponent_perf(data, prefix .. "aus")
end

irreg_conjugations["placeo"] = function(args, data, typeinfo)
	table.insert(data.title, "[[Appendix:Latin second conjugation|second conjugation]]")
	table.insert(data.title, "[[semi-deponent]]")
	table.insert(data.categories, "Latin second conjugation verbs")
	table.insert(data.categories, "Latin semi-deponent verbs")
	table.insert(data.categories, "Latin defective verbs")
	
	local prefix = typeinfo.prefix or ""
	
	make_pres_2nd(data, prefix .. "plac", "nopass", "noimpr")
	make_perf(data, prefix .. "placu", "noinf")
	make_deponent_perf(data, prefix .. "placit")
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
	local prefix_d = if_not_empty(args[3])
	prefix_d = prefix_d or prefix
	local prefix_f = if_not_empty(args[4]); if prefix == "ab" then prefix_f = "ā" end
	prefix_f = prefix_f or prefix
	-- The vowel of the prefix is lengthened if it ends in -n and the next word begins with f- or s-.
	local prefix_long = prefix:gsub("([aeiou]n)$", {["an"] = "ān", ["en"] = "ēn", ["in"] = "īn", ["on"] = "ōn", ["un"] = "ūn"})
	prefix_f = prefix_f:gsub("([aeiou]n)$", {["an"] = "ān", ["en"] = "ēn", ["in"] = "īn", ["on"] = "ōn", ["un"] = "ūn"})
	
	typeinfo.subtype = "nopass"
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
		add_form(data, "futr_actv_inf", stem, "ūrus esse")
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

local function show_form(form)
	if not form then
		return "&mdash;"
	end
	
	if type(form) == "table" then
		for key, subform in ipairs(form) do
			if subform == "-" or subform == "—" or subform == "&mdash;" then
				form[key] = "&mdash;"
			elseif reconstructed and not subform:find(NAMESPACE .. ":Latin/")then
				form[key] = make_link({lang = lang, term = NAMESPACE .. ":Latin/" .. subform, alt = subform})
			else
				form[key] = make_link({lang = lang, term = subform})
			end
		end
		
		return table.concat(form, ", ")
	else
		if form == "-" or form == "—" or form == "&mdash;" then
			return "&mdash;"
		elseif reconstructed and not form:find(NAMESPACE .. ":Latin/") then
			return make_link({lang = lang, term = NAMESPACE .. ":Latin/" .. form, alt = form})
		else
			return make_link({lang = lang, term = form})
		end
	end
end

-- Make the table
make_table = function(data)
	local pagename = PAGENAME
	if reconstructed then
		pagename = pagename:gsub("Latin/","")
	end
	return [=[
{| style="width: 100%; background: #EEE; border: 1px solid #AAA; font-size: 95%; text-align: center;" class="inflection-table vsSwitcher vsToggleCategory-inflection"
|-
! colspan="8" class="vsToggleElement" style="background: #CCC; text-align: left;" | &nbsp;&nbsp;&nbsp;Conjugation of ]=] .. make_link({lang = lang, alt = pagename}, "term") .. (#data.title > 0 and " (" .. table.concat(data.title, ", ") .. ")" or "") .. [=[

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
					local form = p .. "_" .. t .. "_" .. v .. "_indc"
					row[col] = "\n| " .. show_form(data.forms[form])..(data.form_footnote_indices[form]==nil and "" or '<sup style="color: red">'..data.form_footnote_indices[form].."</sup>")
					
					if data.forms[p .. "_" .. t .. "_" .. v .. "_indc"] then
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
					local form = p .. "_" .. t .. "_" .. v .. "_subj"
					row[col] = "\n| " .. show_form(data.forms[form])..(data.form_footnote_indices[form]==nil and "" or '<sup style="color: red">'..data.form_footnote_indices[form].."</sup>")
					
					if data.forms[p .. "_" .. t .. "_" .. v .. "_subj"] then
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
					row[col] = "\n| " .. show_form(data.forms[p .. "_" .. t .. "_" .. v .. "_impr"])
					
					if data.forms[p .. "_" .. t .. "_" .. v .. "_impr"] then
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
			--row[col] = "\n| " .. show_form(data.forms[t .. "_" .. f])
			local form = t .. "_" .. f
			row[col] = "\n| " .. show_form(data.forms[form])..(data.form_footnote_indices[form]==nil and "" or '<sup style="color: red">'..data.form_footnote_indices[form].."</sup>")
			
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
		
	for col, n in ipairs({"ger_nom", "ger_gen", "ger_dat", "ger_acc", "sup_acc", "sup_abl"}) do
		if data.forms[n] then
			has_vn = true
		end
		row[col] = "\n| " .. show_form(data.forms[n])..(data.form_footnote_indices[n]==nil and "" or '<sup style="color: red">'..data.form_footnote_indices[n].."</sup>")
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
	local function handle_form(form)
		if args[form] then
			data.forms[form] = show_form(mw.text.split(args[form], "/"))
		end
	end
	for _, v in ipairs({"actv", "pasv"}) do
		local function handle_tense(t, mood)
			local non_pers_form = t .. "_" .. v .. "_" .. mood
			if args[non_pers_form] then
				handle_form(non_pers_form)
			else
				for _, p in ipairs({"1s", "2s", "3s", "1p", "2p", "3p"}) do
					handle_form(p .. "_" .. non_pers_form)
				end
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
			handle_form(t .. "_" .. f)
		end
	end
	for _, n in ipairs({"ger_nom", "ger_gen", "ger_dat", "ger_acc", "sup_acc", "sup_abl"}) do
		handle_form(n)
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
				if not conj:find(" ") then
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
