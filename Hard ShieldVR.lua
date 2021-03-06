--[[

INSANE MOD - created by Discookie

Based on Normal ShieldVR and Expert mods

Released under CC-BY-SA 4.0

https://matekos17.f.fazekas.hu/shield/

---

Branch dev, Version 0.31b

Last commit: 2017.03.09.
--]]



maxAccelLeft = 7      -- Left hand max acceleration => change this if too fast
factAccelLeft = 0.6   -- Left hand factor - shouldn't touch
minAccelLeft = 0      -- Left hand min acceleration - mustn't touch
maxAccelRight = 7     -- Right hand max acceleration => change this if too fast
factAccelRight = 0.6  -- Right hand factor - shouldn't touch
minAccelRight = 0     -- Right hand min acceleration - mustn't touch

impactX_Scaler = 1.7  -- Armspan multiplier => change this if too wide

minSpacingSeconds = 0 -- Minimum spacing => change this if too dense

doubleFactor = 0.2

--[[
Other values - not recommended to change them
--]]

chestHeight = 1.3           -- If notes aren't hitting your chest height
curveFactorX = 100          -- Shouldn't change this
curveFactorY = 170          -- Shouldn't change this
curveY_Max = 75             -- If notes are coming from too high
curveY_Min = 17             -- If notes are coming from too low
curveY_tiltInfluence = .8   -- If notes are too steep
maxNodeDistShown = 1500     -- If lagging like hell
meteorSpeed = .09           -- If meteors are coming too fast

blueMaxX = .5               -- Shouldn't change this
blueSpanX = -1              -- Shouldn't change this
redMinX = -.5               -- Shouldn't change this
redSpanX = 1                -- Shouldn't change this
purpleMaxX = .5             -- Shouldn't change this
purpleSpanX = -1            -- Shouldn't change this
yImpactSpan = .5            -- Shouldn't change this yet
yImpactSpan_MaxRandomExtra = .1 -- Shouldn't change this yet
zImpact = .7                -- Mustn't change this
maxNeighborXspan = 1        -- Shouldn't change this
maxMirroredX = .5           -- Shouldn't change this


allowMusicCutOutOnFail=false    -- If you like to hear when you miss

--[[
Mustn't change anything below this point!
--]]

function fif(test, if_true, if_false)
  if test then return if_true else return if_false end
end

function MiniTrace(text, level)
    return (string.rep(">>", level).." "..text.."\n")
end
function DumpTrace(tbl, level)
  local ret = ""
  if not level then level = 1 end
  for k, v in pairs(tbl) do
    if type(v) == "table" then
      ret = ret..MiniTrace(tostring(k).." = TABLE:", level) 
      ret = ret..DumpTrace(v, level+1)
    elseif type(v) == 'boolean' then
      ret = ret..MiniTrace(tostring(k).." = "..tostring(v), level)      
    else
      ret = ret..MiniTrace(tostring(k).." = "..v, level) 
    end
  end
  return ret
end

GameplaySettings{
        allowmusicdroponfail = allowMusicCutOutOnFail,
        jumpmode="none",
        gravity=-.45,
        playerminspeed = 0.1,
        playermaxspeed = 2.9,
        minimumbestjumptime = 2.5,
        uphilltiltscaler = 0.8,
        downhilltiltscaler = 1.55,
        uphilltiltsmoother = 0.03,
        downhilltiltsmoother = 0.06,
        useadvancedsteepalgorithm = true,
        alldownhill = false,
        usepuzzlegrid = false,
        usetraffic = false,
        towropes = false
}

nodes = nodes or {} 
nodechaincount = nodechaincount or {}

function FindTrackSpan(start, preseconds, postseconds)
    local bound = start
    local newstart = start

    local preTime = track[start].seconds + preseconds
    for i = start, 1,-1 do
        if track[i].seconds <= preTime then
            newstart = i
            break
        end
    end

    local postTime = track[start].seconds + postseconds;
    for i = start, #track do
        if track[i].seconds >= postTime then
            bound = i
            break
        end
    end

    return newstart, bound
end

function TryMarkSpan(start, bound, jumporduck)
    --local flag = false
    --if start > 5300 and bound < 5500 then
    --    flag = true
    --end

    --if flag then print("TryMarkSpan start:"..start.." bound:"..bound.." type:"..jumporduck) end
    --whenever a span is placed, it's responsible for blocking spacing time in front of itself
    local preStart, postBound = FindTrackSpan(start,-minSpacingSeconds,0)
    --Highway.TwoInts ti = Highway.Instance.FindStartEndSpanForDuration(start, -minSpacingSeconds, 0)
    --int preStart = ti.start;
    if (preStart == start) or (preStart==(start-1)) then
        preStart = math.max(1, start - 2)
    end

    if start==bound then--just wants to add a single block, special case to make sure only one block is added
        --if flag then print("solo path") end
        local allgood=true
        for i=preStart,start do
            if nodes[i] ~= nil then
                allgood=false
                break
            end
        end

        if allgood then
            for i=preStart,start do
                --if flag then print("add dirty at "..i) end
                nodes[i] = 'dirty'
                nodechaincount[i] = -1
            end
            --if flag then print("add "..jumporduck.." at "..start) end
            nodes[start] = jumporduck
            nodechaincount[start] = -1
        end
    else
        --if flag then print("multi path") end
        local startTime = -1;
        local started = false;
        for i = preStart, bound do
            if nodes[i] == nil then --this node is not claimed by a jump, duck, or buffer yet
                if not started then
                    started = true
                    startTime = track[i].seconds
                    nodes[i] = 'dirty'--at least one empty node in front of the span
                    --if flag then print("add dirty at "..i) end
                    nodechaincount[i] = -1
                else
                    if (track[i].seconds >= (startTime + minSpacingSeconds)) and (i>=start) then
                        nodes[i] = jumporduck
                        --if flag then print("add "..jumporduck.." at "..i) end
                    else
                        nodes[i] = 'dirty'
                        --if flag then print("add dirty at "..i) end
                    end
                    if bound - preStart > 4 then
                        nodechaincount[i] = bound - i
                    else
                        nodechaincount[i] = -1
                    end
                end
            else
                if started then
                    break--stop marking, ran into another (higher priority) span
                end
            end
        end
    end
end

function CompareJumpTimes(a,b) --used to sort the track nodes by jump duration
    return a.jumpairtime > b.jumpairtime
end

function CompareStrengths(a,b) --used to sort the track nodes by jump duration
    return a.strength > b.strength
end

powernodes = powernodes or {}
track = track or {}
traffic = traffic or {}
maxTilt = 0
minTilt = 0

function OnTrackCreated(theTrack)--track is created before the traffic
    print("LUA OnTrackCreated")
    track = theTrack --store globally
    local songMinutes = track[#track].seconds / 60

    for i=1,#track do
        track[i].jumpedOver = false -- if this node was jumped over by a higher proiority jump
        track[i].origIndex = i
    end

    --find the best jumps path in this song
    local strack = deepcopy(track)
    table.sort(strack, CompareJumpTimes)

    for i=1,#strack do
        maxTilt = math.max(maxTilt, strack[i].tilt)
        minTilt = math.min(minTilt, strack[i].tilt)
        if strack[i].jumpairtime >= 2.5 then --only consider jumps of at least this amount of air time
            if not track[strack[i].origIndex].jumpedOver then
                local flightPathClear = true
                local jumpEndSeconds = strack[i].seconds + strack[i].jumpairtime + 10
                for j=strack[i].origIndex, #track do --make sure a higher priority jump doesn't happen while this one would be airborne
                    if track[j].seconds <= jumpEndSeconds then
                        if track[j].jumpedOver then
                            flightPathClear = false
                        end
                    else
                        break
                    end
                end
                if flightPathClear then
                    -- if #powernodes < (songMinutes + 2) then -- allow about one power node per minute of music
                    if #powernodes < (songMinutes+2) then -- allow about one power node per minute of music
                        if strack[i].origIndex > 300 then
                            --check if this is a real transition point in the song. The nodes before it should be uphill and the nodes after it should be downhill
                            local avgSlopePrev = 0
                            local avgSlopePost = 0
                            local slopeTestCount = 100

                            local strt = math.max(1, strack[i].origIndex-slopeTestCount)
                            local bnd = strack[i].origIndex
                            for ii=strt,bnd do
                                avgSlopePrev = avgSlopePrev + track[ii].tilt
                            end
                            strt = strack[i].origIndex
                            bnd = math.min(#track-1, strack[i].origIndex+slopeTestCount)
                            for ii=strt,bnd do
                                avgSlopePost = avgSlopePost + track[ii].tilt
                            end

                            avgSlopePrev = avgSlopePrev    / slopeTestCount
                            avgSlopePost = avgSlopePost / slopeTestCount
                            --print("avgSlopePrev:"..avgSlopePrev)
                            --print("avgSlopePost:"..avgSlopePost)

                            if (avgSlopePrev < 5 and avgSlopePost >15) or (i==1) then -- only take slope qualifiers. Also, always take the biggest jump
                                powernodes[#powernodes+1] = strack[i].origIndex
                            end
                        end
                        local extraJumpOverBufferSec = 10
                        jumpEndSeconds = strack[i].seconds + strack[i].jumpairtime + extraJumpOverBufferSec
                        for j=strack[i].origIndex, #track do
                            if track[j].seconds <= jumpEndSeconds then
                                track[j].jumpedOver = true --mark this node as jumped over (a better jump took priority) so it is not marked as a powernode
                            else
                                break
                            end
                        end
                    end
                end
            end
        end
    end
end

meteorNodes = meteorNodes or {} -- declare tables this way to support (possible) future live code reloading
meteorImpacts = meteorImpacts or {}
meteorSpeeds = meteorSpeeds or {}
meteorDirections = meteorDirections or {}
meteorCurveMaximums = meteorCurveMaximums or {}
meteorScales = meteorScales or {}
meteorColors = meteorColors or {}
meteorAlbedoColors = {}
meteorTypes = {}
--nodeAttackAngles = nodeAttackAngles or {} -- for each track node, a list of what angles meteors attack from
--nodeAttackSizes = nodeAttackSizes or {} -- for each track node, what size the metoers impacting at that time are

meteorNodes_tails = meteorNodes_tails or {} -- declare tables this way to support (possible) future live code reloading
meteorImpacts_tails = meteorImpacts_tails or {}
meteorSpeeds_tails = meteorSpeeds_tails or {}
meteorDirections_tails = meteorDirections_tails or {}
meteorCurveMaximums_tails = meteorCurveMaximums_tails or {}
meteorScales_tails = meteorScales_tails or {}
meteorColors_tails = meteorColors_tails or {}
meteorAlbedoColors_tails = {}
meteorTypes_tails = {}

function OnTrafficCreated(theTraffic)
    traffic = theTraffic --store globally
    
    -- \mod
    math.randomseed(math.floor(track[#track].seconds * 10000000000))
    --math.randomseed(11)

    local minimapMarkers = {}
    for j=1,#powernodes do --insert powernode spans. They're top priority, so do them first
        local prev = 2
        for i=prev, #traffic do
            if traffic[i].chainend >= powernodes[j] then
                local spanDist = traffic[i].chainend - traffic[i].chainstart
                if spanDist > 5 then -- never make a tiny chain into a rave
                    --if traffic[i].chainstart <= powernodes[j] then
                    TryMarkSpan(traffic[i].chainstart, traffic[i].chainend, 'rave')
                    --else
                    --    local strt = math.max(1,powernodes[j]-3)
                    --    local bnd = math.min(#track-1, powernodes[j]+3)
                    --    TryMarkSpan(strt, bnd, 'rave')
                    --end
                    prev = i
                    table.insert(minimapMarkers, {tracknode=powernodes[j], startheight=0, endheight=fif(j==1, 15, 11), color={233,233,233}})
                end

                break
            end
        end
    end

    --figure out where to put jumps and ducks
    local longestSpan = 0
    local longestSpanStart = 0
    local longestSpanEnd = 0
    for i = 1, #traffic do
        local spanDist = traffic[i].chainend - traffic[i].chainstart
        if spanDist > longestSpan then
            longestSpan = spanDist
            longestSpanStart = traffic[i].chainstart
            longestSpanEnd = traffic[i].chainend
        end
        if spanDist > 2 then
            if spanDist > 10 then --long ones are more likely ducks
                local spanType = (math.random() > 0.5) and 'jump' or 'duck'
                --if (traffic[i].strength > .95) and (math.random()>.9) then -- high speed areas may get additional rave sections
                --    spanType = 'rave'
                --    table.insert(minimapMarkers, {tracknode=traffic[i].chainstart, startheight=0, endheight=11, color={233,233,233}})
                --end
                TryMarkSpan(traffic[i].chainstart, traffic[i].chainend, spanType)
            else --shorter ones are more likely jumps
                TryMarkSpan(traffic[i].chainstart, traffic[i].chainend, (math.random() > 0.5) and 'jump' or 'duck')
            end
        end
    end

    --if longestSpan > 0 then
    --    for i=longestSpanStart, longestSpanEnd do -- turn the longest span into a rave (if it isn't already)
    --        if nodes[i]=='jump' or nodes[i]=='duck' then
    --            nodes[i] = 'rave'
    --        end
    --    end
    --
    --    table.insert(minimapMarkers, {tracknode=longestSpanStart, startheight=0, endheight=11, color={233,233,233}})
    --end

    local straffic = deepcopy(traffic)
    table.sort(straffic, CompareStrengths)

    for i = 1,#straffic do --mark these in their own loop. they're lower priority. place them in strength order to make sure the most important ones aren't overlapped and removed
        if (straffic[i].chainend - straffic[i].chainstart) < 3 then
            TryMarkSpan(straffic[i].impactnode, straffic[i].impactnode, (math.random() > 0.5) and 'jump' or 'duck')
        end
    end

    for i=1,#traffic do
        --if nodes[i]==nil or nodes[i]=='dirty'
        if (nodes[i] ~= 'jump') and (nodes[i]~='duck') and (nodes[i]~='rave') then
            nodes[i] = 'run' -- all non-action nodes get marked as 'run' in order to track the player's efficiency bonus
        end
    end
    --print("initialized player nodestates")
    --for jj=1, #players do
    --    local player = players[jj]
    --    for ii=1,#track do
    --        player.nodestates[ii] = 'run'
    --    end
    --end

    AddMinimapMarkers(minimapMarkers)
end

function InitMeteors()
    local playerHeight_impactYCompensator = 0 -- this is now handled in c#


    local sqrt = math.sqrt --making a local copy of global functions improves performance a bit
    local rand = math.random
    local min = math.min
    local max = math.max
    local sin = math.sin
    local cos = math.cos
    local degreesToRadians = .0174532925

    local chainstarter = true
    local angleD
    local angle
    local heading
    local mag
    local headingNormalized
    local impactRadius
    local impactPosition  
    local lastSentNode
    local color = {255,255,255}
    local typeID
    local mirrorTypeID
    local scale = {.04,.04,.04}
    local prevBlockType = "jump"
    local prevBlockSongTime = 0
    local prevBlockImpactX = 0
    local renderThisChain = true
    local mirrorThisChain = false
    local doubleNote = false
    local xMirrorOffset = 0;
    local mirrorColor
    local mirrorScale
    local jumpColor = {53,141,255} -- {53,141,173}
    local jumpScale = {.035,.035,.035}
    --local duckColor = {255,53,53} -- {176,53,53}
    local duckColor = {255,52,0} 
    local duckScale = {.035,.035,.035}
    local raveColor = {103,53,176}
    local raveScale = {.06,.06,.06}
    local impactX, impactY, impactZ
	local mirrorImpactX = impactX
    local isGroundTroop = false
    --local curveFactorX = 100
    --local curveFactorY = 35
    local impactY_BeyondChestHeight = 0
    local tiltFactor = 0
    local intensityFactor = 0
    local intensityFactorExp = 0

    local impactProxyScales = {}
    local impactProxyVelocities = {}
    local impactProxyScale = {.005,.005,.005}
    local idInThisChain = 1

    local myChainStarTime = 0
    local myChainEndTime = 0
    local nextChainStartTime = 0

    local isBallChain = false
    local isExtraLongBallChain = false
    local sweepDir = 1
    local sweepPosX = 0
    local prevBlockIsBallChain = false
    local prevBallChainDirection = 0
    -- \mod
    local prevBluePosition = 0
    local prevRedPosition = 0
    local prevBlueTime = -5
    local prevRedTime = -5
	local chainType = 'jump'
    
    for i=1,#track do
        if nodes[i]~=nil and nodes[i]~='run' and nodes[i]~='dirty' then
            if chainstarter then -- bring all meteors in this chain from the same direction
                tiltFactor = 0
                intensityFactor = 0
                intensityFactorExp = 0
                idInThisChain = 1
                isBallChain = false -- most of them are squids, not ball chains
                isExtraLongBallChain = false
                local chainLength = 0
				lastChainEndTime = myChainEndTime
                myChainStarTime = track[i].seconds
				
                local k=i
                while k<=#track and nodes[k]~=nil and nodes[k]~='run' and nodes[k]~='dirty' do --use the biggest intensity found in the span
                    local maxTiltSpan = maxTilt - minTilt
                    local myTiltSpan = track[k].tilt - minTilt
                    tiltFactor = max(tiltFactor, myTiltSpan/maxTiltSpan)
                    intensityFactor = max(intensityFactor, track[k].intensity)
                    myChainEndTime = track[k].seconds
                    chainLength = chainLength + 1
                    k = k + 1
                end

                nextChainStartTime = -1
                local kk = k
                for kk=k,#track do
                    if nodes[kk]~=nil and nodes[kk]~='run' and nodes[kk]~='dirty' then
                        nextChainStartTime = track[kk].seconds
                        break
                    end
                end

                --if i<500 then
                --    print("myChainStart:"..myChainStarTime.." myChainEnd:"..myChainEndTime.." nextChainStart:"..nextChainStartTime)
                --end

                intensityFactorExp = intensityFactor*intensityFactor*intensityFactor

                --heading = {-.5*rand() + .5, -.5*rand(), -2*rand()}
                heading = {0, 0, -1}
                headingNormalized = heading
                
                if nodes[i] == 'duck' then
                    local delta = math.pow(track[i].seconds - prevRedTime, 2)
                    
                    impactX = prevRedPosition
                    local bound1 = math.max(0, math.min(1, math.pow(( ((impactX - redMinX) / delta) - minAccelRight) / maxAccelRight, 1/factAccelRight) ))
                    local bound2 = math.max(0, math.min(1, math.pow(( ((redSpanX + redMinX - impactX) / delta) - minAccelRight) / maxAccelRight, 1/factAccelRight) ))
                    local modRand = rand()*(bound1+bound2)-bound1
                    
                    if (modRand < 0) then
                        impactX = impactX - (minAccelRight + maxAccelRight * math.pow(math.abs(modRand), factAccelRight)) * delta
                    else
                        impactX = impactX + (minAccelRight + maxAccelRight * math.pow(math.abs(modRand), factAccelRight)) * delta
                    end
                    
                    --impactX = -.5*rand() + .75
                    --impactX = redMinX + rand() * redSpanX
                elseif nodes[i] == 'jump' then
                    local delta = math.pow(track[i].seconds - prevBlueTime, 2)
                    
                    impactX = prevBluePosition
                    local bound1 = math.max(0, math.min(1, math.pow(( ((blueMaxX - impactX) / delta) - minAccelLeft) / maxAccelLeft, 1/factAccelLeft) ))
                    local bound2 = math.max(0, math.min(1, math.pow(( ((impactX - blueSpanX - blueMaxX ) / delta) - minAccelLeft) / maxAccelLeft, 1/factAccelLeft) ))
                    local modRand = rand()*(bound1+bound2)-bound2
                    
                    if (modRand < 0) then
                        impactX = impactX - (minAccelLeft + maxAccelLeft * math.pow(math.abs(modRand), factAccelLeft)) * delta
                    else
                        impactX = impactX + (minAccelLeft + maxAccelLeft * math.pow(math.abs(modRand), factAccelLeft)) * delta
                    end
                    
                    --impactX = .5 - rand() * .75
                    --impactX = blueMaxX + rand() * blueSpanX
                else
                    impactX = purpleSpanX*rand() + purpleMaxX
                end
                
                impactX = impactX * impactX_Scaler -- 1.7
                
                --impactY_BeyondChestHeight = rand()*yImpactSpan
                impactY_BeyondChestHeight = tiltFactor*tiltFactor*yImpactSpan + rand()*yImpactSpan_MaxRandomExtra
                impactY = chestHeight + impactY_BeyondChestHeight

                local impactDir = {impactX, impactY_BeyondChestHeight, 0}

                local targetMagSq = zImpact * zImpact
                impactZ = zImpact
                local impactXSq=impactX*impactX;
                local impactYSq = impactY_BeyondChestHeight*impactY_BeyondChestHeight
                for k=1, 9 do
                    local mag = impactXSq + impactYSq + impactZ*impactZ
                    if mag <= targetMagSq then
                        break
                    else
                        impactZ = impactZ - .05
                    end
                end

                local minSameBlockTypeSpacing = 0.00

                chainType = nodes[i]

                renderThisChain = true
                mirrorThisChain = false
				doubleNote = false
                isGroundTroop = false
                xMirrorOffset = 0

                --if track[i].intensity < .5 and rand()>.4 then
                --if chainType == 'rave' then
                --    --this one is a ground troop
                --    isGroundTroop = true
                --    impactY = chestHeight - .1
                --    if chainType == 'jump' then
                --        impactX = -1*math.abs(impactX)
                --    elseif chainType == 'duck' then
                --        impactX = math.abs(impactX)
                --    end
                --end

                local minSpacingAfterRaveBlock = 0.00

                --if i<1000 then
                --    print(chainType.."."..track[i].seconds.." prevTime:"..prevBlockSongTime)
                --end

                if prevBlockType == 'rave' then
                    if  not ((track[i].seconds - prevBlockSongTime) >= minSpacingAfterRaveBlock) then
                        renderThisChain = false -- don't render anything too close right after a rave
                    elseif not ((track[i].seconds - prevBlockSongTime) >= 1.5) then
                        --if we follow a rave, make sure we're not hidden behind it
                        if chainType == 'rave' then
                            impactX = prevBlockImpactX
                        elseif chainType == 'jump' then
                            if prevBlockImpactX < .2 then
                                impactX = .35
                            else
                                impactX = 0
                            end
                        elseif chainType == 'duck' then
                            if prevBlockImpactX > -.2 then
                                impactX = -.35
                            else
                                impactX = 0
                            end
                        end
                    end
                end

                local timeGapUntilNextChain = nextChainStartTime - myChainEndTime
                local timeGapSincePrevChain = lastChainEndTime - track[i].seconds
                local minRequiredStrafeForMirroring = .25
                local forceMirrorOn = (timeGapSincePrevChain>0.2) and ((nextChainStartTime<0) or ((intensityFactor > .5) and (timeGapUntilNextChain>2.0)) or (timeGapUntilNextChain>4.0))

				if chainType ~= 'rave' then
					if (intensityFactor > .75) or forceMirrorOn then -- big hit, end of song, or before a gap
						if forceMirrorOn then
							if math.abs(impactX)< minRequiredStrafeForMirroring then
								if (impactX < 0) then
								   impactX = - minRequiredStrafeForMirroring - .01
								else
								   impactX = minRequiredStrafeForMirroring + .01
								end
							end
						end
						if math.abs(impactX) >= minRequiredStrafeForMirroring then
							if (rand() < doubleFactor) or forceMirrorOn then
								mirrorThisChain = true
								impactX = math.max(-1*maxMirroredX, math.min(maxMirroredX, impactX))
								if chainType== 'jump' then
									mirrorScale = duckScale
									mirrorColor = duckColor
								else
									mirrorScale = jumpScale
									mirrorColor = jumpColor
								end
							end
						end
					end
				end
				
				if not mirrorThisChain and rand() < 0.2 and chainType ~= 'rave' then
					doubleNote = true
					if chainType== 'jump' then
						mirrorScale = duckScale
						mirrorColor = duckColor
					else
						mirrorScale = jumpScale
						mirrorColor = jumpColor
					end
				end
				
                if chainType=='jump' then
                    color = jumpColor
                    scale = jumpScale
                    typeID = 0
                    mirrorTypeID = 1
                elseif chainType=='duck' then
                    color = duckColor
                    scale = duckScale
                    typeID = 1
                    mirrorTypeID = 0
                elseif chainType=='rave' then
                    color = raveColor
                    scale = raveScale
                    typeID = 2
                    mirrorTypeID = 2
                end


                --if i <1000 then
                --    print("intensity:"..intensityFactor)
                --end

                if (chainType~='rave') then
                    --if (rand()>.9) and (chainLength>7) then
                    --    isBallChain = true
                    --end
                    if (chainLength>11) and (intensityFactor<.6) then
                        isBallChain = true
                    end
                    if (chainLength>22) and (intensityFactor<.9) then
                        isBallChain = true
                    end
                    --if chainLength>22 then
                    --    isBallChain = true
                    --end
                end
				
				if isBallChain then
					doubleNote = false
				end	
				
                sweepDir = 1
                if impactX > 0 then sweepDir = -1 end
                sweepPosX = impactX

                if isBallChain and chainLength>66 then
                    isExtraLongBallChain = true
                end

                chainstarter = false
            else
                idInThisChain = idInThisChain + 1
            end

            local yCurve = impactY_BeyondChestHeight*curveFactorY
            yCurve = math.min(yCurve, curveY_Max)
            yCurve = math.max(yCurve, curveY_Min)
            --yCurve = curveY_Max
            --local yCurve = impactY*curveFactorY
            --local yCurve = impactY*curveFactorY*((1.0-curveY_tiltInfluence)+curveY_tiltInfluence*tiltFactor)
            --local yCurve = impactY*curveFactorY*((1.0-curveY_tiltInfluence)+curveY_tiltInfluence*intensityFactorExp)

            --if renderThisChain and ((idInThisChain%2)==1) then -- only render every other ball in the chain
            if renderThisChain then
                prevBlockSongTime = track[i].seconds
                prevBlockType = chainType -- nodes[i]
                prevBlockImpactX = impactX
                prevBlockIsBallChain = isBallChain
                prevBallChainDirection = 1

                local adjustedImpactY = impactY + playerHeight_impactYCompensator

                lastSentNode = i

                if idInThisChain==1 or isBallChain then --this is the head of a chain or a strafe chain (ballChain)
                    local allowRender =  true
                    if isExtraLongBallChain and (idInThisChain>1) and (idInThisChain%2==0) then
                        allowRender = false -- for extra long chains, render only every other orb
                    end
                    
                    if allowRender then
                        local additionalX_SweepAcross = 0 -- -.005 + idInThisChain * .0015
                        local sweptImpactX = impactX
                        if isBallChain then
                            --additionalX_SweepAcross = -.025 + idInThisChain * .025
                            --if impactX > 0 then -- always move the trail towards center
                            --    additionalX_SweepAcross = additionalX_SweepAcross * -1
                            --    prevBallChainDirection = -1
                            --end
                            --sweptImpactX = sweptImpactX + additionalX_SweepAcross
                            --sweptImpactX = math.max(-1, math.min(sweptImpactX, 1)) -- contain them to a reseonable field size

                            sweepPosX = sweepPosX + .025 * sweepDir
                            if sweepPosX > 1 then
                                sweepPosX = 1
                                sweepDir = -1
                            elseif sweepPosX < -1 then
                                sweepPosX = -1
                                sweepDir = 1
                            end
                            sweptImpactX = sweepPosX

                            prevBlockImpactX = sweptImpactX
                        end

						if chainType == 'jump' then
							prevBlueTime = myChainEndTime
							prevBluePosition = sweptImpactX/impactX_Scaler
						elseif chainType == 'duck' then
							prevRedTime = myChainEndTime
							prevRedPosition = sweptImpactX/impactX_Scaler
						else
							prevRedTime = myChainEndTime
							prevRedPosition = sweptImpactX/impactX_Scaler
							prevBlueTime = myChainEndTime
							prevBluePosition = sweptImpactX/impactX_Scaler
						end
						ImpactX = sweptImpactX
						
                        meteorNodes[#meteorNodes+1] = i
                        meteorDirections[#meteorDirections+1] = headingNormalized -- {math.random() - .5, 0, math.random() - .5} -- the game normalizes these for us
                        meteorImpacts[#meteorImpacts+1] = {sweptImpactX, adjustedImpactY, impactZ}
                        meteorScales[#meteorScales+1] = scale
                        --meteorCurveMaximums[#meteorCurveMaximums+1] = fif(isGroundTroop,{0,0,0},{impactX*curveFactorX, impactY*curveFactorY, 0})--impactY*60
                        meteorCurveMaximums[#meteorCurveMaximums+1] = fif(isGroundTroop,{0,0,0},{sweptImpactX*curveFactorX, yCurve, 0})--impactY*60
                        meteorColors[#meteorColors+1] = color
                        meteorAlbedoColors[#meteorAlbedoColors+1] = {255,255,255}
                        meteorSpeeds[#meteorSpeeds+1] = meteorSpeed -- fif(isGroundTroop, .025,.05)
                        meteorTypes[#meteorTypes+1] = typeID

                        impactProxyScales[#impactProxyScales+1] = impactProxyScale
                        impactProxyVelocities[#impactProxyVelocities+1] = {0,0,0}

                        if mirrorThisChain or doubleNote then
                            mirrorImpactX = -1*sweptImpactX
                            if xMirrorOffset ~= 0 then
                                mirrorImpactX = sweptImpactX + xMirrorOffset
                            end
							if doubleNote then
								if sweptImpactX > 0 then
									mirrorImpactX = sweptImpactX-(math.random(50, 150)/100)
								else
									mirrorImpactX = sweptImpactX+(math.random(50, 150)/100)
								end
								if chainType == 'jump' then
									local timePast = (track[i].seconds - prevRedTime)
									local NearDistance = 3
									if (timePast < 0.5) then
										NearDistance = 0.15*(timePast*20)
									end
									local minX = prevRedPosition-NearDistance
									if minX < -1 then minX = -1 end
									local maxX = prevRedPosition+NearDistance
									if maxX > 1 then maxX = 1 end
									mirrorImpactX = math.max(mirrorImpactX, maxX)
									mirrorImpactX = math.min(mirrorImpactX, minX)
								elseif chainType == 'duck' then
									local timePast = (track[i].seconds - prevBlueTime)
									local NearDistance = 3
									if (timePast < 0.5) then
										NearDistance = 0.15*(timePast*20)
									end
									local minX = prevBluePosition-NearDistance
									if minX < -1 then minX = -1 end
									local maxX = prevBluePosition+NearDistance
									if maxX > 1 then maxX = 1 end
									mirrorImpactX = math.max(mirrorImpactX, maxX)
									mirrorImpactX = math.min(mirrorImpactX, minX)
								end

							end

							if chainType == 'jump' then
								prevRedTime = myChainEndTime
								prevRedPosition = mirrorImpactX/impactX_Scaler
							elseif chainType == 'duck' then
								prevBlueTime = myChainEndTime
								prevBluePosition = mirrorImpactX/impactX_Scaler
							end

                            meteorNodes[#meteorNodes+1] = i
                            meteorDirections[#meteorDirections+1] = headingNormalized -- {math.random() - .5, 0, math.random() - .5} -- the game normalizes these for us
                            meteorImpacts[#meteorImpacts+1] = {mirrorImpactX, adjustedImpactY, impactZ}
                            meteorScales[#meteorScales+1] = mirrorScale
                            --meteorCurveMaximums[#meteorCurveMaximums+1] = fif(isGroundTroop,{0,0,0},{-1*impactX*curveFactorX, impactY*curveFactorY, 0})
                            meteorCurveMaximums[#meteorCurveMaximums+1] = fif(isGroundTroop,{0,0,0},{mirrorImpactX*curveFactorX, yCurve, 0})
                            meteorColors[#meteorColors+1] = mirrorColor
                            meteorAlbedoColors[#meteorAlbedoColors+1] = {255,255,255}
                            meteorSpeeds[#meteorSpeeds+1] = meteorSpeed -- fif(isGroundTroop, .025,.05)
                            meteorTypes[#meteorTypes+1] = mirrorTypeID

                            impactProxyScales[#impactProxyScales+1] = impactProxyScale
                            impactProxyVelocities[#impactProxyVelocities+1] = {0,0,0}

                        end
                    end
                else -- this is part of a chain tail
                    --.035 -> .06
                    local additionalScale = -.005 + idInThisChain * .0015
                    additionalScale = math.min(additionalScale, .09)
                    local tailScale = {1,1,1}
                    tailScale[1] = scale[1] + additionalScale
                    tailScale[2] = scale[2] + additionalScale
                    tailScale[3] = scale[3] + additionalScale

                    --if i<1000 then
                    --    print("idInThisChain "..idInThisChain)
                    --    print("additionalScale "..additionalScale)
                    --    print("scaleX "..tailScale[1])
                    --end

                    meteorNodes_tails[#meteorNodes_tails+1] = i
                    meteorDirections_tails[#meteorDirections_tails+1] = headingNormalized -- {math.random() - .5, 0, math.random() - .5} -- the game normalizes these for us
                    meteorImpacts_tails[#meteorImpacts_tails+1] = {impactX, adjustedImpactY, impactZ}
                    meteorScales_tails[#meteorScales_tails+1] = tailScale
                    --meteorCurveMaximums[#meteorCurveMaximums+1] = fif(isGroundTroop,{0,0,0},{impactX*curveFactorX, impactY*curveFactorY, 0})--impactY*60
                    meteorCurveMaximums_tails[#meteorCurveMaximums_tails+1] = fif(isGroundTroop,{0,0,0},{impactX*curveFactorX, yCurve, 0})--impactY*60
                    meteorColors_tails[#meteorColors_tails+1] = color
                    meteorAlbedoColors_tails[#meteorAlbedoColors_tails+1] = {255,255,255}
                    meteorSpeeds_tails[#meteorSpeeds_tails+1] = meteorSpeed -- fif(isGroundTroop, .025,.05)
                    meteorTypes_tails[#meteorTypes_tails+1] = typeID

                    impactProxyScales[#impactProxyScales+1] = impactProxyScale
                    impactProxyVelocities[#impactProxyVelocities+1] = {0,0,0}

                    if mirrorThisChain or doubleNote then
                        --mirrorImpactX = -1*impactX
                        if xMirrorOffset ~= 0 then
                            mirrorImpactX = impactX + xMirrorOffset
                        end
                        meteorNodes_tails[#meteorNodes_tails+1] = i
                        meteorDirections_tails[#meteorDirections_tails+1] = headingNormalized -- {math.random() - .5, 0, math.random() - .5} -- the game normalizes these for us
                        meteorImpacts_tails[#meteorImpacts_tails+1] = {mirrorImpactX, adjustedImpactY, impactZ}
                        meteorScales_tails[#meteorScales_tails+1] = tailScale -- mirrorScale
                        --meteorCurveMaximums[#meteorCurveMaximums+1] = fif(isGroundTroop,{0,0,0},{-1*impactX*curveFactorX, impactY*curveFactorY, 0})
                        meteorCurveMaximums_tails[#meteorCurveMaximums_tails+1] = fif(isGroundTroop,{0,0,0},{mirrorImpactX*curveFactorX, yCurve, 0})
                        meteorColors_tails[#meteorColors_tails+1] = mirrorColor
                        meteorAlbedoColors_tails[#meteorAlbedoColors_tails+1] = {255,255,255}
                        meteorSpeeds_tails[#meteorSpeeds_tails+1] = meteorSpeed -- fif(isGroundTroop, .025,.05)
                        meteorTypes_tails[#meteorTypes_tails+1] = mirrorTypeID

                        impactProxyScales[#impactProxyScales+1] = impactProxyScale
                        impactProxyVelocities[#impactProxyVelocities+1] = {0,0,0}
                    end
                end
            end
        else
            chainstarter = true
        end
    end

    print("...............................")
    print("track length:"..#track)
    print("last meteor node"..lastSentNode)

    BatchRenderEveryFrame{prefabName="Meteor",
                            locations = meteorNodes,
                            maxShown = 100, --500, -- 1000,
                            emissivecolors = deepcopy(meteorColors), -- "nodecolor", -- "highway" for them to all be the same shifting color
                            colors = deepcopy(meteorColors),
                            --colors = meteorAlbedoColors, -- meteorColors, -- "nodecolor", -- "highway" for them to all be the same shifting color
                            scales = meteorScales,
                            maxDistanceShown = maxNodeDistShown,
                            broadcastimpactvelocities = true,
                            --songspeedratio = .05, -- amount of speed compression
                            songspeedratios = meteorSpeeds,
                            typeids = meteorTypes,
                            afternodereached_numbernodesrendered = 9,
                            override_impactpositions = meteorImpacts,
                            override_velocities = meteorDirections,
                            sinCurvePositionDistortionPeaks = meteorCurveMaximums,
                            override_velocities_scaledbytrackspeed = true}

    BatchRenderEveryFrame{prefabName="Meteor_Tail",
                            ismeteortail = true,
                            locations = meteorNodes_tails,
                            maxShown = 1500, --500, -- 1000,
                            emissivecolors = deepcopy(meteorColors_tails), -- "nodecolor", -- "highway" for them to all be the same shifting color
                            colors = deepcopy(meteorColors_tails),
                            --colors = meteorAlbedoColors_tails, -- meteorColors, -- "nodecolor", -- "highway" for them to all be the same shifting color
                            --colors = deepcopy(meteorColors_tails),
                            scales = meteorScales_tails,
                            maxDistanceShown = maxNodeDistShown,
                            broadcastimpactvelocities = true,
                            --songspeedratio = .05, -- amount of speed compression
                            songspeedratios = meteorSpeeds_tails,
                            typeids = meteorTypes_tails,
                            afternodereached_numbernodesrendered = 9,
                            override_impactpositions = meteorImpacts_tails,
                            override_velocities = meteorDirections_tails,
                            sinCurvePositionDistortionPeaks = meteorCurveMaximums_tails,
                            override_velocities_scaledbytrackspeed = true}

    --render impact positions to help debug hit timing
    local showDebugImpactPoints = false
    if showDebugImpactPoints then
        BatchRenderEveryFrame{prefabName="Meteor",
                                locations = meteorNodes,
                                maxShown = 50,
                                emissivecolors = deepcopy(meteorColors), -- "nodecolor", -- "highway" for them to all be the same shifting color
                                colors = meteorColors, -- "nodecolor", -- "highway" for them to all be the same shifting color
                                scales = impactProxyScales,
                                maxDistanceShown = maxNodeDistShown,
                                typeids = meteorTypes,
                                --broadcastimpactvelocities = true,
                                --songspeedratio = .05, -- amount of speed compression
                                --songspeedratios = meteorSpeeds,
                                afternodereached_numbernodesrendered = 1,
                                override_impactpositions = meteorImpacts,
                                override_velocities = impactProxyVelocities
        }
    end
                            --sinCurvePositionDistortionPeaks = meteorCurveMaximums,
                            --override_velocities_scaledbytrackspeed = true}
end

camHeightMax = 1100
camHeightMin = 750
camHeight = camHeightMax
score = score or 10000

skinHasLoaded = skinHasLoaded or false
function OnSkinLoaded()-- called after OnTrafficCreated
    HideBuiltinPlayerObjects()

    SetCamera{ -- calling this function (even just once) overrides the camera settings from the skin script
        pos = {0,0,0},
        rot = {0,0,0},
        railoffset = "detached" -- this camera will not move along the track
    }

    skinHasLoaded = true

    InitMeteors()
    hasInitedMeteors = true
end

--function OnPlayerHeightEstablished(playerHeight)
--    InitMeteors()
--    hasInitedMeteors = true
--end

dinoAngle = 0
hittable = true
invulnTicker = 0
invulnDuration = .7
hitsSuffered = 0
timeMoving = 0
timeTotal = 0

function GetScore()
    local numMissed = GetNumShieldMisses()
    return math.max(1, 1000 - 1 * numMissed)
end

quarterSecondCounter = 0
function UpdateEachQuarterSecond()
    local scoref = GetScore()
    SetGlobalScore{score=scoref,showdelta=false}
end

updatesRun = updatesRun or 0
hasInitedMeteors = hasInitedMeteors or false

--[[
doesntwork = true
deltadt = 0
output1 = true
output2 = true

function Update(dt, tracklocation, strafe, input, jumpheight)
    if doesntwork then
        doesntwork = false
        print("frantically blantubularizing")
    end
    if output1 then
        if deltadt < 5 then
            deltadt = deltadt + dt
        else
            output1 = false
            print("machinating deuterium 1.0 - " .. deltadt .. " - " .. dt)
        end
    end
    if output2 then
        if dt >= 5 then
            output2 = false
            print("machinating deuterium 2.0 - " .. dt)
        end
    end
end
--]]

function OnRequestFinalScoring()
    AssignBuiltInAudioshieldScoring()
end