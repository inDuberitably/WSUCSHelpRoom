require 'mail'
require './EmailRequestForm.rb'
class EmailBot
  def initialize
    @@cases= File.open('subjects.txt').read.split("\n")
    @@entire_phrases= File.open('phrases.txt').read.split("\n").each{|y| y.gsub!(/\s+/, '_')}
    @@display_phrases = ""
    @@commands = File.open('commands.txt').read.split("\n")
    a = ""
    list = File.read('email_list.txt').scan(/[^\s+]+/).each {|y| a<<y}
    @@address_book = Mail::AddressList.new(a)
    @@config_pop3 = File.read('pop3.txt').split("\n")
    config_smtp = File.read('smtp.txt').split("\n")

    @@entire_phrases.each do |w|
      @@display_phrases+= w.gsub(/_/, " ")
      if @@entire_phrases.index(w) != @@entire_phrases.length-1
        @@display_phrases+= ", "
      end
    end
    @@time_slot_hsh = {}
    @@pop=Mail.defaults do
      retriever_method :pop3, :address    => @@config_pop3[0],
        :port       => @@config_pop3[1],
        :user_name  => @@config_pop3[2],
        :password   => @@config_pop3[3],
        :enable_ssl => true
    end

    options = { :address              => config_smtp[0],
                :port                 => config_smtp[1],
                :user_name            => config_smtp[2],
                :password             => config_smtp[3],
                :authentication       => 'login', #'login' for Office365
                :encryption => 'tls',
                :enable_starttls_auto => true  }
    Mail.defaults do
      delivery_method :smtp, options
    end
  end

  def purge_completed(email)
    @@time_slot_hsh.delete_if{|key,request| request.completed == true}
    send_email(email,"Purged completed requests.")
  end

  def show_requests()
    if !@@time_slot_hsh.values.empty?
      @@time_slot_hsh.values.select{|request| request.completed == false }.each do |requests|
        puts requests
      end
    else
      puts "{}"
    end
  end

  def status(email)
    status = []
    @@time_slot_hsh.values.each do |requests|
      status << requests
    end
    send_email(email,status)
  end

  def check_inbox()
    show_requests()
    hours =  inbox()
    if hours.empty?
      puts "No requests as of #{Time.now}."
    else
      hours.each do |requested_time|
        send_requests(requested_time,false)
      end
    end
  end
=begin
meant for one user to manage internals
=end
  def send_email(email,command)
    send_message = command
    mail = Mail.deliver do
      from    @@config_pop3[4]
      to       email.from
      subject  email.subject
      text_part do
        body send_message
      end
    end

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
  def send_requests(requested_time,flag)
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

        If you can cover a portion of the shift respond using: [ ] and enclose the times are able to cover this shift
      )

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
        from    @@config_pop3[4]
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
    mail_box = @@pop.all.select{|x| !x.nil?}
    mail_box.each do |email|
=begin
Checks for NEW time off requests
examples: "I need time off for today", "Hours for next week", "I need someone to cover my shift"
=end
      header = @@cases + @@commands & email.subject.downcase.scan(/\w+/).each {|word| word.strip!}
      date_key =  email.subject.gsub(/[^(\d+(...)+)]/,"")
      content = email.body.parts[0].body.decoded
      if @@cases.any?{|sub| sub.include? header[0]} and !@@time_slot_hsh.has_key? date_key
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
          send_requests(email,true)
=begin
Responder can cover a portion of the shift.
=end
        elsif partial_content.length >= 2
          send_requests(email,false)
        else
          puts "Invalid format."
        end
=begin
An email was sent as a command
=end
      elsif  @@commands.any?{|phrase| phrase.include? header[0]}
        if header.include? "status"
          status(email)
        elsif header.include? "purge"
          purge_completed(email)
        end
=begin
An email was sent, but didn't meet the requirements
=end        
      else
        puts "Email without valid subject headers"
      end
    end
    return hours
  end
end
