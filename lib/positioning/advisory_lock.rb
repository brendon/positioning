require "fileutils"

module Positioning
  class AdvisoryLock
    Adapter = Struct.new(:aquire, :release, keyword_init: true)

    attr_reader :base_class

    def initialize(base_class)
      @base_class = base_class

      @adapters = {
        "Mysql2" => Adapter.new(
          aquire: -> { connection.execute "SELECT GET_LOCK(#{connection.quote(lock_name)}, -1)" },
          release: -> { connection.execute "SELECT RELEASE_LOCK(#{connection.quote(lock_name)})" }
        ),
        "PostgreSQL" => Adapter.new(
          aquire: -> { connection.execute "SELECT pg_advisory_lock(#{lock_name.hex & 0x7FFFFFFFFFFFFFFF})" },
          release: -> { connection.execute "SELECT pg_advisory_unlock(#{lock_name.hex & 0x7FFFFFFFFFFFFFFF})" }
        ),
        "SQLite" => Adapter.new(
          aquire: -> {
            FileUtils.mkdir_p "#{Dir.pwd}/tmp"
            filename = "#{Dir.pwd}/tmp/#{lock_name}.lock"
            FileUtils.touch filename
            @file ||= File.open filename, "r+"
            @file.flock File::LOCK_EX
          },
          release: -> {
            @file.flock File::LOCK_UN
          }
        )
      }

      @adapters.default = Adapter.new(aquire: -> {}, release: -> {})
    end

    def aquire(record)
      adapter.aquire.call
    end

    def release(record)
      adapter.release.call
    end

    alias_method :before_save, :aquire
    alias_method :before_destroy, :aquire
    alias_method :after_commit, :release
    alias_method :after_rollback, :release

    private

    def connection
      base_class.connection
    end

    def adapter_name
      connection.adapter_name
    end

    def adapter
      @adapters[adapter_name]
    end

    def lock_name
      lock_name = ["positioning"]
      lock_name << connection.current_database if connection.respond_to?(:current_database)
      lock_name << base_class.table_name

      ActiveSupport::Digest.hexdigest lock_name.join(".")
    end
  end
end
