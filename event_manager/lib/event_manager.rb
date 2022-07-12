# frozen_string_literal: true

require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'
require 'time'
require 'date'

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5, '0')[0, 5]
end

def legislators_by_zipcode(zip)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = 'AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw'

  begin
    civic_info.representative_info_by_address(
      address: zip,
      levels: 'country',
      roles: ['legislatorUpperBody', 'legislatorLowerBody']
    ).officials
  rescue
    'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
  end
end

def save_thank_you_letter(id, form_letter)
  Dir.mkdir('output') unless Dir.exist?('output')

  filename = "output/thanks_#{id}.html"

  File.open(filename, 'w') do |file|
    file.puts form_letter
  end
end

def clean_phone_number(phone)
  phone_numbers = 0
  0.upto(phone.length - 1) do |i|
    phone_numbers += 1 if phone[i] !~ /\D/
  end
  phone = 'bad number' if phone_numbers < 10 || phone_numbers > 11
  if phone_numbers == 11
    phone = phone[0] == '1' ? phone[1, 10] : 'bad number'
  end
  phone
end

def time_targeting_hours(date, hours)
  h = Time.strptime(date, '%m/%d/%y %k:%M').hour
  hours[h] += 1
end

def weekday_targeting(date, days)
  d = Date.strptime(date, '%m/%d/%y').wday
  days[d] += 1
end
puts 'EventManager Initialized!'

template_letter =  File.read('form_letter.erb')
erb_template = ERB.new template_letter
hours = Hash.new(0)
days = Hash.new(0)

contents = CSV.open(
  'event_attendees.csv',
  headers: true,
  header_converters: :symbol
)

contents.each do |row|
  id = row[0]
  name = row[:first_name]
  zipcode = clean_zipcode(row[:zipcode])
  phone = clean_phone_number(row[:homephone])
  time_targeting_hours(row[:regdate], hours)
  weekday_targeting(row[:regdate], days)

  legislators = legislators_by_zipcode(zipcode)

  form_letter = erb_template.result(binding)

  save_thank_you_letter(id, form_letter)
end

hours_sorted = hours.sort_by { |hour, times| times }.reverse
days_sorted = days.sort_by { |days, times| times }.reverse