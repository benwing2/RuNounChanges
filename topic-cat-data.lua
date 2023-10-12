local labels = {}
local handlers = {}

local top_level_data_module = "Module:category tree/topic cat/data"
local data_module_prefix = top_level_data_module .. "/"

local subpages = {
	"Body",
	"Buildings and structures",
	"Communication",
	"Culture",
	"Earth",
	"Food and drink",
	"History",
	"Human",
	"Lifeforms",
		"Animals",
		"Plants",
	"Mathematics",
	"Miscellaneous",
	"Names",
	"Nature",
	"Numbers",
	"People",
	"Philosophy",
	"Places",
	"Sciences",
	"Sex",
	"Social acts",
	"Society",
	"Sports",
	"Technology",
	"Time",
	"Transport",
	"Physical actions",
}

labels["all topics"] = {
	type = "toplevel",
	description = "{{{langname}}} terms organized by topic, such as \"Family\" or \"Chemistry\".",
	parents = {{module = "poscatboiler", args = {label = "{{{langcat}}}", raw = true, called_from_inside = true}}},
}

labels["list of topics"] = {
	type = "toplevel",
	description = "All topics currently available in {{{langname}}}.",
	parents = {{name = "all topics", sort = " *"}},
}

labels["all sets"] = {
	type = "toplevel",
	description = "{{{langname}}} terms that belong to a particular set of things, such as \"Planets\" or \"Canids\".",
	parents = {{module = "poscatboiler", args = {label = "{{{langcat}}}", raw = true, called_from_inside = true}}},
}

labels["list of sets"] = {
	type = "toplevel",
	description = "All sets currently available in {{{langname}}}.",
	parents = {{name = "all sets", sort = " *"}},
}

labels["list of name categories"] = {
	type = "toplevel",
	description = "All name categories currently available in {{{langname}}}.",
	parents = {{name = "all sets", sort = " *"}},
}

labels["list of type categories"] = {
	type = "toplevel",
	description = "All type categories currently available in {{{langname}}}.",
	parents = {{name = "all sets", sort = " *"}},
}

for label, data in pairs(labels) do
	data.module = top_level_data_module
end

-- Import subpages
for _, subpage in ipairs(subpages) do
	local datamodule = data_module_prefix .. subpage
	local retval = require(datamodule)
	if not retval["LABELS"] then
		retval = {LABELS = retval}
	end
	for label, data in pairs(retval["LABELS"]) do
		if labels[label] and not retval["IGNOREDUP"] then
			error("Label " .. label .. " defined in both [["
				.. datamodule .. "]] and [[" .. labels[label].module .. "]].")
		end
		data.module = datamodule
		labels[label] = data
	end
	if retval["HANDLERS"] then
		for _, handler in ipairs(retval["HANDLERS"]) do
			table.insert(handlers, { module = datamodule, handler = handler })
		end
	end
end

return {LABELS = labels, HANDLERS = handlers}
