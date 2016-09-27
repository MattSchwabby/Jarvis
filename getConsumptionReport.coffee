# Description:
#   Emails the requester a CLC Consumption Report for a specified date range

# Require the edge module we installed
edge = require("edge")

# Build the PowerShell that will execute
executePowerShell = edge.func('ps', -> ###
  # Dot source the function
  . .\scripts\GetConsumptionReport.ps1
  # Edge.js passes an object to PowerShell as a variable - $inputFromJS
  # This object is built in CoffeeScript on line 28 below
  getConsumptionReport -alias $inputFromJS.aliasName -start $inputFromJS.start -end $inputFromJS.end -email $inputFromJS.emailName -reseller $inputFromJS.reseller
###
)

module.exports = (robot) ->
  # Capture the user message using a regex capture to find the name of the service
  robot.respond /consumption (.*) (.*) (.*) (.*) (.*)/i, (msg) ->
    # Set the service name to a varaible
    aliasName = msg.match[1]
    start = msg.match[2]
    end = msg.match[3]
    emailName = msg.match[4]
    reseller = msg.match[5]
    msg.send "Generating a consumption report for the #{aliasName} account between #{start} and #{end} to be e-mailed to: #{emailName}. (Reseller: #{reseller})."
    # Build an object to send to PowerShell
    psObject = {
      aliasName: aliasName
      start: start
      end: end
      emailName: emailName
      reseller: reseller
    }

    # Build the PowerShell callback
    callPowerShell = (psObject, msg) ->
      executePowerShell psObject, (error,result) ->
        # If there are any errors that come from the CoffeeScript command
        if error
          msg.send ":fire: An error was thrown in Node.js/CoffeeScript"
          msg.send error
        else
          # Capture the PowerShell outpout and convert the JSON that the function returned into a CoffeeScript object
          result = JSON.parse result[0]

          # Output the results into the Hubot log file so we can see what happened - useful for troubleshooting
          console.log result

          # Check in our object if the command was a success (checks the JSON returned from PowerShell)
          # If there is a success, prepend a check mark emoji to the output from PowerShell.
          if result.success is true
            # Build a string to send back to the channel and include the output (this comes from the JSON output)
            msg.send ":white_check_mark: #{result.output}"
          # If there is a failure, prepend a warning emoji to the output from PowerShell.
          else
            # Build a string to send back to the channel and include the output (this comes from the JSON output)
            msg.send ":warning: #{result.output}"

    # Call PowerShell function
    callPowerShell psObject, msg