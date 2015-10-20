require 'open-uri'

projects = YAML.load(File.open('config.yml'))['projects']

class ErrbitUpdater
  attr_reader :name, :data
  def initialize(name, data)
    @name = name
    @data = data
  end

  def call
    Errbit.new({
      date_format: '%d/%m %H:%M',
      base_uri: 'https://log.subvisual.co',
      api_key: data['errbit']['api_key'],
    }).values
  end
end

class SemaphoreUpdater

  def self.with_updated_response
    api_url = "https://semaphoreapp.com/api/v1/projects?auth_token=#{ENV['SEMAPHORE_AUTH_TOKEN']}"
    @api_response = JSON.parse(open(api_url).read)
    self
  end

  def self.api_response
    @api_response
  end

  attr_reader :name, :data
  def initialize(name, data)
    @name = name
    @data = data
  end

  def call
    project = self.class.api_response.find { |project| project['name'] == data['semaphore']['name'] }
    branch = project['branches'].find { |branch| branch['branch_name'] == (data['semaphore']['branch'] || 'master') }

    return unless branch

    {
      label: branch['branch_name'],
      value: "Build #{branch['branch_name']}, #{branch['result']} ",
      time: calculated_time(branch['finished_at']),
      state: branch['result']
    }
  end

  def calculated_time(finished_at)
    if finished_at
      duration(Time.now - Time.parse(finished_at))
    else
      "Not built yet"
    end
  end

  def duration(time)
    secs  = time.to_int
    mins  = secs / 60
    hours = mins / 60
    days  = hours / 24

    if days > 0
      "#{days} days and #{hours % 24} hours ago"
    elsif hours > 0
      "#{hours} hours and #{mins % 60} minutes ago"
    elsif mins > 0
      "#{mins} minutes and #{secs % 60} seconds ago"
    elsif secs >= 0
      "#{secs} seconds ago"
    end
  end
end

SCHEDULER.every '1m', first_in: 0 do |job|
  project_data = projects.each_with_object([]) do |project, result|
    name, data = project
    result << {
      name: name,
      errbit: ErrbitUpdater.new(name, data).call,
      semaphore: SemaphoreUpdater.with_updated_response.new(name, data).call
    }
  end

  send_event 'projects', { projects: project_data }
end
