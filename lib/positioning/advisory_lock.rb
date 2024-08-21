require "fileutils"
require "openssl"

module Positioning
  class AdvisoryLock
    Adapter = Struct.new(:initialise, :acquire, :release, keyword_init: true)

    attr_reader :base_class

    def initialize(base_class, column, enabled)
      @base_class = base_class
      @column = column.to_s
      @enabled = enabled

      @adapters = {
        "mysql2" => Adapter.new(
          initialise: -> {},
          acquire: -> { connection.execute "SELECT GET_LOCK(#{connection.quote(lock_name)}, -1)" },
          release: -> { connection.execute "SELECT RELEASE_LOCK(#{connection.quote(lock_name)})" }
        ),
        "postgresql" => Adapter.new(
          initialise: -> {},
          acquire: -> { connection.execute "SELECT pg_advisory_lock(#{lock_name.hex & 0x7FFFFFFFFFFFFFFF})" },
          release: -> { connection.execute "SELECT pg_advisory_unlock(#{lock_name.hex & 0x7FFFFFFFFFFFFFFF})" }
        ),
        "sqlite3" => Adapter.new(
          initialise: -> {
            FileUtils.mkdir_p "#{Dir.pwd}/tmp"
            filename = "#{Dir.pwd}/tmp/#{lock_name}.lock"
            @file ||= File.open filename, File::RDWR | File::CREAT, 0o644
          },
          acquire: -> {
            @file.flock File::LOCK_EX
          },
          release: -> {
            @file.flock File::LOCK_UN
          }
        )
      }

      @adapters.default = Adapter.new(initialise: -> {}, acquire: -> {}, release: -> {})

      adapter.initialise.call if @enabled
    end

    def acquire
      adapter.acquire.call if @enabled

      if block_given?
        yield
        adapter.release.call if @enabled
      end
    end

    def release
      adapter.release.call if @enabled
    end

    private

    def connection
      base_class.connection
    end

    def adapter_name
      base_class.connection_db_config.adapter
    end

    def adapter
      @adapters[adapter_name]
    end

    def lock_name
      lock_name = ["positioning"]
      lock_name << connection.current_database if connection.respond_to?(:current_database)
      lock_name << base_class.table_name
      lock_name << @column

      OpenSSL::Digest::MD5.hexdigest(lock_name.join("."))[0...32]
    end
  end
end
