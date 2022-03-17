module(..., package.seeall) -- 使得文件中的函数在何处都可调用
require "pins"
require "math"
require "sys"
require "mpu6050"
require "uartTask"
require "mqttOutMsg"
require "earthquakeWaring"
require "mqtt"
require "misc"
local sample = {x = nil, y = nil, z = nil}
local sstate = {x = nil, y = nil, z = nil} -- x,y,z加速度平均值
local velocity,acceleration  = 0,0
local accelerationx = {[0] = 0.00, [1] = 0.00}
local accelerationy = {[0] = 0.00, [1] = 0.00}
local accelerationz = {[0] = 0.00, [1] = 0.00} -- 合成加速度,x,y,z方向加速度 
local velocityx = {[0] = 0.00, [1] = 0.00}
local velocityy = {[0] = 0.00, [1] = 0.00}
local velocityz = {[0] = 0.00, [1] = 0.00} -- 合成速度，x,y,z方向速度
local count, count1, count2= 1, 1, 1
local intensity = 0 -- 震级
local pga, pgv = 0, 0 -- 加速度峰值，速度峰值
local pgaI, pgvI = 0, 0 -- 地震烈度PGA，PGV
local i = 0 -- 地震烈度
local setGpio10Fnc = pins.setup(pio.P0_10,0)--煤气泄露报警端口设为低电平
local setGpio23Fnc = pins.setup(pio.P0_23,0)--煤气阀门控制端口设为低电平
function DisplacementAlarm(sample, sstate)
    -- 进行滤波
    if math.fmod(count, 3) ~= 0 then
        accelerationx[1] = accelerationx[1] + sample.x/1000
        accelerationy[1] = accelerationy[1] + sample.y/1000
        accelerationz[1] = accelerationz[1] + sample.z/1000
    else
        -- xyz加速度求平均值
        accelerationx[1] = accelerationx[1] / 2
        accelerationy[1] = accelerationy[1] / 2
        accelerationz[1] = accelerationz[1] / 2
        accelerationx[1] = accelerationx[1] -sstate.x
        accelerationy[1] = accelerationy[1] -sstate.y
        accelerationz[1] = accelerationz[1] -sstate.z
        -- 机械滤波
        if (accelerationx[1] <= 0.01) and (accelerationx[1] >= -0.01) then
            accelerationx[1] = 0
        end
        if (accelerationy[1] <= 0.01) and (accelerationy[1] >= -0.01) then
            accelerationy[1] = 0
        end
        if (accelerationz[1] <= 0.01) and (accelerationz[1] >= -0.01) then
            accelerationz[1] = 0
        end
        -- 计算xyz方向加速度
        velocityx[1] = velocityx[0] + accelerationx[0] +(accelerationx[1] - accelerationx[0]) / 2
        velocityy[1] = velocityy[0] + accelerationy[0] +(accelerationy[1] - accelerationy[0]) / 2
        velocityz[1] = velocityz[0] + accelerationz[0] +(accelerationz[1] - accelerationz[0]) / 2
        if (accelerationx[0] - accelerationx[1])<=0.01 and (accelerationx[0] - accelerationx[1])>=-0.01 and 
        (accelerationy[0] - accelerationy[1])<=0.01 and (accelerationy[0] - accelerationy[1])>=-0.01 and 
        (accelerationz[0] - accelerationz[1])<=0.01 and (accelerationz[0] - accelerationz[1])>=-0.01 and 
        count2 <= 10 then
                count2 = count2 + 1
        elseif (accelerationx[0] - accelerationx[1])<=0.01 and (accelerationx[0] - accelerationx[1])>=-0.01 and 
            (accelerationy[0] - accelerationy[1])<=0.01 and (accelerationy[0] - accelerationy[1])>=-0.01 and 
            (accelerationz[0] - accelerationz[1])<=0.01 and (accelerationz[0] - accelerationz[1])>=-0.01 and 
            count2 >10 then
                velocity = 0.00
                mpu6050.CountMpu6050 =1
                mpu6050.Sstate={x=0.00,y=0.00,z=0.00}
                count, count1, count2 = 0, 0, 1
                sample = {x = nil, y = nil, z = nil}
                sstate = {x = nil, y = nil, z = nil} -- x,y,z加速度平均值
                velocity, acceleration = 0, 0
                accelerationx = {[0] = 0.00, [1] = 0.00}
                accelerationy = {[0] = 0.00, [1] = 0.00}
                accelerationz = {[0] = 0.00, [1] = 0.00} -- 合成加速度,x,y,z方向加速度 
                velocityx = {[0] = 0.00, [1] = 0.00}
                velocityy = {[0] = 0.00, [1] = 0.00}
                velocityz = {[0] = 0.00, [1] = 0.00} -- 合成速度，x,y,z方向速度
                intensity = 0 -- 震级
                pga, pgv = 0, 0 -- 加速度峰值，速度峰值
                pgaI, pgvI =0,0 -- 地震烈度PGA，PGV
                i = 0 -- 地震烈度
        end
        accelerationx[0] = accelerationx[1]
        accelerationy[0] = accelerationy[1]
        accelerationz[0] = accelerationz[1]
        -- 合成加速度(xyz方向加速度 )
        acceleration = math.sqrt(math.pow(math.abs(accelerationx[0]), 2) +math.pow(math.abs(accelerationy[0]), 2) +math.pow(math.abs(accelerationz[0]), 2))
        -- 计算xyz方向速度
        velocityx[0] = velocityx[1];
        velocityy[0] = velocityy[1];
        velocityz[0] = velocityz[1];
        -- 合成速度(xyz方向速度)
        velocity = math.sqrt(math.pow(velocityx[0], 2) +math.pow(velocityy[0], 2) +math.pow(velocityz[0], 2))
        velocityx[1], velocityy[1], velocityz[1] = 0.00, 0.00, 0.00
        --if math.fmod(count1, 50) ~= 0 then
            --if acceleration > pga then pga = acceleration end
            --if velocity > pgv then pgv = velocity end
        --else
        pga = acceleration
        pgv = velocity
        pgaI = 3.17 * math.log(pga, 10) + 6.59
        pgvI = 3.17 * math.log(pgv, 10) + 9.77
        if pgaI >= 6.0 and pgvI >= 6.0 then
            i = pgvI
        elseif pgaI < 6.0 or pgvI < 6.0 then
            i = (pgaI + pgvI) / 2
        end
        if i < 1.0 then
            i = 1.0
        elseif i > 12.0 then
            i = 12.0
        end
        intensity = GetRealIntensity(i)
        if intensity >= 5 then
            local count3 = 0
            setGpio10Fnc(1)
            sys.taskInit(solenoidValveOperationTask)
            sys.taskInit(alarmToneControlTask)
            local imei = misc.getImei()
            local topic = "gas/local/"..tostring(misc.getImei())
            local sendMsg ="{".."\"value\":"..tostring(intensity)..",".."\"sysTime\":"..os.time().."}"
            local mqttc = mqtt.client(imei,240,"admin","keson-123",nil,{qos=0,retain=0,topic=
            "gas/offline/"..tostring(imei),payload="{}"},"3.1")
            if mqttc:connect("47.94.80.3",1883,"tcp") then
                mqttc:publish(topic, sendMsg, 0)
            end
            mqttc:disconnect()
        else
            setGpio10Fnc(0)
        end
        --end
        count1 = count1 + 1
    end
    count = count + 1
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
--报警音串口信息发送
function alarmToneControlTask()
    local setGpio9Fnc = pins.setup(pio.P0_9,1)--静音设置（高电平静音）
    setGpio9Fnc(0)
    uartTask.write(0x0C)
    sys.wait(12000)
    setGpio9Fnc(1)   
end
-- 获取地震烈度
function GetRealIntensity(instrumentIntensity)
    if 0 < instrumentIntensity and instrumentIntensity < 1.5 then
        intensity = 1
    elseif 1.5 <= instrumentIntensity and instrumentIntensity < 2.5 then
        intensity = 2
    elseif 2.5 <= instrumentIntensity and instrumentIntensity < 3.5 then
        intensity = 3
    elseif 3.5 <= instrumentIntensity and instrumentIntensity < 4.5 then
        intensity = 4
    elseif 4.5 <= instrumentIntensity and instrumentIntensity < 5.5 then
        intensity = 5
    elseif 5.5 <= instrumentIntensity and instrumentIntensity < 6.5 then
        intensity = 6
    elseif 6.5 <= instrumentIntensity and instrumentIntensity < 7.5 then
        intensity = 7
    elseif 7.5 <= instrumentIntensity and instrumentIntensity < 8.5 then
        intensity = 8
    elseif 8.5 <= instrumentIntensity and instrumentIntensity < 9.5 then
        intensity = 9
    elseif 9.5 <= instrumentIntensity and instrumentIntensity < 10.5 then
        intensity = 10
    elseif 10.5 <= instrumentIntensity and instrumentIntensity < 11.5 then
        intensity = 11
    elseif 11.5 <= instrumentIntensity then
        intensity = 12
    end
    return intensity;
end
