# app.rb

require "sinatra"
require "sinatra/activerecord"
require "yaml"
require "json"

# Note that the production incarnation of this app used http basic auth
# That was integrated with PAM, which was then integrated with an 
# Active Directory domain controller.
# A such, we're not worrying about authentication here, so much as we just needed
# To give the app a tiny little memory so that it won't throw modals all over the place

use Rack::Session::Cookie, :key => 'rack.session',
                           :path => '/',
                           :expire_after => 86400, # In seconds
                           :secret => 'ThisShouldBeABigAwfulRandomNumber'
# To Generate a good Cookie Secret, try this:
# head -n 1 /dev/urandom | openssl enc -base64

db = YAML.load_file(File.expand_path("../config/database.yml", __FILE__))
ActiveRecord::Tasks::DatabaseTasks.database_configuration = db

class Topic < ActiveRecord::Base
  has_many :attachments
  has_many :audits
  belongs_to :Forum
end

class Forum < ActiveRecord::Base
  has_many :topics
end

class Attachment < ActiveRecord::Base
  belongs_to :topic
end

class Audit < ActiveRecord::Base
  belongs_to :Topic
end

get "/" do 
  
  #session[:start] ||= Time.now
  puts "Session: #{session[:start]}"
  # Fire up a session, and set a variable
  # that tells the erb template to open a modal
  # dialog with info/instructions/nags
  if (session[:start]).nil?
    @openmodal = "yes"
    session[:start] = Time.now
    puts "Started session: #{session[:start]}"
  end
  #@openmodal = 'yes'
  # fid sets the default forum in the dropdown
  fid = '21232258'
	@topics = Topic.order("title ASC")
  @forums = Forum.all.order("NAME ASC")
  @forum = Forum.where(fid: fid).first
	erb :"topics/index"

end

get "/topics.json" do
  # Feeds the augular typeahead search
  content_type :json
  @topics = Topic.select("id, title")
  @topics.to_json
end

post "/search" do
	terms = params[:search]
	# @topics = Topic.find(:all, :conditions => [ "title LIKE ?", params[:search] ])
  erb :"topics/index"
end

post "/forum" do

  @forums = Forum.all.order("NAME ASC")
  @forum = Forum.where("fid = ?", params[:forumid]).first
  @topics = Topic.where("forumid = ?", params[:forumid]).order("TITLE ASC")
  erb :"topics/index"

end

post "/topics/:id" do
  # This guy updates existing topics
  # puts params[:text]
  #id = params[:id]
  username = request.env['REMOTE_USER']
  topic = Topic.find_by("id = ?", params[:id])
  # Using this form implicitly parameterizes the query.  Don't get all stressed out over it.
  topic.body = params[:text]
  topic.edited = true
  topic.save

  audit = Audit.new
  audit.username = username
  audit.notes = "Placeholder"
  audit.topics_id = topic.id
  audit.body = params[:text]
  audit.save

end

post "/topics/title/:id" do
  content_type :json
  username = request.env['REMOTE_USER']
  #title = params[:value]

  find = Topic.exists?(['title LIKE ?', "%#{params[:value]}%"])

  puts find

  if find
    topic = Topic.find_by("id = ?", params[:pk])
    response = { :status => 'error', :msg => "The article #{params[:value]} already exists.", :oldvalue => "#{topic.title}" }
    puts response.to_json
    halt 400, "That article already exists."
  elsif params[:value] == ''
    response = { :status => 'error', :msg => 'Really?  You have to Enter a Title', :oldvalue => "#{topic.title}" }
    halt 200, response.to_json
  else
    topic = Topic.find_by("id = ?", params[:pk])
    topic.title = params[:value]
    topic.edited = true
    topic.save

    audit = Audit.new
    audit.username = username
    audit.notes = "Title was Changed to #{params[:value]}"
    audit.topics_id = topic.id
    audit.save
    response = { :status => 'Saved', :msg => "#{topic.title}" }
  end
  # Return status
  response.to_json

end

post "/topic/new" do

  find = Topic.exists?(["title ilike ?", "%#{params[:title]}%" ])
  #puts find

  if find
    if @topic = Topic.find_by_title("#{params[:title].to_s}")
    #@topic = Topic.find(:conditions => ['title ilike ?', "%#{params[:title]}%" ])
    #@topic = Topic.where(["title ilike ?", "%#{params[:title]}%" ])
      redirect "/topics/#{@topic.id}"
    end
  end  

  @topic = Topic.create
  if params[:value] == ''
    response = { :status => 'error', :msg => 'Really?  You have to Enter a Title', :oldvalue => "#{topic.title}" }
    halt 400, "Really?  You have to Enter a Title"
    @topic.destroy
  else
    @topic.title = params[:title].to_s
    @topic.body = "Click Here To Edit"
    @topic.save
    #@title = @topic.title
    #@attachments = Attachment.where("tid = ?", params[:id])
    #@attachments = Attachment.where("tid = ?", @topic.tid)
    #@audits = Audit.where("topics_id = ?", @topic.id).order(created_at: :desc)
    redirect "/topics/#{@topic.id}"
  end
end

get "/topic/new" do

  find = Topic.exists?(["title ilike ?", "%#{params[:title]}%" ])
  #puts find

  if find
    if @topic = Topic.find_by_title("#{params[:title].to_s}")
    #@topic = Topic.find(:conditions => ['title ilike ?', "%#{params[:title]}%" ])
    #@topic = Topic.where(["title ilike ?", "%#{params[:title]}%" ])
      redirect "/topics/#{@topic.id}"
    end
  end  

  @topic = Topic.create
  if params[:value] == ''
    response = { :status => 'error', :msg => 'Really?  You have to Enter a Title', :oldvalue => "#{topic.title}" }
    halt 400, "Really?  You have to Enter a Title"
    @topic.destroy
  else
    @topic.title = params[:title].to_s
    @topic.body = "Click Here To Edit"
    @topic.save
    #@title = @topic.title
    #@attachments = Attachment.where("tid = ?", params[:id])
    #@attachments = Attachment.where("tid = ?", @topic.tid)
    #@audits = Audit.where("topics_id = ?", @topic.id).order(created_at: :desc)
    redirect "/topics/#{@topic.id}"
  end
end

get "/fora" do
  @fora = Forum.all
end

get "/audits/:id" do
  id = params[:id]
  @entries = Audit.find_by id: params[:id]
  puts @entries.to_json
end

get "/audit/:id" do
  @entry = Audit.find_by id: params[:id]
end

# Get the individual page with this ID.
get "/topics/:id" do
  if params[:id] == "new"
    @topic = Topic.new
    @topic.title = "New Topic"
    @topic.body = "Your engaging content goes here."
  else
    @topic = Topic.find_by id: params[:id]
    @title = @topic.title
    #@attachments = Attachment.where("tid = ?", params[:id])
    @attachments = Attachment.where("tid = ?", @topic.tid)
    @audits = Audit.where("topics_id = ?", @topic.id).order(created_at: :desc)
  end
  erb :"topics/show"
end


get "/about" do
  
  if (session[:about]).nil?
    @openmodal = "yes"
    puts "Started session: #{session[:start]}"
    session[:about] = 1
  end
  if session[:about] > 3
    session[:about] = nil
  else
    session[:about] += 1
  end
  erb :"topics/about"
end

get "/files/*/*.*" do |path, ext|
  [path, ext]
end


helpers do
	# If @title is assigned, add it to the page's title.
  def title
    if @title
      "#{@title} -- The Last Incarnation of Docs"
    else
      "The Last Incarnation of Docs"
    end
  end
 
  # Format the Ruby Time object returned from a post's created_at method
  # into a string that looks like this: 06 Jan 2012
  def pretty_date(time)
   time.strftime("%d %b %Y")
  end
 
  include Rack::Utils
  alias_method :h, :escape_html

end
