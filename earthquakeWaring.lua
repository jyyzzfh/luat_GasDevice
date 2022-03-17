module(..., package.seeall) -- 使得文件中的函数在何处都可调用
require "pins" -- 用到了pin库，该库为luatask专用库，需要进行引用
require "sys"
require "rtos"
require "getLbsLoc"
require "rtos"
require "uartTask"
require "utils"
require "mqtt"
require "misc"
require "audio"
local ttsStr = "预警系统演练"
TTS = 1
-- 地震预警系统
-- 两个功能：1.预警系统演练（tts语音播报3遍同时报警音触发）
-- 入参：mqttData接收的预警信息
-- local setGpio9Fnc = pins.setup(pio.P0_9, 1) -- 静音设置（高电平静音）
--[[ function EarthquakeWarningSystem(mqttData)
    log.info("jsonData", mqttData)
    local tjsondata, result, errinfo = json.decode(mqttData)
    if result and type(tjsondata) == "table" then
        local focal_longitude, focal_latitude, quakeTime, quake_intensity,equipment_unit,early_warning_system_drill =
            tjsondata["2"], tjsondata["3"], tjsondata["1"], tjsondata["4"],tjsondata["5"],tjsondata["6"]
            if equipment_unit == 8 then
                if early_warning_system_drill==1 then
                    earlyWarningDrill()
                elseif early_warning_system_drill==0 then
                    EarthquakeWarning(focal_longitude,focal_latitude,quakeTime,quake_intensity)
                end
            end
        log.info("Equipment_latitude", getLbsLoc.Lat, "Equipment_longitude",getLbsLoc.Lng)
    end
end ]]
function EarthquakeWarning(mqttData)
    log.info("jsonData", mqttData)
    local setGpio9Fnc = pins.setup(pio.P0_9, 1) -- 静音设置（高电平静音）
    local setGpio12Fnc = pins.setup(pio.P0_12, 0) -- 报警灯
    local tjsondata, result, errinfo = json.decode(mqttData)
    if result and type(tjsondata) == "table" then
        local focal_longitude, focal_latitude, quakeTime, quake_intensity =
            tjsondata["2"], tjsondata["3"], tjsondata["1"], tjsondata["4"]
        local sysTime = os.time();
        log.info("sysTime", sysTime)
        -- 计算距离
        local distance = Algorithm(getLbsLoc.Lng, getLbsLoc.Lat,
                                focal_longitude, focal_latitude) / 1000
        log.info("distance", distance)
        -- 计算S波到达时间 减1秒网络延时
        local countDownS = math.floor((distance / 3.5) -
                                        ((sysTime - quakeTime) / 1000))
        countDownS = countDownS < 0 and 0 or countDownS
        log.info("countDownS", countDownS)
        -- 烈度计算
        local intensity = math.floor(Round(
                                         quake_intensity - 4 *
                                            math.log((distance / 10 + 1.0), 10)))
        log.info("intensity", intensity)
        if intensity <= 0 then intensity = 1 end
        -- 地震烈度大于等于设定预警临界值则执行报警
        if intensity >= 5 then
            local count = 0
            --[[ while count1 ~= 3 do
                setGpio23Fnc(1)
                count1 = count1 + 1
                sys.wait(500)
                setGpio23Fnc(0)
            end ]]
            if countDownS > 0 then
                setGpio9Fnc(0)
                --sys.taskInit(mqttQuakAlarmSendTask, intensity)
                sys.taskInit(solenoidValveOperationTask)
                sys.taskInit(alarmLampOperationTask, countDownS)
                while countDownS >= 0 do
                    if countDownS <= 10 then
                        ttsStr = tostring(countDownS)
                        audio.play(TTS, "TTS", ttsStr, 7)
                    end
                    if math.fmod(count, 12) == 0 then
                        uartTask.write(0x0C)
                    end
                    --[[ if math.fmod(countDownS, 2) == 0 then
                        setGpio12Fnc(0)
                    else
                        setGpio12Fnc(1)
                    end ]]
                    sys.wait(1000)
                    countDownS = countDownS - 1
                    count = count + 1
                end
                setGpio9Fnc(1) -- 报警结束设置静音
            end
        end
    end
end
-- 报警音串口通讯
--function voiceAlarmTask() uartTask.write(0x0C) end
-- 报警灯操作任务
function alarmLampOperationTask(countDown)
    local count = 0
    local setGpio12Fnc = pins.setup(pio.P0_12, 0) -- 报警灯
    while countDown > 0 do
        while count ~= 4 do
            setGpio12Fnc(1)
            count = count + 1
            sys.wait(250)
        end
        count = 0
        countDown = countDown - 1
        sys.wait(1000)
        countDown = countDown - 1
    end
    setGpio12Fnc(0)
end
-- 电磁阀操作任务
function solenoidValveOperationTask()
    local count1 = 0
    local setGpio23Fnc = pins.setup(pio.P0_23, 0) -- 电磁阀阀门控制端口设为低电平
    while count1 ~= 3 do
        setGpio23Fnc(1)
        count1 = count1 + 1
        sys.wait(1000)
    end
    count1 = 0
    setGpio23Fnc(0)
end
--[[ function earlyWarningDrill()
    log.info("tts voice")
    setGpio9Fnc(0)
    local countDrill = 0
    uartTask.write(0x0C)
    while countDrill ~= 3 do
        audio.play(TTS, "TTS", ttsStr, 7)
        countDrill = countDrill + 1
        sys.wait(1500)
    end
    sys.wait(12000)
    setGpio9Fnc(1) -- 报警结束设置静音
end ]]
--[[ function mqttQuakAlarmSendTask(intensity)
    local imei = misc.getImei()
    local topic = "gas/quake/" .. tostring(misc.getImei())
    local sendMsg =
        "{" .. "value:" .. tostring(intensity) .. "," .. "sysTime:" .. os.time() ..
            "}"
    local mqttc = mqtt.client(imei, nil, "admin", "keson-123", nil, nil, "3.1")
    if mqttc:connect("47.94.80.3", 1883, "tcp") then
        mqttc:publish(topic, sendMsg, 0)
    end
    mqttc:disconnect()
end ]]
function Algorithm(equipment_longitude, equipment_latitude, focal_longitude,
                   focal_latitude)
    local Lat1 = math.rad(equipment_latitude)
    log.info("focal_latitude:", focal_latitude)
    local Lat2 = math.rad(focal_latitude)
    local a = Lat1 - Lat2
    local b = math.rad(equipment_longitude) - math.rad(focal_longitude)
    local s = 2 *
                math.asin(
                      math.sqrt(math.pow(math.sin(a / 2), 2) + math.cos(Lat1) *
                                    math.cos(Lat2) *
                                    math.pow(math.sin(b / 2), 2)))
    s = s * 6378137.0
    s = Round(s * 10000) / 10000; -- 精确距离的数值
    return s
end
function Round(x) return x >= 0 and math.floor(x + 0.5) or math.ceil(x - 0.5) end
