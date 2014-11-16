require 'zendesk_api'
require 'time'
require 'tzinfo'
require 'csv'
require 'net/http'
require 'open-uri'
require 'sqlite3'

begin

  $db = SQLite3::Database.new( "ztocw.db" )
  puts $db.get_first_value 'SELECT SQLITE_VERSION()'
  $db.execute "CREATE TABLE IF NOT EXISTS tickets(id INTEGER PRIMARY KEY, tid INTEGER)"

rescue SQLite3::Exception => e
  puts "Exception occured"
  puts e

end


begin

$client = ZendeskAPI::Client.new do |config|
  # Mandatory:

  config.url = "https://somedomain.zendesk.com/api/v2" # e.g. https://mydesk.zendesk.com/api/v2

  # Basic / Token Authentication
  config.username = "enochroot@somedomain.com"

  # Choose one of the following depending on your authentication choice
  config.token = "asasdfasdfasdfasdfasdfasdfasdf"
  # config.password = "asdfasdfasdfasdf"

  # Retry uses middleware to notify the user
  # when hitting the rate limit, sleep automatically,
  # then retry the request.
  config.retry = true

  # Logger prints to STDERR by default, to e.g. print to stdout:
  #require 'logger'
  #config.logger = Logger.new(STDOUT)

end

rescue
  puts "A call to the Zendesk API failed"

end

count = 0

def fetchData(request)

  begin

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

  rescue
      puts "The SSL Call Failed."
  end

end # end fetchData

def excsv(cols,output,count,tid)
  $csv = CSV.open("output.txt", "ab", :col_sep => "|") do |file|
    #file << headers
    if count == 1
      file << cols
     end 
    output.each do |x|
      file << x.values
    end
    $doneFile << tid
    $db.execute "INSERT INTO tickets(tid) VALUES (#{tid})"
    #output.each do |l|
    #  file.puts l
    #end
    #file << output
  end
end

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



#ticket = client.ticket.find(:id => "37477")

def ticketexport tid,count

  begin
    ticket = ZendeskAPI::Ticket.find($client, :id => tid, :include => :users)
  rescue
    puts "The call to the Zendesk API failed for ticket #{tid}, moving on."
  end

  if ticket.nil?
      puts "No ticket at #{tid}"
      return
  elsif ticket.organization.nil?
      puts "No organization on ticket #{tid}"
      return
  elsif ticket.requester.nil?
      puts "No requester on ticket #{tid}"
      return
  #elsif ticket.status.to_s != "closed" 
  #    puts "Ticket status is not closed"
  #    return
  end


  #if ticket.requester.nil?
  #  return "No requester on ticket #{tid}"
  #else ticket.organization.nil?
  #  return "No organization on ticket #{tid}"
  #end
  puts ticket.id
  puts ticket.to_json

  #puts ticket.status
  #puts ticket.url
  #puts ticket.date
  puts "Company: #{ticket.organization.name}"
  puts "Requester: #{ticket.requester.name}"
  puts "Requester Email: #{ticket.requester.email}"
  puts "Requester Alias: #{ticket.requester.alias}"
  #puts ticket.subject
  #puts ticket.description

  ctime = Time.parse("#{ticket.created_at}")
  cdate = ctime.in_timezone 'America/Chicago'
  cwtime = ctime.strftime("%m/%d/%Y")

  #puts cdate
  begin
    audits = ticket.audits.each
  rescue
      puts "Collecting audits failed, trying again in 30 seconds."
      sleep 30
      audits = ticket.audits.each
  end
  # puts audits.to_json
  # This is a UNC PATH where we will put all of the files
  # On a Windows server.
  # This is NOT ideal, but is a side effect of using a janky import process.
  # It works, but it's a dirty hack.
  path = '\\\\share.somedomain.com\cw\\'

  $pubc = "\n\n################################\n\nThese were Zendesk Public Comments.\n\n"
  $pubc << "Zendesk Ticket URL: https://zen.somedomain.com/tickets/#{ticket.id}\n\n"
  $privc = "\n\n################################\n\nThese Were Zendesk Private Comments.\n\n"
  # $pubc << "Full text: #{path}#{ticket.id}\\FullThread.txt\n\n"
  


  audits.each do |i|
    
    t = Time.parse("#{i.created_at}")
    $localtime = t.in_timezone 'America/Chicago'
    $endtime = t.strftime("%m/%d/%Y")
    i.events.each do |e|
      #if e.body =~ /Ticket \{\{ticket\.id\}\}/
      #puts e.attachments
      if e.attachments
        if ! File.directory?("./cw/#{ticket.id}")
          dir = Dir.mkdir("./cw/#{ticket.id}")
          #dir = Dir.mkdir("./cw/#{ticket.id}/msgs")
        end
        e.attachments.each do |att|
          begin
            afile = att.file_name.gsub(/\//, '-')
            afile = afile.gsub(/^\./, '')
            puts afile
            $pubc << "\n\nAttachment: #{path}#{ticket.id}\\#{afile}\n\n"
            # File.write("./cw/#{ticket.id}/#{att.file_name}", Net::HTTP.get(URI.parse("#{att.content_url}")))        
            File.write("./cw/#{ticket.id}/#{afile}", fetchData("#{att.content_url}"))
          rescue
            puts "There was a problem writing the attachment #{afile}"
          end
        end
      end  
      if e.type.to_s == "Comment"
        if e.public.to_s == 'false'
        # puts "This is a " + ( e.public.to_s == 'false' ? "PRIVATE comment.\n" : "PUBLIC comment.\n" )
          $privc << "\n\n################################\n\n"
          $privc << "At #{$localtime}, #{i.author.email} said:\n\n" rescue "There was an error here"
          #out = e.body[0..30000]
          $privc << e.body
        #if e.attachments
        else
        # puts "This is a " + ( e.public.to_s == 'false' ? "PRIVATE comment.\n" : "PUBLIC comment.\n" )
          $pubc << "\n\n################################\n\n"
          $pubc << "At #{$localtime}, #{i.author.email} said:\n\n" rescue "There was an error here"
          #out = e.body[0..30000]
          $pubc << e.body
          $pubc + "\n\n"
          
        end

      else
        next
      end
    end 
  end

  $pubc << ticket.description
  # Per connectwise, we have to strip out the pipes from the descriptions
  $privc.gsub!('|','*pipe character was removed here*')
  #puts $privc

  $pubc.gsub!('|', '*pipe character was removed here*')
  #puts $pubc

  #puts $privc
  #puts $pubc

  #fulltext = FILE.open("./cw/#{ticket.id}/FullThread.txt", "w") do |ffile|
  #  ffile << $privc
  #  ffile <<pubc
  #end

  headers = %w{SrBoard CompanyName ContactName SrStatus SrType SrSubType SrItem SrSource SrLocation SrPriority Summary DetailDescription InternalAnalysis Resolution AssignedBy DateEntered DateCompleted ConfigName ResourceMember}

  output = [{
    'SrBoard' => "Service Desk",
    'CompanyName' => "#{ticket.organization.name}",
    'ContactName' => "#{ticket.requester.alias}",
    'SrStatus' => "Closed",
    'SrType' => "",
    'SrSubType' => "",
    'SrItem' => "",
    'SrSource' => "Zendesk",
    'SrLocation' => "Remote",
    'SrPriority' => "Priority 5 - No SLA",
    'Summary' => "#{ticket.subject}",
    'DetailDescription' => "#{$pubc}",
    'InternalAnalysis' => "#{$privc}",
    'Resolution' => "",
    'AssignedBy' => "zadmin",
    'DateEntered' => "#{cwtime}",
    'DateCompleted' => "#{$endtime}",
    'ConfigName' => "",
    'ResourceMember' => ""
  }]

  cols = output.first.keys
  excsv cols,output,count,tid
end

def indb(tid)
  stm = $db.prepare "SELECT * FROM tickets WHERE tid=#{tid}"
  rs = stm.execute
  rs.each do |row|
    if row[1]
      puts "Ticket #{tid} has already been processed."
      return true
    end
  end
end


idArray = File.open("ticket_ids.txt") or die "Unable to open Ticket ID file..."
$doneFile = File.open("done.txt", "ab") or die "Couldn\'t open doneFile..."

ids = idArray.each_line do |tid|

  if tid.nil?
    put "No ticket at #{tid}"
    next
  end

  if ! indb tid
    count += 1
    ticketexport tid,count
  end
    
end

##while idArray.shift do |tid|
#  if tid.nil?
#    put "No ticket at #{tid}"
#    next
#  else
#   count += 1
#   ticketexport tid,count
#  end
#end
