# vhs tape — vhs demo/backfill.tape -> demo/backfill.gif
# Records a REAL run against the public fixture repo ronniepinnell/casper-demo.
Output demo/backfill.gif
Set FontSize 13
Set Width 900
Set Height 480
Set Theme "Catppuccin Mocha"
Set TypingSpeed 35ms
Type "# grade the dones this repo already shipped"
Enter
Sleep 800ms
Type "python3 scripts/backfill.py --repo ronniepinnell/casper-demo --badge badge.json"
Enter
Sleep 7s
Type "cat badge.json"
Enter
Sleep 4s
