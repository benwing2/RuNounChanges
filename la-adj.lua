local export = {}

local lang = require("Module:languages").getByCode("la")
local m_links = require("Module:links")
local m_utilities = require("Module:utilities")

NAMESPACE = NAMESPACE or mw.title.getCurrentTitle().nsText
PAGENAME = PAGENAME or mw.title.getCurrentTitle().text

local decl = require("Module:la-adj/data")
local m_table = require("Module:la-adj/table")

local case_order = {
	"nom_sg_m",
	"gen_sg_m",
	"dat_sg_m",
	"acc_sg_m",
	"abl_sg_m",
	"voc_sg_m",
	"nom_sg_f",
	"gen_sg_f",
	"dat_sg_f",
	"acc_sg_f",
	"abl_sg_f",
	"voc_sg_f",
	"nom_sg_n",
	"gen_sg_n",
	"dat_sg_n",
	"acc_sg_n",
	"abl_sg_n",
	"voc_sg_n",
	"nom_pl_m",
	"gen_pl_m",
	"dat_pl_m",
	"acc_pl_m",
	"abl_pl_m",
	"voc_pl_m",
	"nom_pl_f",
	"gen_pl_f",
	"dat_pl_f",
	"acc_pl_f",
	"abl_pl_f",
	"voc_pl_f",
	"nom_pl_n",
	"gen_pl_n",
	"dat_pl_n",
	"acc_pl_n",
	"abl_pl_n",
	"voc_pl_n",
}

local function process_forms_and_overrides(data, args)
	local redlink = false
	if data.num == "pl" then
		table.insert(data.categories, "Latin plural-only adjectives")
	end
	
	local accel_lemma, accel_lemma_f
	if data.num and data.num ~= "" then
		accel_lemma = data.forms["nom_" .. data.num .. "_m"]
		accel_lemma_f = data.forms["nom_" .. data.num .. "_f"]
	else
		accel_lemma = data.forms["nom_sg_m"]
		accel_lemma_f = data.forms["nom_sg_f"]
	end
	
	for _, key in ipairs(case_order) do
		-- If noneut=1 passed, clear out all neuter forms.
		if data.noneut and key:find("_n") then
			data.forms[key] = nil
		end
		if args[key] or data.forms[key] then
			if args[key] then
				val = args[key]
				data.user_specified[key] = true
			else
				val = data.forms[key]
			end
			if type(val) == "string" then
				val = mw.text.split(val, "/")
			end
			if data.num == "pl" and key:find("sg") then
				data.forms[key] = ""
			elseif val[1] == "" or val == "" or val[1] == "-" or val[1] == "—" or val == "-" or val == "—" then
				data.forms[key] = "—"
			else
				for i, form in ipairs(val) do
					local word = data.prefix .. form .. data.suffix
					
					local accel_form = key
					accel_form = accel_form:gsub("_([sp])[gl]_", "|%1|")

					if data.noneut then
						-- If noneut=1, we're being asked to do a noun like
						-- Aquītānus or Rōmānus that has masculine and feminine
						-- variants, not an adjective. In that case, make the
						-- accelerators correspond to nomminal case/number forms
						-- without the gender, and use the feminine as the
						-- lemma for feminine forms.
						if key:find("_f") then
							data.accel[key .. i] = {form = accel_form:gsub("|f$", ""), lemma = accel_lemma_f}
						else
							data.accel[key .. i] = {form = accel_form:gsub("|m$", ""), lemma = accel_lemma}
						end
					else
						if not data.forms.nom_sg_n and not data.forms.nom_pl_n then
							-- use multipart tags if called for
							accel_form = accel_form:gsub("|m$", "|m//f//n")
						elseif not data.forms.nom_sg_f and not data.forms.nom_pl_f then
							accel_form = accel_form:gsub("|m$", "|m//f")
						end
						
						-- use the order nom|m|s, which is more standard than nom|s|m
						accel_form = accel_form:gsub("|(.-)|(.-)$", "|%2|%1")
					
						data.accel[key .. i] = {form = accel_form, lemma = accel_lemma}
					end
					val[i] = word
					if not redlink and NAMESPACE == '' then
						local title = lang:makeEntryName(word)
						local t = mw.title.new(title)
						if t and not t.exists then
							table.insert(data.categories, 'Latin adjectives with red links in their declension tables')
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
			data.forms[key] = table.concat(val, ", ")
		end
	end
	data.footnote = table.concat(notes, "<br />") .. data.footnote
end

local function generate_forms(frame)
	local data = {
		title = "",
		footnote = "",
		num = "",
		voc = true,
		forms = {},
		categories = {},
		notes = {},
		noteindex = {},
		user_specified = {},
		accel = {},
		noneut = false,
	}

	local args = frame:getParent().args
	local iargs = frame.args
	
	-- FIXME! Use [[Module:parameters]]
	data.subtype = iargs["type"] or args["type"] or ""
	data.num = iargs["num"] or args["num"] or ""
	data.prefix = args["prefix"] or ""
	data.suffix = args["suffix"] or ""
	local noneut = args["noneut"]
	data.noneut = not (not noneut or noneut == "" or noneut == "0" or noneut == "no" or noneut == "n" or noneut == "false")
	
	decl[iargs[1] or args["decltype"]](data, args)
	
	process_forms_and_overrides(data, args)

	if data.prefix .. data.suffix ~= "" then
		table.insert(data.categories, "Kenny's testing category 6")
	end

	return data
end

function export.show(frame)
	local data = generate_forms(frame)

	show_forms(data)
	
	return m_table.make_table(data) .. m_utilities.format_categories(data.categories, lang)
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
