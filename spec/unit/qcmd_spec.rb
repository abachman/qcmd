require 'qcmd'

describe Qcmd do
  # tests go here
  it "should log debug messages when in verbose mode" do
    Qcmd.should_receive(:log).with(:debug, 'hello')
    Qcmd.verbose!
    Qcmd.log_level.should eql(:debug)
    Qcmd.debug 'hello'
  end

  it 'should not log debug messages when not in verbose mode' do
    Kernel.should_not_receive(:puts)
    Qcmd.quiet!
    Qcmd.log_level.should eql(:warning)
    Qcmd.debug 'hello'
  end

  it 'should not log debug messages when in quiet block' do
    Qcmd.verbose!
    Qcmd.log_level.should eql(:debug)

    Qcmd.while_quiet do
      Kernel.should_not_receive(:puts)
      Qcmd.log_level.should eql(:warning)
      Qcmd.debug 'hello'
    end

    Qcmd.log_level.should eql(:debug)
  end
end
