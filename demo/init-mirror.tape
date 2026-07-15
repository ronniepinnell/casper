# vhs tape — record in a fresh clone of a repo WITH merged PRs (e.g. the
# casper-demo fixture), with the casper source at ../casper:
#   cd <fresh-clone> && vhs init-mirror.tape
# Paths in the recording must contain no private tokens (record under /tmp).
Output casper-init.gif
Set FontSize 13
Set Width 900
Set Height 600
Set Theme "Catppuccin Mocha"
Set TypingSpeed 35ms
Type "../casper/install.sh --init --yes"
Enter
Sleep 16s
Sleep 4s
