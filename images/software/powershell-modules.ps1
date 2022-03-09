$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# Specifies the installation policy
Set-PSRepository -InstallationPolicy Trusted -Name PSGallery

# Try to update PowerShellGet before the actual installation
Install-Module -Name PowerShellGet -Force
Update-Module -Name PowerShellGet -Force

# Install PowerShell modules
$modules = "az"

foreach($module in $modules)
{
    Write-Host "Installing ${module} module"
    Install-Module -Name $module -Scope AllUsers -SkipPublisherCheck -Force
}
