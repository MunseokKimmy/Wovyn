ruleset temperature_store {
    meta {
        shares __testing, temperatures, threshold_violations, inrange_temperatures
        provides temperatures, threshold_violations, inrange_temperatures
    }
    global {
        __testing = { "queries": [ { "name": "__testing" } ],
                      "events": [ { "domain": "post", "type": "test",
                                  "attrs": [ "temp", "baro" ] } ] }
        temperatures = function() {
            ent:collected_temperatures;
        }
        threshold_violations = function() {
            ent:collected_violations;
        }
        inrange_temperatures = function() {
            ent:collected_temperatures.difference(ent:collected_violations);
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
            ent:collected_temperatures := ent:collected_temperatures.append(a) || [ent:collect_temperatures]
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
            ent:collected_violations := ent:collected_violations.append(a)
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
    
}