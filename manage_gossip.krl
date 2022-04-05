ruleset manage_gossip {
  meta {
    use module manage_sensors alias ms
    use module io.picolabs.subscription alias subscription

  }
  global {

  }
  rule initialize_all_sensors {
    select when gossip initialize_all_sensors
    foreach subscription:established() setting (sub)
    pre {
      peerChannel = sub{"Tx"}
      thisChannel = sub{"Rx"}
    }
    event:send(
      {
        "eci": peerChannel,
        "eid": "initialize",
        "domain": "gossip", "type": "initialize_sensor",
      })
  }
  rule reset_all_sensors_trackers {
    select when gossip reset_all_sensors_trackers
    foreach subscription:established() setting (sub)
    pre {
      peerChannel = sub{"Tx"}
      thisChannel = sub{"Rx"}
    }
    event:send(
      {
        "eci": peerChannel,
        "eid": "initialize",
        "domain": "gossip", "type": "reset_smart_tracker",
      })
  }
  rule create_all_sensors_smart_tracker {
    select when gossip create_all_sensors_smart_tracker
    foreach subscription:established() setting (sub)
    pre {
      peerChannel = sub{"Tx"}
      thisChannel = sub{"Rx"}
    }
    event:send(
      {
        "eci": peerChannel,
        "eid": "initialize",
        "domain": "gossip", "type": "create_smart_tracker",
      })
  }
  rule start_gossip_all_sensors {
    select when gossip start_gossip_all_sensors
    foreach subscription:established() setting (sub)
    pre {
      peerChannel = sub{"Tx"}
      thisChannel = sub{"Rx"}
      newPeriod = event:attr("newPeriod")
    }
    event:send(
      {
        "eci": peerChannel,
        "eid": "initialize",
        "domain": "gossip", "type": "start_heartbeat",
        "attrs": {
          "period": newPeriod
        }
      })
  }
  rule stop_gossip_all_sensors {
    select when gossip stop_gossip_all_sensors
    foreach subscription:established() setting (sub)
    pre {
      peerChannel = sub{"Tx"}
      thisChannel = sub{"Rx"}
    }
    event:send(
      {
        "eci": peerChannel,
        "eid": "initialize",
        "domain": "gossip", "type": "stop_heartbeat",
      })
  }
  rule change_gossip_period_all_sensors {
    select when gossip change_gossip_period_all_sensors
    foreach subscription:established() setting (sub)
    pre {
      peerChannel = sub{"Tx"}
      thisChannel = sub{"Rx"}
      newPeriod = event:attr("newPeriod")
    }
    event:send(
      {
        "eci": peerChannel,
        "eid": "initialize",
        "domain": "gossip", "type": "change_gossip_period",
        "attrs": {
          "period": newPeriod
        }
      })
  }
}