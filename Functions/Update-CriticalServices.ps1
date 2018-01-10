function Update-CriticalServices {
    <#
    .SYNOPSIS
    Updates the Critical Services register created by the Register-CriticalServices Function
    
    .DESCRIPTION
    Updates the Critical Services register created by the Register-CriticalServices Function, this can be done against the current file or generated from a 
    new scan of the target computer
    
    .PARAMETER Computer
    Name of remote computer

    .PARAMETER RunningOnly
    Displays only services that are currently running

    .PARAMETER OutputPath
    Where the output file will be stored

    .PARAMETER Online
    If selected it will run a new scan for services against the machine
        
    .EXAMPLE
    Update-CriticalServices -Computer Server01 -OutputPath \\FILESERVER\RegisterLocation\
    Gets the Critical Services register for Server01 from \\FILESERVER\RegisterLocation\ and runs through the update process

    .EXAMPLE
    Update-CriticalServices -Computer Server01 -OutputPath \\FILESERVER\RegisterLocation\ -Online
    Gets the Critical Services register for Server01 from \\FILESERVER\RegisterLocation\ then runs a new scan for services on
    Server01, it will then run through the update process.

    #>
    [CmdletBinding(DefaultParameterSetName='Default')]
    param (
        [parameter(Position=0,
        Mandatory=$true,
        ValueFromPipeline=$true,
        ParameterSetName='Default')]
        [string]$Computer,

        [parameter(Position=1,
        ValueFromPipeline=$true,
        ParameterSetName='Default')]
        [switch]$RunningOnly,

        [parameter(Position=2,
        Mandatory=$true,
        ValueFromPipeline=$true,
        ParameterSetName='Default')]
        [string]$OutputPath,

        [parameter(Position=3,
        ValueFromPipeline=$true,
        ParameterSetName='Default')]
        [switch]$Online
    )
    begin {

        if ($OutputPath -notmatch '.+?\\$') {
            $OutputPath = $OutputPath+"\"
        }
        if ($Online.IsPresent){
            if (!(Test-Connection $Computer -Count 2 -Quiet)) {
                throw "Machine may be offline"                        
            }
        }
        if (!(Test-Path $OutputPath)) {
            throw "Output path not found"                        
        }
        $OutputFile = $OutputPath + $Computer + ".csv"
        if (!(Test-Path $OutputFile)) {
            throw "Output file not found, please run the Register-CriticalServices function against this machine."                        
        }
    }
    process {
        if ($Online.IsPresent){
            $Current_Status = Import-Csv $OutputFile
            $Current_Critical_Services = $Current_Status | Where-Object {$_.CriticalService -eq 1}
             
            if ($RunningOnly.IsPresent) {
                $Services = Get-WmiObject Win32_Service -ComputerName $Computer | Select-Object SystemName,DisplayName,Name,State,StartMode,PathName,StartName | Where-Object {$_.State -eq "Running"}          
            } else {
                $Services = Get-WmiObject Win32_Service -ComputerName $Computer | Select-Object SystemName,DisplayName,Name,State,StartMode,PathName,StartName
            }

            $Services | Where-Object { $Current_Critical_Services.name -notcontains $_.name } | Add-Member -MemberType NoteProperty -Name "CriticalService" -Value 0 -Force
            $Services | Where-Object {$_.CriticalService -ne 0} | Add-Member -MemberType NoteProperty -Name "CriticalService" -Value 1 -Force

            $Services | Where-Object {$_.CriticalService -ne 1} | Out-GridView -Title "Select Critical Services to Add" -OutputMode Multiple | Add-Member -MemberType NoteProperty -Name "CriticalService" -Value 1 -Force
            $Services | Where-Object {$_.CriticalService -eq 1} | Out-GridView -Title "Select Critical Services to Remove" -OutputMode Multiple | Add-Member -MemberType NoteProperty -Name "CriticalService" -Value 0 -Force

            $Output = $Services
        } else {
            $Current_Status = Import-Csv $OutputFile

            $Current_Status | Where-Object {$_.CriticalService -ne 1} | Out-GridView -Title "Select Critical Services to Add" -OutputMode Multiple | Add-Member -MemberType NoteProperty -Name "CriticalService" -Value 1 -Force
            $Current_Status | Where-Object {$_.CriticalService -eq 1} | Out-GridView -Title "Select Critical Services to Remove" -OutputMode Multiple | Add-Member -MemberType NoteProperty -Name "CriticalService" -Value 0 -Force
        
            $Output = $Current_Status
        }   

    }
    end {
        $Output | Sort-Object CriticalService -Descending | Export-Csv -Path $OutputFile -NoTypeInformation
    }
}