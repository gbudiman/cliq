require_relative '../src/LiquidPlannerInterface.rb'
require 'ap'
require 'text-table'

RSpec.configure { |c| c.include Helpers }

describe 'LiquidPlannerInterface' do
	before :each do
		email, pass = LiquidPlannerInterface::load_account_info
		@lp = LiquidPlannerInterface.new(email: email,
										 pass: 	pass)
		@table = Text::Table.new
	end

	context 'date range of 1 week' do
		it 'should return today\'s week correctly' do
			expect(@lp.determine_date_range).to \
				eq([Date.commercial(Date.today.cwyear, 
									Date.today.cweek),
					Date.commercial(Date.today.cwyear, 
									Date.today.cweek).next_day(6)])
		end

		it 'should return first week of the year correctly' do
			expect(@lp.determine_date_range(year: 2014)).to \
				eq([Date.commercial(2014, 1), 
					Date.commercial(2015, 1).prev_day])
		end

		it 'should return Y2014 W34 correctly' do
			expect(@lp.determine_date_range(year: 2014, week: 34)).to \
				eq([Date.commercial(2014, 34), 
					Date.commercial(2014, 35).prev_day])
		end

		it 'should return W34 correctly' do
			expect(@lp.determine_date_range(year: 2014, week: 34)).to \
				eq([Date.commercial(Date.today.cwyear, 34), 
					Date.commercial(Date.today.cwyear, 35).prev_day])
		end
	end

	context 'date range with 3 weeks forward' do
		it 'should return first week of the year correctly' do
			expect(@lp.determine_date_range(year: 2014, week_length: 3)).to \
				eq([Date.commercial(2014, 1),
					Date.commercial(2014, 4).prev_day])
		end

		it 'should return Y2014 W34 correctly' do
			expect(@lp.determine_date_range(year: 2014, week: 34, 
											week_length: 3)).to \
				eq([Date.commercial(2014, 34), 
					Date.commercial(2014, 37).prev_day])
		end

		it 'should return W34 correctly' do
			expect(@lp.determine_date_range(year: 2014, week: 34, 
											week_length: 3)).to \
				eq([Date.commercial(Date.today.cwyear, 34), 
					Date.commercial(Date.today.cwyear, 37).prev_day])
		end
	end

	context 'date range with 3 weeks backward' do
		it 'should return today\'s week correctly' do
			expect(@lp.determine_date_range(reverse: 3)).to \
				eq([Date.commercial(Date.today.cwyear, 
									Date.today.cweek - 3),
					Date.commercial(Date.today.cwyear, 
									Date.today.cweek).next_day(6)])
		end

		it 'should return first week of the year correctly' do
			expect(@lp.determine_date_range(year: 2014, reverse: 3)).to \
				eq([Date.commercial(2013, 50),
					Date.commercial(2014, 2).prev_day])
		end

		it 'should return Y2014 W34 correctly' do
			expect(@lp.determine_date_range(year: 2014, week: 34, 
											reverse: 3)).to \
				eq([Date.commercial(2014, 31), 
					Date.commercial(2014, 35).prev_day])
		end

		it 'should return W34 correctly' do
			expect(@lp.determine_date_range(year: 2014, week: 34, 
											reverse: 3)).to \
				eq([Date.commercial(Date.today.cwyear, 31), 
					Date.commercial(Date.today.cwyear, 35).prev_day])
		end
	end

	it 'should pass basic authentication given email/password' do
		expect(@lp.get_account).not_to be nil

		first_name = @lp.get_account.attributes[:first_name]
		last_name = @lp.get_account.attributes[:last_name]
		id = @lp.get_account.attributes[:id]

		ap "Welcome #{last_name}, #{first_name}"
		ap "Your member id is #{id}"
	end

	it 'should be able to list workspaces' do
		@table.head = ['W#', 'Workspace Name']

		@lp.list_workspaces
		@lp.workspaces.each { |id, w| @table.rows << [id, w] }

		puts @table.to_s
	end

	context 'given a workspace ID' do
		before :each do
			@ws_id = @lp.list_workspaces[0].id
		end

		after :each do
			puts @table.to_s
		end

		it 'should be able to list projects' do
			@table.head = ['P#', 'Project Name']

			@lp.list_projects_in_workspace(@ws_id)
			@lp.projects.each { |id, p| @table.rows << [id, p] }
		end

		it 'should be able to list tasks' do
			@table.head = ['T#', 'Task Name']

			@lp.list_tasks_in_workspace(@ws_id)
			@lp.tasks.each { |id, t| @table.rows << [id, t] }
		end

		it 'should be able to list activities' do
			@table.head = ['A#', 'Activity Name']

			@lp.list_activities_in_workspace(@ws_id)
			@lp.activities.each { |id, a| @table.rows << [id, a] }
		end

		it 'should be able to list members' do
			@table.head = ['M#', 'User Name', 'Level']
			
			@lp.list_members_in_workspace(@ws_id)
			@lp.members.each do |id, m| 
				@table.rows << [id, m[:user_name], m[:access_level]]
			end
		end

		it 'should be able to list timesheets with appropriate referencing' do
			puts 'Sleeping for 12 seconds to avoid account throttling...'
			sleep 12
			@table.head = ['Member', 'Work', 'Activity', 'Hours']
			@lp.populate_lookup_tables_for_workspace @ws_id
			@lp.list_timesheets_in_workspace(@ws_id, 
											 year: 2014, 
											 all_members: true)

			@lp.timesheets.each do |member, md|
				md.each do |year, yd|
					yd.each do |week, wd|
						wd.each do |activity, dd|
							dd.each do |date, hours|
								@table.rows << [member, date, activity, hours]
							end
						end
					end
				end
			end
		end
	end
end