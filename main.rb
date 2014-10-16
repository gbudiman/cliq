require_relative 'src/ExcelInterface.rb'
require_relative 'src/LiquidPlannerInterface.rb'
require 'ap'
require 'highline/import'
require 'ruby-prof'
require 'trollop'

opts = Trollop::options do
	opt :all_members, 'Apply actions to all members. Requires certain privilege'
	opt :download_tasks, 'Download work activities'
	opt :quiet, 'Quiet mode'
	opt :week_length, 'Number of weeks to query since week_start',
					  type: :int, short: 'l'
	opt :reverse, 'Number of weeks to query since today, counting backwards',
				  type: :int, short: 'r'
	opt :workspace, 'Override default workspace', default: 125712
	opt :profile, 'Run profiling'
end

if File.exists? 'account.txt'
	opts[:email], opts[:pass] = LiquidPlannerInterface::load_account_info
else
	opts[:email] = ask('Email: ')
	opts[:pass] = ask('Password: ') { |q| q.echo = '*' }
end

RubyProf.start if opts[:profile]
lp = LiquidPlannerInterface.new opts

begin
	if opts[:download_tasks]
		lp.set_current_workspace opts[:workspace]
		lp.populate_lookup_tables
		lp.get_timesheets(date: ARGV[0],
						  week_length: opts[:week_length],
						  all_members: opts[:all_members],
						  reverse: opts[:reverse])

		path = File.join('reports', 										\
						 "#{lp.workspaces[opts[:workspace]]}_activities_"	\
					   + "#{lp.date_info[:date]}"							\
					   + sprintf("%+dweek", lp.date_info[:week_length])		\
					   + (opts[:all_members] ? '_all_members' : '')			\
					   + ".xlsx")
		path.gsub(/\s+/, '_')
		ExcelInterface::dump_activities lp.timesheets, path
	end
rescue ArgumentError => e
	ap e.message
	ap e.backtrace
end

if opts[:profile]
	result = RubyProf.stop
	printer = RubyProf::GraphPrinter.new(result)
	printer.print(STDOUT)
end