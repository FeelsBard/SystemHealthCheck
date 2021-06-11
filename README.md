# SystemHealthCheck [![made-with-powershell](https://img.shields.io/badge/PowerShell-1f425f?logo=Powershell)](https://microsoft.com/PowerShell)
Analyzes specified systems for OS corruptions and creates a report to send by Slack, Teams, Discord, email, display in console, or save to a text file.  
## Usage
This Powershell script can be scheduled as a task, run directly from a Powershell console, or from the file.
You are required to configure options inside the script in order to allow to get results. I may put a GUI front end on it in the future to help with configuration as it can be a little overwhelming to look at.  
## Requirements
### Software:
Powershell's AD module (if using the AD query functions)  
### Configuration:
###### Inputs
You need to need to pick 1 of 3 methods of getting the list of systems to run the script against. Currently this is a result array you specify in the script, a CSV file, or a direct query of AD. Some examples are listed for the AD query, but you may need to make one specific to your needs.  
<pre>$csvinput = "False"
$arrayinput = "True"
$adqueryinput = "False"</pre>  
Each has specific configurations you will need to configure.  
CSV input requires you to set the following variable: <pre>$csvtarget = "C:\Path\To.CSV"</pre>
Array input requires you to build an array inside the script. Don't worry. If you haven't done it before it's super easy.  
Create your array at the arraytargets variable:
<pre>$arraytargets = @()</pre>
So let's say you have your DC, DC2, FileServer (hostname of FS1), TermServer (hostname of TS1), and an App server (hostname of App1). You enter their hostname between the route brackets, in single quotes, and seperated by commas.
<pre>Example:
$arraytargets = @('DC','DC2','FS1','TS1','App1')</pre>
Told you it was easy.  
AD query input is the hardest option to configure. I have put a default query for ALL systems running a Windows Server OS . If that's all you need then you don't have to configure anything additional. I have also included some additional queries you can use and replace everything after `$targetlist = ` If that's not the case... It's very specific to the domain you're on, what you're looking for, and whatever else you need to query to get exactly the results you want. If you are willing to take the time and configure this it's fantastic because you don't need to update an array or CSV file later. If a system is added or removed from an OU the script automatically knows that when run. The configuration for this is NOT with the other configurations. This is to make it less accessible for novices and run more optimal.  
<pre>if ($adqueryinput -eq "True"){
    # Enter the information you need for your query. This is flexable based on your needs.
    # Examples:
    # OU specific: Get-ADComputer -Filter * -SearchBase "OU=IT, DC=contoso, DC=com"
    # All computers: Get-ADComputer -Filter *
    # Workstations only: Get-ADComputer -Filter * -SearchBase "CN=Workstations, DC=contoso, DC=com"
    # Servers only: Get-ADComputer -Filter { OperatingSystem -Like '*Windows Server*'}
    $targetlist = Get-ADComputer -Filter { OperatingSystem -Like '*Windows Server*'}
}</pre>
###### Outputs
You can choose from 5 methods of getting the script output. Set this to "True" or "False" depending on what you want. You can pick as many as you want as long as you configure all the settings for that specific output type.  
<pre>$teamsalerts = "False"  
$slackalerts = "False"  
$emailalerts = "False"  
$discordalerts = "False"  
$terminalalerts = "True" #Enabled by default.  
$textfileoutput = "False"</pre>

#### 1) Teams
Requirements: A webhook needs to be created for Teams. Please consult Microsoft's Documentation [HERE](https://docs.microsoft.com/en-us/microsoftteams/platform/webhooks-and-connectors/how-to/add-incoming-webhook) if you need help creating one.  
<pre>$teamsalertshook = ""</pre>

#### 2) Slack
Requirements: A webhook needs to be created for Slack. Please consult Slack's Documentation [HERE](https://api.slack.com/messaging/webhooks)
<pre>$slackalertshook = ""
$slackchannel = ""</pre>

#### 3) Email
Requirements: You will need to have an available SMTP relay. Some do require credentials. If you enable this option you will be prompted for the credentials before the script can run. The following settings will need to be configured:
<pre>$emailfrom = ""
$emailto = ""
$emailsubject = ""
$emailsmtp = ""
$emailcredentialsrequired = "False" #Disabled by default</pre>

If you are not receiving output via email please open a Powershell window and manually run the Send-MailMessage cmdlet with your settings to see if it's sending correctly.
<pre>Example:
Send-MailMessage -SmtpServer mysmtp.com -Port 25 -From user@domain.com -To user@domain.com -Subject test -Body test</pre>

#### 4) Discord
Requirements: A webhook needs to be created for Discord. Please consult Discord's Documentation [HERE](https://support.discord.com/hc/en-us/articles/228383668-Intro-to-Webhooks)
<pre>$discordalertshook = ""</pre>

#### 5) Terminal/Console
This will put the output in the console you're using. If you are running the script as a scheduled task you will want to configure an additional option since you will not be able to see the output. You do not need to configure anything for this output type.

#### 6) Text File
Requirements: Configure the variable to specify a path to store the file. The user account which this script is running in context of must have access to write to the folder or this will fail. If Bob creates a scheduled task and expects this to write to a folder he has no permission to it won't work. Don't be like Bob. Make sure you're writing to a folder you have rights to.
<pre>$textfileoutputpath = ""</pre>

## Info/FAQ
##### What inspired you to build this ridiculous monstrosity?
Recently we discovered a server had become corrupt. We have enough servers where checking this on every single one is EXTREMELY time consuming (especially for a two person department). I had been fighting with this during nights and weekends for months. Had I known this was the issue I could have saved myself a ton of headache and my users a ton of trouble. If you can get ahead of server corruption you can save yourself thousands of dollars in cost for your company.
##### Do you actually use Teams, Slack, Discord, email, console, AND text files?
Not for alerts. I do have SOME redundency built into my personal stuff, but I'm not using all of these. I know this is the most common methods used so I wanted everyone to have an option.
##### Why don't you like Bob? What did he do to you?
Bob isn't actually named Bob. Bob is an alias to protect the guilty party. Bob knows what he did though...
##### I want something ridiculous for my webhooks to display as the photo. Any suggestions?
Do you know someone made [a skinless robot that blinks like a human](https://cdn.vox-cdn.com/thumbor/UNwAJoM8e6nbSuBccxj_33Ca7eM=/1400x1400/filters:format(jpeg)/cdn.vox-cdn.com/uploads/chorus_asset/file/22005398/disney_robot.jpg)? Why? I don't know, but it's creepy and my new default bot image. (credit: TheVerge.com)
##### Do you have plans to expand this later?
If it's becoming useful enough for a lot of people things such as a GUI, HTML reports, and other items may be added. For now I feel this is fine.
##### Your script just saved my butt. Can I say thanks somehow?
At this time I'm not setup with any tip jar services. I do hope to later as I am planning on content creation at some point. Do I expect anything? No. Would I appreciate it? Of course. I've got 3 kids to feed.
