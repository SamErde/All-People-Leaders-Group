function Update-PeopleLeadersGroup {
    <#
        .SYNOPSIS
        Update the members of an Active Directory group to contain all people leaders in the organization.

        .DESCRIPTION
        Queries Active Directory for all enabled users who have direct reports and whose title matches a
        configurable list of leadership titles (e.g. Chief, Director, Manager, Supervisor). Users whose
        titles match an exclusion list (e.g. Project Manager, Case Manager) are filtered out.

        The resulting set of people leaders is compared with the current membership of the target AD group.
        Missing leaders are added and former leaders are removed so the group stays current.

        .PARAMETER GroupName
        The name of the Active Directory security group to update. The group must already exist.
        Defaults to 'All People Leaders'.

        .PARAMETER LogFilePath
        The full path to the log file. The parent directory will be created if it does not exist.
        Defaults to 'PeopleLeadersGroup.log' in the current working directory.

        .PARAMETER TitlesToInclude
        An array of title keywords that identify people leaders. A user whose title matches any of these
        patterns (regex) is considered a people leader. Defaults to: Chief, President, Director, Manager,
        Supervisor.

        .PARAMETER TitlesToExclude
        An array of title strings to exclude from the people leaders set, even if they match TitlesToInclude.
        Defaults to: Network Relationship Manager, Project Manager, Care Manager, Case Manager.

        .EXAMPLE
        Update-PeopleLeadersGroup

        Synchronizes the default 'All People Leaders' group with current people leaders from Active Directory.

        .EXAMPLE
        Update-PeopleLeadersGroup -GroupName 'Leadership Team'

        Synchronizes the 'Leadership Team' group instead of the default group name.

        .EXAMPLE
        Update-PeopleLeadersGroup -WhatIf

        Shows what changes would be made without actually adding or removing group members.

        .EXAMPLE
        Update-PeopleLeadersGroup -TitlesToInclude 'Director', 'VP' -TitlesToExclude 'Director of Volunteers'

        Uses custom title inclusion and exclusion lists instead of the defaults.

        .EXAMPLE
        Update-PeopleLeadersGroup -LogFilePath 'C:\Logs\PeopleLeaders.log'

        Writes the log to a custom file path.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [ValidatePattern('^[^"\/\\\[\]:;\|=,\+\*\?<>]+$')]
        [string]$GroupName = 'All People Leaders',

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$LogFilePath = (Join-Path -Path $PWD -ChildPath 'PeopleLeadersGroup.log'),

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string[]]$TitlesToInclude = @('Chief', 'President', 'Director', 'Manager', 'Supervisor'),

        [Parameter()]
        [string[]]$TitlesToExclude = @('Network Relationship Manager', 'Project Manager', 'Care Manager', 'Case Manager')
    )

    function Write-LogFile {
        [CmdletBinding()]
        param (
            [switch]$NoTimeStamp,
            [string]$Log,
            [switch]$Header
        )

        if ($NoTimeStamp -and $Log) {
            $Log | Out-File $LogFilePath -Append
        } elseif ($Log) {
            $TimeStamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
            "`n$TimeStamp `t $Log" | Out-File $LogFilePath -Append
        }

        if ($Header) {
            '----------------------------' | Out-File $LogFilePath -Append
            'Running PeopleLeaders Script' | Out-File $LogFilePath -Append
            Get-Date -Format 'yyyy-MM-dd HH:mm:ss' | Out-File $LogFilePath -Append
            '----------------------------' | Out-File $LogFilePath -Append
        }

        if (-not $Log -and -not $Header) {
            Write-Verbose 'No log output was provided.'
        }
    }

    #region Start
    $LogDirectory = Split-Path -Path $LogFilePath -Parent
    if (-not (Test-Path -Path $LogDirectory)) {
        New-Item -Path $LogDirectory -ItemType Directory -Force | Out-Null
    }
    Write-LogFile -Header
    Import-Module ActiveDirectory

    # Verify the target group exists before proceeding.
    try {
        $null = Get-ADGroup -Identity $GroupName
    } catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException] {
        Write-LogFile -Log "The group '$GroupName' was not found in Active Directory."
        Write-Error "The group '$GroupName' was not found in Active Directory. Please create the group first or specify an existing group name."
        return
    }
    #endregion Start

    # Make valid regex strings with escape characters where needed in the inclusion and exclusion strings.
    $RegExInclude = ( ($TitlesToInclude | ForEach-Object { [regex]::Escape($_) }) -join '|' )
    $RegExExclude = if ($TitlesToExclude) {
        ( ($TitlesToExclude | ForEach-Object { [regex]::Escape($_) }) -join '|' )
    } else {
        $null
    }

    # Find all enabled users in Active Directory that have direct reports
    # where their title is in the TitlesToInclude list and not in the TitlesToExclude list.
    $PeopleLeaders = ( Get-ADUser -Properties Title, DirectReports -Filter { Enabled -eq 'True' -and DirectReports -like '*' }
    ).Where({ $_.Title -match $RegExInclude -and (-not $RegExExclude -or $_.Title -notmatch $RegExExclude) })
    Write-LogFile -Log "$($PeopleLeaders.Count) people leaders found."

    # Add any missing group members
    $GroupMembers = Get-ADGroupMember -Identity $GroupName
    if ($GroupMembers) {
        $AddToGroup = (Compare-Object -ReferenceObject $GroupMembers -DifferenceObject $PeopleLeaders -Property DistinguishedName |
            Where-Object { $_.SideIndicator -eq '=>' }).DistinguishedName |
            ForEach-Object { Get-ADUser -Identity $_ }
    } else {
        $AddToGroup = $PeopleLeaders
    }

    # Add new people leaders to the relevant Active Directory group
    if ($AddToGroup) {
        Write-LogFile "$($AddToGroup.Count) new people leaders found."
        if ($PSCmdlet.ShouldProcess($GroupName, "Add $($AddToGroup.Count) members")) {
            try {
                Add-ADGroupMember -Identity $GroupName -Members $AddToGroup -Confirm:$false
                Write-LogFile "$($AddToGroup.Count) people leaders added to `"$GroupName`"."
            } catch {
                Write-LogFile "A problem occurred while adding users to `"$GroupName`": $($_.Exception.Message)"
            }
        }
    } else {
        Write-LogFile 'No new people leaders found.'
    }

    # Remove group members who are no longer people leaders:
    # Get current members of the group.
    $GroupMembers = Get-ADGroupMember -Identity $GroupName
    # Compare current members of the group with the freshly queried PeopleLeaders array.
    $RemoveFromGroup = (Compare-Object -ReferenceObject $PeopleLeaders -DifferenceObject $GroupMembers -Property DistinguishedName |
        Where-Object { $_.SideIndicator -eq '=>' }).DistinguishedName |
        ForEach-Object { Get-ADUser -Identity $_ }
    # If any users exist in $RemoveFromGroup, remove them from the group.
    if ($RemoveFromGroup) {
        if ($PSCmdlet.ShouldProcess($GroupName, "Remove $($RemoveFromGroup.Count) members")) {
            try {
                Remove-ADGroupMember -Identity $GroupName -Members $RemoveFromGroup -Confirm:$false
                Write-LogFile "$($RemoveFromGroup.Count) users removed from `"$GroupName`": "
                $RemoveFromGroup | Sort-Object Name, Title | Format-Table @{Name = 'Action'; Expression = { 'Removed' } }, Name, Title |
                    Out-File -FilePath $LogFilePath -Append
            } catch {
                Write-LogFile "A problem occurred while removing users from `"$GroupName`": $($_.Exception.Message)"
            }
        }
    } else {
        Write-LogFile "0 users removed from `"$GroupName`"."
    }
    Write-LogFile -Log '-----------------'
    Write-LogFile -Log 'Script Completed.'
}

Update-PeopleLeadersGroup
