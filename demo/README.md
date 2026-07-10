# Demo assets

`fake-done.sh` shows the flagship moment: a `fix: … done, all tests pass`
commit blocked by `claim-evidence.sh`, then allowed once real evidence is in
the message. It runs entirely in a throwaway temp dir.

```bash
./demo/fake-done.sh
```

## Record the gif

**vhs** (preferred):
```bash
brew install vhs
vhs demo/demo.tape        # writes demo/blocked-commit.gif (embedded in README)
```

**asciinema** alternative:
```bash
asciinema rec demo/blocked-commit.cast -c ./demo/fake-done.sh
agg demo/blocked-commit.cast demo/blocked-commit.gif   # cargo install agg / brew install agg
```
Upload the `.cast` to asciinema.org and embed both: gif above the fold in the
README, the asciinema link below it so viewers can copy-paste from the replay.

Acceptance bar for the shipped gif: <2.5 MB, <45 s, legible at README width,
with "BLOCKED: done-claim with no test evidence" visible in frame.
