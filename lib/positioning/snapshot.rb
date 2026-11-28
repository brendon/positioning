module Positioning
  module Snapshot
    module_function

    def may_be_stale?(connection)
      mysql?(connection) && sent_something?(connection) && repeatable_read?(connection)
    end

    def mysql?(connection)
      connection.adapter_name.match?(/mysql|trilogy/i)
    end

    def sent_something?(connection)
      connection.transaction_open? &&
        (connection.open_transactions > 1 || connection.current_transaction.materialized?)
    end

    def repeatable_read?(connection)
      transaction = connection.current_transaction
      level = transaction.try(:isolation) || transaction.isolation_level
      return level == :repeatable_read if level

      connection.show_variable("transaction_isolation") == "REPEATABLE-READ"
    end
  end
end
