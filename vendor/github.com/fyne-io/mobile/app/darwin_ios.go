// Copyright 2015 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// +build darwin
// +build ios

package app

/*
#cgo CFLAGS: -x objective-c -DGL_SILENCE_DEPRECATION
#cgo LDFLAGS: -framework Foundation -framework UIKit -framework GLKit -framework OpenGLES -framework QuartzCore -framework UserNotifications
#include <sys/utsname.h>
#include <stdint.h>
#include <pthread.h>
#include <UIKit/UIDevice.h>
#import <GLKit/GLKit.h>

extern struct utsname sysInfo;

void runApp(void);
void makeCurrentContext(GLintptr ctx);
void swapBuffers(GLintptr ctx);
uint64_t threadID();

UIEdgeInsets getDevicePadding();
void showKeyboard();
void hideKeyboard();

void showFileOpenPicker();
void closeFileResource(void* urlPtr);
*/
import "C"
import (
	"log"
	"runtime"
	"strings"
	"sync"
	"time"
	"unsafe"

	"github.com/fyne-io/mobile/event/lifecycle"
	"github.com/fyne-io/mobile/event/paint"
	"github.com/fyne-io/mobile/event/size"
	"github.com/fyne-io/mobile/event/touch"
	"github.com/fyne-io/mobile/geom"
)

var initThreadID uint64

func init() {
	// Lock the goroutine responsible for initialization to an OS thread.
	// This means the goroutine running main (and calling the run function
	// below) is locked to the OS thread that started the program. This is
	// necessary for the correct delivery of UIKit events to the process.
	//
	// A discussion on this topic:
	// https://groups.google.com/forum/#!msg/golang-nuts/IiWZ2hUuLDA/SNKYYZBelsYJ
	runtime.LockOSThread()
	initThreadID = uint64(C.threadID())
}

func main(f func(App)) {
	//if tid := uint64(C.threadID()); tid != initThreadID {
	//	log.Fatalf("app.Run called on thread %d, but app.init ran on %d", tid, initThreadID)
	//}

	go func() {
		f(theApp)
		// TODO(crawshaw): trigger runApp to return
	}()
	C.runApp()
	panic("unexpected return from app.runApp")
}

var pixelsPerPt float32
var screenScale int // [UIScreen mainScreen].scale, either 1, 2, or 3.

var DisplayMetrics struct{
	WidthPx int
	HeightPx int
}

//export setDisplayMetrics
func setDisplayMetrics(width, height int, scale int) {
	DisplayMetrics.WidthPx = width * scale
	DisplayMetrics.HeightPx = height * scale
}

//export setScreen
func setScreen(scale int) {
	C.uname(&C.sysInfo)
	name := C.GoString(&C.sysInfo.machine[0])

	var v float32

	switch {
	case strings.HasPrefix(name, "iPhone"):
		v = 163
	case strings.HasPrefix(name, "iPad"):
		// TODO: is there a better way to distinguish the iPad Mini?
		switch name {
		case "iPad2,5", "iPad2,6", "iPad2,7", "iPad4,4", "iPad4,5", "iPad4,6", "iPad4,7":
			v = 163 // iPad Mini
		default:
			v = 132
		}
	default:
		v = 163 // names like i386 and x86_64 are the simulator
	}

	if v == 0 {
		log.Printf("unknown machine: %s", name)
		v = 163 // emergency fallback
	}

	pixelsPerPt = v * float32(scale) / 72
	screenScale = scale
}

//export updateConfig
func updateConfig(width, height, orientation int32) {
	o := size.OrientationUnknown
	switch orientation {
	case C.UIDeviceOrientationPortrait, C.UIDeviceOrientationPortraitUpsideDown:
		o = size.OrientationPortrait
	case C.UIDeviceOrientationLandscapeLeft, C.UIDeviceOrientationLandscapeRight:
		o = size.OrientationLandscape
	}
	widthPx := screenScale * int(width)
	heightPx := screenScale * int(height)
	insets := C.getDevicePadding()

	theApp.eventsIn <- size.Event{
		WidthPx:       widthPx,
		HeightPx:      heightPx,
		WidthPt:       geom.Pt(float32(widthPx) / pixelsPerPt),
		HeightPt:      geom.Pt(float32(heightPx) / pixelsPerPt),
		InsetTopPx:    int(float32(insets.top) * float32(screenScale)),
		InsetBottomPx: int(float32(insets.bottom) * float32(screenScale)),
		InsetLeftPx:   int(float32(insets.left) * float32(screenScale)),
		InsetRightPx:  int(float32(insets.right) * float32(screenScale)),
		PixelsPerPt:   pixelsPerPt,
		Orientation:   o,
	}
	theApp.eventsIn <- paint.Event{External: true}
}

// touchIDs is the current active touches. The position in the array
// is the ID, the value is the UITouch* pointer value.
//
// It is widely reported that the iPhone can handle up to 5 simultaneous
// touch events, while the iPad can handle 11.
var touchIDs [11]uintptr

var touchEvents struct {
	sync.Mutex
	pending []touch.Event
}

//export sendTouch
func sendTouch(cTouch, cTouchType uintptr, x, y float32) {
	id := -1
	for i, val := range touchIDs {
		if val == cTouch {
			id = i
			break
		}
	}
	if id == -1 {
		for i, val := range touchIDs {
			if val == 0 {
				touchIDs[i] = cTouch
				id = i
				break
			}
		}
		if id == -1 {
			panic("out of touchIDs")
		}
	}

	t := touch.Type(cTouchType)
	if t == touch.TypeEnd {
		touchIDs[id] = 0
	}

	theApp.eventsIn <- touch.Event{
		X:        x,
		Y:        y,
		Sequence: touch.Sequence(id),
		Type:     t,
	}
}

//export lifecycleDead
func lifecycleDead() { theApp.sendLifecycle(lifecycle.StageDead) }

//export lifecycleAlive
func lifecycleAlive() { theApp.sendLifecycle(lifecycle.StageAlive) }

//export lifecycleVisible
func lifecycleVisible() { theApp.sendLifecycle(lifecycle.StageVisible) }

//export lifecycleFocused
func lifecycleFocused() { theApp.sendLifecycle(lifecycle.StageFocused) }

//export drawloop
func drawloop() {
	runtime.LockOSThread()
	defer runtime.UnlockOSThread()

	for workAvailable := theApp.worker.WorkAvailable();;{
		select {
		case <-workAvailable:
			theApp.worker.DoWork()
		case <-theApp.publish:
			theApp.publishResult <- PublishResult{}
			return
		case <-time.After(100 * time.Millisecond): // incase the method blocked!!
			return
		}
	}
}

//export startloop
func startloop(ctx C.GLintptr) {
	go theApp.loop(ctx)
}

// loop is the primary drawing loop.
//
// After UIKit has captured the initial OS thread for processing UIKit
// events in runApp, it starts loop on another goroutine. It is locked
// to an OS thread for its OpenGL context.
func (a *app) loop(ctx C.GLintptr) {
	runtime.LockOSThread()
	C.makeCurrentContext(ctx)

	workAvailable := a.worker.WorkAvailable()

	for {
		select {
		case <-workAvailable:
			a.worker.DoWork()
		case <-theApp.publish:
		loop1:
			for {
				select {
				case <-workAvailable:
					a.worker.DoWork()
				default:
					break loop1
				}
			}
			C.swapBuffers(ctx)
			theApp.publishResult <- PublishResult{}
		}
	}
}

// driverShowVirtualKeyboard requests the driver to show a virtual keyboard for text input
func driverShowVirtualKeyboard() {
	C.showKeyboard()
}

// driverHideVirtualKeyboard requests the driver to hide any visible virtual keyboard
func driverHideVirtualKeyboard() {
	C.hideKeyboard()
}

var fileCallback func(string, func())

//export filePickerReturned
func filePickerReturned(str *C.char, urlPtr unsafe.Pointer) {
	if fileCallback == nil {
		return
	}

	fileCallback(C.GoString(str), func() {
		C.closeFileResource(urlPtr)
	})
	fileCallback = nil
}

func driverShowFileOpenPicker(callback func(string, func())) {
	fileCallback = callback

	C.showFileOpenPicker()
}