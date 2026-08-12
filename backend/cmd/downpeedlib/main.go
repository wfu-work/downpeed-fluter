package main

/*
#include <stdint.h>
*/
import "C"

import (
	"unsafe"

	"github.com/wfu-work/downpeed-fluter/backend/internal/enginehost"
)

var host = enginehost.New()

// DownpeedStart starts the embedded engine and waits until its HTTP listener
// is ready. The JSON pointer may be NULL to use secure local defaults.
//
//export DownpeedStart
func DownpeedStart(configJSON *C.char) C.int32_t {
	value := "{}"
	if configJSON != nil {
		value = C.GoString(configJSON)
	}
	if err := host.Start(value); err != nil {
		return 1
	}
	return 0
}

// DownpeedStop gracefully stops the engine and waits for active task state to
// be checkpointed. Calling it while stopped is safe.
//
//export DownpeedStop
func DownpeedStop() C.int32_t {
	if err := host.Stop(); err != nil {
		return 1
	}
	return 0
}

// DownpeedLastError copies the last public error as UTF-8. Its return value is
// the required buffer size including the trailing NUL. Call with a NULL buffer
// to query the size; memory remains owned by the caller.
//
//export DownpeedLastError
func DownpeedLastError(buffer *C.char, bufferLength C.int32_t) C.int32_t {
	message := []byte(host.LastError())
	required := len(message) + 1
	if buffer == nil || bufferLength <= 0 {
		return C.int32_t(required)
	}
	capacity := int(bufferLength)
	target := unsafe.Slice((*byte)(unsafe.Pointer(buffer)), capacity)
	count := len(message)
	if count >= capacity {
		count = capacity - 1
	}
	copy(target, message[:count])
	target[count] = 0
	return C.int32_t(required)
}

func main() {}
