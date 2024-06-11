local export = {}

local force_cat = false -- for testing

local rhymes_styles_css_module = "Module:rhymes/styles.css"

local IPA_module = "Module:IPA"
local parameters_module = "Module:parameters"
local parameter_utilities_module = "Module:parameter utilities"
local pron_qualifier_module = "Module:pron qualifier"
local script_utilities_module = "Module:script utilities"
local string_utilities_module = "Module:string utilities"
local TemplateStyles_module = "Module:TemplateStyles"
local utilities_module = "Module:utilities"

local concat = table.concat
local insert = table.insert


local function rsplit(text, pattern)
	return require(string_utilities_module).split(text, pattern)
end

local function track(page)
	require("Module:debug/track")("rhymes/" .. page)
	return true
end


local function tag_rhyme(rhyme, lang)
	local formatted_rhyme, cats
	-- FIXME, should not be here. Telugu should use IPA as well.
	if lang:getCode() == "te" then
		formatted_rhyme = require(script_utilities_module).tag_text(rhyme, lang)
		cats = {}
	else
		formatted_rhyme, cats = require(IPA_module).format_IPA(lang, rhyme, "raw")
	end
	return formatted_rhyme, cats
end

local function make_rhyme_link(lang, link_rhyme, display_rhyme)
	local retval, cats
	if not link_rhyme then
		retval = concat{"[[Rhymes:", lang:getCanonicalName(), "|", lang:getCanonicalName(), "]]"}
		cats = {}
	else
		local formatted_rhyme
		formatted_rhyme, cats = tag_rhyme(display_rhyme or link_rhyme, lang)
		retval = concat{"[[Rhymes:", lang:getCanonicalName(), "/", link_rhyme, "|", formatted_rhyme, "]]"}
	end
	return retval, cats
end

--[==[
Implementation of {{tl|rhymes row}}.
]==]
function export.show_row(frame)
	local args = require(parameters_module).process(
		frame.getParent and frame:getParent().args or frame,
		{
			[1] = {required = true, type = "language"},
			[2] = {required = true},
			[3] = {},
		}
	)

	if not args[1] then
		return "[[Rhymes:English/aɪmz|<span class=\"IPA\">-aɪmz</span>]]"
	end

	-- Discard cleanup categories from make_rhyme_link().
	return (make_rhyme_link(args[1], args[2], "-" .. args[2])) .. (args[3] and (" (''" .. args[3] .. "'')") or "")
end

do
	local function add_syllable_categories(categories, lang, rhyme, num_syl)
		local prefix = "Rhymes:" .. lang .. "/" .. rhyme
		insert(categories, prefix)
		if num_syl then
			for _, n in ipairs(num_syl) do
				local c
				if n > 1 then
					c = prefix .. "/" .. n .. " syllables"
				else
					c = prefix .. "/1 syllable"
				end
				insert(categories, c)
			end
		end
	end

--[==[
Meant to be called from a module. `data` is a table containing the following fields:
* `lang`: language object for the rhymes;
* `rhymes`: a list of rhymes, each described by an object which specifies the rhyme, optional number of syllables, and
  optional left and right regular and accent qualifier fields:
** `rhyme`: the rhyme itself;
** `num_syl`: {nil} or a list of numbers, specifying the number of syllables of the word with this rhyme; optional and
   currently used only for categorization; if omitted, defaults to the top-level `num_syl`;
** `separator`: {nil} or the string used to separate this rhyme from the preceding one when displayed; defaults to the
   top-level `separator`;
** `q`: {nil} or a list of left regular qualifier strings, formatted using {format_qualifier()} in [[Module:qualifier]]
   and displayed directly before the rhyme in question;
** `qq`: {nil} or a list of right regular qualifier strings, displayed directly after the rhyme in question;
** `qualifiers`: {nil} or a list of qualifier strings; also displayed on the left; for compatibility purposes only, do
   not use in new code;
** `a`: {nil} or a list of left accent qualifier strings, formatted using {format_qualifiers()} in
   [[Module:accent qualifier]] and displayed directly before the rhyme in question;
** `aa`: {nil} or a list of right accent qualifier strings, displayed directly after the rhyme in question;
** `refs`: {nil} or a list of references or reference specs to add directly after the rhyme; the value of a list item is
   either a string containing the reference text (typically a call to a citation template such as {{tl|cite-book}}, or a
   template wrapping such a call), or an object with fields `text` (the reference text), `name` (the name of the
   reference, as in {{cd|<nowiki><ref name="foo">...</ref></nowiki>}} or {{cd|<nowiki><ref name="foo" /></nowiki>}})
   and/or `group` (the group of the reference, as in {{cd|<nowiki><ref name="foo" group="bar">...</ref></nowiki>}} or
   {{cd|<nowiki><ref name="foo" group="bar"/></nowiki>}}); this uses a parser function to format the reference
   appropriately and insert a footnote number that hyperlinks to the actual reference, located in the
   {{cd|<nowiki><references /></nowiki>}} section;
** `nocat`: if {true}, suppress categorization for this rhyme only;
* `num_syl`: {nil} or a list of numbers, specifying the number of syllables for all rhymes; optional and currently used
  only for categorization; overridable at the individual rhyme level;
* `separator`: {nil} or a string, specifying the separator displayed before all rhymes but the first; by default,
  {", "}; overridable at the individual rhyme level;
* `q`: {nil} or a list of left regular qualifier strings, formatted using {format_qualifier()} in [[Module:qualifier]]
  and displayed before the initial caption;
* `qq`: {nil} or a list of right regular qualifier strings, displayed after all rhymes;
* `qualifiers`: {nil} or a list of left regular qualifier strings; for compatibility purposes only, do not use in new
  code;
* `a`: {nil} or a list of left accent qualifier strings, formatted using {format_qualifiers()} in
  [[Module:accent qualifier]] and dispalyed before the initial caption;
* `aa`: {nil} or a list of right accent qualifier strings, displayed after all rhymes;
* `sort`: {nil} or sort key;
* `caption`: {nil} or string specifying the caption to use, in place of {"Rhymes"}; a colon and space is automatically
  added after the caption;
* `nocaption`: if {true}, suppress the caption display;
* `nocat`: if {true}, suppress categorization;
* `force_cat`: if {true}, force categorization even on non-mainspace pages.

If both regular and accent qualifiers on the same side and at the same level are specified, the accent qualifiers
precede the regular qualifiers on both left and right.

'''WARNING''': Destructively modifies the objects inside the `rhymes` field.

Note that the number of syllables is currently used only for categorization; if present, an extra category will
be added such as [[Category:Rhymes:Italian/ino/3 syllables]] in addition to [[Category:Rhymes:Italian/ino]].
]==]
	function export.format_rhymes(data)
		local langname = data.lang:getCanonicalName()
		local parts = {}
		local categories = {}
		local overall_sep = data.separator or ", "
		for i, r in ipairs(data.rhymes) do
			local rhyme = r.rhyme
			local link, link_cats = make_rhyme_link(data.lang, rhyme, "-" .. rhyme)
			if not r.nocat and not data.nocat then
				for _, cat in ipairs(link_cats) do
					insert(categories, cat)
				end
			end
			if r.q and r.q[1] or r.qq and r.qq[1] or r.qualifiers and r.qualifiers[1]
				or r.a and r.a[1] or r.aa and r.aa[1] or r.refs and r.refs[1] then
				link = require(pron_qualifier_module).format_qualifiers {
					lang = data.lang,
					text = link,
					q = r.q,
					qq = r.qq,
					qualifiers = r.qualifiers,
					a = r.a,
					aa = r.aa,
					refs = r.refs,
				}
			end
			insert(parts, r.separator or i > 1 and overall_sep or "")
			insert(parts, link)
			if not r.nocat and not data.nocat then
				add_syllable_categories(categories, langname, rhyme, r.num_syl or data.num_syl)
			end
		end

		local text = concat(parts)
		if not data.nocaption then
			text = (data.caption or "Rhymes") .. ": " .. text
		end
		if data.q and data.q[1] or data.qq and data.qq[1] or data.a and data.a[1] or data.aa and data.aa[1] then
			text = require(pron_qualifier_module).format_qualifiers {
				lang = data.lang,
				text = text,
				q = data.q,
				qq = data.qq,
				a = data.a,
				aa = data.aa,
			}
		end
		if categories[1] then
			local categories = require(utilities_module).format_categories(categories, data.lang, data.sort, nil,
				force_cat or data.force_cat)
			text = text .. categories
		end
		return text
	end
end

do
	local function parse_num_syl(arg, parse_err)
		arg = rsplit(arg, "%s*,%s*")
		local ret = {}
		for _, v in ipairs(arg) do
			local n = tonumber(v) or parse_err("Unrecognized #syllables '" .. v .. "', should be a number")
			insert(ret, n)
		end
		return ret
	end

	--[==[
	Implementation of {{tl|rhymes}}.
	]==]
	function export.show(frame)
		local parent_args = frame:getParent().args
		local compat = parent_args.lang
		local offset = compat and 0 or 1

		local plain = {}
		local boolean = {type = "boolean"}
		local params = {
			[compat and "lang" or 1] = {required = true, type = "language", etym_lang = true, default = "en"},
			[1 + offset] = {list = true, required = true, disallow_holes = true, default = "aɪmz"},
			["caption"] = plain,
			["nocaption"] = boolean,
			["nocat"] = boolean,
			["sort"] = plain,
		}

		local param_mods = {
			s = {
				item_dest = "num_syl",
				separate_no_index = true,
				convert = parse_num_syl,
			},
		}

		local m_param_utils = require(parameter_utilities_module)

		m_param_utils.augment_param_mods_with_pron_qualifiers(param_mods)
		m_param_utils.augment_params_with_modifiers(params, param_mods)

		local args = require("Module:parameters").process(parent_args, params)

		local lang = args[compat and "lang" or 1]

		local rhymes = m_param_utils.process_list_arguments {
			args = args,
			param_mods = param_mods,
			termarg = 1 + offset,
			term_dest = "rhyme",
			track_module = "rhymes",
		}

		local data = {
			lang = lang,
			rhymes = rhymes,
			num_syl = args.s.default and parse_num_syl(args.s.default) or nil,
			caption = args.caption,
			nocaption = args.nocaption,
			nocat = args.nocat,
			sort = args.sort,
		}
		require(pron_qualifier_module).parse_qualifiers {
			store_obj = data,
			q = args.q.default,
			qq = args.qq.default,
			a = args.a.default,
			aa = args.aa.default,
		}

		return export.format_rhymes(data)
	end
end

--[==[
Implementation of {{tl|rhymes nav}}.
]==]
function export.show_nav(frame)
	local args = require(parameters_module).process(
		frame:getParent().args,
		{
			[1] = {required = true, type = "language", default = "und"},
			[2] = {list = true, allow_holes = true},
			["nocat"] = {type = "boolean"},
		}
	)

	local lang = args[1]
	local langname = lang:getCanonicalName()
	local parts = args[2]

	-- Create steps
	-- FIXME: We should probably use format_categories() in [[Module:utilities]] rather than constructing categories
	-- manually.
	local categories = {}
	-- Here and below, we ignore any cleanup categories coming out of make_rhyme_link() by adding an extra set of parens
	-- around the call to make_rhyme_link() to cause the second argument (the categories) to be ignored. {{rhymes nav}}
	-- is run on a rhymes page so it's not clear we want the page to be added to any such categories, if they exist.
	local steps = {"[[Wiktionary:Rhymes|Rhymes]]", (make_rhyme_link(lang))}

	if #parts > 0 then
		local last = parts[#parts]
		parts[#parts] = nil
		local prefix = ""

		for i, part in ipairs(parts) do
			prefix = prefix .. part
			parts[i] = prefix
		end

		for _, part in ipairs(parts) do
			insert(steps, (make_rhyme_link(lang, part .. "-", "-" .. part .. "-")))
		end

		if last == "-" then
			insert(steps, (make_rhyme_link(lang, prefix, "-" .. prefix)))
			insert(categories, "[[Category:" .. langname .. " rhymes" .. (prefix == "" and "" or "/" .. prefix .. "-") .. "| ]]")
		elseif mw.title.getCurrentTitle().text == langname .. "/" .. prefix .. last .. "-" then
			insert(steps, (make_rhyme_link(lang, prefix .. last .. "-", "-" .. prefix .. last .. "-")))
			insert(categories, "[[Category:" .. langname .. " rhymes/" .. prefix .. last .. "-|-]]")
		else
			insert(steps, (make_rhyme_link(lang, prefix .. last, "-" .. prefix .. last)))
			insert(categories, "[[Category:" .. langname .. " rhymes" .. (prefix == "" and "" or "/" .. prefix .. "-") .. "|" .. last .. "]]")
		end
	elseif lang:getCode() ~= "und" then
		insert(categories, "[[Category:" .. langname .. " rhymes| ]]")
	end

	if mw.title.getCurrentTitle().nsText == "Rhymes" then
		frame:callParserFunction("DISPLAYTITLE",
			mw.title.getCurrentTitle().fullText:gsub(
				"/(.+)$",
				function (rhyme)
					return "/" .. (tag_rhyme(rhyme, lang)) -- ignore cleanup categories
				end))
	end

	local templateStyles = require(TemplateStyles_module)(rhymes_styles_css_module)

	local ol = mw.html.create("ol")
	for _, step in ipairs(steps) do
		ol:node(mw.html.create("li"):wikitext(step))
	end
	local div = mw.html.create("div")
		:attr("role", "navigation")
		:attr("aria-label", "Breadcrumb")
		:addClass("ts-rhymesBreadcrumbs")
		:node(ol)

	local formatted_cats = args.nocat and "" or concat(categories)
	return templateStyles .. tostring(div) .. formatted_cats
end

return export
