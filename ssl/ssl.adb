------------------------------------------------------------------------------
--                            Secure Sockets Layer                          --
--                         Binding to OpenSSL library                       --
--                                                                          --
--                         Copyright (C) 2000-2001                          --
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

with Interfaces.C;
with Ada.Exceptions;
with Ada.Strings.Fixed;
with Ada.Calendar;

with SSL.Thin;
with System.Storage_Elements;

package body SSL is

   use Interfaces;
   use type C.int;

   CRLF                 : constant String := ASCII.CR & ASCII.LF;

   Private_Key_Internal : Thin.RSA     := Null_Ptr;
   Context              : Thin.SSL_Ctx := Null_Ptr;

   function Error_Str (Code : in Thin.Error_Code) return String;
   --  Returns error message for Code

   procedure Error_If (Error  : in Boolean;
                       Except : in Ada.Exceptions.Exception_Id);
   --  Raises exception Except if Error is true.

   procedure Init_Random;
   --  Initialize the random number generator for OpenSSL

   procedure Set_Fd (Socket : in out Handle);
   --  Associate a secure socket to Socket

   function Private_Key return Thin.RSA;
   --  Returns the private key that will be used for the certificate.

   -------------------
   -- Accept_Socket --
   -------------------

   procedure Accept_Socket
     (Socket     : in     Sockets.Socket_FD;
      New_Socket :    out Handle) is
   begin
      loop
         Sockets.Accept_Socket (Socket, Sockets.Socket_FD (New_Socket));
         Set_Fd (New_Socket);
         Thin.SSL_Set_Accept_State (New_Socket.H);
         exit when Thin.SSL_Accept (New_Socket.H) > 0;
         Shutdown (New_Socket);
      end loop;
      Set_Read_Ahead (New_Socket, True);
   end Accept_Socket;

   -------------
   -- Connect --
   -------------

   procedure Connect
     (Socket : in Handle;
      Host   : in String;
      Port   : in Positive) is
   begin
      Sockets.Connect (Sockets.Socket_FD (Socket), Host, Port);
      Thin.SSL_Set_Connect_State (Socket.H);
      Error_If (Thin.SSL_Connect (Socket.H) = -1, Lib_Error'Identity);
   end Connect;

   ------------------
   -- Do_Handshake --
   ------------------

   procedure Do_Handshake (Socket : in Handle) is
   begin
      if Socket.H /= Null_Ptr then
         Error_If (Thin.SSL_Do_Handshake (Socket.H) = -1, Lib_Error'Identity);
      end if;
   end Do_Handshake;

   ---------------
   -- Error_Str --
   ---------------

   function Error_Str (Code : in Thin.Error_Code) return String is
      Buffer : C.char_array := (0 .. 511 => Interfaces.C.nul);
   begin
      Thin.Err_Error_String_N (Code, Buffer, Buffer'Length);
      return C.To_Ada (Buffer);
   end Error_Str;

   --------------
   -- Error_If --
   --------------

   procedure Error_If
     (Error  : in Boolean;
      Except : in Ada.Exceptions.Exception_Id)
   is
      use Ada;
   begin
      if Error then
         Exceptions.Raise_Exception (Except, Error_Str (Thin.Err_Get_Error));
      end if;
   end Error_If;

   -----------
   -- Final --
   -----------

   procedure Final is
   begin
      Thin.SSL_Ctx_Free (Context);
      Context := Null_Ptr;
   end Final;

   ----------
   -- Free --
   ----------

   procedure Free (Socket : in out Handle)
   is
   begin
      if Socket.H /= Null_Ptr then
         Thin.SSL_Free (Socket.H);
         Socket.H := Null_Ptr;
      end if;
   end Free;

   ----------
   -- Init --
   ----------

   procedure Init (Meth : in Method) is

      type Meth_Func is access function return Thin.SSL_Method;
      pragma Convention (C, Meth_Func);

      type Methods_Array is array (Method) of Meth_Func;

      Methods : constant Methods_Array :=
        (SSLv2          => Thin.SSLv2_Method'Access,
         SSLv2_Server   => Thin.SSLv2_Server_Method'Access,
         SSLv2_Client   => Thin.SSLv2_Client_Method'Access,
         SSLv23         => Thin.SSLv23_Method'Access,
         SSLv23_Server  => Thin.SSLv23_Server_Method'Access,
         SSLv23_Client  => Thin.SSLv23_Client_Method'Access,
         Tlsv1          => Thin.Tlsv1_Method'Access,
         Tlsv1_Server   => Thin.Tlsv1_Server_Method'Access,
         Tlsv1_Client   => Thin.Tlsv1_Client_Method'Access,
         SSLv3          => Thin.SSLv3_Method'Access,
         SSLv3_Server   => Thin.SSLv3_Server_Method'Access,
         SSLv3_Client   => Thin.SSLv3_Client_Method'Access);
   begin
      if Context /= Null_Ptr then
         Final;
      end if;

      Context := Thin.SSL_Ctx_New (Methods (Meth).all);
      Error_If (Context = Null_Ptr, Lib_Error'Identity);
   end Init;

   -----------------
   -- Init_Random --
   -----------------

   procedure Init_Random is
      use Ada.Calendar;
      use System.Storage_Elements;

      Buf : String
        := Duration'Image
        (Clock - Time_Of (Year  => Year_Number'First,
                          Month => Month_Number'First,
                          Day   => Day_Number'First))
        & Integer_Address'Image (To_Integer (Init_Random'Address));
   begin
      Thin.Rand_Seed (Buf'Address, Buf'Length);
   end Init_Random;

   --------------
   -- New_Line --
   --------------

   procedure New_Line
     (Socket : in Handle;
      Count  : in Natural := 1)
   is
      use Ada.Strings.Fixed;
   begin
      Put (Socket, Count * CRLF);
   end New_Line;

   -------------
   -- Pending --
   -------------

   function Pending (Socket : in Handle) return Boolean is
      Rc : Interfaces.C.int := Thin.SSL_Pending (Socket.H);
   begin
      return Rc /= 0;
   end Pending;

   -----------------
   -- Private_Key --
   -----------------

   function Private_Key return Thin.RSA is
   begin
      if Private_Key_Internal = Null_Ptr then
         Private_Key_Internal :=
           Thin.Rsa_Generate_Key (Bits     => 512,
                                  E        => Thin.Rsa_F4,
                                  Callback => null,
                                  Cb_Arg   => Null_Ptr);
         Error_If (Private_Key_Internal = Null_Ptr, Lib_Error'Identity);
      end if;

      return Private_Key_Internal;
   end Private_Key;

   --------------
   -- Put_Line --
   --------------

   procedure Put_Line (Socket : in Handle; Item : in String) is
   begin
      Put (Socket, Item & CRLF);
   end Put_Line;

   ---------
   -- Put --
   ---------

   procedure Put (Socket : in Handle; Item : in String) is
   begin
      Error_If (Thin.SSL_Write (Socket.H, Item'Address, Item'Length) = -1,
                Lib_Error'Identity);
   end Put;

   -------------
   -- Receive --
   -------------

   function Receive
     (Socket : in Handle;
      Max    : in Ada.Streams.Stream_Element_Count := 4096)
      return Ada.Streams.Stream_Element_Array
   is
      use Ada.Streams; --  Stream_Element_Count;

      Buffer : Stream_Element_Array (0 .. Max - 1);
      Len    : Interfaces.C.int;
   begin
      Len := Thin.SSL_Read (Socket.H, Buffer'Address, Buffer'Length);
      Error_If (Len <= 0, Sockets.Connection_Closed'Identity);

      return Buffer
        (Buffer'First
         .. Buffer'First - 1 + Ada.Streams.Stream_Element_Count (Len));
   end Receive;

   -----------------
   -- Renegotiate --
   -----------------

   procedure Renegotiate (Socket : in Handle) is
   begin
      if Socket.H /= Null_Ptr then
         Error_If (Thin.SSL_Renegotiate (Socket.H) = -1, Lib_Error'Identity);
      end if;
   end Renegotiate;

   ---------------------
   -- Set_Certificate --
   ---------------------

   procedure Set_Certificate
     (Cert_Filename : in String;
      Key_Filename  : in String := "")
   is

      function Key_File_Name return String;
      --  returns the key file (Key_Filename) is it is defined and the
      --  certificate filename (Cert_Filename) otherwise.

      -------------------
      -- Key_File_Name --
      -------------------

      function Key_File_Name return String is
      begin
         if Key_Filename'Length > 0 then
            return Key_Filename;
         else
            return Cert_Filename;
         end if;
      end Key_File_Name;

      use Interfaces.C;

   begin
      Error_If
        (Thin.SSL_Ctx_Use_Privatekey_File
           (Ctx    => Context,
            File   => To_C (Key_File_Name),
            C_Type => Thin.SSL_Filetype_Pem) = -1,
         Lib_Error'Identity);

      Error_If
        (Thin.SSL_Ctx_Use_Certificate_File
           (Ctx    => Context,
            File   => To_C (Cert_Filename),
            C_Type => Thin.SSL_Filetype_Pem) = -1,
         Lib_Error'Identity);

      Error_If (Thin.SSL_Ctx_Check_Private_Key (Ctx  => Context) = -1,
                Lib_Error'Identity);

      if Thin.SSL_Ctx_Ctrl (Ctx  => Context,
                            Cmd  => Thin.SSL_Ctrl_Need_Tmp_Rsa,
                            Larg => 0,
                            Parg => Null_Ptr) /= 0
      then
         Error_If (Thin.SSL_Ctx_Ctrl (Ctx => Context,
                                      Cmd => Thin.SSL_Ctrl_Set_Tmp_Rsa,
                                      Larg => 0,
                                      Parg => Private_Key) = -1,
                   Lib_Error'Identity);
      end if;
   end Set_Certificate;

   ------------
   -- Set_Fd --
   ------------

   procedure Set_Fd (Socket : in out Handle) is
   begin
      if Socket.H = Null_Ptr then
         Socket.H := Thin.SSL_New (Context);
         Error_If (Socket.H = Null_Ptr, Lib_Error'Identity);
      end if;

      Error_If
        (Thin.SSL_Set_Fd (Socket.H,
                          Sockets.Get_FD (Sockets.Socket_FD (Socket))) = -1,
         Lib_Error'Identity);
   end Set_Fd;

   --------------------
   -- Set_Read_Ahead --
   --------------------

   procedure Set_Read_Ahead (Socket : in Handle; Value : in Boolean)  is
   begin
      Thin.SSL_Set_Read_Ahead (S   => Socket.H,
                               Yes => Boolean'Pos (Value));
   end Set_Read_Ahead;

   ------------------------
   -- Set_Quiet_Shutdown --
   ------------------------

   procedure Set_Quiet_Shutdown (Value : in Boolean := True) is
   begin
      Thin.SSL_Ctx_Set_Quiet_Shutdown (Ctx  => Context,
                                       Mode => Boolean'Pos (Value));
   end Set_Quiet_Shutdown;

   -------------------------
   -- Set_Sess_Cache_Size --
   -------------------------

   procedure Set_Sess_Cache_Size (Value : in Natural) is
   begin
      Error_If (Thin.SSL_Ctx_Ctrl (Ctx  => Context,
                                   Cmd  => Thin.SSL_Ctrl_Set_Sess_Cache_Size,
                                   Larg => Interfaces.C.int (Value),
                                   Parg => Null_Ptr) = -1,
                Lib_Error'Identity);
   end Set_Sess_Cache_Size;

   ----------
   -- Send --
   ----------

   procedure Send
     (Socket : in Handle;
      Data   : in Ada.Streams.Stream_Element_Array) is
   begin
      Error_If (Thin.SSL_Write (Socket.H, Data'Address, Data'Length) = -1,
                Lib_Error'Identity);
   end Send;

   --------------
   -- Shutdown --
   --------------

   procedure Shutdown
     (Socket : in out Handle;
      How    : in     Sockets.Shutdown_Type := Sockets.Both)
   is
      use type C.int;

      Shutdown_SSL : constant array (Sockets.Shutdown_Type) of C.int :=
        (Sockets.Receive => Thin.SSL_RECEIVED_SHUTDOWN,
         Sockets.Send    => Thin.SSL_SENT_SHUTDOWN,
         Sockets.Both    => Thin.SSL_SENT_SHUTDOWN
                              + Thin.SSL_RECEIVED_SHUTDOWN);
   begin
      Thin.SSL_Set_Shutdown (Socket.H, Shutdown_SSL (How));
      Sockets.Shutdown (Sockets.Socket_FD (Socket), How);
   end Shutdown;

   ------------
   -- Socket --
   ------------

   procedure Socket
     (Sock   :    out Handle;
      Domain : in     Sockets.Socket_Domain := Sockets.AF_INET;
      Typ    : in     Sockets.Socket_Type   := Sockets.SOCK_STREAM) is
   begin
      Sockets.Socket (Sockets.Socket_FD (Sock), Domain, Typ);
      Set_Fd (Sock);
   end Socket;

begin
   Thin.SSL_Load_Error_Strings;
   Thin.SSL_Library_Init;
   Init_Random;
end SSL;
