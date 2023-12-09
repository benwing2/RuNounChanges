local export = {}

local m_links = require("Module:links")
local m_ipa = require("Module:IPA")

local English = {"[[I]] (<span style=\"font-variant:small-caps;\">1sg</span>)", "[[you]] (<span style=\"font-variant:small-caps;\">2sg</span>)", "[[he]], [[she]], [[it]] (<span style=\"font-variant:small-caps;\">3sg</span>)", "[[we]] (<span style=\"font-variant:small-caps;\">1pl</span>)", "[[you]] (<span style=\"font-variant:small-caps;\">2pl</span>)", "[[they]] (<span style=\"font-variant:small-caps;\">3pl</span>)", "[[this]]", "[[that]]", "[[here]]", "[[there]]", "[[who]]", "[[what]]", "[[where]]", "[[when]]", "[[how]]", "[[not]]", "[[all]]", "[[many]]", "[[some]]", "[[few]]", "[[other]]", "[[one]]", "[[two]]", "[[three]]", "[[four]]", "[[five]]", "[[big]]", "[[long]]", "[[wide]]", "[[thick]]", "[[heavy]]", "[[small]]", "[[short]]", "[[narrow]]", "[[thin]]", "[[woman]]", "[[man]] (adult male)", "[[man]] (human being)", "[[child]]", "[[wife]]", "[[husband]]", "[[mother]]", "[[father]]", "[[animal]]", "[[fish]]", "[[bird]]", "[[dog]]", "[[louse]]", "[[snake]]", "[[worm]]", "[[tree]]", "[[forest]]", "[[stick]]", "[[fruit]]", "[[seed]]", "[[leaf]]", "[[root]]", "[[bark]] (of a tree)", "[[flower]]", "[[grass]]", "[[rope]]", "[[skin]]", "[[meat]]", "[[blood]]", "[[bone]]", "[[fat]] (noun)", "[[egg]]", "[[horn]]", "[[tail]]", "[[feather]]", "[[hair]]", "[[head]]", "[[ear]]", "[[eye]]", "[[nose]]", "[[mouth]]", "[[tooth]]", "[[tongue]] (organ)", "[[fingernail]]", "[[foot]]", "[[leg]]", "[[knee]]", "[[hand]]", "[[wing]]", "[[belly]]", "[[guts]]", "[[neck]]", "[[back]]", "[[breast]]", "[[heart]]", "[[liver]]", "to [[drink]]", "to [[eat]]", "to [[bite]]", "to [[suck]]", "to [[spit]]", "to [[vomit]]", "to [[blow]]", "to [[breathe]]", "to [[laugh]]", "to [[see]]", "to [[hear]]", "to [[know]]", "to [[think]]", "to [[smell]]", "to [[fear]]", "to [[sleep]]", "to [[live]]", "to [[die]]", "to [[kill]]", "to [[fight]]", "to [[hunt]]", "to [[hit]]", "to [[cut]]", "to [[split]]", "to [[stab]]", "to [[scratch]]", "to [[dig]]", "to [[swim]]", "to [[fly]]", "to [[walk]]", "to [[come]]", "to [[lie]] (as in a bed)", "to [[sit]]", "to [[stand]]", "to [[turn]] (intransitive)", "to [[fall]]", "to [[give]]", "to [[hold]]", "to [[squeeze]]", "to [[rub]]", "to [[wash]]", "to [[wipe]]", "to [[pull]]", "to [[push]]", "to [[throw]]", "to [[tie]]", "to [[sew]]", "to [[count]]", "to [[say]]", "to [[sing]]", "to [[play]]", "to [[float]]", "to [[flow]]", "to [[freeze]]", "to [[swell]]", "[[sun]]", "[[moon]]", "[[star]]", "[[water]]", "[[rain]]", "[[river]]", "[[lake]]", "[[sea]]", "[[salt]]", "[[stone]]", "[[sand]]", "[[dust]]", "[[earth]]", "[[cloud]]", "[[fog]]", "[[sky]]", "[[wind]]", "[[snow]]", "[[ice]]", "[[smoke]]", "[[fire]]", "[[ash]]", "to [[burn]]", "[[road]]", "[[mountain]]", "[[red]]", "[[green]]", "[[yellow]]", "[[white]]", "[[black]]", "[[night]]", "[[day]]", "[[year]]", "[[warm]]", "[[cold]]", "[[full]]", "[[new]]", "[[old]]", "[[good]]", "[[bad]]", "[[rotten]]", "[[dirty]]", "[[straight]]", "[[round]]", "[[sharp]] (as a knife)", "[[dull]] (as a knife)", "[[smooth]]", "[[wet]]", "[[dry]]", "[[correct]]", "[[near]]", "[[far]]", "[[right]]", "[[left]]", "[[at]]", "[[in]]", "[[with]]", "[[and]]", "[[if]]", "[[because]]", "[[name]]"}
--array - list of 207 objects in this form {gloss=term}
local data = {}

function export.python_dictionary(frame)
	local args = frame:getParent().args
	local dataurl = args['lang']
	if args['var'] then dataurl = dataurl .. '/' .. args['var'] end
	local data = require("Module:Swadesh/data/" .. dataurl)
	local lang = require("Module:languages").getByCode(args.lang, "lang", "allow etym")
	local res = "{'name': '" .. lang:getCanonicalName()
	if data['header'] ~= nil then res = res .. ' (' .. data['header'] .. ')' end
	res = res .. "',"
	
	for word = 1, #English do
		res = res .. "'" .. word .. "': ["
		if data[word] ~= nil then
			for _, termdata in ipairs(data[word]) do
				local translit = (lang:transliterate(termdata.alt or termdata.term))
				res = res .. '{'
				if termdata.term then res = res .. "'term': '" .. termdata.term:gsub("'", "&#39;") .. "', " end
				if termdata.alt then res = res .. "'alt': '" .. termdata.alt:gsub("'", "&#39;") .. "', " end
				if termdata.tr or translit then res = res .. "'translit': '" ..  (termdata.tr or translit):gsub("'", "&#39;") .. "', " end
				if termdata.ts then res = res .. "'transcript': '" ..  termdata.ts:gsub("'", "&#39;") .. "', " end
				if termdata.id then res = res .. "'id': '" ..  termdata.id:gsub("'", "&#39;") .. "', " end
				if termdata.ipa then res = res .. "'ipa': '" ..  termdata.ipa:gsub("'", "&#39;") .. "', " end
				if termdata.nolink then res = res .. "'nolink': '" .. termdata.nolink:gsub("'", "&#39;") .. "', " end
				if termdata.notes then res = res .. "'notes': '" ..  termdata.notes:gsub("'", "&#39;") .. "', " end
				res = res .. '},'
			end
		end
		res = res .. "],"
	end
	res = res .. "}"
	
	return "<pre>" .. mw.text.nowiki(res) .. "</pre>"
end


function export.show(frame)
	local args = frame:getParent().args
	local data = {}
	local langs = {}
	
	local res = mw.html.create("table"):addClass("wikitable sortable")
	
	local headers = res:tag("tr")
	for _, text in ipairs { "№", "English" } do
		headers:tag("th"):node(text)
	end
	
	for i, arg in ipairs(args) do
		local lang = arg
		local header = arg
		local lang_obj = require("Module:languages").getByCode(lang, i, "allow etym")
		langs[i] = lang_obj
		local var = args["var" .. i]
		if var ~= nil then
			arg = arg .. '/' .. var
		end
		local data_module = require("Module:Swadesh/data/" .. arg)
		data[i] = data_module
		local header = lang_obj:getCanonicalName()
		local header_in_data = data_module['header']
		if header_in_data ~= nil and args['translit'] == nil then
			header = header .. ' (' .. header_in_data .. ')'
		end
		local nativename = data_module['nativename']
		if nativename ~= nil then
			header = header .. '<br><small>' .. m_links.full_link({lang = lang_obj, alt = nativename}) .. "</small>"
		end
		local count = 0
		for k, v in pairs(data_module) do
    		if (type(k) == 'number') then count = count + 1 end
    	end
		header = header .. "<br><small><sup>[[Module:Swadesh/data/" .. arg .. "|edit (" .. count .. ")]]</sup></small>"
		headers:tag("th"):node(header)
	end
	
	local show_ipa = args[2] == nil and args['translit'] == nil
	if show_ipa then
		show_ipa = args['ipa']
		
		-- do not display IPA by default for reconstructed languages
		if show_ipa == nil then
			show_ipa = not langs[1]:hasType("reconstructed")
		end
		
		if show_ipa then
			local has_ipa = false
			for word = 1, #English do
				if data[1][word] then
					for _, termdata in ipairs(data[1][word]) do
						if termdata.ipa then
							has_ipa = true
							break
						end
					end
				end
				if has_ipa then break end
			end
			show_ipa = has_ipa
		end
		
		if show_ipa then
			local key = ""
			if mw.loadData("Module:IPA/data").langs_with_infopages[langs[1]:getCode()] then
				key = "<br><small>([[Appendix:" .. langs[1]:getCanonicalName() .. " pronunciation|key]])</small>"
			end
			headers:tag("th"):node("IPA" .. key)
		end
	end
	
	for word = 1, #English do
		local row = mw.html.create("tr")
		row:tag("td"):node(word)
		row:tag("td"):node(English[word])
		
		for lang, arg in ipairs(args) do
			local res = ""
			local count = 0
			local terms = data[lang][word]
			local lang_obj = langs[lang]
			if terms then
				for _, termdata in ipairs(terms) do
					if count ~= 0 then res = res .. ", " end
					local term = termdata.term
					if args["translit"] then
						res = res .. '<span class="swadesh-translit">'
						local alt = termdata.ts or termdata.tr or (lang_obj:transliterate(termdata.alt or term)) or term
							or (termdata.ipa and '<span class="IPA">' .. termdata.ipa .. '</span>')
							or '?'
						if not termdata.nolink and term ~= nil and term ~= "" then
							res = res .. m_links.language_link({lang = lang_obj, term = term or '?',
								alt = alt})
						else
							res = res .. alt
						end
					else
						res = res .. '<span class="swadesh-term">'
						if termdata.nolink == nil then
							res = res .. m_links.full_link({lang = lang_obj, term = term, alt = termdata.alt, tr = termdata.tr, ts = termdata.ts, id = termdata.id})
						else
							res = res .. term
						end
					end
					local notes = termdata.notes
					if notes then
						if args[2] == nil then res = res .. " (''<span class=\"swadesh-note\">" .. notes .. "</span>'')"
						else res = res .. '<abbr title = "' .. notes .. '>*</abbr>' end
					end
					res = res .. '</span>'
					count = count + 1
				end
			end
			row:tag("td"):node(res)
		end
		
		if show_ipa then
			local ipas = ""
			local count = 0
			if data[1][word] then
				for _, termdata in ipairs(data[1][word]) do
					if count ~= 0 then
						ipas = ipas .. ", "
					end
					if termdata.ipa then
						ipas = ipas .. '<span class="IPA">' .. termdata.ipa .. '</span>'
						count = count + 1
					end
				end
			end
			row:tag("td"):node(ipas)
		end
		res:node(row)
	end
	
	
	return res;
end

return export
