{{
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// VGA64 Bitmap Demo
//
// Author: Kwabena W. Agyeman
// Updated: 7/27/2010
// Designed For: P8X32A
// Version: 1.0
//
// Copyright (c) 2010 Kwabena W. Agyeman
// See end of file for terms of use.
//
// Update History:
//
// v1.0 - Original release - 7/27/2010.
//
// Run the program with the specified driver hardware.
//
// Nyamekye,
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
}}

CON

  _clkmode = xtal1 + pll16x
  _xinfreq = 5_000_000

  _pinGroup = 2
  _linePoints = 4

  _horizontalResolution = 320
  _verticalResolution = 200

  QX_10_HScanLineClks = 80_000_000 / 19_110
  QX_10_HSyncPulseClks = QX_10_HScanLineClks / 20
  QX_10_BackPorchClks = QX_10_HScanLineClks / 20
  QX_10_FrontPorchClks = QX_10_HScanLineClks / 20
  QX_10_HActiveVideoClks = QX_10_HScanLineClks - QX_10_HSyncPulseClks - QX_10_BackPorchClks - QX_10_FrontPorchClks
  QX_10_ClksPerPixel = QX_10_HActiveVideoClks / 640
  QX_10_VSyncDelay = 5 * QX_10_HScanLineClks

  HALF_QX_10_ClksPerPixel = QX_10_ClksPerPixel / 2

  Propeller_WaitCnt_Fudge = 544

  QX_VSyncPin = 1
  QX_HSyncPin = 2

  QX_VideoPin = 5

  QX_VSyncMask =  %0010
  QX_HSyncMask =  %0100

  ' TODO: Try testing for opposite state.
  QX_VSyncState = %0000
  QX_HSyncState = %0000

VAR

  word XPoints[_linePoints], YPoints[_linePoints], XPointsDir[_linePoints], YPointsDir[_linePoints]
  long displayBuffer[((_horizontalResolution * _verticalResolution) / 32)]

OBJ

  bmp: "VGA64_BMPEngine.spin"

PUB demo | randomSeed, displayPointer, extraCounter, currentDisplay, lineColor, beamX, beamY, waitX, waitY, offset

  ifnot(bmp.BMPEngineStart(_pinGroup, 1, _horizontalResolution, _verticalResolution, @displayBuffer))
    reboot

  bmp.displayColor(0, bmp#black)
  bmp.displayColor(1, bmp#green)

  dira[0]~~

  ' 45.5 kHz
  'repeat
  '  !outa[0]

  ' 27.2 kHz
  'dira[QX_VSyncPin]~~
  'outa[QX_VSyncPin]~
  'repeat
  '  waitpeq(0, QX_VSyncMask, 0)
  '  !outa[0]

  ' 45.4Hz
  'repeat
  '  waitpeq(QX_VSyncMask, QX_VSyncMask, 0)
  '  !outa[0]'~~
  '  waitpeq(0, QX_VSyncMask, 0)
  '  !outa[0]'~

  ' 19.1 kHz
  'repeat
  '  waitpeq(QX_HSyncMask, QX_HSyncMask, 0)
  '  !outa[0]'~~
  '  '''waitpeq(0, QX_HSyncMask, 0) <- not necessary on HSync
  '  !outa[0]'~

  ' 45.4Hz x2 with indicator
  ' Displays a 12 pixel high blob that could be text.
  ' Appears to slant / at about a 1x:2y slope meaning we're roughly
  ' half a pixel advanced for every line when counting only from VSync.
repeat
  repeat offset from 0 to 1
    repeat beamY from 0 to 14
      waitY := (beamY + 190) * QX_10_HScanLineClks + QX_10_VSyncDelay
      repeat beamX from 0 to 319
        waitX := QX_10_BackPorchClks + (3 * beamX + 3000)
        waitpeq(QX_VSyncMask, QX_VSyncMask, 0)
        'waitpeq(0, QX_VSyncMask, 0)
        outa[0]~~

        bmp.plotPixel(1, beamX, beamY+beamY+offset, @displayBuffer)
        'waitpeq(QX_VSyncMask, QX_VSyncMask, 0)
        waitpeq(0, QX_VSyncMask, 0)
        outa[0]~

        waitcnt(waitX + waitY - Propeller_WaitCnt_Fudge + cnt)

        !outa[0]
        !outa[0]
        lineColor := ina[QX_VideoPin]
        !outa[0]
        bmp.plotPixel(lineColor, beamX, beamY+beamY+offset, @displayBuffer)
        !outa[0]


  randomSeed := cnt
  repeat result from 0 to constant(_linePoints - 1) step 1

    XPoints[result] := ((||(randomSeed?)) // _horizontalResolution)
    YPoints[result] := ((||(randomSeed?)) // _verticalResolution)

    XPointsDir[result] or= ((randomSeed?) & 1)
    YPointsDir[result] or= ((randomSeed?) & 1)

  displayPointer := constant((_horizontalResolution * _verticalResolution) / 32)
  repeat

    bmp.displayWait(1)
    bmp.displayPointer(@displayBuffer[0])
    not currentDisplay
    bmp.displayClear(0, @displayBuffer[displayPointer & currentDisplay])

    repeat result from 0 to constant(_linePoints - 1) step 1

      repeat extraCounter from result to constant(_linePoints - 1) step 1

        line( XPoints[result], {
            } YPoints[result], {
            } XPoints[extraCounter // _linePoints], {
            } YPoints[extraCounter // _linePoints], {
            } 1, @displayBuffer[displayPointer & currentDisplay])

    repeat result from 0 to constant(_linePoints - 1) step 1

      XPointsDir[result] ^= ((XPoints[result] =< 0) ^ (XPoints[result] => constant(_horizontalResolution - 1)))
      XPoints[result] += ((XPointsDir[result]) | 1)

      YPointsDir[result] ^= ((YPoints[result] =< 0) ^ (YPoints[result] => constant(_verticalResolution - 1)))
      YPoints[result] += ((YPointsDir[result]) | 1)

PRI line(x0, y0, x1, y1, lineColor, displayBase) | deltaX, deltaY, x, y, loopError, loopStep

  result := ((||(y1 - y0)) > (||(x1 - x0)))

  if(result)
    swap(@x0, @y0)
    swap(@x1, @y1)

  if(x0 > x1)
    swap(@x0, @x1)
    swap(@y0, @y1)

  deltaX := (x1 - x0)
  deltaY := (||(y1 - y0))
  loopError := (deltax >> 1)
  loopStep := ((y0 => y1) | 1)

  y := y0
  repeat x from x0 to x1 step 1

    if(result)
      bmp.plotPixel(lineColor, y, x, displayBase)
    else
      bmp.plotPixel(lineColor, x, y, displayBase)

    loopError -= deltaY
    if(loopError < 0)
      y += loopStep
      loopError += deltaX

PRI swap(x, y)

  result := long[x]
  long[x] := long[y]
  long[y] := result

{{

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                                                  TERMS OF USE: MIT License
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation
// files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy,
// modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the
// Software is furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all copies or substantial portions of the
// Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE
// WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
// COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
// ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
}}
