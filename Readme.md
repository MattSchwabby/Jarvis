# Jarvis

Code repository for Slack bot functionality that facilitates CenturyLink Cloud customer reporting.

Author: Matt Schwabenbauer

Date: September 27, 2016

Matt.Schwabenbauer@ctl.io

### About this repository

This repository was created to give CenturyLink personnel the ability to quickly access account data for a given customer account alias.

For any given piece of functionality there are two files, a PowerShell script and a CofeeScript file. Any interaction with the CenturyLink Cloud APIs or parsing of data is done in a PowerShell script that is called by a CoffeeScript file, which also contains the parameters to trigger any functionality from the Hubot listener.

### Deploying Jarvis

This respository is meant to be synced with the local script repository of a PoshHubot instance that has already been deployed. Instructions for deploying a PoshHubot instance can be found here: https://github.com/MattHodge/PoshHubot. I recommend removing every external script from the external-scripts.json file that will be created during the Hubot installation, with the exception of the entry for "hubot-help".

There is a known issue where the CoffeeScript commands become unable to execute PowerShell commands after a long period of time. This can be worked around by creating a service for Jarvis using NSSM (https://nssm.cc/). A service with administrator privileges that calls Start-Hubot will ensure the service is always available for the user.

Each of the scripts and modules included in the PoshHubot PowerShell module will need to be unblocked on the system running the Jarvis Hubot. I recommend unblocking the entire directory using the Unblock-Item PowerShell command.

Future plan: Eventually create automation to provision an instance of Jarvis, or create a fork of the PoshHubot repository with the Jarvis functionality included.

### Current Deployment

Jarvis's instance for the CenturyLink Cloud Slack Workspace (cl-cloud.slack.com) is hosted on UC1MSCHJARVIS01. This slack workspace is on the Standard Slack plan.

Jarvis's instance for the CTL Slack workspace (ctl-connected.slack.com)is hosted on UC1MSCHJARCTL03. This slack workspace is on the Free Slack plan.

These machines are Windows Server VMs and their IP Addresses and login credentials can be found on control.ctl.io
The scripts to Start and Restart Jarvis can be found on the Desktop of the respective machines. 

VPN Requirements:

To access these servers, a VPN connection to UC1 is required. To connect to a Windows server hosting Jarvis, find out its IP address from control.
Then on your local machine add a route to for the Windows server like this:

$ sudo route add <subnet-windows-machine> <tunnel IP>

e.g. if the Windows server IP is 10.140.141.33, and the tunnel IP is 10.255.124.11, the command will be:

$ sudo route add 10.140.141.0/24 10.255.124.11


### Authentication

The beginning of each script calls two login functions for the CenturyLink Cloud APIs. I have not included those functions here for security reasons. Replacement functionality could be easily created by reviewing the CenturyLink Cloud API docs here: https://www.ctl.io/api-docs/v2/.

Your SMTP Relay alias will be specified in the individual PowerShell scripts that call for it. I have also secured my SMTP relay password via a PowerShell function, but that can be directly replaced with a string or object containing your password.

The functions for authentication are defined in a PowerShell module under C:\Windows\System32\WindowsPowerShell\v1.0\Modules\loginCLCAPI\loginCLCAPI.psm1
This module defines functions to authenticate to V1 and V2 control APIs.

The credentials for both V1 and V2 are encoded using a standard PowerShell module ConvertTo-SecureString (https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.security/convertto-securestring?view=powershell-6)
The encoded credentials are stored in a JSON file at C:\Users\Administrator\JK\config.json


### Support

This code is presented as is and is open to contribution from the community.

Feature requests and enhancements can be suggested to Matt.Schwabenbauer@ctl.io. Any future development is not guaranteed.