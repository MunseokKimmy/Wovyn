ruleset manage_sensors {
    meta {
        shares nameFromID, showChildren, sensors
        provides nameFromID, showChildren, sensors
        use module io.picolabs.wrangler alias wrangler
    }
    global {
        nameFromID = function(name) {
            "Sensor " + name + " Pico"
        }
        showChildren = function() {
          wrangler:children()
        }
        sensors = function() {
          ent:sensors
        }
        all_temperatures = function() {
          ent:all_temperatures
        }
        threshold_default = 77
        eventPolicy = {
          "allow": [ { "domain": "*", "name": "*" }, ],
          "deny": []
        }
        queryPolicy = {
          "allow": [ { "rid": "*", "name": "*" } ],
          "deny": []
        }
    }
    rule sensor_already_exists {
        select when sensor new_sensor
        pre {
          sensor_name = event:attr("name")
          exists = ent:sensors && ent:sensors >< sensor_name
        }
        if exists then
          send_directive("sensor_ready", {"name":sensor_name})
      }
    rule sensor_does_not_exist {
        select when sensor new_sensor
        pre {
            sensor_name = event:attr("name")
            exists = ent:sensors && ent:sensors >< sensor_name
        }
        if not exists then noop()
        fired {
          raise wrangler event "new_child_request"
            attributes { "name": sensor_name,
                         "backgroundColor": "#ff69b4",}
        }
    }
    rule initialize_sensors {
      select when sensor needs_initialization
      always {
        ent:sensors := {}
      }
    }
    rule store_new_sensor {
        select when wrangler new_child_created
        foreach ["temperature_store", "sensor_profile", "wovyn_base", "io.picolabs.wovyn.emitter"] setting (x) 
        pre {
          the_sensor = {"eci": event:attr("eci")}
          sensor_name = event:attr("name")
        }
        if sensor_name.klog("found sensor")
          then event:send(
            { "eci": the_sensor.get("eci"), 
              "eid": "install-ruleset", // can be anything, used for correlation
              "domain": "wrangler", "type": "install_ruleset_request",
              "attrs": {
                "absoluteURL": meta:rulesetURI,
                "rid": x,
                "config": {},
                "sensor_name": sensor_name
              }
            }
          )
        fired {
          ent:sensors{sensor_name} := the_sensor
        }
    }
    rule update_sensor_profile {
      select when wrangler new_child_created
      pre {
        the_sensor = {"eci": event:attr("eci")}
        sensor_name = event:attr("name")
      }
      if sensor_name.klog("found sensor for sending event")
        then event:send(
          { "eci": the_sensor.get("eci"), 
            "eid": "set_profile", // can be anything, used for correlation
            "domain": "sensor", "type": "profile_updated",
            "attrs": {
              "location": "Munseok's Kitchen",
              "name": "New Phone who dis",
              "threshold": threshold_default,
              "number": 4433590071
            }
          }
        )
      fired {
        ent:sensors{sensor_name} := the_sensor
      }
    }
    rule delete_sensor {
      select when sensor unneeded_sensor 
      pre {
        sensor_id = event:attr("sensor_id")
        exists = ent:sensors >< sensor_id
        eci_to_delete = ent:sensors{[sensor_id,"eci"]}
      }
      if exists && eci_to_delete then
        send_directive("deleting_sensor", {"sensor_id":sensor_id})
      fired {
        raise wrangler event "child_deletion_request"
          attributes {"eci": eci_to_delete};
        clear ent:sensors{sensor_id}
      }
    }
    rule all_temperatures {
      select when sensor all_temperatures
      foreach ent:sensors setting(x)
      pre {

      }
    }
}