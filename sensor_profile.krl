ruleset sensor_profile {
    meta {
        shares __testing, sensor_profile
        provides sensor_profile
    }
    global {
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