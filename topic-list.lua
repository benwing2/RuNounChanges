local export = {}

local columns_module = "Module:columns"
local parameters_module = "Module:parameters"

local function letter_like_category(data)
	return ("Category:%s letters"):format(data.lang:getCanonicalName())
end

local function page_exists(page)
	local title = mw.title.new(appendix)
	return title and title.exists
end

local function letter_like_appendix(data)
	local appendices = {}
	local alphabet_appendix = ("Appendix:%s alphabet"):format(data.lang:getCanonicalName())
	if page_exists(alphabet_appendix) then
		table.insert(appendices, ("[[%s|alphabet appendix]]"):format(alphabet_appendix))
	end
	local script_name = data.default_title:match("^(.* script) .*$")
	if not script_name then
		error(("Internal error: Can't pull out script name from default title '%s'"):format(data.default_title))
	end
	local script_appendix = "Appendix:" .. script_name
	if page_exists(script_appendix) then
		table.insert(appendices, ("[[%s|script appendix]]"):format(script_appendix))
	end
	if appendices[1] then
		return table.concat(appendices, ",")
	else
		return nil
	end
end

local letter_like_properties = {
	horiz = "comma",
	sort = false,
	cat = letter_like_category,
	appendix = letter_like_appendix,
	notr = true,
	space_delim = true,
	narrow_tilde = true,
}

local function letter_name_category(data)
	local script_name = data.default_title:match("^(.*) script .*$")
	if not script_name then
		error(("Internal error: Can't pull out script name from default title '%s'"):format(data.default_title))
	end
	return ("%s letter names"):format(script_name)
end

local topic_list_properties = {
	{".* calendar months", {sort = false}},
	{".* calendar month adjectives", {sort = false}},
	{".* script letters", letter_like_properties},
	{".* script vowels", letter_like_properties},
	{".* script consonants", letter_like_properties},
	{".* script diacritics", letter_like_properties},
	{".* script digraphs", letter_like_properties},
	-- FIXME: We may need to be smarter, and use a regular columnar display in some cases (e.g. when translit is
	-- present)
	{".* script letter names", {horiz = "bullet", sort = false, cat = letter_name_category}},
	{"books of the.* Testament", {sort = false, cat = "Books of the Bible"}},
	{"canids", {horiz = "bullet"}}, -- only 5 items on most lists
	{"countries in .*", {appendix = "Appendix:Countries of the world"}},
	{"days of the week", {horiz = "bullet", sort = false, appendix = "Appendix:Days of the week"}},
	{"dentistry location adjectives", {cat = "Dentistry"}},
	{"electromagnetic radiation", {sort = false, cat = "Electromagnetism"}},
	{"fundamental interactions", {cat = "Physics"}},
	{"geological time units", {sort = false, cat = "Units of time,Geology"}},
	{"human anatomy location adjectives", {cat = "Medicine"}},
	{"Islamic prophets", {sort = false}},
	{"leptons", {sort = false, horiz = "bullet"}},
	{"antileptons", {sort = false, horiz = "bullet", cat = "Leptons"}},
	{"oceans", {horiz = "bullet"}},
	{"planets of the Solar System", {horiz = "bullet", sort = false}},
	{"quarks", {sort = false, horiz = "bullet"}},
	{"squarks", {sort = false, horiz = "bullet", cat = "Quarks"}},
	{"antiquarks", {sort = false, horiz = "bullet", cat = "Quarks"}},
	{"religions", {cat = "Religion"}}, -- FIXME, use "Religions"
	{"religious adherents", {cat = "Religion"}},
	{"religious texts", {cat = "Religion"}},
	{"seasons", {horiz = "bullet", sort = false}},
	{"sexual orientation adjectives", {cat = "Sexual orientations"}},
	{"taxonomic ranks", {sort = false}},
	{"times of day", {sort = false}},
	{"units of time", {sort = false}},
}

--[==[
This implements topic lists. A given topic list template must directly invoke this function rather than
going through a wrapping template. A sample template implementation (e.g. for {{tl|list:continents/sw}}) is
{
{{#invoke:topic list|show|sw
|hypernym=[[bara|mabara]]
|Afrika<t:Africa>
|Antaktika~Antaktiki<t:Antarctica>
|Asia<t:Asia>
|Ulaya,Uropa<t:Europe>
|Amerika ya Kaskazini<t:North America>
|Amerika ya Kusini<t:South America>
|Australia<t:Australia>
}}
}

The syntax of the params is largely the same as for {{tl|col}}, but the following additional params supported:
* {{para|cat}}: Comma-separated list of categories to add the page to. The categories should specify bare topic
  categories without the preceding language code, e.g. `Islamic calendar months` for a category
  `LANGCODE:Islamic calendar months`. If you need to specify a different type of category, prefix the full category name
  with `Category:`. There must not be any spaces after the comma delimiter for it to be recognized as such. By default,
  the category comes from the template name, minus the initial `list:` and anything starting with a slash, and with the
  first letter capitalized; but only if the top-level language-agnostic category exists. Hence a template like
  {{tl|list:prefectures of Japan/ja}} will automatically categorize into [[:Category:ja:Prefectures of Japan]] (and
  likewise {{tl|list:prefectures of Japan/sq}} will still categorize into [[:Category:sq:Prefectures of Japan]] whether
  or not it exists, because the top-level [[:Category:Prefectures of Japan]] exists), but a template like
  {{tl|list:human anatomy direction adjectives/en}} will not categorize anywhere by default because there is no
  top-level [[:Category:Human anatomy direction adjectives]]. Use {{para|cat|-}} to disable categorization. Note that no
  categorization takes place if {{para|nocat|1}} is specified in the invocation of the list template or if the page is
  the same as any of the pages linked to by the language-specific hypernym(s) given in {{para|hypernym}}.
* {{para|hypernym}}: The language-specific plural form of the hypernym category (e.g. in the above example, the word for
  "continents" in Swahili). Generally this should be linked to the corresponding singular, if they are different. If
  specified, it is displayed after the English hypernym, following a colon. This parameter can be omitted to not display
  a hypernym, and you can also specify multiple comma-separated or tilde-separated hypernyms with inline modifiers
  attached to each one (essentially, following the format of a given item in {{tl|col}}).
* {{para|enhypernym}}: The English-language hypernym, e.g. `continents` in the above example. If omitted, this is
  derived from the template name by chopping off the initial `list:` and anything starting with a slash. This will be
  hyperlinked to the first category that the page categorizes into, if such a category exists.
]==]
function export.show(frame)
	local raw_item_args = frame.args
	local frame_parent = frame:getParent()
	local raw_user_args = frame_parent.args
	local topic_list_template = frame_parent:getTitle()

	local user_params = {
		nocat = {type = "boolean"},
		sortbase = {},
	}

	local user_args = require(parameters_module).process(raw_user_args, user_params)

	return require(columns_module).handle_display_from_or_topic_list(
		{minrows = 2, sort = true, collapse = true}, raw_item_args, user_args, topic_list_template)
end

return export
