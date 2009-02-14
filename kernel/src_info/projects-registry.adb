-----------------------------------------------------------------------
--                               G P S                               --
--                                                                   --
--                 Copyright (C) 2002-2009, AdaCore                  --
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

with Ada.Calendar;              use Ada.Calendar;
with Ada.Unchecked_Deallocation;
with Ada.Characters.Handling;   use Ada.Characters.Handling;
with Ada.Containers.Doubly_Linked_Lists;
with Ada.Strings.Fixed;         use Ada.Strings.Fixed;

with GNAT.Directory_Operations; use GNAT.Directory_Operations;
with GNAT.OS_Lib;               use GNAT.OS_Lib;
with GNAT.Case_Util;            use GNAT.Case_Util;

with GNATCOLL.Traces;
with GNATCOLL.Utils;            use GNATCOLL.Utils;
with GNATCOLL.VFS;              use GNATCOLL.VFS;
with GNATCOLL.VFS_Utils;        use GNATCOLL.VFS_Utils;

with ALI;
with Namet;                     use Namet;
with Opt;                       use Opt;
with Output;
with Osint;                     use Osint;
with Prj_Output;                use Prj_Output;
with Scans;                     use Scans;
with Snames;                    use Snames;
with Stringt;

with Csets;
with File_Utils;                use File_Utils;
with GPS.Intl;                  use GPS.Intl;
with OS_Utils;                  use OS_Utils;
with Prj.Com;                   use Prj.Com;
with Prj.Env;                   use Prj.Env;
with Prj.Ext;                   use Prj.Ext;
with Prj.PP;                    use Prj.PP;
with Prj.Util;                  use Prj.Util;
with Prj.Part;                  use Prj.Part;
with Prj.Proc;                  use Prj.Proc;
with Prj.Tree;                  use Prj.Tree;
with Prj;                       use Prj;
with Projects.Editor;           use Projects.Editor;
with Remote;                    use Remote;
with Sinput.P;
with String_Hash;
with Traces;                    use Traces;
with Types;                     use Types;

package body Projects.Registry is

   Me      : constant Debug_Handle := Create ("Projects.Registry");
   Me_Gnat : constant Debug_Handle :=
               Create ("Projects.GNAT", GNATCOLL.Traces.Off);

   Project_Backward_Compatibility : constant Boolean := True;
   --  Should be set to true if saved project should be compatible with GNAT
   --  3.15a1, False if they only need to be compatible with GNAT 3.16 >=
   --  20021024

   Keywords_Initialized : Boolean := False;
   --  Whether we have already initialized the Ada keywords list. This is only
   --  used by Is_Valid_Project_Name

   Dummy_Suffix : constant String := "<no suffix defined>";
   --  A dummy suffixes that is used for languages that have either no spec or
   --  no implementation suffix defined.

   package Virtual_File_List is new Ada.Containers.Doubly_Linked_Lists
     (Element_Type => Virtual_File);
   use Virtual_File_List;

   procedure Do_Nothing (Project : in out Project_Type) is null;
   --  Do not free the project (in the hash tables), since it shared by several
   --  entries and several htables

   package Project_Htable is new String_Hash
     (Data_Type      => Project_Type,
      Free_Data      => Do_Nothing,
      Null_Ptr       => No_Project,
      Case_Sensitive => False);
   use Project_Htable.String_Hash_Table;

   type Directory_Dependency is (Direct, As_Parent, None);
   --  The way a directory belongs to the project: either as a direct
   --  dependency, or because one of its subdirs belong to the project, or
   --  doesn't belong at all.

   procedure Do_Nothing (Dep : in out Directory_Dependency) is null;
   package Directory_Htable is new String_Hash
     (Data_Type      => Directory_Dependency,
      Free_Data      => Do_Nothing,
      Null_Ptr       => None,
      Case_Sensitive => Is_Case_Sensitive (Build_Server));
   use Directory_Htable.String_Hash_Table;

   type Source_File_Data is record
      Project   : Project_Type;
      File      : GNATCOLL.VFS.Virtual_File;
      Lang      : Name_Id;
   end record;
   No_Source_File_Data : constant Source_File_Data :=
     (No_Project, GNATCOLL.VFS.No_File, No_Name);
   --   In some case, Lang might be set to Unknown_Language, if the file was
   --   set in the project (for instance through the Source_Files attribute),
   --   but no matching language was found.

   procedure Do_Nothing (Data : in out Source_File_Data) is null;
   package Source_Htable is new String_Hash
     (Data_Type      => Source_File_Data,
      Free_Data      => Do_Nothing,
      Null_Ptr       => No_Source_File_Data,
      Case_Sensitive => Is_Case_Sensitive (Build_Server));
   use Source_Htable.String_Hash_Table;

   procedure Do_Nothing (Name : in out Name_Id) is null;
   package Languages_Htable is new String_Hash
     (Data_Type => Name_Id,
      Free_Data => Do_Nothing,
      Null_Ptr  => No_Name);
   use Languages_Htable.String_Hash_Table;

   procedure Do_Nothing (Bool : in out Boolean) is null;
   package Boolean_Htable is new String_Hash
        (Data_Type => Boolean,
         Free_Data => Do_Nothing,
         Null_Ptr  => False);
   use Boolean_Htable.String_Hash_Table;

   type Naming_Scheme_Record;
   type Naming_Scheme_Access is access Naming_Scheme_Record;
   type Naming_Scheme_Record is record
      Language            : GNAT.Strings.String_Access;
      Default_Spec_Suffix : GNAT.Strings.String_Access;
      Default_Body_Suffix : GNAT.Strings.String_Access;
      Next                : Naming_Scheme_Access;
   end record;

   type Project_Registry_Data is record
      Tree      : Prj.Tree.Project_Node_Tree_Ref;
      View_Tree : Prj.Project_Tree_Ref;
      --  The description of the trees

      Root    : Project_Type := No_Project;
      --  The root of the project hierarchy

      Sources : Source_Htable.String_Hash_Table.HTable;
      --  Index on base source file names, return the managing project

      Directories : Directory_Htable.String_Hash_Table.HTable;
      --  Index on directory name

      Projects : Project_Htable.String_Hash_Table.HTable;
      --  Index on project names. Some project of the hierarchy might not
      --  exist, since the Project_Type are created lazily the first time they
      --  are needed.

      Naming_Schemes : Naming_Scheme_Access;
      --  The list of default naming schemes for the languages known to GPS

      Scenario_Variables : Scenario_Variable_Array_Access;
      --  Cached value of the scenario variables. This should be accessed only
      --  through the function Scenario_Variables, since it needs to be
      --  initialized first.

      Predefined_Object_Path : Filesystem_String_Access;
      --  Predefined object path for the runtime library

      Predefined_Source_Path : Filesystem_String_Access;
      --  Predefined source paths for the runtime library

      Predefined_Source_Files : GNATCOLL.VFS.File_Array_Access;
      --  The list of source files in Predefined_Source_Path

      Xrefs_Subdir : GNAT.Strings.String_Access;
      --  Object dirs subdirectory containing the cross-refs

      Extensions : Languages_Htable.String_Hash_Table.HTable;
      --  The extensions registered for each language

      Timestamp : Ada.Calendar.Time;
      --  Time when we last parsed the project from the disk

      Trusted_Mode : Boolean := True;
      --  Whether we are in trusted mode when recomputing the project view

      --  Implicit dependency on the global htables in the Prj.* packages
   end record;

   procedure Add_Foreign_Source_Files
     (Registry         : Project_Registry;
      Project          : Project_Type;
      Errors           : Put_Line_Access;
      Source_File_List : in out Virtual_File_List.List;
      Seen             : in out Boolean_Htable.String_Hash_Table.HTable);
   --  Add to Project the list of source files for languages other than
   --  Ada. These sources are also cached in the registry.
   --  (Source_File_List, Seen) are preinitialized list of source files for
   --  the current project. They have been initialized from the project manager
   --  structures (currently only Ada files, therefore).

   procedure Reset
     (Registry  : in out Project_Registry;
      View_Only : Boolean);
   --  Reset the contents of the project registry. This should be called only
   --  if a new project is loaded, otherwise no project is accessible to the
   --  application any more.
   --  If View_Only is true, then the projects are not destroyed, but all the
   --  fields related to the current view are reset.

   procedure Create_Environment_Variables (Registry : in out Project_Registry);
   --  Make sure that all the environment variables actually exist (possibly
   --  with their default value). Otherwise, GNAT will not be able to compute
   --  the project view.

   procedure Reset_Environment_Variables (Registry : Project_Registry);
   --  Find all the environment variables for the project, and cache the list
   --  in the registry.
   --  Does nothing if the cache is not empty.

   procedure Parse_Source_Files
     (Registry : in out Project_Registry;
      Errors   : Put_Line_Access);
   --  Find all the source files for the project, and cache them in the
   --  registry.
   --  At the same time, check that the gnatls attribute is coherent between
   --  all projects and subprojects, and memorize the sources in the
   --  hash-table.

   procedure Add_Runtime_Files
     (Registry : in out Project_Registry; Path : Filesystem_String);
   --  Add all runtime files to the caches

   function Normalize_Project_Path
     (Path : Filesystem_String) return Filesystem_String;
   --  Normalize the full path to a project (and make sure the project file
   --  extension is set)

   procedure Canonicalize_File_Names_In_Project (Registry : Project_Registry);
   --  Canonicalize the file and directory names in the project tree, as
   --  needed.

   procedure Canonicalize_File_Names_In_Project
     (Registry : Project_Registry; P : Project_Type);
   --  Canonicalize the file and directory names for a single project

   procedure Unchecked_Free is new Ada.Unchecked_Deallocation
     (Scenario_Variable_Array, Scenario_Variable_Array_Access);
   procedure Unchecked_Free is new Ada.Unchecked_Deallocation
     (Naming_Scheme_Record, Naming_Scheme_Access);

   function String_Elements
     (R : Project_Registry) return Prj.String_Element_Table.Table_Ptr;
   function Array_Elements
     (R : Project_Registry) return Prj.Array_Element_Table.Table_Ptr;
   pragma Inline (String_Elements);
   pragma Inline (Array_Elements);
   --  Return access to the various tables that contain information about the
   --  project

   procedure Do_Subdirs_Cleanup (Registry : Project_Registry);
   --  Cleanup empty subdirs created when opening a project with prj.subdirs
   --  set.

   --------------------
   -- Array_Elements --
   --------------------

   function Array_Elements
     (R : Project_Registry) return Prj.Array_Element_Table.Table_Ptr is
   begin
      return R.Data.View_Tree.Array_Elements.Table;
   end Array_Elements;

   ---------------------
   -- String_Elements --
   ---------------------

   function String_Elements
     (R : Project_Registry) return Prj.String_Element_Table.Table_Ptr is
   begin
      return R.Data.View_Tree.String_Elements.Table;
   end String_Elements;

   ---------------------------
   -- Is_Valid_Project_Name --
   ---------------------------

   function Is_Valid_Project_Name (Name : String) return Boolean is
   begin
      if Name'Length = 0
        or else (Name (Name'First) not in 'a' .. 'z'
                 and then Name (Name'First) not in 'A' .. 'Z')
      then
         return False;
      end if;

      for N in Name'First + 1 .. Name'Last loop
         if Name (N) not in 'a' .. 'z'
           and then Name (N) not in 'A' .. 'Z'
           and then Name (N) not in '0' .. '9'
           and then Name (N) /= '_'
           and then Name (N) /= '.'
         then
            return False;
         end if;
      end loop;

      if not Keywords_Initialized then
         Scans.Initialize_Ada_Keywords;
         Keywords_Initialized := True;
      end if;

      if Is_Keyword_Name (Get_String (Name)) then
         return False;
      end if;

      return True;
   end Is_Valid_Project_Name;

   ----------------------
   -- Set_Trusted_Mode --
   ----------------------

   procedure Set_Trusted_Mode
     (Registry     : Project_Registry'Class;
      Trusted_Mode : Boolean) is
   begin
      Registry.Data.Trusted_Mode := Trusted_Mode;
   end Set_Trusted_Mode;

   ----------------------
   -- Get_Trusted_Mode --
   ----------------------

   function Get_Trusted_Mode
     (Registry : Project_Registry'Class) return Boolean is
   begin
      return Registry.Data.Trusted_Mode;
   end Get_Trusted_Mode;

   ------------------------------------
   -- Reset_Scenario_Variables_Cache --
   ------------------------------------

   procedure Reset_Scenario_Variables_Cache (Registry : Project_Registry) is
   begin
      Unchecked_Free (Registry.Data.Scenario_Variables);
   end Reset_Scenario_Variables_Cache;

   ----------------------
   -- Reset_Name_Table --
   ----------------------

   procedure Reset_Name_Table
     (Registry           : Project_Registry;
      Project            : Project_Type;
      Old_Name, New_Name : String) is
   begin
      if Registry.Data /= null then
         Set (Registry.Data.Projects, New_Name, Project);
         Remove (Registry.Data.Projects, Old_Name);
      end if;
   end Reset_Name_Table;

   --------------------
   -- Unload_Project --
   --------------------

   procedure Unload_Project
     (Registry : Project_Registry; View_Only : Boolean := False)
   is
      Project : Project_Type;
      Iter    : Project_Htable.String_Hash_Table.Iterator;
   begin
      if Registry.Data /= null then
         --  Free all projects

         Get_First (Registry.Data.Projects, Iter);
         loop
            Project := Get_Element (Iter);
            exit when Project = No_Project;

            if View_Only then
               Reset (Project);
            else
               Destroy (Project);
            end if;
            Get_Next (Registry.Data.Projects, Iter);
         end loop;

         if not View_Only then
            Reset (Registry.Data.Projects);
            Prj.Ext.Reset;
            Reset (Registry.Data.View_Tree);
            Prj.Tree.Tree_Private_Part.Projects_Htable.Reset
              (Registry.Data.Tree.Projects_HT);
            Registry.Data.Root := No_Project;
            Sinput.P.Clear_Source_File_Table;
            Sinput.P.Reset_First;
         end if;

         Unchecked_Free (Registry.Data.Predefined_Source_Files);
         Reset (Registry.Data.Sources);
         Reset (Registry.Data.Directories);
         Reset_Scenario_Variables_Cache (Registry);
      end if;
   end Unload_Project;

   -----------
   -- Reset --
   -----------

   procedure Reset
     (Registry  : in out Project_Registry;
      View_Only : Boolean)
   is
      Naming : Naming_Scheme_Access;
   begin
      if Registry.Data /= null then
         Do_Subdirs_Cleanup (Registry);
         Unload_Project (Registry, View_Only);
      else
         Registry.Data           := new Project_Registry_Data;
         Registry.Data.Tree      := new Project_Node_Tree_Data;
         Registry.Data.View_Tree := new Project_Tree_Data;
         Reset (Registry.Data.Sources);
         Reset (Registry.Data.Directories);
      end if;

      if not View_Only then
         Prj.Tree.Initialize (Registry.Data.Tree);
      end if;

      Prj.Initialize (Registry.Data.View_Tree);

      if View_Only then
         Naming := Registry.Data.Naming_Schemes;
         while Naming /= null loop
            declare
               Spec_Suffix : String := Naming.Default_Spec_Suffix.all;
               Body_Suffix : String := Naming.Default_Body_Suffix.all;
            begin
               Canonical_Case_File_Name (Spec_Suffix);
               Canonical_Case_File_Name (Body_Suffix);

               Prj.Register_Default_Naming_Scheme
                 (Language            => Get_String (Naming.Language.all),
                  Default_Spec_Suffix => Get_String (Spec_Suffix),
                  Default_Body_Suffix => Get_String (Body_Suffix),
                  In_Tree             => Registry.Data.View_Tree);
            end;

            Add_Language_Extension
              (Registry, Naming.Language.all, Naming.Default_Spec_Suffix.all);
            Add_Language_Extension
              (Registry, Naming.Language.all, Naming.Default_Body_Suffix.all);
            Naming := Naming.Next;
         end loop;
      end if;
   end Reset;

   ------------------
   -- Load_Or_Find --
   ------------------

   function Load_Or_Find
     (Registry     : Project_Registry;
      Project_Path : Filesystem_String) return Project_Type
   is
      Path : constant Filesystem_String :=
        Base_Name (Project_Path, Project_File_Extension);
      P    : Project_Type;
      Node : Project_Node_Id;
   begin
      Name_Len := Path'Length;
      Name_Buffer (1 .. Name_Len) := +Path;
      P := Get_Project_From_Name (Registry, Name_Find);
      if P = No_Project then
         Sinput.P.Clear_Source_File_Table;
         Sinput.P.Reset_First;
         Prj.Part.Parse (Registry.Data.Tree,
                         Node, +Normalize_Project_Path (Project_Path), True,
                         Store_Comments => True,
                         Is_Config_File => False,
                         Current_Directory => Get_Current_Dir);
         P := Get_Project_From_Name
           (Registry, Prj.Tree.Name_Of (Node, Registry.Data.Tree));
      end if;

      return P;
   end Load_Or_Find;

   ----------------------------
   -- Normalize_Project_Path --
   ----------------------------

   function Normalize_Project_Path
     (Path : Filesystem_String) return Filesystem_String
   is
      function Extension return Filesystem_String;
      --  Return the extension to add to the file name (.gpr if not already
      --  there)

      ---------------
      -- Extension --
      ---------------

      function Extension return Filesystem_String is
      begin
         if File_Extension (Path) /= Project_File_Extension then
            return Project_File_Extension;
         else
            return "";
         end if;
      end Extension;

   begin
      return Normalize_Pathname (Path, Resolve_Links => False) & Extension;
   end Normalize_Project_Path;

   ----------
   -- Load --
   ----------

   procedure Load
     (Registry           : in out Project_Registry;
      Root_Project_Path  : GNATCOLL.VFS.Virtual_File;
      Errors             : Projects.Error_Report;
      New_Project_Loaded : out Boolean;
      Status             : out Boolean)
   is
      procedure Fail (S : String);
      --  Replaces Osint.Fail

      procedure Internal_Load
        (Registry           : in out Project_Registry;
         Root_Project_Path  : GNATCOLL.VFS.Virtual_File;
         Errors             : Projects.Error_Report;
         New_Project_Loaded : out Boolean);
      --  Actual implementation. Reload_If_Errors is used to decide whether
      --  to reload the previous project or not.

      ----------
      -- Fail --
      ----------

      procedure Fail (S : String) is
      begin
         if Errors /= null then
            Errors (S);
         end if;
      end Fail;

      -------------------
      -- Internal_Load --
      -------------------

      procedure Internal_Load
        (Registry           : in out Project_Registry;
         Root_Project_Path  : GNATCOLL.VFS.Virtual_File;
         Errors             : Projects.Error_Report;
         New_Project_Loaded : out Boolean)
      is
         Project          : Project_Node_Id;
         Iter             : Imported_Project_Iterator;
         Timestamp        : Time;
         Success          : Boolean;
         Previous_Project : Virtual_File;
         Previous_Default : Boolean;

      begin
         if Registry.Data /= null
           and then Registry.Data.Root /= No_Project
         then
            Previous_Project := Project_Path (Registry.Data.Root);
            Previous_Default := Projects.Status (Registry.Data.Root) = Default;

         else
            Previous_Project := GNATCOLL.VFS.No_File;
            Previous_Default := False;
         end if;

         if not Is_Regular_File (Root_Project_Path) then
            Trace (Me, "Load: " & (+Full_Name (Root_Project_Path).all)
                   & " is not a regular file");

            if Errors /= null then
               Errors (+Full_Name (Root_Project_Path).all
                       & (-" is not a regular file"));
            end if;

            New_Project_Loaded := False;
            Status := False;
            return;
         end if;

         Trace (Me, "Set project path to "
                & (+Get_Predefined_Project_Path (Registry)));
         Prj.Ext.Set_Project_Path
           (+Get_Predefined_Project_Path (Registry));

         New_Project_Loaded := True;

         --  Use the full path name so that the messages are sent to the result
         --  view.

         Opt.Full_Path_Name_For_Brief_Errors := True;
         Prj_Output.Set_Special_Output (Output.Output_Proc (Errors));
         Reset (Registry, View_Only => False);

         Prj.Com.Fail := Fail'Unrestricted_Access;

         Opt.Follow_Links_For_Files := not Registry.Data.Trusted_Mode;
         Opt.Follow_Links_For_Dirs := Opt.Follow_Links_For_Files;

         Sinput.P.Clear_Source_File_Table;
         Sinput.P.Reset_First;
         Prj.Part.Parse
           (Registry.Data.Tree, Project, +Full_Name (Root_Project_Path).all,
            True, Store_Comments => True, Is_Config_File => False,
            Current_Directory => Get_Current_Dir);
         Prj.Com.Fail := null;

         Opt.Full_Path_Name_For_Brief_Errors := False;

         if Project = Empty_Node then
            Load_Empty_Project (Registry);
            Status := False;
            return;
         end if;

         Registry.Data.Root := Get_Project_From_Name
           (Registry, Prj.Tree.Name_Of (Project, Registry.Data.Tree));
         Unchecked_Free (Registry.Data.Scenario_Variables);

         Set_Status (Registry.Data.Root, From_File);
         Prj_Output.Cancel_Special_Output;

         --  We cannot simply use Clock here, since this returns local time,
         --  and the file timestamps will be returned in GMT, therefore we
         --  won't be able to compare.

         Registry.Data.Timestamp := GNATCOLL.Utils.No_Time;
         Iter := Start (Registry.Data.Root);

         while Current (Iter) /= No_Project loop
            Timestamp := File_Time_Stamp (Project_Path (Current (Iter)));

            if Timestamp > Registry.Data.Timestamp then
               Registry.Data.Timestamp := Timestamp;
            end if;

            Next (Iter);
         end loop;

         if Previous_Default then
            Trace (Me, "Remove default project on disk, no longer used");
            Delete (Previous_Project, Success);
         end if;

         Trace (Me, "End of Load project");

      exception
         when E : others =>
            Trace (Exception_Handle, E);
            Prj_Output.Cancel_Special_Output;
            raise;
      end Internal_Load;

   begin
      --  Activate Traces. They will unfortunately be output on stdout,
      --  but this is a convenient way to at least get them.
      if Active (Me_Gnat) then
         Prj.Current_Verbosity := Prj.High;
      end if;

      Status := True;
      Internal_Load (Registry, Root_Project_Path, Errors, New_Project_Loaded);
   end Load;

   ----------------------
   -- Reload_If_Needed --
   ----------------------

   procedure Reload_If_Needed
     (Registry : in out Project_Registry;
      Errors   : Projects.Error_Report;
      Reloaded : out Boolean)
   is
      Iter               : Imported_Project_Iterator;
      New_Project_Loaded : Boolean;
      Status             : Boolean;
   begin
      Iter     := Start (Registry.Data.Root);
      Reloaded := False;

      while Current (Iter) /= No_Project loop
         if File_Time_Stamp (Project_Path (Current (Iter))) >
           Registry.Data.Timestamp
         then
            Trace (Me, "Reload_If_Needed: timestamp has changed for "
                   & Project_Name (Current (Iter)));
            Reloaded := True;
            exit;
         end if;

         Next (Iter);
      end loop;

      if Reloaded then
         Load
           (Registry           => Registry,
            Root_Project_Path  => Project_Path (Registry.Data.Root),
            Errors             => Errors,
            New_Project_Loaded => New_Project_Loaded,
            Status             => Status);
      else
         Trace (Me, "Reload_If_Needed: nothing to do, timestamp unchanged");
      end if;
   end Reload_If_Needed;

   -------------------------
   -- Load_Custom_Project --
   -------------------------

   procedure Load_Custom_Project
     (Registry : Project_Registry;
      Project  : Project_Type) is
   begin
      Registry.Data.Root := Project;
      Set_Project_Modified (Registry.Data.Root, False);
   end Load_Custom_Project;

   ------------------------
   -- Load_Empty_Project --
   ------------------------

   procedure Load_Empty_Project (Registry : in out Project_Registry) is
   begin
      Reset (Registry, View_Only => False);
      Prj.Tree.Initialize (Registry.Data.Tree);
      Load_Custom_Project
        (Registry, Create_Project (Registry, "empty", Get_Current_Dir));
      Set_Status (Registry.Data.Root, Empty);
   end Load_Empty_Project;

   --------------------
   -- Recompute_View --
   --------------------

   procedure Recompute_View
     (Registry : in out Project_Registry;
      Errors   : Projects.Error_Report)
   is
      Language : constant Name_Id :=
                   Get_String (String (Languages_Attribute));
      Set_As_Incomplete_When_Errors : Boolean := True;
      Current_Dir : constant String := Get_Current_Dir;

      procedure Report_Error
        (S : String; Project : Project_Id; Tree : Project_Tree_Ref);
      --  Handler called when the project parser finds an error

      procedure Normalize_View (Project : Project_Type);
      --  Normalize the view of the project. In particular, make sure the
      --  languages attribute is lower case.
      --  ??? Should this be done directly by the GNAT parser ?

      ------------------
      -- Report_Error --
      ------------------

      procedure Report_Error
        (S : String; Project : Project_Id; Tree : Project_Tree_Ref)
      is
         pragma Unreferenced (Tree);
         P : Project_Type;
      begin
         if Project = Prj.No_Project then
            if Set_As_Incomplete_When_Errors then
               declare
                  Iter : Imported_Project_Iterator :=
                    Start (Registry.Data.Root);
               begin
                  while Current (Iter) /= No_Project loop
                     Set_View_Is_Complete (Current (Iter), False);
                     Next (Iter);
                  end loop;
               end;
            end if;

         else
            P := Get_Project_From_Name (Registry, Project.Name);

            --  Unless we have a warning...
            if Index (S, "Warning") < S'First then
               if Set_As_Incomplete_When_Errors then
                  Set_View_Is_Complete (P, False);
               end if;
            end if;
         end if;

         Trace (Me, "Recompute_View: error " & S);

         if Errors /= null then
            if Project = Prj.No_Project then
               Errors (S);

            elsif Status (Registry.Data.Root) = From_File
              or else Project_Modified (Registry.Data.Root)
            then
               Errors (Project_Name (P) & ": " & S);
            end if;
         end if;
      end Report_Error;

      --------------------
      -- Normalize_View --
      --------------------

      procedure Normalize_View (Project : Project_Type) is
         Var   : constant Variable_Id := Get_View (Project).Decl.Attributes;
         Value : constant Variable_Value :=
                   Value_Of (Language, Var, Registry.Data.View_Tree);
         Lang  : String_List_Id;
      begin
         if Value /= Nil_Variable_Value then
            Lang := Value.Values;
            while Lang /= Nil_String loop
               Get_Name_String (String_Elements (Registry)(Lang).Value);
               To_Lower (Name_Buffer (1 .. Name_Len));
               String_Elements (Registry)(Lang).Value := Name_Find;

               Lang := String_Elements (Registry)(Lang).Next;
            end loop;
         end if;
      end Normalize_View;

      View    : Project_Id;
      Success : Boolean;
      Iter    : Imported_Project_Iterator := Start (Registry.Data.Root);

   begin
      while Current (Iter) /= No_Project loop
         Set_View_Is_Complete (Current (Iter), True);
         Next (Iter);
      end loop;

      Reset (Registry, View_Only => True);

      Unchecked_Free (Registry.Data.Scenario_Variables);

      Create_Environment_Variables (Registry);

      Prj.Proc.Process
        (In_Tree                => Registry.Data.View_Tree,
         Project                => View, Success => Success,
         From_Project_Node      => Registry.Data.Root.Node,
         From_Project_Node_Tree => Registry.Data.Tree,
         Report_Error           => Report_Error'Unrestricted_Access,
         Is_Config_File         => False,
         Current_Dir            => Current_Dir,
         When_No_Sources        => Warning);

      --  Lower case the languages attribute

      Iter := Start (Registry.Data.Root);
      while Current (Iter) /= No_Project loop
         Normalize_View (Current (Iter));
         Next (Iter);
      end loop;

      --  Do not set the project as incomplete if no sources existed for a
      --  given language. Otherwise, a dialog is displayed when editing the
      --  project properties, and this might be confusing for the user.
      Set_As_Incomplete_When_Errors := False;

      Parse_Source_Files (Registry, Report_Error'Unrestricted_Access);

   exception
      --  We can get an unexpected exception (actually Directory_Error) if the
      --  project file's path is invalid, for instance because it was
      --  modified by the user.
      when E : others => Trace (Exception_Handle, E);
   end Recompute_View;

   ------------------------
   -- Parse_Source_Files --
   ------------------------

   procedure Parse_Source_Files
     (Registry : in out Project_Registry;
      Errors   : Put_Line_Access)
   is
      procedure Register_Directory (Directory : Filesystem_String);
      --  Register Directory as belonging to Project.
      --  The parent directories are also registered.

      ------------------------
      -- Register_Directory --
      ------------------------

      procedure Register_Directory (Directory : Filesystem_String) is
         Dir  : constant Filesystem_String := Name_As_Directory (Directory);
         Last : Integer := Dir'Last - 1;
      begin
         Set (Registry.Data.Directories, K => +Dir, E => Direct);

         loop
            while Last >= Dir'First
              and then not OS_Utils.Is_Directory_Separator (Dir (Last))
            loop
               Last := Last - 1;
            end loop;

            Last := Last - 1;

            exit when Last <= Dir'First;

            if Get (Registry.Data.Directories,
                    +Dir (Dir'First .. Last)) /= Direct
            then
               Set (Registry.Data.Directories,
                    K => +Dir (Dir'First .. Last), E => As_Parent);
            end if;
         end loop;
      end Register_Directory;

      Gnatls  : constant String :=
                  Get_Attribute_Value (Registry.Data.Root, Gnatlist_Attribute);
      Iter    : Imported_Project_Iterator := Start (Registry.Data.Root, True);
      Sources : String_List_Id;
      P       : Project_Type;
      Source_Iter : Source_Iterator;
      Source  : Source_Id;
      Seen             : Boolean_Htable.String_Hash_Table.HTable;
      Source_File_List : Virtual_File_List.List;

   begin
      loop
         P := Current (Iter);
         exit when P = No_Project;

         declare
            Ls : constant String :=
              Get_Attribute_Value (P, Gnatlist_Attribute);
         begin
            if Ls /= "" and then Ls /= Gnatls and then Errors /= null then
               Errors
                 (-("Warning: the project attribute IDE.gnatlist doesn't have"
                    & " the same value as in the root project."
                    & " The value """ & Gnatls & """ will be used"),
                  Get_View (P),
                  Registry.Data.View_Tree);
            end if;
         end;

         --  Reset the list of source files for this project. We must not
         --  Free it, since it is now stored in the previous project's instance

         Source_File_List := Virtual_File_List.Empty_List;

         --  Add the directories

         Sources := Get_View (P).Source_Dirs;
         while Sources /= Nil_String loop
            Register_Directory
              (+Get_String (String_Elements (Registry)(Sources).Value));
            Sources := String_Elements (Registry)(Sources).Next;
         end loop;

         Register_Directory (+Get_String (Get_View (P).Object_Directory.Name));
         Register_Directory (+Get_String (Get_View (P).Exec_Directory.Name));

         --  Add the Ada sources that are already in the project.
         --  Convert the names to UTF8 for proper handling in GPS

         Source_Iter := For_Each_Source
           (Registry.Data.View_Tree, Get_View (P));
         loop
            Source := Element (Source_Iter);
            exit when Source = No_Source;

            --  Get the absolute path name for this source
            Get_Name_String (Source.Path.Display_Name);

            declare
               File : constant Virtual_File := Create
                 (+Name_Buffer (1 .. Name_Len));
            begin
               Set (Registry.Data.Sources,
                    K => +Base_Name (File),
                    E => (P, File, Source.Language.Name));

               --  The project manager duplicates files that contain several
               --  units. Only add them once in the project sources.

               if not Get (Seen, +Base_Name (File)) then
                  Append (Source_File_List, File);

                  --  We must set the source has seen so that it does not
                  --  appear twice in the project explorer which happens for
                  --  project that uses both Source_Files and Source_Dirs
                  --  attributes.

                  Set (Seen, +Base_Name (File), True);
               end if;
            end;

            Next (Source_Iter);
         end loop;

         --  Canonicalize the file names in the naming exception lists

         Canonicalize_File_Names_In_Project (Registry);

         --  Add the other languages' files

         Add_Foreign_Source_Files
           (Registry, P, Errors, Source_File_List, Seen);

         Boolean_Htable.String_Hash_Table.Reset (Seen);

         Next (Iter);
      end loop;
   end Parse_Source_Files;

   -----------------------
   -- Add_Runtime_Files --
   -----------------------

   procedure Add_Runtime_Files
     (Registry : in out Project_Registry; Path : Filesystem_String)
   is
      Iter      : Path_Iterator := Start (Path);
      Dir       : Dir_Type;
      File      : String (1 .. 1024);
      Last      : Natural;
      Info      : Source_File_Data;
      VFile     : Virtual_File;
   begin
      while not At_End (Path, Iter) loop
         declare
            Curr : constant Filesystem_String :=
              Name_As_Directory (Current (Path, Iter));
         begin
            if Curr /= "" then
               Open (Dir, +Curr);

               loop
                  Read (Dir, File, Last);
                  exit when Last = 0;

                  if Last > 4
                    and then (File (Last - 3 .. Last) = ".ads"
                              or else File (Last - 3 .. Last) = ".adb")
                  then
                     --  Do not override runtime files that are in the
                     --  current project
                     Info := Get (Registry.Data.Sources, File (1 .. Last));
                     if Info.Lang = No_Name then
                        VFile := Create (Curr & (+File (1 .. Last)));
                        Set (Registry.Data.Sources,
                             K => File (1 .. Last),
                             E => (No_Project, VFile, Name_Ada));
                     end if;
                  end if;
               end loop;

               Close (Dir);
            end if;

         exception
            when Directory_Error =>
               Trace (Me, "Directory_Error while opening " & (+Curr));
         end;

         Iter := Next (Path, Iter);
      end loop;
   end Add_Runtime_Files;

   ----------------------------------------
   -- Canonicalize_File_Names_In_Project --
   ----------------------------------------

   procedure Canonicalize_File_Names_In_Project
     (Registry : Project_Registry; P : Project_Type)
   is
      procedure Process_List (List : Array_Element_Id);
      --  Canonicalize all the files in the given list

      ------------------
      -- Process_List --
      ------------------

      procedure Process_List (List : Array_Element_Id) is
         Arr : Array_Element_Id := List;
         Str : String_List_Id;

      begin
         while Arr /= No_Array_Element loop
            case Array_Elements (Registry)(Arr).Value.Kind is
               when Undefined | Single =>
                  null;  --  Unexpected case, but probably not an error
                  Trace (Me, "Canonicalize_File_Names, error in type");

               when Prj.List =>
                  Str := Array_Elements (Registry)(Arr).Value.Values;
                  while Str /= Nil_String loop
                     Get_Name_String (String_Elements (Registry)(Str).Value);
                     Canonical_Case_File_Name (Name_Buffer (1 .. Name_Len));
                     String_Elements (Registry)(Str).Value := Name_Find;
                     Str := String_Elements (Registry)(Str).Next;
                  end loop;
            end case;

            Arr := Array_Elements (Registry)(Arr).Next;
         end loop;
      end Process_List;

      Naming : constant Naming_Data := Get_View (P).Naming;
   begin
      Process_List (Naming.Implementation_Exceptions);
      Process_List (Naming.Specification_Exceptions);
   end Canonicalize_File_Names_In_Project;

   ----------------------------------------
   -- Canonicalize_File_Names_In_Project --
   ----------------------------------------

   procedure Canonicalize_File_Names_In_Project
     (Registry : Project_Registry)
   is
      Iter : Imported_Project_Iterator := Start (Registry.Data.Root);
      P    : Project_Type;
   begin
      loop
         P := Current (Iter);
         exit when P = No_Project;

         Canonicalize_File_Names_In_Project (Registry, P);

         Next (Iter);
      end loop;
   end Canonicalize_File_Names_In_Project;

   ----------------------------------
   -- Create_Environment_Variables --
   ----------------------------------

   procedure Create_Environment_Variables
     (Registry : in out Project_Registry) is
   begin
      Reset_Environment_Variables (Registry);

      for J in Registry.Data.Scenario_Variables'Range loop
         Ensure_External_Value (Registry.Data.Scenario_Variables (J),
                                Registry.Data.Tree);
      end loop;
   end Create_Environment_Variables;

   ---------------------------------
   -- Reset_Environment_Variables --
   ---------------------------------

   procedure Reset_Environment_Variables (Registry : Project_Registry) is
   begin
      if Registry.Data.Scenario_Variables = null then
         Trace (Me, "Reset_Environment_Variables");
         Registry.Data.Scenario_Variables := new Scenario_Variable_Array'
           (Find_Scenario_Variables
            (Registry.Data.Root, Parse_Imported => True));
      end if;
   end Reset_Environment_Variables;

   ------------------------------
   -- Add_Foreign_Source_Files --
   ------------------------------

   procedure Add_Foreign_Source_Files
     (Registry : Project_Registry;
      Project  : Project_Type;
      Errors   : Put_Line_Access;
      Source_File_List : in out Virtual_File_List.List;
      Seen             : in out Boolean_Htable.String_Hash_Table.HTable)
   is
      Sources_Specified       : Boolean := False;
      Specified_Sources_Count : Natural := 0;

      Languages  : Argument_List := Get_Languages (Project);
      Languages2 : Name_Id_Array (Languages'Range);
      Languages3 : Name_Id_Array (Languages'Range);
      --  The list of languages. Languages2 is a precomputed version of
      --  Languages to speed up string comparison. Languages3's contents is
      --  reset to No_Name if at least one file exists for the given language.
      --  Thus we can easily issue warnings when a language has no file.

      function File_In_Sources (File : String) return Boolean;
      --  Whether File belongs to the list of source files for this project

      procedure Process_Explicit_Source (File : String);
      --  Do the required processing for a source file that has been specified
      --  explicitly by the user, either through Source_Files or
      --  Source_List_File attributes.

      procedure Set_Source_Files;
      --  Set the source file cache of the project

      -----------------------------
      -- Process_Explicit_Source --
      -----------------------------

      procedure Process_Explicit_Source (File : String) is
         Src : Source_File_Data;
      begin
         if Get (Seen, File) then
            return;
         end if;

         Specified_Sources_Count := Specified_Sources_Count + 1;

         Src := Get (Registry.Data.Sources, File);

         if Src.File = GNATCOLL.VFS.No_File then
            Src.File := Create (+File, Project, Use_Object_Path => False);
         end if;

         --  We only add sources that can be found. In case of a debugger
         --  project, it can appears that some of the explicit sources
         --  (returned by the debugger itself) cannot be found (they were
         --  used to compile the run-time for example but are not part of
         --  the compiler distribution).

         if Src.File.Is_Regular_File then
            Append (Source_File_List, Src.File);
            Set (Seen, File, True);
         end if;

         if Src.Lang = No_Name then
            --  Language not found from the project, check the default
            --  list of extensions.

            declare
               Ext : constant String := File_Extension (File);
            begin
               if Ext = "" then
                  --  No extension, use Base_Name to find the
                  --  proper language for this file. This is needed
                  --  for makefile and ChangeLog files for example.
                  Src.Lang := Languages_Htable.String_Hash_Table.Get
                    (Registry.Data.Extensions, To_Lower (File));
               else
                  Src.Lang := Languages_Htable.String_Hash_Table.Get
                    (Registry.Data.Extensions, Ext);
               end if;
            end;
         end if;

         if Src.Lang = Name_Ada then
            --  No warning, this was already processed
            null;

         elsif Src.Project /= No_Project then
            Errors (-("Warning, duplicate source file ") & File
                    & " (already in "
                    & Project_Name (Src.Project) & ')',
                    Get_View (Project),
                   Registry.Data.View_Tree);
         else
            --  Mark this language has having at least one source
            for Index in Languages2'Range loop
               if Languages2 (Index) = Src.Lang then
                  Languages3 (Index) := No_Name;
                  exit;
               end if;
            end loop;

            Src.Project := Project;

            Set (Registry.Data.Sources,
                 K => File,
                 E => Src);
         end if;
      end Process_Explicit_Source;

      ---------------------
      -- File_In_Sources --
      ---------------------

      function File_In_Sources (File : String) return Boolean is
         Data : Source_File_Data;
      begin
         if Sources_Specified then
            Data := Get (Registry.Data.Sources, File);
            return Data.Lang /= No_Name and then Data.Project = Project;
         else
            return True;
         end if;
      end File_In_Sources;

      ----------------------
      -- Set_Source_Files --
      ----------------------

      procedure Set_Source_Files is
         Count   : constant Ada.Containers.Count_Type :=
                     Virtual_File_List.Length (Source_File_List);
         Files   : constant File_Array_Access :=
                     new File_Array (1 .. Natural (Count));
         Current : Cursor := First (Source_File_List);
         J       : Natural := Files'First;
      begin
         while Has_Element (Current) loop
            Files (J) := Element (Current);
            Next (Current);
            J := J + 1;
         end loop;

         Set_Source_Files (Project, Files);
      end Set_Source_Files;

      Dirs      : GNAT.Strings.String_List_Access;
      Dir       : Dir_Type;
      Length    : Natural;
      Buffer    : String (1 .. 2048);
      Lang      : Name_Id;

   begin
      for L in Languages'Range loop
         Languages2 (L) := Get_String (Languages (L).all);
      end loop;

      Languages3 := Languages2;

      --  Nothing to do if the only language is Ada, since this has already
      --  been taken care of.
      --  ??? This is actually wrong in the case of a project created through
      --  the debugger: the runtime files, for instance, were not found yet in
      --  the source dirs, and were not part of the list of source files
      --  returned by the project manager. But when we process the sources
      --  below (Process_Explicit_Source), they get added. Luckily it seems
      --  that gdb never creates an Ada-only project in any case

      if Languages'Length = 0
        or else (Languages'Length = 1
                 and then Languages (Languages'First).all = Ada_String)
      then
         Set_Source_Files;
         Free (Languages);
         return;
      end if;

      --  Preprocess the Source_Files attribute
      --  ??? Should be shared with the project parser (Prj.Nmsc)

      declare
         View    : constant Project_Id := Get_View (Project);
         Sources : constant Variable_Value :=
                     Prj.Util.Value_Of
                       (Name_Source_Files, View.Decl.Attributes,
                        Registry.Data.View_Tree);
         File    : String_List_Id := Sources.Values;

      begin
         if not Sources.Default then
            Sources_Specified := True;

            while File /= Nil_String loop
               Get_Name_String (String_Elements (Registry)(File).Value);
               Process_Explicit_Source (Name_Buffer (1 .. Name_Len));
               File := String_Elements (Registry)(File).Next;
            end loop;
         end if;
      end;

      --  Preprocess the Source_List_File attribute
      --  ??? Should also be shared with the project parser (Prj.Nmsc)

      declare
         View             : constant Project_Id := Get_View (Project);
         Source_List_File : constant Variable_Value :=
                              Prj.Util.Value_Of
                                (Name_Source_List_File, View.Decl.Attributes,
                                 Registry.Data.View_Tree);
         File             : Prj.Util.Text_File;
         Line             : String (1 .. 2000);
         Last             : Natural;

      begin
         if not Source_List_File.Default then
            Sources_Specified := True;

            declare
               F : constant Filesystem_String :=
                     Name_As_Directory
                       (+Get_String (View.Directory.Name)) &
                        (+Get_String (Source_List_File.Value));
            begin
               if Is_Regular_File (F) then
                  Open (File, +F);

                  while not Prj.Util.End_Of_File (File) loop
                     Prj.Util.Get_Line (File, Line, Last);

                     if Last /= 0
                       and then (Last = 1 or else Line (1 .. 2) /= "--")
                     then
                        Process_Explicit_Source (Line (1 .. Last));
                     end if;
                  end loop;

                  Close (File);
               end if;
            end;
         end if;
      end;

      --  ??? Should check locally removed file, but this should really be done
      --  by sharing code with Prj-Nmsc.
      --  Given the implementation in prj-nmsc, does this attribute apply for
      --  languages other than Ada ?

      if not Sources_Specified then
         --  Parse all directories to find the files that match the naming
         --  scheme.

         Dirs := Source_Dirs (Project, False);

         for D in Dirs'Range loop
            Open (Dir, Dirs (D).all);

            loop
               Read (Dir, Buffer, Length);
               exit when Length = 0;

               --  Need to normalize the casing, before we call
               --  File_In_Sources. Unfortunately,
               --  Get_Unit_Part_And_Name_From_Filename will do the same again,
               --  which is slightly inefficient

               --  Convert the file to UTF8

               declare
                  UTF8      : String := Buffer (1 .. Length);
                  Part      : Unit_Part;
                  Unit_Name : Name_Id;
                  File      : Virtual_File;
               begin
                  Canonical_Case_File_Name (UTF8);

                  --  Check if the file is in the list of sources, for this
                  --  project, as specified in the project file.

                  if File_In_Sources (UTF8) then
                     --  First check naming scheme in the project, in case the
                     --  naming scheme overrides GPS's default.

                     Get_Unit_Part_And_Name_From_Filename
                       (+Buffer (1 .. Length), Project, Part, Unit_Name, Lang);

                     --  Check if the returned language belongs to the
                     --  supported languages for the project.

                     if Lang /= No_Name
                       and then Lang /= Name_Ada
                     then
                        for Index in Languages2'Range loop
                           if Languages2 (Index) = Lang then
                              File := Create
                                (+(Dirs (D).all & Buffer (1 .. Length)));
                              Append (Source_File_List, File);

                              Set
                                (Registry.Data.Sources,
                                 K => +Base_Name (File),
                                 E => (Project, File, Lang));

                              Languages3 (Index) := No_Name;
                              exit;
                           end if;
                        end loop;
                     end if;
                  end if;
               end;
            end loop;

            Close (Dir);
         end loop;
      end if;

      Set_Source_Files;

      --  Print error messages for remaining languages

      if not Sources_Specified
        or else Specified_Sources_Count /= 0
      then
         Length := 0;
         for L in Languages2'Range loop
            if Languages3 (L) /= No_Name
              and then Languages3 (L) /= Name_Ada
            then
               Length := Length + Languages (L)'Length + 2;
            end if;
         end loop;

         if Length /= 0 then
            declare
               Error : String (1 .. Length);
               Index : Natural := Error'First;
            begin
               for L in Languages2'Range loop
                  if Languages3 (L) /= No_Name
                    and then Languages3 (L) /= Name_Ada
                  then
                     Error (Index .. Index + Languages (L)'Length + 1) :=
                       Languages (L).all & ", ";
                     Index := Index + Languages (L).all'Length + 2;
                  end if;
               end loop;

               if Errors /= null then
                  Errors (-("Warning, no source files for ")
                          & Error (Error'First .. Error'Last - 2),
                          Get_View (Project),
                          Registry.Data.View_Tree);
               end if;
            end;
         end if;
      end if;

      Free (Languages);
      Free (Dirs);
   end Add_Foreign_Source_Files;

   ------------------------
   -- Scenario_Variables --
   ------------------------

   function Scenario_Variables (Registry : Project_Registry)
      return Projects.Scenario_Variable_Array is
   begin
      Reset_Environment_Variables (Registry);
      return Registry.Data.Scenario_Variables.all;
   end Scenario_Variables;

   ----------------------
   -- Get_Root_Project --
   ----------------------

   function Get_Root_Project (Registry : Project_Registry)
      return Projects.Project_Type is
   begin
      return Registry.Data.Root;
   end Get_Root_Project;

   -----------------------------
   -- Reset_Project_Name_Hash --
   -----------------------------

   procedure Reset_Project_Name_Hash
     (Registry : Project_Registry;
      Name     : Namet.Name_Id) is
   begin
      if Registry.Data /= null then
         Get_Name_String (Name);
         Remove (Registry.Data.Projects, Name_Buffer (1 .. Name_Len));
      end if;
   end Reset_Project_Name_Hash;

   ---------------------------
   -- Get_Project_From_Name --
   ---------------------------

   function Get_Project_From_Name
     (Registry : Project_Registry; Name : Namet.Name_Id) return Project_Type
   is
      P    : Project_Type;
      Node : Project_Node_Id;
   begin
      if Registry.Data = null then
         Trace (Me, "Get_Project_From_Name: Registry not initialized");
         return No_Project;

      else
         Get_Name_String (Name);
         P := Get (Registry.Data.Projects, Name_Buffer (1 .. Name_Len));

         if P = No_Project then
            Node := Prj.Tree.Tree_Private_Part.Projects_Htable.Get
              (Registry.Data.Tree.Projects_HT, Name).Node;

            if Node = Empty_Node then
               P := No_Project;
               Trace (Me, "Get_Project_From_Name: "
                      & Get_String (Name) & " wasn't found");

            else
               Create_From_Node
                 (P, Registry, Registry.Data.Tree,
                  Registry.Data.View_Tree, Node);
               Set (Registry.Data.Projects, Name_Buffer (1 .. Name_Len), P);
            end if;
         end if;

         return P;
      end if;
   end Get_Project_From_Name;

   ---------------------------
   -- Get_Project_From_File --
   ---------------------------

   function Get_Project_From_File
     (Registry          : Project_Registry;
      Source_Filename   : Virtual_File;
      Root_If_Not_Found : Boolean := True)
      return Project_Type
   is
      S : constant Source_File_Data :=
        Get (Registry.Data.Sources, +Base_Name (Source_Filename));
      P : Project_Type := S.Project;
   begin
      --  Make sure the file we found has the same full name, since it might
      --  match a file from the project that has the same base name, but not
      --  belong to the project (FB03-003).

      if S.File /= Source_Filename then
         P := No_Project;
      end if;

      if P = No_Project and then Root_If_Not_Found then
         return Registry.Data.Root;
      end if;
      return P;
   end Get_Project_From_File;

   ---------------------------
   -- Get_Project_From_File --
   ---------------------------

   function Get_Project_From_File
     (Registry          : Project_Registry;
      Base_Name         : Filesystem_String;
      Root_If_Not_Found : Boolean := True)
      return Project_Type
   is
      P : constant Project_Type :=
            Get (Registry.Data.Sources, +Base_Name).Project;
   begin
      if P = No_Project and then Root_If_Not_Found then
         return Registry.Data.Root;
      end if;
      return P;
   end Get_Project_From_File;

   -----------------------------------------
   -- Get_Language_From_File_From_Project --
   -----------------------------------------

   function Get_Language_From_File_From_Project
     (Registry : Project_Registry; Source_Filename : Virtual_File)
      return Namet.Name_Id
   is
      Base_Name : constant String := +GNATCOLL.VFS.Base_Name (Source_Filename);
      S         : constant Source_File_Data :=
                    Get (Registry.Data.Sources, Base_Name);

   begin
      if S = No_Source_File_Data then
         --  This is most probably one of the runtime files.
         --  For now, we simply consider the standard GNAT extensions, although
         --  we should search in the list of registered languages
         --  (language_handlers-gps)

         declare
            Ext : constant String := File_Extension (Base_Name);
         begin
            if Ext = ".ads" or else Ext = ".adb" then
               return Name_Ada;

            elsif Ext = "" then
               --  This is a file without extension like Makefile or
               --  ChangeLog for example. Use the filename to get the proper
               --  language for this file.

               return Languages_Htable.String_Hash_Table.Get
                 (Registry.Data.Extensions, To_Lower (Base_Name));

            else
               --  Try with the top-level project. This contains the default
               --  registered extensions when the languages were registered.
               --  At least, we might be able to display files that don't
               --  directly belong to a project with the appropriate
               --  highlighting.
               --  If there is no root project, this will use the default
               --  naming scheme

               return Languages_Htable.String_Hash_Table.Get
                 (Registry.Data.Extensions, +File_Extension (Source_Filename));
            end if;
         end;

      else
         return S.Lang;
      end if;
   end Get_Language_From_File_From_Project;

   -----------------------------------------
   -- Register_Default_Language_Extension --
   -----------------------------------------

   procedure Register_Default_Language_Extension
     (Registry            : Project_Registry;
      Language_Name       : String;
      Default_Spec_Suffix : String;
      Default_Body_Suffix : String)
   is
      Spec, Impl : String_Access;
   begin
      --  GNAT doesn't allow empty suffixes, and will display an error when
      --  the view is recomputed, in that case. Therefore we substitute dummy
      --  empty suffixes instead

      if Default_Spec_Suffix = "" then
         Spec := new String'(Dummy_Suffix);
      else
         Spec := new String'(Default_Spec_Suffix);
      end if;

      if Default_Body_Suffix = "" then
         Impl := new String'(Dummy_Suffix);
      else
         Impl := new String'(Default_Body_Suffix);
      end if;

      Registry.Data.Naming_Schemes := new Naming_Scheme_Record'
        (Language            => new String'(To_Lower (Language_Name)),
         Default_Spec_Suffix => Spec,
         Default_Body_Suffix => Impl,
         Next                => Registry.Data.Naming_Schemes);
   end Register_Default_Language_Extension;

   ----------------------------
   -- Add_Language_Extension --
   ----------------------------

   procedure Add_Language_Extension
     (Registry      : Project_Registry;
      Language_Name : String;
      Extension     : String)
   is
      Lang : constant Name_Id := Get_String (To_Lower (Language_Name));
      Ext  : String := Extension;
   begin
      Canonical_Case_File_Name (Ext);

      Languages_Htable.String_Hash_Table.Set
        (Registry.Data.Extensions, Ext, Lang);
   end Add_Language_Extension;

   -------------------------------
   -- Get_Registered_Extensions --
   -------------------------------

   function Get_Registered_Extensions
     (Registry      : Project_Registry;
      Language_Name : String) return GNAT.OS_Lib.Argument_List
   is
      Lang  : constant Name_Id := Get_String (To_Lower (Language_Name));
      Iter  : Languages_Htable.String_Hash_Table.Iterator;
      Name  : Name_Id;
      Count : Natural := 0;
   begin
      Get_First (Registry.Data.Extensions, Iter);
      loop
         Name := Get_Element (Iter);
         exit when Name = No_Name;

         if Name = Lang then
            Count := Count + 1;
         end if;

         Get_Next (Registry.Data.Extensions, Iter);
      end loop;

      declare
         Args : Argument_List (1 .. Count);
      begin
         Count := Args'First;
         Get_First (Registry.Data.Extensions, Iter);
         loop
            Name := Get_Element (Iter);
            exit when Name = No_Name;

            if Name = Lang then
               Args (Count) := new String'(Get_Key (Iter));
               Count := Count + 1;
            end if;

            Get_Next (Registry.Data.Extensions, Iter);
         end loop;

         return Args;
      end;
   end Get_Registered_Extensions;

   -------------
   -- Destroy --
   -------------

   procedure Destroy (Registry : in out Project_Registry) is
      procedure Unchecked_Free is new Ada.Unchecked_Deallocation
        (Project_Registry_Data, Project_Registry_Data_Access);
      Naming  : Naming_Scheme_Access;
      Naming2 : Naming_Scheme_Access;
   begin
      Unload_Project (Registry);

      if Registry.Data /= null then
         Naming := Registry.Data.Naming_Schemes;
         while Naming /= null loop
            Free (Naming.Language);
            Free (Naming.Default_Spec_Suffix);
            Free (Naming.Default_Body_Suffix);

            Naming2 := Naming.Next;
            Unchecked_Free (Naming);
            Naming := Naming2;
         end loop;

         Languages_Htable.String_Hash_Table.Reset (Registry.Data.Extensions);
         Free (Registry.Data.Predefined_Source_Path);
         Free (Registry.Data.Predefined_Object_Path);
         Free (Registry.Data.Tree);
         Free (Registry.Data.View_Tree);
         Unchecked_Free (Registry.Data);
      end if;
   end Destroy;

   ------------------
   -- Pretty_Print --
   ------------------

   procedure Pretty_Print
     (Project              : Project_Type;
      Increment            : Positive             := 3;
      Minimize_Empty_Lines : Boolean              := False;
      W_Char               : Prj.PP.Write_Char_Ap := null;
      W_Eol                : Prj.PP.Write_Eol_Ap  := null;
      W_Str                : Prj.PP.Write_Str_Ap  := null) is
   begin
      Pretty_Print
        (Project.Node,
         Project_Registry (Get_Registry (Project)).Data.Tree,
         Increment,
         False,
         Minimize_Empty_Lines,
         W_Char, W_Eol, W_Str,
         Backward_Compatibility => Project_Backward_Compatibility,
         Id                     => Get_View (Project));
   end Pretty_Print;

   ----------------
   -- Initialize --
   ----------------

   procedure Initialize is
   begin
      Namet.Initialize;
      Csets.Initialize;
      Snames.Initialize;

      Name_C_Plus_Plus := Get_String (Cpp_String);
      Any_Attribute_Name := Get_String (Any_Attribute);
   end Initialize;

   --------------
   -- Finalize --
   --------------

   procedure Finalize is
   begin
      Prj.Ext.Reset;
      Namet.Finalize;
      Stringt.Initialize;

      --  ??? Should this be done every time we parse an ali file ?
      ALI.ALIs.Free;
      ALI.Units.Free;
      ALI.Withs.Free;
      ALI.Args.Free;
      ALI.Linker_Options.Free;
      ALI.Sdep.Free;
      ALI.Xref.Free;
   end Finalize;

   ------------
   -- Report --
   ------------

   overriding procedure Report
     (Handler : access Null_Error_Handler_Record;
      Msg     : String)
   is
      pragma Unreferenced (Handler, Msg);
   begin
      null;
   end Report;

   --------------------------------
   -- Get_Predefined_Source_Path --
   --------------------------------

   function Get_Predefined_Source_Path
     (Registry : Project_Registry) return Filesystem_String is
   begin
      if Registry.Data.Predefined_Source_Path /= null then
         return Registry.Data.Predefined_Source_Path.all;
      else
         return "";
      end if;
   end Get_Predefined_Source_Path;

   --------------------------------
   -- Get_Predefined_Object_Path --
   --------------------------------

   function Get_Predefined_Object_Path
     (Registry : Project_Registry) return Filesystem_String is
   begin
      if Registry.Data.Predefined_Object_Path /= null then
         return Registry.Data.Predefined_Object_Path.all;
      else
         return "";
      end if;
   end Get_Predefined_Object_Path;

   ---------------------------------
   -- Get_Predefined_Source_Files --
   ---------------------------------

   function Get_Predefined_Source_Files
     (Registry : Project_Registry) return GNATCOLL.VFS.File_Array_Access is
   begin
      --  ??? A nicer way would be to implement this with a predefined project,
      --  and rely on the project parser to return the source
      --  files. Unfortunately, this doesn't work with the current
      --  implementation of this parser, since one cannot have two separate
      --  project hierarchies at the same time.

      if Registry.Data.Predefined_Source_Files = null then
         Registry.Data.Predefined_Source_Files := Read_Files_From_Dirs
           (Get_Predefined_Source_Path (Registry));
      end if;

      --  Make a copy of the result, so that we can keep a cache in the kernel

      return new File_Array'(Registry.Data.Predefined_Source_Files.all);
   end Get_Predefined_Source_Files;

   --------------------------------
   -- Set_Predefined_Source_Path --
   --------------------------------

   procedure Set_Predefined_Source_Path
     (Registry : in out Project_Registry; Path : Filesystem_String) is
   begin
      Free (Registry.Data.Predefined_Source_Path);
      Registry.Data.Predefined_Source_Path := new Filesystem_String'(Path);

      Unchecked_Free (Registry.Data.Predefined_Source_Files);

      --  ??? We used to initialize the caches with the runtime files, but I
      --  am not sure why this is needed since Get_Full_Path_From_File will do
      --  it just as well anyway, lazily. That speeds up start time in GPS.
      if False then
         Add_Runtime_Files (Registry, Path);
      end if;
   end Set_Predefined_Source_Path;

   --------------------------------
   -- Set_Predefined_Object_Path --
   --------------------------------

   procedure Set_Predefined_Object_Path
     (Registry : in out Project_Registry; Path : Filesystem_String) is
   begin
      Free (Registry.Data.Predefined_Object_Path);
      Registry.Data.Predefined_Object_Path := new Filesystem_String'(Path);
   end Set_Predefined_Object_Path;

   ---------------------------------
   -- Set_Predefined_Project_Path --
   ---------------------------------

   procedure Set_Predefined_Project_Path
     (Registry : in out Project_Registry; Path : Filesystem_String) is
      pragma Unreferenced (Registry);
   begin
      Prj.Ext.Set_Project_Path (+Path);
   end Set_Predefined_Project_Path;

   -----------------------------
   -- Get_Full_Path_From_File --
   -----------------------------

   procedure Get_Full_Path_From_File
     (Registry        : Project_Registry;
      Filename        : Filesystem_String;
      Use_Source_Path : Boolean;
      Use_Object_Path : Boolean;
      Project         : Project_Type := No_Project;
      Create_As_Base_If_Not_Found : Boolean := False;
      File            : out Virtual_File)
   is
      Locale                 : Filesystem_String renames Filename;
      Project2, Real_Project : Project_Type;
      Path                   : Filesystem_String_Access;
      Iterator               : Imported_Project_Iterator;
      Info                   : Source_File_Data := No_Source_File_Data;
      In_Predefined          : Boolean := False;

   begin
      --  First check the cache, so that we always return the same instance
      --  of Virtual_File (thus saving allocation and system calls)

      if Use_Source_Path then
         Info := Get (Registry.Data.Sources, +Filename);

         if Info.Lang = Name_Error then
            --  Not found previously, we do not try again
            File := GNATCOLL.VFS.No_File;
            return;
         end if;

         if Info.File /= GNATCOLL.VFS.No_File then
            File := Info.File;
            return;
         end if;
      end if;

      --  Note: in this procedure, we test project with
      --  Get_View (..) /= Prj.No_Project
      --  rathen than by comparing directly with Projects.No_Project.
      --  This is slightly more efficient

      if Is_Absolute_Path (Filename) then
         File := Create (Normalize_Pathname (Locale, Resolve_Links => False));

      else
         --  If we are editing a project file, check in the loaded tree first
         --  (in case an old copy is kept somewhere in the source or object
         --  path)

         if File_Extension (Locale) = Project_File_Extension
           and then Get_View (Get_Root_Project (Registry)) /= Prj.No_Project
         then
            Iterator := Start (Get_Root_Project (Registry));

            loop
               Project2 := Current (Iterator);
               exit when Project2 = No_Project;

               if +Project_Name (Project2) & Project_File_Extension =
                 Filename
               then
                  File := Project_Path (Project2);
                  return;
               end if;

               Next (Iterator);
            end loop;
         end if;

         --  Otherwise we have a source file

         Real_Project := Get_Project_From_File
           (Registry, Base_Name => Filename, Root_If_Not_Found => True);

         if Project /= No_Project then
            Project2 := Project;
         else
            Project2 := Real_Project;
         end if;

         if Locale /= "" then
            if Get_View (Project2) /= Prj.No_Project then
               if Use_Source_Path then
                  Path := Locate_Regular_File
                    (Locale, Include_Path (Project2, False));
               end if;

               if Path = null and then Use_Object_Path then
                  Path := Locate_Regular_File
                    (Locale, Object_Path (Project2, False));
               end if;
            end if;

            if Get_View (Get_Root_Project (Registry)) /= Prj.No_Project then
               if Path = null and then Use_Source_Path then
                  --  ??? Should not search again in the directories from
                  --  Project2
                  Path := Locate_Regular_File
                    (Locale,
                     Include_Path (Get_Root_Project (Registry), True)
                     & Path_Separator & Get_Predefined_Source_Path (Registry)
                     & Path_Separator & ".");

                  if Path /= null then
                     In_Predefined := True;
                  end if;
               end if;

               if Path = null and then Use_Object_Path then
                  Path := Locate_Regular_File
                    (Locale,
                     Object_Path (Get_Root_Project (Registry), True)
                     & Path_Separator & Get_Predefined_Object_Path (Registry));
               end if;
            end if;
         end if;

         if Path /= null then
            File := Create (Full_Filename => Path.all);
            Free (Path);

            --  If this is one of the source files, we cache the
            --  directory. This significantly speeds up the explorer. If
            --  this is not a source file, not need to cache it, it is a
            --  one-time request most probably.
            --  We do not cache anything if the project was forced, however
            --  since this wouldn't work with extended projects were sources
            --  can be duplicated.

            if In_Predefined then
               --  Make sure the file will be added in the cache. This is
               --  similar to what we used to do when the project is loaded
               --  (initialize the cache with files from the predefined
               --  path, assuming they are Ada), but done lazily

               if Info.Lang = No_Name then
                  Info.Lang := Get_Language_From_File_From_Project
                    (Registry, File);
               end if;

               Info.File := File;
               Info.Project := No_Project;
            end if;

            if Info /= No_Source_File_Data
              and then Project2 = Real_Project
            then
               Info.File := File;
               Set (Registry.Data.Sources, +Filename, Info);
            end if;

            return;

         elsif Project2 = Real_Project then
            --  Still update the cache, to avoid further system calls to
            --  Locate_Regular_File. However, we shouldn't update the cache
            --  if the project was forced, since it might store incorrect
            --  information when we are using extended projects (with duplicate
            --  source files)
            if Use_Source_Path then
               Info := (Project   => Project2,
                        File      => GNATCOLL.VFS.No_File,
                        Lang      => Name_Error);
               Set (Registry.Data.Sources, +Filename, Info);
            end if;
         end if;

         if Create_As_Base_If_Not_Found then
            File := Create (Full_Filename => Filename);
         else
            File := GNATCOLL.VFS.No_File;
         end if;
      end if;
   end Get_Full_Path_From_File;

   ----------------------------------
   -- Directory_Belongs_To_Project --
   ----------------------------------

   function Directory_Belongs_To_Project
     (Registry    : Project_Registry;
      Directory   : Filesystem_String;
      Direct_Only : Boolean := True) return Boolean
   is
      Belong : constant Directory_Dependency :=
                 Get (Registry.Data.Directories,
                      +Name_As_Directory (Directory));
   begin
      return Belong = Direct
        or else (not Direct_Only and then Belong = As_Parent);
   end Directory_Belongs_To_Project;

   ------------
   -- Create --
   ------------

   function Create
     (Name            : Filesystem_String;
      Registry        : Project_Registry'Class;
      Use_Source_Path : Boolean := True;
      Use_Object_Path : Boolean := True) return GNATCOLL.VFS.Virtual_File
   is
   begin
      if Is_Absolute_Path_Or_URL (Name) then
         return Create (Full_Filename => Name);

      else
         declare
            File : Virtual_File;
         begin
            Get_Full_Path_From_File
              (Registry        => Registry,
               Filename        => Name,
               Use_Source_Path => Use_Source_Path,
               Use_Object_Path => Use_Object_Path,
               File            => File);

            if File /= GNATCOLL.VFS.No_File then
               return File;
            end if;
         end;

         --  Else just open the relative paths. This is mostly intended
         --  for files opened from the command line.
         --  ??? To remove convertion to/from UTF8 we need a Normalize_Pathname
         --  which supports UTF-8.
         return Create
           (Full_Filename =>
              (Normalize_Pathname (Name,
                                   Resolve_Links => False)));
      end if;
   end Create;

   ---------------------------------
   -- Get_Predefined_Project_Path --
   ---------------------------------

   function Get_Predefined_Project_Path
     (Registry : Project_Registry) return Filesystem_String
   is
      pragma Unreferenced (Registry);
   begin
      return +Prj.Ext.Project_Path;
   end Get_Predefined_Project_Path;

   ----------------------
   -- Set_Xrefs_Subdir --
   ----------------------

   procedure Set_Xrefs_Subdir
     (Registry : in out Project_Registry; Subdir : Filesystem_String)
   is
   begin
      if Registry.Data.Xrefs_Subdir /= null then
         GNAT.Strings.Free (Registry.Data.Xrefs_Subdir);
      end if;

      if Subdir /= "" then
         Registry.Data.Xrefs_Subdir := new String'(+Subdir);
      end if;
   end Set_Xrefs_Subdir;

   ---------------------
   -- Set_Mode_Subdir --
   ---------------------

   procedure Set_Mode_Subdir
     (Registry : in out Project_Registry; Subdir : Filesystem_String)
   is
   begin
      if Prj.Subdirs /= null then
         Do_Subdirs_Cleanup (Registry);
         Types.Free (Prj.Subdirs);
      end if;

      if Subdir /= "" then
         Prj.Subdirs := new String'(+Subdir);
      end if;
   end Set_Mode_Subdir;

   ----------------------
   -- Get_Xrefs_Subdir --
   ----------------------

   function Get_Xrefs_Subdir
     (Registry : Project_Registry) return Filesystem_String is
   begin
      if Registry.Data.Xrefs_Subdir = null then
         return "";
      end if;

      return +Registry.Data.Xrefs_Subdir.all;
   end Get_Xrefs_Subdir;

   ---------------------
   -- Get_Mode_Subdir --
   ---------------------

   function Get_Mode_Subdir
     (Registry : Project_Registry) return Filesystem_String
   is
      pragma Unreferenced (Registry);
   begin
      if Prj.Subdirs = null then
         return "";
      end if;

      return +Prj.Subdirs.all;
   end Get_Mode_Subdir;

   ------------------------
   -- Do_Subdirs_Cleanup --
   ------------------------

   procedure Do_Subdirs_Cleanup (Registry : Project_Registry) is
      function Get_Paths return Filesystem_String;
      --  Get the list of directories that potentially need cleanup

      function Get_Paths return Filesystem_String is
      begin
         if Registry.Data = null
           or else Get_View (Registry.Data.Root) = Prj.No_Project
         then
            return +Prj.Subdirs.all;
         else
            declare
               Objs : constant String :=
                        Prj.Env.Ada_Objects_Path
                          (Get_View (Registry.Data.Root),
                           Registry.Data.Root.View_Tree).all;
            begin
               if Objs = "" then
                  return +Prj.Subdirs.all;
               else
                  return +Objs;
               end if;
            end;
         end if;
      end Get_Paths;

      Dir_Iter : Path_Iterator;

   begin
      --  Nothing to do if Prj.Subdirs is not set
      if Prj.Subdirs = null then
         return;
      end if;

      declare
         Objs : constant Filesystem_String := Get_Paths;
      begin
         Dir_Iter := Start (Objs);

         while not At_End (Objs, Dir_Iter) loop
            declare
               Dir : constant Filesystem_String := Current (Objs, Dir_Iter);
            begin
               if Dir /= ""
                 and then Is_Directory (Dir)
                 and then Is_Empty (Dir)
               then
                  --  Remove emtpy directories
                  GNAT.Directory_Operations.Remove_Dir (+Dir);
               end if;
            end;

            Dir_Iter := Next (Objs, Dir_Iter);
         end loop;
      end;
   end Do_Subdirs_Cleanup;

   --------------
   -- Get_Tree --
   --------------

   function Get_Tree
     (Registry : Project_Registry) return Project_Node_Tree_Ref
   is
   begin
      return Registry.Data.Tree;
   end Get_Tree;

end Projects.Registry;
