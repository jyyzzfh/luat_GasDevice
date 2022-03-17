module(..., package.seeall)  --使得文件中的函数在何处都可调用
require "pins"
require "rtos"
require "uartTask"
require"mqtt"
require "misc"
require "sys"
function gpioIntFnc(msg)
    local setGpio10Fnc = pins.setup(pio.P0_10,0)--煤气泄露报警端口设为低电平
    local setGpio9Fnc = pins.setup(pio.P0_9,1)--静音设置（高电平静音）
    local setGpio23Fnc = pins.setup(pio.P0_23,0)--煤气阀门控制端口设为低电平
    log.info("testGpioSingle.gpio18IntFnc",msg,getGpio18Fnc())
    if msg==cpu.INT_GPIO_NEGEDGE then
        log.info(">>>>>>>>>>>gasLeakageAlarm<<<<<<<<<<<<<<<<<")
        local count =0
        setGpio9Fnc(0)
        setGpio10Fnc(1)
        while count ~= 3 do
            setGpio23Fnc(1)
            count = count +1
            rtos.sleep(500)
            setGpio23Fnc(0)
        end
        sys.taskInit(mqttSendTask)
        uartTask.write(0x0C)
        setGpio23Fnc(1)
        rtos.sleep(12000)
        setGpio9Fnc(1)
    else
        setGpio10Fnc(0)
    end
end
function mqttSendTask()
    local topic = "gas/gas/"..tostring(misc.getImei())
    local sendMsg ="{".."value:5"..",".."sysTime:"..os.time().."}"
    local imei = misc.getImei()
    local mqttc = mqtt.client(imei,240,"admin","keson-123",nil,{qos=0,retain=0,topic=
    "gas/offline/"..tostring(imei),payload="{}"},"3.1")
    if mqttc:connect("47.94.80.3",1883,"tcp") then
        mqttc:publish(topic, sendMsg, 0)
    end
    mqttc:disconnect()
end
--下降沿中断时：msg为cpu.INT_GPIO_POSEDGE；下降沿中断时：msg为cpu.INT_GPIO_NEGEDGE
getGpio18Fnc = pins.setup(pio.P0_18,gpioIntFnc)
