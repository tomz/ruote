
#
# Testing Ruote (OpenWFEru)
#
# John Mettraux at openwfe.org
#
# Sun Oct 29 15:41:44 JST 2006
#
# somewhere between Philippina and the Japan
#

require 'rubygems'
require 'test/unit'

%w{ lib old_test }.each do |path|
  path = File.expand_path(File.dirname(__FILE__) + '/../' + path)
  $:.unshift(path) unless $:.include?(path)
end

require 'openwfe/workitem'
require 'openwfe/engine/engine'
require 'openwfe/rudefinitions'
require 'openwfe/participants/participants'

require 'rutest_utils'


$WORKFLOW_ENGINE_CLASS = OpenWFE::Engine

pers = ARGV.find { |a| a.match(/^-p.$/) }
pers = pers ? pers[2, 1] : ENV['__persistence__']

#p pers


if %w{ pure-persistence p f }.include?(pers)

  require 'openwfe/engine/file_persisted_engine'
  $WORKFLOW_ENGINE_CLASS = OpenWFE::FilePersistedEngine

elsif %w{ cached-persistence c }.include?(pers)

  require 'openwfe/engine/file_persisted_engine'
  $WORKFLOW_ENGINE_CLASS = OpenWFE::CachedFilePersistedEngine

elsif %w{ db-persistence D }.include?(pers)

  require 'extras/active_connection'
  require 'openwfe/extras/engine/db_persisted_engine'
  $WORKFLOW_ENGINE_CLASS = OpenWFE::Extras::DbPersistedEngine

elsif %w{ cached-db-persistence d }.include?(pers)

  require 'extras/active_connection'
  require 'openwfe/extras/engine/db_persisted_engine'
  $WORKFLOW_ENGINE_CLASS = OpenWFE::Extras::CachedDbPersistedEngine

elsif %w{ tokyo-persistence t }.include?(pers)

  require 'openwfe/engine/tc_engine'
  $WORKFLOW_ENGINE_CLASS = OpenWFE::TokyoPersistedEngine

elsif %w{ marshal-persistence m }.include?(pers)

  require 'openwfe/engine/fs_engine'
  $WORKFLOW_ENGINE_CLASS = OpenWFE::FsPersistedEngine
end

#
# finding which test is currently 'on'
#
def get_test_filename
  c = caller
  l = c.find do |l|
    l.match(/test\//) and
    #(not l.match(/test\/unit/)) and
    (not l.match(/test\/flowtestbase/))
  end
  "#{l} (#{c.size} lines)"
end


puts
puts "testing with engine of class " + $WORKFLOW_ENGINE_CLASS.to_s
puts

module FlowTestBase

  attr_reader :engine, :tracer

  #
  # SETUP
  #
  def setup

    @engine = $WORKFLOW_ENGINE_CLASS.new

    class << @engine.get_wfid_generator
      #
      # tracking which wfids got generated
      #
      include OpenWFE::OwfeServiceLocator
      alias :old_generate :generate
      def generate (launchitem=nil)
        wfid = old_generate(launchitem)
        $OWFE_LOG.info(
          "new wfid : #{wfid} " +
          "at #{get_test_filename} " +
          "for engine #{get_engine.object_id}")
        wfid
      end
    end
    class << @engine
      #
      # tagging which process instance (wfid) got started for which test
      # in the log file
      #
      alias :old_launch :launch
      def launch (launch_object, options={})
        result = old_launch(launch_object, options)
        fei = result.is_a?(Array) ? result.last : result
        $OWFE_LOG.info(
          "launched #{fei.wfid} " +
          "at #{get_test_filename} " +
          "on engine #{self.object_id}")
        result
      end
    end

    $OWFE_LOG.info(
      #"setup() started engine #{@engine.object_id} @ #{caller[-1]}")
      "setup() started engine #{@engine.object_id}")

    @terminated_processes = []
    @engine.get_expression_pool.add_observer(:terminate) do |c, fe, wi|
      @terminated_processes << fe.fei.wfid
      #p [ :terminated, @terminated_processes ]
    end
    #@terminated = false
    #@engine.get_expression_pool.add_observer(:terminate) do |c, fe, wi|
    #  @terminated = true
    #end

    @engine.application_context[:ruby_eval_allowed] = true
    @engine.application_context[:definition_in_launchitem_allowed] = true

    @tracer = Tracer.new
    @engine.application_context['__tracer'] = @tracer

    @engine.register_participant('pp-workitem') do |workitem|

      puts
      #require 'pp'; pp workitem
      p workitem
      puts
    end

    @engine.register_participant('pp-fields') do |workitem|

      workitem.attributes.keys.sort.each do |field|
        next if field == "___map_type" or field == "__result__"
        next if field == "params"
        @tracer << "#{field}: #{workitem.attributes[field]}\n"
      end
      @tracer << "--\n"
    end

    @engine.register_participant 'test-.*', OpenWFE::PrintParticipant.new

    @engine.register_participant('block-participant') do |workitem|
      @tracer << "the block participant received a workitem"
      @tracer << "\n"
    end

    @engine.register_participant('p-toto') do |workitem|
      @tracer << "toto"
    end
  end

  #
  # TEARDOWN
  #
  def teardown

    if @engine
      $OWFE_LOG.level = Logger::INFO
      @engine.stop
    end
  end

  protected

    def log_level_to_debug
      $OWFE_LOG.level = Logger::DEBUG
    end

    def print_exp_list (l)
      puts
      l.each do |fexp|
        puts "   - #{fexp.fei.to_debug_s}"
      end
      puts
    end

    def name_of_test

      s = caller(1)[0]
      i = s.index('`')
      s[i+6..s.length-2]
    end

    #
    # some tests return quickly, leverage the @terminated_processes
    # of the test engine to determine those processes that are
    # already over...
    #
    def wait_for (fei)
      #for i in (0..42)
      for i in (0..217)
        Thread.pass
        return if @terminated_processes.include?(fei.wfid)
        #return if @terminated
      end
      @engine.wait_for fei
    end

    #
    # calling
    #
    #   launch li
    #
    # instead of
    #
    #   @engine.launch li
    #
    # ensures that the logs will contain a mention of the wfid of the
    # flow just started along with the test method (and it's location
    # in its source file).
    #
    def launch (li, options={})

      result = @engine.launch(li, options)

      fei = result.is_a?(Array) ? result[2] : result

      result
    end

    #
    # dotest()
    #
    def dotest (
      flowdef,
      expected_trace,
      join=false,
      allow_remaining_expressions=false)

      @tracer.clear

      #li = if flowDef.kind_of?(OpenWFE::LaunchItem)
      #  flowDef
      #else
      #  OpenWFE::LaunchItem.new flowDef
      #end

      options = {}
      options[:wait_for] = true unless join.is_a?(Numeric)

      #fei = launch li, options
      fei = launch(flowdef, options)

      sleep join if join.is_a?(Numeric)

      trace = @tracer.to_s

      #if trace == ''
      #  Thread.pass; sleep 0.350
      #  trace = @tracer.to_s
      #end
        #
        # occurs when the tracing is done from a participant
        # (participant dispatching occurs in a thread)

      #puts "...'#{trace}' ?= '#{expected_trace}'"

      if expected_trace.is_a?(Array)

        result = expected_trace.find do |etrace|
          trace == etrace
        end
        assert(
          (result != nil),
          """flow failed :

  trace doesn't correspond to any of the expected traces...

  traced :

'#{trace}'

""")
      elsif expected_trace.kind_of?(Regexp)

        assert trace.match(expected_trace)
      else

        assert(
          trace == expected_trace,
          """flow failed :

  traced :

'#{trace}'

  but was expecting :

'#{expected_trace}'
""")
      end

      if allow_remaining_expressions

        purge_engine

        return fei
      end

      #Thread.pass; sleep 0.003; Thread.pass

      exp_storage = engine.get_expression_storage

      view = exp_storage.to_s
      size = exp_storage.size

      if size != 1
        sleep 0.400
        view = exp_storage.to_s
        size = exp_storage.size
      end

      if size != 1
        puts
        puts "  remaining expressions : #{size}"
        puts
        puts view
        puts
        puts OpenWFE::caller_to_s(0, 2)
        puts

        purge_engine
      end

      assert_equal(
        1,
        size,
        "there are expressions remaining in the expression pool " +
        "(right now : #{exp_storage.length})")

      fei
    end

    #
    # makes sure to purge the engine's expression storage
    #
    def purge_engine

      @engine.get_expression_storages.each { |s| s.purge }
    end

    def assert_trace (desired_trace)

      assert_equal desired_trace, @tracer.to_s
    end

end

#
# A bunch of methods for testing the journal component
#
module JournalTestBase

  def get_journal

    @engine.get_journal
  end

  def get_error_count (wfid)

    fn = get_journal.workdir + "/" + wfid + ".journal"

    get_journal.flush_buckets

    events = get_journal.load_events(fn)

    events.inject(0) { |r, evt| r += 1 if evt[0] == :error; r }
  end
end

