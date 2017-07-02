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

#include <string.h>

#import "OFString.h"
#import "OFArray.h"
#import "OFApplication.h"
#import "OFURL.h"
#import "OFHTTPRequest.h"
#import "OFHTTPResponse.h"
#import "OFHTTPClient.h"
#import "OFFile.h"
#import "OFStdIOStream.h"

#import "OFOutOfRangeException.h"

#import "TableGenerator.h"
#import "copyright.h"

#define UNICODE_DATA_URL \
	@"http://www.unicode.org/Public/UNIDATA/UnicodeData.txt"
#define CASE_FOLDING_URL \
	@"http://www.unicode.org/Public/UNIDATA/CaseFolding.txt"

OF_APPLICATION_DELEGATE(TableGenerator)

@implementation TableGenerator
- init
{
	self = [super init];

	_uppercaseTableSize           = SIZE_MAX;
	_lowercaseTableSize           = SIZE_MAX;
	_titlecaseTableSize           = SIZE_MAX;
	_casefoldingTableSize         = SIZE_MAX;
	_decompositionTableSize       = SIZE_MAX;
	_decompositionCompatTableSize = SIZE_MAX;

	return self;
}

- (void)applicationDidFinishLaunching
{
	OFString *path;
	[self parseUnicodeData];
	[self parseCaseFolding];

	[of_stdout writeString: @"Writing files…"];

	path = [OFString pathWithComponents: [OFArray arrayWithObjects:
	    OF_PATH_PARENT_DIRECTORY, @"src", @"unicode.m", nil]];
	[self writeTablesToFile: path];

	path = [OFString pathWithComponents: [OFArray arrayWithObjects:
	    OF_PATH_PARENT_DIRECTORY, @"src", @"unicode.h", nil]];
	[self writeHeaderToFile: path];

	[of_stdout writeLine: @" done"];

	[OFApplication terminate];
}

- (void)parseUnicodeData
{
	void *pool = objc_autoreleasePoolPush();
	OFHTTPRequest *request;
	OFHTTPClient *client;
	OFHTTPResponse *response;
	OFString *line;

	[of_stdout writeString: @"Downloading and parsing UnicodeData.txt…"];

	request = [OFHTTPRequest requestWithURL:
	    [OFURL URLWithString: UNICODE_DATA_URL]];
	client = [OFHTTPClient client];
	response = [client performRequest: request];

	while ((line = [response readLine]) != nil) {
		void *pool2;
		OFArray OF_GENERIC(OFString *) *components;
		of_unichar_t codePoint;

		if ([line length] == 0)
			continue;

		pool2 = objc_autoreleasePoolPush();

		components = [line componentsSeparatedByString: @";"];
		if ([components count] != 15) {
			of_log(@"Invalid line: %@\n", line);
			[OFApplication terminateWithStatus: 1];
		}

		codePoint = (of_unichar_t)
		    [[components objectAtIndex: 0] hexadecimalValue];

		if (codePoint > 0x10FFFF)
			@throw [OFOutOfRangeException exception];

		_uppercaseTable[codePoint] = (of_unichar_t)
		    [[components objectAtIndex: 12] hexadecimalValue];
		_lowercaseTable[codePoint] = (of_unichar_t)
		    [[components objectAtIndex: 13] hexadecimalValue];
		_titlecaseTable[codePoint] = (of_unichar_t)
		    [[components objectAtIndex: 14] hexadecimalValue];

		if ([[components objectAtIndex: 5] length] > 0) {
			OFArray *decomposed = [[components objectAtIndex: 5]
			    componentsSeparatedByString: @" "];
			bool compat = false;
			OFMutableString *string;

			if ([[decomposed firstObject] hasPrefix: @"<"]) {
				decomposed = [decomposed objectsInRange:
				    of_range(1, [decomposed count] - 1)];
				compat = true;
			}

			string = [OFMutableString string];

			for (OFString *character in decomposed)
				[string appendFormat: @"%C",
				    (of_unichar_t)[character hexadecimalValue]];

			[string makeImmutable];

			if (!compat)
				_decompositionTable[codePoint] = [string copy];
			_decompositionCompatTable[codePoint] = [string copy];
		}

		objc_autoreleasePoolPop(pool2);
	}

	[of_stdout writeLine: @" done"];

	objc_autoreleasePoolPop(pool);
}

- (void)parseCaseFolding
{
	void *pool = objc_autoreleasePoolPush();
	OFHTTPRequest *request;
	OFHTTPClient *client;
	OFHTTPResponse *response;
	OFString *line;

	[of_stdout writeString: @"Downloading and parsing CaseFolding.txt…"];

	request = [OFHTTPRequest requestWithURL:
	    [OFURL URLWithString: CASE_FOLDING_URL]];
	client = [OFHTTPClient client];
	response = [client performRequest: request];

	while ((line = [response readLine]) != nil) {
		void *pool2;
		OFArray OF_GENERIC(OFString *) *components;
		of_unichar_t codePoint;

		if ([line length] == 0 || [line hasPrefix: @"#"])
			continue;

		pool2 = objc_autoreleasePoolPush();

		components = [line componentsSeparatedByString: @"; "];
		if ([components count] != 4) {
			of_log(@"Invalid line: %s\n", line);
			[OFApplication terminateWithStatus: 1];
		}

		if (![[components objectAtIndex: 1] isEqual: @"S"] &&
		    ![[components objectAtIndex: 1] isEqual: @"C"])
			continue;

		codePoint = (of_unichar_t)
		    [[components objectAtIndex: 0] hexadecimalValue];

		if (codePoint > 0x10FFFF)
			@throw [OFOutOfRangeException exception];

		_casefoldingTable[codePoint] = (of_unichar_t)
		    [[components objectAtIndex: 2] hexadecimalValue];

		objc_autoreleasePoolPop(pool2);
	}

	[of_stdout writeLine: @" done"];

	objc_autoreleasePoolPop(pool);
}

- (void)writeTablesToFile: (OFString *)path
{
	void *pool = objc_autoreleasePoolPush();
	OFFile *file = [OFFile fileWithPath: path
				       mode: @"wb"];

	[file writeString: COPYRIGHT
	    @"#include \"config.h\"\n"
	    @"\n"
	    @"#import \"OFString.h\"\n\n"
	    @"static const of_unichar_t emptyPage[0x100] = { 0 };\n"
	    @"static const char *emptyDecompositionPage[0x100] = { NULL };\n"
	    @"\n"];

	/* Write uppercasePage%u */
	for (of_unichar_t i = 0; i < 0x110000; i += 0x100) {
		bool isEmpty = true;

		for (of_unichar_t j = i; j < i + 0x100; j++) {
			if (_uppercaseTable[j] != 0) {
				isEmpty = false;
				_uppercaseTableSize = i >> 8;
				_uppercaseTableUsed[_uppercaseTableSize] = 1;
				break;
			}
		}

		if (!isEmpty) {
			void *pool2 = objc_autoreleasePoolPush();

			[file writeString: [OFString stringWithFormat:
			    @"static const of_unichar_t "
			    @"uppercasePage%u[0x100] = {\n", i >> 8]];

			for (of_unichar_t j = i; j < i + 0x100; j += 8)
				[file writeString: [OFString stringWithFormat:
				    @"\t%u, %u, %u, %u, %u, %u, %u, %u,\n",
				    _uppercaseTable[j],
				    _uppercaseTable[j + 1],
				    _uppercaseTable[j + 2],
				    _uppercaseTable[j + 3],
				    _uppercaseTable[j + 4],
				    _uppercaseTable[j + 5],
				    _uppercaseTable[j + 6],
				    _uppercaseTable[j + 7]]];

			[file writeString: @"};\n\n"];

			objc_autoreleasePoolPop(pool2);
		}
	}

	/* Write lowercasePage%u */
	for (of_unichar_t i = 0; i < 0x110000; i += 0x100) {
		bool isEmpty = true;

		for (of_unichar_t j = i; j < i + 0x100; j++) {
			if (_lowercaseTable[j] != 0) {
				isEmpty = false;
				_lowercaseTableSize = i >> 8;
				_lowercaseTableUsed[_lowercaseTableSize] = 1;
				break;
			}
		}

		if (!isEmpty) {
			void *pool2 = objc_autoreleasePoolPush();

			[file writeString: [OFString stringWithFormat:
			    @"static const of_unichar_t "
			    @"lowercasePage%u[0x100] = {\n", i >> 8]];

			for (of_unichar_t j = i; j < i + 0x100; j += 8)
				[file writeString: [OFString stringWithFormat:
				    @"\t%u, %u, %u, %u, %u, %u, %u, %u,\n",
				    _lowercaseTable[j],
				    _lowercaseTable[j + 1],
				    _lowercaseTable[j + 2],
				    _lowercaseTable[j + 3],
				    _lowercaseTable[j + 4],
				    _lowercaseTable[j + 5],
				    _lowercaseTable[j + 6],
				    _lowercaseTable[j + 7]]];

			[file writeString: @"};\n\n"];

			objc_autoreleasePoolPop(pool2);
		}
	}

	/* Write titlecasePage%u if it does NOT match uppercasePage%u */
	for (of_unichar_t i = 0; i < 0x110000; i += 0x100) {
		bool isEmpty = true;

		for (of_unichar_t j = i; j < i + 0x100; j++) {
			if (_titlecaseTable[j] != 0) {
				isEmpty = !memcmp(_uppercaseTable + i,
				    _titlecaseTable + i,
				    256 * sizeof(of_unichar_t));
				_titlecaseTableSize = i >> 8;
				_titlecaseTableUsed[_titlecaseTableSize] =
				    (isEmpty ? 2 : 1);
				break;
			}
		}

		if (!isEmpty) {
			void *pool2 = objc_autoreleasePoolPush();

			[file writeString: [OFString stringWithFormat:
			    @"static const of_unichar_t "
			    @"titlecasePage%u[0x100] = {\n", i >> 8]];

			for (of_unichar_t j = i; j < i + 0x100; j += 8)
				[file writeString: [OFString stringWithFormat:
				    @"\t%u, %u, %u, %u, %u, %u, %u, %u,\n",
				    _titlecaseTable[j],
				    _titlecaseTable[j + 1],
				    _titlecaseTable[j + 2],
				    _titlecaseTable[j + 3],
				    _titlecaseTable[j + 4],
				    _titlecaseTable[j + 5],
				    _titlecaseTable[j + 6],
				    _titlecaseTable[j + 7]]];

			[file writeString: @"};\n\n"];

			objc_autoreleasePoolPop(pool2);
		}
	}

	/* Write casefoldingPage%u if it does NOT match lowercasePage%u */
	for (of_unichar_t i = 0; i < 0x110000; i += 0x100) {
		bool isEmpty = true;

		for (of_unichar_t j = i; j < i + 0x100; j++) {
			if (_casefoldingTable[j] != 0) {
				isEmpty = !memcmp(_lowercaseTable + i,
				    _casefoldingTable + i,
				    256 * sizeof(of_unichar_t));
				_casefoldingTableSize = i >> 8;
				_casefoldingTableUsed[_casefoldingTableSize] =
				    (isEmpty ? 2 : 1);
				break;
			}
		}

		if (!isEmpty) {
			void *pool2 = objc_autoreleasePoolPush();

			[file writeString: [OFString stringWithFormat:
			    @"static const of_unichar_t "
			    @"casefoldingPage%u[0x100] = {\n", i >> 8]];

			for (of_unichar_t j = i; j < i + 0x100; j += 8)
				[file writeString: [OFString stringWithFormat:
				    @"\t%u, %u, %u, %u, %u, %u, %u, %u,\n",
				    _casefoldingTable[j],
				    _casefoldingTable[j + 1],
				    _casefoldingTable[j + 2],
				    _casefoldingTable[j + 3],
				    _casefoldingTable[j + 4],
				    _casefoldingTable[j + 5],
				    _casefoldingTable[j + 6],
				    _casefoldingTable[j + 7]]];

			[file writeString: @"};\n\n"];

			objc_autoreleasePoolPop(pool2);
		}
	}

	/* Write decompositionPage%u */
	for (of_unichar_t i = 0; i < 0x110000; i += 0x100) {
		bool isEmpty = true;

		for (of_unichar_t j = i; j < i + 0x100; j++) {
			if (_decompositionTable[j] != nil) {
				isEmpty = false;
				_decompositionTableSize = i >> 8;
				_decompositionTableUsed[
				    _decompositionTableSize] = 1;
				break;
			}
		}

		if (!isEmpty) {
			void *pool2 = objc_autoreleasePoolPush();

			[file writeString: [OFString stringWithFormat:
			    @"static const char *const "
			    @"decompositionPage%u[0x100] = {\n", i >> 8]];

			for (of_unichar_t j = i; j < i + 0x100; j++) {
				if ((j - i) % 2 == 0)
					[file writeString: @"\t"];
				else
					[file writeString: @" "];

				if (_decompositionTable[j] != nil) {
					const char *UTF8String =
					    [_decompositionTable[j] UTF8String];
					size_t length = [_decompositionTable[j]
					    UTF8StringLength];

					[file writeString: @"\""];

					for (size_t k = 0; k < length; k++)
						[file writeFormat:
						    @"\\x%02X",
						    (uint8_t)UTF8String[k]];

					[file writeString: @"\","];
				} else
					[file writeString: @"NULL,"];

				if ((j - i) % 2 == 1)
					[file writeString: @"\n"];
			}

			[file writeString: @"};\n\n"];

			objc_autoreleasePoolPop(pool2);
		}
	}

	/* Write decompCompatPage%u if it does NOT match decompositionPage%u */
	for (of_unichar_t i = 0; i < 0x110000; i += 0x100) {
		bool isEmpty = true;

		for (of_unichar_t j = i; j < i + 0x100; j++) {
			if (_decompositionCompatTable[j] != 0) {
				/*
				 * We bulk-compare pointers via memcmp here.
				 * This is safe, as we always set the same
				 * pointer in both tables if both are the same.
				 */
				isEmpty = !memcmp(_decompositionTable + i,
				    _decompositionCompatTable + i,
				    256 * sizeof(const char *));
				_decompositionCompatTableSize = i >> 8;
				_decompositionCompatTableUsed[
				    _decompositionCompatTableSize] =
				    (isEmpty ? 2 : 1);

				break;
			}
		}

		if (!isEmpty) {
			void *pool2 = objc_autoreleasePoolPush();

			[file writeString: [OFString stringWithFormat:
			    @"static const char *const "
			    @"decompCompatPage%u[0x100] = {\n", i >> 8]];

			for (of_unichar_t j = i; j < i + 0x100; j++) {
				if ((j - i) % 2 == 0)
					[file writeString: @"\t"];
				else
					[file writeString: @" "];

				if (_decompositionCompatTable[j] != nil) {
					const char *UTF8String =
					    [_decompositionCompatTable[j]
					    UTF8String];
					size_t length =
					    [_decompositionCompatTable[j]
					    UTF8StringLength];

					[file writeString: @"\""];

					for (size_t k = 0; k < length; k++)
						[file writeFormat:
						    @"\\x%02X",
						    (uint8_t)UTF8String[k]];

					[file writeString: @"\","];
				} else
					[file writeString: @"NULL,"];

				if ((j - i) % 2 == 1)
					[file writeString: @"\n"];
			}

			[file writeString: @"};\n\n"];

			objc_autoreleasePoolPop(pool2);
		}
	}

	/*
	 * Those are currently set to the last index.
	 * But from now on, we need the size.
	 */
	_uppercaseTableSize++;
	_lowercaseTableSize++;
	_titlecaseTableSize++;
	_casefoldingTableSize++;
	_decompositionTableSize++;
	_decompositionCompatTableSize++;

	/* Write of_unicode_uppercase_table */
	[file writeString: [OFString stringWithFormat:
	    @"const of_unichar_t *const of_unicode_uppercase_table[0x%X] = "
	    @"{\n\t", _uppercaseTableSize]];

	for (of_unichar_t i = 0; i < _uppercaseTableSize; i++) {
		if (_uppercaseTableUsed[i])
			[file writeString: [OFString stringWithFormat:
			    @"uppercasePage%u", i]];
		else
			[file writeString: @"emptyPage"];

		if (i + 1 < _uppercaseTableSize) {
			if ((i + 1) % 4 == 0)
				[file writeString: @",\n\t"];
			else
				[file writeString: @", "];
		}
	}

	[file writeString: @"\n};\n\n"];

	/* Write of_unicode_lowercase_table */
	[file writeString: [OFString stringWithFormat:
	    @"const of_unichar_t *const of_unicode_lowercase_table[0x%X] = "
	    @"{\n\t", _lowercaseTableSize]];

	for (of_unichar_t i = 0; i < _lowercaseTableSize; i++) {
		if (_lowercaseTableUsed[i])
			[file writeString: [OFString stringWithFormat:
			    @"lowercasePage%u", i]];
		else
			[file writeString: @"emptyPage"];

		if (i + 1 < _lowercaseTableSize) {
			if ((i + 1) % 4 == 0)
				[file writeString: @",\n\t"];
			else
				[file writeString: @", "];
		}
	}

	[file writeString: @"\n};\n\n"];

	/* Write of_unicode_titlecase_table */
	[file writeString: [OFString stringWithFormat:
	    @"const of_unichar_t *const of_unicode_titlecase_table[0x%X] = {"
	    @"\n\t", _titlecaseTableSize]];

	for (of_unichar_t i = 0; i < _titlecaseTableSize; i++) {
		if (_titlecaseTableUsed[i] == 1)
			[file writeString: [OFString stringWithFormat:
			    @"titlecasePage%u", i]];
		else if (_titlecaseTableUsed[i] == 2)
			[file writeString: [OFString stringWithFormat:
			    @"uppercasePage%u", i]];
		else
			[file writeString: @"emptyPage"];

		if (i + 1 < _titlecaseTableSize) {
			if ((i + 1) % 4 == 0)
				[file writeString: @",\n\t"];
			else
				[file writeString: @", "];
		}
	}

	[file writeString: @"\n};\n\n"];

	/* Write of_unicode_casefolding_table */
	[file writeString: [OFString stringWithFormat:
	    @"const of_unichar_t *const of_unicode_casefolding_table[0x%X] = "
	    @"{\n\t", _casefoldingTableSize]];

	for (of_unichar_t i = 0; i < _casefoldingTableSize; i++) {
		if (_casefoldingTableUsed[i] == 1)
			[file writeString: [OFString stringWithFormat:
			    @"casefoldingPage%u", i]];
		else if (_casefoldingTableUsed[i] == 2)
			[file writeString: [OFString stringWithFormat:
			    @"lowercasePage%u", i]];
		else
			[file writeString: @"emptyPage"];

		if (i + 1 < _casefoldingTableSize) {
			if ((i + 1) % 3 == 0)
				[file writeString: @",\n\t"];
			else
				[file writeString: @", "];
		}
	}

	[file writeString: @"\n};\n\n"];

	/* Write of_unicode_decomposition_table */
	[file writeString: [OFString stringWithFormat:
	    @"const char *const *of_unicode_decomposition_table[0x%X] = "
	    @"{\n\t", _decompositionTableSize]];

	for (of_unichar_t i = 0; i < _decompositionTableSize; i++) {
		if (_decompositionTableUsed[i])
			[file writeString: [OFString stringWithFormat:
			    @"decompositionPage%u", i]];
		else
			[file writeString: @"emptyDecompositionPage"];

		if (i + 1 < _decompositionTableSize) {
			if ((i + 1) % 3 == 0)
				[file writeString: @",\n\t"];
			else
				[file writeString: @", "];
		}
	}

	[file writeString: @"\n};\n\n"];

	/* Write of_unicode_decomposition_compat_table */
	[file writeString: [OFString stringWithFormat:
	    @"const char *const *of_unicode_decomposition_compat_table[0x%X] = "
	    @"{\n\t", _decompositionCompatTableSize]];

	for (of_unichar_t i = 0; i < _decompositionCompatTableSize; i++) {
		if (_decompositionCompatTableUsed[i] == 1)
			[file writeString: [OFString stringWithFormat:
			    @"decompCompatPage%u", i]];
		else if (_decompositionCompatTableUsed[i] == 2)
			[file writeString: [OFString stringWithFormat:
			    @"decompositionPage%u", i]];
		else
			[file writeString: @"emptyDecompositionPage"];

		if (i + 1 < _decompositionCompatTableSize) {
			if ((i + 1) % 3 == 0)
				[file writeString: @",\n\t"];
			else
				[file writeString: @", "];
		}
	}

	[file writeString: @"\n};\n"];

	objc_autoreleasePoolPop(pool);
}

- (void)writeHeaderToFile: (OFString *)path
{
	void *pool = objc_autoreleasePoolPush();
	OFFile *file = [OFFile fileWithPath: path
				       mode: @"wb"];

	[file writeString: COPYRIGHT
	    @"#import \"OFString.h\"\n\n"];

	[file writeString: [OFString stringWithFormat:
	    @"#define OF_UNICODE_UPPERCASE_TABLE_SIZE 0x%X\n"
	    @"#define OF_UNICODE_LOWERCASE_TABLE_SIZE 0x%X\n"
	    @"#define OF_UNICODE_TITLECASE_TABLE_SIZE 0x%X\n"
	    @"#define OF_UNICODE_CASEFOLDING_TABLE_SIZE 0x%X\n"
	    @"#define OF_UNICODE_DECOMPOSITION_TABLE_SIZE 0x%X\n"
	    @"#define OF_UNICODE_DECOMPOSITION_COMPAT_TABLE_SIZE 0x%X\n\n",
	    _uppercaseTableSize, _lowercaseTableSize, _titlecaseTableSize,
	    _casefoldingTableSize, _decompositionTableSize,
	    _decompositionCompatTableSize]];

	[file writeString:
	    @"#ifdef __cplusplus\n"
	    @"extern \"C\" {\n"
	    @"#endif\n"
	    @"extern const of_unichar_t *const _Nonnull\n"
	    @"    of_unicode_uppercase_table["
	    @"OF_UNICODE_UPPERCASE_TABLE_SIZE];\n"
	    @"extern const of_unichar_t *const _Nonnull\n"
	    @"    of_unicode_lowercase_table["
	    @"OF_UNICODE_LOWERCASE_TABLE_SIZE];\n"
	    @"extern const of_unichar_t *const _Nonnull\n"
	    @"    of_unicode_titlecase_table["
	    @"OF_UNICODE_TITLECASE_TABLE_SIZE];\n"
	    @"extern const of_unichar_t *const _Nonnull\n"
	    @"    of_unicode_casefolding_table["
	    @"OF_UNICODE_CASEFOLDING_TABLE_SIZE];\n"
	    @"extern const char *const _Nullable *const _Nonnull\n"
	    @"    of_unicode_decomposition_table["
	    @"OF_UNICODE_DECOMPOSITION_TABLE_SIZE];\n"
	    @"extern const char *const _Nullable *const _Nonnull\n"
	    @"    of_unicode_decomposition_compat_table["
	    @"OF_UNICODE_DECOMPOSITION_COMPAT_TABLE_SIZE];\n"
	    @"#ifdef __cplusplus\n"
	    @"}\n"
	    @"#endif\n"];

	objc_autoreleasePoolPop(pool);
}
@end
