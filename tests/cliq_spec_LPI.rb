require_relative '../src/LiquidPlannerInterface.rb'
require 'ap'
require 'text-table'

describe 'LiquidPlannerInterface' do
	before :each do
		email, pass = LiquidPlannerInterface::load_account_info
		@lp = LiquidPlannerInterface.new(email: email,
										 pass: 	pass)
		@table = Text::Table.new
	end

	context 'date range of 1 week' do
		it 'should return today\'s week correctly when no argument is given' do
			expect(@lp.determine_date_range).to \
				eq([Date.commercial(Date.today.cwyear, 
									Date.today.cweek),
					Date.commercial(Date.today.cwyear, 
									Date.today.cweek).next_day(6)])
		end

		it 'should return the first week of Y2014 given 2014/1/1' do
			expect(@lp.determine_date_range(date: '2014/1/1')).to \
				eq([Date.commercial(2014, 1), 
					Date.commercial(2014, 2).prev_day])
		end

		it 'should return the last week of Y2014 given 2014/12/25' do
			expect(@lp.determine_date_range(date: '2014/12/25')).to \
				eq([Date.commercial(2014, 52), 
					Date.commercial(2014, 52).next_day(6)])
		end

		it 'should properly handle corner-case 2013/12/31' do
			expect(@lp.determine_date_range(date: '2013/12/31')).to \
				eq([Date.commercial(2014, 1), 
					Date.commercial(2014, 1).next_day(6)])
		end

		it 'should return the first week of current year given 1/1' do
			date = Date.new(Date.today.year, 1, 1)
			commercial = Date.commercial(date.cwyear, date.cweek)
			expect(@lp.determine_date_range(date: '1/1')).to \
				eq([commercial, commercial.next_day(6)])
		end
	end

	context 'date range with 3 weeks forward' do
		it 'should return first week of the year correctly' do
			expect(@lp.determine_date_range(week_length: 3)).to \
				eq([Date.commercial(Date.today.cwyear,
									Date.today.cweek),
					Date.commercial(Date.today.cwyear,
									Date.today.cweek).next_day(20)])
		end

		it 'should return the first week of Y2014 given 2014/1/1' do
			expect(@lp.determine_date_range(date: '2014/1/1', 
											week_length: 3)).to \
				eq([Date.commercial(2014, 1), 
					Date.commercial(2014, 4).prev_day])
		end

		it 'should return the last week of Y2014 given 2014/12/25' do
			expect(@lp.determine_date_range(date: '2014/12/25', 
											week_length: 3)).to \
				eq([Date.commercial(2014, 52), 
					Date.commercial(2015, 3).prev_day])
		end
	end

	context 'date range with 3 weeks backward' do
		it 'should return today\'s week correctly' do
			expect(@lp.determine_date_range(reverse: 3)).to \
				eq([Date.commercial(Date.today.cwyear,
									Date.today.cweek).prev_day(21),
					Date.commercial(Date.today.cwyear,
									Date.today.cweek).next_day(6)])
		end

		it 'should return the first week of Y2014 given 2014/1/1' do
			expect(@lp.determine_date_range(date: '2014/1/1', 
											reverse: 3)).to \
				eq([Date.commercial(2013, 50), 
					Date.commercial(2014, 2).prev_day])
		end

		it 'should return the last week of Y2014 given 2014/12/25' do
			expect(@lp.determine_date_range(date: '2014/12/25', 
											reverse: 3)).to \
				eq([Date.commercial(2014, 49), 
					Date.commercial(2015, 1).prev_day])
		end
	end

	it 'should return monthly date range of Y2014 M7' do
		ws = Date.new(2014, 7)
		we = Date.new(2014, 8)
		cs = Date.commercial(ws.cwyear, ws.cweek)
		ce = Date.commercial(we.cwyear, we.cweek)
		expect(@lp.determine_date_range(date: '2014/7')).to \
			eq([cs, ce.next_day(6)])
	end

	it 'should return monthly date range of Y2014 M2' do
		ws = Date.new(2014, 2)
		we = Date.new(2014, 3)
		cs = Date.commercial(ws.cwyear, ws.cweek)
		ce = Date.commercial(we.cwyear, we.cweek)
		expect(@lp.determine_date_range(date: '2014/2')).to \
			eq([cs, ce.next_day(6)])
	end

	it 'should return yearly date range of Y2014' do
		ws = Date.new(2014)
		we = Date.new(2015)
		cs = Date.commercial(ws.cwyear, ws.cweek)
		ce = Date.commercial(we.cwyear, we.cweek)
		expect(@lp.determine_date_range(date: '2014')).to \
			eq([cs, ce.next_day(6)])
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
			@lp.set_current_workspace(@lp.list_workspaces[0].id)
		end

		after :each do
			puts @table.to_s
		end

		it 'should be able to create task and update its checklist items' do
			@lp.create_task(name: "New task test #{Time.now}", 
							package_id: 17209536,
							parent_id: 17209601,
							activity_id: 172280,
							owner_id: 410218,
							description: 'This task is generated',
							promise_by: Date.today.next_day(12))

			@lp.update_task_properties(checklist: [
										{ name: "New checklist #{Time.now}",
										  owner_id: 410218 } ],
							 		   estimate: [2.0, 5.5])

			ap @lp.retrieve_task
		end

		it 'should be able to retrieve a task' do
			@lp.set_current_task(@lp.get_tasks.first.attributes[:id])
			ap @lp.retrieve_task
			puts 'Sleeping for 12 seconds to avoid account throttling...'
			sleep 12
		end

		it 'should be able to list everything in workspace' do
			@table.head = ['T#', 'Type', 'Name']

			@lp.list_items_in_workspace
			@lp.items.each { |id, d| @table.rows << [id, d[:type], d[:name]] }
		end

		it 'should be able to list activities' do
			@table.head = ['A#', 'Activity Name']

			@lp.list_activities_in_workspace
			@lp.activities.each { |id, a| @table.rows << [id, a] }
		end

		it 'should be able to list members' do
			@table.head = ['M#', 'User Name', 'Level']
			
			@lp.list_members_in_workspace
			@lp.members.each do |id, m| 
				@table.rows << [id, m[:user_name], m[:access_level]]
			end
		end

		it 'should be able to list timesheets with appropriate referencing' do
			@table.head = ['Member', 'Work', 'Activity', 'Hours']
			@lp.populate_lookup_tables
			@lp.list_timesheets_in_workspace(date: '2014', 
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