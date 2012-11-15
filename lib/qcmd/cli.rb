require 'qcmd/server'

require 'readline'

require 'osc-ruby'
require 'osc-ruby/em_server'

module Qcmd
  class CLI
    include Qcmd::Plaintext

    attr_accessor :server, :prompt

    def self.launch options={}
      new options
    end

    def initialize options={}
      # start local listening port
      Qcmd.context = Qcmd::Context.new

      self.prompt = '> '

      start

      # if local machines have already been detected and only one is available,
      # use it.
      if Qcmd::Network.machines
        if Qcmd::Network.machines.size == 1 && !Qcmd::Network.machines.first.passcode?
          puts "AUTOCONNECT"
          connect Qcmd::Network.machines.first, nil
        end
      end
    end

    def connect machine, passcode
      if machine.nil?
        print "A valid machine is needed to connect!"
        return
      end

      Qcmd.context.machine = machine
      Qcmd.context.workspace = nil

      if server.nil?
        # set client connection and start listening port
        self.server = Qcmd::Server.new :receive => 53001
      else
        # change client connection
        server.connect_to_client
      end
      server.run

      server.load_workspaces

      self.prompt = "#{ machine.name }> "

      if Qcmd.context.machine.workspaces.size == 1
        Qcmd.debug '(only one workspace available)'
        use_workspace Qcmd.context.machine.workspaces.first
      end
    end

    def use_workspace workspace
      Qcmd.debug %[(connecting to workspace: "#{workspace.name}")]
      # set workspace in context. Will unset later if there's a problem.
      Qcmd.context.workspace = workspace
      self.prompt = "#{ Qcmd.context.machine.name }:#{ workspace.name }> "

      server.connect_to_workspace workspace
    end

    def reset
      Qcmd.context.reset
      server.stop
      self.prompt = "> "
    end

    def start
      loop do
        # blocks the whole Ruby VM
        message = Readline.readline(prompt, true)

        if message.nil? || message.size == 0
          Qcmd.debug "(got: #{ message.inspect })"
          next
        end

        args    = message.strip.split
        command = args.shift

        case command
        when 'exit'
          print 'exiting...'
          exit 0
        when 'connect'
          Qcmd.debug "(connect command received args: #{ args.inspect })"

          machine_name = args.shift
          passcode     = args.shift

          if machine = Qcmd::Network.find(machine_name)
            print "connecting to machine: #{machine_name}"
            connect machine, passcode
          else
            print 'sorry, that machine could not be found'
          end
        when 'disconnect'
          reset
          Qcmd::Network.browse_and_display
        when 'use'
          Qcmd.debug "(use command received args: #{ args.inspect })"

          argument_string = args.join ' '

          if match = /"([^"]+)"/.match(argument_string)
            # look for matching quotes
            workspace_name = match[1]
            passcode = argument_string.gsub(/"([^"]+)"/, '').strip
          else
            workspace_name = args.shift
            passcode       = args.shift
          end

          Qcmd.debug "(using workspace: #{ workspace_name.inspect })"
          if workspace = Qcmd.context.machine.find_workspace(workspace_name)
            workspace.passcode = passcode
            print "connecting to workspace: #{workspace_name}"
            use_workspace workspace
          end
        when 'cues'
          ## Cues Table
          if Qcmd.context.workspace.cues
            table ['Number', 'Id', 'Name', 'Type'], Qcmd.context.workspace.cues.map {|cue|
              [cue.number, cue.id, cue.name, cue.type]
            }
          end
        else
          if Qcmd.context.workspace
            server.send_workspace_command(command, *args)
          else
            server.send_command(command, *args)
          end
        end
      end
    end
  end
end
