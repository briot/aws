------------------------------------------------------------------------------
--                              Ada Web Server                              --
--                                                                          --
--                         Copyright (C) 2000-2004                          --
--                                ACT-Europe                                --
--                                                                          --
--  Authors: Dmitriy Anisimkov - Pascal Obry                                --
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

with Ada.Exceptions;
with Ada.Strings.Maps;
with Ada.Unchecked_Deallocation;

pragma Warnings (Off);

--  Ignore warning about portability of the GNAT.Sockets.Thin
--  because we are using only Socket_Errno and it is exists at all main
--  platforms Unix, Windows and VMS.

with GNAT.Sockets.Thin;
with GNAT.Sockets.Constants;

pragma Warnings (On);

with Interfaces.C;

package body AWS.Net.Std is

   use Ada;
   use GNAT;

   type Socket_Hidden is record
      FD  : Sockets.Socket_Type;
   end record;

   procedure Free is
      new Ada.Unchecked_Deallocation (Socket_Hidden, Socket_Hidden_Access);

   procedure Raise_Exception
     (E       : in Exceptions.Exception_Occurrence;
      Routine : in String);
   pragma No_Return (Raise_Exception);
   --  Raise exception Socket_Error with E's message and a reference to the
   --  routine name.

   function Get_Inet_Addr (Host : in String) return Sockets.Inet_Addr_Type;
   pragma Inline (Get_Inet_Addr);
   --  Returns the inet address for the given host.

   procedure Set_Non_Blocking_Mode (Socket : in Socket_Type);
   --  Set the socket to the non-blocking mode.
   --  AWS is not using blocking sockets internally.

   -------------------
   -- Accept_Socket --
   -------------------

   procedure Accept_Socket
     (Socket     : in     Net.Socket_Type'Class;
      New_Socket : in out Socket_Type)
   is
      Sock_Addr : Sockets.Sock_Addr_Type;
   begin
      if New_Socket.S = null then
         New_Socket.S := new Socket_Hidden;
      end if;

      --  Check for Accept_Socket timeout.

      Wait_For (Input, Socket);

      Sockets.Accept_Socket
        (Socket_Type (Socket).S.FD,
         New_Socket.S.FD, Sock_Addr);

      Set_Non_Blocking_Mode (New_Socket);

      Set_Cache (New_Socket);
   exception
      when E : Sockets.Socket_Error =>
         Free (New_Socket);
         Raise_Exception (E, "Accept_Socket");
   end Accept_Socket;

   ----------
   -- Bind --
   ----------

   procedure Bind
     (Socket : in out Socket_Type;
      Port   : in     Natural;
      Host   : in     String := "")
   is
      Inet_Addr : Sockets.Inet_Addr_Type;
   begin
      if Host = "" then
         Inet_Addr := Sockets.Any_Inet_Addr;
      else
         Inet_Addr := Get_Inet_Addr (Host);
      end if;

      if Socket.S = null then
         Socket.S := new Socket_Hidden;
         Sockets.Create_Socket (Socket.S.FD);
         Set_Non_Blocking_Mode (Socket);
      end if;

      Sockets.Bind_Socket
        (Socket.S.FD,
         (Sockets.Family_Inet, Inet_Addr, Sockets.Port_Type (Port)));
   exception
      when E : Sockets.Socket_Error | Sockets.Host_Error =>
         Raise_Exception (E, "Bind");
   end Bind;

   -------------
   -- Connect --
   -------------

   procedure Connect
     (Socket   : in out Socket_Type;
      Host     : in     String;
      Port     : in     Positive)
   is
      Sock_Addr : Sockets.Sock_Addr_Type;

      Close_On_Exception : Boolean := True;
   begin
      if Socket.S = null then
         Socket.S := new Socket_Hidden;

         Close_On_Exception := False;
         Sockets.Create_Socket (Socket.S.FD);
         Close_On_Exception := True;
      end if;

      Sock_Addr := (Sockets.Family_Inet,
                    Get_Inet_Addr (Host),
                    Sockets.Port_Type (Port));

      Sockets.Connect_Socket (Socket.S.FD, Sock_Addr);

      --  GNAT.Sockets does not support non blocking connect,
      --  so we are making socket non-blocking after connect.

      Set_Non_Blocking_Mode (Socket);

      Set_Cache (Socket);
   exception
      when E : Sockets.Socket_Error | Sockets.Host_Error =>
         if Close_On_Exception then
            Sockets.Close_Socket (Socket.S.FD);
         end if;

         Free (Socket);
         Raise_Exception (E, "Connect");
   end Connect;

   -----------
   -- Errno --
   -----------

   function Errno return Integer is
   begin
      return GNAT.Sockets.Thin.Socket_Errno;
   end Errno;

   ----------
   -- Free --
   ----------

   procedure Free (Socket : in out Socket_Type) is
   begin
      Free (Socket.S);
      Release_Cache (Socket);
   end Free;

   ------------
   -- Get_FD --
   ------------

   function Get_FD (Socket : in Socket_Type) return Integer is
   begin
      return Sockets.To_C (Socket.S.FD);
   end Get_FD;

   -------------------
   -- Get_Inet_Addr --
   -------------------

   function Get_Inet_Addr (Host : in String) return Sockets.Inet_Addr_Type is
      use Strings.Maps;
      IP : constant Character_Set := To_Set ("0123456789.");
   begin
      if Is_Subset (To_Set (Host), IP) then
         --  Only numbers, this is an IP address
         return Sockets.Inet_Addr (Host);
      else
         return Sockets.Addresses (Sockets.Get_Host_By_Name (Host), 1);
      end if;
   end Get_Inet_Addr;

   -----------------------------
   -- Get_Receive_Buffer_Size --
   -----------------------------

   function Get_Receive_Buffer_Size (Socket : in Socket_Type) return Natural is
      use Sockets;
   begin
      return Get_Socket_Option (Socket.S.FD, Name => Receive_Buffer).Size;
   exception
      when E : Sockets.Socket_Error =>
         Raise_Exception (E, "Get_Receive_Buffer_Size");
   end Get_Receive_Buffer_Size;

   --------------------------
   -- Get_Send_Buffer_Size --
   --------------------------

   function Get_Send_Buffer_Size (Socket : in Socket_Type) return Natural is
      use Sockets;
   begin
      return Get_Socket_Option (Socket.S.FD, Name => Send_Buffer).Size;
   exception
      when E : Sockets.Socket_Error =>
         Raise_Exception (E, "Get_Send_Buffer_Size");
   end Get_Send_Buffer_Size;

   ---------------
   -- Host_Name --
   ---------------

   function Host_Name return String is
   begin
      return Sockets.Host_Name;
   end Host_Name;

   ------------
   -- Listen --
   ------------

   procedure Listen
     (Socket     : in Socket_Type;
      Queue_Size : in Positive := 5) is
   begin
      Sockets.Listen_Socket (Socket.S.FD, Queue_Size);
   exception
      when E : Sockets.Socket_Error =>
         Raise_Exception (E, "Listen");
   end Listen;

   ---------------
   -- Peer_Addr --
   ---------------

   function Peer_Addr (Socket : in Socket_Type) return String is
      use Sockets;
   begin
      return Image (Get_Peer_Name (Socket.S.FD).Addr);
   exception
      when E : Sockets.Socket_Error =>
         Raise_Exception (E, "Peer_Addr");
   end Peer_Addr;

   ---------------------
   -- Raise_Exception --
   ---------------------

   procedure Raise_Exception
     (E       : in Exceptions.Exception_Occurrence;
      Routine : in String)
   is
      use Ada.Exceptions;
   begin
      Raise_Exception
        (Socket_Error'Identity,
         Message => Routine & " : " & Exception_Message (E));
   end Raise_Exception;

   -------------
   -- Receive --
   -------------

   procedure Receive
     (Socket : in     Socket_Type;
      Data   :    out Stream_Element_Array;
      Last   :    out Stream_Element_Offset) is
   begin
      Wait_For (Input, Socket);

      Sockets.Receive_Socket (Socket.S.FD, Data, Last);

      --  Check if socket closed by peer.

      if Last = Data'First - 1 then
         Ada.Exceptions.Raise_Exception
           (Socket_Error'Identity,
            Message => "Receive : Socket closed by peer.");
      end if;

   exception
      when E : Sockets.Socket_Error =>
         Raise_Exception (E, "Receive");
   end Receive;

   ----------
   -- Send --
   ----------

   procedure Send
     (Socket : in     Socket_Type;
      Data   : in     Stream_Element_Array;
      Last   :    out Stream_Element_Offset)
   is
      use Interfaces;
      use Sockets;
      use type C.int;

      Errno : Integer;
      RC    : C.int;
   begin
      RC := Thin.C_Send
              (C.int (Get_FD (Socket)),
               Data'Address,
               Data'Length,
               0);

      if RC = Thin.Failure then
         Errno := Thin.Socket_Errno;

         if Errno = Constants.EWOULDBLOCK then
            Last := Data'First - 1;

            return;

         else
            Ada.Exceptions.Raise_Exception
              (Socket_Error'Identity,
               Message => "Send error code:" & Integer'Image (Errno));
         end if;
      end if;

      Last := Data'First - 1 + Stream_Element_Offset (RC);
   end Send;

   ---------------------------
   -- Set_Non_Blocking_Mode --
   ---------------------------

   procedure Set_Non_Blocking_Mode (Socket : in Socket_Type) is
      use Sockets;
      Mode : Request_Type (Non_Blocking_IO);
   begin
      Mode.Enabled := True;

      Control_Socket (Socket.S.FD, Mode);
   exception
      when E : Sockets.Socket_Error =>
         Raise_Exception (E, "Set_Non_Blocking_Mode");
   end Set_Non_Blocking_Mode;

   -----------------------------
   -- Set_Receive_Buffer_Size --
   -----------------------------

   procedure Set_Receive_Buffer_Size
     (Socket : in Socket_Type;
      Size   : in Natural)
   is
      use Sockets;
   begin
      Set_Socket_Option (Socket.S.FD, Option => (Receive_Buffer, Size));
   exception
      when E : Sockets.Socket_Error =>
         Raise_Exception (E, "Set_Receive_Buffer_Size");
   end Set_Receive_Buffer_Size;

   --------------------------
   -- Set_Send_Buffer_Size --
   --------------------------

   procedure Set_Send_Buffer_Size
     (Socket : in Socket_Type;
      Size   : in Natural)
   is
      use Sockets;
   begin
      Set_Socket_Option (Socket.S.FD, Option => (Send_Buffer, Size));
   exception
      when E : Sockets.Socket_Error =>
         Raise_Exception (E, "Set_Send_Buffer_Size");
   end Set_Send_Buffer_Size;

   --------------
   -- Shutdown --
   --------------

   procedure Shutdown (Socket : in Socket_Type) is
   begin
      if Socket.S /= null then
         begin
            --  We catch socket exceptions here as we do not want this call to
            --  fail. A shutdown will fail on non connected sockets.

            Sockets.Shutdown_Socket (Socket.S.FD);
         exception
            when Sockets.Socket_Error =>
               null;
         end;

         begin
            --  ??? In some cases the call above fails because the socket
            --  descriptor is not valid (errno = EABF). This happen on
            --  GNU/Linux only and the problem is not fully understood at this
            --  point. We catch the exception here to hide this problem.

            Sockets.Close_Socket (Socket.S.FD);
         exception
            when Sockets.Socket_Error | Constraint_Error =>
               null;
         end;
      end if;
   end Shutdown;

begin
   Sockets.Initialize;
end AWS.Net.Std;
