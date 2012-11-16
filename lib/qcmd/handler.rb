module Qcmd
  class Handler
    include Qcmd::Plaintext

    def handle reply
      Qcmd.debug "(handling #{ reply })"

      case reply.address
      when %r[/workspaces]
        Qcmd.context.machine.workspaces = reply.data.map {|ws| Qcmd::QLab::Workspace.new(ws)}

        print centered_text(" Workspaces ", '-')
        print
        Qcmd.context.machine.workspaces.each_with_index do |ws, n|
          print "#{ n + 1 }. #{ ws.name }"
        end

        print
        print wrapped_text('Type `use "WORKSPACE_NAME" PASSCODE` to load a workspace. ' +
                           'Only enter a passcode if your workspace uses one')
        print

      when %r[/workspace/[^/]+/connect]
        # connecting to a workspace
        if reply.data == 'badpass'
          print 'failed to connect to workspace'
          Qcmd.context.disconnect_workspace
        elsif reply.data == 'ok'
          print 'connected to workspace'
          Qcmd.context.workspace_connected = true
        end

      when %r[/cueLists]
        Qcmd.debug "(received cueLists)"

        # load global cue list
        Qcmd.context.workspace.cues = cues = reply.data.map {|cue_list|
          cue_list['cues'].map {|cue| Qcmd::QLab::Cue.new(cue)}
        }.compact.flatten

        print "loaded #{pluralize cues.size, 'cue'}"

      when %r[/(selectedCues|runningCues|runningOrPausedCues)]
        cues = reply.data.map {|cue|
          cues = [Qcmd::QLab::Cue.new(cue)]

          if cue['cues']
            cues << cue['cues'].map {|cue| Qcmd::QLab::Cue.new(cue)}
          end

          cues
        }.compact.flatten

        title = case reply.address
                when /selectedCues/;        "Selected Cues"
                when /runningCues/;         "Running Cues"
                when /runningOrPausedCues/; "Running or Paused Cues"
                end

        print
        print centered_text(" #{title} ", '-')
        table(['Number', 'Id', 'Name', 'Type'], cues.map {|cue|
          [cue.number, cue.id, cue.name, cue.type]
        })
        print

      when %r[/(cue|cue_id)/[^/]+/[a-zA-Z]+]
        # properties, just print reply data
        result = reply.data
        if result.is_a?(String) || result.is_a?(Numeric)
          print result
        else
          print result.inspect
        end
      else
        Qcmd.debug "(unrecognized message from QLab, cannot handle #{ reply.address })"
      end
    end
  end
end
