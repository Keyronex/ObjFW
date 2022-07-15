/*
 * Copyright (c) 2008-2022 Jonathan Schleifer <js@nil.im>
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

#import "OFException.h"

OF_ASSUME_NONNULL_BEGIN

/**
 * @class OFSetOptionFailedException \
 *	  OFSetOptionFailedException.h ObjFW/OFSetOptionFailedException.h
 *
 * @brief An exception indicating that setting an option for an object failed.
 */
@interface OFSetOptionFailedException: OFException
{
	id _object;
	int _errNo;
}

/**
 * @brief The object for which the option could not be set.
 */
@property (readonly, nonatomic) id object;

/**
 * @brief The errno of the error that occurred.
 */
@property (readonly, nonatomic) int errNo;

/**
 * @brief Creates a new, autoreleased set option failed exception.
 *
 * @param object The object for which the option could not be set
 * @param errNo The errno of the error that occurred
 * @return A new, autoreleased set option failed exception
 */
+ (instancetype)exceptionWithObject: (id)object errNo: (int)errNo;

+ (instancetype)exception OF_UNAVAILABLE;

/**
 * @brief Initializes an already allocated set option failed exception.
 *
 * @param object The object for which the option could not be set
 * @param errNo The errno of the error that occurred
 * @return An initialized set option failed exception
 */
- (instancetype)initWithObject: (id)object
			 errNo: (int)errNo OF_DESIGNATED_INITIALIZER;

- (instancetype)init OF_UNAVAILABLE;
@end

OF_ASSUME_NONNULL_END
