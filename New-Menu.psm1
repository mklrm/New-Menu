# TODO Add HELP and such...

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
        # Align item names Center of Left
        [ValidateSet('Center','Left')]
        [String]$AlignText = 'Left',
        # The name of the property of items to be displayed on the menu, such as Name
        [Parameter(Mandatory=$false)][String]$DisplayProperty,   
        #     Default: Select one by hitting Enter
        # Multiselect: Pick multiple items with Space, select with Enter
        #        List: Display a list of items and return them
        [Parameter(Mandatory=$false)]
        [ValidateSet('Multiselect','List','Default')]
        [String]$Mode = 'Default',
        # A title / help text to display above the menu
        [String[]]$Title,
        # Align Title Center of Left
        [ValidateSet('Center','Left')]
        [String]$AlignTitle = 'Center',
        # Display a list of selected objects after multiselection
        [Parameter(Mandatory=$false)]
        [Switch]$ListSelected,
        # Horizontal position of the upper left corner
        [ValidateRange(-1, [int]::MaxValue)][int]$X = -1,
        # Vertical position of the upper left corner
        [ValidateRange(-1, [int]::MaxValue)][int]$Y = -1,
        # Width of the menu
        [ValidateRange(-1, [int]::MaxValue)][Int]$Width = -1,
        # Height of the menu
        [ValidateRange(-1, [int]::MaxValue)][Int]$Height = -1,
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
        # Remove edge
        [Switch]$NoEdge
    )

    # TODO Add different options for automatic positioning 
    # of the menu, such as in the middle of the buffer or 
    # where the cursor is at
    # TODO ?-icon for invoking help. No other help texts etc. 
    # required. Just tell user Esc is cancel, Enter confirm.
    # TODO A search function such like pressing / starts taking 
    # input and with each added character the string is matched 
    # against the items on the menu
    # TODO Add indicators for lists higher than the window, for example:
    #
    #   +
    # ITEM 3
    # ITEM 4
    # ITEM 5
    #   +
    #
    # ...I do not want to implement those in New-Square though. I might have to.
        
    # This Begin-Process-End block is here just to make it possible to 
    # pass the input object from pipeline... for which there's probably 
    # a better way of doing than this.
    Begin {
        if ($Width -eq 0) {
            Write-Host "A width of zero is not supported." -ForegroundColor Red
            exit
        }
        if ($Height -eq 0) {
            Write-Host "A height of zero is not supported." -ForegroundColor Red
            exit
        }
        $tmp = $()
        $windowWidth = $Host.UI.RawUI.WindowSize.Width
        $windowHeight = $Host.UI.RawUI.WindowSize.Height
        $windowY = $Host.UI.RawUI.WindowPosition.Y
        $windowBottom = $windowY + $windowHeight
        $EdgeWidth = 2
        $EdgeHeight = 1
        if ($NoEdge.IsPresent) {
            $EdgeWidth = 0
            $EdgeHeight = 0
        }
    } Process {
        $tmp += $InputObject
    } End {
        $InputObject = $tmp
        
        # NOTE Let's not accept empty strings and such. For now at least. They 
        # break -something-, probably GetItemName in New-MenuContent
        $InputObject = $InputObject | Where-Object { $_ }

        # NOTE As a quick fix for List Mode being given an empty list 
        # when nothing was picked in -MultiSelect, I changed InputObject 
        # to not being mandatory and added the following line:
        if (-not $InputObject) { return }

        # These can't seem to be defined directly as the default values in the parameters
        if (-not $ItemColor) {
            $ItemColor = $Host.UI.RawUI.BackgroundColor
        }
        if (-not $BackgroundColor) {
            $BackgroundColor = $Host.UI.RawUI.ForegroundColor
        }

        # Create a mapping object for attaching an item index number to a line number on the buffer
        $script:lineMap = @()

        $firstMenuItemLineNumber = 0 # Line on which to write the first displayed item
         $lastMenuItemLineNumber = 0 # Line on which to write the last displayed item
        
        if ($InputObject -isnot [Array]) {
            $InputObject = @($InputObject)
        }
        
        $menu = [PSCustomObject]@{
            Content =   if (-not $DisplayProperty) {
                            New-MenuContent -Array $InputObject
                        } else {
                            New-MenuContent -Array $InputObject -DisplayProperty $DisplayProperty
                        }
        }
        $menu | Add-Member -MemberType NoteProperty -Name ID -Value (Get-Random)

        if ($Width -eq -1) {
            $Width = $menu.Content.ItemMaxLen
        }

        if ($Width -gt $windowWidth) {
            $Width = $windowWidth
        }
        
        if ($X -eq -1) {
            $X = [Math]::Floor($windowWidth / 2) - [Math]::Floor(($Width / 2))
        } elseif ($X + $Width + ($EdgeWidth * 2) -ge $windowWidth) {
            $X = $windowWidth - ($Width + $EdgeWidth * 2)
        }

        if ($Height -eq -1) {
            if ($menu.Content.Items.Count + $EdgeHeight * 2 -gt $windowHeight) {
                $Height = $windowHeight - $EdgeHeight * 2
            } else {
                $Height = $menu.Content.Items.Count
            }
        }

        if ($Height + $EdgeHeight * 2 -gt $windowHeight) {
            $Height = $windowHeight - $EdgeHeight * 2
        }
        
        if ($Title -and -not $NoEdge.IsPresent) {
            if ($Height + $Title.Count + $EdgeHeight * 2 -gt $windowHeight) {
                $Height--
            }
        }

        if ($Y -eq -1) {
            $windowMiddle = $windowY + $windowHeight / 2
            $windowMiddle = [Math]::Floor($windowMiddle)
            $Y = $windowMiddle - [Math]::Floor($Height / 2)
        } else {
            $Y += $windowY
        }

        if ($Height + $EdgeHeight * 2 -gt $windowHeight) {
            $Y = $windowY
        } elseif ($Y + $Height + $EdgeHeight * 2 -gt $windowBottom) {
            $Y = $windowBottom - ($Height + $EdgeHeight * 2)
        }
        
        if ($Title) {
            if ($Height + $Title.Count + $EdgeHeight * 2 + 1 -gt $windowHeight) {
                if (-not $NoEdge.IsPresent -and $title.Count -eq 1) {
                    $Height--
                }
            } elseif ($NoEdge.IsPresent -and $Y + $Height + $EdgeHeight * 2 + $Title.Count + 1 -gt $windowBottom) {
                $Y = $windowBottom - ($Height + $EdgeHeight * 2 + $Title.Count + 1)
            } elseif ($Y + $Height + $EdgeHeight * 2 + $Title.Count -gt $windowBottom) {
                $Y = $windowBottom - ($Height + $EdgeHeight * 2 + $Title.Count)
            }
        }

        if ($Title) {
            if ($Height + $Title.Count + $EdgeHeight * 2 -gt $windowHeight) {
                $Height = $Height - $Title.Count
                if ($NoEdge.IsPresent) {
                    $Height--
                }
            }
            $Y = $Y + $Title.Count
            $titleWidth = 0
            $titleX = $X
            foreach ($t in $Title) {
                if ($t.Length -gt $titleWidth) {
                    $titleWidth = $t.Length
                }
            }
            if ($titleWidth -lt $Width + $EdgeWidth * 2) {
                $titleWidth = $Width + $EdgeWidth * 2
            }
            if ($titleWidth -gt $Width + $EdgeWidth * 2) {
                $titleX = [Math]::Floor($X - ($titleWidth - ($Width + $EdgeWidth * 2)) / 2)
            }
            $i = $Title.Count
            $titleList = foreach ($t in $Title) {
                $titleY = $Y - $EdgeHeight - $i
                New-Square -X $titleX -Y $titleY `
                    -Width $titleWidth -Height 1 -Character $Character `
                    -ForegroundColor $ItemColor -BackgroundColor $BackgroundColor
                $i--
            }
            if ($NoEdge.IsPresent) {
                $Y++
            }
            $menu | Add-Member -MemberType NoteProperty -Name Title -Value $titleList
        }

        $menu | Add-Member -MemberType NoteProperty -Name Square -Value (
            New-Square -X $X -Y $Y `
                -Width $Width -Height $Height -Character $Character `
                -ForegroundColor $ItemColor -BackgroundColor $BackgroundColor
        )
        $menu.Square.GrowWidth($EdgeWidth * 2)
        $menu.Square.GrowHeight($EdgeHeight * 2)

        # Set which line to write the first item to the beginning of the menu
        $firstMenuItemLineNumber = $menu.Square.Position.Y + $EdgeHeight
        
        # Set which line to write the last item to the end of the menu
        $lastMenuItemLineNumber = $menu.Square.Position.Y + $menu.Square.Height - ($EdgeHeight * 2)

        # Fixes an issue with one extra item getting written below the square
        if ($EdgeHeight -eq 0) {
            $lastMenuItemLineNumber--
        }

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

        $menu | Add-Member -MemberType ScriptMethod -Name WriteTitles -Value `
        {
            if (-not $Title) { return }
            $i = 0
            foreach ($t in $this.Title) {
                $pos = $Host.UI.RawUI.WindowPosition
                $pos.X = $t.Position.X
                if ($AlignTitle -eq 'Center' -and $t.Length -lt $titleWidth) {
                    $pos.X += [Math]::Floor(($titleWidth - $Title[$i].Length) / 2)
                }
                $pos.Y = $t.Position.Y
                $outBuffer = $Host.UI.RawUI.NewBufferCellArray(
                    $Title[$i],
                    $ItemColor, 
                    $BackgroundColor
                )
                $Host.UI.RawUI.SetBufferContents($pos,$outBuffer)
                $i++
            }
        }

        $menu | Add-Member -MemberType ScriptMethod -Name WriteItem -Value `
        {
            Param(
                [Int]$ItemIndex = $this.Content.CurrentItem,
                [Int]$LineNumber = 0,
                [String]$ItemColor = $this.GetItemColor($ItemIndex)
            )

            $itemName = $this.Content.GetItemName($ItemIndex)

            $pos   = $Host.UI.RawUI.WindowPosition
            $pos.X = $this.Square.Position.X + $EdgeWidth
            if ($AlignText -eq 'Center' -and $itemName.Length -lt $Width) {
                $pos.X += [Math]::Floor(($Width - $itemName.Length) / 2)
            }
            $pos.Y = $LineNumber

            if ($itemName.Length -gt $Width) {
                $itemName = $itemName.SubString(0,$Width)
            }
            $outBuffer = $Host.UI.RawUI.NewBufferCellArray(
                $itemName,
                $ItemColor, 
                $this.Square.BackgroundColor
            )

            $Host.UI.RawUI.SetBufferContents($pos,$outBuffer)
        }

        $menu | Add-Member -MemberType ScriptMethod -Name WriteItems -Value `
        {
            if (-not $this.Content.Items) { return }
            if ($this.Content.Items.Count -eq 1) {
                $currentItemLine = ($script:lineMap | Where-Object { $_.ItemIndex -eq $this.Content.CurrentItem }).Number
                $this.WriteItem(0, $currentItemLine)
            } else {
                foreach ($line in $script:lineMap) {
                    $this.WriteItem($line.ItemIndex, $line.Number)
                }
            }
        }

        $menu | Add-Member -MemberType ScriptMethod -Name WriteMenu -Value `
        {
            foreach ($t in $this.Title) {
                $t.WriteToConsoleBuffer()
            }
            $this.WriteTitles()
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
            $currentItemLine = ($script:lineMap | `
                Where-Object { $_.ItemIndex -eq $this.Content.CurrentItem }).Number
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
            if ($this.Content.Items.Count -le $lastMenuItemLineNumber - $firstMenuItemLineNumber - 1) {
                return
            }

            # Get to the last item on $script:lineMap using $this.Content.NextItem()
            while ($this.Content.CurrentItem -ne $script:lineMap[-1].ItemIndex) {
                $this.Content.NextItem()
            }
            # Do $this.NextItem() to move to next page
            $this.NextItem()
        }

        # Write the previous batch of items (if there's too many items to show simultaneously)
        $menu | Add-Member -MemberType ScriptMethod -Name PreviousPage -Value `
        {
            # Check that there's actually more items on the list than can fit on the menu
            if ($this.Content.Items.Count -le $lastMenuItemLineNumber - $firstMenuItemLineNumber - 1) {
                return
            }

            # Get to the first item on $script:lineMap using $this.Content.PreviousItem()
            while ($this.Content.CurrentItem -ne $script:lineMap[0].ItemIndex) {
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
                $currentItemLine = ($script:lineMap | Where-Object { $_.ItemIndex -eq $this.Content.CurrentItem }).Number
                $this.WriteItem($this.Content.CurrentItem, $currentItemLine, $ItemColor)
                
                # Now change the current item to the one at the top of the menu and 
                # write it in the highlightcolor
                $this.Content.CurrentItem = ($script:lineMap | Select-Object -First 1).ItemIndex
                $currentItemLine = ($script:lineMap | Where-Object { $_.ItemIndex -eq $this.Content.CurrentItem }).Number
                $this.WriteItem($this.Content.CurrentItem, $currentItemLine)
            }
        }

        # Find previous item matching a pattern
        $menu | Add-Member -MemberType ScriptMethod -Name FindPreviousItem -Value `
        {
            # TODO Implement
            # For example, find the previous item from the currently selected one 
            # the name of which starts with X and move to it
        }

        # Return the current item
        $menu | Add-Member -MemberType ScriptMethod -Name GetCurrentItem -Value `
        {
            if ($Mode -eq 'List') { return $InputObject }

            if ($Mode -eq 'Default') {
                $this.Content.GetCurrentItem()
            } elseif ($Mode -eq 'Multiselect') {
                if ($ListSelected.IsPresent) {
                    $this.Square.RestoreBuffer()
                    New-Menu -InputObject $this.Content.GetSelectedItems() -Mode List
                } else {
                    $this.Square.RestoreBuffer()
                    $this.Content.GetSelectedItems()
                }
            }
        }

        # Toggle selection of current item
        $menu | Add-Member -MemberType ScriptMethod -Name ToggleCurrentItemSelection -Value `
        {
            if ($Mode -eq 'Multiselect') {
                $this.Content.ToggleCurrentItemSelection()
                $currentItemLine = ($script:lineMap | Where-Object { $_.ItemIndex -eq $this.Content.CurrentItem }).Number
                $this.WriteItem($this.Content.CurrentItem, $currentItemLine)
            }
        }

        # Exit the menu
        $menu | Add-Member -MemberType ScriptMethod -Name Exit -Value `
        {
            # Restore the console buffer from before the menu was written
            foreach ($t in $this.Title) {
                $t.RestoreBuffer()
            }
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
                            if ($key -match '[a-zA-Z]\d{0,1}' -and $key.Length -le 2) {
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
