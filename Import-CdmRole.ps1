###############################################################################################################
# Import-CdmRole - Import Role using CSV format
#
# Author       : Fabrice Viguier
# Contact      : fabrice.viguier AT centrify.com
# Release      : 9/5/2017
# Version      : Git repository https://bitbucket.org/centrifyps/cmdletsextension
###############################################################################################################

<#
.SYNOPSIS
This Cmdlet is intend to import Role(s) using CSV data

.DESCRIPTION
This Cmdlet will import one or more Role(s) in one or more Zone(s) by using data stored in a CSV formated file. 

.PARAMETER Domain
Specify the AD Domain name where perform actions in FQDN format (e.g. company.com).

.PARAMETER Credential
Specify the PSCredential of an AD User to perform actions on AD (e.g. (Get-Credential NTDOMAIN\Administrator)).

.PARAMETER FilePath
Specify CSV file with data to import.

.PARAMETER CreateADGroup
Specify if missing AD Group(s) should be created.

.PARAMETER Force
Overwrite existing definition.

.PARAMETER PassThru
Return created object(s).

.PARAMETER Progress
Show progress bar.

.INPUTS
None

.OUTPUTS
None

.EXAMPLE

.EXAMPLE

.LINK
#>

param
(
	[Parameter(Mandatory = $false, HelpMessage = "Specify the AD Domain name where perform actions in FQDN format (e.g. company.com).")]
	[Alias("d")]
	[System.String]$Domain = [DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain().Name,

	[Parameter(Mandatory = $false, HelpMessage = "Specify the PSCredential of an AD User to perform actions on AD (e.g. (Get-Credential NTDOMAIN\Administrator)).")]
	[Management.Automation.PSCredential]$Credential, 

	[Parameter(Mandatory = $false, HelpMessage = "Specify Domain Controller name to connect.")]
	[Alias("s")]
	[System.String]$Server,

	[Parameter(Mandatory = $true, Position = 0, HelpMessage = "Specify CSV file with data to import.")]
	[Alias("f")]
	[System.String]$FilePath,
	
	[Parameter(Mandatory = $false, HelpMessage = "Overwrite existing definition.")]
	[Switch]$Force,

	[Parameter(Mandatory = $false, HelpMessage = "Return created object(s).")]
	[Switch]$PassThru,

	[Parameter(Mandatory = $false, HelpMessage = "Show progress bar.")]
	[Switch]$Progress
)

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

# Set preferred Domain Controller
if (-not [System.String]::IsNullOrEmpty($Server))
{
	Set-CdmPreferredServer -Domain $Domain -Server $Server
}

# Set PSCredential for Domain connection
if ($Credential -ne [Void]$null)
{
	Set-CdmCredential -Domain $Domain -Credential $Credential
}

# Read CSV Data
if (Test-Path -Path $FilePath)
{
	$Data = Import-Csv -Path $FilePath
	if ($Data -eq [void]$null)
	{
		Throw "Unable to load CSV data."
	}
	Write-Debug ("Processing CSV File: {0}" -f $FilePath)	
}

# Get list of parameters from CSV file header, removing doublequotes to allow hashtable convertion
$Header = (Get-Content -Path $FilePath)[0].Replace('"', '') -Split ','

# Import Role
$index = 1
$Data | ForEach-Object {
	if ($Progress.IsPresent)
	{
		if ($Data.GetType() -eq [System.Array])
		{
			$Count = $Data.Count
		}
		else
		{
			$Count = 1
		}
		# Show progress for overall import
		$OverallProgressActivity	= ("Import Role [{0}/{1}]" -f $index, $Count)
		$OverallProgressStatus		= "Percent processed: "
		$OverallProgressComplete	= (($index / $Count)*100)
		$index++
		Write-Progress -Activity $OverallProgressActivity -Status $OverallProgressStatus -PercentComplete $OverallProgressComplete -Id 1
	}
	# Debug informations
	Write-Debug ("Processing Entry: {0}" -f $_)

	# Create Hash from Array of Parameters
	try
	{
		$CmdletParameters = @{}
		foreach ($Key in $Header)
		{
			# Convert only non-null value
			if (-not [System.String]::IsNullOrEmpty($_.$Key))
			{
				$CmdletParameters[$Key] = $_.$Key
			}
		}
	}
	catch
	{
		Throw $_.Exception
	}

	# Validate Parameters

	# Zone must be given using DN format
	if (-not [System.String]::IsNullOrEmpty($_.Zone))
	{
		if ($_.Zone -notmatch "^CN=" -and $_.Zone -notmatch "^OU=")
		{
			# Get Centrify Zone DN and replace value
			try
			{
				$CmdletParameters.Zone = (Get-CdmZone -Name $_.Zone -Domain $Domain).DistinguishedName
			}
			catch
			{
				Throw $_.Exception
			}
		}		
	}
	
	# Formating Array from Strings
	if (-not [System.String]::IsNullOrEmpty($_.UnixSysRights))
	{
		$CmdletParameters.UnixSysRights = $_.UnixSysRights -Split ','
	}
	if (-not [System.String]::IsNullOrEmpty($_.WinSysRights))
	{
		$CmdletParameters.WinSysRights = $_.WinSysRights -Split ','
	}
	
	# Formating Bollean values
	if (-not [System.String]::IsNullOrEmpty($_.HasRescueRight) -and $_.HasRescueRight -eq "true")
	{
		$CmdletParameters.HasRescueRight = $true
	}
	else
	{
		$CmdletParameters.HasRescueRight = $false
	}
	
	if (-not [System.String]::IsNullOrEmpty($_.AllowLocalUser) -and $_.AllowLocalUser -eq "true")
	{
		$CmdletParameters.AllowLocalUser = $true
	}
	else
	{
		$CmdletParameters.AllowLocalUser = $false
	}
		
	# Create Role
	try
	{
		$CdmRole = New-CdmRole @CmdletParameters
	}
	catch [System.ApplicationException]
	{
		if ($_.Exception.Message -match "Failed to commit the role. .* already exists")
		{
			if ($Force.IsPresent)
			{
				# Try to overwrite object definition
				$CdmZone = $CmdletParameters.Zone
				$CmdletParameters.Remove("Zone")
				Write-Debug ("Overwriting existing role '{0}'" -f $CmdletParameters.Name)
				
				# Set Object
				$CdmRole = (Get-CdmRole -Zone $CdmZone -Name $CmdletParameters.Name | Set-CdmRole @CmdletParameters)
			}
			else
			{
				# Cannot create Role that already exists
				Write-Warning $_.Exception.Message.Replace("the role", ("role '{0}' in zone {1}" -f $CmdletParameters.Name, $CmdletParameters.Zone))
			}
		}
		else
		{
			# Unknown exception
			Throw $_.Exception
		}
	}
	catch
	{
		# Unknown exception
		Throw $_.Exception
	}	

	# If Role has login or ssologin given, add login-all PAM Access Right to the Role
	if ($CdmRole.UnixSystemRights -contains "login" -or $CdmRole.UnixSystemRights -contains "ssologin")
	{
		$CdmRight = Get-CdmPamRight -Zone $CdmRole.Zone -Name "login-all"
		if ($CdmRight -eq [void]$null)
		{
			# If predefined PAM Right login-all does not exist in this Zone, create it first
			$CdmRight = New-CdmPamRight -Zone $CdmRole.Zone -Name "login-all" -Application "*" -Description "Predefined global PAM permission. Do not delete."
		}
		Add-CdmPamRight -Role $CdmRole -Right $CdmRight
	}

	# Return object if PassThru is set
	if ($PassThru.IsPresent)
	{
		$CdmRole
	}
}
if ($Progress.IsPresent)
{
	# Close progress bar
	Write-Progress -Activity "All Computers done" -Status "Hidden" -Id 1 -Completed
}

# SIG # Begin signature block
# MIIEKgYJKoZIhvcNAQcCoIIEGzCCBBcCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUWuwqrJ5Kzh8hMW1OPjvdDOBc
# R+GgggI3MIICMzCCAaCgAwIBAgIQxH+aGsBVZbxNZjfCW1OLZDAJBgUrDgMCHQUA
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
# BAGCNwIBCzEOMAwGCisGAQQBgjcCARUwIwYJKoZIhvcNAQkEMRYEFOc/30itaNAr
# WpfD18TLjp3Q4bwCMA0GCSqGSIb3DQEBAQUABIGAj0z0bPeOEjIH5MJmyp9FNCbQ
# zvcoOjXCBJaBsLCC+FK8Uh0Jy7lbgjM2pVEUwN2k7pynjNZJ70TtGpVC163gvFcW
# VcFH37l/Vl7MHJFpvHbWD8IjcU1vQyjL/W2jw6X9XfIQ9ll3GzGzteHXhjEU99hn
# G2mJX2nf/8c7gGuKgBI=
# SIG # End signature block
