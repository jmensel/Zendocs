require 'zendesk_api'
require 'time'
require 'tzinfo'
require 'net/http'
require 'open-uri'
require "sinatra"
require "sinatra/activerecord"
require "yaml"
 

db = YAML.load_file(File.expand_path("../../config/database.yml", __FILE__))
ActiveRecord::Tasks::DatabaseTasks.database_configuration = db

=end
begin

client = ZendeskAPI::Client.new do |config|
  # Mandatory:

  config.url = "https://zendesk-subdomain.zendesk.com/api/v2" # e.g. https://mydesk.zendesk.com/api/v2

  # Basic / Token Authentication
  config.username = "you@yourdomain.com"

  # Choose one of the following depending on your authentication choice
  config.token = "YourConfigToken"
  # config.password = "asdfasdfasdfasdf"

  # Retry uses middleware to notify the user
  # when hitting the rate limit, sleep automatically,
  # then retry the request.
  config.retry = true

  # Logger prints to STDERR by default, to e.g. print to stdout:
  #require 'logger'
  #config.logger = Logger.new(STDOUT)

end

rescue ZendeskAPI::Error => e
  puts "A call to the Zendesk API failed"

end

count = 0

def fetchData(request)

  #begin

      url = URI.parse(request)
      http = Net::HTTP.new( url.host, url.port )
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      path = url.path + "?" + url.query
      data = http.get( path )
      if data.is_a?(Net::HTTPSuccess)
        return data.body
      else
        puts "Oh, snap!  The HTTP Call failed."
      end

  #rescue
  #    puts "The SSL Call Failed."
  #end

end # end fetchData


class Time
   require 'tzinfo'
   # tzstring e.g. 'America/Los_Angeles'
   def in_timezone tzstring
     tz = TZInfo::Timezone.get tzstring
     p = tz.period_for_utc self
     e = self + p.utc_offset
     "#{e.strftime("%m/%d/%Y %I:%M %p")} #{p.zone_identifier}"
   end
end 

def topics(client,db)

  begin
    client.topics.all do |topic|      
      puts "Topic ID: #{topic.id}"
      puts "Topic Title: #{topic.title}"
      puts "Topic ForumID: #{topic.forum_id}"

      Topic.where(:tid => topic.id).first_or_create(
        :tid => topic.id,
        :title => topic.title,
        :forumid => topic.forum_id,
        :body => topic.body,
        :json => topic.to_json
        ) 
      

      topic.attachments.each do |attachment|
        attach(client,db,attachment,topic)
      end

    end

  rescue ActiveRecord::RecordInvalid => invalid
    puts "I failed to insert the topic into the database.  Something is no bueno."
    puts invalid.record.errors
  end

end

def attach(client,db,attachment,topic)

  puts "File: #{topic.id}"
  if ! File.directory?("./public/files/#{topic.id}")
    dir = Dir.mkdir("./public/files/#{topic.id}")
  end

  apath = "./public/files/#{topic.id}/#{attachment.file_name}"
  puts "./public/files/#{topic.id}/#{attachment.file_name}"
  path = "#{topic.id}/#{attachment.file_name}"

  if ! File.exist?("./public/files/#{topic.id}/#{attachment.file_name}")
    puts "Fetching #{attachment.file_name} - #{attachment.content_url}"
    puts "Filename: ./public/files/#{topic.id}/#{attachment.file_name}"
    File.write("#{apath}", fetchData("#{attachment.content_url}"))
        
   end
   # Regardless of whether we fetched the file or not, update the db entry.
    Attachment.where(:tid => topic.id, :name => attachment.file_name).first_or_create(
      :tid => topic.id,
      :name => attachment.file_name,
      :url => attachment.content_url,
      :path => path
     ) 
end  

def fora(client,db)
   begin

    client.forums.all do |forum|
      #puts forum
      puts "#{forum.id} - #{forum.name}"

      Forum.where(:fid => forum.id).first_or_create(
      :fid => forum.id,
      :name => forum.name
      )

    end
    #puts forums

  rescue
  
    puts "The call to the Zendesk API for a list of forums failed."
  
  end
end

topics(client,db)
fora(client,db)
