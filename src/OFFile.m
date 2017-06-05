/*
 * Copyright (c) 2008, 2009, 2010, 2011, 2012, 2013, 2014, 2015, 2016, 2017
 *   Jonathan Schleifer <js@heap.zone>
 *
 * All rights reserved.
 *
 * This file is part of ObjFW. It may be distributed under the terms of the
 * Q Public License 1.0, which can be found in the file LICENSE.QPL included in
 * the packaging of this file.
 *
 * Alternatively, it may be distributed under the terms of the GNU General
 * Public License, either version 2 or 3, which can be found in the file
 * LICENSE.GPLv2 or LICENSE.GPLv3 respectively included in the packaging of this
 * file.
 */

#include "config.h"

#include <assert.h>
#include <errno.h>

#ifdef HAVE_FCNTL_H
# include <fcntl.h>
#endif
#include "unistd_wrapper.h"

#ifdef HAVE_SYS_STAT_H
# include <sys/stat.h>
#endif

#import "OFFile.h"
#import "OFString.h"
#import "OFLocalization.h"
#import "OFDataArray.h"

#import "OFInitializationFailedException.h"
#import "OFInvalidArgumentException.h"
#import "OFNotOpenException.h"
#import "OFOpenItemFailedException.h"
#import "OFOutOfRangeException.h"
#import "OFReadFailedException.h"
#import "OFSeekFailedException.h"
#import "OFWriteFailedException.h"

#ifdef OF_WINDOWS
# include <windows.h>
#endif

#ifdef OF_WII
# define BOOL OGC_BOOL
# include <fat.h>
# undef BOOL
#endif

#ifdef OF_NINTENDO_DS
# include <stdbool.h>
# include <filesystem.h>
#endif

#ifndef O_BINARY
# define O_BINARY 0
#endif
#ifndef O_CLOEXEC
# define O_CLOEXEC 0
#endif
#ifndef O_EXCL
# define O_EXCL 0
#endif
#ifndef O_EXLOCK
# define O_EXLOCK 0
#endif

#ifndef OF_MORPHOS
# define closeHandle(h) close(h)
#else
static OFDataArray *openHandles = nil;

static void
closeHandle(of_file_handle_t handle)
{
	if (handle.index != SIZE_MAX) {
		BPTR *handles = [openHandles items];
		size_t count = [openHandles count];

		assert(handles[handle.index] == handle.handle);

		handles[handle.index] = handles[count - 1];
		[openHandles removeItemAtIndex: count - 1];
	}

	Close(handle.handle);
}

OF_DESTRUCTOR()
{
	BPTR *handles = [openHandles items];
	size_t count = [openHandles count];

	for (size_t i = 0; i < count; i++)
		Close(handles[i]);
}
#endif

#ifndef OF_MORPHOS
static int
parseMode(const char *mode)
{
	if (strcmp(mode, "r") == 0)
		return O_RDONLY;
	if (strcmp(mode, "w") == 0)
		return O_WRONLY | O_CREAT | O_TRUNC;
	if (strcmp(mode, "wx") == 0)
		return O_WRONLY | O_CREAT | O_EXCL | O_EXLOCK;
	if (strcmp(mode, "a") == 0)
		return O_WRONLY | O_CREAT | O_APPEND;
	if (strcmp(mode, "rb") == 0)
		return O_RDONLY | O_BINARY;
	if (strcmp(mode, "wb") == 0)
		return O_WRONLY | O_CREAT | O_TRUNC | O_BINARY;
	if (strcmp(mode, "wbx") == 0)
		return O_WRONLY | O_CREAT | O_EXCL | O_EXLOCK;
	if (strcmp(mode, "ab") == 0)
		return O_WRONLY | O_CREAT | O_APPEND | O_BINARY;
	if (strcmp(mode, "r+") == 0)
		return O_RDWR;
	if (strcmp(mode, "w+") == 0)
		return O_RDWR | O_CREAT | O_TRUNC;
	if (strcmp(mode, "a+") == 0)
		return O_RDWR | O_CREAT | O_APPEND;
	if (strcmp(mode, "r+b") == 0 || strcmp(mode, "rb+") == 0)
		return O_RDWR | O_BINARY;
	if (strcmp(mode, "w+b") == 0 || strcmp(mode, "wb+") == 0)
		return O_RDWR | O_CREAT | O_TRUNC | O_BINARY;
	if (strcmp(mode, "w+bx") == 0 || strcmp(mode, "wb+x") == 0)
		return O_RDWR | O_CREAT | O_EXCL | O_EXLOCK;
	if (strcmp(mode, "ab+") == 0 || strcmp(mode, "a+b") == 0)
		return O_RDWR | O_CREAT | O_APPEND | O_BINARY;

	return -1;
}
#else
static int
parseMode(const char *mode, bool *append)
{
	*append = false;

	if (strcmp(mode, "r") == 0)
		return MODE_OLDFILE;
	if (strcmp(mode, "w") == 0)
		return MODE_NEWFILE;
	if (strcmp(mode, "wx") == 0)
		return MODE_NEWFILE;
	if (strcmp(mode, "a") == 0) {
		*append = true;
		return MODE_READWRITE;
	}
	if (strcmp(mode, "rb") == 0)
		return MODE_OLDFILE;
	if (strcmp(mode, "wb") == 0)
		return MODE_NEWFILE;
	if (strcmp(mode, "wbx") == 0)
		return MODE_NEWFILE;
	if (strcmp(mode, "ab") == 0) {
		*append = true;
		return MODE_READWRITE;
	}
	if (strcmp(mode, "r+") == 0)
		return MODE_OLDFILE;
	if (strcmp(mode, "w+") == 0)
		return MODE_NEWFILE;
	if (strcmp(mode, "a+") == 0) {
		*append = true;
		return MODE_READWRITE;
	}
	if (strcmp(mode, "r+b") == 0 || strcmp(mode, "rb+") == 0)
		return MODE_OLDFILE;
	if (strcmp(mode, "w+b") == 0 || strcmp(mode, "wb+") == 0)
		return MODE_NEWFILE;
	if (strcmp(mode, "w+bx") == 0 || strcmp(mode, "wb+x") == 0)
		return MODE_NEWFILE;
	if (strcmp(mode, "ab+") == 0 || strcmp(mode, "a+b") == 0) {
		*append = true;
		return MODE_READWRITE;
	}

	return -1;
}
#endif

@implementation OFFile
+ (void)initialize
{
	if (self != [OFFile class])
		return;

#ifdef OF_MORPHOS
	openHandles = [[OFDataArray alloc] initWithItemSize: sizeof(BPTR)];
#endif

#ifdef OF_WII
	if (!fatInitDefault())
		@throw [OFInitializationFailedException
		    exceptionWithClass: self];
#endif

#ifdef OF_NINTENDO_DS
	if (!nitroFSInit(NULL))
		@throw [OFInitializationFailedException
		    exceptionWithClass: self];
#endif
}

+ (instancetype)fileWithPath: (OFString *)path
			mode: (OFString *)mode
{
	return [[[self alloc] initWithPath: path
				      mode: mode] autorelease];
}

+ (instancetype)fileWithHandle: (of_file_handle_t)handle
{
	return [[[self alloc] initWithHandle: handle] autorelease];
}

- init
{
	OF_INVALID_INIT_METHOD
}

- initWithPath: (OFString *)path
	  mode: (OFString *)mode
{
	of_file_handle_t handle;

	@try {
		void *pool = objc_autoreleasePoolPush();
		int flags;

#ifndef OF_MORPHOS
		if ((flags = parseMode([mode UTF8String])) == -1)
			@throw [OFInvalidArgumentException exception];

		flags |= O_CLOEXEC;

# if defined(OF_WINDOWS)
		if ((handle = _wopen([path UTF16String], flags,
		    _S_IREAD | _S_IWRITE)) == -1)
# elif defined(OF_HAVE_OFF64_T)
		if ((handle = open64([path cStringWithEncoding:
		    [OFLocalization encoding]], flags, 0666)) == -1)
# else
		if ((handle = open([path cStringWithEncoding:
		    [OFLocalization encoding]], flags, 0666)) == -1)
# endif
			@throw [OFOpenItemFailedException
			    exceptionWithPath: path
					 mode: mode
					errNo: errno];
#else
		handle.index = SIZE_MAX;

		if ((flags = parseMode([mode UTF8String],
		    &handle.append)) == -1)
			@throw [OFInvalidArgumentException exception];

		if ((handle.handle = Open([path cStringWithEncoding:
		    [OFLocalization encoding]], flags)) == 0) {
			int errNo;

			switch (IoErr()) {
			case ERROR_OBJECT_IN_USE:
			case ERROR_DISK_NOT_VALIDATED:
				errNo = EBUSY;
				break;
			case ERROR_OBJECT_NOT_FOUND:
				errNo = ENOENT;
				break;
			case ERROR_DISK_WRITE_PROTECTED:
				errNo = EROFS;
				break;
			case ERROR_WRITE_PROTECTED:
			case ERROR_READ_PROTECTED:
				errNo = EACCES;
				break;
			default:
				errNo = 0;
				break;
			}

			@throw [OFOpenItemFailedException
			    exceptionWithPath: path
					 mode: mode
					errNo: errNo];
		}

		[openHandles addItem: &handle.handle];
		handle.index = [openHandles count] - 1;

		if (handle.append) {
			if (Seek64(handle.handle, 0, OFFSET_END) == -1) {
				closeHandle(handle);
				@throw [OFOpenItemFailedException
				    exceptionWithPath: path
						 mode: mode
						errNo: EIO];
			}
		}
#endif

		objc_autoreleasePoolPop(pool);
	} @catch (id e) {
		[self release];
		@throw e;
	}

	@try {
		self = [self initWithHandle: handle];
	} @catch (id e) {
		closeHandle(handle);
		@throw e;
	}

	return self;
}

- initWithHandle: (of_file_handle_t)handle
{
	self = [super init];

	_handle = handle;

	return self;
}

- (bool)lowlevelIsAtEndOfStream
{
	if (!OF_FILE_HANDLE_IS_VALID(_handle))
		@throw [OFNotOpenException exceptionWithObject: self];

	return _atEndOfStream;
}

- (size_t)lowlevelReadIntoBuffer: (void *)buffer
			  length: (size_t)length
{
	ssize_t ret;

	if (!OF_FILE_HANDLE_IS_VALID(_handle))
		@throw [OFNotOpenException exceptionWithObject: self];

#if defined(OF_WINDOWS)
	if (length > UINT_MAX)
		@throw [OFOutOfRangeException exception];

	if ((ret = read(_handle, buffer, (unsigned int)length)) < 0)
		@throw [OFReadFailedException exceptionWithObject: self
						  requestedLength: length
							    errNo: errno];
#elif defined(OF_MORPHOS)
	if (length > LONG_MAX)
		@throw [OFOutOfRangeException exception];

	if ((ret = Read(_handle.handle, buffer, length)) < 0)
		@throw [OFReadFailedException exceptionWithObject: self
						  requestedLength: length
							    errNo: EIO];
#else
	if ((ret = read(_handle, buffer, length)) < 0)
		@throw [OFReadFailedException exceptionWithObject: self
						  requestedLength: length
							    errNo: errno];
#endif

	if (ret == 0)
		_atEndOfStream = true;

	return ret;
}

- (void)lowlevelWriteBuffer: (const void *)buffer
		     length: (size_t)length
{
	if (!OF_FILE_HANDLE_IS_VALID(_handle))
		@throw [OFNotOpenException exceptionWithObject: self];

#if defined(OF_WINDOWS)
	if (length > INT_MAX)
		@throw [OFOutOfRangeException exception];

	if (write(_handle, buffer, (int)length) != (int)length)
		@throw [OFWriteFailedException exceptionWithObject: self
						   requestedLength: length
							     errNo: errno];
#elif defined(OF_MORPHOS)
	if (length > LONG_MAX)
		@throw [OFOutOfRangeException exception];

	if (_handle.append) {
		if (Seek64(_handle.handle, 0, OFFSET_END) == -1)
			@throw [OFWriteFailedException
			    exceptionWithObject: self
				requestedLength: length
					  errNo: EIO];
	}

	if (Write(_handle.handle, (void *)buffer, length) != (LONG)length)
		@throw [OFWriteFailedException exceptionWithObject: self
						   requestedLength: length
							     errNo: EIO];
#else
	if (length > SSIZE_MAX)
		@throw [OFOutOfRangeException exception];

	if (write(_handle, buffer, length) != (ssize_t)length)
		@throw [OFWriteFailedException exceptionWithObject: self
						   requestedLength: length
							     errNo: errno];
#endif
}

- (of_offset_t)lowlevelSeekToOffset: (of_offset_t)offset
			     whence: (int)whence
{
	of_offset_t ret;

	if (!OF_FILE_HANDLE_IS_VALID(_handle))
		@throw [OFNotOpenException exceptionWithObject: self];

#ifndef OF_MORPHOS
# if defined(OF_WINDOWS)
	ret = _lseeki64(_handle, offset, whence);
# elif defined(OF_HAVE_OFF64_T)
	ret = lseek64(_handle, offset, whence);
# else
	ret = lseek(_handle, offset, whence);
# endif

	if (ret == -1)
		@throw [OFSeekFailedException exceptionWithStream: self
							   offset: offset
							   whence: whence
							    errNo: errno];
#else
	switch (whence) {
	case SEEK_SET:
		ret = Seek64(_handle.handle, offset, OFFSET_BEGINNING);
		break;
	case SEEK_CUR:
		ret = Seek64(_handle.handle, offset, OFFSET_CURRENT);
		break;
	case SEEK_END:
		ret = Seek64(_handle.handle, offset, OFFSET_END);
		break;
	default:
		ret = -1;
		break;
	}

	if (ret == -1)
		@throw [OFSeekFailedException exceptionWithStream: self
							   offset: offset
							   whence: whence
							    errNo: EINVAL];
#endif

	_atEndOfStream = false;

	return ret;
}

#ifdef OF_FILE_HANDLE_IS_FD
- (int)fileDescriptorForReading
{
	return _handle;
}

- (int)fileDescriptorForWriting
{
	return _handle;
}
#endif

- (void)close
{
	if (OF_FILE_HANDLE_IS_VALID(_handle))
		closeHandle(_handle);

	_handle = OF_INVALID_FILE_HANDLE;

	[super close];
}

- (void)dealloc
{
	[self close];

	[super dealloc];
}
@end
