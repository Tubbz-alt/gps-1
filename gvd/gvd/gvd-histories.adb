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

with Unchecked_Deallocation;

package body Odd.Histories is

   procedure Free is new Unchecked_Deallocation
     (Data_Type, Data_Access);

   ------------
   -- Append --
   ------------

   procedure Append (History : in out History_List;
                     Data    : Data_Type)
   is
      Prev_Last : constant Integer :=
        (History.Last - 1 + History.Max_Items) mod History.Max_Items;
      --  Index of the last item entered in the list.

   begin
      if History.Collapse_Duplicates
        and then History.Last /= -1
        and then Data = History.Contents (Prev_Last + 1).Data.all
      then
         History.Contents (History.Last).Repeat_Num :=
           History.Contents (History.Last).Repeat_Num + 1;

      else
         --  Free the previous item, if any

         if History.Last = History.First then
            Free (History.Contents (History.Last + 1).Data);
            History.First := (History.First + 1) mod History.Max_Items;
         end if;

         if History.Last = -1 then
            History.Last := History.First;
         end if;

         History.Contents (History.Last + 1) :=
           History_Entry' (Data       => new Data_Type'(Data),
                           Repeat_Num => 1);
         History.Last := (History.Last + 1) mod History.Max_Items;
      end if;

      --  Increment the pointers

      History.Current := -1;
   end Append;

   -----------------
   -- Get_Current --
   -----------------

   function Get_Current (History : History_List) return Data_Type is
   begin
      if History.Current = -1 then
         raise No_Such_Item;
      end if;
      return History.Contents (History.Current + 1).Data.all;
   end Get_Current;

   ----------------------
   -- Move_To_Previous --
   ----------------------

   procedure Move_To_Previous (History : in out History_List) is
   begin
      if History.Last = -1
        or else History.Current = History.First
      then
         return;
      elsif History.Current = -1 then
         History.Current := History.Last;
      end if;

      History.Current := (History.Current - 1 + History.Max_Items)
        mod History.Max_Items;
   end Move_To_Previous;

   ------------------
   -- Move_To_Next --
   ------------------

   procedure Move_To_Next (History : in out History_List) is
   begin
      if History.Current = -1
        or else (History.Current + 1) mod History.Max_Items = History.Last
      then
         History.Current := -1;
         raise No_Such_Item;
      else
         History.Current := (History.Current + 1) mod History.Max_Items;
      end if;
   end Move_To_Next;

   ------------
   -- Rewind --
   ------------

   procedure Rewind  (History : in out History_List) is
   begin
      History.Current := History.First;
   end Rewind;

   ------------
   -- Length --
   ------------

   function Length (History : in History_List) return Integer
   is
   begin
      --  What about Collapse_Duplicates ???
      if History.Last = -1 then
         return 0;
      elsif History.Last > History.First then
         return History.Last - History.First;
      else
         return History.Max_Items + History.Last - History.First;
      end if;
   end Length;

   ----------------------------
   -- Get_Current_Repeat_Num --
   ----------------------------

   function Get_Current_Repeat_Num (History : History_List) return Natural is
   begin
      if History.Current = -1 then
         raise No_Such_Item;
      end if;
      return History.Contents (History.Current + 1).Repeat_Num;
   end Get_Current_Repeat_Num;

end Odd.Histories;
