ruleset org.twilio.sdk {
    meta {
        configure using
        accountSID = ""
        authToken = ""
      provides messages, sendSMS
    }
    global {
        base_url = "https://api.twilio.com/2010-04-01/"
        messages = function(pageSize, fromNumber, toNumber) {
            size = (pageSize => "PageSize=" + pageSize | "")
            _from = (fromNumber => "&From=%2B1" + fromNumber | "")
            _to = (toNumber => "&To=%2B1" + toNumber | "")

            response = http:get(<<#{base_url}/Accounts/#{accountSID}/Messages.json?#{size}#{_from}#{_to}>>, auth = {"username" : accountSID, "password" : authToken})
            response{"content"}.decode()
        }
        sendSMS = defaction(message, fromNumber, toNumber) {
             body = {"Body":message, "From":fromNumber, "To":toNumber}
             http:post(<<#{base_url}/Accounts/#{accountSID}/Messages.json>>, 
                auth = {"username" : accountSID, "password" : authToken}, form=body) setting(response)
             return response.klog()
         }
    }
  }