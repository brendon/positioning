module SqliteTransactionFix
  def begin_db_transaction # :nodoc:
    log("begin transaction", "IMMEDIATE") do
      with_raw_connection(allow_retry: true, materialize_transactions: false) do |conn|
        result = conn.transaction(:immediate)
        verified!
        result
      end
    end
  end
end

module ActiveRecord
  module ConnectionAdapters
    class SQLiteAdapter < AbstractAdapter
      prepend SqliteTransactionFix
    end
  end
end
