# TODO Add HELP and such...

$PSScriptRoot = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition

Get-ChildItem $PSScriptRoot\subModules\*.psm1 | Foreach-Object {
    Import-Module $_.FullName -Force
}

function New-Menu
{
    Param(
        # Menu items
        [Parameter(
            Mandatory=$false,
            ValueFromPipeline=$true
        )][System.Object[]]$InputObject,
        # The name of the property of items to be displayed on the menu, such as Name
        [Parameter(Mandatory=$false)][String]$DisplayProperty,   
        #     Default: Select one by hitting Enter
        # Multiselect: Pick multiple items with Space, select with Enter
        #        List: Display a list of items and return them
        [Parameter(Mandatory=$false)]
        [ValidateSet('Multiselect','List','Default')]
        [String]$Mode = 'Default',
        # Horizontal position of the upper left corner
        [int]$X = $null,
        # Vertical position of the upper left corner
        [int]$Y = $null,
        # Disable automatically resizing the menu to fit items
        [Switch]$NoAutoSize,
        # Width of the menu
        [Int]$Width = 12,
        # Height of the menu
        [Int]$Height = 6,
        # Character to write on empty cells like edges
        [Char]$Character = ' ',
        # Foreground color
        [String]$ItemColor,
        # Background color
        [String]$BackgroundColor,
        # Indicates current item
        [String]$ItemHighlightColor = 'Green',
        # Indicates an item is selected
        [String]$ItemSelectedColor = 'Yellow',
        # Indicates a color is both current and selected
        [String]$ItemHighlightedAndSelectedColor = 'Magenta',
        # Edge width
        [Int]$EdgeWidth = 2,
        # Edge height
        [Int]$EdgeHeight = 1
    )
    
    # This Begin-Process-End block is here just to make it possible to 
    # pass the input object from pipeline... for which there's probably 
    # a better way of doing than this.
    Begin {
        $tmp = $()
    } Process {
        $tmp += $InputObject
    } End {
        $InputObject = $tmp
        
        # TODO I am yet to deal with menus that can not fit their items (NoAutoSize can be forced to do this), 
        # menus that can't fit the window vertically.
        # TODO Deal with the above by:
        # Partially hiding too long items
        #   Scrolling the item can be added later
        #     Possibly should add GetItemLength to the content module. That uses GetItemName.
        # giving an error at some point I guess
        # I guess I could allow an infinetily small menu too. Like an invisible one.

        # NOTE Let's not accept empty strings and such. For now at least. They 
        # break -something-, probably GetItemName in New-MenuContent
        $InputObject = $InputObject | Where-Object { $_ }

        # NOTE As a quick fix for List Mode being given an empty list 
        # when nothing was picked in -MultiSelect, I changed InputObject 
        # to not being mandatory and added the following line:
        if (-not $InputObject) { return }

        # These can't seem to be defined directly as the default values in the parameters
        if (-not $ItemColor) { $ItemColor = $Host.UI.RawUI.BackgroundColor }
        if (-not $BackgroundColor) { $BackgroundColor = $Host.UI.RawUI.ForegroundColor }

        # TODO ?-icon for invoking help. No other help texts etc. 
        # required. Just tell user Esc is cancel, Enter confirm.
        # TODO A search function such like pressing / starts taking 
        # input and with each added character the string is matched 
        # against the items on the menu
        # TODO Add different options for automatic positioning 
        # of the menu, such as in the middle of the buffer or 
        # where the cursor is at
        # TODO Add indicators for lists higher than the window, for example:
        #
        #   +
        # ITEM 3
        # ITEM 4
        # ITEM 5
        #   +
        #
        # ...I do not want to implement those in New-Square though. I might have to.
        
        # Create a mapping object for attaching an item index number to a line number on the buffer
        $script:lineMap = @()

        $firstMenuItemLineNumber = 0 # Line on which to write the first displayed item
         $lastMenuItemLineNumber = 0 # Line on which to write the last displayed item
        $firstDisplayedItemIndex = 0 # Index number of the first item getting displayed
        # $lastDisplayedItemIndex = 0 # Index number of the last item getting displayed
        
        if ($InputObject -isnot [Array]) {
            $InputObject = @($InputObject)
        }
        
        $menu = [PSCustomObject]@{
            Content =   if (-not $DisplayProperty) {
                            New-MenuContent -Array $InputObject
                        } else {
                            New-MenuContent -Array $InputObject -DisplayProperty $DisplayProperty
                        }
            ItemHighlightColor = $ItemHighlightColor
            EdgeWidth = $EdgeWidth
            EdgeHeight = $EdgeHeight
        }

        $menu | Add-Member -MemberType NoteProperty -Name ID -Value (Get-Random)

        $menu | Add-Member -MemberType NoteProperty -Name Square -Value (
            New-Square -X $X -Y $Y -Width $Width -Height $Height -Character $Character `
                -ForegroundColor $ItemColor -BackgroundColor $BackgroundColor
        )


        $menu | Add-Member -MemberType ScriptMethod -Name SetSquareWidthToItemWidth -Value `
        {
            $this.Square.SetWidth($this.Content.ItemMaxLen)
        }

        $menu | Add-Member -MemberType ScriptMethod -Name SetSquareHeightToItemHeight -Value `
        {
            if ($this.Content.Items.Count + $EdgeHeight * 2 -gt $Host.UI.RawUI.WindowSize.Height) {
                # The square will not fit in the window, make it the same height as the window
                $this.Square.SetHeight($Host.UI.RawUI.WindowSize.Height - $EdgeHeight * 2)
            } else {
                $this.Square.SetHeight($this.Content.Items.Count)
            }
        }

        $menu | Add-Member -MemberType ScriptMethod -Name SetSquareToItemSize -Value `
        {
            $this.SetSquareWidthToItemWidth()
            $this.SetSquareHeightToItemHeight()
        }

        # Automatically size the menu to fit items on it
        if ((-not $NoAutoSize.IsPresent) -and ($menu.Content.Items)) {
            $menu.SetSquareToItemSize()
        }

        $menu.Square.GrowWidth($menu.EdgeWidth * 2)
        $menu.Square.GrowHeight($menu.EdgeHeight * 2)
         
        if ($X -eq 0 -and $Y -eq 0) {
            # Move the menu horizontally to the middle of the window
            $menu.Square.SetPosition(
                ([Math]::Floor($Host.UI.RawUI.WindowSize.Width / 2) - $menu.Square.Width),
                ($menu.Square.Position.Y)
            )

            # Move the menu vertically to the middle of the window
            $menu.Square.SetPosition(
                ($menu.Square.Position.X),
                (
                    ($menu.Square.Position.Y + [Math]::Floor($Host.UI.RawUI.WindowSize.Height / 2)) - `
                    [Math]::Floor($menu.Square.Height / 2)
                )
            )
        }

        # Set which line to write the first item to the beginning of the menu
        $firstMenuItemLineNumber = $menu.Square.Position.Y + $menu.EdgeHeight
        
        # Set which line to write the last item to the end of the menu
        $lastMenuItemLineNumber = $menu.Square.Position.Y + $menu.Square.Height - ($menu.EdgeHeight * 2)

        # Set the index of the last item to write to correspond to the height of the menu
        $lastDisplayedItemIndex = $firstDisplayedItemIndex + $menu.Square.Height - ($menu.EdgeHeight * 2)

        # At this point we can simply start picking the indeces from 0, incrementing by 1 on each line
        $i = 0
        foreach ($lineNumber in $firstMenuItemLineNumber..$lastMenuItemLineNumber) {
            $script:lineMap += [PSCustomObject]@{
                Number    = $lineNumber
                ItemIndex = $i
            }
            $i++
        }

        $menu | Add-Member -MemberType ScriptMethod -Name GetItemColor -Value `
        {
            Param(
                [Int]$ItemIndex = $this.Content.CurrentItem
            )

            # Returns $ItemColor, $ItemHighlightColor, 
            # $ItemSelectedColor or $ItemHighlightedAndSelectedColor 
            # depending on the state of the item

            $color = $this.Square.ForegroundColor
            if ($Mode -eq 'List') { return $color } # We do not highlight things in listmode

            if ($ItemIndex -eq $this.Content.CurrentItem) {
                $color = $ItemHighlightColor
            }
            
            if ($this.Content.SelectedItems -contains $ItemIndex) {
                $color = $ItemSelectedColor
            }

            if ($ItemIndex -eq $this.Content.CurrentItem -and $this.Content.SelectedItems -contains $ItemIndex) {
                $color = $ItemHighlightedAndSelectedColor
            }

            $color
        }

        $menu | Add-Member -MemberType ScriptMethod -Name WriteItem -Value `
        {
            Param(
                [Int]$ItemIndex = $this.Content.CurrentItem,
                [Int]$LineNumber = 0,
                [String]$ItemColor = $this.GetItemColor($ItemIndex)
            )

            $pos   = $Host.UI.RawUI.WindowPosition
            $pos.X = $this.Square.Position.X + $this.EdgeWidth
            $pos.Y = $LineNumber

            $outBuffer = $Host.UI.RawUI.NewBufferCellArray(
                $this.Content.GetItemName($ItemIndex),
                $ItemColor, 
                $this.Square.BackgroundColor
            )

            $Host.UI.RawUI.SetBufferContents($pos,$outBuffer)
        }

        $menu | Add-Member -MemberType ScriptMethod -Name WriteItems -Value `
        {
            if (-not $this.Content.Items) { return }
            if ($this.Content.Items.Count -eq 1) {
                $currentItemLine = `
                    ($script:lineMap | Where-Object { $_.ItemIndex -eq $this.Content.CurrentItem }).Number
                $this.WriteItem(0, $currentItemLine)
            } else {
                foreach ($line in $script:lineMap) {
                    $this.WriteItem($line.ItemIndex, $line.Number)
                }
            }
        }

        $menu | Add-Member -MemberType ScriptMethod -Name WriteMenu -Value `
        {
            $this.Square.WriteToConsoleBuffer()
            $this.WriteItems()
        }

        $menu | Add-Member -MemberType ScriptMethod -Name UpdateLineMap -Value `
        {
            $script:lineMap = @()
            foreach ($lineNumber in $firstMenuItemLineNumber..$lastMenuItemLineNumber) {
                $script:lineMap += [PSCustomObject]@{
                    Number    = $lineNumber
                    ItemIndex = $this.Content.CurrentItem
                }
                # We do not want to move to the next item if we already have a full map
                if ($lineNumber -lt $lastMenuItemLineNumber) {
                    $this.Content.NextItem()
                }
            }
        }

        $menu | Add-Member -MemberType ScriptMethod -Name NextItem -Value `
        {
            # Write the current item with default colors
            $currentItemLine = ($script:lineMap | Where-Object { $_.ItemIndex -eq $this.Content.CurrentItem }).Number
            $fgColor = $ItemColor
            if ($this.Content.SelectedItems -contains $this.Content.CurrentItem) {
                $fgColor = $ItemSelectedColor
            }
            $this.WriteItem($this.Content.CurrentItem, $currentItemLine, $fgColor)

            # Select next item and write it with ItemHighlightColor
            $this.Content.NextItem()
            $currentItemLine = ($script:lineMap | Where-Object { $_.ItemIndex -eq $this.Content.CurrentItem }).Number
            # See if we have run out of items on $script:lineMap
            if (-not $currentItemLine) {
                # Rebuild $script:lineMap
                $this.UpdateLineMap()
                # Make the first item on the list the current one
                $this.Content.CurrentItem = ($script:lineMap | Select-Object -First 1).ItemIndex
                # Rewrite the menu using the new map
                $this.WriteMenu()
            } else {
                $this.WriteItem($this.Content.CurrentItem, $currentItemLine)
            }
        }
     
        $menu | Add-Member -MemberType ScriptMethod -Name PreviousItem -Value `
        {
            # Write the current item with default colors
            $currentItemLine = ($script:lineMap | Where-Object { $_.ItemIndex -eq $this.Content.CurrentItem }).Number
            $fgColor = $ItemColor
            if ($this.Content.SelectedItems -contains $this.Content.CurrentItem) {
                $fgColor = $ItemSelectedColor
            }
            $this.WriteItem($this.Content.CurrentItem, $currentItemLine, $fgColor)

            # Select previous item and write it with ItemHighlightColor
            $this.Content.PreviousItem()
            $currentItemLine = ($script:lineMap | Where-Object { $_.ItemIndex -eq $this.Content.CurrentItem }).Number
            # See if we have run out of items on $script:lineMap
            if (-not $currentItemLine) {
                # First move back on the list of items to find the correct one to start writing from
                2..($script:lineMap.Count) | Foreach-Object { $this.Content.PreviousItem() }
                # Rebuild $script:lineMap
                $this.UpdateLineMap()
                # Rewrite the menu using the new map
                $this.WriteMenu()
            } else {
                $this.WriteItem($this.Content.CurrentItem, $currentItemLine)
            }
        }
        
        # Write the next batch of items (if there's too many items to show simultaneously)
        $menu | Add-Member -MemberType ScriptMethod -Name NextPage -Value `
        {
            # Check that there's actually more items on the list than can fit on the menu
            if ($this.Content.Items.Count -le $lastMenuItemLineNumber - $firstMenuItemLineNumber - 1) { return }

            # Get to the last item on $script:linemap using $this.Content.NextItem()
            while ($this.Content.CurrentItem -ne $script:linemap[-1].ItemIndex) {
                $this.Content.NextItem()
            }
            # Do $this.NextItem() to move to next page
            $this.NextItem()
        }

        # Write the previous batch of items (if there's too many items to show simultaneously)
        $menu | Add-Member -MemberType ScriptMethod -Name PreviousPage -Value `
        {
            # Check that there's actually more items on the list than can fit on the menu
            if ($this.Content.Items.Count -le $lastMenuItemLineNumber - $firstMenuItemLineNumber - 1) { return }

            # Get to the first item on $script:linemap using $this.Content.PreviousItem()
            while ($this.Content.CurrentItem -ne $script:linemap[0].ItemIndex) {
                $this.Content.PreviousItem()
            }
            # Do $this.PreviousItem() to move to last page
            $this.PreviousItem()
        }

        # Find next item matching a pattern
        $menu | Add-Member -MemberType ScriptMethod -Name FindNextItem -Value `
        {
            Param(
                [Parameter(Mandatory=$true)][String]$Pattern
            )
            # For example, find the next item from the currently selected one 
            # the name of which starts with X and move to it
            if ($this.Content.FindNextItem($Pattern)) {
                # Rebuild $script:lineMap
                $this.UpdateLineMap()
                # Rewrite the menu using the new map
                $this.WriteMenu()
                
                # UpdateLineMap() moved the selected item to the last one on the menu and 
                # wrote it in the highlightcolor. Write it in the unselected foreground color.
                $currentItemLine = `
                    ($script:lineMap | Where-Object { $_.ItemIndex -eq $this.Content.CurrentItem }).Number
                $this.WriteItem($this.Content.CurrentItem, $currentItemLine, $ItemColor)
                
                # Now change the current item to the one at the top of the menu and 
                # write it in the highlightcolor
                $this.Content.CurrentItem = ($script:lineMap | Select-Object -First 1).ItemIndex
                $currentItemLine = `
                    ($script:lineMap | Where-Object { $_.ItemIndex -eq $this.Content.CurrentItem }).Number
                $this.WriteItem($this.Content.CurrentItem, $currentItemLine)
            }
        }

        # Find previous item matching a pattern
        $menu | Add-Member -MemberType ScriptMethod -Name FindPreviousItem -Value `
        {
            # For example, find the previous item from the currently selected one 
            # the name of which starts with X and move to it
        }

        # Return the current item
        $menu | Add-Member -MemberType ScriptMethod -Name GetCurrentItem -Value `
        {
            if ($Mode -eq 'List') { return $InputObject }

            if ($Mode -eq 'Default') {
                $this.Content.GetCurrentItem()
            } else {
                $this.Square.RestoreBuffer()
                New-Menu -InputObject $this.Content.GetSelectedItems() -Mode List
            }
        }

        # Toggle selection of current item
        $menu | Add-Member -MemberType ScriptMethod -Name ToggleCurrentItemSelection -Value `
        {
            if ($Mode -eq 'Multiselect') {
                $this.Content.ToggleCurrentItemSelection()
                $currentItemLine = `
                    ($script:lineMap | Where-Object { $_.ItemIndex -eq $this.Content.CurrentItem }).Number
                $this.WriteItem($this.Content.CurrentItem, $currentItemLine)
            }
        }

        # Exit the menu
        $menu | Add-Member -MemberType ScriptMethod -Name Exit -Value `
        {
            # Restore the console buffer from before the menu was written
            $this.Square.RestoreBuffer()
        }

        $menu | Add-Member -MemberType ScriptMethod -Name ReadKey `
        {
            $bail = $false
            while ($bail -eq $false) {
                $hideKeysStrokes = $true
                $key = ([Console]::ReadKey($hideKeysStrokes)).Key
                switch ($key) {
                    UpArrow     {
                        if ($Mode -ne 'List') {
                            $this.PreviousItem()
                        }
                    }
                    DownArrow   {
                        if ($Mode -ne 'List') {
                            $this.NextItem()
                        }
                    }
                    PageUp     {
                        $this.PreviousPage()
                    }
                    PageDown   {
                        $this.NextPage()
                    }
                    Escape {
                        $bail = $true
                    }
                    Spacebar {
                        if ($Mode -ne 'List') {
                            $this.ToggleCurrentItemSelection()
                        }
                    }
                    Enter {
                        $bail = $true
                        $this.GetCurrentItem()
                    }
                    '/' {
                        # TODO Start searching
                    }
                    Tab {
                        # TODO Change search direction
                    }
                    Default {
                        if ($Mode -ne 'List') {
                            $key = $key.ToString()
                            if ($key -match '[a-zA-Z]\d{0,1}' -and $key.length -le 2) {
                                # Numbers get returned with a leading D
                                if ($key -match '^D\d') {
                                    $key = $key -replace '^D'
                                }
                                $key = "^$key"
                                $this.FindNextItem($key)
                            }
                        }
                    }
                }
            }
            $this.Exit()
        }

        $menu.WriteMenu()
        $menu.ReadKey()

    }
}

Export-ModuleMember -Function New-Menu
