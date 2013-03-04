/*
 * Copyright (c) 2008, 2009, 2010, 2011, 2012, 2013
 *   Jonathan Schleifer <js@webkeks.org>
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

#include <stdlib.h>

#import "OFAcceptFailedException.h"
#import "OFString.h"
#import "OFTCPSocket.h"

#import "common.h"

@implementation OFAcceptFailedException
+ (instancetype)exceptionWithClass: (Class)class
			    socket: (OFTCPSocket*)socket
{
	return [[[self alloc] initWithClass: class
				     socket: socket] autorelease];
}

- initWithClass: (Class)class
{
	@try {
		[self doesNotRecognizeSelector: _cmd];
	} @catch (id e) {
		[self release];
		@throw e;
	}

	abort();
}

- initWithClass: (Class)class
	 socket: (OFTCPSocket*)socket
{
	self = [super initWithClass: class];

	_socket = [socket retain];
	_errNo = GET_SOCK_ERRNO;

	return self;
}

- (void)dealloc
{
	[_socket release];

	[super dealloc];
}

- (OFString*)description
{
	return [OFString stringWithFormat:
	    @"Failed to accept connection in socket of type %@! " ERRFMT,
	    _inClass, ERRPARAM];
}

- (OFTCPSocket*)socket
{
	OF_GETTER(_socket, false)
}

- (int)errNo
{
	return _errNo;
}
@end
