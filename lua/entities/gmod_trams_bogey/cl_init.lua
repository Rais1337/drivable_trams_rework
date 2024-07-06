include("shared.lua")
net.Receive("metrostroi-bogey",function()
	self = net.ReadEntity()
	if not self._Net then return end
	local ID,val = net.ReadInt(3)+1,net.ReadFloat()
	self._Net[ID] = val
end)
net.Receive("metrostroi-bogey-sync",function()
	self =  net.ReadEntity()
	self._Net = net.ReadTable()
end)


--------------------------------------------------------------------------------
function ENT:ReinitializeSounds()
	-- Bogey-related sounds
	self.SoundNames = {}
	self.SoundNames["engine"]		= "trams/misc/engine_1.wav"
	self.SoundNames["engine5"]		= "trams/misc/engine_2.wav"
	self.SoundNames["engine6"]		= "trams/misc/engine_3.wav"
	self.SoundNames["bpsn"]	    	= "trams/misc/idle.wav"
	self.SoundNames["kplus"]       	= "trams/music/kplus.mp3"
	self.SoundNames["flange2"]		= "trams/misc/flange_10.wav"
	self.SoundNames["horn"]         = "trams/misc/horn_1.wav"
	self.SoundNames["speed2"]		= "trams/misc/speed2.wav"
	self.SoundNames["up-1"]			= "trams/run_snd/up-1.wav"
	self.SoundNames["up-2"]			= "trams/run_snd/up-2.wav"
	self.SoundNames["up-3"]			= "trams/run_snd/up-3.wav"
	self.SoundNames["up-4"]			= "trams/run_snd/up-4.wav"
	self.SoundNames["up-5"]			= "trams/run_snd/up-5.wav"
	self.SoundNames["up-6"]			= "trams/run_snd/up-6.wav"
	self.SoundNames["up-7"]			= "trams/run_snd/up-7.wav"
	
	-- Remove old sounds
	if self.Sounds then
		for k,v in pairs(self.Sounds) do
			v:Stop()
		end
	end

	-- Create sounds
	self.Sounds = {}
	self.Playing = {}
	for k,v in pairs(self.SoundNames) do
		util.PrecacheSound(v)
		local e = self
		if (k == "brake3a") and IsValid(self:GetNWEntity("TrainWheels")) then
			e = self:GetNWEntity("TrainWheels")
		end
		self.Sounds[k] = CreateSound(e, Sound(v))
	end
end

function ENT:SetSoundState(sound,volume,pitch)
	if (volume <= 0) or (pitch <= 0) then
		--self.Sounds[sound]:Stop()
		self.Sounds[sound]:ChangeVolume(0.0,0)
		return
	end

	if not self.Playing[sound] then
		self.Sounds[sound]:Play()
	end
	local pch = math.floor(math.max(0,math.min(255,100*pitch)) + math.random())
	self.Sounds[sound]:ChangeVolume(math.max(0,math.min(255,2.55*volume)) + (0.001/2.55) + (0.001/2.55)*math.random(),0)
	self.Sounds[sound]:ChangePitch(pch+1,0)
end

function ENT:Initialize()
--	self:ReinitializeSounds()
end

function ENT:OnRemove()
	if self.Sounds then
		for k,v in pairs(self.Sounds) do
			v:Stop()
		end
	end
end




--------------------------------------------------------------------------------
function ENT:Think()
	if not self.Sounds then
		self:ReinitializeSounds()
	end
	
	-- Get interesting parameters
	local motorPower = self:GetMotorPower()
	local speed = self:GetSpeed()
	local dPdT = self:GetdPdT()
	
	-- Engine sound
	--speed = 40
	--motorPower = 1.0
	if (speed > 1.0) and (motorPower < 0.0) then
		local t = RealTime()*2.5
		local modulation = 0.2 + 1.0*math.max(0,0.2+math.sin(t)*math.sin(t*3.12)*math.sin(t*0.24)*math.sin(t*4.0))
		local mod2 = 1.0-math.min(1.0,(math.abs(motorPower)/0.1))
		local startVolRamp = 0.2 + 0.8*math.max(0.0,math.min(1.0,(speed - 1.0)*0.5))
		local powerVolRamp = 0.3*modulation*mod2 + 2*math.abs(motorPower)--2.0*(math.abs(motorPower)^2)
		--math.max(0.3,math.min(1.0,math.abs(motorPower)))

		local k,x = 1.0,math.max(0,math.min(1.1,(speed-1.0)/80))
		local motorPchRamp = (k*x^3 - k*x^2 + x)
		local motorPitch = 0.03+1*motorPchRamp
		
		local crossfade = math.min(1.0,math.max(0.0,1.25*(math.abs(motorPower)-0.15) ))
		
		self:SetSoundState("engine",0.3,motorPitch)
		self:SetSoundState("engine6",0.3,motorPitch)
		self:SetSoundState("engine5",0.3,motorPitch)
	else
		self:SetSoundState("engine",0,0)
		self:SetSoundState("engine5",0,0)
		self:SetSoundState("engine6",0,0)
	end
	
--print(motorPower)
	
	-- Run sound
	if speed > 1 then
		//self:SetSoundState("speed1",1,0.6)
	else
		//self:SetSoundState("speed1",0,0)
		self:SetSoundState("bpsn",0.1,1) // bpsn - idle sound
	end
	
	if (speed > 3) and (motorPower > 0) then
		self:SetSoundState("up-1",1,1)
	else
		self:SetSoundState("up-1",0,0)
	end
	
	if (speed > 15) and (motorPower > 0) then
		self:SetSoundState("up-2",1,1)
		self:SetSoundState("up-1",0,0)
	else
		self:SetSoundState("up-2",0,0)
	end
	
	if (speed > 25) and(motorPower > 0) then
		self:SetSoundState("up-3",1,1)
		self:SetSoundState("up-2",0,0)
	else
		self:SetSoundState("up-3",0,0)
	end
	
	if (speed > 27) and (motorPower > 0) then
		self:SetSoundState("up-4",1,1)
		self:SetSoundState("up-3",0,0)
	else
		self:SetSoundState("up-4",0,0)
	end
	
	if (speed > 35) and (motorPower > 0) then
		self:SetSoundState("up-5",1,1)
		self:SetSoundState("up-4",0,0)
	else
		self:SetSoundState("up-5",0,0)
	end
	
	if (speed > 40) and (motorPower > 0) then
		self:SetSoundState("up-6",1,1)
		self:SetSoundState("up-5",0,0)
	else
		self:SetSoundState("up-6",0,0)
	end
	
	if (speed > 49) and (motorPower > 0) then
		self:SetSoundState("up-7",1,1)
		self:SetSoundState("up-6",0,0)
	else
		self:SetSoundState("up-7",0,0)
	end

	if (speed > 10) then
		self:SetSoundState("bpsn",0.05,1)
		//self:SetSoundState("speed1",0,0)
		//self:SetSoundState("speed2",1,1)
	else
		//self:SetSoundState("speed2",0,0)
	end
	
	-- If u don't press W and u speed > 12, then playing this
	if (speed > 12) and (motorPower == 0) then
		self:SetSoundState("speed2",1,1)
		self:SetSoundState("up-1",0,0)
		self:SetSoundState("up-2",0,0)
		self:SetSoundState("up-3",0,0)
		self:SetSoundState("up-4",0,0)
		self:SetSoundState("up-5",0,0)
		self:SetSoundState("up-6",0,0)
		self:SetSoundState("up-7",0,0)
	elseif (motorPower > 0) or (speed <= 9) then
		self:SetSoundState("speed2",0,0)
	end
	
	
	-- Timing
	self.PrevTime = self.PrevTime or RealTime()
	local dT = (RealTime() - self.PrevTime)
	self.PrevTime = RealTime()
	
	-- Generate procedural landscape thingy
	local a = self:GetPos().x
	local b = self:GetPos().y
	local c = self:GetPos().z
	local f = math.sin(c/200 + a*c/3e7 + b*c/3e7) --math.sin(a/3000)*math.sin(b/3000)
	
	-- Calculate flange squeal
	self.PreviousAngles = self.PreviousAngles or self:GetAngles()
	local deltaAngle = (self:GetAngles().yaw - self.PreviousAngles.yaw)/dT
	deltaAngle = ((deltaAngle + 180) % 360 - 180)
	deltaAngle = math.max(math.min(1.0,f*10)*math.abs(deltaAngle),0)
	self.PreviousAngles = self:GetAngles()
	
	-- Smooth it out
	self.SmoothAngleDelta = self.SmoothAngleDelta or 0
	self.SmoothAngleDelta = self.SmoothAngleDelta + (deltaAngle - self.SmoothAngleDelta)*1.0*dT
	if (not (self.SmoothAngleDelta <= 0)) and (not (self.SmoothAngleDelta >= 0)) then
		self.SmoothAngleDelta = 0
	end
	
	-- Create sound
	local x = self.SmoothAngleDelta
	local f1 = math.max(0,x-6.0)*0.1
	local f2 = math.max(0,x-9.0)*0.1
	local t = RealTime()
	local modulation = 1.5*math.max(0,0.2+math.sin(t)*math.sin(t*3.12)*math.sin(t*0.24)*math.sin(t*4.0))
	local pitch = math.max(0.8,1.0+(speed-40.0)/160.0)
	local speed_mod = math.min(1.0,math.max(0.0,(speed-20)*0.1))
	
	-- Play it
	//self:SetSoundState("flange1",speed_mod*f1,pitch)
	self:SetSoundState("flange2",speed_mod*f2*modulation,pitch)

	-- Horn
	if self:GetNWBool("horn") then
		self:SetSoundState("horn",1,1)
	else
		self:SetSoundState("horn",0,0)
	end
	
	--valdis
	if self:GetNWBool("valdis") then
		self:SetSoundState("kplus",1,1)
	else
		self:SetSoundState("kplus",0,0)
	end
	/*local ent = self:GetNWEntity("TrainEntity")
	if IsValid(ent) and ent:GetNWEntity("seat_driver") and IsValid(ent:GetNWEntity("seat_driver")) then 
		for k,ply in pairs(player.GetAll()) do
			if ply:GetVehicle() != ent:GetNWEntity("seat_driver") then continue end
			if IsValid(ply) and ply:KeyDown( IN_SPEED ) then
    			self:SetSoundState("horn",1,1)
    		else
    			self:SetSoundState("horn",0,0)
    		end
    		if IsValid(ply) and ply:KeyDown( IN_MOVERIGHT ) then
    			self:SetSoundState("valdis",1,1)
    		else
    			self:SetSoundState("valdis",0,0)
    		end
    		break
		end
	end*/

end