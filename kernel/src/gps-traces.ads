------------------------------------------------------------------------------
--                               GNAT Studio                                --
--                                                                          --
--                     Copyright (C) 2018-2019, AdaCore                     --
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

--  Traces configuration and preferences.

with GNATCOLL.Traces;  use GNATCOLL.Traces;
with GNATCOLL.VFS;
with GPS.Kernel;       use GPS.Kernel;

package GPS.Traces is

   procedure Register_Module
     (Kernel : access GPS.Kernel.Kernel_Handle_Record'Class);
   --  Register the Traces module in the list

   procedure Setup_Traces_Config (GPS_Home_Dir : GNATCOLL.VFS.Virtual_File);
   --  Setup the traces configuration file, disabling some verbose external
   --  traces by default (e.g: the LIBADALANG* traces).

end GPS.Traces;
