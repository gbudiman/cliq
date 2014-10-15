require 'date'
require 'LiquidPlanner'

class LiquidPlannerInterface
	attr_reader :workspace, 
				:activities, 
				:items,
				:members,  
				:timesheets, 
				:workspaces, 
				:date_info,
				:account

	def initialize **h
		@lp = LiquidPlanner::Base.new(email: h[:email], password: h[:pass])
		@current_workspace = nil
		@current_task = nil
		@activities = {}
		@items = {}
		@members = {}
		@timesheets = {}
		@workspaces = {}
		@date_info = {}
		@account = nil
	end

	def set_current_task _task_id
		raise RuntimeError, 'Workspace not set' if @current_workspace == nil
		@current_task = @current_workspace.tasks(_task_id)

		return self
	end

	def set_current_workspace _ws_id
		@current_workspace = @lp.workspaces(_ws_id)

		return self
	end

	def create_task **h
		raise RuntimeError, 'Workspace not set' if @current_workspace == nil
		task = @current_workspace.create_task(h).attributes
		set_current_task task[:id]

		return task
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

	def get_tasks
		raise RuntimeError, 'Workspace not set' if @current_workspace == nil

		@current_workspace.tasks
	end

	def list_activities_in_workspace
		raise RuntimeError, 'Workspace not set' if @current_workspace == nil
		@current_workspace.activities.elements.each do |e|
			a = e.attributes
			@activities[a[:id]] = a[:name]
		end
	end

	def list_items_in_workspace
		raise RuntimeError, 'Workspace not set' if @current_workspace == nil
		@current_workspace.treeitems.each do |e|
			a = e.attributes
			@items[a[:id]] = a
		end
	end

	def list_members_in_workspace
		raise RuntimeError, 'Workspace not set' if @current_workspace == nil
		@current_workspace.members.elements.each do |e|
			a = e.attributes
			@members[a[:id]] = { user_name: 	a[:user_name],
								 access_level: 	a[:access_level] }
		end
	end

	def list_timesheets_in_workspace **h	
		raise RuntimeError, 'Workspace not set' if @current_workspace == nil
		arg = Hash.new

		arg[:member_id] = @account[:id] unless h[:all_members]
		arg[:start_date], arg[:end_date] = determine_date_range h

		@current_workspace.timesheet_entries(:all,	arg).each do |e|
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

	def populate_lookup_tables
		list_workspaces
		list_activities_in_workspace
		list_members_in_workspace
		list_items_in_workspace
	end

	def retrieve_task
		raise RuntimeError, 'Workspace not set' if @current_workspace == nil
		raise RuntimeError, 'Task not set' if @current_task == nil

		return @current_task.attributes
	end

	def update_task_properties **h
		raise RuntimeError, 'Workspace not set' if @current_workspace == nil
		raise RuntimeError, 'Task not set' if @current_task == nil

		h.each do |property, value|
			case property
			when :checklist
				value.each do |checklist|
					@current_task.create_checklist_items(checklist)
				end
			when :estimate
				@current_task.create_estimate(low: value[0], high: value[1])
			end
		end						  
	end

	def self.load_account_info
		f = File.readlines('account.txt')
		return [f[0].strip, f[1].strip]
	end
end