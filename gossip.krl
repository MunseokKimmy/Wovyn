ruleset gossip {
  meta {
    use module temperature_store alias ts
    use module sensor_profile alias sp
    use module io.picolabs.subscription alias subscription
    use module io.picolabs.wrangler alias wrangler

    shares smart_tracker, scheduled, lastReading, data, name, sequenceNumber, state, ids, getMessage,sumNodeInfo, getNodeInNeed, getIdKeys, 
    chooseMessageRandomly, mostRecentReading, test, violationState, violationSum, violationReport, checkForViolation, getNewViolationState,getMostRecentStatus
    provides smart_tracker, scheduled, lastReading, data, name, sequenceNumber, state, ids, getMessage,sumNodeInfo, getNodeInNeed, getIdKeys, 
    chooseMessageRandomly, mostRecentReading, test, violationState, violationSum, violationReport, checkForViolation, getNewViolationState,getMostRecentStatus
  }
  global {
    smart_tracker = function() {
      ent:smart_tracker.defaultsTo({});
    }
    scheduled = function() {
      schedule:list().defaultsTo("No scheduled events")
    }
    lastReading = function() {
      ent:lastReading.defaultsTo("No readings");
    }
    data = function() {
      ent:data.defaultsTo({});
    }
    name = function() {
      ent:name.defaultsTo("Name not set")
    }
    sequenceNumber = function() {
      ent:sequenceNumber.defaultsTo("Number not set")
    }
    state = function() {
      ent:state
    }
    ids = function() {
      ent:ids
    }
    checkState = function(name) {
      ent:state{name}
    }
    splitMessageID = function(messageID) {
      messageID.split(re#:#)
    }
    mostRecentReading = function() {
      ent:name + ":" + (ent:sequenceNumber-1)
    }
    getMessage = function(id, lower, upper) {
      messageIDsToSend = [];
      lowerBound = lower + 1;
      messageRange = lowerBound.range(upper)
      c = messageRange.map(function(x) {id + ":" + x.as("String")})
      c
    }
    getNodeInNeed = function(){
       keys = ent:smart_tracker.keys()
       sums = keys.map(function(x){sumNodeInfo(x)})
       lowestSum = sums.sort("numeric").head()
       index = sums.index(lowestSum)
       nodeInNeed = index > -1 && (keys.length() == ent:ids.length()) => keys[index] | getIdKeys(keys.length())
       nodeInNeed
    }
    test = function() {
      keys = ent:smart_tracker.keys()
      sums = keys.map(function(x){sumNodeInfo(x)})
      lowestSum = sums.sort()
      sums
    }
    sumNodeInfo = function(name) {
      values = ent:smart_tracker{name}.values()
      sum = values.reduce(function(a, i){a + i})
      sum
    }
    getIdKeys = function(index) {
      idKeys = ent:ids.keys()
      idKeys[index]
    }
    chooseMessageRandomly = function() {
      random = random:integer(lower = 0, upper = 1)
      messageType = random == 0 => "Rumor" | "Seen"
      messageType
    }

    violationState = function() {
      ent:violationState.defaultsTo({});
    }

    violationSum = function() {
      values = ent:violationState.values()
      sum = values.reduce(function(a, i){a + i})
      sum
    }

    violationReport = function() {
      violationSum()
    }

    checkForViolation = function() {
      violation = sp:sensor_profile(){"threshold"} <= lastReading()
      violation 
    }

    getMostRecentStatus = function() {
      ent:recentStatus
      //false = not experiencing, true = experiencing
    }

    getNewViolationState = function() {
      currentViolation = checkForViolation() 
      //true if they are matching/ false if they are not matching
      matching = getMostRecentStatus() == currentViolation
      newState = matching => 0 | notMatching(currentViolation)
      newState
    }

    notMatching = function(currentViolation) {
      newState = currentViolation => 1 | -1
      newState
    }


  }
  rule initialize_sensor {
    select when gossip initialize_sensor
    pre {
    }
    always {
      ent:smart_tracker := {}
      ent:data := {}
      ent:name := random:word()
      ent:sequenceNumber := 1
      ent:state := {}
      ent:lastReading := null
      raise gossip event "stop_heartbeat"
      raise gossip event "get_last_reading"
    }
  }
  rule start_heartbeat {
    select when gossip start_heartbeat
    pre {
      period = event:attr("period")
    }
    always {
      schedule gossip event "gossip_heartbeat" 
            repeat << */#{period} * * * * * >> attributes { }
    }
  }
  rule stop_heartbeat {
    select when gossip stop_heartbeat
    pre {
      scheduledEvent = scheduled()[0]
    }
    if scheduledEvent then 
      schedule:remove(scheduledEvent{"id"})
    
    fired {

    }
  }
  rule change_gossip_period {
    select when gossip change_gossip_period
    pre {
      newPeriod = event:attr("newPeriod")
      scheduledEvent = scheduled()[0]
    }
    if scheduledEvent then noop()
    fired {
      raise gossip event "stop_heartbeat"
      raise gossip event "start_heartbeat"
        attributes {"period": newPeriod}
    }
  }
  rule gossip_heartbeat {
    select when gossip gossip_heartbeat
    pre {
      nodeInNeed = getNodeInNeed()
      peerChannel = ent:ids{nodeInNeed}.get("channelId").as("String")
      m = chooseMessageRandomly().klog("Node in need " + nodeInNeed) //prep message
    }
    if m == "Rumor" then noop()
    fired { //send your own rumor data
      raise gossip event "get_own_sensor_data"
      raise gossip event "get_last_reading"
      raise gossip event "send_rumor"
      attributes { 
        "eci": peerChannel,
        "messagesToSend": [mostRecentReading()],
        "messageFrom": nodeInNeed
      }
      raise gossip event "prepare_violation_rumor"
      attributes {
        "eci": peerChannel
      }
    }
    else { //send a seen message
      raise gossip event "send_seen"
      attributes {
        "eci": peerChannel
      }
    }
  }
  rule get_own_sensor_data {
    select when gossip get_own_sensor_data
    pre {
      name = ent:name
      data = ent:data
      sequenceNumber = ent:sequenceNumber.defaultsTo(1)
      messageID = name + ":" + sequenceNumber
    }
    always {
      newData = {"MessageID": messageID, "SensorID": name, "Temperature": ent:lastReading, "TimeStamp": event:time}
      ent:data{messageID} := newData
      ent:sequenceNumber := sequenceNumber + 1
      ent:state{name} := sequenceNumber
    }
  }
  rule get_last_reading {
    select when gossip get_last_reading
    pre {
      lastReading = ts:lastTemperature(){"temperature"}
    }
    always {
      ent:lastReading := lastReading

    }
  }
  rule create_smart_tracker {
    select when gossip create_smart_tracker
    foreach subscription:established() setting (sub)
    pre {
      rx_role = sub{"Rx_role"}
      peerChannel = sub{"Tx"}
      peerHost = (sub{"Tx_host"} || meta:host)  
      tx_role = sub{"Tx_role"}
      name = wrangler:skyQuery(peerChannel, "gossip", "name", null, peerHost)
    }
    if rx_role == "node" && tx_role == "node"
    then noop()
    fired {
      ent:ids{name} := {"channelId": peerChannel}
    }
  }
  rule reset_smart_tracker {
    select when gossip reset_smart_tracker
    fired {
      ent:smart_tracker := {}
      ent:data := {}
      ent:state := {}
      ent:ids := {}
      ent:violationState := {}
      ent:violationState{ent:name} := 0
      ent:recentStatus := false
      ent:violationReport := 0
      ent:sequenceNumber := 1
      raise gossip event "get_own_sensor_data"
    }
  }

  /*
  Rumor Message:
  {
    "MessageID": table:1,
    "SensorID": table:1,
    "Temperature": 71,
    "TimeStamp": 214123423,
  }
  */
  rule gossip_rumor {
    select when gossip rumor
    pre {
      messageID = event:attr("message").get("MessageID")
      messageParts = splitMessageID(messageID)
      state = ent:state{messageParts[0]}.defaultsTo(0)
    }
    if state < messageParts[1] then noop()
    fired {
      ent:data{messageID} := event:attr("message")
      raise gossip event "check_for_store"
      attributes {
        "message": event:attr("message"),
        "messageParts": messageParts,
        "state": state.as("Number")
      }
    }
  }

  rule prepare_violation_rumor {
    select when gossip prepare_violation_rumor
    pre {
      peerChannel = event:attr("eci")
      newViolationState = getNewViolationState()
    }
    always {
      ent:violationState{ent:name} := newViolationState
      ent:recentStatus := newViolationState > 0 => newViolationState == 1 | newViolationState == -1
      raise gossip event "send_violation_rumor"
      attributes {
        "eci": peerChannel,
      }
    }
  }

  rule send_violation_rumor {
    select when gossip send_violation_rumor
    pre {
      stateToSend = ent:violationState
      peerChannel = event:attr("eci")
    }
    event:send(
      {
        "eci": peerChannel,
        "eid": "rumor",
        "domain": "gossip", "type": "violation_rumor",
        "attrs": {
          "state": stateToSend
        }
      }
    )
  }
  rule gossip_violation_rumor {
    select when gossip violation_rumor
    pre {
      sentState = event:attr("state")
    }
    always {
      raise gossip event "check_violation_state"
      attributes {
        "state": sentState
      }
    }
  }


  rule check_violation_state {
    select when gossip check_violation_state
    foreach event:attr("state").keys() setting (key)
    pre {
      newValue = event:attr("state"){key}
      currentValue = ent:violationState{key}
    }
    if currentValue != null || newValue != currentValue then noop()
    fired {
      ent:violationState{key} := newValue
      ent:violationReport := violationSum()
    }
  }
  rule gossip_seen {
    select when gossip seen
    pre {
      messageFrom = event:attr("from")
      message = event:attr("message")
    }
    fired {
      raise gossip event "check_seen"
      attributes {
        "message": message,
        "messageFrom": messageFrom,
      }
      ent:smart_tracker{messageFrom} := message
    }
  }
  // Seen Message:
  // {"opinion": 1,
  // "mass": 1 }
  // Stored:
  // {"opinion": 1, 
  // "mass": 1}
  rule check_seen_empty {
    select when gossip check_empty
    pre {
      messageFrom = event:attr("messageFrom")
      message = event:attr("message")
    }
    if message == {} then noop()
    fired {
      raise gossip event "send_all_data"
    }
    else {
      raise gossip event "check_seen"
      attributes {
        "message": message,
        "messageFrom": messageFrom,
      }
    }
  }
  rule gossip_check_seen {
    select when gossip check_seen
    foreach event:attr("message").keys() setting(key)
    pre {
      messageFrom = event:attr("messageFrom")
      peerChannel = ent:ids{messageFrom}.get("channelId").as("String")
      message = event:attr("message")
      storedSequenceNumber = ent:state{key}.as("Number").defaultsTo(0)
      seenSequenceNumber = message{key}.as("Number").defaultsTo(0).klog(storedSequenceNumber)
      
    }
    if (ent:name != messageFrom) && (storedSequenceNumber < seenSequenceNumber) then noop() //We have outdated data
    fired { //send them a seen message
      ent:state{key} := storedSequenceNumber
      ent:smart_tracker{messageFrom} := message
      raise gossip event "send_seen"
      attributes {
        "eci": peerChannel
      }
    }
    else { //Either the data matches or they have outdated data
      raise gossip event "send_rumor"
      attributes { 
        "eci": peerChannel,
        "messagesToSend": getMessage(key, seenSequenceNumber, storedSequenceNumber),
        "messageFrom": messageFrom
      } if (storedSequenceNumber > seenSequenceNumber) //don't send if they match
    }
  }

  rule gossip_send_rumors {
    select when gossip send_rumor
    foreach event:attr("messagesToSend") setting(messageKey)
    pre {
      peerChannel = event:attr("eci").klog("Message ID is " + messageKey)
      rumor = ent:data{messageKey}
      messageParts = splitMessageID(messageKey)
      messageFrom = event:attr("messageFrom").klog("Rumor message is " + rumor)
    } 
    event:send(
      {
        "eci": peerChannel,
        "eid": "rumor",
        "domain": "gossip", "type": "rumor",
        "attrs": {
          "message": rumor
        }
      }
    )
    fired {
      raise gossip event "enter_smart_tracker"
      attributes {
        "messageTo": messageFrom,
        "messageName": messageParts[0],
        "messageNumber": messageParts[1]
      }
    }
  }

  rule put_in_smart_tracker {
    select when gossip enter_smart_tracker
    pre {
      messageTo = event:attr("messageTo")
      messageName = event:attr("messageName")
      messageNumber = event:attr("messageNumber")
    }
    if messageTo != ent:name then noop()
    fired {
      ent:smart_tracker{[messageTo, messageName]} := messageNumber.as("Number")
    }
  }

  rule gossip_send_seen {
    select when gossip send_seen
    pre {
      peerChannel = event:attr("eci")
      seenMessage = ent:state
    }
    event:send(
      {
        "eci": peerChannel,
        "eid": "seenChannel",
        "domain": "gossip", "type": "seen",
        "attrs": {
          "message": seenMessage,
          "from": ent:name
        }
      }
    )
  }
    /*
  Rumor Message:
  {
    "MessageID": table:1,
    "SensorID": table:1,
    "Temperature": 71,
    "TimeStamp": 214123423,
  }
  */
  rule check_for_store {
    select when gossip check_for_store
    pre {
      messageParts = event:attr("messageParts")
      newMessage = messageParts[1].as("Number")
      state = event:attr("state").klog("New Message # is " + newMessage)
    }
    if newMessage == (state + 1) then noop()
    fired {
      ent:state{messageParts[0]} := messageParts[1].as("Number")
    }
  }
  rule test_rumor {
    select when gossip test_rumor
    pre {
      messageID = event:attr("messageID")
      sensorID = event:attr("messageID")
      temperature = event:attr("temp")
      timestamp = event:time
    }
    fired {
      raise gossip event "rumor"
      attributes {
        "message": {"MessageID": messageID, "SensorID": sensorID, "Temperature": temperature, "TimeStamp": timestamp}
      }
    }
  }
  rule test_seen {
    select when gossip test_seen
    pre {
      sequenceNumber1 = event:attr("forest")
      sequenceNumber2 = event:attr("mass")
      sequenceNumber3 = event:attr("opinion")
      from = event:attr("from")
      message = {"forest": sequenceNumber1, "mass": sequenceNumber2, "opinion":sequenceNumber3}
    }
    fired {
      raise gossip event "seen"
      attributes {
        "message": message,
        "from": from
      }
    }
  }

}