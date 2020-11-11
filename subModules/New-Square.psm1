
function New-BufferCell {
    param(
        [Parameter(Mandatory=$true)][Char]$Character,
        [consolecolor]$ForeGroundColor = $Host.UI.RawUI.ForegroundColor,
        [consolecolor]$BackGroundColor = $Host.UI.RawUI.BackgroundColor,
        [System.Management.Automation.Host.BufferCellType]$BufferCellType = "Complete"
    )

    # Blatantly copied from:
    # https://dbawhocodes.blogspot.fi/2016/09/screensaver-matrix-style-powershell.html
  
    $cell = New-Object System.Management.Automation.Host.BufferCell
    $cell.Character = $Character
    $cell.ForegroundColor = $foregroundcolor
    $cell.BackgroundColor = $backgroundcolor
    $cell.BufferCellType = $buffercelltype
    
    $cell
}

function New-Square {
    Param(
        [Int]$X = 6,
        [Int]$Y = 3,
        [Int]$Width = 12,
        [Int]$Height = 6,
        [Char]$Character = ' ',
        [String]$ForegroundColor = $Host.UI.RawUI.ForegroundColor,
        [String]$BackgroundColor = $Host.UI.RawUI.BackgroundColor
    )

    $square = [PSCustomObject]@{
        Position = @{
            X = $X
            Y = $Y
        }
        Width  = $Width
        Height = $Height
        Character = $Character
        ForegroundColor = $ForegroundColor
        BackgroundColor = $BackgroundColor
        StoredBufferPosition = $null
        StoredBuffer = $null
        Border = @{
            Enabled = $false
            Character = ' '
            ForegroundColor = 'Yellow'
            BackgroundColor = 'DarkYellow'
            Cell = $null
        }
    }
    
    $square.Border.Cell = New-BufferCell -Character $square.Border.Character `
        -ForeGroundColor $square.Border.ForegroundColor -BackGroundColor $square.Border.BackgroundColor

    # A method for capturing the buffer within the area of the square. Used while 
    # initializing a square and to 'remove' the square by restoring the saved buffer.
    $square | Add-Member -MemberType ScriptMethod -Name CaptureBuffer -Value {

        $pos = $Host.UI.RawUI.CursorPosition
        $pos.X = $this.Position.X
        $pos.Y = $this.Position.Y
        $this.StoredBufferPosition = $pos

        $left   = $this.Position.X
        $bottom = $this.Position.Y
        $top    = $this.Position.Y + $this.Height
        $right  = $this.Position.X + $this.Width

        $rec = New-Object System.Management.Automation.Host.Rectangle $left, $bottom, $right, $top
        $this.StoredBuffer = $Host.UI.RawUI.GetBufferContents($rec)
    }

    $square.CaptureBuffer()

    # This restores the buffer captured with CaptureBuffer
    $square | Add-Member -MemberType ScriptMethod -Name RestoreBuffer -Value {
        $Host.UI.RawUI.SetBufferContents($this.StoredBufferPosition, $this.StoredBuffer)
    }

    $square | Add-Member -MemberType ScriptMethod -Name WriteToConsoleBuffer -Value {
        $pos = $Host.UI.RawUI.CursorPosition
        $pos.X = $this.Position.X
        $pos.Y = $this.Position.Y

        $cell = New-BufferCell -Character ' ' -ForeGroundColor $this.ForegroundColor `
            -BackGroundColor $this.BackgroundColor
        
        $cellArr = $host.UI.RawUI.NewBufferCellArray($this.Width, $this.Height, $cell)
        $host.UI.RawUI.SetBufferContents($pos,$cellArr)

        if ($this.Border.Enabled) {
            $this.WriteBorder()
        }

    }

    # This restores the buffer at the current location, sets a new one, 
    # captures the buffer there and redraws the square there 
    $square | Add-Member -MemberType ScriptMethod -Name SetPosition -Value {
        Param(
            [Int]$X,
            [Int]$Y
        )
        $this.RestoreBuffer()
        $this.Position.X = $X
        $this.Position.Y = $Y
        $this.CaptureBuffer()
        $this.WriteToConsoleBuffer()
    }

    # This moves the squares position to Direction by Length cells
    $square | Add-Member -MemberType ScriptMethod -Name MovePosition -Value {
        Param(
            [ValidateSet('Right','Down','Left','Up')]$Direction = 'Right',
            [Int]$Length = 1
        )
        $X = $this.Position.X
        $Y = $this.Position.Y
        switch ($Direction) {
            'Right' {
                $X += $Length
                $this.SetPosition($X,$Y)
            }
            'Down'  {
                $Y += $Length
                $this.SetPosition($X,$Y)
            }
            'Left'  {
                $X -= $Length
                $this.SetPosition($X,$Y)
            }
            'Up'    {
                $Y -= $Length
                $this.SetPosition($X,$Y)
            }
        }
    }

    # This can be used to change the squares width
    $square | Add-Member -MemberType ScriptMethod -Name SetWidth -Value {
        Param(
           [Parameter(Mandatory=$true)][Int]$Width 
        )
        $this.RestoreBuffer()
        $this.Width = $Width
        $this.CaptureBuffer()
    }

    # This can be used to change the squares height
    $square | Add-Member -MemberType ScriptMethod -Name SetHeight -Value {
        Param(
            [Parameter(Mandatory=$true)][Int]$Height
        )
        $this.RestoreBuffer()
        $this.Height = $Height
        $this.CaptureBuffer()
    }

    # This can be used to change the squares width and height
    $square | Add-Member -MemberType ScriptMethod -Name SetSize -Value {
        Param(
            [Parameter(Mandatory=$true)][Int]$Width,
            [Parameter(Mandatory=$true)][Int]$Height
        )
        $this.SetWidth($Width)
        $this.SetHeight($Height)
    }

    $square | Add-Member -MemberType ScriptMethod -Name GrowWidth -Value {
        Param(
            [Int]$Amount = 0
        )
        $this.SetWidth($this.Width + $Amount)
    }

    $square | Add-Member -MemberType ScriptMethod -Name GrowHeight -Value {
        Param(
            [Int]$Amount = 0
        )
        $this.SetHeight($this.Height + $Amount)
    }

    # This can be used to write a top border
    $square | Add-Member -MemberType ScriptMethod -Name WriteTopBorder -Value {
        $pos = $host.UI.RawUI.CursorPosition
        $pos.X = $this.Position.X
        $pos.Y = $this.Position.Y

        $cellArr = $host.UI.RawUI.NewBufferCellArray($this.Width, 1, ($this.Border.Cell))

        $host.UI.RawUI.SetBufferContents($pos,$cellArr)
    }

    # This can be used to write a left border
    $square | Add-Member -MemberType ScriptMethod -Name WriteLeftBorder -Value {
        $pos = $host.UI.RawUI.CursorPosition
        $pos.X = $this.Position.X
        $pos.Y = $this.Position.Y

        $cellArr = $host.UI.RawUI.NewBufferCellArray(2, $this.height, ($this.Border.Cell))

        $host.UI.RawUI.SetBufferContents($pos,$cellArr)
    }

    # This can be used to write a bottom border
    $square | Add-Member -MemberType ScriptMethod -Name WriteBottomBorder -Value {
        $pos = $host.UI.RawUI.CursorPosition
        $pos.X = $this.Position.X
        $pos.Y = $this.Position.Y + $this.Height - 1

        $cellArr = $host.UI.RawUI.NewBufferCellArray($this.Width, 1, ($this.Border.Cell))

        $host.UI.RawUI.SetBufferContents($pos,$cellArr)
    }

    # This can be used to write a right border
    $square | Add-Member -MemberType ScriptMethod -Name WriteRightBorder -Value {
        $pos = $host.UI.RawUI.CursorPosition
        $pos.X = $this.Position.X + $this.Width - 2
        $pos.Y = $this.Position.Y

        $cellArr = $host.UI.RawUI.NewBufferCellArray(2, $this.height, ($this.Border.Cell))

        $host.UI.RawUI.SetBufferContents($pos,$cellArr)
    }

    # This can be used to write a border within the square. Not recommended.
    $square | Add-Member -MemberType ScriptMethod -Name WriteBorder -Value {
        $this.WriteTopBorder()
        $this.WriteLeftBorder()
        $this.WriteBottomBorder()
        $this.WriteRightBorder()
    }

    $square
}

Export-ModuleMember -Function New-Square
