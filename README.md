# All People Leaders Group

Create and maintain an Active Directory group that contains all of an organization's "people leaders."

[![Codacy Badge](https://api.codacy.com/project/badge/Grade/16ed463b5f4743d7a97e57abb466209e)](https://app.codacy.com/gh/SamErde/All-People-Leaders-Group?utm_source=github.com&utm_medium=referral&utm_content=SamErde/All-People-Leaders-Group&utm_campaign=Badge_Grade)

This PowerShell script will help create and maintain an AD group that contains all of an organization's "people leaders." It is based on querying all Active Directory user objects that have a value in their DirectReports property and then filtering that group by actual leadership/managerial titles. The list of titles can be customized to suit an organization's unique titles.

## To Do

  - [ ] Add a function to check for the existence of the "all people leaders" group and create it if not yet present.
  - [X] Add logging and error handling.
  - [ ] Add visual output for when run in a console.
  - [ ] Add an option to email a report to the IT Service Desk / Help Desk or other administrators.
  - [ ] Create a version that works with Azure Active Directory.
  - [ ] Document the process to create a Windows scheduled task for this script.
  - [ ] Document a process to automate this script in Azure Functions.
  - [ ] Add parameters to present visual output with Out-GridView.
