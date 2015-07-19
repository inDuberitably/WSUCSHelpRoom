require 'mail'

class EmailRequestForm
  class << self
    attr_accessor :sender, :email_id, :original_msg, :hours, :completed, :total_hours
    def to_s
      return "Sender:#{self.sender}\nEmail_id:#{self.email_id}\nOriginal_msg:#{self.original_msg}\nHours:#{self.hours}\nCompleted?:#{self.completed}\n"
    end
    def total_hours
      total_hours = self.hours.scan(/\d+/)
      return(total_hours[0]..total_hours[1]).to_a
    end
  end
end

class EmailBot
  def initialize
    @@cases= File.open('subjects.txt').read.split("\n")
    @@entire_phrases= File.open('phrases.txt').read.split("\n")
    @@time_slot_hsh = {}
    @@working_hours = working_hours()
    @@i = 0
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
    Mail.defaults do
      delivery_method :smtp, options
    end
  end
  def working_hours()
    a = (10..12).to_a
    b = (1..9).to_a
    c = (10.5..12.5).step.to_a
    d = (1.5..9).step.to_a
    return a + b + c + d
  end
  def check_inbox()
    puts @@i
    @@i += 1

    @@time_slot_hsh.values.select{|request| request.completed == false }.each do |requests|
      puts requests
    end

    hours =  inbox()
    if hours.empty?
      puts "Process is asleep"
      sleep(30)
    else
      hours.each do |requested_time|
        send_mail(requested_time)
      end
    end
    return check_inbox()
  end

  def available_hours(msg)
=begin
Grabs time slots  
=end
    time_slot = msg.scan(/((\d+:)(..)|\d+)/)
    hsh_slot= Hash[time_slot.map {|key, value| [key, value]}]
    return hsh_slot.keys.join(" - ")
  end

  def send_mail(requested_time)
    msg = requested_time.parts[0].body.decoded
    subj = "Hours Available as of #{Time.now}"
    hours = available_hours(msg)
    send_message = "The following shift is available from #{requested_time.from}: #{hours}\n\nOriginal Message:\n#{msg}"
    puts "\asending mail"
    mail = Mail.deliver do
      from    ''
      to       ''
      subject  subj
      text_part do
        body send_message
      end
    end
    if !@@time_slot_hsh.has_key? subj.gsub(/[^(\d+(...)+)]/,"")
      store_msg(requested_time.from,subj,msg,hours,false)
    end
  end
  def store_msg(original_sender,id,content,hours,status)
    stored_msg = Class.new(EmailRequestForm) do
      self.sender = original_sender
      self.email_id = id
      self.original_msg = content
      self.hours = hours
      self.completed = status
    end
    key = id.gsub(/[^(\d+(...)+)]/,"")
    @@time_slot_hsh[key] = stored_msg
  end

  def inbox()
    puts "Opening inbox"
=begin
key phrases to select mail with as to prevent spam
=end
    hours = []
    @@pop.all.each do |email|
=begin
Checks for NEW time off requests
examples: "I need time off for today", "Hours for next week", "I need someone to cover my shift"
=end
      header = @@cases & email.subject.downcase.scan(/\w+/).each {|word| word.strip!}
      date_key =  email.subject.gsub(/[^(\d+(...)+)]/,"")
      content = email.body.parts[0].body.decoded
      if header.length >= 1 and !@@time_slot_hsh.has_key? date_key
        hours << email
        puts "You've got mail with subject headers"
=begin
Checks for replies to OLD requests
examples: "Hours Available as of #{Time.now}"
=end
      elsif @@time_slot_hsh.has_key? date_key and @@time_slot_hsh.fetch(date_key).completed == false
        puts "I'm like hey what's up hello\a"
=begin
Responder can cover all hours
=end
        if  @@entire_phrases.include? content
          @@time_slot_hsh.fetch(date_key).completed = true
          self.send_mail(email)
        end
=begin

=end        
      else

        puts "I'm in the kitchen cooking pies with my baby."

      end
    end
    return hours
  end

end

