require 'date'
require 'LiquidPlanner'

class LiquidPlannerInterface
	attr_reader :activities, 
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
		@lookup_tables_loaded = false

		@activities = {}
		@items = {}
		@members = {}
		@timesheets = {}
		@workspaces = {}
		
		@account = nil
		@date_info = {}
		@quiet_mode = h[:quiet] || false
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

	def get_timesheets **h	
		raise RuntimeError, 'Workspace not set' if @current_workspace == nil
		arg = { entry_count: 0 }

		arg[:member_id] = @account[:id] unless h[:all_members]
		arg[:start_date], arg[:end_date] = determine_date_range h

		print 'Generating timesheet from ' \
			+ "#{arg[:start_date]} to #{arg[:end_date]}... " unless @quiet_mode

		@current_workspace.timesheet_entries(:all,	arg).each do |e|
			if e.work > 0 and e.activity_id > 0
				arg[:entry_count] += 1
				member = @members[e.member_id][:user_name]
				activity = @activities[e.activity_id][:name]
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
		
		puts "#{arg[:entry_count]} entries found"
	end

	def get_workspaces
		get_account.workspaces.each do |workspace|
			a = workspace.attributes
			@workspaces[a[:id]] = a[:name]
		end
	end

	def set_current_task _task_id
		raise RuntimeError, 'Workspace not set' if @current_workspace == nil
		@current_task = @current_workspace.tasks(_task_id)

		return self
	end

	def set_current_workspace _ws_id
		@current_workspace = @lp.workspaces(_ws_id)
		@lookup_tables_loaded = false

		return self
	end

	def create_task **h
		raise RuntimeError, 'Workspace not set' if @current_workspace == nil

		populate_lookup_tables
		primary_properties = Hash.new
		secondary_properties = Hash.new

		h.each do |property, value|
			case property
			when :checklists, :estimate
				secondary_properties[property] = value
			when :activity_id, :owner_id, :package_id, :parent_id
				if value.is_a? Integer
					primary_properties[property] = value
				else
					primary_properties[property] = lookup(property, value)
				end
			else
				primary_properties[property] = value
			end
		end

		task = @current_workspace.create_task(primary_properties).attributes
		set_current_task task[:id]

		secondary_properties.each do |property, value|
			case property
			when :checklists
				value.each do |checklist|
					unless checklist[:owner_id].is_a? Integer 
						checklist[:owner_id] = lookup(:owner_id, 
													  checklist[:owner_id])
					end
					@current_task.create_checklist_items checklist
				end
			when :estimate
				@current_task.create_estimate value
			end
		end
		
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

	def list _subject
		raise RuntimeError, 'Workspace not set' if @current_workspace == nil

		case _subject
		when :activities
			@current_workspace.activities.elements.each do |e|
				a = e.attributes
				@activities[a[:id]] = a
			end
		when :items
			@current_workspace.treeitems.each do |e|
				a = e.attributes
				@items[a[:id]] = a
			end
		when :members
			@current_workspace.members.elements.each do |e|
				a = e.attributes
				@members[a[:id]] = a
			end
		end
	end

	def lookup _item, _value
		lookup_matches = nil

		case _item
		when :activity_id
			lookup_matches = @activities.select do |k, v|
				v[:name] =~ /#{_value}/i
			end
		when :owner_id
			lookup_matches = @members.select do |k, v| 
				v[:user_name] =~ /#{_value}/i
			end
		when :package_id
			lookup_matches = @items.select do |k, v| 
				v[:name] =~ /#{_value}/i and v[:type] =~ /package/i
			end
		when :parent_id
			lookup_matches = @items.select do |k, v| 
				v[:name] =~ /#{_value}/i and v[:type] =~ /folder/i
			end
		end

		case lookup_matches.length
		when 0
			raise RuntimeError, "No match returned for #{_item} #{_value}"
		when 1
			return lookup_matches.keys.first
		else
			raise RuntimeError, "Multiple match returned for #{_item} #{_value}"
		end
	end

	def populate_lookup_tables
		unless @lookup_tables_loaded
			print 'Loading workspace data... ' unless @quiet_mode
			get_workspaces
			list :activities
			list :members
			list :items
			puts 'DONE!' unless @quiet_mode

			@lookup_tables_loaded = true
		end

		return self
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