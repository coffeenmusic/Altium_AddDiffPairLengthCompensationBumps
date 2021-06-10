# How to Run
1. Select all tracks of poth differential pairs for a given layer. Only one layer currently supported at a time.
2. Run script

This script with match the P/N lengths by adding compensation bumps to the shortest of the pair. Adds 2 bumps per 45 degree bend in pair (overall bend, not each bend since some cancel out).

# TODO
- Add bumps at bends instead of just anywhere
- Allow for selecting multiple diff pairs
- Run Route --> Retrace Selected before running script???
- Every two bumps, add a gap with no bumps
- Rename GetBumpSegment() to CopyTrack()
- Replace calculations in GetAngleBetweenTracks with function GetCoordFromLocation
- If track spans multiple layers, throw error and exit.
- Calculate final length comparison between two pairs
- Make IPCB_Board Board a global variable