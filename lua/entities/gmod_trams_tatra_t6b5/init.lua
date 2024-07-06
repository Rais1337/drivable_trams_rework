AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

ENT.DoorOpenSound = Sound("vehicles/trams/misc/tatra_t3_door_open.wav")
ENT.DoorCloseSound = Sound("vehicles/trams/misc/tatra_t3_door_close.wav")//на шобы ты видел        spasibo

ENT.Doors = {
	[1] = {
		pos = Vector(262.6, 55.8, -20),
		ang = Angle(0, -90, 0),
		size = Vector(1,0.88,0.92),
		openinst = "open",
		closeinst = "close",
		model = "models/props_vehicles/trams/tatra_t3/tatra_doors.mdl",
		IsDriver = true,
	},
	[2] = {
		pos = Vector(-37.4, 55.8, -20),
		ang = Angle(0, -90, 0),
		openinst = "open",
		closeinst = "close",
		size = Vector(1,0.88,0.92),
		model = "models/props_vehicles/trams/tatra_t3/tatra_doors.mdl",
	},
	[3] = {
		pos = Vector(-262.3, 55.8, -20),
		ang = Angle(0, -91, 0),
		size = Vector(1,0.88,0.92),
		openinst = "open",
		closeinst = "close",
		model = "models/props_vehicles/trams/tatra_t3/tatra_doors.mdl",
	},
}

--------------------------------------------------------------------------------
function ENT:Initialize()
	-- Defined train information
	self.SubwayTrain = {
		Type = "Tatra",
		Name = "Tatra T6B5",
	}

	-- Set model and initialize
	self:SetModel("models/props_vehicles/trams/tatra_t6b5/tatra_t6b5.mdl")
	self.BaseClass.Initialize(self)
	self:SetPos(self:GetPos() + Vector(0,0,140))
	
    -- Create seat entities
	self.DriverSeat = self:CreateSeat("driver",Vector(289,15,-26))
	self.PassengerSeat = self:CreateSeat("passenger",Vector(195,42,-38))
	self.PassengerSeat = self:CreateSeat("passenger",Vector(165,42,-38))
	self.PassengerSeat = self:CreateSeat("passenger",Vector(125,42,-38))
	self.PassengerSeat = self:CreateSeat("passenger",Vector(87,42,-38))
	self.PassengerSeat = self:CreateSeat("passenger",Vector(46,42,-38))
	self.PassengerSeat = self:CreateSeat("passenger",Vector(10,42,-38))
	self.PassengerSeat = self:CreateSeat("passenger",Vector(-26,42,-38))
	self.PassengerSeat = self:CreateSeat("passenger",Vector(-66,42,-38))
	self.PassengerSeat = self:CreateSeat("passenger",Vector(-98,42,-38))
	self.PassengerSeat = self:CreateSeat("passenger",Vector(-138,42,-38))
	self.PassengerSeat = self:CreateSeat("passenger",Vector(-175,42,-38))
	self.PassengerSeat = self:CreateSeat("passenger",Vector(-210,42,-38))	
	self.PassengerSeat = self:CreateSeat("passenger",Vector(164,-45,-38))
	self.PassengerSeat = self:CreateSeat("passenger",Vector(125,-45,-38))
	self.PassengerSeat = self:CreateSeat("passenger",Vector(84,-45,-38))
	self.PassengerSeat = self:CreateSeat("passenger",Vector(50,-45,-38))
	self.PassengerSeat = self:CreateSeat("passenger",Vector(13,-45,-38))
	self.PassengerSeat = self:CreateSeat("passenger",Vector(-100,-45,-38))
	self.PassengerSeat = self:CreateSeat("passenger",Vector(-137,-45,-38))
	self.PassengerSeat = self:CreateSeat("passenger",Vector(-174,-45,-38))
	self.PassengerSeat = self:CreateSeat("passenger",Vector(-213,-45,-38))

	-- Create bogeys
	self.FrontBogey = self:CreateBogey(Vector( 160,0,-70),Angle(0,180,0),true,"tatra")
	self.RearBogey  = self:CreateBogey(Vector(-170,0,-70),Angle(0,0,0),false,"tatra")
	
	-- Create joins
	self.FrontJoin = self:CreateJoin(Vector(340,0,-70),false)
	self.RearJoin = self:CreateJoin(Vector(-330,0,-70),true)
	
	-- Initialize key mapping
	self.KeyMap = {
		[KEY_W] = "Drive",
		[KEY_S] = "Brake",
		[KEY_R] = "Reverse",
	}
end

function ENT:CreateJoin(pos,rev)
	local ang = Angle(0,0,0)
	if rev then ang = Angle(0,180,0) end
	local join = ents.Create("gmod_trams_coupler")
	join:SetModel("models/props_vehicles/trams/tatra_t3/tatra_join.mdl")
	join:SetPos(self:LocalToWorld(pos))
	join:SetAngles(self:GetAngles() + ang)
	join:Spawn()
	join:SetOwner(self:GetOwner())
	join.Rev = rev
	join.Train = self

	-- Constraint join to the train
	--[[constraint.Axis(join,self,0,0,
		Vector(0,0,0),Vector(0,0,0),
		0,0,0,1,Vector(0,0,1),false)]]--
	local xmin = -5
	local xmax = 2
	if rev then
		xmin = -2
		xmax = 5
	end
	
	constraint.AdvBallsocket(
		join,
		self,
		0, --bone
		0, --bone
		Vector(-40,0,10),
		pos,
		0, --forcelimit
		0, --torquelimit
		xmin, --xmin
		0, --ymin
		-30, --zmin
		xmax, --xmax
		0, --ymax
		30, --zmax
		0, --xfric
		0, --yfric
		0, --zfric
		0, --rotonly
		1 --nocollide
	)

	-- Add to cleanup list
	table.insert(self.TrainEntities,join)
	return join
end