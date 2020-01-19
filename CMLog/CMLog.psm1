<#

.Synopsis
	Module to Create an SCCM Style Log File for Powershell Scripts

.Description
	Module to Create an SCCM Style Log File for Powershell Scripts
	
.Inputs
	None
	
.Outputs
	None
	
.Notes
	Version:			1.3
	Author:				Chris Mitchell
	Creation Date:		2018-04-18
	Last Revision Date:	2019-10-23
	Purpose Change:		1.0 - 2018-04-18 - Chris Mitchell - Initial Module
						1.1 - 2018-04-18 - Chris Mitchell - Signed Module
						1.2 - 2018-10-10 - Chris Mitchell - Added step to Start-CMLog to create log directory if it doesn;t exist.
						1.3 - 2019-10-23 - Chris Mitchell - Added method to rename existing log file once a size limit is reached. Default Size limit is 1MB
							
.Example
	Start-CMLog -LogPath "C:\Windows\CCM\Logs\CustomLog.log"
	Will begin the Logging Session for the Script and set the Global Script Variable to the specified Path.
    If LogFile does not exist, will create log file.
	
#>

Function Start-CMLog
{
	param
	(
	#Log File path.
    [Parameter(ValueFromPipelineByPropertyName,
    Position = 0)]
    [string]
    $LogPath

    )
	Process
	{
            
		#Check for Directory and Create if Required
		$Parent = Split-Path $LogPath
		If(!(Test-Path $Parent)){
			New-Item -Path $Parent -ItemType Directory -Force
		}			
			
        #Check for the File and Create it if required
		Try{
            If(!(Test-Path $LogPath))
            {
                New-Item $LogPath -ItemType File | Out-Null
            }
            
            $Global:CMLogPath = $LogPath
            
        }Catch{
            Write-Error $_.Exception.Message
        }
        		
	}
}

Function Write-CMLog{

	param
	(
	#Message to Write Into Log.
    [Parameter(ValueFromPipelineByPropertyName,
    Position = 0)]
    [string]
    $Message,
	
	 #Message Type (1=Information, 2=Warning, 3=Error)
    [Parameter(ValueFromPipelineByPropertyName,
	Position = 1)]
	[ValidateSet(1, 2, 3)]
    [int]
    $LogLevel = 1

	)

	#Check that the Log File is under the maximum size
	CheckCMLogSize

	#Generate Required Values for Log File
	$Time = "$(Get-Date -Format HH:mm:ss).$((Get-Date).Millisecond)+000"
	$Date = (Get-Date -Format MM-dd-yyyy)
	$ScriptDetails = "$($MyInvocation.ScriptName | Split-Path -Leaf):$($MyInvocation.ScriptLineNumber)"

	#Log Line
	$TempLine = '<![LOG[{0}]LOG]!><time="{1}" date="{2}" component="{3}" context ="" type="{4}" thread="" file="">'
	$LineData = $Message, $Time, $Date, $ScriptDetails, $LogLevel
	$LogLine = $TempLine -f $LineData

	#Write the Log Data
	Add-Content -Value $LogLine -Path $CMLogPath

	#Write to the Console if Being Run Interactivly
	If($LogLevel -eq 1){

		Write-Output $Message

	}elseif($LogLevel -eq 2){

		Write-Warning $Message

	}elseif($LogLevel -eq 3){

		Write-Error $Message

	}
	
}

Function CheckCMLogSize{

	param
	(

	#Maximum File size.
    [Parameter(ValueFromPipelineByPropertyName,
    Position = 0)]
    [double]
	$MaxLogSize = 1

	)

	#Convert to MB's
	$MaxLogSize = $MaxLogSize * 1024 * 1024

	#Check for Existing Log and rename if this is greater than the MaxLogSize
	If((Get-Item $CMLogPath -ErrorAction SilentlyContinue).Length -gt ${MaxLogSize}){

		$Timestamp = [DateTime]::Now.ToString("yyyyMMdd-HHmmss")
		$LogName = [System.IO.Path]::GetFileNameWithoutExtension("$CMLogPath")
		Rename-Item -Path $CMLogPath -NewName "${LogName}.log"
		New-Item $LogPath -ItemType File | Out-Null

	}
	
}
