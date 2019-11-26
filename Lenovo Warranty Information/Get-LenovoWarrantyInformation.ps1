<#
.SYNOPSIS
    Get warranty information for a Lenovo system
.DESCRIPTION
    This Script will gather Warranty Information for the Current Machine and write this into a Custom WMI Class
.EXAMPLE
    .\Get-LenovoWarrantyInformation.ps1

.NOTES
    Script name: Get-LenovoWarrantyInformation.ps1
    Author:      Chris Mitchell
    DateCreated: 2019-11-21

.SOURCES
    https://www.scconfigmgr.com/2015/03/21/get-lenovo-warranty-information-with-powershell/
    https://forums.lenovo.com/t5/Lenovo-Technologies/Warranty-API/td-p/3484953
    https://sccmguru.wordpress.com/2019/01/15/gather-lenovo-warranty-information-with-powershell/

#>

$CustomWMIClass = "CM_MachineWarranty"

#Uncomment the below section if Proxy Authentication is required.
<#
$Wcl = New-Object System.Net.WebClient
$Wcl.Headers.Add("user-agent", "PowerShell Script")
$Wcl.Proxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials
#>

$Model = (Get-CimInstance -Class Win32_ComputerSystem).Model
$SerialNumber = (Get-CimInstance -Class Win32_SystemEnclosure).SerialNumber
$Pwd = "ENTER CLIENT ID HERE"

$URL = "https://ibase.lenovo.com/POIRequest.aspx"
$Method = "POST"
$Header = @{ "Content-Type" = "application/x-www-form-urlencoded" }
$Body = "xml=<wiInputForm source='ibase'><id>LSC3</id><pw>$Pwd</pw><product>$Model</product><serial>$SerialNumber</serial><wiOptions><machine/><parts/><service/><upma/><entitle/></wiOptions></wiInputForm>"

Try{
    $Result = (Invoke-RestMethod -Method $Method -Uri $URL -Body $Body -Headers $Header).wiOutputForm
}
Catch [Exception]
{
    Write-Output "Unable to connect to Remote Address. Please check Internet Access."
    [System.Environment]::Exit(2)
}

$RandomFileName = [io.path]::GetRandomFileName() + ".xml"
$TempFile = "${env:TEMP}\$RandomFileName"

#Export to Clixml to use XPath to retrieve the Extended Warranty Information
$Result | Export-Clixml -Path $TempFile

Try{
    $ExtendedExpiration = (Select-XML -Path $TempFile -XPath "//*[@N='mEndDate']").Node.InnerText[0]
    $ExtendedDescription = (Select-XML -Path $TempFile -XPath "//*[@N='mSDFDesc']").Node.InnerText[0]
}
Catch{}

Remove-Item -Path $TempFile -Force

#Check Extended Warranty Info and re-write values if the machine doesn't have warranty:
If($ExtendedExpiration -notmatch "^\d{4}"){
    $ExtendedExpiration = "N/A"
    $ExtendedDescription = "This machine does not have extended Premier Support."
}

$WarrantyInformation = [PSCustomObject]@{
Type = $Result.warrantyInfo.machineinfo.type
Model = $Result.warrantyInfo.machineinfo.model
Product = $Result.warrantyInfo.machineinfo.product
SerialNumber = $Result.warrantyInfo.machineinfo.serial
StartDate = $Result.warrantyInfo.serviceInfo.warstart[0]
ExpirationDate = $Result.warrantyInfo.serviceInfo.wed[0]
ExtendedExpiration = $ExtendedExpiration
ExtendedDescription = $ExtendedDescription
Location = $Result.warrantyInfo.serviceInfo.countryDesc[0]
Description = $Result.warrantyInfo.serviceInfo.sdfDesc[0]
}

#Check if the WMI Class Exists
Try{
    Get-WmiObject -Class $CustomWMIClass -ErrorAction Stop
    $ClassExists = $true
}
Catch{
    $ClassExists = $false
}

#Remove WMI Class if it exists
If($ClassExists){
    Try{
        Get-WmiObject -Class $CustomWMIClass | Remove-WMIObject
    }
    Catch{
        Exit
    }
}

#Create the Custom WMI Class
$NewWMIClass = New-Object System.Management.ManagementClass("root\cimv2",[String]::Empty,$null)

$NewWMIClass["__CLASS"] = $CustomWMIClass
$NewWMIClass.Qualifiers.Add("Static",$true)
$NewWMIClass.Properties.Add("Type",[System.Management.CimType]::String,$false)
$NewWMIClass.Properties["Type"].Qualifiers.Add("Key",$true)
$NewWMIClass.Properties.Add("Model",[System.Management.CimType]::String,$false)
$NewWMIClass.Properties["Model"].Qualifiers.Add("Key",$true)
$NewWMIClass.Properties.Add("Product",[System.Management.CimType]::String,$false)
$NewWMIClass.Properties["Product"].Qualifiers.Add("Key",$true)
$NewWMIClass.Properties.Add("SerialNumber",[System.Management.CimType]::String,$false)
$NewWMIClass.Properties["SerialNumber"].Qualifiers.Add("Key",$true)
$NewWMIClass.Properties.Add("StartDate",[System.Management.CimType]::String,$false)
$NewWMIClass.Properties.Add("ExpirationDate",[System.Management.CimType]::String,$false)
$NewWMIClass.Properties.Add("ExtendedExpiration",[System.Management.CimType]::String,$false)
$NewWMIClass.Properties.Add("ExtendedDescription",[System.Management.CimType]::String,$false)
$NewWMIClass.Properties.Add("Description",[System.Management.CimType]::String,$false)

$NewWMIClass.put() | Out-Null

ForEach($_ in $WarrantyInformation){

    $WMIClass = Get-WmiObject -Class $CustomWMIClass -List
    
    $WMIInstance = $WMIClass.CreateInstance()
    $WMIInstance.Type = $_.Type
    $WMIInstance.Model = $_.Model
    $WMIInstance.Product = $_.Product
    $WMIInstance.SerialNumber = $_.SerialNumber
    $WMIInstance.StartDate = $_.StartDate
    $WMIInstance.ExpirationDate = $_.ExpirationDate
    $WMIInstance.ExtendedExpiration = $_.ExtendedExpiration
    $WMIInstance.ExtendedDescription = $_.ExtendedDescription
    $WMIInstance.Description = $_.Description

    $WMIInstance.Put() | Out-Null

}