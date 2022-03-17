module(..., package.seeall)  --使得文件中的函数在何处都可调用
require"pins"
require"sys"
function gpioIntFnc(msg)
    log.info("testGpioSingle.gpio10IntFnc",msg,getGpio19Fnc())
    local setGpio11Fnc = pins.setup(pio.P0_11,1)--静音设置（高电平静音）
    if msg==cpu.INT_GPIO_NEGEDGE then
        log.info(">>>>>>>>>>>mute or not gpio0_11<<<<<<<<<<<<<<<<<")
        setGpio11Fnc(0)
    else
        setGpio11Fnc(1)
    end
end
--下降沿中断时：msg为cpu.INT_GPIO_POSEDGE；下降沿中断时：msg为cpu.INT_GPIO_NEGEDGE
getGpio19Fnc = pins.setup(pio.P0_19,gpioIntFnc)
