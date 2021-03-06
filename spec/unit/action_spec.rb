require 'qcmd'

def test_log msg=''
  puts msg
end

class DeadHandler
  def self.handle response
    # do nothing :P
  end
end

def stubbed_modified_action modifier
  action = Qcmd::CueAction.new ''
  action.stub(:code) { [:cue, 1, :sliderLevel, 0, modifier] }
  action
end

describe Qcmd::Action do
  before do
    Qcmd.context = Qcmd::Context.new
    Qcmd.context.machine = Qcmd::Machine.new('test machine', 'localhost', 53000)
    Qcmd.context.connect_to_qlab DeadHandler

    # always reply ON
    Qcmd.context.qlab.send(OSC::Message.new('/alwaysReply', 1))
  end

  it "should parse when initialized" do
    action = Qcmd::Action.new 'cue 10 name'
    action.code.should eql([:cue, 10, :name])
  end

  it 'should send a command when evaluated' do
    action = Qcmd::Action.new 'workspaces'

    action.stub(:send_message) { true }
    action.should_receive :send_message

    action.evaluate
  end

  it 'should return the data resulting from an OSC message' do
    action = Qcmd::Action.new 'cueLists'

    result = nil

    expect {
      result = action.evaluate
    }.to_not raise_error

    result.should_not be_nil
    result.should be_an_instance_of(Array)
  end

  describe 'workspace specific action' do
    before do
      osc_message = OSC::Message.new '/workspaces'
      Qcmd.context.qlab.send(osc_message) do |response|
        reply = Qcmd::QLab::Reply.new(response)
        Qcmd.context.machine.workspaces = reply.data.map {|ws| Qcmd::QLab::Workspace.new(ws)}
      end
    end

    it 'should be able to connect' do
      workspace = Qcmd.context.machine.workspaces.first

      ws_action_string = "workspace/#{workspace.id}/connect"

      reply = Qcmd::Action.evaluate(ws_action_string)

      reply.should eql('ok')
    end
  end

  describe 'cue specific action' do
    it 'should send a cue OSC message' do
      action = Qcmd::CueAction.new 'cue 1 isRunning'
      action.send(:osc_address).should eql('/cue/1/isRunning')
      action.send(:osc_arguments).should eql([])
    end

    it 'should nest actions' do
      action = Qcmd::CueAction.new 'cue 1 name (cue 2 name)'
      action.code[3].should be_an_instance_of(Qcmd::CueAction)
    end

    describe 'modifiers' do
      describe 'positive' do
        it 'should match int' do
          action = stubbed_modified_action :'++1'
          found = action.send(:trailing_modifier)

          found.should_not be_nil
          found.first.should eql(:+)
          found.last.should eql('1')
        end

        it 'should match float' do
          action = stubbed_modified_action :'++1.2'
          found = action.send(:trailing_modifier)

          found.should_not be_nil
          found.first.should eql(:+)
          found.last.should eql('1.2')
        end

        it 'should match bare float' do
          action = stubbed_modified_action :'++.2'
          found = action.send(:trailing_modifier)

          found.should_not be_nil
          found.first.should eql(:+)
          found.last.should eql('.2')
        end

      end

      describe 'negative' do
        it 'should match int' do
          action = stubbed_modified_action :'--1'
          found = action.send(:trailing_modifier)

          found.should_not be_nil
          found.first.should eql(:-)
          found.last.should eql('1')
        end

        it 'should match float' do
          action = stubbed_modified_action :'--1.2'
          found = action.send(:trailing_modifier)

          found.should_not be_nil
          found.first.should eql(:-)
          found.last.should eql('1.2')
        end

        it 'should match bare float' do
          action = stubbed_modified_action :'--.2'
          found = action.send(:trailing_modifier)

          found.should_not be_nil
          found.first.should eql(:-)
          found.last.should eql('.2')
        end
      end
    end
  end

end
