require 'write_xlsx'

class ExcelInterface
	def self.dump_activities _d, _path
		wb = WriteXLSX.new _path

		col = row = 0

		if _d.length == 0
			ws = wb.add_worksheet
			ws.write(row, col, 'No timesheets found')
			wb.close
			return
		end

		_d.each do |member, md|
			ws = wb.add_worksheet member

			md.each do |year, yd|
				yd.each do |week, wd|
					first_day = self.get_first_day_given_commercial(year, week)
					ws.write(row, col, "Week of #{first_day}")
					row += 1

					ws.write(row, col, 'Activities')
					(0..6).each do |i|
						ws.write(row, col+i+1, (first_day + i).strftime("%a %-m/%-d"))
					end
					ws.write(row, 8, 'Project Total')
					row += 1

					activities = {}
					daily_total = {}
					daily_total.default = 0
					total = 0
					wd.each do |date, dd|
						dd.each do |activity, hours|
							activities[activity] ||= {}
							activities[activity][date] = hours
							daily_total[Date.parse(date).cwday] += hours
						end
					end

					activities.sort.each do |activity, whd|
						project_total = 0
						ws.write(row, col, activity)

						whd.each do |date, hours|
							ws.write(row, Date.parse(date).cwday, hours)
							project_total += hours
							total += hours
						end

						ws.write(row, col+8, project_total)

						row += 1
					end

					ws.write(row, col, 'Daily Total')
					daily_total.each do |col_index, daily|
						ws.write(row, col_index, daily)
					end
					ws.write(row, col+8, total)

					row += 2
				end
			end
			#dd.each do |date, 
		end

		wb.close
	end

	def self.get_first_day_given_commercial _y, _w
		return Date.strptime("#{_y} #{_w}", "%Y %W")
	end
end