/****************************************************************************
*
*                   VESA Generalized Timing Formula (GTF)
*
*  ========================================================================
*
*                 Copyright 1991-2002 SciTech Software, Inc.
*
*  Permission to use, copy, modify, distribute, and sell this software and its
*  documentation for any purpose is hereby granted without fee, provided that
*  the above copyright notice appear in all copies and that both that
*  copyright notice and this permission notice appear in supporting
*  documentation, and that the name of the authors not be used in
*  advertising or publicity pertaining to distribution of the software without
*  specific, written prior permission.  The authors makes no representations
*  about the suitability of this software for any purpose.  It is provided
*  "as is" without express or implied warranty.
*
*  THE AUTHORS DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE,
*  INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS, IN NO
*  EVENT SHALL THE AUTHORS BE LIABLE FOR ANY SPECIAL, INDIRECT OR
*  CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE,
*  DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER
*  TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR
*  PERFORMANCE OF THIS SOFTWARE.
*
*  ========================================================================
*
* Author:       Kendall Bennett (KendallB@scitechsoft.com)
* Language:     ANSI C
* Environment:  Any
*
* Description:  Header file for generating GTF compatible timings given a
*               set of input requirements. Translated from the original GTF
*               1.14 spreadsheet definition.
*
****************************************************************************/

#ifndef __GTF_H
#define __GTF_H

/*---------------------- Macros and type definitions ----------------------*/

/* Define the structures for holding the horizontal and vertical
 * CRTC parameters for a mode.
 *
 * Note: The sync timings are defined in both VGA compatible timings
 *       (sync start and sync end positions) and also in GTF compatible
 *       modes with the front porch, sync width and back porch defined.
 */

typedef struct {
    int     hTotal;             /* Horizontal total                     */
    int     hDisp;              /* Horizontal displayed                 */
    int     hSyncStart;         /* Horizontal sync start                */
    int     hSyncEnd;           /* Horizontal sync end                  */
    int     hFrontPorch;        /* Horizontal front porch               */
    int     hSyncWidth;         /* Horizontal sync width                */
    int     hBackPorch;         /* Horizontal back porch                */
    } GTF_hCRTC;

typedef struct {
    int     vTotal;             /* Vertical total                       */
    int     vDisp;              /* Vertical displayed                   */
    int     vSyncStart;         /* Vertical sync start                  */
    int     vSyncEnd;           /* Vertical sync end                    */
    int     vFrontPorch;        /* Vertical front porch                 */
    int     vSyncWidth;         /* Vertical sync width                  */
    int     vBackPorch;         /* Vertical back porch                  */
    } GTF_vCRTC;

/* Define the main structure for holding generated GTF timings */

typedef struct {
    GTF_hCRTC   h;              /* Horizontal CRTC paremeters           */
    GTF_vCRTC   v;              /* Vertical CRTC parameters             */
    char        hSyncPol;       /* Horizontal sync polarity             */
    char        vSyncPol;       /* Vertical sync polarity               */
    char        interlace;      /* 'I' for Interlace, 'N' for Non       */
    double      vFreq;          /* Vertical frequency (Hz)              */
    double      hFreq;          /* Horizontal frequency (KHz)           */
    double      dotClock;       /* Pixel clock (Mhz)                    */
    } GTF_timings;

/* Define the structure for holding standard GTF formula constants */

typedef struct {
    double  margin;         /* Margin size as percentage of display     */
    double  cellGran;       /* Character cell granularity               */
    double  minPorch;       /* Minimum front porch in lines/chars       */
    double  vSyncPercent;   /* Width of V sync as percent of total      */
    double  hSyncPercent;   /* Width of H sync as percent of total      */
    double  minVSyncBP;     /* Minimum vertical sync + back porch (us)  */
    double  m;              /* Blanking formula gradient                */
    double  c;              /* Blanking formula offset                  */
    double  k;              /* Blanking formula scaling factor          */
    double  j;              /* Blanking formula scaling factor weight   */
    } GTF_constants;

#define GTF_lockVF  1       /* Lock to vertical frequency               */
#define GTF_lockHF  2       /* Lock to horizontal frequency             */
#define GTF_lockPF  3       /* Lock to pixel clock frequency            */

/*-------------------------- Function Prototypes --------------------------*/

#ifdef  __cplusplus
extern "C" {                        /* Use "C" linkage when in C++ mode */
#endif

/* Generate a set of timings for a mode from the GTF formulas. This will
 * allow you to generate a set of timings by specifying the type as:
 *
 *  1.  Vertical frequency
 *  2.  Horizontal frequency
 *  3.  Pixel clock
 *
 * Generally if you want to find the timings for a specific vertical
 * frequency, you may want to generate a first set of timings given the
 * desired vertical frequency, which will give you a specific horizontal
 * frequency and dot clock. You can then adjust the dot clock to a value
 * that is known to be available on the underlying hardware, and then
 * regenerate the timings for that particular dot clock to determine what
 * the exact final timings will be.
 *
 * Alternatively if you only have a fixed set of dot clocks available such
 * as on older controllers, you can simply run through the set of available
 * dot clocks, and generate a complete set of all available timings that
 * can be generated with the set of available dot clocks (and filter out
 * unuseable values say < 60Hz and > 120Hz).
 */

void GTF_calcTimings(double hPixels,double vLines,double freq,int type,
    int wantMargins,int wantInterlace,GTF_timings *timings);

/* Functions to read and write the current set of GTF formula constants.
 * These constants should be left in the default state that is defined
 * by the current version of the GTF specification. However newer DDC
 * monitos that support the GTF specification may be able to pass back a
 * table of GTF constants to fine tune the GTF timings for their particular
 * requirements.
 */

void GTF_getConstants(GTF_constants *constants);
void GTF_setConstants(GTF_constants *constants);

#ifdef  __cplusplus
}                                   /* End of "C" linkage for C++       */
#endif

#endif  /* __GTF_H */

