# How to Run
1. Select 2 tracks (single diff pair segment), one from the positive & one from the negative differential pair. (Don't select entire diff pair & select only 1 track per net)
2. Run script

This will create a bump that can be added to the short end of the differential pair.

45 degree difference: Add 2 bumps
90 degree difference: Add 4 bumps

# TODO
- Every two bumps, add a gap with no bumps
- Rename GetBumpSegment() to CopyTrack()
- Replace calculations in GetAngleBetweenTracks with function GetCoordFromLocation
- If track spans multiple layers, throw error and exit.
- Calculate final length comparison between two pairs
- Make IPCB_Board Board a global variable