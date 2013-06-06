unit ControlEditor;

interface

uses System.SysUtils, System.Types, System.UITypes, System.Rtti,
  System.Variants, System.Classes, FMX.Messages,
  FMX.Layouts, FMX.Objects, FMX.Controls, FMX.Types;

type
  TPinPosition = (ppTopLeft, ppTop, ppTopRight,
                  ppLeft, ppCenter, ppRight,
                  ppBottomLeft, ppBottom, ppBottomRight);
  TPinPositions = set of TPinPosition;
  TControlHanger = class;

  TControlResizeMessage = class(TMessage)
  private
    FControl: TControl;
  public
    constructor Create(const AControl: TControl);
    property Control: TControl read FControl;
  end;

  THangerPin = class(TRectangle)
  private
    FHanger: TControlHanger;
    FPinPosition: TPinPosition;
    FMouseDown: Boolean;
    FMouseDownPt: TPointF;
    procedure SetHanger(const Value: TControlHanger);
    procedure SetPinPosition(const Value: TPinPosition);
  protected
    procedure DoMouseEnter; override;
    procedure DoMouseLeave; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Single); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Single); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Single); override;

  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    property PinPosition: TPinPosition read FPinPosition write SetPinPosition;
    property Hanger: TControlHanger read FHanger write SetHanger;
  end;

  TControlSelection = class(THangerPin)
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  end;

  TControlHanger = class(TStyledControl)
  private
    FResizeControlMsgId: Integer;
    FTarget: TControl;
    fSelection: TRectangle;
    FPins: array[ppTopLeft..ppBottomRight] of THangerPin;
    FPinSize: Single;
    FDragging: Boolean;
    FActivePin: TPinPosition;
    procedure SetTarget(const Value: TControl);
    procedure SetPinSize(const Value: Single);

    procedure ResizeControlHandler(const Sender : TObject; const Msg : TMessage);

  protected
    procedure ApplyStyle; override;
    procedure FreeStyle; override;
    procedure ApplyStyleLookup; override;
    procedure AttachToTarget(const AResize: Boolean = True);
    procedure ResizeTarget;// override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    property Target: TControl read FTarget write SetTarget;
    property PinSize: Single read FPinSize write SetPinSize;
  end;





implementation

{ TControlHanger }
procedure TControlHanger.ApplyStyle;
var
  p: TPinPosition;
begin
  inherited;
  for p := Low(TPinPosition) to High(TPinPosition) do
  begin
    FPins[p] := THangerPin.Create(Self);
    FPins[p].PinPosition := p;
//    FPins[p].Visible := True;
  end;
  fSelection := TControlSelection.Create(Self);
  fSelection.Parent := Self;
  fSelection.Fill.Color := $01FFFFFF;
  fSelection.Stroke.Color := $802995da;
  fSelection.Align := TAlignLayout.alContents;
  fSelection.SendToBack;
  fSelection.Margins.Rect := RectF(2, 2, 2, 2);
  AttachToTarget;
end;

procedure TControlHanger.ApplyStyleLookup;
begin
  inherited;

end;

procedure TControlHanger.AttachToTarget(const AResize: Boolean);
var
  p: TPinPosition;
  pin: THangerPin;
  r: TRectF;
  sx, sy: Single;

  procedure PinPos(const DX, DY: Single);
  begin
    if DX < 0 then
      pin.Position.X := 0
    else if DX=0 then
      pin.Position.X := Width/2 - SX
    else
      pin.Position.X := Width - FPinSize;

    if DY < 0 then
      pin.Position.Y := 0
    else if DY=0 then
      pin.Position.Y := Height/2 - SY
    else
      pin.Position.Y := Height - FPinSize;


  end;

begin
  if FTarget = nil then
  begin
    Visible := False;
    Exit;
  end;
  Parent := Target.Parent;
  r := RectF(Target.Position.X, Target.Position.Y,
    Target.Width+Target.Position.X,
    Target.Height+Target.Position.Y
    );
  sx := fPinSize/2;
  sy := FPinSize/2;
  if AResize then SetBounds(R.Left-SX, R.Top-SY, R.Width+fPinSize, R.Height+fPinSize);
  for p := Low(TPinPosition) to High(TPinPosition) do
  begin
    pin := FPins[p];
    if pin = nil then Continue;
    if pin.Parent <> Self then pin.Parent := Self;
//    pin.Width := fPinSize;
//    pin.Height := fPinSize;
    case p of
      ppTopLeft: PinPos(-1, -1);
      ppTop: PinPos(0, -1);
      ppTopRight: PinPos(1, -1);

      ppLeft: PinPos(-1, 0);
      ppCenter:
        begin
          PinPos(0, 0);
          // pin.Visible := False;
        end;
      ppRight: PinPos(1, 0);

      ppBottomLeft: PinPos(-1, 1);
      ppBottom: PinPos(0, 1);
      ppBottomRight: PinPos(1, 1);
    end;

    pin.Visible := p <> ppCenter;

  end;
  Visible := True;
  BringToFront;
end;

constructor TControlHanger.Create(AOwner: TComponent);
begin
  inherited;
  FResizeControlMsgId := TMessageManager.DefaultManager.SubscribeToMessage(TControlResizeMessage,
    ResizeControlHandler);
  fTarget := Self;
  fPinsize := 5;
  ApplyStyle;
end;

destructor TControlHanger.Destroy;
begin

  inherited;
end;


procedure TControlHanger.FreeStyle;
begin
  inherited;

end;

procedure TControlHanger.ResizeTarget;
var
  sx: Single;
begin
//  inherited;
  sx := fPinSize/2;
  if (Target <> nil) and (Target <> Self) then
  begin
    Target.SetBounds(
      Trunc(Position.X+sx),
      Trunc(Position.Y+sx),
      Trunc(Width-sx*2),
      Trunc(Height-sx*2)
    );
//    AttachToTarget(False);

  end else
  begin
    BringToFront;
  end;
end;

procedure TControlHanger.ResizeControlHandler(const Sender: TObject;
  const Msg: TMessage);
begin

end;

procedure TControlHanger.SetPinSize(const Value: Single);
begin
  FPinSize := Value;
end;

procedure TControlHanger.SetTarget(const Value: TControl);
begin
  FTarget := Value;
  AttachToTarget;
end;

{ THangerPin }

constructor THangerPin.Create(AOwner: TComponent);
begin
  inherited;
  if AOwner is TControlHanger then
  begin
    FHanger := TControlHanger(AOwner);
    Parent := TFmxObject(Aowner);
  end;
  FMouseDown := False;
  Width := 5;
  Height := 5;
  Fill.Color := $FF000000;
  Fill.Kind := TBrushKind.bkSolid;
  // Stroke.Kind := TBrushKind.bkNone;
end;

destructor THangerPin.Destroy;
begin

  inherited;
end;


procedure THangerPin.DoMouseEnter;
begin
  inherited;
end;

procedure THangerPin.DoMouseLeave;
begin
  inherited;

end;

procedure THangerPin.MouseDown(Button: TMouseButton; Shift: TShiftState; X,
  Y: Single);
begin
  inherited;
  FMouseDown := True;
  FMouseDownPt := PointF(X, Y);
  Capture;
end;

procedure THangerPin.MouseMove(Shift: TShiftState; X, Y: Single);

  procedure ResizeControl(X, Y, W, H: Single);
  begin
    Hanger.SetBounds(Hanger.Position.X + X, Hanger.Position.Y+Y,
      Hanger.Width+W, Hanger.Height+H);
    Hanger.ResizeTarget;
    Hanger.AttachToTarget(False);
  end;

var
  dx, dy: Single;
begin
  inherited;

  dx := X-FMouseDownPt.X;
  dy := Y-FMouseDownPt.Y;
  if FMouseDown then
  begin
    case FPinPosition of
      ppTopLeft: ResizeControl(DX, DY, -DX, -DY);
      ppTop: ResizeControl(0, DY, 0, -DY);
      ppTopRight: ResizeControl(0, DY, DX, -DY);

      ppLeft: ResizeControl(DX, 0, -DX, 0);
      ppRight:  ResizeControl(0, 0, DX, 0);

      ppCenter: ResizeControl(DX, DY, 0, 0);

      ppBottomLeft: ResizeControl(DX, 0, -DX, DY);
      ppBottom: ResizeControl(0, 0, 0, DY);
      ppBottomRight: ResizeControl(0, 0, DX, DY);
    end;
  end;
end;

procedure THangerPin.MouseUp(Button: TMouseButton; Shift: TShiftState; X,
  Y: Single);
begin
  inherited;
  FMouseDown := False;
  ReleaseCapture;
end;

procedure THangerPin.SetHanger(const Value: TControlHanger);
begin
  FHanger := Value;
end;

procedure THangerPin.SetPinPosition(const Value: TPinPosition);
begin
  FPinPosition := Value;
  case FPinPosition of
    ppTopLeft: Cursor := crSizeNWSE;
    ppTop: Cursor := crSizeNS;
    ppTopRight: Cursor := crSizeNESW;

    ppLeft: Cursor := crSizeWE;
    ppRight: Cursor := crSizeWE;

    ppBottomLeft: Cursor := crSizeNESW;
    ppBottom: Cursor := crSizeNS;
    ppBottomRight: Cursor := crSizeNWSE;
  end;

end;

{ TControlSelection }

constructor TControlSelection.Create(AOwner: TComponent);
begin
  inherited;
  FPinPosition := ppCenter;
end;

destructor TControlSelection.Destroy;
begin

  inherited;
end;

{ TControlResizeMessage }

constructor TControlResizeMessage.Create(const AControl: TControl);
begin
  inherited Create;
  fControl := AControl;
end;

end.
