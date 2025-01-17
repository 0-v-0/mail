module mail.utils;

import std.algorithm;
import std.conv : to;
import std.string;
import std.datetime;

enum months = ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"];

extern (C) pure nothrow
{
	alias void* iconv_t;

	iconv_t iconv_open(const char* tocode, const char* fromcode);
	size_t iconv(iconv_t cd, const char** inbuf, size_t* inbytesleft,
			char** outbuf, size_t* outbytesleft);
	int iconv_close(iconv_t cd);
}

string recode(in string f, in string t, char[] src)
{
	import std.array : uninitializedArray;

	auto cd = iconv_open(toStringz(t.toUpper), toStringz(f.toUpper));
	if (cast(size_t)cd == -1)
		return cast(string)src;

	auto dst = uninitializedArray!(char[])(src.length * 6);

	auto src_ptr = cast(char*) src.ptr;
	auto dst_ptr = cast(char*) dst.ptr;
	auto src_len = src.length;
	auto dst_len = dst.length;

	auto r = iconv(cd, &src_ptr, &src_len, &dst_ptr, &dst_len);
	iconv_close(cd);

	return cast(string)(r == -1 ? src : dst[0 .. $ - dst_len]);
}

ubyte[] fromPercentEncoding(ref ubyte[] src, ubyte chr = '%')
{
	ubyte[] dst;
	if (!src.length)
		return dst;

	size_t i = 0,
		len = src.length,
		outLen = 0;
	while (i < len)
	{
		ubyte c = src[i];
		if (c == chr && i + 2 < len)
		{
			int a = src[++i],
				b = src[++i];
			if (a >= '0' && a <= '9')
				a -= '0';
			else if (a >= 'a' && a <= 'f')
				a = a - 'a' + 10;
			else if (a >= 'A' && a <= 'F')
				a = a - 'A' + 10;

			if (b >= '0' && b <= '9')
				b -= '0';
			else if (b >= 'a' && b <= 'f')
				b = b - 'a' + 10;
			else if (b >= 'A' && b <= 'F')
				b = b - 'A' + 10;
			dst ~= cast(ubyte)((a << 4) | b);
		}
		else
		{
			dst ~= c;
		}
		++i;
		++outLen;
	}
	if (outLen != len)
	{
		dst.length = outLen;
	}
	return dst;
}

ubyte[] removeAll(ubyte[] src, ubyte[] val)
{
	ubyte[] dst = src;
	if (!val.length)
		return src;
	ptrdiff_t i = -1;
	do
	{
		i = dst.countUntil(val);
		if (i >= 0)
		{
			foreach (j; 0 .. val.length)
			{
				dst = dst.remove(i);
			}
		}
	}
	while (i >= 0);
	return dst;
}

ubyte[] removeAll(ubyte[] src, ubyte val)
{
	ubyte[] dst = src;
	ptrdiff_t i = -1;
	do
	{
		i = dst.countUntil(val);
		if (i >= 0)
		{
			dst = dst.remove(i);
		}
	}
	while (i >= 0);
	return dst;
}

SysTime parseDate(in string src, in SysTime fail = Clock.currTime)
{
	import std.ascii : isDigit;

	DateTime dt;
	immutable tz = new SimpleTimeZone(0.minutes);

	scope (failure) return fail;

	auto l = src.findSplitAfter(",")[1].strip().toUpper;

	uint x = l[1].isDigit ? 2 : 1;

	dt.day = l[0 .. x].to!int;

	l = l[++x .. $];

	dt.month  = cast(Month)(months.countUntil(l[0 .. 3]) + 1);
	dt.year   = l[ 4 .. 8].to!int;
	dt.hour   = l[ 9 .. 11].to!int;
	dt.minute = l[12 .. 14].to!int;
	dt.second = l[15 .. 17].to!int;
	int z = 0;

	if (l.length > 18)
	{
		auto tmp = l[18 .. $];
		if (tmp != "UT" && tmp != "UTC" && tmp != "GMT")
		{
			int sign = tmp[0] == '-' ? -1 : 1;

			if (tmp[0] == '-' || tmp[0] == '+')
			{
				tmp = tmp[1 .. $];
			}

			if (tmp.length == 4)
			{
				int tzH = tmp[0 .. 2].to!int;
				int tzM = tmp[2 .. 4].to!int;

				return SysTime(dt, new immutable SimpleTimeZone(((tzH * 60 + tzM) * sign).minutes));
			}
		}
	}

	return SysTime(dt, tz);
}
///
unittest
{
	assert(parseDate("8 Feb 2017 15:21:13 +0000").toISOExtString == "2017-02-08T15:21:13+00:00");
	assert(parseDate("8 Feb 2017 15:21:13 +0530").toISOExtString == "2017-02-08T15:21:13+05:30");
	assert(parseDate("18 Feb 2017 15:21:13 +0000").toISOExtString == "2017-02-18T15:21:13+00:00");
	assert(parseDate("18 Feb 2017 15:21:13 +0530").toISOExtString == "2017-02-18T15:21:13+05:30");
}