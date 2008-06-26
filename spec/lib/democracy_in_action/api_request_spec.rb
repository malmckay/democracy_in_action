require File.dirname(__FILE__) + "/../../spec_helper"

describe DemocracyInAction::API do
  before do
    @api = DemocracyInAction::API.new( api_arguments ) 
    #Net::HTTP::Post.stub!(:new).and_return(stub_everything)
  end

  describe "build_body" do
    it "should convert key value pair into string" do
      body = @api.send(:build_body, {"key" => "123456"})
      body.should == "key=123456"
    end
    it "should convert multiple key value pairs into string" do
      body = @api.send(:build_body, {"key" => "123456", "email" => "test@domain.org"})
      body.should == "key=123456&email=test%40domain.org"
    end
    it "should convert key value pairs that contain arrays into string" do
      body = @api.send(:build_body, {"key" => "123456", "names" => ["austin", "patrice", "seth"]})
      body.should == "names=austin&names=patrice&names=seth&key=123456"
    end
  end

  describe "disabling" do
    it "is not disabled by default" do
      DemocracyInAction::API.should_not be_disabled
    end

    describe "when disabled" do
      before(:all) do
        DemocracyInAction::API.disable!
      end

      after(:all) do
        class DemocracyInAction::API; @@disabled=false; end
      end

      it "should provide ability to disable actually posting data to DIA" do
        DemocracyInAction::API.should be_disabled
      end
    end
  end

  describe "cookies" do
    it "should have cookies" do
      @api.cookies.should be_an_instance_of(Array)
    end
    it "accepts and keeps cookies" do
      @api.cookies << 'blah'
      @api.cookies << 'blah' 
      @api.cookies.size.should == 2
    end
  end

  describe "get" do

    describe "process_options" do
      it "returns a hash when passed a nil value" do
        @api.send(:process_options, "test", nil).should be_an_instance_of(Hash)
      end
      it "returns a hash with key 'key' when passed a single key" do
        @api.send(:process_options, "test", 5)['key'].should == 5
      end
      it "always adds the table value to the hash" do
        @api.send(:process_options, "test", nil)['table'].should == 'test'
      end
      it "always specifies the request is simple, so as to receive an xml response" do
        @api.send(:process_options, "test", nil)['simple'].should == true
      end
    end

    describe "with multiple keys" do
      it "doesn't change requests without keys" do
        start_hash = { 'test' => 5, "blah" => 2 }
        @api.send(:process_multiple_keys, start_hash.dup ).should == start_hash
      end
      it "doesn't change singular keys" do
        start_hash = { 'test' => 5, "blah" => 2, 'key' => "scram" }
        @api.send(:process_multiple_keys, start_hash.dup ).should == start_hash
      end
      it "changes arrays of keys" do
        start_hash = { 'test' => 5, "blah" => 2, 'key' => [ "scram", 'suckah'] }
        @api.send(:process_multiple_keys, start_hash.dup ).should_not == start_hash
      end
      it "changes arrays of keys to comma-delimited strings" do
        start_hash = { 'test' => 5, "blah" => 2, 'key' => [ "scram", 'suckah'] }
        @api.send(:process_multiple_keys, start_hash.dup )['key'].should == "scram, suckah"
      end
    end

    describe "with process_get_options" do
      it "should return a hash with table and simple" do
        @api.send(:process_get_options, 'test', nil ).keys.should include( 'table' )
        @api.send(:process_get_options, 'test', nil ).keys.should include( 'simple' )
        
      end
    end
  end

  describe "process" do
    describe "link hash" do
      it "raises an error unless it is passed a hash" do
        lambda{ @api.send :linkHashToQueryStringArray, "blech" }.should raise_error
      end
      it "returns an array" do
        @api.send(:linkHashToQueryStringArray, {} ).should be_an_instance_of(Array)
      end
      it "returns an array with the key and value pairs joined" do
        @api.send(:linkHashToQueryStringArray, { 'test' => '5'} ).first.should == 'test|5'
      end
      it "returns an array with the key and value pairs joined, and value arrays processed with the keys duplicated" do
        @api.send(:linkHashToQueryStringArray, { 'test' => [5, 6, 7]} ).should == [ 'test|5','test|6','test|7']
      end
      it "handles multiple table names" do
        @api.send(:linkHashToQueryStringArray, { 'fail' => [72,19], 'test' => [5, 6, 7] } ).should == [ 'fail|72', 'fail|19', 'test|5','test|6','test|7' ]
      end
    end
    describe "process_process_options" do
      it "should call process options to process the options" do
        @api.should_receive(:process_options).with('supporter', {"hello" => "i love you"}).and_return({})
        @api.send(:process_process_options, 'supporter', {"hello" => "i love you"})
      end
    end
  end

  describe "send Request" do
    describe "build request" do
      it "returns a POST" do
        @api.send(:build_request, URI.parse(@api.urls[:get]), {}).should be_an_instance_of(Net::HTTP::Post)
        
      end
      it "imports the authentication to the options" do
        @api.should_receive(:build_body).with(hash_including('user'=>api_arguments[:username],'password' => api_arguments[:password] ))
        @api.send(:build_request, URI.parse(@api.urls[:get]), {})
      end

      describe "modifications" do
        before do
          @req = Net::HTTP::Post.new(URI.parse(@api.urls[:get]).path)
          Net::HTTP::Post.stub!(:new).and_return(@req)
        end
        it "appends the cookies" do
          @api.instance_variable_set( :@cookies, [ 'blah', 'blah' ] )
          @req.should_receive(:add_field).with("Cookie", 'blah').exactly(2).times
          @api.send(:build_request, URI.parse(@api.urls[:get]), {})
        end
        it "appends passed options into the body" do
          @api.should_receive(:build_body).with(hash_including(:joe =>'smokey',:ronah => 'delightful'))
          @api.send(:build_request, URI.parse(@api.urls[:get]), { :joe => 'smokey', :ronah => 'delightful' })
        end
        it "sets the content-type" do
          @req.should_receive(:set_content_type).with('application/x-www-form-urlencoded')
          @api.send(:build_request, URI.parse(@api.urls[:get]), {})
        end
      end
    end

    describe "request and resolution" do
      describe "the actual request" do
        before do
          @net_req = stub( 'request', :start => true, :error! => true, :body => true )
          Net::HTTP.stub!(:new).and_return( @net_req )
        end
        it "is sent" do
          @net_req.should_receive(:start).and_return( @net_req )
          @api.send(:send_request, @api.urls[:get], {})
        end
        it "is resolved" do
          @net_req.stub!(:start).and_return(@net_req)
          @api.should_receive(:resolve).with(@net_req).and_return( @net_req )
          @api.send(:send_request, @api.urls[:get], {})
        end
      end

      describe "resolution" do
        it "calls error on the response unless the response is a success" do
          req = nil
          req.should_receive(:error!)
          @api.send :resolve, req 
        end


        describe "response is a success" do
          before do
            @req = stub( 'response', :get_fields => false )
            @req.stub!(:is_a?).with(Net::HTTPSuccess).and_return(true)
          end

          it "does not call error on a success" do
            @req.should_not_receive(:error!)
            @api.send :resolve, @req 
          end

          it "extracts cookies from the response" do
            @req.stub!(:get_fields).and_return([ 'blah', 'blue', 'blunder' ] )
            @api.send :resolve, @req 
            @api.cookies.should == [ 'blah', 'blue', 'blunder' ]
          end
          it "returns the first argument" do
            @api.send( :resolve, @req  ).should == @req
          end
        end
      end
    end
  end
end
