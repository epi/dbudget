/*
Written in the D Programming Language

decimal.d - a type to hold exact currency values

Copyright (C) 2012 Adrian Matoga

This file is part of dbudget - accounting and budget planning
application for console geeks. See https://github.com/epi/dbudget

dbudget is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

dbudget is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with dbudget.  If not, see <http://www.gnu.org/licenses/>.
*/

import std.string;
import std.math;

struct Decimal
{
	long _payload;

	this(long payload) { _payload = payload; }

	this(string s)
	{
		bool neg;
		if (s.startsWith('+'))
			s = s[1 .. $];
		else if (s.startsWith('-'))
		{
			neg = true;
			s = s[1 .. $];
		}

		long m = 1000000;
		long div = 1;
		while (s.length)
		{
			if (s[0] >= '0' && s[0] <= '9')
			{
				_payload = _payload * 10 + s[0] - '0';
				m /= div;
			}
			else if (s[0] == '.')
			{
				if (div > 1)
					throw new Exception("Double dot");
				div = 10;
			}
			else
				throw new Exception(format("Invalid character '%s'", s[0]));
			s = s[1 .. $];
		}
		if (m < 1)
			throw new Exception("Too many fractional digits");
		_payload *= m;
		if (neg)
			_payload = -_payload;
	}

	unittest
	{
		static assert (Decimal("0")._payload == 0);
		static assert (Decimal("15")._payload == 15_000000);
		static assert (Decimal("-15")._payload == -15_000000);
		static assert (Decimal("-15.123456")._payload == -15_123456);
	}

	Decimal opBinary(string op)(Decimal rhs) if (op == "+" || op == "-" || op == "+=" || op == "-=")
	{
		Decimal result;
		result._payload = mixin("this._payload " ~ op ~ " rhs._payload");
		return result;
	}

	Decimal opBinary(string op)(Decimal rhs) if (op == "/")
	{
		Decimal result;
		result._payload = this._payload * 1_000000 / rhs._payload;
		return result;
	}

	Decimal opUnary(string op)() if (op == "-")
	{
		return DecimalZero - this;
	}

	bool opEquals(const Decimal rhs)
	{
		return this._payload == rhs._payload;
	}

	int opCmp(const Decimal rhs) const
	{
		auto res = this._payload - rhs._payload;
		if (res < 0)
			return -1;
		else if (res > 0)
			return 1;
		else
			return 0;
	}

	unittest
	{
		assert (-Decimal("-15") == Decimal("15"));
		static assert ((Decimal("31.337") + Decimal("-1.336"))._payload == 30_001000);
		static assert ((Decimal("30.007") - Decimal("-1.3301"))._payload == 31_337100);
		assert (Decimal("41.447") > Decimal("31.337"));
		assert (Decimal("31.337") + Decimal("-1.336") == Decimal("30.001"));
	}

	string toString()
	{
		return format("%d.%02d", _payload / 1_000000, abs(_payload % 1_000000 / 10000));
	}

	string prettyPrint()
	{
		if (_payload >= 0)
			return format("%6d.%02d",
				_payload / 1_000000,
				abs(_payload % 1_000000 / 10000));
		else
			return format("\x1b[31;1m%6d.%02d\x1b[0m",
				_payload / 1_000000,
				abs(_payload % 1_000000 / 10000));
	}

	@property static Decimal Zero() { return DecimalZero; }
	@property static Decimal One() { return DecimalOne; }
}

enum DecimalZero = Decimal(0);
enum DecimalOne = Decimal(1_000000);
