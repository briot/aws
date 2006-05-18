------------------------------------------------------------------------------
--                              Ada Web Server                              --
--                                                                          --
--                           Copyright (C) 2006                             --
--                                 AdaCore                                  --
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

private package AWS.Config.Utils is

   procedure Set_Parameter
     (Param_Set     : in out Parameter_Set;
      Name          : in     Parameter_Name;
      Value         : in     String;
      Error_Context : in     String);
   --  Set the AWS parameters. Raises Constraint_Error in case of wrong
   --  parameter value. Error_Context should contain additional information
   --  about the parameter. This  message will be added to the Constraint_Error
   --  exception. One way to use Error_Context is to set it with information
   --  about where this parameter come form.

   function Value
     (Item : in String; Error_Context : in String) return Parameter_Name;
   --  Convert string representation of AWS parameter name into Parameter_Name
   --  type.

end AWS.Config.Utils;
