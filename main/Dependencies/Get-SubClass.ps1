﻿function Get-SubClass{
[cmdletbinding()]
param(
    [string]$Name
)

$filter="(|(distinguishedname=$Name)(samaccountname=$Name)(name=$Name))"
switch($Name){
    'Administrators'{$object=Get-ADGroup -LDAPFilter $filter}
    Default{$object=Get-ADObject -LDAPFilter $filter}
}

if(!$object){
    $eMessage="Cannot find an object with identity: '{0}' under: '{1}'." -f $Name,$((Get-ADDomain).DistinguishedName)
    throw $eMessage
}
if($object.count -gt 1){
    throw "Multiple objects with Name '$Name' were found. Use DistinguishedName for unique output."
}

$culture=(Get-Culture).TextInfo

$subClass=switch($object.ObjectClass)
{
    'User'{
        
        $hash=@{
            Properties='a-userObjectCode','a-userObjectSubCode','userPrincipalName'
            Identity=$object.DistinguishedName
        }
        $props=Get-ADObject @hash
        
        switch($props.'a-userObjectCode')
        {
            '1'{
                if($props.Name -match '^ads\.|^gdn\.|^sads\.'){'Admin Account'}
                else{'Enterprise ID'}
            }
            '2'{'Contractor ID'}
            '3'{
                switch($props.'a-userObjectSubCode')
                {
                    '8'{'Standard Mailbox'}
                    '16'{'Custom Mailbox'}
                    Default{'Application ID'}
                }
            }
            '5'{'Test ID'}
            '6'{'Alias'}
            '8'{'Client ID'}
            '9'{'Restricted Contractor'}
            Default{'Other'}
        }
    }

    'Group'{

        $props=Get-ADGroup $object.Name
        switch($props.GroupCategory)
        {
            'Distribution'{'Distribution List'}
            'Security'{'Security Group'}
            Default{$_}
        }
    }
    'Computer'{
        (Get-ADComputer $object.Name -Properties OperatingSystem).OperatingSystem
    }
    'msDS-GroupManagedServiceAccount'{'gMSA Account'}
    Default{$object.ObjectClass}
}

[psCustomObject]@{
    Name=$object.Name
    UserPrincipalName=$props.UserPrincipalName
    ObjectClass=$culture.ToTitleCase($object.ObjectClass)
    SubClass=$subClass
}

}