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
with Ada.Unchecked_Deallocation;

with AWS.OS_Lib.Definitions;
with AWS.Utils;

with Interfaces.C.Strings;

with Sockets.Constants;
with Sockets.Naming;
with Sockets.Thin;

with System;

package body AWS.Net.Std is

   use Ada;
   use Interfaces;

   package OSD renames AWS.OS_Lib.Definitions;

   type Socket_Hidden is record
      FD : Sockets.Socket_FD;
   end record;

   procedure Free is
      new Ada.Unchecked_Deallocation (Socket_Hidden, Socket_Hidden_Access);

   procedure Raise_Exception (Errno : in Integer; Routine : in String);
   pragma No_Return (Raise_Exception);
   --  Raise exception Socket_Error with a Message.

   procedure Raise_Exception
     (E       : in Exceptions.Exception_Occurrence;
      Routine : in String);
   pragma No_Return (Raise_Exception);
   --  Raise exception Socket_Error with E's message and a reference to the
   --  routine name.

   function Get_Addr_Info
     (Host  : in String;
      Port  : in Positive;
      Flags : in Interfaces.C.int := 0)
      return OSD.Addr_Info_Access;
   --  Returns the inet address information for the given host and port.
   --  Flags should be used from getaddrinfo C routine.

   procedure Set_Non_Blocking_Mode (Socket : in Socket_Type);
   --  Set the socket to the non-blocking mode.
   --  AWS is not using blocking sockets internally.

   -------------------
   -- Accept_Socket --
   -------------------

   procedure Accept_Socket
     (Socket     : in     Net.Socket_Type'Class;
      New_Socket : in out Socket_Type) is
   begin
      if New_Socket.S = null then
         New_Socket.S := new Socket_Hidden;
      end if;

      --  Check for Accept_Socket timeout.

      Wait_For (Input, Socket);

      Sockets.Accept_Socket
        (Socket_Type (Socket).S.FD, New_Socket.S.FD);

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
      use type C.int;

      Res   : C.int;
      Errno : Integer;
      Info  : constant OSD.Addr_Info_Access
        := Get_Addr_Info (Host, Port, OSD.AI_PASSIVE);
   begin
      if Socket.S = null then
         Socket.S := new Socket_Hidden;

         begin
            Sockets.Socket (Socket.S.FD);
         exception
            when E : Sockets.Socket_Error =>
               Free (Socket.S);
               OSD.FreeAddrInfo (Info);
               Raise_Exception (E, "Bind.Create_Socket");
         end;

         Set_Non_Blocking_Mode (Socket);
      end if;

      Res := Sockets.Thin.C_Bind
        (C.int (Get_FD (Socket)),
         Info.ai_addr,
         C.int (Info.ai_addrlen));

      if Res = Sockets.Thin.Failure then
         Errno := Std.Errno;
         Res := Sockets.Thin.C_Close (C.int (Get_FD (Socket)));
         Free (Socket.S);
         OSD.FreeAddrInfo (Info);
         Raise_Exception (Errno, "Bind.Create_Socket");
      end if;

      OSD.FreeAddrInfo (Info);
   end Bind;

   -------------
   -- Connect --
   -------------

   procedure Connect
     (Socket   : in out Socket_Type;
      Host     : in     String;
      Port     : in     Positive)
   is
      use type C.int;

      Res   : C.int;
      Errno : Integer;
      Info  : constant OSD.Addr_Info_Access := Get_Addr_Info (Host, Port);
   begin
      if Socket.S = null then
         Socket.S := new Socket_Hidden;

         begin
            Sockets.Socket (Socket.S.FD);
         exception
            when E : Sockets.Socket_Error =>
               Free (Socket.S);
               OSD.FreeAddrInfo (Info);
               Raise_Exception (E, "Connect.Create_Socket");
         end;
      end if;

      Set_Non_Blocking_Mode (Socket);

      Res := Sockets.Thin.C_Connect
        (C.int (Get_FD (Socket)),
         Info.ai_addr,
         C.int (Info.ai_addrlen));

      if Res = Sockets.Thin.Failure then
         Errno := Std.Errno;

         if Errno /= Sockets.Constants.Ewouldblock
           and Errno /= Sockets.Constants.Einprogress
         then
            Res := Sockets.Thin.C_Close (C.int (Get_FD (Socket)));
            Free (Socket.S);
            OSD.FreeAddrInfo (Info);
            Raise_Exception (Errno, "Connect");
         end if;
      end if;

      OSD.FreeAddrInfo (Info);

      if not Wait (Socket, (Output => True, Input => False)) (Output) then
         Res := Sockets.Thin.C_Close (C.int (Get_FD (Socket)));
         Free (Socket.S);
         Ada.Exceptions.Raise_Exception
           (Socket_Error'Identity, "Connect timeout.");
      end if;

      Set_Cache (Socket);
   end Connect;

   -----------
   -- Errno --
   -----------

   function Errno return Integer is
   begin
      return Sockets.Thin.Errno;
   end Errno;

   ----------
   -- Free --
   ----------

   procedure Free (Socket : in out Socket_Type) is
   begin
      Free (Socket.S);
      Release_Cache (Socket);
   end Free;

   -------------------
   -- Get_Addr_Info --
   -------------------

   function Get_Addr_Info
     (Host  : in String;
      Port  : in Positive;
      Flags : in Interfaces.C.int := 0)
      return OSD.Addr_Info_Access
   is
      use Interfaces.C;
      use type OSD.Addr_Info_Access;

      C_Node : aliased char_array := To_C (Host);
      P_Node : Strings.chars_ptr;
      C_Serv : aliased char_array := To_C (AWS.Utils.Image (Port));
      Res    : int;
      Result : aliased OSD.Addr_Info_Access;
      Hints  : constant OSD.Addr_Info
        := (ai_family    => Sockets.Constants.Af_Inet,
            ai_socktype  => Sockets.Constants.Sock_Stream,
            ai_protocol  => OSD.IPPROTO_TCP,
            ai_flags     => Flags,
            ai_addrlen   => 0,
            ai_canonname => Strings.Null_Ptr,
            ai_addr      => System.Null_Address,
            ai_next      => null);
   begin
      if Host = "" then
         P_Node := Strings.Null_Ptr;
      else
         P_Node := Strings.To_Chars_Ptr (C_Node'Unchecked_Access);
      end if;

      Res := OSD.GetAddrInfo
               (node    => P_Node,
                service => Strings.To_Chars_Ptr (C_Serv'Unchecked_Access),
                hints   => Hints,
                res     => Result'Access);

      if Res /= 0 then
         Raise_Exception (Errno, "Get_Addr_Info");
      end if;

      return Result;
   end Get_Addr_Info;

   ------------
   -- Get_FD --
   ------------

   function Get_FD (Socket : in Socket_Type) return Integer is
   begin
      return Integer (Sockets.Get_FD (Socket.S.FD));
   end Get_FD;

   -----------------------------
   -- Get_Receive_Buffer_Size --
   -----------------------------

   function Get_Receive_Buffer_Size (Socket : in Socket_Type) return Natural is
      use Sockets;
      Size : Natural;
   begin
      Getsockopt (Socket.S.FD, Optname => SO_RCVBUF, Optval => Size);

      return Size;
   exception
      when E : Sockets.Socket_Error =>
         Raise_Exception (E, "Get_Receive_Buffer_Size");
   end Get_Receive_Buffer_Size;

   ---------------------
   -- Get_Send_Buffer --
   ---------------------

   function Get_Send_Buffer_Size (Socket : in Socket_Type) return Natural is
      use Sockets;
      Size : Natural;
   begin
      Getsockopt (Socket.S.FD, Optname => SO_SNDBUF, Optval => Size);

      return Size;
   exception
      when E : Sockets.Socket_Error =>
         Raise_Exception (E, "Get_Send_Buffer_Size");
   end Get_Send_Buffer_Size;

   ---------------
   -- Host_Name --
   ---------------

   function Host_Name return String is
   begin
      return Sockets.Naming.Host_Name;
   end Host_Name;

   ------------
   -- Listen --
   ------------

   procedure Listen
     (Socket     : in Socket_Type;
      Queue_Size : in Positive := 5) is
   begin
      Sockets.Listen (Socket.S.FD, Queue_Size);
   exception
      when E : Sockets.Socket_Error =>
         Raise_Exception (E, "Listen");
   end Listen;

   ---------------
   -- Peer_Addr --
   ---------------

   function Peer_Addr (Socket : in Socket_Type) return String is
   begin
      return Sockets.Naming.Image
        (Sockets.Naming.Address'
           (Sockets.Naming.Get_Peer_Addr (Socket.S.FD)));
   exception
      when E : others =>
         Raise_Exception (E, "Peer_Addr");
   end Peer_Addr;

   -------------
   -- Pending --
   -------------

   function Pending (Socket : in Socket_Type) return Stream_Element_Count is
      use type C.int;
      Arg : aliased C.int;
      Res : constant C.int := Sockets.Thin.C_Ioctl
                                (C.int (Get_FD (Socket)),
                                 Sockets.Constants.Fionread,
                                 Arg'Unchecked_Access);
   begin
      if Res = Sockets.Thin.Failure then
         Raise_Exception (Errno, "Pending");
      end if;

      return Stream_Element_Count (Arg);
   end Pending;

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

   ---------------------
   -- Raise_Exception --
   ---------------------

   procedure Raise_Exception (Errno : in Integer; Routine : in String) is
   begin
      Ada.Exceptions.Raise_Exception
        (Socket_Error'Identity,
         Routine & " : (error code" & Integer'Image (Errno) & ')');
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

      Sockets.Receive_Some (Socket.S.FD, Data, Last);
   exception
      when E : Sockets.Socket_Error       |
               Sockets.Connection_Closed  |
               Sockets.Connection_Refused => Raise_Exception (E, "Receive");
   end Receive;

   ----------
   -- Send --
   ----------

   procedure Send
     (Socket : in     Socket_Type;
      Data   : in     Stream_Element_Array;
      Last   :    out Stream_Element_Offset)
   is
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
         Errno := Thin.Errno;

         if Errno = Constants.Ewouldblock then
            Last := Data'First - 1;

            return;

         else
            Raise_Exception (Errno, "Send");
         end if;
      end if;

      Last := Data'First - 1 + Stream_Element_Offset (RC);
   end Send;

   ---------------------------
   -- Set_Non_Blocking_Mode --
   ---------------------------

   procedure Set_Non_Blocking_Mode (Socket : in Socket_Type) is
      use Sockets;
      use Interfaces.C;
      Enabled : aliased int := 1;
   begin
      if Thin.C_Ioctl
           (Get_FD (Socket.S.FD),
            Constants.Fionbio,
            Enabled'Access) /= 0
      then
         Ada.Exceptions.Raise_Exception
           (Socket_Error'Identity, "Set_Non_Blocking_Mode");
      end if;
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
      Setsockopt (Socket.S.FD, Optname => SO_RCVBUF, Optval => Size);
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
      Setsockopt (Socket.S.FD, Optname => SO_SNDBUF, Optval => Size);
   exception
      when E : Sockets.Socket_Error =>
         Raise_Exception (E, "Set_Send_Buffer_Size");
   end Set_Send_Buffer_Size;

   --------------
   -- Shutdown --
   --------------

   procedure Shutdown (Socket : in Socket_Type) is
   begin
      Sockets.Shutdown (Socket.S.FD);
   exception
      when E : others =>
         Raise_Exception (E, "Shutdown");
   end Shutdown;

begin
   --  Dummy call for initialize static pointers inside of libwspiapi.a
   --  We should remove this call after remove libwspiapi.a usage.
   --  libwspiapi.a need for support Windows 2000.

   OSD.FreeAddrInfo (Get_Addr_Info ("", 88, OSD.AI_PASSIVE));
end AWS.Net.Std;
