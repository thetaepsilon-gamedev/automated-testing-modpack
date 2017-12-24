local i = {}



-- get a content ID or raise an exception.
-- get_content_id returns CONTENT_IGNORE for invalid names at the time of writing.
-- first check that as it's not documented in lua_api.txt
local invalid = "__this_name_cant_possibly_exist_ever"
local ignore = minetest.CONTENT_IGNORE
assert(minetest.get_content_id(invalid) == ignore)

local get_content_id = function(name, prefix)
	prefix = prefix or ""
	local id = minetest.get_content_id(name)
	if id == ignore then
		error(prefix.."node name "..name.." was not a valid node")
	end
	return id
end
i.get_content_id_throw = get_content_id



-- fill an area with a single node and param2 value.
-- this version doesn't do any checking of the loaded area,
-- and defaults to voxelmanip's "rounding up" to whole chunks
-- returns: minp, maxp, dimensions of region as a vector, and volume.
local fill_area_chunks = function(pos1, pos2, nodename, param2v)
	param2v = param2v or 0
	local cid = get_content_id(nodename, "unable to determine content id: ")
	local vm = VoxelManip(pos1, pos2)
	local minp, maxp = vm:get_emerged_area()

	-- we're not interested in existing map data,
	-- so determine the flat 3D array size manually and pre-fill it.
	local dim = vector.subtract(maxp, minp)

	-- note that volumes are inclusive of the node they are in
	local x = (dim.x + 1)
	local y = (dim.y + 1)
	local z = (dim.z + 1)
	local volume =  x*y*z 

	local data = {}
	local param2 = {}
	for i = 1, volume, 1 do
		data[i] = cid
		param2[i] = param2v
	end
	vm:set_data(data)
	vm:set_param2_data(param2)
	vm:write_to_map(true)	-- update light also

	return minp, maxp, vector.new(x, y, z), volume
end
i.fill_area_chunks = fill_area_chunks



-- whereas this version does an exact area.
-- due to the whole chunk restriction,
-- modifying parts of them is a read-modify-write operation.
-- returns the cuboid of the modified region as a minp/maxp pair, and updated volume.
local inrange = function(lower, x, upper)
	return (lower <= x) and (x <= upper)
end
local fill_area_exact = function(pos1, pos2, nodename, param2v)
	param2v = param2v or 0
	local cid = get_content_id(nodename, "unable to determine content id: ")
	local vm = VoxelManip(pos1, pos2)
	local minpa, maxpa = vm:get_emerged_area()

	-- determine the xyz bounds of the actual region.
	local dima = vector.subtract(maxpa, minpa)
	-- don't subtract one as the for-loop bounds below are inclusive anyway,
	-- and we start the x/y/z at zero to match the index position in the flattened 3d array.
	local xa = (dima.x)
	local ya = (dima.y)
	local za = (dima.z)

	-- the target region is always a subset of the rounded-up-to-chunk vm region.
	-- we therefore need to calculate which xyz offsets inside the region to touch.
	local minpt, maxpt = vector.sort(pos1, pos2)
	local minoffset = vector.subtract(minpt, minpa)
	local maxoffset = vector.subtract(maxpt, maxpa)	-- will end up negative
	local xrmin = minoffset.x
	local yrmin = minoffset.y
	local zrmin = minoffset.z
	local xrmax = xa + maxoffset.x
	local yrmax = ya + maxoffset.y
	local zrmax = za + maxoffset.z

	local data = vm:get_data()
	local param2 = vm:get_param2_data()
	local index = 1
	local volume = 0
	-- sorry about the formatting... too many indents otherwise
	for z = 0, za, 1 do
	for y = 0, ya, 1 do
	for x = 0, xa, 1 do
		if inrange(xrmin, x, xrmax) and inrange(yrmin, y, yrmax) and inrange(zrmin, z, zrmax) then
			data[index] = cid
			param2[index] = param2v
			volume = volume + 1
		end
		index = index + 1
	end
	end
	end

	vm:set_data(data)
	vm:set_param2_data(param2)
	vm:write_to_map(true)	-- update light also

	return minpt, maxpt, volume
end
i.fill_area_exact = fill_area_exact



-- lint note: intentional global assignment
testhelpers = i
