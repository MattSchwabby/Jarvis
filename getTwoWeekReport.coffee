# Description:
#   Emails the requester a two week CenturyLink Cloud utilization report for a given account alias
#
# Commands:
#   *@jarvis utilization report <alias> <email>* - Emails the requester a two week CenturyLink Cloud utilization report for a given account alias - rolls up all sub accounts (does not include machines that are powered off or templates).

# Require the edge module we installed
edge = require("edge")

# Build the PowerShell that will execute
executePowerShell = edge.func('ps', -> ###
  # Dot source the function
  . .\scripts\GetTwoWeekReport.ps1
  # Edge.js passes an object to PowerShell as a variable - $inputFromJS
  # This object is built in CoffeeScript on line 28 below
  getTwoWeekReport -alias $inputFromJS.alias -email $inputFromJS.email
###
)

module.exports = (robot) ->
  # Capture the account alias being requested
  robot.respond /utilization report (.*) (.*)/i, (msg) ->
    # Set the requested alias to a variable
    alias = msg.match[1]
    email = msg.match[2]
    msg.send "Sending a two week utilization report for the #{alias} account to #{email}. This will take several minutes or longer, depending on the amount of sub accounts and assets in the account."
    # Build an object to send to PowerShell
    psObject = {
      alias: alias
      email: email
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