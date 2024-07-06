--------------------------------------------------------------------------------
-- Schedule generator
--------------------------------------------------------------------------------
-- List of all unique routes that can be used in schedule generation
-- 		{ station, platform }
Drivtrams.ScheduleRoutes = Drivtrams.ScheduleRoutes or {}
Drivtrams.SchedulesInitialized = false

-- List of all time intervals in which schedules must be generated
-- 		{ start_time, end_time, route_name, train_interval, 
Drivtrams.ScheduleConfiguration = Drivtrams.ScheduleConfiguration or {}

-- List of station names
Drivtrams.StationNames = Drivtrams.StationNames or {}
Drivtrams.StationTitles = Drivtrams.StationTitles or {}
Drivtrams.StationNamesConfiguration = Drivtrams.StationNamesConfiguration or {}

-- AI train behavior configuration
Drivtrams.AIConfiguration = Drivtrams.AIConfiguration or {}

-- Current server time
function Drivtrams.ServerTime()
	return (os.time() % 86400)
end

-- Departure time of last train from first station
Drivtrams.DepartureTime = Drivtrams.DepartureTime or {}
-- Schedule counter
Drivtrams.ScheduleID = Drivtrams.ScheduleID or 0


--------------------------------------------------------------------------------
local function timeToSec(str)
	local x = string.find(str,":")
	if not x then return tonumber(sec) or 0 end
	
	local min = tonumber(string.sub(str,1,x-1)) or 0
	local sec = tonumber(string.sub(str,x+1)) or 0
	return min*60+sec,min,sec
end

local function prepareRouteData(routeData,name)
	-- Prepare general route information
	routeData.Duration = 0
	routeData.Name = name

	-- Fix up every station
	for i,stationID in ipairs(routeData) do
		routeData[i].ID = i
		routeData[i].TimeOffset = routeData.Duration
		if routeData[i+1] then
			if not Drivtrams.Stations[routeData[i][1]]						then print(Format("No station %d",routeData[i][1])) return end
			if not Drivtrams.Stations[routeData[i][1]][routeData[i][2]]	then print(Format("No platform %d for station %d",routeData[i][2],routeData[i][1])) return end
			if not Drivtrams.Stations[routeData[i+1][1]]					then print(Format("No station %d",routeData[i+1][1])) return end
			if not Drivtrams.Stations[routeData[i+1][1]][routeData[i][2]]	then print(Format("No platform %d for station %d",routeData[i+1][2],routeData[i+1][1])) return end
			
			-- Get nodes
			local start_node =	Drivtrams.Stations[routeData[i  ][1]][routeData[i  ][2]].node_end
			local end_node =	Drivtrams.Stations[routeData[i+1][1]][routeData[i+1][2]].node_end
			if start_node.path ~= end_node.path then
				print(Format("Platform %d for station %d: path %d; Platform %d for station %d: path %d",
					routeData[i  ][2],routeData[i  ][1],start_node.path.id,
					routeData[i+1][2],routeData[i+1][1],end_node.path.id))
				return
			end
			
			-- Calculate travel time between two nodes
			local travelTime,travelDistance = Drivtrams.GetTravelTime(start_node,end_node)
			-- Add time for startup and slowdown
			travelTime = travelTime + 25
			
			-- Remember stats
			routeData.Duration = routeData.Duration + travelTime
			routeData[i].TravelTime = travelTime
			routeData[i].TravelDistance = travelDistance
	
			-- Print debug information
			print(Format("\t\t[%03d-%d]->[%03d-%d]  %02d:%02d min  %4.0f m  %4.1f km/h",
				routeData[i][1],routeData[i][2],
				routeData[i+1][1],routeData[i+1][2],
				math.floor(travelTime/60),math.floor(travelTime)%60,travelDistance,(travelDistance/travelTime)*3.6))
		else
			routeData.LastID = i
			routeData.LastStation = routeData[i][1]
		end
	end
	
	-- Add a quick lookup
	routeData.Lookup = {}
	for i,_ in ipairs(routeData) do
		routeData.Lookup[routeData[i][1]] = routeData[i]
	end
end

function Drivtrams.InitializeSchedules()
	if Drivtrams.SchedulesInitialized then return end
	Drivtrams.SchedulesInitialized = true
	
	-- Fix up all routes
	print("Drivtrams: Preparing routes...")
	for routeName,routeData in pairs(Drivtrams.ScheduleRoutes) do
		print(Format("\tTravel distances for preset route '%s':",routeName))
		prepareRouteData(routeData,routeName)
		print(Format("\t\tTotal duration: %02d:%02d min",math.floor(routeData.Duration/60),math.floor(routeData.Duration)%60))
	end
end

function Drivtrams.GenerateSchedule(routeID)
	Drivtrams.InitializeSchedules()
	if not Drivtrams.ScheduleRoutes[routeID] then return end
	
	-- Time padding (extra time before schedule starts, wait time between trains)
	local paddingTime = timeToSec("1:30")
	-- Current server time
	local serverTime = Drivtrams.ServerTime()/60
	-- hack
	if routeID == "Line1_Platform2" then
		paddingTime = timeToSec("3:00")
	end
	
	-- Determine schedule configuration
	local interval
	for _,config in pairs(Drivtrams.ScheduleConfiguration) do
		local t_start = timeToSec(config[1])
		local t_end = timeToSec(config[2])
		if (config[3] == routeID) and (t_start <= serverTime) and (t_end > serverTime) then
			interval = timeToSec(config[4])
		end
	end
	-- If no interval, then no schedules available
	if not interval then return end
	
	-- If no schedules started 
	if not Drivtrams.DepartureTime[routeID] then
		Drivtrams.DepartureTime[routeID] = serverTime + paddingTime/60
	else
		-- If schedules started, depart with interval
		Drivtrams.DepartureTime[routeID] = math.max(Drivtrams.DepartureTime[routeID] + interval/60,serverTime + paddingTime/60)
	end
	
	-- Create new schedule
	Drivtrams.ScheduleID = Drivtrams.ScheduleID + 1
	local schedule = {
		ScheduleID = Drivtrams.ScheduleID,
		Interval = interval,
		Duration = Drivtrams.ScheduleRoutes[routeID].Duration,
	}
	
	-- Fill out all stations
	local currentTime = Drivtrams.DepartureTime[routeID]
	for id,stationData in ipairs(Drivtrams.ScheduleRoutes[routeID]) do
		-- Calculate stop time
		local stopTime = 15
--		if not stationData.TravelTime then stopTime = 0 end
		
		-- Add entry
		schedule[#schedule+1] = {
			stationData[1],				-- Station
			stationData[2],				-- Platform
			currentTime+stopTime/60,		-- Departure time
			currentTime,				-- Arrival time
		}
		
		schedule[#schedule].arrivalTimeStr = 
			Format("%02d:%02d:%02d",
				math.floor(schedule[#schedule][3]/60),
				math.floor(schedule[#schedule][3])%60,
				math.floor(schedule[#schedule][3]*60)%60)
		
		-- Add travel time
		if stationData.TravelTime then
			currentTime = currentTime + (stationData.TravelTime + stopTime)/60
		end
	end
	
	-- Fill out start and end
	schedule.StartStation = schedule[1][1]
	schedule.EndStation = schedule[#schedule][1]
	schedule.StartTime = schedule[1][2]
	schedule.EndTime = schedule[#schedule][2]

	-- Print result
	print(Format("--- %03d --- From %03d to %03d --------------------",
		schedule.ScheduleID,schedule.StartStation,schedule.EndStation))
	for i,d in ipairs(schedule) do
		print(Format("\t%03d   %s",d[1],d.arrivalTimeStr))
	end
	return schedule
end

function Drivtrams.LoadSchedulesData(data)
	Drivtrams.ScheduleRoutes = data.Routes or {}
	Drivtrams.ScheduleConfiguration = data.Configuration or {}
	Drivtrams.StationNames = data.StationNames or {}
	Drivtrams.StationTitles = data.StationTitles or {}
	Drivtrams.AIConfiguration = data.AIConfiguration or {}
	Drivtrams.StationNamesConfiguration = data.StationNamesConfiguration or {}
	Drivtrams.SchedulesInitialized = false

	timer.Simple(45.0,function()
		Drivtrams.InitializeSchedules()
	end)
end

concommand.Add("metrostroi_schedule1", function(ply, _, args)
	Drivtrams.GenerateSchedule("Line1_Platform1")
end)
concommand.Add("metrostroi_schedule2", function(ply, _, args)
	Drivtrams.GenerateSchedule("Line1_Platform2")
end)
concommand.Add("metrostroi_print_scheduleinfo", function(ply, _, args)
	for routeName,routeData in pairs(Drivtrams.ScheduleRoutes) do
		print(Format("\tTravel distances for preset route '%s':",routeName))
		prepareRouteData(routeData,routeName)
		print(Format("\t\tTotal duration: %02d:%02d min",math.floor(routeData.Duration/60),math.floor(routeData.Duration)%60))
	end
end)