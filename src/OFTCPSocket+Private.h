/*
 * Copyright (c) 2008, 2009, 2010, 2011, 2012, 2013, 2014, 2015, 2016, 2017,
 *               2018, 2019
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

#import "OFTCPSocket.h"

OF_ASSUME_NONNULL_BEGIN

@interface OFTCPSocket ()
#ifndef OF_WII
@property (readonly, nonatomic) int of_socketError;
#endif

- (bool)of_createSocketForAddress: (const of_socket_address_t *)address
			    errNo: (int *)errNo;
- (bool)of_connectSocketToAddress: (const of_socket_address_t *)address
			    errNo: (int *)errNo;
- (void)of_closeSocket;
@end

OF_ASSUME_NONNULL_END
