ruleset temperature_store {
    meta {
        shares __testing, temperatures, threshold_violations, inrange_temperatures, lastTemperature
        provides temperatures, threshold_violations, inrange_temperatures, lastTemperature
    }
    global {
        temperatures = function() {
            ent:collected_temperatures.defaultsTo([]);
        }
        threshold_violations = function() {
            ent:collected_violations.defaultsTo([]);
        }
        inrange_temperatures = function() {
            ent:collected_temperatures.difference(ent:collected_violations);
        }
        lastTemperature = function() {
            ent:collected_temperatures.defaultsTo([])[ent:collected_temperatures.length() - 1]
        }
    }
    rule collect_temperatures {
        select when wovyn new_temperature_reading
        pre {
            temperature = event:attr("temperature").klog("attrs")
            timestamp = event:attr("timestamp").klog("attrs")
        }
        always {
            a = {"temperature": temperature, "timestamp": timestamp}
            ent:collected_temperatures := ent:collected_temperatures.defaultsTo([]).append(a) || [ent:collect_temperatures]
        }
    }
    rule collect_threshold_violations {
        select when wovyn threshold_violation
        pre {
            temperature = event:attr("temperature").klog("temp:")
            timestamp = event:attr("timestamp").klog("temp:")
        }
        always {
            a = {"temperature": temperature, "timestamp": timestamp}
            ent:collected_violations := ent:collected_violations.defaultsTo([]).append(a)
        }
    }
    rule clear_temperatures {
        select when sensor reading_reset 
        pre {
            
        }
        always {
            clear ent:collected_violations
            clear ent:collected_temperatures
        }
    }

    rule create_report {
        select when sensor get_report
        pre {
            correlationID = event:attr("id")
            managerChannel = event:attr("managerCI")
            the_sensor = event:attr("sensorCI")
            lastTemperatureReading = temperatures()[temperatures().length() - 1]
        }
        if (not correlationID.isnull())
            then event:send(
                {   "eci": managerChannel,
                    "eid": "create report",
                    "domain": "reports", "type": "sensor_report",
                    "attrs": {
                        "data": lastTemperatureReading, 
                        "correlationID": correlationID,
                        "sensor": the_sensor,
                    }
                })
        fired {

        }
    }

    
}