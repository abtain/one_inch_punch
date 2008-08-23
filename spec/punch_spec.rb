require File.dirname(__FILE__) + '/spec_helper.rb'

describe Punch do
  it 'should load data' do
    Punch.should respond_to(:load)
  end
  
  describe 'when loading data' do
    before :each do
      @data = <<-EOD
      ---
      rip: 
      - out: 2008-05-19T18:34:39.00-05:00
        log: 
        - punch in @ 2008-05-19T17:09:05-05:00
        - punch out @ 2008-05-19T18:34:39-05:00
        total: "01:25:34"
        in: 2008-05-19T17:09:05.00-05:00
      - out: 2008-05-19T21:04:03.00-05:00
        total: "00:50:22"
        log: 
        - punch in @ 2008-05-19T20:13:41-05:00
        - punch out @ 2008-05-19T21:04:03-05:00
        in: 2008-05-19T20:13:41.00-05:00
      ps: 
      - out: 2008-05-19T12:18:52.00-05:00
        log: 
        - punch in @ 2008-05-19T11:23:35-05:00
        - punch out @ 2008-05-19T12:18:52-05:00
        total: "00:55:17"
        in: 2008-05-19T11:23:35.00-05:00
      EOD
      File.stubs(:read).returns(@data)
      
      Punch.instance_eval do
        class << self
          public :data
        end
      end
      
      Punch.reset
    end
    
    it 'should read the ~/.punch.yml file' do
      File.expects(:read).with(File.expand_path('~/.punch.yml')).returns(@data)
      Punch.load
    end
    
    describe 'when the file is found' do
      it 'should load the data as yaml' do
        Punch.load
        Punch.data.should == YAML.load(@data)
      end
      
      it 'should return true' do
        Punch.load.should == true
      end
    end
    
    describe 'when no file is found' do
      before :each do
        File.stubs(:read).raises(Errno::ENOENT)
      end
      
      it 'should leave the data blank' do
        Punch.load
        Punch.data.should be_nil
      end
      
      it 'should return false' do
        Punch.load.should == false
      end
    end
  end
  
  it 'should reset itself' do
    Punch.should respond_to(:reset)
  end
  
  describe 'when resetting itself' do
    before :each do
      Punch.instance_eval do
        class << self
          public :data, :data=
        end
      end
    end
    
    it 'should set its data to nil' do
      Punch.data = { 'proj' => 'lots of stuff here' }
      Punch.reset
      Punch.data.should be_nil
    end
  end
  
  it 'should write data' do
    Punch.should respond_to(:write)
  end
  
  describe 'when writing data' do
    before :each do
      @file = stub('file')
      File.stubs(:open).yields(@file)
      @data = { 'proj' => 'data goes here' }
      
      Punch.instance_eval do
        class << self
          public :data=
        end
      end
      Punch.data = @data
    end
    
    it 'should open the data file for writing' do
      File.expects(:open).with(File.expand_path('~/.punch.yml'), 'w')
      Punch.write
    end
    
    it 'should write the data to the file in YAML form' do
      @file.expects(:puts).with(@data.to_yaml)
      Punch.write
    end
  end
  
  it "should give a project's status" do
    Punch.should respond_to(:status)
  end
  
  describe "giving a project's status" do
    before :each do
      @now = Time.now
      @projects = { 'out' => 'test-o', 'in' => 'testshank' }
      @data = { 
        @projects['out'] => [ { 'in' => @now, 'out' => @now + 12 } ],
        @projects['in']  => [ { 'in' => @now } ]
      }
      
      Punch.instance_eval do
        class << self
          public :data=
        end
      end
      Punch.data = @data
    end
    
    it 'should accept a project name' do
      lambda { Punch.status('proj') }.should_not raise_error(ArgumentError)
    end
    
    it 'should require a project name' do
      lambda { Punch.status }.should raise_error(ArgumentError)
    end
    
    it "should return 'out' if the project is currently punched out" do
      Punch.status(@projects['out']).should == 'out'
    end
    
    it "should return 'in' if the project is currently punched in" do
      Punch.status(@projects['in']).should == 'in'
    end
    
    it 'should return nil if the project does not exist' do
      Punch.status('other project').should be_nil
    end
    
    it 'should return nil if the project has no time data' do
      project = 'empty project'
      @data[project] = []
      Punch.data = @data
      Punch.status(project).should be_nil
    end
    
    it 'should use the last time entry for the status' do
      @data[@projects['out']].unshift *[{ 'in' => @now - 100 }, { 'in' => @now - 90, 'out' => @now - 50 }]
      @data[@projects['in']].unshift  *[{ 'in' => @now - 100, 'out' => @now - 90 }, { 'in' => @now - 50 }]
      Punch.data = @data
      
      Punch.status(@projects['out']).should == 'out'
      Punch.status(@projects['in']).should  == 'in'
    end
  end
  
  it 'should indicate whether a project is punched out' do
    Punch.should respond_to(:out?)
  end
  
  describe 'indicating whether a project is punched out' do
    before :each do
      @project = 'testola'
    end
    
    it 'should accept a project name' do
      lambda { Punch.out?('proj') }.should_not raise_error(ArgumentError)
    end
    
    it 'should require a project name' do
      lambda { Punch.out? }.should raise_error(ArgumentError)
    end
        
    it "should get the project's status" do
      Punch.expects(:status).with(@project)
      Punch.out?(@project)
    end
    
    it "should return true if the project's status is 'out'" do
      Punch.stubs(:status).returns('out')
      Punch.out?(@project).should == true
    end
    
    it "should return false if the project's status is 'in'" do
      Punch.stubs(:status).returns('in')
      Punch.out?(@project).should == false
    end
    
    it "should return true if the project's status is nil" do
      Punch.stubs(:status).returns(nil)
      Punch.out?(@project).should == true
    end
  end
  
  it 'should indicate whether a project is punched in' do
    Punch.should respond_to(:in?)
  end
  
  describe 'indicating whether a project is punched in' do
    before :each do
      @project = 'testola'
    end
    
    it 'should accept a project name' do
      lambda { Punch.in?('proj') }.should_not raise_error(ArgumentError)
    end
    
    it 'should require a project name' do
      lambda { Punch.in? }.should raise_error(ArgumentError)
    end
        
    it "should get the project's status" do
      Punch.expects(:status).with(@project)
      Punch.in?(@project)
    end
    
    it "should return false if the project's status is 'out'" do
      Punch.stubs(:status).returns('out')
      Punch.in?(@project).should == false
    end
    
    it "should return true if the project's status is 'in'" do
      Punch.stubs(:status).returns('in')
      Punch.in?(@project).should == true
    end
    
    it "should return false if the project's status is nil" do
      Punch.stubs(:status).returns(nil)
      Punch.in?(@project).should == false
    end
  end
  
  it 'should punch a project in' do
    Punch.should respond_to(:in)
  end
  
  describe 'punching a project in' do
    before :each do
      @now = Time.now
      Time.stubs(:now).returns(@now)
      @project = 'test project'
      @data = { @project => [ {'in' => @now - 50, 'out' => @now - 25} ] }
      
      Punch.instance_eval do
        class << self
          public :data, :data=
        end
      end
      Punch.data = @data
      
      @test = states('test').starts_as('setup')
      Punch.stubs(:write).when(@test.is('setup'))
    end
    
    it 'should accept a project name' do
      lambda { Punch.in('proj') }.should_not raise_error(ArgumentError)
    end
    
    it 'should require a project name' do
      lambda { Punch.in }.should raise_error(ArgumentError)
    end
    
    it 'should check whether the project is already punched in' do
      Punch.expects(:in?).with(@project)
      Punch.in(@project)
    end
    
    describe 'when the project is already punched in' do
      before :each do
        Punch.stubs(:in?).returns(true)
      end
      
      it 'should not change the project data' do
        Punch.in(@project)
        Punch.data.should == @data
      end
      
      it 'should not write the data' do
        @test.become('test')
        Punch.expects(:write).never.when(@test.is('test'))
        Punch.in(@project)
      end
      
      it 'should return false' do
        Punch.in(@project).should == false
      end
    end
    
    describe 'when the project is not already punched in' do
      before :each do
        Punch.stubs(:in?).returns(false)
      end
      
      it 'should add a time entry to the project data' do
        Punch.in(@project)
        Punch.data[@project].length.should == 2
      end
      
      it 'should use now for the punch-in time' do
        Punch.in(@project)
        Punch.data[@project].last['in'].should == @now
      end
      
      it 'should write the data' do
        @test.become('test')
        Punch.expects(:write).when(@test.is('test'))
        Punch.in(@project)
      end
      
      it 'should return true' do
        Punch.in(@project).should == true
      end
    end
    
    describe 'when the project does not yet exist' do
      before :each do
        @project = 'non-existent project'
      end
      
      it 'should create the project' do
        Punch.in(@project)
        Punch.data.should include(@project)
      end
      
      it 'should add a time entry to the project data' do
        Punch.in(@project)
        Punch.data[@project].length.should == 1
      end
      
      it 'should use now for the punch-in time' do
        Punch.in(@project)
        Punch.data[@project].last['in'].should == @now
      end
      
      it 'should write the data' do
        @test.become('test')
        Punch.expects(:write).when(@test.is('test'))
        Punch.in(@project)
      end
      
      it 'should return true' do
        Punch.in(@project).should == true
      end
    end
  end
  
  it 'should punch a project out' do
    Punch.should respond_to(:out)
  end
  
  describe 'punching a project out' do
    before :each do
      @now = Time.now
      Time.stubs(:now).returns(@now)
      @project = 'test project'
      @data = { @project => [ {'in' => @now - 50, 'out' => @now - 25} ] }
      
      Punch.instance_eval do
        class << self
          public :data, :data=
        end
      end
      Punch.data = @data
      
      @test = states('test').starts_as('setup')
      Punch.stubs(:write).when(@test.is('setup'))
    end
    
    it 'should accept a project name' do
      lambda { Punch.out('proj') }.should_not raise_error(ArgumentError)
    end
    
    it 'should require a project name' do
      lambda { Punch.out }.should raise_error(ArgumentError)
    end
    
    it 'should check whether the project is already punched out' do
      Punch.expects(:out?).with(@project)
      Punch.out(@project)
    end
    
    describe 'when the project is already punched out' do
      before :each do
        Punch.stubs(:out?).returns(true)
      end
      
      it 'should not change the project data' do
        Punch.out(@project)
        Punch.data.should == @data
      end
      
      it 'should not write the data' do
        @test.become('test')
        Punch.expects(:write).never.when(@test.is('test'))
        Punch.out(@project)
      end
      
      it 'should return false' do
        Punch.out(@project).should == false
      end
    end
    
    describe 'when the project is not already punched out' do
      before :each do
        Punch.stubs(:out?).returns(false)
      end
      
      it 'should not add a time entry to the project data' do
        Punch.out(@project)
        Punch.data[@project].length.should == 1
      end
      
      it 'should use now for the punch-out time' do
        Punch.out(@project)
        Punch.data[@project].last['out'].should == @now
      end
      
      it 'should write the data' do
        @test.become('test')
        Punch.expects(:write).when(@test.is('test'))
        Punch.out(@project)
      end
      
      it 'should return true' do
        Punch.out(@project).should == true
      end
    end
  end

  it 'should delete a project' do
    Punch.should respond_to(:delete)
  end
  
  describe 'deleting a project' do
    before :each do
      @now = Time.now
      @project = 'test project'
      @data = { @project => [ {'in' => @now - 50, 'out' => @now - 25} ] }
      
      Punch.instance_eval do
        class << self
          public :data, :data=
        end
      end
      Punch.data = @data
      
      @test = states('test').starts_as('setup')
      Punch.stubs(:write).when(@test.is('setup'))
    end
    
    it 'should accept a project name' do
      lambda { Punch.delete('proj') }.should_not raise_error(ArgumentError)
    end
    
    it 'should require a project name' do
      lambda { Punch.delete }.should raise_error(ArgumentError)
    end
    
    describe 'when the project exists' do
      it 'should remove the project data' do
        Punch.delete(@project)
        Punch.data.should_not include(@project)
      end
      
      it 'should write the data' do
        @test.become('test')
        Punch.expects(:write).when(@test.is('test'))
        Punch.delete(@project)
      end
      
      it 'should return true' do
        Punch.delete(@project).should == true
      end
    end
    
    describe 'when the project does not exist' do
      before :each do
        @project = 'non-existent project'
      end
      
      it 'should not write the data' do
        @test.become('test')
        Punch.expects(:write).never.when(@test.is('test'))
        Punch.delete(@project)
      end
      
      it 'should return nil' do
        Punch.delete(@project).should be_nil
      end
    end
  end
  
  it 'should list project data' do
    Punch.should respond_to(:list)
  end
  
  describe 'listing project data' do
    before :each do
      @now = Time.now
      @project = 'test project'
      @data = { @project => [ {'in' => @now - 5000, 'out' => @now - 2500}, {'in' => @now - 2000, 'out' => @now - 1000}, {'in' => @now - 500, 'out' => @now - 100} ] }
      
      Punch.instance_eval do
        class << self
          public :data, :data=
        end
      end
      Punch.data = @data
    end
    
    it 'should accept a project name' do
      lambda { Punch.list('proj') }.should_not raise_error(ArgumentError)
    end
    
    it 'should require a project name' do
      lambda { Punch.list }.should raise_error(ArgumentError)
    end
    
    it 'should allow options' do
      lambda { Punch.list('proj', :after => Time.now) }.should_not raise_error(ArgumentError)
    end
    
    describe 'when the project exists' do
      it 'should return the project data' do
        Punch.list(@project).should == Punch.data[@project]
      end
      
      it 'should restrict returned data to times only after a certain time' do
        Punch.list(@project, :after => @now - 501).should == Punch.data[@project].last(1)
      end
      
      it 'should restrict returned data to times only before a certain time' do
        Punch.list(@project, :before => @now - 2499).should == Punch.data[@project].first(1)
      end
      
      it 'should restrict returned data to times only within a time range' do
        Punch.list(@project, :after => @now - 2001, :before => @now - 999).should == Punch.data[@project][1, 1]
      end
    end

    describe 'when the project does not exist' do
      before :each do
        @project = 'non-existent project'
      end
      
      it 'should return nil' do
        Punch.list(@project).should be_nil
      end
      
      it 'should return nil if options given' do
        Punch.list(@project, :after => @now - 500).should be_nil
      end
    end
  end

  it 'should get the total time for a project' do
    Punch.should respond_to(:total)
  end
  
  describe 'getting total time for a project' do
    before :each do
      @now = Time.now
      Time.stubs(:now).returns(@now)
      @project = 'test project'
      @data = { @project => [ {'in' => @now - 5000, 'out' => @now - 2500}, {'in' => @now - 500, 'out' => @now - 100} ] }
      
      Punch.instance_eval do
        class << self
          public :data, :data=
        end
      end
      Punch.data = @data
    end
    
    it 'should accept a project name' do
      lambda { Punch.total('proj') }.should_not raise_error(ArgumentError)
    end
    
    it 'should require a project name' do
      lambda { Punch.total }.should raise_error(ArgumentError)
    end
    
    describe 'when the project exists' do
      describe 'and is punched out' do
        it 'should return the amount of time spent on the project (in seconds)' do
          Punch.total(@project).should == 2900
        end
      end
      
      describe 'and is punched in' do
        before :each do
          @data[@project].push({ 'in' => @now - 25 })
          Punch.data = @data
        end
        
        it 'give the time spent until now' do
          Punch.total(@project).should == 2925
        end
      end
    end

    describe 'when the project does not exist' do
      before :each do
        @project = 'non-existent project'
      end
      
      it 'should return nil' do
        Punch.total(@project).should be_nil
      end
    end
  end
end