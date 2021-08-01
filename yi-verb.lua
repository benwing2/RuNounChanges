-- TODO: `cv' transliteration

local strutils = require("Module:string utilities")
local com = require("Module:yi-common")
local links = require("Module:links")

local export = {}

local lang = require("Module:languages").getByCode("yi")

local past_forms = {
	["n"] = true,
	["t"] = true,
	["-n"] = true,
	["-t"] = true,
}

local auxiliaries = {
	["h"] = {
		["inf"] = "האָבן",
		["pres1s"] = "האָב",
		["pres1p"] = "האָבן",
		["pres2s"] = "האָסט",
		["pres2p"] = "האָט",
		["pres3s"] = "האָט",
		["pres3p"] = "האָבן",
		["pp"] = "געהאַט",
	},
	["z"] = {
		["inf"] = "זײַן",
		["pres1s"] = "בין",
		["pres1p"] = "זענען",
		["pres2s"] = "ביסט",
		["pres2p"] = "זענט",
		["pres3s"] = "איז",
		["pres3p"] = "זענען",
		["pp"] = "געווען",
	},
}

local veln = {
	["pres1s"] = "וועל",
	["pres1p"] = "וועלן",
	["pres2s"] = "וועסט",
	["pres2p"] = "וועט",
	["pres3s"] = "וועט",
	["pres3p"] = "וועלן",
}

local numbers = {
	["1s"] = "איך",
	["1p"] = "מיר",
	["2s"] = "דו",
	["2p"] = "איר",
	["3s"] = "ער",
	["3p"] = "זיי",
}

local imperatives = {
	["imp|s"] = "דו",
	["imp|p"] = "איר",
}

local nonfinites = {
	["inf"] = true,
	["pres"] = true,
	["past-participle"] = true,
	["aux"] = true,
}

local function make_link_form(text, tr, accel)
	return (
		links.full_link({lang = lang, term = text, tr = "-", accel = accel}) ..
		"<br/><small>" .. tr .. "</small>"
	)
end

local function make_display_form(text, tr)
	return (
		links.full_link({lang = lang, alt = text, tr = "-"}) ..
		"<br/><small>" .. tr .. "</small>"
	)
end

local function process_forms(forms, aux)
	-- present
	for n, p in pairs(numbers) do
		f = "pres" .. n
		if forms[f] == "-" then
			forms[f] = "—"
		else
			forms[f] = make_link_form(
				p .. " [[" .. forms[f].text .. "]]",
				com.translit(p) .. " " .. com.translit(forms[f]),
				{ form = n .. "|pres" }
			)
		end
	end

	-- imperative
	for n, p in pairs(imperatives) do
		if forms[n] == "-" then
			forms[n] = "—"
		else
			forms[n] = make_link_form(
				"[[" .. forms[n].text .. "]] (" .. p .. ")",
				com.translit(forms[n]) .. " (" .. com.translit(p) .. ")",
				{ form = n }
			)
		end
	end

	-- past
	for n, p in pairs(numbers) do
		p = p .. " " .. aux["pres" .. n]
		n = "past" .. n
		if forms["past-participle"] == "-" then
			forms[n] = "—"
		else
			forms[n] = make_display_form(
				p .. " " .. forms["past-participle"].text,
				com.translit(p) .. " " .. com.translit(forms["past-participle"])
			)
		end
	end

	-- pluperfect
	for n, p in pairs(numbers) do
		p = p .. " " .. aux["pres" .. n] .. " " .. aux["pp"]
		n = "plup" .. n
		if forms["past-participle"] == "-" then
			forms[n] = "—"
		else
			forms[n] = make_display_form(
				p .. " " .. forms["past-participle"].text,
				com.translit(p) .. " " .. com.translit(forms["past-participle"])
			)
		end
	end

	-- future
	for n, p in pairs(numbers) do
		p = p .. " " .. veln["pres" .. n]
		n = "fut" .. n
		if forms["inf"] == "-" then
			forms[n] = "—"
		else
			forms[n] = make_display_form(
				p .. " " .. forms["inf"].text,
				com.translit(p) .. " " .. com.translit(forms["inf"])
			)
		end
	end

	-- future perfect
	for n, p in pairs(numbers) do
		p = p .. " " .. veln["pres" .. n] .. " " .. aux["inf"]
		n = "futp" .. n
		if forms["past-participle"] == "-" then
			forms[n] = "—"
		else
			forms[n] = make_display_form(
				p .. " " .. forms["past-participle"].text,
				com.translit(p) .. " " .. com.translit(forms["past-participle"])
			)
		end
	end

	-- non-finite forms (must be done last)
	for n, v in pairs(nonfinites) do
		if forms[n] == "-" then
			forms[n] = "—"
		else
			forms[n] = make_link_form(
				"[[" .. forms[n].text .. "]]",
				com.translit(forms[n]),
				{ form = n }
			)
		end
	end
end

local function generate_forms(args, hint, aux)
	local forms = {}

	local inftext = args["inf"] or SUBPAGENAME
	
	local prescv = ""
	local cv = ""
	if args["converb"] then
		cv = args["converb"]
		prescv = " " .. cv
	end
	
	local base = nil
	if args[1] then
		base = com.form(args[1], args["tr"])
		hint = hint or com.ends_in(base, "e") and "e" or hint
	elseif inftext == "-" then
		base = com.form(SUBPAGENAME, args["tr"])
	else
		hint = hint or args["tr"] and mw.ustring.match(args["tr"], "e$") and "e" or hint
		local tmp = mw.ustring.gsub(inftext, "ע?ן$", "")
		if hint == "e" then
			tmp = tmp .. "ע"
		else
			tmp = mw.ustring.gsub(tmp, "יִ$", "י")
		end
		base = com.form(tmp, args["tr"])
	end

	local inftr = nil
	if args["inftr"] or not base.tr then
		inftr = args["inftr"]
	else
		local tmp = base
		if hint == "e" then
			tmp = com.form(
				mw.ustring.gsub(tmp.text, "ע$", ""),
				mw.ustring.gsub(tmp.tr, "e$", "")
			)
		end
		if (inftext ~= "-" and
			#tmp.text < #inftext and
			tmp.text == inftext:sub(1, #tmp.text)) then
			local ending = inftext:sub(#tmp.text + 1)
			if ending == "ען" then
				inftr = tmp.tr .. "en"
			elseif ending == "ן" then
				inftr = tmp.tr .. (com.ends_nasal(tmp) and "en" or "n")
			end
		end
	end
	local inf = com.form(inftext, inftr)

	local nbase = nil
	if args["n"] then
		nbase = com.form(args["n"], args["ntr"])
	else
		local tmp = base
		if hint == "e" then
			tmp = com.form(
				mw.ustring.gsub(tmp.text, "ע$", ""),
				tmp.tr and mw.ustring.gsub(tmp.tr, "e$", "")
			)
		end
		if (inf ~= "-" and
			#tmp.text < #inf.text and
			tmp.text == inf.text:sub(1, #tmp.text)) then
			nbase = com.form(inf.text, args["ntr"] or inf.tr)
		else
			local suf = "ן"
			if com.ends_nasal(tmp) then
				suf = "ען"
			end
			nbase = com.suffix(tmp, suf)
		end
	end

	local tbase = nil
	if args["t"] then
		tbase = com.form(args["t"], args["ttr"])
	elseif com.ends_in(base, "t") then
		tbase = base
	else
		tbase = com.suffix(base, "ט")
	end

	base = com.finalize(base)

	forms["inf"] = inf
	forms["pres1s"] = com.form(args["pres1s"] or (base.text .. prescv), args["pres1str"] or base.tr)
	forms["pres3s"] = com.form(args["pres3s"] or (tbase.text .. prescv), args["pres3str"] or tbase.tr)
	forms["pres2p"] = com.form(args["pres2p"] or (tbase.text .. prescv), args["pres2ptr"] or tbase.tr)
	forms["pres1p"] = com.form(args["pres1p"] or (nbase.text .. prescv), args["pres1ptr"] or nbase.tr)
	forms["pres3p"] = com.form(args["pres3p"] or (nbase.text .. prescv), args["pres3ptr"] or nbase.tr)
	if args["pres2s"] then
		forms["pres2s"] = com.form(args["pres2s"], args["pres2str"])
	elseif com.ends_in(base, "s") then -- or com.ends_in(base, "ts")
		forms["pres2s"] = com.form((tbase.text .. prescv), args["pres2str"] or tbase.tr)
	-- elseif com.ends_in(base, "z") then
	--	 forms["pres2s"] = com.form(
	--		 mw.ustring.gsub(base.text, "ז$", "סט"),
	--		 base.tr and mw.ustring.gsub(base.tr, "z$", "st")
	--	 )
	else
		forms["pres2s"] = com.form((com.suffix(base, "סט").text .. prescv), args["pres2str"] or com.suffix(base, "סט").tr)
	end
	if args["imp"] == "-" then
		forms["imp|s"] = "-"
		forms["imp|p"] = "-"
	else
		forms["imp|s"] = com.form(args["imps"] or (base.text .. prescv), args["impstr"] or base.tr)
		forms["imp|p"] = com.form(args["impp"] or (tbase.text .. prescv), args["impptr"] or tbase.tr)
	end
	forms["pres"] = com.form(
		args["pres"] or cv .. com.suffix(nbase, "דיק").text,
		args["prestr"] or com.suffix(nbase, "דיק").tr
	)
	local past_form = args["past"] or "t"
	if past_forms[past_form] then
		local past = nil
		if past_form:sub(-1, -1) == "n" then
			past = nbase
		else
			past = tbase
		end
		if past_form:sub(1, 1) ~= "-" then
			past = com.prefix(cv .. "גע", past)
		end
		forms["past-participle"] = com.form(past.text, args["pasttr"] or past.tr)
	else
		forms["past-participle"] = com.form(past_form, args["pasttr"])
	end

	forms["aux"] = com.form(aux["inf"])

	return forms
end

local template = nil

-- The main entry point.
-- This is the only function that can be invoked from a template.
function export.conjugate(frame)
	local args = frame:getParent().args
	local hint = args["hint"] or frame.args[1]
	SUBPAGENAME = frame.args["pagename"] or mw.title.getCurrentTitle().subpageText
	NAMESPACE = mw.title.getCurrentTitle().nsText

	for k, v in pairs(args) do
		if v == "" then
			args[k] = nil
		end
	end

	local aux = auxiliaries[args["aux"] or "h"]

	local forms = generate_forms(args, hint, aux)
	process_forms(forms, aux)
	forms["title"] = args["title"] or (
		"Conjugation of " ..
		links.full_link({lang = lang, alt = SUBPAGENAME, tr = "-"})
	)
	return strutils.format(template, forms)
end

template = [===[
<div class="NavFrame" style="width:56em">
<div class="NavHead" style="background:#ccccff">{title}</div>
<div class="NavContent">
{\op}| style="border:1px solid #ccccff; text-align:center; width:100%" class="inflection-table" cellspacing="1" cellpadding="3"
|- style="background:#f2f2ff"
! colspan="1" style="background:#ccccff; width:20%" | infinitive
| colspan="2" | {inf}
|- style="background:#f2f2ff"
! colspan="1" style="background:#ccccff" | present participle
| colspan="2" | {pres}
|- style="background:#f2f2ff"
! colspan="1" style="background:#ccccff" | past participle
| colspan="2" | {past-participle}
|- style="background:#f2f2ff"
! colspan="1" style="background:#ccccff" | auxiliary
| colspan="2" | {aux}
|- style="background:#f2f2ff"
! colspan="3" style="background:#ccccff; height:0.25em" |
|- style="background:#f2f2ff"
! rowspan="3" style="background:#ccccff" | present
| {pres1s}
| {pres1p}
|- style="background:#f2f2ff"
| {pres2s}
| {pres2p}
|- style="background:#f2f2ff"
| {pres3s}
| {pres3p}
|- style="background:#f2f2ff"
| colspan="3" style="background:#ccccff; height:0.25em" |
|- style="background:#f2f2ff"
! style="background:#ccccff" | imperative
| {imp|s}
| {imp|p}
|-
| colspan="3" | <div class="NavFrame" style="width:100%">
<div class="NavHead" style="background:#ccccff">Composed forms</div>
<div class="NavContent">
{\op}| style="border:1px solid #ccccff; text-align:center; width:100%" class="inflection-table" cellspacing="1" cellpadding="3"
|- style="background:#f2f2ff"
! rowspan="3" style="background:#ccccff; width:20%" | past
| {past1s}
| {past1p}
|- style="background:#f2f2ff"
| {past2s}
| {past2p}
|- style="background:#f2f2ff"
| {past3s}
| {past3p}
|- style="background:#f2f2ff"
! colspan="3" style="background:#ccccff; height:0.25em" |
|- style="background:#f2f2ff"
! rowspan="3" style="background:#ccccff" | pluperfect
| {plup1s}
| {plup1p}
|- style="background:#f2f2ff"
| {plup2s}
| {plup2p}
|- style="background:#f2f2ff"
| {plup3s}
| {plup3p}
|- style="background:#f2f2ff"
! colspan="3" style="background:#ccccff; height:0.25em" |
|- style="background:#f2f2ff"
! rowspan="3" style="background:#ccccff" | future
| {fut1s}
| {fut1p}
|- style="background:#f2f2ff"
| {fut2s}
| {fut2p}
|- style="background:#f2f2ff"
| {fut3s}
| {fut3p}
|- style="background:#f2f2ff"
! colspan="3" style="background:#ccccff; height:0.25em" |
|- style="background:#f2f2ff"
! rowspan="3" style="background:#ccccff" | future perfect
| {futp1s}
| {futp1p}
|- style="background:#f2f2ff"
| {futp2s}
| {futp2p}
|- style="background:#f2f2ff"
| {futp3s}
| {futp3p}
|{\cl}</div></div>
|{\cl}</div></div>]===]

return export
