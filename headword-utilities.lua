local export = {}

local rfind = mw.ustring.find
local rmatch = mw.ustring.match
local rsplit = mw.text.split


-- Auto-add links to a "space word" (after splitting on spaces). We split off
-- final punctuation, and then split on hyphens if split_hyphen is given.
-- Code ported from [[Module:fr-headword]].
local function add_space_word_links(space_word, split_hyphen)
	local space_word_no_punct, punct = rmatch(space_word, "^(.*)([,;:?!])$")
	space_word_no_punct = space_word_no_punct or space_word
	punct = punct or ""
	local words
	-- don't split prefixes and suffixes
	if not split_hyphen or rfind(space_word_no_punct, "^%-") or rfind(space_word_no_punct, "%-$") then
		words = {space_word_no_punct}
	else
		words = rsplit(space_word_no_punct, "%-")
	end
	local linked_words = {}
	for _, word in ipairs(words) do
		word = "[[" .. word .. "]]"
		table.insert(linked_words, word)
	end
	return table.concat(linked_words, "-") .. punct
end


-- Auto-add links to a lemma. We split on spaces, and also on hyphens
-- if split_hyphen is given or the word has no spaces. We don't always
-- split on hyphens because of cases like "आदान-प्रदान करना" where
-- "आदान-प्रदान" should be linked as a whole. If there's no space, however, then
-- it makes sense to split on hyphens by default.
function export.add_lemma_links(lemma, split_hyphen)
	if rfind(lemma, "[%[%]]") then
		return lemma
	end
	if not rfind(lemma, " ") then
		split_hyphen = true
	end
	local words = rsplit(lemma, " ")
	local linked_words = {}
	for _, word in ipairs(words) do
		table.insert(linked_words, add_space_word_links(word, split_hyphen))
	end
	local retval = table.concat(linked_words, " ")
	-- If we ended up with a single link consisting of the entire lemma,
	-- remove the link.
	local unlinked_retval = rmatch(retval, "^%[%[([^%[%]]*)%]%]$")
	return unlinked_retval or retval
end


function export.show_headword(frame, data)
	local poscat = frame.args[1]
		or error("Part of speech has not been specified. Please pass parameter 1 to the module invocation.")

	local parargs = frame:getParent().args

	local params = {
		["head"] = {list = true},
		["id"] = {},
		["splithyph"] = {type = "boolean"},
		["nolinkhead"] = {type = "boolean"},
		["json"] = {type = "boolean"},
		["pagename"] = {}, -- for testing
	}

	if data.sort_param then
		params.sort = {}
	end

	if data.tr_param then
		params.tr = {list = true}
	end

	if data.ts_param then
		params.ts = {list = true}
	end

	if data.add_params then
		data.add_params(poscat, params)
	end

	if data.pos_functions then
		for pos, posdata in pairs(data.posdata) do
			if posdata.inflections then
			end
			if posdata.params then
			for key, val in pairs(posdata.params) do
				params[key] = val
			end
		end
	end

	local args = require("Module:parameters").process(parargs, params)

	-- Use `subpageText` not `text` so we work correctly with userspace testing pages and such.
	local pagename = args.pagename or mw.title.getCurrentTitle().subpageText

	local user_specified_heads = args.head
	local heads = user_specified_heads
	if args.nolinkhead then
		if #heads == 0 then
			heads = {pagename}
		end
	else
		local romut = require(romut_module)
		local auto_linked_head = romut.add_links_to_multiword_term(pagename, args.splithyph,
			no_split_apostrophe_words)
		if #heads == 0 then
			heads = {auto_linked_head}
		else
			for i, head in ipairs(heads) do
				if head:find("^~") then
					head = romut.apply_link_modifiers(auto_linked_head, usub(head, 2))
					heads[i] = head
				end
				if head == auto_linked_head then
					track("redundant-head")
				end
			end
		end
	end

	local data = {
		lang = lang,
		pos_category = poscat,
		categories = {},
		heads = heads,
		user_specified_heads = user_specified_heads,
		genders = {},
		inflections = {},
		pagename = pagename,
		id = args.id,
		sort_key = args.sort,
		force_cat_output = force_cat,
	}

	local is_suffix = false
	if pagename:find("^%-") and poscat ~= "suffix forms" then
		is_suffix = true
		data.pos_category = "suffixes"
		local singular_poscat = require("Module:string utilities").singularize(poscat)
		table.insert(data.categories, langname .. " " .. singular_poscat .. "-forming suffixes")
		table.insert(data.inflections, {label = singular_poscat .. "-forming suffix"})
	end

	local tracking_categories = {}

	if pos_functions[poscat] then
		pos_functions[poscat].func(args, data, tracking_categories, frame, is_suffix)
	end

	if args.apoc then
		-- Apocopated form of a term; do this after calling pos_functions[], because the function might modify
		-- data.pos_category.
		local pos = data.pos_category
		if not pos:find(" forms") then
			-- Apocopated forms are non-lemma forms.
			local singular_poscat = require("Module:string utilities").singularize(pos)
			data.pos_category = singular_poscat .. " forms"
		end
		-- If this is a suffix, insert label 'apocopated' after 'FOO-forming suffix', otherwise insert at the beginning.
		table.insert(data.inflections, is_suffix and 2 or 1, {label = glossary_link("apocopated")})
	end

	if args.json then
		return require("Module:JSON").toJSON(data)
	end

	return require("Module:headword").full_headword(data)
		.. (#tracking_categories > 0 and require("Module:utilities").format_categories(tracking_categories, lang, args.sort, nil, force_cat) or "")
end


return export
