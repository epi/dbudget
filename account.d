/*
Written in the D Programming Language

account.d - just a god class, smarter design may come later

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
import std.datetime;
import std.exception;
import std.string;
import std.conv;
import std.regex;
import std.algorithm;
import decimal;

class Account
{
	string _name;
	Decimal _balance;
	string _currency;

	this(string name, string currency)
	{
		enforce(currency.length == 3, format(
			"Invalid currency identifier `%s'", currency));
		_name = name;
		_balance = Decimal.Zero;
		_currency = currency;
	}

	void increase(Decimal amount)
	{
		_balance = _balance + amount;
	}
}

class Transaction
{
	private static struct Movement
	{
		Account account;
		Decimal amount;
	}

	private uint _serial;
	private Date _date;
	private string _title;
	private Movement[] _movements;
	private static uint _serialCounter;

	override bool opEquals(Object rhs)
	{
		auto t = cast(Transaction) rhs;
		if (!t)
			return false;
		return false; 
	}

	override int opCmp(Object rhs) const
	{
		auto t = cast(Transaction) rhs;
		if (!t)
			throw new Exception("Cannot compare apples with oranges");
		if (this._date == t._date)
			return this._serial - t._serial;
		return this._date.opCmp(t._date);
	}

	void addMovement(Account account, Decimal amount)
	{
		_movements ~= Movement(account, amount);
	}

	this(Date date, string title)
	{
		_serial = ++_serialCounter;
		_date = date;
		_title = title;
	}
}

Date today;

static this()
{
	today = cast(Date) Clock.currTime();
}

interface ReportFormatter
{
	void startReport(string name, size_t numAccounts);

	void startHeader();
	void writeAccountHeader(string name);
	void finalizeHeader();

	void startTransaction(uint n, uint serial, Date date, string title);
	void printTransactionComp(Decimal credit, Decimal balance, string currency);
	void printEmptyTransactionComp();
	void finalizeTransaction();

	void startBalance(Date date, string title);
	void printBalanceComp(Decimal balance, string currency);
	void finalizeBalance();

	void startFuture();

	void finalizeReport();
}

class Report
{
	private TransactionLog _transactionLog;
	private string _name;
	private Date _startDate;
	private Date _endDate;
	private Account[] _accountsToShow;
	private bool _showMonthlyBalance = false;
	private bool _showTransactions = true;

	this(TransactionLog tl, string name)
	{
		_transactionLog = tl;
		_name = name;
		_endDate = today;
	}

	void print(ReportFormatter fmt)
	{
		fmt.startReport(_name, _accountsToShow.length);

		fmt.startHeader();
		foreach (acc; _accountsToShow)
			fmt.writeAccountHeader(acc._name);
		fmt.finalizeHeader();

		bool afterStartDate;
		bool future;
		uint n;
		Date prevDate;

		foreach (tr; _transactionLog._transactions)
		{
			if (tr._date >= _startDate && !afterStartDate)
			{
				fmt.startBalance(_startDate, "Initial balance");
				foreach (acc; _accountsToShow)
					fmt.printBalanceComp(acc._balance, acc._currency);
				fmt.finalizeBalance();
				afterStartDate = true;
			}
			if (tr._date.month != prevDate.month && _showMonthlyBalance)
			{
				fmt.startBalance(Date(tr._date.year, tr._date.month, 1),
					"Monthly balance");
				foreach (acc; _accountsToShow)
					fmt.printBalanceComp(acc._balance, acc._currency);
				fmt.finalizeBalance();
			}
			if (tr._date > today && !future)
			{
				fmt.startFuture();
				future = true;
			}
			if (tr._date > _endDate)
				break;
			bool showThis;
			Transaction.Movement[] mvmts;
			mvmts.length = _accountsToShow.length;
			foreach (i, acc; _accountsToShow)
			{
				foreach (mvm; tr._movements)
				{
					if (mvm.account is acc)
					{
						showThis = true;
						mvmts[i] = mvm;
					}
				}
			}
			if (showThis)
			{
				if (_showTransactions && afterStartDate)
					fmt.startTransaction(++n, tr._serial, tr._date, tr._title);
				foreach (mvm; mvmts)
				{
					if (mvm.account)
					{
						mvm.account.increase(mvm.amount);
						if (_showTransactions && afterStartDate)
							fmt.printTransactionComp(mvm.amount,
								mvm.account._balance, mvm.account._currency);
					}
					else
					{
						if (_showTransactions && afterStartDate)
							fmt.printEmptyTransactionComp();
					}
				}
				if (_showTransactions && afterStartDate)
					fmt.finalizeTransaction();
			}
			prevDate = tr._date;
		}
		fmt.startBalance(_endDate, "Closing balance");
		foreach (acc; _accountsToShow)
			fmt.printBalanceComp(acc._balance, acc._currency);
		fmt.finalizeBalance();

		fmt.finalizeReport();
	}
}

Date parseDate(in char[] d)
{
	auto m = match(d, "([^-]+)-([^-]+)-([^-]+)");
	if (!m)
		throw new Exception("Invalid date specified");
	return Date(
		to!uint(m.captures[1]),
		to!uint(m.captures[2]),
		to!uint(m.captures[3]));
}

bool parseOnOff(in char[] s)
{
	if (s.toUpper() == "OFF")
		return false;
	if (s.toUpper() == "ON")
		return true;
	throw new Exception("Expected `On' or `Off'");
}

class TransactionLog
{
	private Account[string] _accounts;
	private Transaction[] _transactions;
	private Report[string] _reports;

	Report addReport(string name)
	{
		enforce(name.length, "Empty report name");
		enforce(name !in _reports, format(
			"Report `%s' already defined", name));
		auto result = new Report(this, name);
		_reports[name] = result;
		return result;
	}

	Account addAccount(string name, string currency)
	{
		enforce(name.length, "Empty account name");
		enforce(name !in _accounts, format(
			"Account `%s' already defined", name));
		auto result = new Account(name, currency);
		_accounts[name] = result;
		return result;
	}

	Transaction addTransaction(Date date, string title)
	{
		enforce(title.length, "Empty transaction title");
		auto result = new Transaction(date, title);
		_transactions ~= result;
		return result;
	}

	void addMovement(Transaction t, string account, Decimal amount)
	{
		enforce(account in _accounts, format(
			"Undefined account `%s' in transaction `%s'", account, t._title));
		t.addMovement(_accounts[account], amount);
	}

	Report getReport(string name)
	{
		return enforce(_reports.get(name, null), format(
			"No such report: `%s'", name));
	}

	static TransactionLog loadFile(string fileName)
	{
		enum State
		{
			InReport,
			Idle,
			InTransaction
		}

		auto result = new TransactionLog;
		auto f = File(fileName);
		State state;
		uint n = 0;
		bool future = false;

		Transaction t;
		Report r;

		foreach (line; f.byLine())
		{
			++n;
			scope (failure) stderr.writeln("At line ", n);
			if (line.length == 0)
			{
				if (state == state.InTransaction)
					t = null;
				else if (state == state.InReport)
					r = null;
				state = State.Idle;
				continue;
			}
			else if (line.startsWith('#'))
			{
				continue;
			}

			if (state == State.Idle)
			{
				if (line.startsWith("Account"))
				{
					auto fields = std.array.split(line[7 .. $].strip);
					if (fields.length == 2)
					{
						string name = fields[0].idup;
						result.addAccount(name, fields[1].idup);
						continue;
					}
				}
				else if (line.startsWith("Report"))
				{
					r = result.addReport(line[6 .. $].strip.idup);
					state = State.InReport;
					continue;
				}
				else if (line == "Future:")
				{
					future = true;
					continue;
				}
				else
				{
					auto m = match(line, "([^-]*)-([^-]*)-([^ ]*) *(.*)");
					if (m)
					{
						auto date = Date(
							to!uint(m.captures[1].strip),
							to!uint(m.captures[2].strip),
							to!uint(m.captures[3].strip));
						auto title = m.captures[4].strip.idup;
						if ((date > today) != future)
							stderr.writefln(
								"Warning: transaction `%s %s' " ~
								"should be in section `%s'",
								date, title, !future ? "future" : "past");
						t = result.addTransaction(date, title);
						state = State.InTransaction;
						continue;
					}
				}
			}
			else if (state == State.InTransaction)
			{
				auto m = match(line, "([^ ]*) *-> *([^ ]*) *(.*)");
				if (m)
				{
					result.addMovement(t, m.captures[1].strip.idup,
						-Decimal(m.captures[3].strip.idup));
					result.addMovement(t, m.captures[2].strip.idup,
						Decimal(m.captures[3].strip.idup));
					continue;
				}
				m = match(line, "([^ ]*) *(.*)");
				if (m)
				{
					result.addMovement(t, m.captures[1].strip.idup,
						Decimal(m.captures[2].strip.idup));
					continue;
				}
			}
			else if (state == State.InReport)
			{
				if (line.startsWith("Account"))
				{
					string name = line[7 .. $].strip.idup;
					enforce(name in result._accounts, format(
						"Unknown account `%s' in report `%s'", name, r._name));
					r._accountsToShow ~= result._accounts[name];
					continue;
				}
				else if (line.startsWith("StartDate"))
				{
					r._startDate = parseDate(line[9 .. $].strip);
					continue;
				}
				else if (line.startsWith("EndDate"))
				{
					r._endDate = parseDate(line[7 .. $].strip);
					continue;
				}
				else if (line.startsWith("Monthly"))
				{
					r._showMonthlyBalance = parseOnOff(line[7 .. $].strip);
					continue;
				}
				else if (line.startsWith("Transactions"))
				{
					r._showTransactions = parseOnOff(line[12 .. $].strip);
					continue;
				}
			}
			throw new Exception(format(
				"Invalid syntax at line %s:\n%s", n, line));
		}
		result._transactions.sort();

		return result;
	}

private:
	this() {}
}
