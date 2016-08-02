function Get-ADDomain() {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [ValidateNotNull()]
        [ValidateSet('Negotiate','Basic')]
        [string]
        ${AuthType},

        [Parameter(Mandatory=$false)]
        [ValidateNotNull()]
        [pscredential]
        ${Credential},

        [Parameter(Mandatory=$false)]
        [ValidateSet('LocalComputer','LoggedOnUser')]
        [string]
        ${Current},

        [Parameter(Mandatory=$false)]
        [ValidateNotNull()]
        [string]
        ${Identity},

        [Parameter(Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        [string]
        ${Server}
    )
}

Export-ModuleMember -Function @(
    'Get-ADDomain'
)
