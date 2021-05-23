#Requires -module 'xPSDesiredStateConfiguration'

<#
    .SYNOPSIS
        Configuration that changes the recovery options for an existing service.

    .DESCRIPTION
        Configuration that changes the recovery options for an existing service.

    .PARAMETER Name
        The name of the Windows service.

    .PARAMETER State
        The state that the Windows service should have.

    .PARAMETER ResetPeriodSeconds
        The time to wait for the Failure count to reset in seconds.

    .PARAMETER FailureCommand
        The command line to run if a service fails.

    .PARAMETER RebootMessage
        An optional broadcast message to send to logged in users if the machine reboots as a result of a failure action.

    .EXAMPLE
        xService_ChangeServiceStateConfig -Name 'spooler' -State 'Stopped'

        Compiles a configuration that make sure the state for the Windows
        service 'spooler' is 'Stopped'. If the service is running the
        Windows service will be stopped.
#>
Configuration xService_ChangeServiceFailureActionsConfig
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $Name,

        [Parameter()]
        [ValidateSet('Running', 'Stopped')]
        [System.String]
        $State = 'Running',

        [Parameter()]
        [System.Int32]
        $ResetPeriodSeconds = 86400,

        [Parameter()]
        [System.String]
        $FailureCommand,

        [Parameter()]
        [System.String]
        $RebootMessage,

        [Parameter()]
        [Switch]
        $FailureActionsOnNonCrashFailures
    )

    Import-DscResource -ModuleName 'xPSDesiredStateConfiguration'

    Node localhost
    {
        xService 'ChangeServiceState'
        {
            Name                             = $Name
            State                            = $State
            Ensure                           = 'Present'
            ResetPeriodSeconds               = $ResetPeriodSeconds
            RebootMessage                    = $RebootMessage
            FailureCommand                   = $FailureCommand
            FailureActionsOnNonCrashFailures = $FailureActionsOnNonCrashFailures
            FailureActionsCollection = @(
                DSC_xFailureAction
                {
                    Type = 'RESTART'
                    DelayMilliSeconds = 60000
                }
                DSC_xFailureAction
                {
                    Type = 'RESTART'
                    DelayMilliSeconds = 120000
                }
                DSC_xFailureAction
                {
                    Type = 'Reboot'
                    DelayMilliSeconds = 240000
                }
                DSC_xFailureAction
                {
                    Type = 'RUN_COMMAND'
                    DelayMilliSeconds = 240000
                }
            )
        }
    }
}
