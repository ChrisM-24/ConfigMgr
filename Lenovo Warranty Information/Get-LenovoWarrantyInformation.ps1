<#
.SYNOPSIS
    Get warranty information for a Lenovo system
.DESCRIPTION
    This Script will gather Warranty Information for the Current Machine and write this into Custom WMI Classes
.EXAMPLE
    .\Get-LenovoWarrantyInformation.ps1

.NOTES
    Script name: Get-LenovoWarrantyInformation.ps1
    Author:      Chris Mitchell
    DateCreated: 2019-11-27

#>

$WMIClass_BasicWarranty = "CM_MachineWarranty"
$WMIClass_DetailedWarranty = "CM_DetailedMachineWarranty"

$SerialNumber = (Get-CimInstance -Class Win32_SystemEnclosure).SerialNumber
$AccessToken = "ENTER ACCESS TOKEN HERE"

$Url = "http://supportapi.lenovo.com/v2.5/warranty?Serial=${SerialNumber}"
$Method = "POST"
$Header = @{
        "Content-Type" = "application/x-www-form-urlencoded"
        "ClientID" = "${AccessToken}"
    }
$ContentType = "application/JSON"

Try{
    $Result = Invoke-RestMethod -Method $Method -Uri $URL -Headers $Header -ContentType $ContentType
}
Catch [Exception]
{
    Write-Output "Unable to connect to Remote Address. Please check Internet Access."
    Exit
}

#Define the Regex to find the first non-digit or -
$SplitRegex = "[^\d^-]"

$DetailedWarrantyInfo = @()

ForEach($Warranty in $Result.Warranty){

    $WarrantyResult=@{
        ID = $Warranty.ID
        Name = $Warranty.Name
        Description = $Warranty.Description
        Type = $Warranty.Type
        StartDate = ($Warranty.Start -split $SplitRegex)[0]
        EndDate = ($Warranty.End -split $SplitRegex)[0]
    }

    $DetailedWarrantyInfo += New-Object psobject -Property $WarrantyResult
    

}

#Determine the Warranty with the latest Expiry Date
$LongestWarranty = ($DetailedWarrantyInfo | Sort-Object -Property EndDate -Descending).EndDate[0]

#Define the Basic Warranty Information

$BasicWarrantyInfo=@{
    Serial = $Result.Serial
    Product = $Result.Product
    InWarranty = $Result.InWarranty
    Country = $Result.Country
    Expiry = $LongestWarranty
}

#Write the Information into WMI to show Overall Warranty Status, and the Extended Warranty Information
$CustomWMIClasses = @($WMIClass_BasicWarranty,$WMIClass_DetailedWarranty)

#Remove WMI Classes if they exist on the Machine
ForEach($Class in $CustomWMIClasses){
    #Check if the WMI Class Exists
    Try{
        $CIMInstance = Get-CimInstance -Class $Class -ErrorAction Stop
        Get-CimInstance -Class $Class | Remove-CimInstance -ErrorAction SilentlyContinue
    }
    Catch{
        #Class doesn't exist
    }
}

#Create the WMI Classes
$WMI_Basic = New-Object System.Management.ManagementClass("root\cimv2",[String]::Empty,$null)
$WMI_Basic["__CLASS"] = $WMIClass_BasicWarranty
$WMI_Basic.Qualifiers.Add("Static",$true)
ForEach($Property in $BasicWarrantyInfo.Keys){
    $WMI_Basic.Properties.Add($Property,[System.Management.CimType]::String,$false)
}
$WMI_Basic.Properties["Serial"].Qualifiers.Add("Key",$true)
$WMI_Basic.Put() | Out-Null

$WMI_Detailed = New-Object System.Management.ManagementClass("root\cimv2",[String]::Empty,$null)
$WMI_Detailed["__CLASS"] = $WMIClass_DetailedWarranty
$WMI_Detailed.Qualifiers.Add("Static",$true)
ForEach($Property in $DetailedWarrantyInfo[0].psobject.Properties){
    $WMI_Detailed.Properties.Add($Property.Name,[System.Management.CimType]::String,$false)
}
$WMI_Detailed.Properties["ID"].Qualifiers.Add("Key",$true)
$WMI_Detailed.Put() | Out-Null

#Populate the WMI Classes
$WMIClass = Get-WmiObject -Class $WMIClass_BasicWarranty -List
$WMIInstance = $WMIClass.CreateInstance()

ForEach($Property in $BasicWarrantyInfo.Keys){
    $WMIInstance.$Property = $BasicWarrantyInfo.$Property
}
$WMIInstance.Put() | Out-Null

$WMIClass = Get-WmiObject -Class $WMIClass_DetailedWarranty -List

ForEach($Warranty in $DetailedWarrantyInfo){

    $WMIInstance = $WMIClass.CreateInstance()

    ForEach($Property in $DetailedWarrantyInfo[0].psobject.Properties){
        $WMIInstance.($Property.Name) = $Warranty.($Property.Name)
    }

    $WMIInstance.Put() | Out-Null
}