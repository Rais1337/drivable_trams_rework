--------------------------------------------------------------------------------
-- Signs in tunnels and on stations
--------------------------------------------------------------------------------
Drivtrams.Signs = Drivtrams.Signs or {}



--------------------------------------------------------------------------------
-- Helper for commonly used trace
--------------------------------------------------------------------------------
local function trace(pos,dir,col)
	local tr = util.TraceLine({
		start = pos,
		endpos = pos+dir,
		mask = MASK_NPCWORLDSTATIC
	})
	timer.Simple(0.05,function()
		local t = 5
		debugoverlay.Line(tr.StartPos,tr.HitPos,t,col or Color(0,0,255),true)
		debugoverlay.Sphere(tr.StartPos,2,t,Color(0,255,255),true)
		debugoverlay.Sphere(tr.HitPos,2,t,Color(255,0,0),true)
	end)
	return tr
end


--------------------------------------------------------------------------------
-- Create station name signs
--------------------------------------------------------------------------------
function Drivtrams.AddStationSign(ent)
	local platformStart	= ent.PlatformStart
	local platformEnd	= ent.PlatformEnd
	local platformDir   = platformEnd-platformStart
	local platformN		= (platformDir:Angle()-Angle(0,90,0)):Forward()
	local platformD		= platformDir:GetNormalized()

	local N = 2
	local X = { 0.25, 0.75 }
	for i=1,N do
		local pos = (platformStart + platformDir*X[i]) + Vector(0,0,64+32) + platformN*96
		local tr = trace(pos,platformN*384)
		
		-- Bad hit workaround
		if (not tr.Hit) or (tr.Fraction < 0.05) then
			--print("STATION BAD HIT 1",ent.StationIndex,tr.Hit,tr.Fraction)

			pos = (platformStart + platformDir*X[i]) + Vector(0,0,64+32) + platformN*0
			tr = trace(pos,platformN*384)
		end
		if (not tr.Hit) or (tr.Fraction < 0.05) then
			--print("STATION BAD HIT 3",ent.StationIndex,tr.Hit,tr.Fraction)

			pos = (platformStart + platformDir*X[i]) + Vector(0,0,64+32) + platformN*0
			tr = trace(pos,-platformN*384)
		end
		if (not tr.Hit) or (tr.Fraction < 0.05) then
			--print("STATION BAD HIT 2",ent.StationIndex,tr.Hit,tr.Fraction)

			pos = (platformStart + platformDir*X[i]) + Vector(0,0,64+32) + platformN*96
			tr = trace(pos,-platformN*384)
		end
		
		local sign = ents.Create("gmod_track_sign")
		if IsValid(sign) then
			if tr.Hit then
				sign:SetPos(tr.HitPos + tr.HitNormal*4)
				sign:SetAngles(tr.HitNormal:Angle())
			else
				sign:SetPos(tr.HitPos + tr.HitNormal*4)
				sign:SetAngles(-platformN:Angle())
				print(Format("Drivtrams: Could not find a nice way to place station names for %03d",ent.StationIndex))
			end
			sign:Spawn()
			
			sign:SetNWString("Type","station")
			sign:SetNWString("Name",Drivtrams.StationNames[ent.StationIndex])
			sign:SetNWInt("ID",ent.StationIndex)
			sign:SetNWInt("Platform",ent.PlatformIndex)
			
			-- Get path of this station
			local path1 = math.floor(ent.StationIndex/100)
			
			-- List of change stations
			local ChangeStations = {
				[122] = 321,
				[321] = 122,
			}
			
			-- Store up to two changes
			local change2List = {}
			local change3List = {}
			local change2Used = nil
			local change3Used = nil
			for k,v in pairs(ChangeStations) do
				local path2 = math.floor(k/100)
				if path1 == path2 then
					if not change2Used then
						change2Used = k
						sign:SetNWInt("Change2",k)
						sign:SetNWInt("Change2ID",v)
					elseif not change3Used then
						change3Used = k
						sign:SetNWInt("Change3",k)
						sign:SetNWInt("Change3ID",v)
					end
				end
			end

			-- Get stations list
			local change2_path = math.floor((ChangeStations[change2Used or 0] or 0)/100)
			local change3_path = math.floor((ChangeStations[change3Used or 0] or 0)/100)
			local stationList = {}
			for k,v in pairs(Drivtrams.StationNames) do
				local path2 = math.floor(k/100)
				if (path1 == path2) or (change2_path == path2) or (change3_path == path2) then
					local R = (Drivtrams.StationNamesConfiguration[k] or {})[1] or 0
					local G = (Drivtrams.StationNamesConfiguration[k] or {})[2] or 0
					local B = (Drivtrams.StationNamesConfiguration[k] or {})[3] or 0
					local Use = (Drivtrams.StationNamesConfiguration[k] or {})[4] or 0
					if (Use > 0) then
						if (change2_path == path2) and (path2 ~= path1) then
							table.insert(change2List,k)
						elseif (change3_path == path3) and (path2 ~= path1) then
							table.insert(change3List,k)
						else
							if ((ent.PlatformIndex == 2) and (ent.StationIndex >= k)) or
							   ((ent.PlatformIndex == 1) and (ent.StationIndex <= k)) then
								table.insert(stationList,k)
							end
						end
					end
				end
			end
			
			-- Sort stations list
			if ent.PlatformIndex == 2 then
				table.sort(stationList, function(a, b) return a < b end)
			else
				table.sort(stationList, function(a, b) return a > b end)
			end
			table.sort(change2List, function(a, b) return a < b end)
			table.sort(change3List, function(a, b) return a < b end)
			
			-- Send stations list
			sign:SetNWInt("StationList#",#stationList)
			for k,v in ipairs(stationList) do
				sign:SetNWInt("StationList"..k.."[ID]",v)
				sign:SetNWString("StationList"..k.."[Name1]",Drivtrams.StationTitles[v])
				sign:SetNWString("StationList"..k.."[Name2]",Drivtrams.StationNames[v])
				sign:SetNWInt("StationList"..k.."[R]",(Drivtrams.StationNamesConfiguration[v] or {})[1])
				sign:SetNWInt("StationList"..k.."[G]",(Drivtrams.StationNamesConfiguration[v] or {})[2])
				sign:SetNWInt("StationList"..k.."[B]",(Drivtrams.StationNamesConfiguration[v] or {})[3])
				--sign:SetNWInt("StationList"..k.."[R]",(Metrostroi.StationNamesConfiguration[v.ID] or {})[1])
			end
			
			-- Send change lists
			sign:SetNWInt("Change2List#",#change2List)
			for k,v in ipairs(change2List) do
				sign:SetNWInt("Change2List"..k.."[ID]",v)
				sign:SetNWString("Change2List"..k.."[Name1]",Drivtrams.StationTitles[v])
				sign:SetNWString("Change2List"..k.."[Name2]",Drivtrams.StationNames[v])
				sign:SetNWInt("Change2List"..k.."[R]",(Drivtrams.StationNamesConfiguration[v] or {})[1])
				sign:SetNWInt("Change2List"..k.."[G]",(Drivtrams.StationNamesConfiguration[v] or {})[2])
				sign:SetNWInt("Change2List"..k.."[B]",(Drivtrams.StationNamesConfiguration[v] or {})[3])
			end
			sign:SetNWInt("Change3List#",#change3List)
			for k,v in ipairs(change3List) do
				sign:SetNWInt("Change3List"..k.."[ID]",v)
				sign:SetNWString("Change3List"..k.."[Name1]",Drivtrams.StationTitles[v])
				sign:SetNWString("Change3List"..k.."[Name2]",Drivtrams.StationNames[v])
				sign:SetNWInt("Change3List"..k.."[R]",(Drivtrams.StationNamesConfiguration[v] or {})[1])
				sign:SetNWInt("Change3List"..k.."[G]",(Drivtrams.StationNamesConfiguration[v] or {})[2])
				sign:SetNWInt("Change3List"..k.."[B]",(Drivtrams.StationNamesConfiguration[v] or {})[3])
			end
			
			--[[sign:MakeStationSign(
				Metrostroi.StationTitles[ent.StationIndex] or Metrostroi.StationNames[ent.StationIndex],
				Metrostroi.StationNames[ent.StationIndex])]]--
			table.insert(Drivtrams.Signs,sign)
		end
	end
end


--------------------------------------------------------------------------------
-- Create horizontal lift signals
--------------------------------------------------------------------------------
function Drivtrams.AddStationSignal(ent)
	if ent.HorliftStation == 0 then return end

	local platformStart	= ent.PlatformStart
	local platformEnd	= ent.PlatformEnd
	local platformDir   = platformEnd-platformStart
	local platformN		= (platformDir:Angle()-Angle(0,90,0)):Forward()
	local platformD		= platformDir:GetNormalized()

	local pos = platformEnd + Vector(0,0,64) + platformN*96 + platformD*(192-32)
	local tr = trace(pos,platformN*384)
		
	local sign = ents.Create("gmod_track_horlift_signal")
	if IsValid(sign) then
		if tr.Hit then
			sign:SetPos(tr.HitPos)
			sign:SetAngles(tr.HitNormal:Angle())
		else
			sign:SetPos(tr.HitPos)
			sign:SetAngles(-platformN:Angle())
		end
		sign:Spawn()
		table.insert(Drivtrams.Signs,sign)
	end
end


--------------------------------------------------------------------------------
-- Create all signs
--------------------------------------------------------------------------------
function Drivtrams.InitializeSigns()
	-- Clear old signs
	for k,v in pairs(Drivtrams.Signs) do
		SafeRemoveEntity(v)
	end
	Drivtrams.Signs = {}
	
	-- Add sign for every station name
	local entities = ents.FindByClass("gmod_track_platform")
	for k,v in pairs(entities) do
		Drivtrams.AddStationSign(v)
		Drivtrams.AddStationSignal(v)
	end
	
	-- Add temporary lights
	--[[
	local entities = ents.FindByClass("gmod_track_switch")
	for k,v in pairs(entities) do
		for k2,v2 in pairs(v.TrackSwitches) do
			local tr = trace(v2:GetPos(),Vector(0,0,384))
			if tr.Hit then
				local light = ents.Create("env_projectedtexture")
				light:SetPos(tr.HitPos - Vector(0,0,16))
				light:SetAngles(tr.HitNormal:Angle())

				-- Set parameters
				light:SetKeyValue("enableshadows", 0)
				light:SetKeyValue("farz", 600)
				light:SetKeyValue("nearz", 16)
				light:SetKeyValue("lightfov", 170)

				-- Set Brightness
				local brightness = 0.3
				light:SetKeyValue("lightcolor",
					Format("%i %i %i 255",
						180*brightness,
						255*brightness,
						255*brightness
					)
				)

				-- Turn light on
				light:Spawn()
				light:Input("SpotlightTexture",nil,nil,"effects/flashlight001")
				table.insert(Metrostroi.Signs,light)			
			end
		end
	end
	
	--17473 20200
	if Metrostroi.Paths[1] then
		for k,v in pairs(Metrostroi.Paths[1]) do
			if (type(v) == "table") and (v.x) and (v.x > 17470) and (v.x < 20200) then
				local tr = trace(v.pos + Vector(0,0,64),Vector(0,0,384)) --384*(v.dir:Angle() + Angle(0,0,90)):Forward())
				if tr.Hit and ((k % 2) == 0) and false then
					local light = ents.Create("env_projectedtexture")
					light:SetPos(tr.HitPos - tr.HitNormal*64)
					light:SetAngles(tr.HitNormal:Angle())

					-- Set parameters
					light:SetKeyValue("enableshadows", 0)
					light:SetKeyValue("farz", 512+192)
					light:SetKeyValue("nearz", 128)
					light:SetKeyValue("lightfov", 160)

					-- Set Brightness
					local brightness = 0.20
					light:SetKeyValue("lightcolor",
						Format("%i %i %i 255",
							180*brightness,
							255*brightness,
							255*brightness
						)
					)

					-- Turn light on
					light:Spawn()
					light:Input("SpotlightTexture",nil,nil,"effects/flashlight001")
					table.insert(Metrostroi.Signs,light)	
				end
			end
		end
	end]]--
end

Drivtrams.InitializeSigns()
