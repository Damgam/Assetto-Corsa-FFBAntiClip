
ConfigFile = ac.INIConfig.load(ac.getFolder(ac.FolderID.ACApps) .. "/lua/FFBAntiClip/" .. "settings.ini")
DataFile = ac.INIConfig.load(ac.getFolder(ac.FolderID.ACApps) .. "/lua/FFBAntiClip/" .. "data.ini")

Sim = ac.getSim()
Car = ac.getCar(Sim.focusedCar)
MyCarID = Sim.focusedCar
MyCarFolderName = ac.getCarID(Sim.focusedCar)
MyCarHumanName = ac.getCarName(Sim.focusedCar, true)
TrackFolderName = ac.getTrackFullID("_")
TrackHumanName = ac.getTrackName()

ConfigFFBAntiClipEnabled = ConfigFile:get("settings", "FFBAntiClipEnabled", true)
ConfigDesiredFFBLevel = ConfigFile:get("settings", "FFBDesiredLevel", 100) -- percentage

ConfigCarGainModifierEnabled = ConfigFile:get(MyCarFolderName, "FFBGainModifier", false)
ConfigCarGainModifierValue = ConfigFile:get(MyCarFolderName, "FFBGainModifierValue", 100) -- percentage

ConfigCurrentCarFFB = DataFile:get(MyCarFolderName, TrackFolderName, Car.ffbMultiplier)
ac.setFFBMultiplier(ConfigCurrentCarFFB)

Timer = 0
Updates = 0
TimerFFBRaise = 0
RaisesSinceLastDrop = 1
ClippingFrames = 0

function FFBAntiClipFunction()
    local ffbCurrent = Car.ffbFinal
    local ffbMultiplier = Car.ffbMultiplier

    if ffbCurrent and (ffbCurrent >= (ConfigDesiredFFBLevel*0.01)*(ConfigCarGainModifierValue*0.01) or ffbCurrent <= -((ConfigDesiredFFBLevel*0.01)*(ConfigCarGainModifierValue*0.01))) then
        ClippingFrames = ClippingFrames + 1
    elseif ClippingFrames > 0 then
        ClippingFrames = 0
    end

    if ClippingFrames > 30 then
        ac.setFFBMultiplier(ffbMultiplier-0.001)
    elseif ClippingFrames > 15 then
        ac.setFFBMultiplier(ffbMultiplier-0.0001)
    elseif ClippingFrames > 5 then
        ac.setFFBMultiplier(ffbMultiplier-0.00001)
        RaisesSinceLastDrop = 1
        TimerFFBRaise = 0
    end

    if TimerFFBRaise > 60/RaisesSinceLastDrop then
        ac.setFFBMultiplier(ffbMultiplier+(0.001))
        TimerFFBRaise = 0
        DataFile:set(MyCarFolderName, TrackFolderName, ffbMultiplier)
        ConfigCurrentCarFFB = ffbMultiplier
        DataFile:save()
        RaisesSinceLastDrop = RaisesSinceLastDrop + 1
    end
end

function script.update(dt)
    Timer = Timer + dt
    Updates = Updates + 1
    TimerFFBRaise = TimerFFBRaise + dt

    Sim = ac.getSim()
    Car = ac.getCar(Sim.focusedCar)

    if ConfigFFBAntiClipEnabled and (not Sim.isReplayActive) and Car.speedKmh > 50 and (not Sim.isPaused) then -- FFB Anti-Clip
        FFBAntiClipFunction()
    end

end

function script.windowMain()
    local needToSave = false
    local checkbox = false

    ui.separator()
    ui.text("Force Feedback. Current: " .. math.ceil(Car.ffbMultiplier*10000)/100 .. "%")
    ui.text(MyCarHumanName)
    ui.text(TrackHumanName)
    ui.separator()

    checkbox = ui.checkbox("Enabled", ConfigFFBAntiClipEnabled)
    if checkbox then
        ConfigFFBAntiClipEnabled = not ConfigFFBAntiClipEnabled
        ConfigFile:set("settings", "FFBAntiClipEnabled", ConfigFFBAntiClipEnabled)
        ConfigCurrentCarFFB = DataFile:get(MyCarFolderName, TrackFolderName, 1)
        ac.setFFBMultiplier(ConfigCurrentCarFFB)
        needToSave = true
    end

    ui.text('Desired Force Feedback Gain')
    local sliderValue2 = ConfigDesiredFFBLevel
    sliderValue2 = ui.slider("% (Default 100%) ##slider2", sliderValue2, 0, 200)
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
        ConfigCurrentCarFFB = ConfigFile:get(MyCarFolderName, TrackFolderName, 1)
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