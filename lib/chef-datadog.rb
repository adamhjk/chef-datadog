require 'rubygems'
require 'dogapi'

class Chef
  class DataDog < Chef::Handler
    def initialize(api_key)
      @api_key = api_key
      @dog = Dogapi::Client.new(api_key, 'https://app.datadoghq.com')
    end

    def report
      our_time = Time.now.utc
      @dog.emit_point("chef.resources.total", run_status.all_resources.length, :host => run_status.node.name)
      @dog.emit_point("chef.resources.updated", run_status.updated_resources.length, :host => run_status.node.name)
      @dog.emit_point("chef.resources.elapsed_time", run_status.elapsed_time, :host => run_status.node.name)

      event_data = "Chef run for #{run_status.node.name}"
      if run_status.success?
        event_data << " complete in #{run_status.elapsed_time} seconds\n"
      else
        event_data << " failed in #{run_status.elapsed_time} seconds\n"
      end
      event_data << "Managed #{run_status.all_resources.length} resources\n"
      event_data << "Updated #{run_status.updated_resources.length} resources"
      if run_status.updated_resources.length.to_i > 0
        event_data << "\n\n@@@\n"
        run_status.updated_resources.each do |r|
          event_data << "- #{r.to_s} (#{r.defined_at})\n"
        end
        event_data << "\n@@@\n"
      end

      if run_status.failed?
        event_data << "\n\n@@@\n#{run_status.formatted_exception}\n@@@\n"
        event_data << "\n\n@@@\n#{run_status.backtrace.join("\n")}\n@@@\n"
      end

      Chef::Log.warn(event_data)
      @dog.emit_event(Dogapi::Event.new(event_data), :host => run_status.node.name)
    end
  end
end
