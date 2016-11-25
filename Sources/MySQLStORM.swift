//
//  MySQLStORM.swift
//  MySQLStORM
//
//  Created by Jonathan Guthrie on 2016-10-03.
//
//

import StORM
import MySQL


open class MySQLStORM: StORM, StORMProtocol {
	open var connection = MySQLConnect()
	public var lastStatement: MySQLStmt?

	open func table() -> String {
		return "unset"
	}

	override public init() {
		super.init()
	}

	public init(_ connect: MySQLConnect) {
		super.init()
		self.connection = connect
		lastStatement = MySQLStmt(connect.server)
	}

	private func printDebug(_ statement: String, _ params: [String]) {
		if StORMdebug { print("StORM Debug: \(statement) : \(params.joined(separator: ", "))") }
	}

	// Internal function which executes statements, with parameter binding
	// Returns raw result
	@discardableResult
	func exec(_ statement: String) throws -> MySQL.Results {
		connection.open()
//		defer { connection.server.close() }
		connection.statement = statement

		printDebug(statement, [])
		let querySuccess = connection.server.query(statement: statement)

		guard querySuccess else {
			throw StORMError.error(connection.server.errorMessage())
		}
		let result = connection.server.storeResults()!
		return result
	}
	
	private func fieldNamesToStringArray(_ arr: [Int:String]) -> [String] {
		var out = [String]()
		for i in 0..<arr.count {
			out.append(arr[i]!)
		}
		return out
	}

//	@discardableResult
	func exec(_ statement: String, params: [String], isInsert: Bool = false) throws {
		let thisConnection = MySQLConnect(
			host:		connection.credentials.host,
			username:	connection.credentials.username,
			password:	connection.credentials.password,
			database:	connection.database,
			port:		connection.credentials.port
		)
		thisConnection.open()
		defer { thisConnection.server.close() }
		thisConnection.statement = statement

//		printDebug(statement, params)
		//let querySuccess = connection.server.query(statement: statement, params: params)

		lastStatement = MySQLStmt(thisConnection.server)
		defer { lastStatement?.close() }
		var res = lastStatement?.prepare(statement: statement)
		guard res! else {
			throw StORMError.error(thisConnection.server.errorMessage())
		}

		for p in params {
			lastStatement?.bindParam(p)
		}

		res = lastStatement?.execute()
		guard res! else {
			print(thisConnection.server.errorMessage())
			print(thisConnection.server.errorCode())
			throw StORMError.error(thisConnection.server.errorMessage())
		}

		let result = lastStatement?.results()
		results.foundSetCount = (result?.numRows)!
		if isInsert {
			results.insertedID = Int((lastStatement?.insertId())!)
		}
//		connection.server.close()
//		return result!
	}

	// Internal function which executes statements, with parameter binding
	// Returns a processed row set
	@discardableResult
	func execRows(_ statement: String, params: [String]) throws -> [StORMRow] {
		let thisConnection = MySQLConnect(
			host:		connection.credentials.host,
			username:	connection.credentials.username,
			password:	connection.credentials.password,
			database:	connection.database,
			port:		connection.credentials.port
		)

		thisConnection.open()
		defer { thisConnection.server.close() }
		thisConnection.statement = statement

		//printDebug(statement, params)

		lastStatement = MySQLStmt(thisConnection.server)
//		defer { lastStatement?.close() }
		var res = lastStatement?.prepare(statement: statement)
		guard res! else {
			throw StORMError.error(thisConnection.server.errorMessage())
		}

		for p in params {
			lastStatement?.bindParam(p)
		}

		res = lastStatement?.execute()

		for index in 0..<Int((lastStatement?.fieldCount())!) {
			let this = lastStatement?.fieldInfo(index: index)!
			results.fieldInfo[this!.name] = String(describing: this!.type)
		}

		guard res! else {
			throw StORMError.error(thisConnection.server.errorMessage())
		}

//		let result = connection.server.storeResults()!
		let result = lastStatement?.results()

		results.foundSetCount = (result?.numRows)!
		results.fieldNames = fieldNamesToStringArray((lastStatement?.fieldNames())!)

		let resultRows = parseRows(result!, resultSet: results)
		return resultRows
	}


	open func to(_ this: StORMRow) {
		//		id				= this.data["id"] as! Int
		//		firstname		= this.data["firstname"] as! String
		//		lastname		= this.data["lastname"] as! String
		//		email			= this.data["email"] as! String
	}

	open func makeRow() {
		self.to(self.results.rows[0])
	}

	@discardableResult
	open func save() throws {
		do {
			if keyIsEmpty() {
				try insert(asData(1))
			} else {
				let (idname, idval) = firstAsKey()
				try update(data: asData(1), idName: idname, idValue: idval)
			}
		} catch {
			throw StORMError.error(error.localizedDescription)
		}
	}
	@discardableResult
	open func save(set: (_ id: Any)->Void) throws {
		do {
			if keyIsEmpty() {
				let setId = try insert(asData(1))
				set(setId)
			} else {
				let (idname, idval) = firstAsKey()
				try update(data: asData(1), idName: idname, idValue: idval)
			}
		} catch {
			throw StORMError.error(error.localizedDescription)
		}
	}

	@discardableResult
	override open func create() throws {
		do {
			try insert(asData())
		} catch {
			throw StORMError.error(error.localizedDescription)
		}
	}
	
}
