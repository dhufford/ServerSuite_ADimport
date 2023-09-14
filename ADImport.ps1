###############################################################################################################
# ADImport - Import Centrify Data into AD
#
# DISCLAIMER   : Note that this script is used by Centrify Professionnal Services to help customers migrate 
#                from Unix to Active Directory by importing Centrify data in AD. This script is NOT supported 
#                by Centrify Support, but when delivered during an engagement is supported by Professional 
#                Services themselves for up to 60 days after end of the engagement (as stated in Statement of 
#                Work). This script SHOULD NOT be used in production environment to fulfill Centrify data 
#                management on a day-to-day basis. Instead this steps should be be covered by using directly 
#                the Centrify.DirectControl.PowerShell Cmdlets, in specifically written scripts, or called by 
#                external means (e.g. IAM solutions or Web Portal). 
#
# Author       : Fabrice Viguier
# Contact      : fabrice.viguier AT centrify.com
# Release      : 17/09/2012
# Version      : Git repository https://bitbucket.org/centrifyps/adimport
###############################################################################################################

<#
.SYNOPSIS
Import Centrify Data in Centrify Zones into target Active Directory from a collection of CSV files.

.DESCRIPTION
This script is intend to import Centrify data in Centrify Zones. The script take a list of UNIX data from CSV formated files.
The CSV files are provide in a given structures that this script analyze and present as a menu. You can import data by chosing which kind of UNIX data to import by giving the appropriate parameter.
By default operations are done with current logon account on the current system joined Active Directory domain.
It's possible to specify AD account user name to connect to AD with alternative credential (e.g. NTDOMAIN\Administrator). It's also possible to specify a target AD domain by giving FQDN path of the domain (e.g. company.com).

DISCLAIMER:
Note that this script is used by Centrify Professionnal Services to help customers migrate from Unix to Active Directory by importing Centrify data in AD.
This script is NOT supported by Centrify Support, but when delivered during an engagement is supported by Professional Services themselves for up to 60 days after end of the engagement (as stated in Statement of Work).
This script SHOULD NOT be used in production environment to fulfill Centrify data management on a day-to-day basis. Instead this steps should be be covered by using directly the Centrify.DirectControl.PowerShell Cmdlets, in specifically written scripts, or called by external means (e.g. IAM solutions or Web Portal). 

.PARAMETER Domain
Specify the AD Domain name where perform actions in FQDN format (e.g. company.com). 

.PARAMETER Credential
Specify the PSCredential of an AD User to perform actions on AD (e.g. (Get-Credential NTDOMAIN\Administrator)).

.PARAMETER Zones
 Specify the CSV File to import Zones.
 The CSV File format should be as below:

 Name,Container,Description,IsOU,Parent

 Name          Name of the zone.
 Container     Container in which to create the zone. This can be ignored if Parent Zone is specified and the Child Zone should be created under his Parent Zone.
 Description   Description of the new zone.
 IsOU          If you specify this parameter, the zone is created as an organizational unit (OU). Otherwise, it is created as a container object.  
 Parent        The parent zone of the new zone, if any. Specify an empty string if there is no parent zone. 

.PARAMETER Computers
 Specify the CSV File to import and prepare Computers into Zones.
 The CSV File format should be as below:

 Hostname,Zone,Container

 Hostname     The name of the computer.
 Zone         The zone to which the computer is added. You can specify either the Zone name or a distinguished name for this parameter.
 Container    The Active Directory container in which the AD computer is to be created. Specify this parameter only if you are creating a new Active Directory computer.

.PARAMETER Users
 Specify the CSV File to import Unix User profiles into Zones and/or as Computer overrides.
 The CSV File format should be as below:

 Zone,User,UnixName,UID,GID,Gecos,Home,Shell

 Zone       The zone for which to create the UNIX profile. You can specify either the Zone name or a distinguished name for this parameter.
            Alternatively you can specify a managed computer for which to create the UNIX profile. You can specify either a CdmManagedComputer object or any of the following values for the Active Directory computer:
               - distinguishedName
               - SID
               - samAccountName
 User      The Active Directory user for which you are adding a UNIX user profile. You may specify any of the following values for this parameter:
               - distinguishedName
               - SID
               - samAccountName
               - <samAccountName>@<domain>
 UnixName   The UNIX login name for the user associated with the profile.
 UID        The UID of the user associated with the UNIX profile.
 GID        The group ID (GID) of the primary group of the user associated with the UNIX profile.
 Gecos      The GECOS field of the user UNIX profile.  Use this parameter for hierarchical zones only.
 Home       Default home directory of the user associated with the UNIX profile.
 Shell      The default shell of the user associated with the UNIX profile.

.PARAMETER Groups
 Specify the CSV File to import Unix Group profiles into Zones and/or as Computer overrides.
 The CSV File format should be as below:

 Zone,Group,UnixName,GID,Members

 Zone       The zone for which to create the UNIX profile. You can specify either the Zone name or a distinguished name for this parameter.
            Alternatively you can specify a managed computer for which to create the UNIX profile. You can specify either a CdmManagedComputer object or any of the following values for the Active Directory computer:
               - distinguishedName
               - SID
               - samAccountName
 Group      The Active Directory group for which you are adding a UNIX group profile. You may specify any of the following values for this parameter:
               - distinguishedName
               - SID
               - samAccountName
               - <samAccountName>@<domain>
 Container  The AD Container where to create the Active Directory group to associate to the UNIX group profile.
 UnixName   Name of the UNIX group profile.
 GID        The GID of the group UNIX profile.
 Members    List of Unix Names members of the Unix secondary group (as members are comma separeted this vallue MUST be enclosed with "" (double quotes))

.PARAMETER RolesAndRights
 Specify the CSV File to import Roles and Rights into Zones.
 The CSV File format should be as below:

 Zone,RoleName,RoleAuditLevel,RoleDescription,UnixSysRights,RoleHasRescueRight,RoleAllowLocalUser,PamName,PamDescription,PamApplication,CommandName,CommandDescription,CommandPattern,CommandPatternType,CommandMatchPath,CommandPriority,CommandDzshRunAs,CommandDzdoRunAsUser,CommandDzdoRunAsGroup,CommandKeepVar,CommandDeleteVar,CommandAddVar,CommandAuthentication

 Zone                    The zone in which to create the role. You can specify either the Zone name or a distinguished name for this parameter.
 RoleName                The name of the role.
 RoleDescription         Description of the role. 
 RoleAuditLevel          Audit setting for this role.  You may specify any one of the following values:
                            - no            Audit not requested/required
                            - possible      Audit if possible
                            - required      Audit required
 UnixSysRights           UNIX system rights granted to the role.  You can specify any combination of the following rights:
                            - login         Password login and non-password (SSO) login are allowed
                            - ssologin      Non-password (SSO) login is allowed
                            - disableacc    Account disabled in Active Directory can be used by sudo, cron, etc.
                            - nondzsh       Login with non-restricted shell
                         separate values with comma to specify more than one values, e.g. for default "UNIX Login" Role: "login,ssologin,nondzsh"
 RoleHasRescueRight      Determines whether this role has the rescue system right. If true, this role can operate without being audited in case of audit system failure.
 RoleAllowLocalUser      Determines whether local users can be assigned this role. If true, local users can be assigned this role.
 PamName                 The name of the PAM access right.
 PamDescription          Description of the PAM access right.
 PamApplication          The PAM application.
 CommandName             The name of the command right.
 CommandDescription      Description of the command right.
 CommandPattern          The pattern to match when looking for the command.
 CommandPatternType      The type of the command-matching pattern.  You may specify one of the following values:
                            - glob      Glob expression
                            - regexp    Regular expression
 CommandMatchPath        The path to use when matching the command.  You can specify one of the following values:
                            - "USERPATH"     		Standard user path
                            - "SYSTEMPATH"   		Standard system path
                            - "SYSTEMSEARCHPATH"	System search path
                            - Other strings		Custom specific path
 CommandPriority         The priority of the command.
 CommandDzshRunAs        The user this command runs under when using dzsh. You can specify one of the following values:
                            - "$"            run as current user
                            - ""             this command cannot be run in dzsh
                            - Other string   a specific user
 CommandDzdoRunAsUser    Users allowed to run this command using dzdo. Specify a comma-separated list, or specify one of the following values:
                            - "*"  can run as any user enabled for the zone
                            -  ""   cannot run as any user
                         Note: If you specify empty strings for both parameters DzdoRunAsUser and DzdoRunAsGroup, then this command cannot be run using dzdo.
 CommandDzdoRunAsGroup   Groups allowed to run this command using dzdo. Specify a comma-separated list, or specify one of the following values:
                            - "*"  can run as any group enabled for the zone
                            - ""   cannot run as any group
                         Note: If you specify empty strings for both parameters DzdoRunAsUser and DzdoRunAsGroup, then this command cannot be run using dzdo.
 CommandKeepVar          Environment variables to keep when dzdo is run. The dzdo.env_keep configuration parameter in the centrifydc.conf file defines a default set of environment variables to retain from the current user's environment when the dzdo command is run. This parameter lists environment variables to keep in addition to the default set.
                         Specify a comma-separated list of variables; or you can specify an empty string to indicate there are no variables to keep other than the default set. Use the DeleteVar parameter to remove variables from the default set.
                         You cannot specify both the KeepVar and DeleteVar parameters.
 CommandDeleteVar        Environment variables to delete when dzdo is run. The dzdo.env_keep configuration parameter in the centrifydc.conf file defines a default set of environment variables to retain from the current user's environment when the dzdo command is run. This parameter lists environment variables to remove from the default set.
                         Specify a comma-separated list of variables; or you can specify an empty string to indicate there are no variables to delete from the default set. Use the KeepVar parameter to add variables to the default set.
                         You cannot specify both the KeepVar and DeleteVar parameters.
 CommandAddVar           Environment variable name-value pairs to add to the final set of environment variables resulting from the keep or delete sets described in the KeepVar and DeleteVar parameters.
                         Specify a comma-separated list of name-value pairs specified as "name=value"; or you can specify an empty string to indicate there are no variables to add.
 CommandAuthentication   type of authentication needed to run the command. You can specify one of the following values:
                            - none          no authentication is required
                            - user          authentication is required with current user's password
                            - runastarget   authentication is required with run-as target user's password

.PARAMETER ComputerRoles
 Specify the CSV File to import Centrify Computer Roles into Zones.
 The CSV File format should be as below:

 Zone,Name,Description,Group,Container,Members

 Zone          The zone of the computer role. You can specify either the Zone name or a distinguished name for this parameter.
 Name          Name of the computer role.
 Description   Description of the computer role.
 Group         The computer group to associate with this computer role. You may specify any of the following values for this parameter:
                  - distinguishedName
                  - SID
				  - samAccountName
                  - <samAccountName>@<domain>
 Container     The Active Directory container in which the AD group is to be created. This can be ignored if the AD Group already exists.
 Members       List of Computer hostnames and/or AD groups members of the Computer Role (can be ignored)

.PARAMETER RoleAssignments
 Specify the CSV File to import Centrify Role Assignments into Zones/ComputerRoles/Computers.
 The CSV File format should be as below:

 TargetType,TargetName,Role,ADTrustee,TrusteeType,LocalTrustee,StartTime,EndTime

 TargetType    Indicate on which type of object create the Role Assignment. You may specify any of the following values for this parameter:
                  - Zone
				  - ComputerRole
				  - Computer
 TargetName    The Zone/Computer/Computer Role for which to create the role assignment. You may specify any of the following values for this parameter:
                  - Name
				  - distinguishedName
				  - samAccountName (for Computer only)
 Role          The role to assign to the zone, computer, or computer role. By default the Role is picked from the nearest Zone but target Zone can be specified using the format <Role Name>/<Zone Name>.
 ADTrustee     The Active Directory account to be used as the trustee. You can use this parameter only if the trustee is a specific AD user or group. In that case, do not use the "TrusteeType" parameter. You may specify any of the following values for this parameter:
                  - distinguishedName
                  - SID
				  - samAccountName
                  - <samAccountName>@<domain>
 TrusteeType   is the type of trustee. Do not use this parameter if the trustee is a specific Active Directory user or group.  If the trustee is local, you must use both this parameter and the LocalTrustee parameter. You must assign one of the following values:
                  - LocalUnixUser   local UNIX user
                  - LocalUnixUid    local UNIX UID
                  - LocalUnixGroup  local UNIX group
                  - LocalWinUser    local Windows user
                  - LocalWinGroup   local Windows group
                  - AllAD           all AD accounts
                  - AllLocalUnix    all local UNIX accounts
                  - AllLocalWin     all local Windows accounts
 LocalTrustee  The local account to use as the trustee. You can use this parameter only if the trustee is local, not Active Directory.
               For a user or a group, specify the name; for example, "userName". For a UID, specify the UID number; for example, "12345".
 StartTime     The date and time when the role assignment becomes effective.
 EndTime       The date and time when the role assignment expires.

.PARAMETER Progress
Show progress bars.

.PARAMETER Banner
Show banner, don't clear Host (usefull if you want to wrapp ADImport commands into a custom script and keep message on screen).

.PARAMETER Version
Show version of this script.

.PARAMETER Help
Show usage for this script.

.INPUTS
None. You can't redirect or pipe input to this script.

.OUTPUTS
None. This script only writes statistics on output.

.EXAMPLE
C:\PS> .\ADImport.ps1 -Computers .\ComputersList.csv
Create and prepare Computers listed in the given CSV File.

.EXAMPLE
C:\PS> .\ADImport.ps1 -Users .\sample\Users.txt -Progress
Import Unix User profiles listed in the given CSV File, a progress bar will be shown during the import (by default no progress is shown to improve performance).

.EXAMPLE
C:\PS> .\ADImport.ps1 -z .\Zones -Banner; .\ADImport.ps1 -c .\Computers.csv; .\ADImport.ps1 -u .\Users.csv; .\ADImport.ps1 -g .\Groups.csv
Import Zones, Computers, User and Group profiles in a single sequence. Show the banner only for the first import will prevent the screeen to be cleared between each steps and so by end of import a complete log of import will be available.
#>

param
(
	[Parameter(Mandatory = $false, HelpMessage = "Specify the AD Domain name where perform actions in FQDN format (e.g. company.com).")]
	[Alias("d")]
	[System.String]$Domain = [DirectoryServices.ActiveDirectory.Domain]::GetComputerDomain().Name,

	[Parameter(Mandatory = $false, HelpMessage = "Specify the PSCredential of an AD User to perform actions on AD (e.g. (Get-Credential NTDOMAIN\Administrator)).")]
	[Management.Automation.PSCredential]$Credential, 

	[Parameter(Mandatory = $false, HelpMessage = "Specify Domain Controller name to connect.")]
	[Alias("s")]
	[System.String]$Server,

	[Parameter(Mandatory = $false, HelpMessage = "Specify the CSV File to import Centify Zones.")]
	[Alias("z")]
	[System.String]$Zones,

	[Parameter(Mandatory = $false, HelpMessage = "Specify the CSV File to import and prepare Computers into Zones.")]
	[Alias("c")]
	[System.String]$Computers,

	[Parameter(Mandatory = $false, HelpMessage = "Specify the CSV File to import Unix User profiles into  Zones.")]
	[Alias("u")]
	[System.String]$Users,

	[Parameter(Mandatory = $false, HelpMessage = "Specify the CSV File to import Unix Group profiles into Zones.")]
	[Alias("g")]
	[System.String]$Groups,

	[Parameter(Mandatory = $false, HelpMessage = "Specify the CSV File to import Computer Roles into Zones.")]
	[Alias("cr")]
	[System.String]$ComputerRoles,

	[Parameter(Mandatory = $false, HelpMessage = "Specify the CSV File to import Role Assignments into Zones.")]
	[Alias("ra")]
	[System.String]$RoleAssignments,

	[Parameter(Mandatory = $false, HelpMessage = "Specify the CSV File to import Roles into  Zones.")]
	[Alias("r")]
	[System.String]$Roles,

	[Parameter(Mandatory = $false, HelpMessage = "Specify the CSV File to import Unix Rights into  Zones.")]
	[Alias("ur")]
	[System.String]$UnixRights,

	[Parameter(Mandatory = $false, HelpMessage = "Specify the CSV File to import Windows Rights into  Zones.")]
	[Alias("wr")]
	[System.String]$WindowsRights,

	[Parameter(Mandatory = $false, HelpMessage = "Show progress bars.")]
	[Switch]$Progress,

	[Parameter(Mandatory = $false, HelpMessage = "Show usage for this script.")]
	[Alias("h")]
	[Switch]$Help
)

#######################################
###     VERSION NUMBER and HELP     ###
#######################################

$VersionNumber = "5.0.921"
Write-Host ("#`n# ADImport - Import Centrify Data into AD`n# Version: {0}`n#`n" -f $VersionNumber)

if ($Help.IsPresent)
{
	Get-Help .\ADImport.ps1 -Full
	Exit
}

###########################
###     PREFERENCES     ###
###########################

# Debug preference
if ($PSCmdlet.MyInvocation.BoundParameters["Debug"].IsPresent) 
{
	# Debug continue without waiting for confirmation
	$DebugPreference = "Continue"
}
else 
{
	# Debug message are turned off
	$DebugPreference = "SilentlyContinue"
}

# Server preference
if ([System.String]::IsNullOrEmpty($Server))
{
	# Get Preferred Server from current session
	$Server = (Get-CdmPreferredServer | Where-Object { $_.Domain -eq $Domain }).Server
}
else 
{
	# Set Preferred Server
	Set-CdmPreferredServer -Domain $Domain -Server $Server
}
# Set PSCredential for Domain connection
if ([System.String]::IsNullOrEmpty($Credential))
{
	Write-Host "Running ADImport with Current User credentials"
}
else
{
	Set-CdmCredential -Domain $Domain -Credential $Credential
	Write-Host ("Running ADImport with {0} credentials" -f $Credential.UserName)
}

##########################################
###     CENTRIFY POWERSHELL MODULE     ###
##########################################

# Add PowerShell Module to session if not already loaded
[System.String]$ModuleName = "Centrify.DirectControl.PowerShell"
# Load PowerShell Module if not already loaded
if (@(Get-Module | Where-Object {$_.Name -eq $ModuleName}).count -eq 0)
{
	Write-Host ("Loading {0} module..." -f $ModuleName)
	Import-Module $ModuleName
	if (@(Get-Module | Where-Object {$_.Name -eq $ModuleName}).count -ne 0)
	{
		Write-Host ("{0} module loaded." -f $ModuleName)
	}
	else
	{
		Throw "Unable to load PowerShell module."
	}
}

##########################
###     MAIN LOGIC     ###
##########################

# Keep track of runtime
[System.DateTime]$StartingTime = [System.DateTime]::Now

# Allow running ADImport with multiples types of objects in one execution
foreach ($Parameter in $PSBoundParameters.GetEnumerator())
{
	# Hide ADImport optional parameters
	if ($Parameter.Key -eq "Credential")
	{
		# Do nothing
	}

	# Centrify Zones import
	elseif ($Parameter.Key -eq "Zones")
	{
		if (Test-Path -Path $Zones)
		{
			Write-Host "`nImporting Zones"
			Write-Host ("Running command: .\cmdlets\Import-CdmZone -Domain {0} -FilePath {1} -Progress" -f $Domain, $Zones)
			.\cmdlets\Import-CdmZone -Domain $Domain -Credential $Credential -FilePath $Zones -Progress
		}
		else
		{
			Throw "Can't find specified file to import."
		}
	}
	
	# Centrify Computers import and preparation
	elseif ($Parameter.Key -eq "Computers")
	{
		if (Test-Path -Path $Computers)
		{
			Write-Host "`nImporting Computers"
			Write-Host ("Running command: .\cmdlets\Import-CdmManagedComputer -Domain {0} -FilePath {1} -Progress" -f $Domain, $Computers)
			.\cmdlets\Import-CdmManagedComputer -Domain $Domain -Credential $Credential -FilePath $Computers -Progress
		}
		else
		{
			Throw "Can't find specified file to import."
		}
	}
	
	# Centrify Unix User profiles import
	elseif ($Parameter.Key -eq "Users")
	{
		if (Test-Path -Path $Users)
		{
			.\cmdlets\Import-CdmUserProfile -Domain $Domain -Credential $Credential -FilePath $Users -Progress
		}
		else
		{
			Throw "Can't find specified file to import."
		}
	}
	
	# Centrify Unix Group profiles import
	elseif ($Parameter.Key -eq "Groups")
	{
		if (Test-Path -Path $Groups)
		{
			.\cmdlets\Import-CdmGroupProfile -Domain $Domain -Credential $Credential -FilePath $Groups -Progress -CreateADGroup
		}
		else
		{
			Throw "Can't find specified file to import."
		}
	}
	
	# Centrify Roles import
	elseif ($Parameter.Key -eq "Roles")
	{
		if (Test-Path -Path $Roles)
		{
			.\cmdlets\Import-CdmRole -Domain $Domain -Credential $Credential -FilePath $Roles -Progress
		}
		else
		{
			Throw "Can't find specified file to import."
		}
	}
	
	# Centrify Unix Rights import
	elseif ($Parameter.Key -eq "UnixRights")
	{
		if (Test-Path -Path $UnixRights)
		{
			.\cmdlets\Import-CdmCommandRight -Domain $Domain -Credential $Credential -FilePath $UnixRights -Progress
		}
		else
		{
			Throw "Can't find specified file to import."
		}
	}
	
	# Centrify Windows Rights import
	elseif ($Parameter.Key -eq "WindowsRights")
	{
		if (Test-Path -Path $WindowsRights)
		{
			Throw "WindowsRights import currently not supported."
#			.\cmdlets\Import-CdmRole -Domain $Domain -Credential $Credential -FilePath $Roles -Progress
		}
		else
		{
			Throw "Can't find specified file to import."
		}
	}
	
	# Centrify Computer Roles import
	elseif ($Parameter.Key -eq "ComputerRoles")
	{
		if (Test-Path -Path $ComputerRoles)
		{
			.\cmdlets\Import-CdmComputerRole -Domain $Domain -Credential $Credential -FilePath $ComputerRoles -Progress -CreateADGroup
		}
		else
		{
			Throw "Can't find specified file to import."
		}
	}
	
	# Centrify Role Assignments import
	elseif ($Parameter.Key -eq "RoleAssignments")
	{
		if (Test-Path -Path $RoleAssignments)
		{
			.\cmdlets\Import-CdmRoleAssignment -Domain $Domain -Credential $Credential -FilePath $RoleAssignments -Progress -CreateADGroup
		}
		else
		{
			Throw "Can't find specified file to import."
		}
	}

	# ADImport need argument
	else
	{
		Write-Error "Missing type of data to import.`n"
		# Print Help
		Get-Help .\ADImport.ps1
		Exit
		# Done.
	}
}

# Print Elapsed time
[System.TimeSpan]$ElapsedTime = [DateTime]::Now - $StartingTime
Write-Host ("`nRuntime: {0:D2}h{1:D2}m{2:D2}s.`n" -f $ElapsedTime.Hours, $ElapsedTime.Minutes, $ElapsedTime.Seconds)
# All Done.

# SIG # Begin signature block
# MIIEKgYJKoZIhvcNAQcCoIIEGzCCBBcCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUEtTNjT5qr0Qujm1mlHNuAovX
# nDKgggI3MIICMzCCAaCgAwIBAgIQxH+aGsBVZbxNZjfCW1OLZDAJBgUrDgMCHQUA
# MCkxJzAlBgNVBAMTHkNlbnRyaWZ5IFByb2Zlc3Npb25hbCBTZXJ2aWNlczAeFw0x
# NDA2MTEwODAwMTlaFw0zOTEyMzEyMzU5NTlaMBoxGDAWBgNVBAMTD0ZhYnJpY2Ug
# VmlndWllcjCBnzANBgkqhkiG9w0BAQEFAAOBjQAwgYkCgYEAxfURIpF7SU3RmrXd
# /Vww7ud2J0kZL+Sc//kJqxDmjxngCsBjpOqIKLgxsi5DxjZio0gk/aav6Ifk7ej4
# Mtp2IYY1L5EiAitYlRfFCGapnAolrbQ9r1fInmhpAJXiwxD+pedVA3pjQue1xhB7
# dvKZxfwxZqdNHVLPQr8vgCZzscsCAwEAAaNzMHEwEwYDVR0lBAwwCgYIKwYBBQUH
# AwMwWgYDVR0BBFMwUYAQj6wqZRzzWAIFIMGJqC9WlqErMCkxJzAlBgNVBAMTHkNl
# bnRyaWZ5IFByb2Zlc3Npb25hbCBTZXJ2aWNlc4IQ3lgycgf2r6dK3jpN2H3n5DAJ
# BgUrDgMCHQUAA4GBAGl0+syZ3Q+39hBNUyzigpjbswckp3gZc6PVO53a+bd+PFEG
# gi/96JeLpq3PDWZq1n12Kp9ZHsxiuzb0mWdbumw2p5laQWMlO40JQUJOoP64DPLL
# Ou7szPH6o89dHGJ2UDWYlU02Iiysa4hCv9sJaLesnetxlcY4Cdfdlo41LhvfMYIB
# XTCCAVkCAQEwPTApMScwJQYDVQQDEx5DZW50cmlmeSBQcm9mZXNzaW9uYWwgU2Vy
# dmljZXMCEMR/mhrAVWW8TWY3wltTi2QwCQYFKw4DAhoFAKB4MBgGCisGAQQBgjcC
# AQwxCjAIoAKAAKECgAAwGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQwHAYKKwYB
# BAGCNwIBCzEOMAwGCisGAQQBgjcCARUwIwYJKoZIhvcNAQkEMRYEFKAd4mH0ShSb
# JN2jZBxTlCE7yTRzMA0GCSqGSIb3DQEBAQUABIGAur65aOf0BJYrTAKfKN6NRteV
# w13jvgA+vI1n/b8/gpbcQLHRrmeTTYcSfCyiZJWeMKEJAM8dax4TGrUNx87fEWWG
# tfDrZL09ar71w5rRii3qSSCx4ew/n233Gtkm2mN3b1VEEJl9AKSrVfm28Wgsmjkp
# LK0ztHyhJR8jbYJeprc=
# SIG # End signature block
