local m_links = require("Module:links")
local strutils = require("Module:string utilities")

local lang = require("Module:languages").getByCode("ang")

local export = {}

local cases = { "nom", "acc", "gen", "dat" }
local numbers = { "sg", "pl" }
local slots_to_accel_form = {}
for _, case in ipairs(cases) do
	for _, number in ipairs(numbers) do
		slots_to_accel_form[case .. "_" .. number] = case .. "|" .. number
	end
end

local slots_to_args = {
	nom_sg = 1,
	nom_pl = 2,
	acc_sg = 3,
	acc_pl = 4,
	gen_sg = 5,
	gen_pl = 6,
	dat_sg = 7,
	dat_pl = 8,
}

function export.make_table(frame)
	local parent_args = frame:getParent().args
	local params = {
		["title"] = {},
		["type"] = {},
		["width"] = {},
		["style"] = {},
		["num"] = {},
		["g"] = {},
		["gender"] = {alias_of = "g"},
	}
	for slot, arg in pairs(slots_to_args) do
		params[arg] = {list = slot}
	end
	
	local args = require("Module:parameters").process(parent_args, params)
	local title = args.title
	if not title then
		local curtitle = mw.title.getCurrentTitle()
		title = "Declension of ''" .. (
			curtitle.baseText == "Old English" and "*" .. curtitle.subpageText or
			curtitle.text
		) .. "''"
		if args["type"] then
			title = title .. "&nbsp;(" .. args["type"] .. ")"
		end
		if args.g then
			title = title .. "&nbsp;(" .. (
				args.g == "m" and "masculine" or
				args.g == "f" and "feminine" or
				args.g == "n" and "neuter" or
				error("Unrecognized gender '" .. args.g .. "'")
			) .. ")"
		end
	end
	local table_args = {
		title = title,
		style = args.style == "right" and "float:right; clear:right;" or "",
		width = args.width or "30",
	}
	local accel_lemma_sg = args[slots_to_args.nom_sg][1]
	local accel_lemma_pl = args[slots_to_args.nom_pl][1]
	local accel_lemma =
		accel_lemma_sg and accel_lemma_sg ~= "—" and accel_lemma_sg ~= "-" and accel_lemma_sg:gsub(",.*", "") or
		accel_lemma_pl and accel_lemma_pl ~= "—" and accel_lemma_pl ~= "-" and accel_lemma_pl:gsub(",.*", "") or
		nil
	for slot, accel_form in pairs(slots_to_accel_form) do
		local form_args = args[slots_to_args[slot]]
		if #form_args == 0 then
			form_args = {"—"}
		end
		local forms = {}
		for _, form_arg in ipairs(form_args) do
			for _, form in ipairs(mw.text.split(form_arg, ", *")) do
				table.insert(forms, form)
			end
		end
		local table_arg = {}
		for _, form in ipairs(forms) do
			table.insert(table_arg, form == "—" and form or m_links.full_link{
				lang = lang, term = form, accel = {
					form = accel_form,
					lemma = accel_lemma,
				}
			})
			table_args[slot] = table.concat(table_arg, ", ")
		end
	end
	if args.num == "pl" then
		table_args.nom_sg = "—"
		table_args.acc_sg = "—"
		table_args.gen_sg = "—"
		table_args.dat_sg = "—"
	elseif args.num == "sg" then
		table_args.nom_pl = "—"
		table_args.acc_pl = "—"
		table_args.gen_pl = "—"
		table_args.dat_pl = "—"
	end

	local table = [=[
<div class="NavFrame" style="{style}width:{width}em">
<div class="NavHead" style="background:#eff7ff">{title}
</div>
<div class="NavContent">
{\op}| style="background: #F9F9F9; text-align:left; width:{width}em" class="inflection-table"
! [[case|Case]]
! style="background: #EFEFFF; font-size: 90%; width: 50%"|[[singular|Singular]]
! style="background: #EFEFFF; font-size: 90%; width: 50%"|[[plural|Plural]]
|-
! style="background: #EFEFFF; text-align: left; font-size: 90%;"| [[nominative case|nominative]]
| {nom_sg}
| {nom_pl}
|-
! style="background: #EFEFFF; text-align: left; font-size: 90%;"| [[accusative case|accusative]]
| {acc_sg}
| {acc_pl}
|-
! style="background: #EFEFFF; text-align: left; font-size: 90%;"| [[genitive case|genitive]]
| {gen_sg}
| {gen_pl}
|-
! style="background: #EFEFFF; text-align: left; font-size: 90%;"| [[dative case|dative]]
| {dat_sg}
| {dat_pl}
|{\cl}</div></div>]=]
	return strutils.format(table, table_args)
end

local nouns = {}

nouns["m.a"] = function(data)
	add_ending(args, "nom_sg", data.bare or data.stem, "")
	add_ending(args, "acc_sg", data.bare or data.stem, "")
	add_ending(args, "gen_sg", data.stem, "es")
	add_ending(args, "dat_sg", data.stem, "e")
	add_ending(args, "nom_pl", data.pl or data.stem, "as")
	add_ending(args, "acc_pl", data.pl or data.stem, "as")
	add_ending(args, "gen_pl", data.pl or data.stem, "a")
	add_ending(args, "dat_pl", data.pl or data.stem, "um")
end

nouns["n.a"] = function(data)
	add_ending(args, "nom_sg", data.bare or data.stem, "")
	add_ending(args, "acc_sg", data.bare or data.stem, "")
	add_ending(args, "gen_sg", data.stem, "es")
	add_ending(args, "dat_sg", data.stem, "e")
	if data.short then
		add_ending(args, "nom_pl", data.pl or data.stem, "u")
		add_ending(args, "acc_pl", data.pl or data.stem, "u")
	else
		add_ending(args, "nom_pl", data.bare or data.stem, "")
		add_ending(args, "acc_pl", data.bare or data.stem, "")
	end
	add_ending(args, "gen_pl", data.pl or data.stem, "a")
	add_ending(args, "dat_pl", data.pl or data.stem, "um")
end

local function compute_noun_args(adjtype, bare, vstem, cstemn, cstemr, short, h)
	local args = {}
	local function add_ending(slot, stems, ending, construct_stem_ending)
		local function default_construct_stem_ending(stem, ending)
			if ending == "-" then
				return stem
			else
				return stem .. ending
			end
		end
		construct_stem_ending = construct_stem_ending or default_construct_stem_ending
		if type(stems) ~= "table" then
			stems = {stems}
		end
		if not args[slot] then
			args[slot] = {}
		end
		for _, stem in ipairs(stems) do
			local form = construct_stem_ending(stem, ending)
			if type(form) == "string" then
				ut.insert_if_not(args[slot], form)
			else
				for _, f in ipairs(form) do
					ut.insert_if_not(args[slot], f)
				end
			end
		end
	end

	local function compute_stem_for_ending(ending)
		if ending == "" then
			return bare
		elseif ending:find("^n") then
			return cstemn
		elseif ending:find("^r") then
			return cstemr
		else
			return vstem
		end
	end

	local function construct_h_stem_ending(stem, ending)
		-- Delete a vowel at the beginning of the ending. But -um can
		-- either assume the contracted form (-m) or the full form (-um).
		if ending == "um" then
			return {stem .. "m", stem .. "um"}
		elseif ending:find("^[aeiou%-]") then
			return stem .. ending:gsub("^.", "")
		else
			return stem .. ending
		end
	end

	local construct_stem_ending
	if h then
		construct_stem_ending = construct_h_stem_ending
	end

	local function add_row(slot_suffix, nom, acc, gen, dat, ins)
		local function add(slot_prefix, ending)
			if type(ending) ~= "table" then
				ending = {ending}
			end
			for _, e in ipairs(ending) do
				local stem = compute_stem_for_ending(e)
				add_ending(slot_prefix .. "_" .. slot_suffix, stem, e,
					construct_stem_ending)
			end
		end
		add("nom", nom)
		add("acc", acc)
		add("gen", gen)
		add("dat", dat)
		add("ins", ins)
	end

	if adjtype == "strong" then
		-- short == "h" is a special signal for adjectives in -h (esp. sċeolh, þweorh);
		-- use the vowel stem but have no ending.
		local short_ending = short == "opt" and {"", "u", "o"} or short == "h" and "-" or
			short and {"u", "o"} or ""
		add_row("sg_m", "", "ne", "es", "um", "e")
		add_row("sg_f", short_ending, "e", "re", "re", "re")
		add_row("sg_n", "", "", "es", "um", "e")
		add_row("pl_m", "e", "e", "ra", "um", "um")
		add_row("pl_f", {"a", "e"}, {"a", "e"}, "ra", "um", "um")
		add_row("pl_n", short_ending, short_ending, "ra", "um", "um")
	elseif adjtype == "weak" then
		add_row("sg_m", "a", "an", "an", "an", "an")
		add_row("sg_f", "e", "an", "an", "an", "an")
		add_row("sg_n", "e", "e", "an", "an", "an")
		add_row("pl_m", "an", "an", {"ra", "ena"}, "um", "um")
		add_row("pl_f", "an", "an", {"ra", "ena"}, "um", "um")
		add_row("pl_n", "an", "an", {"ra", "ena"}, "um", "um")
	else
		error("Unrecognized adjective type: '" .. adjtype .. "'")
	end

	return args
end

return export

-- For Vim, so we get 4-space tabs
-- vim: set ts=4 sw=4 noet:
