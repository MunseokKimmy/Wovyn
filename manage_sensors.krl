ruleset manage_sensors {
    meta {
        shares nameFromID, showChildren, sensors, infoFromSubs, all_temperatures
        provides nameFromID, showChildren, sensors, infoFromSubs
        use module io.picolabs.wrangler alias wrangler
        use module io.picolabs.subscription alias subscription
        use module org.twilio.sdk alias sdk
        with 
            accountSID = meta:rulesetConfig{"account_sid"}
            authToken = meta:rulesetConfig{"auth_token"}
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
        infoFromSubs = function() {
          ent:subs
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
        wellKnown_Rx = function(name) {
          eci = ent:sensors{[name,"eci"]}
          eci.isnull() => null
            | ctx:query(eci,"io.picolabs.subscription","wellKnown_Rx"){"id"}
        }
        myPhone = "+14433590071"
        myTwilio = "+14435966495"
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
        ent:subs := {}
        ent:all_temperatures := {}
      }
    }
    rule store_new_sensor {
        select when wrangler new_child_created
        foreach ["temperature_store", "sensor_profile", "io.picolabs.wovyn.emitter", "wovyn_subscription", "wovyn_base"] setting (x) 
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
                "wellKnown_Rx": "ckzz0zzoc015hx0u0bdylgwr3",
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

    rule message {
      select when wovyn threshold_violation
      pre {
        temperature = event:attr("temperature").klog("attrs")
      }
        sdk:sendSMS("Temperature violation " + temperature,
        myTwilio, //myPhone
        )

    }
    /* Our rule that reacts to a new subscription being added and records it in an entity variable */
    rule newSubAdded {
      select when wrangler subscription_added
      pre {
        subID = event:attr("Id").klog(event:attrs)                // The ID of the subscription is given as an attribute
        subInfo = event:attr("bus")             // The relevant subscription info is given in the "bus" attribute
        name = event:attr("name")
      }
      always {
        ent:subs{subID} := {"name": name, "subInfo": subInfo}              // Record the sub info in this ruleset so we can use it
      }
    }

    rule get_all_data {
      select when wovyn get_all_data
      foreach subscription:established() setting (sub)
      pre {
        peerChannel = sub{"Tx"}                                                                       // Get the "Tx" channel to send our query to
        peerHost = (sub{"Tx_host"} || meta:host)  
        temperatures = wrangler:skyQuery(peerChannel, "temperature_store", "temperatures", null, peerHost)  
      }
      always {
        ent:all_temperatures := ent:all_temperatures.defaultsTo([]).append({"Wovyn temperatures": temperatures})
      }
      

    }
}