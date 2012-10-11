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
//		printDoubleBar();
		printBar();
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

	void printDoubleBar()
	{
		writeln(std.range.repeat('=', 48 + _numAccounts * 19));
	}
}

int main(string[] args)
{
	if (args.length < 2)
	{
		stderr.writefln("Usage: %s input_file [report_name]", args[0]);
		return 1;
	}

	if (args.length == 2)
		args ~= "default";

	auto tl = TransactionLog.loadFile(args[1]);
	auto rf = new DefaultReportFormatter();
	
	tl.getReport(args[2]).print(rf);

/*	// ... and print!
	sort(transactions);
	future = false;
	foreach (repname; args[2 .. $])
	{
		auto rep = reports[repname];
		writeln("Report: ", repname);
		uint i;

		writef("%47s", "");
		foreach (acc; rep.accountsToShow)
			write(" ", center(acc[0 .. min(19, acc.length)], 19));
		writef("\n%5s%10s%-12s%-20s", "#", "", "Date", "Title");
		foreach (j; 0 .. rep.accountsToShow.length)
			writef("%10s%10s", "Change", "Balance");
		writef("\n------------------------------------------------");
		foreach (j; 0 .. rep.accountsToShow.length)
			writef("--------------------");
		writeln();
		foreach (ref tr; transactions)
		{
			if (tr.date > today && !future)
			{
				writef("------------------------------------------------");
				foreach (j; 0 .. rep.accountsToShow.length)
					writef("--------------------");
				writeln();
				future = true;
			}
			if (tr.date > rep.endDate)
				break;
			bool showThis;
			foreach (acc; rep.accountsToShow)
			{
				if (acc in tr.movements)
				{
					showThis = true;
					break;
				}
			}
			if (showThis)
			{
				writef("%5d. [%5d] %s %-20.20s",
					++i, tr.serial, tr.date, to!dstring(tr.title));
				foreach (acc; rep.accountsToShow)
				{
					if (acc in tr.movements)
					{
						accounts[acc].balance =
							accounts[acc].balance + tr.movements[acc];
						writef(" %s %s",
							tr.movements[acc].prettyPrint(),
							accounts[acc].balance.prettyPrint());
					}
					else
					{
						writef("%20s", "");
					}
				}
				writeln();
			}
		}
		writef("------------------------------------------------");
		foreach (j; 0 .. rep.accountsToShow.length)
			writef("--------------------");
		writef("\n%15s%-12s %-20s", "", rep.endDate, "Closing Balance");
		foreach (acc; rep.accountsToShow)
			writef("%11s%s", "", accounts[acc].balance.prettyPrint());
		writeln();
	}

	foreach (acc; accounts)
		writefln("%-30s %s %s", to!dstring(acc.name), acc.balance.prettyPrint(),
			acc.currency);*/

	return 0;
}
