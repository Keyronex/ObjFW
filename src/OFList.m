/*
 * Copyright (c) 2008, 2009, 2010, 2011
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

#include "assert.h"

#import "OFList.h"
#import "OFString.h"
#import "OFAutoreleasePool.h"

#import "OFEnumerationMutationException.h"

#import "macros.h"

@implementation OFList
+ list
{
	return [[[self alloc] init] autorelease];
}

- init
{
	self = [super init];

	firstListObject = NULL;
	lastListObject = NULL;

	return self;
}

- (void)dealloc
{
	of_list_object_t *iter;

	for (iter = firstListObject; iter != NULL; iter = iter->next)
		[iter->object release];

	[super dealloc];
}

- (of_list_object_t*)firstListObject;
{
	return firstListObject;
}

- (of_list_object_t*)lastListObject;
{
	return lastListObject;
}

- (of_list_object_t*)appendObject: (id)object
{
	of_list_object_t *listObject;

	listObject = [self allocMemoryWithSize: sizeof(of_list_object_t)];
	listObject->object = [object retain];
	listObject->next = NULL;
	listObject->previous = lastListObject;

	if (lastListObject != NULL)
		lastListObject->next = listObject;

	lastListObject = listObject;
	if (firstListObject == NULL)
		firstListObject = listObject;

	count++;
	mutations++;

	return listObject;
}

- (of_list_object_t*)prependObject: (id)object
{
	of_list_object_t *listObject;

	listObject = [self allocMemoryWithSize: sizeof(of_list_object_t)];
	listObject->object = [object retain];
	listObject->next = firstListObject;
	listObject->previous = NULL;

	if (firstListObject != NULL)
		firstListObject->previous = listObject;

	firstListObject = listObject;
	if (lastListObject == NULL)
		lastListObject = listObject;

	count++;
	mutations++;

	return listObject;
}

- (of_list_object_t*)insertObject: (id)object
		 beforeListObject: (of_list_object_t*)listObject
{
	of_list_object_t *newListObject;

	newListObject = [self allocMemoryWithSize: sizeof(of_list_object_t)];
	newListObject->object = [object retain];
	newListObject->next = listObject;
	newListObject->previous = listObject->previous;

	if (listObject->previous != NULL)
		listObject->previous->next = newListObject;

	listObject->previous = newListObject;

	if (listObject == firstListObject)
		firstListObject = newListObject;

	count++;
	mutations++;

	return newListObject;
}

- (of_list_object_t*)insertObject: (id)object
		  afterListObject: (of_list_object_t*)listObject
{
	of_list_object_t *newListObject;

	newListObject = [self allocMemoryWithSize: sizeof(of_list_object_t)];
	newListObject->object = [object retain];
	newListObject->next = listObject->next;
	newListObject->previous = listObject;

	if (listObject->next != NULL)
		listObject->next->previous = newListObject;

	listObject->next = newListObject;

	if (listObject == lastListObject)
		lastListObject = newListObject;

	count++;
	mutations++;

	return newListObject;
}

- (void)removeListObject: (of_list_object_t*)listObject
{
	if (listObject->previous != NULL)
		listObject->previous->next = listObject->next;
	if (listObject->next != NULL)
		listObject->next->previous = listObject->previous;

	if (firstListObject == listObject)
		firstListObject = listObject->next;
	if (lastListObject == listObject)
		lastListObject = listObject->previous;

	count--;
	mutations++;

	[listObject->object release];

	[self freeMemory: listObject];
}

- (size_t)count
{
	return count;
}

- (BOOL)isEqual: (id)object
{
	OFList *otherList;
	of_list_object_t *iter, *iter2;

	if (![object isKindOfClass: [OFList class]])
		return NO;

	otherList = (OFList*)object;

	if ([otherList count] != count)
		return NO;

	for (iter = firstListObject, iter2 = [otherList firstListObject];
	    iter != NULL && iter2 != NULL;
	    iter = iter->next, iter2 = iter2->next)
		if (![iter->object isEqual: iter2->object])
			return NO;

	/* One is bigger than the other although we checked the count */
	assert(iter == NULL && iter2 == NULL);

	return YES;
}

- (BOOL)containsObject: (id)object
{
	of_list_object_t *iter;

	if (count == 0)
		return NO;

	for (iter = firstListObject; iter != NULL; iter = iter->next)
		if ([iter->object isEqual: object])
			return YES;

	return NO;
}

- (BOOL)containsObjectIdenticalTo: (id)object
{
	of_list_object_t *iter;

	if (count == 0)
		return NO;

	for (iter = firstListObject; iter != NULL; iter = iter->next)
		if (iter->object == object)
			return YES;

	return NO;
}

- copy
{
	OFList *copy = [[OFList alloc] init];
	of_list_object_t *iter, *listObject, *previous;

	listObject = NULL;
	previous = NULL;

	@try {
		for (iter = firstListObject; iter != NULL; iter = iter->next) {
			listObject = [copy allocMemoryWithSize:
			    sizeof(of_list_object_t)];
			listObject->object = [iter->object retain];
			listObject->next = NULL;
			listObject->previous = previous;

			if (copy->firstListObject == NULL)
				copy->firstListObject = listObject;
			if (previous != NULL)
				previous->next = listObject;

			copy->count++;

			previous = listObject;
		}
	} @catch (id e) {
		[copy release];
		@throw e;
	}

	copy->lastListObject = listObject;

	return copy;
}

- (uint32_t)hash
{
	of_list_object_t *iter;
	uint32_t hash;

	OF_HASH_INIT(hash);

	for (iter = firstListObject; iter != NULL; iter = iter->next) {
		uint32_t h = [iter->object hash];

		OF_HASH_ADD(hash, h >> 24);
		OF_HASH_ADD(hash, (h >> 16) & 0xFF);
		OF_HASH_ADD(hash, (h >> 8) & 0xFF);
		OF_HASH_ADD(hash, h & 0xFF);
	}

	OF_HASH_FINALIZE(hash);

	return hash;
}

- (OFString*)description
{
	OFMutableString *ret;
	OFAutoreleasePool *pool;
	of_list_object_t *iter;

	if (count == 0)
		return @"[]";

	ret = [OFMutableString stringWithString: @"[\n"];
	pool = [[OFAutoreleasePool alloc] init];

	for (iter = firstListObject; iter != NULL; iter = iter->next) {
		[ret appendString: [iter->object description]];

		if (iter->next != NULL)
			[ret appendString: @",\n"];

		[pool releaseObjects];
	}
	[ret replaceOccurrencesOfString: @"\n"
			     withString: @"\n\t"];
	[ret appendString: @"\n]"];

	[pool release];

	/*
	 * Class swizzle the string to be immutable. We declared the return type
	 * to be OFString*, so it can't be modified anyway. But not swizzling it
	 * would create a real copy each time -[copy] is called.
	 */
	ret->isa = [OFString class];
	return ret;
}

- (OFString*)stringBySerializing
{
	OFMutableString *ret;
	OFAutoreleasePool *pool;
	of_list_object_t *iter;

	if (count == 0)
		return @"(list,mutable)[]";

	ret = [OFMutableString stringWithString: @"(list,mutable)[\n"];
	pool = [[OFAutoreleasePool alloc] init];

	for (iter = firstListObject; iter != NULL; iter = iter->next) {
		[ret appendString: [iter->object stringBySerializing]];

		if (iter->next != NULL)
			[ret appendString: @",\n"];

		[pool releaseObjects];
	}
	[ret replaceOccurrencesOfString: @"\n"
			     withString: @"\n\t"];
	[ret appendString: @"\n]"];

	[pool release];

	/*
	 * Class swizzle the string to be immutable. We declared the return type
	 * to be OFString*, so it can't be modified anyway. But not swizzling it
	 * would create a real copy each time -[copy] is called.
	 */
	ret->isa = [OFString class];
	return ret;
}

- (int)countByEnumeratingWithState: (of_fast_enumeration_state_t*)state
			   objects: (id*)objects
			     count: (int)count_
{
	of_list_object_t **list_obj = (of_list_object_t**)state->extra;

	state->itemsPtr = objects;
	state->mutationsPtr = &mutations;

	if (state->state == 0) {
		*list_obj = firstListObject;
		state->state = 1;
	}

	if (*list_obj == NULL)
		return 0;

	objects[0] = (*list_obj)->object;
	*list_obj = (*list_obj)->next;
	return 1;
}

- (OFEnumerator*)objectEnumerator
{
	return [[[OFListEnumerator alloc]
	        initWithList: self
	    mutationsPointer: &mutations] autorelease];
}
@end

@implementation OFListEnumerator
-     initWithList: (OFList*)list_
  mutationsPointer: (unsigned long*)mutationsPtr_;
{
	self = [super init];

	list = [list_ retain];
	current = [list firstListObject];
	mutations = *mutationsPtr_;
	mutationsPtr = mutationsPtr_;

	return self;
}

- (void)dealloc
{
	[list release];

	[super dealloc];
}

- (id)nextObject
{
	id ret;

	if (*mutationsPtr != mutations)
		@throw [OFEnumerationMutationException newWithClass: isa
							     object: list];

	if (current == NULL)
		return nil;

	ret = current->object;
	current = current->next;

	return ret;
}

- (void)reset
{
	if (*mutationsPtr != mutations)
		@throw [OFEnumerationMutationException newWithClass: isa];

	current = [list firstListObject];
}
@end
