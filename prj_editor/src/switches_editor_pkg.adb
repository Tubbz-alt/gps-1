-----------------------------------------------------------------------
--                          G L I D E  I I                           --
--                                                                   --
--                     Copyright (C) 2001-2002                       --
--                            ACT-Europe                             --
--                                                                   --
-- GLIDE is free software; you can redistribute it and/or modify  it --
-- under the terms of the GNU General Public License as published by --
-- the Free Software Foundation; either version 2 of the License, or --
-- (at your option) any later version.                               --
--                                                                   --
-- This program is  distributed in the hope that it will be  useful, --
-- but  WITHOUT ANY WARRANTY;  without even the  implied warranty of --
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU --
-- General Public License for more details. You should have received --
-- a copy of the GNU General Public License along with this library; --
-- if not,  write to the  Free Software Foundation, Inc.,  59 Temple --
-- Place - Suite 330, Boston, MA 02111-1307, USA.                    --
-----------------------------------------------------------------------

pragma Style_Checks (Off);

with Gtk; use Gtk;
with Gtk.Adjustment;  use Gtk.Adjustment;
with Gtk.Widget;      use Gtk.Widget;
with Gtk.Enums;       use Gtk.Enums;
with Gtkada.Handlers; use Gtkada.Handlers;
with Glide_Intl; use Glide_Intl;
with Switches_Editor_Pkg.Callbacks; use Switches_Editor_Pkg.Callbacks;

package body Switches_Editor_Pkg is

procedure Gtk_New (Switches_Editor : out Switches_Editor_Access) is
begin
   Switches_Editor := new Switches_Editor_Record;
   Switches_Editor_Pkg.Initialize (Switches_Editor);
end Gtk_New;

procedure Initialize (Switches_Editor : access Switches_Editor_Record'Class) is
   pragma Suppress (All_Checks);
   Num_Processes_Adj : Gtk_Adjustment;
   Ada_Optimization_Level_Items : String_List.Glist;
   C_Optimization_Level_Items : String_List.Glist;
   Cpp_Optimization_Level_Items : String_List.Glist;
   Pragma_Casing_Items : String_List.Glist;
   References_Casing_Items : String_List.Glist;
   Attribute_Casing_Items : String_List.Glist;
   Keyword_Casing_Items : String_List.Glist;
   Construct_Layout_Items : String_List.Glist;
   Comments_Layout_Items : String_List.Glist;
   Indent_Level_Adj : Gtk_Adjustment;
   Max_Line_Length_Adj : Gtk_Adjustment;
   Vbox27_Group : Widget_SList.GSList;

begin
   Gtk.Window.Initialize (Switches_Editor, Window_Toplevel);
   Set_Title (Switches_Editor, -"Switches");
   Set_Policy (Switches_Editor, False, True, False);
   Set_Position (Switches_Editor, Win_Pos_None);
   Set_Modal (Switches_Editor, False);
   Set_Default_Size (Switches_Editor, 400, 300);

   Gtk_New_Vbox (Switches_Editor.Vbox2, False, 0);
   Add (Switches_Editor, Switches_Editor.Vbox2);

   Gtk_New (Switches_Editor.Notebook);
   Set_Scrollable (Switches_Editor.Notebook, False);
   Set_Show_Border (Switches_Editor.Notebook, True);
   Set_Show_Tabs (Switches_Editor.Notebook, True);
   Set_Tab_Hborder (Switches_Editor.Notebook, 2);
   Set_Tab_Vborder (Switches_Editor.Notebook, 2);
   Set_Tab_Pos (Switches_Editor.Notebook, Pos_Top);
   Pack_Start (Switches_Editor.Vbox2, Switches_Editor.Notebook, True, True, 0);

   Gtk_New (Switches_Editor.Make_Switches, 2, 2, False);
   Set_Row_Spacings (Switches_Editor.Make_Switches, 0);
   Set_Col_Spacings (Switches_Editor.Make_Switches, 0);
   Add (Switches_Editor.Notebook, Switches_Editor.Make_Switches);

   Gtk_New (Switches_Editor.Make_Dep_Frame, -"Dependencies");
   Set_Border_Width (Switches_Editor.Make_Dep_Frame, 5);
   Set_Shadow_Type (Switches_Editor.Make_Dep_Frame, Shadow_Etched_In);
   Attach (Switches_Editor.Make_Switches, Switches_Editor.Make_Dep_Frame, 0, 1, 0, 1,
     Expand or Fill, Expand or Fill,
     0, 0);

   Gtk_New_Vbox (Switches_Editor.Vbox25, False, 0);
   Add (Switches_Editor.Make_Dep_Frame, Switches_Editor.Vbox25);

   Gtk_New (Switches_Editor.Make_All_Files, -"Consider all files");
   Set_Active (Switches_Editor.Make_All_Files, False);
   Pack_Start (Switches_Editor.Vbox25, Switches_Editor.Make_All_Files, False, False, 0);
   Widget_Callback.Object_Connect
     (Switches_Editor.Make_All_Files, "toggled",
      Widget_Callback.To_Marshaller (Refresh_Make_Switches'Access), Switches_Editor);

   Gtk_New (Switches_Editor.Make_Recompile_Switches, -"Recompile if switches changed");
   Set_Active (Switches_Editor.Make_Recompile_Switches, False);
   Pack_Start (Switches_Editor.Vbox25, Switches_Editor.Make_Recompile_Switches, False, False, 0);
   Widget_Callback.Object_Connect
     (Switches_Editor.Make_Recompile_Switches, "toggled",
      Widget_Callback.To_Marshaller (Refresh_Make_Switches'Access), Switches_Editor);

   Gtk_New (Switches_Editor.Make_Minimal_Recompile, -"Minimal recompilation");
   Set_Active (Switches_Editor.Make_Minimal_Recompile, False);
   Pack_Start (Switches_Editor.Vbox25, Switches_Editor.Make_Minimal_Recompile, False, False, 0);
   Widget_Callback.Object_Connect
     (Switches_Editor.Make_Minimal_Recompile, "toggled",
      Widget_Callback.To_Marshaller (Refresh_Make_Switches'Access), Switches_Editor);

   Gtk_New (Switches_Editor.Make_Compile_Frame, -"Compilation");
   Set_Border_Width (Switches_Editor.Make_Compile_Frame, 5);
   Set_Shadow_Type (Switches_Editor.Make_Compile_Frame, Shadow_Etched_In);
   Attach (Switches_Editor.Make_Switches, Switches_Editor.Make_Compile_Frame, 1, 2, 0, 1,
     Expand or Fill, Fill,
     0, 0);

   Gtk_New_Vbox (Switches_Editor.Vbox26, False, 0);
   Add (Switches_Editor.Make_Compile_Frame, Switches_Editor.Vbox26);

   Gtk_New_Hbox (Switches_Editor.Hbox1, False, 0);
   Pack_Start (Switches_Editor.Vbox26, Switches_Editor.Hbox1, False, False, 0);

   Gtk_New (Switches_Editor.Make_Multiprocessing, -"Multiprocessing");
   Set_Active (Switches_Editor.Make_Multiprocessing, False);
   Pack_Start (Switches_Editor.Hbox1, Switches_Editor.Make_Multiprocessing, False, False, 0);
   Widget_Callback.Object_Connect
     (Switches_Editor.Make_Multiprocessing, "toggled",
      Widget_Callback.To_Marshaller (Refresh_Make_Switches'Access), Switches_Editor);

   Gtk_New (Num_Processes_Adj, 1.0, 0.0, 100.0, 1.0, 10.0, 10.0);
   Gtk_New (Switches_Editor.Num_Processes, Num_Processes_Adj, 1.0, 0);
   Set_Numeric (Switches_Editor.Num_Processes, False);
   Set_Snap_To_Ticks (Switches_Editor.Num_Processes, False);
   Set_Update_Policy (Switches_Editor.Num_Processes, Update_Always);
   Set_Value (Switches_Editor.Num_Processes, 1.0);
   Set_Wrap (Switches_Editor.Num_Processes, False);
   Pack_Start (Switches_Editor.Hbox1, Switches_Editor.Num_Processes, True, True, 0);
   Widget_Callback.Object_Connect
     (Switches_Editor.Num_Processes, "changed",
      Widget_Callback.To_Marshaller (Refresh_Make_Switches'Access), Switches_Editor);

   Gtk_New (Switches_Editor.Make_Keep_Going, -"Keep going");
   Set_Active (Switches_Editor.Make_Keep_Going, False);
   Pack_Start (Switches_Editor.Vbox26, Switches_Editor.Make_Keep_Going, False, False, 0);
   Widget_Callback.Object_Connect
     (Switches_Editor.Make_Keep_Going, "toggled",
      Widget_Callback.To_Marshaller (Refresh_Make_Switches'Access), Switches_Editor);

   Gtk_New (Switches_Editor.Make_Debug, -"Debug information");
   Set_Active (Switches_Editor.Make_Debug, False);
   Pack_Start (Switches_Editor.Vbox26, Switches_Editor.Make_Debug, False, False, 0);
   Widget_Callback.Object_Connect
     (Switches_Editor.Make_Debug, "toggled",
      Widget_Callback.To_Marshaller (Refresh_Make_Switches'Access), Switches_Editor);

   Gtk_New (Switches_Editor.Make_Mapping_File, -"Use mapping file");
   Set_Active (Switches_Editor.Make_Mapping_File, False);
   Pack_Start (Switches_Editor.Vbox26, Switches_Editor.Make_Mapping_File, False, False, 0);
   Widget_Callback.Object_Connect
     (Switches_Editor.Make_Mapping_File, "toggled",
      Widget_Callback.To_Marshaller (Refresh_Make_Switches'Access), Switches_Editor);

   Gtk_New (Switches_Editor.Make_Switches_Entry);
   Set_Editable (Switches_Editor.Make_Switches_Entry, True);
   Set_Max_Length (Switches_Editor.Make_Switches_Entry, 0);
   Set_Text (Switches_Editor.Make_Switches_Entry, -"");
   Set_Visibility (Switches_Editor.Make_Switches_Entry, True);
   Attach (Switches_Editor.Make_Switches, Switches_Editor.Make_Switches_Entry, 0, 2, 1, 2,
     Expand or Fill, 0,
     5, 0);
   Widget_Callback.Object_Connect
     (Switches_Editor.Make_Switches_Entry, "changed",
      Widget_Callback.To_Marshaller (On_Make_Switches_Entry_Changed'Access), Switches_Editor);

   Gtk_New (Switches_Editor.Make_Label, -("Make"));
   Set_Alignment (Switches_Editor.Make_Label, 0.5, 0.5);
   Set_Padding (Switches_Editor.Make_Label, 0, 0);
   Set_Justify (Switches_Editor.Make_Label, Justify_Center);
   Set_Line_Wrap (Switches_Editor.Make_Label, False);
   Set_Tab (Switches_Editor.Notebook, 0, Switches_Editor.Make_Label);

   Gtk_New (Switches_Editor.Ada_Switches, 3, 2, False);
   Set_Row_Spacings (Switches_Editor.Ada_Switches, 0);
   Set_Col_Spacings (Switches_Editor.Ada_Switches, 0);
   Add (Switches_Editor.Notebook, Switches_Editor.Ada_Switches);

   Gtk_New (Switches_Editor.Ada_Codegen_Frame, -"Code generation");
   Set_Border_Width (Switches_Editor.Ada_Codegen_Frame, 5);
   Set_Shadow_Type (Switches_Editor.Ada_Codegen_Frame, Shadow_Etched_In);
   Attach (Switches_Editor.Ada_Switches, Switches_Editor.Ada_Codegen_Frame, 0, 1, 0, 1,
     Expand or Fill, Expand or Fill,
     0, 0);

   Gtk_New_Vbox (Switches_Editor.Vbox19, False, 0);
   Add (Switches_Editor.Ada_Codegen_Frame, Switches_Editor.Vbox19);

   Gtk_New (Switches_Editor.Ada_Optimization_Level);
   Set_Case_Sensitive (Switches_Editor.Ada_Optimization_Level, False);
   Set_Use_Arrows (Switches_Editor.Ada_Optimization_Level, True);
   Set_Use_Arrows_Always (Switches_Editor.Ada_Optimization_Level, False);
   String_List.Append (Ada_Optimization_Level_Items, -"No optimization");
   String_List.Append (Ada_Optimization_Level_Items, -"Some optimization");
   String_List.Append (Ada_Optimization_Level_Items, -"Full optimization");
   String_List.Append (Ada_Optimization_Level_Items, -"Full + Automatic inlining");
   Combo.Set_Popdown_Strings (Switches_Editor.Ada_Optimization_Level, Ada_Optimization_Level_Items);
   Free_String_List (Ada_Optimization_Level_Items);
   Pack_Start (Switches_Editor.Vbox19, Switches_Editor.Ada_Optimization_Level, False, False, 0);

   Switches_Editor.Ada_Optimization_Level_Entry := Get_Entry (Switches_Editor.Ada_Optimization_Level);
   Set_Editable (Switches_Editor.Ada_Optimization_Level_Entry, False);
   Set_Max_Length (Switches_Editor.Ada_Optimization_Level_Entry, 0);
   Set_Text (Switches_Editor.Ada_Optimization_Level_Entry, -"No optimization");
   Set_Visibility (Switches_Editor.Ada_Optimization_Level_Entry, True);
   Widget_Callback.Object_Connect
     (Switches_Editor.Ada_Optimization_Level_Entry, "changed",
      Widget_Callback.To_Marshaller (Refresh_Ada_Switches'Access), Switches_Editor);

   Gtk_New (Switches_Editor.Ada_No_Inline, -"No inlining");
   Set_Active (Switches_Editor.Ada_No_Inline, False);
   Pack_Start (Switches_Editor.Vbox19, Switches_Editor.Ada_No_Inline, False, False, 0);
   Widget_Callback.Object_Connect
     (Switches_Editor.Ada_No_Inline, "toggled",
      Widget_Callback.To_Marshaller (Refresh_Ada_Switches'Access), Switches_Editor);

   Gtk_New (Switches_Editor.Ada_Interunit_Inlining, -"Interunit inlining");
   Set_Active (Switches_Editor.Ada_Interunit_Inlining, False);
   Pack_Start (Switches_Editor.Vbox19, Switches_Editor.Ada_Interunit_Inlining, False, False, 0);
   Widget_Callback.Object_Connect
     (Switches_Editor.Ada_Interunit_Inlining, "toggled",
      Widget_Callback.To_Marshaller (Refresh_Ada_Switches'Access), Switches_Editor);

   Gtk_New (Switches_Editor.Ada_Unroll_Loops, -"Unroll loops");
   Set_Active (Switches_Editor.Ada_Unroll_Loops, False);
   Pack_Start (Switches_Editor.Vbox19, Switches_Editor.Ada_Unroll_Loops, False, False, 0);
   Widget_Callback.Object_Connect
     (Switches_Editor.Ada_Unroll_Loops, "toggled",
      Widget_Callback.To_Marshaller (Refresh_Ada_Switches'Access), Switches_Editor);

   Gtk_New (Switches_Editor.Ada_Pic, -"Position independent code");
   Set_Active (Switches_Editor.Ada_Pic, False);
   Pack_Start (Switches_Editor.Vbox19, Switches_Editor.Ada_Pic, False, False, 0);
   Widget_Callback.Object_Connect
     (Switches_Editor.Ada_Pic, "toggled",
      Widget_Callback.To_Marshaller (Refresh_Ada_Switches'Access), Switches_Editor);

   Gtk_New (Switches_Editor.Ada_Code_Coverage, -"Code coverage");
   Set_Active (Switches_Editor.Ada_Code_Coverage, False);
   Pack_Start (Switches_Editor.Vbox19, Switches_Editor.Ada_Code_Coverage, False, False, 0);
   Widget_Callback.Object_Connect
     (Switches_Editor.Ada_Code_Coverage, "toggled",
      Widget_Callback.To_Marshaller (Refresh_Ada_Switches'Access), Switches_Editor);

   Gtk_New (Switches_Editor.Ada_Instrument_Arcs, -"Instrument arcs");
   Set_Active (Switches_Editor.Ada_Instrument_Arcs, False);
   Set_Sensitive (Switches_Editor.Ada_Instrument_Arcs, False);
   Pack_Start (Switches_Editor.Vbox19, Switches_Editor.Ada_Instrument_Arcs, False, False, 0);
   Widget_Callback.Object_Connect
     (Switches_Editor.Ada_Instrument_Arcs, "toggled",
      Widget_Callback.To_Marshaller (Refresh_Ada_Switches'Access), Switches_Editor);

   Gtk_New (Switches_Editor.Frame22, -"Run time checks");
   Set_Border_Width (Switches_Editor.Frame22, 5);
   Set_Shadow_Type (Switches_Editor.Frame22, Shadow_Etched_In);
   Attach (Switches_Editor.Ada_Switches, Switches_Editor.Frame22, 1, 2, 0, 1,
     Expand or Fill, Fill,
     0, 0);

   Gtk_New_Vbox (Switches_Editor.Vbox20, False, 0);
   Add (Switches_Editor.Frame22, Switches_Editor.Vbox20);

   Gtk_New (Switches_Editor.Ada_Overflow_Checking, -"Overflow checking");
   Set_Active (Switches_Editor.Ada_Overflow_Checking, False);
   Pack_Start (Switches_Editor.Vbox20, Switches_Editor.Ada_Overflow_Checking, False, False, 0);
   Widget_Callback.Object_Connect
     (Switches_Editor.Ada_Overflow_Checking, "toggled",
      Widget_Callback.To_Marshaller (Refresh_Ada_Switches'Access), Switches_Editor);

   Gtk_New (Switches_Editor.Ada_Suppress_All_Checks, -"Suppress all checks");
   Set_Active (Switches_Editor.Ada_Suppress_All_Checks, False);
   Pack_Start (Switches_Editor.Vbox20, Switches_Editor.Ada_Suppress_All_Checks, False, False, 0);
   Widget_Callback.Object_Connect
     (Switches_Editor.Ada_Suppress_All_Checks, "toggled",
      Widget_Callback.To_Marshaller (Refresh_Ada_Switches'Access), Switches_Editor);

   Gtk_New (Switches_Editor.Ada_Stack_Checking, -"Stack checking");
   Set_Active (Switches_Editor.Ada_Stack_Checking, False);
   Pack_Start (Switches_Editor.Vbox20, Switches_Editor.Ada_Stack_Checking, False, False, 0);
   Widget_Callback.Object_Connect
     (Switches_Editor.Ada_Stack_Checking, "toggled",
      Widget_Callback.To_Marshaller (Refresh_Ada_Switches'Access), Switches_Editor);

   Gtk_New (Switches_Editor.Ada_Dynamic_Elaboration, -"Dynamic elaboration");
   Set_Active (Switches_Editor.Ada_Dynamic_Elaboration, False);
   Pack_Start (Switches_Editor.Vbox20, Switches_Editor.Ada_Dynamic_Elaboration, False, False, 0);
   Widget_Callback.Object_Connect
     (Switches_Editor.Ada_Dynamic_Elaboration, "toggled",
      Widget_Callback.To_Marshaller (Refresh_Ada_Switches'Access), Switches_Editor);

   Gtk_New (Switches_Editor.Frame23, -"Messages");
   Set_Border_Width (Switches_Editor.Frame23, 5);
   Set_Shadow_Type (Switches_Editor.Frame23, Shadow_Etched_In);
   Attach (Switches_Editor.Ada_Switches, Switches_Editor.Frame23, 0, 1, 1, 2,
     Fill, Expand or Fill,
     0, 0);

   Gtk_New_Vbox (Switches_Editor.Vbox21, False, 0);
   Add (Switches_Editor.Frame23, Switches_Editor.Vbox21);

   Gtk_New (Switches_Editor.Ada_Full_Errors, -"Full errors");
   Set_Active (Switches_Editor.Ada_Full_Errors, False);
   Pack_Start (Switches_Editor.Vbox21, Switches_Editor.Ada_Full_Errors, False, False, 0);
   Widget_Callback.Object_Connect
     (Switches_Editor.Ada_Full_Errors, "toggled",
      Widget_Callback.To_Marshaller (Refresh_Ada_Switches'Access), Switches_Editor);

   Gtk_New (Switches_Editor.Ada_No_Warnings, -"No warning");
   Set_Active (Switches_Editor.Ada_No_Warnings, False);
   Pack_Start (Switches_Editor.Vbox21, Switches_Editor.Ada_No_Warnings, False, False, 0);
   Widget_Callback.Object_Connect
     (Switches_Editor.Ada_No_Warnings, "toggled",
      Widget_Callback.To_Marshaller (Refresh_Ada_Switches'Access), Switches_Editor);

   Gtk_New (Switches_Editor.Ada_Warning_Error, -"Warning=Error");
   Set_Active (Switches_Editor.Ada_Warning_Error, False);
   Pack_Start (Switches_Editor.Vbox21, Switches_Editor.Ada_Warning_Error, False, False, 0);
   Widget_Callback.Object_Connect
     (Switches_Editor.Ada_Warning_Error, "toggled",
      Widget_Callback.To_Marshaller (Refresh_Ada_Switches'Access), Switches_Editor);

   Gtk_New (Switches_Editor.Ada_Elab_Warning, -"Elab warning");
   Set_Active (Switches_Editor.Ada_Elab_Warning, False);
   Pack_Start (Switches_Editor.Vbox21, Switches_Editor.Ada_Elab_Warning, False, False, 0);
   Widget_Callback.Object_Connect
     (Switches_Editor.Ada_Elab_Warning, "toggled",
      Widget_Callback.To_Marshaller (Refresh_Ada_Switches'Access), Switches_Editor);

   Gtk_New (Switches_Editor.Ada_Unused_Warning, -"Unused vars warning");
   Set_Active (Switches_Editor.Ada_Unused_Warning, False);
   Pack_Start (Switches_Editor.Vbox21, Switches_Editor.Ada_Unused_Warning, False, False, 0);
   Widget_Callback.Object_Connect
     (Switches_Editor.Ada_Unused_Warning, "toggled",
      Widget_Callback.To_Marshaller (Refresh_Ada_Switches'Access), Switches_Editor);

   Gtk_New (Switches_Editor.Ada_Style_Checks, -"Style checks");
   Set_Active (Switches_Editor.Ada_Style_Checks, False);
   Pack_Start (Switches_Editor.Vbox21, Switches_Editor.Ada_Style_Checks, False, False, 0);
   Widget_Callback.Object_Connect
     (Switches_Editor.Ada_Style_Checks, "toggled",
      Widget_Callback.To_Marshaller (Refresh_Ada_Switches'Access), Switches_Editor);

   Gtk_New_Vbox (Switches_Editor.Vbox22, False, 0);
   Attach (Switches_Editor.Ada_Switches, Switches_Editor.Vbox22, 1, 2, 1, 2,
     Fill, Fill,
     0, 0);

   Gtk_New (Switches_Editor.Frame24, -"Debugging");
   Set_Border_Width (Switches_Editor.Frame24, 5);
   Set_Shadow_Type (Switches_Editor.Frame24, Shadow_Etched_In);
   Pack_Start (Switches_Editor.Vbox22, Switches_Editor.Frame24, True, True, 0);

   Gtk_New_Vbox (Switches_Editor.Vbox23, False, 0);
   Add (Switches_Editor.Frame24, Switches_Editor.Vbox23);

   Gtk_New (Switches_Editor.Ada_Debug, -"Debug Information");
   Set_Active (Switches_Editor.Ada_Debug, False);
   Pack_Start (Switches_Editor.Vbox23, Switches_Editor.Ada_Debug, False, False, 0);
   Widget_Callback.Object_Connect
     (Switches_Editor.Ada_Debug, "toggled",
      Widget_Callback.To_Marshaller (Refresh_Ada_Switches'Access), Switches_Editor);

   Gtk_New (Switches_Editor.Ada_Assertions, -"Enable assertions");
   Set_Active (Switches_Editor.Ada_Assertions, False);
   Pack_Start (Switches_Editor.Vbox23, Switches_Editor.Ada_Assertions, False, False, 0);
   Widget_Callback.Object_Connect
     (Switches_Editor.Ada_Assertions, "toggled",
      Widget_Callback.To_Marshaller (Refresh_Ada_Switches'Access), Switches_Editor);

   Gtk_New (Switches_Editor.Ada_Debug_Expanded_Code, -"Debug expanded code");
   Set_Active (Switches_Editor.Ada_Debug_Expanded_Code, False);
   Pack_Start (Switches_Editor.Vbox23, Switches_Editor.Ada_Debug_Expanded_Code, False, False, 0);
   Widget_Callback.Object_Connect
     (Switches_Editor.Ada_Debug_Expanded_Code, "toggled",
      Widget_Callback.To_Marshaller (Refresh_Ada_Switches'Access), Switches_Editor);

   Gtk_New (Switches_Editor.Frame25, -"Syntax");
   Set_Border_Width (Switches_Editor.Frame25, 5);
   Set_Shadow_Type (Switches_Editor.Frame25, Shadow_Etched_In);
   Pack_Start (Switches_Editor.Vbox22, Switches_Editor.Frame25, True, True, 0);

   Gtk_New_Vbox (Switches_Editor.Vbox24, False, 0);
   Add (Switches_Editor.Frame25, Switches_Editor.Vbox24);

   Gtk_New (Switches_Editor.Ada_Language_Extensions, -"Language extensions");
   Set_Active (Switches_Editor.Ada_Language_Extensions, False);
   Pack_Start (Switches_Editor.Vbox24, Switches_Editor.Ada_Language_Extensions, False, False, 0);
   Widget_Callback.Object_Connect
     (Switches_Editor.Ada_Language_Extensions, "toggled",
      Widget_Callback.To_Marshaller (Refresh_Ada_Switches'Access), Switches_Editor);

   Gtk_New (Switches_Editor.Ada83_Mode, -"Ada 83 mode");
   Set_Active (Switches_Editor.Ada83_Mode, False);
   Pack_Start (Switches_Editor.Vbox24, Switches_Editor.Ada83_Mode, False, False, 0);
   Widget_Callback.Object_Connect
     (Switches_Editor.Ada83_Mode, "toggled",
      Widget_Callback.To_Marshaller (Refresh_Ada_Switches'Access), Switches_Editor);

   Gtk_New (Switches_Editor.Ada_Switches_Entry);
   Set_Editable (Switches_Editor.Ada_Switches_Entry, True);
   Set_Max_Length (Switches_Editor.Ada_Switches_Entry, 0);
   Set_Text (Switches_Editor.Ada_Switches_Entry, -"");
   Set_Visibility (Switches_Editor.Ada_Switches_Entry, True);
   Attach (Switches_Editor.Ada_Switches, Switches_Editor.Ada_Switches_Entry, 0, 2, 2, 3,
     Expand or Fill, 0,
     0, 0);
   Widget_Callback.Object_Connect
     (Switches_Editor.Ada_Switches_Entry, "changed",
      Widget_Callback.To_Marshaller (On_Ada_Switches_Entry_Changed'Access), Switches_Editor);

   Gtk_New (Switches_Editor.Ada_Label, -("Ada"));
   Set_Alignment (Switches_Editor.Ada_Label, 0.5, 0.5);
   Set_Padding (Switches_Editor.Ada_Label, 0, 0);
   Set_Justify (Switches_Editor.Ada_Label, Justify_Center);
   Set_Line_Wrap (Switches_Editor.Ada_Label, False);
   Set_Tab (Switches_Editor.Notebook, 1, Switches_Editor.Ada_Label);

   Gtk_New (Switches_Editor.C_Switches, 3, 2, False);
   Set_Row_Spacings (Switches_Editor.C_Switches, 0);
   Set_Col_Spacings (Switches_Editor.C_Switches, 0);
   Add (Switches_Editor.Notebook, Switches_Editor.C_Switches);

   Gtk_New (Switches_Editor.Frame41, -"Messages");
   Set_Border_Width (Switches_Editor.Frame41, 5);
   Set_Shadow_Type (Switches_Editor.Frame41, Shadow_Etched_In);
   Attach (Switches_Editor.C_Switches, Switches_Editor.Frame41, 0, 2, 1, 2,
     Fill, Expand or Fill,
     0, 0);

   Gtk_New_Vbox (Switches_Editor.Vbox48, False, 0);
   Add (Switches_Editor.Frame41, Switches_Editor.Vbox48);

   Gtk_New (Switches_Editor.C_All_Warnings, -"All warnings");
   Set_Active (Switches_Editor.C_All_Warnings, False);
   Pack_Start (Switches_Editor.Vbox48, Switches_Editor.C_All_Warnings, False, False, 0);
   Widget_Callback.Object_Connect
     (Switches_Editor.C_All_Warnings, "toggled",
      Widget_Callback.To_Marshaller (Refresh_C_Switches'Access), Switches_Editor);

   Gtk_New (Switches_Editor.C_No_Warnings, -"No warning");
   Set_Active (Switches_Editor.C_No_Warnings, False);
   Pack_Start (Switches_Editor.Vbox48, Switches_Editor.C_No_Warnings, False, False, 0);
   Widget_Callback.Object_Connect
     (Switches_Editor.C_No_Warnings, "toggled",
      Widget_Callback.To_Marshaller (Refresh_C_Switches'Access), Switches_Editor);

   Gtk_New (Switches_Editor.C_Ansi, -"Strict ANSI");
   Set_Active (Switches_Editor.C_Ansi, False);
   Pack_Start (Switches_Editor.Vbox48, Switches_Editor.C_Ansi, False, False, 0);
   Widget_Callback.Object_Connect
     (Switches_Editor.C_Ansi, "toggled",
      Widget_Callback.To_Marshaller (Refresh_C_Switches'Access), Switches_Editor);

   Gtk_New (Switches_Editor.C_Codegen_Frame, -"Code generation");
   Set_Border_Width (Switches_Editor.C_Codegen_Frame, 5);
   Set_Shadow_Type (Switches_Editor.C_Codegen_Frame, Shadow_Etched_In);
   Attach (Switches_Editor.C_Switches, Switches_Editor.C_Codegen_Frame, 0, 1, 0, 1,
     Fill, Expand or Fill,
     0, 0);

   Gtk_New_Vbox (Switches_Editor.Vbox46, False, 0);
   Add (Switches_Editor.C_Codegen_Frame, Switches_Editor.Vbox46);

   Gtk_New (Switches_Editor.C_Optimization_Level);
   Set_Case_Sensitive (Switches_Editor.C_Optimization_Level, False);
   Set_Use_Arrows (Switches_Editor.C_Optimization_Level, True);
   Set_Use_Arrows_Always (Switches_Editor.C_Optimization_Level, False);
   String_List.Append (C_Optimization_Level_Items, -"No optimization");
   String_List.Append (C_Optimization_Level_Items, -"Some optimization");
   String_List.Append (C_Optimization_Level_Items, -"Full optimization");
   String_List.Append (C_Optimization_Level_Items, -"Full + Automatic inlining");
   Combo.Set_Popdown_Strings (Switches_Editor.C_Optimization_Level, C_Optimization_Level_Items);
   Free_String_List (C_Optimization_Level_Items);
   Pack_Start (Switches_Editor.Vbox46, Switches_Editor.C_Optimization_Level, False, False, 0);

   Switches_Editor.C_Optimization_Level_Entry := Get_Entry (Switches_Editor.C_Optimization_Level);
   Set_Editable (Switches_Editor.C_Optimization_Level_Entry, False);
   Set_Max_Length (Switches_Editor.C_Optimization_Level_Entry, 0);
   Set_Text (Switches_Editor.C_Optimization_Level_Entry, -"No optimization");
   Set_Visibility (Switches_Editor.C_Optimization_Level_Entry, True);
   Widget_Callback.Object_Connect
     (Switches_Editor.C_Optimization_Level_Entry, "changed",
      Widget_Callback.To_Marshaller (Refresh_C_Switches'Access), Switches_Editor);

   Gtk_New (Switches_Editor.C_No_Inline, -"No inlining");
   Set_Active (Switches_Editor.C_No_Inline, False);
   Pack_Start (Switches_Editor.Vbox46, Switches_Editor.C_No_Inline, False, False, 0);
   Widget_Callback.Object_Connect
     (Switches_Editor.C_No_Inline, "toggled",
      Widget_Callback.To_Marshaller (Refresh_C_Switches'Access), Switches_Editor);

   Gtk_New (Switches_Editor.C_Unroll_Loops, -"Unroll loops");
   Set_Active (Switches_Editor.C_Unroll_Loops, False);
   Pack_Start (Switches_Editor.Vbox46, Switches_Editor.C_Unroll_Loops, False, False, 0);
   Widget_Callback.Object_Connect
     (Switches_Editor.C_Unroll_Loops, "toggled",
      Widget_Callback.To_Marshaller (Refresh_C_Switches'Access), Switches_Editor);

   Gtk_New (Switches_Editor.C_Pic, -"Position independent code");
   Set_Active (Switches_Editor.C_Pic, False);
   Pack_Start (Switches_Editor.Vbox46, Switches_Editor.C_Pic, False, False, 0);
   Widget_Callback.Object_Connect
     (Switches_Editor.C_Pic, "toggled",
      Widget_Callback.To_Marshaller (Refresh_C_Switches'Access), Switches_Editor);

   Gtk_New (Switches_Editor.C_Profile, -"Profiling");
   Set_Active (Switches_Editor.C_Profile, False);
   Pack_Start (Switches_Editor.Vbox46, Switches_Editor.C_Profile, False, False, 0);
   Widget_Callback.Object_Connect
     (Switches_Editor.C_Profile, "toggled",
      Widget_Callback.To_Marshaller (Refresh_C_Switches'Access), Switches_Editor);

   Gtk_New (Switches_Editor.C_Code_Coverage, -"Code coverage");
   Set_Active (Switches_Editor.C_Code_Coverage, False);
   Pack_Start (Switches_Editor.Vbox46, Switches_Editor.C_Code_Coverage, False, False, 0);
   Widget_Callback.Object_Connect
     (Switches_Editor.C_Code_Coverage, "toggled",
      Widget_Callback.To_Marshaller (Refresh_C_Switches'Access), Switches_Editor);

   Gtk_New (Switches_Editor.C_Instrument_Arcs, -"Instrument arcs");
   Set_Active (Switches_Editor.C_Instrument_Arcs, False);
   Set_Sensitive (Switches_Editor.C_Instrument_Arcs, False);
   Pack_Start (Switches_Editor.Vbox46, Switches_Editor.C_Instrument_Arcs, False, False, 0);
   Widget_Callback.Object_Connect
     (Switches_Editor.C_Instrument_Arcs, "toggled",
      Widget_Callback.To_Marshaller (Refresh_C_Switches'Access), Switches_Editor);

   Gtk_New (Switches_Editor.Frame44, -"Debugging");
   Set_Border_Width (Switches_Editor.Frame44, 5);
   Set_Shadow_Type (Switches_Editor.Frame44, Shadow_Etched_In);
   Attach (Switches_Editor.C_Switches, Switches_Editor.Frame44, 1, 2, 0, 1,
     Fill, Fill,
     0, 0);

   Gtk_New_Vbox (Switches_Editor.Vbox51, False, 0);
   Add (Switches_Editor.Frame44, Switches_Editor.Vbox51);

   Gtk_New (Switches_Editor.C_Debug, -"Debug information");
   Set_Active (Switches_Editor.C_Debug, False);
   Pack_Start (Switches_Editor.Vbox51, Switches_Editor.C_Debug, False, False, 0);
   Widget_Callback.Object_Connect
     (Switches_Editor.C_Debug, "toggled",
      Widget_Callback.To_Marshaller (Refresh_C_Switches'Access), Switches_Editor);

   Gtk_New (Switches_Editor.C_Switches_Entry);
   Set_Editable (Switches_Editor.C_Switches_Entry, True);
   Set_Max_Length (Switches_Editor.C_Switches_Entry, 0);
   Set_Text (Switches_Editor.C_Switches_Entry, -"");
   Set_Visibility (Switches_Editor.C_Switches_Entry, True);
   Attach (Switches_Editor.C_Switches, Switches_Editor.C_Switches_Entry, 0, 2, 2, 3,
     Expand or Fill, 0,
     0, 0);
   Widget_Callback.Object_Connect
     (Switches_Editor.C_Switches_Entry, "changed",
      Widget_Callback.To_Marshaller (On_C_Switches_Entry_Changed'Access), Switches_Editor);

   Gtk_New (Switches_Editor.C_Label, -("C"));
   Set_Alignment (Switches_Editor.C_Label, 0.5, 0.5);
   Set_Padding (Switches_Editor.C_Label, 0, 0);
   Set_Justify (Switches_Editor.C_Label, Justify_Center);
   Set_Line_Wrap (Switches_Editor.C_Label, False);
   Set_Tab (Switches_Editor.Notebook, 2, Switches_Editor.C_Label);

   Gtk_New (Switches_Editor.Cpp_Switches, 3, 2, False);
   Set_Row_Spacings (Switches_Editor.Cpp_Switches, 0);
   Set_Col_Spacings (Switches_Editor.Cpp_Switches, 0);
   Add (Switches_Editor.Notebook, Switches_Editor.Cpp_Switches);

   Gtk_New (Switches_Editor.Frame43, -"Messages");
   Set_Border_Width (Switches_Editor.Frame43, 5);
   Set_Shadow_Type (Switches_Editor.Frame43, Shadow_Etched_In);
   Attach (Switches_Editor.Cpp_Switches, Switches_Editor.Frame43, 0, 2, 1, 2,
     Fill, Expand or Fill,
     0, 0);

   Gtk_New_Vbox (Switches_Editor.Vbox50, False, 0);
   Add (Switches_Editor.Frame43, Switches_Editor.Vbox50);

   Gtk_New (Switches_Editor.Cpp_All_Warnings, -"All warnings");
   Set_Active (Switches_Editor.Cpp_All_Warnings, False);
   Pack_Start (Switches_Editor.Vbox50, Switches_Editor.Cpp_All_Warnings, False, False, 0);
   Widget_Callback.Object_Connect
     (Switches_Editor.Cpp_All_Warnings, "toggled",
      Widget_Callback.To_Marshaller (Refresh_Cpp_Switches'Access), Switches_Editor);

   Gtk_New (Switches_Editor.Cpp_No_Warnings, -"No warning");
   Set_Active (Switches_Editor.Cpp_No_Warnings, False);
   Pack_Start (Switches_Editor.Vbox50, Switches_Editor.Cpp_No_Warnings, False, False, 0);
   Widget_Callback.Object_Connect
     (Switches_Editor.Cpp_No_Warnings, "toggled",
      Widget_Callback.To_Marshaller (Refresh_Cpp_Switches'Access), Switches_Editor);

   Gtk_New (Switches_Editor.Cpp_Overloaded_Virtual, -"Overloaded virtual");
   Set_Active (Switches_Editor.Cpp_Overloaded_Virtual, False);
   Pack_Start (Switches_Editor.Vbox50, Switches_Editor.Cpp_Overloaded_Virtual, False, False, 0);
   Widget_Callback.Object_Connect
     (Switches_Editor.Cpp_Overloaded_Virtual, "toggled",
      Widget_Callback.To_Marshaller (Refresh_Cpp_Switches'Access), Switches_Editor);

   Gtk_New (Switches_Editor.Cpp_Switches_Entry);
   Set_Editable (Switches_Editor.Cpp_Switches_Entry, True);
   Set_Max_Length (Switches_Editor.Cpp_Switches_Entry, 0);
   Set_Text (Switches_Editor.Cpp_Switches_Entry, -"");
   Set_Visibility (Switches_Editor.Cpp_Switches_Entry, True);
   Attach (Switches_Editor.Cpp_Switches, Switches_Editor.Cpp_Switches_Entry, 0, 2, 2, 3,
     Expand or Fill, 0,
     0, 0);
   Widget_Callback.Object_Connect
     (Switches_Editor.Cpp_Switches_Entry, "changed",
      Widget_Callback.To_Marshaller (On_Cpp_Switches_Entry_Changed'Access), Switches_Editor);

   Gtk_New (Switches_Editor.Cpp_Codegen_Frame, -"Code generation");
   Set_Border_Width (Switches_Editor.Cpp_Codegen_Frame, 5);
   Set_Shadow_Type (Switches_Editor.Cpp_Codegen_Frame, Shadow_Etched_In);
   Attach (Switches_Editor.Cpp_Switches, Switches_Editor.Cpp_Codegen_Frame, 0, 1, 0, 1,
     Fill, Expand or Fill,
     0, 0);

   Gtk_New_Vbox (Switches_Editor.Vbox49, False, 0);
   Add (Switches_Editor.Cpp_Codegen_Frame, Switches_Editor.Vbox49);

   Gtk_New (Switches_Editor.Cpp_Optimization_Level);
   Set_Case_Sensitive (Switches_Editor.Cpp_Optimization_Level, False);
   Set_Use_Arrows (Switches_Editor.Cpp_Optimization_Level, True);
   Set_Use_Arrows_Always (Switches_Editor.Cpp_Optimization_Level, False);
   String_List.Append (Cpp_Optimization_Level_Items, -"No optimization");
   String_List.Append (Cpp_Optimization_Level_Items, -"Some optimization");
   String_List.Append (Cpp_Optimization_Level_Items, -"Full optimization");
   String_List.Append (Cpp_Optimization_Level_Items, -"Full + Automatic inlining");
   Combo.Set_Popdown_Strings (Switches_Editor.Cpp_Optimization_Level, Cpp_Optimization_Level_Items);
   Free_String_List (Cpp_Optimization_Level_Items);
   Pack_Start (Switches_Editor.Vbox49, Switches_Editor.Cpp_Optimization_Level, False, False, 0);

   Switches_Editor.Cpp_Optimization_Level_Entry := Get_Entry (Switches_Editor.Cpp_Optimization_Level);
   Set_Editable (Switches_Editor.Cpp_Optimization_Level_Entry, False);
   Set_Max_Length (Switches_Editor.Cpp_Optimization_Level_Entry, 0);
   Set_Text (Switches_Editor.Cpp_Optimization_Level_Entry, -"No optimization");
   Set_Visibility (Switches_Editor.Cpp_Optimization_Level_Entry, True);
   Widget_Callback.Object_Connect
     (Switches_Editor.Cpp_Optimization_Level_Entry, "changed",
      Widget_Callback.To_Marshaller (Refresh_Cpp_Switches'Access), Switches_Editor);

   Gtk_New (Switches_Editor.Cpp_No_Inline, -"No inlining");
   Set_Active (Switches_Editor.Cpp_No_Inline, False);
   Pack_Start (Switches_Editor.Vbox49, Switches_Editor.Cpp_No_Inline, False, False, 0);
   Widget_Callback.Object_Connect
     (Switches_Editor.Cpp_No_Inline, "toggled",
      Widget_Callback.To_Marshaller (Refresh_Cpp_Switches'Access), Switches_Editor);

   Gtk_New (Switches_Editor.Cpp_Unroll_Loops, -"Unroll loops");
   Set_Active (Switches_Editor.Cpp_Unroll_Loops, False);
   Pack_Start (Switches_Editor.Vbox49, Switches_Editor.Cpp_Unroll_Loops, False, False, 0);
   Widget_Callback.Object_Connect
     (Switches_Editor.Cpp_Unroll_Loops, "toggled",
      Widget_Callback.To_Marshaller (Refresh_Cpp_Switches'Access), Switches_Editor);

   Gtk_New (Switches_Editor.Cpp_Pic, -"Position independent code");
   Set_Active (Switches_Editor.Cpp_Pic, False);
   Pack_Start (Switches_Editor.Vbox49, Switches_Editor.Cpp_Pic, False, False, 0);
   Widget_Callback.Object_Connect
     (Switches_Editor.Cpp_Pic, "toggled",
      Widget_Callback.To_Marshaller (Refresh_Cpp_Switches'Access), Switches_Editor);

   Gtk_New (Switches_Editor.Cpp_Profile, -"Profiling");
   Set_Active (Switches_Editor.Cpp_Profile, False);
   Pack_Start (Switches_Editor.Vbox49, Switches_Editor.Cpp_Profile, False, False, 0);
   Widget_Callback.Object_Connect
     (Switches_Editor.Cpp_Profile, "toggled",
      Widget_Callback.To_Marshaller (Refresh_Cpp_Switches'Access), Switches_Editor);

   Gtk_New (Switches_Editor.Cpp_Code_Coverage, -"Code coverage");
   Set_Active (Switches_Editor.Cpp_Code_Coverage, False);
   Pack_Start (Switches_Editor.Vbox49, Switches_Editor.Cpp_Code_Coverage, False, False, 0);
   Widget_Callback.Object_Connect
     (Switches_Editor.Cpp_Code_Coverage, "toggled",
      Widget_Callback.To_Marshaller (Refresh_Cpp_Switches'Access), Switches_Editor);

   Gtk_New (Switches_Editor.Cpp_Instrument_Arcs, -"Instrument arcs");
   Set_Active (Switches_Editor.Cpp_Instrument_Arcs, False);
   Set_Sensitive (Switches_Editor.Cpp_Instrument_Arcs, False);
   Pack_Start (Switches_Editor.Vbox49, Switches_Editor.Cpp_Instrument_Arcs, False, False, 0);
   Widget_Callback.Object_Connect
     (Switches_Editor.Cpp_Instrument_Arcs, "toggled",
      Widget_Callback.To_Marshaller (Refresh_Cpp_Switches'Access), Switches_Editor);

   Gtk_New (Switches_Editor.Cpp_Exceptions, -"Exceptions support");
   Set_Active (Switches_Editor.Cpp_Exceptions, False);
   Pack_Start (Switches_Editor.Vbox49, Switches_Editor.Cpp_Exceptions, False, False, 0);
   Widget_Callback.Object_Connect
     (Switches_Editor.Cpp_Exceptions, "toggled",
      Widget_Callback.To_Marshaller (Refresh_Cpp_Switches'Access), Switches_Editor);

   Gtk_New (Switches_Editor.Cpp_Elide_Constructor, -"Elide constructor");
   Set_Active (Switches_Editor.Cpp_Elide_Constructor, False);
   Pack_Start (Switches_Editor.Vbox49, Switches_Editor.Cpp_Elide_Constructor, False, False, 0);
   Widget_Callback.Object_Connect
     (Switches_Editor.Cpp_Elide_Constructor, "toggled",
      Widget_Callback.To_Marshaller (Refresh_Cpp_Switches'Access), Switches_Editor);

   Gtk_New (Switches_Editor.Cpp_Conserve_Space, -"Conserve space");
   Set_Active (Switches_Editor.Cpp_Conserve_Space, False);
   Pack_Start (Switches_Editor.Vbox49, Switches_Editor.Cpp_Conserve_Space, False, False, 0);
   Widget_Callback.Object_Connect
     (Switches_Editor.Cpp_Conserve_Space, "toggled",
      Widget_Callback.To_Marshaller (Refresh_Cpp_Switches'Access), Switches_Editor);

   Gtk_New (Switches_Editor.Frame45, -"Debugging");
   Set_Border_Width (Switches_Editor.Frame45, 5);
   Set_Shadow_Type (Switches_Editor.Frame45, Shadow_Etched_In);
   Attach (Switches_Editor.Cpp_Switches, Switches_Editor.Frame45, 1, 2, 0, 1,
     Fill, Fill,
     0, 0);

   Gtk_New_Vbox (Switches_Editor.Vbox52, False, 0);
   Add (Switches_Editor.Frame45, Switches_Editor.Vbox52);

   Gtk_New (Switches_Editor.Cpp_Debug, -"Debug information");
   Set_Active (Switches_Editor.Cpp_Debug, False);
   Pack_Start (Switches_Editor.Vbox52, Switches_Editor.Cpp_Debug, False, False, 0);
   Widget_Callback.Object_Connect
     (Switches_Editor.Cpp_Debug, "toggled",
      Widget_Callback.To_Marshaller (Refresh_Cpp_Switches'Access), Switches_Editor);

   Gtk_New (Switches_Editor.Cpp_Label, -("C++"));
   Set_Alignment (Switches_Editor.Cpp_Label, 0.5, 0.5);
   Set_Padding (Switches_Editor.Cpp_Label, 0, 0);
   Set_Justify (Switches_Editor.Cpp_Label, Justify_Center);
   Set_Line_Wrap (Switches_Editor.Cpp_Label, False);
   Set_Tab (Switches_Editor.Notebook, 3, Switches_Editor.Cpp_Label);

   Gtk_New (Switches_Editor.Pp_Switches, 6, 2, False);
   Set_Row_Spacings (Switches_Editor.Pp_Switches, 0);
   Set_Col_Spacings (Switches_Editor.Pp_Switches, 0);
   Add (Switches_Editor.Notebook, Switches_Editor.Pp_Switches);

   Gtk_New (Switches_Editor.Pp_Switches_Entry);
   Set_Editable (Switches_Editor.Pp_Switches_Entry, True);
   Set_Max_Length (Switches_Editor.Pp_Switches_Entry, 0);
   Set_Text (Switches_Editor.Pp_Switches_Entry, -"");
   Set_Visibility (Switches_Editor.Pp_Switches_Entry, True);
   Attach (Switches_Editor.Pp_Switches, Switches_Editor.Pp_Switches_Entry, 0, 2, 5, 6,
     Expand or Fill, 0,
     0, 0);
   Widget_Callback.Object_Connect
     (Switches_Editor.Pp_Switches_Entry, "changed",
      Widget_Callback.To_Marshaller (On_Pp_Switches_Entry_Changed'Access), Switches_Editor);

   Gtk_New (Switches_Editor.Pp_Align_Frame, -"Alignments");
   Set_Border_Width (Switches_Editor.Pp_Align_Frame, 5);
   Set_Shadow_Type (Switches_Editor.Pp_Align_Frame, Shadow_Etched_In);
   Attach (Switches_Editor.Pp_Switches, Switches_Editor.Pp_Align_Frame, 0, 2, 3, 4,
     Fill, Expand or Fill,
     0, 0);

   Gtk_New_Vbox (Switches_Editor.Vbox55, False, 0);
   Add (Switches_Editor.Pp_Align_Frame, Switches_Editor.Vbox55);

   Gtk_New (Switches_Editor.Align_Colons, -"Colons in declarations");
   Set_Active (Switches_Editor.Align_Colons, False);
   Pack_Start (Switches_Editor.Vbox55, Switches_Editor.Align_Colons, False, False, 0);
   Widget_Callback.Object_Connect
     (Switches_Editor.Align_Colons, "toggled",
      Widget_Callback.To_Marshaller (Refresh_Pp_Switches'Access), Switches_Editor);

   Gtk_New (Switches_Editor.Align_Assign_Decl, -"Assignments in declarations");
   Set_Active (Switches_Editor.Align_Assign_Decl, False);
   Pack_Start (Switches_Editor.Vbox55, Switches_Editor.Align_Assign_Decl, False, False, 0);
   Widget_Callback.Object_Connect
     (Switches_Editor.Align_Assign_Decl, "toggled",
      Widget_Callback.To_Marshaller (Refresh_Pp_Switches'Access), Switches_Editor);

   Gtk_New (Switches_Editor.Align_Assign_Stmt, -"Assignments in statements");
   Set_Active (Switches_Editor.Align_Assign_Stmt, False);
   Pack_Start (Switches_Editor.Vbox55, Switches_Editor.Align_Assign_Stmt, False, False, 0);
   Widget_Callback.Object_Connect
     (Switches_Editor.Align_Assign_Stmt, "toggled",
      Widget_Callback.To_Marshaller (Refresh_Pp_Switches'Access), Switches_Editor);

   Gtk_New (Switches_Editor.Align_Arrow, -"Arrow delimiters in associations");
   Set_Active (Switches_Editor.Align_Arrow, False);
   Pack_Start (Switches_Editor.Vbox55, Switches_Editor.Align_Arrow, False, False, 0);
   Widget_Callback.Object_Connect
     (Switches_Editor.Align_Arrow, "toggled",
      Widget_Callback.To_Marshaller (Refresh_Pp_Switches'Access), Switches_Editor);

   Gtk_New (Switches_Editor.Set_Labels, -"Set missing end/exit labels");
   Set_Border_Width (Switches_Editor.Set_Labels, 3);
   Set_Active (Switches_Editor.Set_Labels, True);
   Attach (Switches_Editor.Pp_Switches, Switches_Editor.Set_Labels, 0, 2, 4, 5,
     Fill, 0,
     0, 0);
   Widget_Callback.Object_Connect
     (Switches_Editor.Set_Labels, "toggled",
      Widget_Callback.To_Marshaller (Refresh_Pp_Switches'Access), Switches_Editor);

   Gtk_New (Switches_Editor.Pp_Casing_Frame, -"Casing");
   Set_Border_Width (Switches_Editor.Pp_Casing_Frame, 5);
   Set_Shadow_Type (Switches_Editor.Pp_Casing_Frame, Shadow_Etched_In);
   Attach (Switches_Editor.Pp_Switches, Switches_Editor.Pp_Casing_Frame, 0, 2, 1, 2,
     Fill, Expand or Fill,
     0, 0);

   Gtk_New (Switches_Editor.Pp_Casing_Table, 4, 2, False);
   Set_Row_Spacings (Switches_Editor.Pp_Casing_Table, 0);
   Set_Col_Spacings (Switches_Editor.Pp_Casing_Table, 0);
   Add (Switches_Editor.Pp_Casing_Frame, Switches_Editor.Pp_Casing_Table);

   Gtk_New (Switches_Editor.Pragma_Casing);
   Set_Case_Sensitive (Switches_Editor.Pragma_Casing, False);
   Set_Use_Arrows (Switches_Editor.Pragma_Casing, True);
   Set_Use_Arrows_Always (Switches_Editor.Pragma_Casing, False);
   String_List.Append (Pragma_Casing_Items, -"Mixed case");
   String_List.Append (Pragma_Casing_Items, -"Lower case");
   String_List.Append (Pragma_Casing_Items, -"Upper case");
   Combo.Set_Popdown_Strings (Switches_Editor.Pragma_Casing, Pragma_Casing_Items);
   Free_String_List (Pragma_Casing_Items);
   Attach (Switches_Editor.Pp_Casing_Table, Switches_Editor.Pragma_Casing, 1, 2, 3, 4,
     Expand or Fill, 0,
     0, 0);

   Switches_Editor.Pragma_Casing_Entry := Get_Entry (Switches_Editor.Pragma_Casing);
   Set_Editable (Switches_Editor.Pragma_Casing_Entry, True);
   Set_Max_Length (Switches_Editor.Pragma_Casing_Entry, 0);
   Set_Text (Switches_Editor.Pragma_Casing_Entry, -"Mixed case");
   Set_Visibility (Switches_Editor.Pragma_Casing_Entry, True);
   Widget_Callback.Object_Connect
     (Switches_Editor.Pragma_Casing_Entry, "changed",
      Widget_Callback.To_Marshaller (Refresh_Pp_Switches'Access), Switches_Editor);

   Gtk_New (Switches_Editor.References_Casing);
   Set_Case_Sensitive (Switches_Editor.References_Casing, False);
   Set_Use_Arrows (Switches_Editor.References_Casing, True);
   Set_Use_Arrows_Always (Switches_Editor.References_Casing, False);
   String_List.Append (References_Casing_Items, -"As declared");
   String_List.Append (References_Casing_Items, -"Mixed case");
   Combo.Set_Popdown_Strings (Switches_Editor.References_Casing, References_Casing_Items);
   Free_String_List (References_Casing_Items);
   Attach (Switches_Editor.Pp_Casing_Table, Switches_Editor.References_Casing, 1, 2, 2, 3,
     Expand or Fill, 0,
     0, 0);

   Switches_Editor.References_Casing_Entry := Get_Entry (Switches_Editor.References_Casing);
   Set_Editable (Switches_Editor.References_Casing_Entry, True);
   Set_Max_Length (Switches_Editor.References_Casing_Entry, 0);
   Set_Text (Switches_Editor.References_Casing_Entry, -"As declared");
   Set_Visibility (Switches_Editor.References_Casing_Entry, True);
   Widget_Callback.Object_Connect
     (Switches_Editor.References_Casing_Entry, "changed",
      Widget_Callback.To_Marshaller (Refresh_Pp_Switches'Access), Switches_Editor);

   Gtk_New (Switches_Editor.Attribute_Casing);
   Set_Case_Sensitive (Switches_Editor.Attribute_Casing, False);
   Set_Use_Arrows (Switches_Editor.Attribute_Casing, True);
   Set_Use_Arrows_Always (Switches_Editor.Attribute_Casing, False);
   String_List.Append (Attribute_Casing_Items, -"Mixed case");
   String_List.Append (Attribute_Casing_Items, -"Lower case");
   String_List.Append (Attribute_Casing_Items, -"Upper case");
   Combo.Set_Popdown_Strings (Switches_Editor.Attribute_Casing, Attribute_Casing_Items);
   Free_String_List (Attribute_Casing_Items);
   Attach (Switches_Editor.Pp_Casing_Table, Switches_Editor.Attribute_Casing, 1, 2, 1, 2,
     Expand or Fill, 0,
     0, 0);

   Switches_Editor.Attribute_Casing_Entry := Get_Entry (Switches_Editor.Attribute_Casing);
   Set_Editable (Switches_Editor.Attribute_Casing_Entry, True);
   Set_Max_Length (Switches_Editor.Attribute_Casing_Entry, 0);
   Set_Text (Switches_Editor.Attribute_Casing_Entry, -"Mixed case");
   Set_Visibility (Switches_Editor.Attribute_Casing_Entry, True);
   Widget_Callback.Object_Connect
     (Switches_Editor.Attribute_Casing_Entry, "changed",
      Widget_Callback.To_Marshaller (Refresh_Pp_Switches'Access), Switches_Editor);

   Gtk_New (Switches_Editor.Keyword_Casing);
   Set_Case_Sensitive (Switches_Editor.Keyword_Casing, False);
   Set_Use_Arrows (Switches_Editor.Keyword_Casing, True);
   Set_Use_Arrows_Always (Switches_Editor.Keyword_Casing, False);
   String_List.Append (Keyword_Casing_Items, -"Lower case");
   String_List.Append (Keyword_Casing_Items, -"Upper case");
   Combo.Set_Popdown_Strings (Switches_Editor.Keyword_Casing, Keyword_Casing_Items);
   Free_String_List (Keyword_Casing_Items);
   Attach (Switches_Editor.Pp_Casing_Table, Switches_Editor.Keyword_Casing, 1, 2, 0, 1,
     Expand or Fill, 0,
     0, 0);

   Switches_Editor.Keyword_Casing_Entry := Get_Entry (Switches_Editor.Keyword_Casing);
   Set_Editable (Switches_Editor.Keyword_Casing_Entry, True);
   Set_Max_Length (Switches_Editor.Keyword_Casing_Entry, 0);
   Set_Text (Switches_Editor.Keyword_Casing_Entry, -"Lower case");
   Set_Visibility (Switches_Editor.Keyword_Casing_Entry, True);
   Widget_Callback.Object_Connect
     (Switches_Editor.Keyword_Casing_Entry, "changed",
      Widget_Callback.To_Marshaller (Refresh_Pp_Switches'Access), Switches_Editor);

   Gtk_New (Switches_Editor.Label67, -("Keyword:"));
   Set_Alignment (Switches_Editor.Label67, 0.0, 0.5);
   Set_Padding (Switches_Editor.Label67, 5, 0);
   Set_Justify (Switches_Editor.Label67, Justify_Center);
   Set_Line_Wrap (Switches_Editor.Label67, False);
   Attach (Switches_Editor.Pp_Casing_Table, Switches_Editor.Label67, 0, 1, 0, 1,
     Fill, 0,
     0, 0);

   Gtk_New (Switches_Editor.Label68, -("Attribute:"));
   Set_Alignment (Switches_Editor.Label68, 0.0, 0.5);
   Set_Padding (Switches_Editor.Label68, 5, 0);
   Set_Justify (Switches_Editor.Label68, Justify_Center);
   Set_Line_Wrap (Switches_Editor.Label68, False);
   Attach (Switches_Editor.Pp_Casing_Table, Switches_Editor.Label68, 0, 1, 1, 2,
     Fill, 0,
     0, 0);

   Gtk_New (Switches_Editor.Label69, -("Reference:"));
   Set_Alignment (Switches_Editor.Label69, 0.0, 0.5);
   Set_Padding (Switches_Editor.Label69, 5, 0);
   Set_Justify (Switches_Editor.Label69, Justify_Center);
   Set_Line_Wrap (Switches_Editor.Label69, False);
   Attach (Switches_Editor.Pp_Casing_Table, Switches_Editor.Label69, 0, 1, 2, 3,
     Fill, 0,
     0, 0);

   Gtk_New (Switches_Editor.Label70, -("Pragma:"));
   Set_Alignment (Switches_Editor.Label70, 0.0, 0.5);
   Set_Padding (Switches_Editor.Label70, 5, 0);
   Set_Justify (Switches_Editor.Label70, Justify_Center);
   Set_Line_Wrap (Switches_Editor.Label70, False);
   Attach (Switches_Editor.Pp_Casing_Table, Switches_Editor.Label70, 0, 1, 3, 4,
     Fill, 0,
     0, 0);

   Gtk_New (Switches_Editor.Pp_Layout_Frame, -"Layout");
   Set_Border_Width (Switches_Editor.Pp_Layout_Frame, 5);
   Set_Shadow_Type (Switches_Editor.Pp_Layout_Frame, Shadow_Etched_In);
   Attach (Switches_Editor.Pp_Switches, Switches_Editor.Pp_Layout_Frame, 0, 2, 2, 3,
     Fill, Expand or Fill,
     0, 0);

   Gtk_New (Switches_Editor.Pp_Layout_Table, 2, 2, False);
   Set_Row_Spacings (Switches_Editor.Pp_Layout_Table, 0);
   Set_Col_Spacings (Switches_Editor.Pp_Layout_Table, 0);
   Add (Switches_Editor.Pp_Layout_Frame, Switches_Editor.Pp_Layout_Table);

   Gtk_New (Switches_Editor.Label65, -("Construct:"));
   Set_Alignment (Switches_Editor.Label65, 0.0, 0.5);
   Set_Padding (Switches_Editor.Label65, 5, 0);
   Set_Justify (Switches_Editor.Label65, Justify_Center);
   Set_Line_Wrap (Switches_Editor.Label65, False);
   Attach (Switches_Editor.Pp_Layout_Table, Switches_Editor.Label65, 0, 1, 0, 1,
     Fill, 0,
     0, 0);

   Gtk_New (Switches_Editor.Label66, -("Comment:"));
   Set_Alignment (Switches_Editor.Label66, 0.0, 0.5);
   Set_Padding (Switches_Editor.Label66, 5, 0);
   Set_Justify (Switches_Editor.Label66, Justify_Center);
   Set_Line_Wrap (Switches_Editor.Label66, False);
   Attach (Switches_Editor.Pp_Layout_Table, Switches_Editor.Label66, 0, 1, 1, 2,
     Fill, 0,
     0, 0);

   Gtk_New (Switches_Editor.Construct_Layout);
   Set_Case_Sensitive (Switches_Editor.Construct_Layout, False);
   Set_Use_Arrows (Switches_Editor.Construct_Layout, True);
   Set_Use_Arrows_Always (Switches_Editor.Construct_Layout, False);
   String_List.Append (Construct_Layout_Items, -"GNAT style");
   String_List.Append (Construct_Layout_Items, -"Compact");
   String_List.Append (Construct_Layout_Items, -"Uncompact");
   Combo.Set_Popdown_Strings (Switches_Editor.Construct_Layout, Construct_Layout_Items);
   Free_String_List (Construct_Layout_Items);
   Attach (Switches_Editor.Pp_Layout_Table, Switches_Editor.Construct_Layout, 1, 2, 0, 1,
     Expand or Fill, 0,
     0, 0);

   Switches_Editor.Construct_Layout_Entry := Get_Entry (Switches_Editor.Construct_Layout);
   Set_Editable (Switches_Editor.Construct_Layout_Entry, True);
   Set_Max_Length (Switches_Editor.Construct_Layout_Entry, 0);
   Set_Text (Switches_Editor.Construct_Layout_Entry, -"GNAT style");
   Set_Visibility (Switches_Editor.Construct_Layout_Entry, True);
   Widget_Callback.Object_Connect
     (Switches_Editor.Construct_Layout_Entry, "changed",
      Widget_Callback.To_Marshaller (Refresh_Pp_Switches'Access), Switches_Editor);

   Gtk_New (Switches_Editor.Comments_Layout);
   Set_Case_Sensitive (Switches_Editor.Comments_Layout, False);
   Set_Use_Arrows (Switches_Editor.Comments_Layout, True);
   Set_Use_Arrows_Always (Switches_Editor.Comments_Layout, False);
   String_List.Append (Comments_Layout_Items, -"GNAT style line indentation");
   String_List.Append (Comments_Layout_Items, -"Standard line indentation");
   String_List.Append (Comments_Layout_Items, -"GNAT style comment beginning");
   String_List.Append (Comments_Layout_Items, -"Reformat blocks");
   Combo.Set_Popdown_Strings (Switches_Editor.Comments_Layout, Comments_Layout_Items);
   Free_String_List (Comments_Layout_Items);
   Attach (Switches_Editor.Pp_Layout_Table, Switches_Editor.Comments_Layout, 1, 2, 1, 2,
     Expand or Fill, 0,
     0, 0);

   Switches_Editor.Comments_Layout_Entry := Get_Entry (Switches_Editor.Comments_Layout);
   Set_Editable (Switches_Editor.Comments_Layout_Entry, True);
   Set_Max_Length (Switches_Editor.Comments_Layout_Entry, 0);
   Set_Text (Switches_Editor.Comments_Layout_Entry, -"GNAT style line indentation");
   Set_Visibility (Switches_Editor.Comments_Layout_Entry, True);
   Widget_Callback.Object_Connect
     (Switches_Editor.Comments_Layout_Entry, "changed",
      Widget_Callback.To_Marshaller (Refresh_Pp_Switches'Access), Switches_Editor);

   Gtk_New (Switches_Editor.Pp_Spacing_Frame, -"Spacing");
   Set_Border_Width (Switches_Editor.Pp_Spacing_Frame, 5);
   Set_Shadow_Type (Switches_Editor.Pp_Spacing_Frame, Shadow_Etched_In);
   Attach (Switches_Editor.Pp_Switches, Switches_Editor.Pp_Spacing_Frame, 0, 2, 0, 1,
     Fill, Expand or Fill,
     0, 0);

   Gtk_New (Switches_Editor.Table5, 1, 4, False);
   Set_Row_Spacings (Switches_Editor.Table5, 0);
   Set_Col_Spacings (Switches_Editor.Table5, 0);
   Add (Switches_Editor.Pp_Spacing_Frame, Switches_Editor.Table5);

   Gtk_New (Switches_Editor.Label63, -("Indentation:"));
   Set_Alignment (Switches_Editor.Label63, 0.0, 0.5);
   Set_Padding (Switches_Editor.Label63, 5, 0);
   Set_Justify (Switches_Editor.Label63, Justify_Center);
   Set_Line_Wrap (Switches_Editor.Label63, False);
   Attach (Switches_Editor.Table5, Switches_Editor.Label63, 0, 1, 0, 1,
     Fill, 0,
     0, 0);

   Gtk_New (Indent_Level_Adj, 3.0, 1.0, 9.0, 1.0, 3.0, 3.0);
   Gtk_New (Switches_Editor.Indent_Level, Indent_Level_Adj, 1.0, 0);
   Set_Numeric (Switches_Editor.Indent_Level, False);
   Set_Snap_To_Ticks (Switches_Editor.Indent_Level, False);
   Set_Update_Policy (Switches_Editor.Indent_Level, Update_Always);
   Set_Value (Switches_Editor.Indent_Level, 3.0);
   Set_Wrap (Switches_Editor.Indent_Level, False);
   Attach (Switches_Editor.Table5, Switches_Editor.Indent_Level, 1, 2, 0, 1,
     Expand, 0,
     0, 0);
   Widget_Callback.Object_Connect
     (Switches_Editor.Indent_Level, "changed",
      Widget_Callback.To_Marshaller (Refresh_Pp_Switches'Access), Switches_Editor);

   Gtk_New (Switches_Editor.Label71, -("Maximum line length:"));
   Set_Alignment (Switches_Editor.Label71, 0.0, 0.5);
   Set_Padding (Switches_Editor.Label71, 5, 0);
   Set_Justify (Switches_Editor.Label71, Justify_Center);
   Set_Line_Wrap (Switches_Editor.Label71, False);
   Attach (Switches_Editor.Table5, Switches_Editor.Label71, 2, 3, 0, 1,
     Fill, 0,
     0, 0);

   Gtk_New (Max_Line_Length_Adj, 79.0, 23.0, 256.0, 1.0, 10.0, 10.0);
   Gtk_New (Switches_Editor.Max_Line_Length, Max_Line_Length_Adj, 1.0, 0);
   Set_Numeric (Switches_Editor.Max_Line_Length, False);
   Set_Snap_To_Ticks (Switches_Editor.Max_Line_Length, False);
   Set_Update_Policy (Switches_Editor.Max_Line_Length, Update_Always);
   Set_Value (Switches_Editor.Max_Line_Length, 79.0);
   Set_Wrap (Switches_Editor.Max_Line_Length, False);
   Attach (Switches_Editor.Table5, Switches_Editor.Max_Line_Length, 3, 4, 0, 1,
     Expand, 0,
     0, 0);
   Widget_Callback.Object_Connect
     (Switches_Editor.Max_Line_Length, "changed",
      Widget_Callback.To_Marshaller (Refresh_Pp_Switches'Access), Switches_Editor);

   Gtk_New (Switches_Editor.Pp_Label, -("Pretty Printer"));
   Set_Alignment (Switches_Editor.Pp_Label, 0.5, 0.5);
   Set_Padding (Switches_Editor.Pp_Label, 0, 0);
   Set_Justify (Switches_Editor.Pp_Label, Justify_Center);
   Set_Line_Wrap (Switches_Editor.Pp_Label, False);
   Set_Tab (Switches_Editor.Notebook, 4, Switches_Editor.Pp_Label);

   Gtk_New (Switches_Editor.Binder_Switches, 2, 1, False);
   Set_Row_Spacings (Switches_Editor.Binder_Switches, 0);
   Set_Col_Spacings (Switches_Editor.Binder_Switches, 0);
   Add (Switches_Editor.Notebook, Switches_Editor.Binder_Switches);

   Gtk_New (Switches_Editor.Binder_Switches_Entry);
   Set_Editable (Switches_Editor.Binder_Switches_Entry, True);
   Set_Max_Length (Switches_Editor.Binder_Switches_Entry, 0);
   Set_Text (Switches_Editor.Binder_Switches_Entry, -"");
   Set_Visibility (Switches_Editor.Binder_Switches_Entry, True);
   Attach (Switches_Editor.Binder_Switches, Switches_Editor.Binder_Switches_Entry, 0, 1, 1, 2,
     Expand or Fill, 0,
     0, 0);
   Widget_Callback.Object_Connect
     (Switches_Editor.Binder_Switches_Entry, "changed",
      Widget_Callback.To_Marshaller (On_Binder_Switches_Entry_Changed'Access), Switches_Editor);

   Gtk_New_Vbox (Switches_Editor.Vbox27, False, 0);
   Attach (Switches_Editor.Binder_Switches, Switches_Editor.Vbox27, 0, 1, 0, 1,
     Fill, Expand or Fill,
     0, 0);

   Gtk_New (Switches_Editor.Binder_Tracebacks, -"Store call stack in exceptions");
   Set_Active (Switches_Editor.Binder_Tracebacks, False);
   Pack_Start (Switches_Editor.Vbox27, Switches_Editor.Binder_Tracebacks, False, False, 0);
   Widget_Callback.Object_Connect
     (Switches_Editor.Binder_Tracebacks, "toggled",
      Widget_Callback.To_Marshaller (Refresh_Bind_Switches'Access), Switches_Editor);

   Gtk_New (Switches_Editor.Binder_Restrictions, -"List possible restrictions");
   Set_Active (Switches_Editor.Binder_Restrictions, False);
   Pack_Start (Switches_Editor.Vbox27, Switches_Editor.Binder_Restrictions, False, False, 0);
   Widget_Callback.Object_Connect
     (Switches_Editor.Binder_Restrictions, "toggled",
      Widget_Callback.To_Marshaller (Refresh_Bind_Switches'Access), Switches_Editor);

   Gtk_New (Switches_Editor.Binder_Static_Gnat, Vbox27_Group, -"Static GNAT runtime");
   Vbox27_Group := Group (Switches_Editor.Binder_Static_Gnat);
   Set_Active (Switches_Editor.Binder_Static_Gnat, False);
   Pack_Start (Switches_Editor.Vbox27, Switches_Editor.Binder_Static_Gnat, False, False, 0);
   Widget_Callback.Object_Connect
     (Switches_Editor.Binder_Static_Gnat, "toggled",
      Widget_Callback.To_Marshaller (Refresh_Bind_Switches'Access), Switches_Editor);

   Gtk_New (Switches_Editor.Binder_Shared_Gnat, Vbox27_Group, -"Shared GNAT runtime");
   Vbox27_Group := Group (Switches_Editor.Binder_Shared_Gnat);
   Set_Active (Switches_Editor.Binder_Shared_Gnat, False);
   Pack_Start (Switches_Editor.Vbox27, Switches_Editor.Binder_Shared_Gnat, False, False, 0);

   Gtk_New (Switches_Editor.Binder_Label, -("Binder"));
   Set_Alignment (Switches_Editor.Binder_Label, 0.5, 0.5);
   Set_Padding (Switches_Editor.Binder_Label, 0, 0);
   Set_Justify (Switches_Editor.Binder_Label, Justify_Center);
   Set_Line_Wrap (Switches_Editor.Binder_Label, False);
   Set_Tab (Switches_Editor.Notebook, 5, Switches_Editor.Binder_Label);

   Gtk_New (Switches_Editor.Linker_Switches, 2, 1, False);
   Set_Row_Spacings (Switches_Editor.Linker_Switches, 0);
   Set_Col_Spacings (Switches_Editor.Linker_Switches, 0);
   Add (Switches_Editor.Notebook, Switches_Editor.Linker_Switches);

   Gtk_New (Switches_Editor.Linker_Switches_Entry);
   Set_Editable (Switches_Editor.Linker_Switches_Entry, True);
   Set_Max_Length (Switches_Editor.Linker_Switches_Entry, 0);
   Set_Text (Switches_Editor.Linker_Switches_Entry, -"");
   Set_Visibility (Switches_Editor.Linker_Switches_Entry, True);
   Attach (Switches_Editor.Linker_Switches, Switches_Editor.Linker_Switches_Entry, 0, 1, 1, 2,
     Expand or Fill, 0,
     0, 0);
   Widget_Callback.Object_Connect
     (Switches_Editor.Linker_Switches_Entry, "changed",
      Widget_Callback.To_Marshaller (On_Linker_Switches_Entry_Changed'Access), Switches_Editor);

   Gtk_New_Vbox (Switches_Editor.Vbox40, False, 0);
   Attach (Switches_Editor.Linker_Switches, Switches_Editor.Vbox40, 0, 1, 0, 1,
     Fill, Expand or Fill,
     0, 0);

   Gtk_New (Switches_Editor.Linker_Strip, -"Strip Symbols");
   Set_Active (Switches_Editor.Linker_Strip, False);
   Pack_Start (Switches_Editor.Vbox40, Switches_Editor.Linker_Strip, False, False, 0);
   Widget_Callback.Object_Connect
     (Switches_Editor.Linker_Strip, "toggled",
      Widget_Callback.To_Marshaller (Refresh_Linker_Switches'Access), Switches_Editor);

   Gtk_New (Switches_Editor.Linker_Debug, -"Debug Information");
   Set_Active (Switches_Editor.Linker_Debug, False);
   Pack_Start (Switches_Editor.Vbox40, Switches_Editor.Linker_Debug, False, False, 0);
   Widget_Callback.Object_Connect
     (Switches_Editor.Linker_Debug, "toggled",
      Widget_Callback.To_Marshaller (Refresh_Linker_Switches'Access), Switches_Editor);

   Gtk_New (Switches_Editor.Linker_Profile, -"Profiling");
   Set_Active (Switches_Editor.Linker_Profile, False);
   Set_Sensitive (Switches_Editor.Linker_Profile, False);
   Pack_Start (Switches_Editor.Vbox40, Switches_Editor.Linker_Profile, False, False, 0);
   Widget_Callback.Object_Connect
     (Switches_Editor.Linker_Profile, "toggled",
      Widget_Callback.To_Marshaller (Refresh_Linker_Switches'Access), Switches_Editor);

   Gtk_New (Switches_Editor.Linker_Label, -("Linker"));
   Set_Alignment (Switches_Editor.Linker_Label, 0.5, 0.5);
   Set_Padding (Switches_Editor.Linker_Label, 0, 0);
   Set_Justify (Switches_Editor.Linker_Label, Justify_Center);
   Set_Line_Wrap (Switches_Editor.Linker_Label, False);
   Set_Tab (Switches_Editor.Notebook, 6, Switches_Editor.Linker_Label);

   Gtk_New (Switches_Editor.Hbuttonbox1);
   Set_Spacing (Switches_Editor.Hbuttonbox1, 30);
   Set_Layout (Switches_Editor.Hbuttonbox1, Buttonbox_Spread);
   Set_Child_Size (Switches_Editor.Hbuttonbox1, 85, 27);
   Set_Child_Ipadding (Switches_Editor.Hbuttonbox1, 7, 0);
   Pack_Start (Switches_Editor.Vbox2, Switches_Editor.Hbuttonbox1, False, False, 0);
end Initialize;

end Switches_Editor_Pkg;
