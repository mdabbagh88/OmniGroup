// Copyright 1997-2000, 2006 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Id$
// DO NOT MODIFY THIS FILE -- IT IS AUTOGENERATED!
//
// Platform specific defines for marking data and code
// as 'extern'.
//

#ifndef _OWFDEFINES_H
#define _OWFDEFINES_H

//
//  OpenStep/Mach or Rhapsody
//

#if defined(__MACH__)

#ifdef __cplusplus
#define OWF_EXTERN               extern
#define OWF_PRIVATE_EXTERN       __private_extern__
#else
#define OWF_EXTERN               extern
#define OWF_PRIVATE_EXTERN       __private_extern__
#endif


//
//  OpenStep/NT, YellowBox/NT, and YellowBox/95
//

#elif defined(WIN32)

#ifndef _NSBUILDING_OWF_DLL
#define _OWF_WINDOWS_DLL_GOOP       __declspec(dllimport)
#else
#define _OWF_WINDOWS_DLL_GOOP       __declspec(dllexport)
#endif

#ifdef __cplusplus
#define OWF_EXTERN			_OWF_WINDOWS_DLL_GOOP extern
#define OWF_PRIVATE_EXTERN		extern
#else
#define OWF_EXTERN			_OWF_WINDOWS_DLL_GOOP extern
#define OWF_PRIVATE_EXTERN		extern
#endif

//
// Standard UNIX: PDO/Solaris, PDO/HP-UX, GNUstep
//

#elif defined(sun) || defined(hpux) || defined(GNUSTEP)

#ifdef __cplusplus
#  define OWF_EXTERN               extern
#  define OWF_PRIVATE_EXTERN       extern
#else
#  define OWF_EXTERN               extern
#  define OWF_PRIVATE_EXTERN       extern
#endif

#else

#error Do not know how to define extern on this platform

#endif

#endif // _OWFDEFINES_H
