
/*
   $Id$

   This program is used to get some OS specific settings
*/

#include <stdio.h>

#ifdef _WIN32
#define WIN2000SUPPORT
/* We define WIN2000SUPPORT to ensure that executables built with this version
   will run ok on both Win2000 and WinXP.  */
#include <ws2tcpip.h>
#else
#include <sys/poll.h>
#include <sys/socket.h>
#include <netdb.h>
#endif

int
main (void)
{
  const int s_long   = sizeof (long);
  const int s_int    = sizeof (int);
  const int s_short  = sizeof (short);

  const struct addrinfo ai;

  const void *ai_ptr = &ai;

  const int ai_flags_offset     = (void *)&ai.ai_flags     - ai_ptr;
  const int ai_family_offset    = (void *)&ai.ai_family    - ai_ptr;
  const int ai_socktype_offset  = (void *)&ai.ai_socktype  - ai_ptr;
  const int ai_protocol_offset  = (void *)&ai.ai_protocol  - ai_ptr;
  const int ai_addrlen_offset   = (void *)&ai.ai_addrlen   - ai_ptr;
  const int ai_addr_offset      = (void *)&ai.ai_addr      - ai_ptr;
  const int ai_canonname_offset = (void *)&ai.ai_canonname - ai_ptr;
  const int ai_next_offset      = (void *)&ai.ai_next      - ai_ptr;

#ifdef _WIN32
  const char *i_conv      = "Stdcall";
  const int s_nfds_t      = s_long;
  const int s_fd_type     = s_int;
  const int s_events_type = s_short;
  const int v_POLLIN      = 1;
  const int v_POLLPRI     = 2;
  const int v_POLLOUT     = 4;
  const int v_POLLERR     = 8;
  const int v_POLLHUP     = 16;
  const int v_POLLNVAL    = 32;
#else
  const char *i_conv      = "C";
  const struct pollfd v_pollfd;
  const int s_nfds_t      = sizeof (nfds_t);
  const int s_fd_type     = sizeof (v_pollfd.fd);
  const int s_events_type = sizeof (v_pollfd.events);
  const int v_POLLIN      = POLLIN;
  const int v_POLLPRI     = POLLPRI;
  const int v_POLLOUT     = POLLOUT;
  const int v_POLLERR     = POLLERR;
  const int v_POLLHUP     = POLLHUP;
  const int v_POLLNVAL    = POLLNVAL;
#endif

  printf ("\n--  AUTOMATICALLY GENERATED, DO NOT EDIT THIS FILE\n\n");
  printf ("with Interfaces.C.Strings;\n");
  printf ("with System;\n\n");
  printf ("package AWS.OS_Lib.Definitions is\n\n");
  printf ("   use Interfaces;\n\n");

#ifdef _WIN32
  // libpoll.a need for poll call emulation.
  printf ("   pragma Linker_Options (\"-lpoll\");\n");
#ifdef WIN2000SUPPORT
  // libwspiapi.a need for getaddrinfo freeaddrinfo routines in Windows 2000.
  printf ("   pragma Linker_Options (\"-lwspiapi\");\n");
#endif
  // libws2_32.a need for getaddrinfo freeaddrinfo routines in Windows XP/2003.
  printf ("   pragma Linker_Options (\"-lws2_32\");\n\n");
#endif

  /* POLL constants */

  printf ("   POLLIN   : constant := %d;\n", v_POLLIN);
  printf ("   POLLPRI  : constant := %d;\n", v_POLLPRI);
  printf ("   POLLOUT  : constant := %d;\n", v_POLLOUT);
  printf ("   POLLERR  : constant := %d;\n", v_POLLERR);
  printf ("   POLLHUP  : constant := %d;\n", v_POLLHUP);
  printf ("   POLLNVAL : constant := %d;\n\n", v_POLLNVAL);

  /* getaddrinfo constants */

  printf ("   AI_PASSIVE     : constant := %d;\n",   AI_PASSIVE);
  printf ("   AI_CANONNAME   : constant := %d;\n",   AI_CANONNAME);
  printf ("   AI_NUMERICHOST : constant := %d;\n\n", AI_NUMERICHOST);

  /* constants needed for AWS and not defined in AdaSockets */

  printf ("   IPPROTO_TCP : constant := %d;\n\n", IPPROTO_TCP);

  /* nfds_t */

  if (s_nfds_t == s_long)
    printf ("   type nfds_t is new C.unsigned_long;\n\n");
  else
    printf ("   type nfds_t is new C.unsigned;\n\n");

  /* FD_Type */

  if (s_fd_type == s_long) {
    printf ("   type FD_Type is mod 2 ** C.unsigned_long'Size;\n");
    printf ("   for FD_Type'Size use C.unsigned_long'Size;\n\n");
  } else {
    printf ("   type FD_Type is mod 2 ** C.int'Size;\n");
    printf ("   for FD_Type'Size use C.int'Size;\n\n");
  }

  /* Events_Type */

  if (s_events_type == s_long) {
    printf ("   type Events_Type is mod 2 ** C.unsigned_long'Size;\n");
    printf ("   for Events_Type'Size use C.unsigned_long'Size;\n\n");
  } else if (s_events_type == s_int) {
    printf ("   type Events_Type is mod 2 ** C.int'Size;\n");
    printf ("   for Events_Type'Size use C.int'Size;\n\n");
  } else {
    printf ("   type Events_Type is mod 2 ** C.short'Size;\n");
    printf ("   for Events_Type'Size use C.short'Size;\n\n");
  }

  /* Addr_Info */

  if (ai_flags_offset > 0
      || ai_family_offset    >= ai_socktype_offset
      || ai_socktype_offset  >= ai_protocol_offset
      || ai_addrlen_offset   >= ai_addr_offset
      || ai_addrlen_offset   >= ai_canonname_offset
      || ai_addr_offset      >= ai_next_offset
      || ai_canonname_offset >= ai_next_offset)
      //  Broke source code because of
      printf ("   Unexpected addrinfo fields order.");

  printf ("   type Addr_Info;\n");
  printf ("   type Addr_Info_Access is access all Addr_Info;\n\n");

  printf ("   type Addr_Info is record\n");
  printf ("      ai_flags     : C.int;\n");
  printf ("      ai_family    : C.int;\n");
  printf ("      ai_socktype  : C.int;\n");
  printf ("      ai_protocol  : C.int;\n");
  printf ("      ai_addrlen   : C.size_t;\n");

  if (ai_canonname_offset < ai_addr_offset) {
    //  Linux fields order.

    printf ("      ai_canonname : C.Strings.chars_ptr;\n");
    printf ("      ai_addr      : System.Address;\n");
  } else {
    // Win32, FreeBSD, Solaris fields order.

    printf ("      ai_addr      : System.Address;\n");
    printf ("      ai_canonname : C.Strings.chars_ptr;\n");
  }

  printf ("      ai_next      : Addr_Info_Access;\n");
  printf ("   end record;\n");
  printf ("   pragma Convention (C, Addr_Info);\n\n");

  printf ("   function GetAddrInfo\n");
  printf ("     (node    : in     C.Strings.chars_ptr;\n");
  printf ("      service : in     C.Strings.chars_ptr;\n");
  printf ("      hints   : in     Addr_Info;\n");
  printf ("      res     : access Addr_Info_Access)\n");
  printf ("      return C.int;\n\n");

  printf ("   procedure FreeAddrInfo (res : in Addr_Info_Access);\n\n");

  printf ("private\n\n");

#ifdef WIN2000SUPPORT
  printf ("   pragma Import (Stdcall, GetAddrInfo, \"WspiapiGetAddrInfo\");\n");
  printf ("   pragma Import (Stdcall, FreeAddrInfo, \"WspiapiFreeAddrInfo\");\n\n");
#else
  printf ("   pragma Import (%s, GetAddrInfo, \"getaddrinfo\");\n", i_conv);
  printf ("   pragma Import (%s, FreeAddrInfo, \"freeaddrinfo\");\n\n", i_conv);
#endif

  printf ("end AWS.OS_Lib.Definitions;\n");

  return 0;
}
