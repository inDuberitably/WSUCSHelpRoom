require 'mail'
require './EmailRequestForm.rb'
class EmailBot
  def initialize
    @@cases= File.open('subjects.txt').read.split("\n")
    @@entire_phrases= File.open('phrases.txt').read.split("\n").each{|y| y.gsub!(/\s+/, '_')}
    @@display_phrases = ""
    a = ""
    list = File.read('email_list.txt').scan(/[^\s+]+/).each {|y| a<<y}
    config_pop3 = File.read('pop3.txt').split("\n")
    config_smtp = File.read('smtp.txt').split("\n")
    @@address_book = Mail::AddressList.new(a)

    @@entire_phrases.each do |w|
      @@display_phrases+= w.gsub(/_/, " ")
      if @@entire_phrases.index(w) != @@entire_phrases.length-1
        @@display_phrases+= ", "
      end
    end
    @@time_slot_hsh = {}
    @@i = 0
    @@pop=Mail.defaults do
      retriever_method :pop3, :address    => config_pop3[0],
        :port       => config_pop3[1],
        :user_name  => config_pop3[2],
        :password   => config_pop3[3],
        :enable_ssl => true
    end

    options = { :address              => config_smtp[0],
                :port                 => config_smtp[1],
                :user_name            => config_smtp[2],
                :password             => config_smtp[3],
                :authentication       => 'plain', #'login' for Office365
                :encryption => 'tls', 
                :enable_starttls_auto => true  }
    Mail.defaults do
      delivery_method :smtp, options
    end
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
        send_mail(requested_time,false)
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
=begin
Writes response to a given request
=end
  def send_mail(requested_time,flag)
    msg = requested_time.parts[0].body.decoded
    hours = available_hours(msg)
    send_message = ""
=begin
Is this a response or new request?
=end    
    if !@@time_slot_hsh.has_key? requested_time.subject.gsub(/[^(\d+(...)+)]/,"") and flag == false
      subj = "Hours Available as of #{Time.now}"
      send_message = %Q(
        The following shift is available from #{requested_time.from[0]}: #{hours}
        Original Message:
        #{msg}

        If you can cover the ENTIRE shift respond with one of the following phrases: #{@@display_phrases}

        If you can cover a portion of the shift respond using: [ ] and enclose the times are able to cover this shift)

      store_msg(requested_time.from,subj,msg,hours,false)
    elsif @@time_slot_hsh.has_key? requested_time.subject.gsub(/[^(\d+(...)+)]/,"") and flag == false
      puts "Hey someone can cover for part of the time"
      subj = requested_time.subject
      #Grabs everything between brackets
      msg.scan(/\[(.*?)\]/).each{|c| c.each {|d| send_message<< d.strip}}
      send_message += "\n Partial time awarded to #{requested_time.from[0]}"
    else
      subj = requested_time.subject
      send_message = "Hours are awarded to #{requested_time.from}\n#{msg}"
    end
    puts "\asending mail"
    @@address_book.addresses.each do |person|
      mail = Mail.deliver do
        from    'izzy.dome@gmail.com'
        to       person
        subject  subj
        text_part do
          body send_message
        end
      end
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
=begin
Reads email responses 
=end
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
        partial_content = content.scan(/\[(.*?)\]/).flatten 
        content=content.scan(/^[^\:]+\n/).each{|y| y.strip!}.each{|y| y.gsub!(/\s+/, '_')}
        content=@@entire_phrases&content

=begin
Responder can cover all hours
=end

        if !content.empty? and @@entire_phrases.any?{|phrase| phrase.include? content[0]}
          puts "Awarding hours..."
          @@time_slot_hsh.fetch(date_key).completed = true
          self.send_mail(email,true)
=begin
Responder can cover a portion of the shift.
=end
        elsif partial_content.length >= 2
          send_mail(email,false)
        else
 			puts "What the fuck dude he fucked up big time."
        end

=begin
An email was sent, but didn't meet the requirements
=end        
      else
        puts "I'm in the kitchen cooking pies with my baby."
      end
    end
    return hours
  end
end
em = EmailBot.new()

puts em.check_inbox
