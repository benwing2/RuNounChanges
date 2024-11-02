local lang = require("Module:languages").getByCode("inc-ash")
local m_links = require("Module:links")
local m_labels = require("Module:labels")
local iut = require("Module:inflection utilities")
local m_string_utilities = require("Module:string utilities")
local sub = mw.ustring.sub
local variety_data = require("Module:inc-ash/dial/data")

local export = {}

local variety_list = {
	"Central", "East", "Northwest", "West", "South"
}

local variety_colour = {
	["Central"]		= "FAF5F0",
	["East"]		= "F0F5FA",
	["Northwest"]	= "F0FAF3",
	["West"]		= "FAF0F6",
	["South"]		= "FAF9F0",
}

local dots = {
	"d2502e", "6941c7", "9fdd42", "c74dc9", "6ccb6e", 
	"d34280", "77d6ba", "4f286c", "d1b94e", "777ad0", 
	"557433", "cf8ebf", "342a29", "c7c3a2", "7f3241", 
	"8ab8d7", "8d6234", "5b6080", "da8573", "4e7a6e"
}

local special_note = {
	-- none yet
}

-- declension
local genders = {"m", "f", "n"}
local numbers = {"sg", "pl"}
local cases = {"nom", "acc", "ins", "dat", "abl", "gen", "loc"}
local cases_full = {"nominative", "accusative", "instrumental", "dative", "ablative", "genitive", "locative"}
local persons = {"1", "2", "3"}
local persons_full = {"1st", "2nd", "3rd"}
local moods = {"pres", "imp", "potn", "impf", "aor", "fut"}
local moods_full = {"present", "imperative", "potential", "imperfect", "aorist", "future"}

local slots = {}
slots["noun"] = {
	{"nom.sg", "nom|sg"}, {"nom.pl", "nom|pl"},
	{"acc.sg", "acc|sg"}, {"acc.pl", "acc|pl"},
	{"ins.sg", "ins|sg"}, {"ins.pl", "ins|pl"},
	{"dat.sg", "dat|sg"}, {"dat.pl", "dat|pl"},
	{"abl.sg", "abl|sg"}, {"abl.pl", "abl|pl"},
	{"gen.sg", "gen|sg"}, {"gen.pl", "gen|pl"},
	{"loc.sg", "loc|sg"}, {"loc.pl", "loc|pl"},
}
slots["adj"] = {
	{"m.nom.sg", "m|nom|sg"}, {"m.nom.pl", "m|nom|pl"}, {"f.nom.sg", "f|nom|sg"}, {"f.nom.pl", "f|nom|pl"}, {"n.nom.sg", "n|nom|sg"}, {"n.nom.pl", "n|nom|pl"},
	{"m.acc.sg", "m|acc|sg"}, {"m.acc.pl", "m|acc|pl"}, {"f.acc.sg", "f|acc|sg"}, {"f.acc.pl", "f|acc|pl"}, {"n.acc.sg", "n|acc|sg"}, {"n.acc.pl", "n|acc|pl"},
	{"m.ins.sg", "m|ins|sg"}, {"m.ins.pl", "m|ins|pl"}, {"f.ins.sg", "f|ins|sg"}, {"f.ins.pl", "f|ins|pl"}, {"n.ins.sg", "n|ins|sg"}, {"n.ins.pl", "n|ins|pl"},
	{"m.dat.sg", "m|dat|sg"}, {"m.dat.pl", "m|dat|pl"}, {"f.dat.sg", "f|dat|sg"}, {"f.dat.pl", "f|dat|pl"}, {"n.dat.sg", "n|dat|sg"}, {"n.dat.pl", "n|dat|pl"},
	{"m.abl.sg", "m|abl|sg"}, {"m.abl.pl", "m|abl|pl"}, {"f.abl.sg", "f|abl|sg"}, {"f.abl.pl", "f|abl|pl"}, {"n.abl.sg", "n|abl|sg"}, {"n.abl.pl", "n|abl|pl"},
	{"m.gen.sg", "m|gen|sg"}, {"m.gen.pl", "m|gen|pl"}, {"f.gen.sg", "f|gen|sg"}, {"f.gen.pl", "f|gen|pl"}, {"n.gen.sg", "n|gen|sg"}, {"n.gen.pl", "n|gen|pl"},
	{"m.loc.sg", "m|loc|sg"}, {"m.loc.pl", "m|loc|pl"}, {"f.loc.sg", "f|loc|sg"}, {"f.loc.pl", "f|loc|pl"}, {"n.loc.sg", "n|loc|sg"}, {"n.loc.pl", "n|loc|pl"},
}
slots["verb"] = {
	{"1sg.pres", "1|sg|pres"}, {"2sg.pres", "2|sg|pres"}, {"3sg.pres", "3|sg|pres" }, {"1pl.pres", "1|pl|pres"}, {"2pl.pres", "2|pl|pres"}, {"3pl.pres", "3|pl|pres" },
	-- add middle, passive
	{"1sg.imp", "1|sg|imp"}, {"2sg.imp", "2|sg|imp"}, {"3sg.imp", "3|sg|imp" }, {"1pl.imp", "1|pl|imp"}, {"2pl.imp", "2|pl|imp"}, {"3pl.imp", "3|pl|imp" },
	{"1sg.potn", "1|sg|potn"}, {"2sg.potn", "2|sg|potn"}, {"3sg.potn", "3|sg|potn" }, {"1pl.potn", "1|pl|potn"}, {"2pl.potn", "2|pl|potn"}, {"3pl.potn", "3|pl|potn" },
	{"1sg.impf", "1|sg|impf"}, {"2sg.impf", "2|sg|impf"}, {"3sg.impf", "3|sg|impf" }, {"1pl.impf", "1|pl|impf"}, {"2pl.impf", "2|pl|impf"}, {"3pl.impf", "3|pl|impf" },
	{"1sg.aor", "1|sg|aor"}, {"2sg.aor", "2|sg|aor"}, {"3sg.aor", "3|sg|aor" }, {"1pl.aor", "1|pl|aor"}, {"2pl.aor", "2|pl|aor"}, {"3pl.aor", "3|pl|aor" },
	{"1sg.fut", "1|sg|fut"}, {"2sg.fut", "2|sg|fut"}, {"3sg.fut", "3|sg|fut" }, {"1pl.fut", "1|pl|fut"}, {"2pl.fut", "2|pl|fut"}, {"3pl.fut", "3|pl|fut" },
}

-- format a link for the dialect table, including notes
function format_link(word, all_notes, alt)
	notes = mw.text.split(all_notes or "", "; ")
	local filtered_notes = {}
	local partial = false
	for _, note in ipairs(notes) do
		if note == "partial" then
			partial = true
		else
			table.insert(filtered_notes, note)
		end
	end
	local note = table.concat(filtered_notes, "; ")
	return ((partial and "<sup>?</sup>") or "") .. m_links.full_link({
		term = word,
		alt = alt,
		lang = lang,
		tr = "-",
	}) .. ((note and (' <span style="font-size:60%"><i>' .. note .. '</i></span>')) or '') .. ' <small>(' .. lang:transliterate(word or alt) .. ')</small>'
end

function get_lemma(word)
	return mw.ustring.match(word, "{(.*)}") or mw.ustring.match(word, "<(.*)>") or word
end

function remove_lemma_indicators(word)
	return mw.ustring.gsub(mw.ustring.gsub(word, "{.*}", ""), "[<>]", "")
end

local function make_table(data, pos)
	local result = ""
	if pos == "adj" then
		result = [=[
{| class="inflection-table vsSwitcher" data-toggle-category="declension" style="background:var(--wikt-palette-lavender, #f8f8ff); text-align:center; min-width:45em; border: 1px solid #9e9e9e;"
|- style="background: var(--wikt-palette-lightblue, #d9ebff);"
! class="vsToggleElement" style="text-align: left;" colspan="7" | Declension of {lemma}
|- class="vsHide"
! style="background:var(--wikt-palette-lightblue, #d9ebff); width:25%" rowspan="2" |
! style="background:var(--wikt-palette-lightblue, #d9ebff)" colspan="2" | masculine
! style="background:var(--wikt-palette-lightblue, #d9ebff)" colspan="2" | feminine
! style="background:var(--wikt-palette-lightblue, #d9ebff)" colspan="2" | neuter
|- class="vsHide"
! style="background:var(--wikt-palette-lightblue, #d9ebff)" | singular
! style="background:var(--wikt-palette-lightblue, #d9ebff)" | plural
! style="background:var(--wikt-palette-lightblue, #d9ebff)" | singular
! style="background:var(--wikt-palette-lightblue, #d9ebff)" | plural
! style="background:var(--wikt-palette-lightblue, #d9ebff)" | singular
! style="background:var(--wikt-palette-lightblue, #d9ebff)" | plural]=]
	
		for i, case in ipairs(cases) do
			local row = '\n|- class="vsHide"'
			row = row .. '\n! style="background:var(--wikt-palette-lighterblue, #ebf4ff)" | ' .. cases_full[i]
			for _, gender in ipairs(genders) do
				for _, number in ipairs(numbers) do
					row = row .. '\n| {' .. gender .. '.' .. case ..  '.' .. number .. '}'
				end
			end
			result = result .. row
		end
		
		result = result .. "\n{notes_clause}\n|}"
	elseif pos == "noun" then
		result = [=[
{| class="inflection-table vsSwitcher" data-toggle-category="declension" style="background:var(--wikt-palette-lavender, #f8f8ff); text-align:center; min-width:45em; border: 1px solid #9e9e9e;"
|- style="background: var(--wikt-palette-lightblue, #d9ebff);"
! class="vsToggleElement" style="text-align: left;" colspan="3" | Declension of {lemma}
|- class="vsHide"
! style="background:var(--wikt-palette-lightblue, #d9ebff); width:33%" |
! style="background:var(--wikt-palette-lightblue, #d9ebff)" | singular
! style="background:var(--wikt-palette-lightblue, #d9ebff)" | plural]=]
	
		for i, case in ipairs(cases) do
			local row = '\n|- class="vsHide"'
			row = row .. '\n! style="background:var(--wikt-palette-lighterblue, #ebf4ff)" | ' .. cases_full[i]
			for _, number in ipairs(numbers) do
				row = row .. '\n| {' .. case ..  '.' .. number .. '}'
			end
			result = result .. row
		end
		
		result = result .. "\n{notes_clause}\n|}"
	elseif pos == "verb" then
		result = [=[
{| class="inflection-table vsSwitcher" data-toggle-category="declension" style="background:var(--wikt-palette-lavender, #f8f8ff); text-align:center; min-width:45em; border: 1px solid #9e9e9e;"
|- style="background: var(--wikt-palette-lightblue, #d9ebff);"
! class="vsToggleElement" style="text-align: left;" colspan="7" | Personal forms of {lemma}
|- class="vsHide"
! style="background:var(--wikt-palette-lightblue, #d9ebff); width:33%" rowspan="2" |
! style="background:var(--wikt-palette-lightblue, #d9ebff)" colspan="3" | singular
! style="background:var(--wikt-palette-lightblue, #d9ebff)" colspan="3" | plural
|- class="vsHide"
! style="background:var(--wikt-palette-lightblue, #d9ebff)" | 1st
! style="background:var(--wikt-palette-lightblue, #d9ebff)" | 2nd
! style="background:var(--wikt-palette-lightblue, #d9ebff)" | 3rd
! style="background:var(--wikt-palette-lightblue, #d9ebff)" | 1st
! style="background:var(--wikt-palette-lightblue, #d9ebff)" | 2nd
! style="background:var(--wikt-palette-lightblue, #d9ebff)" | 3rd]=]
	
		for i, mood in ipairs(moods) do
			local row = '\n|- class="vsHide"'
			row = row .. '\n! style="background:var(--wikt-palette-lighterblue, #ebf4ff)" | ' .. moods_full[i]
			for _, number in ipairs(numbers) do
				for _, person in ipairs(persons) do
					row = row .. '\n| {' .. person .. number ..  '.' .. mood .. '}'
				end
			end
			result = result .. row
		end
		
		result = result .. "\n{notes_clause}\n|}"
	end

	local notes_template = [===[
|- class="vsHide"
| colspan=3 | 
<div class="hi-footnote-outer-div">
<div class="hi-footnote-inner-div">
{footnote}
</div></div>
]===]
	
	-- footnotes
	data.forms.notes_clause = data.forms.footnote ~= "" and
		m_string_utilities.format(notes_template, data.forms) or ""
	data.forms.desc = data.desc
	data.forms.lemma = format_link(data.lemma)
	result = m_string_utilities.format(result, data.forms)
		
	return result
end

function export.inflection(frame)
	local args = frame:getParent().args
	local pagename = mw.title.getCurrentTitle().text
	local target_page = args[1] or pagename
	local main_lemma = args[2] or pagename
	local resource_page = "Module:inc-ash/dial/data/" .. target_page
	
	-- get page data
	if mw.title.new(resource_page).exists then
		m_syndata = require(resource_page).list
	else
		return frame:expandTemplate{ title = "Template:inc-ash-dial/uncreated", args = { target_page } }
	end
	
	-- remove unnecessary data
	m_syndata["meaning"] = nil
	local pos = m_syndata["pos"] or "none"
	m_syndata["pos"] = nil
	if m_syndata["note"] then
		note = m_syndata["note"]
		m_syndata["note"] = nil
	end
	if pos == nil then
		error("Please specify a valid pos in the resource page " .. resource_page)
	end
	
	-- slots
	local props = {
	  lang = lang,
	  lemmas = {main_lemma},
	  slot_list = slots[pos],
	  include_translit = true,
	  create_footnote_obj = nil,
	  canonicalize = nil,
	  preprocess_forms = nil,
	  no_deduplicate_forms = false,
	  combine_metadata_during_dedup = nil,
	  transform_accel_obj = nil,
	  format_forms = nil,
	  generate_link = nil,
	  format_tr = nil,
	  join_spans = nil,
	  allow_footnote_symbols = nil,
	  footnotes = nil,
	}
	
	-- get forms
	local data = {forms = {}}
	data.forms.footnote = ""
	-- local process = ""
	for location, synonym_set in pairs(m_syndata) do
		-- check if location is in alias list and use the proper one if so
		if variety_data['aliases'][location] ~= nil then location = variety_data['aliases'][location] end
		if synonym_set[1] ~= "" then
			for i, synonym in ipairs(synonym_set) do
				local synonym_decomp = mw.text.split(synonym, ":")
				local lemma = get_lemma(synonym_decomp[1])
				synonym_decomp[1] = remove_lemma_indicators(synonym_decomp[1])
				if lemma == main_lemma then
					local notes = mw.text.split(synonym_decomp[2] or "", "; ")
					for _, gloss in ipairs(notes) do
						iut.insert_form(data.forms, gloss, {form=synonym_decomp[1]})
						-- process = process .. "\nInserted " .. synonym_decomp[1] .. " into " .. gloss
					end
				end
			end
		end
	end
	
	-- make table
	-- if pos == "verb" then return process end
	data.lemma = main_lemma
	iut.show_forms(data.forms, props)
	return make_table(data, pos)
end

function export.main(frame)
	local args = frame:getParent().args
	local pagename = mw.title.getCurrentTitle().text
	local target_page = args[1] or pagename
	local resource_page = "Module:inc-ash/dial/data/" .. target_page
	if mw.title.new(resource_page).exists then
		m_syndata = require(resource_page).list
	else
		return frame:expandTemplate{ title = "Template:inc-ash-dial/uncreated", args = { target_page } }
	end
	
	local template = {
		["Central"]		= {},
		["East"]		= {},
		["Northwest"]	= {},
		["West"]		= {},
		["South"]		= {},
	}

	main_title = mw.ustring.gsub((target_page == pagename and pagename or '[[' .. target_page .. ']]'), "[0-9%-]", "")
	text = [=[
	{| class="wikitable mw-collapsible mw-collapsed" style="margin:0; text-align:center;"
	|-
	! style="background:#FCFFFC; width:40em" colspan=4 | Dialectal forms of <b><span class="Brah" lang="inc-ash">]=] ..
		main_title .. '</span></b> (“' .. m_syndata["meaning"] .. '”) ' .. [=[
		
	|-
	! style="background:#E8ECFA" | Variety
	! style="background:#E8ECFA" | Location
	! style="background:#E8ECFA" | Lemmas
	! style="background:#E8ECFA; text-align: left;" | Forms]=] .. [=[
	<div style="float: right; clear: right; font-size:60%"><span class="plainlinks">[]=] ..
		tostring(mw.uri.fullUrl("Module:inc-ash/dial/data/" .. target_page, { ["action"] = "edit" })) ..
	' edit]</span></div>'
	
	m_syndata["meaning"] = nil
	local pos = m_syndata["pos"] or "none"
	m_syndata["pos"] = nil
	if m_syndata["note"] then
		note = m_syndata["note"]
		m_syndata["note"] = nil
	end
	
	local categories = ""
	
	for location, synonym_set in pairs(m_syndata) do
		-- check if location is in alias list and use the proper one if so
		if variety_data['aliases'][location] ~= nil then location = variety_data['aliases'][location] end
		
		local sc = "Brah"
		if location == "Shahbazgarhi" or location == "Mansehra" then
			sc = "Khar"
		end
		if synonym_set[1] ~= "" then
			local formatted_synonyms = {}
			local formatted_lemmas = {}
			for i, synonym in ipairs(synonym_set) do
				local synonym_decomp = mw.text.split(synonym, ":")
				local word =  remove_lemma_indicators(synonym_decomp[1])
				local lemma = get_lemma(synonym_decomp[1], pos, sc)
				if (synonym_decomp[1] ~= word) or (synonym_decomp[2] ~= nil) then
					table.insert(formatted_synonyms, {
						formatted = format_link(word, synonym_decomp[2], nil),
						form = word,
					})
				end
				formatted_lemmas[lemma] = format_link(lemma, nil, nil)
			end
			local location_data = variety_data[location]
			local location_name = mw.ustring.gsub(location_data.english or location, "(%(.*%))", "<small>%1</small>")
			local location_link = location_data.link or location_name
			table.insert(template[location_data.group],
				{ location_data.order, location_name, location_link, formatted_synonyms, formatted_lemmas })
		end
	end
	
	local attested = {}
	
	for _, variety in ipairs(variety_list) do
		local sc = "Brah"
		if variety == "Northwest" then
			sc = "Khar"
		end
		local colour = variety_colour[variety]
		if #template[variety] > 0 then
			table.sort(template[variety], function(first, second) return first[1] < second[1] end)
			for i, point_data in ipairs(template[variety]) do
				local forms = {}
				local lemmas = {}
				local attested_point = false
				for lemma_plain, lemma in pairs(point_data[5]) do
					if lemma_plain == pagename then
						attested_point = true
					end
					table.insert(lemmas, lemma)
				end
				for _, word in ipairs(point_data[4]) do
					if word.form == pagename then
						attested_point = true
					end
					table.insert(forms, word.formatted)
				end
				if attested_point then
					table.insert(attested, {point_data[3], point_data[2]})
				end
				text = text .. "\n|-"
				if i == 1 then
					text = text .. "\n!rowspan=" .. #template[variety] .. (special_note[variety] and " colspan=2" or "") .. 
					' style="background:#' .. colour .. '"| ' .. (special_note[variety] or variety)
				end
				text = text .. ((point_data[2] and not special_note[variety]) and ('\n|style="background:#' .. colour .. '"| ' .. 
					'[[w:' .. point_data[3] .. '|' .. point_data[2] .. ']]') or '') ..
					'\n| ' .. table.concat(lemmas, ", ") ..
					'\n|style="text-align: left;"| ' .. table.concat(forms, ", ")
			end
		end
	end

	if note and note ~= "" then
		text = text .. '\n|-\n! style="background:#FFF7FB; padding-top:5px; padding-bottom: 5px" | ' ..
			"<small>Note</small>\n| colspan=2|<small><i>" .. note .. "</i></small>"
	end

	local attested_parts = {}
	table.sort(attested)
	for _, label in ipairs(attested) do
		table.insert(attested_parts, m_labels.show_forms
		if i == #attested and i ~= 1 then
			res = res .. " and "
		elseif i ~= 1 then
			res = res .. ", "
		end
		res = res .. '[[w:' .. dialect[1] .. '|' .. dialect[2] .. ']]'
	end
	
	local res = "Attested at "
	return res .. '.\n' .. text .. '\n|}' .. categories
end

function export.make_map(frame)
	local width = tonumber(frame.args["width"]) or 1200
	local word = frame.args[1] or mw.title.getCurrentTitle().text
	local syn_data = require("Module:inc-ash/dial/data/" .. word).list
	local map = [=[
		<div style="margin-left: auto; margin-right:auto; width:]=] .. width .. [=[px; max-width:]=] .. width .. [=[px;">
		<div><div style="height:]=] .. width * (1615/1500) .. [=[px;width:]=] .. width .. [=[px;overflow:auto;">
		<div style="position:relative;top:0;left:0">
		<div style="position:relative;top:0;left:0;line-height:0">[[File:India location map.svg|]=] .. width .. [=[px|link=]]</div>
		]=]
	local prelim_data, data, points, legend = {}, {}, {}, {}
	for location, synonym_set in pairs(syn_data) do
		-- check if location is in alias list and use the proper one if so
		local actual_location = location
		if variety_data['aliases'][location] ~= nil then actual_location = variety_data['aliases'][location] end
		if location ~= "note" and location ~= "meaning" and location ~= "pos" and variety_data[actual_location].lat and synonym_set[1] ~= "" then
			for _, term in ipairs(synonym_set) do
				term = get_lemma(mw.text.split(term, ":")[1])
				local lemma = lang:transliterate(term)
				if prelim_data[term] then
					prelim_data[term].count = prelim_data[term].count + 1
					table.insert(prelim_data[term].locations, location)
				else
					prelim_data[term] = { count = 1, locations = { location }, term = remove_lemma_indicators(term), lemma = lemma }
				end
			end
		end
	end
	for term, term_data in pairs(prelim_data) do
		table.insert(data, { term = term_data.term, count = term_data.count, locations = term_data.locations, lemma = term_data.lemma })
	end
	table.sort(data, function(first, second) return first.count > second.count end)
	
	local prev_count = data[1].count
	local greyed, greyed_count = false, 0
	local completed_lemmas = {}
	local num_completed = 0
	for _, d in ipairs(data) do
		local num = -1
		if completed_lemmas[d.lemma] then
			num = completed_lemmas[d.lemma]
		else
			num = num_completed + 1
			completed_lemmas[d.lemma] = num
			num_completed = num_completed + 1
		end
		greyed = greyed or (num > 10 and d.count ~= prev_count) or num > 20
		local colour = greyed and "CCCCBF" or dots[num]
		for _, location in ipairs(d.locations) do
			-- check if location is in alias list and use the proper one if so
			local actual_location = location
			if variety_data['aliases'][location] ~= nil then actual_location = variety_data['aliases'][location] end
			
			local loc_info = variety_data[actual_location]
			local top_offset, left_offset = 0, 0
			if table.getn(syn_data[location]) > 1 then
				top_offset = math.random(-300, 300) / 100
				left_offset = math.random(-300, 300) / 100
			end
			local top = ((37.5 - loc_info.lat) * (width*(1615/1500))/(37.5-5)) + top_offset
			local left = ((loc_info.long - 67) * width/(99-67)) + left_offset
			local loc_name = mw.ustring.gsub(loc_info.english or actual_location, "%((.*)%)$", "- %1")
			table.insert(points,
				tostring( mw.html.create( "div" )
					:css( "position", "absolute" )
					:css( "top", top .. "px" )
					:css( "left", left .. "px" )
					:css( "margin", "auto" )
					:css( "transform", "translate(-50%,-50%)" ) -- http://stackoverflow.com/questions/33683602/transform-origin-equivalent-for-position-absolute
					:css( "padding", "5px" )
					:css( "border-radius", "100%" )
					:css( "background-color", "#" .. colour )
					:css( "cursor", "help" )
					:css( "opacity", "0.8" )
					:attr( "title", loc_name .. " (" .. loc_info.group .. ")" )))
		end
		if greyed then
			greyed_count = greyed_count + d.count
		else
			table.insert(legend, 
				tostring( mw.html.create( "div" )
					:css( "display", "inline-block" )
					:css( "width", "10px" )
					:css( "height", "10px" )
					:css( "border-radius", "100%" )
					:css( "background-color", "#" .. colour )) .. 
				
				m_links.full_link({lang = lang,
					term = mw.ustring.gsub(d.term, "(.+)_[1-9]", "%1"),
					alt = mw.ustring.gsub(d.term, "(.+)_([1-9])", "%1<sub>%2</sub>")}) .. " (" .. d.count .. ")")
		end
		
		prev_count = d.count
	end
	
	if greyed_count > 0 then
		table.insert(legend, 
			tostring( mw.html.create( "div" )
				:css( "display", "inline-block" )
				:css( "width", "10px" )
				:css( "height", "10px" )
				:css( "border-radius", "100%" )
				:css( "background-color", "#CCCCBF" )) .. 
			
			"other terms (" .. greyed_count .. ")")
	end

	map = [=[
	{| class="wikitable mw-collapsible mw-collapsed" style="margin:0; text-align:center;"
	|-
	! style="background:#FCFFFC; width:40em" colspan=3 | Map of dialectal forms of <b><span class="Brah" lang="inc-ash">]=] ..
		word .. '</span></b> (“' .. syn_data["meaning"] .. '”) ' .. "\n|-\n|\n" .. map .. table.concat(points) .. '</div></div></div>' ..
		'<div style="column-count:' .. math.ceil(width/240) .. ';-moz-column-count:' .. math.ceil(width/240) .. ';-webkit-column-count:' .. math.ceil(width/240) .. ';font-size:smaller;line-height:1.7">' ..
		table.concat(legend, "<br>") .. "</div></div>" .. [=[
		
	|}]=]
		
	return map
end

return export
