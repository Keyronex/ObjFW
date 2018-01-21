/*
 * Copyright (c) 2008, 2009, 2010, 2011, 2012, 2013, 2014, 2015, 2016, 2017,
 *               2018
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

#import "OFValue.h"
#import "OFMethodSignature.h"
#import "OFString.h"
#import "OFValue_bytes.h"
#import "OFValue_nonretainedObject.h"
#import "OFValue_pointer.h"

#import "OFInvalidFormatException.h"
#import "OFOutOfMemoryException.h"

static struct {
	Class isa;
} placeholder;

@interface OFValue_placeholder: OFValue
@end

@implementation OFValue_placeholder
- (instancetype)initWithBytes: (const void *)bytes
		     objCType: (const char *)objCType
{
	return (id)[[OFValue_bytes alloc] initWithBytes: bytes
					       objCType: objCType];
}

- (instancetype)initWithPointer: (const void *)pointer
{
	return (id)[[OFValue_pointer alloc] initWithPointer: pointer];
}

- (instancetype)initWithNonretainedObject: (id)object
{
	return (id)[[OFValue_nonretainedObject alloc]
	    initWithNonretainedObject: object];
}
@end

@implementation OFValue
+ (void)initialize
{
	if (self == [OFValue class])
		placeholder.isa = [OFValue_placeholder class];
}

+ (instancetype)alloc
{
	if (self == [OFValue class])
		return (id)&placeholder;

	return [super alloc];
}

+ (instancetype)valueWithBytes: (const void *)bytes
		      objCType: (const char *)objCType
{
	return [[[self alloc] initWithBytes: bytes
				   objCType: objCType] autorelease];
}

+ (instancetype)valueWithPointer: (const void *)pointer
{
	return [[[self alloc] initWithPointer: pointer] autorelease];
}

+ (instancetype)valueWithNonretainedObject: (id)object
{
	return [[[self alloc] initWithNonretainedObject: object] autorelease];
}

- (instancetype)initWithBytes: (const void *)bytes
		     objCType: (const char *)objCType
{
	OF_INVALID_INIT_METHOD
}

- (instancetype)initWithPointer: (const void *)pointer
{
	OF_INVALID_INIT_METHOD
}

- (instancetype)initWithNonretainedObject: (id)object
{
	OF_INVALID_INIT_METHOD
}

- (bool)isEqual: (id)object
{
	const char *objCType;
	size_t size;
	void *value, *otherValue;

	if (![object isKindOfClass: [OFValue class]])
		return false;

	objCType = [self objCType];

	if (strcmp([object objCType], objCType) != 0)
		return false;

	size = of_sizeof_type_encoding(objCType);

	if ((value = malloc(size)) == NULL)
		@throw [OFOutOfMemoryException
		    exceptionWithRequestedSize: size];

	if ((otherValue = malloc(size)) == NULL) {
		free(value);
		@throw [OFOutOfMemoryException
		    exceptionWithRequestedSize: size];
	}

	@try {
		[self getValue: value
			  size: size];
		[object getValue: otherValue
			    size: size];

		return (memcmp(value, otherValue, size) == 0);
	} @finally {
		free(value);
		free(otherValue);
	}
}

- (uint32_t)hash
{
	size_t size = of_sizeof_type_encoding([self objCType]);
	unsigned char *value;
	uint32_t hash;

	if ((value = malloc(size)) == NULL)
		@throw [OFOutOfMemoryException
		    exceptionWithRequestedSize: size];

	@try {
		[self getValue: value
			  size: size];

		OF_HASH_INIT(hash);

		for (size_t i = 0; i < size; i++)
			OF_HASH_ADD(hash, value[i]);

		OF_HASH_FINALIZE(hash);
	} @finally {
		free(value);
	}

	return hash;
}

- (id)copy
{
	return [self retain];
}

- (const char *)objCType
{
	OF_UNRECOGNIZED_SELECTOR
}

- (void)getValue: (void *)value
	    size: (size_t)size
{
	OF_UNRECOGNIZED_SELECTOR
}

- (void *)pointerValue
{
	void *ret;

	[self getValue: &ret
		  size: sizeof(ret)];

	return ret;
}

- (id)nonretainedObjectValue
{
	id ret;

	[self getValue: &ret
		  size: sizeof(ret)];

	return ret;
}

- (OFString *)description
{
	OFMutableString *ret =
	    [OFMutableString stringWithString: @"<OFValue: "];
	size_t size = of_sizeof_type_encoding([self objCType]);
	unsigned char *value;

	if ((value = malloc(size)) == NULL)
		@throw [OFOutOfMemoryException
		    exceptionWithRequestedSize: size];

	@try {
		[self getValue: value
			  size: size];

		for (size_t i = 0; i < size; i++) {
			if (i > 0)
				[ret appendString: @" "];

			[ret appendFormat: @"%02x", value[i]];
		}
	} @finally {
		free(value);
	}

	[ret appendString: @">"];

	[ret makeImmutable];
	return ret;
}
@end
