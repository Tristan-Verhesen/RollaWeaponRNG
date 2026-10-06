--!strict
--[[
	Minimal typed signal. Listeners run in their own threads so one erroring listener cannot
	break the others or the code that fired the signal.
]]

export type Connection = {
	Connected: boolean,
	Disconnect: (self: Connection) -> (),
}

export type Signal<T...> = {
	Connect: (self: Signal<T...>, callback: (T...) -> ()) -> Connection,
	Once: (self: Signal<T...>, callback: (T...) -> ()) -> Connection,
	Fire: (self: Signal<T...>, T...) -> (),
	DisconnectAll: (self: Signal<T...>) -> (),
}

type Entry<T...> = {
	callback: (T...) -> (),
	connection: Connection,
}

local Signal = {}

function Signal.new<T...>(): Signal<T...>
	local entries: { Entry<T...> } = {}

	local function connect(callback: (T...) -> ()): Connection
		local connection: Connection
		connection = {
			Connected = true,
			Disconnect = function(self: Connection)
				if not self.Connected then
					return
				end
				self.Connected = false
				for index, entry in entries do
					if entry.connection == connection then
						table.remove(entries, index)
						break
					end
				end
			end,
		}
		table.insert(entries, { callback = callback, connection = connection })
		return connection
	end

	local signal: Signal<T...> = {
		Connect = function(_self: Signal<T...>, callback: (T...) -> ()): Connection
			return connect(callback)
		end,
		Once = function(_self: Signal<T...>, callback: (T...) -> ()): Connection
			local connection: Connection
			connection = connect(function(...: T...)
				connection:Disconnect()
				callback(...)
			end)
			return connection
		end,
		Fire = function(_self: Signal<T...>, ...: T...)
			for _, entry in table.clone(entries) do
				if entry.connection.Connected then
					task.spawn(entry.callback, ...)
				end
			end
		end,
		DisconnectAll = function(_self: Signal<T...>)
			for _, entry in entries do
				entry.connection.Connected = false
			end
			table.clear(entries)
		end,
	}
	return signal
end

return Signal
