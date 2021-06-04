function GetTrackRotation(trk: IPCB_Track) : Integer;
var
    Rot: Double;
    dx, dy: Double;
begin
    dx := trk.x2 - trk.x1;
    dy := trk.y2 - trk.y1;

    Rot := RadToDeg(arctan(dy/dx));

    if (dx >= 0) and (dy >= 0) then
    begin
        Rot := Rot + 0;
    end
    else if (dx < 0) and (dy >= 0) then
    begin
        Rot := Rot + 180;
    end
    else if (dx < 0) and (dy < 0) then
    begin
        Rot := Rot + 180;
    end
    else
    begin
        Rot := Rot + 360;
    end;

    // Return angle between 180 & negative 180 instead of 0 & 360
    if Rot > 180 then
    begin
        Rot := Rot - 360;
    end;

    result := Rot;
end;

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

function GetDiffPairGap(Board: IPCB_Board, var gap: Double) : Boolean;
var
    dp: TPCBObjectHandle;
    i: Integer;
    Net : IPCB_Net;
    InBoard, NotVerticalLine:Boolean;
    trk1, trk2: IPCB_Track;
    found_cnt, width: Integer;
    rot1, rot2, rot90: Double;
begin
   result := False;
   gap := 0.0;

   if Board.SelectecObjectCount <> 2 then exit;

   // Get selected tracks as IPCB_Track objects
   found_cnt := 0;
   for i := 0 to Board.SelectecObjectCount - 1 do
   begin
      if Board.SelectecObject[i].ObjectId = eTrackObject then
      begin
         if i = 0 then
         begin
            trk1 := GetBumpSegment(Board.SelectecObject[i]);
            Inc(found_cnt);
         end
         else if i = 1 then
         begin
            trk2 := GetBumpSegment(Board.SelectecObject[i]);
            Inc(found_cnt);
         end;
      end;
   end;

   // Calculate Gap
   if found_cnt = 2 then
   begin
       gap := CoordToMils(Board.PrimPrimDistance(trk1, trk2));

       result := True;
   end;
end;

procedure Run;
var
   Board    : IPCB_Board;
   Arc      : IPCB_Arc;
   Track, Bump, Bump_Segment : IPCB_Track;
   side_len, run_len, gap, width : Double;
   found_gap: Boolean;
   x, y: Integer;
begin
   Board := PCBServer.GetCurrentPCBBoard;
   if Board = nil then exit;

   if Board.SelectecObjectCount = 0 then
   begin
       ShowMessage('No tracks selected. Please select differential pair tracks before running.');
   end
   else if Board.SelectecObjectCount = 1 then
   begin
       ShowMessage('Only 1 track selected. Please select differential pair tracks before running.');
   end
   else if Board.SelectecObjectCount > 2 then
   begin
       ShowMessage('Too many tracks selected. Please only select one segment (2 tracks) of diff pair tracks.');
   end;

   found_gap := GetDiffPairGap(Board, gap);
   if not found_gap then exit;

   Track := GetSelectedTrack(Board);
   width := CoordToMils(Track.Width);
   CalculateBump(Board, width, gap, side_len, run_len);

   // First Segment (Flat track)
   Bump_Segment := GetBumpSegment(Track);
   Bump_Segment.MoveByXY(MilsToCoord(20), MilsToCoord(20));
   Bump_Segment.SetState_Length(MilsToCoord(run_len));
   Bump_Segment.RotateBy(-GetTrackRotation(Bump_Segment)); // Reset to horizontal
   Board.AddPCBObject(Bump_Segment);

   x := Bump_Segment.x2;
   y := Bump_Segment.y2;

   // Second Segment (45 track)
   Bump_Segment := GetBumpSegment(Bump_Segment);
   //Bump_Segment.MoveByXY(Bump_Segment.x2 - Bump_Segment.x1, Bump_Segment.y2 - Bump_Segment.y1);
   Bump_Segment.MoveToXY(x, y);
   Bump_Segment.SetState_Length(MilsToCoord(side_len));
   Bump_Segment.RotateBy(45.0);
   Board.AddPCBObject(Bump_Segment);

   x := Bump_Segment.x2;
   y := Bump_Segment.y2;

   // Third Segment (Top flat track)
   Bump_Segment := GetBumpSegment(Bump_Segment);
   //Bump_Segment.MoveByXY(Bump_Segment.x2 - Bump_Segment.x1, Bump_Segment.y2 - Bump_Segment.y1);
   Bump_Segment.MoveToXY(x, y);
   Bump_Segment.SetState_Length(MilsToCoord(run_len));
   Bump_Segment.RotateBy(-45.0);
   Board.AddPCBObject(Bump_Segment);

   x := Bump_Segment.x2;
   y := Bump_Segment.y2;

   // Last Segment (-45 track)
   Bump_Segment := GetBumpSegment(Bump_Segment);
   //Bump_Segment.MoveByXY(Bump_Segment.x2 - Bump_Segment.x1, Bump_Segment.y2 - Bump_Segment.y1);
   Bump_Segment.MoveToXY(x, y);
   Bump_Segment.SetState_Length(MilsToCoord(side_len));
   Bump_Segment.RotateBy(-45.0);
   Board.AddPCBObject(Bump_Segment);

   Board.ViewManager_FullUpdate;

   ShowMessage('Width: '+FloatToStr(width)+', Gap: '+FloatToStr(gap)+', Side Length: '+FloatToStr(side_len)+', Run Length: '+FloatToStr(run_len));
end;
