
ConfigFile = ac.INIConfig.load(ac.getFolder(ac.FolderID.ACApps) .. "/lua/FFBAntiClip/" .. "settings.ini")
DataFile = ac.INIConfig.load(ac.getFolder(ac.FolderID.ACApps) .. "/lua/FFBAntiClip/" .. "data.ini")

Sim = ac.getSim()
Car = ac.getCar(Sim.focusedCar)
MyCarID = Sim.focusedCar
MyCarFolderName = ac.getCarID(Sim.focusedCar)
MyCarHumanName = ac.getCarName(Sim.focusedCar, true)

ConfigFFBAntiClipEnabled = ConfigFile:get("settings", "FFBAntiClipEnabled", true)
ConfigDesiredFFBLevel = ConfigFile:get("settings", "FFBDesiredLevel", 90) -- percentage

ConfigCarGainModifierEnabled = ConfigFile:get(MyCarFolderName, "FFBGainModifier", false)
ConfigCarGainModifierValue = ConfigFile:get(MyCarFolderName, "FFBGainModifierValue", 100) -- percentage

ConfigCurrentCarFFB = DataFile:get(MyCarFolderName, "FFB", Car.ffbMultiplier)
ac.setFFBMultiplier(ConfigCurrentCarFFB)

Timer = 0
Updates = 0
TimerFFBRaise = 0
RaisesSinceLastDrop = 1
ClippingFrames = 0

local samples = {}
local avgFPS = 60

function math_average(t)
    local sum = 0
    for _,v in pairs(t) do -- Get the sum of all numbers in t
        sum = sum + v
    end
    return sum / #t
end

function FFBAntiClipFunction()
    local ffbCurrent = Car.ffbFinal
    local ffbMultiplier = Car.ffbMultiplier
    local ffbTarget = (ConfigDesiredFFBLevel*0.01)*(ConfigCarGainModifierValue*0.01)
    

    if ffbCurrent and math.abs(ffbCurrent) >= ffbTarget*0.5 then -- Only take samples when FFB is higher than 80% of target to avoid it gaining on straights. We want to see how the FFB acts under pressure.
        TimerFFBRaise = 0
        if math.abs(ffbCurrent) >= ffbTarget then
            for _ = 1,4 do
                samples[#samples+1] = math.abs(ffbCurrent)
            end
        else
            samples[#samples+1] = math.abs(ffbCurrent)
        end
    end
    --ac.log(avgFPS)
    if math.abs(ffbCurrent) < 0.05 then
        if #samples >= 20*avgFPS then
            local ffbAverage = math_average(samples)
            ac.setFFBMultiplier(ffbMultiplier + math.max(-0.2, math.min(0.02, ((ffbTarget - ffbAverage)))*0.1))
            samples = {}
        elseif TimerFFBRaise > 10 then
            TimerFFBRaise = 0
            ac.setFFBMultiplier(ffbMultiplier + 0.001)
        end
    end

    if Updates%600 == 0 then
        DataFile:set(MyCarFolderName, "FFB", ffbMultiplier)
        DataFile:save()
    end
end

local crashTimer = 0

function script.update(dt)
    Timer = Timer + dt
    Updates = Updates + 1
    TimerFFBRaise = TimerFFBRaise + dt

    Sim = ac.getSim()
    Car = ac.getCar(Sim.focusedCar)
    if Car.collisionDepth > 0 then
        if Car.collisionDepth < 0.1 and crashTimer < 10 then
            crashTimer = 10
        elseif Car.collisionDepth >= 0.1 and Car.collisionDepth < 0.25 and crashTimer < 20 then
            crashTimer = 20
        elseif Car.collisionDepth >= 0.25 and crashTimer < 30 then
            crashTimer = 30
        end
    elseif crashTimer > 0 then
        crashTimer = crashTimer - dt
    end

    avgFPS = ((avgFPS*599)+Sim.fps)/600

    if ConfigFFBAntiClipEnabled and (not Sim.isReplayActive) and Car.speedKmh > 50 and (not Sim.isPaused) and (not Car.isAIControlled) and ac.getSim().inputMode == 0 and crashTimer <= 0 then -- FFB Anti-Clip
        FFBAntiClipFunction()
    end

end

function script.windowMain()
    local needToSave = false
    local checkbox = false
    
    ui.separator()
    ui.text(MyCarHumanName)
    ui.separator()
    ui.text("Force Feedback. Current: " .. math.ceil(Car.ffbMultiplier*10000)/100 .. "%")
    local nextAdjustment = (math.ceil(math.max(-0.2, math.min(0.02, (((ConfigDesiredFFBLevel*0.01)*(ConfigCarGainModifierValue*0.01) - math_average(samples))))*0.1)*10000)/100)
    if nextAdjustment > 0 then
        ui.text("Next Adjustment: +" .. nextAdjustment .. "%")
    else
        ui.text("Next Adjustment: " .. nextAdjustment .. "%")
    end
    
    ui.separator()
    ui.text("Samples Until Next Adjustment: " .. math.max(0, math.ceil((20*avgFPS) - #samples)))
    ui.text("Time Until Next Passive FFB Raise: " .. math.max(0, math.ceil(10 - TimerFFBRaise)) .. " Seconds")
    ui.separator()

    checkbox = ui.checkbox("Enabled", ConfigFFBAntiClipEnabled)
    if checkbox then
        ConfigFFBAntiClipEnabled = not ConfigFFBAntiClipEnabled
        ConfigFile:set("settings", "FFBAntiClipEnabled", ConfigFFBAntiClipEnabled)
        ConfigCurrentCarFFB = DataFile:get(MyCarFolderName, "FFB", 1)
        ac.setFFBMultiplier(ConfigCurrentCarFFB)
        needToSave = true
    end

    ui.text('Desired Force Feedback Gain')
    local sliderValue2 = ConfigDesiredFFBLevel
    sliderValue2 = ui.slider("% (Default 90%) ##slider2", sliderValue2, 0, 200)
    if ConfigDesiredFFBLevel ~= sliderValue2 then
        ConfigDesiredFFBLevel = sliderValue2
        ConfigFile:set("settings", "FFBDesiredLevel", sliderValue2)
        needToSave = true
    end
    if ui.itemHovered() then
        ui.setTooltip('This basically defines how strong you want your force feedback to be, or if set above 100%, how much clipping you allow to happen. It is recommended to set this value lower for Direct Drive wheels, and higher for weak wheels.')
    end

    checkbox = ui.checkbox("Car Override Enabled", ConfigCarGainModifierEnabled)
    if checkbox then
        ConfigCarGainModifierEnabled = not ConfigCarGainModifierEnabled
        ConfigFile:set(MyCarFolderName, "FFBGainModifier", ConfigCarGainModifierEnabled)
        ConfigCurrentCarFFB = ConfigFile:get(MyCarFolderName, "FFB", 1)
        ac.setFFBMultiplier(ConfigCurrentCarFFB)
        needToSave = true
    end
    if ui.itemHovered() then
        ui.setTooltip('If the car you are driving ends up with force feedback too low or too high, and you dont want to change the global value, you can set a relative multiplier for this specific car.')
    end

    if ConfigCarGainModifierEnabled then
        
        ui.text('Car Override Value (Relative to global)')
        local sliderValue3 = ConfigCarGainModifierValue
        sliderValue3 = ui.slider("% (Default 100%) ##slider3", sliderValue3, 0, 200)
        if ConfigCarGainModifierValue ~= sliderValue3 then
            ConfigCarGainModifierValue = sliderValue3
            ConfigFile:set(MyCarFolderName, "FFBGainModifierValue", sliderValue3)
            needToSave = true
        end
        if ui.itemHovered() then
            ui.setTooltip('Car specific multiplier for gain target. Use this if the car youre driving has too low or too high gain and you dont want to change the global setting')
        end

        ui.text('Result: ' .. ((ConfigDesiredFFBLevel*0.01)*(ConfigCarGainModifierValue*0.01))*100 .. "%")
        
    elseif (not ConfigCarGainModifierEnabled) and ConfigCarGainModifierValue ~= 100 then
        ConfigCarGainModifierValue = 100
        ConfigFile:set(MyCarFolderName, "FFBGainModifierValue", 100)
        needToSave = true
    end

    if needToSave then
        ConfigFile:save()
    end
end