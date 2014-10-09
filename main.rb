require_relative 'src/ExcelInterface.rb'
require_relative 'src/LiquidPlannerInterface.rb'
require 'ap'
require 'highline/import'
require 'trollop'

opts = Trollop::options do
	opt :all_members, 'Apply actions to all members. Requires certain privilege'
	opt :download_tasks, 'Download work activities'
	opt :year, '4-digits year for LP query', type: :int
	opt :week, 'Start week number for LP query', type: :int
	opt :week_length, 'Number of weeks to query since week_start',
					  type: :int, short: 'l'
	opt :reverse, 'Number of weeks to query since today, counting backwards',
				  type: :int, short: 'r'
	opt :workspace, 'Override default workspace', default: 125712
end

if File.exists? 'account.txt'
	opts[:email], opts[:pass] = LiquidPlannerInterface::load_account_info
else
	opts[:email] = ask('Email: ')
	opts[:pass] = ask('Password: ') { |q| q.echo = '*' }
end

lp = LiquidPlannerInterface.new opts

begin
	if opts[:download_tasks]
		lp.populate_lookup_tables_for_workspace opts[:workspace]
		lp.list_timesheets_in_workspace opts[:workspace], \
									  { year: opts[:year],
									    week: opts[:week],
									    year_end: opts[:year_end],
									    week_end: opts[:week_end],
									    week_length: opts[:week_length],
									    all_members: opts[:all_members],
									    reverse: opts[:reverse] }

		path = File.join('reports', 										\
						 "#{lp.workspaces[opts[:workspace]]}_activities_"	\
					   + "Y#{lp.date_info[:year]}_"							\
				       + "W#{lp.date_info[:week]}"							\
					   + sprintf("%+d", lp.date_info[:week_length]) 		\
					   + (opts[:all_members] ? '_all_members' : '')			\
					   + ".xlsx")
		path.gsub(/\s+/, '_')
		ExcelInterface::dump_activities lp.timesheets, path
	end
rescue ArgumentError => e
	ap e.message
	ap e.backtrace
end