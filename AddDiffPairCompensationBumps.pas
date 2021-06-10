var
    Board    : IPCB_Board;

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

function GetSelectedTrackList(NetName: String) : TInterfaceList;
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

function GetSelectedNetList() : TStringList;
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

function CalculateBump(trace_width: Double, diff_gap: Double, var side_len: Double, var top_len: Double) : Boolean;
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

function GetNextConnectedTrack(OriginalTrackList: TInterfaceList, Net: String, PrevTrk: IPCB_Track, CurTrk: IPCB_Track) : IPCB_Track;
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
          dist := CoordToMils(Board.PrimPrimDistance(CurTrk, trk));
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


function GetMatchingPairTrack(Track: IPCB_Track, TrackList: TInterfaceList) : IPCB_Track;
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

function GetEndTrack(OriginalTrackList: TInterfaceList, NetName: String) : IPCB_Track;
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
       Track := GetNextConnectedTrack(TrackList, NetName, PrevTrack, Track);
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

function SortTrackList(TrackList: TInterfaceList) : TInterfaceList;
var
    Track, PrevTrack: IPCB_Track;
    i: Integer;
    SortedTrackList: TInterfaceList;
    NetName: String;
begin
    NetName := TrackList[0].Net.Name;
    Track := GetEndTrack(TrackList, TrackList[0].Net.Name);
    TrackList.Remove(Track);

    SortedTrackList := TInterfaceList.Create;
    SortedTrackList.Add(Track);

    while TrackList.Count > 0 do
    begin
       PrevTrack := Track;
       Track.Selected := True;
       Track := GetNextConnectedTrack(TrackList, NetName, PrevTrack, Track);
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

function GetCoordFromLocation(Track: IPCB_Track, PrevTrack: IPCB_Track, Location:String, var x: Integer, var y: Integer);
var
    x_cent, y_cent, x_beg, y_beg, x_end, y_end: Integer;
begin
    if (Track.x1 = PrevTrack.x1) and (Track.y1 = PrevTrack.y1) then
    begin
        x_cent := Track.x1; y_cent := Track.y1;
        x_end := Track.x2; y_end := Track.y2;
        x_beg := PrevTrack.x2; y_beg := PrevTrack.y2;
    end
    else if (Track.x1 = PrevTrack.x2) and (Track.y1 = PrevTrack.y2) then
    begin
        x_cent := Track.x1; y_cent := Track.y1;
        x_end := Track.x2; y_end := Track.y2;
        x_beg := PrevTrack.x1; y_beg := PrevTrack.y1;
    end
    else if (Track.x2 = PrevTrack.x1) and (Track.y2 = PrevTrack.y1) then
    begin
        x_cent := Track.x2; y_cent := Track.y2;
        x_end := Track.x1; y_end := Track.y1;
        x_beg := PrevTrack.x2; y_beg := PrevTrack.y2;
    end
    else if (Track.x2 = PrevTrack.x2) and (Track.y2 = PrevTrack.y2) then
    begin
        x_cent := Track.x2; y_cent := Track.y2;
        x_end := Track.x1; y_end := Track.y1;
        x_beg := PrevTrack.x1; y_beg := PrevTrack.y1;
    end;



    if LowerCase(Location) = 'begin' then
    begin
        x := x_beg; y := y_beg;
    end
    else if LowerCase(Location) = 'end' then
    begin
        x := x_end; y := y_end;
    end
    else // Center
    begin
        x := x_cent; y := y_cent;
    end;
end;

function SameTrack(Track1: IPCB_Track, Track2: IPCB_Track): Boolean;
begin
    result := False;
    if (((Track1.x1 = Track2.x1) and (Track1.y1 = Track2.y1)) and
       ((Track1.x2 = Track2.x2) and (Track1.y2 = Track2.y2))) or
       (((Track1.x2 = Track2.x1) and (Track1.y2 = Track2.y1)) and
       ((Track1.x1 = Track2.x2) and (Track1.y1 = Track2.y2))) then
    begin
        result := True;
    end;
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

function GetDiffPairBend(TrackList1: TInterfaceList, TrackList2: TInterfaceList) : Double;
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
       ShowMessage('Unable to calculate differential pair bend. Try running Route --> Retrace Selected before running the script.');
       exit;
   end;
end;

function GetTrackLength(TrackList: TInterfaceList) : Double;
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

function GetClosestDiffPairDistance(Track: IPCB_Track, TrackList: TInterfaceList): Integer;
var
    trk: IPCB_Track;
    i, minDist: Integer;
begin
    for i:=0 to TrackList.Count -1 do
    begin
        trk := TrackList[i];

        if (i=0) or (Board.PrimPrimDistance(Track, trk) < minDist) then
        begin
           minDist := Board.PrimPrimDistance(Track, trk);
        end;
    end;
    result := minDist;
end;

function GetNextLargest(NumberList: TList): Integer;
var
    i, val, minVal: Integer;
begin
    for i:=0 to NumberList.Count - 1 do
    begin
        val := NumberList.Items[i];
        if (i=0) or (val < minVal) then
        begin
            minVal := NumberList.Items[i];
        end;
    end;
    result := minVal;
end;

function SortNumberList(NumberList: TList): TList;
var
    nextNumber: Double;
    sorted: TList;
begin
    sorted := TList.Create;
    while NumberList.Count > 0 do
    begin
        nextNumber := GetNextLargest(NumberList);
        sorted.Add(nextNumber);
        NumberList.Remove(nextNumber);
    end;
    result := sorted;
end;

function SwapTrackCoordinates(Track: IPCB_Track):IPCB_Track;
var
    NewTrack: IPCB_Track;
begin
    NewTrack := GetBumpSegment(Track);
    NewTrack.x1 := Track.x2;
    NewTrack.x2 := Track.x1;
    NewTrack.y1 := Track.y2;
    NewTrack.y2 := Track.y1;
    result := NewTrack;
end;

function GetDiffPairGap(TrackList1: TInterfaceList, TrackList2: TInterfaceList) : Double;
var
    i: Integer;
    GapList: TList;
    val: Double;
begin
   GapList := TList.Create;

   for i := 0 to TrackList1.Count - 1 do
   begin
      GapList.Add(GetClosestDiffPairDistance(TrackList1[i], TrackList2));
   end;

   GapList := SortNumberList(GapList);

   // Get median value
   result := CoordToMils(GapList[int(GapList.Count/2)]);
end;

function TrackClearanceGood(Track: IPCB_Track, minClearance: Integer, MatchingNet: String): Boolean;
const
    FILTER_PAD = 5; // mils
var
    Iterator: IPCB_SpatialIterator;
    Rect : TCoordRect;
    pad : Integer;
    Obj: IPCB_ObjectClass;
begin
    result := True;

    pad := MilsToCoord(FILTER_PAD);
    Rect := Track.BoundingRectangle;

    Iterator := Board.SpatialIterator_Create;
    Iterator.AddFilter_ObjectSet(MkSet(eViaObject, ePadObject, eTrackObject));
    Iterator.AddFilter_LayerSet(MkSet(eMultiLayer, Track.Layer));
    Iterator.AddFilter_Area(Rect.Left - pad, Rect.Bottom - pad, Rect.Right + pad, Rect.Top + pad);

    Obj := Iterator.FirstPCBObject;
    while Obj <> nil do
    begin
        if (Obj.ObjectId = eTrackObject) and ((Obj.Net.Name = Track.Net.Name) or (Obj.Net.Name = MatchingNet)) then
        begin
            Obj := Iterator.NextPCBObject;
            continue;
        end;

        if Board.PrimPrimDistance(Track, Obj) < minClearance then
        begin
            result := False;
            exit;
        end;
        Obj := Iterator.NextPCBObject;
    end;
    Board.SpatialIterator_Destroy(Iterator);
end;

function AddBumpToTrack(MatchingTrackList: TInterfaceList, gap: Double, var Track: IPCB_Track): Boolean;
const
    MIN_OTHER_OBJ_CLEARANCE = 4;
var
    side_len, run_len, width, flatLen, closestDist, dist : Double;
    Bump_Segment, Prev_Bump_Segment: IPCB_Track;
    i, j, x, y, direction, addRot: Integer;
    TrksAdded: TInterfaceList;
begin
   PCBServer.PreProcess;

   result := True;
   direction := 1; addRot := 0;
   TrksAdded := TInterfaceList.Create;

   CalculateBump(CoordToMils(Track.Width), gap, side_len, run_len);
   flatLen := 2*run_len + 2*(side_len/sqrt(2));

   // First Segment (Flat track)
   Bump_Segment := GetBumpSegment(Track);
   Bump_Segment.SetState_Length(MilsToCoord(run_len));
   PCBServer.SendMessageToRobots(Bump_Segment.I_ObjectAddress, c_Broadcast, PCBM_BeginModify, c_NoEventData);
   Board.AddPCBObject(Bump_Segment);
   PCBServer.SendMessageToRobots(Bump_Segment.I_ObjectAddress, c_Broadcast, PCBM_EndModify, c_NoEventData);
   TrksAdded.Add(Bump_Segment);

   x := Bump_Segment.x2;
   y := Bump_Segment.y2;

   // Second Segment (45 track)
   Prev_Bump_Segment := GetBumpSegment(Bump_Segment);
   Bump_Segment := GetBumpSegment(Bump_Segment);
   Bump_Segment.MoveToXY(x, y);
   Bump_Segment.SetState_Length(MilsToCoord(side_len));
   Bump_Segment.RotateBy(direction*45.0);
   closestDist := CoordToMils(GetClosestDiffPairDistance(Bump_Segment, MatchingTrackList));
   if closestDist < gap then
   begin
       direction := direction * -1;
       Bump_Segment.RotateBy(direction*90);
       if Board.PrimPrimDistance(Bump_Segment, Prev_Bump_Segment) <> 0 then
       begin
           Bump_Segment.RotateBy(180);
           Bump_Segment.MoveToXY(x, y);
       end;
   end;
   PCBServer.SendMessageToRobots(Bump_Segment.I_ObjectAddress, c_Broadcast, PCBM_BeginModify, c_NoEventData);
   Board.AddPCBObject(Bump_Segment);
   PCBServer.SendMessageToRobots(Bump_Segment.I_ObjectAddress, c_Broadcast, PCBM_EndModify, c_NoEventData);
   TrksAdded.Add(Bump_Segment);

   GetCoordFromLocation(Bump_Segment, Prev_Bump_Segment, 'end', x, y);

   // Third Segment (Top flat track)
   Prev_Bump_Segment := GetBumpSegment(Bump_Segment);
   Bump_Segment := GetBumpSegment(Bump_Segment);
   Bump_Segment.MoveToXY(x, y);
   if SameTrack(Bump_Segment, Prev_Bump_Segment) then
   begin
      addRot := 180; // Bump segment didn't move outside previous bump, so rotate 180
   end;
   Bump_Segment.SetState_Length(MilsToCoord(run_len));
   Bump_Segment.RotateBy((direction*-45.0)+addRot);
   PCBServer.SendMessageToRobots(Bump_Segment.I_ObjectAddress, c_Broadcast, PCBM_BeginModify, c_NoEventData);
   Board.AddPCBObject(Bump_Segment);
   PCBServer.SendMessageToRobots(Bump_Segment.I_ObjectAddress, c_Broadcast, PCBM_EndModify, c_NoEventData);
   TrksAdded.Add(Bump_Segment);

   GetCoordFromLocation(Bump_Segment, Prev_Bump_Segment, 'end', x, y);

   // Last Segment (-45 track)
   Prev_Bump_Segment := GetBumpSegment(Bump_Segment);
   Bump_Segment := GetBumpSegment(Bump_Segment);
   Bump_Segment.MoveToXY(x, y);
   Bump_Segment.SetState_Length(MilsToCoord(side_len));
   Bump_Segment.RotateBy(direction*-45.0);
   PCBServer.SendMessageToRobots(Bump_Segment.I_ObjectAddress, c_Broadcast, PCBM_BeginModify, c_NoEventData);
   Board.AddPCBObject(Bump_Segment);
   PCBServer.SendMessageToRobots(Bump_Segment.I_ObjectAddress, c_Broadcast, PCBM_EndModify, c_NoEventData);
   TrksAdded.Add(Bump_Segment);

   GetCoordFromLocation(Bump_Segment, Prev_Bump_Segment, 'end', x, y);

   // Verify Bump Clearances, Skip first track
   for i:=1 to TrksAdded.Count - 1 do
   begin
       if not TrackClearanceGood(TrksAdded[i], MilsToCoord(MIN_OTHER_OBJ_CLEARANCE), MatchingTrackList[0].Net.Name) then
       begin
           result := False;
           for j:=0 to TrksAdded.Count - 1 do
           begin
               Board.RemovePCBObject(TrksAdded[j]);
           end;

           // Add flat track
           Bump_Segment := GetBumpSegment(Track);
           Bump_Segment.SetState_Length(MilsToCoord(flatLen));
           PCBServer.SendMessageToRobots(Bump_Segment.I_ObjectAddress, c_Broadcast, PCBM_BeginModify, c_NoEventData);
           Board.AddPCBObject(Bump_Segment);
           PCBServer.SendMessageToRobots(Bump_Segment.I_ObjectAddress, c_Broadcast, PCBM_EndModify, c_NoEventData);
       break;
       end;
   end;

   // Update original track so it doesn't overlap new bump
   PCBServer.SendMessageToRobots(Track.I_ObjectAddress, c_Broadcast, PCBM_BeginModify , c_NoEventData);
   Track.SetState_Length(Track.GetState_Length() - MilsToCoord(flatLen));
   Track.MoveToXY(x, y);
   PCBServer.SendMessageToRobots(Track.I_ObjectAddress, c_Broadcast, PCBM_EndModify , c_NoEventData);

   PCBServer.PostProcess;

   Board.ViewManager_FullUpdate;
end;

procedure Run;
const
   BUMP_CHAIN_LIMIT = 4;
var
   Arc      : IPCB_Arc;
   Track, Bump : IPCB_Track;
   gap, width: Double;
   i, bmpChainCnt, bumpsNeeded, bumpsAdded: Integer;
   trkLen, trkBend : Double;
   NetList : TStringList;
   shortLen, side_len, run_len, flat_len : Double;
   TrackList1, TrackList2, ShortTrkList, LongTrkList: TInterfaceList;
begin
   Board := PCBServer.GetCurrentPCBBoard;
   if Board = nil then exit;

   NetList := TStringList.Create;
   NetList := GetSelectedNetList();

   if NetList.Count = 0 then
   begin
       ShowMessage('No tracks selected. Please select differential pair tracks before running.');
       exit;
   end
   else if NetList.Count = 1 then
   begin
       ShowMessage('Only 1 track selected. Please select differential pair tracks before running.');
       exit;
   end
   else if NetList.Count > 2 then
   begin
       ShowMessage('Too many tracks selected. Please only select one segment (2 tracks) of diff pair tracks.');
       exit;
   end;

   // TODO: If only 2 tracks are selected and not entire track on layer, place single bump

   // Store selected tracks in lists
   TrackList1 := GetSelectedTrackList(NetList.Get(0));
   TrackList2 := GetSelectedTrackList(NetList.Get(1));
   Client.SendMessage('PCB:DeSelect', 'Scope=All', 255, Client.CurrentView);

   // SORT Tracks in track lists
   TrackList1 := SortTrackList(TrackList1);
   TrackList2 := SortTrackList(TrackList2);

   // If the last track is closer than the first track, reverse order
   if Board.PrimPrimDistance(TrackList1[0], TrackList2[0]) > Board.PrimPrimDistance(TrackList1[0], TrackList2[TrackList2.Count-1]) then
   begin
      TrackList2 := CopyList(TrackList2, True); // Copy in reverse order
   end;

   // Get overall bend on layer for diff pair
   trkBend := GetDiffPairBend(TrackList1, TrackList2);
   if trkBend = -1 then
   begin
       // TODO: Add single bump
       // for now, exit
       exit;
   end;
   bumpsNeeded := Round(abs(trkBend)/45)*2; // Number of bumps to match length

   // Get shortest differential pair
   shortLen := GetTrackLength(TrackList1);
   ShortTrkList := CopyList(TrackList1, False);
   LongTrkList := CopyList(TrackList2, False);
   if GetTrackLength(TrackList2) < shortLen then
   begin
       shortLen := GetTrackLength(TrackList2);
       ShortTrkList := CopyList(TrackList2, False);
       LongTrkList := CopyList(TrackList1, False);
   end;
   if shortLen = 0 then exit;

   gap := GetDiffPairGap(TrackList1, TrackList2);

   width := CoordToMils(TrackList1[0].Width);
   CalculateBump(width, gap, side_len, run_len);
   flat_len := 2*run_len + 2*(side_len/sqrt(2));

   bumpsAdded := 0;
   for i:=0 to ShortTrkList.Count - 1 do
   begin
       Track := ShortTrkList[i];
       trkLen := CoordToMils(Track.GetState_Length());

       bmpChainCnt := 0;
       while (CoordToMils(Track.GetState_Length()) > flat_len+run_len) and (bmpChainCnt < BUMP_CHAIN_LIMIT) do
       begin
           if AddBumpToTrack(LongTrkList, gap, Track) then
           begin
               Inc(bmpChainCnt);
               Inc(bumpsAdded);
           end;
           if bumpsAdded >= bumpsNeeded then break;
       end;
       if bumpsAdded >= bumpsNeeded then break;
   end;

   Board.ViewManager_FullUpdate;

   ShowMessage(IntToStr(bumpsAdded)+' of '+IntToStr(bumpsNeeded)+' bumps successfully added.'+
   ' Width: '+FloatToStr(width)+
   ', Gap: '+FloatToStr(gap)+
   ', Side Length: '+FloatToStr(side_len)+
   ', Run Length: '+FloatToStr(run_len));
end;
