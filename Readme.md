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

I plan to eventually create automation to provision an instance of Jarvis, or create a fork of the PoshHubot repository with the Jarvis functionality included.

### Authentication

The beginning of each script calls two login functions for the CenturyLink Cloud APIs. I have not included those functions here for security reasons. Replacement functionality could be easily created by reviewing the CenturyLink Cloud API docs here: https://www.ctl.io/api-docs/v2/.

Your SMTP Relay alias will be specified in the individual PowerShell scripts that call for it. I have also secured my SMTP relay password via a PowerShell function, but that can be directly replaced with a string or object containing your password.

### Support

This code is presented as is and is open to contribution from the community.

Feature requests and enhancements can be suggested to Matt.Schwabenbauer@ctl.io. Any future development is not guaranteed.