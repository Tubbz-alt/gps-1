-----------------------------------------------------------------------
--                               G P S                               --
--                                                                   --
--                     Copyright (C) 2006                            --
--                              AdaCore                              --
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

with Ada.Exceptions;     use Ada.Exceptions;

with Glib;               use Glib;
with Glib.Convert;       use Glib.Convert;
with Glib.Object;        use Glib.Object;

with Gtk.Button;         use Gtk.Button;
with Gtk.Enums;          use Gtk.Enums;
with Gtk.GEntry;         use Gtk.GEntry;
with Gtk.Handlers;       use Gtk.Handlers;
with Gtk.Label;          use Gtk.Label;
with Gtk.List;           use Gtk.List;
with Gtk.List_Item;      use Gtk.List_Item;
with Gtk.Table;          use Gtk.Table;
with Gtk.Tooltips;       use Gtk.Tooltips;
with Gtk.Widget;         use Gtk.Widget;
with Gtkada.Combo;       use Gtkada.Combo;
with Gtkada.MDI;         use Gtkada.MDI;

with GPS.Intl;           use GPS.Intl;
with GPS.Kernel;         use GPS.Kernel;
with GPS.Kernel.Modules; use GPS.Kernel.Modules;
with GPS.Kernel.MDI;     use GPS.Kernel.MDI;
with GPS.Kernel.Remote;  use GPS.Kernel.Remote;

with Traces;             use Traces;

package body Remote_Views is

--     Me : constant Debug_Handle := Create ("Remote_Views");

   type Remote_View_Module_Record is new Module_ID_Record with null record;
   Remote_View_Module_Id : Module_ID;

   type Remote_View_Record is new Gtk.Table.Gtk_Table_Record with record
      Kernel             : GPS.Kernel.Kernel_Handle;
      Simple_Mode        : Boolean;
      Simple_Table       : Gtk_Table;
      Full_Table         : Gtk_Table;
      Remote_Combo       : Gtkada_Combo;
      Build_Combo        : Gtkada_Combo;
      Debug_Combo        : Gtkada_Combo;
      Exec_Combo         : Gtkada_Combo;
      Simple_View_Button : Gtk_Button;
      Full_View_Button   : Gtk_Button;
   end record;
   type Remote_View is access all Remote_View_Record'Class;

   procedure Gtk_New
     (View            : out Remote_View;
      Kernel          : access Kernel_Handle_Record'Class;
      Use_Simple_View : Boolean := True);
   --  Create a new remote view associated with Manager.

   procedure Initialize
     (View            : access Remote_View_Record'Class;
      Kernel          : access Kernel_Handle_Record'Class;
      Use_Simple_View : Boolean := True);
   --  Internal function for creating new widgets

   procedure Set_Servers
     (View  : access Remote_View_Record'Class);
   --  Set the list of available servers

   ---------------
   -- Callbacks --
   ---------------

   type Remote_Data is record
      View   : Remote_View;
      Server : Server_Type;
   end record;

   procedure Setup (Data : Remote_Data; Id : Handler_Id);
   package View_Callback is new Gtk.Handlers.User_Callback_With_Setup
     (Gtk_Widget_Record, Remote_Data, Setup);

   procedure On_Combo_Changed
     (Combo : access Gtk_Widget_Record'Class;
      User  : Remote_Data);
   --  Called when one of the combo box's value changes

   procedure On_View_Mode_Clicked
     (View : access Gtk_Widget_Record'Class;
      User : Remote_Data);
   --  Called when the view's mode is changed

   procedure On_Show_Remote_View
     (Widget : access GObject_Record'Class;
      Kernel : Kernel_Handle);
   --  Remote->Show Remote View

   -------------
   -- Gtk_New --
   -------------

   procedure Gtk_New
     (View            : out Remote_View;
      Kernel          : access Kernel_Handle_Record'Class;
      Use_Simple_View : Boolean := True)
   is
   begin
      View := new Remote_View_Record;
      Initialize (View, Kernel, Use_Simple_View);
   end Gtk_New;

   ----------------
   -- Initialize --
   ----------------

   procedure Initialize
     (View            : access Remote_View_Record'Class;
      Kernel          : access Kernel_Handle_Record'Class;
      Use_Simple_View : Boolean := True)
   is
      Label         : Gtk_Label;
      Tooltips      : Gtk_Tooltips;
   begin
      Gtk.Table.Initialize (View, 2, 1, False);

      View.Kernel := Kernel_Handle (Kernel);
      Gtk_New (View.Simple_Table, 2, 2, False);
      Attach (View, View.Simple_Table, 0, 1, 0, 1,
              Expand or Fill, 0);
      Gtk_New (View.Full_Table, 4, 2, False);
      Attach (View, View.Full_Table, 0, 1, 0, 2,
              Expand or Fill, 0);
      Tooltips := Get_Tooltips (View.Kernel);

      View.Simple_Mode := Use_Simple_View;

      --  Simple view
      Gtk_New (Label, -("Remote Server:"));
      Set_Alignment (Label, 0.0, 0.5);
      Attach (View.Simple_Table, Label, 0, 1, 0, 1, Fill);
      Gtk_New (View.Remote_Combo);
      Set_Editable (Get_Entry (View.Remote_Combo), False);
      Set_Width_Chars (Get_Entry (View.Remote_Combo), 0);
      Attach (View.Simple_Table, View.Remote_Combo, 1, 2, 0, 1);
      View_Callback.Connect
        (View.Remote_Combo, "changed", On_Combo_Changed'Access,
         (View => Remote_View (View), Server => Build_Server));
      View_Callback.Connect
        (View.Remote_Combo, "changed", On_Combo_Changed'Access,
         (View => Remote_View (View), Server => Debug_Server));
      View_Callback.Connect
        (View.Remote_Combo, "changed", On_Combo_Changed'Access,
         (View => Remote_View (View), Server => Execution_Server));
      Set_Tip
        (Tooltips, Get_Entry (View.Remote_Combo),
         -"The remote server used to compile, debug and execute your " &
         "project.");
      Gtk_New (View.Simple_View_Button, -"Advanced >>");
      Attach (View.Simple_Table, View.Simple_View_Button, 0, 2, 1, 2, 0, 0);
      View_Callback.Connect
        (View.Simple_View_Button, "clicked", On_View_Mode_Clicked'Access,
         (View =>  Remote_View (View), Server => GPS_Server));

      --  Full view mode

      Gtk_New (Label, -("Build:"));
      Set_Alignment (Label, 0.0, 0.5);
      Attach (View.Full_Table, Label, 0, 1, 0, 1, Fill);

      Gtk_New (Label, -("Debug:"));
      Set_Alignment (Label, 0.0, 0.5);
      Attach (View.Full_Table, Label, 0, 1, 1, 2, Fill);

      Gtk_New (Label, -("Execution:"));
      Set_Alignment (Label, 0.0, 0.5);
      Attach (View.Full_Table, Label, 0, 1, 2, 3, Fill);

      Gtk_New (View.Build_Combo);
      Set_Editable (Get_Entry (View.Build_Combo), False);
      Set_Width_Chars (Get_Entry (View.Build_Combo), 0);
      Attach (View.Full_Table, View.Build_Combo, 1, 2, 0, 1);
      View_Callback.Connect
        (View.Build_Combo, "changed", On_Combo_Changed'Access,
         (View => Remote_View (View), Server => Build_Server));

      Gtk_New (View.Debug_Combo);
      Set_Editable (Get_Entry (View.Debug_Combo), False);
      Set_Width_Chars (Get_Entry (View.Debug_Combo), 0);
      Attach (View.Full_Table, View.Debug_Combo, 1, 2, 1, 2);
      View_Callback.Connect
        (View.Debug_Combo, "changed", On_Combo_Changed'Access,
         (View => Remote_View (View), Server => Debug_Server));

      Gtk_New (View.Exec_Combo);
      Set_Editable (Get_Entry (View.Exec_Combo), False);
      Set_Width_Chars (Get_Entry (View.Exec_Combo), 0);
      Attach (View.Full_Table, View.Exec_Combo, 1, 2, 2, 3);
      View_Callback.Connect
        (View.Exec_Combo, "changed", On_Combo_Changed'Access,
         (View => Remote_View (View), Server => Execution_Server));

      Set_Tip
        (Tooltips, Get_Entry (View.Build_Combo),
         -"The server used to perform builds and execute gnat tools.");
      Set_Tip
        (Tooltips, Get_Entry (View.Debug_Combo),
         -"The server used to launch the debugger.");
      Set_Tip
        (Tooltips, Get_Entry (View.Exec_Combo),
         -"The server used to execute the built executables.");

      Gtk_New (View.Full_View_Button, -"Basic <<");
      Attach (View.Full_Table, View.Full_View_Button, 0, 2, 3, 4, 0, 0);
      View_Callback.Connect
        (View.Full_View_Button, "clicked", On_View_Mode_Clicked'Access,
         (View =>  Remote_View (View), Server => GPS_Server));

      Set_Child_Visible (View.Simple_Table,
                         View.Simple_Mode);
      Set_Child_Visible (View.Full_Table,
                         not View.Simple_Mode);
      Set_Servers (View);
   end Initialize;

   -----------
   -- Setup --
   -----------

   procedure Setup (Data : Remote_Data; Id : Handler_Id) is
   begin
      Add_Watch (Id, Data.View);
   end Setup;

   -----------------
   -- Set_Servers --
   -----------------

   procedure Set_Servers
     (View : access Remote_View_Record'Class)
   is
      procedure Set_Servers_List
        (List   : access Gtk_List_Record'Class);
      --  Sets the list of available servers

      ----------------------
      -- Set_Servers_List --
      ----------------------

      procedure Set_Servers_List
        (List   : access Gtk_List_Record'Class)
      is
         Item : Gtk_List_Item;
      begin
         Clear_Items (List, 0, -1);
         for J in 1 .. Get_Number_Of_Server_Config loop
            Gtk_New (Item, Locale_To_UTF8
                     (Get_Nickname (J)));
            Add (List, Item);
         end loop;
         Show_All (List);
      end Set_Servers_List;

      Simple_Config : Boolean;
   begin
      Set_Servers_List (Get_List (View.Remote_Combo));
      Set_Servers_List (Get_List (View.Build_Combo));
      Set_Servers_List (Get_List (View.Debug_Combo));
      Set_Servers_List (Get_List (View.Exec_Combo));

      --  Set server for simple view, if possible.
      declare
         First_Server : constant String
           := Get_Nickname (Remote_Server_Type'First);
      begin
         Simple_Config := True;
         for S in Remote_Server_Type'Range loop
            if Get_Nickname (S) /= First_Server then
               Simple_Config := False;
               exit;
            end if;
         end loop;
      end;
      if Simple_Config then
         Set_Text (Get_Entry (View.Remote_Combo),
                   Get_Nickname (Build_Server));
      else
         Set_Text (Get_Entry (View.Remote_Combo),
                   -"(Advanced configuration)");
      end if;
      --  Set server for full view
      Set_Text (Get_Entry (View.Build_Combo),
                Get_Nickname (Build_Server));
      Set_Text (Get_Entry (View.Debug_Combo),
                Get_Nickname (Debug_Server));
      Set_Text (Get_Entry (View.Exec_Combo),
                Get_Nickname (Execution_Server));
   end Set_Servers;

   ----------------------
   -- On_Combo_Changed --
   ----------------------

   procedure On_Combo_Changed
     (Combo : access Gtk_Widget_Record'Class;
      User  : Remote_Data)
   is
      Value : constant String := Get_Text (Get_Entry (Gtkada_Combo (Combo)));
   begin
      if Value /= "" then
         Assign (User.Server,
                 Value);
      end if;
   end On_Combo_Changed;

   --------------------------
   -- On_View_Mode_Clicked --
   --------------------------

   procedure On_View_Mode_Clicked
     (View : access Gtk_Widget_Record'Class;
      User : Remote_Data)
   is
      pragma Unreferenced (View);
   begin
      User.View.Simple_Mode := not User.View.Simple_Mode;

      Set_Child_Visible (User.View.Simple_Table,
                         User.View.Simple_Mode);
      Set_Child_Visible (User.View.Full_Table,
                         not User.View.Simple_Mode);
      Show (User.View.Simple_Table);
      Show (User.View.Full_Table);
      Set_Servers (User.View);
   end On_View_Mode_Clicked;

   -------------------------
   -- On_Show_Remote_View --
   -------------------------

   procedure On_Show_Remote_View
     (Widget : access GObject_Record'Class;
      Kernel : Kernel_Handle)
   is
      pragma Unreferenced (Widget);
      Remote : Remote_View;
      Child  : GPS_MDI_Child;
   begin
      Child := GPS_MDI_Child (Find_MDI_Child_By_Tag
                              (Get_MDI (Kernel), Remote_View_Record'Tag));
      if Child = null then
         Gtk_New (Remote, Kernel);
         Gtk_New (Child, Remote,
                  Default_Width => 215,
                  Group         => Group_View,
                  Module        => Remote_View_Module_Id);
         Set_Title (Child, -"Remote Servers View", -"Remote Servers View");
         Put (Get_MDI (Kernel), Child, Initial_Position => Position_Left);
      end if;

      Set_Focus_Child (Child);
      Raise_Child (Child);

   exception
      when E : others =>
         Trace (Exception_Handle,
                "Unexpected exception: " & Exception_Information (E));
   end On_Show_Remote_View;

   ---------------------
   -- Register_Module --
   ---------------------

   procedure Register_Module
     (Kernel : access GPS.Kernel.Kernel_Handle_Record'Class)
   is
      Remote : constant String := "/_" & (-"Remote") & '/';
   begin
      Remote_View_Module_Id := new Remote_View_Module_Record;
      Register_Module
        (Module      => Remote_View_Module_Id,
         Kernel      => Kernel,
         Module_Name => "Remote_View");

      Register_Menu
        (Kernel, Remote, -"_Show Remote View", "",
         On_Show_Remote_View'Access);
   end Register_Module;

end Remote_Views;
