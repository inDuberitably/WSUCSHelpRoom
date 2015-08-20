class EmailRequestForm
  class << self
    attr_accessor :sender, :email_id, :original_msg, :hours, :completed, :total_hours
    def to_s
      return "Sender:#{self.sender}\nEmail_id:#{self.email_id}\nOriginal_msg:#{self.original_msg}\nHours:#{self.hours}\nCompleted?:#{self.completed}\n"
    end
  end
end
