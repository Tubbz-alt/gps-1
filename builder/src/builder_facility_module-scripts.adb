-----------------------------------------------------------------------
--                               G P S                               --
--                                                                   --
--                 Copyright (C) 2008-2009, AdaCore                  --
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
-- a copy of the GNU General Public License along with this library; --
-- if not,  write to the  Free Software Foundation, Inc.,  59 Temple --
-- Place - Suite 330, Boston, MA 02111-1307, USA.                    --
-----------------------------------------------------------------------

with Ada.Strings.Unbounded;      use Ada, Ada.Strings.Unbounded;
with Ada.Unchecked_Deallocation;

with GNAT.OS_Lib;

with GNATCOLL.Scripts;           use GNATCOLL.Scripts;

with Build_Command_Manager;      use Build_Command_Manager;
with Build_Configurations;       use Build_Configurations;
with GPS.Kernel;                 use GPS.Kernel;
with GPS.Kernel.Scripts;         use GPS.Kernel.Scripts;
with GPS.Intl;                   use GPS.Intl;
with String_List_Utils;          use String_List_Utils;

package body Builder_Facility_Module.Scripts is

   ----------------
   --  Constants --
   ----------------

   --  NOTE: these constants must match the names of the predefined targets
   --  registered in builder_support.py.
   Compile_File_Target   : constant String := "Compile File";
   Build_File_Target     : constant String := "Build <current file>";
   Check_Syntax_Target   : constant String := "Check Syntax";
   Check_Semantic_Target : constant String := "Check Semantic";

   --  BuildTarget class

   Target_Name_Cst   : aliased constant String := "target_name";
   Main_Name_Cst     : aliased constant String := "main_name";
   Force_Cst         : aliased constant String := "force";
   File_Cst          : aliased constant String := "file";
   Extra_Args_Cst    : aliased constant String := "extra_args";
   Build_Mode_Cst    : aliased constant String := "build_mode";
   Synchronous_Cst   : aliased constant String := "synchronous";

   Target_Class_Name : constant String := "BuildTarget";

   Constructor_Args : constant Cst_Argument_List :=
     (2 => Target_Name_Cst'Access);

   Execute_Args : constant Cst_Argument_List :=
     (2 => Main_Name_Cst'Access,
      3 => File_Cst'Access,
      4 => Force_Cst'Access,
      5 => Extra_Args_Cst'Access,
      6 => Build_Mode_Cst'Access,
      7 => Synchronous_Cst'Access);

   type Target_Property is new Instance_Property_Record with record
      Target_Name : Unbounded_String;
   end record;
   type Target_Property_Access is access all Target_Property'Class;

   -----------------------
   -- Local subprograms --
   -----------------------

   procedure Shell_Handler
     (Data    : in out Callback_Data'Class;
      Command : String);
   --  Shell command handler

   function Get_Target_Class
     (Kernel : access Kernel_Handle_Record'Class) return Class_Type;
   --  Convenience function to get the target class

   function Get_Target_Name (Inst : Class_Instance) return String;
   --  Convenience function to get the target stored in Inst

   procedure Free (Ar : in out GNAT.OS_Lib.String_List);
   procedure Free (Ar : in out GNAT.OS_Lib.String_List_Access);
   --  Free the memory associate with Ar

   ---------------------
   -- Get_Target_Name --
   ---------------------

   function Get_Target_Name (Inst : Class_Instance) return String is
      T : constant Target_Property_Access := Target_Property_Access
        (Instance_Property'(Get_Data (Inst, Target_Class_Name)));
   begin
      if T = null then
         return "";
      else
         return To_String (T.Target_Name);
      end if;
   end Get_Target_Name;

   ----------------------
   -- Get_Target_Class --
   ----------------------

   function Get_Target_Class (Kernel : access Kernel_Handle_Record'Class)
      return Class_Type is
   begin
      return New_Class (Kernel, Target_Class_Name);
   end Get_Target_Class;

   -------------------
   -- Shell_Handler --
   -------------------

   procedure Shell_Handler
     (Data    : in out Callback_Data'Class;
      Command : String)
   is
      use String_List;
      Target_Class : constant Class_Type :=
                       Get_Target_Class (Get_Kernel (Data));
      Kernel       : constant Kernel_Handle := Get_Kernel (Data);
      Node         : List_Node;
      Extra_Args   : GNAT.OS_Lib.Argument_List_Access;
      Info         : Virtual_File;
   begin
      if Command = Constructor_Method then
         Name_Parameters (Data, Constructor_Args);

         declare
            Inst : constant Class_Instance := Nth_Arg (Data, 1, Target_Class);
            Name : constant String := Nth_Arg (Data, 2);
         begin
            if Name = "" then
               Set_Error_Msg (Data, -"Target name must be specified.");
               return;
            end if;

            --  Verify that the target does exist

            if Get_Target_From_Name (Registry, Name) = null then
               Set_Error_Msg
                 (Data,
                  (-"No target is registered with the name: '") & Name & "'");
            end if;

            Set_Data (Inst, Target_Class_Name, Target_Property'
                        (Target_Name => To_Unbounded_String (Name)));
         end;

      elsif Command = "remove" then
         declare
            Inst : constant Class_Instance := Nth_Arg (Data, 1, Target_Class);
            Name : constant String := Get_Target_Name (Inst);
         begin
            if Name = "" then
               Set_Error_Msg (Data, -"Invalid target");
               return;
            end if;

            Remove_Target (Registry, Name);

            Refresh_Graphical_Elements;
            Save_Targets;
         end;

      elsif Command = "clone" then
         declare
            Inst : constant Class_Instance := Nth_Arg (Data, 1, Target_Class);
            Name : constant String := Get_Target_Name (Inst);
            New_Name     : constant String := Nth_Arg (Data, 2);
            New_Category : constant String := Nth_Arg (Data, 3);
         begin
            if Name = "" then
               Set_Error_Msg (Data, -"Invalid target");
               return;
            end if;

            Duplicate_Target (Registry, Name, New_Name, New_Category);

            Refresh_Graphical_Elements;
            Save_Targets;
         end;

      elsif Command = "execute" then
         Name_Parameters (Data, Execute_Args);

         declare
            Inst        : constant Class_Instance :=
                            Nth_Arg (Data, 1, Target_Class);
            Main        : constant String  := Nth_Arg (Data, 2, "");
            Force       : constant Boolean := Nth_Arg (Data, 4, False);
            Name        : constant String  := Get_Target_Name (Inst);
            Mode        : Dialog_Mode      := Default;
            Build_Mode  : constant String  := Nth_Arg (Data, 6, "");
            Synchronous : constant Boolean := Nth_Arg (Data, 7, True);
            Directory   : constant Filesystem_String := Nth_Arg (Data, 8, "");
            Dir         : Virtual_File := No_File;

         begin
            Info := Get_Data
              (Nth_Arg (Data, 3, Get_File_Class (Kernel), True));

            if Base_Name (Info)'Length = 0 then
               Info := No_File;
            end if;

            if Name = "" then
               Set_Error_Msg (Data, -"Invalid target");
               return;
            end if;

            Extra_Args := GNAT.OS_Lib.Argument_String_To_List
              (Nth_Arg (Data, 5, ""));

            if Force then
               Mode := Force_No_Dialog;
            end if;

            if Directory /= "" then
               Dir := GNATCOLL.VFS.Create (Directory);
            end if;

            Launch_Target (Kernel       => Kernel,
                           Registry     => Registry,
                           Target_Name  => Name,
                           Mode_Name    => Build_Mode,
                           Force_File   => Info,
                           Extra_Args   => Extra_Args,
                           Quiet        => False,
                           Synchronous  => Synchronous,
                           Dialog       => Mode,
                           Main         => Main,
                           Directory    => Dir);
            Free (Extra_Args);
         end;

      elsif Command = "get_build_output" then
         Node := First (Get_Build_Output (Shadow => False));

         Set_Return_Value_As_List (Data);
         while Node /= Null_Node loop
            Set_Return_Value (Data, String_List_Utils.String_List.Data (Node));
            Node := Next (Node);
         end loop;

      elsif Command = "compile" then
         Info := Get_Data (Nth_Arg (Data, 1, Get_File_Class (Kernel)));
         Extra_Args := GNAT.OS_Lib.Argument_String_To_List
           (Nth_Arg (Data, 2, ""));

         Launch_Target (Kernel       => Kernel,
                        Registry     => Registry,
                        Target_Name  => Compile_File_Target,
                        Mode_Name    => "",
                        Force_File   => Info,
                        Extra_Args   => Extra_Args,
                        Quiet        => False,
                        Synchronous  => True,
                        Dialog       => Default,
                        Main         => "");

         Free (Extra_Args);

      elsif Command = "make" then
         Info := Get_Data (Nth_Arg (Data, 1, Get_File_Class (Kernel)));
         Extra_Args := GNAT.OS_Lib.Argument_String_To_List
           (Nth_Arg (Data, 2, ""));

         Launch_Target (Kernel       => Kernel,
                        Registry     => Registry,
                        Target_Name  => Build_File_Target,
                        Mode_Name    => "",
                        Force_File   => Info,
                        Extra_Args   => Extra_Args,
                        Quiet        => False,
                        Synchronous  => True,
                        Dialog       => Default,
                        Main         => "");

         Free (Extra_Args);

      elsif Command = "check_syntax" then
         Info := Get_Data (Nth_Arg (Data, 1, Get_File_Class (Kernel)));
         Launch_Target (Kernel       => Kernel,
                        Registry     => Registry,
                        Target_Name  => Check_Syntax_Target,
                        Force_File   => Info,
                        Mode_Name    => "",
                        Extra_Args   => null,
                        Quiet        => False,
                        Synchronous  => True,
                        Dialog       => Default,
                        Main         => "");

      elsif Command = "check_semantic" then
         Info := Get_Data (Nth_Arg (Data, 1, Get_File_Class (Kernel)));
         Launch_Target (Kernel       => Kernel,
                        Registry     => Registry,
                        Target_Name  => Check_Semantic_Target,
                        Force_File   => Info,
                        Mode_Name    => "",
                        Extra_Args   => null,
                        Quiet        => False,
                        Synchronous  => True,
                        Dialog       => Default,
                        Main         => "");

      elsif Command = "get_build_mode" then
         Set_Return_Value (Data, Get_Mode);

      elsif Command = "set_build_mode" then
         Set_Mode (Nth_Arg (Data, 1, ""));

      end if;
   end Shell_Handler;

   -----------------------
   -- Register_Commands --
   -----------------------

   procedure Register_Commands (Kernel : GPS.Kernel.Kernel_Handle) is
      Target_Class : constant Class_Type := Get_Target_Class (Kernel);
   begin
      Register_Command
        (Kernel, Constructor_Method, 1, 1, Shell_Handler'Access, Target_Class);

      Register_Command
        (Kernel, "remove",
         Minimum_Args => 0,
         Maximum_Args => 0,
         Class        => Target_Class,
         Handler      => Shell_Handler'Access);

      Register_Command
        (Kernel, "clone",
         Minimum_Args => 1,
         Maximum_Args => 2,
         Class        => Target_Class,
         Handler      => Shell_Handler'Access);

      Register_Command
        (Kernel, "execute",
         Minimum_Args => 0,
         Maximum_Args => 8,
         Class        => Target_Class,
         Handler      => Shell_Handler'Access);

      Register_Command
        (Kernel, "get_build_output",
         Handler => Shell_Handler'Access);

      --  File commands

      Register_Command
        (Kernel, "compile",
         Minimum_Args => 0,
         Maximum_Args => 1,
         Class   => Get_File_Class (Kernel),
         Handler      => Shell_Handler'Access);

      Register_Command
        (Kernel, "make",
         Minimum_Args => 0,
         Maximum_Args => 1,
         Class   => Get_File_Class (Kernel),
         Handler      => Shell_Handler'Access);

      Bind_Default_Key (Kernel      => Kernel,
                        Action      => (-"Build Main Number 1"),
                        Default_Key => "F4");
      Bind_Default_Key (Kernel      => Kernel,
                        Action      => -"Custom Build...",
                        Default_Key => "F9");
      Bind_Default_Key (Kernel      => Kernel,
                        Action      => -"Compile File",
                        Default_Key => "shift-F4");

      --  Global commands

      Register_Command (Kernel        => Kernel,
                        Command       => "set_build_mode",
                        Minimum_Args  => 1,
                        Maximum_Args  => 1,
                        Handler       => Shell_Handler'Access);

      Register_Command (Kernel        => Kernel,
                        Command       => "get_build_mode",
                        Minimum_Args  => 0,
                        Maximum_Args  => 0,
                        Handler       => Shell_Handler'Access);
   end Register_Commands;

   ----------
   -- Free --
   ----------

   procedure Free (Ar : in out GNAT.OS_Lib.String_List) is
      use GNAT.OS_Lib;
   begin
      for A in Ar'Range loop
         Free (Ar (A));
      end loop;
   end Free;

   procedure Free (Ar : in out GNAT.OS_Lib.String_List_Access) is
      use GNAT.OS_Lib;
      procedure Free is new Unchecked_Deallocation
          (GNAT.OS_Lib.String_List, GNAT.OS_Lib.String_List_Access);

   begin
      if Ar /= null then
         Free (Ar.all);
         Free (Ar);
      end if;
   end Free;

end Builder_Facility_Module.Scripts;
