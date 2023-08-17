# Work in Progress!

# To create the cloud-based group in Entra ID using the Microsoft Graph:
$GroupParams = @{
    DisplayName = "All People Leaders"
    Description = "A dynamic group of all people leaders in the organization (managerial titles with direct reports)."
    MailEnabled = $False
    SecurityEnabled = $true
    GroupTypes = "DynamicMembership","Security"
    MembershipRuleProcessingState = "On"
}
# Change this sample rule:
New-MgGroup @GroupParams -MembershipRule "(user.employeehiredate -ge ""2023-01-01T00:00:00Z"" -and (user.usertype eq ""Member"")"