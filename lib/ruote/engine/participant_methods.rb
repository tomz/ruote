#--
# Copyright (c) 2005-2009, John Mettraux, jmettraux@gmail.com
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
#
# Made in Japan.
#++


module Ruote

  #
  # Engine methods for [un]registering participants.
  #
  module ParticipantMethods

    # Registers a participant in the engine. Returns the participant instance.
    #
    # Some examples :
    #
    #   require 'ruote/part/hash_participant'
    #   alice = engine.register_participant 'alice', Ruote::HashParticipant
    #     # register an in-memory (hash) store for Alice's workitems
    #
    #   engine.register_participant 'compute_sum' do |wi|
    #     wi.fields['sum'] = wi.fields['articles'].inject(0) do |s, (c, v)|
    #       s + c * v # sum + count * value
    #     end
    #     # a block participant implicitely replies to the engine immediately
    #   end
    #
    #   class MyParticipant
    #     def initialize (name)
    #       @name = name
    #     end
    #     def consume (workitem)
    #       workitem.fields['rocket_name'] = @name
    #       send_to_the_moon(workitem)
    #     end
    #     def cancel (fei, flavour)
    #       # do nothing
    #     end
    #   end
    #   engine.register_participant /^moon-.+/, MyParticipant.new('Saturn-V')
    #
    def register_participant (regex, participant=nil, opts={}, &block)

      pa = plist.register(regex, participant, opts, block)

      wqueue.emit(
        :participants, :registered,
        :regex => regex, :participant => pa)

      pa
    end

    # Removes/unregisters a participant from the engine.
    #
    def unregister_participant (name_or_participant)

      entry = plist.unregister(name_or_participant)

      raise(ArgumentError.new('participant not found')) unless entry

      wqueue.emit(
        :participants, :unregistered,
        :regex => entry.first, :participant => entry.last)
    end
  end
end

