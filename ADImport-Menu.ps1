###########################################################################################
# ADImport Menu - Import Centrify Data into AD using a wrapper Menu to ADImport script
#
# Author       : Fabrice Viguier
# Contact      : fabrice.viguier AT centrify.com
# Release      : 25/11/2013
# Version      : See ADImport.ps1 version notes
###########################################################################################

<#
.SYNOPSIS
Wrapper menu for the ADImport.ps1 script.

.DESCRIPTION
This script is intend to provide a menu for ADImport.ps1 script that import Centrify data in Centrify Zones. Through the menu you can import data by chosing which kind of UNIX data to import in which Zones.
By default operations are done with current logon account on the current system joined Active Directory domain.
It's possible to specify AD account user name to connect to AD with alternative credential (i.e. NTDOMAIN\Administrator). It's also possible to specify a target AD domain by giving FQDN path of the domain (i.e. company.com).

.PARAMETER Domain
Specify the AD Domain Name, in FQDN format (i.e. company.com), where the OU should be created. 

.PARAMETER Credential
Specify the PSCredential of an AD User to perform actions on AD (i.e. (Get-Credential NTDOMAIN\Administrator)).

.PARAMETER Server
Specify Domain Controller name to connect.

.PARAMETER Version
Show version of this script.

.PARAMETER Help
Show usage for this script.

.INPUTS
None. You can't redirect or pipe input to this script.

.OUTPUTS
None. This script only writes statistics on output.

.EXAMPLE
C:\PS> .\ADImport-Menu.ps1
Run the menu and follow instructions.

.EXAMPLE
C:\PS> .\ADImport-Menu.ps1 -V
Show version number of ADImport.ps1 script used with this wrapper menu.

.LINK
ADImport.ps1
#>
param
(
	[Parameter(Mandatory = $false, HelpMessage = "Specify the AD Domain name where perform actions in FQDN format (i.e. olympe.demo).")]
	[Alias("d")]
	[String]$Domain = [DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain().Name,

	[Parameter(Mandatory = $false, HelpMessage = "Specify the PSCredential of an AD User to perform actions on AD (i.e. (Get-Credential NTDOMAIN\Administrator)).")]
	[Management.Automation.PSCredential]$Credential, 

	[Parameter(Mandatory = $false, HelpMessage = "Specify Domain Controller name to connect.")]
	[Alias("s")]
	[String]$Server,

	[Parameter(Mandatory = $false, HelpMessage = "Show version of this script.")]
	[Alias("v")]
	[Switch]$Version,

	[Parameter(Mandatory = $false, HelpMessage = "Show usage for this script.")]
	[Alias("h")]
	[Switch]$Help
)
###########################################################################################
# VERSION NUMBER and HELP                                                                 #
###########################################################################################

if($Version.IsPresent)
{
	# Return ADImport version as a variable
	return (.\ADImport.ps1 -Version)	
}

if($Help.IsPresent)
{
	Get-Help .\ADImport-Menu.ps1 -Full
	Exit
}

###########################################################################################
# PARAMETERS                                                                              #
###########################################################################################
#$global:Domain 				= [DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain().Name
#$global:Server 				= [Void]$null
#$global:UserName				= [Security.Principal.WindowsIdentity]::GetCurrent().Name
#$global:Credential				= [Void]$null
#$global:CdmConnection	 		= [Void]$null

###########################################################################################
# FUNCTIONS                                                                               #
###########################################################################################
function Show-Banner
{
	#######################################################################################
	# PARAMETERS                                                                          #
	#######################################################################################
	param
	(
		[Parameter(Mandatory = $true, HelpMessage = "Specify the Breadcrumb value for the Menu banner.")]
		[Alias("b")]
		[String]$Breadcrumb
	)
	#######################################################################################
	# SCRIPT BLOCK                                                                        #
	#######################################################################################
	end
	{
		# Show Banner
		Clear-Host
		Write-Host "                                                                                           " -BackgroundColor DarkCyan -ForegroundColor White
		Write-Host " ADImport - Import Centrify Data into AD                                                   " -BackgroundColor DarkCyan -ForegroundColor Yellow
		Write-Host "                                                                                           " -BackgroundColor DarkCyan -ForegroundColor White
		Write-Host " Author : Fabrice Viguier                                                                  " -BackgroundColor DarkCyan -ForegroundColor White
		Write-Host " Contact: fabrice.viguier AT centrify.com                                                  " -BackgroundColor DarkCyan -ForegroundColor White
		Write-Host (" Version: {0}                                                           " -f (.\ADImport.ps1 -Version)) -BackgroundColor DarkCyan -ForegroundColor White
		Write-Host "                                                                                           " -BackgroundColor DarkCyan -ForegroundColor White
		Write-Host
		# Show Breadcrumb
		Write-Host $Breadcrumb -ForegroundColor Yellow
		# Show Connexion information
		$CdmPreferredServers = Get-CdmPreferredServer
		if($CdmPreferredServers -eq [Void]$null)
		{
			# Set Server by using Centrify API
			[Void](Get-CdmZone)
			# Get current connection
			$CdmPreferredServers = Get-CdmPreferredServer
		}
		foreach ($ADConnexion in $CdmPreferredServers)
		{
			$CdmCredential = Get-CdmCredential | Where-Object { $_.Target -eq $ADConnexion.Domain }
			if([System.String]::IsNullOrEmpty($CdmCredential.User))
			{
				$ADCredential = ("{0}\{1}" -f $env:USERDOMAIN, $env:USERNAME)
			}
			else
			{
				$ADCredential = $CdmCredential.User
			}
			Write-Host ("`nAD Domain Name: {0}" -f $ADConnexion.Domain)
			Write-Host ("Preferred DC  : {0}" -f $ADConnexion.Server)
			Write-Host ("AD Credential : {0}`n" -f $ADCredential)
		}
	}
}

function Get-Data
{
	#######################################################################################
	# PARAMETERS                                                                          #
	#######################################################################################
	param()
	#######################################################################################
	# SCRIPT BLOCK                                                                        #
	#######################################################################################
	end
	{
		Clear
		# Get Data from Structure
		$global:Zones = @()
		# Get child Directory only, exclude special Directories (_Archives, data, import and tools) 
		$ZoneList = Get-ChildItem | Where-Object { ($_.Mode -match "^d.*$") -and ($_.Name -notmatch "^(analysis|archives|data|import|sample|tools)$") }
		$i = 1
		foreach($Zone in $ZoneList)
		{
			$ZoneName = $Zone.Name
			# Show Zone data processing progress
			if($ZoneList.Count -eq [Void]$null) { $nbZones = 1 }
			else { $nbZones = $ZoneList.Count }
			$ProgressActivity	= ("Loading Zones data [{0}/{1}]" -f $i, $nbZones)
			$ProgressStatus		= "Percent processed: "
			$ProgressComplete	= (($i++ / $nbZones)*100)
			Write-Progress -Activity $ProgressActivity -Status $ProgressStatus -PercentComplete $ProgressComplete -Id 1
			# Build a ZoneObject object with information from founded directories
			$ZoneObject = New-Object System.Object
			$ZoneObject | Add-Member -MemberType NoteProperty -Name "Name" -Value $Zone.Name
			# Get Computers
			$ZoneObject | Add-Member -MemberType NoteProperty -Name "Computers" -Value (Test-Path -Path (".\{0}\Computers.csv" -f $Zone.Name))
			# Get UNIX Data
			$ZoneObject | Add-Member -MemberType NoteProperty -Name "Users" -Value (Test-Path -Path (".\{0}\UNIXData-Users.csv" -f $Zone.Name))
			$ZoneObject | Add-Member -MemberType NoteProperty -Name "Groups" -Value (Test-Path -Path (".\{0}\UNIXData-Groups.csv" -f $Zone.Name))
			# Get Authorization Data
			$ZoneObject | Add-Member -MemberType NoteProperty -Name "ComputerRoles" -Value (Test-Path -Path (".\{0}\Authorization-ComputerRoles.csv" -f $Zone.Name))
			$ZoneObject | Add-Member -MemberType NoteProperty -Name "RolesAndRights" -Value (Test-Path -Path (".\{0}\Authorization-RolesAndUnixRights.csv" -f $Zone.Name))
			$ZoneObject | Add-Member -MemberType NoteProperty -Name "RoleAssignments" -Value (Test-Path -Path (".\{0}\Authorization-RoleAssignments.csv" -f $Zone.Name))
			# Add the ZoneObject to the Zone collection
			$global:Zones += $ZoneObject
		}
		Sleep 1
		# Hide progress bars		
		Write-Progress -Activity "Computers data loaded" -Status "Hidden" -Id 2 -ParentId 1 -Completed
		Write-Progress -Activity "Zones data loaded" -Status "Hidden" -Id 1 -Completed
	}
}

function Get-Zone
{
	#######################################################################################
	# PARAMETERS                                                                          #
	#######################################################################################
	param()
	#######################################################################################
	# SCRIPT BLOCK                                                                        #
	#######################################################################################
	end
	{
		# Show analysis
		Write-Host ("`n{0} Centrify Zones found:" -f $global:Zones.Count)
		for($i = 1; $i -le $global:Zones.Count; $i++)
		{
			Write-Host ("{0} - {1}" -f $i, $global:Zones[$i-1].Name)
		}
		Write-Host
		# Choose the Zone to process
		do
		{
			try
			{
				$IsInteger = $true
				[Int32]$input = Read-Host "Choose the Zone to process (enter number of the Zone)"
			}
			catch
			{
				$IsInteger = $false
			}
		}
		while(-not $IsInteger -or (($input -lt 1) -or ($input -gt $global:Zones.Count)))
		# Return the chosen Zone
		return $global:Zones[$input-1]
	}
}

<#
function Get-Computer
{
	#######################################################################################
	# PARAMETERS                                                                          #
	#######################################################################################
	param
	(
		[Parameter(Mandatory = $true, HelpMessage = "Specify the Computer List to process.")]
		[Alias("c")]
		[Object]$Computers
	)
	#######################################################################################
	# SCRIPT BLOCK                                                                        #
	#######################################################################################
	end
	{
		# Show list of Computers for this Zone
		Write-Host ("`n{0} Centrify Computers found in this Zone:" -f $Computers.Count)
		for($i = 1; $i -le $Computers.Count; $i++)
		{
			Write-Host ("{0} - {1}" -f $i, $Computers[$i-1].Name)
		}
		Write-Host
		# Choose the Computer to process
		do
		{
			try
			{
				$IsInteger = $true
				[Int32]$input = Read-Host "Choose the Computer to process (enter number of the Computer)"
			}
			catch
			{
				$IsInteger = $false
			}
		}
		while(-not $IsInteger -or ($input -lt 1) -or ($input -gt $Computers.Count))
		# Return the chosen Computer
		return $Computers[$input-1]
	}
}
#>

function Show-PrepareComputersMenu
{
	#######################################################################################
	# PARAMETERS                                                                          #
	#######################################################################################
	param
	(
		[Parameter(Mandatory = $true, HelpMessage = "Specify the Zone to process.")]
		[Alias("z")]
		[Object]$Zone
	)
	#######################################################################################
	# SCRIPT BLOCK                                                                        #
	#######################################################################################
	end
	{
		# Menu Title
		Show-Banner ("[Main Menu > Prepare Computers > {0} Zone]" -f $Zone.Name)
		# Build Menu
		$Title = "Choose an operation to perform:"
		$Message = ""
		if($Zone.Computers -ne [Void]$null) { $Message += "P - Prepare UNIX Computers.`n" }
		$Message += "Z - Change Zone.`n"
		$Message += "R - Return to main menu.`n"
		$Message += "Q - Quit menu."
		$Choice0 = New-Object System.Management.Automation.Host.ChoiceDescription "&Prepare Computers", "Prepare UNIX Computers."
		$Choice1 = New-Object System.Management.Automation.Host.ChoiceDescription "Change &Zone", "Change Zone."
		$Choice2 = New-Object System.Management.Automation.Host.ChoiceDescription "&Return", "Return to main menu."
		$Choice3 = New-Object System.Management.Automation.Host.ChoiceDescription "&Quit", "Quit menu."
		$Options = [System.Management.Automation.Host.ChoiceDescription[]]($Choice0, $Choice1, $Choice2, $Choice3)
		# Prompt for choice
		$Prompt = $Host.UI.PromptForChoice($Title, $Message, $Options, 0) 
		switch($Prompt)
		{
			0 # Prepare Zone Computers
			{
				if($Zone.Computers)
				{
					$ImportFile = (".\{0}\Computers.csv" -f $Zone.Name)
					$nbComputers = (Import-Csv $ImportFile).Count
					# Build Menu
					$Title = "Confirm operation?"
					$Message = ""
					$Message += ("Computer(s) to prepare: {0}`n" -f $nbComputers)
					$Choice0 = New-Object System.Management.Automation.Host.ChoiceDescription "&Ok", "Ok to proceed."
					$Choice1 = New-Object System.Management.Automation.Host.ChoiceDescription "&Cancel", "Cancel process."
					$Options = [System.Management.Automation.Host.ChoiceDescription[]]($Choice0, $Choice1)
					# Prompt for choice
					$Prompt = $Host.UI.PromptForChoice($Title, $Message, $Options, 0) 
					switch($Prompt)
					{
						0 # Ok
						{
							Write-Host "`nCalling ADImport..."
							# Call ADImport
							&.\ADImport.ps1 -Computers $ImportFile -Server $global:Server -Credential $global:Credential -NoBanner -NoProgress
						}
						1 # Cancel
						{
							Write-Host "Operation canceled.`n"
						}
					}
					# Done.
				}
				else
				{
					Write-Warning "No Computers to prepare in this Zone. Skip."
				}
			}
			1 # Change Zone
			{
				Show-PrepareComputersMenu -Zone (Get-Zone)
			}
			2 # Return to main menu
			{
				Show-MainMenu
			}
			3 # Quit
			{
				Quit-Menu
			}
		}
		# Build Menu
		$Title = "Do you want to continue?"
		$Message = ""
		$Choice0 = New-Object System.Management.Automation.Host.ChoiceDescription "&Continue", "Return to menu."
		$Choice1 = New-Object System.Management.Automation.Host.ChoiceDescription "&Quit", "Exit this menu."
		$Options = [System.Management.Automation.Host.ChoiceDescription[]]($Choice0, $Choice1)
		# Prompt for choice
		$Prompt = $Host.UI.PromptForChoice($Title, $Message, $Options, 0) 
		switch($Prompt)
		{
			0 # Continue
			{
				Show-PrepareComputersMenu -Zone $Zone
			}
			1 # Quit
			{
				Show-MainMenu
			}
		}
	}
}

function Show-ZoneImportMenu
{
	#######################################################################################
	# PARAMETERS                                                                          #
	#######################################################################################
	param
	(
		[Parameter(Mandatory = $true, HelpMessage = "Specify the Zone to process.")]
		[Alias("z")]
		[Object]$Zone
	)
	#######################################################################################
	# SCRIPT BLOCK                                                                        #
	#######################################################################################
	end
	{
		# Menu Title
		Show-Banner ("[Main Menu > Import Menu > {0} Zone]" -f $Zone.Name)
		# Build Menu
		$Title = "Choose an operation to perform:"
		$Message = ""
		if($Zone.Users) { $Message += "U - Import Zone Users.`n"  }
		if($Zone.Groups) { $Message += "G - Import Zone Groups.`n" }
		if($Zone.Groups) { $Message += "M - Process Group Membership.`n" }
		if($Zone.ComputerRoles) { $Message += "C - Import Computer Roles.`n" }
		if($Zone.RolesAndRights) { $Message += "O - Import Roles and Rights.`n" }
		if($Zone.RoleAssignments) { $Message += "A - Import Role Assignments.`n" }
		$Message += "Z - Change Zone.`n"
		$Message += "R - Return to main menu.`n"
		$Message += "Q - Quit menu."
		$Choice0 = New-Object System.Management.Automation.Host.ChoiceDescription "&Users", "Import Zone Users."
		$Choice1 = New-Object System.Management.Automation.Host.ChoiceDescription "&Groups", "Import Zone Groups." 
		$Choice2 = New-Object System.Management.Automation.Host.ChoiceDescription "Group &Members", "Process Group Membership." 
		$Choice3 = New-Object System.Management.Automation.Host.ChoiceDescription "&Computer Roles", "Import Computer Roles." 
		$Choice4 = New-Object System.Management.Automation.Host.ChoiceDescription "R&oles and Rights", "Import Roles and Rights." 
		$Choice5 = New-Object System.Management.Automation.Host.ChoiceDescription "Roles &Assignments", "Import Role Assignments." 
		$Choice6 = New-Object System.Management.Automation.Host.ChoiceDescription "Change &Zone", "Change Zone."
		$Choice7 = New-Object System.Management.Automation.Host.ChoiceDescription "&Return", "Return to main menu."
		$Choice8 = New-Object System.Management.Automation.Host.ChoiceDescription "&Quit", "Quit menu."
		$Options = [System.Management.Automation.Host.ChoiceDescription[]]($Choice0, $Choice1, $Choice2, $Choice3, $Choice4, $Choice5, $Choice6, $Choice7, $Choice8)
		# Prompt for choice
		$Prompt = $Host.UI.PromptForChoice($Title, $Message, $Options, 0) 
		$ImportFile = [Void]$null
		switch($Prompt)
		{
			0 # Import Users
			{
				if($Zone.Users)
				{
					$ImportFile = (".\{0}\UNIXData-Users.csv" -f $Zone.Name)
					$nbUsers = (Import-Csv $ImportFile).Count
					# Build Menu
					$Title = "Confirm operation?"
					$Message = ""
					$Message += ("User(s) to import: {0}`n" -f $nbUsers)
					$Choice0 = New-Object System.Management.Automation.Host.ChoiceDescription "&Ok", "Ok to proceed."
					$Choice1 = New-Object System.Management.Automation.Host.ChoiceDescription "&Cancel", "Cancel process."
					$Options = [System.Management.Automation.Host.ChoiceDescription[]]($Choice0, $Choice1)
					# Prompt for choice
					$Prompt = $Host.UI.PromptForChoice($Title, $Message, $Options, 0) 
					switch($Prompt)
					{
						0 # Ok
						{
							Write-Host "`nCalling ADImport..."
							# Call ADImport
							&.\ADImport.ps1 -Users $ImportFile -Server $global:Server -Credential $global:Credential -NoBanner -NoProgress
						}
						1 # Cancel
						{
							Write-Host "Operation canceled.`n"
						}
					}
					# Done.
				}
				else
				{
					Write-Warning "No existing data for this operation. Skip."
				}
			}
			1 # Import Groups
			{
				if($Zone.Groups)
				{
					$ImportFile = (".\{0}\UNIXData-Groups.csv" -f $Zone.Name)
					$nbGroups = (Import-Csv $ImportFile).Count
					# Build Menu
					$Title = "Confirm operation?"
					$Message = ""
					$Message += ("Group(s) to import: {0}`n" -f $nbGroups)
					$Choice0 = New-Object System.Management.Automation.Host.ChoiceDescription "&Ok", "Ok to proceed."
					$Choice1 = New-Object System.Management.Automation.Host.ChoiceDescription "&Cancel", "Cancel process."
					$Options = [System.Management.Automation.Host.ChoiceDescription[]]($Choice0, $Choice1)
					# Prompt for choice
					$Prompt = $Host.UI.PromptForChoice($Title, $Message, $Options, 0) 
					switch($Prompt)
					{
						0 # Ok
						{
							Write-Host "`nCalling ADImport..."
							# Call ADImport
							&.\ADImport.ps1 -Groups $ImportFile -Server $global:Server -Credential $global:Credential -NoBanner -NoProgress
						}
						1 # Cancel
						{
							Write-Host "Operation canceled.`n"
						}
					}
					# Done.
				}
				else
				{
					Write-Warning "No existing data for this operation. Skip."
				}
			}
			2 # Import Groups membership
			{
				if($Zone.Groups)
				{
					Write-Host "Process group membership..."
					$Groups = Import-CSV (".\{0}\UNIXData-Groups.csv" -f $Zone.Name)
					if($Groups -ne [Void]$null)
					{
						foreach($Group in $Groups)
						{
							# Process list of groups
							$Members = $Group.Members
							if(-not [String]::IsNullOrEmpty($Members))
							{
								# Get Group even if groupname is empty in this Zone
								$GroupProfileByName = Get-CDCGroup -Domain $Domain -Credential $Credential -Group $Group.GroupName -Server $global:Server
								if($GroupProfileByName -ne [Void]$null)
								{
									# Group exist in one Zone
									$GroupProfiles = Get-CDCGroup -Domain $Domain -Credential $Credential -Zone $Zone.Name -Server $global:Server
									$GroupExist = $false
									foreach($GroupProfile in $GroupProfiles)
									{
										if($GroupProfile.Group.ID -eq $GroupProfileByName.Group.ID)
										{
											# Group exist in this Zone
											$GroupExist = $true
											break
										}
									}
								}
								if($GroupExist)
								{
									Write-Host ("Import group membership for group '{0}'" -f $Group.GroupName)
									# Search for Members
									foreach($Member in $Members.Split(","))
									{
										# Double check if User exist in this Zone
										$UserExist = $false
										$UnixProfilesByName = Get-CDCUser -Domain $Domain -Credential $Credential -UnixName $Member -Server $global:Server
										if($UnixProfilesByName -ne [Void]$null)
										{
											# User exist in one Zone
											foreach($UnixProfileByName in $UnixProfilesByName)
											{
												$UnixProfileByUser = Get-CDCUser -Domain $Domain -Credential $Credential -Zone $Zone.Name -User $UnixProfileByName.User.SamAccountName -Server $global:Server
												if($UnixProfileByUser -ne [Void]$null)
												{
													# User exist in this Zone
													$UserExist = $true
													break
												}
											}
										}
										if($UserExist)
										{
											# Get ADGroup object
											$Path = $GroupProfile.Group.ADsPath
											if([String]::IsNullOrEmpty($Credential)) { $ADGroup = New-Object System.DirectoryServices.DirectoryEntry($Path) }
											else { $ADGroup = New-Object System.DirectoryServices.DirectoryEntry($Path, $Credential.GetNetworkCredential().UserName, $Credential.GetNetworkCredential().Password, "Secure") }
											if($ADGroup -ne [Void]$null)
											{
												# Get ADUser object
												$Path = $UnixProfileByUser.User.ADsPath
												if([String]::IsNullOrEmpty($Credential)) { $ADUser = New-Object System.DirectoryServices.DirectoryEntry($Path) }
												else { $ADUser = New-Object System.DirectoryServices.DirectoryEntry($Path, $Credential.GetNetworkCredential().UserName, $Credential.GetNetworkCredential().Password, "Secure") }
												if($ADUser -ne [Void]$null)
												{
													# Does User already member of the Group
													$UserDN = $ADUser.Properties.Item("distinguishedName")
													if($ADGroup.Member -notcontains $UserDN)
													{
														Write-Host ("Add user '{0}' to group '{1}' members." -f $UnixProfileByUser.User.SamAccountName, $Group.GroupName)
														$ADGroup.Member += $UserDN
														$ADGroup.SetInfo()
													}
													else
													{
														Write-Warning ("User '{0}' is already a member of group '{1}'. Skip action." -f $UnixProfileByUser.User.SamAccountName, $Group.GroupName)
													}
												}
											}
										}
									}
								}
							}
						}
					}
					Write-Host "Done."
					}
				else
				{
					Write-Warning "No existing data for this operation. Skip."
				}
			}
			3 # Import Computer Roles
			{
				if($Zone.ComputerRoles)
				{
					$ImportFile = (".\{0}\Authorization-ComputerRoles.csv" -f $Zone.Name)
					$nbComputerRoles = (Import-Csv $ImportFile).Count
					# Build Menu
					$Title = "Confirm operation?"
					$Message = ""
					$Message += ("Computer Role(s) to import: {0}`n" -f $nbComputerRoles)
					$Choice0 = New-Object System.Management.Automation.Host.ChoiceDescription "&Ok", "Ok to proceed."
					$Choice1 = New-Object System.Management.Automation.Host.ChoiceDescription "&Cancel", "Cancel process."
					$Options = [System.Management.Automation.Host.ChoiceDescription[]]($Choice0, $Choice1)
					# Prompt for choice
					$Prompt = $Host.UI.PromptForChoice($Title, $Message, $Options, 0) 
					switch($Prompt)
					{
						0 # Ok
						{
							Write-Host "`nCalling ADImport..."
							# Call ADImport
							&.\ADImport.ps1 -ComputerRoles $ImportFile -Server $global:Server -Credential $global:Credential -NoBanner -NoProgress
						}
						1 # Cancel
						{
							Write-Host "Operation canceled.`n"
						}
					}
					# Done.
				}
				else
				{
					Write-Warning "No existing data for this operation. Skip."
				}
			}
			4 # Import Roles and Rights
			{
				if($Zone.RolesAndRights)
				{
					$ImportFile = (".\{0}\Authorization-RolesAndUnixRights.csv" -f $Zone.Name)
					$nbRolesAndRights = (Import-Csv $ImportFile).Count
					# Build Menu
					$Title = "Confirm operation?"
					$Message = ""
					$Message += ("Role(s) and Right(s) to import: {0}`n" -f $nbRolesAndRights)
					$Choice0 = New-Object System.Management.Automation.Host.ChoiceDescription "&Ok", "Ok to proceed."
					$Choice1 = New-Object System.Management.Automation.Host.ChoiceDescription "&Cancel", "Cancel process."
					$Options = [System.Management.Automation.Host.ChoiceDescription[]]($Choice0, $Choice1)
					# Prompt for choice
					$Prompt = $Host.UI.PromptForChoice($Title, $Message, $Options, 0) 
					switch($Prompt)
					{
						0 # Ok
						{
							Write-Host "`nCalling ADImport..."
							# Call ADImport
							&.\ADImport.ps1 -RolesAndRights $ImportFile -Server $global:Server -Credential $global:Credential -NoBanner -NoProgress
						}
						1 # Cancel
						{
							Write-Host "Operation canceled.`n"
						}
					}
					# Done.
				}
				else
				{
					Write-Warning "No existing data for this operation. Skip."
				}
			}
			5 # Import Role Assignments
			{ 
				if($Zone.RoleAssignments)
				{
					$ImportFile = (".\{0}\Authorization-RoleAssignments.csv" -f $Zone.Name)
					$nbRoleAssignments = (Import-Csv $ImportFile).Count
					# Build Menu
					$Title = "Confirm operation?"
					$Message = ""
					$Message += ("Role Assignment(s) to import: {0}`n" -f $nbRoleAssignments)
					$Choice0 = New-Object System.Management.Automation.Host.ChoiceDescription "&Ok", "Ok to proceed."
					$Choice1 = New-Object System.Management.Automation.Host.ChoiceDescription "&Cancel", "Cancel process."
					$Options = [System.Management.Automation.Host.ChoiceDescription[]]($Choice0, $Choice1)
					# Prompt for choice
					$Prompt = $Host.UI.PromptForChoice($Title, $Message, $Options, 0) 
					switch($Prompt)
					{
						0 # Ok
						{
							Write-Host "`nCalling ADImport..."
							# Call ADImport
							&.\ADImport.ps1 -RoleAssignments $ImportFile -Server $global:Server -Credential $global:Credential -NoBanner -NoProgress
						}
						1 # Cancel
						{
							Write-Host "Operation canceled.`n"
						}
					}
					# Done.
				}
				else
				{
					Write-Warning "No existing data for this operation. Skip."
				}
			}	
			6 # Change Zone
			{
				Show-ZoneImportMenu -Zone (Get-Zone)
			}
			7 # Return to main menu
			{
				Show-MainMenu
			}
			8 # Quit
			{
				Quit-Menu
			}
		}
		# Build Menu
		$Title = "Do you want to continue ?"
		$Message = ""
		$Choice0 = New-Object System.Management.Automation.Host.ChoiceDescription "&Continue", "Return to menu."
		$Choice1 = New-Object System.Management.Automation.Host.ChoiceDescription "&Quit", "Exit this menu."
		$Options = [System.Management.Automation.Host.ChoiceDescription[]]($Choice0, $Choice1)
		# Prompt for choice
		$Prompt = $Host.UI.PromptForChoice($Title, $Message, $Options, 0) 
		switch($Prompt)
		{
			0 # Continue
			{
				Show-ZoneImportMenu -Zone $Zone
			}
			1 # Quit
			{
				Show-MainMenu
			}
		}
	}
}

<#
function Show-ComputerImportMenu
{
	#######################################################################################
	# PARAMETERS                                                                          #
	#######################################################################################
	param
	(
		[Parameter(Mandatory = $true, HelpMessage = "Specify the Zone of the Computer to process.")]
		[Alias("z")]
		[Object]$Zone,
		
		[Parameter(Mandatory = $true, HelpMessage = "Specify the Computer to process.")]
		[Alias("c")]
		[Object]$Computer
	)
	#######################################################################################
	# SCRIPT BLOCK                                                                        #
	#######################################################################################
	end
	{
		# Menu Title
		Show-Banner ("[Main Menu > Import Menu > {0} Zone > {1} Computer]" -f $Zone.Name, $Computer.Name)
		# Build Menu
		$Title = "Choose an operation to perform:"
		$Message = ""
		if($Computer.Users) { $Message += "U - Import Users.`n"  }
		if($Computer.Groups) { $Message += "G - Import Groups.`n" }
		$Message += "C - Change Computer.`n"
		$Message += "R - Return to Zone menu.`n"
		$Message += "Q - Quit menu."
		$Choice0 = New-Object System.Management.Automation.Host.ChoiceDescription "&Users", "Import Users."
		$Choice1 = New-Object System.Management.Automation.Host.ChoiceDescription "&Groups", "Import Groups." 
		$Choice2 = New-Object System.Management.Automation.Host.ChoiceDescription "Change &Computer", "Change Computer."
		$Choice3 = New-Object System.Management.Automation.Host.ChoiceDescription "&Return", "Return to Zone menu."
		$Choice4 = New-Object System.Management.Automation.Host.ChoiceDescription "&Quit", "Quit menu."
		$Options = [System.Management.Automation.Host.ChoiceDescription[]]($Choice0, $Choice1, $Choice2, $Choice3, $Choice4)
		# Prompt for choice
		$Prompt = $Host.UI.PromptForChoice($Title, $Message, $Options, 0) 
		switch($Prompt)
		{
			0 # Import Users
			{
				if($Zone.Users)
				{
					$ImportFile = (".\{0}\Computers-UNIXData-Users.csv" -f $Zone.Name)
				}
				else
				{
					Write-Warning "No existing data for this operation. Skip."
				}
			}
			1 # Import Groups
			{
				if($Zone.Groups)
				{
					$ImportFile = (".\{0}\Computers-UNIXData-Groups.csv" -f $Zone.Name)
				}
				else
				{
					Write-Warning "No existing data for this operation. Skip."
				}
			}
			2 # Change Computer
			{
				Show-ComputerImportMenu -Zone $Zone -Computer (Get-Computer $Zone.Computers)
			}
			3 # Return to Zone menu
			{
				Show-ZoneImportMenu -Zone $Zone
			}
			4 # Quit
			{
				Quit-Menu
			}
		}
		if($ImportFile -ne [Void]$null)
		{
			# Build Menu
			$Title = "Confirm operation ?"
			$Message = ""
			$Message += ("File to import: {0}`n" -f $ImportFile)
			$Choice0 = New-Object System.Management.Automation.Host.ChoiceDescription "&Ok", "Ok to proceed."
			$Choice1 = New-Object System.Management.Automation.Host.ChoiceDescription "&Cancel", "Cancel process."
			$Options = [System.Management.Automation.Host.ChoiceDescription[]]($Choice0, $Choice1)
			# Prompt for choice
			$Prompt = $Host.UI.PromptForChoice($Title, $Message, $Options, 0) 
			switch($Prompt)
			{
				0 # Ok
				{
					Write-Host "`nCalling ADImport..."
					# Call ADImport
					&.\ADImport.ps1 -Domain $Domain -Credential $Credential -File $ImportFile -Zone $Zone.Name -Computer $Computer.Name -Server $global:Server
				}
				1 # Cancel
				{
					Write-Host "Operation canceled.`n"
				}
			}
			# Done.
		}
		# Build Menu
		$Title = "Do you want to continue ?"
		$Message = ""
		$Choice0 = New-Object System.Management.Automation.Host.ChoiceDescription "&Continue", "Return to menu."
		$Choice1 = New-Object System.Management.Automation.Host.ChoiceDescription "&Quit", "Exit this menu."
		$Options = [System.Management.Automation.Host.ChoiceDescription[]]($Choice0, $Choice1)
		# Prompt for choice
		$Prompt = $Host.UI.PromptForChoice($Title, $Message, $Options, 0) 
		switch($Prompt)
		{
			0 # Continue
			{
				Show-ComputerImportMenu -Zone $Zone -Computer $Computer
			}
			1 # Quit
			{
				Show-ZoneImportMenu -Zone $Zone
			}
		}
	}
}
#>

<#
function Show-AllComputersImportMenu
{
	#######################################################################################
	# PARAMETERS                                                                          #
	#######################################################################################
	param
	(
		[Parameter(Mandatory = $true, HelpMessage = "Specify the Zone of the Computers to process.")]
		[Alias("z")]
		[Object]$Zone,
		
		[Parameter(Mandatory = $true, HelpMessage = "Specify the Computers to process.")]
		[Alias("c")]
		[Array]$Computers
	)
	#######################################################################################
	# SCRIPT BLOCK                                                                        #
	#######################################################################################
	end
	{
		# Menu Title
		Show-Banner ("[Main Menu > Import Menu > {0} Zone > All Computers]" -f $Zone.Name, $Computer.Name)
		# Build Menu
		$Title = "Choose an operation to perform:"
		$Message = ""
		$Message += "U - Import Users.`n"
		$Message += "G - Import Groups.`n"
		$Message += "R - Return to Zone menu.`n"
		$Message += "Q - Quit menu."
		$Choice0 = New-Object System.Management.Automation.Host.ChoiceDescription "&Users", "Import Users."
		$Choice1 = New-Object System.Management.Automation.Host.ChoiceDescription "&Groups", "Import Groups." 
		$Choice2 = New-Object System.Management.Automation.Host.ChoiceDescription "&Return", "Return to Zone menu."
		$Choice3 = New-Object System.Management.Automation.Host.ChoiceDescription "&Quit", "Quit menu."
		$Options = [System.Management.Automation.Host.ChoiceDescription[]]($Choice0, $Choice1, $Choice2, $Choice3)
		# Prompt for choice
		$Prompt = $Host.UI.PromptForChoice($Title, $Message, $Options, 0) 
		switch($Prompt)
		{
			0 # Import Users
			{
				$ImportFile = (".\{0}\Computers-UNIXData-Users.csv" -f $Zone.Name)
			}
			1 # Import Groups
			{
				$ImportFile = (".\{0}\Computers-UNIXData-Groups.csv" -f $Zone.Name)
			}
			2 # Return to Zone menu
			{
				Show-ZoneImportMenu -Zone $Zone
			}
			3 # Quit
			{
				Quit-Menu
			}
		}
		if($ImportFile -ne [Void]$null)
		{
			# Build Menu
			$Title = "Confirm operation ?"
			$Message = ""
			$Message += ("File to import: {0}`n" -f $ImportFile)
			$Choice0 = New-Object System.Management.Automation.Host.ChoiceDescription "&Ok", "Ok to proceed."
			$Choice1 = New-Object System.Management.Automation.Host.ChoiceDescription "&Cancel", "Cancel process."
			$Options = [System.Management.Automation.Host.ChoiceDescription[]]($Choice0, $Choice1)
			# Prompt for choice
			$Prompt = $Host.UI.PromptForChoice($Title, $Message, $Options, 0) 
			switch($Prompt)
			{
				0 # Ok
				{
					Write-Host "Calling ADImport..."
					# Call ADImport
					&.\ADImport.ps1 -Domain $Domain -Credential $Credential -File $ImportFile -Zone $Zone.Name -Server $global:Server
				}
				1 # Cancel
				{
					Write-Host "Operation canceled.`n"
				}
			}
			# Done.
		}
		# Build Menu
		$Title = "Do you want to continue ?"
		$Message = ""
		$Choice0 = New-Object System.Management.Automation.Host.ChoiceDescription "&Continue", "Return to menu."
		$Choice1 = New-Object System.Management.Automation.Host.ChoiceDescription "&Quit", "Exit this menu."
		$Options = [System.Management.Automation.Host.ChoiceDescription[]]($Choice0, $Choice1)
		# Prompt for choice
		$Prompt = $Host.UI.PromptForChoice($Title, $Message, $Options, 0) 
		switch($Prompt)
		{
			0 # Continue
			{
				Show-AllComputersImportMenu -Zone $Zone -Computers $Computers
			}
			1 # Quit
			{
				Show-ZoneImportMenu -Zone $Zone
			}
		}
	}
}
#>

function Show-SettingsMenu
{
	#######################################################################################
	# PARAMETERS                                                                          #
	#######################################################################################
	param()
	#######################################################################################
	# SCRIPT BLOCK                                                                        #
	#######################################################################################
	end
	{
		# Menu Title
		Show-Banner "[Main Menu > Settings]"
		# Build Menu
		$Title = "Choose an operation to perform:"
		$Message = "D - Add/Change Active Directory Domain connexion.`n"
		$Message += "C - Add/Change Active Directory Credential.`n"
		$Message += "R - Return to Main menu.`n"
		$Message += "Q - Quit menu.`n"
		$Choice0 = New-Object System.Management.Automation.Host.ChoiceDescription "&Domain", "Add Active Directory Domain connexion."
		$Choice1 = New-Object System.Management.Automation.Host.ChoiceDescription "&Credential", "Add/Change Active Directory Credential." 
		$Choice2 = New-Object System.Management.Automation.Host.ChoiceDescription "&Return", "Return to Main menu."
		$Choice3 = New-Object System.Management.Automation.Host.ChoiceDescription "&Quit", "Quit menu."
		$Options = [System.Management.Automation.Host.ChoiceDescription[]]($Choice0, $Choice1, $Choice2, $Choice3)
		# Prompt for choice
		$Prompt = $Host.UI.PromptForChoice($Title, $Message, $Options, 2) 
		switch($Prompt)
		{
			0 # Add Active Directory Domain connexion
			{
				Write-Host
				[System.String]$strDomainName = Read-Host "Enter the name of the AD Domain to connect in FQDN format (e.g. company.com)"
				[System.String]$strServerName = Read-Host "Enter the name of the Domain Controller to connect in FQDN format (e.g. dc01.company.com)"
				Set-CdmPreferredServer -Domain $strDomainName -Server $strServerName
				Show-SettingsMenu
				# Done.
			}
			1 # Add/Change Active Directory Credential
			{
				Write-Host
				[System.String]$strDomainName = Read-Host "Enter the name of the AD Domain to connect in FQDN format (e.g. company.com)"
				[Management.Automation.PSCredential]$Credential = Get-Credential
				Set-CdmCredential -Domain $strDomainName -Credential $Credential
				Show-SettingsMenu
				# Done.
			}
			2 # Return to Main menu
			{
				Show-MainMenu
				# Done.
			}
			3 # Quit
			{ 
				Quit-Menu
			}	
		}
	}
}

function Show-MainMenu
{
	#######################################################################################
	# PARAMETERS                                                                          #
	#######################################################################################
	param()
	#######################################################################################
	# SCRIPT BLOCK                                                                        #
	#######################################################################################
	end
	{
		# Menu Title
		Show-Banner "[Main Menu]"
		# Build Menu
		$Title = "Choose an operation to perform:"
		$Message = "A - Analyse UNIX Data to import into Active Directory.`n"
		$Message += "P - Prepare Computers into Active Directory.`n"
		$Message += "I - Import UNIX Data into Centrify Zone.`n"
		$Message += "S - Change Settings.`n"
		$Message += "Q - Quit menu.`n"
		$Choice0 = New-Object System.Management.Automation.Host.ChoiceDescription "&Analyse", "Analyse UNIX Data to import into Active Directory." 
		$Choice1 = New-Object System.Management.Automation.Host.ChoiceDescription "&Prepare", "Prepare Computers into Active Directory." 
		$Choice2 = New-Object System.Management.Automation.Host.ChoiceDescription "&Import", "Import UNIX Data into Centrify Zone." 
		$Choice3 = New-Object System.Management.Automation.Host.ChoiceDescription "Change &Settings", "Change Settings."
		$Choice4 = New-Object System.Management.Automation.Host.ChoiceDescription "&Quit", "Quit menu."
		$Options = [System.Management.Automation.Host.ChoiceDescription[]]($Choice0, $Choice1, $Choice2, $Choice3, $Choice4)
		# Prompt for choice
		$Prompt = $Host.UI.PromptForChoice($Title, $Message, $Options, 0) 
		switch($Prompt)
		{
			0 # Anayse data
			{
				Write-Host "`n`nThis function is not yet implemented in the Menu. Please use scripts located under ./tools instead.`n"
				# Done.
			}
			1 # Prepare Computers
			{
				Show-PrepareComputersMenu -Zone (Get-Zone)
				# Done.
			}
			2 # Import Zone Data
			{
				Show-ZoneImportMenu -Zone (Get-Zone)
				# Done.
			}
			3 # Change settings
			{
				Show-SettingsMenu
				# Done.
			}
			4 # Quit
			{ 
				Quit-Menu
			}	
		}
	}
}

function Quit-Menu
{
	#######################################################################################
	# PARAMETERS                                                                          #
	#######################################################################################
	param()
	#######################################################################################
	# SCRIPT BLOCK                                                                        #
	#######################################################################################
	end
	{
		# Cleanup screen
		Clear-Host
		# Remove PowerShell Module from session	
#		Unload-PSModule -Name "CentrifyDirectControl"		
		# Exit to PSSession
		Exit
	}
}

function Get-ObjectCount
{
	#######################################################################################
	# PARAMETERS                                                                          #
	#######################################################################################
	param
	(
		[Parameter(Position = 0, Mandatory = $true, HelpMessage = "Objects to count.")]
		[Alias("o")]
		[Object]$Objects
	)
	#######################################################################################
	# SCRIPT BLOCK                                                                        #
	#######################################################################################
	end
	{
		if($Objects -ne [Void]$null)
		{
			if($Objects.GetType().BaseType -eq [Array])
			{
				# Objects is an Array, use the Count method				
				$nbObjects = $Objects.Count
			}
			else
			{	
				# Objects is not an Array, means there is only one
				$nbObjects = 1
			}
		}
		else
		{
			# Objects doesn't exist
			$nbObjects = 0
		}
		return $nbObjects
	}
}
				

##########################################
#region ### CENTRIFY POWERSHELL MODULE ###
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
##########################################
#endregion
##########################################

###########################################################################################
# MAIN LOGIC                                                                              #
###########################################################################################

# Get Data and Show the Main Menu
Get-Data
Show-MainMenu
