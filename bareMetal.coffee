# Description:
#   Bare Metal Availability -  Returns the available Bare Metal SKUs in each data center, as well as the remaining available amounts.
#
# Commands:
#   *@jarvis bare metal* -  Returns the available Bare Metal SKUs in each data center, as well as the remaining available amounts..

# Require the edge module we installed
edge = require("edge")

# Build the PowerShell that will execute
executePowerShell = edge.func('ps', -> ###
  # Dot source the function
  . .\scripts\bareMetalMySQLPROD.ps1
  # Edge.js passes an object to PowerShell as a variable - $inputFromJS
  # This object is built in CoffeeScript on line 28 below
  bareMetal
###
)

module.exports = (robot) ->
  # Capture the account alias being requested
  robot.respond /bare metal/i, (msg) ->
    # Set the requested alias to a variable
    msg.send "Getting the available bare metal SKUs in each data center."
    # Build an object to send to PowerShell
    psObject = {
    }

    # Build the PowerShell callback
    callPowerShell = (psObject, msg) ->
      executePowerShell psObject, (error,result) ->
        # Catch any errors
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