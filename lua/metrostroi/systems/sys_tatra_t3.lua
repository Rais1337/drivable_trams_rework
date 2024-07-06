Drivtrams.DefineSystem("T3_Systems")
TRAIN_SYSTEM.DontAccelerateSimulation = true

function TRAIN_SYSTEM:Initialize()
	self.Drive = 0
	self.Brake = 0
	self.Reverse = 0
end


function TRAIN_SYSTEM:Inputs()
	return { "Drive", "Brake","Reverse" }
end

function TRAIN_SYSTEM:TriggerInput(name,value)
	if self[name] then self[name] = value end
end



--------------------------------------------------------------------------------
function TRAIN_SYSTEM:Think()
	self.Train.FrontBogey.MotorForce = 18000
	self.Train.RearBogey.MotorForce  = 19000
	local sys = self
	local tram = self.Train
	if self.Train.CoupledTrains then
		sys = self.Train.CoupledTrains[1].Systems["T3_Systems"]
		tram = self.Train.CoupledTrains[1]
	end
	if self.Train.ControllerPowered then
		local controller = tram:GetNWInt("Controller", 0)/4
		local reversed = tram:GetNWBool("ToggleReverse", false)
		local sas = controller
		if sas <= 0 then sas = sas * 1 end
		self.Train.FrontBogey.MotorPower = sas
		self.Train.FrontBogey.Reversed = reversed
		
		local sas2 = controller
		if sas2 <= 0 then sas2 = sas2 * 1 end
		self.Train.RearBogey.MotorPower = sas2
		self.Train.RearBogey.Reversed = !reversed
	else
		self.Train.FrontBogey.MotorPower = sys.Drive - sys.Brake * 1
		self.Train.FrontBogey.Reversed = (sys.Reverse > 0.5)
		
		self.Train.RearBogey.MotorPower = sys.Drive - sys.Brake * 1
		self.Train.RearBogey.Reversed = not (sys.Reverse > 0.5)
	end
end 