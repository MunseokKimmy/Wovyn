ruleset wovyn_base {
    meta {
        use module org.twilio.sdk alias sdk
        with 
            accountSID = meta:rulesetConfig{"account_sid"}
            authToken = meta:rulesetConfig{"auth_token"}
        shares __testing
    }
    global {
        __testing = { "queries": [ { "name": "__testing" } ],
                      "events": [ { "domain": "post", "type": "test",
                                  "attrs": [ "temp", "baro" ] } ] }
        temperature_threshold = 80
        myPhone = "+14433590071"
        myTwilio = "+14435966495"
      }

    rule process_heartbeat {
        select when wovyn heartbeat
        pre {
          genericThing = event:attr("genericThing") => event:attrs.klog("attrs") | none
        }
        fired {
            raise wovyn event "new_temperature_reading"
            attributes {
                "temperature": event:attr("genericThing").get(["data","temperature"]).head().get(["temperatureF"]),
                "timestamp": event:time
            }
        }
    }
    rule find_high_temps {
        select when wovyn new_temperature_reading
        pre {
            temperature = event:attr("temperature").klog("attrs")
            temperature_threshold = temperature_threshold.klog("threshold")
        }
        fired {
            raise wovyn event "threshold_violation"
            attributes {
                "temperature": event:attr("temperature"),
                "timestamp": event:attr("timestamp")
            } if temperature > temperature_threshold
        }
    }
    rule threshold_notification {
        select when wovyn threshold_violation 
        pre {
            temperatire = event:attr("temperature").klog("attrs")
        }
            sdk:sendSMS("Temperature violation",
            myTwilio,
            )
        
    }
    
}