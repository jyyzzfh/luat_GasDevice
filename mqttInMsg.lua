--- 模块功能：MQTT客户端数据接收处理
-- @author openLuat
-- @module mqtt.mqttInMsg
-- @license MIT
-- @copyright openLuat
-- @release 2018.03.28

module(...,package.seeall)
require "earthquakeWaring"
require "getLbsLoc"
require "mqttOutMsg"
--- MQTT客户端数据接收处理
-- @param mqttClient，MQTT客户端对象
-- @return 处理成功返回true，处理出错返回false
-- @usage mqttInMsg.proc(mqttClient)
function proc(mqttClient)
    local result,data
    while true do
        result,data = mqttClient:receive(60000,"APP_SOCKET_SEND_DATA")
        log.info(",qttInMsg")
        --接收到数据
        if result then
            log.info("mqttInMsg.proc",data.topic,data.payload)
            if data.topic =="gas/check" then
                local topic = "gas/online/"..misc.getImei()
                local sendMsg ="{".."longitude:"..tostring(getLbsLoc.Lng)..",".."latitude:"..
                tostring(getLbsLoc.Lat)..",".."sysTime:"..os.time().."}"
                mqttClient:publish(topic,sendMsg,0)
            end
            if not earthquakeWaring.EarthquakeWarning(data.payload) then
                log.error("earthquakeWarning error")
            end
        else
            break
        end
    end
	
    return result or data=="timeout" or data=="APP_SOCKET_SEND_DATA"
end
