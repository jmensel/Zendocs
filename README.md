# The Zendesk Documentation Transmogrifier and Reader

This little app was born of a problem:  my team and I were migrating all of our ticketing and documentation stuff out of Zendesk and into other systems.  This was a pity, because Zendesk is awesome, and I was sad to see it go.

Anyway, the point of this app is to get your forum articles out of Zendesk and into a little-bitty web app that you can use to manipulate the docs with some bare-bones editing and search features.  It was never intended to be a complete CMS, or even a feature-complete app, just a tidy way of moving stuff out of Zendesk.

Please note that, strictly speaking, I'm a sysadmin, not a developer, so you may see some code that you find silly, simplistic, or verbose to the point of lunacy.  This is by design - I have to keep things simple, or it all runs off the rails :-)

The versioning feature in particular is dynfunctional, and I suggest that you disable it.

The rest of the app works fine, and has survived a years worth of 25-odd nerds beating on it, so it's somewhat robust when used as directed.
  
# Setup

Nothing special or odd here.  Make sure you've got ruby 1.9.3 or newer.  We're using Sinatra, which is quite lightweight and doesn't have a ton of crazy dependencies.

I *strongly* suggest that if you aren't using RVM to manage Ruby, go get a copy yesterday.  It will save you considerable wailing and gnashing of teeth.

cd into the root directory and do:

	$ bundle install

The efficacy of the bundle install command is going to vary depending on how you've set your system up.  Go ahead and work out the kinks.  I'll grab a cup of coffee while you get it sorted.

To fire up a local copy, we'll use shotgun.  Shotgun's nice, as we don't have to reload Sinatra every time we make a change to the app.

	$ cd <root directory>

	# Select your ruby
	$ rvm use ruby-1.9.3-p545; # Or whatever floats your boat and is 1.9.3 or better

	# Fire up the server
	$ shotgun

	# Test
	http://localhost:9393

# Postgres:
	Setting up a postgres instance is beyond the scope of what I'll document here.  So far as the app is concerned, just look in *database.yml* for all the usual properties that need to be set.


# Seeding the database (Which will download EVERYTHING from Zendesk, and may take a while):

There are some rake jobs that fetch all of the articles in your Zendesk forums, along with any files that are attached, and stick them in a Postgres database.

To update the database, download new attachments, and sync everything up with Zendesk:

	$ rake db:drop

	$ rake db:create

	$ rake db:migrate

	# Fetches the data from Zendesk
	# Executes db/seeds.rb
	$ rake db:seed

# Authentication
This app was designed to fit an environment that used (of all things)  Basic Authentication, which was connected to PAM, which was in turn connected to Active Directory via Centrify.  This worked surprisingly well, and despite it's limitations was fine for this very limited use case.

If you deploy this app in a production environment, you'll need to fancy up your Apache configs to use all of these things.  Don't blindly copy this into your Apache config file - I'm putting it here for example purposes only.  In this case, we're using Mod_Passenger to do ruby duties.  

# This config may drink all of the beer in your fridge!
# Don't use it blindly!  Seriously!
        ServerName docs.yourdomain.com
        DocumentRoot /var/www/vhosts/docs/public
        AddExternalAuth pwauth /usr/sbin/pwauth
        SetExternalAuthMethod   pwauth pipe
        PassengerAppEnv production
        PassengerRuby /usr/local/rubies/.rvm/gems/ruby-1.9.3-p545/wrappers/ruby
        <Directory />
                Options FollowSymLinks
                AllowOverride None
        </Directory>
        <Directory /var/www/vhosts/docs/public/>
                Options -Indexes +FollowSymLinks -MultiViews
                AllowOverride None
                AuthType Basic
                AuthName "Speak, friend, and enter."
                #AuthPAM_Enabled On
                AuthBasicProvider external
                AuthExternal pwauth
                require valid-user
        </Directory>

