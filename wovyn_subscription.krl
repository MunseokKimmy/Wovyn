ruleset wovyn_subscription {
    meta {
        use module io.picolabs.subscription alias subs
        use module io.picolabs.wrangler alias wrangler
        shares sensorCollectionWellKnown
    }
    global {
        sensorCollectionWellKnown = function() {
            ent:wellKnown_Rx.defaultsTo("ckzz0zzoc015hx0u0bdylgwr3")
        }
    }
    rule capture_initial_state {
        select when wrangler ruleset_installed
          where event:attr("rids") >< meta:rid
        pre {
          tags = ["sensor"]
          eventPolicy = {"allow": [{"domain": "*", "name": "*"}], "deny": []}
          queryPolicy = {"allow":[{"rid": "*", "name": "*"}], "deny": []}
        }
        if ent:sensor_eci.isnull() then
          wrangler:createChannel(tags, eventPolicy, queryPolicy) setting(channel)
        fired {
          ent:name := event:attr("sensor_name")
          ent:wellKnown_Rx := event:attr("wellKnown_Rx")
          ent:sensor_eci := channel{"id"}
          raise sensor event "new_subscription_request"
        }
    }
    rule make_a_subscription {
        select when sensor new_subscription_request
        event:send({"eci":ent:wellKnown_Rx.defaultsTo("ckzz0zzoc015hx0u0bdylgwr3"),
          "domain":"wrangler", "name":"subscription",
          "attrs": {
            "wellKnown_Tx": subs:wellKnown_Rx(){"id"},
            "Rx_role":"collection", 
            "Tx_role":"sensor",
            "name":ent:name+"-collection", 
            "channel_type":"subscription"
          }
        })
    } 
    rule subscribe_existing_sensor {
        select when sensor subscribe_existing_sensor
        pre {
            sensor_wellKnown = event:attr("wellKnown")
        }
        event:send({"eci":ent:wellKnown_Rx.defaultsTo("ckzz0zzoc015hx0u0bdylgwr3"),
            "domain":"wrangler", "name":"subscription",
            "attrs": {
              "wellKnown_Tx": sensor_wellKnown,
              "Rx_role":"collection", 
              "Tx_role":"sensor",
              "name":ent:name+"-collection", 
              "channel_type":"subscription"
            }
          })
    }
    rule auto_accept_add {
        select when wrangler inbound_pending_subscription_added
          Rx_role re#^sensor$#
          Tx_role re#^collection$#
        pre {
          sensor_name = event:attr("sensor_name")
        }
        if sensor_name then noop()
        fired {
          raise wrangler event "pending_subscription_approval"
            attributes  event:attrs
          last
        }
      }
      rule auto_accept {
        select when wrangler inbound_pending_subscription_added
        pre {
          my_role = event:attr("Rx_role")
          their_role = event:attr("Tx_role")
        }
        if my_role=="sensor" && their_role=="collection" then noop()
        fired {
          raise wrangler event "pending_subscription_approval"
            attributes event:attrs
          ent:subscriptionTx := event:attr("Tx")
        } else {
          raise wrangler event "inbound_rejection"
            attributes event:attrs
        }
    }
}