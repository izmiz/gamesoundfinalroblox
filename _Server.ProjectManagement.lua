--[[ 

Personal Sounds (Chat Commands):
- Drumroll: Type Drums
- Boo: Type L
- Cheer: Type G
- Clap: Player presses the C key

Normal Sounds
- Whistle: Plays when a player with a football touches out of bounds
- Catch: Plays when a football is caught by the player
- Punt: Player presses the T key with a football
- Goalpost: Plays when a football hits the goalpost

Background Sound
- Plays in a loop with variance depending on the flow of the game

Dialouge
- Plays during the cutscene trigged via the Cutscene action on the AudioRemote

3D Spatial Sound
- Plays dynamically when the football has a body velocity

]]

-- // Services
local Players = game:GetService('Players')
local TweenService = game:GetService('TweenService')
local ReplicatedStorage = game:GetService('ReplicatedStorage')

-- // Folder for storing all sounds
local ProjectAudios = Instance.new('Folder')
ProjectAudios.Name = 'ProjectAudios'
ProjectAudios.Parent = workspace

-- // Remote Event for client-server communication
local AudioRemote = Instance.new('RemoteEvent', ReplicatedStorage)
AudioRemote.Name = "AudioRemote"

-- // Audio Galleries
local my_personal_sounds = { -- Personal sounds triggered via chat commands
	[1] = { name = 'Drumroll', id = 'rbxassetid://96925331057976', volume = 1 },
	[2] = { name = 'Boo', id = 'rbxassetid://97756576944874', volume = 1 },
	[3] = { name = 'Woo', id = 'rbxassetid://109894216672441', volume = 1 },
	[4] = { name = 'Clap', id = 'rbxassetid://77377309295003', volume = 1 },
}

local normal_sounds = { -- Normal sounds triggered by gameplay events
	[1] = { name = "Whistle", id = "rbxassetid://526315071", volume = 1 },
	[2] = { name = "Catch", id = "rbxassetid://526315800", volume = 1 },
	[3] = { name = "Punt", id = "rbxassetid://2573901578", volume = 1 },
	[4] = { name = "Goalpost", id = "rbxassetid://2445250825", volume = 1 },
}

local background_sound = { name = 'background audio', id = 'rbxassetid://9119562311', variance = 0.5 }

local dialogue = { -- Dialogue audio and text for cutscene
	[1] = { id = 'rbxassetid://121072188923645', text = "We'll have a toss to determine who receives. Call it in the air" },
	[2] = { id = 'rbxassetid://105134356864499', text = "Heads" },
	[3] = { id = 'rbxassetid://124448384391582', text = "It is Heads" },
	[4] = { id = 'rbxassetid://114312093865699', text = "Would you like to Kick or Receive?" },
	[5] = { id = 'rbxassetid://109338328789189', text = "Kick" },
}

local spatial_sound = { id = 'rbxassetid://4933142217', volume = 2 } -- 3D sound for flying football

-- // Variables
local useBackgroundSound = true
local debounce = false
local debounceTable = {} -- Prevents repeated triggering of the same sound

-- // Helper Function: Find football in a model
local function findFootball(model)
	for _, descendant in pairs(model:GetDescendants()) do
		if descendant.Name == "Football" then
			return true
		end
	end
	return false
end

-- // Teleports players and referee to their positions at the start of the cutscene
local function teleportPlayersAndSetup()
	-- Teleport all players to workspace.HomeCaptain
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character or player.CharacterAdded:Wait()
		local homeCaptainPosition = workspace:WaitForChild("HomeCaptain").Position + Vector3.new(0, 3, 0)
		character:SetPrimaryPartCFrame(CFrame.new(homeCaptainPosition))
	end

	-- Teleport RefereeA to RefereeCT
	local refereeA = workspace:WaitForChild("RefereeA")
	local refereeCT = workspace:WaitForChild("RefereeCT").Position + Vector3.new(0, 3, 0)
	refereeA:SetPrimaryPartCFrame(CFrame.new(refereeCT))
end

-- // Helper Function: Create and configure sound
local function createSound(parent, soundData)
	local newSound = Instance.new('Sound')
	newSound.Name = soundData.name or "UnnamedSound"
	newSound.SoundId = soundData.id or ""
	newSound.Volume = soundData.volume or 1
	newSound.Parent = parent or ProjectAudios
	return newSound
end

-- Background audio setup
local backgroundAudio = createSound(ProjectAudios, background_sound)

-- // Helper Function: Gradually fade out audio
local function fadeOutAudio(audio, duration)
	if not audio or not audio:IsA('Sound') then return end
	local fadeTween = TweenService:Create(audio, TweenInfo.new(duration), { Volume = 0 })
	fadeTween:Play()
	fadeTween.Completed:Connect(function()
		audio:Stop()
	end)
end

-- // Helper Function: Adjust audio volume with variance
local function tweenAudioVolume(audio, variance)
	if not audio or not audio:IsA('Sound') then return end
	local targetVolume = math.clamp(audio.Volume + (math.random() * variance - variance / 2), 0, 1)
	local volumeTween = TweenService:Create(audio, TweenInfo.new(1), { Volume = targetVolume })
	volumeTween:Play()
end

-- // Football Sound Management
workspace.ChildAdded:Connect(function(child)
	if child:IsA('Part') and child.Name == 'Football' then
		
		if not child:FindFirstChild('FlyingSound') then
			local flyingSound = createSound(child, spatial_sound)
			flyingSound.Name = 'FlyingSound'

			-- Make 3D effects more dramatic
			flyingSound.EmitterSize = 10 -- Larger audible area
			flyingSound.MaxDistance = 1000 -- Increase maximum audible distance
			flyingSound.RollOffMode = Enum.RollOffMode.Inverse -- More dramatic distance fade
			flyingSound.RollOffMinDistance = 20 -- Starts fading further away
			
			-- Monitor BodyVelocity
			local runService = game:GetService("RunService")
			local monitoring = true
			runService.Heartbeat:Connect(function()
				if not monitoring then return end

				local bodyVelocity = child:FindFirstChild('BodyVelocity')
				if bodyVelocity then
					-- Play sound if it isn't already playing
					if not flyingSound.IsPlaying then
						flyingSound:Play()
					end
				else
					-- Stop sound if BodyVelocity is removed
					if flyingSound.IsPlaying then
						flyingSound:Stop()
					end
				end
			end)

			-- Stop monitoring when the football is removed
			child.AncestryChanged:Connect(function()
				if not child:IsDescendantOf(workspace) then
					monitoring = false
					if flyingSound then
						flyingSound:Stop()
						flyingSound:Destroy()
					end
				end
			end)
		end
		
		-- Play goalpost sound when football touches the goalpost
		child.Touched:Connect(function(hit)
			local player = Players:GetPlayerFromCharacter(hit.Parent)

			-- Check for Goalpost interaction
			if hit.Parent.Name == 'Goalpost' then
				if not debounceTable['Goalpost'] then
					debounceTable['Goalpost'] = true

					-- Play the goalpost sound
					local goalpostSound = createSound(ProjectAudios, normal_sounds[4])
					goalpostSound:Play()
					goalpostSound.Ended:Connect(function()
						goalpostSound:Destroy()
					end)

					-- Reset debounce after 2 seconds
					task.delay(2, function()
						debounceTable['Goalpost'] = false
					end)
				end
			elseif player then
				-- Check for Catch interaction
				if not debounceTable['Catch'] then
					debounceTable['Catch'] = true

					-- Play the catch sound
					local catchSound = createSound(ProjectAudios, normal_sounds[2])
					catchSound:Play()
					catchSound.Ended:Connect(function()
						catchSound:Destroy()
					end)

					-- Reset debounce after 2 seconds
					task.delay(2, function()
						debounceTable['Catch'] = false
					end)
				end
			end
		end)
	end
end)

-- // Background Sound Loop
spawn(function()
	while useBackgroundSound do
		if not backgroundAudio.IsPlaying then
			backgroundAudio:Play()
		end

		-- Adjust volume randomly for ambient effect
		tweenAudioVolume(backgroundAudio, background_sound.variance)

		wait(1)
	end
end)

for _, bound in pairs(workspace.Field.Gridiron.Bounds:GetChildren()) do
	if bound:IsA('BasePart') then
		bound.Touched:Connect(function(hit)
			if not debounce then
				debounce = true
				local isPlayer = Players:GetPlayerFromCharacter(hit.Parent) or Players:GetPlayerFromCharacter(hit.Parent.Parent)
				if isPlayer then
					local hasFootball = findFootball(hit.Parent) or findFootball(isPlayer.Backpack)
					if hasFootball then
						local whistleSound = createSound(ProjectAudios, normal_sounds[1])
						whistleSound:Play()
						whistleSound.Ended:Connect(function()
							whistleSound:Destroy()
						end)
						-- Reset debounce after a delay
						task.delay(2, function()
							debounce = false
						end)
					else
						debounce = false
					end
				else
					debounce = false
				end
			end
		end)
	end
end

AudioRemote.OnServerEvent:Connect(function(player, action)
	if action == "Punt" then
		-- Play the Punt sound
		local puntSound = createSound(ProjectAudios, normal_sounds[3])
		puntSound:Play()
		puntSound.Ended:Connect(function()
			puntSound:Destroy()
		end)
	elseif action == "Clap" then
		local clapSound = createSound(ProjectAudios, my_personal_sounds[4])
		clapSound:Play()
		clapSound.Ended:Connect(function()
			clapSound:Destroy()
		end)
	elseif action == 'Cutscene' then
		teleportPlayersAndSetup()

		-- Play the cutscene
		for i, line in ipairs(dialogue) do
			-- Determine the camera target
			local target
			if i == 1 then
				target = "RefereeA"
			elseif i == 2 or i == 5 then
				target = Players:GetPlayers()[1].Name
			elseif i == 3 or i == 4 then
				target = "RefereeA"
			end

			-- Fire event to set the camera
			AudioRemote:FireClient(player, "SetCamera", target, line.text)

			-- Play the dialogue audio
			local dialogueSound = Instance.new("Sound")
			dialogueSound.SoundId = line.id
			dialogueSound.Volume = 1
			dialogueSound.Parent = workspace
			dialogueSound:Play()

			-- Wait for the dialogue to finish before moving the camera
			dialogueSound.Ended:Wait()
			dialogueSound:Destroy()

			-- Small pause after camera move
			task.wait(2)
		end

		-- Notify the client that the cutscene is complete
		AudioRemote:FireClient(player, "CutsceneComplete")
	end
end)

local soundCounters = {} -- Track spam counts for each sound
Players.PlayerAdded:Connect(function(Player)
	Player.Chatted:Connect(function(message)
		local noCaseRulesMsg = string.upper(message)
		local soundData, key 

		-- Determine which sound to play
		if noCaseRulesMsg == 'G' then
			soundData = my_personal_sounds[3] -- Cheer sound
			key = "Cheer"
		elseif noCaseRulesMsg == 'L' then
			soundData = my_personal_sounds[2] -- Boo sound
			key = "Boo"
		elseif noCaseRulesMsg == 'DRUMS' then
			soundData = my_personal_sounds[1] -- Drumroll sound
			key = "Drumroll"
		end

		if soundData then
			-- Initialize or increment the spam counter
			if not soundCounters[key] then
				soundCounters[key] = { count = 0, decayTask = nil }
			end
			soundCounters[key].count += 1

			-- Create and play the sound
			local dynamicVolume = math.clamp(soundData.volume + (soundCounters[key].count * 0.1), 0, 2) -- Scale volume up to 2
			local sound = createSound(ProjectAudios, { name = soundData.name, id = soundData.id, volume = dynamicVolume })
			sound:Play()
			sound.Ended:Connect(function()
				sound:Destroy()
			end)

			-- Reset counter after 5 seconds of no spam
			if not soundCounters[key].decayTask then
				soundCounters[key].decayTask = task.delay(5, function()
					soundCounters[key] = nil -- Reset the counter
				end)
			else
				task.cancel(soundCounters[key].decayTask) -- Cancel existing decay task
				soundCounters[key].decayTask = task.delay(5, function()
					soundCounters[key] = nil -- Reset the counter
				end)
			end
		end
	end)
end)
