require 'mail'
class EmailBot
  def initialize
    @@pop=Mail.defaults do
      retriever_method :pop3, :address    => "pop.gmail.com",
        :port       => 995,
        :user_name  => '',
        :password   => '',
        :enable_ssl => true
    end

    options = { :address              => "smtp.gmail.com",
                :port                 => 587,
                :user_name            => '',
                :password             => '',
                :authentication       => 'plain',
                :enable_starttls_auto => true  }
    @@smtp=Mail.defaults do
      delivery_method :smtp, options
    end
  end
  def check_inbox()
    hours =  inbox()
    if hours.empty?
      puts "Process is asleep"
      sleep(30)
    else
      puts "Sending email"
      send_mail(hours)
    end
    return check_inbox()
  end

  def send_mail(hours)
    email_log = File.open('email.txt','w')
    hours.each do |email|
      puts email.class
      puts email.to_s
      email_log.write(email.to_s)
    end
=begin
    @@smtp.deliver do
      from		''
      to       ''
      subject  'Hours Available'
      body     File.read('email.txt')
    end
=end
  end
  def inbox()
    puts "Opening inbox"
=begin
key phrases to select mail with as to prevent spam
=end
    hours = []
    cases= File.open('subjects.txt').read.split("\n")
    @@pop.all.each do |email|
      puts email
      if cases.include? email.subject.downcase
        puts "You've got mail with subject headers"
        hours << email
      end
    end
    return hours
  end
end

