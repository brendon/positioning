module Positioning
  class AdvisoryLock
    Adapter = Struct.new(:aquire, :release, keyword_init: true)

    def initialize(positioned)
      @positioned = positioned

      @adapters = {
        "Mysql2" => Adapter.new(
          aquire: -> { "SELECT GET_LOCK(#{connection.quote(lock_name)}, -1)" },
          release: -> { "SELECT RELEASE_LOCK(#{connection.quote(lock_name)})" }
        ),
        "PostgreSQL" => Adapter.new(
          aquire: -> { "SELECT pg_advisory_lock(#{lock_name.hex & 0x7FFFFFFFFFFFFFFF})" },
          release: -> { "SELECT pg_advisory_unlock(#{lock_name.hex & 0x7FFFFFFFFFFFFFFF})" }
        )
      }
    end

    def aquire
      execute adapter.aquire.call if adapter
    end

    def release
      execute adapter.release.call if adapter
    end

    private

    def base_class
      @positioned.class.base_class
    end

    def connection
      base_class.connection
    end

    def adapter_name
      connection.adapter_name
    end

    def lock_name
      ActiveSupport::Digest.hexdigest "#{connection.current_database}.#{base_class.table_name}"
    end

    def adapter
      @adapters[adapter_name]
    end

    def execute(command)
      ActiveRecord::Base.connection.execute command
    end
  end
end
