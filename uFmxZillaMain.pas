unit uFmxZillaMain;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Rtti, TypInfo,
  System.Classes,
  System.Variants, FMX.Types, FMX.Controls, FMX.Forms, FMX.Dialogs,
  FMX.StdCtrls, FMX.Layouts, FMX.ListBox, System.Generics.Collections,
  FMX.Objects, FMX.Edit, FMX.TreeView, ControlEditor, FMX.ExtCtrls, FMX.Grid;

type
  TStringGridHelper = class helper for TStringGrid
  public
    function CellRect(ACol, ARow: Integer): TRectF;
    function SelectedCellRect: TRectF;
  end;


  TFMXClass = class of TFMXObject;
  TControlPaletteItem = class
  private
    FFMXClass: TFMXClass;
    FIcon: TBitmap;
    procedure SetFMXClass(const Value: TFMXClass);
    procedure SetIcon(const Value: TBitmap);
  public
    constructor Create;
    destructor Destroy; override;

    property FMXClass: TFMXClass read FFMXClass write SetFMXClass;
    property Icon: TBitmap read FIcon write SetIcon;
  end;
  TControlPalette = TObjectDictionary<String, TControlPaletteItem>;
  TControls = TObjectList<TControl>;

  TfrmMonkeyzilla = class(TForm)
    layLeft: TLayout;
    layRight: TLayout;
    layContent: TLayout;
    layTop: TLayout;
    btnOpen: TButton;
    dlgOpen: TOpenDialog;
    sbSelf: TStyleBook;
    lstControlPalette: TListBox;
    tvControls: TTreeView;
    gridProperties: TStringGrid;
    colPropertyNames: TStringColumn;
    colValues: TStringColumn;
    Splitter1: TSplitter;
    StyleBook1: TStyleBook;
    Splitter2: TSplitter;
    Splitter3: TSplitter;
    Text1: TText;
    cboEnumProperty: TComboBox;
    sbContents: TFramedScrollBox;
    StyleBook3: TStyleBook;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure tvControlsClick(Sender: TObject);
    procedure SpeedButton1Click(Sender: TObject);
    procedure layContentMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Single);
    procedure gridPropertiesResize(Sender: TObject);
    procedure gridPropertiesSelChanged(Sender: TObject);
    procedure FormShow(Sender: TObject);
  private
    { Private declarations }
    fControlPalette: TControlPalette;
    fControls: TControls;
    fHanger: TControlHanger;
    fSelectedControl, fActiveDesign: TControl;
    fControlProperties: PPropList;
    procedure FillControlPalette;
    procedure AddControlToPalette(AControlClass: TFMXClass);
    procedure AddControlsToPalette(AControlClasses: array of TFMXClass);
    procedure RefreshUI;
    procedure FillControls;
    function AddControlToTree(AControl: TFMXObject; AParentNode: TTreeViewItem): TTreeViewItem;
    procedure SelectControl(AControl: TControl);
    procedure ShowProperties(AControl: TControl);
    procedure LoadStyles;
    function FindRootNode(ATreenode: TTreeViewItem): TTreeViewItem;
  public
    { Public declarations }
  end;

var
  frmMonkeyzilla: TfrmMonkeyzilla;

implementation

uses Math;

{$R *.fmx}
function IsReadablePropInfo(APropInfo: PPropInfo): Boolean; inline;
begin
  Result := False;
  if APropInfo^.GetProc = nil then
  begin
    Exit;
  end;
  case APropInfo.PropType^^.Kind of
  tkInteger, tkChar,
    tkWChar, tkEnumeration, tkSet, tkFloat, tkString, tkLString,
    tkWString, tkUString, tkInt64:
    begin
      Result := True;
    end;
  else
    // Not readable
  end;
end;


function getReadPropList(AControl: TObject; out APropList: PPropList): Integer;
var
  pplist: PPropList;
  c, i, j: Integer;
  val: Variant;
  info: PTypeInfo;
begin
  info := (AControl.ClassInfo);
  Result := 0;
  //  c := GetTypeData(info)^.PropCount;
  c := GetPropList(info, tkProperties, nil, True);
  GetMem(pplist, c * SizeOf(Pointer));
  try
    c := GetPropList(info, tkProperties, pplist, True);

    j := 0;

    for i := 0 to c-1 do
    begin
      if IsReadablePropInfo(pplist[i]) then Inc(j);
    end;

    GetMem(APropList, SizeOf(Pointer)*j);

    j := 0;
    for i := 0 to c-1 do
    begin
      if IsReadablePropInfo(pplist[i]) then
      begin
        APropList[j] := pplist[i];
        Inc(j);
      end;
    end;

    Result := j;
  finally

    FreeMem(pplist);
  end;


end;


type
  TComponentHack = class(TComponent);

  { TfrmMonkeyzilla }

procedure TfrmMonkeyzilla.AddControlsToPalette(
  AControlClasses: array of TFMXClass);
var
  i: Integer;
begin
  for I := Low(AControlClasses) to High(AControlClasses) do
  begin
    AddControlToPalette(AControlClasses[i]);
  end;
end;

procedure TfrmMonkeyzilla.AddControlToPalette(AControlClass: TFMXClass);
var
  pal: TControlPaletteItem;
begin
  pal := TControlPaletteItem.Create;
  pal.FMXClass := AControlClass;

  fControlPalette.AddOrSetValue(AControlClass.ClassName, pal);
end;

function TfrmMonkeyzilla.AddControlToTree(AControl: TFMXObject;
  AParentNode: TTreeViewItem): TTreeViewItem;
var
  i: Integer;
begin

  if not (AControl is TStyleContainer) then
  begin
    Result := TTreeViewItem.Create(tvControls);
    TComponentHack(AControl).SetDesignInstance(True);
    Result.TagObject := AControl;
    if AControl.StyleName <> '' then
      Result.Text := Format('%s:%s', [AControl.Stylename, AControl.ClassName])
    else
      Result.Text := Format('%s:%s', [AControl.Name, AControl.ClassName]);
    if AParentNode <> nil then
    begin
      AParentNode.AddObject(Result);
    end else
    begin
      tvControls.AddObject(Result);
    end;
  end else
  begin
    Result := nil;
  end;

  if AControl <> tvControls then
    for I := 0 to AControl.ChildrenCount-1 do
    begin
      if (AControl.Children[i] is TControl) then
        AddControlToTree(AControl.Children[i], Result);
    end;

end;

procedure TfrmMonkeyzilla.FillControlPalette;
begin
  AddControlsToPalette([TText, TImage, TLine, TRectangle,
    TCircle, TRoundRect, TPie, TEllipse, TLayout, TListBox, TEdit,
    TButton]);
end;

procedure TfrmMonkeyzilla.FillControls;
var
  i: Integer;
begin
  for I := 0 to fControls.Count-1 do
  begin
    AddControlToTree(fControls[i], nil);
  end;
end;

procedure TfrmMonkeyzilla.FormCreate(Sender: TObject);
var
  i: Integer;
begin
  fControls := TControls.Create(False);
  fActiveDesign := nil;
  fSelectedControl := nil;
  fControlProperties := nil;
//  for I := 0 to ComponentCount-1 do
//  begin
//    if (Components[i] is TControl) then
//    begin
//      if TControl(Components[i]).Parent = Self then
//      begin
//        fControls.Add(TControl(Components[i]));
//      end;
//    end;
//  end;
  fHanger := TControlHanger.Create(Self);
  fHanger.Parent := Self;
//  fHanger.SetBounds(20, 20, 20, 20);
//  fHanger.BringToFront;

  fHanger.Visible := False;

  fControlPalette := TControlPalette.Create([doOwnsValues], 100);
  FillControlPalette;
//  FillControls;
  LoadStyles;
end;

procedure TfrmMonkeyzilla.FormDestroy(Sender: TObject);
begin
  fControlPalette.Free;
  fControls.Free;
end;

procedure TfrmMonkeyzilla.FormShow(Sender: TObject);
begin
  RefreshUI;
end;

procedure TfrmMonkeyzilla.gridPropertiesResize(Sender: TObject);
begin
  colValues.Width := gridProperties.ClientWidth-colPropertyNames.Width;
end;

procedure TfrmMonkeyzilla.gridPropertiesSelChanged(Sender: TObject);
var
  typeinfo: PTypeInfo;
  i, addIndex: Integer;
  r: TRectF;
begin
  Text1.Text := gridProperties.Cells[gridProperties.ColumnIndex, gridProperties.Selected];
  typeinfo := fControlProperties[gridProperties.Selected]^.PropType^;
  case typeinfo^.Kind of
  tkEnumeration:
  begin
    cboEnumProperty.Items.Clear;
    for i := typeinfo^.TypeData^.MinValue to typeinfo^.TypeData^.MaxValue do
    begin
      addIndex := cboEnumProperty.Items.Add(GetEnumName(typeinfo, i));
      if (GetEnumName(typeinfo, i) = GetPropValue( fSelectedControl, fControlProperties[gridProperties.Selected], True)) then
      begin
        cboEnumProperty.ItemIndex := addIndex;
      end;

    end;
    r := gridProperties.SelectedCellRect;
    cboEnumProperty.SetBounds(r.Left, r.Top, r.Width, r.Height);
    cboEnumProperty.Visible := True;
  end;
  else
    cboEnumProperty.Visible := False;
  end;
end;

procedure TfrmMonkeyzilla.layContentMouseDown(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Single);
var
  i: Integer;
  c: TControl;
  mousePt: TPointF;
begin

  if fActiveDesign = nil then Exit;

  mousePT := TControl(Sender).LocalToAbsolute(PointF(X, Y));

//  c := fLastClicked.ObjectAtPoint(mousePT);
  for i := 0 to fActiveDesign.Controls.Count-1 do
  begin
    c := fActiveDesign.Controls[i];

    if (c.PointInObject(mousePT.X, mousePT.Y)) then
    begin
      if c <> fHanger then
      begin
        SelectControl(c);
        Exit;
      end;
    end;
  end;

  SelectControl(nil);
end;

procedure TfrmMonkeyzilla.LoadStyles;
var
  i: Integer;
begin
  Stylebook1.FileName := 'C:\Users\Public\Documents\RAD Studio\11.0\Styles\Air.Style';

  for I := 0 to Stylebook1.Style.ChildrenCount-1 do
  begin
    if (Stylebook1.Style.Children[i] is TControl) then
      AddControlToTree(Stylebook1.Style.Children[i], nil);
  end;


  AddControlToTree(Stylebook1.Style, nil);
end;

procedure TfrmMonkeyzilla.RefreshUI;
var
  pal: TControlPaletteItem;
  listitem: TListboxItem;
begin
  lstControlPalette.Clear;
  for pal in fControlPalette.Values do
  begin
    listitem := TListboxitem.Create(Self);
    listitem.StyleLookup := 'component_item';
    listitem.ApplyStyleLookup;
    listitem.Text := pal.FMXClass.ClassName;
    listitem.StylesData['icon'] := pal.Icon;
    listitem.Parent := lstControlPalette;
//    listitem.StylesData['text'] := pal.FMXClass.ClassName;
//    lstControlPalette.AddObject(listitem);
  end;
end;

procedure TfrmMonkeyzilla.SelectControl(AControl: TControl);
begin
  fHanger.Target := AControl;
  fSelectedControl := AControl;
//  fHanger.Visible := True;
  ShowProperties(AControl);
end;

procedure TfrmMonkeyzilla.ShowProperties(AControl: TControl);
var
  c, i, j: Integer;
begin
  if fControlProperties <> nil then
  begin
    FreeMem(fControlProperties);
    fControlProperties := nil;
  end;

  if AControl=nil then
  begin
    gridProperties.RowCount := 0;
    Exit;
  end;

  c := getReadPropList(AControl, fControlProperties);

  if c <= 0 then Exit;

  gridProperties.RowCount := c;
  for i := 0 to c-1 do
  begin
    gridProperties.Cells[0, i] := GetPropName(fControlProperties^[i]);
    gridProperties.Cells[1, i] := GetPropValue(AControl, fControlProperties^[i]);
  end;

end;

procedure TfrmMonkeyzilla.SpeedButton1Click(Sender: TObject);
begin
  SelectControl(TStyledControl(Sender));
end;

function TfrmMonkeyzilla.FindRootNode(ATreenode: TTreeViewItem): TTreeViewItem;
begin
  if ATreenode.ParentItem = nil then
  begin
    Result := ATreenode;
    Exit;
  end else
  begin
    Result := FindRootNode(ATreenode.ParentItem);
  end;

end;

procedure TfrmMonkeyzilla.tvControlsClick(Sender: TObject);
var
  clicked, rootCtrl: TControl;
  isControlRoot: Boolean;
begin

  isControlRoot := tvControls.Selected.Level = 0;

  try
    if tvControls.Selected.TagObject is TControl then
    begin
      clicked := TControl(tvControls.Selected.TagObject);
      rootCtrl := TControl(FindRootNode(tvControls.Selected).TagObject);

      if (clicked = nil) or (rootCtrl=nil) then Exit;

      if rootCtrl <> fActiveDesign then
      begin
        rootCtrl.Parent := sbContents;
        rootCtrl.SetDesign(True);
        rootCtrl.DesignVisible := True;
        rootCtrl.SetBounds(
          (sbContents.Width-rootCtrl.Width)/2,
          (sbContents.Height-rootCtrl.Height)/2,
          rootCtrl.Width,
          rootCtrl.Height
           );

        rootCtrl.Visible := True;
        if (fActiveDesign <> nil) then //(flastClicked.Parent = sbContents)
          fActiveDesign.Parent := nil;
        fActiveDesign := rootCtrl;
      end;
//      ShowProperties(clicked);
      SelectControl(clicked);
    end;
  except
//    ReleaseCapture;
  end;

end;

{ TControlPaletteItem }

constructor TControlPaletteItem.Create;
begin
  inherited Create;
  fIcon := TBitmap.Create(0, 0);

end;

destructor TControlPaletteItem.Destroy;
begin
  fIcon.Free;
  inherited;
end;

procedure TControlPaletteItem.SetFMXClass(const Value: TFMXClass);
var
  iconfile: TFilename;
begin
  FFMXClass := Value;
  iconfile := GetHomePath() +
    '/FireMonkeyStyler/Components/Icons/' +
    FMXClass.ClassName + '.bmp';

  if FileExists(iconfile) then
    FIcon.LoadFromFile(iconfile);
end;

procedure TControlPaletteItem.SetIcon(const Value: TBitmap);
begin
  FIcon.Assign(Value);
end;

{ TStringGridHelper }

function TStringGridHelper.CellRect(ACol, ARow: Integer): TRectF;
var
  x, y: Single;
  i: Integer;
begin
  x := 0;
  for i := 0 to ACol-1 do
  begin
    x := x + Self.Columns[i].Width;
  end;
  y := (ARow) * Self.RowHeight;

  Result := RectF(x, y, x + Self.Columns[ACol].Width,
    Min(y + Self.RowHeight, Self.ClientWidth));
  InflateRect(Result, -1, -1);
end;

function TStringGridHelper.SelectedCellRect: TRectF;
begin
  Result := Self.CellRect(ColumnIndex, Selected);
end;

initialization
  GlobalUseDirect2D := False;
  GlobalUseDX10 := False;


end.
