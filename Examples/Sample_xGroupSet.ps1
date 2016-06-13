Configuration xGroupSetExample
{
    Import-DscResource -ModuleName xPSDesiredStateConfiguration

    xGroupSet xGroupSet1
    {
        GroupName = @('MyGroup1', 'MyGroup2', 'MyGroup3')
        Ensure = "Present"
        MembersToInclude = @('Member1', 'Member2')
    }
}
