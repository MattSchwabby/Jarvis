function doPrettyPrint {
param($message)

$output = $message | ConvertFrom-Json

if($output.success) { 
    return ([char]0x2705 +" "+ $output.output)
    } else { 
        return ([char]0x274C +" "+ $output.output)
}

}