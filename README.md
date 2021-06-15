# How to Run
1. Select all differential pairs that you want to length match with compensation bumps. You can select on just one layer or on multiple layers, but speed is increased when using just one layer.
2. Run script

This script will match the P/N lengths for each layer independently by adding compensation bumps to the shortest of the pair. Adds 2 bumps per 45 degree bend in pair (overall bend, not each bend since some cancel out).

# TODO
- Run Route --> Retrace Selected before running script??? Client.SendMessage('PCB:Retrace', 'Track=True', 255, Client.CurrentView); // Retrace selected tracks  
- Every two bumps, add a gap with no bumps
- Replace calculations in GetAngleBetweenTracks with function GetCoordFromLocation