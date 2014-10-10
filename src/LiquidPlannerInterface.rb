require 'date'
require 'LiquidPlanner'

class LiquidPlannerInterface
	attr_reader :workspace, 
				:activities, 
				:members, 
				:projects, 
				:tasks, 
				:timesheets, 
				:workspaces, 
				:date_info,
				:account

	def initialize **h
		@lp = LiquidPlanner::Base.new(email: h[:email], password: h[:pass])
		@workspace = h[:workspace]
		@activities = {}
		@members = {}
		@projects = {}
		@tasks = {}
		@timesheets = {}
		@workspaces = {}
		@date_info = {}
		@account = nil
	end

	def determine_date_range **h
		if h[:reverse] != nil and h[:week_length] != nil
			raise ArgumentError, 
				  'Only either --reverse or --week-length can be used, not both'
		end

		case h[:date]
		when nil
			given_date = Date.today
			@date_info[:week_length] = 1
		when /^\d{4,4}$/
			given_date = Date.parse(h[:date] + '/1')
			@date_info[:week_length] = 53
		when /^\d{4,4}.\d+$/
			given_date = Date.parse(h[:date])
			@date_info[:week_length] = 5
		else
			given_date = Date.parse(h[:date])
			@date_info[:week_length] = 1
		end

		week_day = Date.commercial(given_date.cwyear, given_date.cweek)
		@date_info[:date] = "#{week_day.year}-#{week_day.month}-#{week_day.day}"

		if h[:week_length] != nil
			@date_info[:week_length] = h[:week_length] < 1 ? 1 : h[:week_length]
		end

		if h[:reverse]
			week_end = week_day - (h[:reverse] < 1 ? 1 : h[:reverse]) * 7
			week_day, week_end = week_end, week_day.next_day(6)
			@date_info[:week_length] = -1 * h[:reverse]
		else
			week_end = week_day + @date_info[:week_length] * 7 - 1
		end

		return [week_day, week_end]
	end

	def get_account
		begin
			@account = @lp.account.attributes
		rescue ActiveResource::UnauthorizedAccess => e
			puts 'Unauthorized access. Incorrect email/password?'
		rescue Exception => e
			puts e.message
			ap e.backtrace
		end

		return @lp.account
	end

	def list_activities_in_workspace _id
		@lp.workspaces(_id).activities.elements.each do |e|
			a = e.attributes
			@activities[a[:id]] = a[:name]
		end
	end

	def list_members_in_workspace _id
		@lp.workspaces(_id).members.elements.each do |e|
			a = e.attributes
			@members[a[:id]] = { user_name: 	a[:user_name],
								 access_level: 	a[:access_level] }
		end
	end

	def list_projects_in_workspace _id
		 @lp.workspaces(_id).projects.each do |e|
		 	a = e.attributes
		 	@projects[a[:id]] = a[:name]
		 end
	end

	def list_tasks_in_workspace _id
		@lp.workspaces(_id).tasks.elements.each do |e|
			@tasks[e.activity_id] = e.name
		end
	end

	def list_timesheets_in_workspace _id, **h	
		arg = Hash.new

		arg[:member_id] = @account[:id] unless h[:all_members]
		arg[:start_date], arg[:end_date] = determine_date_range h

		@lp.workspaces(_id).timesheet_entries(:all,	arg).each do |e|
			if e.work > 0 and e.activity_id > 0
				member = @members[e.member_id][:user_name]
				activity = @activities[e.activity_id]
				date = e.work_performed_on
				year = Date.parse(date).cwyear
				week = Date.parse(date).cweek
				@timesheets[member] ||= {}
				@timesheets[member][year] ||= {}
				@timesheets[member][year][week] ||= {}
				@timesheets[member][year][week][date] ||= {}
				@timesheets[member][year][week][date][activity] ||= 0
				@timesheets[member][year][week][date][activity] += e.work
			end
		end
	end

	def list_workspaces
		get_account.workspaces.each do |workspace|
			a = workspace.attributes
			@workspaces[a[:id]] = a[:name]
		end
	end

	def populate_lookup_tables_for_workspace _id
		list_workspaces
		list_activities_in_workspace _id
		list_members_in_workspace _id
		list_projects_in_workspace _id
		list_tasks_in_workspace _id
	end

	def self.load_account_info
		f = File.readlines('account.txt')
		return [f[0].strip, f[1].strip]
	end
end