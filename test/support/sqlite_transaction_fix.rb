module SqliteTransactionFix
  module Rails71
    def begin_db_transaction # :nodoc:
      log("begin transaction", "TRANSACTION") do
        with_raw_connection(allow_retry: true, materialize_transactions: false) do |conn|
          result = conn.transaction(:immediate)
          verified!
          result
        end
      end
    end
  end

  module Rails61
    def begin_db_transaction # :nodoc:
      log("begin transaction", "TRANSACTION") { @connection.transaction(:immediate) }
    end
  end
end

module ActiveRecord
  module ConnectionAdapters
    class SQLiteAdapter < AbstractAdapter
      if ActiveRecord.version >= Gem::Version.new("7.1")
        prepend SqliteTransactionFix::Rails71
      else
        prepend SqliteTransactionFix::Rails61
      end
    end
  end
end
