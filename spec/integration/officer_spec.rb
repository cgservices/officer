require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe Officer do
  before do
    @server = Officer::Server.new :stats => true # :log_level => "debug"
    @server.instance_variable_set("@enable_shutdown_port", true)
    @server_thread = Thread.new {@server.run}
    while !@server.running?; end
  end

  after do
    shutdown_socket = TCPSocket.new("127.0.0.1", 11501)
    shutdown_socket.close
    while @server.running?; end
  end

  describe "COMMAND: with_lock" do
    before do
      @client = Officer::Client.new
    end

    after do
      @client.send("disconnect")
      @client = nil
    end

    it "should allow a client to request and release a lock using block syntax" do
      @client.with_lock("testlock") do
        @client.my_locks.should eq({"value"=>["testlock"], "result"=>"my_locks"})
      end
    end
  end

  describe "COMMAND: reset" do
    before do
      @client = Officer::Client.new
    end

    after do
      @client.send("disconnect")
      @client = nil
    end

    it "should allow a client to reset all of its locks (release them all)" do
      @client.lock("testlock1")
      @client.lock("testlock2")
      actual = @client.my_locks
      expected = {"value"=>["testlock1", "testlock2"], "result"=>"my_locks"}
      actual.class.should eq(Hash)
      actual["value"].sort.should eq(expected["value"].sort)
      actual["result"].should eq(expected["result"])
      @client.reset
      @client.my_locks.should eq({"value"=>[], "result"=>"my_locks"})
    end
  end

  describe "COMMAND: reconnect" do
    before do
      @client = Officer::Client.new
    end

    after do
      @client.send("disconnect")
      @client = nil
    end

    it "should allow a client to force a reconnect in order to get a new socket" do
      original_socket = @client.instance_variable_get("@socket")
      @client.reconnect
      @client.instance_variable_get("@socket").should_not eq(original_socket)
      @client.my_locks.should eq({"value"=>[], "result"=>"my_locks"})
    end
  end

  describe "COMMAND: connections" do
    before do
      @client1 = Officer::Client.new
      @client2 = Officer::Client.new

      @client1_src_port = @client1.instance_variable_get('@socket').addr[1]
      @client2_src_port = @client2.instance_variable_get('@socket').addr[1]

      @client1.lock("client1_testlock1")
      @client1.lock("client1_testlock2")
      @client2.lock("client2_testlock1")
      @client2.lock("client2_testlock2")
    end

    after do
      @client1.send("disconnect")
      @client1 = nil
      @client2.send("disconnect")
      @client2 = nil
    end

    it "should allow a client to see all the connections to a server" do
      connections = @client2.connections

      connections["value"]["127.0.0.1:#{@client1_src_port}"].sort.should eq(["client1_testlock1", "client1_testlock2"].sort)
      connections["value"]["127.0.0.1:#{@client2_src_port}"].sort.should eq(["client2_testlock1", "client2_testlock2"].sort)
      connections["value"].keys.length.should eq(2)
      connections["result"].should eq("connections")
    end
  end

  describe "COMMAND: locks" do
    before do
      @client1 = Officer::Client.new
      @client2 = Officer::Client.new

      @client1_src_port = @client1.instance_variable_get('@socket').addr[1]
      @client2_src_port = @client2.instance_variable_get('@socket').addr[1]

      @client1.lock("client1_testlock1")
      @client1.lock("client1_testlock2")
      @client2.lock("client2_testlock1")
      @client2.lock("client2_testlock2")
    end

    after do
      @client1.send("disconnect")
      @client1 = nil
      @client2.send("disconnect")
      @client2 = nil
    end

    it "should allow a client to see all the locks on a server (including those owned by other clients)" do
      locks = @client2.locks

      locks["value"]["client1_testlock1"].should eq(["127.0.0.1:#{@client1_src_port}"])
      locks["value"]["client1_testlock2"].should eq(["127.0.0.1:#{@client1_src_port}"])
      locks["value"]["client2_testlock1"].should eq(["127.0.0.1:#{@client2_src_port}"])
      locks["value"]["client2_testlock2"].should eq(["127.0.0.1:#{@client2_src_port}"])
      locks["value"].length.should eq(4)
      locks["result"].should eq("locks")
    end
  end

  describe "COMMAND: my_locks" do
    before do
      @client = Officer::Client.new
    end

    after do
      @client.send("disconnect")
      @client = nil
    end

    it "should allow a client to request its locks" do
      @client.lock("testlock")
      @client.my_locks.should eq({"value"=>["testlock"], "result"=>"my_locks"})
    end
  end

  describe "COMMAND: lock & unlock" do
    describe "basic functionality" do
      before do
        @client = Officer::Client.new
      end

      after do
        @client.send("disconnect")
        @client = nil
      end

      it "should allow a client to request and release a lock" do
        @client.lock("testlock").should eq({"result" => "acquired", "name" => "testlock", "lock_id" => "0"})
        @client.my_locks.should eq({"value"=>["testlock"], "result"=>"my_locks"})
        @client.unlock("testlock")
        @client.my_locks.should eq({"value"=>[], "result"=>"my_locks"})
      end

      it "should inform the client they already have a lock if they previously locked it" do
        @client.lock("testlock").should eq({"result" => "acquired", "name" => "testlock", "lock_id" => "0"})
        @client.lock("testlock").should eq({"result" => "already_acquired", "name" => "testlock"})
      end

      it "should inform the client they don't have a lock if they try to unlock a lock that they don't have" do
        @client.unlock("testlock").should eq({"result" => "release_failed", "name" => "testlock"})
      end
    end

    describe "locking options" do
      describe "OPTION: timeout" do
        before do
          @client1 = Officer::Client.new
          @client2 = Officer::Client.new

          @client1_src_port = @client1.instance_variable_get('@socket').addr[1]
          @client2_src_port = @client2.instance_variable_get('@socket').addr[1]

          @client1.lock("testlock")
        end

        after do
          @client1.send("disconnect")
          @client1 = nil
          @client2.send("disconnect")
          @client2 = nil
        end

        it "should allow a client to set an instant timeout when obtaining a lock" do
          @client2.lock("testlock", :timeout => 0).should eq(
            {"result"=>"timed_out", "name"=>"testlock", "queue"=>["127.0.0.1:#{@client1_src_port}"]}
          )
        end

        it "should allow a client to set an instant timeout when obtaining a lock (block syntax)" do
          lambda {
            @client2.with_lock("testlock", :timeout => 0){}
          }.should raise_error(Officer::LockTimeoutError, "queue=127.0.0.1:#{@client1_src_port}")
        end

        it "should allow a client to set a positive integer timeout when obtaining a lock" do
          time = Benchmark.realtime do
            @client2.lock("testlock", :timeout => 1).should eq(
              {"result"=>"timed_out", "name"=>"testlock", "queue"=>["127.0.0.1:#{@client1_src_port}"]}
            )
          end
          time.should > 1
          time.should < 1.5
        end
      end

      describe "OPTION: queue_max" do
        before do
          @client1 = Officer::Client.new
          @client1.lock("testlock")

          @thread1 = Thread.new {
            @client2 = Officer::Client.new
            @client2.lock("testlock")
          }

          @thread2 = Thread.new {
            @client3 = Officer::Client.new
            @client3.lock("testlock")
          }

          @client4 = Officer::Client.new
          while @client4.locks["value"]["testlock"].count != 3; end

          @client1_src_port = @client1.instance_variable_get('@socket').addr[1]
          @client2_src_port = @client2.instance_variable_get('@socket').addr[1]
          @client3_src_port = @client3.instance_variable_get('@socket').addr[1]
        end

        after do
        end

        it "should allow a client to abort lock acquisition if the wait queue is too long" do
          actual = @client4.lock("testlock", :queue_max => 3)
          expected = {
            "result" => "queue_maxed",
            "name" => "testlock",
            "queue" => ["127.0.0.1:#{@client1_src_port}", "127.0.0.1:#{@client2_src_port}", "127.0.0.1:#{@client3_src_port}"]
          }
          actual.class.should eq(Hash)
          actual["result"].should eq(expected["result"])
          actual["name"].should eq(expected["name"])
          actual["queue"].sort.should eq(expected["queue"].sort)
        end

        it "should allow a client to abort lock acquisition if the wait queue is too long (block syntax)" do
          lambda {
            @client4.with_lock("testlock", :queue_max => 3) {}
          }.should raise_error(Officer::LockQueuedMaxError)
        end
      end

      describe "OPTION: namespace" do
        before do
          @client = Officer::Client.new(:namespace => "myapp")
        end

        after do
          @client.send("disconnect")
          @client = nil
        end

        it "should allow a client to set a namespace when obtaining a lock" do
          @client.with_lock("testlock") do
            @client.locks["value"]["myapp:testlock"].should_not eq(nil)
          end
        end
      end
    end

    describe "EXPERIMENTAL: server support for non-blocking clients attempting to release a queued lock request" do
      before do
        @client = Officer::Client.new

        @socket = TCPSocket.new "127.0.0.1", 11500
        @socket = TCPSocket.new "127.0.0.1", 11500
      end

      after do
        @client.send("disconnect")
        @client = nil

        @socket.close
        @socket = nil
      end

      it "should inform the client that their request has been de-queued" do
        @client.lock("testlock")
        @socket.write("{\"command\":\"lock\",\"name\":\"testlock\"}\n")
        @socket.write("{\"command\":\"unlock\",\"name\":\"testlock\"}\n")
        JSON.parse(@socket.gets("\n").chomp).should eq({"result" => "released", "name" => "testlock"})
      end
    end

    describe "NEW: server support for multiple locks" do
      before do
        @client1 = Officer::Client.new
        @client2 = Officer::Client.new
        @client3 = Officer::Client.new

        @client1_src_port = @client1.instance_variable_get('@socket').addr[1]
        @client2_src_port = @client2.instance_variable_get('@socket').addr[1]
        @client3_src_port = @client2.instance_variable_get('@socket').addr[1]
      end

      after do
        @client1.send("disconnect")
        @client1 = nil
        @client2.send("disconnect")
        @client2 = nil
        @client3.send("disconnect")
        @client3 = nil
      end

      it "should allow a client to obtaining and releasing the number of allowed locks" do
        @client1.lock("testlock#2").should eq({"result" => "acquired", "name" => "testlock#2", "lock_id" => "0"})
        @client2.lock("testlock#2").should eq({"result" => "acquired", "name" => "testlock#2", "lock_id" => "1"})
        @client1.locks.should eq({"value"=>{"testlock#2"=>["127.0.0.1:#{@client1_src_port}", "127.0.0.1:#{@client2_src_port}"]}, "result"=>"locks"})
        @client2.locks.should eq({"value"=>{"testlock#2"=>["127.0.0.1:#{@client1_src_port}", "127.0.0.1:#{@client2_src_port}"]}, "result"=>"locks"})
        @client1.my_locks.should eq({"value"=>["testlock#2"], "result"=>"my_locks"})
        @client2.my_locks.should eq({"value"=>["testlock#2"], "result"=>"my_locks"})
        @client1.unlock("testlock#2")
        @client2.unlock("testlock#2")
        @client1.locks.should eq({"value"=>{}, "result"=>"locks"})
      end

      it "should not allow a client to request a lock that is already acquired" do
        @client1.lock("testlock#2").should eq({"result" => "acquired", "name" => "testlock#2", "lock_id" => "0"})
        @client1.lock("testlock#2").should eq({"result" => "already_acquired", "name" => "testlock#2"})
        @client2.unlock("testlock#2")
      end

      it "should allow timeout if number of allowed connections is reached" do
        @client1.lock("testlock#2").should eq({"result" => "acquired", "name" => "testlock#2", "lock_id" => "0"})
        @client2.lock("testlock#2").should eq({"result" => "acquired", "name" => "testlock#2", "lock_id" => "1"})
        @client3.lock("testlock#2", :timeout => 0).should eq(
          {"result"=>"timed_out", "name"=>"testlock#2", "queue"=>["127.0.0.1:#{@client1_src_port}", "127.0.0.1:#{@client2_src_port}"]}
        )
      end

      it "should queue a connection if number of allowed connections is reached and allow connection if a lock is released" do
        t = Thread.new do
          @client1.lock("testlock#2").should eq({"result" => "acquired", "name" => "testlock#2", "lock_id" => "0"})
          @client2.lock("testlock#2").should eq({"result" => "acquired", "name" => "testlock#2", "lock_id" => "1"})
          @client3.lock("testlock#2").should eq({"result" => "acquired", "name" => "testlock#2", "lock_id" => "0"})
        end
        
        t2 = Thread.new do
          puts @client1.locks
          @client1.unlock
          puts @client1.locks
        end
        sleep 5
      end
    end
  end
end
