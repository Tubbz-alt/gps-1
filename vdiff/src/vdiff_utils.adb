-----------------------------------------------------------------------
--                               G P S                               --
--                                                                   --
--                 Copyright (C) 2001-2008, AdaCore                  --
--                                                                   --
-- GPS is free  software;  you can redistribute it and/or modify  it --
-- under the terms of the GNU General Public License as published by --
-- the Free Software Foundation; either version 2 of the License, or --
-- (at your option) any later version.                               --
--                                                                   --
-- This program is  distributed in the hope that it will be  useful, --
-- but  WITHOUT ANY WARRANTY;  without even the  implied warranty of --
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU --
-- General Public License for more details. You should have received --
-- a copy of the GNU General Public License along with this program; --
-- if not,  write to the  Free Software Foundation, Inc.,  59 Temple --
-- Place - Suite 330, Boston, MA 02111-1307, USA.                    --
-----------------------------------------------------------------------

with Ada.Text_IO;               use Ada.Text_IO;
with Ada.Unchecked_Deallocation;
with Interfaces.C.Strings;

with Gdk.Color;                 use Gdk.Color;
with Gdk.Event;

with Glib;                      use Glib;
with Glib.Object;               use Glib.Object;
with Glib.Values;

with Gtk.Adjustment;            use Gtk.Adjustment;
with Gtk.Enums;                 use Gtk.Enums;
with Gtk.Menu;
with Gtk.Object;                use Gtk.Object;
with Gtk.Style;                 use Gtk.Style;

with Gtkada.Handlers;           use Gtkada.Handlers;

with Pango.Font;                use Pango.Font;

with GPS.Kernel.Contexts;       use GPS.Kernel.Contexts;
with GPS.Kernel.Modules;        use GPS.Kernel.Modules;
with GPS.Kernel.Preferences;    use GPS.Kernel.Preferences;
with GPS.Kernel;                use GPS.Kernel;
with String_Utils;              use String_Utils;
with Traces;                    use Traces;
with Vdiff_Module;              use Vdiff_Module;
with Vdiff_Pkg;                 use Vdiff_Pkg;
with Basic_Types;               use Basic_Types;

package body Vdiff_Utils is

   package ICS renames Interfaces.C.Strings;

   type Vdiff_Info is new GObject_Record with record
      Kernel : Kernel_Handle;
      File   : VFS.Virtual_File;
   end record;
   type Vdiff_Info_Access is access all Vdiff_Info'Class;

   Num_Line_Sep : constant := 3;
   --  Number of empty lines separating each chunk, in Fill_Diff_List
   --  functions.

   -----------------------
   -- Local subprograms --
   -----------------------

   procedure Gtk_New
     (Vdiff  : out Vdiff_Info_Access;
      Kernel : Kernel_Handle;
      File   : VFS.Virtual_File);
   --  Create a new Vdiff_Info

   procedure Initialize
     (Vdiff  : access Vdiff_Info'Class;
      Kernel : Kernel_Handle;
      File   : VFS.Virtual_File);
   --  Internal initialization function

   procedure On_Destroy
     (Object : access GObject_Record'Class;
      Params : Glib.Values.GValues);
   --  Callback for the "destroy" signal

   procedure Context_Factory
     (Context      : in out Selection_Context;
      Kernel       : access Kernel_Handle_Record'Class;
      Event_Widget : access Gtk.Widget.Gtk_Widget_Record'Class;
      Object       : access Glib.Object.GObject_Record'Class;
      Event        : Gdk.Event.Gdk_Event;
      Menu         : Gtk.Menu.Gtk_Menu);
   --  Creates a new context relative to Object

   ---------------------
   -- Context_Factory --
   ---------------------

   procedure Context_Factory
     (Context      : in out Selection_Context;
      Kernel       : access Kernel_Handle_Record'Class;
      Event_Widget : access Gtk.Widget.Gtk_Widget_Record'Class;
      Object       : access Glib.Object.GObject_Record'Class;
      Event        : Gdk.Event.Gdk_Event;
      Menu         : Gtk.Menu.Gtk_Menu)
   is
      use Gdk.Event;
      Vdiff  : constant Vdiff_Info_Access := Vdiff_Info_Access (Object);
      List   : constant Gtk_Clist := Gtk_Clist (Event_Widget);
      Row    : Gint;
      Column : Gint;
      Valid  : Boolean := False;
      L      : Integer := 0;
      C      : Visible_Column_Type := 0;

      pragma Unreferenced (Menu);

   begin
      Set_Context_Information
        (Context, Kernel, Abstract_Module_ID (Vdiff_Module_ID));

      if Get_Event_Type (Event) in Button_Press .. Button_Release then
         Get_Selection_Info
           (List, Gint (Get_X (Event)), Gint (Get_Y (Event)),
            Row, Column, Valid);

         if Valid then
            declare
               S : constant String := Get_Text (List, Row, 0);
            begin
               if S /= "" then
                  L := Integer'Value (S);
                  C := 1;
               end if;
            exception
               when Constraint_Error =>
                  null;
            end;
         end if;
      end if;

      Set_File_Information
        (Context,
         Files  => (1 => Vdiff.File),
         Line   => L,
         Column => C);

   exception
      when E : others => Trace (Exception_Handle, E);
   end Context_Factory;

   -------------
   -- Gtk_New --
   -------------

   procedure Gtk_New
     (Vdiff  : out Vdiff_Info_Access;
      Kernel : Kernel_Handle;
      File   : VFS.Virtual_File) is
   begin
      Vdiff := new Vdiff_Info;
      Initialize (Vdiff, Kernel, File);
   end Gtk_New;

   ----------------
   -- On_Destroy --
   ----------------

   procedure On_Destroy
     (Object : access GObject_Record'Class;
      Params : Glib.Values.GValues)
   is
      pragma Unreferenced (Params);
      Vdiff : constant Vdiff_Info_Access := Vdiff_Info_Access (Object);
   begin
      Unref (Vdiff);
   end On_Destroy;

   ----------------
   -- Initialize --
   ----------------

   procedure Initialize
     (Vdiff  : access Vdiff_Info'Class;
      Kernel : Kernel_Handle;
      File   : VFS.Virtual_File) is
   begin
      Initialize (Vdiff);
      Vdiff.Kernel := Kernel;
      Vdiff.File := File;
   end Initialize;

   ---------------------
   -- Fill_Diff_Lists --
   ---------------------

   procedure Fill_Diff_Lists
     (Kernel : access Kernel_Handle_Record'Class;
      List1  : access Gtk_Clist_Record'Class;
      List2  : access Gtk_Clist_Record'Class;
      File1  : VFS.Virtual_File;
      File2  : VFS.Virtual_File;
      Diff   : Diff_Occurrence_Link)
   is
      Context_Len     : Integer :=
        Integer (Get_Pref (Diff_Context_Length));
      --  Number of lines displayed before and after each chunk of differences

      S               : String (1 .. 8192);
      Last            : Natural;
      Len             : Natural;
      Infile1         : Ada.Text_IO.File_Type;
      Infile2         : Ada.Text_IO.File_Type;
      Texts           : ICS.chars_ptr_array (0 .. 1);
      Row             : Gint;
      Line1           : Natural;
      Line2           : Natural;
      Offset1         : Natural;
      Offset2         : Natural;
      Link            : Diff_Occurrence_Link;
      Default_Style   : Gtk_Style;
      Old_Style       : Gtk_Style;
      Append_Style    : Gtk_Style;
      Remove_Style    : Gtk_Style;
      Change_Style    : Gtk_Style;
      Color           : Gdk_Color;
      Context_Changed : Boolean;
      Desc            : constant Pango_Font_Description :=
        Get_Pref_Font (GPS.Kernel.Preferences.Default_Style);

      Info_1          : Vdiff_Info_Access;
      Info_2          : Vdiff_Info_Access;

      procedure Add_Line
        (List  : access Gtk_Clist_Record'Class;
         Style : Gtk_Style;
         Line  : String := "");
      --  Add a line constaining Line in List, using Style for font/color

      procedure Read_Line
        (Infile  : File_Type;
         List    : access Gtk_Clist_Record'Class;
         Line    : Natural;
         Style   : Gtk_Style;
         Display : Boolean := True);
      --  Read the next line in Infile and add it in List, with the line
      --  number Line, using Style for font/color.
      --  If Display is True, add the line in the list, otherwise only
      --  read the line in Infile.

      --------------
      -- Add_Line --
      --------------

      procedure Add_Line
        (List  : access Gtk_Clist_Record'Class;
         Style : Gtk_Style;
         Line  : String := "") is
      begin
         Texts (0) := ICS.Null_Ptr;
         Texts (1) := ICS.New_String (Line);
         Row := Append (List, Texts);
         Set_Cell_Style (List, Row, 0, Style);
         Set_Cell_Style (List, Row, 1, Style);
         ICS.Free (Texts (1));
      end Add_Line;

      ---------------
      -- Read_Line --
      ---------------

      procedure Read_Line
        (Infile  : File_Type;
         List    : access Gtk_Clist_Record'Class;
         Line    : Natural;
         Style   : Gtk_Style;
         Display : Boolean := True) is
      begin
         Get_Line (File => Infile, Item => S, Last => Last);

         if Display then
            Texts (0) := ICS.New_String (Image (Line));
            Texts (1) := ICS.New_String (Strip_CR (S (1 .. Last)));
            Row := Append (List, Texts);
            Set_Cell_Style (List, Row, 0, Style);
            Set_Cell_Style (List, Row, 1, Style);
            ICS.Free (Texts (0));
            ICS.Free (Texts (1));
         end if;
      end Read_Line;

   begin
      Gtk_New (Info_1, Kernel_Handle (Kernel), File1);
      Gtk_New (Info_2, Kernel_Handle (Kernel), File2);

      Object_Callback.Object_Connect
        (List1, Signal_Destroy,
         On_Destroy'Access,
         Info_1);

      Register_Contextual_Menu
        (Kernel,
         List1,
         Info_1,
         Vdiff_Module_ID,
         Context_Factory'Access);

      Register_Contextual_Menu
        (Kernel,
         List2,
         Info_2,
         Vdiff_Module_ID,
         Context_Factory'Access);

      if Context_Len = -1 then
         Context_Len := Integer'Last;
      end if;

      --  ??? When are these styles freed ?
      Default_Style := Copy (Get_Style (List1));
      Set_Font_Description (Default_Style, Desc);

      Old_Style     := Copy (Default_Style);
      Append_Style  := Copy (Default_Style);
      Remove_Style  := Copy (Default_Style);
      Change_Style  := Copy (Default_Style);

      --  <preferences>
      Set_Rgb (Color, 50000, 50000, 50000);
      Set_Base (Old_Style, State_Normal, Color);
      Set_Rgb (Color, 170 * 256, 254 * 256, 170 * 256);
      Set_Base (Append_Style, State_Normal, Color);
      Set_Rgb (Color, 254 * 256, 170 * 256, 170 * 256);
      Set_Base (Remove_Style, State_Normal, Color);
      Set_Rgb (Color, 164 * 256, 223 * 256, 255 * 256);
      Set_Base (Change_Style, State_Normal, Color);

      begin
         Open (Infile1, In_File, Full_Name (File1).all);
      exception
         when Name_Error =>
            return;
      end;

      begin
         Open (Infile2, In_File, Full_Name (File2).all);
      exception
         when Name_Error =>
            Close (Infile1);
            return;
      end;

      Freeze (List1);
      Freeze (List2);

      Line1 := 1;
      Line2 := 1;
      Link := Diff;

      while Link /= null loop
         Context_Changed := False;

         for J in Line1 .. Link.Range1.First - 1 loop
            if J - Line1 < Context_Len
              or else Link.Range1.First - J <= Context_Len
            then
               Read_Line (Infile1, List1, J, Default_Style);
            else
               Read_Line (Infile1, List1, J, Default_Style, False);

               if not Context_Changed then
                  for J in 1 .. Num_Line_Sep loop
                     Add_Line (List1, Default_Style);
                  end loop;

                  Context_Changed := True;
               end if;
            end if;
         end loop;

         Context_Changed := False;

         for J in Line2 .. Link.Range2.First - 1 loop
            if J - Line2 < Context_Len
              or else Link.Range2.First - J <= Context_Len
            then
               Read_Line (Infile2, List2, J, Default_Style);
            else
               Read_Line (Infile2, List2, J, Default_Style, False);

               if not Context_Changed then
                  for J in 1 .. Num_Line_Sep loop
                     Add_Line (List2, Default_Style);
                  end loop;

                  Context_Changed := True;
               end if;
            end if;
         end loop;

         case Link.Action is
            when Append =>
               for J in Link.Range2.First .. Link.Range2.Last - 1 loop
                  Add_Line (List1, Old_Style);
               end loop;

               for J in Link.Range2.First .. Link.Range2.Last - 1 loop
                  Read_Line (Infile2, List2, J, Append_Style);
               end loop;

               Line1 := Link.Range1.First;
               Line2 := Link.Range2.Last;

            when Change =>
               Offset1 := Link.Range1.Last - Link.Range1.First;
               Offset2 := Link.Range2.Last - Link.Range2.First;

               for J in Link.Range1.First .. Link.Range1.Last - 1 loop
                  Read_Line (Infile1, List1, J, Old_Style);
               end loop;

               for J in Link.Range2.First .. Link.Range2.Last - 1 loop
                  Read_Line (Infile2, List2, J, Change_Style);
               end loop;

               if Offset1 < Offset2 then
                  for J in Offset1 .. Offset2 - 1 loop
                     Add_Line (List1, Old_Style);
                  end loop;
               elsif Offset1 > Offset2 then
                  for J in Offset2 .. Offset1 - 1 loop
                     Add_Line (List2, Change_Style);
                  end loop;
               end if;

               Line1 := Link.Range1.Last;
               Line2 := Link.Range2.Last;

            when Delete =>
               for J in Link.Range1.First .. Link.Range1.Last - 1 loop
                  Read_Line (Infile1, List1, J, Old_Style);
               end loop;

               for J in Link.Range1.First .. Link.Range1.Last - 1 loop
                  Add_Line (List2, Remove_Style);
               end loop;

               Line1 := Link.Range1.Last;
               Line2 := Link.Range2.First;

            when others =>
               null;
         end case;

         Link := Link.Next;
      end loop;

      --  Complete files with the remaining lines

      Len := 0;
      while Len < Context_Len and then not End_Of_File (Infile1) loop
         Read_Line (Infile1, List1, Line1, Default_Style);
         Line1 := Line1 + 1;
         Len   := Len + 1;
      end loop;

      Len := 0;
      while Len < Context_Len and then not End_Of_File (Infile2) loop
         Read_Line (Infile2, List2, Line2, Default_Style);
         Line2 := Line2 + 1;
         Len   := Len + 1;
      end loop;

      Thaw (List2);
      Thaw (List1);
      Close (Infile2);
      Close (Infile1);

   exception
      when End_Error =>
         Thaw (List2);
         Thaw (List1);
         Close (Infile2);
         Close (Infile1);
   end Fill_Diff_Lists;

   ----------
   -- Free --
   ----------

   procedure Free (This : in out Text_Iterator_Access) is
      procedure Free_Data is
         new Ada.Unchecked_Deallocation (Text_Iterator, Text_Iterator_Access);
   begin
      if This = null then
         return;
      end if;

      if This.Next /= null then
         Free (This.Next);
      end if;

      GNAT.Strings.Free (This.New_Line);
      GNAT.Strings.Free (This.Old_Line);
      Free_Data (This);
   end Free;

   ---------------------
   -- Fill_Diff_Lists --
   ---------------------

   procedure Fill_Diff_Lists
     (Kernel     : access Kernel_Handle_Record'Class;
      List1      : access Gtk_Clist_Record'Class;
      List2      : access Gtk_Clist_Record'Class;
      First_Line : Text_Iterator_Access)
   is

      Texts            : ICS.chars_ptr_array (0 .. 1);
      Row              : Gint;
      Default_Style    : Gtk_Style;
      Old_Style        : Gtk_Style;
      Append_Style     : Gtk_Style;
      Remove_Style     : Gtk_Style;
      Change_Style     : Gtk_Style;
      Color            : Gdk_Color;

      Info_1           : Vdiff_Info_Access;
      Info_2           : Vdiff_Info_Access;

      Current_Line     : Text_Iterator_Access;
      Offset_Line      : Integer := 0;
      Last_Line_Number : Natural;
      Desc             : constant Pango_Font_Description :=
        Get_Pref_Font (GPS.Kernel.Preferences.Default_Style);

      procedure Add_Line
        (List   : access Gtk_Clist_Record'Class;
         Style  : Gtk_Style;
         Number : Natural := 0;
         Line   : String := "");
      --  Add a line constaining Line in List, using Style for font/color

      --------------
      -- Add_Line --
      --------------

      procedure Add_Line
        (List   : access Gtk_Clist_Record'Class;
         Style  : Gtk_Style;
         Number : Natural := 0;
         Line   : String := "") is
      begin
         if Number = 0 then
            Texts (0) := ICS.Null_Ptr;
         else
            Texts (0) := ICS.New_String (Image (Number));
         end if;
         Texts (1) := ICS.New_String (Line);
         Row := Append (List, Texts);
         if Current_Line.Color_Enabled then
            Set_Cell_Style (List, Row, 0, Style);
            Set_Cell_Style (List, Row, 1, Style);
         else
            Set_Cell_Style (List, Row, 0, Default_Style);
            Set_Cell_Style (List, Row, 1, Default_Style);
         end if;
         ICS.Free (Texts (0));
         ICS.Free (Texts (1));
      end Add_Line;

   begin
      Gtk_New (Info_1, Kernel_Handle (Kernel), VFS.No_File);
      Gtk_New (Info_2, Kernel_Handle (Kernel), VFS.No_File);

      Object_Callback.Object_Connect
        (List1, Signal_Destroy,
         On_Destroy'Access,
         Info_1);

      --  ??? When are these styles freed ?
      Default_Style := Copy (Get_Style (List1));
      Set_Font_Description (Default_Style, Desc);

      Old_Style     := Copy (Default_Style);
      Append_Style  := Copy (Default_Style);
      Remove_Style  := Copy (Default_Style);
      Change_Style  := Copy (Default_Style);

      --  <preferences>
      Set_Rgb (Color, 50000, 50000, 50000);
      Set_Base (Old_Style, State_Normal, Color);
      Set_Rgb (Color, 0, 56000, 0);
      Set_Base (Append_Style, State_Normal, Color);
      Set_Rgb (Color, 56000, 0, 0);
      Set_Base (Remove_Style, State_Normal, Color);
      Set_Rgb (Color, 0, 40000, 65000);
      Set_Base (Change_Style, State_Normal, Color);

      Freeze (List1);
      Freeze (List2);

      Last_Line_Number := 0;
      Current_Line := First_Line;

      while Current_Line /= null loop

         if Current_Line.File_Caption then

            for J in 1 .. Num_Line_Sep / 2 loop
               Add_Line (List1, Default_Style);
               Add_Line (List2, Default_Style);
            end loop;

            Add_Line (List1, Default_Style, 0, Current_Line.Old_Line.all);
            Add_Line (List2, Default_Style, 0, Current_Line.New_Line.all);

            for J in 1 .. Num_Line_Sep / 2 loop
               Add_Line (List1, Default_Style);
               Add_Line (List2, Default_Style);
            end loop;

            Offset_Line := 0;

         else

            if Last_Line_Number + 1 < Current_Line.Original_Position then
               for J in 1 .. Num_Line_Sep loop
                  Add_Line (List1, Default_Style);
                  Add_Line (List2, Default_Style);
               end loop;
            end if;

            Last_Line_Number := Current_Line.Original_Position;

            case Current_Line.Action is
               when Append =>
                  Offset_Line := Offset_Line + 1;

                  Add_Line (List1, Old_Style);
                  Add_Line
                    (List2,
                     Append_Style,
                     Current_Line.Original_Position + Offset_Line,
                     Current_Line.New_Line.all);

               when Change =>
                  Add_Line
                    (List1,
                     Old_Style,
                     Current_Line.Original_Position,
                     Current_Line.Old_Line.all);
                  Add_Line
                    (List2,
                     Change_Style,
                     Current_Line.Original_Position + Offset_Line,
                     Current_Line.New_Line.all);

               when Delete =>
                  Add_Line
                    (List1,
                     Old_Style,
                     Current_Line.Original_Position,
                     Current_Line.Old_Line.all);
                  Add_Line (List2, Remove_Style);

                  Offset_Line := Offset_Line - 1;

               when Nothing =>
                  Add_Line
                    (List1,
                     Default_Style,
                     Current_Line.Original_Position,
                     Current_Line.Old_Line.all);
                  Add_Line
                    (List2,
                     Default_Style,
                     Current_Line.Original_Position + Offset_Line,
                     Current_Line.New_Line.all);

            end case;

         end if;

         Current_Line := Current_Line.Next;

      end loop;

      Thaw (List2);
      Thaw (List1);

   exception
      when End_Error =>
         Thaw (List2);
         Thaw (List1);
   end Fill_Diff_Lists;

   --------------------
   -- Value1_Changed --
   --------------------

   procedure Value1_Changed
     (Object : access Gtk_Widget_Record'Class)
   is
      Vdiff : constant Vdiff_Access := Vdiff_Access (Object);
   begin
      if Vdiff.Ignore_Value_Changed then
         return;
      end if;

      Vdiff.Ignore_Value_Changed := True;
      Set_Value
        (Get_Vadjustment (Vdiff.Clist2),
         Get_Value (Get_Vadjustment (Vdiff.Clist1)));
      Vdiff.Ignore_Value_Changed := False;
   end Value1_Changed;

   --------------------
   -- Value2_Changed --
   --------------------

   procedure Value2_Changed
     (Object : access Gtk_Widget_Record'Class)
   is
      Vdiff : constant Vdiff_Access := Vdiff_Access (Object);
   begin
      if Vdiff.Ignore_Value_Changed then
         return;
      end if;

      Vdiff.Ignore_Value_Changed := True;
      Set_Value
        (Get_Vadjustment (Vdiff.Clist1),
         Get_Value (Get_Vadjustment (Vdiff.Clist2)));
      Vdiff.Ignore_Value_Changed := False;
   end Value2_Changed;

   ----------------------
   -- H_Value1_Changed --
   ----------------------

   procedure H_Value1_Changed
     (Object : access Gtk_Widget_Record'Class)
   is
      Vdiff : constant Vdiff_Access := Vdiff_Access (Object);
   begin
      if Vdiff.Ignore_Value_Changed then
         return;
      end if;

      Vdiff.Ignore_Value_Changed := True;
      Set_Value
        (Get_Hadjustment (Vdiff.Clist2),
         Get_Value (Get_Hadjustment (Vdiff.Clist1)));
      Vdiff.Ignore_Value_Changed := False;
   end H_Value1_Changed;

   ----------------------
   -- H_Value2_Changed --
   ----------------------

   procedure H_Value2_Changed
     (Object : access Gtk_Widget_Record'Class)
   is
      Vdiff : constant Vdiff_Access := Vdiff_Access (Object);
   begin
      if Vdiff.Ignore_Value_Changed then
         return;
      end if;

      Vdiff.Ignore_Value_Changed := True;
      Set_Value
        (Get_Hadjustment (Vdiff.Clist1),
         Get_Value (Get_Hadjustment (Vdiff.Clist2)));
      Vdiff.Ignore_Value_Changed := False;
   end H_Value2_Changed;

end Vdiff_Utils;
