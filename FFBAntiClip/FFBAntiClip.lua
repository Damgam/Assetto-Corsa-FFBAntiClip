
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
ConfigFFBUpdateRate = ConfigFile:get("settings", "FFBUpdateRate", 1) -- multiplier
ConfigDesiredFFBLevel = ConfigFile:get("settings", "FFBDesiredLevel", 110) -- percentage
ConfigFFBQuickDrops = ConfigFile:get("settings", "FFBQuickDrops", true)

ConfigCurrentCarFFB = DataFile:get(MyCarFolderName, TrackFolderName, Car.ffbMultiplier)
ac.setFFBMultiplier(ConfigCurrentCarFFB)

Timer = 0
Updates = 0
TimerFFBDrop = 0
TimerFFBRaise = 0

function FFBAntiClipFunction()
    if (not Sim.isReplayActive) then
        local ffbCurrent = Car.ffbFinal
        if (TimerFFBDrop > ConfigFFBUpdateRate or ConfigFFBQuickDrops) and ffbCurrent and (ffbCurrent >= ConfigDesiredFFBLevel*0.01 or ffbCurrent <= (-ConfigDesiredFFBLevel)*0.01) then
            local ffbMultiplier = Car.ffbMultiplier
            ac.setFFBMultiplier(ffbMultiplier-0.001)
            TimerFFBDrop = 0
        end

        if TimerFFBRaise > ConfigFFBUpdateRate*20 then
            local ffbMultiplier = Car.ffbMultiplier
            ac.setFFBMultiplier(ffbMultiplier+0.001)
            TimerFFBRaise = 0
            DataFile:set(MyCarFolderName, TrackFolderName, ffbMultiplier)
            ConfigCurrentCarFFB = ffbMultiplier
            DataFile:save()
        end
    end
end

function script.update(dt)
    Timer = Timer + dt
    Updates = Updates + 1
    TimerFFBDrop = TimerFFBDrop + dt
    TimerFFBRaise = TimerFFBRaise + dt

    Sim = ac.getSim()
    Car = ac.getCar(Sim.focusedCar)

    if ConfigFFBAntiClipEnabled and Car.speedKmh > 50 then -- FFB Anti-Clip
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

    checkbox = ui.checkbox("Quick FFB Gain Reduction", ConfigFFBQuickDrops)
    if checkbox then
        ConfigFFBQuickDrops = not ConfigFFBQuickDrops
        ConfigFile:set("settings", "FFBQuickDrops", ConfigFFBQuickDrops)
        needToSave = true
    end
    if ui.itemHovered() then
        ui.setTooltip('Reduce gain value as soon as you are clipping, regardless of the update rate')
    end

    ui.text('Desired Force Feedback Gain')
    local sliderValue2 = ConfigDesiredFFBLevel
    sliderValue2 = ui.slider("% (Default 110%) ##slider2", sliderValue2, 0, 200)
    if ConfigDesiredFFBLevel ~= sliderValue2 then
        ConfigDesiredFFBLevel = sliderValue2
        ConfigFile:set("settings", "FFBDesiredLevel", sliderValue2)
        needToSave = true
    end
    if ui.itemHovered() then
        ui.setTooltip('This basically defines how strong you want your force feedback to be, or if set above 100%, how much clipping you allow to happen. It is recommended to set this value lower for Direct Drive wheels, and higher for weak wheels. Default 110% is perfect for my T300 RS')
    end

    ui.text('Force Feedback Gain Update Rate Multiplier')
    local sliderValue3 = ConfigFFBUpdateRate
    sliderValue3 = ui.slider("(Default 1) ##slider3", sliderValue3, 0.01, 5)
    if ConfigFFBUpdateRate ~= sliderValue3 then
        ConfigFFBUpdateRate = sliderValue3
        ConfigFile:set("settings", "FFBUpdateRate", sliderValue3)
        needToSave = true
    end
    if ui.itemHovered() then
        ui.setTooltip('Default is to reduce 0.1% every 1 second and raise  0.1% every 20 seconds. If Quick FFB Gain Reduction option is enabled, dropping is always instant.')
    end

    if needToSave then
        ConfigFile:save()
    end
end