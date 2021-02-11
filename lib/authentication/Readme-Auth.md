# Jarvis

Authentication module for Jarvis

Author: Praveen Kumar

Date: November 20, 2018

Praveen.Kumar1@centurylink.com

### About this repository

This module provides the authentication functions for Jarvis.

### Deploying the auth module

The functions for authentication are defined in the PowerShell module loginCLCAPI.psm1. 
During deployment, this file should be placed at C:\Windows\System32\WindowsPowerShell\v1.0\Modules\loginCLCAPI\loginCLCAPI.psm1

This module defines functions to authenticate to V1 and V2 control APIs.

The credentials for both V1 and V2 are encoded using a standard PowerShell module ConvertTo-SecureString (https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.security/convertto-securestring?view=powershell-6)
The encoded credentials should be stored in a file named config.json in the following JSON format:

{
    "JK1": "<API Key for Control API V1 authentication>",
    "JK2": "<Encoded password for Control API V1 authentication>",
    "JK3": "<Username for Control API V2 authentication>",
    "JK4": "<Encoded Password for Control API V2 authentication>",
    "JK5": "<Encoded SMTP credentials>",
    "JK6": "<Consumption API Username>",
    "JK7": "<Encoded password for Consumption API>",
    "JK8": "<Encoded password for Consumtion DB>",
    "BM1": "<Forecast username>",
    "BM2": "<Forecast password>",
    "BM3": "<>",
    "BM4": "<>"
}

For Jarvis, only JK1, JK2, JK3 and JK4 values are relevant.

This config.json file should be deployed at C:\Users\Administrator\JK\config.json