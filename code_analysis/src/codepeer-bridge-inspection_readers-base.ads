------------------------------------------------------------------------------
--                                  G P S                                   --
--                                                                          --
--                       Copyright (C) 2018, AdaCore                        --
--                                                                          --
-- This is free software;  you can redistribute it  and/or modify it  under --
-- terms of the  GNU General Public License as published  by the Free Soft- --
-- ware  Foundation;  either version 3,  or (at your option) any later ver- --
-- sion.  This software is distributed in the hope  that it will be useful, --
-- but WITHOUT ANY WARRANTY;  without even the implied warranty of MERCHAN- --
-- TABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public --
-- License for  more details.  You should have  received  a copy of the GNU --
-- General  Public  License  distributed  with  this  software;   see  file --
-- COPYING3.  If not, go to http://www.gnu.org/licenses for a complete copy --
-- of the license.                                                          --
------------------------------------------------------------------------------

private package CodePeer.Bridge.Inspection_Readers.Base is

   type Base_Inspection_Reader
     (Kernel : not null GPS.Kernel.Kernel_Handle) is
         limited new Abstract_Inspection_Reader with private;

   function Create_Base_Inspection_Reader
     (Kernel          : not null GPS.Kernel.Kernel_Handle;
      Base_Directory  : GNATCOLL.VFS.Virtual_File;
      Root_Inspection : Code_Analysis.CodePeer_Data_Access;
      Messages        : access CodePeer.Message_Maps.Map)
      return not null Inspection_Reader_Access;

private

   type Base_Inspection_Reader
     (Kernel : not null GPS.Kernel.Kernel_Handle) is
         limited new Abstract_Inspection_Reader with
   record
      Ignore_Depth          : Natural := 0;
      --  Depth of ignore of nested XML elements to be able to load data files
      --  of newer version when GPS module supports.

      Base_Directory        : GNATCOLL.VFS.Virtual_File;
      --  base directory to reconstruct full paths to referenced data files
      --  (values, backtraces, annotations). Added in version 5.

      Root_Inspection       : Code_Analysis.CodePeer_Data_Access;
      Projects              : Code_Analysis.Code_Analysis_Tree;

      Annotation_Categories : Annotation_Category_Maps.Map;
      CWE_Categories        : CWE_Category_Maps.Map;
      Message_Categories    : Message_Category_Maps.Map;
      Messages              : access CodePeer.Message_Maps.Map;

      File_Node             : Code_Analysis.File_Access;
      Subprogram_Node       : Code_Analysis.Subprogram_Access;
      Subprogram_Data       : CodePeer.Subprogram_Data_Access;
      Current_Message       : CodePeer.Message_Access;

      Entry_Point_Map       : Entry_Point_Maps.Map;
      Object_Race           : CodePeer.Object_Race_Information;
      Object_Accesses       : CodePeer.Entry_Point_Object_Access_Information;
      Race_Category         : CodePeer.Message_Category_Access;
   end record;

   overriding procedure Start_Element
     (Self  : in out Base_Inspection_Reader;
      Name  : String;
      Attrs : Sax.Attributes.Attributes'Class);

   overriding procedure End_Element
     (Self  : in out Base_Inspection_Reader;
      Name  : String);

   overriding function Get_Code_Analysis_Tree
     (Self : Base_Inspection_Reader) return Code_Analysis.Code_Analysis_Tree;

   overriding function Get_Race_Category
     (Self : Base_Inspection_Reader) return CodePeer.Message_Category_Access;

   overriding function Get_Annotation_Categories
     (Self : Base_Inspection_Reader) return Annotation_Category_Maps.Map;

end CodePeer.Bridge.Inspection_Readers.Base;
