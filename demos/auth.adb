------------------------------------------------------------------------------
--                              Ada Web Server                              --
--                                                                          --
--                         Copyright (C) 2000-2001                          --
--                                ACT-Europe                                --
--                                                                          --
--  Authors: Dmitriy Anisimov - Pascal Obry                                 --
--                                                                          --
--  This library is free software; you can redistribute it and/or modify    --
--  it under the terms of the GNU General Public License as published by    --
--  the Free Software Foundation; either version 2 of the License, or (at   --
--  your option) any later version.                                         --
--                                                                          --
--  This library is distributed in the hope that it will be useful, but     --
--  WITHOUT ANY WARRANTY; without even the implied warranty of              --
--  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU       --
--  General Public License for more details.                                --
--                                                                          --
--  You should have received a copy of the GNU General Public License       --
--  along with this library; if not, write to the Free Software Foundation, --
--  Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.          --
--                                                                          --
--  As a special exception, if other files instantiate generics from this   --
--  unit, or you link this unit with other files to produce an executable,  --
--  this  unit  does not  by itself cause  the resulting executable to be   --
--  covered by the GNU General Public License. This exception does not      --
--  however invalidate any other reasons why the executable file  might be  --
--  covered by the  GNU Public License.                                     --
------------------------------------------------------------------------------

--  $Id$

with Ada.Text_IO;

with AWS.Server;
with AWS.Response;
with AWS.Status;

procedure Auth is

   use Ada;

   Is_First : Boolean := True;

   ---------
   -- Get --
   ---------

   function Get (Request : in AWS.Status.Data) return AWS.Response.Data is
   begin
      if Is_First then
         Is_First := False;
         return AWS.Response.Authenticate ("AWS restricted usage");
      else
         return AWS.Response.Build
           ("text/html",
            "<p>Very good !<br>"
            & AWS.Status.Authorization_Name (Request) & "<br>"
            & AWS.Status.Authorization_Password (Request));
      end if;
   end Get;

   WS : AWS.Server.HTTP;

begin
   Text_IO.Put_Line ("AWS " & AWS.Version);
   Text_IO.Put_Line ("Kill me when you want me to stop...");

   AWS.Server.Start (WS, "Auth demo",
                     Port           => 1234,
                     Max_Connection => 10,
                     Callback       => Get'Unrestricted_Access);
end Auth;
