function New-MenuContent
{
    Param(
        # Some items
        [Parameter(Mandatory=$true)][Array]$Array,
        # Name of a Property to be returned by ToString
        [Parameter(Mandatory=$false)][String]$DisplayProperty
    )

    # GetItemName was unable to access $DisplayProperty when it was 
    # called from another script that initialized the whole object
    $script:displayProperty = $DisplayProperty

    # Add Items property with some content, #
    # properties to items in the menu,      #
    # an ItemMaxLen property                #
    
    $content = [PSCustomObject]@{
        Items = $Array
        ItemMaxLen = 0
        CurrentItem = 0
        SelectedItems = [System.Collections.ArrayList]@()
    }

    # Add CurrentItem property to indicate currently selected item via  #
    # its index in the Items property. Add Methods to get the item and  #
    # to move to next and previous item.                                #

    $content | Add-Member -MemberType ScriptMethod -Name GetCurrentItem -Value `
    {
        $this.Items[$this.CurrentItem]
    }
    
    $content | Add-Member -MemberType ScriptMethod -Name ToggleCurrentItemSelection -Value `
    {
        # Adds current item to selected items or removes it from them
        if ($this.SelectedItems -notcontains $this.CurrentItem) {
            $this.SelectedItems.Add($this.CurrentItem) | Out-Null
        } else {
            $this.SelectedItems.Remove($this.CurrentItem)
        }
    }

    $content | Add-Member -MemberType ScriptMethod -Name GetSelectedItems -Value `
    {
        foreach ($index in $this.SelectedItems) {
            $this.Items[$index]
        }
    }

    $content | Add-Member -MemberType ScriptMethod -Name NextItem -Value `
    {
        $nextItem = $this.CurrentItem + 1
        if ($this.Items[$nextItem]) {
            $this.CurrentItem = $nextItem
        } else {
            $this.CurrentItem = 0
        }
    }
    
    $content | Add-Member -MemberType ScriptMethod -Name PreviousItem -Value `
    {
        $nextItem = $this.CurrentItem - 1
        if ($nextItem -ge 0) {
            $this.CurrentItem = $nextItem
        } else {
            $this.CurrentItem = $this.Items.Count - 1
        }
    }

    $content | Add-Member -MemberType ScriptMethod -Name FindNextItem -Value `
    {
        Param(
            # A pattern to match
            [Parameter(Mandatory=$true)][String]$Pattern
        )
        # Set the item next to the current one as the first to be matched against
        $nextItem = $this.CurrentItem + 1
        if (-not $this.Items[$nextItem]) { $nextItem = 0 }

        # Iterate through items
        while ($true) {
            if ($this.GetItemName($nextItem) -match $Pattern) {
                # Set it as the current item and return $true to indicate a match was found
                $this.CurrentItem = $nextItem
                return $true
            }
            $nextItem += 1
            if (-not $this.Items[$nextItem]) { $nextItem = 0 }

            # If we have iterated through the complete list and found 
            # no matching items, return $false to indicate no match was found
            if ($nextItem -eq $this.CurrentItem + 1) {
                return $false
            }
        }
    }

    $content | Add-Member -MemberType ScriptMethod -Name FindPreviousItem -Value `
    {
        # TODO Implement
    }

    $content | Add-Member -MemberType ScriptMethod -Name GetItemName -Value `
    {
        Param(
            [Parameter(Mandatory=$false)][Int]$ItemIndex = $this.CurrentItem
        )
        $item = $this.Items[$ItemIndex]
        if (-not $script:displayProperty -or (-not $item.$script:displayProperty)) {
            # Either the user didn't set DisplayProperty or the item doesn't 
            # contain a property by that name
            if ($item | Get-Member -MemberType Method, ScriptMethod -Name ToString) {
                # A ToString method seems to exist, however! We cannot trust it. At least as 
                # I was testing, a fresh [PSCustomObject] had a ToString method... which returns
                # an emptry string. Useful. Let's see if it actually returns something:
                if ($item.ToString().Length -gt 0) {
                    # It does, let's return that
                    return $item.ToString()
                }
            }
            # So can't use ToString, let's try to guess at a 
            # property that makes sense to display on a menu
            if ($item | Get-Member -MemberType Property, NoteProperty -Name Name) {
                # Use Name as a property in ToString since there is one
                return $item.Name
            } elseif ($item | Get-Member -MemberType Property, NoteProperty -Name *Name*) {
                # Return the first property that contains Name... in the name.
                $propName = ($item | Get-Member -MemberType Property, NoteProperty -Name *Name*)[0].Name
                return $item.$propName
            } elseif ($item | Get-Member -MemberType Property, NoteProperty) {
                # Just settle with something then
                $propName = ($item | Get-Member -MemberType Property, NoteProperty)[0].Name
                return $item.$propName
            } else {
                # We are dealing with a scroundrel feeding us strange, propertyless objects
                return "CANT_FIND_A_NAME"
            }
        } else {
            return ($item.$script:displayProperty).ToString() # NOTE ToString() usually makes dates and other types printable
        }
    }

    $content | Add-Member -MemberType ScriptMethod -Name SetItemMaxLength -Value `
    {
        $i = 0
        $y = $content.Items.Count - 1
        $i..$y | Foreach-Object {
            $itemLen = $this.GetItemName($_).Length
            if ($itemLen -gt $content.ItemMaxLen) {
                $content.ItemMaxLen = $itemLen
            }
        }
    }
    
    $content.SetItemMaxLength()

    $content
}

Export-ModuleMember -Function New-MenuContent
