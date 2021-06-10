# How to Run
1. On just one layer, select all differential pairs that you want to length match with compensation bumps. Make sure to select the full track (but just on that layer) for each diff pair.
2. Run script

This script will match the P/N lengths by adding compensation bumps to the shortest of the pair. Adds 2 bumps per 45 degree bend in pair (overall bend, not each bend since some cancel out).

# TODO
- Run Route --> Retrace Selected before running script???
- Every two bumps, add a gap with no bumps
- Replace calculations in GetAngleBetweenTracks with function GetCoordFromLocation
- If track spans multiple layers, throw error and exit.
- Calculate final length comparison between two pairs