# New-Menu

Yes, the code is horrid, what it can do is take a list of objects and throw them into an ASCII menu. It tries to find some property like Name in the objects and display that. Then you pick your item and items and the script returns them.

## Usage examples

### In the default mode you can pick one item by pressing enter:
New-Menu -InputObject $myArrayOfObjects | Foreach-Object { <# Do something with the selected object #> }

### You can select multiple menu items in multiselect mode by pressing space on an item and then return them by pressing enter:
New-Menu -InputObject $myArrayOfObjects -Mode Multiselect | Foreach-Object { <# Do something with the selected objects #> }

### In list mode you can't select and the script doesn't return anything, it exists purely for your viewing pleasure
New-Menu -InputObject $myArrayOfObjects -Mode List

You can use arrow down and up, page down and up to move. Typing a letter or a number will jump to the next item that starts with the pressed character.
