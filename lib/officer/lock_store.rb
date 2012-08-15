module Officer

  class LockQueue < Array
    def to_host_a
      map {|conn| conn.to_host_s}
    end
  end

  class Lock
    attr_reader :name
    attr_reader :size
    attr_reader :queue
    attr_reader :lock_ids

    def initialize name, size = 1
      @name = name
      @size = size.to_i
      @lock_ids = (0..@size-1).to_a
      @queue = LockQueue.new
    end
  end

  class LockStore
    include Singleton

    def initialize
      @locks = {} # name => Lock
      @connections = {} # Connection => Set(name, ...)
      @locked_connections = {} # {lock_id => Connection}
      @acquire_counter = 0
      @mutex = Mutex.new
    end

    def log_state
      l = Officer::Log

      l.info '-----'

      l.info 'LOCK STORE:'
      l.info ''

      l.info "locks:"
      @locks.each do |name, lock|
        l.info "#{name}: connections=[#{lock.queue.to_host_a.join(', ')}]"
      end
      l.info ''

      l.info "Connections:"
      @connections.each do |connection, names|
        l.info "#{connection.to_host_s}: names=[#{names.to_a.join(', ')}]"
      end
      l.info ''

      l.info "Acquire Rate: #{@acquire_counter.to_f / 5}/s"
      @acquire_counter = 0

      l.info '-----'
    end

    def acquire name, connection, options={}
      name, size = split_name(name)

      if options[:queue_max]
        lock = @locks[name]

        if lock && !lock.queue.include?(connection) && lock.queue.length >= options[:queue_max]
          connection.queue_maxed name, :queue => lock.queue.to_host_a
          return
        end
      end

      @acquire_counter += 1

      lock = @locks[name] ||= Lock.new(name, size)

      if lock.queue[0..lock.size-1].include?(connection)
        return connection.already_acquired(name)
      end

      if lock.queue.count < lock.size
        lock.queue << connection
        lock_id = lock_connection(connection, lock)
        (@connections[connection] ||= Set.new) << name

        connection.acquired name, lock_id
      else
        lock.queue << connection
        (@connections[connection] ||= Set.new) << name

        connection.queued(name, options)
      end
    end

    def release name, connection, options={}
      name, size = split_name(name)

      if options[:callback].nil?
        options[:callback] = true
      end
      lock = @locks[name]
      names = @connections[connection]
      # Client should only be able to release a lock that
      # exists and that it has previously queued.
      if lock.nil? || names.nil? || !names.include?(name)
        connection.release_failed(name) if options[:callback]
        return
      end

      # If connecton has the lock, release it and let the next
      # connection know that it has acquired the lock.
      if index = lock.queue.index(connection)
        if index < lock.size
          lock.queue.delete_at(index)
          release_connection(connection, lock)

          connection.released name if options[:callback]

          if next_connection = lock.queue[lock.size-1]
            lock_id = lock_connection(next_connection, lock)
            next_connection.acquired name, lock_id
          end
          @locks.delete name if lock.queue.count == 0

        # If the connection is queued and doesn't have the lock,
        # dequeue it and leave the other connections alone.
        else
          lock.queue.delete connection
          connection.released name
        end
        names.delete name
      end
    end

    def reset connection
      # names = @connections[connection] || []
      names = @connections[connection] || Set.new

      names.each do |name|
        release name, connection, :callback => false
      end

      @connections.delete connection
      connection.reset_succeeded
    end

    def timeout name, connection
      name, size = split_name(name)

      lock = @locks[name]
      names = @connections[connection]

      return if lock.queue.first == connection # Don't timeout- already have the lock.

      lock.queue.delete connection
      names.delete name

      connection.timed_out name, :queue => lock.queue.to_host_a
    end

    def locks connection
      locks = {}

      @locks.each do |name, lock|
        locks[name] = lock.queue.to_host_a
      end

      connection.locks locks
    end

    def connections connection
      connections = {}

      @connections.each do |conn, names|
        connections[conn.to_host_s] = names.to_a
      end

      connection.connections connections
    end

    def my_locks connection
      my_locks = @connections[connection] ? @connections[connection].to_a : []
      connection.my_locks my_locks
    end

    def close_idle_connections(max_idle)
      @connections.each do |conn, names|
        if conn.last_cmd_at < Time.now.utc - max_idle
          Officer::Log.error "Closing due to max idle time: #{conn.to_host_s}"
          conn.close_connection
        end
      end
    end

    protected
    def split_name(name)
      if name.include?("#")
        name_array = name.split("#")
        size = (name_array.last.to_i > 0 && name_array.size > 1) ? name_array.last.to_i : 1
      else
        size = 1
      end
      [name, size]
    end

    def lock_connection(connection, lock)
      @mutex.synchronize do
        @locked_connections[lock.lock_ids.first] = connection
        lock_id = lock.lock_ids.shift
        lock.lock_ids.push(lock_id)
        lock_id
      end
    end

    def release_connection(connection, lock)
      @mutex.synchronize do
        if lock_id = @locked_connections.key(connection)
          lock.lock_ids.delete(lock_id)
          lock.lock_ids.insert(0, lock_id)
          lock_id
        end
      end
    end
  end

end
