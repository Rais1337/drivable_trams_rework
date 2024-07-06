AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

ENT.DoorOpenSound = Sound("vehicles/trams/misc/tatra_t3_door_open.wav")
ENT.DoorCloseSound = Sound("vehicles/trams/misc/tatra_t3_door_close.wav")//на шобы ты видел        spasibo

ENT.Doors = {
	[1] = {
		pos = Vector(272.7, 51.7, -8),
		ang = Angle(0, -80, 0),
		size = Vector(0.9,1,1.05),
		openinst = "open",
		closeinst = "close",
		model = "models/props_vehicles/trams/tatra_t3/tatra_doors.mdl",
		IsDriver = true,
	},
	[2] = {
		pos = Vector(-31, 58, -8),
		ang = Angle(0, -90, 0),
		size = Vector(0.9,1,1.05),
		openinst = "open",
		closeinst = "close",
		model = "models/props_vehicles/trams/tatra_t3/tatra_doors.mdl",
	},
	[3] = {
		pos = Vector(-261 ,52.7, -8),
		ang = Angle(0, -98, 0),
		size = Vector(0.9,1,1.05),
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
		Name = "Tatra T3SU",
	}

	-- Set model and initialize
	self:SetModel("models/props_vehicles/trams/tatra_t3/tatra_t3.mdl")
	self.BaseClass.Initialize(self)
	self:SetPos(self:GetPos() + Vector(0,0,140))
	
	-- Create seat entities
	self.DriverSeat = self:CreateSeat("driver",Vector(296,10,-12))
	self.PassengerSeat = self:CreateSeat("passenger",Vector(205,37,-12))
	self.PassengerSeat = self:CreateSeat("passenger",Vector(215,-42,-12),Angle(0,180,0))
	self.PassengerSeat = self:CreateSeat("passenger",Vector(163,37,-12))
	self.PassengerSeat = self:CreateSeat("passenger",Vector(131,37,-12))
	self.PassengerSeat = self:CreateSeat("passenger",Vector(94,37,-12))
	self.PassengerSeat = self:CreateSeat("passenger",Vector(57,37,-12))
	self.PassengerSeat = self:CreateSeat("passenger",Vector(19,37,-12))
	self.PassengerSeat = self:CreateSeat("passenger",Vector(-20,37,-12))
	self.PassengerSeat = self:CreateSeat("passenger",Vector(-57,37,-12))
	self.PassengerSeat = self:CreateSeat("passenger",Vector(-92,37,-12))
	self.PassengerSeat = self:CreateSeat("passenger",Vector(-128,37,-12))
	self.PassengerSeat = self:CreateSeat("passenger",Vector(-164,37,-12))
	self.PassengerSeat = self:CreateSeat("passenger",Vector(-200,37,-12))
	self.PassengerSeat = self:CreateSeat("passenger",Vector(-246,37,-12))
	self.PassengerSeat = self:CreateSeat("passenger",Vector(-200,-40,-12))
	self.PassengerSeat = self:CreateSeat("passenger",Vector(-164,-21,-12))
	self.PassengerSeat = self:CreateSeat("passenger",Vector(-164,-40,-12))
	self.PassengerSeat = self:CreateSeat("passenger",Vector(-128,-21,-12))
	self.PassengerSeat = self:CreateSeat("passenger",Vector(-128,-40,-12))
	self.PassengerSeat = self:CreateSeat("passenger",Vector(-92,-21,-12))
	self.PassengerSeat = self:CreateSeat("passenger",Vector(-92,-40,-12))
	self.PassengerSeat = self:CreateSeat("passenger",Vector(19,-21,-12))
	self.PassengerSeat = self:CreateSeat("passenger",Vector(19,-40,-12))
	self.PassengerSeat = self:CreateSeat("passenger",Vector(57,-21,-12))
	self.PassengerSeat = self:CreateSeat("passenger",Vector(57,-40,-12))
	self.PassengerSeat = self:CreateSeat("passenger",Vector(168,-21,-12))
	self.PassengerSeat = self:CreateSeat("passenger",Vector(168,-40,-12))
	self.PassengerSeat = self:CreateSeat("passenger",Vector(131,-21,-12))
	self.PassengerSeat = self:CreateSeat("passenger",Vector(131,-40,-12))
	self.PassengerSeat = self:CreateSeat("passenger",Vector(94,-21,-12))
	self.PassengerSeat = self:CreateSeat("passenger",Vector(94,-40,-12))
	
	-- Create bogeys
	self.FrontBogey = self:CreateBogey(Vector( 160,0,-60),Angle(0,180,0),true,"tatra")
	self.RearBogey  = self:CreateBogey(Vector(-150,0,-60),Angle(0,0,0),false,"tatra")
	
	-- Create joins
	self.FrontJoin = self:CreateJoin(Vector(350,0,-50),false)
	self.RearJoin = self:CreateJoin(Vector(-350,0,-50),true)
	
	-- Initialize key mapping
	self.KeyMap = {
		[KEY_W] = "Drive",
		[KEY_S] = "Brake",
		[KEY_R] = "Reverse"
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