{
 ***************************************************************************
 *                                                                         *
 *   This source is free software; you can redistribute it and/or modify   *
 *   it under the terms of the GNU General Public License as published by  *
 *   the Free Software Foundation; either version 2 of the License, or     *
 *   (at your option) any later version.                                   *
 *                                                                         *
 *   This code is distributed in the hope that it will be useful, but      *
 *   WITHOUT ANY WARRANTY; without even the implied warranty of            *
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU     *
 *   General Public License for more details.                              *
 *                                                                         *
 *   A copy of the GNU General Public License is available on the World    *
 *   Wide Web at <http://www.gnu.org/copyleft/gpl.html>. You can also      *
 *   obtain it by writing to the Free Software Foundation,                 *
 *   Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.        *
 *                                                                         *
 ***************************************************************************

  Author: Marius
  Modified by Juha Manninen

  Abstract:
    A dialog to quickly find components and to add the found component
    to the designed form.
}
unit ComponentList;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, LCLType, Forms, Controls, Graphics, StdCtrls, ExtCtrls,
  ComCtrls, ButtonPanel, Buttons, LazarusIDEStrConsts, ComponentReg, PackageDefs,
  FormEditingIntf, TreeFilterEdit, fgl, LCLProc;

type

  TRegisteredCompList = specialize TFPGList<TRegisteredComponent>;

  { TComponentListForm }

  TComponentListForm = class(TForm)
    ListTree: TTreeView;
    ButtonPanel: TButtonPanel;
    OKButton: TPanelBitBtn;
    LabelSearch: TLabel;
    PageControl: TPageControl;
    FilterPanel: TPanel;
    Panel5: TPanel;
    Panel6: TPanel;
    Panel7: TPanel;
    TabSheetInheritance: TTabSheet;
    TabSheetList: TTabSheet;
    TabSheetPaletteTree: TTabSheet;
    InheritanceTree: TTreeView;
    PalletteTree: TTreeView;
    TreeFilterEd: TTreeFilterEdit;
    procedure FormShow(Sender: TObject);
    procedure OKButtonClick(Sender: TObject);
    procedure ComponentsDblClick(Sender: TObject);
    procedure ComponentsClick(Sender: TObject);
    //procedure ComponentsListboxDrawItem(Control: TWinControl; Index: Integer;
    //  ARect: TRect; State: TOwnerDrawState);
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure TreeCustomDrawItem(Sender: TCustomTreeView;
      Node: TTreeNode; State: TCustomDrawState; var DefaultDraw: Boolean);
    procedure TreeFilterEdAfterFilter(Sender: TObject);
    procedure PageControlChange(Sender: TObject);
    procedure TreeKeyPress(Sender: TObject; var Key: char);
    procedure UpdateComponentSelection(Sender: TObject);
    procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
  private
    PrevPageIndex: Integer;
    FComponentList: TRegisteredCompList;
    FKeepSelected: Boolean;
    procedure ClearSelection;
    procedure ComponentWasAdded;
    procedure FindAllLazarusComponents;
    procedure UpdateButtonState;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    function GetSelectedComponent: TRegisteredComponent;
  end;
  
var
  ComponentListForm: TComponentListForm;

implementation

{$R *.lfm}

{ TComponentListForm }

constructor TComponentListForm.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FComponentList := TRegisteredCompList.Create;

  //Translations
  LabelSearch.Caption := lisMenuFind;
  Caption := lisCmpLstComponents;
  TabSheetList.Caption := lisCmpLstList;
  TabSheetPaletteTree.Caption := lisCmpLstPalette;
  TabSheetInheritance.Caption := lisCmpLstInheritance;
  ButtonPanel.OKButton.Caption := lisUseAndClose;

  ListTree.DefaultItemHeight       := ComponentPaletteImageHeight + 1;
  InheritanceTree.DefaultItemHeight:= ComponentPaletteImageHeight + 1;
  PalletteTree.DefaultItemHeight   := ComponentPaletteImageHeight + 1;
  PrevPageIndex := -1;
  PageControl.ActivePage := TabSheetList;
  FindAllLazarusComponents;
  UpdateComponentSelection(nil);
  with ListTree do
    Selected := Items.GetFirstNode;
  TreeFilterEd.InvalidateFilter;
  IDEComponentPalette.AddHandlerComponentAdded(@ComponentWasAdded);
end;

destructor TComponentListForm.Destroy;
begin
  if Assigned(IDEComponentPalette) then
    IDEComponentPalette.RemoveHandlerComponentAdded(@ComponentWasAdded);
  ComponentListForm := nil;
  FreeAndNil(FComponentList);
  inherited Destroy;
end;

procedure TComponentListForm.FormShow(Sender: TObject);
var
  ParentParent: TWinControl;  // Used for checking if the form is anchored.
begin
  ParentParent := Nil;
  if Assigned(Parent) then
    ParentParent := Parent.Parent;
  DebugLn(['*** TComponentListForm.FormShow, Parent=', Parent, ', Parent.Parent=', ParentParent]);
  ButtonPanel.Visible := ParentParent=Nil;
  if ButtonPanel.Visible then begin
    PageControl.AnchorSideBottom.Side := asrTop;
    UpdateButtonState;
  end
  else
    PageControl.AnchorSideBottom.Side := asrBottom;
end;

procedure TComponentListForm.ClearSelection;
begin
  ListTree.Selected := Nil;
  PalletteTree.Selected := Nil;
  InheritanceTree.Selected := Nil;
end;

function TComponentListForm.GetSelectedComponent: TRegisteredComponent;
begin
  Result:=nil;
  if ListTree.IsVisible then
  begin
    if Assigned(ListTree.Selected) then
      Result := TRegisteredComponent(ListTree.Selected.Data);
  end
  else if PalletteTree.IsVisible then
  begin
    if Assigned(PalletteTree.Selected) then
      Result := TRegisteredComponent(PalletteTree.Selected.Data);
  end
  else if InheritanceTree.IsVisible then
  begin
    if Assigned(InheritanceTree.Selected) then
      Result := TRegisteredComponent(InheritanceTree.Selected.Data);
  end;
end;

procedure TComponentListForm.ComponentWasAdded;
begin
  ClearSelection;
  UpdateButtonState;
end;

procedure TComponentListForm.FindAllLazarusComponents;
//Collect all available components (excluding hidden)
var
  AComponent: TRegisteredComponent;
  APage: TBaseComponentPage;
  i, j: Integer;
begin
  if Assigned(IDEComponentPalette) then
  begin
    for i := 0 to IDEComponentPalette.Count-1 do
    begin
      APage := IDEComponentPalette.Pages[i];
      if APage.Visible then
        for j := 0 to APage.Count-1 do
        begin
          AComponent := APage.Comps[j];
          if AComponent.Visible and (AComponent.PageName<>'') then
            FComponentList.Add(AComponent);
        end;
    end;
  end;
end;

procedure TComponentListForm.UpdateButtonState;
begin
  ButtonPanel.OKButton.Enabled := Assigned(GetSelectedComponent);
end;

procedure TComponentListForm.UpdateComponentSelection(Sender: TObject);
// Fill the three tabsheets.
var
  AComponent: TRegisteredComponent;
  AClassName: string;
  AClassList, List: TStringList;
  i, j, AIndex: Integer;
  ANode: TTreeNode;
  AClass: TClass;
begin
  if [csDestroying,csLoading]*ComponentState<>[] then exit;
  Screen.Cursor := crHourGlass;
  try
    //First tabsheet (List)
    ListTree.BeginUpdate;
    try
      ListTree.Items.Clear;
      for i := 0 to FComponentList.Count-1 do
      begin
        AComponent := FComponentList[i];
        AClassName := AComponent.ComponentClass.ClassName;
        ANode := ListTree.Items.AddChildObject(Nil, AClassName, AComponent);
      end;
    finally
      ListTree.EndUpdate;
    end;

    //Second tabsheet (palette layout)
    PalletteTree.BeginUpdate;
    try
      PalletteTree.Items.Clear;
      for i := 0 to FComponentList.Count-1 do
      begin
        AComponent := FComponentList[i];
        AClassName := AComponent.ComponentClass.ClassName;
        //find out parent node
        ANode := PalletteTree.Items.FindTopLvlNode(AComponent.PageName);
        if ANode = nil then
          ANode := PalletteTree.Items.AddChild(nil, AComponent.PageName);
        //add the item
        ANode := PalletteTree.Items.AddChildObject(ANode, AClassName, AComponent);
      end;
      PalletteTree.FullExpand;
    finally
      PalletteTree.EndUpdate;
    end;

    //Third tabsheet (component inheritence)
    List := TStringList.Create;
    AClassList := TStringList.Create;
    InheritanceTree.Items.BeginUpdate;
    try
      InheritanceTree.Items.Clear;
      AClassList.Sorted := true;
      AClassList.CaseSensitive := false;
      AClassList.Duplicates := dupIgnore;
      for i := 0 to FComponentList.Count-1 do
      begin
        AComponent := FComponentList[i];
        AClassName := AComponent.ComponentClass.ClassName;
        // walk down to parent, stop on tcomponent, since components are at least
        // a tcomponent descendant
        List.Clear;
        AClass := AComponent.ComponentClass;
        while (AClass.ClassInfo <> nil) and (AClass.ClassType <> TComponent.ClassType) do
        begin
          List.AddObject(AClass.ClassName, TObject(AClass));
          AClass := AClass.ClassParent;
        end;
        //build the tree
        for j := List.Count - 1 downto 0 do
        begin
          AClass := TClass(List.Objects[j]);
          AClassName := List[j];
          if not AClassList.Find(AClassName, AIndex)
          then begin
            //find out parent position
            if Assigned(AClass.ClassParent) and AClassList.Find(AClass.ClassParent.ClassName, AIndex)
            then ANode := TTreeNode(AClassList.Objects[AIndex])
            else ANode := nil;
            //add the item
            if AClassName <> AComponent.ComponentClass.ClassName
            then ANode := InheritanceTree.Items.AddChild(ANode, AClassName)
            else ANode := InheritanceTree.Items.AddChildObject(ANode, AClassName, AComponent);
            AClassList.AddObject(AClassName, ANode);
          end;
        end;
      end;
      InheritanceTree.AlphaSort;
      InheritanceTree.FullExpand;
    finally
      List.Free;
      AClassList.Free;
      InheritanceTree.Items.EndUpdate;
    end;
    
  finally
    Screen.Cursor := crDefault;
  end;
end;
{
procedure TComponentListForm.ComponentsListboxDrawItem(Control: TWinControl;
  Index: Integer; ARect: TRect; State: TOwnerDrawState);
var
  Comp: TRegisteredComponent;
  CurStr: string;
  CurIcon: TCustomBitmap;
  TxtH, IconWidth, IconHeight: Integer;
begin
  if (Index<0) or (Index>=ComponentsListBox.Items.Count) then exit;
  // draw registered component
  Comp:=TRegisteredComponent(ComponentsListBox.Items.Objects[Index]);
  with ComponentsListBox.Canvas do begin
    CurStr:=Comp.ComponentClass.ClassName;
//  CurStr:=Format(lisPckEditPage,[Comp.ComponentClass.ClassName,Comp.Page.PageName]);
    TxtH:=TextHeight(CurStr);
    FillRect(ARect);
    CurIcon:=nil;
    if Comp is TPkgComponent then
      CurIcon:=TPkgComponent(Comp).Icon;
    if CurIcon<>nil then
    begin
      IconWidth:=CurIcon.Width;
      IconHeight:=CurIcon.Height;
      Draw(ARect.Left+(25-IconWidth) div 2,
           ARect.Top+(ARect.Bottom-ARect.Top-IconHeight) div 2, CurIcon);
    end;
    TextOut(ARect.Left+25,
            ARect.Top+(ARect.Bottom-ARect.Top-TxtH) div 2, CurStr);
  end;
end;
}
procedure TComponentListForm.TreeCustomDrawItem(Sender: TCustomTreeView;
  Node: TTreeNode; State: TCustomDrawState; var DefaultDraw: Boolean);
var
  Comp: TRegisteredComponent;
  ARect: TRect;
  CurIcon: TCustomBitmap;
  Indent, IconWidth, IconHeight: Integer;
begin
  DefaultDraw := False;
  Indent := (Sender as TTreeView).Indent;
  Comp := TRegisteredComponent(Node.Data);
  with Sender.Canvas do
  begin
    if cdsSelected in State then
    begin
      Brush.Color := clHighlight;   //Brush.Style := ...
      Font.Color := clHighlightText;
    end
    else begin
      Brush.Color := clDefault;
      Font.Color := clDefault;
    end;
    ARect := Node.DisplayRect(False);
    FillRect(ARect);
    //Brush.Style := bsClear;     //don't paint over the background bitmap.
    ARect.Left := ARect.Left + (Node.Level * Indent);
    // ARect.Left now points to the left of the image, or text if no image
    CurIcon := nil;
    if Comp is TPkgComponent then
      CurIcon := TPkgComponent(Comp).Icon;
    if CurIcon<>nil then
    begin
      IconWidth := CurIcon.Width;
      IconHeight := CurIcon.Height;
      ARect.Left := ARect.Left + Indent;
      //ARect.Left is now the leftmost portion of the image.
      Draw(ARect.Left+(25-IconWidth) div 2,
           ARect.Top+(ARect.Bottom-ARect.Top-IconHeight) div 2, CurIcon);
      ARect.Left := ARect.Left + IconWidth + 2;
    end;
    //Now we are finally in a position to draw the text.
    TextOut(ARect.Left, ARect.Top, Node.Text);
  end;
end;

procedure TComponentListForm.TreeFilterEdAfterFilter(Sender: TObject);
begin
  UpdateButtonState;
end;

procedure TComponentListForm.ComponentsDblClick(Sender: TObject);
// This is used for all 3 treeviews
begin
  OKButtonClick(nil);       // Select and close this form
end;

procedure TComponentListForm.ComponentsClick(Sender: TObject);
// This is used for all 3 treeviews
var
  AComponent: TRegisteredComponent;
begin
  AComponent:=GetSelectedComponent;
  if AComponent<>nil then
    IDEComponentPalette.Selected:=AComponent;
  UpdateButtonState;
end;

procedure TComponentListForm.TreeKeyPress(Sender: TObject; var Key: char);
// This is used for all 3 treeviews
begin
  if Key = Char(VK_RETURN) then
    ComponentsDblClick(Sender);
end;

procedure TComponentListForm.PageControlChange(Sender: TObject);
begin
  Assert(PageControl.PageIndex <> PrevPageIndex, Format(
    'TComponentListForm.PageControlChange: PageControl.PageIndex = PrevPageIndex = %d',
    [PrevPageIndex]));
  case PageControl.PageIndex of
    0: TreeFilterEd.FilteredTreeview := ListTree;
    1: TreeFilterEd.FilteredTreeview := PalletteTree;
    2: TreeFilterEd.FilteredTreeview := InheritanceTree;
  end;
  TreeFilterEd.InvalidateFilter;
  PrevPageIndex := PageControl.PageIndex;
end;

procedure TComponentListForm.FormClose(Sender: TObject; var CloseAction: TCloseAction);
begin
  if Parent=nil then begin
    ClearSelection;
    if not fKeepSelected then
      IDEComponentPalette.Selected := Nil;
  end
  else begin
    // Using a dock manager...
    CloseAction := caNone;
    //todo: helper function in DockManager or IDEDockMaster for closing forms.
    // Only close the window if it's floating.
    // AnchorDocking doesn't seem to initialize 'FloatingDockSiteClass' so we can't just check 'Floating'.
    // Also, AnchorDocking use nested forms, so the check for HostDockSite.Parent.
    if Assigned(HostDockSite) and (HostDockSite.DockClientCount <= 1)
      and (HostDockSite is TCustomForm) and (HostDockSite.Parent = nil) then
    begin
      TCustomForm(HostDockSite).Close;
    end;
  end;
  FKeepSelected := False;
end;

procedure TComponentListForm.FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
//Close the form on escape key like every other IDE dialog does
begin
  if Key=VK_ESCAPE then
    Close;
end;

procedure TComponentListForm.OKButtonClick(Sender: TObject);
// Select component from palette and close this form. User can insert the component.
var
  AComponent: TRegisteredComponent;
begin
  AComponent := GetSelectedComponent;
  if AComponent<>nil then begin
    IDEComponentPalette.Selected := AComponent;
    FKeepSelected := True;
    Close;
  end;
end;

end.

