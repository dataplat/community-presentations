# failsafe
break

<#
The dbatools parameter for instances

Its premise: Accept any object that legally represents a database

Benefits:
 - User does not have to think in types
 - Easy to implement for contributors
 - Easy to update for all commands in dbatools
#>

# We need to explicitly import for this if it's not already imported
Import-Module dbatools

# A small demo function that shows what reached the inside of the function
function Get-DbaTest
{
    [CmdletBinding()]
    Param (
        [Parameter(ValueFromPipeline = $true)]
        [DbaInstanceParameter[]]
        $SqlInstance
    )

    process
    {
        foreach ($instance in $SqlInstance)
        {
            $instance
        }
    }
}

# Let's try just a computername
Get-DbaTest -SqlInstance sql2014

# Maybe add an instance name
Get-DbaTest -SqlInstance sql2014\foo

# This is not doing any external lookups btw
Get-DbaTest -SqlInstance foo\bar

# Port numbers are ok as well
Get-DbaTest -SqlInstance "foo,1234"

# Or if you come from the networking side of things
Get-DbaTest -SqlInstance "foo:1234"

# How about some sql customary usages?
Get-DbaTest -SqlInstance "."

# Or piped?
"." | Get-DbaTest

# I've heard dbas hate/love connection strings
Get-DbaTest -SqlInstance "Server=myServerAddress;Database=myDataBase;Trusted_Connection=True;"

# Remember this path?
Get-DbaTest -SqlInstance "\\.\pipe\sql\query"
Get-DbaTest -SqlInstance "\\foo\pipe\sql\query"
Get-DbaTest -SqlInstance '\\foo\pipe\MSSQL$bar\sql\query'

# Dns Resolutions?
[System.Net.Dns]::Resolve("sql2016")
[System.Net.Dns]::Resolve("sql2016") | Get-DbaTest

# Active Directory Computer?
Get-ADComputer sql2016 | Get-DbaTest

<#
Key takeaway:
If you think an object - the output of a command,
or an object of a given type - should be legal input
to target an instance, it probably is.

It's also easy to add.
So don't hesitate to ask for the feature!
#>