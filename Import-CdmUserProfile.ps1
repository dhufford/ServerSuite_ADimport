###############################################################################################################
# Import-CdmUserProfile - Import User Profile using CSV format
#
# Author       : Fabrice Viguier
# Contact      : fabrice.viguier AT centrify.com
# Release      : 9/5/2017
# Version      : Git repository https://bitbucket.org/centrifyps/cmdletsextension
###############################################################################################################

<#
.SYNOPSIS
This Cmdlet is intend to import UNIX User Profile(s) using CSV data

.DESCRIPTION
This Cmdlet will import one or more UNIX User Profile(s) at Zone or Computer level by using data stored in a CSV formated file.

.PARAMETER Domain
Specify the AD Domain name where perform actions in FQDN format (e.g. company.com).

.PARAMETER Credential
Specify the PSCredential of an AD User to perform actions on AD (e.g. (Get-Credential NTDOMAIN\Administrator)).

.PARAMETER FilePath
Specify CSV file with data to import.

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

# Import User Profiles
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
		$OverallProgressActivity	= ("Import User Profiles [{0}/{1}]" -f $index, $Count)
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

	# AD Computer must be given using DN format
	if (-not [System.String]::IsNullOrEmpty($_.Computer))
	{
		if ($_.Computer -notmatch "^CN=")
		{
			# Get AD Computer DN and replace value
			try
			{
				$CmdletParameters.Computer = (Get-CdmManagedComputer -Name $_.Computer).Computer.DistinguishedName
			}
			catch
			{
				Throw $_.Exception
			}
		}		
	}

	# AD User must be given using <sAMAccountName>@<domainName> format
	if ($_.User -notmatch "^.*@.*$")
	{
		# Append Domain Name and replace value
		$CmdletParameters.User = ("{0}@{1}" -f $_.User, $Domain)
	}		
	
	# Create User Profile
	try
	{
		$CdmUserProfile = New-CdmUserProfile @CmdletParameters
	}
	catch [System.ApplicationException]
	{
		if ($_.Exception.Message -match "Duplicated username")
		{
			if (-not [System.String]::IsNullOrEmpty($CmdletParameters.Computer))
			{
				# Cannot create User Profile at Computer level
				Write-Warning ("Duplicated username '{0}' in computer '{1}'" -f $CmdletParameters.Login, (($CmdletParameters.Computer -Split ',')[0] -Split '=')[1])
			}
			else
			{
				# Cannot create User Profile at Zone level
				Write-Warning $_.Exception.Message
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
		if ($_.Exception.Message -match "Failed to get object")
		{
			# Cannot find AD User in Domain
			Write-Error $_.Exception.Message
		}
		else
		{
			# Unknown exception
			Throw $_.Exception
		}
	}

	# Return object if PassThru is set
	if ($PassThru.IsPresent)
	{
		$CdmUserProfile
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
