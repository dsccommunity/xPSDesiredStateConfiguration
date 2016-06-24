<#
    Implementatation Notes

    Managing Disposable Objects
        The types PrincipalContext, Principal, and DirectoryEntry are used througout the code and
        all are disposable. However, in many cases, disposing the object immediately causes
        subsequent operations to fail or duplicate dispose calls to occur.
        
        To simplify management of these disposables, each public entry point defines a $disposables
        ArrayList variable and passes it to secondary functions that may need to create disposable
        objects. The public entry point is then required to dispose the contents of the list in a
        finally block.

    Managing PrincipalContext Instances
        To use the AccountManagement APIs to connect to the local machine or a domain, a
        PrincipalContext is needed.

        For the local groups and users, a PrincipalContext reflecting the current user can be
        created.

        For the default domain, the domain where the machine is joined, explicit credentials are
        needed since the default user context is SYSTEM which has no rights to the domain.

        Additional PrincipalContext instances may be needed when the machine is in a domain that is
        part of a multi-domain forest. For example, Microsoft uses a multi-domain forest that
        includes domains such as ntdev, redmond, wingroup and a group may have members that
        span multiple domains. Unless the enterprise implements the Global Catalog,
        something that Microsoft does not do, a unique PrincipalContext is needed to resolve
        accounts in each of the domains.

        To manage the use of PrincipalContext across domains, public entry points define a
        $principalContexts hashtable and pass it to support functions that need to resolve a group
        or group member. Consumers of a PrincipalContext call Get-PrincipalContext with a scope
        (domain name or machine name). Get-PrincipalContext returns an existing hashtable entry or
        creates a new entry.  Note that a PrincipalContext to a target domain requires connecting
        to the domain. The hashtable avoids subsequent connection calls. Also note that
        Get-PrincipalContext takes a Credential parameter for the case where a new PrincipalContext
        is needed. The implicit assumption is that the credential provided for the primary domain
        also has rights to resolve accounts in any of the other domains.

    Resolving Group Members
        The original implementation assumed that group members could be resolved using the machine
        PrincipalContext or the logged on user. In practice this is not reliable since the resource
        is typically run under the SYSTEM account and this account is not guaranteed to have rights
        to resolve domain accounts. Additionally, the APIs for enumerating group members do not
        provide a facility for passing additional credentials resulting in domain members failing
        to resolve.

        To address this, group members are enumerated by first converting the GroupPrincipal to a
        DirectoryEntry and enumerating its child members. The returned DirectoryEntry instances are
        then resolved to Principal objects using a PrincipalContext appropriate for the target
        domain.
        
        See Resolve-GroupMembersToPrincipals for more details.

    Handling Stale Group Members
        A group may have stale members if the machine was moved from one domain to a another
        foreign domain or when accounts are deleted (domain or local). At this point, members that
        were defined in the original domain or were deleted are now stale and cannot be resolved
        using Principal::FindByIdentity. The original implementation failed at this point
        preventing any operations against the group. The current implementation calls Write-Warning
        with the associated SID of the member that cannot be resolved then continues the operation.
#>

# A global variable that contains localized messages.
data LocalizedData
{
# culture="en-US"
ConvertFrom-StringData @'
GroupWithName = Group: {0}
RemoveOperation = Remove
AddOperation = Add
SetOperation = Set
GroupCreated = Group {0} created successfully.
GroupUpdated = Group {0} properties updated successfully.
GroupRemoved = Group {0} removed successfully.
NoConfigurationRequired = Group {0} exists on this node with the desired properties. No action required.
NoConfigurationRequiredGroupDoesNotExist = Group {0} does not exist on this node. No action required.
CouldNotFindPrincipal = Could not find a principal with the provided name [{0}]
MembersAndIncludeExcludeConflict = The {0} and {1} and/or {2} parameters conflict. The {0} parameter should not be used in any combination with the {1} and {2} parameters.
MembersIsNull = The Members parameter value is null. The {0} parameter must be provided if neither {1} nor {2} is provided.
MembersIsEmpty = The Members parameter is empty.  At least one group member must be provided.
MemberNotValid = The group member does not exist or cannot be resolved: {0}.
IncludeAndExcludeConflict = The principal {0} is included in both {1} and {2} parameter values. The same principal must not be included in both {1} and {2} parameter values.
IncludeAndExcludeAreEmpty = The MembersToInclude and MembersToExclude are either both null or empty.  At least one member must be specified in one of these parameters"
InvalidGroupName = The name {0} cannot be used. Names may not consist entirely of periods and/or spaces, or contain these characters: {1}
GroupExists = A group with the name {0} exists.
GroupDoesNotExist = A group with the name {0} does not exist.
PropertyMismatch = The value of the {0} property is expected to be {1} but it is {2}.
MembersNumberMismatch = Property {0}. The number of provided unique group members {1} is different from the number of actual group members {2}.
MembersMemberMismatch = At least one member {0} of the provided {1} parameter does not have a match in the existing group {2}.
MemberToExcludeMatch = At least one member {0} of the provided {1} parameter has a match in the existing group {2}.
ResolvingLocalAccount = Resolving {0} as a local account.
ResolvingDomainAccount = Resolving {0} in the {1} domain.
ResolvingDomainAccountWithTrust = Resolving {0} with domain trust.
DomainCredentialsRequired = Credentials are required to resolve the domain account {0}.
UnableToResolveAccount = Unable to resolve account '{0}'. Failed with message: {1} (error code={2})
'@
}

Import-LocalizedData -BindingVariable 'LocalizedData' -FileName 'MSFT_xGroupResource.strings.psd1'

Import-Module -Name "$PSScriptRoot\..\CommonResourceHelper.psm1"

if (-not (Test-IsNanoServer))
{
    Add-Type -AssemblyName 'System.DirectoryServices.AccountManagement'
}

function Get-TargetResource
{
    [OutputType([Hashtable])]
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String] $GroupName,

        [PSCredential] $Credential
    )

    if (Test-IsNanoServer)
    {
        return Get-TargetResourceOnNanoServer @PSBoundParameters
    }
    else
    {
        return Get-TargetResourceOnFullSKU @PSBoundParameters
    }
}

function Set-TargetResource
{
    [CmdletBinding(SupportsShouldProcess = $true)]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String] $GroupName,

        [ValidateSet('Present', 'Absent')]
        [String] $Ensure = 'Present',

        [String] $Description,

        [String[]] $Members,

        [String[]] $MembersToInclude,

        [String[]] $MembersToExclude,

        [ValidateNotNullOrEmpty()]
        [PSCredential] $Credential
    )

    if (Test-IsNanoServer)
    {
        Set-TargetResourceOnNanoServer @PSBoundParameters
    }
    else
    {
        Set-TargetResourceOnFullSKU @PSBoundParameters
    }
}

function Test-TargetResource
{
    [OutputType([Boolean])]
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String] $GroupName,

        [ValidateSet('Present', 'Absent')]
        [String] $Ensure = 'Present',

        [String] $Description,

        [String[]] $Members,

        [String[]] $MembersToInclude,

        [String[]] $MembersToExclude,

        [ValidateNotNullOrEmpty()]
        [PSCredential] $Credential
    )

    if (Test-IsNanoServer)
    {
        return Test-TargetResourceOnNanoServer @PSBoundParameters
    }
    else
    {
        return Test-TargetResourceOnFullSKU @PSBoundParameters
    }
}

<#
    .SYNOPSIS
        The Get-TargetResource cmdlet for a full server.
#>
function Get-TargetResourceOnFullSKU
{
    [OutputType([Hashtable])]
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]
        $GroupName,

        [PSCredential]
        $Credential
    )

    Set-StrictMode -Version 'Latest'

    Assert-GroupNameValid -GroupName $GroupName

    $disposables = New-Object -TypeName 'System.Collections.ArrayList'

    $principalContexts = @{}

    try
    {
        [System.DirectoryServices.AccountManagement.GroupPrincipal] $group = GetGroup -groupName $GroupName -principalContexts $principalContexts -disposables $disposables
        
        if($group -ne $null)
        {
            $null = $disposables.Add($group)

            # The group is found. Enumerate all group members.
            $members = [String[]]@(EnumerateMembersOnFullSKU -Group $group -principalContexts $principalContexts -disposables $disposables -credential $Credential)

            # Return all group properties and Ensure="Present".
            $returnValue = @{
                                GroupName = $group.Name;
                                Ensure = "Present";
                                Description = $group.Description;
                                Members = [System.String[]] $members;
                            }

            return $returnValue
        }

        # The group is not found. Return Ensure=Absent.
        return @{
                    GroupName = $GroupName;
                    Ensure = "Absent";
                }
    }
    finally
    {
        DisposeAll $disposables
    }
}

<#
.Synopsis
The Set-TargetResource cmdlet for Full SKU images.
#>
function Set-TargetResourceOnFullSKU
{
    [CmdletBinding(SupportsShouldProcess=$true)]
    param
    (
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $GroupName,

        [ValidateSet("Present", "Absent")]
        [System.String]
        $Ensure = "Present",

        [System.String]
        $Description,

        [System.String[]]
        $Members,

        [System.String[]]
        $MembersToInclude,

        [System.String[]]
        $MembersToExclude,

        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.PSCredential]
        $Credential
    )

    Set-StrictMode -Version Latest

    Assert-GroupNameValid -GroupName $GroupName

    # store disposable objects in a list for cleanup later.
    # This is needed for the case where utility functions need to create
    # disposable objects (Principal and PrincipalContext) and the
    # object's life time is longer than the function. The $disposables
    # collection is passed to these functions for storing the disposable objects
    # and this function disposes the contents prior to returning.
    # See references to DisposeAll for details.
    $disposables = New-Object System.Collections.ArrayList

    # hash table of scope to PrincipalContext. This is used for
    # cases where the group membership contains entries that span the machine
    # and one or more domains. The hashtable's key is the machine or domain
    # name (scope) while the value is the PrincipalContext to use to resolve accounts
    # within the named scope.
    $principalContexts = @{}

    try
    {
        # Try to find a group by its name.
        [System.DirectoryServices.AccountManagement.GroupPrincipal] $group = GetGroup -groupName $GroupName -principalContexts $principalContexts -disposables $disposables
        [bool] $groupExists = $false

        if ($group -ne $null)
        {
            $groupExists = $true
        }

        if($Ensure -eq "Present")
        {
            [System.DirectoryServices.AccountManagement.Principal[]] $membersToIncludePrincipals = $null
            [System.DirectoryServices.AccountManagement.Principal[]] $membersToExcludePrincipals = $null

            if ($group -ne $null)
            {
                $null = $disposables.Add($group)
            }

            # Ensure is set to "Present".

            [bool] $whatIfShouldProcess = $true
            [bool] $saveChanges = $false

            if(-not $groupExists)
            {
                # A group does not exist. Check WhatIf for adding a group.
                $whatIfShouldProcess = $pscmdlet.ShouldProcess(($LocalizedData.GroupWithName -f $GroupName), $LocalizedData.AddOperation)
            }
            else
            {
                # Check WhatIf for setting a group.
                $whatIfShouldProcess = $pscmdlet.ShouldProcess(($LocalizedData.GroupWithName -f $GroupName), $LocalizedData.SetOperation)
            }

            if($whatIfShouldProcess)
            {
                if(-not $groupExists)
                {
                    # NOTE: The PrincipalContext for the local machine is populated above in the call to GetGroup
                    $localPrincipalContext = $principalContexts[$env:COMPUTERNAME]

                    # The group with the provided name does not exist. Add a new group.
                    $group = New-Object System.DirectoryServices.AccountManagement.GroupPrincipal($localPrincipalContext)
                    $null = $disposables.Add($group)

                    $group.Name = $GroupName
                    $saveChanges = $true
                }

                # Set group properties.

                if($PSBoundParameters.ContainsKey('Description') -and ((-not $groupExists) -or ($Description -ne $group.Description)))
                {
                    $group.Description = $Description
                    $saveChanges = $true
                }

                # NOTE: Group members can be updated in two ways..
                # 1: Supplying the Members parameter - this causes the membership to be replaced with the members defined in Members.
                #    NOTE: If Members is empty, the group membership is cleared.
                # 2: Providing MembersToInclude and/or MembersToExclude - this adds/removes members from the list.
                #    If Members is mutually exclusive with MembersToInclude and MembersToExclude
                #    If Members is not defined then MembersToInclude or MembersToExclude must contain at least one entry.

                if($PSBoundParameters.ContainsKey('Members'))
                {
                    if($PSBoundParameters.ContainsKey('MembersToInclude') -or $PSBoundParameters.ContainsKey('MembersToExclude'))
                    {
                        # If Members are provided, Include and Exclude are not allowed.
                        ThrowInvalidArgumentError -ErrorId "GroupTestCmdlet_MembersPlusIncludeOrExcludeConflict" -ErrorMessage ($LocalizedData.MembersAndIncludeExcludeConflict -f "Members","MembersToInclude","MembersToExclude")
                    }

                    if($Members -eq $null)
                    {
                        ThrowInvalidArgumentError -ErrorId "GroupTestCmdlet_MembersIsNull" -ErrorMessage ($LocalizedData.MembersIsNull -f "Members","MembersToInclude","MembersToExclude")
                    }

                    if ($Members.Count -eq 0)
                    {
                        $group.Members.Clear()
                        $saveChanges = $true
                    }
                    else
                    {
                        # Remove duplicate names as strings.
                        $Members = [String[]]@(RemoveDuplicates -Members $Members)

                        # Resolve the names to actual principal objects.
                        [System.DirectoryServices.AccountManagement.Principal[]]$expectedPrincipals = ResolveNamesToPrincipals -principalContexts $principalContexts -Disposables $disposables -credential $Credential -ObjectNames $Members

                        if ($expectedPrincipals.Length -gt 0)
                        {
                            $group.Members.Clear()
                            # Set the contents of the group
                            if ((AddGroupMembers -Group $group -Principals $expectedPrincipals) -eq $true)
                            {
                                $saveChanges = $true
                            }
                        }
                        else
                        {
                            #ISSUE: Is an empty $Members parameter valid?
                            ThrowInvalidArgumentError -ErrorId "GroupSetCmdlet_MembersEmpty" -ErrorMessage ($LocalizedData.MembersIsEmpty)
                        }
                    }
                }
                else
                {
                    [System.DirectoryServices.AccountManagement.Principal[]] $membersToIncludePrincipals = $null
                    [System.DirectoryServices.AccountManagement.Principal[]] $membersToExcludePrincipals = $null

                    if($PSBoundParameters.ContainsKey('MembersToInclude'))
                    {
                        $MembersToInclude = [String[]]@(RemoveDuplicates -Members $MembersToInclude)

                        # Resolve the names to actual principal objects.
                        $membersToIncludePrincipals = ResolveNamesToPrincipals -principalContexts $principalContexts -Disposables $disposables -credential $Credential -ObjectNames $MembersToInclude
                    }

                    if($PSBoundParameters.ContainsKey('MembersToExclude'))
                    {
                        $MembersToExclude = [String[]]@(RemoveDuplicates -Members $MembersToExclude)

                        # Resolve the names to actual principal objects.
                        $membersToExcludePrincipals = ResolveNamesToPrincipals -principalContexts $principalContexts -Disposables $disposables -credential $Credential -ObjectNames $MembersToExclude
                    }

                    if($membersToIncludePrincipals -ne $null -and $membersToExcludePrincipals -ne $null)
                    {
                        # Both MembersToInclude and MembersToExlude were provided. Check if they have common principals.
                        foreach($includePrincipal in $membersToIncludePrincipals)
                        {
                            foreach($excludePrincipal in $membersToExcludePrincipals)
                            {
                                if($includePrincipal -eq $excludePrincipal)
                                {
                                    ThrowInvalidArgumentError -ErrorId "GroupSetCmdlet_IncludeAndExcludeConflict" -ErrorMessage ($LocalizedData.IncludeAndExcludeConflict -f $includePrincipal.SamAccountName,"MembersToInclude", "MembersToExclude")
                                }
                            }
                        }
                        if ($membersToIncludePrincipals.Length -eq 0 -and $membersToExcludePrincipals.Length -eq 0)
                        {
                            ThrowInvalidArgumentError -ErrorId "GroupSetCmdlet_EmptyIncludeAndExclude" -ErrorMessage ($LocalizedData.IncludeAndExcludeAreEmpty)
                        }
                    }


                    if ((RemoveGroupMembers -Group $group -Principals $membersToExcludePrincipals) -eq $true)
                    {
                        $saveChanges = $true
                    }

                    if ((AddGroupMembers -Group $group -Principals $membersToIncludePrincipals) -eq $true)
                    {
                        $saveChanges = $true
                    }
                }

                if($saveChanges)
                {
                    $group.Save()

                    # Send an operation success verbose message.
                    if($groupExists)
                    {
                        Write-Verbose -Message ($LocalizedData.GroupUpdated -f $GroupName)
                    }
                    else
                    {
                        Write-Verbose -Message ($LocalizedData.GroupCreated -f $GroupName)
                    }
                }
                else
                {
                    Write-Verbose -Message ($LocalizedData.NoConfigurationRequired -f $GroupName)
                }
            }
        }
        else
        {
            # Ensure is set to "Absent".
            if($groupExists -eq $true)
            {
                # The group exists.
                if($pscmdlet.ShouldProcess(($LocalizedData.GroupWithName -f $GroupName), $LocalizedData.RemoveOperation))
                {
                    # Remove the group by the provided name.
                    # NOTE: Don't add to $disposables since Delete also disposes.
                    $group.Delete()
                    Write-Verbose -Message ($LocalizedData.GroupRemoved -f $GroupName)
                }
                else
                {
                    $null = $disposables.Add($group)
                }
            }
            else
            {
                Write-Verbose -Message ($LocalizedData.NoConfigurationRequiredGroupDoesNotExist -f $GroupName)
            }
        }
    }
    finally
    {
        DisposeAll $disposables
    }
}

<#
.Synopsis
The Test-TargetResource cmdlet for Full SKU images is used to validate if the resource is in a state as expected in the instance document.
#>
function Test-TargetResourceOnFullSKU
{
    param
    (
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $GroupName,

        [ValidateSet("Present", "Absent")]
        [System.String]
        $Ensure = "Present",

        [System.String]
        $Description,

        [System.String[]]
        $Members,

        [System.String[]]
        $MembersToInclude,

        [System.String[]]
        $MembersToExclude,

        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.PSCredential]
        $Credential
    )

    Set-StrictMode -Version Latest

    Assert-GroupNameValid -GroupName $GroupName

    # store disposable objects in a list for cleanup later.
    # This is needed for the case where utility functions need to create
    # disposable objects (Principal and PrincipalContext) and the
    # object's life time is longer than the function. The $disposables
    # collection is passed to these functions for storing the disposable objects
    # and this function disposes the contents prior to returning.
    # See references to DisposeAll for details.
    $disposables = New-Object System.Collections.ArrayList

    # hash table of scope to PrincipalContext. This is used for
    # cases where the group membership contains entries that span the machine
    # and one or more domains. The hashtable's key is the machine or domain
    # name (scope) while the value is the PrincipalContext to use to resolve accounts
    # within the named scope.
    $principalContexts = @{}

    try
    {
        [System.DirectoryServices.AccountManagement.GroupPrincipal] $group = GetGroup -groupName $GroupName -principalContexts $principalContexts -disposables  $disposables
        if($group -eq $null)
        {
            # A group with the provided name does not exist.
            Write-Log -Message ($LocalizedData.GroupDoesNotExist -f $GroupName)

            if($Ensure -eq "Absent")
            {
                return $true
            }
            else
            {
                return $false
            }
        }
        $null = $disposables.Add($group)

        # A group with the provided name exists.
        Write-Log -Message ($LocalizedData.GroupExists -f $GroupName)

        # Validate separate properties.
        if($Ensure -eq "Absent")
        {
            Write-Log -Message ($LocalizedData.PropertyMismatch -f "Ensure", "Absent", "Present")
            return $false # The Ensure property does not match. Return $false
        }

        if($PSBoundParameters.ContainsKey('GroupName') -and $GroupName -ne $group.SamAccountName -and $GroupName -ne $group.Sid.Value)
        {
            return $false # The Name property does not match. Return $false
        }

        if($PSBoundParameters.ContainsKey('Description') -and $Description -ne $group.Description)
        {
            Write-Log -Message ($LocalizedData.PropertyMismatch -f "Description", $Description, $group.Description)
            return $false # The Description property does not match. Return $false
        }

        if($PSBoundParameters.ContainsKey('Members'))
        {
            if($PSBoundParameters.ContainsKey('MembersToInclude') -or $PSBoundParameters.ContainsKey('MembersToExclude'))
            {
                # If Members are provided, Include and Exclude are not allowed.
                ThrowInvalidArgumentError -ErrorId "GroupTestCmdlet_MembersPlusIncludeOrExcludeConflict" -ErrorMessage ($LocalizedData.MembersAndIncludeExcludeConflict -f "Members","MembersToInclude","MembersToExclude")
            }

            if($Members -eq $null)
            {
                ThrowInvalidArgumentError -ErrorId "GroupTestCmdlet_MembersIsNull" -ErrorMessage ($LocalizedData.MembersIsNull -f "Members","MembersToInclude","MembersToExclude")
            }

            if ($Members.Count -eq 0)
            {
                if ($group.Members.Count -eq 0)
                {
                    return $true
                }
                else
                {
                    return $false
                }
            }
            else
            {
                # Remove duplicate names as strings.
                $Members = [String[]]@(RemoveDuplicates -Members $Members)

                # Resolve the names to actual principal objects.
                [System.DirectoryServices.AccountManagement.Principal[]] $expectedMembers = ResolveNamesToPrincipals -principalContexts $principalContexts -Disposables $disposables -credential $Credential -ObjectNames $Members

                if($expectedMembers.Length -ne $group.Members.Count)
                {
                    Write-Log -Message ($LocalizedData.MembersNumberMismatch -f "Members", $expectedMembers.Length, $group.Members.Count)
                    return $false; # The number of provided unique group members is different from the number of actual group members. Return $false.
                }

                [System.DirectoryServices.AccountManagement.Principal[]] $actualMembers = ResolveGroupMembersToPrincipals -group $group -principalContexts $principalContexts -disposables $disposables -credential $Credential

                # Compare two members lists.
                foreach ($expectedMember in $expectedMembers)
                {
                    $matchFound = $false

                    foreach($groupMember in $actualMembers)
                    {
                        if($expectedMember -eq $groupMember)
                        {
                            $matchFound = $true
                            break;
                        }
                    }

                    if(!$matchFound)
                    {
                        Write-Log -Message ($LocalizedData.MembersMemberMismatch -f $expectedMember.SamAccountName, "Members", $group.SamAccountName)
                        return $false # At least one element does not have a match. Return $false
                    }
                }
            }
        }
        else
        {
            [System.DirectoryServices.AccountManagement.Principal[]] $actualMembers = ResolveGroupMembersToPrincipals -group $group -principalContexts $principalContexts -disposables $disposables -credential $Credential

            if($PSBoundParameters.ContainsKey('MembersToInclude'))
            {
                $MembersToInclude = [String[]]@(RemoveDuplicates -Members $MembersToInclude)

                # Resolve the names to actual principal objects.
                [System.DirectoryServices.AccountManagement.Principal[]] $membersToIncludePrincipals = ResolveNamesToPrincipals -principalContexts $principalContexts -Disposables $disposables -credential $Credential -ObjectNames $MembersToInclude

                # Check if every element in $membersToIncludePrincipals has a match in $group.Members.
                # Compare two members lists.
                foreach($expectedMember in $membersToIncludePrincipals)
                {
                    $matchFound = $false

                    foreach($groupMember in $actualMembers)
                    {
                        if($expectedMember -eq $groupMember)
                        {
                            $matchFound = $true
                            break
                        }
                    }

                    if(!$matchFound)
                    {
                        Write-Log -Message ($LocalizedData.MembersMemberMismatch -f $expectedMember.SamAccountName, "MembersToInclude", $group.SamAccountName)
                        return $false # At least one element from $MembersToInclude does not have a match. Return $false
                    }
                }
            }

            if($PSBoundParameters.ContainsKey('MembersToExclude'))
            {
                $MembersToExclude = [String[]]@(RemoveDuplicates -Members $MembersToExclude);

                # Resolve the names to actual principal objects.
                [System.DirectoryServices.AccountManagement.Principal[]] $membersToExcludePrincipals = ResolveNamesToPrincipals -principalContexts $principalContexts -Disposables $disposables -credential $Credential -ObjectNames $MembersToExclude

                foreach($expectedMember in $membersToExcludePrincipals)
                {
                    foreach($groupMember in $actualMembers)
                    {
                        if($expectedMember -eq $groupMember)
                        {
                            Write-Log -Message ($LocalizedData.MemberToExcludeMatch -f $expectedMember.SamAccountName, "MembersToExclude", $group.SamAccountName)
                            return $false  # At least one element from $MembersToExclude has a match. Return $false
                        }
                    }
                }
            }
        }
    }
    finally
    {
        DisposeAll $disposables
    }

    # All properties match. Return $true.
    return $true;
}

<#
.Synopsis
The Get-TargetResource cmdlet for Nano Server images.
#>
function Get-TargetResourceOnNanoServer
{
    param
    (
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $GroupName,

        [System.Management.Automation.PSCredential]
        $Credential = $null
    )

    Set-StrictMode -Version Latest

    Assert-GroupNameValid -GroupName $GroupName

    try
    {
        [Microsoft.PowerShell.Commands.LocalGroup] $group = Get-LocalGroup -Name $GroupName -ErrorAction Stop
    }
    catch [System.Exception]
    {
        if ($_.CategoryInfo.Reason -eq 'GroupNotFoundException')
        {
            # The group is not found. Return Ensure=Absent.
            return @{
                        GroupName = $GroupName;
                        Ensure = "Absent";
                    }
        }
        Throw-TerminatingError -ErrorRecord $_
    }

    # The group is found. Enumerate all group members.
    $members = [String[]](EnumerateMembersOnNanoServer -Group $group)

    # Return all group properties and Ensure="Present".
    $returnValue = @{
                        GroupName = $group.Name;
                        Ensure = "Present";
                        Description = $group.Description;
                        Members = [System.String[]] $members;
                    }
    
    return $returnValue
}

<#
.Synopsis
The Set-TargetResource cmdlet for Nano Server images.
#>
function Set-TargetResourceOnNanoServer
{
    [CmdletBinding(SupportsShouldProcess=$true)]
    param
    (
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $GroupName,

        [ValidateSet("Present", "Absent")]
        [System.String]
        $Ensure = "Present",

        [System.String]
        $Description,

        [System.String[]]
        $Members,

        [System.String[]]
        $MembersToInclude,

        [System.String[]]
        $MembersToExclude,

        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.PSCredential]
        $Credential
    )

    Set-StrictMode -Version Latest

    Assert-GroupNameValid -GroupName $GroupName
    
    # Try to find a group by its name.
    [bool] $groupExists = $false
    try
    {
        [Microsoft.PowerShell.Commands.LocalGroup] $group = Get-LocalGroup -Name $GroupName -ErrorAction Stop
        $groupExists = $true
    }
    catch [System.Exception]
    {
        if ($_.CategoryInfo.Reason -eq 'GroupNotFoundException')
        {
            # A group with the provided name does not exist.
            Write-Log -Message ($LocalizedData.GroupDoesNotExist -f $GroupName)
        }
        else
        {
            Throw-TerminatingError -ErrorRecord $_
        }
    }

    if($Ensure -eq "Present")
    {
        # Ensure is set to "Present".
        if(-not $groupExists)
        {
            # The group with the provided name does not exist. Add a new group.
            New-LocalGroup -Name $GroupName
            Write-Verbose -Message ($LocalizedData.GroupCreated -f $GroupName)
        }
    
        # Set group properties.
        
        if($PSBoundParameters.ContainsKey('Description') -and ((-not $groupExists) -or ($Description -ne $group.Description)))
        {
            Set-LocalGroup -Name $GroupName -Description $Description
        }
        
        # NOTE: Group members can be updated in two ways..
        # 1: Supplying the Members parameter - this causes the membership to be replaced with the members defined in Members.
        #    NOTE: If Members is empty, the group membership is cleared.
        # 2: Providing MembersToInclude and/or MembersToExclude - this adds/removes members from the list.
        #    If Members is mutually exclusive with MembersToInclude and MembersToExclude
        #    If Members is not defined then MembersToInclude or MembersToExclude must contain at least one entry.
        
        if($PSBoundParameters.ContainsKey('Members'))
        {
            if($PSBoundParameters.ContainsKey('MembersToInclude') -or $PSBoundParameters.ContainsKey('MembersToExclude'))
            {
                # If Members are provided, Include and Exclude are not allowed.
                ThrowInvalidArgumentError -ErrorId "GroupTestCmdlet_MembersPlusIncludeOrExcludeConflict" -ErrorMessage ($LocalizedData.MembersAndIncludeExcludeConflict -f "Members","MembersToInclude","MembersToExclude")
            }
        
            if($Members -eq $null)
            {
                ThrowInvalidArgumentError -ErrorId "GroupTestCmdlet_MembersIsNull" -ErrorMessage ($LocalizedData.MembersIsNull -f "Members","MembersToInclude","MembersToExclude")
            }
        
            # Remove duplicate names as strings.
            $ExpectedMembers = [String[]]@(RemoveDuplicates -Members $Members)
        
            if ($ExpectedMembers.Length -gt 0)
            {
                # Get current members
                $CurrentMembers = EnumerateMembersOnNanoServer -Group $group

                # Remove the current members of the group
                Remove-LocalGroupMember -Group $GroupName -Member $CurrentMembers

                # Add the list of expected members to the group
                Add-LocalGroupMember -Group $GroupName -Member $ExpectedMembers
            }
            else
            {
                ThrowInvalidArgumentError -ErrorId "GroupSetCmdlet_MembersEmpty" -ErrorMessage ($LocalizedData.MembersIsEmpty)
            }
        }
        else
        {
            if($PSBoundParameters.ContainsKey('MembersToInclude'))
            {
                $MembersToInclude = [String[]]@(RemoveDuplicates -Members $MembersToInclude)
            }
       
            if($PSBoundParameters.ContainsKey('MembersToExclude'))
            {
                $MembersToExclude = [String[]]@(RemoveDuplicates -Members $MembersToExclude)
            }
       
            if($PSBoundParameters.ContainsKey('MembersToInclude') -and $PSBoundParameters.ContainsKey('MembersToExclude'))
            {
                # Both MembersToInclude and MembersToExlude were provided. Check if they have common principals.
                foreach($includeMember in $MembersToInclude)
                {
                    foreach($excludeMember in $MembersToExclude)
                    {
                        if($includeMember -eq $excludeMember)
                        {
                            ThrowInvalidArgumentError -ErrorId "GroupSetCmdlet_IncludeAndExcludeConflict" -ErrorMessage ($LocalizedData.IncludeAndExcludeConflict -f $includeMember ,"MembersToInclude", "MembersToExclude")
                        }
                    }
                }
                if ($MembersToInclude.Length -eq 0 -and $MembersToExclude.Length -eq 0)
                {
                    ThrowInvalidArgumentError -ErrorId "GroupSetCmdlet_EmptyIncludeAndExclude" -ErrorMessage ($LocalizedData.IncludeAndExcludeAreEmpty)
                }
            }
            
            if($PSBoundParameters.ContainsKey('MembersToInclude'))
            {
                foreach($includeMember in $MembersToInclude)
                {
                    try
                    {
                        Add-LocalGroupMember -Group $GroupName -Member $includeMember -ErrorAction Stop
                    }
                    catch [System.Exception]
                    {
                        if ($_.CategoryInfo.Reason -ne 'MemberExistsException')
                        {
                            throw $_.Exception
                        }
                    }
                }
            }
       
            if($PSBoundParameters.ContainsKey('MembersToExclude'))
            {
                foreach($excludeMember in $MembersToExclude)
                {
                    try
                    {
                        Remove-LocalGroupMember -Group $GroupName -Member $excludeMember -ErrorAction Stop
                    }
                    catch [System.Exception]
                    {
                        if ($_.CategoryInfo.Reason -ne 'MemberNotFoundException')
                        {
                            Throw-TerminatingError -ErrorRecord $_
                        }
                    }
                }
            }
        }
    }
    else
    {
        # Ensure is set to "Absent".
        if($groupExists -eq $true)
        {
            # The group exists. Remove the group by the provided name.
            Remove-LocalGroup -Name $GroupName
            Write-Verbose -Message ($LocalizedData.GroupRemoved -f $GroupName)
        }
        else
        {
            Write-Verbose -Message ($LocalizedData.NoConfigurationRequiredGroupDoesNotExist -f $GroupName)
        }
    }
}

<#
.Synopsis
The Test-TargetResource cmdlet for Nano Server images is used to validate if the resource is in a state as expected in the instance document.
#>
function Test-TargetResourceOnNanoServer
{
    param
    (
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $GroupName,

        [ValidateSet("Present", "Absent")]
        [System.String]
        $Ensure = "Present",

        [System.String]
        $Description,

        [System.String[]]
        $Members,

        [System.String[]]
        $MembersToInclude,

        [System.String[]]
        $MembersToExclude,

        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.PSCredential]
        $Credential
    )

    Set-StrictMode -Version Latest

    Assert-GroupNameValid -GroupName $GroupName

    try
    {
        [Microsoft.PowerShell.Commands.LocalGroup] $group = Get-LocalGroup -Name $GroupName -ErrorAction Stop
    }
    catch [System.Exception]
    {
        if ($_.CategoryInfo.Reason -eq 'GroupNotFoundException')
        {
            # A group with the provided name does not exist.
            Write-Log -Message ($LocalizedData.GroupDoesNotExist -f $GroupName)
        
            if($Ensure -eq "Absent")
            {
                return $true
            }
            else
            {
                return $false
            }
        }
        Throw-TerminatingError -ErrorRecord $_
    }

    # A group with the provided name exists.
    Write-Log -Message ($LocalizedData.GroupExists -f $GroupName)

    # Validate separate properties.
    if($Ensure -eq "Absent")
    {
        Write-Log -Message ($LocalizedData.PropertyMismatch -f "Ensure", "Absent", "Present")
        return $false # The Ensure property does not match. Return $false
    }
    
    if($PSBoundParameters.ContainsKey('Description') -and $Description -ne $group.Description)
    {
        Write-Log -Message ($LocalizedData.PropertyMismatch -f "Description", $Description, $group.Description)
        return $false # The Description property does not match. Return $false
    }
    
    if($PSBoundParameters.ContainsKey('Members'))
    {
        Write-Verbose "Testing members..."
        if($PSBoundParameters.ContainsKey('MembersToInclude') -or $PSBoundParameters.ContainsKey('MembersToExclude'))
        {
            # If Members are provided, Include and Exclude are not allowed.
            ThrowInvalidArgumentError -ErrorId "GroupTestCmdlet_MembersPlusIncludeOrExcludeConflict" -ErrorMessage ($LocalizedData.MembersAndIncludeExcludeConflict -f "Members","MembersToInclude","MembersToExclude")
        }
    
        if($Members -eq $null)
        {
            ThrowInvalidArgumentError -ErrorId "GroupTestCmdlet_MembersIsNull" -ErrorMessage ($LocalizedData.MembersIsNull -f "Members","MembersToInclude","MembersToExclude")
        }
    
        # Remove duplicate names as strings.
        $ExpectedMembers = [String[]]@(RemoveDuplicates -Members $Members)

        # Get current members
        $CurrentMembers = EnumerateMembersOnNanoServer -Group $group
        
        if($ExpectedMembers.Length -ne $CurrentMembers.Length)
        {
            Write-Log -Message ($LocalizedData.MembersNumberMismatch -f "Members", $ExpectedMembers.Length, $CurrentMembers.Length)
            return $false; # The number of provided unique group members is different from the number of actual group members. Return $false.
        }
    
        # Compare two members lists.
        foreach ($ExpectedMember in $ExpectedMembers)
        {
            $matchFound = $false
        
            foreach($groupMember in $CurrentMembers)
            {
                if($ExpectedMember -eq $groupMember)
                {
                    $matchFound = $true
                    break;
                }
            }
        
            if(-not $matchFound)
            {
                Write-Log -Message ($LocalizedData.MembersMemberMismatch -f $expectedMember, "Members", $group.Name)
                return $false # At least one element does not have a match. Return $false
            }
        }
    }
    else
    {
        # Get current members
        $CurrentMembers = EnumerateMembersOnNanoServer -Group $group

        if($PSBoundParameters.ContainsKey('MembersToInclude'))
        {
            $MembersToInclude = [String[]]@(RemoveDuplicates -Members $MembersToInclude)
    
            # Check if every element in $membersToIncludePrincipals has a match in $group.Members.
            # Compare two members lists.
            foreach($expectedMember in $MembersToInclude)
            {
                $matchFound = $false
    
                foreach($groupMember in $CurrentMembers)
                {
                    if($expectedMember -eq $groupMember)
                    {
                        $matchFound = $true
                        break
                    }
                }
    
                if(-not $matchFound)
                {
                    Write-Log -Message ($LocalizedData.MembersMemberMismatch -f $expectedMember, "MembersToInclude", $group.Name)
                    return $false # At least one element from $MembersToInclude does not have a match. Return $false
                }
            }
        }
    
        if($PSBoundParameters.ContainsKey('MembersToExclude'))
        {
            $MembersToExclude = [String[]]@(RemoveDuplicates -Members $MembersToExclude);
    
            foreach($expectedMember in $MembersToExclude)
            {
                foreach($groupMember in $CurrentMembers)
                {
                    if($expectedMember -eq $groupMember)
                    {
                        Write-Log -Message ($LocalizedData.MemberToExcludeMatch -f $expectedMember, "MembersToExclude", $group.Name)
                        return $false  # At least one element from $MembersToExclude has a match. Return $false
                    }
                }
            }
        }
    }

    # All properties match. Return $true.
    return $true;
}

function RemoveDuplicates
{
    param
    (
        [System.String[]] $Members
    )

    Set-StrictMode -Version Latest

    $destIndex = 0;
    for([int] $sourceIndex = 0 ; $sourceIndex -lt $Members.Count; $sourceIndex++)
    {
        $matchFound = $false
        for([int] $matchIndex = 0; $matchIndex -lt $destIndex; $matchIndex++)
        {
            if($Members[$sourceIndex] -eq $Members[$matchIndex])
            {
                # A duplicate is found. Discard the duplicate.
                $matchFound = $true
                continue
            }
        }

        if(!$matchFound)
        {
            $Members[$destIndex++] = $Members[$sourceIndex].ToLowerInvariant();
        }
    }

    # Create the output array.
    $destination = New-Object System.String[] -ArgumentList $destIndex

    # Copy only distinct elements from the original array to the destination array.
    [System.Array]::Copy($Members, $destination, $destIndex);

    if ($destIndex -gt 0)
    {
        return $destination
    }
    return [System.String[]]@()
}

function EnumerateMembersOnNanoServer
{
    [OutputType([System.String[]])]
    param
    (
        [parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [Microsoft.PowerShell.Commands.LocalGroup]
        $Group
    )

    Set-StrictMode -Version Latest
    [System.Collections.ArrayList] $members = New-Object System.Collections.ArrayList

    # Get the group members.
    $groupmembers = Get-LocalGroupMember -Group $Group

    foreach($member in $groupmembers)
    {
        if ($member.PrincipalSource -eq "Local")
        {
            $null = $members.Add($member.Name.Substring($member.Name.IndexOf("\")+1))
        }
        else
        {
            Write-Verbose "$($member.Name) is not a local user (PrincipalSource = $($member.PrincipalSource))"
        }
    }

    if ($members.Count -gt 0)
    {
        return $members.ToArray()
    }
    return ,([System.String[]]@())
}

function EnumerateMembersOnFullSKU
{
    [OutputType([System.String[]])]
    param
    (
        [parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [System.DirectoryServices.AccountManagement.GroupPrincipal]
        $group,

        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        $principalContexts,

        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [System.Collections.ArrayList]
        $disposables,

        [System.Net.NetworkCredential]
        $credential = $null
    )

    Set-StrictMode -Version Latest
    [System.Collections.ArrayList] $members = New-Object System.Collections.ArrayList

    # Get the group members as Principal objects.
    [System.DirectoryServices.AccountManagement.Principal[]] $principals = ResolveGroupMembersToPrincipals -group $group -principalContexts $principalContexts -disposables  $disposables -credential $credential

    foreach($principal in $principals)
    {
        if($principal.ContextType -eq [System.DirectoryServices.AccountManagement.ContextType]::Domain)
        {
            # Select only the first part of the full domain name.
            [String]$domainName = $principal.Context.Name;
            [int] $separatorIndex = $domainName.IndexOf('.')
            if ($separatorIndex -ne -1)
            {
                $domainName = $domainName.Substring(0, $separatorIndex)
            }

            if($principal.StructuralObjectClass -eq "computer")
            {
                $null = $members.Add($domainName+'\'+$principal.Name)
            }
            else
            {
                $null = $members.Add($domainName+'\'+$principal.SamAccountName)
            }
        }
        else
        {
            $null = $members.Add($principal.Name)
        }
    }

    return $members.ToArray()
}

<#
.Synopsis
    Resolves the members of a group to Principal instances.
#>
function ResolveGroupMembersToPrincipals
{
    [OutputType([System.DirectoryServices.AccountManagement.Principal[]])]
    param
    (
        [parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [System.DirectoryServices.AccountManagement.GroupPrincipal]
        $group,

        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        $principalContexts,

        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [System.Collections.ArrayList]
        $disposables,

        [System.Net.NetworkCredential]
        $credential = $null
    )
    Set-StrictMode -Version latest

    [System.Collections.ArrayList] $principals = New-Object System.Collections.ArrayList

    # NOTE: This logic enumerates the group members using the underlying DirectoryEntry API.
    # The reason this is needed is due to the fact that enumerating the group
    # members as principal instances causes a resolve to occur. Since there is no
    # facility for passing credentials to perform the resolution, any members that
    # cannot be resolved using the current user will fail; such as when the DSC
    # Group resource runs as system.  Dropping down to the underyling API
    # allows us to access the account's SID which can then be used to
    # resolve the associated principal using explicit credentials.
    [System.DirectoryServices.DirectoryEntry] $groupDe = $group.GetUnderlyingObject()

    $enum = $groupDe.Invoke("Members")
    foreach ($item in $enum)
    {
        [string] $scope = $null
        [string] $accountName = $null
        [string] $machineName = $env:COMPUTERNAME
        [System.DirectoryServices.AccountManagement.Principal] $principal = $null

        # extract the objectSid from the underlying DirectoryEntry
        [System.DirectoryServices.DirectoryEntry] $entry = New-Object System.DirectoryServices.DirectoryEntry($item)
        [byte[]] $sidBytes = $entry.Properties["objectSid"].Value

        $null = $disposables.Add($entry)

        [string[]] $parts = $entry.Path.Split("/")

        if ($parts.Count -eq 4)
        {
            # parsing WinNT://domainname/accountname
            # or WinNT://machinename/accountname
            $scope = $parts[2]
            $accountName = $parts[3]
        }
        elseif ($parts.Count -eq 5)
        {
            # parsing WinNT://domainname/machinename/accountname
            $scope = $parts[3]
            $accountName = $parts[4]
        }
        else
        {
            # the account is stale either becuase it was deleted or
            # the machine was moved to a new domain without removing
            # the domain members from the group.
            # If we consider this a fatal error, the group is no longer
            # managable by the DSC resource.  Writing a warning allows
            # the operation to complete while leaving the stale member in the
            # group.
            Write-Warning -Message ($LocalizedData.MemberNotValid -f  $entry.Path)
            continue
        }


        [bool] $isLocalMachine = [System.String]::CompareOrdinal($scope, $machineName) -eq 0

        $principalContext = GetPrincipalContext -principalContexts $principalContexts -disposables $disposables -scope $scope -credential $credential

        # if local machine qualified, get the PrincipalContext for the local machine
        if ($isLocalMachine -eq $true)
        {
            Write-Verbose -Message ($LocalizedData.ResolvingLocalAccount -f $accountName)
        }
        # the account is domain qualified - credentials required to resolve it.
        elseif ($credential -ne $null  -or $principalContext -ne $null)
        {
            Write-Verbose -Message ($LocalizedData.ResolvingDomainAccount -f  $scope, $accountName)
        }
        else
        {
            # The provided name is not scoped to the local machine and no credentials were provided.
            # This is an unsupported use case; credentials are required to resolve off-box.
            ThrowInvalidArgumentError -ErrorId "PrincipalNotFoundNoCredential" -ErrorMessage ($LocalizedData.DomainCredentialsRequired -f $accountName)
        }

        # create a sid to enable comparison againt the expected member's sid.
        [System.Security.Principal.SecurityIdentifier] $sid = New-Object System.Security.Principal.SecurityIdentifier($sidBytes, 0)

        $principal = ResolveSidToPrincipal -principalContext $principalContext -sid $sid -isLocalMachineQualified $isLocalMachine
        $null = $principals.Add($principal)
        $null = $disposables.Add($principal)
    }

    return $principals.ToArray()
}

<#
.Synopsis
    Resolves an array of object names to Principal instances.
#>
function ResolveNamesToPrincipals
{
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [String[]] $objectNames,

        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [System.Collections.ArrayList] $disposables,

        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        $principalContexts,

        [System.Net.NetworkCredential]
        $credential = $null
    )
    Set-StrictMode -Version Latest

    [System.Collections.ArrayList] $principals = New-Object System.Collections.ArrayList
    $keys = @{}

    foreach($objectName in $objectNames)
    {
        $principal = ResolveNameToPrincipal -principalContexts $principalContexts -credential $credential -disposables $disposables -objectName $objectName
        if ($principal -ne $null)
        {
            [string] $key = $null
            # handle duplicate entries
            if ($principal.ContextType -eq [System.DirectoryServices.AccountManagement.ContextType]::Domain)
            {
                $key = $principal.DistinguishedName
            }
            else
            {
                $key = $principal.SamAccountName
            }
            if ($keys.ContainsKey($key) -eq $false)
            {
                $keys.Add($key, $null)
                $null = $principals.Add($principal)
            }
        }
    }

    $keys.Clear()
    return $principals.ToArray()
}

<#
.Synopsis
    resolves an object name to a Principal
#>
function ResolveNameToPrincipal
{
    [OutputType([System.DirectoryServices.AccountManagement.Principal])]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        $principalContexts,

        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        $disposables,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $objectName,

        [System.Net.NetworkCredential]
        $credential = $null

    )
    Set-StrictMode -Version Latest

    [string] $accountName = $null

    # the scope of the the object name when in the form of scope\name, UPN, or DN
    [string] $scope = Parse-Scope -fullName $objectName -accountName ([ref] $accountName)

    # check for an object qualified to the local machine
    [bool] $isLocalMachine = IsLocalMachine $scope

    [System.DirectoryServices.AccountManagement.PrincipalContext] $principalContext = $null
    [bool] $UseDomainTrust = $false

    # if local machine qualified, get the PrincipalContext for the local machine
    if ($isLocalMachine -eq $true)
    {
        Write-Verbose -Message ($LocalizedData.ResolvingLocalAccount -f $objectName)
    }
    # the account is domain qualified - credentials provided to resolve it.
    elseif ($credential -ne $null)
    {
        Write-Verbose -Message ($LocalizedData.ResolvingDomainAccount -f  $ObjectName, $scope)
    }
    # no credentials provided to resolve account name, so try with domain trust
    else
    {
        # The provided name is not scoped to the local machine and no credentials were provided.
        # If the object is a domain qualified name, we can try to resolve the user with domain trust, if setup.
        $UseDomainTrust = $true
        Write-Verbose -Message ($LocalizedData.ResolvingDomainAccountWithTrust -f $objectName)
    }

    # Get a PrincipalContext to use to resolve the object
    $principalContext = GetPrincipalContext -principalContexts $principalContexts -disposables $disposables -scope $scope -credential $credential
    
    if ($UseDomainTrust)
    {
        # When using domain trust, we use the object name to resolve. Object name can be in different formats such as a domain 
        # qualified name, UPN, or a distinguished name for the scope
        $account = $objectName
    }
    else
    {
        $account = $accountName
    }

    try
    {
        [System.DirectoryServices.AccountManagement.Principal] $principal = [System.DirectoryServices.AccountManagement.Principal]::FindByIdentity($principalContext, $account)
    }
    catch [System.Runtime.InteropServices.COMException]
    {
        ThrowInvalidArgumentError -ErrorId "PrincipalNotFound" -ErrorMessage ( $LocalizedData.UnableToResolveAccount -f $objectName, $_.Exception.Message, $_.Exception.HResult )
    }

    if ($principal -eq $null)
    {
        [string] $errorId = $null
        if ($isLocalMachine)
        {
            $errorId = "PrincipalNotFound_LocalMachine"
        }
        else
        {
            $errorId = "PrincipalNotFound_ProvidedCredential"
        }

        ThrowInvalidArgumentError -ErrorId $errorId -ErrorMessage ($LocalizedData.CouldNotFindPrincipal -f $objectName)
    }

    return $principal
}

<#
.Synopsis
    Resolves a SID to a principal
#>
function ResolveSidToPrincipal
{
    [OutputType([System.DirectoryServices.AccountManagement.Principal])]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [System.DirectoryServices.AccountManagement.PrincipalContext] $principalContext,

        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [System.Security.Principal.SecurityIdentifier] $sid,

        [Parameter(Mandatory = $true)]
        [bool] $isLocalMachineQualified
    )
    Set-StrictMode -Version Latest

    [string] $sidValue = $Sid.Value

    # Try to find a matching principal.
    $principal = [System.DirectoryServices.AccountManagement.Principal]::FindByIdentity($principalContext, [System.DirectoryServices.AccountManagement.IdentityType]::Sid, $sidValue)

    if ($principal -eq $null)
    {
        [string] $errorId = $null
        if ($isLocalMachineQualified)
        {
            $errorId = "PrincipalNotFound_LocalMachine"
        }
        else
        {
            $errorId = "PrincipalNotFound_ProvidedCredential"
        }

        ThrowInvalidArgumentError -ErrorId $errorId -ErrorMessage ($LocalizedData.CouldNotFindPrincipal -f $sid.ToString())
    }

    return $principal
}

<#
.Synopsis
    Gets a PrincipalContext to use to resolve an object in the specified $scope
    $principalContexts is a hashtable of scope to PrincipalContext. This is used to
    cache PrincipalContext instances for cases where it is used multiple times.
    disposables is an array of disposable objects. When a new PrincipalContext is
    created, it is added to the disposable list as well as the hashtable.
    $credential is used when a new PrincipalContext needs to be created with explicit
    credentials to a target domain
#>
function GetPrincipalContext
{
    [OutputType([System.DirectoryServices.AccountManagement.PrincipalContext])]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        $principalContexts,

        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        $disposables,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [object] $scope,

        [System.Net.NetworkCredential]
        $credential = $null
    )

    # The PrincipalContext to use to resolve the account
    [System.DirectoryServices.AccountManagement.PrincipalContext] $principalContext = $null

    # check for an object qualified to the local machine
    [bool] $isLocalMachine = [System.String]::Compare($env:COMPUTERNAME, $scope) -eq 0

    if ($isLocalMachine)
    {
        # check for a cached PrincipalContext for the local machine.
        if ($principalContexts.ContainsKey($env:COMPUTERNAME))
        {
            $principalContext = $principalContexts[$env:COMPUTERNAME]
        }
        else
        {
            # Create a PrincipalContext for the local machine
            $principalContext = New-Object System.DirectoryServices.AccountManagement.PrincipalContext([System.DirectoryServices.AccountManagement.ContextType]::Machine)

            # Cache the PrincipalContext for this scope for subsequent calls.
            $principalContexts.Add($env:COMPUTERNAME, $principalContext)
            $null = $disposables.Add($principalContext)
        }
    }
    elseif ($principalContexts.ContainsKey($scope))
    {
        $principalContext = $principalContexts[$scope]
    }
    elseif ($credential -ne $null)
    {
        # Create a PrincipalContext targeing $scope using the network credentials that were passed in.

        $name = [System.String]::Format("{0}\{1}", $credential.Domain, $credential.UserName)
        $principalContext = New-Object System.DirectoryServices.AccountManagement.PrincipalContext([System.DirectoryServices.AccountManagement.ContextType]::Domain, $scope, $name, $credential.Password)

        # Cache the PrincipalContext for this scope for subsequent calls.
        $principalContexts.Add($scope, $principalContext)
        $null = $disposables.Add($principalContext)
    }
    else
    {
        # Get a PrincipalContext for the current user in the target domain (even for local System account).
        $principalContext = New-Object System.DirectoryServices.AccountManagement.PrincipalContext([System.DirectoryServices.AccountManagement.ContextType]::Domain, $scope)

        # Cache the PrincipalContext for this scope for subsequent calls.
        $principalContexts.Add($scope, $principalContext)
        $null = $disposables.Add($principalContext)
    }

    return $principalContext
}


<#
.Synopsis
    Adds the entries defined in $Principals from $Group.Members.
    Returns $true if the members changed (i.e., members were added);
    otherwise, $false if all of the entries in $Principals were already present
    in $Group.Members
#>function AddGroupMembers
{
    [OutputType([bool])]
    param
    (
        [System.DirectoryServices.AccountManagement.GroupPrincipal] $Group,

        [System.DirectoryServices.AccountManagement.Principal[]] $Principals
    )
    Set-StrictMode -Version Latest
    [bool] $updated = $false

    if ($Principals -ne $null)
    {
        # Make changes to the group.
        foreach($principal in $Principals)
        {
            if ($group.Members.Contains($principal))
            {
                continue
            }
            $group.Members.Add($principal)
            # indicate a change was made to $Group.Members
            $updated = $true
        }
    }
    return $updated
}

<#
.Synopsis
    Removes the entries defined in $Principals from $Group.Members.
    Returns $true if the members changed (i.e., members were removed);
    otherwise, $false if none of the entries in $Principals were present
    in $Group.Members
#>
function RemoveGroupMembers
{
    [OutputType([bool])]
    param
    (
        [System.DirectoryServices.AccountManagement.GroupPrincipal] $Group,

        [System.DirectoryServices.AccountManagement.Principal[]] $Principals
    )
    Set-StrictMode -Version Latest
    [bool] $updated = $false

    if ($Principals -ne $null)
    {
        # Make changes to the group.
        foreach($principal in $Principals)
        {
            if ($group.Members.Remove($principal) -eq $true)
            {
                # indicated a change was made to the members.
                $updated = $true
            }
        }
    }

    return $updated
}

#region Utilities

<#
.Synopsis
    Determines if a scope represents the current machine.
#>
function IsLocalMachine
{
    [OutputType([bool])]
    param
    (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $scope
    )
    Set-StrictMode -Version latest

    if ($scope -eq ".")
    {
        return $true
    }

    if ($scope -eq $env:COMPUTERNAME)
    {
        return $true
    }

    if ($scope -eq "localhost")
    {
        return $true
    }

    if ($scope.Contains("."))
    {
        if ($scope -eq "127.0.0.1")
        {
            return $true
        }

        # Determine if we have an ip address that matches an ip address on one of the
        # network adapters.
        # NOTE: This is likely overkill; consider removing it.
        $items = @(Get-WmiObject Win32_NetworkAdapterConfiguration)
        foreach ($item in $items)
        {
            if ($item.IPaddress -ne $null)
            {
                foreach ($addr in $item.IPaddress)
                {
                    if ($addr -eq $scope)
                    {
                        return $true
                    }
                }
            }
        }
    }
    return $false
}

<#
.Synopsis
    Determines if a specified domain is the same as the domain defined in a PrincipalContext.
    This is used to determine if a new connection (PrincipalContext) needs to be created.

.Notes
    This method uses simple string compare and simple parsing to perform the match and
    should only be used to determine if a new connection is required since some
    comparisons may returned $false due to formatting differences.
#>
function IsSameDomain
{
    [OutputType([bool])]
    param
    (
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [System.DirectoryServices.AccountManagement.PrincipalContext] $principalContext,

        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [String] $domain
    )
    Set-StrictMode -Version latest

    # Compare against Name of $principalContext - typically the undecorated domain name
    [bool] $isSameDomain = [System.String]::Compare($domain, $principalContext.Name, [System.StringComparison]::OrdinalIgnoreCase) -eq 0

    if ($isSameDomain -eq $false)
    {
        $dotIndex = $principalContext.ConnectedServer.IndexOf(".")
        if ($dotIndex -ne -1)
        {
            $principalDomain = $principalContext.ConnectedServer.Substring($dotIndex + 1)
            $isSameDomain = [System.String]::Compare($domain, $principalDomain, [System.StringComparison]::OrdinalIgnoreCase) -eq 0
        }
    }

    return $isSameDomain
}

<#
.Synopsis
    Parses various object name formats to extract the machine or domain scope.

    The returned $scope is used to determine where to perform the resolution,
    the local machine or a target domain while $accountName is the name
    of the account to resolve.

    The following details the formats that are handled as well as how the
    values are determined.

    Domain qualified names (domainname\username)

    The value is split on the first '\' character with the left hand side
    returned as the scope and the right hand side is returned as the account name.

    UPN: (username@domainname)

    The value is split on the first '@' character with the left hand side
    returned as the account name and the right hand side returned
    as the scope

    DistinguishedName:

    The value at the first occurance of "DC=" is used to extract the unqualified
    domain name.  The incoming string is returned, as is, for the account
    name.

    Unqualified account names:

    The incoming string is returned as the account name and the local
    machine name is returned as the scope. Note that values that do
    not fall into the above categories are interpreted as unqualified
    account names.

.Notes
    ResolveNameToPrincipal will fail if a machine name is specified
    as domainname\machinename. It will succeed if the machine name
    is specified as the SAM name (domainname\machinename$) or
    as the unqualified machine name.
    Parse-Scope splits the scope and account name to avoid
    the problem.
#>
function Parse-Scope
{
    [OutputType([string])]
    param
    (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $fullName,

        [Parameter(Mandatory=$true)]
        [AllowEmptyString()]
        [AllowNull()]
        [ref] $accountName
    )
    Set-StrictMode -Version latest

    # assume no scope is defined or $fullName is a DistinguishedName
    $accountName.Value = $fullName

    # parse domain or machine qualified account name
    [int] $separatorIndex = $fullName.IndexOf("\")
    if ($separatorIndex -ne -1)
    {
        $scope = $fullName.Substring(0, $separatorIndex)
        if (IsLocalMachine $scope)
        {
            $scope = $env:COMPUTERNAME
        }
        $accountName.Value = $fullName.Substring($separatorIndex+1)
        return $scope
    }

    # parse UPN for the scope
    $separatorIndex = $fullName.IndexOf("@")
    if ($separatorIndex -ne -1)
    {
        $scope = $fullName.Substring($separatorIndex + 1)
        $accountName.Value = $fullName.Substring(0,$separatorIndex)
        return $scope
    }

    # parse distinguished name for the scope
    $separatorIndex = $fullName.IndexOf("DC=", [System.StringComparison]::OrdinalIgnoreCase)
    if ($separatorIndex -ne -1)
    {
        # NOTE: For distinguished name formats, the DistinguishedName is
        # returned as the account name. See the initialization of $accountName
        # above.
        $startIndex = $separatorIndex + 3
        $endIndex = $fullName.IndexOf(",", $startIndex)
        if ($endIndex -gt $startIndex)
        {
            $length = $endIndex - $separatorIndex - 3
            $scope = $fullName.Substring($startIndex, $length)
            return $scope
        }
    }
    return $env:COMPUTERNAME
}

<#
.Synopsis
    Disposes the contents of an array list containing IDisposable objects.
#>
function DisposeAll
{
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [AllowEmptyCollection()]
        [System.Collections.ArrayList]
        $disposables
    )
    Set-StrictMode -Version latest

    if ($disposables.Count -gt 0)
    {
        foreach ($disposable in $disposables)
        {
            if ($disposable -is [System.IDisposable])
            {
                $disposable.Dispose()
            }
        }
    }
}

<#
    .SYNOPSIS
        Gets a local Windows group.

    .NOTES
        The returned value is NOT added to the $disposables list.
#>
function Get-Group
{
    [OutputType([System.DirectoryServices.AccountManagement.GroupPrincipal])]
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String] $GroupName,

        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [AllowEmptyCollection()]
        [System.Collections.ArrayList] $Disposables,

        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [Object[]] $PrincipalContexts
    )

    [System.DirectoryServices.AccountManagement.PrincipalContext] $principalContext = GetPrincipalContext -principalContexts $principalContexts -disposables $Disposables -scope $env:COMPUTERNAME -credential $null
    [System.DirectoryServices.AccountManagement.GroupPrincipal] $group = [System.DirectoryServices.AccountManagement.GroupPrincipal]::FindByIdentity($principalContext, $groupName)
    # NOTE: $group is not automatically added to $disposables because the caller
    # may need to call $group.Delete() which also disposes it.
    return $group
}

<#
    .SYNOPSIS
        Throws an error if a group name contains invalid characters.

    .PARAMETER GroupName
        The group name to test.
#>
function Assert-GroupNameValid
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String] $GroupName
    )

    $invalidCharacters = @( '\', '/', '"', '[', ']', ':', '|', '<', '>', '+', '=', ';', ',', '?', '*', '@' )

    if ($GroupName.IndexOfAny($invalidCharacters) -ne -1)
    {
        ThrowInvalidArgumentError -ErrorId 'GroupNameHasInvalidCharacter' -ErrorMessage ($LocalizedData.InvalidGroupName -f $GroupName, [String]::Join(' ', $invalidCharacters))
    }

    $nameContainsOnlyWhitspaceOrDots = $true

    # Check if the name consists of only periods and/or white spaces.
    for ($groupNameIndex = 0; $groupNameIndex -lt $GroupName.Length; $groupNameIndex++)
    {
        if (-not [Char]::IsWhiteSpace($GroupName, $groupNameIndex) -and $GroupName[$groupNameIndex] -ne '.')
        {
            $nameContainsOnlyWhitspaceOrDots = $false
            break
        }
    }

    if ($nameContainsOnlyWhitspaceOrDots)
    {
        ThrowInvalidArgumentError -ErrorId 'GroupNameHasOnlyWhiteSpacesAndDots' -ErrorMessage ($LocalizedData.InvalidGroupName -f $GroupName, [String]::Join(' ', $invalidCharacters))
    }
}

<#
.Synopsis
Throws an argument error.
#>
function ThrowInvalidArgumentError
{
    [CmdletBinding()]
    param
    (

        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $ErrorId,

        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $ErrorMessage
    )

    $errorCategory=[System.Management.Automation.ErrorCategory]::InvalidArgument
    $exception = New-Object System.ArgumentException $ErrorMessage;
    $errorRecord = New-Object System.Management.Automation.ErrorRecord $exception, $ErrorId, $errorCategory, $null
    throw $errorRecord
}

Function Throw-TerminatingError
{
    param(
        [string] $Message,
        [System.Management.Automation.ErrorRecord] $ErrorRecord,
        [string] $ExceptionType
    )
    
    $exception = new-object "System.InvalidOperationException" $Message,$ErrorRecord.Exception
    $errorRecord = New-Object System.Management.Automation.ErrorRecord $exception,"MachineStateIncorrect","InvalidOperation",$null
    throw $errorRecord
}

<#
.Synopsis
Writes either to Verbose or ShouldProcess channel.
#>
function Write-Log
{
    [CmdletBinding(SupportsShouldProcess=$true)]
    param
    (
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Message
    )

    if ($PSCmdlet.ShouldProcess($Message, $null, $null))
    {
        Write-Verbose $Message
    }
}

#endregion

Export-ModuleMember -Function *-TargetResource
