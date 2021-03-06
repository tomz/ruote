
#
# Testing OpenWFE
#
# John Mettraux at openwfe.org
#
# Tue Jan  2 13:14:37 JST 2007
#

#require 'profile'

require File.dirname(__FILE__) + '/../flowtestbase'
require 'openwfe/def'


class FlowTest26c < Test::Unit::TestCase
  include FlowTestBase

  #
  # Test 0
  #

  #N = 10_000
  N = 100

  class TestDefinition0 < OpenWFE::ProcessDefinition
    sequence do
      N.times do
        count
      end
    end
  end

  def test_load_0

    #log_level_to_debug

    #@engine.get_scheduler.sstop
      #
      # JRuby is no friend of the Scheduler

    $count = 0

    @engine.register_participant("count") do |workitem|
      $count += 1
      print "."
    end

    fei = @engine.launch(
      OpenWFE::LaunchItem.new(TestDefinition0), :wait_for => true)

    #log_level_to_debug

    assert_equal N, $count
  end

  #
  # Thu Sep 13 15:41:20 JST 2007
  #
  # ruby 1.8.5 (2006-12-25 patchlevel 12) [i686-darwin8.8.3]
  #
  # 10_000 in 27.69s
  #
  # before optimization : 10k in 138.341
  #
  #
  # ruby 1.8.5 (2007-09-13 rev 3876) [i386-jruby1.1]
  #
  # 10_000 in 53.96s
  #
  # ruby 1.8.5 (2007-09-13 rev 3876) [i386-jruby1.1]
  # -O -J-server
  #
  # 10_000 in 42.616s

  #
  # Thu Nov  8 21:36:02 JST 2007
  #
  # ruby 1.8.6 (2007-06-07 patchlevel 36) [universal-darwin9.0]
  #
  # 10_000 in 39.089
  #
  # ?
  #

  #
  # Fri Jul 25 09:34:15 JST 2008
  #
  # 10_000 in 33.60s
  #
  # ruby 1.8.6 (2008-03-03 patchlevel 114) [universal-darwin9.0]
  #
  # focusing on Marshal for fulldup...
  #

  #
  # Thu Oct 16 22:58:15 JST 2008
  #
  # 10_000 in 31.939s
  #
  # 2GB RAM -> 4GB RAM, well...
  #

  #
  # Mon Oct 20 10:30:47 JST 2008
  #
  # 10_000 in 23.845s
  #
  # after the initial work on "no raw expression children"
  #

  #
  # Sun Nov  2 14:58:19 JST 2008
  #
  # 10_000 in 22.006s
  #
  # ruby 1.8.6 (2008-03-03 patchlevel 114) [universal-darwin9.0]
  # on 2.4GHz Intel Core duo, 4GB Memory
  #
  # 10_000 in 15.282s
  #
  # commented some ldebugs out of the critical path
  #

end

