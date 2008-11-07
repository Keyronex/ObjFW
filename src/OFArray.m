/*
 * Copyright (c) 2008
 *   Jonathan Schleifer <js@webkeks.org>
 *
 * All rights reserved.
 *
 * This file is part of libobjfw. It may be distributed under the terms of the
 * Q Public License 1.0, which can be found in the file LICENSE included in
 * the packaging of this file.
 */

#import <stdio.h>
#import <string.h>
#import <unistd.h>

#import "OFArray.h"

#import "OFExceptions.h"
#import "OFMacros.h"

static size_t pagesize = 0;

@implementation OFArray
+ newWithItemSize: (size_t)is
{
	return [[OFArray alloc] initWithItemSize: is];
}

- initWithItemSize: (size_t)is
{
	if ((self = [super init])) {
		data = NULL;
		itemsize = is;
		items = 0;
	}

	return self;
}

- (size_t)items
{
	return items;
}

- (size_t)itemsize
{
	return itemsize;
}

- (void*)data
{
	return data;
}

- (void*)item: (size_t)item
{
	if (item >= items)
		[[OFOutOfRangeException newWithObject: self] raise];

	return data + item * itemsize;
}

- (void*)last
{
	return data + (items - 1) * itemsize;
}

- add: (void*)item
{
	if (SIZE_MAX - items < 1)
		[[OFOutOfRangeException newWithObject: self] raise];

	data = [self resizeMem: data
		      toNItems: items + 1
			ofSize: itemsize];

	memcpy(data + items++ * itemsize, item, itemsize);

	return self;
}

- addNItems: (size_t)nitems
 fromCArray: (void*)carray
{
	if (nitems > SIZE_MAX - items)
		[[OFOutOfRangeException newWithObject: self] raise];

	data = [self resizeMem: data
		      toNItems: items + nitems
			ofSize: itemsize];

	memcpy(data + items * itemsize, carray, nitems * itemsize);
	items += nitems;

	return self;
}

- removeNItems: (size_t)nitems
{
	if (nitems > items)
		[[OFOutOfRangeException newWithObject: self] raise];

	data = [self resizeMem: data
		      toNItems: items - nitems
			ofSize: itemsize];

	items -= nitems;

	return self;
}
@end

@implementation OFBigArray
+ newWithItemSize: (size_t)is
{
	return [[OFBigArray alloc] initWithItemSize: is];
}

- initWithItemSize: (size_t)is
{
	if (pagesize == 0)
		pagesize = getpagesize();

	if ((self = [super initWithItemSize: is]))
		size = 0;

	return self;
}

- addNItems: (size_t)nitems
 fromCArray: (void*)carray
{
	size_t nsize;

	if (nitems > SIZE_MAX - items || items + nitems > SIZE_MAX / itemsize)
		[[OFOutOfRangeException newWithObject: self] raise];

	nsize = (((items + nitems) * itemsize) / pagesize) + 1;

	if (size != nsize)
		data = [self resizeMem: data
				toSize: nsize];

	memcpy(data + items * itemsize, carray, nitems * itemsize);
	items += nitems;
	size = nsize;

	return self;
}

- removeNItems: (size_t)nitems
{
	size_t nsize;

	if (nitems > items)
		[[OFOutOfRangeException newWithObject: self] raise];

	nsize = (((items - nitems) * itemsize) / pagesize) + 1;

	if (size != nsize)
		data = [self resizeMem: data
				toSize: nsize];

	items -= nitems;
	size = nsize;

	return self;
}
@end
