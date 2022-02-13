ruleset sensor_profile {
    meta {
        shares __testing, temperatures, threshold_violations, inrange_temperatures
        provides temperatures, threshold_violations, inrange_temperatures
    }
    global {
        __testing = { "queries": [ { "name": "__testing" } ],
                      "events": [ { "domain": "post", "type": "test",
                                  "attrs": [ "temp", "baro" ] } ] }
        sensor_profile = function() {
            ent:sensor_profile.defaultsTo({"location": "Munseok's Apartment", "name": "temp sensor", "threshold": 80, "number": "+14433590071"});
        }
    }

    rule sensor_profile_updated {
        select when sensor profile_updated
        pre {
            location = event:attr("location").klog("loc:")
            name = event:attr("name").klog("name:")
            tempThreshold = event:attr("threshold")
            number = event:attr("number")
        }
        always {
            ent:sensor_profile := {"location": location, "name": name, "threshold": tempThreshold, "number": number};
        }
    }

}