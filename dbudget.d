/*
Written in the D Programming Language

dbudget.d - console interface for dbudget

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

import std.stdio;
import std.string;
import std.regex;
import std.datetime;
import std.conv;
import std.math;
import std.getopt;
import std.range;
import std.algorithm;
import decimal;
import account;

class DefaultReportFormatter : ReportFormatter
{
	private enum LastPrinted
	{
		None,
		Transaction,
		Balance
	}

	private LastPrinted _lastPrinted;
	private size_t _numAccounts;

	override void startReport(string name, size_t numAccounts)
	{
		writeln("Report: ", name);
		_numAccounts = numAccounts;
	}

	override void startHeader()
	{
		writef("%47s", "");
	}

	override void writeAccountHeader(string name)
	{
		auto x = to!dstring(name);
		write(" ", center(x[0 .. min(18, x.length)], 18));
	}

	override void finalizeHeader()
	{
		writef("\n%5s%10s%-12s%-20s", "#", "", "Date", "Title");
		foreach (j; 0 .. _numAccounts)
			writef(" %9s%9s", "Change", "Balance");
		writeln();
	}

	override void startTransaction(uint n, uint serial, Date date,
		string title)
	{
		if (_lastPrinted != LastPrinted.Transaction)
			printBar();
		writef("%5d. [%5d] %s %-20.20s",
			n, serial, date, to!dstring(title));
		_lastPrinted = LastPrinted.Transaction;
	}

	override void printTransactionComp(Decimal credit, Decimal balance,
		string currency)
	{
		writef(" %s%s", credit.prettyPrint(), balance.prettyPrint());
	}

	override void printEmptyTransactionComp()
	{
		writef("%19s", "");
	}

	override void finalizeTransaction()
	{
		writeln();
	}

	override void startBalance(Date date, string title)
	{
		if (_lastPrinted != LastPrinted.Balance)
			printBar();
		writef("%15s%-12s %-20.20s", "", date, to!dstring(title));
		_lastPrinted = LastPrinted.Balance;
	}

	override void printBalanceComp(Decimal balance, string currency)
	{
		writef("%10s%s", "", balance.prettyPrint());
	}

	override void finalizeBalance()
	{
		writeln();
	}

	override void startFuture()
	{
	}

	override void finalizeReport()
	{
		printBar();
		writeln("Generated on ", Clock.currTime());
	}

	void printBar()
	{
		writeln(std.range.repeat('-', 48 + _numAccounts * 19));
	}
}

int main(string[] args)
{
	bool verify;

	getopt(args,
		config.caseSensitive,
		config.noPassThrough,
		"verify", &verify);

	if (args.length < 2)
	{
		stderr.writefln("Usage: %s input_file [report_name]", args[0]);
		return 1;
	}

	if (args.length == 2)
		args ~= "default";

	auto tl = TransactionLog.loadFile(args[1]);
	if (verify)
	{
		foreach (t; tl.transactions)
		{
			auto total = t.totalByCurrency();
			auto currs = total.keys;
			auto amounts = total.values;
			if (total.length > 2)
			{
				writeln("Warning: transaction `%s': more than 2 currencies",
					t.title);
			}
			else if (total.length == 2 && amounts[1] != Decimal.Zero)
			{
				writefln(
					"Info: transaction `%s': conversion rate: 1 %s = %s %s",
					t.title, currs[0], amounts[1] / amounts[0], currs[1]);
			}
			else if (total.length == 1 && amounts[0] != Decimal.Zero)
			{
				writefln("Warning: transaction `%s': off by %s %s",
					t.title, amounts[0], currs[0]);
			}
		}
	}

	auto rf = new DefaultReportFormatter();
	tl.getReport(args[2]).print(rf);

	return 0;
}
