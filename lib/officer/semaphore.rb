module Officer
  class Semaphore
    attr_accessor :size

    def initialize(host, port, name, size)
      size ||= 1

      @client = Officer::Client.new(:host => host, :port => port)
      @name = "#{name}##{size}"
      @size = size
    end

    def lock
      @client.lock(@name)
    end

    def unlock
      @client.unlock(@name)
    end

    def synchronize
      @client.with_lock @name do
        yield
      end
    end
  end
end