--------------------------------------------------------------------------------
-- Rail network handling and ARS simulation
--------------------------------------------------------------------------------
if not Drivtrams.Paths then
	-- Definition of paths used in runtime
	Drivtrams.Paths = {}
	-- Spatial lookup for nodes
	Drivtrams.SpatialLookup = {}
	
	-- List of signal entities for every track segment/node
	Drivtrams.SignalEntitiesForNode = {}
	-- List of nodes for every signal entity
	Drivtrams.SignalEntityPositions = {}
	-- List of track switches for every track segment/node
	Drivtrams.SwitchesForNode = {}
	-- List of trains for every segment/node
	Drivtrams.TrainsForNode = {}
	-- List of train positions
	Drivtrams.TrainPositions = {}
	
	-- List of stations/platforms
	Drivtrams.Stations = {}
	
	-- List of ARS subsections
	Drivtrams.ARSSubSections = {}
	
	-- Should position updates in switches and signals be ignores
	Drivtrams.IgnoreEntityUpdates = false
end




--------------------------------------------------------------------------------
-- Size of spatial cells into which all the 3D space is divided
local SPATIAL_CELL_WIDTH = 1024
local SPATIAL_CELL_HEIGHT = 256

-- Return spatial cell indexes for given XYZ
local function spatialPosition(pos)
	return math.floor(pos.x/SPATIAL_CELL_WIDTH),
		   math.floor(pos.y/SPATIAL_CELL_WIDTH),
		   math.floor(pos.z/SPATIAL_CELL_HEIGHT)
end

-- Return list of nodes in spatial cell kx,ky,kz
local empty_table = {}
local function spatialNodes(kx,ky,kz)
	if Drivtrams.SpatialLookup[kz] then
		if Drivtrams.SpatialLookup[kz][kx] then
			return Drivtrams.SpatialLookup[kz][kx][ky] or empty_table
		else
			return empty_table
		end
	else
		return empty_table
	end
end


--------------------------------------------------------------------------------
-- for nodeID,node in Metrostroi.NearestNodes(pos) do ... end
--
-- This is used for iterating through nodes around given position
--------------------------------------------------------------------------------
function Drivtrams.NearestNodes(pos)
	local kx,ky,kz = spatialPosition(pos)
	local t = {}
	for x=-1,1 do for y=-1,1 do for z=-1,1 do
		table.insert(t,spatialNodes(kx+x,ky+y,kz+z))
	end end end
	
	local i,j = 0,1
	return function ()
		-- Find next set of nodes that's not empty
		while (j <= #t) and (i >= #t[j]) do 
			j = j + 1; i = 0 
		end
		-- Should iterator end
		if j > #t then return nil end
		
		-- Iterate table like normal
		i = i + 1
		if i <= #t[j] then return t[j][i].id,t[j][i] end
	end
end


--------------------------------------------------------------------------------
-- Return position on track for target XYZ
--
-- Simply checks every line between two nodes, for all ndoes around position
--------------------------------------------------------------------------------
function Drivtrams.GetPositionOnTrack(pos,ang,opts)
	if not opts then opts = empty_table end
	
	-- Angle can be specified to determine if facing forward or backward
	ang = ang or Angle(0,0,0)
	
	-- Size of box which envelopes region of space that counts as being on track
	local X_PAD = 0
	local Y_PAD = opts.y_pad or opts.radius or 384/2
	local Z_PAD = opts.z_pad or 256/2
	
	-- Find position on any track
	local results = {}
	for nodeID,node in Drivtrams.NearestNodes(pos) do		
		-- Get local coordinate system of a section
		local forward = node.dir
		local up = Vector(0,0,1)
		local right = forward:Cross(up)

		-- Transform position into local coordinates
		local local_pos = pos - node.pos
		local local_x = local_pos:Dot(forward)
		local local_y = local_pos:Dot(right)
		local local_z = local_pos:Dot(up)
		local yz_delta = math.sqrt(local_y^2 + local_z^2)

		-- Determine if facing forward or backward
		local local_dir = ang:Forward()
		local dir_delta = local_dir:Dot(forward)
		local dir_forward = dir_delta > 0
		local dir_angle = 90-math.deg(math.acos(dir_delta))

		-- If this position resides on track, add it to results
		if ((local_x > -X_PAD) and (local_x < node.vec:Length()+X_PAD) and
			(local_y > -Y_PAD) and (local_y < Y_PAD) and
			(local_z > -Z_PAD) and (local_z < Z_PAD)) and (node.path ~= opts.ignore_path) then

			table.insert(results,{
				node1 = node,
				node2 = node.next,
				path = node.path,
				
				angle = dir_angle,				-- Angle between forward vector and axis of track
				forward = dir_forward,			-- Is facing forward relative to track
				x = local_x*0.01905 + node.x,	-- Local coordinates in track curvilinear coordinates
				y = local_y*0.01905,			--
				z = local_z*0.01905,			--
				
				distance = yz_delta,			-- Distance to path axis
			})
		end	
	end
	
	-- Sort results by distance
	table.sort(results, function(a,b) return a.distance < b.distance end)
	
	-- Return list of positions
	return results
end


--------------------------------------------------------------------------------
-- Return XYZ for given position on path
--------------------------------------------------------------------------------
function Drivtrams.GetTrackPosition(path,x)
	-- Build a lookup
	if not path.GetTrackPosition then
		path.GetTrackPosition = {}
		for nodeID,node in ipairs(path) do
			if not path.GetTrackPosition[math.floor(node.x/500)] then
				path.GetTrackPosition[math.floor(node.x/500)] = nodeID
			end
		end
	end

	-- Find offset on path path.GetTrackPosition[math.floor(x/200)] or 
	local startNodeID = 1
	for nodeID=startNodeID,#path do
		local node = path[nodeID]
		if (node.x < x) and (path[nodeID+1]) and (path[nodeID+1].x > x) then
			local dir1 = node.dir
			local dir2 = path[nodeID+1].dir
			local t = (x - node.x)/node.length
			return (node.pos+node.vec*t),dir1*(1-t)+dir2*t,node
		end
	end
end


--------------------------------------------------------------------------------
-- Update list of signal entities and signal positions on track
--------------------------------------------------------------------------------
function Drivtrams.UpdateSignalEntities()
	local options = { z_pad = 256 }
	if Drivtrams.IgnoreEntityUpdates then return end
	Drivtrams.SignalEntitiesForNode = {}
	Drivtrams.SignalEntityPositions = {}
	
	local entities = ents.FindByClass("gmod_track_signal")
	for k,v in pairs(entities) do
		local pos = Drivtrams.GetPositionOnTrack(v:GetPos(),v:GetAngles() - Angle(0,90,0),options)[1]
		if pos then -- FIXME make it select proper path
			Drivtrams.SignalEntitiesForNode[pos.node1] = 
				Drivtrams.SignalEntitiesForNode[pos.node1] or {}
			table.insert(Drivtrams.SignalEntitiesForNode[pos.node1],v)

			-- A signal belongs only to a single track
			Drivtrams.SignalEntityPositions[v] = pos
			v.TrackPosition = pos
			v.TrackX = pos.x
		--else
			--print("position not found",k,v)
		end
	end
end


--------------------------------------------------------------------------------
-- Update lists of switches
--
-- This is used for searching where the switches belong on tracks. One switch
-- belongs to one track.
--------------------------------------------------------------------------------
function Drivtrams.UpdateSwitchEntities()
	if Drivtrams.IgnoreEntityUpdates then return end
	Drivtrams.SwitchesForNode = {}
	
	local entities = ents.FindByClass("gmod_track_switch")
	for k,v in pairs(entities) do
		local pos = Drivtrams.GetPositionOnTrack(v:GetPos(),v:GetAngles() - Angle(0,90,0))[1]
		if pos then
			Drivtrams.SwitchesForNode[pos.node1] = Drivtrams.SwitchesForNode[pos.node1] or {}
			table.insert(Drivtrams.SwitchesForNode[pos.node1],v)
			v.TrackPosition = pos -- FIXME: check that one switch belongs to one track
		end
	end	
end


--------------------------------------------------------------------------------
-- Add additional ARS element in the given node
--
-- These ARS elements do not isolate track signals, only isolate ARS signals
--------------------------------------------------------------------------------
function Drivtrams.AddARSSubSection(node,source)
	local ent = ents.Create("gmod_track_signal")
	if not IsValid(ent) then return end
	
	local tr = Drivtrams.RerailGetTrackData(node.pos - node.dir*32,node.dir)
	if not tr then return end
	
	ent:SetPos(tr.centerpos - tr.up * 9.5)
	ent:SetAngles((-tr.right):Angle())
	ent:Spawn()
	ent:SetLightsStyle(0)
	ent:SetTrafficLights(0)
	ent:SetSettings(0)
	ent:SetIsolatingLight(false)
	ent:SetIsolatingSwitch(false)
	
	-- Add to list of ARS subsections
	Drivtrams.ARSSubSections[ent] = true
	Drivtrams.ARSSubSectionCount = Drivtrams.ARSSubSectionCount + 1
end


--------------------------------------------------------------------------------
-- Update ARS sections (and add additional subsections
--------------------------------------------------------------------------------
function Drivtrams.UpdateARSSections()
	Drivtrams.ARSSubSections = {}
	Drivtrams.ARSSubSectionCount = 0

	print("Drivtrams: Updating ARS subsections...")
	Drivtrams.IgnoreEntityUpdates = true
	for k,v in pairs(Drivtrams.SignalEntityPositions) do
		-- Find signal which sits BEFORE this signal
		local signal = Drivtrams.GetARSJoint(v.node1,v.x,false)
		
		--Metrostroi.GetNextTrafficLight(v.node1,v.x,not v.forward,true)
		if IsValid(k) and signal then
			local pos = Drivtrams.SignalEntityPositions[signal]
			--debugoverlay.Line(k:GetPos(),signal:GetPos(),10,Color(0,0,255),true)

			-- Interpolate between two positions and add intermediates
			local count = 0
			local offset = 0
			local delta_offset = 120 --100
			if (v.path == pos.path) and (pos.x < v.x) then
				--print(Format("Metrostroi: Adding ARS sections between [%d] %.0f -> %.0f m",pos.path.id,pos.x,v.x))
				local node = pos.node1
				while (node) and (node ~= v.node1) do
					if (offset > delta_offset) and (math.abs(node.x - v.x) > delta_offset) then
						Drivtrams.AddARSSubSection(node,signal)
						offset = offset - delta_offset
						count = count + 1
					end
	
					node = node.next
					if node then
						offset = offset + node.length
					end
				end
			end
			--if count == 0 then
				--print("Could not add any signals for",k)
			--end
		end
	end
	Drivtrams.IgnoreEntityUpdates = false
	Drivtrams.UpdateSignalEntities()
	
	print(Format("Drivtrams: Added %d ARS rail joints",Drivtrams.ARSSubSectionCount))
end


--------------------------------------------------------------------------------
-- Scans an isolated track segment and for every useable segment calls func
--------------------------------------------------------------------------------
local check_table = {}
function Drivtrams.ScanTrack(itype,node,func,x,dir,checked)
	-- Check if this node was already scanned
	if not node then return end
	if not checked then 
		for k,v in pairs(check_table) do
			check_table[k] = nil
		end
		checked = check_table
	end
	if checked[node] then return end	
	checked[node] = true

	-- Try to use entire node length by default
	local min_x = node.x
	local max_x = min_x + node.length
	
	-- Get range of node which can be actually sensed
	local isolateForward = false	-- Should scanning continue forward along track
	local isolateBackward = false	-- Should scanning continue backward along track
	if Drivtrams.SignalEntitiesForNode[node] then
		for k,v in pairs(Drivtrams.SignalEntitiesForNode[node]) do
			local isolating = false
			if IsValid(v) then
				if itype == "light" then isolating = v:GetIsolatingLight() end
				if itype == "switch" then isolating = v:GetIsolatingSwitch() end
				if itype == "ars" then isolating = true end
			end
			if isolating then
				-- If scanning forward, and there's a joint IN FRONT of current X
				if dir and (v.TrackX > x) then
					max_x = math.min(max_x,v.TrackX)
					isolateForward = true
				end
				-- If scanning forward, and there's a joint in current X
				-- This is triggered when traffic light searches for next light from its own X (then
				--  scan direction is defined by dir)
				if dir and (v.TrackX == x) then
					min_x = math.max(min_x,v.TrackX)
					isolateBackward = true
				end
				-- if scanning backward, and there's a joint BEHIND current X
				if (not dir) and (v.TrackX < x) then
					min_x = math.max(min_x,v.TrackX)
					isolateBackward = true
				end
				-- If scanning backward starting from current X, use dir for guiding scan
				if (not dir) and (v.TrackX == x) then
					max_x = math.min(max_x,v.TrackX)
					isolateForward = true
				end
			end
		end
	end
	
	-- Show the scanned path
	--[[if GetConVarNumber("metrostroi_drawdebug") == 1 then
		local T = CurTime()
		timer.Simple(0.05 + math.random()*0.05,function()
			if node.next then
				debugoverlay.Line(node.pos,node.next.pos,3,Color((T*1234)%255,(T*12345)%255,(T*12346)%255),true)
			end
		end)
	end]]--

	-- Call function for the determined portion of the node
	local result = func(node,min_x,max_x)
	if result ~= nil then return result end

	-- First check all the branches, whose positions fall within min_x..max_x
	if node.branches and (itype ~= "ars") then
		for k,v in pairs(node.branches) do
			if (v[1] >= min_x) and (v[1] <= max_x) then
				-- FIXME: somehow define direction and X!
				local result = Drivtrams.ScanTrack(itype,v[2],func,v[1],true,checked)
				if result ~= nil then return result end
			end
		end
	end
	-- If not isolated, continue scanning forward from the front end of node
	if (not isolateForward) then 
		local result = Drivtrams.ScanTrack(itype,node.next,func,max_x,true,checked)
		if result ~= nil then return result end
	end
	-- If not isolated, continue scanning backward from the rear end of node
	if (not isolateBackward) then
		local result = Drivtrams.ScanTrack(itype,node.prev,func,min_x,false,checked)
		if result ~= nil then return result end
	end
end




--------------------------------------------------------------------------------
-- Get one next traffic light within current isolated segment. Ignores ARS sections.
--------------------------------------------------------------------------------
function Drivtrams.GetNextTrafficLight(src_node,x,dir,include_ars_sections,override_type)
	return Drivtrams.ScanTrack(override_type or "light",src_node,function(node,min_x,max_x)
		-- If there are no signals in node, keep scanning
		if (not Drivtrams.SignalEntitiesForNode[node]) or (#Drivtrams.SignalEntitiesForNode[node] == 0) then
			return
		end

		-- For every signal entity in node, check if it rests on path
		for k,v in pairs(Drivtrams.SignalEntitiesForNode[node]) do
			if IsValid(v) and
				(((v:GetTrafficLights() > 0) or include_ars_sections) and (v.TrackX ~= x) and 
				 (v.TrackX >= min_x) and (v.TrackX <= max_x)) then
				return v
			end
		end
	end,x,dir)
end


--------------------------------------------------------------------------------
-- Get next/previous ARS section
--------------------------------------------------------------------------------
function Drivtrams.GetARSJoint(src_node,x,dir)
	return Drivtrams.ScanTrack("ars",src_node,function(node,min_x,max_x)
		-- If there are no signals in node, keep scanning
		if (not Drivtrams.SignalEntitiesForNode[node]) or (#Drivtrams.SignalEntitiesForNode[node] == 0) then
			return
		end

		-- For every signal entity in node, check if it rests on path
		for k,v in pairs(Drivtrams.SignalEntitiesForNode[node]) do
			if IsValid(v) and
				((not v:GetNoARS()) and (v.TrackX ~= x) and 
				 (v.TrackX >= min_x) and (v.TrackX <= max_x)) then
				if dir and (v.TrackX > x) then return v end
				if (not dir) and (v.TrackX < x) then return v end
			end
		end
	end,x,dir)
end


--------------------------------------------------------------------------------
-- Get all track switches in an isolated section
--------------------------------------------------------------------------------
function Drivtrams.GetTrackSwitches(src_node,x,dir)
	local switches = {}
	Drivtrams.ScanTrack("switch",src_node,function(node,min_x,max_x)
		-- If there are no signals in node, keep scanning
		if (not Drivtrams.SwitchesForNode[node]) or (#Drivtrams.SwitchesForNode[node] == 0) then
			return
		end

		-- For every entity in node, check if it rests on path
		for k,v in pairs(Drivtrams.SwitchesForNode[node]) do
			if v.TrackPosition and 
				(v.TrackPosition.x >= min_x) and (v.TrackPosition.x <= max_x) then
				table.insert(switches,v)
			end
		end
	end,x,dir)
	
	-- Find similar switches and add them even if they aren't on the same section
	local ent_list = ents.FindByClass("gmod_track_switch")
	local extra_switches = {}
	for k,v in pairs(switches) do
		if v.TrackSwitches[1] then
			local name = v.TrackSwitches[1]:GetName()
			for _,v2 in pairs(ent_list) do
				if v2.TrackSwitches[1] and (v2 ~= v) and (name == v2.TrackSwitches[1]:GetName()) then
					table.insert(extra_switches,v2)
				end
			end
		end
	end
	
	for k,v in pairs(extra_switches) do table.insert(switches,v) end
	return switches
end


--------------------------------------------------------------------------------
-- Check if there is a train somewhere in the local isolated section. This
-- ignores ARS subsections (if they are unisolated), accounts for traffic lights
--------------------------------------------------------------------------------
function Drivtrams.IsTrackOccupied(src_node,x,dir,t)
	return Drivtrams.ScanTrack(t or "light",src_node,function(node,min_x,max_x)
		-- If there are no trains in node, keep scanning
		if (not Drivtrams.TrainsForNode[node]) or (#Drivtrams.TrainsForNode[node] == 0) then
			return
		end
		
		-- For every train in node, for every path it rests on, check if it's in range
		--print("SCAN TRACK",node.id,min_x,max_x)
		for k,v in pairs(Drivtrams.TrainsForNode[node]) do
			local pos = Drivtrams.TrainPositions[v]
			for k2,v2 in pairs(pos) do
				if v2.path == node.path then
					--local x1 = v2.x-1100*0.5
					--local x2 = v2.x+1100*0.5
					--print(x1,x2)
					local x1,x2 = v2.x,v2.x
					if ((x1 >= min_x) and (x1 <= max_x)) or
					   ((x2 >= min_x) and (x2 <= max_x)) or
					   ((x1 <= min_x) and (x2 >= max_x)) then
						return true
					end
				end
			end
		end
	end,x,dir)
end




--------------------------------------------------------------------------------
-- Update train positions
--------------------------------------------------------------------------------
function Drivtrams.UpdateTrainPositions()
	Drivtrams.TrainPositions = {}
	Drivtrams.TrainsForNode = {}

	-- Query all train types
	for _,class in pairs(Drivtrams.TrainClasses) do
		local trains = ents.FindByClass(class)
		for _,train in pairs(trains) do
			local positions = Drivtrams.GetPositionOnTrack(train:GetPos(),train:GetAngles())
			Drivtrams.TrainPositions[train] = {}
			if positions and positions[1] then
				Drivtrams.TrainPositions[train][1] = positions[1]
			end
		
			--print("TRAIN",train)
			--for k,v in pairs(Metrostroi.TrainPositions[train]) do
				--print(Format("\t[%d] Path #%d: (%.2f x %.2f x %.2f) m  Facing %s",k,v.path.id,v.x,v.y,v.z,v.forward and "forward" or "backward"))
			--end
	
			for _,pos in pairs(Drivtrams.TrainPositions[train]) do
				Drivtrams.TrainsForNode[pos.node1] = Drivtrams.TrainsForNode[pos.node1] or {}
				table.insert(Drivtrams.TrainsForNode[pos.node1],train)
			end
		end
	end
end
timer.Create("Drivtrams_TrainPositionTimer",0.50,0,Drivtrams.UpdateTrainPositions)


--------------------------------------------------------------------------------
-- Update stations list
--------------------------------------------------------------------------------
function Drivtrams.UpdateStations()
	Drivtrams.Stations = {}
	local platforms = ents.FindByClass("gmod_track_platform")
	for _,platform in pairs(platforms) do
		local station = Drivtrams.Stations[platform.StationIndex] or {}
		Drivtrams.Stations[platform.StationIndex] = station
		
		-- Position
		local dir = platform.PlatformEnd - platform.PlatformStart
		local pos1 = Drivtrams.GetPositionOnTrack(platform.PlatformStart,dir:Angle())[1]
		local pos2 = Drivtrams.GetPositionOnTrack(platform.PlatformEnd,dir:Angle())[1]

		if pos1 and pos2 then		
			-- Add platform to station
			local platform_data = {
				x_start = pos1.x,
				x_end = pos2.x,
				length = math.abs(pos2.x - pos1.x),
				node_start = pos1.node1,
				node_end = pos2.node1,
			}
			if station[platform.PlatformIndex] then
				print(Format("Drivtrams: Error, station %03d has two platforms %d with same index!",platform.StationIndex,platform.PlatformIndex))
			else
				station[platform.PlatformIndex] = platform_data
			end
			
			-- Print information
			print(Format("\t[%03d][%d] %.3f-%.3f km (%.1f m) on path %d",
				platform.StationIndex,platform.PlatformIndex,pos1.x*1e-3,pos2.x*1e-3,
				platform_data.length,platform_data.node_start.path.id))
		end
	end
end


--------------------------------------------------------------------------------
-- Get travel time between two nodes in seconds
--------------------------------------------------------------------------------
function Drivtrams.GetTravelTime(src,dest)
	-- Determine direction of travel
	assert(src.path == dest.path)
	local direction = src.x < dest.x
	
	-- Accumulate travel time
	local travel_time = 0
	local travel_dist = 0
	local travel_speed = 20
	local node = src
	while (node) and (node ~= dest) do
		local ars_speed
		local ars_joint = Drivtrams.GetARSJoint(node,node.x+0.01,false)
		if ars_joint then
			if ars_joint:GetNominalSignalsBit(14) then ars_speed = 20 end
			if ars_joint:GetNominalSignalsBit(13) then ars_speed = 40 end
			if ars_joint:GetNominalSignalsBit(12) then ars_speed = 60 end
			if ars_joint:GetNominalSignalsBit(11) then ars_speed = 70 end
			if ars_joint:GetNominalSignalsBit(10) then ars_speed = 80 end
		end
		if ars_speed then travel_speed = ars_speed end
		--print(Format("[%03d] %.2f m   V = %02d km/h",node.id,node.length,ars_speed or 0))
		
		-- Assume 70% of travel speed
		local speed = travel_speed * 0.82

		-- Add to travel time
		travel_dist = travel_dist + node.length
		travel_time = travel_time + (node.length / (speed/3.6))
		node = node.next
	end
	
	return travel_time,travel_dist
end




--------------------------------------------------------------------------------
-- Load track definition and sign definitions
--------------------------------------------------------------------------------
function Drivtrams.Load(name,keep_signs)
	name = name or game.GetMap()
	if not file.Exists(string.format("metrostroi_data/track_%s.txt",name),"DATA") then
		print("Track definition file not found: metrostroi_data/track_"..name..".txt")
		return
	end
	if not file.Exists(string.format("metrostroi_data/signs_%s.txt",name),"DATA") then
		print("Sign definition file not found: metrostroi_data/signs_"..name..".txt")
		-- This is optional
	end

	-- Load path data
	print("Drivtrams: Loading track definition...")
	local paths = util.JSONToTable(file.Read(string.format("metrostroi_data/track_%s.txt",name)))
	if not paths then
		print("Parse error in track definition JSON")
		paths = {}
	end
	-- Quick small hack to load tracks as well
	if Drivtrams.TrackEditor then
		Drivtrams.TrackEditor.Paths = paths
	end
	
	-- Prepare spatial lookup table
	Drivtrams.SpatialLookup = {}
	local function addLookup(node)
		local kx,ky,kz = spatialPosition(node.pos)
		
		Drivtrams.SpatialLookup[kz] = Drivtrams.SpatialLookup[kz] or {}
		Drivtrams.SpatialLookup[kz][kx] = Drivtrams.SpatialLookup[kz][kx] or {}
		Drivtrams.SpatialLookup[kz][kx][ky] = Drivtrams.SpatialLookup[kz][kx][ky] or {}
		table.insert(Drivtrams.SpatialLookup[kz][kx][ky],node)
	end
	
	-- Create paths definition
	Drivtrams.Paths = {}
	for pathID,path in pairs(paths) do
		local currentPath = { id = pathID }
		Drivtrams.Paths[pathID] = currentPath
		
		-- Count length of path and offset in every node
		currentPath.length = 0
		local prevPos,prevNode
		for nodeID,nodePos in pairs(path) do
			-- Count distance
			local distance = 0
			if prevPos then 
				distance = prevPos:Distance(nodePos)*0.01905
				currentPath.length = currentPath.length + distance				
			end
			
			-- Add a node
			currentPath[nodeID] = {
				id = nodeID,
				path = currentPath,
				
				pos = nodePos,
				x = currentPath.length,
				prev = prevNode,
			}
			if prevNode then
				prevNode.next = currentPath[nodeID] 
				prevNode.dir = (nodePos - prevNode.pos):GetNormalized()
				prevNode.vec = nodePos - prevNode.pos
				prevNode.length = distance
			end

			-- Add to spatial lookup
			addLookup(currentPath[nodeID])
			prevPos = nodePos
			prevNode = currentPath[nodeID] 
		end
		
		if prevNode then
			prevNode.next = nil
			prevNode.dir = Vector(0,0,0)
			prevNode.vec = Vector(0,0,0)
			prevNode.length = 0
		end
	end
	
	-- Find places where tracks link up together
	for pathID,path in pairs(Drivtrams.Paths) do
		-- Find position of end nodes
		local node1,node2 = path[1],path[#path]
		local pos1 = Drivtrams.GetPositionOnTrack(node1.pos,nil,{ ignore_path = path })
		local pos2 = Drivtrams.GetPositionOnTrack(node2.pos,nil,{ ignore_path = path })
		
		-- Create connection
		local join1,join2
		if pos1[1] then join1 = pos1[1].node1 end
		if pos2[1] then join2 = pos2[1].node1 end
		
		-- Record it
		if join1 then
			join1.branches = join1.branches or {}
			table.insert(join1.branches,{ pos1[1].x, node1 })
			node1.branches = node1.branches or {}
			table.insert(node1.branches,{ node1.x, join1 })
		end
		if join2 then
			join2.branches = join2.branches or {}
			table.insert(join2.branches,{ pos2[1].x, node2 })
			node2.branches = node2.branches or {}
			table.insert(node2.branches,{ node2.x, join2 })
		end
	end

	-- Initialize stations list
	Drivtrams.UpdateStations()
	-- Print info
	Drivtrams.PrintStatistics()
	
	-- Ignore updates to prevent created/removed switches from constantly updating table of positions
	Drivtrams.IgnoreEntityUpdates = true
	
	-- Remove old entities
	if not keep_signs then
		local signals_ents = ents.FindByClass("gmod_track_signal")
		for k,v in pairs(signals_ents) do SafeRemoveEntity(v) end
		local switch_ents = ents.FindByClass("gmod_track_switch")
		for k,v in pairs(switch_ents) do SafeRemoveEntity(v) end
		
		-- Create new entities (add a delay so the old entities clean up)
		print("Drivtrams: Loading signs, signals, switches...")	
		local signs = util.JSONToTable(file.Read(string.format("metrostroi_data/signs_%s.txt",name)) or "")
		if signs then
			for k,v in pairs(signs) do
				local ent = ents.Create(v.Class)
				if IsValid(ent) then
					ent:SetPos(v.Pos)
					ent:SetAngles(v.Angles)
					ent:Spawn()
					if v.Class == "gmod_track_signal" then
						ent:SetSettings(v.Settings)
						ent:SetTrafficLights(v.TrafficLights)
						ent:SetLightsStyle(v.LightsStyle)
					end
					if v.Class == "gmod_track_switch" then
						ent:SetChannel(v.Channel or 1)
						ent.LockedSignal = v.LockedSignal
					end
				end
			end
		end
	end
	
	timer.Simple(0.05,function()
		-- No more ignoring updates
		Drivtrams.IgnoreEntityUpdates = false
		-- Load ARS entities
		Drivtrams.UpdateSignalEntities()
		-- Load switches
		Drivtrams.UpdateSwitchEntities()
		-- Add additional ARS sections
		Drivtrams.UpdateARSSections()
	end)

	-- Load schedules data
	print("Drivtrams: Loading schedules configuration...")
	local sched_data = util.JSONToTable(file.Read(string.format("metrostroi_data/sched_%s.txt",name)) or "")
	if sched_data then
		Drivtrams.LoadSchedulesData(sched_data)
	else
		print("Drivtrams: Could not load schedules configuration!")
	end
	
	-- Initialize signs
	print("Drivtrams: Initializing signs...")
	Drivtrams.InitializeSigns()
end


--------------------------------------------------------------------------------
-- Save track & sign definitions
--------------------------------------------------------------------------------
function Drivtrams.Save(name)
	if not file.Exists("metrostroi_data","DATA") then
		file.CreateDir("metrostroi_data")
	end
	name = name or game.GetMap()
	
	-- Format signs, signal, switch data
	local signs = {}
	local signals_ents = ents.FindByClass("gmod_track_signal")
	for k,v in pairs(signals_ents) do
		if not Drivtrams.ARSSubSections[v] then
			table.insert(signs,{
				Class = "gmod_track_signal",
				Pos = v:GetPos(),
				Angles = v:GetAngles(),
				Settings = v:GetSettings(),
				TrafficLights = v:GetTrafficLights(),
				LightsStyle = v:GetLightsStyle(),
			})
		end
	end
	local switch_ents = ents.FindByClass("gmod_track_switch")
	for k,v in pairs(switch_ents) do
		table.insert(signs,{
			Class = "gmod_track_switch",
			Pos = v:GetPos(),
			Angles = v:GetAngles(),
			Channel = v:GetChannel(),
			LockedSignal = v.LockedSignal
		})
	end

	-- Save data
	print("Drivtrams: Saving signs and track definition...")
	local data = util.TableToJSON(signs)
	file.Write(string.format("metrostroi_data/signs_%s.txt",name),data)
	print("Saved to metrostroi_data/signs_"..name..".txt")
end


--------------------------------------------------------------------------------
-- Concommands and automatic loading of rail network
--------------------------------------------------------------------------------
hook.Add("Initialize", "Drivtrams_MapInitialize", function()
	timer.Simple(2.0,Drivtrams.Load)
end)

concommand.Add("metrostroi_save", function(ply, _, args)
	if (ply:IsValid()) and (not ply:IsAdmin()) then return end
	Drivtrams.Save()
end)

concommand.Add("metrostroi_load", function(ply, _, args)
	if (ply:IsValid()) and (not ply:IsAdmin()) then return end
	Drivtrams.Load()
end)

concommand.Add("metrostroi_cleanup_signals", function(ply, _, args)
	if (ply:IsValid()) and (not ply:IsAdmin()) then return end
	
	Drivtrams.IgnoreEntityUpdates = true
	local signals_ents = ents.FindByClass("gmod_track_signal")
	for k,v in pairs(signals_ents) do SafeRemoveEntity(v) end
	local switch_ents = ents.FindByClass("gmod_track_switch")
	for k,v in pairs(switch_ents) do SafeRemoveEntity(v) end
	Drivtrams.IgnoreEntityUpdates = false
end)

concommand.Add("metrostroi_load_without_signs", function(ply, _, args)
	if (ply:IsValid()) and (not ply:IsAdmin()) then return end
	Drivtrams.Load(nil,true)
end)

concommand.Add("metrostroi_pos_info", function(ply, _, args)
	if (ply:IsValid()) and (not ply:IsAdmin()) then return end
	
	-- Draw nearest nodes
	timer.Simple(0.05,function()
		for k,v in Drivtrams.NearestNodes(ply:GetPos()) do
			debugoverlay.Cross(v.pos,10,10,Color(0,0,255),true)
			debugoverlay.Line(v.pos,ply:GetPos(),10,Color(0,0,255),true)
		end
	end)
	
	-- Print interesting information
	local results = Drivtrams.GetPositionOnTrack(ply:GetPos(),ply:GetAimVector():Angle())
	for k,v in pairs(results) do
		print(Format("\t[%d] Path #%d: (%.2f x %.2f x %.2f) m  Facing %s",k,v.path.id,v.x,v.y,v.z,v.forward and "forward" or "backward"))
	end
	
	-- Info about local track
	if results[1] then
		print(Format("Track status: %s",
			Drivtrams.IsTrackOccupied(results[1].node1) and "occupied" or "free"
		))
	end
end)

concommand.Add("metrostroi_track_main", function(ply, _, args)
	if (not ply:IsValid()) then return end
	
	-- Trigger all track switches
	local results = Drivtrams.GetPositionOnTrack(ply:GetPos(),ply:GetAimVector():Angle())
	for k,v in pairs(results) do
		local switches = Drivtrams.GetTrackSwitches(v.node1,v.x,v.forward)
		for _,switch in pairs(switches) do
			print("Found switch:",switch,switch.TrackPosition.x)
			switch:SendSignal("main",tonumber(args[1]) or 1)
		end
	end
end)

concommand.Add("metrostroi_track_alt", function(ply, _, args)
	if (not ply:IsValid()) then return end

	-- Trigger all track switches
	local results = Drivtrams.GetPositionOnTrack(ply:GetPos(),ply:GetAimVector():Angle())
	for k,v in pairs(results) do
		local switches = Drivtrams.GetTrackSwitches(v.node1,v.x,v.forward)
		for _,switch in pairs(switches) do
			print("Found switch:",switch,switch.TrackPosition.x)
			switch:SendSignal("alt",tonumber(args[1]) or 1)
		end
	end
end)

concommand.Add("metrostroi_track_arstest", function(ply, _, args)
	if (ply:IsValid()) and (not ply:IsAdmin()) then return end
	
	-- Trigger all track switches
	local results = Drivtrams.GetPositionOnTrack(ply:GetPos(),ply:GetAimVector():Angle())
	for k,v in pairs(results) do
	    --Drivtrams.GetARSJoint(pos.node1,pos.x,false)
		local ars = Drivtrams.GetARSJoint(v.node1,v.x,false)
		
		--Drivtrams.GetNextTrafficLight(v.node1,v.x,v.forward,true)
		if ars then
			local ARS80 = ars:GetActiveSignalsBit(10)
			local ARS70 = ars:GetActiveSignalsBit(11)
			local ARS60 = ars:GetActiveSignalsBit(12)
			local ARS40 = ars:GetActiveSignalsBit(13)
			local ARS0  = ars:GetActiveSignalsBit(14)
			local ARSsp = ars:GetActiveSignalsBit(15)

			if not (ARS80 or ARS70 or ARS60 or ARS40 or ARS0 or ARSsp) then
				print(Format("[%d] ARS: NO SIGNAL",k))
			else
				print(Format("[%d] ARS: 80:%d 70:%d 60:%d 40:%d 0:%d Sp:%d",
					k,
					ARS80 and 1 or 0,
					ARS70 and 1 or 0,
					ARS60 and 1 or 0,
					ARS40 and 1 or 0,
					ARS0 and 1 or 0,
					ARSsp and 1 or 0))
			end			
		else
			print(Format("[%d] ARS: NO SIGNAL (NO ARS)",k))
		end
	end
end)




--------------------------------------------------------------------------------
-- Print statistics and information about the loaded rail network
--------------------------------------------------------------------------------
function Drivtrams.PrintStatistics()
	local totalLength = 0
	for pathNo,path in pairs(Drivtrams.Paths) do
		totalLength = totalLength + path.length
	end
	
	print(Format("Drivtrams: Total %.3f km of paths defined:",totalLength/1000))
	for pathNo,path in pairs(Drivtrams.Paths) do
		print(Format("\t[%d] %.3f km (%d nodes)",path.id,path.length/1000,#path))	
	end
	
	local count = #Drivtrams.SpatialLookup
	local cells = {}
	for _,z in pairs(Drivtrams.SpatialLookup) do
		count = count + #z
		for _,x in pairs(z) do
			count = count + #x
			for _,y in pairs(x) do
				table.insert(cells,#y)
			end
		end
	end
	print(Format("Drivtrams: %d tables used for spatial lookup (%d cells)",count,#cells))
	local maxn,avgn = 0,0
	for k,v in pairs(cells) do maxn = math.max(maxn,v) avgn = avgn + v end
	print(Format("Drivtrams: Most nodes in cell: %d, average nodes in cell: %.2f",maxn,avgn/#cells))
end


--Metrostroi.Load()