/*
Written in the D Programming Language

dbudget - accounting and budget planning application for console geeks
Copyright (C) 2012 Adrian Matoga

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

import std.stdio;
import std.string;
import std.regex;
import std.datetime;
import std.conv;
import std.math;
import std.getopt;
import std.algorithm;

struct Decimal
{
	long _payload;

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

	enum Zero = Decimal(0);
	enum One = Decimal(1_000000);

	Decimal opBinary(string op)(Decimal rhs) if (op == "+" || op == "-" || op == "+=" || op == "-=")
	{
		Decimal result;
		result._payload = mixin("this._payload " ~ op ~ " rhs._payload");
		return result;
	}

	Decimal opUnary(string op)() if (op == "-")
	{
		return Decimal.Zero - this;
	}

	bool opEquals(ref const Decimal rhs)
	{
		return this._payload == rhs._payload;
	}

	int opCmp(ref const Decimal rhs) const
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
}

Decimal[string] accounts;

struct Transaction
{
	uint serial;
	Date date;
	string title;
	Decimal[string] movements;
	
	bool opEquals(ref const Transaction rhs)
	{
		return false;
	}

	int opCmp(ref const Transaction rhs) const
	{
		if (this.date == rhs.date)
			return this.serial - rhs.serial;
		return this.date.opCmp(rhs.date);
	}
}

Transaction[] transactions;

enum State
{
	Idle,
	InTransaction
}

int main(string[] args)
{
	string endDateString;
	Date endDate;
	string[] accountsToShow;

	getopt(args,
		config.noBundling,
		config.caseInsensitive,
		config.noPassThrough,
		"d|end-date", &endDateString,
		"a|account", &accountsToShow);

	if (endDateString.length)
	{
		auto m = match(endDateString, "([^-]+)-([^-]+)-([^-]+)");
		if (!m)
			throw new Exception("Invalid date specified");
		endDate = Date(
			to!uint(m.captures[1]),
			to!uint(m.captures[2]),
			to!uint(m.captures[3]));
	}
	else
	{
		endDate = cast(Date) Clock.currTime();
	}

	if (args.length != 2)
	{
		stderr.writefln("Usage: %s [options] input_file", args[0]);
		stderr.write("Options are:\n" ~
			" -d  --end-date=yyyy-mm-dd  Stop at date (default: today)\n" ~
			" -a  --account=acc          Specify account(s) to track. May appear multiple times.\n");
		return 1;
	}

	auto f = File(args[1]);
	State state;
	uint n = 0;
	Transaction t;
	foreach (line; f.byLine())
	{
		++n;
		if (line.length == 0)
		{
			if (state == state.InTransaction)
				transactions ~= t;
			state = State.Idle;
			continue;
		}
		else if (line.startsWith('#'))
		{
			continue;
		}

		if (state == State.Idle)
		{
			auto m = match(line, "([^=]*)=(.*)");
			if (m)
			{
				accounts[m.captures[1].strip.idup] =
					Decimal(m.captures[2].strip.idup);
				continue;
			}
			m = match(line, "([^-]*)-([^-]*)-([^ ]*) *(.*)");
			if (m)
			{
				t.serial++;
				t.date = Date(
					to!uint(m.captures[1].strip),
					to!uint(m.captures[2].strip),
					to!uint(m.captures[3].strip));
				t.title = m.captures[4].strip.idup;
				t.movements.clear();
				state = State.InTransaction;
				continue;
			}
		}
		else if (state == State.InTransaction)
		{
			auto m = match(line, "([^ ]*) *-> *([^ ]*) *(.*)");
			if (m)
			{
				t.movements[m.captures[1].strip.idup] =
					-Decimal(m.captures[3].strip.idup);
				t.movements[m.captures[2].strip.idup] =
					Decimal(m.captures[3].strip.idup);
				continue;
			}
			m = match(line, "([^ ]*) *(.*)");
			if (m)
			{
				t.movements[m.captures[1].strip.idup] =
					Decimal(m.captures[2].strip.idup);
				continue;
			}
		}
		throw new Exception(format(
			"Invalid syntax at line %s:\n%s", n, line));
	}
	if (state == state.InTransaction)
		transactions ~= t;
	sort(transactions);
	foreach (acc; accountsToShow)
	{
		writeln("Account: ", acc);
		uint i;
		Decimal balance = accounts[acc];
		writefln("%5s%10s%-12s%-20s%10s%10s", "#", "", "Date", "Title", "Change", "Balance");
		writefln("--------------------------------------------------------------------");
		writefln("%27s%-20.20s%11s%s", "", "Initial balance", "", balance.prettyPrint());
		foreach (ref tr; transactions)
		{
			if (tr.date > endDate)
				break;
			if (acc in tr.movements)
			{
				balance = balance + tr.movements[acc];
				writefln("%5d. [%5d] %s %-20.20s %s %s", ++i, tr.serial, tr.date, to!dstring(tr.title),
				tr.movements[acc].prettyPrint(),
				balance.prettyPrint());
			}
		}
	}

	return 0;
}
