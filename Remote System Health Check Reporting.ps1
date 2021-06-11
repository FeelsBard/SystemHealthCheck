# Remote System Health Check Reporting

# Self-elevate the script if needed.
$selfelevate = "False"
if ($selfelevate -eq "True"){
    if (-Not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator')) {
    if ([int](Get-CimInstance -Class Win32_OperatingSystem | Select-Object -ExpandProperty BuildNumber) -ge 6000) {
        $CommandLine = "-File `"" + $MyInvocation.MyCommand.Path + "`" " + $MyInvocation.UnboundArguments
        Start-Process -FilePath PowerShell.exe -Verb Runas -ArgumentList $CommandLine
        Exit
    }
}
}

# Select alert types. Multiple options can be set to true.
$teamsalerts = "False"
$slackalerts = "False"
$emailalerts = "False"
$discordalerts = "False"
$terminalalerts = "True" #Enabled by default.
$textfileoutput = "False"

# Alert wording for violations found/not found. These are able to be changed if needed.
$violationsfound = "Integrity Violations Found!"
$violationsnotfound = "No Violations Found."
$dismcorruptionfound = "Component Store Corruption Found!"
$dismcorruptionnotfound = "No Component Store Corruption Found."

# Configure outputs. Only alert types you plan on using need to be configured.
# MS Teams webhook. Create a webhook if needed. How To: https://docs.microsoft.com/en-us/microsoftteams/platform/webhooks-and-connectors/how-to/add-incoming-webhook
$teamsalertshook = ""

# Slack channel webhook and channel specification. Create a webhook if needed. How To: https://api.slack.com/messaging/webhooks
$slackalertshook = ""
$slackchannel = ""

# Discord channel webhook. Create a webhook if needed. How To: https://support.discord.com/hc/en-us/articles/228383668-Intro-to-Webhooks
$discordalertshook = ""

# Email alerts. You'll need to configure your subject, sender, SMTP relay, and credentials (if needed by your relay)
# If your SMTP relay requires credentials you will need to set $emailcredentialsrequired to "True"
$emailfrom = ""
$emailto = ""
$emailsubject = ""
$emailsmtp = ""
$emailcredentialsrequired = "False" # Disabled by default

# Text output. Specify the path to save a text copy of the output.
$textfileoutputpath = ""

# Only send alerts for systems found with violations.
$violationsonlyalerts = "False"

# Select source for list of systems to check for violations.
# Only ONE should be set to True and is required.
# Replace "False" with "True" to enable source.
$csvinput = "False"
$arrayinput = "True"
$adqueryinput = "False"

# Configure Inputs
# From CSV file
$csvtarget = "C:\Path\To.CSV"
# Manually built array
# Example @('ConstegoDC',')
$arraytargets = @()
# AD Query

# Check for incorrect source counts. There should ALWAYS be 1 true and 2 false options selected.
$sourcetruecount = 0
$sourcefalsecount = 0
if ($csvinput -eq "False"){
    $sourcefalsecount = $sourcefalsecount + 1
}
if ($arrayinput -eq "False"){
    $sourcefalsecount = $sourcefalsecount + 1
}
if ($adqueryinput -eq "False"){
    $sourcefalsecount = $sourcefalsecount + 1
}
if ($csvinput -eq "True"){
    $sourcetruecount = $sourcetruecount + 1
}
if ($arrayinput -eq "True"){
    $sourcetruecount = $sourcetruecount + 1
}
if ($adqueryinput -eq "True"){
    $sourcetruecount = $sourcetruecount + 1
}
if ($sourcetruecount -gt 1){
    Write-Host "Too many sources selected. Please select only 1 target source."
    Exit
}
if ($sourcefalsecount -eq 3){
    Write-Host "No sources selected. Please select and configure a target source."
    Exit
}
#Prompt for credentials of user permitted to use the relay.
If ($emailcredentialsrequired -eq "True"){
    $emailcredentials = Get-Credential
    }
# Builds targetlist array.
if ($csvinput -eq "True"){
    # Change to your CSV location
    $targetlist = Import-Csv -Path $csvtarget -Header target
}
if ($arrayinput -eq "True"){
    $ms = New-Object System.IO.MemoryStream
    $bf = New-Object System.Runtime.Serialization.Formatters.Binary.BinaryFormatter
    $bf.Serialize($ms, $arraytargets)
    $ms.Position = 0
    $targetlist = $bf.Deserialize($ms)
    $ms.Close()
}
if ($adqueryinput -eq "True"){
    # Enter the information you need for your query. This is flexable based on your needs.
    # Examples:
    # OU specific: Get-ADComputer -Filter * -SearchBase "OU=IT, DC=contoso, DC=com"
    # All computers: Get-ADComputer -Filter *
    # Workstations only: Get-ADComputer -Filter * -SearchBase "CN=Workstations, DC=contoso, DC=com"
    # Servers only: Get-ADComputer -Filter { OperatingSystem -Like '*Windows Server*'}
    $targetlist = Get-ADComputer -Filter { OperatingSystem -Like '*Windows Server*'}
}
#######################################################################################################################
########Changing any variables below this line could cause failure for alerts to be pushed or the script to run########
#Be extremely careful modifying ANYTHING below this line. Safe to modify fields will be commented with "#Customizable"#
#######################################################################################################################
$resultarray = @()
# Runs through a loop of all systems declared as targets and builds results array.
foreach ($target in $targetlist) {
    Write-Host "Restarting TrustedInstaller on $target."
    Invoke-Command -ComputerName $target -ScriptBlock {Restart-Service -Name TrustedInstaller}
    Write-Host "Remotely invoking SFC on $target."
    
    $sfcout = Invoke-Command -ComputerName $target -ScriptBlock {sfc /verifyonly}
    $sfcout = $sfcout -replace "`0" | Where-Object {$_}

    try {If ($sfcout.Contains("Windows Resource Protection found integrity violations.")){
    $sfcresult = $violationsfound
    }} catch {$_.Exception.Message | Out-File RSHCR.txt -Append}

    try {If ($sfcout.Contains("Windows Resource Protection did not find any integrity violations.")){
    $sfcresult = $violationsnotfound
    }} catch {$_.Exception.Message | Out-File RSHCR.txt -Append}
    try {if ($null -eq $sfcout){$sfcresult = "Scan Error. Server may be busy."}} catch {$_.Exception.Message | Out-File RSHCR.txt -Append}
    Write-Host "$target Result: $sfcresult"
    Write-Host "Remotely invoking DISM on $target"
    $dismout = Invoke-Command -ComputerName $target -ScriptBlock {dism /online /cleanup-image /checkhealth}

    If ($dismout.Contains("No component store corruption detected.")){
        $dismresult = $dismcorruptionnotfound
    }
    If ($dismout.Contains("repairable")){
        $dismresult = $dismcorruptionfound
    }
    if ($null -eq $dismout){$dismout = "Scan Error. Server may be busy."}
    Write-Host "$target result: $dismresult"
    $results = @{
    Hostname=$target
    SFC_Result=$sfcresult
    DISM_Result=$dismresult}
    $Service = New-Object -TypeName psobject -Property $results
    $resultarray += $Service
}
# Remove systems without violations from the array if enabled by $violationsonlyalerts setting.
if ($violationsonlyalerts -eq "True"){
    foreach ($result in $resultarray) {
        if ($result -contains $violationsnotfound -or $dismcorruptionnotfound){
            $resultarray.Remove($result)
        }
    }
}

# Push alerts to Microsoft Teams if enabled.
if ($teamsalerts -eq "True"){
    $TeamsBody = [PSCustomObject][Ordered]@{
    "@type"      = "MessageCard"
    "@context"   = "http://schema.org/extensions"
    #Customizable
    "summary"    = "System Health Check Report Results"
    #Customizable
    "title"      = "System Health Check Report"
    "text"       = $resultarray | Format-List Hostname,SFC_Result,DISM_Result | Out-String
    }
    $TeamMessageBody = ConvertTo-Json $TeamsBody -Depth 1
    $parameters = @{
        "URI"         = $teamsalertshook
        "Method"      = 'POST'
        "Body"        = $TeamMessageBody
        "ContentType" = 'application/json'
    }
    Invoke-RestMethod @parameters
    }

# Push alerts to Slack if enabled.
if ($slackalerts -eq "True"){
    $slackbodytext = $resultarray | Format-List Hostname,SFC_Result,DISM_Result | Out-String
    $slackbodytextformatted = $slackbodytext -replace "`r`n","\n"
    $Slackbody = @"
    {
        "channel": "$slackchannel",
        "text": "$slackbodytextformatted",
        "icon_emoji": ":loudspeaker:",
        "username": "Server Integrity Bot",
    }
"@
    try {Invoke-WebRequest -uri $slackalertshook -Method Post -body $slackbody -Headers @{'Content-Type' = 'application/json'}} catch {$_.Exception.Message | Out-File RSHCR.txt -Append}
    Write-Host $Slackbody
}

# Send alert as email message if enabled.
if ($emailalerts -eq "True"){
    $Emailbody = $resultarray | Format-List Hostname,SFC_Result,DISM_Result | Out-String
    if ($emailcredentialsrequired -eq "False"){
        Send-MailMessage -To $emailto -From $emailfrom -Subject $emailsubject -SmtpServer $emailsmtp -Body $Emailbody
    }
    if ($emailcredentialsrequired -eq "True"){
        Send-MailMessage -To $emailto -From $emailfrom -Subject $emailsubject -SmtpServer $emailsmtp -Credential $emailcredentials -Body $Emailbody
    }
}
# Push alerts to Discord if enabled
if ($discordalerts -eq "True"){
    $discordbodytext = ($resultarray | Out-String)
    $discordbodytextformatted = $discordbodytext -replace "`r`n","\n"
    $discordalertbody = @"
    {
        "content": "$discordbodytextformatted"
    }
"@
    try {Invoke-RestMethod -Uri $discordalertshook -Method Post -Body $discordalertbody -Headers @{'Content-Type' = 'application/json'}} catch {$_.Exception.Message | Out-File RSHCR.txt -Append}
    Write-Host $discordcontent
}
# Write results array to terminal/console if enabled (Enabled by default)
if ($terminalalerts -eq "True"){
    $resultarray | Format-List Hostname,SFC_Result,DISM_Result
}

# Write results to a text file.
if ($textfileoutput -eq "True"){
    $resultarray | Format-List Hostname,SFC_Result,DISM_Result | Out-File -Append $textfileoutputpath
}