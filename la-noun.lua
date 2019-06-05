local export = {}

local lang = require("Module:languages").getByCode("la")
local m_links = require("Module:links")
local m_utilities = require("Module:utilities")
local m_para = require("Module:parameters")

local current_title = mw.title.getCurrentTitle().nsText
local NAMESPACE = current_title.nsText
local PAGENAME = current_title.text

local decl = require("Module:la-noun/data")
local m_table = require("Module:la-noun/table")

-- Canonical order of cases
local case_order = {
	"nom_sg",
	"gen_sg",
	"dat_sg",
	"acc_sg",
	"abl_sg",
	"voc_sg",
	"loc_sg",
	"nom_pl",
	"gen_pl",
	"dat_pl",
	"acc_pl",
	"abl_pl",
	"voc_pl",
	"loc_pl"
}

local ligatures = {
	['Ae'] = 'Æ',
	['ae'] = 'æ',
	['Oe'] = 'Œ',
	['oe'] = 'œ',
}

local function process_forms_and_overrides(data, args)
	local redlink = false
	if data.num == "pl" and NAMESPACE == '' then
		table.insert(data.categories, "Latin pluralia tantum")
	elseif data.num == "sg" and NAMESPACE == '' then
		table.insert(data.categories, "Latin singularia tantum")
	end

	local accel_lemma
	if data.num and data.num ~= "" then
		accel_lemma = data.forms["nom_" .. data.num]
	else
		accel_lemma = data.forms["nom_sg"]
	end

	for _, key in ipairs(case_order) do
		if args[key] or data.forms[key] then
			local val
			if args[key] then
				val = args[key]
				data.user_specified[key] = true
			else
				val = data.forms[key]
			end
			if type(val) == "string" then
				val = mw.text.split(val, "/")
			end
			if (data.num == "pl" and key:find("sg")) or (data.num == "sg" and key:find("pl")) then
				data.forms[key] = ""
			elseif val[1] == "" or val[1] == "-" or val[1] == "—" then
				data.forms[key] = "—"
			else
				for i, form in ipairs(val) do
					local word = data.prefix .. (data.n and mw.ustring.gsub(form,"m$","n") or form) .. data.suffix
					if data.lig then
						word = word:gsub("[AaOo]e", ligatures)
					end
					
					local accel_form = key
					accel_form = accel_form:gsub("_([sp])[gl]$", "|%1")

					data.accel[key .. i] = {form = accel_form, lemma = accel_lemma}
					val[i] = word
					if not redlink and NAMESPACE == '' then
						local title = lang:makeEntryName(word)
						local t = mw.title.new(title)
						if t and not t.exists then
							table.insert(data.categories, 'Latin nouns with red links in their declension tables')
							redlink = true
						end
					end
				end
				data.forms[key] = val
			end
		end
	end
end

local function show_forms(data)
	local noteindex = 1
	local notes = {}
	for _, key in ipairs(case_order) do
		local val = data.forms[key]
		if val and val ~= "" and val ~= "—" then
			for i, form in ipairs(val) do
				local link = m_links.full_link({lang = lang, term = form, accel = data.accel[key .. i]})
				if (data.notes[key .. i] or data.noteindex[key .. i]) and not data.user_specified[key] then
					-- If the decl entry hasn't specified a footnote index, generate one.
					local this_noteindex = data.noteindex[key .. i]
					if not this_noteindex then
						this_noteindex = noteindex
						noteindex = noteindex + 1
						table.insert(notes, '<sup style="color: red">' .. this_noteindex .. '</sup>' .. data.notes[key .. i])
					end
					val[i] = link .. '<sup style="color: red">' .. this_noteindex .. '</sup>'
				else
					val[i] = link
				end
			end
			data.forms[key] = table.concat(val, "<br />")
		end
	end
	data.footnote = table.concat(notes, "<br />") .. data.footnote
end

local function make_table(data)
	if data.num == "sg" then
		return m_table.make_table_sg(data)
	elseif data.num == "pl" then
		return m_table.make_table_pl(data)
	else
		return m_table.make_table(data)
	end
end

local function generate_forms(frame)
	local data = {
		title = "",
		footnote = "",
		num = "",
		loc = false,
		um = false,
		forms = {},
		types = {},
		categories = {},
		notes = {},
		noteindex = {},
		user_specified = {},
		accel = {},
	}
	
	local iparams = {
		[1] = {},
		decl_type = {},
		num = {},
	}
	
	local iargs = m_para.process(frame.args, iparams)

	local parent_args = frame:getParent().args
	
	local decl_type = iargs.decl_type or parent_args.decl_type
	
	if decl_type and decl_type ~= "" then 
		for name, val in ipairs(mw.text.split(decl_type, "-")) do
			data.types[val] = true
		end
	end
	
	local params = {
		[1] = {required = true},
		decl = {},
		decl_type = {},
		noun = {},
		num = {},
		nom_sg = {},
		gen_sg = {},
		dat_sg = {},
		acc_sg = {},
		abl_sg = {},
		voc_sg = {},
		loc_sg = {},
		nom_pl = {},
		gen_pl = {},
		dat_pl = {},
		acc_pl = {},
		abl_pl = {},
		voc_pl = {},
		loc_pl = {},
		loc = {type = "boolean"},
		um = {type = "boolean"},
		genplum = {type = "boolean"},
		n = {type = "boolean"},
		lig = {type = "boolean"},
		prefix = {},
		suffix = {},
		footnote = {},
	}
	
	local decl_arg = iargs[1] or parent_args.decl
	
	if (decl_arg == "2" and data.types.er) or decl_arg == "3" then
		params[2] = {}
	end
	
	local args = m_para.process(parent_args, params)
	
	data.num = iargs.num or args.num or ""
	data.loc = args.loc
	data.lig = args.lig
	data.um = args.um or args.genplum
	data.prefix = args.prefix or ""
	data.suffix = args.suffix or ""
	data.footnote = args.footnote or ""
	data.n = args.n and (data.suffix ~= "") -- Must have a suffix and n specified
	
	decl[decl_arg](data, args)
	
	process_forms_and_overrides(data, args)
	
	if data.prefix .. data.suffix ~= "" then
		table.insert(data.categories, "Kenny's testing category 6")
	end

	return data
end
	
function export.show(frame)
	local data = generate_forms(frame)

	show_forms(data)
	
	return make_table(data) .. m_utilities.format_categories(data.categories, lang)
end

function export.generate_forms(frame)
	local data = generate_forms(frame)

	local ins_text = {}
	for _, key in ipairs(case_order) do
		local val = data.forms[key]
		if val and val ~= "" and val ~= "—" and #val > 0 then
			table.insert(ins_text, key .. "=" .. table.concat(val, ","))
		end
	end
	return table.concat(ins_text, "|")
end

return export

-- For Vim, so we get 4-space tabs
-- vim: set ts=4 sw=4 noet:
