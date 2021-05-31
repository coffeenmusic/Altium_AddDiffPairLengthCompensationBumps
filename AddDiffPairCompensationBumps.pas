function GetSelectedTrack(Board: IPCB_Board) : IPCB_Track;
var
    Track: IPCB_Track;
    i: Integer;
begin
   if Board.SelectecObjectCount = 0 then exit;

   for i := 0 to Board.SelectecObjectCount - 1 do
   begin
      if Board.SelectecObject[i].ObjectId = eTrackObject then
      begin
         result := Board.SelectecObject[i];
         exit;
      end;
   end;
end;

function CalculateBump(Board: IPCB_Board, trace_width: Double, diff_gap: Double, var side_len: Double, var top_len: Double) : Boolean;
var
    diff_pitch, bump_inner, bend45extra: Double;
begin
   diff_pitch := trace_width + diff_gap;
   bend45extra := 2*diff_pitch/Tan(DegToRad(135/2));
   bump_inner := (bend45extra/2)/(2*(Sqrt(2)-1));

   side_len := bump_inner/Sin(DegToRad(45));
   top_len := 3*trace_width;
end;

function GetBumpSegment(ReferenceTrack: IPCB_Track) : IPCB_Track;
var
    Seg: IPCB_Track;
begin
   Seg := PCBServer.PCBObjectFactory(eTrackObject, eNoDimension, eCreate_Default);
   Seg := ReferenceTrack.Replicate;
   result := Seg;
end;

procedure Run;
const
   DIFF_GAP = 7.5;
var
   Board    : IPCB_Board;
   Arc      : IPCB_Arc;
   Track, Bump, Bump_Segment : IPCB_Track;
   side_len, run_len : Double;
begin
   Board := PCBServer.GetCurrentPCBBoard;
   if Board = nil then exit;

   Track := GetSelectedTrack(Board);
   CalculateBump(Board, CoordToMils(Track.Width), DIFF_GAP, side_len, run_len);

   // First Segment (Flat track)
   Bump_Segment := GetBumpSegment(Track);
   Bump_Segment.MoveByXY(0, MilsToCoord(20));
   Bump_Segment.SetState_Length(MilsToCoord(run_len));
   Board.AddPCBObject(Bump_Segment);

   // Second Segment (45 track)
   Bump_Segment := GetBumpSegment(Bump_Segment);
   Bump_Segment.MoveByXY(Bump_Segment.x2 - Bump_Segment.x1, Bump_Segment.y2 - Bump_Segment.y1);
   Bump_Segment.SetState_Length(MilsToCoord(side_len));
   Bump_Segment.RotateBy(45.0);
   Board.AddPCBObject(Bump_Segment);

   // Third Segment (Top flat track)
   Bump_Segment := GetBumpSegment(Bump_Segment);
   Bump_Segment.MoveByXY(Bump_Segment.x2 - Bump_Segment.x1, Bump_Segment.y2 - Bump_Segment.y1);
   Bump_Segment.SetState_Length(MilsToCoord(run_len));
   Bump_Segment.RotateBy(-45.0);
   Board.AddPCBObject(Bump_Segment);

   // Last Segment (-45 track)
   Bump_Segment := GetBumpSegment(Bump_Segment);
   Bump_Segment.MoveByXY(Bump_Segment.x2 - Bump_Segment.x1, Bump_Segment.y2 - Bump_Segment.y1);
   Bump_Segment.SetState_Length(MilsToCoord(side_len));
   Bump_Segment.RotateBy(-45.0);
   Board.AddPCBObject(Bump_Segment);

   Board.ViewManager_FullUpdate;
end;
