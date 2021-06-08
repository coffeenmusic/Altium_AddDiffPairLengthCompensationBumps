function GetTrackRotation(trk: IPCB_Track, Center: Boolean) : Double;
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
    if (Center) and (Rot > 180) then
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

function GetSelectedTrackList(Board: IPCB_Board, NetName: String) : TInterfaceList;
var
    TrackList : TInterfaceList;
    i : Integer;
begin
   if Board.SelectecObjectCount = 0 then exit;

   TrackList := TInterfaceList.Create;
   for i := 0 to Board.SelectecObjectCount - 1 do
   begin
      if Board.SelectecObject[i].ObjectId = eTrackObject then
      begin
          if Board.SelectecObject[i].Net.Name = NetName then
          begin
              TrackList.Add(Board.SelectecObject[i]);
          end;
      end;
   end;
   result := TrackList;
end;

function GetSelectedNetList(Board: IPCB_Board) : TStringList;
var
    Nets : TStringList;
    trk: IPCB_Track;
    i : Integer;
begin
   if Board.SelectecObjectCount = 0 then exit;

   Nets := TStringList.Create;
   Nets.Sorted := True;
   Nets.Duplicates := dupIgnore;

   for i := 0 to Board.SelectecObjectCount - 1 do
   begin
      if Board.SelectecObject[i].ObjectId = eTrackObject then
      begin
         trk := Board.SelectecObject[i];
         Nets.Add(trk.Net.Name);
      end;
   end;
   result := Nets;
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

function CopyList(TrackList: TInterfaceList, Reverse: Boolean) : TInterfaceList;
var
    i: Integer;
    copyList: TInterfaceList;
begin
    copyList := TInterfaceList.Create;
    for i:=0 to TrackList.Count - 1 do
    begin
        if Reverse then
        begin
            copyList.Add(TrackList[TrackList.Count - 1 - i]);
        end
        else
        begin
            copyList.Add(TrackList[i]);
        end;
    end;
    result := copyList;
end;

function GetMinTrackDistance(Track1: IPCB_Track, Track2: IPCB_Track): Double;
var
    minDist, tmpDist: Double;
begin
    minDist := abs(Track1.x1 - Track2.x1) + abs(Track1.y1 - Track2.y1);

    tmpDist := abs(Track1.x1 - Track2.x2) + abs(Track1.y1 - Track2.y2);
    if tmpDist < minDist then
    begin
        minDist := tmpDist;
    end;

    tmpDist := abs(Track1.x2 - Track2.x1) + abs(Track1.y2 - Track2.y1);
    if tmpDist < minDist then
    begin
        minDist := tmpDist;
    end;

    tmpDist := abs(Track1.x2 - Track2.x2) + abs(Track1.y2 - Track2.y2);
    if tmpDist < minDist then
    begin
        minDist := tmpDist;
    end;
    result := minDist;
end;

function GetNextConnectedTrack(Board: IPCB_Board, OriginalTrackList: TInterfaceList, Net: String, PrevTrk: IPCB_Track, CurTrk: IPCB_Track) : IPCB_Track;
var
    TrackList, Touching: TInterfaceList;
    i, dist, minLen: Integer;
    trk, minTrk : IPCB_Track;
    uniqueId, PrevuniqueId, CuruniqueId: String;
    Rect : TCoordRect;
    minDist: Double;
begin
   TrackList := CopyList(OriginalTrackList, False);
   Touching := TInterfaceList.Create;

   if TrackList.IndexOf(CurTrk) >= 0 then
   begin
      TrackList.Remove(CurTrk);
   end
   else if TrackList.IndexOf(PrevTrk) >= 0 then
   begin
       TrackList.Remove(PrevTrk);
   end;

   for i := 0 to TrackList.Count - 1 do
   begin
      trk := TrackList[i];

      if Net = trk.Net.Name then
      begin
          //Rect := trk.BoundingRectangle;
          trk.Selected := True;
          //Board.GraphicalView_ZoomOnRect(Rect.Left,Rect.Bottom,Rect.Right,Rect.Top);

          dist := CoordToMils(Board.PrimPrimDistance(CurTrk, trk));
          trk.Selected := False;
          if Board.PrimPrimDistance(CurTrk, trk) = 0 then
          begin
              Touching.Add(trk);
          end;
      end;
   end;

   if Touching.Count = 0 then
   begin
      result := nil;
   end
   else if Touching.Count = 1 then
   begin
      result := Touching[0];
   end
   else
   begin
      for i:=0 to Touching.Count - 1 do
      begin
          trk := Touching[i];
          if (i = 0) or (GetMinTrackDistance(CurTrk, trk) < minDist) then
          begin
              minDist := GetMinTrackDistance(CurTrk, trk);
              minTrk := trk;
          end;
      end;
      result := minTrk;
   end;
end;


function GetMatchingPairTrack(Board: IPCB_Board, Track: IPCB_Track, TrackList: TInterfaceList) : IPCB_Track;
var
    MatchingTrack, Track2: IPCB_Track;
    i, minDistance: Integer;
begin
    for i:= 0 to TrackList.Count - 1 do
    begin
        Track2 := TrackList[i];
        if (i = 0) or (Board.PrimPrimDistance(Track, Track2) < minDistance) then
        begin
            minDistance := Board.PrimPrimDistance(Track, Track2);
            MatchingTrack := Track2;
        end;
    end;
    result := MatchingTrack;
end;

function GetEndTrack(Board: IPCB_Board, OriginalTrackList: TInterfaceList, NetName: String) : IPCB_Track;
var
    TrackList: TInterfaceList;
    Track, PrevTrack: IPCB_Track;
    i: Integer;
    Rect: TCoordRect;
begin
   TrackList := CopyList(OriginalTrackList, False);

   for i:= 0 to TrackList.Count - 1 do
   begin
       Track := TrackList[i];
       if Track.Net.Name = NetName then break;
   end;

   while TrackList.Count > 0 do
   begin
       PrevTrack := Track;
       Track := GetNextConnectedTrack(Board, TrackList, NetName, PrevTrack, Track);
       if (Track <> nil) and (TrackList.Count > 0) then
       begin
          TrackList.Remove(Track);
       end
       else
       begin
           result := PrevTrack;
           exit;
       end;
   end;
end;



function SortTrackList(Board: IPCB_Board, TrackList: TInterfaceList) : TInterfaceList;
var
    Track, PrevTrack: IPCB_Track;
    i: Integer;
    SortedTrackList: TInterfaceList;
    NetName: String;
begin
    NetName := TrackList[0].Net.Name;
    Track := GetEndTrack(Board, TrackList, TrackList[0].Net.Name);
    TrackList.Remove(Track);

    SortedTrackList := TInterfaceList.Create;
    SortedTrackList.Add(Track);

    while TrackList.Count > 0 do
    begin
       PrevTrack := Track;
       Track.Selected := True;
       Track := GetNextConnectedTrack(Board, TrackList, NetName, PrevTrack, Track);
       PrevTrack.Selected := False;
       if (Track <> nil) and (TrackList.Count > 0) then
       begin
          SortedTrackList.Add(Track);
          TrackList.Remove(Track);
       end
       else
       begin
          break;
       end;
    end;

    result := SortedTrackList;
end;

function GetSlope(Track: IPCB_Track, var Slope: Double): Boolean;
begin
    result := True;
    if Track.x2 - Track.x1 = 0 then
    begin
        result := False;
        exit;
    end;
    Slope := (Track.y2 - Track.y1)/(Track.x2 - Track.x1);
end;

function GetAngleBetweenTracks(Track: IPCB_Track, PrevTrack: IPCB_Track): Double;
var
    Angle, m1, m2, r1, r2: Double;
    s1, s2: Boolean;
    x1, x2, y1, y2, px2, py2: Integer;
begin
    if (Track.x1 = PrevTrack.x1) and (Track.y1 = PrevTrack.y1) then
    begin
        x1 := Track.x1; y1 := Track.y1;
        x2 := Track.x2; y2 := Track.y2;
        px2 := PrevTrack.x2; py2 := PrevTrack.y2;
    end
    else if (Track.x1 = PrevTrack.x2) and (Track.y1 = PrevTrack.y2) then
    begin
        x1 := Track.x1; y1 := Track.y1;
        x2 := Track.x2; y2 := Track.y2;
        px2 := PrevTrack.x1; py2 := PrevTrack.y1;
    end
    else if (Track.x2 = PrevTrack.x1) and (Track.y2 = PrevTrack.y1) then
    begin
        x1 := Track.x2; y1 := Track.y2;
        x2 := Track.x1; y2 := Track.y1;
        px2 := PrevTrack.x2; py2 := PrevTrack.y2;
    end
    else if (Track.x2 = PrevTrack.x2) and (Track.y2 = PrevTrack.y2) then
    begin
        x1 := Track.x2; y1 := Track.y2;
        x2 := Track.x1; y2 := Track.y1;
        px2 := PrevTrack.x1; py2 := PrevTrack.y1;
    end;

    s1 := GetSlope(Track, m1);
    s2 := GetSlope(PrevTrack, m2);
    if (s1) and (s2) then
    begin
         Angle := RadToDeg(arctan((m2 - m1)/(1+m1*m2)));
    end
    else
    begin
         r1 := GetTrackRotation(Track, False);
         r2 := GetTrackRotation(PrevTrack, False);

         if (abs(r1) = 90) or (r1 = 270) then
         begin
             if y1 > y2 then r1 := 270;
             if y1 < y2 then r1 := 90;
         end;
         if (abs(r1) = 180) or (r1 = 0) then
         begin
             if x1 > x2 then r1 := 180;
             if x1 < x2 then r1 := 0;
         end;

         if (abs(r2) = 90) or (r2 = 270) then
         begin
             if y1 > py2 then r2 := 90;
             if y1 < py2 then r2 := 270;
         end;
         if (abs(r2) = 180) or (r2 = 0) then
         begin
             if x1 > px2 then r2 := 0;
             if x1 < px2 then r2 := 180;
         end;

         Angle :=  r2 - r1;
         Angle := Angle mod 90;
    end;
    result := Angle;
end;

function GetTrackRotationDelta(TrackList: TInterfaceList): Double;
var
   Rotation, PrevRotation, RotationDelta, TotalRotation: Double;
   i: Integer;
   trk: IPCB_Track;
   Sign: Double;
begin
   TotalRotation := 0;
   for i:=1 to TrackList.Count-1 do
   begin
       //TrackList[i].Selected := True;
       //TrackList[i-1].Selected := True;
       Rotation := GetAngleBetweenTracks(TrackList[i], TrackList[i-1]) mod 90;
       TotalRotation := TotalRotation + Rotation;
       //TrackList[i].Selected := False;
       //TrackList[i-1].Selected := False;
   end;
   result := TotalRotation;
end;

function GetDiffPairBend(Board: IPCB_Board, TrackList1: TInterfaceList, TrackList2: TInterfaceList) : Double;
var
    Track: IPCB_Track;
    i, trkLen: Integer;
    Bend1, Bend2 : Double;
    RotList1, RotList2: TInterfaceList;
begin
   Bend1 := 0; Bend2 := 0;
   Bend1 := GetTrackRotationDelta(TrackList1);
   Bend2 := GetTrackRotationDelta(TrackList2);
   if Bend1 = Bend2 then
   begin
       result := Bend1;
       exit;
   end
   else
   begin
       result := -1;
       ShowMessage('Unable to calculate differential pair bend.');
       exit;
   end;
end;

function GetTrackLength(Board: IPCB_Board, TrackList: TInterfaceList) : Double;
var
    trk: IPCB_Track;
    i, trkLen: Integer;
    segLen: Double;
begin
   trkLen := 0; segLen := 0;

   for i := 0 to TrackList.Count - 1 do
   begin
       trk := TrackList[i];
       trkLen := trk.GetState_Length();
       segLen := segLen + CoordToMils(trkLen);
   end;

   result := segLen;
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
   i, x, y: Integer;
   trkLen, bmpLen, trkBend : Double;
   NetList : TStringList;
   shortLen : Double;
   shortNet : String;
   TrackList1, TrackList2: TInterfaceList;
begin
   Board := PCBServer.GetCurrentPCBBoard;
   if Board = nil then exit;

   NetList := TStringList.Create;
   NetList := GetSelectedNetList(Board);

   if NetList.Count = 0 then
   begin
       ShowMessage('No tracks selected. Please select differential pair tracks before running.');
   end
   else if NetList.Count = 1 then
   begin
       ShowMessage('Only 1 track selected. Please select differential pair tracks before running.');
   end
   else if NetList.Count > 2 then
   begin
       ShowMessage('Too many tracks selected. Please only select one segment (2 tracks) of diff pair tracks.');
   end;

   // TODO: If only 2 tracks are selected and not entire track on layer, place single bump

   // Store selected tracks in lists
   TrackList1 := GetSelectedTrackList(Board, NetList.Get(0));
   TrackList2 := GetSelectedTrackList(Board, NetList.Get(1));
   Client.SendMessage('PCB:DeSelect', 'Scope=All', 255, Client.CurrentView);

   // SORT Tracks in track lists
   TrackList1 := SortTrackList(Board, TrackList1);
   TrackList2 := SortTrackList(Board, TrackList2);

   // If the last track is closer than the first track, reverse order
   if Board.PrimPrimDistance(TrackList1[0], TrackList2[0]) > Board.PrimPrimDistance(TrackList1[0], TrackList2[TrackList2.Count-1]) then
   begin
      TrackList2 := CopyList(TrackList2, True); // Copy in reverse order
   end;

   // Get overall bend on layer for diff pair
   trkBend := GetDiffPairBend(Board, TrackList1, TrackList2);
   if trkBend = -1 then
   begin
       // TODO: Add single bump
       // for now, exit
       exit;
   end;


   shortLen := GetTrackLength(Board, TrackList1);
   shortNet := TrackList1[0].Net.Name;
   if GetTrackLength(Board, TrackList2) < shortLen then
   begin
       shortLen := GetTrackLength(Board, TrackList2);
       shortNet := TrackList2[0].Net.Name;
   end;
   if shortLen = 0 then exit;

   found_gap := GetDiffPairGap(Board, gap);
   if not found_gap then exit;

   Track := GetSelectedTrack(Board);
   width := CoordToMils(Track.Width);
   CalculateBump(Board, width, gap, side_len, run_len);
   bmpLen := 2*run_len + 2*(side_len/sqrt(2));

   // First Segment (Flat track)
   Bump_Segment := GetBumpSegment(Track);
   Bump_Segment.MoveByXY(MilsToCoord(20), MilsToCoord(20));
   Bump_Segment.SetState_Length(MilsToCoord(run_len));
   Bump_Segment.RotateBy(-GetTrackRotation(Bump_Segment, True)); // Reset to horizontal
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
