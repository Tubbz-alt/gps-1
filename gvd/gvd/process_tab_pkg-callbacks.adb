-----------------------------------------------------------------------
--                 Odd - The Other Display Debugger                  --
--                                                                   --
--                         Copyright (C) 2000                        --
--                 Emmanuel Briot and Arnaud Charlet                 --
--                                                                   --
-- Odd is free  software;  you can redistribute it and/or modify  it --
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

with System; use System;
with Glib; use Glib;
with Gtk.Widget; use Gtk.Widget;
with Gtk.Handlers; use Gtk.Handlers;
with Unchecked_Conversion;
with Odd.Process; use Odd.Process;
with Gdk.Types.Keysyms;  use Gdk.Types.Keysyms;
with Gdk.Event;   use Gdk.Event;
with Odd.Histories;

with Ada.Text_IO; use Ada.Text_IO;

package body Process_Tab_Pkg.Callbacks is

   Command_History_Size : constant := 100;
   --  Number of items in the command history list.

   Command_History_Collapse_Entries : constant Boolean := True;
   --  Whether we should collapse entries in the history list.

   use Gtk.Arguments;

   package String_History is new Odd.Histories (String);
   use String_History;
   Command_History : String_History.History_List
     (Command_History_Size, Command_History_Collapse_Entries);

   ----------------------------------
   -- On_Debugger_Text_Insert_Text --
   ----------------------------------

   procedure On_Debugger_Text_Insert_Text
     (Object : access Gtk_Widget_Record'Class;
      Params : Gtk.Arguments.Gtk_Args)
   is
      Arg1 : String := To_String (Params, 1);
      --  Arg2 : Gint := To_Gint (Params, 2);
      Position : Address := To_Address (Params, 3);

      Top  : Debugger_Process_Tab := Debugger_Process_Tab (Object);

      type Guint_Ptr is access all Guint;
      function To_Guint_Ptr is new Unchecked_Conversion (Address, Guint_Ptr);
      use Odd.Process;

   begin
      if To_Guint_Ptr (Position).all < Top.Edit_Pos then
         Emit_Stop_By_Name (Top.Debugger_Text, "insert_text");
      else
         if Arg1 (Arg1'First) = ASCII.LF then
            --  ???Would be nice to display the LF character right away, so
            --  that the user knows his command has been taken into account.

            --  This would require to: insert the LF, force a screen update,
            --  process the command, stop the emission of the signal, set the
            --  final position of the cursor. Note that forcing a screen
            --  update can probably only be done by using an idle handle
            --  to call Process_User_Command, instead of calling it in this
            --  function.

            --  Can't we at least change the cursor ?

            declare
               S : String :=
                 Get_Chars (Top.Debugger_Text, Gint (Top.Edit_Pos));
            begin
               Process_User_Command (Top, S);
               Append (Command_History, S);
            end;
         end if;
      end if;
   end On_Debugger_Text_Insert_Text;

  ----------------------------------
   -- On_Debugger_Text_Delete_Text --
   ----------------------------------

   procedure On_Debugger_Text_Delete_Text
     (Object : access Gtk_Widget_Record'Class;
      Params : Gtk.Arguments.Gtk_Args)
   is
      --  Arg1 : Gint := To_Gint (Params, 1);
      Arg2 : Gint := To_Gint (Params, 2);

      Top  : Debugger_Process_Tab := Debugger_Process_Tab (Object);

   begin
      if Arg2 <= Gint (Top.Edit_Pos) then
         Emit_Stop_By_Name (Top.Debugger_Text, "delete_text");
      end if;
   end On_Debugger_Text_Delete_Text;

   -----------------------------------
   -- On_Debugger_Text_Insert_Text2 --
   -----------------------------------

   procedure On_Debugger_Text_Insert_Text2
     (Object : access Gtk_Widget_Record'Class;
      Params : Gtk.Arguments.Gtk_Args)
   is
      Arg1 : String := To_String (Params, 1);
      --  Arg2 : Gint := To_Gint (Params, 2);
      --  Arg3 : Address := To_Address (Params, 3);
      Top  : Debugger_Process_Tab := Debugger_Process_Tab (Object);
   begin
      --  This callback is called last in the list for "insert_text".  This is
      --  required because in the first handler On_Debugger_Text_Insert_Text,
      --  the ASCII.LF character is inserted only after the output of the
      --  command has been inserted. Since the emit also memorizes the
      --  position, the character is inserted correctly. However, this leaves
      --  the cursor at an incorrect position, which we restore here.

      if Arg1 (Arg1'First) = ASCII.LF then
         Top.Edit_Pos := Get_Length (Top.Debugger_Text);
         Set_Point (Top.Debugger_Text, Top.Edit_Pos);
         Set_Position (Top.Debugger_Text, Gint (Top.Edit_Pos));
       end if;
   end On_Debugger_Text_Insert_Text2;

   --------------------------------------
   -- On_Debugger_Text_Key_Press_Event --
   --------------------------------------

   function On_Debugger_Text_Key_Press_Event
     (Object : access Gtk_Widget_Record'Class;
      Params : Gtk.Arguments.Gtk_Args) return Boolean
   is
      Arg1 : Gdk_Event := To_Event (Params, 1);
      Top  : Debugger_Process_Tab := Debugger_Process_Tab (Object);
      use type Gdk.Types.Gdk_Key_Type;
   begin
      if Get_Key_Val (Arg1) = Gdk_Up
        or else Get_Key_Val (Arg1) = Gdk_Down
      then
         Delete_Text (Top.Debugger_Text,
                      Gint (Top.Edit_Pos),
                      Gint (Get_Length (Top.Debugger_Text)));
         begin
            if Get_Key_Val (Arg1) = Gdk_Up then
               Move_To_Previous (Command_History);
            else
               Move_To_Next (Command_History);
            end if;
            Set_Point (Top.Debugger_Text, Top.Edit_Pos);
            Text_Output_Handler (Top, Get_Current (Command_History));
            Set_Position (Top.Debugger_Text,
                          Gint (Get_Length (Top.Debugger_Text)));
         exception
            when No_Such_Item =>
               null;
         end;
         Emit_Stop_By_Name (Top.Debugger_Text, "key_press_event");
      end if;
      return True;
   end On_Debugger_Text_Key_Press_Event;

end Process_Tab_Pkg.Callbacks;
